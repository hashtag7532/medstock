import 'package:flutter/services.dart';

import '../models/medicine.dart';
import 'claude_label_reader.dart';
import 'label_parser.dart';

class ScanResult {
  const ScanResult({required this.draft, required this.source, this.warning});

  final Medicine draft;

  /// Which reader produced the draft, shown to the user.
  final String source;
  final String? warning;
}

/// Reads a label photo. Uses Claude vision when an API key is provided
/// (`--dart-define=CLAUDE_API_KEY=...`), otherwise free on-device OCR.
class ExtractionService {
  ExtractionService({ClaudeLabelReader? claude}) : _claude = claude;

  final ClaudeLabelReader? _claude;

  bool get usesAi => _claude != null;

  Future<ScanResult> extract(String imagePath) async {
    final claude = _claude;
    if (claude != null) {
      try {
        return ScanResult(draft: await claude.read(imagePath), source: 'AI label reader');
      } catch (e) {
        return ScanResult(
          draft: await _readOnDevice(imagePath),
          source: 'On-device OCR',
          warning: 'AI reader unavailable, used on-device OCR instead ($e)',
        );
      }
    }
    return ScanResult(draft: await _readOnDevice(imagePath), source: 'On-device OCR');
  }

  /// Native on-device text recognition: ML Kit on Android (MainActivity.kt),
  /// Apple Vision on iOS (AppDelegate.swift). Free and works offline.
  static const _ocr = MethodChannel('medstock/ocr');

  Future<Medicine> _readOnDevice(String imagePath) async {
    final raw = await _ocr.invokeListMethod<Map<Object?, Object?>>('recognize', {'path': imagePath}) ?? const [];
    final lines = [
      for (final line in raw) OcrLine(line['text'] as String? ?? '', (line['height'] as num?)?.toDouble() ?? 0),
    ];
    return const LabelParser().parse(lines, imagePath: imagePath);
  }
}
