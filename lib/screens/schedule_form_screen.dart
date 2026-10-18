import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../widgets/dose_widgets.dart';

/// Set up or change a dose schedule (e.g. 1 tablet at 8 am and 9 pm for 5 days).
class ScheduleFormScreen extends StatefulWidget {
  const ScheduleFormScreen({super.key, required this.services, required this.medicine, this.existing});

  final AppServices services;
  final Medicine medicine;
  final DoseSchedule? existing;

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  late int _dose = widget.existing?.dosePerIntake ?? 1;
  late List<DoseTime> _times = widget.existing?.times ?? DoseTime.defaultsFor(2);
  late bool _ongoing = widget.existing?.isOngoing ?? false;
  late int _days = widget.existing?.durationDays ?? 5;
  late DateTime _start = widget.existing?.startDate ?? DateTime.now();
  late final _instructions = TextEditingController(text: widget.existing?.instructions ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final base = widget.existing ??
        DoseSchedule(medicineId: widget.medicine.id!, times: _times, startDate: _start);
    await widget.services.doses.save(base.copyWith(
      dosePerIntake: _dose,
      times: _times,
      startDate: _startMoment(),
      durationDays: _days,
      ongoing: _ongoing,
      instructions: _instructions.text.trim(),
    ));
    await widget.services.doses.requestPermission();
    if (mounted) Navigator.of(context).pop();
  }

  /// Starting today means from now; a later day means from that midnight.
  DateTime _startMoment() {
    final now = DateTime.now();
    final day = DateTime(_start.year, _start.month, _start.day);
    final isToday = day == DateTime(now.year, now.month, now.day);
    if (widget.existing != null && day == DateTime(widget.existing!.startDate.year, widget.existing!.startDate.month, widget.existing!.startDate.day)) {
      return widget.existing!.startDate;
    }
    return isToday ? now : day;
  }

  Future<void> _stop() async {
    await widget.services.doses.stop(widget.existing!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.medicine;
    final needed = _ongoing ? null : _dose * _times.length * _days;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Dose schedule' : 'Edit schedule')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(m.brandName, style: theme.textTheme.titleLarge),
          if (m.compositionSummary.isNotEmpty) Text(m.compositionSummary, style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          Text('Each dose', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          NumberStepper(value: _dose, min: 1, suffix: qty(_dose, m.unit).split(' ').last, onChanged: (v) => setState(() => _dose = v)),
          const SizedBox(height: 24),
          Text('Times', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DoseTimesEditor(times: _times, onChanged: (t) => setState(() => _times = t)),
          const SizedBox(height: 24),
          Text('How long', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Number of days')),
              ButtonSegment(value: true, label: Text('Ongoing')),
            ],
            selected: {_ongoing},
            onSelectionChanged: (s) => setState(() => _ongoing = s.first),
          ),
          if (!_ongoing) ...[
            const SizedBox(height: 12),
            NumberStepper(value: _days, min: 1, suffix: 'days', onChanged: (v) => setState(() => _days = v)),
          ],
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Starts'),
            subtitle: Text('${_start.day} ${monthNames[_start.month - 1]} ${_start.year}'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _start,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _start = picked);
            },
          ),
          TextField(
            controller: _instructions,
            decoration: const InputDecoration(labelText: 'Instructions', hintText: 'e.g. After food'),
          ),
          const SizedBox(height: 16),
          if (needed != null)
            Card(
              color: needed > m.quantity ? Colors.amber.shade100 : theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: Icon(needed > m.quantity ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                    color: Colors.black87),
                title: Text('Course needs $needed ${m.unit}', style: const TextStyle(color: Colors.black87)),
                subtitle: Text(
                  needed > m.quantity
                      ? 'You have ${m.quantity}. Buy ${needed - m.quantity} more.'
                      : 'You have ${m.quantity}. Enough for the course.',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'You will get a reminder at each time with Yes, Skipped and Stopped taking. '
            'Yes reduces what is left by ${qty(_dose, m.unit)}.',
            style: theme.textTheme.bodySmall,
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop this course'),
              onPressed: _stop,
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving || _times.isEmpty ? null : _save,
            child: const Text('Save schedule'),
          ),
        ),
      ),
    );
  }
}
