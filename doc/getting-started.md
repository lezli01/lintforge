# Getting Started

LintForge is published as a globally activated Dart executable. You install it
once, then point it at any Dart or Flutter project you want to analyze.

## Install

```sh
dart pub global activate lintforge
```

The command installs a `lintforge` executable into your pub global cache
(`~/.pub-cache/bin` on macOS/Linux and the equivalent pub cache bin directory on
Windows). Make sure that directory is on `PATH`.

To upgrade, run the same command again:

```sh
dart pub global activate lintforge
```

To pin a specific version:

```sh
dart pub global activate lintforge 0.4.1
```

## Run

From a project root:

```sh
lintforge
```

With no explicit paths, LintForge analyzes these directories when they exist:

- `lib/`
- `bin/`
- `test/`

You can also pass files, directories, or glob patterns:

```sh
lintforge lib test
lintforge lib/src/some_file.dart
lintforge "packages/*/lib"
```

## Interpret results

LintForge groups diagnostics by file and prints each finding with:

- severity
- line and column
- rule id
- message
- optional correction hint

A clean run prints `No issues found`.

Warnings do not fail the process. The CLI exits non-zero only when an enabled
rule emits an `error` diagnostic, or when command-line parsing fails.

## Typical CI usage

Add a CI step after dependencies are restored:

```sh
dart pub global activate lintforge
lintforge
```

If the repository uses FVM for its own commands, keep using FVM for package
setup and tests, but the published `lintforge` executable remains a standalone
tool:

```sh
fvm dart pub get
dart pub global activate lintforge
lintforge
```

## Next steps

- Use [the CLI reference](cli.md) for all flags and exit codes.
- Use [configuration](configuration.md) for rule selection and exclude behavior.
- Read [the built-in rules reference](rules/README.md) for exact rule coverage.
