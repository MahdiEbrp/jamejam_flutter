/// The coverage gate: reads `coverage/lcov.info` and fails under the threshold.
///
/// Written as a plain Dart script with no dependencies so CI can run it on any runner with
/// the Flutter SDK — `flutter test --coverage` writes the lcov file, this reads it.
///
/// Usage:
///   flutter test --coverage
///   dart run tool/coverage.dart [--threshold 60] [--verbose]
///
/// The threshold is a floor, not a target: the port's suites are written against the
/// original's behaviour rather than for a number, and the parts that cannot be covered in a
/// test process (platform channels, window plumbing) are listed by name, not hidden by a
/// lower bar.
library;

import 'dart:io';

/// Directories whose lines are counted, with what each holds.
const List<String> _trackedRoots = ['lib/core', 'lib/features', 'lib/widgets'];

/// Files that cannot run in a unit-test process, and why.
const Map<String, String> _excluded = {
  'lib/main.dart': 'the entry point: it starts a real app with real plugins',
};

void main(List<String> args) {
  final threshold = _numberArg(args, '--threshold') ?? 60;
  final verbose = args.contains('--verbose');
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info is missing — run `flutter test --coverage` first.',
    );
    exitCode = 2;
    return;
  }

  final records = _parse(file.readAsLinesSync());
  final rows = <String, _Totals>{};
  final overall = _Totals();

  for (final record in records) {
    final path = record.path;
    if (!_trackedRoots.any(path.startsWith)) continue;
    if (_excluded.containsKey(path)) continue;
    final bucket = _bucketOf(path);
    rows.putIfAbsent(bucket, _Totals.new).add(record);
    overall.add(record);
  }

  final sorted = rows.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

  stdout.writeln('Lines covered, by area');
  for (final entry in sorted) {
    stdout.writeln(
      '  ${entry.key.padRight(28)} ${entry.value.toString().padLeft(18)}',
    );
  }
  if (verbose) {
    stdout.writeln('\nUncovered files under the threshold:');
    final byFile = <String, _Totals>{};
    for (final record in records) {
      if (!_trackedRoots.any(record.path.startsWith)) continue;
      if (_excluded.containsKey(record.path)) continue;
      byFile.putIfAbsent(record.path, _Totals.new).add(record);
    }
    for (final entry in byFile.entries) {
      if (entry.value.percent < threshold) {
        stdout.writeln('  ${entry.value}  ${entry.key}');
      }
    }
  }

  stdout.writeln(
    '\n  ${'TOTAL'.padRight(28)} ${overall.toString().padLeft(18)}',
  );
  final percent = overall.percent;
  if (percent < threshold) {
    stderr.writeln(
      '\nCoverage $percent% is under the $threshold% floor. '
      'Either cover the new code or move the floor deliberately.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln('Coverage gate: $percent% (floor $threshold%).');
}

/// `lib/features/taqvim/sqlite_taqvim_store.dart` → `features/taqvim`.
String _bucketOf(String path) {
  final parts = path.split('/');
  if (parts.length < 3) return parts.first;
  return '${parts[1]}/${parts[2]}';
}

double? _numberArg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  return double.tryParse(args[index + 1]);
}

/// One file's hit counts.
class _Record {
  _Record(this.path, this.found, this.hit);

  final String path;
  final int found;
  final int hit;
}

/// Running totals.
class _Totals {
  int found = 0;
  int hit = 0;

  void add(_Record record) {
    found += record.found;
    hit += record.hit;
  }

  double get percent => found == 0 ? 100 : hit * 100 / found;

  @override
  String toString() => '${percent.toStringAsFixed(1)}% ($hit/$found)';
}

/// Reads the lcov `SF`/`LF`/`LH` triplets.
List<_Record> _parse(List<String> lines) {
  final records = <_Record>[];
  String? path;
  var found = 0;
  var hit = 0;

  void flush() {
    if (path != null && found > 0) records.add(_Record(path!, found, hit));
    path = null;
    found = 0;
    hit = 0;
  }

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      flush();
      path = line.substring(3).trim();
    } else if (line.startsWith('LF:')) {
      found = int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line.startsWith('LH:')) {
      hit = int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line == 'end_of_record') {
      flush();
    }
  }
  flush();
  return records;
}
