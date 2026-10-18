import 'package:flutter/material.dart';

import 'app_services.dart';
import 'screens/doses_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  try {
    await services.doses.start();
  } catch (e) {
    // Reminders failing to set up shouldn't stop the cabinet from opening.
    debugPrint('Dose reminders unavailable: $e');
  }
  runApp(MedStockApp(services: services));
}

class MedStockApp extends StatelessWidget {
  const MedStockApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F7B6C);
    return MaterialApp(
      title: 'MedStock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: HomeShell(services: services),
    );
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
    if (state == AppLifecycleState.resumed) widget.services.doses.processResponses();
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
