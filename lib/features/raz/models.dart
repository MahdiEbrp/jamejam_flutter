/// raz — see doc/raz.md and AGENTS.md
import '../../core/date_only.dart';
import 'raz_defaults.dart';

enum TotpAlgorithm {
  /// The entry carries no TOTP seed.
  none(0),

  /// HMAC-SHA1 — the authenticator-app default.
  sha1(1),

  /// HMAC-SHA256.
  sha256(2),

  /// HMAC-SHA512.
  sha512(3);

  const TotpAlgorithm(this.code);

  /// Numeric code, identical to the .NET enum (and the backup format).
  final int code;

  /// Parses the numeric form; unknown codes fall back to [none].
  static TotpAlgorithm fromCode(int code) => switch (code) {
    1 => TotpAlgorithm.sha1,
    2 => TotpAlgorithm.sha256,
    3 => TotpAlgorithm.sha512,
    _ => TotpAlgorithm.none,
  };
}

class RazEntry {
  const RazEntry({
    required this.title,
    required this.secret,
    required this.createdAt,
    required this.updatedAt,
    this.id = 0,
    this.username = '',
    this.url = '',
    this.notes = '',
    this.tags = '',
    this.totpSeed = '',
    this.totpAlgorithm = TotpAlgorithm.none,
    this.totpDigits = 0,
    this.totpPeriodSeconds = 0,
    this.expiresOn,
    this.favorite = false,
  });

  /// Assigned by the store.
  final int id;

  /// Human label (encrypted at rest).
  final String title;

  /// The password or key (encrypted at rest).
  final String secret;

  /// Login name (encrypted at rest).
  final String username;

  /// Where this is used (encrypted at rest).
  final String url;

  /// Free notes (encrypted at rest).
  final String notes;

  /// Comma-joined tags (encrypted at rest).
  final String tags;

  /// Base32 TOTP seed (encrypted at rest; empty = none).
  final String totpSeed;

  /// TOTP hash algorithm.
  final TotpAlgorithm totpAlgorithm;

  /// TOTP code length.
  final int totpDigits;

  /// TOTP time step.
  final int totpPeriodSeconds;

  /// Rotation deadline (plaintext for queryable reminders).
  final DateOnly? expiresOn;

  /// Pinned in listings (plaintext).
  final bool favorite;

  /// When the entry was created.
  final DateTime createdAt;

  /// When the entry was last changed.
  final DateTime updatedAt;

