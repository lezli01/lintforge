// Imported by `lib/all_rules_sample.dart` (an entry point) and owns
// `used_via_part.dart` as a `part`. Both files must be reachable and must
// NOT be flagged by the `unused_source_file` rule.
library;

part 'used_via_part.dart';

/// Public helper used by the sample's entry point.
String hello(String name) => 'Hello, $name';
