<p align="center">
  <img src="https://raw.githubusercontent.com/lezli01/lintforge/master/.github/assets/lintforge-mark.png" alt="LintForge logo" width="96">
</p>

<h1 align="center">LintForge</h1>

<p align="center">
  <strong>Pluggable static analysis for Dart &amp; Flutter — write custom lint rules as plain Dart classes.</strong>
</p>

<p align="center">
  Rule contracts, a registry, a multi-file runner, built-in <code>unused_*</code> rules, and a CLI —<br>
  so teams can enforce project-specific checks without writing a full analyzer plugin.
</p>

<p align="center">
  <a href="https://github.com/lezli01/lintforge/actions/workflows/ci.yml"><img src="https://github.com/lezli01/lintforge/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/lezli01/lintforge/releases"><img src="https://img.shields.io/github/v/release/lezli01/lintforge?sort=semver" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <a href="https://www.buymeacoffee.com/lezli01"><img src="https://img.shields.io/badge/Buy_Me_a_Coffee-ffdd00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee"></a>
</p>

<p align="center">
  <a href="#why-lintforge">Why</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#cli-usage">CLI</a> &bull;
  <a href="#built-in-rules">Rules</a> &bull;
  <a href="#custom-rules">Custom Rules</a> &bull;
  <a href="#contributing">Contributing</a>
</p>

---

## Why LintForge?

Adding a custom static check to a Dart or Flutter project usually means authoring
a full analyzer plugin: a separate package, a plugin isolate, the analyzer plugin
protocol, and a release cycle of its own. That is a lot of ceremony for "flag this
one project-specific pattern."

LintForge is the lighter alternative — a framework that supplies the contracts, a
rule registry, a single-file and multi-file runner, and a CLI, so a custom rule is
just a plain Dart class that inspects a fully resolved AST and yields diagnostics.
It ships with a growing set of built-in `unused_*` rules, and because it is itself
a static-analysis package it holds itself to the same bar: it lints cleanly,
follows Effective Dart, and never ships a rule it does not pass.

