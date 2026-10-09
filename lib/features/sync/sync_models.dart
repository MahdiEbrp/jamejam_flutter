/// sync — see doc/sync.md and AGENTS.md
library;

enum SyncMode {
  /// Pull remote, merge into local, push the merged result — both sides converge.
  merge(0, 'merge'),

  /// Pull remote and merge into local only (never touches the remote).
  pull(1, 'pull'),

  /// Replace the remote with the local state (requires `force` when the remote is non-empty).
  push(2, 'push');

  const SyncMode(this.code, this.name);

  /// Stable integer used by the settings/CLI surface.
  final int code;

  /// Canonical lowercase name, as typed on the command line.
  final String name;

  /// Parses a mode name; null or unknown text falls back to [SyncMode.merge].
  static SyncMode parse(String? text) {
    final needle = (text ?? '').trim().toLowerCase();
    return values.firstWhere(
      (mode) => mode.name == needle,
      orElse: () => SyncMode.merge,
    );
  }
}

class SyncReport {
  const SyncReport({
    required this.mode,
    required this.pulled,
    required this.pushed,
    required this.total,
  });

  /// The mode that ran.
  final SyncMode mode;

  /// Tasks applied from the remote (added or updated by last-write-wins).
  final int pulled;

  /// Tasks uploaded to the remote (0 outside merge/push modes).
  final int pushed;

  /// Total local tasks after the sync.
  final int total;

  /// Human-friendly summary line (culture-invariant).
  String describe() {
    switch (mode) {
      case SyncMode.pull:
        return 'Pulled $pulled task(s) — $total local task(s) now.';
      case SyncMode.push:
        return 'Pushed $pushed task(s) — remote replaced.';
      case SyncMode.merge:
        return 'Merged: pulled $pulled, pushed $pushed — $total local task(s) now.';
    }
  }

  @override
  String toString() => describe();
}

class SyncException implements Exception {
  const SyncException(this.message, {this.statusCode});

  /// Safe, redacted description of the failure.
  final String message;

  /// HTTP status code from the remote, when applicable.
  final int? statusCode;

  @override
  String toString() => 'SyncException: $message';
}
