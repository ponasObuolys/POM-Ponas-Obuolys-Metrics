# POM — Claude & Codex usage limits for macOS

**Know how much usage you have left, without leaving your work.**
POM is a native Mac menu bar app that brings Claude and Codex subscription limits,
reset times and extra credits into one small window.

[🇱🇹 Lietuviškai](README.lt.md) · [Downloads](https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases) · [Installation help](docs/INSTALL.txt)

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)
![Apple silicon and Intel](https://img.shields.io/badge/Mac-Apple_silicon_%26_Intel-blue)
![MIT license](https://img.shields.io/badge/license-MIT-green)

> **2.2 development preview.** The features below are implemented in the source tree.
> The latest published release is still 2.1.2. A trusted 2.2 installer is pending
> Developer ID signing and Apple notarization; development builds are not notarized.

<p><img src="docs/images/usage-en.png" width="344" alt="POM showing Claude and Codex limits, reset times and extra usage in English"></p>

## What you can see

- **Claude:** five-hour, weekly all-model usage and a separate Fable weekly limit when reported.
- **Codex:** the longest window in the main Codex usage bucket, plus the account's ChatGPT plan.
- **Extra usage:** Claude's enabled state, monthly usage percentage and spending amounts when currency/scale are provided; Codex credit balances, monthly credit limits and available limit resets when reported. POM does not buy or redeem credits.
- **Several indicators at once:** choose Claude, Fable and Codex individually in the menu bar. Switch between used and remaining percentages.
- **Useful notifications:** configurable low-limit warnings and a notification when fresh data confirms that an exhausted limit has recovered.
- **7- and 30-day history:** interactive charts of the readings collected on your Mac, with separate lines for each limit.
- **English and Lithuanian:** follows your Mac's primary language, with an immediate manual switch in Settings. Other system languages use English.
- **In-app updates:** Sparkle checks for updates and offers installation from a signed update feed. Public releases require Developer ID signing and notarization.

![POM usage history with separate Claude, Fable and Codex series](docs/images/history-en.png)

*Interface previews use sample readings. History is collected locally; past usage cannot be backfilled from provider responses. Gaps represent missing readings or a new limit period. These are usage percentages, not token counts or a prediction of when you will run out.*

## Install

1. Download the DMG from [GitHub Releases](https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases).
2. Drag **POM** into **Applications** and open it there.
3. Sign in to Claude Code and/or Codex CLI. POM will read the available limits automatically.
4. Click the menu bar indicators. Use **Settings → Language** to change the language and **History** to open the charts.

Requires **macOS 14 Sonoma or later** and at least one installed, signed-in CLI:
[Claude Code](https://code.claude.com/docs/en/overview) or [Codex](https://github.com/openai/codex).
The optional Claude status-line bridge additionally needs `jq`. The Claude control protocol is version dependent (tested with Claude Code 2.1.263); older versions may need updating.

**macOS warning on older downloads:** releases through 2.1.2 are not notarized. This
can trigger a Gatekeeper warning on another Mac. A self-signed certificate does not
solve that. Do not disable Gatekeeper or treat a malware warning as a routine install
step. Use the [signing status above](#pom--claude--codex-usage-limits-for-macos) and
[Apple's guidance](https://support.apple.com/en-us/102445) to identify the warning.

Version 2.1.2 has no in-app updater. Moving to the first 2.2 release requires downloading
its DMG once; later releases can be installed through **Check for Updates…**.

Codex recovery notifications require the backend to explicitly report that ordinary usage is allowed. If your CLI omits this field, POM does not claim that access has recovered from percentages alone.

## Privacy and data

POM asks the installed CLIs for usage; it does not send a chat message to a model.
CLI sign-in and credential refresh remain with the respective provider. No separate
API key is needed. An optional Claude server fallback is disabled by default.

POM stores recent readings and 30 days of history in `~/Library/Application Support/POM`.
History contains timestamps, limit percentages and reset times, not prompts, messages
or access tokens. It stays on this Mac and can be cleared in the history window.
POM does not upload history or add analytics. Limits from different providers are
kept separate; missing values are shown as unavailable.

## Build and contribute

```bash
swift run pom-tests
python3 tests/bridge_tests.py
bash scripts/check-ui.sh
bash scripts/bundle.sh
bash scripts/install.sh
```

The bundle script builds a universal **arm64 + x86_64** app using Swift Package Manager
and Apple's command line tools. `bash scripts/make-dmg.sh` creates a clearly marked
**development** DMG. This does not make it a trusted public installer.

See the [developer guide](claudedocs/README.md), [release signing guide](docs/RELEASING.md)
and [2.2 release notes](docs/releases/2.2.0.md). Bug reports should include your macOS,
POM and CLI versions plus the exact error text; omit credentials and private conversations.

## License

[MIT](LICENSE). An independent project by Ponas Obuolys, not affiliated with Anthropic or OpenAI.
Provider marks belong to their respective owners. SVG assets are from
[Lobe Icons](https://github.com/lobehub/lobe-icons); see [third-party notices](Sources/POM/Resources/THIRD-PARTY-NOTICES.txt).
Updates use [Sparkle](https://sparkle-project.org/), distributed under its permissive license.
