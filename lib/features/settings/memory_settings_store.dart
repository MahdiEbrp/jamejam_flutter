/// settings — see doc/settings.md and AGENTS.md
import 'setting_guard.dart';
import 'settings_store.dart';

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore({SettingsOptions? options})
    : options = options ?? const SettingsOptions() {
    this.options.validate();
  }

  /// Validated limits in effect.
  final SettingsOptions options;

  final Map<String, SettingsEntry> _entries = <String, SettingsEntry>{};

  @override
  Future<String?> getValue(String key) async {
    SettingGuard.validateKey(key, options.maxKeyLength);
    return _entries[key]?.value;
  }

  @override
  Future<List<SettingsEntry>> getAll() async {
    final entries = _entries.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return List.unmodifiable(entries);
  }

  @override
  Future<void> setValue(String key, String? value) async {
    SettingGuard.validateKey(key, options.maxKeyLength);
    SettingGuard.ensureNotSecretKey(key, options.secretKeyNeedles);
    final safeValue = SettingGuard.validateValue(value, options.maxValueLength);
    _entries[key] = SettingsEntry(
      key: key,
      value: safeValue,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<bool> remove(String key) async {
    SettingGuard.validateKey(key, options.maxKeyLength);
    return _entries.remove(key) != null;
  }

  @override
  Future<int> clear() async {
    final count = _entries.length;
    _entries.clear();
    return count;
  }
}
