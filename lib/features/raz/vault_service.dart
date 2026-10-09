/// raz — see doc/raz.md and AGENTS.md
import 'dart:convert';
import 'dart:typed_data';

import '../../core/date_only.dart';
import 'models.dart';
import 'password_generator.dart';
import 'raz_defaults.dart';
import 'raz_options.dart';
import 'strength_meter.dart';
import 'totp.dart';
import 'vault_crypto.dart';
import 'vault_store.dart';

class VaultService {
  VaultService({
    required VaultStore store,
    required DateTime Function() clock,
    RazOptions options = const RazOptions(),
  }) : _store = store,
       _clock = clock,
       _options = options {
    _options.validate();
    store.undoDepth = _options.undoDepth;
  }

  final VaultStore _store;
  final DateTime Function() _clock;
  final RazOptions _options;

  Uint8List? _key;
  // Kept only to re-derive keys for portable backups; never persisted.
  String? _passphrase;

  /// The validated options in effect.
  RazOptions get options => _options;

  /// Today according to the injected clock.
  DateOnly get today => DateOnly.fromDateTime(_clock().toUtc());

  /// True once a passphrase has been accepted this lifetime.
  bool get isUnlocked => _key != null;

  /// True when the store already holds vault metadata.
  Future<bool> get isInitialized => _store.isInitialized();

  /// How many undo snapshots are stacked.
  Future<int> get undoCount => _store.undoCount();

  /// Creates the vault with a fresh salt and key-check row.
  ///
  /// Throws [RazException] when the vault already exists.
  Future<void> init(String passphrase) async {
    if (await _store.isInitialized()) {
      throw const RazException(
        'This vault already exists — unlock it instead of initializing again.',
      );
    }

    if (passphrase.trim().isEmpty) {
      throw const RazException('A passphrase is required.');
    }

    final salt = VaultCrypto.randomBytes(RazDefaults.saltSizeBytes);
    final key = await VaultCrypto.deriveKey(
      passphrase,
      salt,
      _options.iterations,
    );
    final check = await VaultCrypto.encrypt(key, RazDefaults.keyCheckPlaintext);
    await _store.setMeta(salt, _options.iterations, check);
    _key = key;
    _passphrase = passphrase;
  }

  /// Verifies the passphrase against the key-check row and unlocks the service.
  ///
  /// Throws [RazException] when there is no vault yet or the passphrase is wrong.
  Future<void> unlock(String passphrase) async {
    if (passphrase.trim().isEmpty) {
      throw const RazException('A passphrase is required.');
    }

    if (!await _store.isInitialized()) {
      throw const RazException('No vault yet — create one first.');
    }

    final salt = await _store.getSalt();
    if (salt == null) {
      throw const RazException('Vault meta is missing its salt.');
    }

    final check = await _store.getKeyCheck();
    if (check == null) {
      throw const RazException('Vault meta is missing its key check.');
    }

    final key = await VaultCrypto.deriveKey(
      passphrase,
      salt,
      await _store.getIterations(),
    );

    String verified;
    try {
      verified = await VaultCrypto.decrypt(key, check);
    } on VaultCryptoException {
      VaultCrypto.wipe(key);
      throw const RazException('Wrong passphrase or corrupted vault.');
    }

    if (verified != RazDefaults.keyCheckPlaintext) {
      VaultCrypto.wipe(key);
      throw const RazException('Wrong passphrase or corrupted vault.');
    }

    _key = key;
    _passphrase = passphrase;
  }

  /// Locks the vault and wipes the derived key from memory.
  void lock() {
    VaultCrypto.wipe(_key);
    _key = null;
    _passphrase = null;
  }

  /// Guards the rest of the service: an unlocked service is required.
  Uint8List _requireKey() {
    final key = _key;
    if (key == null) {
      throw const RazException('The vault is locked — unlock it first.');
    }

    return key;
  }

  // ── Entry lifecycle ──

