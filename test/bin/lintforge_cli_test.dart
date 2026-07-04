import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String _dartExecutable() {
  final exe = Platform.resolvedExecutable;
  if (p.basenameWithoutExtension(exe) == 'dart') {
    return exe;
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    return p.join(flutterRoot, 'bin', 'cache', 'dart-sdk', 'bin', 'dart');
  }
  return 'dart';
}

void main() {
  group('--list-rules', () {
    test(
      'prints registered rules and exits 0',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await Process.run(_dartExecutable(), [
          'run',
          'lintforge',
          '--list-rules',
        ]);

        final stdoutText = result.stdout as String;
        final stderrText = result.stderr as String;

        expect(
          result.exitCode,
          0,
          reason: 'stdout: $stdoutText\nstderr: $stderrText',
        );
        expect(stdoutText, startsWith('Available rules:\n\n'));

        expect(
          stdoutText,
          matches(
            RegExp(r'^  unused_function\s+warning\s+.+$', multiLine: true),
          ),
        );
        expect(
          stdoutText,
          matches(RegExp(r'^  unused_class\s+warning\s+.+$', multiLine: true)),
        );
        expect(
          stdoutText,
          matches(
            RegExp(r'^  unused_source_file\s+warning\s+.+$', multiLine: true),
          ),
        );

        expect(stdoutText, isNot(contains('No issues found')));
        expect(stderrText, isEmpty);

        final classIndex = stdoutText.indexOf('unused_class');
        final functionIndex = stdoutText.indexOf('unused_function');
        final sourceIndex = stdoutText.indexOf('unused_source_file');
        expect(classIndex, greaterThan(-1));
        expect(functionIndex, greaterThan(-1));
        expect(sourceIndex, greaterThan(-1));
        expect(classIndex, lessThan(functionIndex));
        expect(functionIndex, lessThan(sourceIndex));
      },
    );

    test(
      '--list-rules --help still prints usage',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await Process.run(_dartExecutable(), [
          'run',
          'lintforge',
          '--list-rules',
          '--help',
        ]);

        expect(result.exitCode, 0);
        expect(result.stdout as String, startsWith('Usage:'));
      },
    );
  });

  group('analysis output', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lintforge_cli_out_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    void write(String relativePath, String contents) {
      final file = File(p.join(tempDir.path, relativePath));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
    }

    Future<ProcessResult> runLintforge(
      List<String> args, {
      Map<String, String>? environment,
    }) {
      return Process.run(_dartExecutable(), [
        'run',
        'lintforge',
        ...args,
      ], environment: environment);
    }

    test(
      'a clean project reports no issues, exits 0, and emits no color '
      'when stdout is a pipe',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        write(p.join('lib', 'main.dart'), 'void main() {}\n');

        // Neutralize any ambient NO_COLOR / FORCE_COLOR so the assertion
        // depends only on stdout being a pipe. Empty values are ignored by
        // the CLI's color detection, and override anything inherited.
        final result = await runLintforge(
          [p.join(tempDir.path, 'lib')],
          environment: const {'NO_COLOR': '', 'FORCE_COLOR': ''},
        );
        final stdoutText = result.stdout as String;

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        expect(stdoutText, contains('No issues found'));
        expect(stdoutText, isNot(contains('\x1B[')));
      },
    );

    test(
      'FORCE_COLOR forces ANSI color even when stdout is a pipe',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        write(p.join('lib', 'main.dart'), 'void main() {}\n');

        // Empty NO_COLOR neutralizes any inherited NO_COLOR (which would
        // otherwise win over FORCE_COLOR); FORCE_COLOR=1 forces color on.
        final result = await runLintforge(
          [p.join(tempDir.path, 'lib')],
          environment: const {'NO_COLOR': '', 'FORCE_COLOR': '1'},
        );

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        expect(result.stdout as String, contains('\x1B['));
      },
    );

    test(
      'findings are summarized and a warning-only run still exits 0',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        write(p.join('lib', 'src', 'thing.dart'), 'void _unused() {}\n');
        write(
          p.join('lib', 'app.dart'),
          "import 'src/thing.dart';\n\nvoid main() {}\n",
        );

        final result = await runLintforge([p.join(tempDir.path, 'lib')]);
        final stdoutText = result.stdout as String;

        expect(
          result.exitCode,
          0,
          reason: 'stdout: $stdoutText\nstderr: ${result.stderr}',
        );
        expect(stdoutText, contains('unused_function'));
        expect(stdoutText, matches(RegExp(r'\d+ issue(s)? found')));
      },
    );
  });
}
