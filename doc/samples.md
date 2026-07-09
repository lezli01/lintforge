# Sample Projects

The `samples/` directory contains executable documentation for the built-in
rules. Each sample is a small Dart package that depends on the repository root
through a path dependency.

## Samples

| Path | Purpose |
| ---- | ------- |
| `samples/unused_function/` | Positive and negative cases for `unused_function`. |
| `samples/unused_class/` | Positive and negative cases for `unused_class`. |
| `samples/unused_source_file/` | Reachability cases for `unused_source_file`. |
| `samples/all_rules/` | All built-in rules co-firing in one project. |

Each sample README lists the exact diagnostics that should appear and the cases
that must stay silent.

## Run a sample

From the repository root:

```sh
fvm dart pub get --directory samples/unused_function
fvm dart run lintforge --exclude "*.g.dart" samples/unused_function/lib
```

For the combined sample:

```sh
fvm dart pub get --directory samples/all_rules
fvm dart run lintforge --exclude "*.g.dart" samples/all_rules
```

The sample tests in `test/samples_test.dart` assert the expected diagnostic
sets, so samples are kept in sync with rule behavior.

## How to read the samples

Sample source comments use positive and negative tags:

- `P*` means the declaration or file must be flagged.
- `N*` means the declaration or file must not be flagged.

The all-rules sample also demonstrates cross-rule suppression: an unreachable
file is reported once by `unused_source_file`, and the unused class/function
declarations inside it are suppressed.