  /// Adds an entry (encrypting sensitive fields) with an undo snapshot.
  Future<RazEntry> addEntry({
    required String title,
    required String secret,
    String username = '',
    String url = '',
    String notes = '',
    String tags = '',
    String totpSeed = '',
    TotpAlgorithm totpAlgorithm = TotpAlgorithm.none,
    int? totpDigits,
    int? totpPeriodSeconds,
    DateOnly? expiresOn,
    bool favorite = false,
  }) async {
    _requireKey();
    if (await _store.count() >= RazDefaults.maxEntries) {
      throw const RazException(
        'At most ${RazDefaults.maxEntries} entries are allowed.',
      );
    }

    await _pushSnapshot();
    final now = _clock().toUtc();
    final algorithm = _normalizeTotp(
      totpAlgorithm,
      totpSeed,
      totpDigits,
      totpPeriodSeconds,
    );
    final plaintext = RazEntry(
      title: _clean(title, RazDefaults.maxTitleLength),
      secret: secret,
      username: _clean(username, RazDefaults.maxFieldLength),
      url: _clean(url, RazDefaults.maxFieldLength),
      notes: _clean(notes, RazDefaults.maxFieldLength),
      tags: _cleanTags(tags),
      totpSeed: _clean(totpSeed, RazDefaults.maxFieldLength),
      totpAlgorithm: algorithm.$1,
      totpDigits: algorithm.$2,
      totpPeriodSeconds: algorithm.$3,
      expiresOn: expiresOn,
      favorite: favorite,
      createdAt: now,
      updatedAt: now,
    );

    final stored = await _store.addEntry(await _encryptForStore(plaintext));
    return plaintext.copyWith(id: stored.id);
  }

  /// Updates an entry, re-encrypting changed fields, with an undo snapshot.
  Future<RazEntry> updateEntry(int id, RazEntry updated) async {
    if (await findEntry(id) == null) {
      throw RazException('No entry #$id.');
    }

    await _pushSnapshot();
    final existing = await _store.findEntry(id);
    final now = _clock().toUtc();
    final algorithm = _normalizeTotp(
      updated.totpAlgorithm,
      updated.totpSeed,
      updated.totpDigits,
      updated.totpPeriodSeconds,
    );

    final merged = (existing ?? updated).copyWith(
      title: _clean(updated.title, RazDefaults.maxTitleLength),
      secret: updated.secret,
      username: _clean(updated.username, RazDefaults.maxFieldLength),
      url: _clean(updated.url, RazDefaults.maxFieldLength),
      notes: _clean(updated.notes, RazDefaults.maxFieldLength),
      tags: _cleanTags(updated.tags),
      totpSeed: _clean(updated.totpSeed, RazDefaults.maxFieldLength),
      totpAlgorithm: algorithm.$1,
      totpDigits: algorithm.$2,
      totpPeriodSeconds: algorithm.$3,
      expiresOn: updated.expiresOn,
      clearExpiresOn: updated.expiresOn == null,
      favorite: updated.favorite,
      updatedAt: now,
    );

    await _store.updateEntry(await _encryptForStore(merged));
    return merged;
  }

  /// Deletes an entry (undo brings it back) and returns it decrypted.
  Future<RazEntry> deleteEntry(int id) async {
    final existing = await findEntry(id);
    if (existing == null) {
      throw RazException('No entry #$id.');
    }

    await _pushSnapshot();
    await _store.removeEntry(id);
    return existing;
  }

  /// Gets and decrypts one entry.
  Future<RazEntry?> findEntry(int id) async {
    final encrypted = await _store.findEntry(id);
    return encrypted == null ? null : _decrypt(encrypted);
  }

