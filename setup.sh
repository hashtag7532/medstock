#!/usr/bin/env bash
# One-time setup: generates the android/ and ios/ folders around the code in lib/.
set -euo pipefail
cd "$(dirname "$0")"

command -v flutter >/dev/null || { echo "Flutter not found. Install it from https://docs.flutter.dev/get-started/install"; exit 1; }

flutter create --org in.medstock --project-name medstock --platforms=android,ios .

# The template's counter test doesn't apply to this app.
if grep -q "Counter increments" test/widget_test.dart 2>/dev/null; then rm test/widget_test.dart; fi

# iOS camera / photo library permission prompts.
PLIST=ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string Take photos of medicine labels to add them to your cabinet." "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string Choose photos of medicine labels to add them to your cabinet." "$PLIST" 2>/dev/null || true

# Google ML Kit needs iOS 15.5+.
if [ -f ios/Podfile ]; then
  sed -i '' "s/^# *platform :ios.*/platform :ios, '15.5'/" ios/Podfile
else
  echo "Note: after the first iOS build, set  platform :ios, '15.5'  at the top of ios/Podfile."
fi

flutter pub get
flutter test
echo "Setup done. Run with:  flutter run   (add --dart-define=CLAUDE_API_KEY=... for the AI reader)"
