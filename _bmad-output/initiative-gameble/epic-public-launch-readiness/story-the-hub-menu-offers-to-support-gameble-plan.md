---
title: 'The hub menu offers to support gameble'
type: 'feature'
ticket: '45'
created: '2026-10-13'
status: done
baseline_revision: '29eea28a4995b0e839fe09f1318e0306ac743e5b'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      The comment blocks of the hub menu and PLUS views still name DESIGN.md and EXPERIENCE.md, which AGENTS.md forbids in code.
    evidence: |-
      Pre-existing lines ("DESIGN.md, Menu item; EXPERIENCE.md, Menu item", "DESIGN.md, PLUS rows") kept unchanged by this diff; other views likely carry the same references, so a sweep fits better than a one-ticket edit.
    location: >-
      app/views/pages/_menu.html.erb:1, app/views/pages/more.html.erb:2
    severity: low
---

<intent-contract>

## Intent

**Problem:** The only ways to reach the donation page are the legal page and the settings screen; the hub, where every player and visitor lands, does not offer it.

**Approach:** The hub menu gets a last entry, 08 SOUTENIR / SUPPORT (key 8), styled as a menu item whose action is the donation link (`ExternalLinksHelper::DONATION_URL`, opened in a new tab with the external link's `rel`), for a player and a visitor alike; the phone's PLUS screen gets the same row, last. The entry says nothing more than its label: donations are optional and give no advantage, as the legal page already states.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/external_links_helper.rb` -- add `donation_menu_item_to(name, number: nil, **options)`: a link to `DONATION_URL` with the same `rel`/`target` as `external_link_to` (shared constant), content: optional `menu-item__number` (aria-hidden), `menu-item__label`, the visually hidden "(new tab)" hint, the `external` pixel icon as `menu-item__external`.
- [ ] `app/views/pages/_menu_support.html.erb`, `app/views/pages/_menu.html.erb` -- entry 08 after 07, `aria-keyshortcuts: "8"`, `hub_menu_target: "item"`; no `hub-menu#remember` (the hub stays open, nothing to come back to); update the menu comment.
- [ ] `app/views/pages/more.html.erb` -- last PLUS row, for a visitor and a player; update its comment.
- [ ] `app/frontend/styles/hub.css` -- `.menu-item__external` (14px, always visible, turns on-accent with the item on hover).
- [ ] `config/locales/en.yml`, `fr.yml` -- `pages.home.menu.support`: "Support" / "Soutenir".
- [ ] `test/controllers/pages_controller_test.rb` -- player hub: 8 entries, keys 1–8, numbers 01–08, entry 08 href, `_blank`, `rel` with noopener noreferrer external, label and new-tab hint; visitor hub has entry 08 in English.
- [ ] `test/controllers/settings_controller_test.rb` -- PLUS: visitor 5 rows, player 6 rows, the donation row last in a new tab.
- [ ] `test/system/hub_test.rb` -- menu count 8 (not run: system tests disabled).
- [ ] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md`, `DESIGN.md` -- IA, desktop navigation 08 SOUTENIR, keys 1 to 8, PLUS rows, Menu item numbers 01 to 08 and the external icon.

**Acceptance Criteria:**
- Given a visitor or a player on the desktop hub, when they click entry 08 or press 8 with focus in the menu, then the donation page opens in a new tab and the hub stays.
- Given a phone on PLUS, signed in or not, when they tap SOUTENIR, then the donation page opens in a new tab.

## Implementation Notes

Oneshot: about 60 lines across a helper, two views, a stylesheet rule, locales and tests, all following the menu entry 07 and `donation_link_to` patterns.

- `ExternalLinksHelper#donation_menu_item_to` renders the menu item; the `rel`/`target` pair moved into `ExternalLinksHelper::NEW_TAB`, shared with `external_link_to`, and the new-tab hint into a private `new_tab_hint`.
- Entry 08 lives in `app/views/pages/_menu_support.html.erb`; it carries `hub_menu_target: "item"` so key 8 reaches it, but no `hub-menu#remember`: the hub never leaves, so remembering 08 would focus it on a later, unrelated return.
- The external icon (`.menu-item__external`, `app/frontend/styles/hub.css`) shows at rest, unlike the hover arrow, so the row says it leaves the site before it is used.
- The PLUS row is the last row, after Profil et paramètres for a player, as the menu entry is the last one.
- `test/system/hub_test.rb` counts 8 entries (not run, system tests are disabled).

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` the hub test did not assert that entry 08 carries no `hub-menu#remember` — added `assert_nil support["data-action"]` in `test/controllers/pages_controller_test.rb`.
  - `[low]` `[patch]` the PLUS tests did not check the external icon DESIGN.md promises — both PLUS assertions in `test/controllers/settings_controller_test.rb` now require `svg.menu-item__external`.
  - `[low]` `[patch]` DESIGN.md's Menu item hover sentence said a pixel arrow appears on every item, while SOUTENIR renders none — the sentence now says SOUTENIR keeps its external icon and gets no arrow.
  - `[low]` `[patch]` new intent comments in `hub.css` and `_menu_support.html.erb` — the CSS comment is deleted; the partial's header follows the repo's view convention (every menu partial has one, kept in ticket 44's review) and is kept, as it explains why 08 alone lacks `remember`.
  - `[low]` `[defer]` the edited `_menu.html.erb` and `more.html.erb` comment blocks still name DESIGN.md and EXPERIENCE.md — pre-existing lines, not introduced here; deferred for a sweep.
  - `[n/a]` `[reject]` the plan's Execution boxes are unticked — the fix edits this build's plan.

## Verification

**Commands:**
- `bin/rails test` -- expected: all pass (system tests skipped)
- `npm run test:js`, `npm run typecheck` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: clean

## Auto Run Result

**Summary:** the hub menu gets a last entry, 08 SOUTENIR / SUPPORT (key 8), a menu item that opens the donation page (`ExternalLinksHelper::DONATION_URL`) in a new tab with `rel="noopener noreferrer external"`, for a player and a visitor; the phone's PLUS screen gets the same row, last. The entry shows the external pixel icon at rest and is not remembered for the hub's focus restore.

**Files changed:**
- `app/helpers/external_links_helper.rb` -- `donation_menu_item_to`; the new-tab attributes (`NEW_TAB`) and hint shared with `external_link_to`.
- `app/views/pages/_menu_support.html.erb`, `app/views/pages/_menu.html.erb` -- menu entry 08.
- `app/views/pages/more.html.erb` -- the last PLUS row.
- `app/frontend/styles/hub.css` -- `.menu-item__external`.
- `config/locales/en.yml`, `config/locales/fr.yml` -- `pages.home.menu.support`.
- `test/controllers/pages_controller_test.rb`, `test/controllers/settings_controller_test.rb`, `test/system/hub_test.rb` -- 8 entries, entry 08's link, the PLUS rows (system test not run).
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md`, `DESIGN.md` -- IA row, desktop navigation 08, keys 1 to 8, PLUS rows, Menu item numbers and icon.

**Review:** 6 findings from the quick lens: 4 low patched, 1 low deferred (pre-existing design-doc names in view comments), 1 rejected (ticking the plan's boxes edits the plan).

**Follow-up review recommended:** false — patched low 4, no medium or high.

**Verification:** after the patches, `bin/rails test` 2412 runs 0 failures, `npm run test:js` 255 passed, `npm run typecheck` clean, `bin/rails zeitwerk:check` all good, `bundle exec packwerk check` no violations, `bin/rubocop` no offenses, `bundle exec i18n-tasks missing` none. System tests not run, by rule.

**Residual risks:** the entry was not looked at in a browser (the external icon's size and alignment beside the labels); the PLUS row is placed last, after Profil et paramètres, a choice the author may want to move next to Comment ça marche.
