/// settings — see doc/settings.md and AGENTS.md
import 'package:flutter/material.dart';

import '../../core/exceptions.dart';
import 'setting_keys.dart';
import 'settings_store.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final SettingsStore _store;

  List<SettingsEntry> _entries = const [];
  final Map<String, String> _cache = <String, String>{};
  bool _loaded = false;
  bool _busy = false;
  String? _lastError;

  /// Every saved setting, ordered by key.
  List<SettingsEntry> get entries => _entries;

  /// True once the first load finished.
  bool get isLoaded => _loaded;

  /// True while a mutation is in flight.
  bool get isBusy => _busy;

  /// The last error message, or null. The UI shows it verbatim — guards already
  /// produce human-readable, secret-free text.
  String? get lastError => _lastError;

  /// Reads the cached value for [key] synchronously (null when unset).
  String? value(String key) => _cache[key];

  /// Reads a value, hitting the store when the cache has not been filled for [key].
  Future<String?> read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    final value = await _store.getValue(key);
    if (value != null) _cache[key] = value;
    return value;
  }

  /// Reloads every entry from the store.
  Future<void> load() async {
    _busy = true;
    notifyListeners();
    try {
      final entries = await _store.getAll();
      _entries = entries;
      _cache
        ..clear()
        ..addEntries(entries.map((entry) => MapEntry(entry.key, entry.value)));
      _loaded = true;
      _lastError = null;
    } on JameJamException catch (error) {
      _lastError = error.message;
    } catch (error) {
      _lastError = '$error';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Writes [key] = [value] and refreshes the cached view.
  ///
  /// Returns null on success or the human-readable refusal on failure.
  Future<String?> set(String key, String? value) async {
    _busy = true;
    notifyListeners();
    try {
      await _store.setValue(key, value);
      await load();
      return null;
    } on JameJamException catch (error) {
      _lastError = error.message;
      _busy = false;
      notifyListeners();
      return error.message;
    } catch (error) {
      _lastError = '$error';
      _busy = false;
      notifyListeners();
      return _lastError;
    }
  }

  /// Removes [key]. Returns true when it existed.
  Future<bool> remove(String key) async {
    final removed = await _store.remove(key);
    await load();
    return removed;
  }

  /// Removes every setting. Returns how many were removed.
  Future<int> clear() async {
    final count = await _store.clear();
    await load();
    return count;
  }

  // ── UI preferences (persisted as ordinary settings, so they survive restarts) ──

  /// Theme preference: `system`, `light`, or `dark`.
  ThemeMode get themeMode => switch (value(SettingKeys.appTheme)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      set(SettingKeys.appTheme, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });

  /// Locale preference: null means "follow the system".
  Locale? get locale => switch (value(SettingKeys.appLocale)) {
    'en' => const Locale('en'),
    'fa' => const Locale('fa'),
    _ => null,
  };

  Future<void> setLocale(Locale? locale) =>
      set(SettingKeys.appLocale, locale?.languageCode ?? 'system');
}
