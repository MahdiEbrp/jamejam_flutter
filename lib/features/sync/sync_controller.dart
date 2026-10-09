/// sync — see doc/sync.md and AGENTS.md
library;

import 'package:flutter/foundation.dart';

import '../../core/uids.dart';
import '../settings/setting_keys.dart';
import '../settings/settings_controller.dart';
import 'sync_client.dart';
import 'sync_models.dart';
import 'sync_options.dart';
import 'sync_targets.dart';

typedef SyncClientFactory = SyncClient Function(String url, {String? token});

class SyncController extends ChangeNotifier {
  SyncController({
    required List<SyncTarget> targets,
    required SyncClientFactory clientFactory,
    required String Function(String key) environment,
    SettingsController? settings,
  }) : _targets = List.unmodifiable(targets),
       _clientFactory = clientFactory,
       _environment = environment,
       _settings = settings;

  final List<SyncTarget> _targets;
  final SyncClientFactory _clientFactory;
  final String Function(String key) _environment;
  final SettingsController? _settings;

  bool _busy = false;
  String? _message;
  String? _error;
  String _deviceId = '';
  String _deviceName = '';
  final Map<String, SyncOutcome> _outcomes = {};
  final Map<String, String> _urls = {};

  /// The services this build can sync, in display order.
  List<SyncTarget> get targets => _targets;

  /// True while a run is in flight.
  bool get busy => _busy;

  /// The last successful summary line, if any.
  String? get message => _message;

  /// The last failure message, or null when the last action succeeded.
  String? get error => _error;

  /// This device's stable identity. Empty until the first run mints it — the CLI generated
  /// one when it needed one, and nothing is written to the settings store before then.
  String get deviceId => _deviceId;

  /// This device's friendly name, shown in the other device's report.
  String get deviceName =>
      _deviceName.isEmpty ? _defaultDeviceName() : _deviceName;

  /// True once this device has an identity on disk.
  bool get hasIdentity => _deviceId.isNotEmpty;

  /// True when a bearer token is configured. The token itself is never exposed.
  bool get hasToken => _token() != null;

  /// The URL from `JAMEJAM_SYNC_URL`, when the environment provides one.
  ///
  /// The environment wins over every saved URL — the same precedence the CLI used, so a
  /// launch-time override still works in the app.
  String get environmentUrl => _environment('JAMEJAM_SYNC_URL').trim();

  /// True when the environment is overriding the per-service URLs.
  bool get environmentOverrides => environmentUrl.isNotEmpty;

  /// The outcome of the last run for a service, or null when it has not run yet.
  SyncOutcome? outcomeFor(String id) => _outcomes[id];

  /// The URL saved for [id], or an empty string when none is (the setting value).
  String savedUrlFor(String id) => (_urls[id] ?? '').trim();

  /// The URL a run for [id] would use, following the CLI's precedence exactly:
  /// the typed draft (the `--url` flag) → `JAMEJAM_SYNC_URL` → the stored setting.
  ///
  /// The card seeds its field from this, so an untouched field and the stored setting agree,
  /// and the environment still wins over anything saved.
  String effectiveUrlFor(String id, {String? draft}) {
    final typed = (draft ?? '').trim();
    if (typed.isNotEmpty) return typed;
    final environment = environmentUrl;
    if (environment.isNotEmpty) return environment;
    return savedUrlFor(id);
  }

  /// Reads the device identity from settings, generating it on first run.
  ///
  /// The identity is what stops two devices from overwriting each other's envelope: the
  /// engine records who sealed the remote document and reports it when a push is refused.
  Future<void> load() async {
    final settings = _settings;
    if (settings == null) {
      _notify();
      return;
    }

    _deviceId = ((await settings.read(SettingKeys.syncDeviceId)) ?? '').trim();
    _deviceName = ((await settings.read(SettingKeys.syncDeviceName)) ?? '')
        .trim();

    for (final target in _targets) {
      _urls[target.id] = (await settings.read(target.settingKey)) ?? '';
    }
    _notify();
  }

  /// Mints and stores this device's identity if it does not exist yet.
  ///
  /// The identity is what stops two devices from overwriting each other's envelope: the
  /// engine records who sealed the remote document and reports it when a push is refused.
  Future<void> _ensureIdentity() async {
    if (_deviceId.isEmpty) {
      _deviceId = await _deviceSetting(SettingKeys.syncDeviceId, Uids.newUid);
    }
    if (_deviceName.isEmpty) {
      _deviceName = await _deviceSetting(
        SettingKeys.syncDeviceName,
        _defaultDeviceName,
      );
    }
  }

