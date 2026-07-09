import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

import '../diagnostic.dart';
import '../multi_file_analysis_context.dart';
import '../multi_file_analyzer_rule.dart';
import '../severity.dart';
import '../source_location.dart';

/// Flags private class, mixin, enum, and extension-type declarations that are
/// never referenced across the analyzed file set.
///
/// The rule inspects every resolved compilation unit in the analyzed set, so
/// private declarations in a library with `part` files can be kept alive by
/// references from sibling parts. Four kinds of top-level declarations are
/// inspected:
///
/// * `ClassDeclaration` — covers `class`, `abstract class`, and `base`,
///   `final`, `sealed`, and `interface` modifiers (all surface as
///   `ClassDeclaration` in the AST).
/// * `MixinDeclaration`.
/// * `EnumDeclaration`.
/// * `ExtensionTypeDeclaration`.
///
/// Only **private** declarations (identifier begins with `_`) are candidates.
/// Libraries with `part` files are analyzed only when every resolved fragment
/// of that library is present in the analyzed set; otherwise the rule skips
/// the library rather than risk a false positive from a missing sibling part.
///
/// A declaration is considered "used" if any `SimpleIdentifier` in the
/// analyzed set resolves (via `element`) to its declared element, or
/// if any `NamedType` does — the latter covers the class-modifier forms
/// (`sealed`, `base`, `interface`, `final`), mixin types in `with`,
/// `implements`, and `on` clauses, generic type arguments, and the type
/// position of Dart 3+ object patterns. Beyond identifier and named-type
/// references, the rule also inspects Dart 3+ pattern syntax: `case Foo()`
/// object patterns, record patterns, named/positional pattern fields, and
/// constant patterns all count as references through their nested types
/// and identifiers.
///
/// The rule deliberately ignores:
///
/// * public top-level declarations (names not starting with `_`);
/// * `ClassTypeAlias` declarations such as `class _Foo = A with B;` —
///   out of scope for the first cut;
/// * `extension` declarations (non-type `ExtensionDeclaration`) — out of
///   scope for the first cut;
/// * declarations annotated with `@pragma('vm:entry-point')`;
/// * every candidate in a library that imports `dart:mirrors`,
///   because reflective lookup may resolve a class by name at runtime
///   without ever naming it statically — flagging would produce false
///   positives.
class UnusedClassRule implements MultiFileAnalyzerRule {
  /// Creates an instance of the rule. Stateless and `const`-constructible.
  const UnusedClassRule();

  @override
  String get id => 'unused_class';

  @override
  String get description =>
      'Flags private class, mixin, enum, and extension-type declarations '
      'that are never referenced across the analyzed file set.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    final globalReferences = <Element>{};
    final mirrorLibraries = <LibraryElement>{};
    for (final unit in context.units) {
      unit.unit.accept(_ReferenceCollector(globalReferences));
      if (_importsDartMirrors(unit.unit)) {
        mirrorLibraries.add(unit.libraryElement);
      }
    }

    final diagnostics = <Diagnostic>[];
    for (final unit in context.units) {
      if (!context.reportableFilePaths.contains(unit.path)) continue;

      final libraryElement = unit.libraryElement;
      if (mirrorLibraries.contains(libraryElement)) continue;
      if (!_libraryFragmentsAreAnalyzed(
        libraryElement,
        context.analyzedFilePaths,
      )) {
        continue;
      }

      final candidates = <_Candidate>[];
      for (final declaration in unit.unit.declarations) {
        final candidate = _candidateFor(declaration);
        if (candidate != null) {
          candidates.add(candidate);
        }
      }
      if (candidates.isEmpty) continue;

      for (final candidate in candidates) {
        final element = candidate.element?.baseElement;
        if (element == null) continue;
        if (globalReferences.contains(element)) continue;
        diagnostics.add(
          _buildDiagnostic(
            candidate: candidate,
            filePath: unit.path,
            lineInfo: unit.lineInfo,
          ),
        );
      }
    }

    diagnostics.sort((a, b) {
      final byPath = a.location.filePath.compareTo(b.location.filePath);
      if (byPath != 0) return byPath;
      final byLine = a.location.line.compareTo(b.location.line);
      if (byLine != 0) return byLine;
      return a.location.column.compareTo(b.location.column);
    });

