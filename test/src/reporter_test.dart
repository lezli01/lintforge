import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lintforge/src/diagnostic.dart';
import 'package:lintforge/src/reporter.dart';
import 'package:lintforge/src/severity.dart';
import 'package:lintforge/src/source_location.dart';
import 'package:lintforge/src/terminal/ansi.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

/// Runs [body] against an in-memory [IOSink] and returns the decoded text.
Future<String> _capture(void Function(IOSink out) body) async {
  final consumer = _MemoryConsumer();
  final sink = IOSink(consumer);
  body(sink);
  await sink.close();
  return utf8.decode(consumer.bytes);
}

class _MemoryConsumer implements StreamConsumer<List<int>> {
  final List<int> bytes = <int>[];

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
  }

  @override
  Future<void> close() async {}
}

SourceLocation _loc(
  String filePath, {
  int line = 1,
  int column = 1,
  int offset = 0,
  int length = 1,
}) {
  return SourceLocation(
    filePath: filePath,
    offset: offset,
    length: length,
    line: line,
    column: column,
  );
}

Diagnostic _diag(
  String ruleId,
  String message,
  Severity severity,
  SourceLocation location, {
  String? correction,
}) {
  return Diagnostic(
    ruleId: ruleId,
    message: message,
    severity: severity,
    location: location,
    correction: correction,
  );
}

