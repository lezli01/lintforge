# Built-In Rules

LintForge currently ships three default-on rules. All built-in diagnostics use
`Severity.warning`.

| Rule | Dispatch | Summary |
| ---- | -------- | ------- |
| [`unused_function`](unused-function.md) | multi-file | Flags unreferenced function-shaped declarations across the analyzed set. |
| [`unused_class`](unused-class.md) | single-file | Flags private class-like declarations that are never referenced in their unit. |
| [`unused_source_file`](unused-source-file.md) | multi-file | Flags Dart files that are unreachable from package entry points. |

List the rules installed in the CLI:

```sh
lintforge --list-rules
```

Run one rule:

```sh
lintforge --rules unused_source_file
```

Run multiple rules:

```sh
lintforge --rules unused_class,unused_function
```

## Rule interaction

The unused rules intentionally avoid duplicate nested findings:

```text
unused_source_file
  unused_class
    unused_function
```

If a whole file is unreachable, `unused_source_file` reports the file and the
runner suppresses unused type/member findings inside it.

If a private type is unreferenced, `unused_function` skips its members because
`unused_class` is the better finding for that unit of dead code.

This keeps reports focused on the largest actionable artifact.

## Excluded files

Files matched by `--exclude` or by the default excludes are non-reportable, but
they are still resolved and can still contribute references. This is important
for generated files such as `*.g.dart` and `*.freezed.dart`.

See [configuration](../configuration.md) for details.
