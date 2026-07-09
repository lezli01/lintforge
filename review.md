# LintForge Rule Audit Review

Date: 2026-07-09
Branch: `codex/rule-audit-review`

## Scope

This review covers the currently available built-in rules:

- `unused_function`
- `unused_class`
- `unused_source_file`

The audit checked implementation behavior, rule interaction, CLI behavior,
sample projects, documentation consistency, and test/CI robustness.

## Validation Performed

Passing checks:

- `fvm dart analyze`
- `fvm flutter test test/samples_test.dart --reporter=expanded`
- Focused rule tests:
  - `test/src/rules/unused_function_rule_test.dart`
  - `test/src/rules/unused_class_rule_test.dart`
  - `test/src/rules/unused_source_file_rule_test.dart`
- `fvm dart test -j 1 --reporter=expanded`
- `fvm dart pub publish --dry-run`
- Direct CLI sample runs for `unused_function`, `unused_class`, and
  `all_rules` matched expected findings.

Failing or problematic checks:

- Plain `fvm dart test --reporter=expanded` is not parallel-safe.
- `fvm dart pub get --directory samples/<sample>` fails for all sample
  packages because sample pubspecs depend on Flutter while the root package
  depends on `analyzer >=13.3.0 <14.0.0`, which currently requires
  `meta ^1.18.3`; the pinned Flutter SDK provides `meta 1.18.0`.
- Direct CLI run of `samples/unused_source_file` without a package config
  reports an extra `kept_alive_by_excluded.dart` finding because the sample's
  excluded `bin/dev_tool.g.dart` uses a `package:` self-import that does not
  resolve until `pub get` succeeds.

## Findings

### P1: Public constructors are reported despite the public API policy

Public instance/static methods, getters, setters, operators, and extension
members on public types outside `lib/src/` are exempt as package API surface.
Public named constructors on the same public types are still reported.

Relevant code:

- `lib/src/rules/unused_function/constructor_collector.dart`
- `lib/src/rules/unused_function/class_member_collector.dart`

Why it matters:

Package authors commonly expose named constructors as part of their public API.
Flagging `Service.named()` while exempting `Service.method()` is inconsistent
and can produce false positives for normal package surfaces.

Recommendation:

Apply the same public-member/public-type/outside-`lib/src` exemption to
constructor candidates. Preserve private constructors and `lib/src` constructors
as candidates.

### P1: Private non-type extensions can be completely silent

`unused_function` suppresses members of an unreferenced private `extension`,
assuming the enclosing declaration is handled by `unused_class`. However,
`unused_class` explicitly does not report non-type `extension` declarations.

Relevant code:

- `lib/src/rules/unused_function_rule.dart`
- `lib/src/rules/unused_class_rule.dart`
- `lib/src/rules/unused_function/extension_member_collector.dart`

Observed behavior:

An unused private extension such as:

```dart
extension _PrivateExt on String {
  int hidden() => length;
}
```

can produce no diagnostics.

Recommendation:

Either add non-type extension declaration support to `unused_class`, or stop
suppressing extension members unless an outer rule actually reports private
extensions.

### P1: Sample packages are not executable with the pinned SDK

The sample pubspecs depend on Flutter and `lintforge` by path. With the current
root dependency on analyzer 13.3.0, `pub get` fails because Flutter pins
`meta 1.18.0` and analyzer requires `meta ^1.18.3`.

Relevant files:

- `samples/unused_function/pubspec.yaml`
- `samples/unused_class/pubspec.yaml`
- `samples/unused_source_file/pubspec.yaml`
- `samples/all_rules/pubspec.yaml`
- `doc/samples.md`
- sample `README.md` files

Why it matters:

The samples are advertised as executable documentation. If `pub get` fails, a
new contributor or user cannot reproduce the rule examples as documented.

Recommendation:

Make samples pure Dart packages unless Flutter is required for a specific case.
Remove the Flutter SDK dependency from sample pubspecs and adjust docs to use
`fvm dart pub get --directory ...`.

### P1: Default test run is not parallel-safe

`fvm dart test -j 1` passes, but the default parallel test run can fail because
some tests mutate `Directory.current` while other tests assume the repository
root is still the current working directory.

Relevant code:

- `test/src/analysis_runner_test.dart`
- `test/samples_test.dart`
- `.github/workflows/ci.yml`

Observed failure modes:

- `samples_test.dart` looks for `samples/...` under a temporary test CWD.
- CLI tests can run from the wrong CWD and fail to find `pubspec.yaml`.
- Temp directory cleanup can fail while another analysis context still holds a
  handle.

Recommendation:

Remove process-wide CWD mutation from tests where possible. Prefer absolute
paths and explicit `workingDirectory` for subprocesses. If that is not practical
immediately, configure `dart_test.yaml` or CI to run serially until isolation is
fixed.

### P2: Generated-code policy is inconsistent between rules

`unused_function` skips units stamped with:

```dart
// ignore_for_file: type=lint
```

`unused_source_file` only skips file basenames ending in `.g.dart` or
`.freezed.dart`.

Relevant code:

- `lib/src/rules/unused_function_rule.dart`
- `lib/src/rules/unused_source_file_rule.dart`

Why it matters:

Flutter `gen_l10n` and other code generators can emit files with the
`type=lint` marker but not a `.g.dart` or `.freezed.dart` suffix. Those files
can be reported as unused source files even though they are generated.

Recommendation:

Share a generated-file predicate across the unused rules, or teach
`unused_source_file` to skip top-of-file `ignore_for_file: type=lint` units.

### P2: Unknown `--rules` ids silently produce a clean run

