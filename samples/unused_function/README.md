# `unused_function` sample

A self-contained Dart/Flutter package that exercises the
[`unused_function`](../../lib/src/rules/unused_function_rule.dart) rule
shipped by the [`anal`](../..) package.

The sample exists so consumers (and the rule's own contributors) can see
exactly which declarations the rule flags and which it deliberately ignores,
running against a real `pub get`-resolved project.

## Layout

```
samples/unused_function/
  pubspec.yaml                       # path-dependent on the root `anal` package
  lib/unused_function_sample.dart    # all positive + negative cases live here
```

## Run it

From the repository root:

```sh
fvm dart pub get --directory samples/unused_function
fvm dart run anal samples/unused_function/lib
```

## Expected output

Exactly two `unused_function` diagnostics — and nothing else:

```
samples/unused_function/lib/unused_function_sample.dart:18:6 • [warning] unused_function: The top-level function "_unusedPrivateTopLevel" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:48:10 • [warning] unused_function: The local function "unusedLocal" is declared but never used.
```

(Line / column numbers refer to `lib/unused_function_sample.dart`.)

### Positive cases (MUST be flagged)

| Tag  | Where                                | Why it triggers                                            |
| ---- | ------------------------------------ | ---------------------------------------------------------- |
| `P1` | top-level `_unusedPrivateTopLevel`   | Private top-level function with no reference in the unit.  |
| `P2` | local `unusedLocal` inside `doWork`  | Local function with no reference in its enclosing body.    |

### Negative cases (MUST NOT be flagged)

| Tag  | Where                                | Why the rule skips it                                                                 |
| ---- | ------------------------------------ | ------------------------------------------------------------------------------------- |
| `N1` | `publicTopLevel`                     | Public name — top-level candidates must start with `_`.                               |
| `N2` | `main`                               | The `main` entry point is exempt by name.                                             |
| `N3` | `_usedPrivate`                       | Referenced as both a direct call and a tear-off in `main`.                            |
| `N4` | `external _externalPrivate`          | `external` top-level functions are exempt regardless of name.                         |
| `N5` | `@pragma('vm:entry-point')` private  | `@pragma('vm:entry-point')` annotated declarations are exempt regardless of name.     |

A used local function (`usedLocal` inside `Service.doWork`) is also included
so the negative side of the local-function path is exercised.
