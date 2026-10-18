import 'dart:io';

import 'package:flutter/material.dart';

import '../data/medicine_repository.dart';
import '../models/medicine.dart';
import '../widgets/medicine_widgets.dart';

/// Confirm a scanned medicine before saving, or edit/delete an existing one.
class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({
    super.key,
    required this.repository,
    required this.initial,
    this.matches = const [],
    this.notice,
  });

  final MedicineRepository repository;
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
  late final _rows = widget.initial.ingredients.map(_IngredientRow.new).toList();
  late DosageForm _form = widget.initial.form;
  late int? _expiryMonth = widget.initial.expiry?.month;
  late int? _expiryYear = widget.initial.expiry?.year;
  late int _quantity = widget.initial.quantity;
  bool _saving = false;

  bool get _isNew => widget.initial.id == null;

  @override
  void dispose() {
    for (final c in [_brand, _batch, _manufacturer, _unit]) {
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
        createdAt: widget.initial.createdAt,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.repository.save(_build());
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
    await widget.repository.delete(widget.initial);
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
                onPressed: _quantity > 0 ? () => setState(() => _quantity--) : null,
              ),
              SizedBox(
                width: 64,
                child: Text('$_quantity', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              ),
              IconButton.filledTonal(icon: const Icon(Icons.add), onPressed: () => setState(() => _quantity++)),
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
