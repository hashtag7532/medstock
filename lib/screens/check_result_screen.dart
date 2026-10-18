import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/medicine.dart';
import '../widgets/medicine_widgets.dart';
import 'medicine_form_screen.dart';

/// Result of "check before buying": shows what's already at home.
class CheckResultScreen extends StatelessWidget {
  const CheckResultScreen({super.key, required this.services, required this.scanned, required this.matches});

  final AppServices services;
  final Medicine scanned;
  final List<StockMatch> matches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Check before buying')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('You scanned', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: MedicineThumbnail(scanned),
            title: Text(scanned.brandName.isEmpty ? 'Unknown name' : scanned.brandName),
            subtitle: Text(scanned.compositionSummary.isEmpty ? scanned.form.label : scanned.compositionSummary),
          ),
          const SizedBox(height: 12),
          if (matches.isNotEmpty)
            StockMatchPanel(matches)
          else
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: const ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Not in your cabinet'),
                subtitle: Text('Nothing with this name or composition is recorded at home.'),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(matches.isEmpty ? 'Bought it: add to cabinet' : 'Bought anyway: add to cabinet'),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MedicineFormScreen(services: services, initial: scanned),
              ));
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
  }
}