    return diagnostics;
  }

  _Candidate? _candidateFor(CompilationUnitMember declaration) {
    if (declaration is ClassDeclaration) {
      // analyzer 11 removed `ClassDeclaration.name`; the class-name token now
      // lives on `namePart.typeName` (`ClassNamePart.typeName`).
      final nameToken = declaration.namePart.typeName;
      if (!_isPrivateName(nameToken.lexeme)) return null;
      if (_hasVmEntryPointPragma(declaration.metadata)) return null;
      return _Candidate(
        nameToken: nameToken,
        element: declaration.declaredFragment?.element,
        kindLabel: 'class',
      );
    }
    if (declaration is MixinDeclaration) {
      if (!_isPrivateName(declaration.name.lexeme)) return null;
      if (_hasVmEntryPointPragma(declaration.metadata)) return null;
      return _Candidate(
        nameToken: declaration.name,
        element: declaration.declaredFragment?.element,
        kindLabel: 'mixin',
      );
    }
    if (declaration is EnumDeclaration) {
      // See the `ClassDeclaration` branch above: analyzer 11 removed
      // `EnumDeclaration.name`; read the enum-name token from
      // `namePart.typeName`.
      final nameToken = declaration.namePart.typeName;
      if (!_isPrivateName(nameToken.lexeme)) return null;
      if (_hasVmEntryPointPragma(declaration.metadata)) return null;
      return _Candidate(
        nameToken: nameToken,
        element: declaration.declaredFragment?.element,
        kindLabel: 'enum',
      );
    }
    if (declaration is ExtensionTypeDeclaration) {
      // The type-name token is read from `namePart` (a `ClassNamePart`, so it
      // carries `typeName`); `primaryConstructor` is deprecated for this.
      final nameToken = declaration.namePart.typeName;
      if (!_isPrivateName(nameToken.lexeme)) return null;
      if (_hasVmEntryPointPragma(declaration.metadata)) return null;
      return _Candidate(
        nameToken: nameToken,
        element: declaration.declaredFragment?.element,
        kindLabel: 'extension type',
      );
    }
    return null;
  }

  bool _isPrivateName(String name) => name.startsWith('_');

  Diagnostic _buildDiagnostic({
    required _Candidate candidate,
    required String filePath,
    required LineInfo lineInfo,
  }) {
    final nameToken = candidate.nameToken;
    final name = nameToken.lexeme;
    final offset = nameToken.offset;
    final length = nameToken.length;
    final location = lineInfo.getLocation(offset);
    return Diagnostic(
      ruleId: 'unused_class',
      message: 'The ${candidate.kindLabel} "$name" is declared but never used.',
      severity: Severity.warning,
      location: SourceLocation(
        filePath: filePath,
        offset: offset,
        length: length,
        line: location.lineNumber,
        column: location.columnNumber,
      ),
      correction: 'Remove "$name" or reference it.',
    );
  }
}

bool _libraryFragmentsAreAnalyzed(
  LibraryElement libraryElement,
  Set<String> analyzedFilePaths,
) {
  for (final fragment in libraryElement.fragments) {
    if (fragment.isOriginNotExistingFile) return false;
    if (!analyzedFilePaths.contains(p.normalize(fragment.source.fullName))) {
      return false;
    }
  }
  return true;
}

bool _importsDartMirrors(CompilationUnit unit) {
  for (final directive in unit.directives) {
    if (directive is! ImportDirective) continue;
    if (directive.uri.stringValue == 'dart:mirrors') return true;
  }
  return false;
}

bool _hasVmEntryPointPragma(NodeList<Annotation> metadata) {
  for (final annotation in metadata) {
    final identifier = annotation.name;
    final simpleName = identifier is SimpleIdentifier
        ? identifier.name
        : identifier is PrefixedIdentifier
        ? identifier.identifier.name
        : '';
    if (simpleName != 'pragma') continue;
    final arguments = annotation.arguments;
    if (arguments == null || arguments.arguments.isEmpty) continue;
    final first = arguments.arguments.first;
    if (first is StringLiteral && first.stringValue == 'vm:entry-point') {
      return true;
    }
  }
  return false;
}

class _Candidate {
  final Token nameToken;
  final Element? element;
  final String kindLabel;

  const _Candidate({
    required this.nameToken,
    required this.element,
    required this.kindLabel,
  });
}

class _ReferenceCollector extends RecursiveAstVisitor<void> {
  final Set<Element> sink;

  _ReferenceCollector(this.sink);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element != null) sink.add(element.baseElement);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final element = node.element;
    if (element != null) sink.add(element.baseElement);
    super.visitNamedType(node);
  }

  // Dart 3 patterns: `case Foo()` and `case Foo(x: y)`. The pattern's
  // `type` is a `NamedType` whose element resolves to the class being
  // matched, so capturing it here counts the pattern as a use of the
  // class. `super.visitObjectPattern` recurses into the nested fields,
  // each of which is a `PatternField` containing a sub-pattern — those
  // are walked by `RecursiveAstVisitor` so nested patterns
  // (`RecordPattern`, `ConstantPattern`, further `ObjectPattern`s, etc.)
  // surface their own references through the existing
  // `visitNamedType` and `visitSimpleIdentifier` hooks.
  @override
  void visitObjectPattern(ObjectPattern node) {
    final element = node.type.element;
    if (element != null) sink.add(element.baseElement);
    super.visitObjectPattern(node);
  }
}
