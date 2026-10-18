import 'package:flutter/material.dart';

import '../models/lab_report.dart';

Color flagColor(BuildContext context, ResultFlag flag) => switch (flag) {
      ResultFlag.low => Colors.blue.shade700,
      ResultFlag.high => Colors.red.shade700,
      _ => Theme.of(context).colorScheme.onSurface,
    };

/// "85,000 /uL" with a low/high marker.
class ResultValue extends StatelessWidget {
  const ResultValue(this.result, {super.key});

  final LabResult result;

  @override
  Widget build(BuildContext context) {
    final color = flagColor(context, result.flag);
    final marker = switch (result.flag) {
      ResultFlag.low => ' L',
      ResultFlag.high => ' H',
      _ => '',
    };
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: result.displayValue,
          style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 15),
        ),
        if (result.unit.isNotEmpty) TextSpan(text: ' ${result.unit}', style: const TextStyle(fontSize: 12)),
        if (marker.isNotEmpty) TextSpan(text: marker, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
