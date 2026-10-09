/// anahita — see doc/anahita.md and AGENTS.md
library;

abstract final class WeatherCode {
  /// First code of the thunderstorm range (95–99).
  static const int thunderstormMin = 95;

  /// Last code of the thunderstorm range.
  static const int thunderstormMax = 99;

  /// Describes a WMO code in plain words.
  static String describe(int code) => switch (code) {
    0 => 'Clear sky',
    1 => 'Mainly clear',
    2 => 'Partly cloudy',
    3 => 'Overcast',
    45 => 'Fog',
    48 => 'Rime fog',
    51 => 'Light drizzle',
    53 => 'Drizzle',
    55 => 'Dense drizzle',
    56 => 'Freezing drizzle',
    57 => 'Dense freezing drizzle',
    61 => 'Light rain',
    63 => 'Rain',
    65 => 'Heavy rain',
    66 => 'Freezing rain',
    67 => 'Heavy freezing rain',
    71 => 'Light snow',
    73 => 'Snow',
    75 => 'Heavy snow',
    77 => 'Snow grains',
    80 => 'Light showers',
    81 => 'Showers',
    82 => 'Violent showers',
    85 => 'Snow showers',
    86 => 'Heavy snow showers',
    95 => 'Thunderstorm',
    96 => 'Thunderstorm with hail',
    99 => 'Severe thunderstorm with hail',
    _ => 'Unrecognized weather code',
  };

  /// A single glyph for a WMO code (basic symbols, safe everywhere).
  static String icon(int code) => switch (code) {
    0 || 1 => '☀',
    2 || 3 => '☁',
    45 || 48 => '☁',
    >= 51 && <= 67 || >= 80 && <= 82 => '☂',
    >= 71 && <= 77 || 85 || 86 => '❆',
    >= thunderstormMin && <= thunderstormMax => '⚡',
    _ => '·',
  };

  /// True when the code denotes a thunderstorm (WMO 95–99).
  static bool isThunderstorm(int code) =>
      code >= thunderstormMin && code <= thunderstormMax;
}
