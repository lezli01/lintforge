/// Terminal styling primitives: a tiny, dependency-free ANSI SGR palette.
///
/// The palette can be globally [enabled] or disabled. When it is disabled
/// every helper returns its argument unchanged, so call sites can build
/// styled strings unconditionally and let the palette decide — once, at
/// construction — whether escape codes are actually emitted. This keeps the
/// "should we use color?" decision in exactly one place (the CLI) instead of
/// scattering `if (color) …` branches through every formatter.
///
/// Helpers never nest: each returns a self-contained string that opens with
/// the requested Select Graphic Rendition (SGR) codes and closes with a
/// reset (`\x1B[0m`). Compose multiple attributes in a single call via
/// [paint] (for example `paint(text, const [bold, red])`) rather than
/// wrapping one helper's output in another, which would reset the outer
/// style early.
library;

/// A palette of ANSI styles gated by a single [enabled] flag.
class Ansi {
  /// Whether escape codes are emitted. When `false`, every helper is the
  /// identity function.
  final bool enabled;

  /// Creates a palette that emits escape codes when [enabled] is `true`.
  const Ansi({required this.enabled});

  /// A palette that never emits escape codes.
  ///
  /// Use as a safe default for sinks that are not interactive terminals
  /// (files, pipes, in-memory buffers) or when the user opted out of color.
  const Ansi.disabled() : enabled = false;

  /// SGR code: reset all attributes.
  static const int reset = 0;

  /// SGR code: bold / increased intensity.
  static const int bold = 1;

  /// SGR code: faint / decreased intensity (rendered as dim/grey).
  static const int dim = 2;

  /// SGR code: italic.
  static const int italic = 3;

  /// SGR code: underline.
  static const int underline = 4;

  /// SGR code: foreground red.
  static const int red = 31;

  /// SGR code: foreground green.
  static const int green = 32;

  /// SGR code: foreground yellow.
  static const int yellow = 33;

  /// SGR code: foreground blue.
  static const int blue = 34;

  /// SGR code: foreground magenta.
  static const int magenta = 35;

  /// SGR code: foreground cyan.
  static const int cyan = 36;

  /// SGR code: foreground bright-black, i.e. grey.
  static const int grey = 90;

  /// Wraps [text] in the given SGR [codes], or returns it unchanged when the
  /// palette is [enabled] `== false` or [codes] is empty.
  ///
  /// Codes are combined into a single escape sequence
  /// (`\x1B[<c1>;<c2>;…m`), so passing `const [bold, red]` yields bold red
  /// text closed by exactly one reset.
  String paint(String text, List<int> codes) {
    if (!enabled || codes.isEmpty) return text;
    final joined = codes.join(';');
    return '\x1B[${joined}m$text\x1B[${reset}m';
  }

  /// Renders [text] bold.
  String strong(String text) => paint(text, const [bold]);

  /// Renders [text] dim/grey — for secondary detail that should recede.
  String faint(String text) => paint(text, const [dim]);

  /// Removes every ANSI SGR escape sequence from [text].
  ///
  /// Useful for measuring the *visible* width of a styled string and for
  /// asserting on styled output in tests.
  static String strip(String text) => text.replaceAll(_sgrPattern, '');

  static final RegExp _sgrPattern = RegExp(r'\x1B\[[0-9;]*m');
}
