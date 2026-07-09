// (N22) IO branch of the conditional export declared in
// `platform_export.dart`. On the VM the analyzer resolves the export to
// this file, but it is also named in an `if (dart.library.io)`
// configuration, so the `unused_function` rule treats its public declarations
// as conditional-export branch surface.
//
// The public top-level function and the public class members below sit
// under `lib/src/`, so they are NOT covered by the public-members-
// outside-`lib/src/` exemption — the ONLY reason they are not flagged is
// the conditional-export branch-target exemption.
//
// ignore_for_file: unused_element
library;

/// Platform label reported by the IO implementation.
String platformLabel() => 'io';

/// Platform service exposed through the conditional export surface.
class PlatformService {
  /// Starts the platform service.
  void start() {}

  /// Disposes the platform service.
  void dispose() {}
}
