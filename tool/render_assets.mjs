// Renders the lintforge brand PNGs from the committed SVG sources.
//
// The SVGs under .github/assets are the source of truth; this script
// rasterizes them to PNG at their native dimensions so the outputs stay
// reproducible. Text (the "lintforge" wordmark + tagline) is rendered
// with system fonts, so run this on a machine that has a bold sans
// (e.g. Segoe UI / Arial) installed.
//
// Usage:
//   cd tool && npm install && npm run render
//
// Note: the GitHub social-preview image (lintforge-social.png) must be
// uploaded manually via the repo's Settings > General > Social preview —
// there is no API for it.

import { Resvg } from '@resvg/resvg-js';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const assetsDir = join(dirname(fileURLToPath(import.meta.url)), '..', '.github', 'assets');

const targets = [
  { svg: 'lintforge-mark.svg', png: 'lintforge-mark.png' },
  { svg: 'lintforge-logo.svg', png: 'lintforge-logo.png' },
  { svg: 'lintforge-social.svg', png: 'lintforge-social.png' },
];

for (const { svg, png } of targets) {
  const source = readFileSync(join(assetsDir, svg));
  const resvg = new Resvg(source, {
    fitTo: { mode: 'original' },
    font: { loadSystemFonts: true },
    background: 'rgba(0,0,0,0)',
  });
  const rendered = resvg.render();
  const buffer = rendered.asPng();
  writeFileSync(join(assetsDir, png), buffer);
  console.log(`rendered ${svg} -> ${png}  (${rendered.width}x${rendered.height}, ${buffer.length} bytes)`);
}
