/// raz — see doc/raz.md and AGENTS.md
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'raz_defaults.dart';

class VaultCryptoException implements Exception {
  const VaultCryptoException(this.message);

  /// Human-friendly detail.
  final String message;

  @override
  String toString() => message;
}

abstract final class VaultCrypto {
  static final AesGcm _aes = AesGcm.with256bits();
  static final Random _random = Random.secure();

  /// Fills a fresh buffer from the platform CSPRNG (`Random.secure`).
  static Uint8List randomBytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256)),
  );

  /// Derives a 256-bit key from the passphrase and salt (PBKDF2-HMAC-SHA512).
  static Future<Uint8List> deriveKey(
    String passphrase,
    List<int> salt,
    int iterations,
  ) async {
    if (passphrase.trim().isEmpty) {
      throw const RazCryptoArgumentException('A passphrase is required.');
    }

    if (salt.length != RazDefaults.saltSizeBytes) {
      throw RangeError.value(
        salt.length,
        'salt.length',
        'The salt must be ${RazDefaults.saltSizeBytes} bytes.',
      );
    }

    if (iterations < RazDefaults.minIterations) {
      throw RangeError.value(
        iterations,
        'iterations',
        'Iterations must be at least ${RazDefaults.minIterations}.',
      );
    }

    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: iterations,
      bits: RazDefaults.keySizeBytes * 8,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);

    return Uint8List.fromList(await key.extractBytes());
  }

  /// Encrypts [plaintext] under [key]; output is `nonce || ciphertext || tag`.
  static Future<Uint8List> encrypt(List<int> key, String plaintext) async {
    final nonce = randomBytes(RazDefaults.nonceSizeBytes);
    return encryptWithNonce(key, plaintext, nonce);
  }

  /// Encrypts with an explicit nonce. Only the known-answer tests and the wire-format
  /// cross-check use this — production code always draws a fresh random nonce.
  static Future<Uint8List> encryptWithNonce(
    List<int> key,
    String plaintext,
    List<int> nonce,
  ) async {
    if (nonce.length != RazDefaults.nonceSizeBytes) {
      throw RangeError.value(
        nonce.length,
        'nonce.length',
        'The nonce must be ${RazDefaults.nonceSizeBytes} bytes.',
      );
    }

    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    final tail = RazDefaults.nonceSizeBytes + box.cipherText.length;
    return Uint8List(tail + RazDefaults.tagSizeBytes)
      ..setRange(0, RazDefaults.nonceSizeBytes, nonce)
      ..setRange(RazDefaults.nonceSizeBytes, tail, box.cipherText)
      ..setRange(tail, tail + RazDefaults.tagSizeBytes, box.mac.bytes);
  }

  /// Decrypts a payload produced by [encrypt].
  ///
  /// Throws [VaultCryptoException] for a wrong key, a tampered payload, or a truncated one.
  static Future<String> decrypt(List<int> key, List<int> payload) async {
    if (payload.length <
        RazDefaults.nonceSizeBytes + RazDefaults.tagSizeBytes) {
      throw const VaultCryptoException('Encrypted payload is truncated.');
    }

    final nonce = payload.sublist(0, RazDefaults.nonceSizeBytes);
    final cipherText = payload.sublist(
      RazDefaults.nonceSizeBytes,
      payload.length - RazDefaults.tagSizeBytes,
    );
    final tag = payload.sublist(payload.length - RazDefaults.tagSizeBytes);

    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(key),
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoException('Payload failed authentication.');
    } on FormatException {
      throw const VaultCryptoException('Payload is not valid UTF-8.');
    }
  }

  /// Base64 helper for storing encrypted payloads in text formats.
  static String toText(List<int> payload) => base64.encode(payload);

  /// Base64 helper for reading encrypted payloads from text formats.
  static Uint8List fromText(String text) {
    try {
      return base64.decode(text);
    } on FormatException {
      throw const RazCryptoArgumentException('Not a Base64 payload.');
    }
  }

  /// Zeroes key material as soon as a caller is done with it (best effort — the runtime
  /// may have copied the buffer).
  static void wipe(Uint8List? material) {
    if (material == null) return;
    material.fillRange(0, material.length, 0);
  }
}

class RazCryptoArgumentException implements Exception {
  const RazCryptoArgumentException(this.message);

  /// Human-friendly detail.
  final String message;

  @override
  String toString() => message;
}
