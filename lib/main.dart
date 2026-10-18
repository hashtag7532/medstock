import 'package:flutter/material.dart';

import 'data/medicine_repository.dart';
import 'screens/inventory_screen.dart';
import 'services/extraction_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await MedicineRepository.open();
  runApp(MedStockApp(repository: repository, extraction: ExtractionService.fromEnvironment()));
}

class MedStockApp extends StatelessWidget {
  const MedStockApp({super.key, required this.repository, required this.extraction});

  final MedicineRepository repository;
  final ExtractionService extraction;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F7B6C);
    return MaterialApp(
      title: 'MedStock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: InventoryScreen(repository: repository, extraction: extraction),
    );
  }
}
