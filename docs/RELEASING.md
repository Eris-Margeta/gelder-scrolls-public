# Releasing Gelder Scrolls

Public binaries are blocked while `release-policy.json` reports incomplete redistribution clearance. Do not bypass that gate or publish local ad-hoc builds.

## Apple setup

An Apple Developer membership alone is not a signing identity. In the Apple Developer account, create a **Developer ID Application** certificate for distribution outside the App Store. Export the certificate **with its private key** as a password-protected `.p12` from Keychain Access. An Apple Development or Mac App Distribution certificate is not interchangeable with Developer ID Application.

Create the GitHub environment `macos-release`, limit deployment branches to `main`, and require an owner review. Configure these environment secrets through GitHub Settings (never paste them into issues, commits or chat):

| Secret | Value |
|---|---|
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64 encoding of the `.p12` certificate and private key |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password protecting the `.p12` |
| `APPLE_ID` | Apple account authorized to notarize for the team |
| `APPLE_APP_SPECIFIC_PASSWORD` | Dedicated app-specific password for notarization |

Environment variables: `DEVELOPER_ID_IDENTITY` is the complete Developer ID Application identity, including the Team ID in parentheses; `APPLE_TEAM_ID` is the ten-character team identifier.

The keychain exists only in the isolated GitHub runner’s temporary directory. The job restricts imported-key access to signing tools, stores notarization credentials in that temporary keychain, and removes it on exit. Never enable command tracing or upload temporary signing directories.

## Release flow

1. Resolve all third-party redistribution terms and review the exact dependency graph before setting clearance to true. The current Longhand dependency must be replaced or separately cleared; the packaging script deliberately rejects its model bundle.
2. Commit reviewed source, lockfile, version and third-party notices. Run application regression checks on each supported OS. Website checks alone do not prove desktop readiness.
3. Run **Notarized macOS release** from `main`. The workflow uses a GitHub-hosted Apple Silicon runner, refuses absent credentials, builds locked dependencies, signs with hardened runtime and timestamp, and submits the app to Apple.
4. Require `Accepted`, staple and validate the app, and assess it with Gatekeeper. Create the ZIP from the stapled app; create, sign, notarize, staple and assess the DMG separately. Compute checksums only after these operations.
5. Download the verified workflow artifact, test installation/opening a real Markdown file on a clean Mac, then publish a versioned GitHub Release with DMG, ZIP, `SHA256SUMS`, and release notes. Do not overwrite artifacts under an existing version.
6. Update the website manifest with the exact download URL and SHA-256 only after release verification, then deploy the website. A manifest flag is a publication record, not evidence of notarization by itself.

If notarization times out, inspect the recorded submission with `notarytool info`/`log`; a timeout does not mean Apple stopped processing it. Do not repeatedly resubmit the same artifact blindly. Keep distribution disabled until acceptance is verified.

## References

- [Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [GitHub signing certificates on macOS runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)

Windows and Linux desktop builds remain unfinished. Do not advertise a platform download until its actual application artifact and runtime behavior have been verified.
