# LintForge Documentation

LintForge is a standalone static-analysis tool and a small framework for
writing Dart and Flutter analysis rules as plain Dart classes. The command-line
tool ships with default-on `unused_*` rules, while the package API lets teams
assemble their own rule registry and runner.

This documentation is the thorough reference for using and extending the tool.
The repository root README stays as the project overview.

## User guide

- [Getting started](getting-started.md) - install the command, run it locally,
  and add it to CI.
- [CLI reference](cli.md) - command syntax, options, output, color handling, and
  exit codes.
- [Configuration](configuration.md) - include paths, excludes, rule selection,
  and how excluded files still participate as references.
- [Built-in rules](rules/README.md) - the rule catalog and interaction model.
- [Sample projects](samples.md) - executable examples for every built-in rule.

## Extending LintForge

- [Custom rules](custom-rules.md) - implement `AnalyzerRule` and
  `MultiFileAnalyzerRule` with the public API.
- [Architecture](architecture.md) - how the registry, runner, contexts,
  diagnostics, reporters, and built-in rules fit together.

## Quick start

Install the CLI once:

```sh
dart pub global activate lintforge
```

Analyze the current package:

```sh
lintforge
```

Run only one rule:

```sh
lintforge --rules unused_function
```

List the registered rules:

```sh
lintforge --list-rules
```

When no paths are provided, LintForge analyzes `lib/`, `bin/`, and `test/`.
The default rules are `unused_function`, `unused_class`, and
`unused_source_file`, all emitted as warnings.
