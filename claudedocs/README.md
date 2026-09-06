# POM developer guide

POM is a SwiftUI/AppKit menu bar app for macOS 14+. See [English README](../README.md)
or [lietuviškas aprašymas](../README.lt.md) for installation and product details.

## Structure

- `POMCore`: tolerant usage parsers, CLI clients, caches, bounded history, threshold/recovery trackers and formatting.
- `POM`: settings, notifications, menu bar rendering, popover, Swift Charts history window and Sparkle updater.
- `tests/POMCoreTests`: executable test runner; no XCTest dependency.
- `tests/POMViewTests`: isolated SwiftUI rendering and view-model integration checks.
- `tests/bridge_tests.py`: status-line installation/feed/removal checks in a temporary home.

## Data paths

Claude Code is asked only for `initialize` and `get_usage` through its control
protocol, with no model message, session persistence, tools or MCP servers.
The CLI owns credential refresh. Its schema is version dependent; tested with
2.1.263. The optional status-line bridge also supplies readings. A disabled-by-default
OAuth server fallback remains available for credentials with `user:profile` scope.

Codex runs briefly as `codex app-server`. POM sends `initialize`, `initialized`
and `account/rateLimits/read`, then closes the process. Both clients have a deadline,
a forced termination fallback and a bounded response buffer. Polling is normally
once every five minutes, with a 30-second floor for manual refreshes and backoff on errors.

Caches are separate per source under `~/Library/Application Support/POM`:
`snapshot.json`, `server-snapshot.json`, `claude-snapshot.json`, `codex-snapshot.json`.
New fields remain optional so 2.1 caches still load. A generic snapshot without
Fable/credit fields does not erase newer complete CLI metadata.

`usage-history.json` holds raw timestamped percentage samples, not estimates from
reset timers. Retention is 30 days, capped at 180,000 samples, normally at most one
per minute per series; reset/exhaustion changes can be retained sooner. The charts
break lines at resets, decreases or gaps longer than an hour. Reset state persists
in `recovery-state.json`. Codex recovery requires explicit `ordinaryUsageAllowed`
from the backend; null, a passed deadline or a percentage alone is insufficient.

Claude currency is displayed only with a currency code and `decimal_places`.
Codex amounts are credits. Reset credits are informational; POM never redeems them.
Missing fields remain unavailable. History aggregates readings seen on this Mac;
it is not a per-account billing report.

## Build and verify

```bash
swift run pom-tests
python3 tests/bridge_tests.py
bash scripts/check-ui.sh
bash scripts/bundle.sh
bash scripts/make-dmg.sh
```

`bundle.sh` builds arm64 and x86_64 separately, combines the executable, embeds
resources and Sparkle (including helpers), then signs from the inside out.
Development signing is ad-hoc by default and never claims to satisfy Gatekeeper.
Xcode's command line tools are sufficient for local builds. The release process is
in [RELEASING.md](../docs/RELEASING.md).

Opt-in live provider checks:

```bash
POM_CLAUDE_TEST=1 POM_CODEX_TEST=1 swift run pom-tests
```

These read real account usage but do not send a prompt or redeem credits.
Offscreen previews go to `.build/ui-checks`; they use fixtures, not real account data.
They verify layout, resource loading and model integration, not live UI clicks.

## Preferences and installation

Preferences use `lt.ponasobuolys.pom`. `menuBarSources` migrates the old single
`menuBarSource` preference. Language defaults to the system's primary language;
unsupported languages use English. Changes affect POM immediately.

`install.sh` replaces the local `/Applications/POM.app` and starts it. It is a local
development helper, not a solution to Gatekeeper warnings on downloaded apps.
The optional `install-bridge.sh` backs up an existing status line before editing.
`uninstall-bridge.sh` restores it. Launch at login uses a LaunchAgent under
`~/Library/LaunchAgents/lt.ponasobuolys.pom.plist`.

Public releases need Apple Developer ID and notarization. Notification registration
on unsigned builds may fail; the existing AppleScript fallback is used for API
registration errors, never to override a user's notification refusal.

## Removal

Quit POM, turn off Launch at login, restore the optional bridge with
`bash scripts/uninstall-bridge.sh`, then remove `/Applications/POM.app`.
History can be cleared in the app. If desired, remove only POM's support directory
and preferences after quitting; do not remove Claude/Codex authentication files.
