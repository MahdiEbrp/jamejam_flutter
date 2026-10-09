/// raz — see doc/raz.md and AGENTS.md
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/date_only.dart';
import '../../core/secret_store.dart';
import '../settings/settings_controller.dart';
import '../soroush/ai_funnel.dart';
import 'models.dart';
import 'raz_defaults.dart';
import 'raz_options.dart';
import 'security_assistant.dart';
import 'totp.dart';
import 'vault_service.dart';

class VaultController extends ChangeNotifier {
  /// Wires the service, the settings store, the keychain, and the AI funnel.
  VaultController({
    required VaultService service,
    required SettingsController settings,
    required SecretStore secrets,
    required AiFunnel funnel,
    SecurityAssistant? assistant,
    DateTime Function()? clock,
    String Function(String key)? environment,
    Duration? autoLockCheckInterval,
  }) : _service = service,
       _settings = settings,
       _secrets = secrets,
       _funnel = funnel,
       _assistant = assistant ?? SecurityAssistant(service.options),
       _clock = clock ?? DateTime.now,
       _environment = environment ?? ((_) => ''),
       _autoLockCheckInterval =
           autoLockCheckInterval ?? const Duration(seconds: 15);

  final VaultService _service;
  final SettingsController _settings;
  final SecretStore _secrets;
  final AiFunnel _funnel;
  final SecurityAssistant _assistant;
  final DateTime Function() _clock;
  final String Function(String key) _environment;
  final Duration _autoLockCheckInterval;

  List<RazEntry> _entries = const [];
  VaultAuditStats? _stats;
  String _search = '';
  bool _favoritesOnly = false;
  bool _weakOnly = false;
  bool _expiredOnly = false;
  String? _tagFilter;
  String? _error;
  String? _aiAnswer;
  bool _busy = false;
  bool _initialised = false;
  String? _revealedSecret;
  ({String code, int secondsRemaining})? _totp;
  int? _totpEntryId;
  DateTime? _lastActivity;
  Timer? _autoLockTimer;
  bool _disposed = false;

  /// Entries matching the current filters.
  List<RazEntry> get entries => _entries;

  /// The last computed aggregate audit, or null before the first call.
  VaultAuditStats? get stats => _stats;

  /// Current search text.
  String get search => _search;

  /// True when only favorites are listed.
  bool get favoritesOnly => _favoritesOnly;

  /// True when only weak secrets are listed.
  bool get weakOnly => _weakOnly;

  /// True when only expired entries are listed.
  bool get expiredOnly => _expiredOnly;

  /// The tag currently filtered on, if any.
  String? get tagFilter => _tagFilter;

  /// The last failure, rendered by the page.
  String? get error => _error;

  /// The last AI answer (audit or question), rendered by the page.
  String? get aiAnswer => _aiAnswer;

  /// True while a call is in flight.
  bool get busy => _busy;

  /// True once the vault has been opened (or created) this session.
  bool get isUnlocked => _service.isUnlocked;

  /// True when the store already holds vault metadata (the unlock screen shows "create").
  bool get isInitialized => _initialised;

  /// True when the screen is open but the vault is locked.
  bool get isLocked => _initialised && !_service.isUnlocked;

  /// The secret revealed for one entry, if the user asked to see it.
  String? get revealedSecret => _revealedSecret;

  /// The live TOTP code and window for the selected entry, if it has a seed.
  ({String code, int secondsRemaining})? get totp => _totp;

  /// The entry the current TOTP belongs to.
  int? get totpEntryId => _totpEntryId;

  /// The validated options in effect.
  RazOptions get options => _service.options;

  /// How many idle minutes pass before the vault locks itself (0 = never).
  int get autoLockMinutes => _service.options.autoLockMinutes;

  /// True when a stored passphrase could unlock the vault without typing one.
  Future<bool> get hasStoredPassphrase async =>
      (await _storedPassphrase()) != null;

  /// Reads the vault metadata so the page knows whether to offer "create" or "unlock".
  Future<void> initialise() async {
    _initialised = await _service.isInitialized;
    _startAutoLockTimer();
    _notify();
  }

  /// Creates the vault, then shows it.
  Future<void> createVault(String passphrase) => _guard(() async {
    await _service.init(passphrase);
    _initialised = true;
    await _reload();
    _touch();
  });

  /// Unlocks the vault.
  Future<void> unlock(String passphrase) => _guard(() async {
    await _service.unlock(passphrase);
    await _reload();
    _touch();
  });

