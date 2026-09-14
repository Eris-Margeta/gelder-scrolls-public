'use strict';
// A release manifest is promoted only after the signed artifact is verified.
fetch('release.json', { cache: 'no-store' })
  .then(response => { if (!response.ok) throw new Error('Release unavailable'); return response.json(); })
  .then(release => {
    if (release.status !== 'released' || !release.macOS?.notarized || !release.version) return;
    const asset = new URL(release.macOS.url);
    if (asset.origin !== 'https://github.com' || !asset.pathname.startsWith('/Eris-Margeta/gelder-scrolls-public/releases/download/')) return;
    if (!/^[a-f0-9]{64}$/.test(release.macOS.sha256)) return;
    const link = document.getElementById('download-link');
    link.href = asset.href;
    link.textContent = 'Download for Mac ↓';
    document.getElementById('release-detail').textContent = `Version ${release.version} · macOS 14+ · Apple Silicon`;
    document.getElementById('release-note').textContent = `Developer ID signed and notarized. SHA-256: ${release.macOS.sha256}`;
  })
  .catch(() => { /* The truthful static release status remains visible offline. */ });