  /// Saves the URL typed into a service's card.
  ///
  /// An empty value clears the saved URL (the environment, if present, is unaffected).
  /// The endpoint is validated before it is stored, so a saved URL can never fail later.
  Future<void> saveUrl(String id, String url) async {
    _error = null;
    _message = null;
    final target = _target(id);
    if (target == null) {
      _fail("Unknown sync service '$id'.");
      return;
    }

    final trimmed = url.trim();
    try {
      if (trimmed.isNotEmpty) {
        SyncOptions(endpoint: trimmed, bearerToken: _token()).validate();
      }
    } on SyncException catch (failure) {
      _fail(failure.message);
      return;
    }

    _urls[id] = trimmed;
    final settings = _settings;
    if (settings != null) {
      await settings.set(target.settingKey, trimmed.isEmpty ? null : trimmed);
    }
    _message = trimmed.isEmpty
        ? 'Saved URL cleared for ${target.service}.'
        : 'Sync URL saved: $trimmed';
    _notify();
  }

  /// Renames this device. The name travels in the envelope and appears in the other device's
  /// push-refusal report.
  Future<void> saveDeviceName(String name) async {
    _error = null;
    _message = null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _fail('A device name must not be empty.');
      return;
    }
    if (trimmed.length > _maxDeviceNameLength) {
      _fail(
        'The device name must be at most $_maxDeviceNameLength characters.',
      );
      return;
    }

    _deviceName = trimmed;
    await _settings?.set(SettingKeys.syncDeviceName, trimmed);
    _message = 'This device is now called $trimmed.';
    _notify();
  }

  /// Runs one exchange for `id`.
  ///
  /// [SyncMode.push] is refused while the remote differs unless [force] is true — the CLI's
  /// `--force`. The refusal is a normal error: the screen offers the confirmation and calls
  /// back with [force].
  Future<SyncOutcome?> run(
    String id, {
    SyncMode mode = SyncMode.merge,
    bool force = false,
    String? url,
  }) async {
    _error = null;
    _message = null;
    final target = _target(id);
    if (target == null) {
      _fail("Unknown sync service '$id'.");
      return null;
    }

    final resolved = effectiveUrlFor(id, draft: url);
    if (resolved.isEmpty) {
      _fail(
        'No sync URL. Set JAMEJAM_SYNC_URL, or save it once as ${target.settingKey}.',
      );
      return null;
    }

    final options = SyncOptions(endpoint: resolved, bearerToken: _token());
    try {
      options.validate();
    } on SyncException catch (failure) {
      _fail(failure.message);
      return null;
    }

    _busy = true;
    _notify();
    try {
      await _ensureIdentity();
      final outcome = await target.runner.run(
        _clientFactory(resolved, token: options.bearerToken),
        mode: mode,
        force: force,
        deviceId: _deviceId,
        deviceName: _deviceName,
      );
      _outcomes[id] = outcome;
      _message = outcome.summary;
      return outcome;
    } on SyncException catch (failure) {
      _fail(failure.message);
      return null;
    } catch (failure) {
      _fail('$failure');
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Runs one exchange with the mode spelled as text — the CLI's `--mode` surface.
  ///
  /// The window offers the three modes in a dropdown, so this exists for callers that mirror
  /// the command line (and for the parity suite): an unknown word is refused the same way.
  Future<SyncOutcome?> runWithModeText(
    String id,
    String modeText, {
    bool force = false,
    String? url,
  }) async {
    final SyncMode mode;
    try {
      mode = SyncController.modeFromText(modeText);
    } on SyncException catch (failure) {
      _fail(failure.message);
      return null;
    }
    return run(id, mode: mode, force: force, url: url);
  }

  /// Parses `sync`/`merge`/`pull`/`push`, case-insensitively.
  ///
  /// Throws [SyncException] for anything else — the CLI's
  /// `Unknown sync mode 'teleport'. Use merge (default), pull, or push.`
  static SyncMode modeFromText(String? text) {
    switch ((text ?? '').trim().toLowerCase()) {
      case '':
      case 'sync':
      case 'merge':
        return SyncMode.merge;
      case 'pull':
        return SyncMode.pull;
      case 'push':
        return SyncMode.push;
      default:
        throw SyncException(
          "Unknown sync mode '${text?.trim()}'. Use merge (default), pull, or push.",
        );
    }
  }

  /// Clears the last summary and error.
  void clearFeedback() {
    _message = null;
    _error = null;
    _notify();
  }

  // ── Internals ──

  static const int _maxDeviceNameLength = 60;

  SyncTarget? _target(String id) {
    for (final target in _targets) {
      if (target.id == id) return target;
    }
    return null;
  }

  String? _token() {
    final token = _environment('JAMEJAM_SYNC_TOKEN').trim();
    return token.isEmpty ? null : token;
  }

  /// The default device name: the machine's own name when the platform exposes it, else the
  /// toolbox's. The .NET used `Environment.MachineName` with a `JameJam` fallback.
  String _defaultDeviceName() {
    final host = _environment('HOSTNAME').trim();
    return host.isEmpty ? 'JameJam' : host;
  }

  /// Reads a device setting, storing a generated default on first use.
  Future<String> _deviceSetting(String key, String Function() fallback) async {
    final settings = _settings;
    if (settings == null) return fallback();
    final existing = (await settings.read(key))?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final value = fallback();
    await settings.set(key, value);
    return value;
  }

  void _fail(String message) {
    _error = message;
    _busy = false;
    _notify();
  }

  void _notify() => notifyListeners();
}
