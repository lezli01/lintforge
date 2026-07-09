# Architecture

LintForge is intentionally small: a registry collects rules, a runner resolves
Dart files through `package:analyzer`, rules return immutable diagnostics, and a
reporter renders the final list.

## Main components

| Component | Role |
| --------- | ---- |
| `AnalyzerRule` | Contract for single-file rules. Invoked once per reportable resolved unit. |
| `MultiFileAnalyzerRule` | Contract for cross-file rules. Invoked once per run with all resolved units. |
| `RuleRegistry` | Instance-scoped rule collection. Preserves registration order and rejects duplicate ids within each namespace. |
| `LintforgeOptions` | Include paths, exclude globs, and enabled rule ids. |
| `AnalysisRunner` | Discovers files, resolves units, dispatches enabled rules, and returns diagnostics. |
| `AnalysisContext` | Single-file context passed to `AnalyzerRule`. |
| `MultiFileAnalysisContext` | Whole-run context passed to `MultiFileAnalyzerRule`. |
| `Diagnostic` | Immutable finding with rule id, message, severity, location, and optional correction. |
| `Reporter` | Output abstraction. `ConsoleReporter` prints grouped human-readable diagnostics. |

## Runner lifecycle

1. Resolve include paths into Dart files.
2. Partition files into reportable and supplementary sets using exclude globs.
3. Resolve both sets with `package:analyzer`.
4. Dispatch enabled `AnalyzerRule` implementations for reportable files.
5. Dispatch enabled `MultiFileAnalyzerRule` implementations with all resolved
   files and the reportable subset.
6. Suppress nested unused-rule findings inside files already reported by
   `unused_source_file`.
7. Return the accumulated diagnostics to the caller.

Supplementary files are excluded from diagnostics, but they are still resolved.
That lets generated files and other excluded sources contribute references to
cross-file rules.

## Rule namespaces

`RuleRegistry` keeps single-file and multi-file rules in separate namespaces.
The CLI registers:

```dart
registry.registerMultiFile(UnusedFunctionRule());
registry.register(UnusedClassRule());
registry.registerMultiFile(UnusedSourceFileRule());
```

The built-in rule ids are still unique across both namespaces, which makes CLI
selection and report output straightforward.

## Diagnostic model

Diagnostics are values:

- `ruleId` identifies the rule.
- `message` is the user-facing finding.
- `severity` is `info`, `warning`, or `error`.
- `location` stores absolute file path, UTF-16 offset and length, and one-based
  line/column.
- `correction` optionally describes how to fix the issue.

The CLI exits with status `1` when any diagnostic has `Severity.error`.

## Built-in unused hierarchy

The built-in unused rules form a containment hierarchy:

```text
unused_source_file
  unused_class
    unused_function
```

When a source file is unreachable, the runner suppresses nested
`unused_class` and `unused_function` findings in that file. When
`unused_function` sees that a member belongs to a private, unreferenced type, it
skips the member because the enclosing type is the better finding.

The result is one coarser diagnostic instead of a pile of duplicate nested
diagnostics.

## Public API boundary

Use:

```dart
import 'package:lintforge/lintforge.dart';
```

The `src/` tree is exported through that entry point for the package's intended
public surface. Internal helpers under `lib/src/rules/unused_function/` are not
exported and should not be used by consumers.
