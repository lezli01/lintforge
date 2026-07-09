# `unused_source_file`

`unused_source_file` flags Dart files in the analyzed set that are unreachable
from any entry point.

| Field | Value |
| ----- | ----- |
| Rule id | `unused_source_file` |
| Default severity | `warning` |
| Dispatch | multi-file |

## What it reports

The rule reports a non-entry-point Dart source file when no entry point can
reach it through `import`, `export`, or `part` directives.

Diagnostics use this shape:

```text
The source file "<path>" is never imported, exported, or used as a part.
```

The correction is:

```text
Remove the file or reference it from an entry point.
```

## Entry points

These files are always considered reachable:

- files under `bin/`
- files under `test/`
- files with a top-level `main`
- files directly under `lib/`

Files nested under `lib/src/` are not entry points unless one of the other entry
point rules applies.

## Reachability edges

The rule follows directives whose resolved target is inside the analyzed set:

- `import`
- `export`
- `part`

Deferred imports count the same as ordinary imports.

Conditional imports and exports contribute an edge for every branch, not just
the branch selected by the current platform:

```dart
import 'io_impl.dart'
  if (dart.library.html) 'web_impl.dart';
```

Both `io_impl.dart` and `web_impl.dart` are treated as reachable when the
directive is reachable.

## Excluded files

Excluded files are not reported, but they still participate in the reachability
graph. For example, an excluded generated file can import a hand-written helper
and keep that helper's file alive.

Generated basenames ending in `.g.dart` and `.freezed.dart` are skipped
defensively even if default excludes are disabled.

## Cross-rule suppression

When this rule reports a file, nested `unused_class` and `unused_function`
diagnostics inside that file are suppressed. A dead file is reported once at the
file level.

## Examples

Flagged:

```text
lib/src/orphan.dart
```

when no entry point imports, exports, or parts it.

Not flagged:

```dart
// lib/my_package.dart
export 'src/public_impl.dart';
```

because `lib/my_package.dart` is an entry point and reaches
`lib/src/public_impl.dart`.

Not flagged:

```dart
// lib/src/used.dart
part 'used_part.dart';
```

because the part file is reachable through its library.

## Sample

See `samples/unused_source_file/` and `samples/all_rules/` for executable
reachability cases.