void main() {
  group('ConsoleReporter findings layout (no summary)', () {
    test('writes nothing for an empty diagnostic list', () async {
      final out = await _capture(
        (o) => ConsoleReporter(
          out: o,
          showSummary: false,
        ).report(const <Diagnostic>[]),
      );
      expect(out, isEmpty);
    });

    test('writes a single finding under its file header in aligned '
        'columns', () async {
      final out = await _capture(
        (o) => ConsoleReporter(out: o, showSummary: false).report([
          _diag(
            'unused_function',
            'Function "foo" is never used.',
            Severity.warning,
            _loc('lib/src/foo.dart', line: 3, column: 7),
          ),
        ]),
      );
      expect(
        out,
        'lib/src/foo.dart\n'
        '  warning  3:7  unused_function  Function "foo" is never used.\n',
      );
    });

    test('groups multiple diagnostics in one file under a single header, '
        'preserves input order, aligns columns across findings, and renders '
        'the correction continuation aligned under the message', () async {
      final out = await _capture(
        (o) => ConsoleReporter(out: o, showSummary: false).report([
          _diag(
            'unused_function',
            'Function "foo" is never used.',
            Severity.warning,
            _loc('lib/src/foo.dart', line: 10, column: 3),
            correction: 'Remove it or use it.',
          ),
          _diag(
            'unused_class',
            'Class "_Bar" is never used.',
            Severity.info,
            _loc('lib/src/foo.dart', line: 2, column: 1),
          ),
        ]),
      );
      expect(
        out,
        'lib/src/foo.dart\n'
        '  warning  10:3  unused_function  Function "foo" is never used.\n'
        '                                  ↳ Remove it or use it.\n'
        '  info     2:1   unused_class     Class "_Bar" is never used.\n',
      );
    });

    test(
      'emits one header per file in first-seen order, separates file '
      'groups with a blank line, and preserves per-file input order',
      () async {
        final out = await _capture(
          (o) => ConsoleReporter(out: o, showSummary: false).report([
            _diag(
              'unused_function',
              'm1',
              Severity.warning,
              _loc('lib/b.dart', line: 1, column: 1),
            ),
            _diag(
              'unused_function',
              'm2',
              Severity.warning,
              _loc('lib/a.dart', line: 5, column: 2),
            ),
            _diag(
              'unused_function',
              'm3',
              Severity.error,
              _loc('lib/b.dart', line: 9, column: 4),
            ),
          ]),
        );
        expect(
          out,
          'lib/b.dart\n'
          '  warning  1:1  unused_function  m1\n'
          '  error    9:4  unused_function  m3\n'
          '\n'
          'lib/a.dart\n'
          '  warning  5:2  unused_function  m2\n',
        );
      },
    );

    test('handles unicode file paths and messages verbatim', () async {
      final out = await _capture(
        (o) => ConsoleReporter(out: o, showSummary: false).report([
          _diag(
            'unused_function',
            'Function "héllo" is never used.',
            Severity.warning,
            _loc('lib/src/フー/bär.dart', line: 4, column: 8),
          ),
        ]),
      );
      expect(
        out,
        'lib/src/フー/bär.dart\n'
        '  warning  4:8  unused_function  Function "héllo" is never used.\n',
      );
    });
  });

  group('ConsoleReporter summary', () {
    test('an empty list renders a friendly "no issues" line', () async {
      final out = await _capture(
        (o) => ConsoleReporter(out: o).report(const <Diagnostic>[]),
      );
      expect(out, '✓ No issues found\n');
    });

    test('tallies severities, picks the error symbol as the worst, counts '
        'distinct files, and pluralizes correctly', () async {
      final out = await _capture(
        (o) => ConsoleReporter(out: o).report([
          _diag(
            'unused_function',
            'e',
            Severity.error,
            _loc('lib/a.dart', line: 1, column: 1),
          ),
          _diag(
            'unused_function',
            'w',
            Severity.warning,
            _loc('lib/a.dart', line: 2, column: 1),
          ),
          _diag(
            'unused_class',
            'i',
            Severity.info,
            _loc('lib/b.dart', line: 3, column: 1),
          ),
        ]),
      );
      expect(
        out,
        'lib/a.dart\n'
        '  error    1:1  unused_function  e\n'
        '  warning  2:1  unused_function  w\n'
        '\n'
        'lib/b.dart\n'
        '  info     3:1  unused_class     i\n'
        '\n'
        '✖ 3 issues found  (1 error, 1 warning, 1 info)  in 2 files\n',
      );
    });

    test(
      'a single warning uses singular nouns and the warning symbol',
      () async {
        final out = await _capture(
          (o) => ConsoleReporter(out: o).report([
            _diag(
              'unused_function',
              'w',
              Severity.warning,
              _loc('lib/a.dart', line: 1, column: 1),
            ),
          ]),
        );
        expect(
          out,
          'lib/a.dart\n'
          '  warning  1:1  unused_function  w\n'
          '\n'
          '⚠ 1 issue found  (1 warning)  in 1 file\n',
        );
      },
    );

    test('an info-only run uses the info symbol', () async {
      final out = await _capture(
        (o) => ConsoleReporter(out: o).report([
          _diag(
            'x',
            'i',
            Severity.info,
            _loc('lib/a.dart', line: 1, column: 1),
          ),
        ]),
      );
      expect(out, endsWith('ℹ 1 issue found  (1 info)  in 1 file\n'));
    });

    test('warnings without errors use the warning symbol', () async {
      final out = await _capture(
        (o) => ConsoleReporter(out: o).report([
          _diag('x', 'w1', Severity.warning, _loc('a.dart')),
          _diag('x', 'w2', Severity.warning, _loc('a.dart')),
        ]),
      );
      expect(out, endsWith('⚠ 2 issues found  (2 warnings)  in 1 file\n'));
    });
  });

  group('ConsoleReporter color', () {
    test('an enabled palette colors headers, severities, and the summary, '
        'and stripping the codes yields the plain output', () async {
      const ansi = Ansi(enabled: true);
      final diagnostics = [
        _diag(
          'unused_function',
          'Function "foo" is never used.',
          Severity.warning,
          _loc('lib/src/foo.dart', line: 3, column: 7),
        ),
      ];

      final colored = await _capture(
        (o) => ConsoleReporter(out: o, ansi: ansi).report(diagnostics),
      );
      final plain = await _capture(
        (o) => ConsoleReporter(out: o).report(diagnostics),
      );

      // Color was actually emitted...
      expect(colored, contains('\x1B['));
      expect(colored, isNot(equals(plain)));
      // ...the file header is bold, the warning is bold-yellow...
      expect(colored, contains('\x1B[1mlib/src/foo.dart\x1B[0m'));
      expect(colored, contains('\x1B[1;33mwarning\x1B[0m'));
      // ...and removing every SGR sequence recovers the plain bytes exactly.
      expect(Ansi.strip(colored), plain);
    });

    test('the disabled default palette emits no escape sequences', () async {
      final out = await _capture(
        (o) => ConsoleReporter(
          out: o,
        ).report([_diag('x', 'm', Severity.error, _loc('a.dart'))]),
      );
      expect(out, isNot(contains('\x1B[')));
    });
  });

  group('ConsoleReporter relativeTo', () {
    test(
      'displays file headers relative to the given base directory',
      () async {
        final base = p.join(Directory.current.path, 'project');
        final abs = p.join(base, 'lib', 'src', 'foo.dart');
        final out = await _capture(
          (o) => ConsoleReporter(out: o, showSummary: false, relativeTo: base)
              .report([
                _diag('unused_function', 'm', Severity.warning, _loc(abs)),
              ]),
        );
        expect(out, startsWith('${p.join('lib', 'src', 'foo.dart')}\n'));
      },
    );

    test(
      'renders a path outside the base directory as a parent-relative path',
      () async {
        final base = p.join(Directory.current.path, 'base');
        // `lib/foo.dart` resolves under the CWD, one level above `base`.
        final out = await _capture(
          (o) => ConsoleReporter(out: o, showSummary: false, relativeTo: base)
              .report([
                _diag(
                  'unused_function',
                  'm',
                  Severity.warning,
                  _loc('lib/foo.dart'),
                ),
              ]),
        );
        expect(out, startsWith('${p.join('..', 'lib', 'foo.dart')}\n'));
      },
    );

    test(
      'does not throw when relativizing falls back to the verbatim path',
      () async {
        // The reporter guards p.relative with a verbatim fallback; this
        // asserts the guard holds (no throw) regardless of whether the
        // current path package raises for this input.
        final out = await _capture(
          (o) =>
              ConsoleReporter(
                out: o,
                showSummary: false,
                relativeTo: 'relative/base/dir',
              ).report([
                _diag(
                  'unused_function',
                  'm',
                  Severity.warning,
                  _loc('lib/foo.dart'),
                ),
              ]),
        );
        expect(out, contains('foo.dart\n'));
      },
    );
  });
}
