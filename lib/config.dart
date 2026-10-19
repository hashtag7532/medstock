import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

/// Build-time settings, passed with --dart-define. Defaults are for local
/// development on the Android emulator against services on this Mac.
class AppConfig {
  /// `emulator`: Firebase Auth emulator (free, OTP shown in its terminal/UI).
  /// `firebase`: a real Firebase project (real SMS; needs the Blaze plan).
  static const authMode = String.fromEnvironment('AUTH_MODE', defaultValue: 'emulator');
  static bool get useEmulator => authMode == 'emulator';

  /// Your Mac as seen from the device: 10.0.2.2 from the Android emulator,
  /// 127.0.0.1 from the iOS simulator. On a real phone, pass your Mac's Wi-Fi IP.
  static const _devHost = String.fromEnvironment('DEV_HOST');
  static String get devHost => _devHost.isNotEmpty ? _devHost : (Platform.isIOS ? '127.0.0.1' : '10.0.2.2');

  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get apiBaseUrl => _apiBaseUrl.isNotEmpty ? _apiBaseUrl : 'http://$devHost:8080';

  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'demo-medstock');

  /// A `demo-` project works with the emulator only and needs no Firebase setup.
  /// For a real project, pass the values from Firebase console > Project settings.
  /// On iOS, phone login also needs the app ID's URL scheme in Info.plist
  /// (app-1-000000000000-ios-0000000000000000 for the demo project).
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        // Placeholder for the emulator. The iOS SDK rejects keys that don't look
        // real (39 characters, starting with "A"); the emulator never checks it.
        apiKey: const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyDemoKeyForLocalEmulatorOnly000000'),
        appId: _appId.isNotEmpty
            ? _appId
            : (Platform.isIOS ? '1:000000000000:ios:0000000000000000' : '1:000000000000:android:0000000000000000'),
        messagingSenderId: const String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '000000000000'),
        projectId: _projectId,
      );
}
