// Sample file exercising the `unused_function` rule.
//
// The expected diagnostics for this file are documented in this sample's
// README. Two declarations in this file MUST be flagged; everything else MUST
// be silent.
//
// The SDK's built-in `unused_element` lint is disabled for this file because
// it would fire on the very declarations the sample is built to demonstrate;
// those declarations are still flagged by the `anal` runner under the
// `unused_function` rule, which is the point of the sample.
// ignore_for_file: unused_element
library;

// === POSITIVE CASES (MUST trigger unused_function) ===

// (P1) Unused private top-level function. The library has no part files and
// no reference to `_unusedPrivateTopLevel` exists, so the rule flags it.
void _unusedPrivateTopLevel() {}

// === NEGATIVE CASES (MUST NOT trigger unused_function) ===

// (N1) Public top-level function — the rule only inspects private names.
void publicTopLevel() {}

// (N2) The library entry point — exempted by name `main`.
void main() {
  // (N3) Private function referenced both as a direct call and as a tear-off.
  _usedPrivate();
  final tearOff = _usedPrivate;
  tearOff();

  Service().doWork();
}

void _usedPrivate() {}

// (N4) External private top-level function — exempted by `external`.
external void _externalPrivate();

// (N5) `@pragma('vm:entry-point')` annotated private function — exempted by
// the metadata exemption.
@pragma('vm:entry-point')
void _entryPointPrivate() {}

class Service {
  void doWork() {
    // (P2) Unused local function inside a method body — flagged.
    void unusedLocal() {}

    // A used local function so the negative side of the local-function case
    // is also exercised here.
    void usedLocal() {}
    usedLocal();
  }
}
