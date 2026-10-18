import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/medicine.dart';
import '../widgets/medicine_widgets.dart';
import 'medicine_form_screen.dart';
import 'scan_screen.dart';

enum _Filter { all, soon, expired }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Medicine> _items = [];
  bool _loading = true;
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
    // Stock goes down when doses are marked as taken.
    widget.services.doses.changes.addListener(_load);
  }

  @override
  void dispose() {
    widget.services.doses.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await widget.services.medicines.all();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    await _load();
  }

  int _count(ExpiryStatus status) => _items.where((m) => m.expiryStatus == status).length;

  List<Medicine> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((m) {
      final matchesFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.soon => m.expiryStatus == ExpiryStatus.soon,
        _Filter.expired => m.expiryStatus == ExpiryStatus.expired,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return m.brandName.toLowerCase().contains(q) ||
          m.ingredients.any((i) => i.name.toLowerCase().contains(q)) ||
          m.uses.toLowerCase().contains(q) ||
          m.form.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Cabinet'),
        actions: [
          IconButton(
            tooltip: 'Check before buying',
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () => _open(ScanScreen(mode: ScanMode.check, services: widget.services)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Search name, ingredient or use (e.g. fever)',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_Filter>(
              segments: [
                ButtonSegment(value: _Filter.all, label: Text('All (${_items.length})')),
                ButtonSegment(value: _Filter.soon, label: Text('Expiring (${_count(ExpiryStatus.soon)})')),
                ButtonSegment(value: _Filter.expired, label: Text('Expired (${_count(ExpiryStatus.expired)})')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? _EmptyState(hasItems: _items.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
                        itemBuilder: (context, i) {
                          final m = visible[i];
                          return ListTile(
                            leading: MedicineThumbnail(m),
                            title: Text(m.brandName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                if (m.compositionSummary.isNotEmpty) m.compositionSummary
                                else if (m.uses.isNotEmpty) m.uses,
                                '${m.quantity} ${m.unit} left',
                              ].join('\n'),
                            ),
                            isThreeLine: m.compositionSummary.isNotEmpty || m.uses.isNotEmpty,
                            trailing: ExpiryBadge(m),
                            onTap: () => _open(MedicineFormScreen(services: widget.services, initial: m)),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan medicine'),
        onPressed: () => _open(ScanScreen(mode: ScanMode.add, services: widget.services)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasItems});

  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              hasItems ? 'Nothing matches' : 'Your cabinet is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              hasItems
                  ? 'Not at home? Then it is fine to buy it.'
                  : 'Scan the medicines you have at home to start tracking expiry and stock.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
