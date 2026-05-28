// Hand-authored stand-in for a code-generated dev-tool entry point.
// The sample is run with `--exclude '*.g.dart'`, so this file is
// filtered out of the *reportable* set, but the frame still parses it
// and feeds its `import` into the cross-file reachability graph. The
// import below is the ONLY path that reaches
// `lib/src/kept_alive_by_excluded.dart` — without the
// excluded-files-as-references behavior, that file would be flagged
// by `unused_source_file`. With it, the file stays reachable and is
// silent. See the table in this sample's README.
//
// ignore_for_file: avoid_print

import 'package:unused_source_file_sample/src/kept_alive_by_excluded.dart';

void main() {
  print(keptAliveByExcludedRef);
}
