/// Negative case for the `unused_source_file` rule: this file is
/// reached ONLY through the excluded `bin/dev_tool.g.dart` entry-point.
/// The runner is invoked with `--exclude '*.g.dart'`, so
/// `dev_tool.g.dart` is filtered out of the *reportable* set, but the
/// frame still parses it and feeds its `import` directives into the
/// cross-file reachability graph — which keeps this file reachable.
/// Without the excluded-files-as-references behavior, no other entry
/// point would reach this file and the rule would (incorrectly) flag
/// it as `unused_source_file`.
///
/// Declared as a `const` rather than a function so the `unused_function`
/// rule's public-top-level mode does not also flag it.
const String keptAliveByExcludedSource = 'kept-alive';
