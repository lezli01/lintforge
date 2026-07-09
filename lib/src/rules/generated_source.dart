import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:path/path.dart' as p;

/// Whether [filePath] or [unit] identifies a generated Dart source file.
///
/// The basename check covers common Dart generator outputs such as
/// `*.g.dart` and `*.freezed.dart`. The unit check covers generators that
/// instead stamp a top-of-file `// ignore_for_file: type=lint` marker.
bool isGeneratedSourceFile(String filePath, CompilationUnit? unit) {
  if (_hasGeneratedSourceBasename(filePath)) return true;
  if (unit == null) return false;
  return _hasTypeLintIgnoreForFile(unit);
}

bool _hasGeneratedSourceBasename(String filePath) {
  final base = p.basename(filePath);
  return base.endsWith('.g.dart') || base.endsWith('.freezed.dart');
}

bool _hasTypeLintIgnoreForFile(CompilationUnit unit) {
  CommentToken? comment = unit.beginToken.precedingComments;
  while (comment != null) {
    if (_isTypeLintIgnoreForFileComment(comment.lexeme)) return true;
    comment = comment.next as CommentToken?;
  }
  return false;
}

bool _isTypeLintIgnoreForFileComment(String lexeme) {
  if (!lexeme.startsWith('//')) return false;
  final body = lexeme.substring(2).trim();
  const prefix = 'ignore_for_file:';
  if (!body.startsWith(prefix)) return false;
  for (final code in body.substring(prefix.length).split(',')) {
    if (code.trim() == 'type=lint') return true;
  }
  return false;
}
