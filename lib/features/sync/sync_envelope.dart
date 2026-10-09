/// sync — see doc/sync.md and AGENTS.md
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'sync_models.dart';
import 'sync_options.dart';

class SyncEnvelope {
  const SyncEnvelope({
    required this.schema,
    required this.service,
    required this.deviceId,
    required this.deviceName,
    required this.createdAt,
    required this.payload,
    required this.checksum,
  });

  /// The current protocol marker.
  static const String currentSchema = 'jamejam.sync/1';

  /// Protocol marker, e.g. `jamejam.sync/1`.
  final String schema;

  /// Which service this payload belongs to (`divan`, `haftkhan`, …).
  final String service;

  /// Stable identifier of the device that sealed the envelope.
  final String deviceId;

  /// Friendly device name for reports.
  final String deviceName;

  /// When the envelope was sealed (UTC, ISO-8601).
  final String createdAt;

  /// The service-owned JSON document.
  final String payload;

  /// SHA-256 hex digest of the UTF-8 payload.
  final String checksum;

  /// Serializes to compact JSON (culture-invariant, UTC timestamps).
  String toJson() => jsonEncode({
    'schema': schema,
    'service': service,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'createdAt': createdAt,
    'payload': payload,
    'checksum': checksum,
  });

  /// Reads an envelope from its JSON form (case-insensitive keys, like the original).
  factory SyncEnvelope.fromJson(Map<String, dynamic> json) {
    Object? pick(String name) {
      for (final entry in json.entries) {
        if (entry.key.toLowerCase() == name) return entry.value;
      }
      return null;
    }

    return SyncEnvelope(
      schema: (pick('schema') as String?) ?? '',
      service: (pick('service') as String?) ?? '',
      deviceId: (pick('deviceid') as String?) ?? '',
      deviceName: (pick('devicename') as String?) ?? '',
      createdAt: (pick('createdat') as String?) ?? '',
      payload: (pick('payload') as String?) ?? '',
      checksum: (pick('checksum') as String?) ?? '',
    );
  }
}

abstract final class SyncSafety {
  /// Seals [payload] into an envelope, verifying the size rail first.
  static SyncEnvelope seal({
    required String service,
    required String payload,
    required String deviceId,
    required String deviceName,
    required DateTime now,
    int maxPayloadBytes = SyncDefaults.maxPayloadBytes,
  }) {
    if (service.trim().isEmpty) {
      throw const SyncException('Sync requires a service tag.');
    }
    if (payload.trim().isEmpty) {
      throw const SyncException('Sync payloads must not be empty.');
    }
    if (deviceId.trim().isEmpty) {
      throw const SyncException('Sync requires a device id.');
    }

    final size = utf8.encode(payload).length;
    if (size > maxPayloadBytes) {
      throw SyncException(
        'Sync payload is $size bytes — above the configured maximum of $maxPayloadBytes. '
        'Trim it or raise the payload rail.',
      );
    }

    return SyncEnvelope(
      schema: SyncEnvelope.currentSchema,
      service: service,
      deviceId: deviceId,
      deviceName: deviceName,
      createdAt: now.toUtc().toIso8601String(),
      payload: payload,
      checksum: checksumOf(payload),
    );
  }

  /// Opens and verifies an envelope: not a document, wrong schema, or corrupted payload.
  static SyncEnvelope open(String envelopeJson) {
    if (envelopeJson.trim().isEmpty) {
      throw const SyncException(
        'The remote document is empty — nothing to sync.',
      );
    }

    SyncEnvelope envelope;
    try {
      final decoded = jsonDecode(envelopeJson);
      if (decoded is! Map) {
        throw const FormatException('not an object');
      }
      envelope = SyncEnvelope.fromJson(decoded.cast<String, dynamic>());
    } on FormatException {
      throw const SyncException(
        'The remote document is not a JameJam sync envelope.',
      );
    }

    if (envelope.payload.trim().isEmpty || envelope.service.trim().isEmpty) {
      throw const SyncException(
        'The remote document is not a JameJam sync envelope.',
      );
    }

    if (envelope.schema != SyncEnvelope.currentSchema) {
      throw SyncException(
        "The remote speaks sync protocol '${envelope.schema}'; this build speaks "
        "'${SyncEnvelope.currentSchema}'. Upgrade JameJam on both devices.",
      );
    }

    if (checksumOf(envelope.payload) != envelope.checksum) {
      throw const SyncException(
        'The remote envelope failed its integrity check (checksum mismatch) — the document '
        'is corrupted or was tampered with. Nothing was merged.',
      );
    }

    return envelope;
  }

  /// SHA-256 of the UTF-8 payload, lowercase hex.
  static String checksumOf(String payload) =>
      sha256.convert(utf8.encode(payload)).toString();
}
