# POMUsageKit

Shared, data-only Swift package for POM history. Declares macOS 14 and iOS/iPadOS 17 support.
It has no third-party dependencies, subprocesses, networking, AppKit or credential access.
The existing desktop `POMCore` module re-exports its types using type aliases.

`TokenUsageSnapshot` keeps daily counts and their original provider dates. `UsageHistoryReport`
provides a bounded, source-labelled JSON transfer format. Always use `UsageHistoryReport.decode(_:)`
for an external file: it enforces the payload limit and strict UTC ISO timestamps before use.
The format uses whole-second `YYYY-MM-DDTHH:mm:ssZ` timestamps and at most 30 daily buckets per source.

Reports contain local Claude Code history and/or Codex account history. They never assert complete
Claude account coverage. A completed collection is not a claim of complete account coverage.
Multiple reports must not be summed blindly; they can describe overlapping usage. V1 does not carry
account/publisher identity for automatic merging, and no CloudKit transport is implemented here.

Build in isolation with `swift build --package-path Packages/POMUsageKit` from the repository root.
Behavior is exercised by `swift run pom-tests`; desktop export is also checked by `scripts/check-ui.sh`.
Mac and iOS Simulator compilation is verified through the companion app's Xcode project.
Its UI flow also passes on iPhone and iPad simulators; physical-device testing remains pending.
