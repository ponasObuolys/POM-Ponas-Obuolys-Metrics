# Signing, notarization and updates

## Current state

As checked on 2026-09-06, this Mac has **no valid Developer ID Application identity**.
The published 2.2.1 DMG (like 2.1.2) is ad-hoc signed. Its Gatekeeper warning cannot be fixed by
renaming the DMG, compiling again or creating another self-signed certificate.
Version 2.2.1 was explicitly authorized for manual publication without notarization.
A notarized release still requires Apple signing credentials.

The automated signed-release pipeline still requires Developer ID and notarization.
The manual 2.2.1 exception publishes a clearly labelled unnotarized DMG, its SHA-256
checksum and a signed informational appcast. It does not weaken the automated
signing/notarization checks. Local builds remain marked as development builds by
default; `POM_PUBLIC_UNNOTARIZED=1 bash scripts/make-dmg.sh` replaces that package
notice with an explicit unnotarized-release notice. This flag does not bypass
`POM_RELEASE=1` checks. The 2.2.1 appcast uses `--informational-update-versions ""`
and a link to its release page, so Sparkle directs users to manual download.

## One-time Apple setup

An active Apple Developer Program membership is required. In Apple's developer
account/Xcode, create or download a **Developer ID Application** certificate and
install it **with its private key** in the Mac's Keychain. Then verify:

```bash
security find-identity -v -p codesigning
```

Create a notarytool profile interactively. This keeps the app-specific password out
of shell history and this repository:

```bash
xcrun notarytool store-credentials POM-notary
```

Alternatively, store an App Store Connect team API key using `--key`, `--key-id`
and `--issuer`. Use a local `.p8` file, never paste its contents into a chat or commit it.
See [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Sparkle key

POM uses Sparkle 2.9.6, pinned by `Package.resolved`. The public Ed25519 key is in
`config/sparkle-public-key.txt`; the corresponding private key is in the local
login Keychain under account **lt.ponasobuolys.pom**. It was generated with:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account lt.ponasobuolys.pom
```

Do not regenerate the key for each release. Keep a protected backup via Sparkle's
`generate_keys -x` export option; export only into a protected location outside the
repository, never print the private key. Losing it affects future update signing.

## Prepare a local public release

After updating `VERSION` and `docs/releases/<version>.md`:

```bash
swift run pom-tests
python3 tests/bridge_tests.py
bash scripts/check-ui.sh
POM_SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
POM_NOTARY_PROFILE=POM-notary bash scripts/release.sh
```

The identity above is a placeholder: use the exact identity from your Keychain.
`release.sh` builds both CPU architectures, embeds Sparkle, signs nested helpers
before the main app, submits/staples/assesses the app, creates a DMG, then submits,
staples and assesses that DMG. It finally signs and verifies the update archive
and appcast. The archive is also verified against the public key shipped in POM.

Outputs: `dist/POM-<version>.dmg`, its `.sha256` file and `dist/appcast.xml`.
This command **does not upload** them. Check installation on a clean Mac and run
a real update from the previous notarized version before publishing.
The first 2.2 release requires a manual download from 2.1.2, which has no updater.

## GitHub Actions

Configure these repository Actions secrets through GitHub's protected secret UI:

| Secret | Value |
|---|---|
| `POM_CERTIFICATE_P12` | Base64-encoded export of the Developer ID certificate and private key |
| `POM_CERTIFICATE_PASSWORD` | Password protecting that P12 export |
| `POM_SIGN_IDENTITY` | Exact `Developer ID Application: …` identity |
| `APPLE_API_KEY_P8` | App Store Connect **team** API key contents |
| `APPLE_API_KEY_ID` | Key ID |
| `APPLE_API_ISSUER` | Team API issuer UUID |
| `POM_SPARKLE_PRIVATE_KEY` | Sparkle's exported private key, corresponding to the committed public key |

The workflow requires a tag matching `VERSION`. It creates an isolated temporary
Keychain on the ephemeral runner, imports signing material and stores notarization
credentials there. It neither alters a user's login Keychain nor changes the
Keychain search list. Temporary files and Keychain are removed even on failure.
Missing credentials stop the release before publishing.

After successful review, create/push the matching release tag. GitHub uploads the
DMG, checksum and appcast only after all checks pass. Do not create a newer public
GitHub release without its appcast: the stable feed uses the latest release asset.

## Updating

Feed: `https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases/latest/download/appcast.xml`.
Each enclosure points to an immutable version-specific release URL. Appcast feeds
and archives are signed; archives are verified before extraction. Sparkle uses
`CFBundleVersion` to reject downgrades and compare versions. Automatic checks can
be disabled in Settings. Installation is offered to the user, not silently forced.

A local test of archive/feed signatures does not prove Gatekeeper acceptance or a
complete update between notarized releases. Those checks remain required after
Apple credentials are configured.

References: [Sparkle setup](https://sparkle-project.org/documentation/),
[programmatic integration](https://sparkle-project.org/documentation/programmatic-setup/),
[Apple Developer ID](https://developer.apple.com/developer-id/).
