// Companion file to the unused_function sample's main entry point.
//
// Living under `lib/src/`, this file is treated by the rule as part of
// the package's *internal* surface — public top-level declarations
// here are candidates for `unused_function` and become positives when
// they go unreferenced. Files directly under `lib/` are skipped by
// contrast because they form the package's *public* surface.
//
// ignore_for_file: unused_element
library;

// (P11) Unused public top-level function in `lib/src/`. The rule treats
// `lib/src/` as the package's internal surface, so a public top-level
// function with no reference anywhere in the analyzed set is flagged.
void unusedPublicTopLevel() {}

// Used public top-level function — referenced from `main` in the
// sample's entry point, so the rule does not flag it.
void usedPublicTopLevel() {}

// (N20) Public top-level function whose ONLY reference lives in the
// excluded `lib/src/refs.g.dart` file. The runner is invoked with
// `--exclude '*.g.dart'`, so `refs.g.dart` is filtered out of the
// *reportable* set and never has its own candidates flagged. The frame
// still parses excluded files and feeds them into the cross-file rule's
// global reference set, so the call below keeps `keptAliveByExcludedRef`
// alive — without that behavior, this would be a P11-shaped positive.
void keptAliveByExcludedRef() {}