It is released under the [MIT License](LICENSE) and created by `lezli01` at
[lezli01.is-a.dev](https://lezli01.is-a.dev). Contributions are welcome — see
[Contributing](#contributing).

## Features

Point LintForge at a package and it treats writing and running custom analysis as
first-class, plain-Dart work:

- **Rules as plain Dart classes.** Implement `AnalyzerRule` for file-local checks
  or `MultiFileAnalyzerRule` for cross-file ones, register it, and run — no
  analyzer-plugin package, protocol, or isolate to stand up.
- **Resolved AST, not text.** Rules run over fully resolved `package:analyzer`
  compilation units, so they can follow types, inheritance, and references across
  files instead of grepping source.
- **Built-in unused-code rules.** Ships `unused_function`, `unused_class`, and
  `unused_source_file` enabled by default, with a `--rules` flag to narrow the set.
- **Language-feature aware.** The bundled rules account for extensions, extension
  types, mixins, records, patterns, cascades, tear-offs, operator overloads,
  super-parameter forwarding, `noSuchMethod`, `dart:mirrors`, conditional and
  deferred imports, and `@pragma('vm:entry-point')`.
- **A standalone CLI.** Installed once with `dart pub global activate`, the
  `lintforge` command analyzes `lib/`, `bin/`, and `test/` of any project by
  default — no `dev_dependency`, no `pubspec.yaml` changes in the projects you
  lint — with `--rules`, `--exclude`, `--list-rules`, and sensible default
  excludes for generated files and build caches.
- **Reference-aware excludes.** Excluded files (such as `*.g.dart`) are still
  parsed and resolved, so references from generated code keep hand-written
  declarations alive — they just never receive diagnostics themselves.
- **Containment-aware reporting.** The three unused rules form a file → type →
  member hierarchy and suppress nested findings, so a dead artifact is reported
  once at the coarsest level instead of accruing per-declaration noise.

## Installation

LintForge is a **standalone command-line tool**. Install it once and run it
against any Dart or Flutter project — you do **not** add it to that project's
`pubspec.yaml`:

```sh
dart pub global activate lintforge
```

This installs a `lintforge` executable into `~/.pub-cache/bin`. Make sure that
directory is on your `PATH` (see the
[pub global path setup](https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path)).
Re-run the same command to update; append a version to pin one:

```sh
dart pub global activate lintforge <version>
```

> **Writing custom rules?** LintForge can also be consumed as a library so you
> can register your own `AnalyzerRule` / `MultiFileAnalyzerRule` classes and run
> them from a small entrypoint of your own — see [Custom Rules](#custom-rules).

## CLI Usage

Run the analyzer against the current project:

```sh
lintforge [options] [paths...]
```

<p align="center">
  <img src="https://raw.githubusercontent.com/lezli01/lintforge/master/.github/assets/lintforge-cli.png" alt="Example LintForge CLI output reporting unused_function, unused_class, and unused_source_file findings with file locations" width="820">
</p>

When no paths are provided, LintForge inspects `lib/`, `bin/`, and `test/`.

Options:

- `--help`, `-h`: print usage and exit.
- `--version`: print the package version and exit.
- `--list-rules`: print every registered rule with its id, severity, and
  description, then exit.
- `--rules <id,id,...>`: run only the listed rule ids.
- `--exclude <glob>`: exclude matching paths. Repeat for multiple patterns.
  Custom excludes are added on top of the built-in defaults.
- `--no-default-excludes`: disable the built-in default exclude patterns.
  Use `--exclude` to list any patterns you still want excluded.
- `--color` / `--no-color`: force colored output on or off. When omitted,
  color is auto-detected — enabled only for an interactive terminal, and
  disabled when the output is piped or redirected, when `NO_COLOR` is set,
  or when `TERM=dumb`. `FORCE_COLOR` forces it on. An explicit flag always
  wins over the environment.

By default, LintForge excludes generated files and tool/build caches that
consumer projects almost never want to lint: `*.g.dart`, `*.freezed.dart`,
`**/.dart_tool/**`, and `**/build/**`. The two directory patterns mirror
the canonical Dart/Flutter ignore set, so running LintForge against a project
root will not flag Flutter-generated registrants under `.dart_tool/` or
build artefacts under `build/`. Exclude patterns are matched against the
file's basename, its path relative to the current working directory, and
its absolute path; any match excludes the file. To opt out of the defaults
entirely:

```sh
lintforge --no-default-excludes
```

List the rules shipped with LintForge — each entry shows the rule id,
severity, and a one-line description, one rule per line:

```sh
lintforge --list-rules
```

Exit codes:

- `0`: no diagnostics with `Severity.error`.
- `1`: at least one error diagnostic was emitted.
- `64`: command-line usage error.

### Output

LintForge groups findings by file and lays them out in aligned
`severity  line:col  rule  message` columns, with any correction hint on a
continuation line beneath the message. The report ends with a one-line
summary — for example `✖ 3 issues found  (1 error, 2 warnings)  in 2 files`,
or `✓ No issues found` for a clean run.

```text
lib/unused_class_sample.dart
  warning  13:7   unused_class  The class "_Foo" is declared but never used.
                                ↳ Remove "_Foo" or reference it.
  warning  16:7   unused_class  The mixin "_Bar" is declared but never used.
                                ↳ Remove "_Bar" or reference it.

⚠ 2 issues found  (2 warnings)  in 1 file
```

When writing to an interactive terminal the report is colorized (severities
in color, secondary detail dimmed, file headers bold) and left as plain text
when piped or redirected, so captured output stays clean and diffable. Color
follows the `NO_COLOR` / `FORCE_COLOR` conventions and can be forced either
way with `--color` / `--no-color`.

While analysis runs, a live progress indicator (a spinner, a progress bar,
and the file being resolved) is drawn to **stderr** whenever stderr is an
interactive terminal, and erased before the results are printed — so it
never pollutes the diagnostics written to stdout.

## Excluded Files as Reference Sources

`--exclude` (and `excludePaths` in `LintforgeOptions`) suppresses **diagnostic
reporting** for matched files. It does **not** remove them from analysis:
the runner still discovers, parses, and resolves every excluded file
through `package:analyzer` and feeds the resulting compilation unit into
the multi-file reference and reachability graph. Excluded files
participate in cross-file analysis as ordinary sources — they simply
never receive diagnostics themselves and are not dispatched to
single-file rules.

For example, with the default `*.g.dart` exclude in effect:

```dart
// lib/src/handlers.dart  (reportable)
String formatGreeting(String name) => 'Hi $name';
```

```dart
// lib/src/handlers.g.dart  (excluded — not reported on)
String greet(String name) => formatGreeting(name);
```

`handlers.g.dart` is excluded, so it can never be flagged. But the
runner still resolves it, so the call to `formatGreeting` is recorded
as a real reference: `unused_function` sees `formatGreeting` as used
and does not flag it, even though its only caller lives in an excluded
file.

Per built-in rule:

- **`unused_function`** — references in excluded files count as uses
  of candidate declarations in the reportable set. Generated companions
  (`*.g.dart`, `*.freezed.dart`, …) that call into hand-written code
  legitimately keep those declarations alive without producing false
  positives.
- **`unused_source_file`** — excluded files act as both edge sources
  and edge targets in the reachability graph: an excluded file's
  `import` / `export` / `part` directives can mark non-excluded files
  as reached, and a non-excluded file can reach an excluded one.
  Excluded files are never themselves reported as unused, regardless of
  whether anything in the analyzed set imports them.
- **`unused_class`** — file-local. The rule only inspects references
  within the same compilation unit, so excluded-files-as-references has
  no effect beyond the standard "excluded files are never reported on"
  guarantee.

## Built-In Rules

LintForge ships with the following rules enabled by default. To turn one off, pass
`--rules` with a list that omits it.

### `unused_function`

- **Id:** `unused_function`
- **Default severity:** `warning`
- **Dispatch:** multi-file (registered via `registerMultiFile`); the rule sees
  every resolved compilation unit in the analyzed set on a single invocation
  and resolves references across files.

Flags function-shaped declarations that are never referenced anywhere in the
analyzed file set:

- top-level functions — private (name begins with `_`) unconditionally, and
  public when the file lives under a package's `lib/src/` directory and is
  never referenced from outside it;
- top-level getters and setters, with the same privacy + `lib/src/` rule as
  top-level functions;
- local function declarations inside another function or method body;
- constructors on classes and enums (generative, named, factory, and
  redirecting forms);
- instance and `static` methods on classes, mixins, enums, and extension
  types;
- getters, setters, and operators declared on classes, mixins, enums, and
  extension types;
- methods, `static` methods, getters, setters, and operators declared inside
  `extension Foo on T {}` blocks.

Direct calls, tear-offs, named-type references, constructor invocations and
redirects, operator and index expressions, explicit member accesses, and
setter writes all count as a use. The rule is feature-aware: it also
follows Dart 3 object-pattern destructures (`final Foo(:getter) = …`),
record literals and record patterns (`(obj.getter,)` / `final (g,) = …`),
cascade sections (`obj..foo()`), and the implicit `.call` invocation on
callable objects (`instance()` resolves to `instance.call()`), so members
reached only through any of those forms are correctly counted as used.
Super-parameter forwarding (Dart 2.17+, `class B extends A { B({super.x}); }`)
counts as a use of the supertype constructor even though the AST has no
`super(...)` call node — the rule reads the implicit super-constructor
target off the resolved constructor element. The same applies to the
synthetic default constructor inserted when a class declares no
constructor of its own (`class B extends A {}` is a use of `A.new`).
Parameterised-enum value declarations
(`enum Route { home('/'); const Route(this.path); final String path; }`)
implicitly invoke the enum's constructor at const-evaluation time, but
the AST does not model that as an `InstanceCreationExpression` /
`ConstructorName`. The rule reads the constructor target off
`EnumConstantDeclaration.constructorElement`, so the enum's constructor
counts as referenced once per declared value.
Both the global reference set and the candidate set are projected
through `Element.baseElement` before lookup, so members declared on a
generic base class (`class Box<T> { void put(T v) {} }`) match call
sites that resolve through a substituted view of the same declaration
(`IntBox().put(0)` where `IntBox extends Box<int>`), and the same
applies to factory constructors on generic sealed classes
(`Holder<int>.value(0)`).
Overrides of reachable supertype members are treated as uses: when a
`MethodDeclaration` overrides an inherited supertype member that is
either declared outside the analyzed unit set (`dart:*`,
`package:flutter`, any package outside the run) or is itself in the
global reference set, the override is exempt. No explicit `@override`
annotation is required — a declaration that shadows a supertype member
is an override whether or not it is annotated, and framework callbacks
(`State.createState`, `Widget.createElement`, lifecycle hooks) are
routinely written without it. The overridden member is resolved via the
inheritance graph with a by-name fallback across the full
`extends` / `with` / `implements` / `on` chain, so this applies
uniformly to methods, operators, getters, and setters and covers
framework callback overrides (`State.build`, `Object.toString`,
`operator ==`, …) as well as in-repo abstract-base / concrete-subtype
dispatch.

Deliberately not flagged:

- the library's `main` function;
- public top-level functions, getters, and setters declared outside
  `lib/src/` (i.e. the package's public surface);
- public instance/static methods, getters, setters, and operators of a
  public type (class, mixin, enum, extension type, or `extension` block)
  declared outside `lib/src/` — these form the package's consumable public
  API surface, reachable by external consumers and exercised by tests, so
  "no references found in the analyzed set" cannot prove them unused.
  Private members, and members of private types, are still flagged;
- declarations and members in the *non-selected* branch file of a
  conditional export or import (`export 'stub.dart' if (dart.library.html)
  'web.dart';`) — the analyzer resolves each directive to a single branch
  per build target, but every `if (…)` configuration branch is a real
  reference, so members reachable only through a non-selected branch are
  exempt rather than flagged as dead;
- `external` declarations of any shape;
- declarations annotated with `@pragma('vm:entry-point')`;
- top-level functions, getters, and setters declared in a library that has
  `part` files (a sibling part could legitimately reference them, and the
  rule does not currently traverse part libraries);
- every member and constructor of a class whose supertype chain
  (`extends` / `with` / `implements`) declares its own `noSuchMethod` —
  that override can service any selector at runtime, so members reached
  only through it have no static reference. The walk also recognises
  `package:mocktail`'s `Fake` and `Mock` base classes by simple name,
  since the analyzed sources typically do not pull the mocktail library
  in as a resolved dependency;
- every member and constructor declared in a library that imports
  `dart:mirrors` — reflection can invoke arbitrary members by name, so the
  rule conservatively skips the whole unit;
- every declaration in a unit stamped with the de-facto generated-code
  marker `// ignore_for_file: type=lint` at the top of the file — Flutter's
  `flutter gen-l10n` writes this line into the synthetic `L` base class and
  every per-locale `output-localization-file` subclass it emits, and other
  build-time Dart codegen tools follow the same convention, so the rule
  treats the marker as a "this file is generated, do not flag" signal and
  skips every candidate collector for the unit;
- members of a private, unreferenced class, mixin, enum, extension type, or
  extension — `unused_class` already flags the enclosing declaration, so
  re-flagging every member would just repeat the report;
- every declaration in a file `unused_source_file` reports as unreachable —
  the whole file is already flagged, so listing each function inside it would
  just repeat the report (see [Rule interaction](#rule-interaction)).

### `unused_class`

- **Id:** `unused_class`
- **Default severity:** `warning`

Flags file-local declarations whose names begin with `_` that are never
referenced within the same compilation unit:

- `class` declarations (including `abstract`, `base`, `final`, `sealed`,
  and `interface` modifiers);
- `mixin` declarations;
- `enum` declarations;
- `extension type` declarations.

Any reference to the declaration counts as a use, including type
annotations, constructor invocations, `extends`/`implements`/`with`/`on`
clauses, `is`/`as` checks, static-member access, enum-value access, and
constructor or static tear-offs. The rule is Dart 3 feature-aware: it
also follows Dart 3 object patterns (`case _Foo()` in a `switch`),
record type annotations (`(_Foo, int)`), and exhaustive `switch` on a
`sealed` supertype — so a private type referenced only through its
subtypes' pattern arms is correctly treated as used.

Deliberately not flagged in this release:

- public top-level classes, mixins, enums, and extension types;
- `class _Foo = A with B;` typedef-style class declarations
  (`ClassTypeAlias`);
- `extension` declarations (the non-type `extension _Ext on T {}` form);
- declarations annotated with `@pragma('vm:entry-point')`;
- any private candidate declared in a library that imports
  `dart:mirrors` — reflection can name arbitrary types at runtime, so
  the rule conservatively skips the whole unit;
- files belonging to libraries that have `part` files;
- types declared in a file `unused_source_file` reports as unreachable —
  the whole file is already flagged, so re-flagging each type inside it would
  just repeat the report (see [Rule interaction](#rule-interaction)).

### `unused_source_file`

- **Id:** `unused_source_file`
- **Default severity:** `warning`

A cross-file rule that flags Dart source files in the analyzed set that
are never reached from any entry point. Reachability is computed by
walking `import`, `export`, and `part` directives whose resolved URI
lands inside the analyzed set; URIs that resolve to `dart:` libraries,
package dependencies, or files excluded from the run are ignored. For
conditional imports (`import 'x' if (dart.library.io) 'y'`), every
`if (...)` configuration contributes a reachability edge regardless of
the active platform — both alternatives stay reachable in a single
analysis run. Deferred imports (`import 'x' deferred as p`) are
followed identically to ordinary imports.

Entry points (always considered "reached") are:

- files under `bin/`;
- files under `test/`;
- files that declare a top-level `main` function;
- `lib/<package>.dart` and any other file sitting directly under `lib/`
  (i.e. not nested inside a subdirectory such as `lib/src/`), which
  together form the package's public surface.

A non-entry-point file counts as "used" if it is reachable, directly or
transitively, from an entry point via an `import`, `export`, or `part`
directive — including every configuration of a conditional import and
the target of a deferred import.

Deliberately not flagged in this release:

- entry-point files themselves (files under `bin/` or `test/`, files
  with a top-level `main`, and `lib/*.dart` files outside `lib/src/`);
- any file reached, directly or transitively, by an `import`, `export`,
  or `part` directive from an entry point — including every
  configuration of a conditional import and the target of a deferred
  import;
- generated-file basenames such as `*.g.dart` and `*.freezed.dart`,
  which are skipped defensively even if the runner's default excludes
  are turned off.

### Rule interaction

The three "unused" rules form a containment hierarchy — a source file
contains types, a type contains members:

```
unused_source_file   (whole file)
  └── unused_class    (whole type)
        └── unused_function   (member / constructor)
```

When a finding fires at an outer level, the levels nested inside it are
**suppressed** rather than reported again, so a dead artifact is reported
once at the coarsest level instead of accruing a pile of per-declaration
warnings:

- a file flagged by `unused_source_file` swallows any `unused_class` and
  `unused_function` findings inside it — the file is reported once, not once
  per declaration;
- a private, unreferenced type flagged by `unused_class` swallows the
  `unused_function` findings for its members.

The two tiers are enforced in different places. The **file** tier keys off
`unused_source_file`'s emitted findings, so dropping `unused_source_file`
from `--rules` lets the per-declaration findings inside those files through
again. The **type** tier is computed inside `unused_function` itself (from
whether the enclosing type is a private, unreferenced declaration), so it
stays in effect whether or not `unused_class` is enabled.

## Custom Rules

The standalone `lintforge` CLI runs the built-in rules. To run rules of your
own, consume LintForge as a library instead: add it as a `dev_dependency` in
the project you want to lint, implement `AnalyzerRule`, register it with a
`RuleRegistry`, and pass the registry to `AnalysisRunner` from a small
entrypoint you run with `dart run`:

```dart
import 'package:lintforge/lintforge.dart';

class MyRule extends AnalyzerRule {
  @override
  String get id => 'my_rule';

  @override
  String get description => 'Flags a project-specific pattern.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(AnalysisContext context) sync* {
    // Inspect context.unit and yield Diagnostic instances.
  }
}

Future<void> main() async {
  final registry = RuleRegistry()..register(MyRule());
  const options = LintforgeOptions.defaults();
  final runner = AnalysisRunner(registry: registry, options: options);

  final diagnostics = await runner.run();
  for (final diagnostic in diagnostics) {
    print(diagnostic);
  }
}
```

`AnalyzerRule` is dispatched once per file and remains the right contract
for file-local checks: implementations see a single resolved compilation
unit at a time and cannot observe sibling files.

For checks that must reason across files, implement `MultiFileAnalyzerRule`
instead. A multi-file rule is invoked once per run with the full set of
resolved compilation units, so it can build cross-file structures such as
import graphs or symbol indices. Register multi-file rules with the same
`RuleRegistry` used for `AnalyzerRule` implementations; the built-in
`unused_source_file` rule is implemented this way. Existing `AnalyzerRule`
implementations continue to work unchanged.

## Sample Projects

The [`samples/`](samples/) directory contains live, executable
documentation of each built-in rule: one self-contained Dart/Flutter
package per rule, plus an `all_rules` sample that exercises every
built-in rule together. Each sample path-depends on this package and
ships a `README.md` listing the exact positive (MUST be flagged) and
negative (MUST NOT be flagged) cases for the rule it covers.

| Sample                                                                 | Exercises                                  |
| ---------------------------------------------------------------------- | ------------------------------------------ |
| [`samples/unused_function/`](samples/unused_function/)                 | the `unused_function` rule                 |
| [`samples/unused_class/`](samples/unused_class/)                       | the `unused_class` rule                    |
| [`samples/unused_source_file/`](samples/unused_source_file/)           | the `unused_source_file` multi-file rule   |
| [`samples/all_rules/`](samples/all_rules/)                             | every built-in rule together               |

Run any sample from the repository root, for example:

```sh
fvm dart pub get --directory samples/unused_function
fvm dart run lintforge samples/unused_function/lib
```

## Development

LintForge is a pure-Dart package. This repository uses FVM to pin the SDK
version. Install the configured SDK before working locally:

```sh
fvm install
fvm dart pub get
```

Before opening a pull request, run the same checks as CI:

```sh
fvm dart format .
fvm dart analyze --fatal-infos --fatal-warnings
fvm dart test --coverage=coverage
fvm dart pub publish --dry-run
```

## Project Status

LintForge is pre-1.0.0. The framework — rule contracts, the registry, the
single-file and multi-file runners, the CLI, and the built-in `unused_function`,
`unused_class`, and `unused_source_file` rules — is working today and exercised by
the sample projects under [`samples/`](samples/). Public APIs may still change
between minor versions while the framework matures, so pin a specific version
with `dart pub global activate lintforge <version>` if you need repeatable
behavior. Additional built-in rules,
including broader unused-declaration detection and `const` suggestions, are
planned.

## Contributing

Contributions of every size are welcome — bug reports, docs, new rules, test
cases, and features. LintForge is itself a static-analysis package, so it holds
its own sources to the rules it ships; keeping that bar is part of the work. Start
here:

- Read the [Contributing guide](CONTRIBUTING.md) for development setup (FVM), the
  quality checks expected before a pull request, and the commit-message convention.
- Be a good neighbor: this project follows a
  [Code of Conduct](CODE_OF_CONDUCT.md).
- Have a question or an idea? Open a
  [Discussion](https://github.com/lezli01/lintforge/discussions).
- Found a bug or want a rule? Open an
  [issue](https://github.com/lezli01/lintforge/issues/new/choose).

Releases are automated with
[release-please](https://github.com/googleapis/release-please), so pull requests
use [Conventional Commits](https://www.conventionalcommits.org/) titles. Details
are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

LintForge runs locally as a development dependency: it reads your source, resolves
it with `package:analyzer`, and prints diagnostics. It performs no network access
and never executes the code it analyzes, so its attack surface is small — but
security reports are taken seriously. Please report suspected vulnerabilities
privately via GitHub's private vulnerability reporting for this repository rather
than a public issue. See [SECURITY.md](SECURITY.md) for details.

## License

LintForge is released under the [MIT License](LICENSE). © 2026 lezli01.
