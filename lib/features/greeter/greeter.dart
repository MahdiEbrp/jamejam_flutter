/// greeter — see doc/greeter.md and AGENTS.md
abstract final class Greeter {
  /// Gets a friendly greeting for [name].
  ///
  /// Null, empty, or whitespace greets the world.
  static String getGreeting(String? name) {
    if (name == null || name.trim().isEmpty) return 'Hello, World!';
    return 'Hello, ${name.trim()}!';
  }
}

class GreeterOptions {
  const GreeterOptions({this.maxNameLength = 40, this.maxGreetingLength = 200});

  /// Upper rail for [maxNameLength].
  static const int maxNameLengthBound = 128;

  /// Upper rail for [maxGreetingLength].
  static const int maxGreetingLengthBound = 1000;

  /// Longest name fragment placed inside the prompt.
  final int maxNameLength;

  /// Longest greeting accepted back from the AI.
  final int maxGreetingLength;

  /// Validates the bounds against their rails.
  void validate() {
    if (maxNameLength < 1 || maxNameLength > maxNameLengthBound) {
      throw RangeError.value(
        maxNameLength,
        'MaxNameLength',
        'must be between 1 and $maxNameLengthBound',
      );
    }
    if (maxGreetingLength < 1 || maxGreetingLength > maxGreetingLengthBound) {
      throw RangeError.value(
        maxGreetingLength,
        'MaxGreetingLength',
        'must be between 1 and $maxGreetingLengthBound',
      );
    }
  }
}
