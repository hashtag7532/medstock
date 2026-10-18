import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_services.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../services/prescription_reader.dart';
import '../widgets/dose_widgets.dart';

/// Photograph a prescription (one or more pages) and read it.
class PrescriptionScanScreen extends StatefulWidget {
  const PrescriptionScanScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<PrescriptionScanScreen> createState() => _PrescriptionScanScreenState();
}

class _PrescriptionScanScreenState extends State<PrescriptionScanScreen> {
  final _pages = <String>[];
  bool _busy = false;
  String? _error;

  Future<void> _addFromCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 85);
    if (picked != null) setState(() => _pages.add(picked.path));
  }

  Future<void> _addFromGallery() async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 2000, imageQuality: 85);
    setState(() => _pages.addAll(picked.map((x) => x.path)));
  }

  Future<void> _read() async {
    final reader = widget.services.prescriptions!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = await reader.read(_pages);
      final cabinet = await widget.services.medicines.all();
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'No medicines found. Try a clearer photo.';
        });
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PrescriptionReviewScreen(services: widget.services, items: items, cabinet: cabinet),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not read the prescription: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.services.prescriptions == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan prescription')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Reading prescriptions needs the AI reader. Run the app with '
            '--dart-define=CLAUDE_API_KEY=... or add a schedule by hand from the Doses screen.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Scan prescription')),
      body: _busy
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reading the prescription...'),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Photograph the prescription so every medicine line, the dose (e.g. 1-0-1) and the number of days are visible.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (_pages.isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(_pages[i]), width: 90, height: 120, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _pages.removeAt(i)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_pages.isEmpty ? 'Take photo' : 'Add another page'),
                  onPressed: _addFromCamera,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                  onPressed: _addFromGallery,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _pages.isEmpty ? null : _read,
                  child: Text(_pages.length > 1 ? 'Read ${_pages.length} pages' : 'Read prescription'),
                ),
              ],
            ),
    );
  }
}

class _Draft {
  _Draft(this.item, this.match)
      : include = !item.asNeeded,
        dose = item.dosePerIntake,
        times = item.times.isEmpty ? DoseTime.defaultsFor(1) : item.times,
        days = item.durationDays,
        instructions = TextEditingController(text: item.instructions);

  final PrescriptionItem item;
  Medicine? match;
  bool include;
  int dose;
  List<DoseTime> times;

  /// Null = ongoing.
  int? days;
  final TextEditingController instructions;
}

/// Check what was read, link each line to a cabinet medicine, then create the schedules.
class PrescriptionReviewScreen extends StatefulWidget {
  const PrescriptionReviewScreen({super.key, required this.services, required this.items, required this.cabinet});

  final AppServices services;
  final List<PrescriptionItem> items;
  final List<Medicine> cabinet;

  @override
  State<PrescriptionReviewScreen> createState() => _PrescriptionReviewScreenState();
}

class _PrescriptionReviewScreenState extends State<PrescriptionReviewScreen> {
  late final _drafts = [for (final item in widget.items) _Draft(item, matchPrescriptionItem(item, widget.cabinet))];
  bool _saving = false;

  @override
  void dispose() {
    for (final d in _drafts) {
      d.instructions.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final services = widget.services;
    final today = DateTime.now();
    var created = 0;
    for (final d in _drafts.where((d) => d.include && d.times.isNotEmpty)) {
      final medicine = d.match ??
          await services.medicines.save(Medicine(
            brandName: d.item.displayName,
            form: d.item.form,
            unit: d.item.form.unit,
            ingredients: d.item.activeIngredients.isEmpty ? const [] : [Ingredient(d.item.activeIngredients, d.item.strength)],
            createdAt: today,
          ));
      await services.doses.save(DoseSchedule(
        medicineId: medicine.id!,
        dosePerIntake: d.dose,
        times: d.times,
        startDate: today,
        durationDays: d.days,
        instructions: d.instructions.text.trim(),
      ));
      created++;
    }
    await services.doses.requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$created dose schedules set up')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Check prescription')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text('Check each medicine. Untick anything you don\'t want reminders for.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          for (final d in _drafts) _draftCard(d, theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving || !_drafts.any((d) => d.include) ? null : _save,
            child: Text('Set up ${_drafts.where((d) => d.include).length} schedules'),
          ),
        ),
      ),
    );
  }

  Widget _draftCard(_Draft d, ThemeData theme) {
    final unit = d.match?.unit ?? d.item.form.unit;
    final needed = d.days == null ? null : d.dose * d.times.length * d.days!;
    final have = d.match?.quantity ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CheckboxListTile(
            contentPadding: const EdgeInsets.only(left: 4),
            value: d.include,
            onChanged: (v) => setState(() => d.include = v ?? false),
            title: Text(d.item.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: d.item.asNeeded ? const Text('As needed (SOS): no fixed times') : null,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (d.include)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                DropdownButtonFormField<int?>(
                  initialValue: d.match?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'In your cabinet'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Not in cabinet: add it')),
                    for (final m in widget.cabinet)
                      DropdownMenuItem(value: m.id, child: Text('${m.brandName} (${m.quantity} ${m.unit})')),
                  ],
                  onChanged: (id) => setState(() => d.match = widget.cabinet.where((m) => m.id == id).firstOrNull),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Each dose'),
                  const Spacer(),
                  NumberStepper(value: d.dose, min: 1, suffix: qty(d.dose, unit).split(' ').last, onChanged: (v) => setState(() => d.dose = v)),
                ]),
                const SizedBox(height: 8),
                DoseTimesEditor(times: d.times, onChanged: (t) => setState(() => d.times = t)),
                const SizedBox(height: 8),
                Row(children: [
                  Text(d.days == null ? 'Ongoing' : 'For'),
                  const Spacer(),
                  if (d.days != null)
                    NumberStepper(value: d.days!, min: 1, suffix: 'days', onChanged: (v) => setState(() => d.days = v)),
                  TextButton(
                    onPressed: () => setState(() => d.days = d.days == null ? 5 : null),
                    child: Text(d.days == null ? 'Set days' : 'Ongoing'),
                  ),
                ]),
                TextField(
                  controller: d.instructions,
                  decoration: const InputDecoration(labelText: 'Instructions', isDense: true),
                ),
                if (needed != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    needed > have
                        ? 'Needs $needed $unit, you have $have: buy ${needed - have}'
                        : 'Needs $needed $unit, you have $have',
                    style: TextStyle(color: needed > have ? Colors.orange.shade900 : theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}
