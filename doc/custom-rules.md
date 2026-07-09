# Custom Rules

The published CLI runs the built-in rules. To run project-specific rules,
consume LintForge as a library and assemble your own registry and runner.

Import the public surface from one package entry point:

```dart
import 'package:lintforge/lintforge.dart';
```

Do not import from `lib/src/`; those files are implementation details.

If your rule imports `package:analyzer` AST or element APIs directly, add
`analyzer` as a direct dev dependency in the package that owns the custom
runner.

## Single-file rules

Implement `AnalyzerRule` for checks that only need one resolved compilation
unit at a time.

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lintforge/lintforge.dart';

class NoDebugPrintRule extends AnalyzerRule {
  @override
  String get id => 'no_debug_print';

  @override
  String get description => 'Flags debugPrint calls.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(AnalysisContext context) {
    final collector = _DebugPrintCollector(context);
    context.unit.unit.accept(collector);
    return collector.diagnostics;
  }
}

class _DebugPrintCollector extends RecursiveAstVisitor<void> {
  final AnalysisContext context;
  final List<Diagnostic> diagnostics = [];

  _DebugPrintCollector(this.context);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'debugPrint') {
      final location = context.unit.lineInfo.getLocation(node.offset);
      diagnostics.add(
        Diagnostic(
          ruleId: 'no_debug_print',
          message: 'Avoid debugPrint in committed code.',
          severity: Severity.warning,
          location: SourceLocation(
            filePath: context.filePath,
            offset: node.offset,
            length: node.length,
            line: location.lineNumber,
            column: location.columnNumber,
          ),
          correction: 'Remove the call or guard it behind a debug-only path.',
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}
```

`AnalysisContext.unit` is a `ResolvedUnitResult`, so rules can inspect the AST,
resolved elements, library element, and line information.

## Multi-file rules

Implement `MultiFileAnalyzerRule` when the check needs a whole-run view:

- import/export/part reachability
- cross-file symbol references
- duplicate declarations across files
- package architecture boundaries

```dart
class MyCrossFileRule extends MultiFileAnalyzerRule {
  @override
  String get id => 'my_cross_file_rule';

  @override
  String get description => 'Checks a cross-file project invariant.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    // context.units contains every resolved unit.
    // context.reportableFilePaths is the subset allowed to receive diagnostics.
    return const <Diagnostic>[];
  }
}
```

Only emit diagnostics for files in `context.reportableFilePaths`. Excluded
files appear in `context.units` so they can contribute references, but they
should not receive findings.

## Register and run

Create a small Dart entrypoint:

```dart
import 'dart:io';

import 'package:lintforge/lintforge.dart';

Future<void> main(List<String> args) async {
  final registry = RuleRegistry()
    ..register(NoDebugPrintRule())
    ..registerMultiFile(MyCrossFileRule());

  final runner = AnalysisRunner(
    registry: registry,
    options: const LintforgeOptions.defaults(),
  );

  final diagnostics = await runner.run();
  ConsoleReporter(out: stdout).report(diagnostics);

  if (diagnostics.any((diagnostic) => diagnostic.severity == Severity.error)) {
    exitCode = 1;
  }
}
```

Run it with:

```sh
dart run tool/my_lintforge_runner.dart
```

## Rule contracts

Rules should be pure:

- no file I/O inside `analyze`
- no network calls
- no global mutable caches
- no assumptions about rule dispatch order

The runner resolves files and passes immutable context objects to rules. A rule
returns diagnostics; it should not write output itself.

Use stable, lowercase_with_underscores ids. Rule ids appear in configuration,
reports, and diagnostics, so treat them as public API once published.

## Testing custom rules

Good rule tests usually cover:

- one positive case that must emit a diagnostic
- one negative case that must stay silent
- source-location accuracy for the diagnostic
- one edge case for each syntax or language feature the rule claims to support

For cross-file rules, include excluded-file behavior in tests if references from
generated or ignored files should affect the result.
