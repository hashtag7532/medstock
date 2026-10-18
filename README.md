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
  main.dart                       app setup
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

## Next steps

- Expiry reminder notifications (`flutter_local_notifications`)
- "Took one" quick action and dose logging
- Opened-on date for syrups and drops (many must be discarded some weeks after opening)
- Household sharing (sync backend)
- Drug database lookup to standardise names (e.g. a CDSCO-derived dataset)
- Warnings when two medicines share an ingredient (e.g. paracetamol in a cold tablet)
