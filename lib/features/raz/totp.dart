/// raz — see doc/raz.md and AGENTS.md
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'base32.dart';
import 'models.dart';
import 'raz_defaults.dart';

abstract final class Totp {
  /// Length of the counter fed to the HMAC (64-bit big-endian).
  static const int counterBytes = 8;

  /// Computes the code for a Base32 seed at [time].
  static Future<String> computeCode(
    String base32Seed,
    DateTime time, {
    int periodSeconds = RazDefaults.defaultTotpPeriodSeconds,
    int digits = RazDefaults.defaultTotpDigits,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
  }) async {
    final key = Base32.decode(base32Seed);
    final counter =
        time.toUtc().millisecondsSinceEpoch ~/ 1000 ~/ periodSeconds;
    return computeCodeForCounter(key, counter, digits, algorithm);
  }

  /// Seconds left before the current code window rolls over.
  static int secondsRemaining(
    DateTime time, {
    int periodSeconds = RazDefaults.defaultTotpPeriodSeconds,
  }) {
    final epoch = time.toUtc().millisecondsSinceEpoch ~/ 1000;
    final intoWindow = epoch % periodSeconds;
    return periodSeconds - intoWindow;
  }

  /// Resolves the code for an entry, or null when the entry has no TOTP seed.
  static Future<String?> codeFor(RazEntry entry, DateTime now) async {
    if (entry.totpAlgorithm == TotpAlgorithm.none || entry.totpSeed.isEmpty) {
      return null;
    }

    return computeCode(
      entry.totpSeed,
      now,
      periodSeconds: entry.totpPeriodSeconds,
      digits: entry.totpDigits,
      algorithm: entry.totpAlgorithm,
    );
  }

  /// The RFC 4226 truncation, over an explicit counter — the shared half of TOTP/HOTP.
  static Future<String> computeCodeForCounter(
    List<int> key,
    int counter,
    int digits,
    TotpAlgorithm algorithm,
  ) async {
    final counterBytes = Uint8List(Totp.counterBytes);
    for (var i = 0; i < Totp.counterBytes; i++) {
      counterBytes[Totp.counterBytes - 1 - i] = (counter >> (8 * i)) & 0xFF;
    }

    final hash = switch (algorithm) {
      TotpAlgorithm.sha256 => Hmac.sha256(),
      TotpAlgorithm.sha512 => Hmac.sha512(),
      // RFC 6238 specifies HMAC-SHA-1 as the authenticator-app default; HMAC-SHA-1
      // remains unbroken for this use (the .NET build carries the same note).
      _ => Hmac.sha1(),
    };

    final mac = await hash.calculateMac(
      counterBytes,
      secretKey: SecretKey(key),
    );
    final digest = mac.bytes;

    final offset = digest[digest.length - 1] & 0x0F;
    final binary =
        ((digest[offset] & 0x7F) << 24) |
        ((digest[offset + 1] & 0xFF) << 16) |
        ((digest[offset + 2] & 0xFF) << 8) |
        (digest[offset + 3] & 0xFF);

    var modulus = 1;
    for (var i = 0; i < digits; i++) {
      modulus *= 10;
    }

    return (binary % modulus).toString().padLeft(digits, '0');
  }
}
