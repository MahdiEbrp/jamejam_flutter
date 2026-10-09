/// settings — see doc/settings.md and AGENTS.md
class SettingsEntry {
  const SettingsEntry({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  /// Unique setting key.
  final String key;

  /// Stored value (never null — null is stored as empty).
  final String value;

  /// When the value was last written (UTC).
  final DateTime updatedAt;

  @override
  String toString() => 'SettingsEntry($key = $value @ $updatedAt)';
}

abstract interface class SettingsStore {
  /// Gets the value stored under [key], or null when absent.
  Future<String?> getValue(String key);

  /// Gets all entries ordered by key.
  Future<List<SettingsEntry>> getAll();

  /// Creates or overwrites the value under [key]. Null is stored as empty.
  ///
  /// Secret-looking keys are refused by design — the database is plaintext.
  Future<void> setValue(String key, String? value);

  /// Removes [key]. Returns true when it existed.
  Future<bool> remove(String key);

  /// Removes every setting. Returns the number of removed entries.
  Future<int> clear();
}