  /// Lists and decrypts entries under the filter.
  Future<List<RazEntry>> listEntries([VaultFilter? filter]) async {
    if (!await _store.isInitialized()) {
      throw const RazException('No vault yet — create one first.');
    }

    _requireKey();
    final effective = filter ?? const VaultFilter();
    final today = this.today;
    final decrypted = <RazEntry>[];
    for (final encrypted in await _store.listEntries()) {
      decrypted.add(await _decrypt(encrypted));
    }

    return decrypted.where((entry) {
      if (effective.tag != null &&
          !entry.tags
              .toLowerCase()
              .split(',')
              .contains(effective.tag!.toLowerCase())) {
        return false;
      }

      if (effective.favoritesOnly && !entry.favorite) return false;

      if (effective.expiredOnly &&
          !(entry.expiresOn != null && entry.expiresOn!.compareTo(today) < 0)) {
        return false;
      }

      if (effective.weakOnly &&
          StrengthMeter.score(entry.secret).score >
              _options.weakScoreThreshold) {
        return false;
      }

      if (effective.query != null && !_matches(entry, effective.query!)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Restores the most recent undo snapshot. Returns false when the stack is empty.
  Future<bool> undo() async {
    final key = _requireKey();
    final payload = await _store.popUndo();
    if (payload == null) return false;

    List<RazEntryDto> entries;
    try {
      entries = _decodeDtoList(await VaultCrypto.decrypt(key, payload));
    } on RazException {
      throw const RazException('The undo snapshot is unreadable.');
    } on VaultCryptoException {
      throw const RazException('The undo snapshot is unreadable.');
    }

    await _store.replaceEntries(entries.map(_fromDto).toList());
    return true;
  }

  // ── Insight ──

  /// Computes aggregate audit statistics (safe to share with the AI coach).
  Future<VaultAuditStats> audit() async {
    final entries = await listEntries();
    final today = this.today;
    final now = _clock().toUtc();

    final bySecret = <String, int>{};
    for (final entry in entries) {
      bySecret[entry.secret] = (bySecret[entry.secret] ?? 0) + 1;
    }

    final reused = bySecret.values
        .where((count) => count > 1)
        .fold<int>(0, (sum, count) => sum + count);
    final lengths = entries.map((e) => e.secret.length);

    return VaultAuditStats(
      totalEntries: entries.length,
      weakCount: entries
          .where(
            (e) =>
                StrengthMeter.score(e.secret).score <=
                _options.weakScoreThreshold,
          )
          .length,
      reusedCount: reused,
      expiredCount: entries
          .where(
            (e) => e.expiresOn != null && e.expiresOn!.compareTo(today) < 0,
          )
          .length,
      expiringSoonCount: entries
          .where(
            (e) =>
                e.expiresOn != null &&
                e.expiresOn!.compareTo(today) >= 0 &&
                e.expiresOn!.compareTo(
                      today.addDays(_options.expiringSoonDays),
                    ) <=
                    0,
          )
          .length,
      oldCount: entries
          .where(
            (e) => !e.updatedAt.isAfter(
              now.subtract(Duration(days: _options.oldAfterDays)),
            ),
          )
          .length,
      averageSecretLength: entries.isEmpty
          ? 0
          : (lengths.reduce((a, b) => a + b) / entries.length).round(),
      uniqueSecrets: bySecret.length,
    );
  }

  /// Entries expiring within [days] (default: the configured window).
  Future<List<RazEntry>> expiringWithin([int? days]) async {
    final window = days ?? _options.expiringSoonDays;
    if (window < 1 || window > RazDefaults.expiringSoonDaysBound) {
      throw RazException(
        'Days must be between 1 and ${RazDefaults.expiringSoonDaysBound}.',
      );
    }

    final today = this.today;
    return (await listEntries())
        .where(
          (e) =>
              e.expiresOn != null &&
              e.expiresOn!.compareTo(today) >= 0 &&
              e.expiresOn!.compareTo(today.addDays(window)) <= 0,
        )
        .toList()
      ..sort((a, b) => a.expiresOn!.compareTo(b.expiresOn!));
  }

  /// Current TOTP code for an entry plus seconds remaining.
  Future<({String code, int secondsRemaining})?> totpNow(int id) async {
    final entry = await findEntry(id);
    if (entry == null) {
      throw RazException('No entry #$id.');
    }

    final now = _clock().toUtc();
    final code = await Totp.codeFor(entry, now);
    if (code == null) return null;
    return (
      code: code,
      secondsRemaining: Totp.secondsRemaining(
        now,
        periodSeconds: entry.totpPeriodSeconds,
      ),
    );
  }

  /// Generates a password under the (validated) policy.
  String generate([PasswordPolicy? policy]) {
    final effective = policy ?? PasswordPolicy(length: _options.passwordLength);
    return PasswordGenerator.generate(effective);
  }

  // ── Export / import (ciphertext-safe) ──

  /// Serializes the vault to a backup bundle. The envelope carries the KDF meta so any
  /// vault with the same passphrase reopens it; the entry list stays AES-GCM encrypted.
  Future<String> exportJson() async {
    final key = _requireKey();
    final rows = await _store.listEntries();
    final inner = jsonEncode(
      rows.map(_toDto).map((dto) => dto.toJson()).toList(),
    );
    final file = VaultBackupFile(
      version: RazDefaults.backupVersion,
      salt: VaultCrypto.toText(await _store.getSalt() ?? Uint8List(0)),
      iterations: await _store.getIterations(),
      keyCheck: VaultCrypto.toText(await _store.getKeyCheck() ?? Uint8List(0)),
      payload: VaultCrypto.toText(await VaultCrypto.encrypt(key, inner)),
    );

    return jsonEncode(file.toJson());
  }

  /// Imports a backup bundle: verifies the bundle's key check under the current
  /// passphrase, decrypts its payload, and inserts the entries (fresh ids, undo-able).
  Future<int> importJson(String bundle) async {
    if (bundle.trim().isEmpty) {
      throw const RazException('This file is not a Raz backup.');
    }

    _requireKey();
    final passphrase = _passphrase;
    if (passphrase == null) {
      throw const RazException('The vault is locked.');
    }

    VaultBackupFile file;
    try {
      final decoded = jsonDecode(bundle);
      if (decoded is! Map<String, Object?>) {
        throw const RazException('This file is not a Raz backup.');
      }

      file = VaultBackupFile.fromJson(decoded);
    } on FormatException {
      throw const RazException('This file is not a Raz backup.');
    }

    if (file.version != RazDefaults.backupVersion) {
      throw const RazException('This backup version is not supported.');
    }

    Uint8List fileKey;
    String inner;
    try {
      fileKey = await VaultCrypto.deriveKey(
        passphrase,
        VaultCrypto.fromText(file.salt),
        file.iterations,
      );
      final verified = await VaultCrypto.decrypt(
        fileKey,
        VaultCrypto.fromText(file.keyCheck),
      );
      if (verified != RazDefaults.keyCheckPlaintext) {
        throw const RazException(
          'This backup was made under a different passphrase — unlock with that '
          'passphrase first.',
        );
      }

      inner = await VaultCrypto.decrypt(
        fileKey,
        VaultCrypto.fromText(file.payload),
      );
    } on VaultCryptoException {
      throw const RazException(
        'This backup was made under a different passphrase — unlock with that '
        'passphrase first.',
      );
    } on FormatException {
      throw const RazException('This file is not a Raz backup.');
    } on RazCryptoArgumentException {
      throw const RazException('This file is not a Raz backup.');
    } on RangeError {
      throw const RazException('This file is not a Raz backup.');
    }

    List<RazEntryDto> entries;
    try {
      entries = _decodeDtoList(inner);
    } on RazException {
      throw const RazException("This backup's contents are unreadable.");
    }

    await _pushSnapshot();
    var imported = 0;
    for (final dto in entries) {
      final plaintext = RazEntry(
        title: await VaultCrypto.decrypt(
          fileKey,
          VaultCrypto.fromText(dto.title),
        ),
        secret: await VaultCrypto.decrypt(
          fileKey,
          VaultCrypto.fromText(dto.secret),
        ),
        username: await VaultCrypto.decrypt(
          fileKey,
          VaultCrypto.fromText(dto.username),
        ),
        url: await VaultCrypto.decrypt(fileKey, VaultCrypto.fromText(dto.url)),
        notes: await VaultCrypto.decrypt(
          fileKey,
          VaultCrypto.fromText(dto.notes),
        ),
        tags: await VaultCrypto.decrypt(
          fileKey,
          VaultCrypto.fromText(dto.tags),
        ),
        totpSeed: await VaultCrypto.decrypt(
          fileKey,
          VaultCrypto.fromText(dto.totpSeed),
        ),
        totpAlgorithm: TotpAlgorithm.fromCode(dto.totpAlgorithm),
        totpDigits: dto.totpDigits,
        totpPeriodSeconds: dto.totpPeriodSeconds,
        expiresOn: dto.expiresOn == null
            ? null
            : DateOnly.parseIso(dto.expiresOn!),
        favorite: dto.favorite,
        createdAt: DateTime.parse(dto.createdAt).toUtc(),
        updatedAt: DateTime.parse(dto.updatedAt).toUtc(),
      );
      await _store.addEntry(await _encryptForStore(plaintext));
      imported++;
    }

    return imported;
  }

  // ── Internals ──

  static List<RazEntryDto> _decodeDtoList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) {
        throw const RazException('Expected a JSON list of entries.');
      }

      return decoded
          .map(
            (row) => RazEntryDto.fromJson((row as Map).cast<String, Object?>()),
          )
          .toList();
    } on FormatException {
      throw const RazException('This backup\'s contents are unreadable.');
    } on TypeError {
      throw const RazException('This backup\'s contents are unreadable.');
    }
  }

  Future<String> _enc(Uint8List key, String value) async =>
      VaultCrypto.toText(await VaultCrypto.encrypt(key, value));

  /// Maps a plaintext entry to its store form: the seven sensitive fields become
  /// Base64 AES-GCM ciphertext; bookkeeping stays clear.
  Future<RazEntry> _encryptForStore(RazEntry plain) async {
    final key = _requireKey();
    if (plain.secret.isEmpty) {
      throw const RazException(
        'A secret is required — pipe it in, generate one, or type it at the prompt.',
      );
    }

    return plain.copyWith(
      title: await _enc(key, plain.title),
      secret: await _enc(key, plain.secret),
      username: await _enc(key, plain.username),
      url: await _enc(key, plain.url),
      notes: await _enc(key, plain.notes),
      tags: await _enc(key, _cleanTags(plain.tags)),
      totpSeed: await _enc(key, plain.totpSeed),
    );
  }

  Future<RazEntry> _decrypt(RazEntry encrypted) async {
    final key = _requireKey();
    return encrypted.copyWith(
      title: await VaultCrypto.decrypt(
        key,
        VaultCrypto.fromText(encrypted.title),
      ),
      secret: await VaultCrypto.decrypt(
        key,
        VaultCrypto.fromText(encrypted.secret),
      ),
      username: await VaultCrypto.decrypt(
        key,
        VaultCrypto.fromText(encrypted.username),
      ),
      url: await VaultCrypto.decrypt(key, VaultCrypto.fromText(encrypted.url)),
      notes: await VaultCrypto.decrypt(
        key,
        VaultCrypto.fromText(encrypted.notes),
      ),
      tags: await VaultCrypto.decrypt(
        key,
        VaultCrypto.fromText(encrypted.tags),
      ),
      totpSeed: await VaultCrypto.decrypt(
        key,
        VaultCrypto.fromText(encrypted.totpSeed),
      ),
    );
  }

  static bool _matches(RazEntry entry, String query) {
    final needle = query.toLowerCase();
    return entry.title.toLowerCase().contains(needle) ||
        entry.username.toLowerCase().contains(needle) ||
        entry.url.toLowerCase().contains(needle) ||
        entry.notes.toLowerCase().contains(needle) ||
        entry.tags.toLowerCase().split(',').contains(needle);
  }

  static String _cleanTags(String tags) {
    final split = <String>[];
    for (final candidate in tags.split(',')) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) continue;
      if (split.any(
        (existing) => existing.toLowerCase() == trimmed.toLowerCase(),
      )) {
        continue;
      }

      split.add(trimmed);
      if (split.length >= RazDefaults.maxTagsPerEntry) break;
    }

