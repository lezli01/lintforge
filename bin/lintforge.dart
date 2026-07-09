import 'dart:io';

import 'package:lintforge/src/analysis_progress.dart';
import 'package:lintforge/src/lintforge_options.dart';
import 'package:lintforge/src/analysis_runner.dart';
import 'package:lintforge/src/reporter.dart';
import 'package:lintforge/src/rule_registry.dart';
import 'package:lintforge/src/rules/unused_class_rule.dart';
import 'package:lintforge/src/rules/unused_function_rule.dart';
import 'package:lintforge/src/rules/unused_source_file_rule.dart';
import 'package:lintforge/src/severity.dart';
import 'package:lintforge/src/terminal/ansi.dart';
import 'package:lintforge/src/terminal/color_support.dart';
import 'package:lintforge/src/terminal/progress_reporter.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const String _version = '0.4.2'; // x-release-please-version

Future<void> main(List<String> arguments) async {
  final parser = _buildArgParser();

  final ArgResults parsed;
  try {
    parsed = parser.parse(arguments);
  } on FormatException catch (error) {
    // Parsing failed before we could read an explicit --color preference, so
    // fall back to auto-detection for the error/usage output.
    final ansi = _resolveFor(ColorPreference.auto, stderr);
    stderr.writeln(ansi.paint(error.message, const <int>[Ansi.red]));
    stderr.writeln();
    stderr.writeln(_usage(parser, ansi));
    exitCode = 64;
    return;
  }

  final preference = _preference(parsed.wasParsed('color') ? parsed : null);
  final stdoutAnsi = _resolveFor(preference, stdout);
  final stderrAnsi = _resolveFor(preference, stderr);

  if (parsed['help'] as bool) {
    stdout.writeln(_usage(parser, stdoutAnsi));
    return;
  }

  if (parsed['version'] as bool) {
    stdout.writeln(_version);
    return;
  }

  if (parsed['list-rules'] as bool) {
    _printRuleListing(_buildRegistry(), stdout, stdoutAnsi);
    return;
  }

  final registry = _buildRegistry();
  final options = _buildOptions(parsed);
  final unknownRuleIds = _unknownRuleIds(options.enabledRuleIds, registry);
  if (unknownRuleIds.isNotEmpty) {
    stderr.writeln(
      stderrAnsi.paint(
        _unknownRulesMessage(unknownRuleIds, registry),
        const <int>[Ansi.red],
      ),
    );
    stderr.writeln();
    stderr.writeln(_usage(parser, stderrAnsi));
    exitCode = 64;
    return;
  }

  final cwd = Directory.current.path;
  final progress = ProgressReporter(
    out: stderr,
    enabled: stderr.hasTerminal && stderr.supportsAnsiEscapes,
    ansi: stderrAnsi,
    width: _terminalWidth(),
  );

  // Immediate feedback: the analyzer's context-collection setup runs before
  // the first per-file callback, so show an indeterminate tick right away.
  progress.report(phase: 'Analyzing', completed: 0, total: 0);

  final runner = AnalysisRunner(
    registry: registry,
    options: options,
    onProgress: (update) {
      final phaseLabel = switch (update.phase) {
        AnalysisPhase.resolving => 'Analyzing',
        AnalysisPhase.crossFile => 'Cross-file analysis',
      };
      final path = update.currentPath;
      progress.report(
        phase: phaseLabel,
        completed: update.completed,
        total: update.total,
        detail: path == null ? null : _relative(path, cwd),
      );
    },
  );

  final diagnostics = await runner.run();
  progress.clear();

  ConsoleReporter(
    out: stdout,
    ansi: stdoutAnsi,
    relativeTo: cwd,
  ).report(diagnostics);

  if (diagnostics.any((d) => d.severity == Severity.error)) {
    exitCode = 1;
  }
}

ColorPreference _preference(ArgResults? parsed) {
  if (parsed == null) return ColorPreference.auto;
  return (parsed['color'] as bool)
      ? ColorPreference.always
      : ColorPreference.never;
}

Ansi _resolveFor(ColorPreference preference, Stdout stream) {
  return resolveAnsi(
    preference: preference,
    hasTerminal: stream.hasTerminal,
    supportsAnsiEscapes: stream.supportsAnsiEscapes,
    environment: Platform.environment,
  );
}

int _terminalWidth() {
  try {
    if (stderr.hasTerminal) return stderr.terminalColumns;
    if (stdout.hasTerminal) return stdout.terminalColumns;
  } on Object {
    // Fall through to the default when the platform refuses a width.
  }
  return 80;
}

String _relative(String path, String from) {
  try {
    return p.relative(path, from: from);
  } on Object {
    return path;
  }
}

