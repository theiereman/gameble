---
title: 'A screen explains how the game works'
type: 'feature'
ticket: '44'
created: '2026-10-13'
status: done
baseline_revision: '9dd2e8bcb042fa32c78cce117b0bd4cd6ed10383'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Nothing in gameble tells a player or a visitor the rules they meet: which Steam games become cards, what makes a card rare, the odds of each pack, how packs come back, what a season is, which sets exist and how one is completed.

**Approach:** A read-only screen, COMMENT ÇA MARCHE / HOW IT WORKS, at `GET /:locale/how-it-works`, open to visitors, opened from a new hub menu entry 07 (key 7) and a PLUS row on the phone. Every number on it (odds, tier shares, bank size, pack timing, pack sizes, review floor, set thresholds) is computed at render time from the constants the game applies; the rarity explanation lives in one partial so the coming rarity-rule change (epic-season-preparation 11.3) edits one place.

## Boundaries & Constraints

**Always:** `authorize :page, :show?` (PagePolicy); the action reads no database row and writes nothing; strings in `en.yml` and `fr.yml`, the copy in "vous", plain sentences, no "Confrère", no "tu", no exclamation mark; rarity always named in words beside its icon; no `style` attribute; no database id; percentages formatted through the locale (`76 %` in French with a no-break space, `76%` in English).

**Never:** hard-coded numbers in copy or views (every number comes from a constant through an interpolation); planning ids in code, tests or locales; revealing the first-session guarantee (the spec says nothing shows it); describing the card back on a gold tier (not built: `Game::CardBacks` holds only `standard`); a system test; touching ticket 45's donation entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor | `GET /fr/how-it-works`, signed out | 200, French screen, every section | No error expected |
| Player | `GET /en/how-it-works`, signed in | 200, English screen, same sections | No error expected |
| No season | no published season in the database | 200, same content (nothing is read) | No error expected |
| Constant changes | e.g. `DrawOdds::REGULAR[5]` becomes 10 | the shown percent becomes `0.1%`; the test compares to the constant, not a literal | No error expected |
| Hub key | focus in the hub menu, key 7 | activates entry 07 | Missing digits do nothing |

</intent-contract>

## Code Map

