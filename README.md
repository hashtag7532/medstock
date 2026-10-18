# MedStock: prototype

Scan the medicines you have at home, keep track of expiry and how much is left,
and check before buying whether you already have the same medicine (or the same
composition under another brand).

## What's in the prototype

| Screen | What it does |
|---|---|
| **Medicine Cabinet** | All medicines, soonest expiry first. Search by name or ingredient. Filters for *Expiring* (within 60 days) and *Expired*. |
| **Scan medicine** | Take or pick a photo, read the label, then **confirm** the details before saving. *Enter manually* is also available. |
| **Check before buying** (bag icon) | Scan at the pharmacy. Shows anything at home with the same brand or the exact same composition and form, with quantity left and expiry. Nothing is saved unless you tap *add to cabinet*. |
| **Edit** | Tap a medicine to change quantity (+/-), expiry or composition, or remove it. |

All data stays on the phone (SQLite, label photos stored in the app's folder).

## Dose tracking

- **Schedules:** each medicine can have a course, e.g. 1 tablet at 8 am and 9 pm for 5 days, or an ongoing one. Set it up from the medicine's screen, the Doses tab, or by scanning a prescription.
- **Reminders:** at each dose time a notification asks *Yes, taken / Skipped / Stopped taking*. **Yes** reduces the cabinet stock by the dose, **Skipped** only records it, and **Stopped** ends the course and cancels its remaining reminders. Answers given while the app is closed are queued in a small file and applied the next time the app opens or resumes.
- **Doses tab:** today's doses, any from the last 2 days still unanswered, and each course's progress, with a warning when stock won't last until the end.
- **Prescription scan (AI):** reads every medicine with its dose (1-0-1, BD, TDS...), duration and instructions, matches each to a cabinet medicine (or adds it), and creates the schedules after you review them.
- **Commonly used for:** the AI pack reader also records what a medicine is typically used for, which you can search on (e.g. "fever"). It can be looked up later for existing medicines. This is general information, not medical advice.

## Health reports

- Add a lab report as a photo, several photos (one per page), or a PDF. With the AI reader, every test is read with its value, unit and reference range. You check the values, then save.
- Test names are standardised ("Platelet count", "HbA1c"...) so the same test lines up across labs. Lakhs and x10^3/uL counts are converted to full numbers.
- **Report view:** values by section, flagged low or high, each compared with the previous report.
- **Trends:** each test over time, as a chart with the normal range shaded and every value listed. Useful for daily platelet counts in dengue, or for comparing annual check-ups year to year.
- Without an API key, reports can still be stored and their values typed in by hand.

## Two ways to read labels

1. **On-device OCR (default, free, offline):** Google ML Kit text recognition
   plus a parser for Indian label formats (`EXP 03/2027`, `B.No.`, `Each tablet
   contains: ... IP 650 mg`, `1x15`). See `lib/services/label_parser.dart`.
2. **AI label reader (much more accurate):** sends the photo to Claude
   (`claude-opus-5-5`), which returns structured fields. It also reads faint or
   embossed expiry dates and counts the tablets still in a strip. Turn it on by
   passing an API key:

   ```
   flutter run --dart-define=CLAUDE_API_KEY=sk-ant-...
   ```

   If the call fails, the app falls back to on-device OCR automatically.

   **Prototype only:** this builds the key into the app. Before giving the app
   to anyone, move the call to a small backend you control.

## Setup

Requires the Flutter SDK, plus Xcode (iOS) and/or Android Studio (Android).

```
./setup.sh      # generates android/ and ios/, adds permissions, runs tests
flutter run
```

Notes:
- ML Kit's iOS pods may not run on the Apple Silicon **iOS simulator**. Use a
  real iPhone or an Android emulator/device.
- iOS needs `platform :ios, '15.5'` in `ios/Podfile` (the script sets it if the
  Podfile exists).

## Code map

```
lib/
  main.dart                       app setup, tabs, applies queued reminder answers on resume
  app_services.dart               creates repositories, AI readers and the dose service
  data/app_database.dart          SQLite schema + migrations (v2: schedules, dose logs, lab reports)
  data/schedule_repository.dart   schedules, dose logs; "taken" reduces stock in one transaction
  data/report_repository.dart     lab reports, results, trends, previous values
  services/dose_service.dart      reminders <-> schedules <-> stock
  services/dose_notifications.dart  local notifications with Yes/Skipped/Stopped actions
  services/claude_client.dart     shared Claude call with structured JSON output
  services/prescription_reader.dart, lab_report_reader.dart  AI readers
  models/medicine.dart            Medicine, Ingredient, expiry status, matching keys
  data/medicine_repository.dart   SQLite storage + "already at home?" matching
  services/extraction_service.dart  picks AI reader or on-device OCR
  services/claude_label_reader.dart Claude vision call (structured JSON output)
  services/label_parser.dart      OCR text to fields heuristics
  screens/                        inventory, scan, confirm/edit form, check result
test/label_parser_test.dart       parser + matching tests
```

## Matching rules

- **Same medicine:** brand names equal after normalising (`DOLO-650 Tablets` = `Dolo 650`).
- **Same composition:** identical active ingredients, strengths **and** dosage
  form. This is deliberately strict; the app labels it "check with your pharmacist"
  and never recommends a substitute on its own.

## iOS notification actions

Reminder buttons need one addition to `ios/Runner/AppDelegate.swift` (iOS hasn't been built yet: it needs Xcode):

```swift
import flutter_local_notifications
// in application(_:didFinishLaunchingWithOptions:), before GeneratedPluginRegistrant:
FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
  GeneratedPluginRegistrant.register(with: registry)
}
```

## Next steps

- Expiry reminder notifications (the notification plumbing now exists)
- Opened-on date for syrups and drops (many must be discarded some weeks after opening)
- Household sharing (sync backend)
- Drug database lookup to standardise names (e.g. a CDSCO-derived dataset)
- Warnings when two medicines share an ingredient (e.g. paracetamol in a cold tablet)
