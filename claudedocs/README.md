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

Token history is separate from quota recovery. `account/usage/read` supplies Codex
account daily token buckets; unsupported/error responses leave the last cache marked
unavailable. `claude-tokens.json` and `codex-tokens.json` hold at most 30 daily totals.
The legacy `usage-history.json` is left untouched and is no longer read or written.
`recovery-state.json` still tracks exhaustion; Codex requires explicit
`ordinaryUsageAllowed`, never a percentage or elapsed deadline alone.

`ClaudeTokenIndexer` imports `~/.claude/projects/**/*.jsonl`, including subagents,
using the system SQLite library (no added package/service). Its database stores
SHA-256 message IDs/file paths, offsets, dates and token counts only. Replayed/forked
assistant records use the maximum total per message ID; a streaming update replaces
the previous value rather than adding it. Total = input + output + cache creation +
cache read. Nested cache-creation breakdowns are not added again.

The worker runs off the main actor at background priority, discovers file metadata
once per refresh, and reads up to 2 MiB / 50 ms per pass, in 64 KiB chunks. Each pass
has an autorelease pool; the SQLite page cache is limited to 1 MiB. One chunk may
overrun the time target. Between passes it sleeps cooperatively for 0.5 s (2 s in
Low Power Mode). Automatic refresh is every 15 minutes, with a 60 s manual floor
and single-flight tasks. Unchanged logs produce zero content reads. A line over
4 MiB is skipped with an incomplete-total warning. Malformed usage records are
also flagged. Only complete newlines advance the durable cursor; database transactions
keep message counts and offsets consistent across interrupted imports. Inode changes,
truncation and same-size rewrites trigger a deduplicated reread. Append-only growth
is assumed for an existing inode; an in-place rewrite that also grows is not detected.

Retained dates are today and the preceding 29 calendar days. Claude uses UTC;
Codex date-only buckets are kept as returned because the API omits timezone metadata.
The chart contains at most 60 points. Empty successful buckets mean zero recorded
usage; unavailable sources show a dash, with old caches explicitly labelled.
First imports are labelled partial. Token history is not a billing report.
Claude currency is displayed only with a currency code and `decimal_places`.
Codex amounts are credits. Reset credits are informational; POM never redeems them.
Missing fields remain unavailable. Claude coverage is local Claude Code sessions;
Codex coverage is the signed-in account as returned by the service.

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
If desired, remove only POM's support directory
and preferences after quitting; do not remove Claude/Codex authentication files.

## Token-import resource check

```bash
swift build -c release --product pom-tests
POM_TOKEN_BENCHMARK=1 /usr/bin/time -l .build/release/pom-tests
```

This explicit opt-in skips unit tests and reads real local Claude sessions into
`.build/token-benchmark/index.sqlite`. It prints only byte counts, duration, day count
and skipped-line count. It runs batches without the app's quiet intervals to measure
parsing cost. A repeat measures warm-cache discovery; remove only that benchmark
folder to repeat a cold import. Run ordinary `swift run pom-tests` separately.