Passing an unknown rule id selects no rules and prints `No issues found` with
exit code 0.

Relevant code:

- `bin/lintforge.dart`
- `doc/cli.md`

Why it matters:

A typo such as `--rules unused_functon` can make CI appear green while no
intended rule ran.

Recommendation:

Validate requested ids against both registry namespaces after the registry is
built. Emit a usage error with exit code 64 for unknown ids, and include
available ids in the message.

### P2: `unused_class` is still much more conservative than `unused_function`

`unused_class` is single-file and deliberately skips:

- class aliases
- non-type extensions
- libraries with parts
- public declarations, including public declarations under `lib/src`

Relevant code:

- `lib/src/rules/unused_class_rule.dart`

Why it matters:

The tool now has a multi-file reference model for `unused_function`, so
`unused_class` may miss dead types that users expect the "unused" family to
catch.

Recommendation:

Consider promoting `unused_class` to a multi-file rule, or add a second broader
type-level rule. At minimum, document the gap prominently and add regression
tests for intended blind spots.

### P3: Conditional branch files are skipped too broadly for `unused_function`

The rule skips every candidate declared in a conditional import/export branch
target file.

Relevant code:

- `lib/src/rules/unused_function_rule.dart`

Why it matters:

This avoids false positives for platform branch public surfaces, but it can
hide genuinely dead private helpers inside those branch files.

Recommendation:

Narrow the exemption to public declarations or exported API surface within
branch files. Continue to exempt platform-facing members that cannot be proven
unused on the current target.

### P3: Nested local functions can duplicate unused outer findings

An unused method containing an unused local function reports both findings.

Why it matters:

The unused rule family already suppresses file-level and type-level duplicate
noise. Executable-level containment would make reports more focused.

Recommendation:

When an enclosing function or method is reported as unused, suppress unused
local function findings nested inside its body.

## Suggested Fix Order

1. Fix public constructor API exemption. **Status: done 2026-07-09.**
2. Fix private extension silence. **Status: done 2026-07-09.**
3. Make samples pure Dart and executable again. **Status: done 2026-07-09.**
4. Fix test isolation or force serial test execution in CI. **Status: done
   2026-07-09.**
5. Share/generated-code detection across unused rules. **Status: done
   2026-07-09.**
6. Validate unknown `--rules` ids.
7. Decide whether `unused_class` should become multi-file.
8. Narrow conditional branch suppression.
9. Add executable-level nested suppression for local functions.

## Implementation Progress

- 2026-07-09: Completed item 1. Public constructors on public types outside
  `lib/src/` now use the same API-surface exemption as public methods,
  getters, setters, operators, and extension members. Private constructors,
  constructors on private types, and public constructors under `lib/src/`
  remain candidates.
- Validation: `fvm dart analyze`; focused unused-function tests; canonical
  sample test; direct sample CLI probe; full serial `fvm dart test -j 1`.
  The direct `samples/unused_source_file` run still shows the known
  package-config-related extra finding already tracked by item 3.
- 2026-07-09: Completed item 2. Limited duplicate suppression in
  `unused_function` to private unreferenced type declarations that
  `unused_class` actually reports, so members of private non-type
  `extension` declarations now produce `unused_function` diagnostics.
  Updated the focused regression test and sample expectations for the
  existing private extension member examples.
- Validation: `fvm dart analyze`; focused extension-member test; all
  unused-function tests; `test/samples_test.dart`; direct CLI sample runs for
  `samples/unused_class` and `samples/all_rules`; full serial
  `fvm dart test -j 1 --reporter=expanded`.
- 2026-07-09: Completed item 3. Removed the Flutter SDK constraint and
  dependency from all sample pubspecs, regenerated the sample lockfiles as
  pure Dart package graphs, and updated sample READMEs to use
  `fvm dart pub get --directory ...`.
  Synchronized the `unused_function` sample documentation and comments with
  the current public-API exemption behavior while preserving the expected
  sample diagnostics.
- Validation: `fvm dart pub get --directory` for all four sample packages;
  `fvm dart analyze`; `fvm flutter test test/samples_test.dart
  --reporter=expanded`; direct CLI probes for `samples/unused_function`,
  `samples/unused_class`, `samples/unused_source_file`, and
  `samples/all_rules` reported the expected 6, 5, 1, and 12 diagnostics.
- 2026-07-09: Completed item 4. Removed the process-wide
  `Directory.current` mutations from the `AnalysisRunner`
  exclude/default-exclude test fixtures so parallel test files no longer
  inherit a temporary working directory while sample tests are resolving
  `samples/...`. The runner now also matches exclude patterns against each
  discovered file's path relative to the include root that found it, preserving
  default `.dart_tool/` and `build/` exclusions for absolute include paths
  without changing the process CWD.
- Validation: focused parallel runner/sample tests; `fvm dart analyze`; plain
  parallel `fvm dart test --reporter=expanded`; `fvm flutter test`.
- 2026-07-09: Completed item 5. Added a shared generated-source predicate for
  conventional generated Dart basenames and top-of-file
  `// ignore_for_file: type=lint` markers, and wired both unused rules to use
  it. `unused_source_file` now skips generated files that do not use a
  generated basename, while `unused_function` also shares the defensive
  basename skip when generated outputs are reportable. Added an
  `unused_source_file` regression covering an orphan generated file without a
  generated basename.
- Validation: `fvm dart format` on touched Dart files; `fvm dart analyze`;
  focused `unused_source_file` and `unused_function` tests; full
  `fvm flutter test`.

## Notes

This review document now tracks both the original audit findings and the
implementation progress for follow-up fixes on this branch.
