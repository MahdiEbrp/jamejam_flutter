/// raz — see doc/raz.md and AGENTS.md
abstract final class Base32 {
  /// The RFC 4648 alphabet.
  static const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Bits delivered per output character.
  static const int bitsPerChar = 5;

  /// Encodes bytes as unpadded upper-case Base32.
  static String encode(List<int> bytes) {
    if (bytes.isEmpty) return '';

    final bits = bytes.length * 8;
    final length = (bits + bitsPerChar - 1) ~/ bitsPerChar;
    final output = List<String>.filled(length, '');
    var bitBuffer = 0;
    var bitsInBuffer = 0;
    var position = 0;

    for (final octet in bytes) {
      bitBuffer = (bitBuffer << 8) | (octet & 0xFF);
      bitsInBuffer += 8;
      while (bitsInBuffer >= bitsPerChar) {
        output[position++] =
            alphabet[(bitBuffer >> (bitsInBuffer - bitsPerChar)) & 0x1F];
        bitsInBuffer -= bitsPerChar;
      }
    }

    if (bitsInBuffer > 0) {
      output[position++] =
          alphabet[(bitBuffer << (bitsPerChar - bitsInBuffer)) & 0x1F];
    }

    return output.join();
  }

  /// Decodes Base32. Whitespace and `=` padding are ignored; case-insensitive.
  ///
  /// Throws [FormatException] for characters outside the alphabet, and
  /// [ArgumentError] for blank input.
  static List<int> decode(String text) {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Base32 text is required.');
    }

    final output = <int>[];
    var bitBuffer = 0;
    var bitsInBuffer = 0;

    for (final raw in text.split('')) {
      if (raw == '=' || raw.trim().isEmpty) continue;

      final value = alphabet.indexOf(raw.toUpperCase());
      if (value < 0) {
        throw FormatException("'$raw' is not a Base32 character.");
      }

      bitBuffer = (bitBuffer << bitsPerChar) | value;
      bitsInBuffer += bitsPerChar;
      if (bitsInBuffer >= 8) {
        output.add((bitBuffer >> (bitsInBuffer - 8)) & 0xFF);
        bitsInBuffer -= 8;
      }
    }

    return output;
  }
}
