import 'package:lintforge/src/terminal/color_support.dart';
import 'package:test/test.dart';

bool _decide(
  ColorPreference preference, {
  bool hasTerminal = true,
  bool supportsAnsiEscapes = true,
  Map<String, String> environment = const <String, String>{},
}) {
  return shouldEmitAnsi(
    preference: preference,
    hasTerminal: hasTerminal,
    supportsAnsiEscapes: supportsAnsiEscapes,
    environment: environment,
  );
}

void main() {
  group('shouldEmitAnsi — explicit preference wins', () {
    test(
      'never is always false, even on a capable terminal with FORCE_COLOR',
      () {
        expect(
          _decide(
            ColorPreference.never,
            environment: const {'FORCE_COLOR': '1'},
          ),
          isFalse,
        );
      },
    );

    test('always is always true, even off-terminal with NO_COLOR set', () {
      expect(
        _decide(
          ColorPreference.always,
          hasTerminal: false,
          supportsAnsiEscapes: false,
          environment: const {'NO_COLOR': '1'},
        ),
        isTrue,
      );
    });
  });

  group('shouldEmitAnsi — auto detection', () {
    test('a capable interactive terminal enables color', () {
      expect(_decide(ColorPreference.auto), isTrue);
    });

    test('a non-terminal (pipe/file) disables color', () {
      expect(_decide(ColorPreference.auto, hasTerminal: false), isFalse);
    });

    test('a terminal that does not support ANSI disables color', () {
      expect(
        _decide(ColorPreference.auto, supportsAnsiEscapes: false),
        isFalse,
      );
    });

    test('NO_COLOR with a non-empty value disables color', () {
      expect(
        _decide(ColorPreference.auto, environment: const {'NO_COLOR': '1'}),
        isFalse,
      );
    });

    test('an empty NO_COLOR is ignored', () {
      expect(
        _decide(ColorPreference.auto, environment: const {'NO_COLOR': ''}),
        isTrue,
      );
    });

    test('FORCE_COLOR forces color on even without a terminal', () {
      expect(
        _decide(
          ColorPreference.auto,
          hasTerminal: false,
          supportsAnsiEscapes: false,
          environment: const {'FORCE_COLOR': '1'},
        ),
        isTrue,
      );
    });

    test('FORCE_COLOR=0 is ignored', () {
      expect(
        _decide(
          ColorPreference.auto,
          hasTerminal: false,
          environment: const {'FORCE_COLOR': '0'},
        ),
        isFalse,
      );
    });

    test('FORCE_COLOR=false is ignored', () {
      expect(
        _decide(
          ColorPreference.auto,
          hasTerminal: false,
          environment: const {'FORCE_COLOR': 'false'},
        ),
        isFalse,
      );
    });

    test('NO_COLOR takes precedence over FORCE_COLOR', () {
      expect(
        _decide(
          ColorPreference.auto,
          environment: const {'NO_COLOR': '1', 'FORCE_COLOR': '1'},
        ),
        isFalse,
      );
    });

    test('TERM=dumb disables color on an otherwise capable terminal', () {
      expect(
        _decide(ColorPreference.auto, environment: const {'TERM': 'dumb'}),
        isFalse,
      );
    });

    test('FORCE_COLOR overrides a dumb terminal', () {
      expect(
        _decide(
          ColorPreference.auto,
          environment: const {'TERM': 'dumb', 'FORCE_COLOR': '1'},
        ),
        isTrue,
      );
    });
  });

  group('resolveAnsi', () {
    test('returns an enabled palette when color should be emitted', () {
      final ansi = resolveAnsi(
        preference: ColorPreference.always,
        hasTerminal: false,
        supportsAnsiEscapes: false,
        environment: const <String, String>{},
      );
      expect(ansi.enabled, isTrue);
    });

    test('returns a disabled palette when color should be suppressed', () {
      final ansi = resolveAnsi(
        preference: ColorPreference.never,
        hasTerminal: true,
        supportsAnsiEscapes: true,
        environment: const <String, String>{},
      );
      expect(ansi.enabled, isFalse);
    });
  });
}