ArgParser _buildArgParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information and exit.',
    )
    ..addFlag(
      'version',
      negatable: false,
      help: 'Print the package version and exit.',
    )
    ..addFlag(
      'list-rules',
      negatable: false,
      help:
          'List the registered rules with their severity and description, '
          'then exit.',
    )
    ..addFlag(
      'color',
      negatable: true,
      help:
          'Force colored output on (--color) or off (--no-color). '
          'When omitted, color is auto-detected from the terminal and the '
          'NO_COLOR / FORCE_COLOR environment variables.',
    )
    ..addOption(
      'rules',
      help:
          'Comma-separated list of rule ids to enable. '
          'When omitted, every registered rule is enabled.',
      valueHelp: 'id,id,...',
    )
    ..addMultiOption(
      'exclude',
      help:
          'Glob pattern to exclude from analysis. '
          'May be passed multiple times. '
          'Layered on top of the built-in default excludes unless '
          '--no-default-excludes is given.',
      valueHelp: 'glob',
      splitCommas: false,
    )
    ..addFlag(
      'default-excludes',
      defaultsTo: true,
      negatable: true,
      help:
          'Apply the built-in exclude patterns '
          '(*.g.dart, *.freezed.dart, **/.dart_tool/**, **/build/**). '
          'Use --no-default-excludes to opt out.',
    );
}

LintforgeOptions _buildOptions(ArgResults parsed) {
  final paths = parsed.rest;
  final excludes = parsed['exclude'] as List<String>;
  final rulesArg = parsed['rules'] as String?;
  final useDefaults = parsed['default-excludes'] as bool;

  const defaults = LintforgeOptions.defaults();

  final includePaths = paths.isEmpty
      ? defaults.includePaths
      : List<String>.unmodifiable(paths);

  final excludePaths = List<String>.unmodifiable([
    if (useDefaults) ...LintforgeOptions.defaultExcludePaths,
    ...excludes,
  ]);

  final Set<String> enabledRuleIds;
  if (rulesArg == null || rulesArg.isEmpty) {
    enabledRuleIds = const <String>{};
  } else {
    enabledRuleIds = Set<String>.unmodifiable(
      rulesArg.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
    );
  }

  return LintforgeOptions(
    includePaths: includePaths,
    excludePaths: excludePaths,
    enabledRuleIds: enabledRuleIds,
  );
}

List<String> _unknownRuleIds(
  Set<String> requestedRuleIds,
  RuleRegistry registry,
) {
  if (requestedRuleIds.isEmpty) return const <String>[];

  final availableRuleIds = _availableRuleIds(registry);
  return requestedRuleIds.where((id) => !availableRuleIds.contains(id)).toList()
    ..sort();
}

Set<String> _availableRuleIds(RuleRegistry registry) {
  return <String>{
    for (final rule in registry.rules) rule.id,
    for (final rule in registry.multiFileRules) rule.id,
  };
}

String _unknownRulesMessage(
  List<String> unknownRuleIds,
  RuleRegistry registry,
) {
  final availableRuleIds = _availableRuleIds(registry).toList()..sort();
  final noun = unknownRuleIds.length == 1 ? 'id' : 'ids';

  return 'Unknown rule $noun: ${unknownRuleIds.join(', ')}.\n'
      'Available rule ids: ${availableRuleIds.join(', ')}.';
}

String _usage(ArgParser parser, Ansi ansi) {
  final title = ansi.paint('LintForge', const <int>[Ansi.bold, Ansi.cyan]);
  return 'Usage: lintforge [options] [paths...]\n'
      '\n'
      '$title — static analysis for Dart and Flutter projects.\n'
      '\n'
      '${ansi.paint('Options:', const <int>[Ansi.bold])}\n'
      '${parser.usage}';
}

RuleRegistry _buildRegistry() {
  final registry = RuleRegistry();
  registry.registerMultiFile(UnusedFunctionRule());
  registry.registerMultiFile(UnusedClassRule());
  registry.registerMultiFile(UnusedSourceFileRule());
  return registry;
}

void _printRuleListing(RuleRegistry registry, StringSink out, Ansi ansi) {
  final entries = <({String id, Severity severity, String description})>[
    for (final rule in registry.rules)
      (
        id: rule.id,
        severity: rule.defaultSeverity,
        description: rule.description,
      ),
    for (final rule in registry.multiFileRules)
      (
        id: rule.id,
        severity: rule.defaultSeverity,
        description: rule.description,
      ),
  ]..sort((a, b) => a.id.compareTo(b.id));

  var idWidth = 0;
  for (final entry in entries) {
    if (entry.id.length > idWidth) {
      idWidth = entry.id.length;
    }
  }

  out.write('${ansi.paint('Available rules:', const <int>[Ansi.bold])}\n\n');
  for (final entry in entries) {
    out.write(
      '  '
      '${ansi.paint(entry.id.padRight(idWidth + 2), const <int>[Ansi.cyan])}'
      '${ansi.paint(entry.severity.name.padRight(9), _severityStyle(entry.severity))}'
      '${ansi.paint(entry.description, const <int>[Ansi.dim])}'
      '\n',
    );
  }
}

List<int> _severityStyle(Severity severity) => switch (severity) {
  Severity.error => const <int>[Ansi.bold, Ansi.red],
  Severity.warning => const <int>[Ansi.bold, Ansi.yellow],
  Severity.info => const <int>[Ansi.bold, Ansi.cyan],
};
