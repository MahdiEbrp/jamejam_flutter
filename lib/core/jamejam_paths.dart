import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves where each service keeps its SQLite file.
///
/// Port of the CLI composition root's path policy: **one database per service**, all inside
/// one toolbox directory, each overridable by the same environment variables the .NET
/// version honours (`JAMEJAM_SETTINGS_DB`, `JAMEJAM_HAFTKHAN_DB`, …). Desktop defaults to
/// `~/.jamejam`; mobile uses the app support directory, which the OS sandbox already
/// isolates per app.
abstract final class JameJamPaths {
  static String? _rootOverride;
  static String? _resolvedRoot;

  /// Directory name segment for the toolbox root.
  static const String folderName = '.jamejam';

  /// Points the toolbox at a different root — used by tests and by `--data-dir`.
  @visibleForTesting
  static void overrideRoot(String? root) {
    _rootOverride = root;
    _resolvedRoot = null;
  }

  /// The toolbox root directory, creating it when missing.
  static Future<String> root() async {
    final override = _rootOverride;
    if (override != null) return override;

    final cached = _resolvedRoot;
    if (cached != null) return cached;

    final resolved = await _resolveRoot();
    _resolvedRoot = resolved;
    return resolved;
  }

  static Future<String> _resolveRoot() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final support = await getApplicationSupportDirectory();
      return support.path;
    }

    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return p.join(home, folderName);
  }

  /// Absolute path of one service's database file.
  ///
  /// [service] is the folder-style name (`settings`, `haftkhan`, `ganjoor`, `raz`,
  /// `divan`, `taqvim`). [envVar] matches the .NET override, e.g. `JAMEJAM_SETTINGS_DB`.
  static Future<String> database({
    required String service,
    required String envVar,
  }) async {
    final fromEnvironment = Platform.environment[envVar];
    if (fromEnvironment != null && fromEnvironment.trim().isNotEmpty) {
      return fromEnvironment.trim();
    }
    return p.join(await root(), '$service.db');
  }

  /// Ensures the toolbox root exists.
  static Future<void> ensureRoot() async {
    final dir = Directory(await root());
    if (!dir.existsSync()) await dir.create(recursive: true);
  }
}

/// The database paths the toolbox uses, resolved once and injected everywhere.
class JameJamDatabases {
  const JameJamDatabases({
    required this.settings,
    required this.haftkhan,
    required this.ganjoor,
    required this.raz,
    required this.divan,
    required this.taqvim,
  });

  final String settings;
  final String haftkhan;
  final String ganjoor;
  final String raz;
  final String divan;
  final String taqvim;

  /// Resolves every path, honouring the `JAMEJAM_*_DB` environment overrides.
  static Future<JameJamDatabases> resolve() async {
    return JameJamDatabases(
      settings: await JameJamPaths.database(
        service: 'settings',
        envVar: 'JAMEJAM_SETTINGS_DB',
      ),
      haftkhan: await JameJamPaths.database(
        service: 'haftkhan',
        envVar: 'JAMEJAM_HAFTKHAN_DB',
      ),
      ganjoor: await JameJamPaths.database(
        service: 'ganjoor',
        envVar: 'JAMEJAM_GANJOOR_DB',
      ),
      raz: await JameJamPaths.database(
        service: 'raz',
        envVar: 'JAMEJAM_RAZ_DB',
      ),
      divan: await JameJamPaths.database(
        service: 'divan',
        envVar: 'JAMEJAM_DIVAN_DB',
      ),
      taqvim: await JameJamPaths.database(
        service: 'taqvim',
        envVar: 'JAMEJAM_TAQVIM_DB',
      ),
    );
  }
}