- `config/routes.rb` -- add `get "how-it-works" => "pages#how_it_works", as: :how_it_works` beside `more` and `legal`.
- `app/controllers/pages_controller.rb` -- add `how_it_works` (authorize only, like `more`); do not add it to `public_read?`.
- `app/views/pages/_menu.html.erb`, `_menu_feed.html.erb` -- the menu; add entry 07 as a link for everyone, modelled on `_menu_feed` (number "07", `aria-keyshortcuts: "7"`, `hub_menu_target: "item"`, `hub-menu#remember`, `turbo_prefetch: false`, arrow icon), after the loop; update the menu's header comment.
- `app/frontend/controllers/hub_menu_controller.ts` -- `press` accepts only `[1-6]`; accept any digit 1–9 (items are looked up by `aria-keyshortcuts`, an absent one does nothing) and fix the class comment.
- `app/views/pages/more.html.erb` -- PLUS rows; add a "Comment ça marche" link row after Succès, for visitors and players; update its comment.
- `app/views/shell/_tab_bar.html.erb` -- the PLUS tab is current for `pages#more`; make it current for `pages#how_it_works` too.
- `app/views/feeds/show.html.erb` lines 1–8 -- pattern for `back_button`, `title`, `screen_title` and the phone back "◀ PLUS" (`content_for :phone_back`).
- `app/views/pages/legal.html.erb`, `app/frontend/styles/settings.css` (`.legal*`) -- pattern for a panel page (`PanelComponent.new(tag: :section, aria: { labelledby: })`); new styles go in `settings.css` beside `.legal`, block `.how-it-works`.
- `app/components/card_component.rb#rarity_icon` -- rarity icons are `pixel_icon("rarity-compact-#{tier}")`; names are `t("catalog.rarity.#{key}")` with keys from `Catalog::Rarity::TIERS`.
- Facts, read-only (never change them): `Game::DrawOdds` (TOTAL, REGULAR, BONUS, REWARD, EPIC_OR_BETTER), `Game::Pack` (SIZE, BONUS_SIZE, BANK_SIZE, INTERVAL), `Game::Reserve::FULL`, `Game::RewardDraw::MIN_TIER`, `Game::TopUpBank` (replacement INTERVAL after the later of the opening and the bank's latest pack; all missing packs at once when a season is published), `Game::CollectDailyBonus` (once per UTC day, refused at a full reserve), `Game::WeeklyGoal` (week from Monday 00:00 UTC; openings and concluded trades count; every player with a contribution row, both traders included, gets one reward pack), `Steam::ReviewPolicy::MIN_REVIEWS`, `Steam::DetailsPolicy` (type game, vertical image), `Steam::PrestigeScore::SHARE_WEIGHT`, `Catalog::RarityThresholds` (SHARES in basis points per tier from the top, BASIS; common takes the rest; equal scores share a tier), `Catalog::Themes` (`keys.size`, TIER_PERCENTS), `Catalog::SetBuilder` (MIN_GAMES, STUDIO_REVIEW_FLOOR), `Catalog::HallOfFame.keys` with names at `catalog.hall_of_fame.<key>`, `catalog.sets.ufos`, `Game::SetCompletion` (complete once every card is held at once, recorded once).
- `test/controllers/pages_controller_test.rb` lines 94–107 -- the hub test asserts 6 menu entries, keys 1–6 and numbers 01–06; becomes 7.

## Tasks & Acceptance

**Execution:**
- [x] `config/routes.rb`, `app/controllers/pages_controller.rb` -- route and action as mapped.
- [x] `app/helpers/how_it_works_helper.rb` -- `odds_percent(parts)` (parts per `Game::DrawOdds::TOTAL`), `rarity_shares` (tier key => percent of a season from `RarityThresholds::SHARES`, common = the rest), each formatted with `number_to_percentage(..., precision: 2, strip_insignificant_zeros: true)`; `odds_rows(odds)` yielding tier key, icon tier and percent, ascending; durations in minutes from `Game::Pack::INTERVAL` and `BANK_SIZE × INTERVAL`.
- [x] `app/views/pages/_rarity_rule.html.erb` -- the one place the rarity rule is explained: the one-sentence rule, the score in words (review count first, the share of positive reviews weighted by `SHARE_WEIGHT`), the cut at publication with the share of each tier (icon, name, percent), equal scores share a tier; comment says the rule is explained only here.
- [x] `app/views/pages/_odds_table.html.erb` -- a table: caption, one row per tier (icon, name, percent), `data-odds` naming the table (regular, bonus, reward, epic_or_better) so tests read it.
- [x] `app/views/pages/how_it_works.html.erb` -- `h1` and sections, each a `PanelComponent` with an `h2` id: game selection (type game, vertical image, at least `MIN_REVIEWS` reviews, every season re-reads Steam); rarity (`render "pages/rarity_rule"`); packs and odds (regular `Pack::SIZE` cards; odds tables regular, daily, reward, plus the forced card when no Épique or better came); packs over time (bank of `BANK_SIZE`, each opening replaced `INTERVAL` minutes after the last pack waiting, a full bank back in `BANK_SIZE × INTERVAL` minutes, a new season fills a short bank at once); daily booster (once per UTC day, `BONUS_SIZE` cards, no Commune, refused at `Reserve::FULL` ready packs, outside the bank); weekly goal reward; seasons (publication freezes rarity, number and sets; the next season re-reads Steam); sets (themes count, franchise and studio thresholds, the hall of fame set names, the UFOs; tiers bronze/silver/gold from `TIER_PERCENTS` for themes and hall of fame); completion (distinct cards held, duplicates count once, a card counts in every set it belongs to, celebration at opening and a feed line). Back button, title, screen title, phone back "◀ PLUS".
- [x] `app/views/pages/_menu.html.erb`, new `app/views/pages/_menu_how_it_works.html.erb`, `app/frontend/controllers/hub_menu_controller.ts`, `app/views/pages/more.html.erb`, `app/views/shell/_tab_bar.html.erb` -- entry 07, key 7, PLUS row, PLUS tab current.
- [x] `app/frontend/lib/menu_key.ts`, `app/frontend/lib/menu_key.test.ts` -- extract the digit reading of `press` (key, or the `Digit` code for AZERTY; never the numpad code; no Ctrl/Alt/Meta/repeat) into `menuDigit(event)` returning "1"–"9" or undefined, used by `hub_menu_controller.ts`; vitest covers 7 by key, 7 by `Digit7` with Shift, numpad, modifiers, 0 and letters.
- [x] `app/frontend/styles/settings.css` -- `.how-it-works` layout reusing the `.legal` tokens; odds tables readable at phone width.
- [x] `config/locales/fr.yml`, `config/locales/en.yml` -- `pages.home.menu.how_it_works` ("Comment ça marche" / "How it works"), `pages.how_it_works.*`; numbers only through interpolation; plural keys with `zero` in French.
- [x] `test/controllers/how_it_works_test.rb` -- visitor French and player English render every section heading; each `data-odds` table's rows equal its constant (tier name and a percent computed in the test from the constant with BigDecimal, not through the helper) and sum to 100; the rarity shares equal `RarityThresholds::SHARES`; the bank size, interval, refill time, pack sizes, reserve and review floor appear as the constants say; no `[style]`; PLUS tab current and phone back to `/fr/more`; the screen renders the same with no published season (seasons made drafts in the test).
- [x] `test/controllers/pages_controller_test.rb` -- the hub has 7 entries, keys 1–7, numbers 01–07, entry 07 links to `/fr/how-it-works` for a player and a visitor; the PLUS screen has the row for a visitor and a player (here or in `test/integration/shell_test.rb`).
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- IA row "Comment ça marche", desktop navigation 07, phone sub-views list, Menu item keys 1 to 7, PLUS rows; `DESIGN.md` -- Menu item numbers 01 to 07, PLUS rows, a "How it works" screen section.

**Acceptance Criteria:**
- Given a visitor or a player on the desktop hub, when they click entry 07 or press 7 with focus in the menu, then the how-it-works screen opens in their locale.
- Given a phone on PLUS, signed in or not, when they tap "Comment ça marche", then the screen opens with "◀ PLUS" back to PLUS.
- Given the screen, when it renders, then it covers game selection, rarity, odds per pack kind, pack timing, the daily booster, the weekly reward, seasons, set kinds and completion, in French and English.
- Given any constant among the odds, tier shares, bank size, interval or pack sizes, when its value differs from the number shown, then `test/controllers/how_it_works_test.rb` fails.

## Implementation Notes

- Completion copy: the screen says a set is complete when every card is held at once, duplicates count once, a card counts in every set it belongs to, a completion is recorded once, and the player's profile counts the sets held complete now. It does not mention a celebration at opening or a feed line: neither is built (the feed has no set entries and the booster island shows no set tier), so stating them would describe unbuilt behaviour, as with the gold card back.
- Rarity icons on the screen use `pixel_icon("rarity-#{tier}")`, the icon the rarity legend, the collection report and the feed use beside a rarity name; `rarity-compact-*` is the card face's small variant.
- Set tiers are shown through `HowItWorksHelper#set_tier_percents` (from `Catalog::Themes::TIER_PERCENTS`); the score explanation says "one point each time the count is multiplied by ten", the base of the formula's logarithm rather than a tunable constant.
- PLUS rows grew to 5 for a player and 4 for a visitor; `test/controllers/settings_controller_test.rb` covers the new row for both.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 6 findings — high 0, medium 2, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `pages#how_it_works` had no entry in `ShellHelper::SCREEN_LABELS`, so a screen opened from it lost its desktop back button (`history_trail.ts#previousScreen` stops at an unlabelled entry) — added `"pages#how_it_works" => :how_it_works`, `shell.screens.how_it_works` in both locales and a row in `test/helpers/shell_helper_test.rb`.
  - `[low]` `[patch]` EXPERIENCE.md still listed "a guide" as out of the MVP and rejected, beside the new rules screen — both lines now say the guide meant a tour of what to do (the UX memlog's dropped guide) and that the rules reference was asked for by the author on 2026-10-13; the spec's non-goal "A guide or tutorial" is left to the author.
  - `[medium]` `[patch]` the timing and daily copy called the bank of standard boosters "your reserve", while the reserve is every available pack (the chip can show more than ten) — the bank sentences now speak of standard boosters, and "reserve" is kept for the daily booster's refusal, which is the reserve rule.
  - `[low]` `[patch]` "Your complete sets show on your profile" after "recorded only once" implied recorded completions show, while the profile counts sets complete now (`Game::CollectionSummary`) — the sentence now says the profile counts the sets held complete right now.
  - `[low]` `[patch]` the selection rule stated its conditions as sufficient but `Steam::DetailsPolicy` also requires a title and a release date — added both to the sentence.
  - `[low]` `[patch]` new intent-only comments in `HowItWorksHelper` and `PagesController#how_it_works`, and a false "sharing one layout" in the `settings.css` header — deleted the helper and controller comments and the false clause; the view header comments follow the repo's view convention and the `_rarity_rule` one is the pointer the rarity-rule change needs.

### 2026-10-13 — Review pass (follow-up)
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` the franchise sentence stated the game count as sufficient, while `Catalog::SetBuilder.franchises` also drops a franchise named after a studio or publisher of the season and one whose name is in no more than half its titles — the sentence now says the name usually appears in the titles and is not a studio's or a publisher's, in both locales.
  - `[low]` `[patch]` the studio sentence said "from the same studio" while `SetBuilder.studios` counts a game under its first developer only — now "with the same lead studio" / "d'un même studio principal".
  - `[low]` `[patch]` the Phénomènes rule read as a ranking ("the games with the most reviews") while `Catalog::HallOfFame::RULES["phenomenes"]` is a fixed review floor — now "the games with a huge number of reviews" / "un nombre énorme d'évaluations", still without the number.
  - `[low]` `[patch]` `test/system/hub_test.rb` still asserted 6 hub menu entries (two tests) and named its key test "keys 1 to 6" — counts now 7 and the test is named "number keys act only inside the menu"; not run, system tests are disabled.

## Design Notes

The rarity explanation lives in `app/views/pages/_rarity_rule.html.erb` (with its strings under `pages.how_it_works.rarity` and the shares from `HowItWorksHelper#rarity_shares`): the rarity-rule change rewrites that partial and those keys only.

Menu position: 07, key 7, after Succès (the ticket's assumption); ticket 45's SOUTENIR takes 08, which the key handler already accepts.

The first-session guarantee is left out: the spec says nothing shows it. Hall of fame thresholds live in lambdas (`Catalog::HallOfFame::RULES`), so the screen names those sets and describes them in words without numbers rather than copying the thresholds.

## Verification

**Commands:**
- `bin/rails test` -- expected: all pass (system tests skipped)
- `npm run test:js`, `npm run typecheck` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: clean

## Auto Run Result

**Summary:** a read-only screen, COMMENT ÇA MARCHE / HOW IT WORKS, at `GET /:locale/how-it-works`, open to visitors, reached from hub menu entry 07 (key 7) and a PLUS row; it explains game selection, rarity, the odds of each pack kind, the pace of boosters, the daily booster, the weekly goal's reward, seasons, set kinds and completion, every number computed at render time from the game's constants.

**Files changed:**
- `config/routes.rb`, `app/controllers/pages_controller.rb` -- the route and the action (authorize only, no read).
- `app/helpers/how_it_works_helper.rb` -- odds, rarity shares, interval, refill and set tier percents from the constants, locale-formatted.
- `app/views/pages/how_it_works.html.erb` -- the screen, nine panels, back button and "◀ PLUS".
- `app/views/pages/_rarity_rule.html.erb` -- the single place the rarity rule is explained.
- `app/views/pages/_odds_table.html.erb` -- one odds table per `Game::DrawOdds` table.
- `app/views/pages/_menu.html.erb`, `_menu_how_it_works.html.erb` -- menu entry 07.
- `app/views/pages/more.html.erb`, `app/views/shell/_tab_bar.html.erb`, `app/helpers/shell_helper.rb` -- PLUS row, PLUS tab current, the screen's short label for the back button.
- `app/frontend/lib/menu_key.ts` (+ test), `app/frontend/controllers/hub_menu_controller.ts` -- keys 1 to 9 read in one tested function.
- `app/frontend/styles/settings.css` -- the screen's styles.
- `config/locales/en.yml`, `config/locales/fr.yml` -- menu label, screen label, the screen's copy.
- `test/controllers/how_it_works_test.rb`, `test/controllers/pages_controller_test.rb`, `test/controllers/settings_controller_test.rb`, `test/helpers/shell_helper_test.rb` -- the screen, its numbers against the constants, the menu, PLUS and the label.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md`, `DESIGN.md` -- the new screen, entry 07, keys 1 to 7, PLUS rows.

**Review:** 6 findings, all patched (2 medium, 4 low), none deferred, none rejected.

**Follow-up review recommended:** true — two medium entries were patched; the risk to check is the reworded bank and reserve copy and the back-button label from this screen.

**Verification:** after the patches, `bin/rails test` 2412 runs 0 failures, `npm run test:js` 254 passed, `npm run typecheck` clean, `bin/rails zeitwerk:check` all good, `bundle exec packwerk check` no violations, `bin/rubocop` no offenses, `bundle exec i18n-tasks missing` none.

**Residual risks:** the screen was not looked at in a browser (no system test by rule); the spec's non-goal "A guide or tutorial" (`spec-gameble.md`) still reads as excluding guides, for the author to narrow; the copy (French and English) is new and unreviewed by the author.

### Follow-up pass (2026-10-13)

**Review:** 4 findings from the quick lens, all low, all patched (copy of the franchise, studio and Phénomènes sentences in `config/locales/en.yml` and `fr.yml`; the stale hub menu count in `test/system/hub_test.rb`); none deferred, none rejected. The earlier pass's bank/reserve copy and the back-button label were checked against `Game::TopUpBank`, `Game::Reserve` and `ShellHelper::SCREEN_LABELS` and found correct.

**Follow-up review recommended:** false — this follow-up pass patched no high finding (low 4).

**Verification:** `bin/rails test` 2412 runs 0 failures, `npm run test:js` 255 passed, `npm run typecheck` clean, `bin/rails zeitwerk:check` all good, `bundle exec packwerk check` no violations, `bin/rubocop` no offenses, `bundle exec i18n-tasks missing` none. System tests not run, by rule.

**Residual risks:** unchanged — the screen not seen in a browser; the spec's non-goal "A guide or tutorial" left to the author; the new copy unreviewed by the author.