  /// A copy with the given fields replaced (the Dart stand-in for `entry with { … }`).
  RazEntry copyWith({
    int? id,
    String? title,
    String? secret,
    String? username,
    String? url,
    String? notes,
    String? tags,
    String? totpSeed,
    TotpAlgorithm? totpAlgorithm,
    int? totpDigits,
    int? totpPeriodSeconds,
    DateOnly? expiresOn,
    bool clearExpiresOn = false,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RazEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    secret: secret ?? this.secret,
    username: username ?? this.username,
    url: url ?? this.url,
    notes: notes ?? this.notes,
    tags: tags ?? this.tags,
    totpSeed: totpSeed ?? this.totpSeed,
    totpAlgorithm: totpAlgorithm ?? this.totpAlgorithm,
    totpDigits: totpDigits ?? this.totpDigits,
    totpPeriodSeconds: totpPeriodSeconds ?? this.totpPeriodSeconds,
    expiresOn: clearExpiresOn ? null : (expiresOn ?? this.expiresOn),
    favorite: favorite ?? this.favorite,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Tags split into individual labels (empty when the entry has none).
  List<String> get tagList =>
      tags.isEmpty ? const [] : tags.split(',').toList(growable: false);

  @override
  bool operator ==(Object other) =>
      other is RazEntry &&
      other.id == id &&
      other.title == title &&
      other.secret == secret &&
      other.username == username &&
      other.url == url &&
      other.notes == notes &&
      other.tags == tags &&
      other.totpSeed == totpSeed &&
      other.totpAlgorithm == totpAlgorithm &&
      other.totpDigits == totpDigits &&
      other.totpPeriodSeconds == totpPeriodSeconds &&
      other.expiresOn == expiresOn &&
      other.favorite == favorite &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    secret,
    username,
    url,
    notes,
    tags,
    totpSeed,
    totpAlgorithm,
    totpDigits,
    totpPeriodSeconds,
    expiresOn,
    favorite,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'RazEntry(#$id $title, ${tagList.length} tag(s), '
      'favorite: $favorite, totp: ${totpAlgorithm.name})';
}

class VaultFilter {
  const VaultFilter({
    this.tag,
    this.query,
    this.weakOnly = false,
    this.expiredOnly = false,
    this.favoritesOnly = false,
  });

  /// Only entries whose tags contain this (case-insensitive).
  final String? tag;

  /// Substring match over decrypted fields.
  final String? query;

  /// Only entries whose strength is at or below the weak threshold.
  final bool weakOnly;

  /// Only entries past their expiry date.
  final bool expiredOnly;

  /// Only favorites.
  final bool favoritesOnly;
}

class VaultAuditStats {
  const VaultAuditStats({
    required this.totalEntries,
    required this.weakCount,
    required this.reusedCount,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.oldCount,
    required this.averageSecretLength,
    required this.uniqueSecrets,
  });

  /// Entries in the vault.
  final int totalEntries;

  /// Entries at or below the weak threshold.
  final int weakCount;

  /// Entries sharing a secret with at least one other entry.
  final int reusedCount;

  /// Entries past their expiry date.
  final int expiredCount;

  /// Entries expiring within the configured window.
  final int expiringSoonCount;

  /// Entries not changed for longer than the rotation window.
  final int oldCount;

  /// Mean secret length (a number, never the secrets).
  final int averageSecretLength;

  /// Distinct secret values.
  final int uniqueSecrets;

  @override
  String toString() =>
      'VaultAuditStats($totalEntries entries, $weakCount weak, '
      '$expiredCount expired, $uniqueSecrets unique)';
}

class RazException implements Exception {
  const RazException(this.message);

  /// Human-friendly, user-facing text.
  final String message;

  @override
  String toString() => message;
}

class PasswordStrength {
  const PasswordStrength({
    required this.score,
    required this.entropyBits,
    required this.issues,
  });

  /// 0 very weak … 4 excellent.
  final int score;

  /// Estimated entropy after penalties.
  final int entropyBits;

  /// Human-readable weaknesses found (may be empty).
  final List<String> issues;

  /// Label for the score, for the UI and AI contexts.
  String get label => switch (score) {
    0 => 'very weak',
    1 => 'weak',
    2 => 'fair',
    3 => 'strong',
    _ => 'excellent',
  };

  @override
  String toString() => 'PasswordStrength($score — $label, $entropyBits bits)';
}

class PasswordPolicy {
  const PasswordPolicy({
    this.length = RazDefaults.defaultPasswordLength,
    this.lower = true,
    this.upper = true,
    this.digit = true,
    this.symbol = true,
    this.excludeAmbiguous = false,
  });

  /// Password length.
  final int length;

  /// Include a–z.
  final bool lower;

  /// Include A–Z.
  final bool upper;

  /// Include 0–9.
  final bool digit;

  /// Include printable symbols.
  final bool symbol;

  /// Drop look-alike characters (`Il1O0oQ|`).
  final bool excludeAmbiguous;

  /// Validates the policy, mirroring the .NET rails.
  void validate() {
    if (length < RazDefaults.minPasswordLength ||
        length > RazDefaults.maxPasswordLength) {
      throw RangeError.range(
        length,
        RazDefaults.minPasswordLength,
        RazDefaults.maxPasswordLength,
        'length',
        'Length must be between ${RazDefaults.minPasswordLength} and '
            '${RazDefaults.maxPasswordLength}.',
      );
    }

    if (!lower && !upper && !digit && !symbol) {
      throw RangeError('At least one character class must be enabled.');
    }
  }
}

class RazEntryDto {
  const RazEntryDto({
    required this.id,
    required this.title,
    required this.secret,
    required this.username,
    required this.url,
    required this.notes,
    required this.tags,
    required this.totpSeed,
    required this.totpAlgorithm,
    required this.totpDigits,
    required this.totpPeriodSeconds,
    required this.expiresOn,
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Entry id in the source vault.
  final int id;

  /// Ciphertext.
  final String title;

  /// Ciphertext.
  final String secret;

  /// Ciphertext.
  final String username;

  /// Ciphertext.
  final String url;

  /// Ciphertext.
  final String notes;

  /// Ciphertext.
  final String tags;

  /// Ciphertext.
  final String totpSeed;

  /// Algorithm code (0 none, 1 SHA-1, 2 SHA-256, 3 SHA-512).
  final int totpAlgorithm;

  /// Code length.
  final int totpDigits;

  /// Time step.
  final int totpPeriodSeconds;

  /// ISO date or null.
  final String? expiresOn;

  /// Pinned flag.
  final bool favorite;

  /// ISO-8601 timestamp.
  final String createdAt;

  /// ISO-8601 timestamp.
  final String updatedAt;

  /// Serializes to the .NET serializer's shape (PascalCase), so a bundle written here is
  /// readable by the original build and vice versa.
  Map<String, Object?> toJson() => {
    'Id': id,
    'Title': title,
    'Secret': secret,
    'Username': username,
    'Url': url,
    'Notes': notes,
    'Tags': tags,
    'TotpSeed': totpSeed,
    'TotpAlgorithm': totpAlgorithm,
    'TotpDigits': totpDigits,
    'TotpPeriodSeconds': totpPeriodSeconds,
    'ExpiresOn': expiresOn,
    'Favorite': favorite,
    'CreatedAt': createdAt,
    'UpdatedAt': updatedAt,
  };

  /// Reads either build's field casing.
  factory RazEntryDto.fromJson(Map<String, Object?> json) {
    Object? field(String name) =>
        json[name] ?? json[name[0].toLowerCase() + name.substring(1)];

    return RazEntryDto(
      id: (field('Id') as num?)?.toInt() ?? 0,
      title: '${field('Title') ?? ''}',
      secret: '${field('Secret') ?? ''}',
      username: '${field('Username') ?? ''}',
      url: '${field('Url') ?? ''}',
      notes: '${field('Notes') ?? ''}',
      tags: '${field('Tags') ?? ''}',
      totpSeed: '${field('TotpSeed') ?? ''}',
      totpAlgorithm: (field('TotpAlgorithm') as num?)?.toInt() ?? 0,
      totpDigits: (field('TotpDigits') as num?)?.toInt() ?? 0,
      totpPeriodSeconds: (field('TotpPeriodSeconds') as num?)?.toInt() ?? 0,
      expiresOn: field('ExpiresOn') as String?,
      favorite: field('Favorite') as bool? ?? false,
      createdAt: '${field('CreatedAt') ?? ''}',
      updatedAt: '${field('UpdatedAt') ?? ''}',
    );
  }
}

class VaultBackupFile {
  const VaultBackupFile({
    required this.version,
    required this.salt,
    required this.iterations,
    required this.keyCheck,
    required this.payload,
  });

  /// Backup format version.
  final int version;

  /// Base64 KDF salt of the source vault.
  final String salt;

  /// KDF iteration count of the source vault.
  final int iterations;

  /// Base64 key-check payload of the source vault.
  final String keyCheck;

  /// Base64 AES-GCM payload: a JSON list of [RazEntryDto].
  final String payload;

  /// Serializes to the .NET envelope shape so either build can read the file.
  Map<String, Object?> toJson() => {
    'Version': version,
    'Salt': salt,
    'Iterations': iterations,
    'KeyCheck': keyCheck,
    'Payload': payload,
  };

  /// Reads the envelope, tolerating either build's field casing.
  factory VaultBackupFile.fromJson(Map<String, Object?> json) {
    Object? field(String name) =>
        json[name] ?? json[name[0].toLowerCase() + name.substring(1)];

    return VaultBackupFile(
      version: (field('Version') as num?)?.toInt() ?? 0,
      salt: '${field('Salt') ?? ''}',
      iterations: (field('Iterations') as num?)?.toInt() ?? 0,
      keyCheck: '${field('KeyCheck') ?? ''}',
      payload: '${field('Payload') ?? ''}',
    );
  }
}
