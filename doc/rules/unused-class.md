# `unused_class`

`unused_class` flags private class-like declarations that are never referenced
inside the same compilation unit.

| Field | Value |
| ----- | ----- |
| Rule id | `unused_class` |
| Default severity | `warning` |
| Dispatch | single-file |

## What it reports

The rule reports unused private declarations whose names begin with `_`:

- classes
- mixins
- enums
- extension types

Diagnostics use this shape:

```text
The <kind> "<name>" is declared but never used.
```

The correction is:

```text
Remove "<name>" or reference it.
```

## What counts as a use

Any resolved reference to the declaration in the same unit counts, including:

- type annotations
- constructor invocations
- `extends`, `implements`, `with`, and `on` clauses
- `is` checks
- `as` casts
- static member access
- enum value access
- object patterns
- record type annotations
- sealed-supertype switch patterns through referenced subtypes

## Important exemptions

The rule deliberately skips:

- public class-like declarations
- typedef-style class aliases (`class _Foo = A with B;`)
- non-type extension declarations (`extension _Ext on T`)
- declarations annotated with `@pragma('vm:entry-point')`
- any unit that imports `dart:mirrors`
- libraries with part files
- declarations inside files already reported by `unused_source_file`

Because the rule is single-file, references from sibling files do not make a
private declaration count as used. That matches Dart privacy: `_PrivateName` is
library-private, and a single-file library is the common case this rule targets.

## Examples

Flagged:

```dart
class _UnusedClass {}

mixin _UnusedMixin {}

enum _UnusedEnum { value }

extension type _UnusedId(int value) {}
```

Not flagged:

```dart
class _UsedAsType {}

void takes(_UsedAsType value) {}
```

Not flagged because it may be reflectively reached:

```dart
import 'dart:mirrors';

class _ReflectiveType {}
```

## Sample

See `samples/unused_class/` and `samples/all_rules/` for executable positive
and negative cases.
