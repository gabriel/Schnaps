# Releases and Sparkle updates

## Configuration

`Config/Release.json` is the version/build and update configuration. Increase both `version` and the monotonically increasing `build` before a release. The first public release is 0.3.0 (3).

Legacy clients use `https://github.com/gabriel/Schnaps/releases/latest/download/appcast.xml`. New builds use the combined Stable/Beta feed described below. Each latest stable release must include its signed feed and the stable `Schnaps.dmg` download alias. Enclosures use immutable versioned GitHub release asset URLs.

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

## Stable and Beta channels

About Schnaps → Updates → Channel offers Stable and Beta. Stable is the default for normal builds; a fresh beta install defaults to Beta. An explicit choice persists across builds. Beta permits Sparkle's `beta` channel plus normal stable updates; Stable permits only normal releases. Switching to Stable does not downgrade an already installed beta: it receives the next stable build with a higher build number.

New builds use `https://getschnaps.com/appcast.xml`, a byte-identical first-party proxy of the signed combined feed at `https://github.com/gabriel/Schnaps/releases/download/updates/appcast.xml`. The app routes archive requests through its first-party proxy without modifying signed feed or archive bytes. The `updates` prerelease is only a feed host. Existing clients keep using the stable latest-release feed; stable releases still publish `appcast.xml` and `Schnaps.dmg` at the legacy latest-release URLs. Beta releases are GitHub prereleases and never become Latest or replace the stable website download.

### One-command beta publication

```sh
make plan-beta                 # Read-only plan; no release is published
make beta                      # Build, sign, notarize, and publish the next beta
make beta ARGS='--version 0.7.0' # Start a new beta series explicitly
```

The publisher uses the Keychain notary profile `Schnaps` by default and automatically selects a Developer ID Application identity only when exactly one is installed. Override `SCHNAPS_SIGN_IDENTITY` and `SCHNAPS_NOTARY_PROFILE` when needed. macOS may request access to signing keys; approve those prompts in macOS. Private keys never leave Keychain.

Publish from a clean, committed, pushed branch. Betas may come from feature branches. Version planning considers existing release tags, signed feeds, and reserved draft builds. It increments the beta suffix and chooses a globally increasing internal build number. The checked-in stable version/build is not changed. A generated `Release.json` supplies overrides to both the app builder and packager; beta bundles contain `SchnapsUpdateChannel=beta` and beta appcast items contain `sparkle:channel=beta`.

The publisher stages a draft with immutable versioned archives, publishes it as a prerelease, then merges, signs, verifies, and uploads the combined channel feed. Only the combined feed is overwritten. Versioned public archives are never replaced. Both individual release feeds and the combined feed participate in build allocation, including after a failed feed upload. A local lock prevents overlapping publishers on one Mac, and a final feed refresh detects build numbers claimed by another publisher.

If publication fails after packaging, keep `build/releases/<version>/` and resume from the original commit:

```sh
make beta ARGS='--resume 0.6.3-beta.1'
```

Resume validates the manifest, checksums, stapling, code signature, appcast signature, and archive signature before publishing. It can finish a draft or repair a missing combined-feed upload without changing public archive bytes. If packaging failed before uploading anything, a fresh invocation can rebuild the unpublished local output. Remove `build/Publish.lock` manually only after verifying a crashed publisher is no longer running.

For stable releases, update `Config/Release.json` to the intended stable version and publish from merged `main` with `make release`. The same publisher updates both the legacy stable assets and combined channel feed. The allocated build number is always higher than all known stable/beta builds, even when the checked-in build was lower. Authored notes in `releases/<version>.md` are embedded; otherwise a concise commit-based note is generated.
