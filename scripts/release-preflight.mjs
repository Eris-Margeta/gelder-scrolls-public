import { readFileSync } from 'node:fs';
export function validateRelease(policy, environment) {
  if (policy.redistributionCleared !== true) throw new Error('Release blocked: redistribution clearance is incomplete.');
  for (const name of ['DEVELOPER_ID_CERTIFICATE_BASE64', 'DEVELOPER_ID_CERTIFICATE_PASSWORD',
    'DEVELOPER_ID_IDENTITY', 'APPLE_TEAM_ID', 'APPLE_ID', 'APPLE_APP_SPECIFIC_PASSWORD']) {
    if (!environment[name]?.trim()) throw new Error(`Release blocked: missing ${name}.`);
  }
  if (!environment.DEVELOPER_ID_IDENTITY.startsWith('Developer ID Application: ')) {
    throw new Error('Release blocked: direct distribution requires Developer ID Application.');
  }
  if (!/^[A-Z0-9]{10}$/.test(environment.APPLE_TEAM_ID)) throw new Error('Release blocked: invalid Apple Team ID.');
  if (!environment.DEVELOPER_ID_IDENTITY.endsWith(`(${environment.APPLE_TEAM_ID})`)) {
    throw new Error('Release blocked: signing identity and Apple Team ID differ.');
  }
}
if (process.argv[1]?.endsWith('release-preflight.mjs')) {
  try {
    validateRelease(JSON.parse(readFileSync('release-policy.json', 'utf8')), process.env);
    console.log('Release preflight passed. No credential values were logged.');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
