import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, existsSync} from 'node:fs';
const html = readFileSync('website/index.html', 'utf8');
test('landing page has accessible structure and local asset references', () => {
  assert.match(html, /<html lang="en">/);
  assert.match(html, /<main id="main">/);
  assert.equal([...html.matchAll(/<h1\b/g)].length, 1);
  for (const [, url] of html.matchAll(/(?:src|href)="([^"#][^"]*)"/g)) {
    if (!url.startsWith('https:')) assert.ok(existsSync(`website/${url}`), url);
  }
  for (const [, fragment] of html.matchAll(/href="#([^"]+)"/g)) assert.ok(html.includes(`id="${fragment}"`));
});
test('download is gated on explicit verified-release metadata', () => {
  const release = JSON.parse(readFileSync('website/release.json', 'utf8'));
  assert.ok(['preparing', 'released'].includes(release.status));
  if (release.status === 'released') {
    assert.equal(release.macOS.notarized, true);
    assert.match(release.macOS.sha256, /^[a-f0-9]{64}$/);
    assert.match(release.macOS.url, /^https:\/\/github\.com\/Eris-Margeta\/gelder-scrolls-public\/releases\/download\//);
  } else {
    assert.equal(release.macOS, null);
    assert.match(html, /public Mac build is not available yet/);
  }
});
test('security headers and reduced motion support are retained', () => {
  const config = JSON.parse(readFileSync('website/vercel.json', 'utf8'));
  assert.ok(config.headers[0].headers.some(h => h.key === 'Content-Security-Policy' && h.value.includes("frame-ancestors 'none'")));
  assert.match(readFileSync('website/styles.css', 'utf8'), /prefers-reduced-motion/);
});
