# CLI Reference

The LintForge command analyzes Dart source files and prints diagnostics.

```sh
lintforge [options] [paths...]
```

When `paths...` is omitted, the command uses `lib/`, `bin/`, and `test/`.

## Options

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Print usage and exit. |
| `--version` | Print the package version and exit. |
| `--list-rules` | Print each registered rule id, severity, and description, then exit. |
| `--rules <id,id,...>` | Enable only the listed rule ids. When omitted, every registered rule is enabled. |
| `--exclude <glob>` | Exclude a glob from diagnostic reporting. May be passed multiple times. |
| `--no-default-excludes` | Disable the built-in default exclude patterns. |
| `--color` | Force ANSI color on. |
| `--no-color` | Force ANSI color off. |

## Path arguments

Each path argument can be:

- a Dart file
- a directory, searched recursively for `.dart` files
- a glob pattern, evaluated relative to the current working directory

All discovered paths are normalized and sorted before rules run, which keeps
reports deterministic.

## Default excludes

By default, these patterns are excluded from diagnostics:

```text
*.g.dart
*.freezed.dart
**/.dart_tool/**
**/build/**
```

Custom excludes layer on top of these defaults:

```sh
lintforge --exclude "**/*.config.dart"
```

To take full control, disable the defaults:

```sh
lintforge --no-default-excludes --exclude "**/generated/**"
```

Exclude patterns are matched against:

- the file basename
- the path relative to the current working directory
- the absolute path

Any match makes the file non-reportable. See [configuration](configuration.md)
for the important distinction between non-reportable files and files that are
not analyzed at all.

## Rule selection

Run every built-in rule:

```sh
lintforge
```

Run only `unused_function`:

```sh
lintforge --rules unused_function
```

Run two rules:

```sh
lintforge --rules unused_class,unused_source_file
```

Unknown ids simply select no matching rule; use `--list-rules` to inspect the
available ids.

## Color and progress

When output is connected to an interactive terminal, diagnostics are colorized.
When output is piped or redirected, diagnostics are plain text.

Color auto-detection honors:

- `NO_COLOR` - disables color
- `TERM=dumb` - disables color
- `FORCE_COLOR` - enables color

Explicit `--color` and `--no-color` flags take precedence over environment
variables.

The live progress indicator is written to stderr only when stderr is an
interactive terminal. It is cleared before diagnostics are printed, so stdout
stays suitable for capture.

## Output format

Diagnostics are grouped by file and aligned in columns:

```text
lib/example.dart
  warning  13:7   unused_class  The class "_Foo" is declared but never used.
                                -> Remove "_Foo" or reference it.

1 issue found  (1 warning)  in 1 file
```

Clean runs print:

```text
No issues found
```

## Exit codes

| Code | Meaning |
| ---- | ------- |
| `0` | The run completed and emitted no `Severity.error` diagnostics. Warning-only runs exit `0`. |
| `1` | At least one diagnostic had `Severity.error`. |
| `64` | Command-line parsing failed. |

The current built-in rules emit warnings, so they do not fail the process by
severity. Custom rule runners can emit `Severity.error` diagnostics through the
public API.
