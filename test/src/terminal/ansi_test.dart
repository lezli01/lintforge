import 'package:lintforge/src/terminal/ansi.dart';
import 'package:test/test.dart';

void main() {
  group('Ansi (disabled)', () {
    const ansi = Ansi.disabled();

    test('is not enabled', () {
      expect(ansi.enabled, isFalse);
    });

    test('paint returns the text unchanged', () {
      expect(ansi.paint('hello', const [Ansi.red, Ansi.bold]), 'hello');
    });

    test('semantic helpers return the text unchanged', () {
      expect(ansi.strong('x'), 'x');
      expect(ansi.faint('x'), 'x');
    });

    test('the const default constructor is also disabled', () {
      expect(const Ansi(enabled: false).enabled, isFalse);
    });
  });

  group('Ansi (enabled)', () {
    const ansi = Ansi(enabled: true);

    test('paint wraps a single code with a reset', () {
      expect(ansi.paint('hi', const [Ansi.red]), '\x1B[31mhi\x1B[0m');
    });

    test('paint joins multiple codes with a semicolon', () {
      expect(
        ansi.paint('hi', const [Ansi.bold, Ansi.red]),
        '\x1B[1;31mhi\x1B[0m',
      );
    });

    test('paint with no codes is the identity even when enabled', () {
      expect(ansi.paint('hi', const []), 'hi');
    });

    test('strong is bold, faint is dim', () {
      expect(ansi.strong('hi'), '\x1B[1mhi\x1B[0m');
      expect(ansi.faint('hi'), '\x1B[2mhi\x1B[0m');
    });

    test('an empty string still round-trips (no crash, wrapped)', () {
      expect(ansi.paint('', const [Ansi.red]), '\x1B[31m\x1B[0m');
    });
  });

  group('Ansi.strip', () {
    test('removes a single SGR sequence', () {
      expect(Ansi.strip('\x1B[31mred\x1B[0m'), 'red');
    });

    test('removes multi-code and reset sequences', () {
      expect(
        Ansi.strip('\x1B[1;33mwarn\x1B[0m plain \x1B[90mgrey\x1B[0m'),
        'warn plain grey',
      );
    });

    test('is a no-op on text without escapes', () {
      expect(Ansi.strip('no codes here'), 'no codes here');
    });

    test('stripping painted text recovers the original for any codes', () {
      const ansi = Ansi(enabled: true);
      for (final codes in const [
        [Ansi.red],
        [Ansi.bold, Ansi.cyan],
        [Ansi.dim],
        [Ansi.green, Ansi.underline],
      ]) {
        expect(Ansi.strip(ansi.paint('sample', codes)), 'sample');
      }
    });
  });
}
