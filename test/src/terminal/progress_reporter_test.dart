import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lintforge/src/terminal/ansi.dart';
import 'package:lintforge/src/terminal/progress_reporter.dart';
import 'package:test/test.dart';

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

Future<String> _run(
  void Function(ProgressReporter progress) body, {
  bool enabled = true,
  Ansi ansi = const Ansi.disabled(),
  int width = 80,
}) async {
  final consumer = _MemoryConsumer();
  final sink = IOSink(consumer);
  body(ProgressReporter(out: sink, enabled: enabled, ansi: ansi, width: width));
  await sink.close();
  return utf8.decode(consumer.bytes);
}

/// The visible payload of a progress line: the terminal control codes (`\r`,
/// erase-to-end-of-line, and SGR color) removed, leaving what the user reads.
String _visible(String raw) =>
    Ansi.strip(raw.replaceAll('\r', '').replaceAll('\x1B[K', ''));

void main() {
  group('ProgressReporter (disabled)', () {
    test('report writes nothing', () async {
      final out = await _run(
        (p) => p.report(phase: 'Analyzing', completed: 1, total: 10),
        enabled: false,
      );
      expect(out, isEmpty);
    });

    test('clear writes nothing', () async {
      final out = await _run((p) => p.clear(), enabled: false);
      expect(out, isEmpty);
    });
  });

  group('ProgressReporter (enabled)', () {
    test(
      'a determinate report redraws in place with a bar and count',
      () async {
        final out = await _run(
          (p) => p.report(
            phase: 'Analyzing',
            completed: 3,
            total: 10,
            detail: 'lib/foo.dart',
          ),
        );
        expect(out, startsWith('\r'));
        expect(out, endsWith('\x1B[K'));
        final visible = _visible(out);
        expect(visible, contains('Analyzing'));
        expect(visible, contains('3/10'));
        expect(visible, contains('█')); // some filled bar cells
        expect(visible, contains('░')); // some empty bar cells
        expect(visible, contains('lib/foo.dart'));
      },
    );

    test(
      'an indeterminate report (total 0) shows a spinner and phase only',
      () async {
        final out = await _run(
          (p) => p.report(phase: 'Cross-file analysis', completed: 0, total: 0),
        );
        final visible = _visible(out);
        expect(visible, contains('Cross-file analysis'));
        expect(visible, isNot(contains('/')));
        expect(visible, isNot(contains('█')));
      },
    );

    test('the spinner advances one frame per call', () async {
      final out = await _run((p) {
        p.report(phase: 'Analyzing', completed: 0, total: 0);
        p.report(phase: 'Analyzing', completed: 0, total: 0);
      });
      expect(out, contains('⠋')); // first frame
      expect(out, contains('⠙')); // second frame
    });

    test('a long detail is truncated from the left to fit the width', () async {
      const long =
          'lib/src/some/deeply/nested/directory/structure/file_name.dart';
      final out = await _run(
        (p) =>
            p.report(phase: 'Analyzing', completed: 5, total: 5, detail: long),
        width: 60,
      );
      final visible = _visible(out);
      expect(visible.length, lessThanOrEqualTo(60));
      expect(visible, contains('…'));
      // The tail (most specific part of the path) is preserved.
      expect(visible, contains('file_name.dart'));
    });

    test('a narrow terminal shrinks the bar to fit', () async {
      final out = await _run(
        (p) => p.report(
          phase: 'Analyzing',
          completed: 2,
          total: 8,
          detail: 'lib/some/file.dart',
        ),
        width: 30,
      );
      final visible = _visible(out);
      expect(visible.length, lessThanOrEqualTo(30));
      expect(visible, contains('Analyzing'));
      expect(visible, contains('2/8'));
    });

    test('an ultra-narrow terminal omits the bar entirely without '
        'overflowing', () async {
      // width 18: reserved for a full bar is 19, so barWidth clamps to 0 and
      // the bar is dropped, but the phase and count still fit.
      final out = await _run(
        (p) => p.report(phase: 'Analyzing', completed: 2, total: 8),
        width: 18,
      );
      final visible = _visible(out);
      expect(visible.length, lessThanOrEqualTo(18));
      expect(visible, isNot(contains('█')));
      expect(visible, isNot(contains('░')));
      expect(visible, contains('Analyzing'));
      expect(visible, contains('2/8'));
    });

    test('a non-BMP character in the detail is truncated on a rune boundary '
        '(no broken surrogate)', () async {
      // A supplementary-plane glyph (📁, U+1F4C1) in the path must not be cut
      // mid-surrogate; the emitted text must never contain U+FFFD.
      final out = await _run(
        (p) => p.report(
          phase: 'Analyzing',
          completed: 1,
          total: 4,
          detail: 'lib/📁📁📁📁📁📁📁📁/file.dart',
        ),
        width: 44,
      );
      expect(out, isNot(contains('�')));
      expect(_visible(out).length, lessThanOrEqualTo(44));
    });

    test('clear erases a drawn line', () async {
      final out = await _run((p) {
        p.report(phase: 'Analyzing', completed: 1, total: 2);
        p.clear();
      });
      expect(out, endsWith('\r\x1B[K'));
    });

    test('clear is a no-op when nothing has been drawn', () async {
      final out = await _run((p) => p.clear());
      expect(out, isEmpty);
    });

    test('clear only erases once between draws', () async {
      final out = await _run((p) {
        p.report(phase: 'Analyzing', completed: 1, total: 2);
        p.clear();
        p.clear(); // second clear should do nothing
      });
      // Exactly one trailing erase sequence after the (single) draw.
      final erases = '\r\x1B[K'.allMatches(out).length;
      expect(erases, 1);
    });
  });

  group('ProgressReporter color', () {
    test(
      'an enabled palette emits SGR color; a disabled one does not',
      () async {
        final colored = await _run(
          (p) => p.report(phase: 'Analyzing', completed: 1, total: 2),
          ansi: const Ansi(enabled: true),
        );
        final plain = await _run(
          (p) => p.report(phase: 'Analyzing', completed: 1, total: 2),
        );

        // Colored output carries SGR sequences (…m); plain output carries none.
        expect(colored, contains('\x1B[36m')); // cyan spinner
        expect(Ansi.strip(plain), plain);
        // Both render the same visible payload.
        expect(_visible(colored), _visible(plain));
      },
    );
  });
}
