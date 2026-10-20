---
title: "A visitor's way in to every card"
type: 'feature'
ticket: 5
created: '2026-10-20'
status: 'built'
baseline_revision: 'd87874b691b53cac4b30219b93ea52d7b860bb2b'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
commit: '886a0fa07e988d4f46e54677d7e2b6ecbb128390'
context: []
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A signed-out visitor reaches "Toutes les cartes" only through the hub's 02 COLLECTION then "TOUTES LES CARTES ▸"; the landing has no way in. And a visitor still sees a zero set progress (count, bar, tier ticks) in a set album's header and in the collection entry's set search rows, which EXPERIENCE.md's Navigation (signed-out visitors) rules out.

**Approach:** (1) The hub's numbered menu gets "03 TOUTES LES CARTES" right after 02 COLLECTION, a plain link to /library/cards for a player and a visitor alike; ÉCHANGES … SOUTENIR renumber 04 to 09 (numbers and `aria-keyshortcuts`). The phone's PLUS screen gets a TOUTES LES CARTES row first. (2) The landing's module 01 · Concept ("Chaque carte est un jeu Steam.", the five sample cards) ends with the link "Voir toutes les cartes" / "See every card" to /library/cards, styled like 04's "Ouvrir le fil d'activité". (3) For a visitor (`current_player` nil), a set album's header keeps only the set's name, and the entry's set search rows keep the name and kind, with no count, bar, tier ticks or tier mark.

## Boundaries & Constraints