  /// Unlocks with the passphrase from the environment, the keychain, or nothing.
  ///
  /// Returns false when no source has one, so the page can show the unlock form.
  Future<bool> unlockWithStoredPassphrase() async {
    final passphrase = await _storedPassphrase();
    if (passphrase == null) return false;

    await unlock(passphrase);
    return _service.isUnlocked;
  }

  /// Locks the vault and clears everything derived from it.
  void lock() {
    _service.lock();
    _entries = const [];
    _stats = null;
    _aiAnswer = null;
    _revealedSecret = null;
    _clearTotp();
    _notify();
  }

  /// Records user activity so the auto-lock timer starts over.
  void touch() => _touch();

  /// Dismisses the coach's last answer.
  void clearAiAnswer() {
    _aiAnswer = null;
    _notify();
  }

  /// Re-reads the entry list under the current filters.
  Future<void> refresh() => _guard(_reload);

  /// Applies a search string.
  Future<void> setSearch(String value) {
    _search = value;
    return _guard(_reload);
  }

  /// Toggles the favorites filter.
  Future<void> toggleFavorites() {
    _favoritesOnly = !_favoritesOnly;
    return _guard(_reload);
  }

  /// Toggles the weak-secrets filter.
  Future<void> toggleWeakOnly() {
    _weakOnly = !_weakOnly;
    return _guard(_reload);
  }

  /// Toggles the expired filter.
  Future<void> toggleExpired() {
    _expiredOnly = !_expiredOnly;
    return _guard(_reload);
  }

  /// Filters by one tag (or clears it when [tag] is null).
  Future<void> setTagFilter(String? tag) {
    _tagFilter = tag;
    return _guard(_reload);
  }

  /// Clears every filter.
  Future<void> clearFilters() {
    _search = '';
    _favoritesOnly = false;
    _weakOnly = false;
    _expiredOnly = false;
    _tagFilter = null;
    return _guard(_reload);
  }

  /// Adds an entry.
  Future<void> addEntry({
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
  }) => _guard(() async {
    await _service.addEntry(
      title: title,
      secret: secret,
      username: username,
      url: url,
      notes: notes,
      tags: tags,
      totpSeed: totpSeed,
      totpAlgorithm: totpAlgorithm,
      totpDigits: totpDigits,
      totpPeriodSeconds: totpPeriodSeconds,
      expiresOn: expiresOn,
      favorite: favorite,
    );
    await _reload();
    _touch();
  });

  /// Updates an entry in place.
  Future<void> updateEntry(RazEntry entry) => _guard(() async {
    await _service.updateEntry(entry.id, entry);
    await _reload();
    _touch();
  });

  /// Deletes an entry.
  Future<void> deleteEntry(int id) => _guard(() async {
    await _service.deleteEntry(id);
    await _reload();
    _revealedSecret = null;
    _clearTotp();
  });

  /// Restores the most recent undo snapshot. Returns false when there is none.
  Future<bool> undo() async {
    var restored = false;
    await _guard(() async {
      restored = await _service.undo();
      await _reload();
    });
    return restored;
  }

  /// Generates a password under the vault's default policy.
  String generate([PasswordPolicy? policy]) => _service.generate(policy);

  /// Reveals one entry's secret (or hides it again when [id] is null).
  void reveal(int? id) {
    if (id == null) {
      _revealedSecret = null;
      _notify();
      return;
    }

    for (final entry in _entries) {
      if (entry.id == id) {
        _revealedSecret = entry.secret;
        break;
      }
    }

    _notify();
  }

  /// Refreshes the live TOTP code for an entry.
  Future<void> refreshTotp(int id) => _guard(() async {
    final entry = await _service.findEntry(id);
    if (entry == null) {
      _clearTotp();
      return;
    }

    final code = await Totp.codeFor(entry, _clock().toUtc());
    _totp = code == null
        ? null
        : (
            code: code,
            secondsRemaining: Totp.secondsRemaining(
              _clock().toUtc(),
              periodSeconds: entry.totpPeriodSeconds,
            ),
          );
    _totpEntryId = code == null ? null : id;
  });

  /// Computes the aggregate audit.
  Future<VaultAuditStats?> audit() async {
    VaultAuditStats? stats;
    await _guard(() async {
      stats = await _service.audit();
      _stats = stats;
    });
    return stats;
  }

