/// The phase an `AnalysisRunner` is currently executing when it emits a
/// progress update.
enum AnalysisPhase {
  /// Parsing and resolving individual compilation units — the bulk of the
  /// work, reported per file so a determinate progress bar is possible.
  resolving,

  /// Running cross-file (multi-file) rules over the fully resolved set. This
  /// is a single pass, so it is reported as an indeterminate step.
  crossFile,
}

/// An immutable snapshot of an in-progress analysis run.
///
/// `AnalysisRunner` invokes its optional progress callback with one of these
/// as it advances, so a caller (typically the CLI) can render a live
/// indicator. Producing progress is entirely optional: when no callback is
/// supplied the runner does no extra work and behaves identically.
class AnalysisProgress {
  /// The phase currently executing.
  final AnalysisPhase phase;

  /// How many units of work have finished in [phase]. For
  /// [AnalysisPhase.resolving] this counts files already resolved; for
  /// [AnalysisPhase.crossFile] it is not meaningful and is reported as `0`.
  final int completed;

  /// Total units of work in [phase], or `0` when the phase is indeterminate
  /// (as with [AnalysisPhase.crossFile]).
  final int total;

  /// Absolute path of the file being processed, when applicable.
  final String? currentPath;

  /// Creates a progress snapshot.
  const AnalysisProgress({
    required this.phase,
    required this.completed,
    required this.total,
    this.currentPath,
  });
}