**Always:** a player's album, rows and hub sets unchanged; a public profile's album and set rows (owner's progress) unchanged; every string in en.yml and fr.yml; no `style` attribute; no planning ids in code or tests; menu numbers, keyshortcuts, view comments and controller comments agree (01 … 09).

**Never:** change the grid, the card detail, policies, `PublicReadThrottle`, the entry's "EN COURS" section, or the hub's SETS EN COURS; no new route; no new event or operation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Hub, player | signed in, `/fr` | nine items, numbers 01…09, keys 1…9; item 3 a link to `/fr/library/cards` labelled "Toutes les cartes"; ÉCHANGES key 4, AMIS 5, FIL 6, SUCCÈS 7, COMMENT 8, SOUTENIR 9 | none |
| Hub, visitor | signed out, `/en` (the signed-out hub) | item 3 a link (not the sign-in panel) to `/en/library/cards`, "All cards" | none |
| PLUS | `/fr/more`, player and visitor | first row a link to `/fr/library/cards`, "Toutes les cartes" | none |
| Landing | `/fr/landing`, `/en/landing` signed out | module 01 holds a link to `/fr/library/cards` "Voir toutes les cartes" (`/en/library/cards`, "See every card") | none |
| Album, visitor | signed out, `/en/library/theme/roguelike` | `h1` set name and every slot; no `.set-album__count`, `progress`, `.set-album__ticks`, `.set-album__stamp`, no `--tiered` | none |
| Album, player / public profile | signed in / `brother_set_path` | unchanged: count, bar, ticks | none |
| Set search, visitor | `/en/library?q=rogue` and its frame | each result row names set and kind, no `.set-row__count`, `progress`, `.set-tier`, ticks; its accessible text is name and kind | none |
| Set search, player | signed in | unchanged | none |

</intent-contract>

## Code Map

- `app/views/pages/_menu.html.erb` -- the menu list; insert a new `pages/menu_all_cards` partial after the 02 entry; shift the loop positions (`[[:trades, 4], [:friends, 5], [:feed, 6], [:achievements, 7]]` — note the positions are unused inside, numbers live in each partial); rewrite the header comment (keys 1 to 9, 03 the catalog for everyone, the others renumbered).
- `app/views/pages/_menu_feed.html.erb` -- model for the new `_menu_all_cards.html.erb` (link for everyone, `hub-menu#remember`, `turbo_prefetch: false`, number "03", key "3", label `t("pages.home.menu.all_cards")`, comment "Menu 03 …").
- `app/views/pages/_menu_trades.html.erb` 03→04, `_menu_friends.html.erb` 04→05, `_menu_feed.html.erb` 05→06, `_menu_achievements.html.erb` 06→07, `_menu_how_it_works.html.erb` 07→08, `_menu_support.html.erb` 08→09 -- number text, `keyshortcuts` and comments.
- `app/views/pages/more.html.erb` -- first `li`: link to `library_cards_path`, `menu-item menu-item--plus`, label `t("pages.home.menu.all_cards")`; update comment.
- `app/controllers/pages_controller.rb`, `app/controllers/daily_bonuses_controller.rb`, `goal_rewards_controller.rb`, `app/views/pages/home.html.erb` -- comments naming menu numbers (04 friends → 05, 06 achievements → 07; menu 01 stays).
- `config/locales/en.yml` / `fr.yml` -- `pages.home.menu.all_cards`: "All cards" / "Toutes les cartes" (same words as `library.entry.all_cards`); `landings.show.concept.all_cards`: "See every card" / "Voir toutes les cartes".
- `app/views/landings/_concept.html.erb` -- after the `PanelComponent` block, `link_to t("landings.show.concept.all_cards"), library_cards_path, class: "button button--link landing-concept__all-cards"` (as `_live.html.erb`'s `landing-live__open`); `app/frontend/styles/landing.css` -- spacing for the link only if needed, mirroring `.landing-live__open`.
- `app/views/library/_album.html.erb` -- a `progress` local (`local_assigns.fetch(:progress, true)`): without it, header keeps `h1` only (no stamp, count, track, no `--tiered`/`--complete` modifiers); `app/views/library/set.html.erb` passes `progress: current_player.present?`. `public_profiles/set.html.erb` passes nothing (default true).
- `app/views/library/_set_progress_row.html.erb` -- a `progress` local, default true; without it: class `set-row set-row--visitor`, name and kind only, the visually-hidden text name and kind (new helper `set_label_sentence(set)` in `app/helpers/set_rows_helper.rb`, reused by `set_progress_sentence`).
- `app/views/library/show.html.erb` → `_entry.html.erb` → `_set_results.html.erb` -- thread `progress: current_player.present?` to the results rows only (EN COURS untouched; it is empty for a visitor).
- `app/frontend/styles/hub.css` -- `.set-row--visitor { grid-template-columns: minmax(0, 1fr) auto; grid-template-areas: "name meta"; align-items: baseline; }` after `.set-row--progress`, and the name wrapping like `.set-row--progress .set-row__name`.
- Tests: `test/controllers/pages_controller_test.rb` (lines ~131–170, 340–350: keys/numbers 1..9, item 3 for player and visitor, how-it-works key 8, support key 9), `test/controllers/trades_controller_test.rb:59` (key 4), `test/controllers/achievements_controller_test.rb:138-157` (key 7), `test/controllers/friends_controller_test.rb:348-359` (key 5), `test/controllers/feeds_controller_test.rb:242` (menu 06), `test/integration/player_stream_tag_test.rb:49` (name), PLUS row tests wherever `/more` is asserted; `test/controllers/landings_controller_test.rb` (link in module 01, fr and en); `test/controllers/library_set_test.rb:198` visitor album (no count/bar/ticks, slots stay) and a public profile album still showing count (in `public_profiles_controller_test.rb` if not already asserted); `test/controllers/library_controller_test.rb` set search visitor rows. System tests (`test/system/*`): update the menu keys 3→4 (trades), 4→5 (shell_test friends) for consistency only; never run them.

## Tasks & Acceptance

**Execution:**
- [x] `app/views/pages/_menu*.html.erb`, `more.html.erb`, `home.html.erb`, controllers' comments, locales -- menu 03 and PLUS row, renumbering.
- [x] `app/views/landings/_concept.html.erb`, `landing.css`, locales -- the landing link.
- [x] `app/views/library/_album.html.erb`, `set.html.erb`, `show.html.erb`, `_entry.html.erb`, `_set_results.html.erb`, `_set_progress_row.html.erb`, `app/helpers/set_rows_helper.rb`, `hub.css` -- no set progress for a visitor.
- [x] tests listed in the Code Map -- the matrix rows.

**Acceptance Criteria:**
- Given a visitor on the landing in fr or en, when they follow module 01's link, then "Toutes les cartes" opens in one step; likewise from hub menu 03 and the PLUS row.
- Given a player, when they open the hub, PLUS, an album or the set search, then only the new menu 03 and PLUS row (and the renumbering) differ.

## Implementation Notes

- Menu 03 is its own partial, `pages/_menu_all_cards.html.erb`, modelled on menu 06 (feed); every later item renumbered with its key.
- `.landing-concept__all-cards` mirrors `.landing-live__open`, so the link does not stretch across the module's flex column.
- Two album tests that read a visitor's zero progress changed: the French value text now reads a signed-in moderator's empty album; the 130-card paging test lost its "0/130" count.
- `test/system/hub_test.rb`: the "key no item carries" step pressed "6", now the feed; it presses "0" (every digit 1 to 9 is now an item). System tests not run.

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` `test/system/hub_test.rb:271` presses "0", which `menuDigit` drops before the controller, so the step no longer exercises "a digit no item carries does nothing" — with nine items no digit 1 to 9 is free on the hub, so that path cannot be reached there any more; the step still shows a non-item key leaves the hub, and the system test is not run.

## Design Notes

The landing's place and words are not settled by the docs (the ticket's `unknown`, `pending-approvals.md`): module 01 · Concept is chosen as it already shows the cards and states "Every card is a Steam game"; the wording follows the landing's sentence-case links ("Ouvrir le fil d'activité", "Voir toute la feuille de route"). Open question for the author.

## Verification

**Commands:** (prefix Rails commands with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w14_5 CHROME_BIN=/usr/bin/chromium`; never run system tests; do not commit)
- `bin/rails test` -- 0 failures
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bin/brakeman --quiet --no-pager --exit-on-warn` -- clean

## Auto Run Result

- Summary: the hub's menu gets 03 TOUTES LES CARTES (a link to /library/cards for a player and a visitor) and renumbers ÉCHANGES … SOUTENIR 04 to 09 with their keys; the phone's PLUS opens on a Toutes les cartes row; the landing's module 01 · Concept ends with "Voir toutes les cartes" / "See every card"; a visitor's set album header keeps only the set's name (no count, bar, ticks or stamp) and their set search rows only the name and kind. A player's and a public profile's progress are unchanged.
- Files: `app/views/pages/_menu.html.erb`, `_menu_all_cards.html.erb` (new), `_menu_trades|friends|feed|achievements|how_it_works|support.html.erb` (renumbered), `more.html.erb` (PLUS row); `app/controllers/pages_controller.rb` (comment); `app/views/landings/_concept.html.erb`, `app/frontend/styles/landing.css` (landing link); `app/views/library/_album.html.erb`, `set.html.erb`, `show.html.erb`, `_entry.html.erb`, `_set_results.html.erb`, `_set_progress_row.html.erb`, `app/helpers/set_rows_helper.rb`, `app/frontend/styles/hub.css` (no progress for a visitor); `config/locales/en.yml`, `fr.yml`; tests in the pages, trades, achievements, friends, feeds, settings, landings, library and library_set controller tests, `test/integration/player_stream_tag_test.rb`, and the hub, shell and trades system tests (keys only, not run).
- Review (quick): 1 low finding, rejected (see the triage log). No patch, no deferral.
- Follow-up review recommended: false (no patched entry).
- Verification: `bin/rails test` 2912 runs, 0 failures; `npm run test:js` 492 passed; typecheck, zeitwerk, packwerk, rubocop (853 files), i18n-tasks missing and brakeman clean. No system tests run.
- Residual risk: the visitor's set row and album header layouts and the landing link's placement are checked from the markup and CSS only, not in a browser.
- Open questions for the author: (1) the landing link's place (module 01 · Concept, after the five sample cards) and words ("Voir toutes les cartes" / "See every card") are the build's choice, as the docs leave them open; (2) a visitor's collection entry still shows "Aucun set en cours pour l'instant. Cherchez-en un ci-dessus." under EN COURS, a progress line that may read oddly signed out.
