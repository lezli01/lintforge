---
name: upgrade-deps
description: Upgrade the lintforge package to the latest possible dependencies — bump the pinned Flutter SDK in .fvmrc to the newest stable, raise all pub dependencies to their latest major versions, resolve the resulting breaking changes and analyzer/test failures, then commit with Conventional Commits, push a branch, and open a green, mergeable PR. Use whenever you want to "update all dependencies", "bump Flutter to latest", "upgrade the package", or produce a dependency-refresh PR. Leaves GitHub Actions to Dependabot.
---

# upgrade-deps

Take the `lintforge` package to the **latest possible** stable toolchain and
dependencies in one autonomous pass, absorbing any breaking changes, and hand
back a **green, mergeable pull request**.

This skill is fully autonomous through PR creation — do **not** pause for
approval between phases. Only stop early for a hard precondition failure
(Phase 0) or when a decision is genuinely a human's to make (documented as a
*held-back* item, not a stop).

## What this does — and does not — touch

**In scope**

- **Flutter SDK**: bump `.fvmrc` to the newest **stable** channel release.
- **Pub dependencies**: raise `dependencies` / `dev_dependencies` in the root
  `pubspec.yaml` to their latest **major** versions (`pub upgrade --major-versions`).
- **Sample packages**: re-resolve every package under `samples/` against the
  new toolchain so `/lintforge-probe` still passes.
- **Breaking-change fixes**: edit `lib/`, `bin/`, `test/`, and sample sources
  as needed to compile and pass under the new versions.

**Out of scope — do not touch**

- **GitHub Actions** pins in `.github/workflows/` — Dependabot's
  `github-actions` ecosystem owns these. Leave them alone.
- **`version:`** in `pubspec.yaml` and **`_version`** in `bin/lintforge.dart` —
  release-please owns these. Never bump them here.
- **`CHANGELOG.md`** — release-please generates it from commit messages. Never
  hand-edit it.
- **`environment.sdk` / `environment.flutter` floors** — keep them **low**.
  Raise a floor **only if** `pub get` cannot resolve otherwise (see Phase 3).

## Phase 0 — Preconditions (hard gates)

Run every command from the repo root (the directory whose `pubspec.yaml` has
`name: lintforge`). Bail with a clear message if any gate fails:

1. **Clean working tree** — `git status --porcelain` must be empty. If dirty,
   stop and report; do not stash or discard the user's work.
2. **On `master` and up to date** — `git fetch origin master` then ensure the
   local tree matches `origin/master` (or is a clean descendant). Branch from
   the freshest `master`.
3. **Tooling present** — `fvm --version` and `gh auth status` must both
   succeed. `gh` must be authenticated against `github.com`.
4. **No in-flight run** — check for an existing branch/PR from a previous run
   (`git branch --list 'build/deps-upgrade-*'`, `gh pr list --head <branch>`).
   If one exists, report it and ask whether to resume rather than duplicating.

## Phase 1 — Baseline snapshot

Capture the *before* state so the PR body can show an accurate diff. Record:

- Current Flutter + Dart: `fvm flutter --version`.
- Current resolved dependency versions: `fvm dart pub deps --style=list` (or
  read `pubspec.lock`). Note the direct-dependency constraints from
  `pubspec.yaml` verbatim.

Create the working branch off `master` (deterministic name tied to the target
so re-runs are detectable):

```sh
git switch -c build/deps-upgrade-<new-flutter-version>
```

## Phase 2 — Bump the Flutter SDK

1. Discover the newest **stable** release and its bundled Dart:

   ```sh
   fvm api releases --filter-channel stable --limit 1 -c
   # -> .versions[0].version        e.g. "3.44.0"   (the Flutter version)
   # -> .versions[0].dart_sdk_version                (the bundled Dart, for the PR body)
   ```

