import 'dart:io';

import 'package:flutter/material.dart';

import '../models/medicine.dart';

class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge(this.medicine, {super.key});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (medicine.expiryStatus) {
      ExpiryStatus.expired => ('Expired', scheme.errorContainer, scheme.onErrorContainer),
      ExpiryStatus.soon => ('Exp ${formatExpiry(medicine.expiry)}', Colors.orange.shade100, Colors.orange.shade900),
      ExpiryStatus.ok => ('Exp ${formatExpiry(medicine.expiry)}', scheme.secondaryContainer, scheme.onSecondaryContainer),
      ExpiryStatus.unknown => ('No expiry', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class MedicineThumbnail extends StatelessWidget {
  const MedicineThumbnail(this.medicine, {super.key, this.size = 48});

  final Medicine medicine;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_iconFor(medicine.form), color: Theme.of(context).colorScheme.onPrimaryContainer),
    );
    final path = medicine.imagePath;
    if (path == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  static IconData _iconFor(DosageForm form) => switch (form) {
        DosageForm.tablet || DosageForm.capsule => Icons.medication_outlined,
        DosageForm.syrup || DosageForm.suspension || DosageForm.drops => Icons.local_drink_outlined,
        DosageForm.injection => Icons.vaccines_outlined,
        _ => Icons.medical_services_outlined,
      };
}

/// "You already have this at home" panel, shown when scanning a medicine
/// that matches existing stock.
class StockMatchPanel extends StatelessWidget {
  const StockMatchPanel(this.matches, {super.key});

  final List<StockMatch> matches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usable = matches.where((m) => m.medicine.expiryStatus != ExpiryStatus.expired && m.medicine.quantity > 0);
    final title = usable.isNotEmpty ? 'You already have this at home' : 'Found at home, but expired or used up';
    return Card(
      color: usable.isNotEmpty ? Colors.amber.shade100 : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.inventory_2_outlined, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: Colors.black87))),
            ]),
            const SizedBox(height: 8),
            for (final match in matches) _MatchRow(match),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow(this.match);

  final StockMatch match;

  @override
  Widget build(BuildContext context) {
    final m = match.medicine;
    final how = match.kind == MatchKind.sameBrand
        ? 'Same medicine'
        : 'Same composition, different brand (check with your pharmacist)';
    final status = switch (m.expiryStatus) {
      ExpiryStatus.expired => 'expired ${formatExpiry(m.expiry)}, dispose safely',
      ExpiryStatus.unknown => 'expiry unknown',
      _ => 'expires ${formatExpiry(m.expiry)}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MedicineThumbnail(m, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${m.brandName}\n', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: '${m.quantity} ${m.unit} left, $status\n'),
                TextSpan(text: how, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
              ]),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
