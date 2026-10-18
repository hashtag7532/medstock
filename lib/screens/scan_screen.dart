import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_services.dart';
import '../models/medicine.dart';
import 'check_result_screen.dart';
import 'medicine_form_screen.dart';

enum ScanMode {
  /// Add a medicine to the cabinet.
  add,

  /// At the pharmacy: check whether it's already at home, without saving.
  check,
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.mode, required this.services});

  final ScanMode mode;
  final AppServices services;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _scan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.services.extraction.extract(picked.path);
      final matches = await widget.services.medicines.findMatches(result.draft);
      if (!mounted) return;
      await _continueWith(switch (widget.mode) {
        ScanMode.add => MedicineFormScreen(
            services: widget.services,
            initial: result.draft,
            matches: matches,
            notice: result.warning ?? 'Read by ${result.source}. Please check every field.',
          ),
        ScanMode.check => CheckResultScreen(
            services: widget.services,
            scanned: result.draft,
            matches: matches,
          ),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not read the label: $e';
      });
    }
  }

  /// Push the next step, then close this screen once it's done so the
  /// cabinet refreshes after the whole flow finishes.
  Future<void> _continueWith(Widget next) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => next));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCheck = widget.mode == ScanMode.check;
    return Scaffold(
      appBar: AppBar(title: Text(isCheck ? 'Check before buying' : 'Scan medicine')),
      body: _busy
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reading the label...'),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(isCheck ? Icons.shopping_bag_outlined : Icons.document_scanner_outlined,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  isCheck
                      ? 'Scan the medicine you are about to buy. We will tell you if you already have it, or the same composition, at home.'
                      : 'Photograph the pack so the name, composition and expiry date are visible.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const _Tips(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                  onPressed: () => _scan(ImageSource.camera),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                  onPressed: () => _scan(ImageSource.gallery),
                ),
                if (!isCheck) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _continueWith(MedicineFormScreen(
                      services: widget.services,
                      initial: Medicine(brandName: '', createdAt: DateTime.now()),
                    )),
                    child: const Text('Enter manually'),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  widget.services.extraction.usesAi ? 'Using AI label reader' : 'Using on-device OCR (works offline)',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    const tips = [
      'Good light, no glare on the foil',
      'Include the edge where EXP and B.No. are printed',
      'Scan strips before cutting them, or the expiry gets lost',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
