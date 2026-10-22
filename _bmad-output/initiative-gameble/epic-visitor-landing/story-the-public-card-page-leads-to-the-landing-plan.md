---
title: 'The public card page leads to the landing'
type: 'feature'
ticket: '16'
created: '2026-10-22'
status: 'built'
baseline_revision: 'c0978c38ea4df5ea6d7c1453ba55a9ed0d2f492b'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The ticket asks for « Découvrir » and « Embarquer sur le pont » links on the signed-out public card page and for its wordmark to lead to the landing; the design documents (author, 2026-10-20) superseded the two links, and the root switch left the wordmark behaviour untested.

**Approach:** Keep the page as the design describes it: the wordmark is the one link to the landing, « OUVRIR MES PREMIÈRES CAPSULES » the one way in (Steam sign-in), no signed-out hub exists to link to; lock this with a controller and a system test.

</intent-contract>

## Implementation Notes

Oneshot: no production code changes. Since the root switch the public card page's wordmark (the top bar's `home_path` link) already opens the landing for a visitor. The ticket's two links are superseded, not built: EXPERIENCE.md (Information Architecture, Public card page; Interactions, Public card page; Copy deck, Public page) and the spec (CAP-1) say the page carries no « Découvrir » and no « Embarquer sur le pont », and there is no signed-out hub; the epic's Done when 6 ("the signed-out hub is reached from the landing and the public card page") is superseded the same way as in the previous ticket's plan. Files touched: `test/controllers/cards_controller_test.rb` (wordmark href is the landing; the page has no other link to it), `test/system/share_card_test.rb` (a visitor follows the wordmark to the landing).

## Verification

**Commands:**
- `bin/rails test test/controllers/cards_controller_test.rb test/system/share_card_test.rb` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health`, `npm run test:js`, `npx tsc --noEmit`, `bin/rubocop` -- expected: pass

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 0 findings; tests only.

## Auto Run Result

Built as tests only: the wordmark-to-landing behaviour already held and is now locked; the ticket's two links and the signed-out hub are superseded by the design (author, 2026-10-20). Verification: cards controller (57 runs) and share_card system test (6 runs) green.
