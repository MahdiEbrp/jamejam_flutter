/// settings — see doc/settings.md and AGENTS.md
abstract final class SettingKeys {
  /// Default name used when no name is given to the greeter.
  static const String greeterDefaultName = 'greeter.defaultName';

  /// Default length for vault-generated passwords (Raz).
  static const String razDefaultLength = 'raz.length';

  /// Preferred default notebook for new Divan notes.
  static const String divanNotebook = 'divan.notebook';

  /// Default Soroush AI provider (e.g. `openai`, `anthropic`).
  static const String soroushProvider = 'soroush.provider';

  /// Default Soroush AI endpoint URL.
  static const String soroushEndpoint = 'soroush.endpoint';

  /// Default Soroush AI model identifier.
  static const String soroushModel = 'soroush.model';

  /// Default remote sync URL for Haft Khan.
  static const String syncUrl = 'haftkhan.syncUrl';

  /// Default remote sync URL for the Divan pad (two-device sync).
  static const String divanSyncUrl = 'divan.syncUrl';

  /// Sync endpoint for the Taqvim calendar.
  static const String taqvimSyncUrl = 'taqvim.syncUrl';

  /// Stable identity of this installation for sync (a GUID; generated on first sync).
  static const String syncDeviceId = 'sync.deviceId';

  /// Friendly name of this device shown in sync reports.
  static const String syncDeviceName = 'sync.deviceName';

  /// Default Anahita weather location (place name or `lat,lon`).
  static const String anahitaLocation = 'anahita.location';

  /// Default Anahita weather units (`metric` or `imperial`).
  static const String anahitaUnits = 'anahita.units';

  /// Base currency for the Ganjoor wallet (e.g. `EUR`).
  static const String ganjoorCurrency = 'ganjoor.currency';

  /// UI theme preference: `system`, `light`, or `dark`.
  static const String appTheme = 'app.theme';

  /// UI locale preference: `system`, `en`, or `fa`.
  static const String appLocale = 'app.locale';

  /// Every key this build owns, in the order the settings screen lists them.
  static const List<String> wellKnown = [
    greeterDefaultName,
    soroushProvider,
    soroushEndpoint,
    soroushModel,
    anahitaLocation,
    anahitaUnits,
    ganjoorCurrency,
    razDefaultLength,
    divanNotebook,
    syncUrl,
    divanSyncUrl,
    taqvimSyncUrl,
    syncDeviceName,
    appTheme,
    appLocale,
  ];
}
