# MedStock

A home medicine cabinet for Indian families. Scan the medicines you have, track expiry and how much is left, get dose reminders that keep the count up to date, and keep every blood test and health check-up in one place so you can compare results over time.

Flutter app (Android, iOS) + Node.js API + PostgreSQL. Login is by phone number and OTP through Firebase Authentication.

**Product docs:** [Product note](docs/product-note.md) (problem, TG, positioning, onboarding, what not to build, roadmap) · [User journeys](docs/user-journeys.md)

## Features

**Medicine cabinet**
- Scan a strip, box or bottle: name, composition, expiry, batch and pack size are read from the photo (on-device OCR, or Claude vision for better accuracy). You confirm before saving.
- Sorted by expiry, with filters for *expiring within 60 days* and *expired*.
- Search by name, ingredient or use ("fever").
- **Check before buying:** scan a pack at the pharmacy to see if you already have the same medicine, or the same composition under another brand.
- "Commonly used for" on each medicine (general information, not medical advice).

**Doses**
- Courses such as *1 tablet at 8 am and 9 pm for 5 days*, or ongoing.
- A reminder at each dose with **Yes, taken / Skipped / Stopped taking**. *Taken* reduces stock, *Stopped* ends the course. Answers work even when the app is closed.
- Today's doses, unanswered ones, course progress, and a warning when stock won't last the course.
- **Scan a prescription** (1-0-1, BD, TDS, "x 5 days"...) to create schedules automatically.

**Health reports**
- Add lab reports as photos or PDF. Every test is read with its value, unit and reference range.
- Values flagged low/high and compared with the previous report.
- **Trends:** a chart of each test over time with the normal range shaded. Use it for daily platelet counts in dengue, or to compare annual check-ups year to year.

**Accounts and sync**
- Phone number + OTP login (Firebase).
- Each user's data is stored in their own database on the phone (works offline) and synced to the server, so it's backed up and restored on a new phone.

## How it fits together

```
 Flutter app ──── phone + OTP ────▶ Firebase Auth (emulator in development)
   │  SQLite per user                     │ ID token
   │  (offline-first)                     ▼
   └──── POST /v1/sync  (Bearer token) ──▶ Node API ──▶ PostgreSQL
                                          verifies token,       rows scoped
                                          stores per user       by user_id
```

- **Login:** the app signs in with Firebase phone auth and gets an ID token. The API verifies that token on every request and creates the user row on first sight.
- **Storage on the phone:** one SQLite database per user (`medstock_<firebase uid>.db`). Every row carries a UUID, `updated_at` and a `dirty` flag.
- **Sync:** changed rows go up, and the server keeps the newest version of each row (last write wins). The reply carries everything changed for that user since the phone's last sync. Deletes are synced as tombstones. Sync runs at sign-in, when the app resumes, a couple of seconds after any change, and from **Account > Sync now**.
- **What stays on the phone:** label photos and report files (only the extracted data syncs).

## Repository layout

```
lib/                      Flutter app
  main.dart               auth gate (login or app), tabs
  config.dart             --dart-define settings (auth mode, API URL, Firebase)
  app_services.dart       per-user services: storage, repositories, sync, AI readers
  data/                   SQLite schema + repositories (medicines, schedules, reports)
  services/
    auth_service.dart     Firebase phone OTP
    sync_service.dart     two-way sync with the API
    dose_service.dart     schedules <-> reminders <-> stock
    claude_*.dart, *_reader.dart   AI reading of packs, prescriptions, lab reports
  screens/, widgets/      UI
server/                   Node.js API
  src/index.js            routes: /health, /v1/me, /v1/sync
  src/auth.js             Firebase ID token check, user upsert
  src/sync.js             push (last write wins) and pull (changes since cursor)
  migrations/             PostgreSQL schema
  test/api.test.js        end-to-end tests (OTP login, sync, isolation)
test/                     Flutter unit tests
```

## Run it locally

You need **Flutter**, **Android Studio** (emulator) and **Node.js 22+**. PostgreSQL comes from Homebrew.

**1. PostgreSQL** (one-time)

```bash
brew install postgresql@17 && brew services start postgresql@17
```

```bash
/opt/homebrew/opt/postgresql@17/bin/createdb medstock
```

**2. Server** (one-time setup)

```bash
cd server && npm install && cp .env.example .env
```

Check `DATABASE_URL` in `server/.env` (user name = your Mac user).

**3. Every time: start three things**, each in its own terminal:

