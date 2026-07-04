import 'dart:io';

import 'ansi.dart';

/// Draws a single, self-erasing progress line to an [IOSink] (typically
/// `stderr`) while a long-running analysis is in flight.
///
/// The renderer is deliberately transient: it redraws in place with a
/// carriage return and clears itself with [clear] before any final output is
/// written, so it never pollutes captured or piped output. Callers gate
/// [enabled] on "is this an interactive, ANSI-capable terminal?"; when it is
/// `false` every method is a no-op, which is the correct behaviour for pipes,
/// files, and CI logs.
///
/// This type intentionally knows nothing about the analysis layer — it takes
/// plain primitives ([report]'s `phase`, `completed`, `total`, `detail`) so
/// the terminal package stays independent of the runner.
class ProgressReporter {
  /// Sink that receives the progress line (usually `stderr`).
  final IOSink out;

  /// Whether anything is drawn. When `false`, all methods are no-ops.
  final bool enabled;

  /// Palette used to color the spinner, bar, and counters. Pass a disabled
  /// palette (or rely on the default) for a monochrome indicator.
  final Ansi ansi;

  /// Total visible columns available for one line; longer lines have their
  /// trailing [report] `detail` truncated with a leading ellipsis.
  final int width;

  int _tick = 0;
  bool _dirty = false;

  /// Creates a progress reporter.
  ///
  /// [width] defaults to a conservative 80 columns; pass the real terminal
  /// width when known so the detail text uses the full line.
  ProgressReporter({
    required this.out,
    required this.enabled,
    this.ansi = const Ansi.disabled(),
    this.width = 80,
  });

  static const List<String> _frames = <String>[
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  static const int _barWidth = 20;

  /// Redraws the progress line for the current [phase].
  ///
  /// When [total] is positive a `[████░░░░] completed/total` bar is shown and
  /// the spinner advances one frame per call; [detail] (e.g. the file being
  /// analyzed) is appended and truncated from the left to fit [width].
  ///
  /// The assembled line is kept within [width] columns (counting each rune as
  /// one column): the bar shrinks first, then any remaining segment is clamped
  /// so the line does not wrap. This holds for terminals that render these
  /// glyphs single-width, which is the common case; a terminal that renders
  /// the block/shade/ellipsis glyphs double-width may still exceed [width].
  void report({
    required String phase,
    required int completed,
    required int total,
    String? detail,
  }) {
    if (!enabled) return;

    final frame = _frames[_tick++ % _frames.length];

    final segments = <String>[];
    var visible = 0;
    // Appends [text] styled with [codes], right-truncating (rune-aware, so a
    // surrogate pair is never split) to whatever column budget remains. This
    // is the backstop that keeps the whole line within [width].
    void add(String text, [List<int> codes = const <int>[]]) {
      if (text.isEmpty) return;
      final remaining = width - visible;
      if (remaining <= 0) return;
      final runes = text.runes.toList();
      final shown = runes.length <= remaining
          ? text
          : String.fromCharCodes(runes.take(remaining));
      if (shown.isEmpty) return;
      segments.add(ansi.paint(shown, codes));
      visible += shown.runes.length;
    }

    add(frame, const <int>[Ansi.cyan]);
    add('  ');
    add(phase, const <int>[Ansi.bold]);

    if (total > 0) {
      final count = '$completed/$total';
      // Shrink the bar so `spinner + phase + bar + count` fits. Reserve:
      // spinner(1) + gap(2) + phase + gap(2) + gap-after-bar(2) + count.
      final reserved = 1 + 2 + phase.length + 2 + 2 + count.length;
      final barWidth = (width - reserved).clamp(0, _barWidth);
      if (barWidth > 0) {
        final ratio = (completed / total).clamp(0.0, 1.0);
        final filled = (ratio * barWidth).round().clamp(0, barWidth);
        add('  ');
        add('█' * filled, const <int>[Ansi.green]);
        add('░' * (barWidth - filled), const <int>[Ansi.grey]);
      }
      add('  ');
      add(count, const <int>[Ansi.dim]);
    } else if (completed > 0) {
      add('  ');
      add('$completed', const <int>[Ansi.dim]);
    }

    if (detail != null && detail.isNotEmpty) {
      final budget = width - visible - 2;
      if (budget > 1) {
        // Left-truncate (rune-aware) so the most specific tail of the path
        // survives, prefixed with an ellipsis.
        final runes = detail.runes.toList();
        final shown = runes.length <= budget
            ? detail
            : '…${String.fromCharCodes(runes.skip(runes.length - (budget - 1)))}';
        add('  ');
        add(shown, const <int>[Ansi.dim]);
      }
    }

    out.write('\r${segments.join()}\x1B[K');
    _dirty = true;
  }

  /// Erases the current progress line if one is on screen.
  ///
  /// Safe to call unconditionally — it does nothing when [enabled] is `false`
  /// or nothing has been drawn since the last [clear].
  void clear() {
    if (!enabled || !_dirty) return;
    out.write('\r\x1B[K');
    _dirty = false;
  }
}