2. If that version already equals `.fvmrc`'s pinned version, the Flutter SDK is
   already current — skip the install and note "Flutter already at latest
   stable" in the PR body. Otherwise:

   ```sh
   fvm install <new-flutter-version>
   fvm use <new-flutter-version>   # rewrites .fvmrc
   fvm flutter --version           # confirm the new SDK is active
   ```

## Phase 3 — Upgrade pub dependencies

1. **Root package** — raise constraints to latest majors, then resolve:

   ```sh
   fvm dart pub upgrade --major-versions
   fvm flutter pub get
   ```

   `--major-versions` rewrites the constraint floors in `pubspec.yaml`
   (including range-style ones like `analyzer: ">=9.0.0 <14.0.0"`). Review the
   diff to `pubspec.yaml` and confirm each rewritten constraint is intentional.

2. **Environment floors** — leave `environment.sdk` / `environment.flutter`
   **unchanged** unless `pub get` fails to resolve. Only if resolution fails
   because a dependency now requires a newer SDK: raise the offending floor to
   the **minimum** version that resolves — never higher, and never to the full
   dev-SDK version. A raised floor is a MINOR/potentially breaking change for
   consumers — call it out prominently in the PR body.

3. **Sample packages** — each package under `samples/` path-depends on the root
   and must re-resolve against the new toolchain:

   ```sh
   for d in samples/*/; do fvm dart pub get --directory "$d"; done
   ```

   (Use `pub upgrade --major-versions` inside a sample only if that sample
   declares its own third-party deps that need bumping; most only path-depend on
   lintforge + flutter_test.)

## Phase 4 — Resolve breaking changes (iterate to green)

The `analyzer` package is lintforge's core dependency; a major bump there is the
most likely source of breakage (visitor API, element model, AST node changes).
Before editing reachability rules, re-read the Dart-feature checklist in
`CLAUDE.md` ("Dart Language Features Rules Must Be Aware Of") and `LANGUAGE.md`
so a migration doesn't silently regress `unused_function` / `unused_class` /
`unused_source_file`.

Loop until green **or** a dependency is provably un-migratable without a human
decision:

1. `fvm dart analyze --fatal-infos --fatal-warnings` — fix every error, warning,
   and info. Zero output is the bar (CI runs the same flags).
2. `fvm flutter test` — fix failing tests. If a test fails because lintforge's
   **own observable behavior** legitimately changed under the new deps, update
   the test **and** flag it — that maps to a `fix:`/`feat:` commit and a
   changelog entry (see Phase 6), not a silent `refactor`.
3. Re-run until both are clean.

**When a dependency cannot be migrated** (e.g. `analyzer` 14 removed an API with
no straightforward replacement, or the fix requires a product decision):

- **Hold it back**: restore that single dependency to its previous constraint in
  `pubspec.yaml` (and re-run `pub get`) so the rest of the upgrade stays green
  and mergeable. Do the same for the Flutter bump only if the SDK itself is the
  blocker.
- Record the held-back dep, its target version, the **exact** error output, and
  what a human must decide. This becomes the `## Held back` section of the PR.
- Do **not** leave the tree red. The PR must be mergeable; blockers are
  documented, not committed broken.

## Phase 5 — Verification gates (mirror CI + samples)

All must pass on the final tree before committing:

```sh
fvm dart format .                                  # apply formatting; fold any changes into the relevant commit
fvm dart format --output=none --set-exit-if-changed .  # CI's exact check — must now exit 0
fvm dart analyze --fatal-infos --fatal-warnings    # zero issues
fvm flutter test                                   # all green
fvm dart pub publish --dry-run                     # no new publish warnings
```

Then run the sample probe and confirm every sample still emits exactly its
expected diagnostics:

```
/lintforge-probe
```

If the probe reports any unexpected extra, missing, or `_internal` diagnostic,
treat it as breakage and return to Phase 4 (fix the rule/migration) — a dep bump
that changes rule output is not "green".

## Phase 6 — Commit (Conventional Commits, split by concern)

