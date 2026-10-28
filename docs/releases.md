# Releases and Sparkle updates

## Configuration

`Config/Release.json` is the version/build and update configuration. Increase both `version` and the monotonically increasing `build` before a release. The first public release is 0.3.0 (3).

The appcast URL is `https://github.com/gabriel/Schnaps/releases/latest/download/appcast.xml`. Each latest release must include a complete current signed feed and the stable `Schnaps.dmg` download alias. Enclosures use immutable versioned GitHub release asset URLs.

The public Ed25519 key is safe to commit. The private key is stored only in the macOS login Keychain under account `com.gabrielhandford.Schnaps`. Never export it into this repository. Preserve it for future releases; Sparkle key rotation requires following Sparkle's signed-update migration procedure.

## Local prerequisites

- Xcode with Swift 6 support. Icons use the checked-in transparent ICNS on every supported macOS version.
- SwiftPM dependencies resolved: `swift package resolve`.
- An installed Developer ID Application certificate with its private key.
- A valid `notarytool` Keychain credential profile for the certificate's developer team.
- Sparkle's Ed25519 signing key in Keychain. For a new project only, generate it with `.build/artifacts/sparkle/Sparkle/bin/generate_keys --account com.gabrielhandford.Schnaps`, then update the public key in the release config before shipping.

## Build and notarize

```sh
export SCHNAPS_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export SCHNAPS_NOTARY_PROFILE='your-notarytool-profile'
swift test
swift Scripts/release.swift
```

The release script builds a universal app, signs nested Sparkle code from the inside out with hardened runtime and secure timestamps, verifies the app, notarizes and staples it, and checks Gatekeeper assessment. It creates a compressed DMG with the app and Applications symlink, signs/notarizes/staples the DMG, and verifies the disk image. It then generates and validates the signed Sparkle appcast and archive signatures, a stable download alias, and SHA-256 checksums.

Outputs are under `build/releases/<version>/`. Notarization reports stay there for inspection; do not publish those operational reports. Keep Sparkle signing keys, Developer ID private keys, and notarization credentials outside source control.

The build script retains symlinks and executable permissions when embedding `Sparkle.framework`, and includes its license acknowledgment. It never uses `codesign --deep` to produce signatures; `--deep --strict` is used only for verification.

## Publish

Merge reviewed code only after CI passes. Run the release from the merged commit, then create a GitHub release at its version tag. Upload:

- `Schnaps-<version>.dmg`: immutable Sparkle update archive.
- `Schnaps.dmg`: byte-identical alias for the website's latest download.
- `appcast.xml`: signed feed generated from that archive.
- `SHA256SUMS` and release notes.

Example:

```sh
gh release create v0.3.0 \
  build/releases/0.3.0/Schnaps-0.3.0.dmg \
  build/releases/0.3.0/Schnaps.dmg \
  build/releases/0.3.0/appcast.xml \
  build/releases/0.3.0/SHA256SUMS \
  --title 'Schnaps 0.3.0' --notes-file releases/0.3.0.md
```

Verify the public feed and download URLs and test **Check for Updates…** in the installed app. First release validation can verify the current-version response; a full upgrade installation requires a second real version. Never modify a signed feed or release notes without regenerating its signature. Never replace the bytes of an archive that an existing signed feed references.

The website is deployed with Wrangler from `website/`. Cloudflare provisions HTTPS for the custom domain; registrar ownership must be configured first. Keep GitHub source publishing, DMG release publishing, and website deployment as distinct verifiable steps.
