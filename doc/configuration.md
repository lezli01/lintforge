# Configuration

The standalone CLI is configured through command-line flags. Programmatic
runners use `LintforgeOptions`.

## Defaults

The CLI builds the equivalent of:

```dart
const LintforgeOptions.defaults();
```

That means:

- include paths: `lib`, `bin`, `test`
- default excludes: `*.g.dart`, `*.freezed.dart`, `**/.dart_tool/**`,
  `**/build/**`
- enabled rules: empty set, which means every registered rule

## Include paths

CLI path arguments replace the default include paths:

```sh
lintforge packages/app/lib packages/app/test
```

Programmatically:

```dart
final options = LintforgeOptions(
  includePaths: ['packages/app/lib', 'packages/app/test'],
);
```

Each include can be a file, directory, or glob. Directories are searched
recursively for `.dart` files.

## Excludes are report filters

An excluded file is still discovered, parsed, and resolved. It is only removed
from the set of files that may receive diagnostics.

This behavior matters for generated code:

```dart
// lib/src/handlers.dart
String formatGreeting(String name) => 'Hi $name';
```

```dart
// lib/src/handlers.g.dart
String greet(String name) => formatGreeting(name);
```

With the default `*.g.dart` exclude, `handlers.g.dart` is non-reportable, but
its reference to `formatGreeting` still counts. `unused_function` therefore
keeps the hand-written function alive.

The same principle applies to import graphs. An excluded file can import a
non-excluded file and keep it reachable for `unused_source_file`.

## Disabling default excludes

Use `--no-default-excludes` when you want every discovered Dart file to be
reportable unless matched by your own excludes:

```sh
lintforge --no-default-excludes
```

Pair it with explicit excludes for a custom policy:

```sh
lintforge --no-default-excludes --exclude "**/tool/generated/**"
```

Programmatically, pass your own `excludePaths`:

```dart
final options = LintforgeOptions(
  excludePaths: ['**/tool/generated/**'],
);
```

## Rule selection

The CLI selects rules by id:

```sh
lintforge --rules unused_function,unused_class
```

Programmatically, `enabledRuleIds` has the same meaning. An empty set enables
every rule in the registry:

```dart
final options = LintforgeOptions(
  enabledRuleIds: {'unused_function'},
);
```

## Recommended policy

For most projects:

```sh
lintforge
```

For noisy adoption on a large existing project:

```sh
lintforge --rules unused_source_file
lintforge --rules unused_class
lintforge --rules unused_function
```

This lets you review one category at a time while keeping the same analyzer
resolution behavior.