```bash
cd server && npm run emulator
```

```bash
cd server && npm run dev
```

```bash
flutter run
```

The API creates its tables on first start. In the app, enter any 10-digit mobile number. No SMS is sent: the OTP is printed in the emulator terminal and shown at http://localhost:4000/auth.

**AI reading** (prescriptions, lab reports, better pack reading) needs a Claude API key:

```bash
flutter run --dart-define=CLAUDE_API_KEY=sk-ant-...
```

**On a real Android phone:** use your Mac's Wi-Fi IP (Mac and phone on the same network), and add that IP to `android/app/src/main/res/xml/network_security_config.xml`:

```bash
flutter run --dart-define=DEV_HOST=192.168.1.20
```

## Look at the data

```bash
/opt/homebrew/opt/postgresql@17/bin/psql medstock
```

```sql
SELECT u.phone, m.brand_name, m.quantity, m.expiry
FROM medicines m JOIN users u ON u.id = m.user_id
WHERE NOT m.deleted;
```

Tables: `users`, `medicines`, `schedules`, `dose_logs`, `lab_reports`, `lab_results` (see `server/migrations/001_init.sql`).

## Configuration

App (`--dart-define=NAME=value`):

| Name | Default | Purpose |
|---|---|---|
| `AUTH_MODE` | `emulator` | `emulator` or `firebase` |
| `DEV_HOST` | `10.0.2.2` | Your Mac as seen from the device (10.0.2.2 = Android emulator) |
| `API_BASE_URL` | `http://$DEV_HOST:8080` | MedStock API |
| `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID` | demo values | Real Firebase project settings |
| `CLAUDE_API_KEY` | none | Turns on AI reading |

Server (`server/.env`):

| Name | Purpose |
|---|---|
| `PORT` | API port (8080) |
| `DATABASE_URL` | PostgreSQL connection |
| `FIREBASE_PROJECT_ID` | Project whose ID tokens are accepted |
| `FIREBASE_AUTH_EMULATOR_HOST` | Set in development to accept emulator tokens; remove for real Firebase |

## Switching to real Firebase OTP

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com) and enable **Authentication > Sign-in method > Phone**.
2. Add an Android app with package name `in.medstock.medstock`, and register the SHA-1 and SHA-256 fingerprints (`cd android && ./gradlew signingReport`).
3. **SMS needs billing:** since September 2024, sending OTP SMS requires the **Blaze** (pay-as-you-go) plan, charged per SMS. For testing, add numbers with fixed codes under *Phone numbers for testing*: no SMS, no charge.
4. Run the app with your project's values (Project settings > General > Your apps):

   ```bash
   flutter run --dart-define=AUTH_MODE=firebase --dart-define=FIREBASE_PROJECT_ID=... --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_SENDER_ID=...
   ```

5. In `server/.env`, set `FIREBASE_PROJECT_ID` to your project and remove `FIREBASE_AUTH_EMULATOR_HOST`.

## Tests

```bash
flutter analyze && flutter test
```

Server end-to-end tests (emulator and API must be running):

```bash
cd server && npm test
```

They cover OTP login through the emulator, sync between two devices, newest-edit-wins, deletes, rejecting bad requests, and that one user can never read, change or delete another user's data.

## Security notes (prototype)

- `CLAUDE_API_KEY` is built into the app. Before giving the app to others, move the AI calls behind the API.
- Plain HTTP is allowed only to development addresses (10.0.2.2, localhost). Use HTTPS for any deployed API.
- Health data: lab values and medicines are personal data under India's DPDP Act 2023. Get explicit consent and offer deletion before a public launch.

## iOS notes

iOS hasn't been built yet (needs Xcode). Before building:
- set `platform :ios, '15.5'` in `ios/Podfile` (ML Kit);
- add Firebase phone-auth setup (APNs, URL scheme from the iOS app's settings);
- for reminder buttons, add to `ios/Runner/AppDelegate.swift`:

```swift
import flutter_local_notifications
// in application(_:didFinishLaunchingWithOptions:), before GeneratedPluginRegistrant:
FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
  GeneratedPluginRegistrant.register(with: registry)
}
```

## Roadmap

- Upload label photos and report files to the server (object storage)
- Family/household sharing (several phone numbers, one cabinet)
- Expiry reminder notifications
- Drug database lookup to standardise names and power symptom search
- Warnings when two medicines share an ingredient
- Deploy the API (with HTTPS) and PostgreSQL
