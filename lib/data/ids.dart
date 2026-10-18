import 'dart:math';

final _random = Random.secure();

/// Random UUID v4. Rows get one on the device so they keep the same identity
/// on the server and on every other device.
String newUuid() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// UTC timestamp at millisecond precision (what the server stores and returns),
/// so a row echoed back by the server compares equal to the local copy.
String nowStamp() => DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch, isUtc: true).toIso8601String();
