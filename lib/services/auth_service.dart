import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config.dart';

/// Phone number + OTP login through Firebase Authentication.
class AuthService {
  static Future<void> init() async {
    await Firebase.initializeApp(options: AppConfig.firebaseOptions);
    if (AppConfig.useEmulator) {
      await FirebaseAuth.instance.useAuthEmulator(AppConfig.devHost, 9099);
    }
  }

  static Stream<User?> get userChanges => FirebaseAuth.instance.authStateChanges();

  /// Sends an OTP to [phoneNumber] (E.164, e.g. +919876543210). On Android
  /// the SMS may be read automatically, in which case [onSignedIn] runs and
  /// no code needs typing.
  static Future<void> sendOtp(
    String phoneNumber, {
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onError,
    required void Function() onSignedIn,
  }) {
    return FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          onSignedIn();
        } on FirebaseAuthException catch (e) {
          onError(_message(e));
        }
      },
      verificationFailed: (e) => onError(_message(e)),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  static Future<void> verifyOtp(String verificationId, String code) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  static String _message(FirebaseAuthException e) => switch (e.code) {
        'invalid-phone-number' => 'That phone number doesn\'t look right.',
        'invalid-verification-code' => 'Wrong OTP. Check the code and try again.',
        'session-expired' || 'code-expired' => 'The OTP expired. Send a new one.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'network-request-failed' => AppConfig.useEmulator
            ? 'Can\'t reach the Firebase emulator. Is `npm run emulator` running in server/?'
            : 'No internet connection.',
        'billing-not-enabled' => 'SMS login needs the Firebase Blaze plan, or use a test phone number.',
        _ => e.message ?? e.code,
      };
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
