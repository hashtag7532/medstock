import 'package:firebase_core/firebase_core.dart';

/// Build-time settings, passed with --dart-define. Defaults are for local
/// development on the Android emulator against services on this Mac.
class AppConfig {
  /// `emulator`: Firebase Auth emulator (free, OTP shown in its terminal/UI).
  /// `firebase`: a real Firebase project (real SMS; needs the Blaze plan).
  static const authMode = String.fromEnvironment('AUTH_MODE', defaultValue: 'emulator');
  static bool get useEmulator => authMode == 'emulator';

  /// The Mac as seen from the Android emulator is 10.0.2.2. On a real phone,
  /// use your Mac's Wi-Fi IP address.
  static const devHost = String.fromEnvironment('DEV_HOST', defaultValue: '10.0.2.2');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://$devHost:8080');

  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'demo-medstock');

  /// A `demo-` project works with the emulator only and needs no Firebase setup.
  /// For a real project, pass the values from Firebase console > Project settings.
  static FirebaseOptions get firebaseOptions => const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'demo-api-key'),
        appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:000000000000:android:0000000000000000'),
        messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '000000000000'),
        projectId: _projectId,
      );
}