    final joined = split.join(',');
    return joined.length <= RazDefaults.maxFieldLength
        ? joined
        : joined.substring(0, RazDefaults.maxFieldLength);
  }

  static String _clean(String value, int maxLength) {
    final trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }

  static (TotpAlgorithm, int, int) _normalizeTotp(
    TotpAlgorithm algorithm,
    String seed,
    int? digits,
    int? period,
  ) {
    final hasSeed = seed.trim().isNotEmpty;
    if (algorithm == TotpAlgorithm.none && !hasSeed) {
      return (TotpAlgorithm.none, 0, 0);
    }

    final resolvedAlgorithm = algorithm == TotpAlgorithm.none
        ? TotpAlgorithm.sha1
        : algorithm;
    if (!hasSeed) {
      throw const RazException(
        'A TOTP seed is required — add the Base32 secret.',
      );
    }

    final resolvedDigits = digits ?? RazDefaults.defaultTotpDigits;
    final resolvedPeriod = period ?? RazDefaults.defaultTotpPeriodSeconds;
    if (resolvedDigits < RazDefaults.minTotpDigits ||
        resolvedDigits > RazDefaults.maxTotpDigits) {
      throw RazException(
        'TOTP digits must be between ${RazDefaults.minTotpDigits} and '
        '${RazDefaults.maxTotpDigits}.',
      );
    }

    if (resolvedPeriod < RazDefaults.minTotpPeriodSeconds ||
        resolvedPeriod > RazDefaults.maxTotpPeriodSeconds) {
      throw RazException(
        'TOTP period must be between ${RazDefaults.minTotpPeriodSeconds} and '
        '${RazDefaults.maxTotpPeriodSeconds} seconds.',
      );
    }

    return (resolvedAlgorithm, resolvedDigits, resolvedPeriod);
  }

  Future<void> _pushSnapshot() async {
    final key = _requireKey();
    final rows = await _store.listEntries();
    final plain = jsonEncode(
      rows.map(_toDto).map((dto) => dto.toJson()).toList(),
    );
    await _store.pushUndo(await VaultCrypto.encrypt(key, plain));
  }

  static RazEntryDto _toDto(RazEntry entry) => RazEntryDto(
    id: entry.id,
    title: entry.title,
    secret: entry.secret,
    username: entry.username,
    url: entry.url,
    notes: entry.notes,
    tags: entry.tags,
    totpSeed: entry.totpSeed,
    totpAlgorithm: entry.totpAlgorithm.code,
    totpDigits: entry.totpDigits,
    totpPeriodSeconds: entry.totpPeriodSeconds,
    expiresOn: entry.expiresOn?.toIso(),
    favorite: entry.favorite,
    createdAt: entry.createdAt.toUtc().toIso8601String(),
    updatedAt: entry.updatedAt.toUtc().toIso8601String(),
  );

  static RazEntry _fromDto(RazEntryDto dto) {
    if (dto.title.trim().isEmpty || dto.secret.trim().isEmpty) {
      throw const RazException('The undo snapshot is unreadable.');
    }

    return RazEntry(
      id: dto.id,
      title: dto.title,
      secret: dto.secret,
      username: dto.username,
      url: dto.url,
      notes: dto.notes,
      tags: dto.tags,
      totpSeed: dto.totpSeed,
      totpAlgorithm: TotpAlgorithm.fromCode(dto.totpAlgorithm),
      totpDigits: dto.totpDigits,
      totpPeriodSeconds: dto.totpPeriodSeconds,
      expiresOn: dto.expiresOn == null
          ? null
          : DateOnly.parseIso(dto.expiresOn!),
      favorite: dto.favorite,
      createdAt: DateTime.parse(dto.createdAt).toUtc(),
      updatedAt: DateTime.parse(dto.updatedAt).toUtc(),
    );
  }
}
