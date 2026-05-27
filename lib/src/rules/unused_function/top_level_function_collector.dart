part of '../unused_function_rule.dart';

/// Collector for top-level function declarations.
///
/// Only **private** declarations (identifier begins with `_`) are
/// considered, and only when the enclosing library has no `part`
/// files — otherwise a sibling part could legitimately reference the
/// function and the rule would have to be cross-library aware to know
/// that.
///
/// A declaration is exempt when its name is `main` (the library entry
/// point), when it is declared `external`, or when it carries
/// `@pragma('vm:entry-point')`.
///
/// The diagnostic anchor is the declaration's name [Token].
class _TopLevelFunctionCollector implements _UnusedFunctionCandidateCollector {
  const _TopLevelFunctionCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) sync* {
    if (unit.libraryElement.fragments.length > 1) return;
    for (final declaration in unit.unit.declarations) {
      if (declaration is! FunctionDeclaration) continue;
      if (!_isTopLevelCandidate(declaration)) continue;
      final element = declaration.declaredFragment?.element;
      if (element == null) continue;
      yield _Candidate(
        nameToken: declaration.name,
        element: element,
        kindLabel: 'top-level function',
      );
    }
  }

  bool _isTopLevelCandidate(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    if (!name.startsWith('_')) return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    return true;
  }
}
