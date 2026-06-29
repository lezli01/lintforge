# CLAUDE.md

Guidance for Claude Code (and other AI assistants) when working in this repository.

## Project Overview

`lintforge` is an **open-source Dart / Flutter package** providing **static code analysis** tooling. It is intended to be consumed by other Dart and Flutter projects (typically as a `dev_dependency`) to enforce code quality, lint rules, and analyzer configuration.

- **Language:** Dart (Flutter package)
- **Package name:** `lintforge`
- **Entry point:** [lib/lintforge.dart](lib/lintforge.dart)
- **Tests:** [test/lintforge_test.dart](test/lintforge_test.dart)
- **License:** See [LICENSE](LICENSE) (open source)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)

Because this package is about *static analysis*, special care must be taken so that the package itself is exemplary: it must lint cleanly, follow Effective Dart, and never ship analyzer rules it does not itself pass.

## Toolchain

This project uses **[FVM](https://fvm.app/) (Flutter Version Management)** to pin the Flutter / Dart SDK. Always run Flutter and Dart commands through `fvm` so the version matches what CI and other contributors use.

- Install / sync the pinned SDK: `fvm install` then `fvm use`
- Pinned version is recorded in `.fvmrc` / `.fvm/` (do not commit unrelated changes there).
- The Dart SDK constraint is declared in [pubspec.yaml](pubspec.yaml) (`environment.sdk`).

### Common commands

Always prefix with `fvm`:

```sh
fvm flutter pub get          # install dependencies
fvm dart analyze             # run the analyzer (must be clean)
fvm dart format .            # format code (must be a no-op in CI)
fvm flutter test             # run the test suite
fvm dart pub publish --dry-run   # validate before publishing
```

Do **not** invoke bare `flutter` / `dart` in instructions or scripts unless explicitly intended to use the system SDK.

## Repository Layout

```
lib/          Public API of the package. Anything exported here is part of the
              package's stable surface.
test/         Unit tests. Mirror the structure of lib/.
analysis_options.yaml   Analyzer + lint configuration this package uses on itself.
pubspec.yaml  Package metadata, SDK constraints, dependencies.
CHANGELOG.md  Human-readable change history (keep in sync with versions).
README.md     User-facing documentation.
```

## Coding Conventions

- Follow **[Effective Dart](https://dart.dev/effective-dart)** (style, documentation, usage, design).
- Public APIs (anything in `lib/` not under `lib/src/`) **must have dartdoc comments** (`///`).
- Keep implementation details under `lib/src/` and only re-export the intended public surface from `lib/lintforge.dart`.
- Code must pass `fvm dart analyze` with **zero warnings, hints, or infos**. Treat analyzer output as errors.
- Code must be formatted with `fvm dart format .` (88-col default).
- Prefer `final` and `const` wherever possible. Avoid mutable top-level / static state.
- Avoid adding runtime dependencies unless strictly necessary; this is an analysis-focused package.
- When adding or changing lint rules in [analysis_options.yaml](analysis_options.yaml), update the README and CHANGELOG, and ensure the package's own sources still pass.

## Testing

- Tests live in `test/` and use `package:flutter_test` / `package:test`.
- Every bug fix should add a regression test.
- Every new public API should have at least one test covering happy-path and one edge case.
- Run the full suite with `fvm flutter test` before committing.

## Commits — Conventional Commits

This repository uses **[Conventional Commits](https://www.conventionalcommits.org/)**. Every commit message must follow:

```
<type>(<optional scope>): <short summary>

<optional body>

<optional footer(s)>
```

Allowed `type` values (use the lowercase form):

- `feat` — a new feature (bumps MINOR)
- `fix` — a bug fix (bumps PATCH)
- `docs` — documentation only
- `style` — formatting, missing semicolons, etc.; no code change
- `refactor` — code change that neither fixes a bug nor adds a feature
- `perf` — performance improvement
- `test` — adding or fixing tests
- `build` — build system or external dependency changes (e.g. `pubspec.yaml`)
- `ci` — CI configuration changes
- `chore` — other changes that don't modify `lib/` or `test/`
- `revert` — reverts a previous commit

Rules:

- **Breaking changes:** append `!` after the type/scope (`feat!: …`) **and** include a `BREAKING CHANGE:` footer describing the migration. Pre-1.0.0, breaking changes still bump MINOR per Dart pub conventions, but must be clearly called out in the CHANGELOG.
- Summary line: imperative mood, no trailing period, ≤ 72 chars.
- Reference issues in the footer: `Refs: #123`, `Closes: #123`.
- One logical change per commit. Do not mix refactors with feature work.

### Example

```
feat(lints): add prefer_const_constructors_in_immutables rule

Enables the rule in the bundled analysis_options.yaml and documents
it in the README.

Closes: #42
```

## Versioning & Releases

- Follows **[Semantic Versioning](https://semver.org/)** as adapted by `pub.dev`.
- Update [CHANGELOG.md](CHANGELOG.md) with every user-visible change under the next version heading.
- Bump `version:` in [pubspec.yaml](pubspec.yaml) in the same commit that finalizes the changelog entry.
- Validate with `fvm dart pub publish --dry-run` before tagging.
- Tag releases as `vX.Y.Z` matching the pubspec version.

## Things to Watch Out For

1. **Don't ship lint rules the package itself fails.** After editing `analysis_options.yaml`, always re-run `fvm dart analyze` on this repo.
2. **Don't add Flutter-only dependencies if the feature could be pure Dart.** Keep the consumer surface minimal.
3. **Don't bypass FVM** — using a different SDK can produce analyzer output that disagrees with CI.
4. **Don't commit generated files** unless explicitly part of the package contract.
5. **Don't break the public API** without a `!` commit + CHANGELOG `BREAKING CHANGE` entry.
6. **Don't edit `CHANGELOG.md` retroactively** for already-published versions; add a new entry instead.
7. **Don't add license headers per file** unless the project policy changes — the root [LICENSE](LICENSE) covers the package.
8. **Be mindful of `pubspec.yaml` fields** required by pub.dev for scoring: `description` (60–180 chars), `homepage`/`repository`, `version`, `environment`. The current `description` is a placeholder and should be improved before publishing.

## Open Source Hygiene

- Be welcoming in issues and PRs.
- Never commit secrets, tokens, or personal paths.
- Attribute third-party code and respect their licenses.
- Keep documentation accurate — outdated docs are a bug.

## Quick Pre-Commit Checklist

- [ ] `fvm dart format .` — clean
- [ ] `fvm dart analyze` — zero issues
- [ ] `fvm flutter test` — all green
- [ ] CHANGELOG updated (if user-visible)
- [ ] Commit message follows Conventional Commits
