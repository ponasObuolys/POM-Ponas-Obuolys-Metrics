# Apple enrollment and distribution

Status checked on 2026-09-07. The published POM 2.2.3 is still **not notarized**.
Opening the enrollment website is not enrollment, and preparing code is not App Store approval.

## Enrollment

The selected publisher is **Ponas Obuolys, MB**, subject to Apple's organization verification.
The owner supplied the legal name and authorized use of the company's published contact details.
An individual account instead displays the individual's legal name as seller.

1. Sign in at [Apple Developer](https://developer.apple.com/account/) with the owner's Apple Account and complete two-factor authentication in Apple's interface.
2. Choose individual or organization enrollment. Organization enrollment needs the legal entity name, registered address, work contact details, authority to enter agreements, a working company website and a D-U-N-S number.
3. Use [Apple's D-U-N-S lookup](https://developer.apple.com/help/account/membership/D-U-N-S/) before requesting a number. Apple's route is free; do not buy an expedited service for this setup. Allow Apple's and D&B's verification time.
4. After verification, the account holder reviews the agreement and pays the amount displayed by Apple. Apple lists **99 USD per year**, with the checkout showing local pricing. One membership covers the Apple platforms; separate iPhone/iPad memberships are not needed.
5. Confirm the account shows an active program membership and record its actual Team ID in local configuration. No Team ID or enrollment ID has been invented or submitted by POM tooling.

The organization enrollment was submitted successfully on 2026-09-07. Apple's lookup matched the
company, the existing D-U-N-S number was accepted, and the work email was verified. Apple now shows
**Your enrollment is being processed** and will email the owner after verifying signing authority.
The membership agreement and payment step are not available yet. Membership is not active, and no
payment has been made. Personal contact values, verification codes and the enrollment reference are
not stored in this repository.

Sources: [Enrollment](https://developer.apple.com/programs/enroll/),
[D-U-N-S](https://developer.apple.com/help/account/membership/D-U-N-S/),
[identity verification](https://developer.apple.com/help/account/membership/identity-verification).

## Development tools

Xcode 26.6 (17F113) is now present at `/Applications/Xcode.app`; the owner installed it during this task.
First-launch/license setup is now complete. macOS, iOS and iOS Simulator SDK 26.5 and an iOS 26.5 runtime
are available. App builds and iPhone/iPad simulator UI tests pass. Commands in this document select
the full toolchain through `DEVELOPER_DIR`, independently of the global Command Line Tools selection.
Keep Apple Account passwords,
2FA codes, payment details and private signing keys out of chat and Git.

The official Lithuanian App Store listing was checked: Xcode 26.6, app ID 497799835,
price 0 EUR. Installation through the existing `mas` tool stopped at `sudo: a password is required`.
Its App Store page was then opened with `mas open 497799835`, and the owner proceeded with installation.
XcodeGen 2.46.0 was installed through Homebrew to generate the companion app project.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/apple-preflight.sh --app-store
```

This read-only check verifies the selected Xcode, first-launch completion, SDKs and Developer ID setup.
It does not verify App Store eligibility or claim that an app is ready for review.

## First notarized Mac release

After membership is active:

1. Create a **Developer ID Application** certificate with its private key in the local Keychain using the authorized Apple account. An Apple Development or Apple Distribution certificate does not replace Developer ID for the downloadable DMG.
2. Store notarization credentials in a local Keychain profile using the procedure in [RELEASING.md](RELEASING.md). Do not commit a certificate export, private key or app-specific password.
3. Set the exact `POM_SIGN_IDENTITY` and `POM_NOTARY_PROFILE`. If using a separate Keychain, set `POM_SIGN_KEYCHAIN` and `POM_NOTARY_KEYCHAIN` as well.
4. Run `bash scripts/apple-preflight.sh --verify-notary`. This reads Apple's notarization history to verify access; it does not submit software.
5. Allocate a **new version**; never replace the existing 2.2.3 assets with a different binary. Run the source, bridge, UI and signing preflight checks, then `bash scripts/release.sh` with the configured environment.
6. Verify Developer ID signing, Apple's accepted submissions, stapled tickets, Gatekeeper assessment, DMG checksums and Sparkle signatures. Test the downloaded DMG on another Mac before announcing trusted distribution.
7. Configure the documented GitHub Actions secrets and publish only the checked, notarized release. The source/test workflow remains independent of paid Apple membership.

The release script now runs preflight before compiling. Current private keys/credentials are still missing;
no Developer-ID-signed or notarized release has been produced by this change.

Source: [Signing Mac software with Developer ID](https://developer.apple.com/developer-id/).

## Store and mobile work

See [ADR-001](architecture/001-apple-platforms.md) for the proposed product and data architecture.
The reusable package, desktop export and an actual standalone report viewer now exist under
`Apps/POMCompanion`. Its XcodeGen project declares macOS/iOS destinations and macOS sandbox entitlements.
The Mac SwiftPM executable and data/model checks pass; compact/macOS layouts have been rendered in LT/EN.
Full Xcode Mac/iOS builds and the iPhone 17e / iPad (A16) simulator flows pass. The Mac app was built with
a local ad hoc signature and successfully imported a synthetic report into its sandbox container.
Ad hoc signing is not Developer ID signing or notarization. CloudKit transport, StoreKit products,
physical-device testing and App Store submissions do not exist yet. These should not be advertised as
released capabilities.

See [Companion build and QA instructions](../Apps/POMCompanion/README.md).