  /// Entries expiring within [days] (default: the configured window).
  Future<List<RazEntry>> expiringWithin([int? days]) =>
      _service.expiringWithin(days);

  /// Exports the encrypted backup bundle.
  Future<String> exportBackup() => _service.exportJson();

  /// Imports an encrypted backup bundle; returns how many entries were imported.
  Future<int> importBackup(String bundle) async {
    var imported = 0;
    await _guard(() async {
      imported = await _service.importJson(bundle);
      await _reload();
    });
    return imported;
  }

  /// Asks the security coach about the aggregate audit.
  ///
  /// The prompt carries counts only — no titles, urls, usernames, notes, seeds, or secrets.
  Future<String> aiAudit() => _ask(null);

  /// Asks the security coach a question, grounded in the aggregate audit.
  Future<String> ask(String question) => _ask(question.trim());

  Future<String> _ask(String? question) async {
    final stats = await audit();
    if (stats == null) return '';

    if (!await _funnel.hasUsableKey()) {
      throw const RazException(
        'Add an API key in Settings → Soroush before asking the coach.',
      );
    }

    await _guard(() async {
      final prompt = question == null || question.isEmpty
          ? _assistant.buildAuditPrompt(stats)
          : _assistant.buildAskPrompt(question, stats);
      _aiAnswer = await _funnel.completeText(prompt);
    });

    return _aiAnswer ?? '';
  }

  /// Where the passphrase comes from: the environment first (CI and power users),
  /// then the keychain.
  Future<String?> _storedPassphrase() async {
    final fromEnvironment = _environment('JAMEJAM_RAZ_PASSPHRASE').trim();
    if (fromEnvironment.isNotEmpty) return fromEnvironment;

    final stored = (await _secrets.read(
      RazDefaults.passphraseSettingKey,
    ))?.trim();
    if (stored != null && stored.isNotEmpty) return stored;

    // A passphrase typed into the unlock screen and remembered for this install. Forget
    // writes an empty string there, and an empty string is not a passphrase.
    final typed = (await _settings.read(
      RazDefaults.passphraseSettingKey,
    ))?.trim();
    return typed == null || typed.isEmpty ? null : typed;
  }

  /// Remembers a passphrase in the keychain, so the next launch does not ask.
  Future<void> rememberPassphrase(String passphrase) =>
      _secrets.write(RazDefaults.passphraseSettingKey, passphrase);

  /// Forgets the remembered passphrase.
  Future<void> forgetPassphrase() async {
    await _secrets.delete(RazDefaults.passphraseSettingKey);
    await _settings.set(RazDefaults.passphraseSettingKey, '');
    _notify();
  }

  /// Reloads the list with the current filters.
  Future<void> _reload() async {
    if (!_service.isUnlocked) {
      _entries = const [];
      _notify();
      return;
    }

    _entries = await _service.listEntries(
      VaultFilter(
        tag: _tagFilter,
        query: _search.trim().isEmpty ? null : _search.trim(),
        weakOnly: _weakOnly,
        expiredOnly: _expiredOnly,
        favoritesOnly: _favoritesOnly,
      ),
    );
    _notify();
  }

  Future<void> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
    } on RazException catch (failure) {
      _error = failure.message;
    } on VaultFailure catch (failure) {
      _error = failure.message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// The idle timer: once the window passes without activity, the key is dropped.
  void _startAutoLockTimer() {
    // Zero minutes means "never", and a ticker that can never fire is just a wake-up.
    if (_service.options.autoLockMinutes <= 0) return;

    _autoLockTimer ??= Timer.periodic(_autoLockCheckInterval, (_) {
      final minutes = _service.options.autoLockMinutes;
      if (minutes <= 0 || !_service.isUnlocked || _lastActivity == null) return;

      final idle = _clock().difference(_lastActivity!);
      if (idle.inMinutes >= minutes) lock();
    });
  }

  void _touch() {
    _lastActivity = _clock();
    _startAutoLockTimer();
  }

  void _clearTotp() {
    _totp = null;
    _totpEntryId = null;
  }

  /// Notifies listeners unless this controller is already gone.
  ///
  /// A request that was in flight when the screen closed would otherwise call
  /// `notifyListeners` on a disposed notifier — the same dispose-crash class the settings
  /// screen hit.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
    _service.lock();
    super.dispose();
  }
}

class VaultFailure implements Exception {
  const VaultFailure(this.message);

  /// Human-friendly detail.
  final String message;

  @override
  String toString() => message;
}
