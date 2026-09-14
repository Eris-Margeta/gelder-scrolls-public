import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateRelease} from '../scripts/release-preflight.mjs';
const env = {
  DEVELOPER_ID_CERTIFICATE_BASE64: 'test-only', DEVELOPER_ID_CERTIFICATE_PASSWORD: 'test-only',
  DEVELOPER_ID_IDENTITY: 'Developer ID Application: Example (ABCDE12345)', APPLE_TEAM_ID: 'ABCDE12345',
  APPLE_ID: 'test@example.invalid', APPLE_APP_SPECIFIC_PASSWORD: 'test-only'
};
test('uncleared redistribution blocks release even with credentials', () => {
  assert.throws(() => validateRelease({redistributionCleared:false}, env), /redistribution clearance/);
});
test('each missing credential is rejected without exposing its value', () => {
  for(const name of Object.keys(env)) assert.throws(() => validateRelease({redistributionCleared:true}, {...env,[name]:''}), new RegExp(name));
});
test('development identities and mismatched teams cannot pass', () => {
  assert.throws(() => validateRelease({redistributionCleared:true}, {...env,DEVELOPER_ID_IDENTITY:'Apple Development: Example'}), /Developer ID/);
  assert.throws(() => validateRelease({redistributionCleared:true}, {...env,APPLE_TEAM_ID:'ZYXWV98765'}), /differ/);
});
test('valid preflight inputs pass without being treated as notarization proof', () => {
  assert.doesNotThrow(() => validateRelease({redistributionCleared:true}, env));
  const script = readFileSync('scripts/notarize-macos.zsh','utf8');
  assert.match(script,/--options runtime --timestamp/);
  assert.match(script,/status!=="Accepted"/);
  assert.match(script,/stapler validate/);
  assert.match(script,/spctl --assess/);
  assert.match(script,/trap cleanup/);
});
