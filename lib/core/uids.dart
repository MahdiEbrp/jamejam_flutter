import 'dart:math';

/// Stable, time-ordered identifiers — the Dart port of the .NET side's version-7 GUIDs.
///
/// Sync (Step 9) matches records across devices by this value, so it must be generated once,
/// never reused, and never derived from a local row number. UUID v7 is time-ordered, which
/// keeps index locality good while staying collision-free in practice.
abstract final class Uids {
  static final Random _random = Random.secure();

  /// Generates a new UUID v7 string.
  static String newUid() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;

    // 48-bit big-endian timestamp.
    final bytes = List<int>.filled(16, 0);
    bytes[0] = (millis >> 40) & 0xFF;
    bytes[1] = (millis >> 32) & 0xFF;
    bytes[2] = (millis >> 24) & 0xFF;
    bytes[3] = (millis >> 16) & 0xFF;
    bytes[4] = (millis >> 8) & 0xFF;
    bytes[5] = millis & 0xFF;

    // Version 7 + 74 random bits.
    for (var i = 6; i < 16; i++) {
      bytes[i] = _random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x70;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
        '-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// True when [value] looks like a UUID (used to validate imported data).
  static bool isValid(String? value) {
    if (value == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
