import 'package:lintforge/src/lintforge_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LintforgeOptions.defaultExcludePaths', () {
    test(
      'equals exactly [*.g.dart, *.freezed.dart, **/.dart_tool/**, **/build/**]',
      () {
        expect(
          LintforgeOptions.defaultExcludePaths,
          equals(<String>[
            '*.g.dart',
            '*.freezed.dart',
            '**/.dart_tool/**',
            '**/build/**',
          ]),
        );
      },
    );
  });

  group('LintforgeOptions.defaults', () {
    test('excludePaths contains every default pattern', () {
      const options = LintforgeOptions.defaults();
      expect(options.excludePaths, contains('*.g.dart'));
      expect(options.excludePaths, contains('*.freezed.dart'));
      expect(options.excludePaths, contains('**/.dart_tool/**'));
      expect(options.excludePaths, contains('**/build/**'));
    });

    test('excludePaths is the defaultExcludePaths list', () {
      const options = LintforgeOptions.defaults();
      expect(options.excludePaths, equals(LintforgeOptions.defaultExcludePaths));
    });
  });

  group('LintforgeOptions constructor', () {
    test('opt-out: explicit empty excludePaths yields an empty list', () {
      const options = LintforgeOptions(
        includePaths: ['lib/'],
        excludePaths: <String>[],
        enabledRuleIds: <String>{},
      );
      expect(options.excludePaths, isEmpty);
    });
  });

  group('LintforgeOptions equality and hashCode', () {
    test('two instances with identical fields are == and share hashCode', () {
      const a = LintforgeOptions(
        includePaths: ['lib/', 'bin/'],
        excludePaths: ['*.g.dart'],
        enabledRuleIds: <String>{'rule_a', 'rule_b'},
      );
      const b = LintforgeOptions(
        includePaths: ['lib/', 'bin/'],
        excludePaths: ['*.g.dart'],
        enabledRuleIds: <String>{'rule_a', 'rule_b'},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances differing in excludePaths are not ==', () {
      const a = LintforgeOptions(
        includePaths: ['lib/'],
        excludePaths: ['*.g.dart'],
        enabledRuleIds: <String>{},
      );
      const b = LintforgeOptions(
        includePaths: ['lib/'],
        excludePaths: ['*.freezed.dart'],
        enabledRuleIds: <String>{},
      );
      expect(a, isNot(equals(b)));
    });

    test('instances differing in includePaths are not ==', () {
      const a = LintforgeOptions(
        includePaths: ['lib/'],
        excludePaths: <String>[],
        enabledRuleIds: <String>{},
      );
      const b = LintforgeOptions(
        includePaths: ['bin/'],
        excludePaths: <String>[],
        enabledRuleIds: <String>{},
      );
      expect(a, isNot(equals(b)));
    });

    test('instances differing in enabledRuleIds are not ==', () {
      const a = LintforgeOptions(
        includePaths: ['lib/'],
        excludePaths: <String>[],
        enabledRuleIds: <String>{'rule_a'},
      );
      const b = LintforgeOptions(
        includePaths: ['lib/'],
        excludePaths: <String>[],
        enabledRuleIds: <String>{'rule_b'},
      );
      expect(a, isNot(equals(b)));
    });

    test('enabledRuleIds equality is order-independent', () {
      const a = LintforgeOptions(
        includePaths: ['lib/'],
        excludePaths: <String>[],
        enabledRuleIds: <String>{'rule_a', 'rule_b'},
      );
      const b = LintforgeOptions(
        includePaths: ['lib/'],
        excludePaths: <String>[],
        enabledRuleIds: <String>{'rule_b', 'rule_a'},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
