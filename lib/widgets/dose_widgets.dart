import 'package:flutter/material.dart';

import '../models/schedule.dart';

/// Chips for the dose times of a schedule: tap to change, x to remove.
class DoseTimesEditor extends StatelessWidget {
  const DoseTimesEditor({super.key, required this.times, required this.onChanged});

  final List<DoseTime> times;
  final ValueChanged<List<DoseTime>> onChanged;

  Future<DoseTime?> _pick(BuildContext context, DoseTime initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    return picked == null ? null : DoseTime(picked.hour, picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final t in times)
          InputChip(
            avatar: const Icon(Icons.schedule, size: 18),
            label: Text(t.label),
            onPressed: () async {
              final picked = await _pick(context, t);
              if (picked != null) onChanged([...times.where((x) => x != t), picked]..sort());
            },
            onDeleted: times.length > 1 ? () => onChanged(times.where((x) => x != t).toList()) : null,
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Add time'),
          onPressed: () async {
            final picked = await _pick(context, times.isEmpty ? DoseTime.morning : DoseTime.afternoon);
            if (picked != null && !times.contains(picked)) onChanged([...times, picked]..sort());
          },
        ),
      ],
    );
  }
}

/// A compact - value + control.
class NumberStepper extends StatelessWidget {
  const NumberStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.suffix = ''});

  final int value;
  final int min;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.remove),
        onPressed: value > min ? () => onChanged(value - 1) : null,
      ),
      SizedBox(
        width: 72,
        child: Text('$value${suffix.isEmpty ? '' : ' $suffix'}',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      ),
      IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.add),
        onPressed: () => onChanged(value + 1),
      ),
    ]);
  }
}
