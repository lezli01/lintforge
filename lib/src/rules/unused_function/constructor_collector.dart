part of '../unused_function_rule.dart';

/// Collector for constructor declarations on classes and enums.
///
/// Every [ConstructorDeclaration] member of a [ClassDeclaration] or
/// [EnumDeclaration] is a candidate, covering generative, named, factory,
/// and redirecting forms. The synthetic unnamed constructor the analyzer
/// inserts when a class declares no constructors is intentionally not
/// considered: this collector only iterates AST nodes, and that
/// constructor has no [ConstructorDeclaration] in the source.
///
/// A constructor is exempt when it is `external`, carries
/// `@pragma('vm:entry-point')`, or is declared on a public class as part of
/// that class's public API surface outside `lib/src/`. Enum constructors are
/// not externally invocable API, so they remain candidates. The collector
/// additionally skips every constructor on a class or enum when the enclosing declaration —
/// or any class / mixin / interface reached through `extends`, `with`,
/// `implements`, or mixin `on` clauses — declares its own
/// `noSuchMethod`, because such a type can intercept any
/// otherwise-missing call by name and the rule cannot tell whether a
/// constructor is truly unused or invoked through reflection / dynamic
/// dispatch on its enclosing type. The walk also recognises mocktail's
/// `Fake` and `Mock` base classes by simple name, since the analyzed
/// sources typically do not pull in `package:mocktail` as a resolved
/// dependency. See [_enclosingDeclaresNoSuchMethod].
///
/// Every constructor of a [ClassDeclaration] whose metadata carries a
/// `@freezed`, `@Freezed(...)`, `@unfreezed`, `@Unfreezed(...)`, or
/// `@FreezedUnion(...)` annotation is likewise skipped — the boilerplate
/// constructors `package:freezed` expects (private generative `Foo._()`,
/// unnamed forwarding factory, and one named factory per union case)
/// are only invoked from generated `*.freezed.dart` parts, which are
/// usually absent when the rule runs. See [_hasFreezedAnnotation].
///
/// To avoid duplicate noise with `unused_class`, the rule's dispatch
/// site additionally skips a constructor candidate when its enclosing
/// class element is itself absent from the global reference index —
/// `unused_class` already flags that class, and re-flagging every
/// constructor of it would just repeat the report.
///
/// The diagnostic anchor is the constructor's name [Token] for named
/// constructors (e.g. `named` in `MyClass.named()`), and the class name
/// [Token] for the unnamed default constructor (e.g. `MyClass` in
/// `MyClass();`).
class _ConstructorCollector implements _UnusedFunctionCandidateCollector {
  const _ConstructorCollector();

  @override
  Iterable<_Candidate> collect(
    ResolvedUnitResult unit,
    _CollectorContext context,
  ) sync* {
    for (final declaration in unit.unit.declarations) {
      if (declaration is ClassDeclaration) {
        // analyzer 11 removed `ClassDeclaration.name`; the class-name token
        // now lives on `namePart.typeName`.
        final classNameToken = declaration.namePart.typeName;
        // analyzer 11 removed `ClassDeclaration.members`; the members now live
        // on the declaration body. In analyzer 13 `ClassBody` exposes
        // `members` on the sealed base, so no downcast is needed.
        final members = declaration.body.members;
        final enclosing = declaration.declaredFragment?.element;
        if (enclosing != null && _enclosingDeclaresNoSuchMethod(enclosing)) {
          continue;
        }
        if (_hasFreezedAnnotation(declaration.metadata)) continue;
        for (final member in members) {
          if (member is! ConstructorDeclaration) continue;
          final candidate = _candidateFor(
            member,
            classNameToken,
            enclosingTypeName: classNameToken.lexeme,
            filePath: unit.path,
            canBePublicApi: true,
          );
          if (candidate != null) yield candidate;
        }
      } else if (declaration is EnumDeclaration) {
        // See the `ClassDeclaration` branch above: analyzer 11 removed
        // `EnumDeclaration.name` and `EnumDeclaration.members`; read them from
        // `namePart.typeName` and the declaration body respectively.
        final enumNameToken = declaration.namePart.typeName;
        final members = declaration.body.members;
        final enclosing = declaration.declaredFragment?.element;
        if (enclosing != null && _enclosingDeclaresNoSuchMethod(enclosing)) {
          continue;
        }
        for (final member in members) {
          if (member is! ConstructorDeclaration) continue;
          final candidate = _candidateFor(
            member,
            enumNameToken,
            enclosingTypeName: enumNameToken.lexeme,
            filePath: unit.path,
            canBePublicApi: false,
          );
          if (candidate != null) yield candidate;
        }
      }
    }
  }

  _Candidate? _candidateFor(
    ConstructorDeclaration declaration,
    Token classNameToken, {
    required String enclosingTypeName,
    required String filePath,
    required bool canBePublicApi,
  }) {
    if (declaration.externalKeyword != null) return null;
    if (_hasVmEntryPointPragma(declaration.metadata)) return null;
    final nameToken = declaration.name ?? classNameToken;
    if (canBePublicApi &&
        _isPublicMemberOfPublicTypeOutsideLibSrc(
          nameToken.lexeme,
          enclosingTypeName,
          filePath,
        )) {
      return null;
    }
    final element = declaration.declaredFragment?.element;
    if (element == null) return null;
    return _Candidate(
      nameToken: nameToken,
      element: _declaredElement(element),
      kindLabel: 'constructor',
      isConditionalBranchApi:
          canBePublicApi &&
          _isPublicMemberOfPublicType(nameToken.lexeme, enclosingTypeName),
    );
  }
}
