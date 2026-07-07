import 'dart:io';

import 'package:lintforge/src/diagnostic.dart';
import 'package:lintforge/src/multi_file_analysis_context.dart';
import 'package:lintforge/src/rules/unused_source_file_rule.dart';
import 'package:lintforge/src/severity.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedSourceFileRule', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_source_file_rule_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<List<Diagnostic>> runRule(
      Map<String, String> files, {
      Set<String> excluded = const <String>{},
    }) async {
      final paths = <String>[];
      final excludedAbs = <String>{};
      for (final entry in files.entries) {
        final file = File(p.join(tempDir.path, entry.key));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
        final abs = p.normalize(p.absolute(file.path));
        paths.add(abs);
        if (excluded.contains(entry.key)) {
          excludedAbs.add(abs);
        }
      }
      if (paths.isEmpty) {
        final context = MultiFileAnalysisContext(
          units: const <ResolvedUnitResult>[],
          analyzedFilePaths: const <String>{},
        );
        return const UnusedSourceFileRule().analyze(context).toList();
      }
      final collection = AnalysisContextCollection(
        includedPaths: paths,
        sdkPath: _resolveSdkPath(),
      );
      final units = <ResolvedUnitResult>[];
      for (final path in paths) {
        final session = collection.contextFor(path).currentSession;
        final result = await session.getResolvedUnit(path);
        expect(result, isA<ResolvedUnitResult>());
        units.add(result as ResolvedUnitResult);
      }
      final context = MultiFileAnalysisContext(
        units: units,
        analyzedFilePaths: paths.toSet(),
        reportableFilePaths: excludedAbs.isEmpty
            ? null
            : paths.where((p) => !excludedAbs.contains(p)).toSet(),
      );
      return const UnusedSourceFileRule().analyze(context).toList();
    }

    test('exposes the rule contract', () {
      const rule = UnusedSourceFileRule();
      expect(rule.id, 'unused_source_file');
      expect(rule.description, isNotEmpty);
      expect(rule.defaultSeverity, Severity.warning);
    });

    test('empty input emits nothing', () async {
      final diagnostics = await runRule(const <String, String>{});
      expect(diagnostics, isEmpty);
    });

    test('a fully-used graph emits nothing', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): "export 'src/foo.dart';\n",
        p.join('lib', 'src', 'foo.dart'):
            "import 'bar.dart';\nint useBar() => bar();\n",
        p.join('lib', 'src', 'bar.dart'): 'int bar() => 1;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('an orphan lib/src file is flagged', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): '// public surface\n',
        p.join('lib', 'src', 'orphan.dart'): 'int orphan() => 1;\n',
      });
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_source_file');
      expect(diagnostic.severity, Severity.warning);
      expect(
        diagnostic.location.filePath,
        p.normalize(
          p.absolute(p.join(tempDir.path, 'lib', 'src', 'orphan.dart')),
        ),
      );
      expect(diagnostic.location.offset, 0);
      expect(diagnostic.location.length, 0);
      expect(diagnostic.location.line, 1);
      expect(diagnostic.location.column, 1);
      expect(diagnostic.message, contains('orphan.dart'));
      expect(
        diagnostic.message,
        contains('never imported, exported, or used as a part'),
      );
    });

    test('a file reached only via export is not flagged', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): "export 'src/exported.dart';\n",
        p.join('lib', 'src', 'exported.dart'): 'int answer() => 42;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('a file reached only via part is not flagged', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): "library pkg;\npart 'src/parted.dart';\n",
        p.join('lib', 'src', 'parted.dart'):
            "part of pkg;\nint partAnswer() => 7;\n",
      });
      expect(diagnostics, isEmpty);
    });

    test(
      'transitive reachability through a chain of imports is honored',
      () async {
        final diagnostics = await runRule({
          p.join('bin', 'tool.dart'):
              "import '../lib/src/a.dart';\nvoid main() { a(); }\n",
          p.join('lib', 'src', 'a.dart'): "import 'b.dart';\nint a() => b();\n",
          p.join('lib', 'src', 'b.dart'): "import 'c.dart';\nint b() => c();\n",
          p.join('lib', 'src', 'c.dart'): 'int c() => 1;\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'a bin/ entry point and a top-level main function are both treated as roots',
      () async {
        final diagnostics = await runRule({
          p.join(
            'bin',
            'tool.dart',
          ): "import '../lib/src/from_bin.dart';\nvoid main() { fromBin(); }\n",
          p.join('lib', 'src', 'from_bin.dart'): 'int fromBin() => 1;\n',
          // A loose file with a top-level main() should also be a root, even
          // though its path does not match bin/, test/, or lib/<file>.dart.
          p.join(
            'scripts',
            'oneoff.dart',
          ): "import '../lib/src/from_main.dart';\nvoid main() { fromMain(); }\n",
          p.join('lib', 'src', 'from_main.dart'): 'int fromMain() => 2;\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'lib/<package>.dart and other lib/*.dart files are treated as roots',
      () async {
        final diagnostics = await runRule({
          // The package root surface.
          p.join('lib', 'pkg.dart'): "export 'src/from_pkg.dart';\n",
          // Another top-level public file.
          p.join('lib', 'extras.dart'): "export 'src/from_extras.dart';\n",
          p.join('lib', 'src', 'from_pkg.dart'): 'int fromPkg() => 1;\n',
          p.join('lib', 'src', 'from_extras.dart'): 'int fromExtras() => 2;\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test('diagnostics are sorted by file path', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): '// public surface\n',
        p.join('lib', 'src', 'zeta.dart'): 'int zeta() => 1;\n',
        p.join('lib', 'src', 'alpha.dart'): 'int alpha() => 1;\n',
        p.join('lib', 'src', 'mid.dart'): 'int mid() => 1;\n',
      });
      expect(diagnostics, hasLength(3));
      final paths = diagnostics.map((d) => d.location.filePath).toList();
      final sorted = [...paths]..sort();
      expect(paths, sorted);
    });

    test('test/ files are treated as entry points', () async {
      final diagnostics = await runRule({
        p.join('test', 'foo_test.dart'):
            "import '../lib/src/foo.dart';\nvoid main() { foo(); }\n",
        p.join('lib', 'src', 'foo.dart'): 'int foo() => 1;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('a conditional export resolves both branches as reachable', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'):
            "export 'src/mobile_impl.dart'\n"
            "    if (dart.library.html) 'src/web_impl.dart';\n",
        p.join('lib', 'src', 'mobile_impl.dart'): 'int mobile() => 1;\n',
        p.join('lib', 'src', 'web_impl.dart'): 'int web() => 2;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('a conditional import resolves both branches as reachable', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'):
            "import 'src/mobile_impl.dart'\n"
            "    if (dart.library.html) 'src/web_impl.dart';\n"
            'int use() => mobile();\n',
        p.join('lib', 'src', 'mobile_impl.dart'): 'int mobile() => 1;\n',
        p.join('lib', 'src', 'web_impl.dart'): 'int web() => 2;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test(
      'transitive reachability via a conditional branch is honored',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'):
              "export 'src/mobile_impl.dart'\n"
              "    if (dart.library.html) 'src/web_impl.dart';\n",
          p.join('lib', 'src', 'mobile_impl.dart'): 'int mobile() => 1;\n',
          // The web branch is the *only* path that reaches `web_helper.dart`.
          // The web branch is inactive on the VM, but the rule must still
          // treat `web_helper.dart` as reachable so neither file is flagged.
          p.join('lib', 'src', 'web_impl.dart'):
              "import 'web_helper.dart';\nint web() => helper();\n",
          p.join('lib', 'src', 'web_helper.dart'): 'int helper() => 3;\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'a file referenced only by a non-existent conditional URI is still flagged',
      () async {
        // `web_impl.dart` is mentioned only in a conditional branch whose
        // URI does not resolve to any file in the analyzed set (the import
        // points at a file that was deleted). It must therefore remain an
        // orphan and be flagged.
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'):
              "export 'src/mobile_impl.dart'\n"
              "    if (dart.library.html) 'src/missing.dart';\n",
          p.join('lib', 'src', 'mobile_impl.dart'): 'int mobile() => 1;\n',
          p.join('lib', 'src', 'web_impl.dart'): 'int web() => 2;\n',
        });
        expect(diagnostics, hasLength(1));
        expect(
          diagnostics.single.location.filePath,
          p.normalize(
            p.absolute(p.join(tempDir.path, 'lib', 'src', 'web_impl.dart')),
          ),
        );
      },
    );

    test('generated-file basenames are skipped defensively', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): '// public surface\n',
        p.join('lib', 'src', 'thing.g.dart'): '// generated\n',
        p.join('lib', 'src', 'model.freezed.dart'): '// generated\n',
      });
      expect(diagnostics, isEmpty);
    });

    test(
      'follows every configuration of a conditional import regardless of the active platform',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'): "import 'src/hub.dart';\n",
          p.join('lib', 'src', 'hub.dart'):
              "import 'io_impl.dart'\n"
              "    if (dart.library.io) 'io_impl.dart'\n"
              "    if (dart.library.html) 'web_impl.dart';\n"
              "String useIt() => platformName();\n",
          p.join('lib', 'src', 'io_impl.dart'):
              "String platformName() => 'io';\n",
          p.join('lib', 'src', 'web_impl.dart'):
              "String platformName() => 'web';\n",
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'flags a configuration target that nothing else reaches once the conditional is removed',
      () async {
        // Sanity check: without the conditional import, the platform-specific
        // file is unreachable. This confirms the previous test's silence is
        // produced by the configuration edge, not by some other path.
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'): "import 'src/hub.dart';\n",
          p.join('lib', 'src', 'hub.dart'): "int hub() => 1;\n",
          p.join('lib', 'src', 'web_impl.dart'):
              "String platformName() => 'web';\n",
        });
        expect(diagnostics, hasLength(1));
        expect(
          diagnostics.single.location.filePath,
          p.normalize(
            p.absolute(p.join(tempDir.path, 'lib', 'src', 'web_impl.dart')),
          ),
        );
      },
    );

    test('a file reached only via a deferred import is not flagged', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): "import 'src/hub.dart';\n",
        p.join('lib', 'src', 'hub.dart'):
            "import 'deferred.dart' deferred as d;\n"
            "Future<int> hub() async {\n"
            "  await d.loadLibrary();\n"
            "  return d.deferredValue;\n"
            "}\n",
        p.join('lib', 'src', 'deferred.dart'): 'const int deferredValue = 7;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test(
      'an excluded entry point can anchor reachability for a reportable file',
      () async {
        // `bin/script.dart` is excluded from reporting (only present in
        // `analyzedFilePaths`, not in `reportableFilePaths`), but it carries
        // a top-level `main` and imports the otherwise-orphan reportable file
        // `lib/src/used_by_script.dart`. The reportable file must therefore
        // NOT be flagged: reachability is computed over the full loaded set.
        final diagnostics = await runRule(
          {
            p.join('bin', 'script.dart'):
                "import '../lib/src/used_by_script.dart';\n"
                "void main() { fromScript(); }\n",
            p.join('lib', 'src', 'used_by_script.dart'):
                'int fromScript() => 1;\n',
          },
          excluded: {p.join('bin', 'script.dart')},
        );
        expect(diagnostics, isEmpty);
      },
    );

    test('an excluded file is never the subject of a diagnostic, '
        'and the reportable file that imports it is unaffected', () async {
      // `lib/src/excluded.dart` is excluded from reporting. The reportable
      // entry point `lib/pkg.dart` is the only file that imports it. Two
      // things must hold:
      //   * the excluded file must NOT be flagged (it is not reportable);
      //   * the importing reportable file is itself an entry point and
      //     must NOT be flagged either.
      final diagnostics = await runRule(
        {
          p.join('lib', 'pkg.dart'):
              "import 'src/excluded.dart';\nint use() => excluded();\n",
          p.join('lib', 'src', 'excluded.dart'): 'int excluded() => 1;\n',
        },
        excluded: {p.join('lib', 'src', 'excluded.dart')},
      );
      expect(diagnostics, isEmpty);
    });

    test(
      'regression: single-file orphan flagging works when no excludes are configured',
      () async {
        // With no excludes, `reportableFilePaths` defaults to the full
        // analyzed set, and the historical orphan-flagging behavior must be
        // preserved verbatim.
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'): '// public surface\n',
          p.join('lib', 'src', 'orphan.dart'): 'int orphan() => 1;\n',
        });
        expect(diagnostics, hasLength(1));
        expect(
          diagnostics.single.location.filePath,
          p.normalize(
            p.absolute(p.join(tempDir.path, 'lib', 'src', 'orphan.dart')),
          ),
        );
      },
    );

    test(
      'a `part of <uri>` library is reached transitively via its owner',
      () async {
        // Pins the existing graph behavior for URI-style `part of` files: the
        // owning library's `PartDirective` contributes the forward edge, so
        // the part is reachable from the owning library's entry point even
        // though the `part of '...'` directive itself never appears as an
        // outgoing edge.
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'): "import 'src/owner.dart';\n",
          p.join('lib', 'src', 'owner.dart'):
              "part 'parted.dart';\nint use() => partAnswer();\n",
          p.join('lib', 'src', 'parted.dart'):
              "part of 'owner.dart';\nint partAnswer() => 7;\n",
        });
        expect(diagnostics, isEmpty);
      },
    );
  });
}

String? _resolveSdkPath() {
  final defaultPath = p.dirname(p.dirname(Platform.resolvedExecutable));
  if (_looksLikeSdk(defaultPath)) return defaultPath;

  var dir = p.dirname(Platform.resolvedExecutable);
  while (true) {
    final candidate = p.join(dir, 'bin', 'cache', 'dart-sdk');
    if (_looksLikeSdk(candidate)) return candidate;
    final parent = p.dirname(dir);
    if (parent == dir) return defaultPath;
    dir = parent;
  }
}

bool _looksLikeSdk(String sdkPath) {
  return FileSystemEntity.isFileSync(
    p.join(sdkPath, 'lib', '_internal', 'allowed_experiments.json'),
  );
}
