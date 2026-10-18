# POM Companion — development preview

A separate SwiftUI history viewer for macOS 14, iOS 17 and iPadOS 17. It imports POM summary files,
shows daily totals and original source/capture details, and keeps one offline copy. It has no dependency
on the desktop app's CLI collectors, transcript index, Sparkle or provider credentials.

**Status (2026-09-07):** Xcode 26.6 first launch is complete. Mac and iOS Simulator app builds pass with
the installed 26.5 SDKs. The UI flow passes on iPhone 17e and iPad (A16), both running iOS Simulator 26.5:
open the example, switch 7/30 days, change English to Lithuanian, and remove the report. A locally ad hoc
signed Mac app successfully imported the desktop's synthetic report through Launch Services and saved
the exact 5,846-byte report in its sandbox container. There is no Developer ID, notarization, provisioning
profile, CloudKit container or App Store submission yet. Physical-device and full accessibility QA remain.

## What works

- Open a report through the system file picker, or an external file-open action.
- Preserve the distinction between Claude Code on the exporting Mac and Codex account buckets.
- Inspect 7/30-day totals, a daily chart and an accessible list; missing readings remain missing.
- Compare weeks with a reading for every day; the final day may still be incomplete. No percentage comparison for missing days, a failed collection or a zero baseline.
- Display partial/failed collection, capture timestamps, older snapshots and the report's fixed period.
- Save one bounded report locally, reopen offline, export it, or remove the saved copy.
- Explore clearly labelled fictional example data without overwriting a saved report. Example export is disabled.
- Choose English, Lithuanian, or the system's preferred language. Reuse POM's existing icon/provider marks.

Opening a second report **replaces** the first. Reports have no account/publisher binding, so adding them
together would risk double counting. Dates are provider day labels, not converted into the phone's timezone.
The current report contains up to 30 days ending at export time; older snapshots outside that period
show missing readings, not zero. Import is bounded to 256 KiB before decoding and uses file coordination
and security-scoped access for user-selected files. Malformed imports preserve the previous saved report.

## Build

Run from the repository root:

```bash
bash scripts/check-companion.sh --mac
swift run --package-path Apps/POMCompanion pom-companion-preview
```

The preview command launches a development executable, not the sandboxed store bundle. It stores its
own copy under Application Support/POMCompanion; it does not alter the existing POM collector.

For the actual app project, complete Xcode's first launch and install its iOS platform, then:

```bash
brew install xcodegen
xcodegen generate --spec Apps/POMCompanion/project.yml
open Apps/POMCompanion/POMCompanion.xcodeproj
```

Select the actual Apple team in Signing & Capabilities after enrollment. The proposed bundle identifier
is `lt.ponasobuolys.pom.companion`; it has not been registered. `project.yml` is the source of truth;
the generated `.xcodeproj` is ignored. XcodeGen 2.46 or later is required.

Unsigned Mac and iOS Simulator compilation, without buying membership or submitting an app:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/check-companion.sh --xcode
```

These commands cannot skip Apple's license or first-launch setup. The CI workflow runs this check on
a configured macOS runner. Unsigned CI builds do not replace signed archive and physical-device QA.

The macOS target declares App Sandbox and user-selected file access, with no network entitlement.
The privacy manifest declares app-only UserDefaults access (`CA92.1`) for the language setting and no
tracking or collected data. Validate the final signed archive's privacy report before submission.
[Apple's reason definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Validate

```bash
swift run --package-path Apps/POMCompanion pom-companion-checks
swift run --package-path Apps/POMCompanion pom-companion-visual-checks "$PWD/.build/companion-ui-checks"
```

The visual check also exercises import, replacement, failed-input preservation, cache restore, example
isolation and deletion through the actual view model. Compact-width macOS renders are separate from the
actual iPhone/iPad simulator UI tests. To run the UI test on an installed simulator, choose its name:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Apps/POMCompanion/POMCompanion.xcodeproj -scheme POMCompanion \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

UI testing uses a DEBUG-only launch argument to isolate the report cache. All windows share the same
model in normal use, so opening a report in one window updates the others. The system picker/export
flow on physical devices, iCloud Drive downloads, VoiceOver, Dynamic Type and sustained energy use
remain part of release QA. One idle sample of the Mac Debug app with a chart open showed 0.0% CPU and
about 123 MiB resident memory; this is not a release-performance or battery benchmark. No polling,
background fetch, provider calls or transcript scans have been added to this client.

Artwork is checked in. To regenerate it from POM's existing sources:

```bash
swift scripts/make-icon.swift .build/companion-icon.iconset
swift scripts/prepare-companion-assets.swift "$PWD"
```

## Still needed

Supported Claude Max account history is unavailable; neither Apple membership nor this client changes
that. Automatic CloudKit transport, explicit publisher/account binding, quota display, StoreKit tips,
real-device validation and review-ready distribution remain future work. See
[ADR-001](../../docs/architecture/001-apple-platforms.md) and [Apple setup](../../docs/APPLE-DISTRIBUTION.md).
