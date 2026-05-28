// Hand-authored stand-in for a code-generated companion file. The
// sample is run with `--exclude '*.g.dart'`, so this file is parsed
// alongside the rest of the package but never has its own candidates
// flagged — its sole purpose is to demonstrate that excluded files
// still contribute references to the cross-file rule's global
// reference set, keeping `keptAliveByExcludedRef` alive (see N21 in
// the sample README and in `unused_function_sample.dart`'s `main`).
//
// `_refUsage` itself would normally be a positive case for the
// `unused_function` rule (an unused private top-level function under
// `lib/src/`). Because this file is excluded, the rule does not
// dispatch reportable diagnostics against it — `_refUsage` must NOT
// be flagged. If it ever is, the excluded-files-as-references
// behavior has regressed.
//
// ignore_for_file: unused_element

import 'internals.dart';

void _refUsage() {
  keptAliveByExcludedRef();
}
