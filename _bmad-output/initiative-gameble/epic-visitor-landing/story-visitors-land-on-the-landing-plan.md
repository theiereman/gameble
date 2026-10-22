---
title: 'Visitors land on the landing'
type: 'feature'
ticket: '15'
created: '2026-10-22'
status: 'built'
baseline_revision: '8cd2a530e557d62038cfd2cec01a2f68429a8110'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      The root's visitor check loads the player in allow_browser before the read-only wrapper.
    evidence: |-
      A read only; no test of read_only_requests covers pages#home.
    location: >-
      app/controllers/pages_controller.rb
    severity: low
  - summary: >-
      GET /:locale counts against the public-read throttle for players on the hub too.
    evidence: |-
      Rack::Attack has no session; players behind one address share 120 per minute. Settle by measuring hub GETs per player.
    location: >-
      config/initializers/rack_attack.rb
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Signed out, `/fr` and `/en` still redirect to the provisional `/:locale/landing`; the root switch (R7) is the epic's last feature step and every ship condition of R8 now holds.

**Approach:** Serve the landing at the root for a visitor and the hub at the same address for a player, drop the provisional address (permanent redirect to the root), and point every landing destination (wordmark, sign-out, account deletion, refused deep links, motion switch, tab bar) at the root.

</intent-contract>

## Implementation Notes

Oneshot: a routing and controller move with mechanical test renames. The ticket's unknown (the signed-out hub's own address) is settled by the design documents, not guessed: EXPERIENCE.md (Information Architecture; Landing address, 2026-10-21; Open questions, 2026-10-20) and the spec (CAP-1, 2026-10-20) say there is no signed-out hub, "Embarquer sur le pont" signs in through Steam directly (already built), and the landing lives at the root only, `/landing` redirecting permanently to it. The ticket's "opens the hub at its own address" is superseded the same way.

R8 ship conditions, checked 2026-10-22: lore text (14) and Découvrez tile (20) done; JetBrains Mono (1) done; roadmap milestones (19) and pioneer (13) built; repository public with AGPL-3.0 (`gh repo view`, `LICENSE` tracked).

## Verification

**Commands:**
- `bin/rails test test/controllers test/integration` -- expected: pass
- `bin/rails test test/system/shell_test.rb test/system/hub_test.rb test/system/landing_*.rb test/system/share_card_test.rb test/system/roadmap_page_test.rb test/system/settings_test.rb` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health`, `npm run test:js`, `npx tsc --noEmit`, `bin/rubocop` -- expected: pass

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 8 findings — high 0, medium 1, low 5, false 0, maybe-false 2
- findings:
  - `[low]` `[defer]` the root's visitor check calls current_player from allow_browser before the read-only wrapper — a read only, nothing writes; no test covers pages#home in the read-only suite
  - `[medium]` `[defer]` GET /:locale is counted by the public-read throttle (120/min/IP), so players behind one address share it on the hub — Rack::Attack cannot see the session; unverified in practice
  - `[low]` `[patch]` the visitor test was written twice — extracted `visitor_landing?`
  - `[low]` `[patch]` `shell_home_path` became a dead wrapper — removed, callers use `home_path`
  - `[low]` `[patch]` stale headers on PublicRead and PagesController — rewritten
  - `[maybe-false]` `[reject]` landing view and helper kept under landings/ — works, renaming is churn
  - `[low]` `[reject]` deleted wordmark-href assertions in the shell test — visitor and player now share an href by design
  - `[maybe-false]` `[reject]` system tests not run — run: shell, hub, landing_*, roadmap_page, share_card, settings pass

## Auto Run Result

Root switch built. PagesController#home serves the landing to a visitor (HTML) and the hub to a player; `/:locale/landing` redirects 301 to the root; wordmark, sign-out, deletion, refused deep links, motion switch, tab bar and locale redirect lead to the root; the root is a public read for a visitor and throttled with the public pages. Signed-out hub: none (EXPERIENCE.md, spec CAP-1). Licence: repository PUBLIC, AGPL-3.0, LICENSE tracked.
Review: 3 patches applied, 2 deferred, 3 rejected. Verification: controllers and integration 1004 runs green, system tests green, rubocop, packwerk, zeitwerk, vitest, tsc clean; i18n-tasks health reports a pre-existing fr.yml `one` key and unnormalized files, untouched here. Follow-up review not recommended.
