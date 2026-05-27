import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';

import '../analysis_context.dart';
import '../analyzer_rule.dart';
import '../diagnostic.dart';
import '../severity.dart';
import '../source_location.dart';

/// Flags file-local function declarations that are never referenced.
///
/// The rule is intentionally file-local: per the frame's dispatch model, a
/// rule sees one resolved compilation unit at a time and cannot reason about
/// references in sibling files. Two kinds of declarations are inspected:
///
/// * **Top-level private functions** (identifier begins with `_`) — only
///   when the enclosing library has no `part` files, because otherwise a
///   sibling part could legitimately reference the function.
/// * **Local function declarations** — functions declared inside another
///   function or method body. References are sought within the enclosing
///   function body.
///
/// A function is considered "used" if any `SimpleIdentifier` in the scanned
/// scope resolves (via `staticElement`) to its declared element. This
/// captures both direct calls and tear-offs.
///
/// The rule deliberately ignores public top-level functions, methods,
/// constructors, getters, setters, operators, the library's `main` entry
/// point, `external` functions, and any function annotated with
/// `@pragma('vm:entry-point')`.
class UnusedFunctionRule implements AnalyzerRule {
  /// Creates an instance of the rule. Stateless and `const`-constructible.
  const UnusedFunctionRule();

  @override
  String get id => 'unused_function';

  @override
  String get description =>
      'Flags file-local function declarations that are never referenced.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(AnalysisContext context) {
    final compilationUnit = context.unit.unit;
    final libraryElement = context.unit.libraryElement;
    final lineInfo = context.unit.lineInfo;
    final filePath = context.filePath;

    final libraryHasParts = libraryElement.fragments.length > 1;

    final topLevelCandidates = <FunctionDeclaration>[];
    if (!libraryHasParts) {
      for (final declaration in compilationUnit.declarations) {
        if (declaration is FunctionDeclaration &&
            _isTopLevelCandidate(declaration)) {
          topLevelCandidates.add(declaration);
        }
      }
    }

    final localCandidates = <_LocalCandidate>[];
    compilationUnit.accept(_LocalCandidateCollector(localCandidates));

    final unitReferences = <Element>{};
    compilationUnit.accept(_ReferenceCollector(unitReferences));

    final diagnostics = <Diagnostic>[];

    for (final declaration in topLevelCandidates) {
      final element = declaration.declaredFragment?.element;
      if (element == null) continue;
      if (unitReferences.contains(element)) continue;
      diagnostics.add(
        _buildDiagnostic(
          declaration: declaration,
          isTopLevel: true,
          filePath: filePath,
          lineInfo: lineInfo,
        ),
      );
    }

    for (final candidate in localCandidates) {
      final declaration = candidate.declaration;
      final element = declaration.declaredFragment?.element;
      if (element == null) continue;
      final bodyReferences = <Element>{};
      candidate.enclosingBody.accept(_ReferenceCollector(bodyReferences));
      if (bodyReferences.contains(element)) continue;
      diagnostics.add(
        _buildDiagnostic(
          declaration: declaration,
          isTopLevel: false,
          filePath: filePath,
          lineInfo: lineInfo,
        ),
      );
    }

    diagnostics.sort((a, b) {
      final byLine = a.location.line.compareTo(b.location.line);
      if (byLine != 0) return byLine;
      return a.location.column.compareTo(b.location.column);
    });

    return diagnostics;
  }

  bool _isTopLevelCandidate(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    if (!name.startsWith('_')) return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    return true;
  }

  Diagnostic _buildDiagnostic({
    required FunctionDeclaration declaration,
    required bool isTopLevel,
    required String filePath,
    required LineInfo lineInfo,
  }) {
    final nameToken = declaration.name;
    final name = nameToken.lexeme;
    final offset = nameToken.offset;
    final length = nameToken.length;
    final location = lineInfo.getLocation(offset);
    final kindLabel = isTopLevel ? 'top-level' : 'local';
    return Diagnostic(
      ruleId: 'unused_function',
      message: 'The $kindLabel function "$name" is declared but never used.',
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

class _LocalCandidate {
  final FunctionDeclaration declaration;
  final FunctionBody enclosingBody;

  const _LocalCandidate(this.declaration, this.enclosingBody);
}

class _LocalCandidateCollector extends RecursiveAstVisitor<void> {
  final List<_LocalCandidate> sink;

  _LocalCandidateCollector(this.sink);

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    final declaration = node.functionDeclaration;
    if (_isLocalCandidate(declaration)) {
      final body = _findEnclosingFunctionBody(node);
      if (body != null) {
        sink.add(_LocalCandidate(declaration, body));
      }
    }
    super.visitFunctionDeclarationStatement(node);
  }

  bool _isLocalCandidate(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    return true;
  }

  FunctionBody? _findEnclosingFunctionBody(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }
}

class _ReferenceCollector extends RecursiveAstVisitor<void> {
  final Set<Element> sink;

  _ReferenceCollector(this.sink);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element != null) sink.add(element);
    super.visitSimpleIdentifier(node);
  }
}
