import 'dart:io';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../widgets/medicine_widgets.dart';
import 'schedule_form_screen.dart';

/// Confirm a scanned medicine before saving, or edit/delete an existing one.
class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({
    super.key,
    required this.services,
    required this.initial,
    this.matches = const [],
    this.notice,
  });

  final AppServices services;
  final Medicine initial;
  final List<StockMatch> matches;
  final String? notice;

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _IngredientRow {
  _IngredientRow(Ingredient i)
      : name = TextEditingController(text: i.name),
        strength = TextEditingController(text: i.strength);

  final TextEditingController name;
  final TextEditingController strength;

  void dispose() {
    name.dispose();
    strength.dispose();
  }
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.initial.brandName);
  late final _batch = TextEditingController(text: widget.initial.batchNumber);
  late final _manufacturer = TextEditingController(text: widget.initial.manufacturer);
  late final _unit = TextEditingController(text: widget.initial.unit);
  late final _uses = TextEditingController(text: widget.initial.uses);
  List<DoseSchedule> _schedules = [];
  bool _lookingUp = false;
  late final _rows = widget.initial.ingredients.map(_IngredientRow.new).toList();
  late DosageForm _form = widget.initial.form;
  late int? _expiryMonth = widget.initial.expiry?.month;
  late int? _expiryYear = widget.initial.expiry?.year;
  late int _quantity = widget.initial.quantity;

  /// False until the user changes the count here; until then the stored
  /// count wins, since a dose may be marked as taken while this is open.
  bool _quantityTouched = false;
  bool _saving = false;

  bool get _isNew => widget.initial.id == null;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    widget.services.doses.changes.addListener(_refreshStock);
  }

  Future<void> _refreshStock() async {
    final id = widget.initial.id;
    if (id == null || _quantityTouched) return;
    final stored = await widget.services.medicines.byId(id);
    if (stored != null && mounted) setState(() => _quantity = stored.quantity);
  }

  Future<void> _loadSchedules() async {
    final id = widget.initial.id;
    if (id == null) return;
    final schedules = await widget.services.doses.forMedicine(id);
    if (mounted) setState(() => _schedules = schedules);
  }

  Future<void> _openSchedule([DoseSchedule? existing]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ScheduleFormScreen(services: widget.services, medicine: _build(), existing: existing),
    ));
    await _loadSchedules();
  }

  Future<void> _lookUpUses() async {
    final reader = widget.services.labelReader;
    if (reader == null) return;
    setState(() => _lookingUp = true);
    try {
      final uses = await reader.lookUpUses(_build());
      if (mounted) setState(() => _uses.text = uses);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Look-up failed: $e')));
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  @override
  void dispose() {
    widget.services.doses.changes.removeListener(_refreshStock);
    for (final c in [_brand, _batch, _manufacturer, _unit, _uses]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Medicine _build() => Medicine(
        id: widget.initial.id,
        brandName: _brand.text.trim(),
        ingredients: _rows
            .map((r) => Ingredient(r.name.text.trim(), r.strength.text.trim()))
            .where((i) => i.name.isNotEmpty)
            .toList(),
        form: _form,
        expiry: _expiryMonth != null && _expiryYear != null ? DateTime(_expiryYear!, _expiryMonth!) : null,
        batchNumber: _batch.text.trim(),
        manufacturer: _manufacturer.text.trim(),
        quantity: _quantity,
        unit: _unit.text.trim().isEmpty ? _form.unit : _unit.text.trim(),
        imagePath: widget.initial.imagePath,
        uses: _uses.text.trim(),
        createdAt: widget.initial.createdAt,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    var medicine = _build();
    final id = medicine.id;
    if (id != null && !_quantityTouched) {
      final stored = await widget.services.medicines.byId(id);
      if (stored != null) medicine = medicine.copyWith(quantity: stored.quantity);
    }
    await widget.services.medicines.save(medicine);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${widget.initial.brandName}?'),
        content: const Text('It will be removed from your cabinet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.services.medicines.delete(widget.initial);
    await widget.services.doses.rescheduleAll();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now().year;
    final years = [for (var y = now - 3; y <= now + 7; y++) y];
    if (_expiryYear != null && !years.contains(_expiryYear)) years.add(_expiryYear!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Confirm details' : 'Edit medicine'),
        actions: [
          if (!_isNew) IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (widget.matches.isNotEmpty) ...[StockMatchPanel(widget.matches), const SizedBox(height: 8)],
            if (widget.notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(widget.notice!, style: theme.textTheme.bodySmall),
              ),
            if (widget.initial.imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.initial.imagePath!),
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Medicine name', hintText: 'e.g. Dolo 650'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the name printed on the pack' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DosageForm>(
              initialValue: _form,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final f in DosageForm.values) DropdownMenuItem(value: f, child: Text(f.label))],
              onChanged: (f) => setState(() {
                // Keep the unit in sync unless the user typed a custom one.
                if (_unit.text == _form.unit) _unit.text = f!.unit;
                _form = f!;
              }),
            ),
            const SizedBox(height: 20),
            Text('Expiry', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _expiryMonth,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-')),
                    for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(monthNames[m - 1])),
                  ],
                  onChanged: (v) => setState(() => _expiryMonth = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _expiryYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-')),
                    for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) => setState(() => _expiryYear = v),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Text('How much is left', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                onPressed: _quantity > 0
                    ? () => setState(() {
                          _quantity--;
                          _quantityTouched = true;
                        })
                    : null,
              ),
              SizedBox(
                width: 64,
                child: Text('$_quantity', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              ),
              IconButton.filledTonal(icon: const Icon(Icons.add), onPressed: () => setState(() {
                        _quantity++;
                        _quantityTouched = true;
                      })),
              const SizedBox(width: 16),
              Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'))),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Text('Composition', style: theme.textTheme.titleSmall)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add ingredient'),
                onPressed: () => setState(() => _rows.add(_IngredientRow(const Ingredient('', '')))),
              ),
            ]),
            if (_rows.isEmpty)
              Text('No active ingredients detected. Add them to find same-composition medicines.',
                  style: theme.textTheme.bodySmall),
            for (final row in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(controller: row.name, decoration: const InputDecoration(hintText: 'Paracetamol')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(controller: row.strength, decoration: const InputDecoration(hintText: '650 mg')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _rows.remove(row));
                      // Dispose after the row's TextFields have left the tree.
                      WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
                    },
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            TextField(controller: _batch, decoration: const InputDecoration(labelText: 'Batch number')),
            const SizedBox(height: 12),
            TextField(controller: _manufacturer, decoration: const InputDecoration(labelText: 'Manufacturer')),
            const SizedBox(height: 12),
            TextField(
              controller: _uses,
              decoration: InputDecoration(
                labelText: 'Commonly used for',
                hintText: 'e.g. Fever and mild pain',
                helperText: 'General information, not medical advice',
                suffixIcon: widget.services.hasAi
                    ? (_lookingUp
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(tooltip: 'Look up', icon: const Icon(Icons.auto_awesome_outlined), onPressed: _lookUpUses))
                    : null,
              ),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Text('Dose schedule', style: theme.textTheme.titleSmall)),
                TextButton.icon(
                  icon: const Icon(Icons.alarm_add_outlined),
                  label: const Text('Add schedule'),
                  onPressed: () => _openSchedule(),
                ),
              ]),
              if (_schedules.isEmpty)
                Text('No schedule. Add one to get reminders and track what is left.', style: theme.textTheme.bodySmall),
              for (final s in _schedules)
                Card(
                  child: ListTile(
                    leading: Icon(s.status == ScheduleStatus.active ? Icons.alarm_on_outlined : Icons.alarm_off_outlined),
                    title: Text('${qty(s.dosePerIntake, _unit.text)} at ${s.times.map((t) => t.label).join(', ')}'),
                    subtitle: Text([
                      s.isOngoing ? 'Ongoing' : '${s.durationDays} days from ${s.startDate.day} ${monthNames[s.startDate.month - 1]}',
                      if (s.instructions.isNotEmpty) s.instructions,
                      if (s.status != ScheduleStatus.active) s.status.name,
                    ].join(' · ')),
                    onTap: s.status == ScheduleStatus.active ? () => _openSchedule(s) : null,
                  ),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_isNew ? 'Save to cabinet' : 'Save changes'),
          ),
        ),
      ),
    );
  }
}