`pr-title.yml` validates **every commit subject** against
`^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(scope\))?!?: <subject>`
with a **lowercase** subject; for a single-commit PR the commit subject must
equal the PR title exactly. Honor `CLAUDE.md`'s "one logical change per commit —
don't mix refactors with feature work."

Commit in this order, omitting any commit whose change set is empty:

1. **Version bumps only** — `pubspec.yaml`, `.fvmrc`, `pubspec.lock`, and the
   sample lockfiles/`pubspec.yaml` changes:

   ```
   build(deps): bump Flutter to <ver> and upgrade dependencies to latest
   ```

2. **Internal API migrations** (no consumer-visible behavior change) — the
   `lib/`/`bin/` edits that adapt to the new APIs:

   ```
   refactor(deps): migrate to <dep> <major> API
   ```

   `refactor` intentionally produces **no** changelog entry — correct for
   internal migrations.

3. **Behavior changes** — only if lintforge's own output/behavior actually
   changed (e.g. a rule now flags differently under the new analyzer):

   ```
   fix(rules): <what changed for consumers>
   ```

Keep subjects imperative, ≤72 chars, no trailing period, lowercase first word.
End each commit message body with the required trailer:

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

## Phase 7 — Push and open the PR

```sh
git push -u origin build/deps-upgrade-<new-flutter-version>
```

Open a **non-draft** PR against `master`, labeled `dependencies`. For a
multi-commit PR choose an overarching title; for a single-commit PR the title
must equal that commit's subject.

```sh
gh pr create --base master --label dependencies \
  --title 'build(deps): bump Flutter to <ver> and dependencies to latest' \
  --body-file <body>
```

### PR body template

```markdown
## Summary

Upgrades the toolchain and dependencies to the latest possible stable versions
and resolves the resulting breaking changes.

## Upgraded

| Component | Before | After |
|-----------|--------|-------|
| Flutter (.fvmrc) | 3.41.9 | <new> |
| Dart (bundled)   | <old>  | <new> |
| analyzer         | >=9.0.0 <14.0.0 | <new> |
| <dep>            | <old>  | <new> |

## Breaking changes resolved

- <dep> <major>: <what changed and how it was migrated> (`<file:line>`)

## Held back  <!-- omit this section if nothing was held back -->

- **<dep> <target>** — reverted to `<old constraint>` to keep the PR green.
  Error:
  ```
  <exact analyzer/build error>
  ```
  Needs: <the human decision required>.

## Verification

- [x] `dart format .` — no changes
- [x] `dart analyze --fatal-infos --fatal-warnings` — clean
- [x] `flutter test` — all green
- [x] `dart pub publish --dry-run` — no new warnings
- [x] `/lintforge-probe` — all samples pass
```

## Phase 8 — Confirm green and report

Run the local gates (Phase 5) — those are the real signal. Then confirm CI:

```sh
gh pr checks <pr-number> --watch   # bounded wait; report the actual result
```

If CI can't be watched to completion in a reasonable window, report the PR link
plus the local gate results and note that CI is still running. Final report to
the user must state: the new Flutter/Dart versions, the dependencies bumped
(with old→new), anything **held back** and why, the verification outcomes, and
the **PR URL**.

## Guardrails

- Never push to `master`; always work on the `build/deps-upgrade-*` branch and
  land via PR.
- Never bump `version:` / `_version` / `CHANGELOG.md` (release-please owns them).
- Never touch `.github/workflows/` action pins (Dependabot owns them).
- Never open a PR whose CI would be red; hold back the blocker and document it.
- Keep `environment` floors as low as still resolves — don't shrink the
  package's consumer reach without cause.
- If a breaking change requires a genuine product/API decision, document it as a
  held-back item; do not guess at consumer-facing behavior.
- Keep the README in sync in the **same PR** if the upgrade changes bundled
  rules, behavior, or supported SDK/Flutter versions (per `CLAUDE.md`).
