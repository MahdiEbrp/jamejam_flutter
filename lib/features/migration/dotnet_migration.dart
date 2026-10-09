/// migration — see doc/migration.md and AGENTS.md
library;

import 'dart:convert';

enum DotnetDocumentKind {
  /// A Haft Khan backup (`haftkhan export tasks.json`).
  haftKhanBackup('Haft Khan backup'),

  /// A Ganjoor wallet backup (`ganjoor export wallet.json`).
  ganjoorBackup('Ganjoor wallet backup'),

  /// A Raz vault bundle (`raz export vault.json`).
  razBackup('Raz vault backup'),

  /// A calendar document (`taqvim export calendar.ics`).
  taqvimCalendar('Taqvim calendar (.ics)'),

  /// A document whose shape this app does not recognise.
  unknown('Unrecognised document');

  const DotnetDocumentKind(this.label);

  /// A short English name for the kind; the screen localises what it shows.
  final String label;
}

enum DotnetDocumentProblem {
  /// The text is neither JSON nor an `.ics`.
  notJson,

  /// The JSON parsed but no known document has this shape.
  notADocument,
}

class DotnetDocument {
  /// Creates a description of one document.
  const DotnetDocument({
    required this.kind,
    this.version,
    this.counts = const {},
    this.problem,
  });

  /// The recognised kind.
  final DotnetDocumentKind kind;

  /// Schema version the document declares, when it declares one.
  final int? version;

  /// How many of each record the document carries, for the preview line.
  final Map<String, int> counts;

  /// Why the document was rejected, when it was.
  final DotnetDocumentProblem? problem;

  /// True when the document can be imported.
  bool get isImportable =>
      kind != DotnetDocumentKind.unknown && problem == null;
}

abstract final class DotnetMigration {
  /// Reads [text] far enough to name what it is.
  ///
  /// Detection is by shape, not by file name — the user pastes a document, and the answer has
  /// to come from the document. JSON is parsed (a parse failure is reported, not guessed at);
  /// an `.ics` is recognised by its `BEGIN:VCALENDAR` line.
  static DotnetDocument inspect(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const DotnetDocument(kind: DotnetDocumentKind.unknown);
    }
    if (trimmed.toUpperCase().startsWith('BEGIN:VCALENDAR')) {
      return const DotnetDocument(
        kind: DotnetDocumentKind.taqvimCalendar,
        counts: {'events': 0},
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return const DotnetDocument(
        kind: DotnetDocumentKind.unknown,
        problem: DotnetDocumentProblem.notJson,
      );
    }
    if (decoded is! Map) {
      return const DotnetDocument(
        kind: DotnetDocumentKind.unknown,
        problem: DotnetDocumentProblem.notADocument,
      );
    }

    final keys = _KeyView(decoded.cast<Object?, Object?>());
    final version = keys.number('version')?.toInt();

    if (keys.has('tasks') && keys.has('dependencies')) {
      return DotnetDocument(
        kind: DotnetDocumentKind.haftKhanBackup,
        version: version,
        counts: {
          'tasks': keys.lengthOf('tasks'),
          'links': keys.lengthOf('dependencies'),
        },
      );
    }
    if (keys.has('accounts') &&
        (keys.has('transactions') || keys.has('budgets'))) {
      return DotnetDocument(
        kind: DotnetDocumentKind.ganjoorBackup,
        version: version,
        counts: {
          'accounts': keys.lengthOf('accounts'),
          'transactions': keys.lengthOf('transactions'),
          'budgets': keys.lengthOf('budgets'),
        },
      );
    }
    if (keys.has('salt') && keys.has('payload') && keys.has('keyCheck')) {
      return DotnetDocument(
        kind: DotnetDocumentKind.razBackup,
        version: version,
      );
    }
    return const DotnetDocument(
      kind: DotnetDocumentKind.unknown,
      problem: DotnetDocumentProblem.notADocument,
    );
  }

  /// [text] with every JSON key spelled the way the Dart parsers read it.
  ///
  /// Returns the document unchanged when it is not JSON, so passing an `.ics` through this
  /// is harmless. Throws nothing: a malformed document is left for the parser whose error
  /// message the parity suites already pin.
  static String translate(String text) {
    final decoded = _decodeOrNull(text);
    if (decoded == null) return text;
    final lowered = _lowerKeys(decoded);
    final normalised = _normaliseMoney(lowered);
    // A document that already speaks the port's spelling is handed back byte for byte, so a
    // round trip never rewrites a file the user will compare with the original.
    if (jsonEncode(normalised) == jsonEncode(decoded)) return text;
    return const JsonEncoder.withIndent('  ').convert(normalised);
  }

  /// The wallet's money fields, re-spelled from JSON numbers to invariant strings.
  ///
  /// The .NET's wallet held `decimal`, and `System.Text.Json` writes a decimal as a JSON
  /// *number* — `"InitialBalance": 100.00`. The port holds minor units and reads the invariant
  /// *string* (`"100.00"`), which is the spelling its own export writes. One re-spelling here
  /// keeps a migrated file identical to a native one; without it every amount would fail to
  /// parse. Only the wallet has money in a document.
  static const Map<String, List<String>> _moneyFields = {
    'accounts': ['initialBalance'],
    'transactions': ['amount'],
    'budgets': ['monthlyLimit'],
    'bills': ['amount'],
    'goals': ['target', 'contributed'],
    'debts': ['amount', 'settled'],
  };

  static Object? _normaliseMoney(Object? node) {
    if (node is! Map) return node;
    if (!node.containsKey('accounts') || !node.containsKey('transactions')) {
      return node;
    }
    for (final entry in _moneyFields.entries) {
      final rows = node[entry.key];
      if (rows is! List) continue;
      for (final row in rows) {
        if (row is! Map) continue;
        for (final field in entry.value) {
          final value = row[field];
          if (value is num) {
            row[field] = value.toDouble().toStringAsFixed(2);
          }
        }
      }
    }
    return node;
  }

  static Object? _decodeOrNull(String text) {
    try {
      return jsonDecode(text.trim());
    } on FormatException {
      return null;
    }
  }

  /// Recursively lowers the first letter of every object key.
  static Object? _lowerKeys(Object? node) {
    if (node is Map) {
      return {
        for (final entry in node.entries)
          _lowerKey('${entry.key}'): _lowerKeys(entry.value),
      };
    }
    if (node is List) return [for (final item in node) _lowerKeys(item)];
    return node;
  }

  /// `ExportedAt` → `exportedAt`; `UID` → `uid`; `alreadyCamel` → `alreadyCamel`.
  static String _lowerKey(String key) {
    if (key.isEmpty) return key;
    final isAllCaps = key.toUpperCase() == key && key.toLowerCase() != key;
    if (isAllCaps) return key.toLowerCase();
    if (key[0].toUpperCase() != key[0]) return key;
    return key[0].toLowerCase() + key.substring(1);
  }
}

class _KeyView {
  _KeyView(this._row);

  final Map<Object?, Object?> _row;

  Object? _value(String key) {
    final wanted = key.toLowerCase();
    for (final entry in _row.entries) {
      if ('${entry.key}'.toLowerCase() == wanted) return entry.value;
    }
    return null;
  }

  bool has(String key) => _value(key) != null;

  num? number(String key) {
    final value = _value(key);
    return value is num ? value : null;
  }

  int lengthOf(String key) {
    final value = _value(key);
    return value is List ? value.length : 0;
  }
}
