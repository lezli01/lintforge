import 'package:analyzer/dart/analysis/results.dart';

/// Carrier passed into every `MultiFileAnalyzerRule.analyze` invocation.
///
/// A [MultiFileAnalysisContext] bundles the resolved view of every Dart
/// source file in the run with the absolute set of paths that were
/// analyzed. The frame constructs one of these per run and hands the same
/// instance to each enabled multi-file rule.
///
/// Instances are immutable value carriers. There are intentionally no
/// mutable collectors, callbacks, or visitor hooks: rules surface their
/// findings exclusively through the return value of
/// `MultiFileAnalyzerRule.analyze`.
class MultiFileAnalysisContext {
  /// Resolved compilation units for every Dart file under analysis.
  ///
  /// Each entry exposes `unit.unit` (the `CompilationUnit` AST) and
  /// `unit.libraryElement` for symbol-level reasoning. Resolution means
  /// rules can inspect element references across the whole set of files,
  /// not just the raw syntax trees.
  ///
  /// The list is unmodifiable; attempts to mutate it throw.
  final List<ResolvedUnitResult> units;

  /// Absolute, normalized paths of every file resolved into the context.
  ///
  /// This is the *full* set, including files that were pulled in only as
  /// reference material (for example, files matched by the analyzer's
  /// `exclude` configuration that are still imported by analyzed sources
  /// and therefore need resolution so cross-file rules can see their
  /// symbols). Use this set when reasoning about reachability, references,
  /// or anything else that should consider every file the frame loaded.
  ///
  /// Provided as a convenience so rules can test membership ("is this
  /// path part of the analyzed set?") in constant time without scanning
  /// [units]. Always equal to `{for (final u in units) u.path}`.
  ///
  /// The set is unmodifiable; attempts to mutate it throw.
  final Set<String> analyzedFilePaths;

  /// Subset of [analyzedFilePaths] that may receive diagnostics.
  ///
  /// Files resolved purely as references (for example, excluded files
  /// imported by an analyzed source) appear in [analyzedFilePaths] but
  /// are absent from this set. Rules SHOULD only emit diagnostics whose
  /// [Diagnostic.location] points at a path contained in
  /// [reportableFilePaths]; emitting against a reference-only path will
  /// be filtered out by the frame.
  ///
  /// Defaults to [analyzedFilePaths] when the constructor caller does
  /// not pass a narrower set, preserving the historical behavior where
  /// every analyzed file is also reportable.
  ///
  /// The set is unmodifiable; attempts to mutate it throw.
  final Set<String> reportableFilePaths;

  /// Creates a [MultiFileAnalysisContext] for a run.
  ///
  /// [units], [analyzedFilePaths], and [reportableFilePaths] are wrapped
  /// in unmodifiable views so rules cannot mutate the inputs the frame
  /// shares between them.
  ///
  /// If [reportableFilePaths] is omitted, it defaults to a copy of
  /// [analyzedFilePaths] — every analyzed file is treated as
  /// diagnostic-eligible.
  MultiFileAnalysisContext({
    required List<ResolvedUnitResult> units,
    required Set<String> analyzedFilePaths,
    Set<String>? reportableFilePaths,
  }) : units = List<ResolvedUnitResult>.unmodifiable(units),
       analyzedFilePaths = Set<String>.unmodifiable(analyzedFilePaths),
       reportableFilePaths = Set<String>.unmodifiable(
         reportableFilePaths ?? analyzedFilePaths,
       );
}
