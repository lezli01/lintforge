# Changelog

## Unreleased

### Changed

- Promoted `unused_class` to multi-file analysis so private class-like
  declarations can be kept alive by references from sibling `part` files while
  still reporting only on files eligible for diagnostics.
- Narrowed `unused_function` conditional branch exemptions to public branch
  API, so private helpers in branch files can still be reported.
- Suppressed `unused_function` local-function diagnostics nested inside an
  unused enclosing executable already reported by the rule.

### Fixed

- Kept public enum constructors eligible for `unused_function` diagnostics when
  no enum value invokes them.

## [0.4.1](https://github.com/lezli01/lintforge/compare/v0.4.0...v0.4.1) (2026-07-08)


### Bug Fixes

* **unused_function:** exempt freezed underscore constructors ([c79c95c](https://github.com/lezli01/lintforge/commit/c79c95c12e5a63d7270c2de59fa6836e86276f77))
* **unused_function:** exempt freezed underscore constructors ([#52](https://github.com/lezli01/lintforge/issues/52)) ([584e2c4](https://github.com/lezli01/lintforge/commit/584e2c428b799d8e074729f48a7948bc06fc18f8))

## [0.4.0](https://github.com/lezli01/lintforge/compare/v0.3.9...v0.4.0) (2026-07-07)


### ⚠ BREAKING CHANGES

* from dependency to standalone tool

### Features

* **cli:** run lintforge as a standalone globally-activated tool ([5377881](https://github.com/lezli01/lintforge/commit/53778814b8742bc1826eba4128c939ad97d10ac7))
* **cli:** run lintforge as a standalone globally-activated tool ([#49](https://github.com/lezli01/lintforge/issues/49)) ([4f584c3](https://github.com/lezli01/lintforge/commit/4f584c39a2a0d2a783dab8abb7a3d7a6fb097a55))
* from dependency to standalone tool ([f65781e](https://github.com/lezli01/lintforge/commit/f65781e3ad3d5e29f829847320a3ba5ad81e377e))

## [0.3.9](https://github.com/lezli01/lintforge/compare/v0.3.8...v0.3.9) (2026-07-04)


### Features

* **cli:** colorize output, align findings, and show live progress ([7b6ee95](https://github.com/lezli01/lintforge/commit/7b6ee95564c4ad2077da8fff1bfff0de5e91155c))
* **cli:** colorize output, align findings, and show live progress ([#46](https://github.com/lezli01/lintforge/issues/46)) ([b51c75d](https://github.com/lezli01/lintforge/commit/b51c75ddbb7ddbccbe2560e8de551d1535c88e62))

## [0.3.8](https://github.com/lezli01/lintforge/compare/v0.3.7...v0.3.8) (2026-05-29)


### Features

* **cli:** add --list-rules option to print registered rules ([fdcd0e4](https://github.com/lezli01/lintforge/commit/fdcd0e4bc5a730dbd8b4ba501522ff215855f84e))
* **cli:** add --list-rules option to print registered rules ([#31](https://github.com/lezli01/lintforge/issues/31)) ([2761611](https://github.com/lezli01/lintforge/commit/276161180feacde0dcbb041817d89ffab736ab9b))
* hardening unused functions ([#35](https://github.com/lezli01/lintforge/issues/35)) ([251e696](https://github.com/lezli01/lintforge/commit/251e6962300ba1d00efc2e68ab84cfe20ea5aee5))
* **unused_function:** exempt constructors of freezed-annotated classes ([ff79b39](https://github.com/lezli01/lintforge/commit/ff79b39ee12ac59b2a28e826898cca3fc888f591))
* **unused_function:** exempt constructors of freezed-annotated classes ([#34](https://github.com/lezli01/lintforge/issues/34)) ([1ef7ca2](https://github.com/lezli01/lintforge/commit/1ef7ca2da88ac530f1bd87ea675e053791ff1870))
* **unused:** suppress nested findings inside unused source files ([c972e32](https://github.com/lezli01/lintforge/commit/c972e327cc6e6a9567998f56a7910899766e1050))
* **unused:** suppress nested findings inside unused source files ([#36](https://github.com/lezli01/lintforge/issues/36)) ([4a84f2c](https://github.com/lezli01/lintforge/commit/4a84f2c4c81dfacfa1544ffb94e41fa2816939fb))


### Bug Fixes

* **runner:** exclude .dart_tool/ and build/ from analysis by default ([b3973b3](https://github.com/lezli01/lintforge/commit/b3973b307f6834ce2f2fa1d567d6a1725659a512))
* **runner:** exclude .dart_tool/ and build/ from analysis by default ([#33](https://github.com/lezli01/lintforge/issues/33)) ([6456e5c](https://github.com/lezli01/lintforge/commit/6456e5caad78648cca56e8fc10f19d5bf73716b9))
* **unused_function:** exempt conditional-export and public-API members ([fdd67eb](https://github.com/lezli01/lintforge/commit/fdd67eb99a7ab1694d648373350a638ae2f7ec79))
* **unused_function:** exempt conditional-export/import branch targets ([b7ad632](https://github.com/lezli01/lintforge/commit/b7ad6328bff4fddf8749c9f323cdc8c83406597a))
* **unused_function:** exempt public members of public types outside lib/src/ ([e9de657](https://github.com/lezli01/lintforge/commit/e9de65722609d1f362786069d0b87784df36279e))
* **unused_function:** exempt supertype overrides without [@override](https://github.com/override) ([dd40f83](https://github.com/lezli01/lintforge/commit/dd40f83dde5e3247ae350c3f51074ecce68520a8))

## [0.3.7](https://github.com/lezli01/lintforge/compare/v0.3.6...v0.3.7) (2026-05-28)


### Features

* better utilization coverage ([#30](https://github.com/lezli01/lintforge/issues/30)) ([1b86e8f](https://github.com/lezli01/lintforge/commit/1b86e8f1b1e73c53d135e33fdb679262e0fb4ea5))
* **multi_file_analysis_context:** add reportableFilePaths field ([6189773](https://github.com/lezli01/lintforge/commit/61897739c7c69cb7381bd54dd33b42ce54e89481))
* **reporter:** group ConsoleReporter output by file ([8c4bba5](https://github.com/lezli01/lintforge/commit/8c4bba5eda36e1b9269b45792427e224dfc00334))
* **reporter:** group ConsoleReporter output by file ([#28](https://github.com/lezli01/lintforge/issues/28)) ([1880d63](https://github.com/lezli01/lintforge/commit/1880d6338ca464a057a9cfa355ae02bd42732694))
* **samples:** exercise excluded-file references in samples ([9f3301c](https://github.com/lezli01/lintforge/commit/9f3301cf05be5ebd77526d077f6fecfbe3eeca2e))
* **unused_function:** only emit diagnostics for reportable files ([2c6ee3e](https://github.com/lezli01/lintforge/commit/2c6ee3e34b4ebf539acf9f181f77405e0f74a060))
* **unused_source_file:** only flag reportable files ([13ad2ee](https://github.com/lezli01/lintforge/commit/13ad2eeeb7da12d76ef6188c0283b2712f0437ba))

## [0.3.6](https://github.com/lezli01/lintforge/compare/v0.3.5...v0.3.6) (2026-05-28)


### Features

* function analysis enhanced ([#26](https://github.com/lezli01/lintforge/issues/26)) ([b0538b9](https://github.com/lezli01/lintforge/commit/b0538b963ddc65d4e5eb565d578e4673fa369957))
* **unused_function:** normalise generic member identity in reference tracking ([c19c502](https://github.com/lezli01/lintforge/commit/c19c5024ed8a87e5cda64859d751f78b2df7e2f6))
* **unused_function:** record enum-value declarations as uses of the enum constructor ([b592b78](https://github.com/lezli01/lintforge/commit/b592b78e4a2816b381c86d88c828b516e57a7bfa))
* **unused_function:** record implicit super-constructor invocation as a use ([ee2a5c1](https://github.com/lezli01/lintforge/commit/ee2a5c16d6a760f9c3b8a68d77063f55a8701d22))
* **unused_function:** treat overrides of reachable supertype members as uses ([c9f3c0e](https://github.com/lezli01/lintforge/commit/c9f3c0eabc2e20b35cfc9f5e44fcf0b3b32179e2))
* **unused_function:** walk supertype chain for noSuchMethod exemption ([a85e7e2](https://github.com/lezli01/lintforge/commit/a85e7e22e79a5ab0e0c9216ba14bacbe7b262c36))


### Bug Fixes

* **unused_function:** exempt flutter gen-l10n generated localization output ([0c06c1f](https://github.com/lezli01/lintforge/commit/0c06c1f3b1b1d5af5b21d3cb10465ec16477c710))

## [0.3.5](https://github.com/lezli01/lintforge/compare/v0.3.4...v0.3.5) (2026-05-28)


### Features

* dart awareness ([#24](https://github.com/lezli01/lintforge/issues/24)) ([a966836](https://github.com/lezli01/lintforge/commit/a966836093fb7cb22c79a3edb9b083c699183a01))
* **unused_class:** make rule Dart 3 feature-aware ([bc6c086](https://github.com/lezli01/lintforge/commit/bc6c0862b6ef457aba822b8a8fa79b3674e899dc))
* **unused_function:** make rule feature-aware ([0ac7537](https://github.com/lezli01/lintforge/commit/0ac75377812a95d691ff0c49583ec6ebd3f44b0e))
* **unused_source_file:** follow conditional and deferred import edges ([7e1bc72](https://github.com/lezli01/lintforge/commit/7e1bc72cdf70f03baed0a8c84b23419310a5970f))
* updated sample ([#21](https://github.com/lezli01/lintforge/issues/21)) ([9d3e5b2](https://github.com/lezli01/lintforge/commit/9d3e5b26d4bf66992e410ce73b778d0b3ac44f59))


### Bug Fixes

* **unused_source_file:** follow conditional-URI branches when computing reachability ([f7c1bb1](https://github.com/lezli01/lintforge/commit/f7c1bb1aed0ace91c991677cdc1694e1d4f4bcd9))
* **unused_source_file:** follow conditional-URI branches when computing reachability ([#23](https://github.com/lezli01/lintforge/issues/23)) ([ff720f2](https://github.com/lezli01/lintforge/commit/ff720f2fe262986b816d8e5b0363afde05a8114e))

## [0.3.4](https://github.com/lezli01/lintforge/compare/v0.3.3...v0.3.4) (2026-05-27)


### Features

* sample projects ([#17](https://github.com/lezli01/lintforge/issues/17)) ([f120a92](https://github.com/lezli01/lintforge/commit/f120a9202eaff9ba57670cf5011560a27f71844d))
* **samples:** add unused_source_file sample project ([af01ba7](https://github.com/lezli01/lintforge/commit/af01ba7b58df7aeb4a8158ff2b4d79f5d35effee))
* unused functions ([#20](https://github.com/lezli01/lintforge/issues/20)) ([9f79e99](https://github.com/lezli01/lintforge/commit/9f79e99d63d30dd66eb2c153ba803d4a98d2a781))
* **unused_function:** add collector for class, mixin, enum, and extension-type members ([c5574f2](https://github.com/lezli01/lintforge/commit/c5574f2cc28a19de806deb0285987667fd5ba974))
* **unused_function:** add collector for extension declaration members ([ffa728a](https://github.com/lezli01/lintforge/commit/ffa728a11b4060ddad51278d9e5c4a532a56827f))
* **unused_function:** add collector for top-level getters and setters ([3d4d3e7](https://github.com/lezli01/lintforge/commit/3d4d3e7684c7f1836694213d3baddd6c751e8679))
* **unused_function:** flag unreferenced public top-level functions in lib/src/ ([07703ce](https://github.com/lezli01/lintforge/commit/07703ce73bc72073b9c0440e2b0f8934ff5748f9))


### Bug Fixes

* analysis ([ff4cf8c](https://github.com/lezli01/lintforge/commit/ff4cf8c83bd4078e4e5d5d56d1278f32e206ff55))

## [0.3.3](https://github.com/lezli01/lintforge/compare/v0.3.2...v0.3.3) (2026-05-27)


### Bug Fixes

* added nuances ([35937b3](https://github.com/lezli01/lintforge/commit/35937b36ea4f90c7f05157e9af2cfcd69ce65dd3))
* **rules:** avoid UnsupportedError on namePart in unused_class ([7c8acc8](https://github.com/lezli01/lintforge/commit/7c8acc84078e19dd41b893fec836766a93283a46))

## [0.3.2](https://github.com/lezli01/lintforge/compare/v0.3.1...v0.3.2) (2026-05-27)


### Bug Fixes

* removed invalid version ([67cdcac](https://github.com/lezli01/lintforge/commit/67cdcac96f426a118632a60e8698a54d414e557a))

## [0.3.1](https://github.com/lezli01/lintforge/compare/v0.3.0...v0.3.1) (2026-05-27)


### Continuous Integration

* **release:** wire bin/lintforge.dart into release-please and trigger 0.3.1 ([e544060](https://github.com/lezli01/lintforge/commit/e5440600d4531b193e30faa28c85c681d8b98c04))

## [0.3.0](https://github.com/lezli01/lintforge/compare/v0.2.0...v0.3.0) (2026-05-27)

### Added

- New default-on `unused_source_file` rule. It flags Dart source files in
  the analyzed set that are never reached from any entry point via an
  `import`, `export`, or `part` directive. Entry points are files under
  `bin/` or `test/`, files that declare a top-level `main`, and
  `lib/<package>.dart` plus any other file sitting directly under
  `lib/` (i.e. not nested inside `lib/src/`). Generated-file basenames
  such as `*.g.dart` and `*.freezed.dart` are skipped defensively even
  when the runner's default excludes are turned off. Diagnostics are
  emitted at `Severity.warning`. The rule is registered by the built-in
  CLI and enabled automatically. Running `dart run lintforge` against a
  project that previously produced no diagnostics may now surface new
  warnings from this rule.
- New `MultiFileAnalyzerRule` extension point for custom rules that need
  to reason across multiple files in a single invocation (for example to
  build an import graph or a cross-file symbol index). Multi-file rules
  are registered with the same `RuleRegistry` as `AnalyzerRule`
  implementations and are dispatched once per run with the full set of
  resolved compilation units. Existing `AnalyzerRule` implementations
  continue to be dispatched once per file and do not need any changes.
- New `--no-default-excludes` CLI flag that opts out of the built-in
  default exclude patterns. Pair it with explicit `--exclude` flags when
  you want full control over which paths are skipped.
- New `LintforgeOptions.defaultExcludePaths` constant exposing the list of
  glob patterns excluded by `LintforgeOptions.defaults()`. Useful when
  composing custom `LintforgeOptions` instances programmatically.
- New default-on `unused_function` rule. It flags file-local function
  declarations that are never referenced, specifically private top-level
  functions in libraries that have no `part` files and local function
  declarations inside another function or method body. Diagnostics are emitted
  at `Severity.warning`. The rule is registered by the built-in CLI and enabled
  automatically. Running `dart run lintforge` against a project that previously
  produced no diagnostics may now surface new warnings from this rule.
- New default-on `unused_class` rule. It flags file-local declarations
  that are never referenced within the same compilation unit, covering
  `class`, `mixin`, `enum`, and `extension type` declarations whose names
  begin with `_`. The rule only runs against libraries that have no
  `part` files and skips declarations annotated with
  `@pragma('vm:entry-point')`. Diagnostics are emitted at
  `Severity.warning`. The rule is registered by the built-in CLI and
  enabled automatically. Running `dart run lintforge` against a project that
  previously produced no diagnostics may now surface new warnings from
  this rule.
- Open-source project guidance, issue templates, pull request checklist,
  security policy, code of conduct, and Dependabot configuration.
- Coverage artifact upload to CI.
- `.pubignore` to keep automation and assistant-only files out of the published
  package archive.
- `.gitattributes` for predictable text file line endings.

### Changed

- Updated CI and release automation to target the repository default branch.
- Tightened package metadata for pub.dev discovery.
- Widened the analyzer dependency to `>=9.0.0 <13.0.0` so projects using
  `freezed >=3.2.5` can add `lintforge` without a version-solver conflict.
- Default exclude patterns now include `*.g.dart` and `*.freezed.dart`.
  Pass an empty `excludePaths` (or `--no-default-excludes` on the CLI)
  to opt out.
- `--exclude` now layers on top of the default excludes instead of
  replacing them. Patterns you pass are added to the built-in defaults;
  use `--no-default-excludes` if you need to suppress the defaults.

### Fixed

- Fixed directory include discovery on Windows.
- `lintforge` is now installable alongside `freezed ^3.2.5`.
- `dart run lintforge --version` now prints the correct package version
  instead of the stale hardcoded `0.1.0`.
- Restored analyzer 9.0.0 compatibility for the `unused_class` rule.
  The rule previously reached into `ExtensionTypeDeclaration.primaryConstructor`,
  which only exists in analyzer 10+, causing a build break for consumers
  pinned to analyzer 9.0.0 (`'primaryConstructor' isn't defined for the type
  'ExtensionTypeDeclaration'`). The rule now uses the cross-version
  `ExtensionTypeDeclaration.name` accessor.
- `unused_class` no longer crashes on analyzer 9.x/10.x. The rule
  previously read `ClassDeclaration.namePart` and
  `EnumDeclaration.namePart`, which require the default-off experimental
  flag `useDeclaringConstructorsAst = true` and otherwise throw
  `UnsupportedError`, surfacing as
  `Rule unused_class threw during analysis: ...`. The rule now uses the
  always-available `name` token on both nodes.

### Commits

* feat: fixing version handling ([3460776](https://github.com/lezli01/lintforge/commit/34607762c6cdf11b87522b85a40f3884d060c13d))
* fix: fixed ci ([30aa5b6](https://github.com/lezli01/lintforge/commit/30aa5b67a1f33fc18d3a0918d9fef6203fdd1497))
* fix: refreshed readme ([391d527](https://github.com/lezli01/lintforge/commit/391d527d6a51af8f97630b32a09a5342da82e2a4))

## [0.2.0](https://github.com/lezli01/lintforge/compare/v0.1.0...v0.2.0) (2026-05-27)


### ⚠ BREAKING CHANGES

* **api:** Calculator is removed from the public API.

### Features

* add Severity, SourceLocation, Diagnostic value types ([0b965cd](https://github.com/lezli01/lintforge/commit/0b965cdc42f24f356aec89bc32f0ad3f91c08c46))
* **api:** re-export public surface from lib/lintforge.dart ([4cef459](https://github.com/lezli01/lintforge/commit/4cef4595278018e6990da490b7b568ab720c686e))
* **cli:** add bin/lintforge.dart CLI entry point ([ae0fa3b](https://github.com/lezli01/lintforge/commit/ae0fa3b5939055b3352b5f846ce05e06f94bc29e))
* frame basics ([44c400e](https://github.com/lezli01/lintforge/commit/44c400e1b08acefa6be90fbb1cf888358f6c5030))
* **options:** add LintforgeOptions value class ([2c0cb6c](https://github.com/lezli01/lintforge/commit/2c0cb6c0f80198800620a68d803095829b6a3c4d))
* **reporter:** add Reporter abstraction and ConsoleReporter ([85e556d](https://github.com/lezli01/lintforge/commit/85e556d7aec029d4e9b4c45095b3a02e2a2bc664))
* **rules:** add AnalyzerRule contract, AnalysisContext, RuleRegistry ([0e45827](https://github.com/lezli01/lintforge/commit/0e458273cb04a7d653ab3579d0f6aa01d6d1303d))
* **rules:** add unused_class rule ([4adcd8e](https://github.com/lezli01/lintforge/commit/4adcd8ee761094d837c49a31d08b067548c11677))
* **rules:** add unused_function rule ([84e9528](https://github.com/lezli01/lintforge/commit/84e95287cb5b408bf849fdbaf1c79836bcbc568f))
* **rules:** register unused_function rule in CLI ([2ea76c1](https://github.com/lezli01/lintforge/commit/2ea76c1950a1bb388ab4fe9ec35287479998d83f))
* **runner:** add AnalysisRunner orchestrator and smoke test ([b721079](https://github.com/lezli01/lintforge/commit/b721079ef8157570d3efc260013be8d20aa75e85))

## 0.1.0

- Added a pluggable static-analysis framework for Dart and Flutter projects:
  - `AnalyzerRule`: abstract plugin contract for custom rules.
  - `Diagnostic`, `Severity`, `SourceLocation`: value types describing
    analysis findings.
  - `AnalysisContext`: carrier passed into each rule invocation, exposing the
    resolved compilation unit.
  - `RuleRegistry`: in-memory registration and lookup of rules, with
    duplicate-id rejection.
  - `AnalysisRunner`: orchestrator that resolves target files, dispatches
    rules, and collects diagnostics.
  - `LintforgeOptions`: value class describing include/exclude paths and enabled
    rule ids.
  - `Reporter` / `ConsoleReporter`: pluggable diagnostic output, with a stdout
    implementation.
  - CLI executable `lintforge` (`dart run lintforge`) with `--help`, `--version`,
    `--rules`, and `--exclude` flags.

### BREAKING CHANGE

- Removed the `Calculator` stub that shipped in `0.0.1`. Consumers that
  depended on it must remove the import; it was a generator placeholder and
  not part of any intended public API.

## 0.0.1

- Initial package scaffold.
