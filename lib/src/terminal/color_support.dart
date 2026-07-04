/// Decides whether ANSI color should be emitted to an output stream.
///
/// The rules follow the widely-adopted conventions so `lintforge` behaves the
/// way developers expect when piping, redirecting, or running under CI:
///
/// * an explicit user preference (`--color` / `--no-color`) always wins;
/// * otherwise `NO_COLOR` (any non-empty value, see https://no-color.org)
///   disables color and `FORCE_COLOR` forces it on;
/// * a `TERM=dumb` terminal is treated as non-capable;
/// * failing all of the above, color is emitted only when the stream is an
///   interactive terminal that advertises ANSI support.
library;

import 'ansi.dart';

/// A user's explicit color preference, typically parsed from a CLI flag.
enum ColorPreference {
  /// Auto-detect from the stream and environment (the default).
  auto,

  /// Force color on regardless of stream/environment (`--color`).
  always,

  /// Force color off regardless of stream/environment (`--no-color`).
  never,
}

/// Returns whether ANSI escape codes should be written, given a [preference],
/// the target stream's capabilities ([hasTerminal] / [supportsAnsiEscapes]),
/// and the process [environment].
///
/// This is a pure function of its inputs so callers can unit-test every
/// branch without a real terminal.
bool shouldEmitAnsi({
  required ColorPreference preference,
  required bool hasTerminal,
  required bool supportsAnsiEscapes,
  required Map<String, String> environment,
}) {
  switch (preference) {
    case ColorPreference.never:
      return false;
    case ColorPreference.always:
      return true;
    case ColorPreference.auto:
      final noColor = environment['NO_COLOR'];
      if (noColor != null && noColor.isNotEmpty) return false;

      final forceColor = environment['FORCE_COLOR'];
      if (forceColor != null &&
          forceColor.isNotEmpty &&
          forceColor != '0' &&
          forceColor.toLowerCase() != 'false') {
        return true;
      }

      if (environment['TERM'] == 'dumb') return false;

      return hasTerminal && supportsAnsiEscapes;
  }
}

/// Convenience wrapper that resolves a ready-to-use [Ansi] palette from the
/// same inputs as [shouldEmitAnsi].
Ansi resolveAnsi({
  required ColorPreference preference,
  required bool hasTerminal,
  required bool supportsAnsiEscapes,
  required Map<String, String> environment,
}) {
  return Ansi(
    enabled: shouldEmitAnsi(
      preference: preference,
      hasTerminal: hasTerminal,
      supportsAnsiEscapes: supportsAnsiEscapes,
      environment: environment,
    ),
  );
}
