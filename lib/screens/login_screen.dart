import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/auth_service.dart';

/// Phone number, then OTP. Signing in is picked up by the auth gate in main.dart.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  String get _e164 => '+91${_phone.text.trim()}';
  bool get _phoneValid => RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.trim());

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _send({bool resend = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await AuthService.sendOtp(
      _e164,
      resendToken: resend ? _resendToken : null,
      onCodeSent: (id, token) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _resendToken = token;
          _busy = false;
        });
        _startResendTimer();
      },
      onError: (message) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = message;
          });
        }
      },
      onSignedIn: () {},
    );
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.verifyOtp(_verificationId!, _otp.text.trim());
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeSent = _verificationId != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Icon(Icons.medication_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('MedStock', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Your family\'s medicines, doses and health reports in one place.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (!codeSent) ...[
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofocus: true,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _phoneValid && !_busy ? _send() : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _phoneValid && !_busy ? _send : null,
                child: Text(_busy ? 'Sending...' : 'Send OTP'),
              ),
            ] else ...[
              Text('Enter the 6-digit code sent to +91 ${_phone.text}', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
                onChanged: (v) {
                  setState(() {});
                  if (v.length == 6 && !_busy) _verify();
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _otp.text.length == 6 && !_busy ? _verify : null,
                child: Text(_busy ? 'Verifying...' : 'Verify'),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _verificationId = null;
                            _otp.clear();
                            _error = null;
                          }),
                  child: const Text('Change number'),
                ),
                TextButton(
                  onPressed: _resendIn > 0 || _busy ? null : () => _send(resend: true),
                  child: Text(_resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend OTP'),
                ),
              ]),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
            ],
            if (AppConfig.useEmulator) ...[
              const SizedBox(height: 32),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Development mode: no SMS is sent. The OTP appears in the Firebase emulator terminal '
                    '(npm run emulator in server/) and at http://localhost:4000/auth.',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
