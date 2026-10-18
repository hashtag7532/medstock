import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_services.dart';
import 'screens/doses_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reports_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  runApp(const MedStockApp());
}

class MedStockApp extends StatelessWidget {
  const MedStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F7B6C);
    return MaterialApp(
      title: 'MedStock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

/// Shows the login screen, or the app with the signed-in user's own data.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _sub;
  User? _user;
  AppServices? _services;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _sub = AuthService.userChanges.listen(_onUser);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _services?.dispose();
    super.dispose();
  }

  Future<void> _onUser(User? user) async {
    if (user?.uid == _user?.uid && _ready) return;
    final old = _services;
    setState(() {
      _user = user;
      _services = null;
      _ready = user == null;
    });
    await old?.dispose();
    if (user == null) return;

    final services = await AppServices.create(user);
    try {
      await services.doses.start();
    } catch (e) {
      // Reminders failing to set up shouldn't stop the cabinet from opening.
      debugPrint('Dose reminders unavailable: $e');
    }
    if (!mounted || _user?.uid != user.uid) {
      await services.dispose();
      return;
    }
    unawaited(services.sync.sync());
    setState(() {
      _services = services;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final services = _services;
    if (_user == null || services == null) return const LoginScreen();
    return HomeShell(key: ValueKey(services.user.uid), services: services);
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Apply Yes/Skipped/Stopped taps made on reminders while the app was in the background.
    if (state == AppLifecycleState.resumed) {
      widget.services.doses.processResponses();
      widget.services.sync.sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          InventoryScreen(services: widget.services),
          DosesScreen(services: widget.services),
          ReportsScreen(services: widget.services),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Cabinet'),
          NavigationDestination(icon: Icon(Icons.alarm_outlined), selectedIcon: Icon(Icons.alarm), label: 'Doses'),
          NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: 'Reports'),
        ],
      ),
    );
  }
}
