import 'dart:io';

import 'package:path/path.dart' as p;

import 'diagnostic.dart';
import 'severity.dart';
import 'terminal/ansi.dart';

/// Presents a list of [Diagnostic]s to some sink (console, file, IDE, ...).
///
/// Implementations decide the wire format and destination. The runner calls
/// [report] exactly once with the full accumulated diagnostic list at the end
/// of an analysis run.
abstract class Reporter {
  /// Writes [diagnostics] to the implementation's destination.
  void report(List<Diagnostic> diagnostics);
}

/// A [Reporter] that writes a human-friendly, column-aligned report to an
/// [IOSink], grouped by file.
///
/// Findings are bucketed by `location.filePath` while preserving the order in
/// which each file first appears in the input, and within each file the input
/// order is kept verbatim (the reporter never sorts by line, column, or
/// severity). Each file is emitted once as a header line, followed by one
/// indented row per finding laid out in aligned columns:
///
/// ```
/// <severity>  <line>:<column>  <ruleId>  <message>
/// ```
///
/// Column widths are computed once across the whole report so every row lines
/// up. A finding's optional [Diagnostic.correction] is written on a
/// continuation line aligned under the message and prefixed with `↳`. File
/// groups are separated by a blank line, and — unless [showSummary] is
/// `false` — the report ends with a one-line summary tallying findings by
/// severity (or a "No issues found" line when the list is empty).
///
/// ## Color
///
/// Styling is delegated to [ansi]. With the default [Ansi.disabled] palette
/// the output is plain text (identical bytes on every platform), which is the
/// right choice for pipes, files, and test buffers. Pass an enabled palette
/// to color severities, dim secondary detail, and bold headers. The reporter
/// never inspects the sink itself — the caller decides whether color is
/// appropriate (see `shouldEmitAnsi`).
///
/// ## Paths
///
/// When [relativeTo] is set, file headers are displayed relative to that
/// directory (falling back to the raw path if it lies on another root);
/// otherwise the path is shown verbatim. Bucketing always keys off the raw
/// `location.filePath`, so display formatting never merges distinct files.
class ConsoleReporter implements Reporter {
  /// Sink that receives the grouped diagnostic report.
  final IOSink out;

  /// Palette used to style the report. Defaults to plain (no color).
  final Ansi ansi;

  /// When `true` (the default), a summary line is appended after the findings
  /// (or emitted on its own for an empty list).
  final bool showSummary;

  /// Directory that file paths are displayed relative to, or `null` to show
  /// paths verbatim.
  final String? relativeTo;

  /// Creates a [ConsoleReporter] writing to [out].
  const ConsoleReporter({
    required this.out,
    this.ansi = const Ansi.disabled(),
    this.showSummary = true,
    this.relativeTo,
  });

  @override
  void report(List<Diagnostic> diagnostics) {
    final byFile = <String, List<Diagnostic>>{};
    for (final d in diagnostics) {
      (byFile[d.location.filePath] ??= <Diagnostic>[]).add(d);
    }

    final (sevWidth, locWidth, ruleWidth) = _columnWidths(diagnostics);
    // Column start of the message, used to align correction continuations.
    final messageIndent = 2 + sevWidth + 2 + locWidth + 2 + ruleWidth + 2;

    var firstGroup = true;
    for (final entry in byFile.entries) {
      if (!firstGroup) out.writeln();
      firstGroup = false;

      out.writeln(ansi.paint(_displayPath(entry.key), const <int>[Ansi.bold]));
      for (final d in entry.value) {
        final loc = '${d.location.line}:${d.location.column}';
        out.writeln(
          '  '
          '${ansi.paint(d.severity.name.padRight(sevWidth), _severityStyle(d.severity))}'
          '  '
          '${ansi.paint(loc.padRight(locWidth), const <int>[Ansi.grey])}'
          '  '
          '${ansi.paint(d.ruleId.padRight(ruleWidth), const <int>[Ansi.grey])}'
          '  '
          '${d.message}',
        );
        final correction = d.correction;
        if (correction != null) {
          out.writeln(
            '${' ' * messageIndent}'
            '${ansi.paint('↳ $correction', const <int>[Ansi.dim])}',
          );
        }
      }
    }

    if (showSummary) {
      if (diagnostics.isNotEmpty) out.writeln();
      _writeSummary(diagnostics, byFile.length);
    }
  }

  (int, int, int) _columnWidths(List<Diagnostic> diagnostics) {
    var sev = 0;
    var loc = 0;
    var rule = 0;
    for (final d in diagnostics) {
      if (d.severity.name.length > sev) sev = d.severity.name.length;
      final locLen = '${d.location.line}:${d.location.column}'.length;
      if (locLen > loc) loc = locLen;
      if (d.ruleId.length > rule) rule = d.ruleId.length;
    }
    return (sev, loc, rule);
  }

  String _displayPath(String filePath) {
    final base = relativeTo;
    if (base == null) return filePath;
    try {
      return p.relative(filePath, from: base);
    } on Object {
      return filePath;
    }
  }

  List<int> _severityStyle(Severity severity) => switch (severity) {
    Severity.error => const <int>[Ansi.bold, Ansi.red],
    Severity.warning => const <int>[Ansi.bold, Ansi.yellow],
    Severity.info => const <int>[Ansi.bold, Ansi.cyan],
  };

  void _writeSummary(List<Diagnostic> diagnostics, int fileCount) {
    if (diagnostics.isEmpty) {
      out.writeln(
        ansi.paint('✓ No issues found', const <int>[Ansi.bold, Ansi.green]),
      );
      return;
    }

    var errors = 0;
    var warnings = 0;
    var infos = 0;
    for (final d in diagnostics) {
      switch (d.severity) {
        case Severity.error:
          errors++;
        case Severity.warning:
          warnings++;
        case Severity.info:
          infos++;
      }
    }

    final worst = errors > 0
        ? Severity.error
        : warnings > 0
        ? Severity.warning
        : Severity.info;
    final symbol = switch (worst) {
      Severity.error => '✖',
      Severity.warning => '⚠',
      Severity.info => 'ℹ',
    };

    final total = diagnostics.length;
    final headline = '$symbol $total ${_plural(total, 'issue')} found';

    final parts = <String>[
      if (errors > 0) '$errors ${_plural(errors, 'error')}',
      if (warnings > 0) '$warnings ${_plural(warnings, 'warning')}',
      if (infos > 0) '$infos info',
    ];
    final breakdown = '(${parts.join(', ')})';
    final where = 'in $fileCount ${_plural(fileCount, 'file')}';

    out.writeln(
      '${ansi.paint(headline, _severityStyle(worst))}'
      '  '
      '${ansi.paint('$breakdown  $where', const <int>[Ansi.dim])}',
    );
  }

  static String _plural(int n, String singular) =>
      n == 1 ? singular : '${singular}s';
}
