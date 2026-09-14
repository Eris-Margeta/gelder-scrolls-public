#!/bin/zsh
# Run only on an isolated macOS release runner. Never enable shell tracing.
set -euo pipefail
umask 077
cd "${0:A:h:h}"
node scripts/release-preflight.mjs
[[ "${GITHUB_ACTIONS:-}" == true ]] || { print -u2 'Use the isolated GitHub release workflow.'; exit 1; }
[[ "${RUNNER_OS:-}" == macOS && "${RUNNER_ARCH:-}" == ARM64 ]] || { print -u2 'An Apple Silicon macOS runner is required.'; exit 1; }
[[ -n "${RUNNER_TEMP:-}" && -d "$RUNNER_TEMP" ]] || exit 1
version=$(<VERSION)
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { print -u2 'Invalid release version.'; exit 1; }
release_work=$(mktemp -d "$RUNNER_TEMP/gelder-signing.XXXXXX")
release_keychain="$release_work/signing.keychain-db"
keychain_password=$(openssl rand -hex 32)
cleanup() {
  security delete-keychain "$release_keychain" >/dev/null 2>&1 || true
  [[ "$release_work" == "$RUNNER_TEMP"/gelder-signing.* ]] && rm -rf -- "$release_work"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
export RELEASE_WORK="$release_work"
node --input-type=module -e 'import {writeFileSync} from "node:fs"; writeFileSync(process.env.RELEASE_WORK+"/certificate.p12", Buffer.from(process.env.DEVELOPER_ID_CERTIFICATE_BASE64,"base64"), {mode:0o600})'
security create-keychain -p "$keychain_password" "$release_keychain"
security set-keychain-settings -lut 7200 "$release_keychain"
security unlock-keychain -p "$keychain_password" "$release_keychain"
security import "$release_work/certificate.p12" -k "$release_keychain" -P "$DEVELOPER_ID_CERTIFICATE_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$release_keychain" >/dev/null
rm -- "$release_work/certificate.p12"
xcrun notarytool store-credentials gelder-notary --keychain "$release_keychain" \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" >/dev/null

# Build from the committed lockfile; no dependency update in a release job.
swift build -c release --disable-automatic-resolution -Xswiftc -warnings-as-errors
binary_dir=$(swift build -c release --show-bin-path)
app="$release_work/Gelder Scrolls.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" .build/notarized
cp "$binary_dir/GelderScrolls" "$app/Contents/MacOS/GelderScrolls"
cp Packaging/macos/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${GITHUB_RUN_NUMBER}" "$app/Contents/Info.plist"
cp Packaging/macos/AppIcon.icns "$app/Contents/Resources/"
cp "$binary_dir/GelderScrolls_GelderScrolls.bundle/"* "$app/Contents/Resources/"
cp LICENSE "$app/Contents/Resources/APP-LICENSE.txt"
# Only cleared model/resources may be added here after the release policy audit.
[[ ! -e "$binary_dir/longhand_InkGraves.bundle" ]] || { print -u2 'Uncleared handwriting model is still in the build graph.'; exit 1; }
codesign --force --sign "$DEVELOPER_ID_IDENTITY" --keychain "$release_keychain" \
  --options runtime --timestamp "$app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dv --verbose=4 "$app" 2> "$release_work/signature.txt"
grep -q 'flags=.*runtime' "$release_work/signature.txt"
grep -q "TeamIdentifier=$APPLE_TEAM_ID" "$release_work/signature.txt"
ditto -c -k --sequesterRsrc --keepParent "$app" "$release_work/submission.zip"
xcrun notarytool submit "$release_work/submission.zip" --keychain-profile gelder-notary \
  --keychain "$release_keychain" --wait --timeout 30m --output-format json > .build/notarized/app-notarization.json
node --input-type=module -e 'import{readFileSync}from"node:fs"; if(JSON.parse(readFileSync(".build/notarized/app-notarization.json")).status!=="Accepted")process.exit(1)'
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=4 "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" ".build/notarized/GelderScrolls-$version-macOS-arm64.zip"
mkdir "$release_work/dmg"
ditto "$app" "$release_work/dmg/Gelder Scrolls.app"
ln -s /Applications "$release_work/dmg/Applications"
dmg=".build/notarized/GelderScrolls-$version-macOS-arm64.dmg"
hdiutil create -volname "Gelder Scrolls $version" -srcfolder "$release_work/dmg" -format UDZO "$dmg"
codesign --sign "$DEVELOPER_ID_IDENTITY" --keychain "$release_keychain" --timestamp "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile gelder-notary --keychain "$release_keychain" \
  --wait --timeout 30m --output-format json > .build/notarized/dmg-notarization.json
node --input-type=module -e 'import{readFileSync}from"node:fs"; if(JSON.parse(readFileSync(".build/notarized/dmg-notarization.json")).status!=="Accepted")process.exit(1)'
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=4 "$dmg"
(
  cd .build/notarized
  shasum -a 256 *.zip *.dmg > SHA256SUMS
)
print 'Signed, notarized, stapled and assessed artifacts are in .build/notarized.'
