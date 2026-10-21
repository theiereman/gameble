---
title: 'Refactor sweep'
type: 'refactor'
ticket: '12'
created: '2026-10-21'
status: built
baseline_revision: '7f8baff5b9ca5cd6b6648273d1fdd4c7103cadfd'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The epic's build records and the review findings deferred during it leave small debts; none had been settled.

**Approach:** Every deferred finding found in the epic's plans and in `deferred-work.md` is fixed, recorded as left open on purpose, or dropped with a reason. Only cleanup: no behaviour, markup or copy changes.

</frozen-after-approval>

## Implementation Notes

Oneshot: a comment-only cleanup, the rest is a disposition of findings.

- Fixed: the planning ids left in comments of the epic's files (`accounts/sign_in.rb`, `accounts/player.rb`, `accounts/persona_name.rb`, `persona_name_test.rb`, `test/support/library_requests.rb`) and in three README headings and sentences, rewritten as plain English. The other files carrying ids belong to the repo-wide cleanup entry in `deferred-work.md` and stay there.
- Resolved elsewhere: the `IN`-check guard and the migrations replay in CI; the cross-site invite auto-send; a deleted player lingering in friends, trades and invitations; the bank lock of the backfill operations; the opening's replacement wording in the architecture; the stale card-face baselines and the disabled system tests (the suite was rebuilt and the pixel-for-pixel tests removed); the throttling half of the old entry 10; the Sentry retention claim (30 days, set by the author on 2026-10-20); the account-deletion paragraph of the legal page (the deletion wording was approved by the author, commit a625d87a); the ban reason in the data export (`moderationDecisions` carries it, `app/models/player_export.rb:43`); the `LEGAL_*` variables (set in `config/deploy.production.yml:51-54`); the smoke run through Thruster (the script and its CI job are gone).
- Left open, cheap but not cleanup: the `hold` test helper copied in about 34 test files (the signatures differ, a shared one would change them all); staging has no log age limit in `config/deploy.staging.yml` (an infrastructure edit whose wording the privacy notice ties to the author's 30 days).
- Left open on purpose, each a product, legal or privacy call for the author: the Brotherhood voice left in staff-facing copy and URLs (`staff_required`, `/brothers/`); staff seeing a hidden or banned profile with no marker; no audit trail or ban-reason page; the stale publisher and moderation lines of the legal page; the moderation history keeping a ban reason after the account is deleted; the back-office player search's `ILIKE` without a `pg_trgm` index (matters at hundreds of thousands of players).
- Left open, needing tooling: the phone tray thumbnails' art states have no test (vitest has no DOM).
- Notes only: the old container's events during a staging deploy keep `remote_ip` (rerun the strip once); Cloudflare's no-store behaviour must be checked at the edge; the README's journald step stays a host step.

## Verification

**Commands:**
- `bundle exec packwerk check` -- expected: no offenses
- `bundle exec rubocop` on the edited files -- expected: no offenses
- `bin/rails test test/packs/accounts` -- expected: green
