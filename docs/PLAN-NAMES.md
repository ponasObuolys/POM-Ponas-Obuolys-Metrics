# Plan display names

Last checked: **2026-11-03**. These are display-name rules, not subscription prices,
usage entitlements, or a mechanism to infer an account's plan from its limits.

## Verified provider names

| Provider | Current naming and compatibility rule | Official reference |
| --- | --- | --- |
| Claude | Pro, Max, Ultra; former Max 5x is Max, former Max 20x is Ultra. Free, Team and Enterprise remain supported. | [Max](https://support.claude.com/en/articles/11049741-what-is-the-max-plan), [Ultra](https://support.claude.com/en/articles/17728952-what-is-the-ultra-plan) |
| ChatGPT / Codex | Pro 100, Pro 200, Pro 500 are the named Pro tiers. A generic `pro` or historical `prolite` API type only establishes the Pro family for POM; display **ChatGPT Pro**, without inventing a price or multiplier. An explicitly returned `Pro 100/200/500` label or numeric type can be displayed precisely. | [About ChatGPT Pro tiers](https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers) |
| Cursor | Free, Plus, Premium, Super, Ultra, Teams, Enterprise. Preserve the returned `planInfo.planName`; do not relabel existing legacy subscriptions based only on current pricing. | [Cursor pricing](https://cursor.com/pricing) |
| Grok Bot | Preserve the backend's unified `cursorPlanName` or legacy `grokPlanLabel`. Local cache uses `unifiedPlanName` when present, otherwise `grokPlanLabel`. Legacy linked grants are not automatically converted to a new unified subscription. | [Grok Bot plans](https://cursor.com/help/grok-bot/plans) |

## Source precedence and future changes

- `SubscriptionPlan` is the central compatibility layer. Explicit modern Claude
  types take precedence over stale local metadata. The legacy generic `max` type
  can be refined by the known local rate-limit tier (`default_claude_max_20x` → Ultra).
- New, non-empty source plan names are preserved. Do not silently hide a future
  plan, map it to a familiar cheaper tier, or infer a multiplier from percentages,
  reset windows, model names or token counts. Blank, oversized and control-character
  labels are omitted. Unknown rate-limit tier identifiers alone are not plan names.
- Historical API identifiers can outlive marketing names. Only add an alias when
  the correspondence is supported by provider documentation and the owning source.
  Keep unknown explicit identifiers visible as received rather than guessing.
- POM does not scrape pricing pages at runtime. A marketing rename with unchanged
  API identifiers requires a reviewed compatibility update; preserving dynamic
  source names alone cannot detect every rename.

## Maintenance check

Before a release, or whenever changing a provider integration, reopen the official
sources above. Record the check date and any changed mapping here. Check both
current and legacy plans, verify actual source fields, update regression fixtures,
and regenerate screenshots containing affected badges. A passing unit test only
proves agreement with the fixture; it does not prove that marketing names are current.

Tests cover old Claude identifiers, modern types overriding stale metadata, generic
and explicit ChatGPT Pro tiers, future names, label validation and unified Grok cache
precedence. No billing or quota behavior depends on these display rules.

Validation on 2026-11-03: 400 core checks and the SwiftUI rendering/integration
suite passed. Updated sample screenshots show Claude Ultra and ChatGPT Pro
without historical usage multipliers.
