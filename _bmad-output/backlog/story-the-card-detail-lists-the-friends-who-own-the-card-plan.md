---
title: 'Card detail lists the friends who own the card'
type: 'feature'
ticket: 'story-the-card-detail-lists-the-friends-who-own-the-card'
created: '2026-11-05'
status: done
baseline_revision: 'a0dc3e9f282d5998355e116e7537fd5c2c87bf69'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The card detail tells a player what they hold, but not which of their friends own the card, so they cannot see who to ask or whose profile to visit.

**Approach:** Add an owners fact to the signed-in card detail with two lists of the viewer's friends: first those holding the edition being viewed, then, under a "they own another edition" heading, those holding only other editions of the same game, each line naming which editions they hold.

## Decisions

- Friends only: the viewer's friends whose profile is not private (same set as `Game::FriendsPresence` minus `:private`), never other players.
- Any edition of the game counts; friends holding the viewed edition come first, the rest go in the "another edition" section with their editions spelled out (rarity + season, like the editions fact).
- Each section shows its first 3 friends, the rest folded behind a `<details>` "+N more", as the editions fact does.
- Each friend shows their copy count ("×2"): of the viewed edition in the first section, of all their editions in the second; sorted by copies descending, then name.

## Boundaries & Constraints

**Always:** Each name links to the friend's profile by token; never a database id. Strings in `en.yml` and `fr.yml` (French plurals with `zero`). The read lives in a Game query. No `style` attribute; CSS in the card detail stylesheet.

**Never:** No write on the GET. No new JavaScript. No change to the signed-out public card page. No non-friend is ever named or counted.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Same edition | Friend holds the viewed edition ×2 | Listed in the first section, "×2", linked to profile | No error expected |
| Other edition | Friend holds only S1 rare of a card viewed in S2 | Listed under "another edition" with "Rare : S1" | No error expected |
| Both | Friend holds viewed and another edition | Only in the first section | No error expected |
| Private friend | Friend's visibility is private | Not listed | No error expected |
| Non-friend | Public stranger holds the card | Not listed | No error expected |
| No friend owns it | — | Fact shows "None of your friends owns it" | No error expected |
| Many | 5 friends in a section | 3 shown, "+2 more" fold | No error expected |
| Quantity 0 | Holding row with quantity 0 | Not an owner | No error expected |

</frozen-after-approval>

## Code Map

- `app/controllers/cards_controller.rb` -- `show`; set `@friend_owners` beside `@pioneer`, skipped when `@public`.
- `app/views/cards/show.html.erb` -- passes locals to `cards/detail`; add `friend_owners:`.
- `app/views/cards/_detail.html.erb` -- `<dl class="card-detail__facts">`; add the owners fact after the editions fact (inside `if signed_in`), reusing the editions fold markup (`card-detail__editions-fold`, `card-detail__editions-more`). Extract the fact into a partial `cards/_friend_owners.html.erb` to keep `_detail` readable.
- `app/domains/game/app/queries/game/friends_presence.rb` -- source of the viewer's visible friends (reject `state == :private`); `FriendsOf.call(player)` gives the friend players.
- `app/domains/game/app/queries/game/held_editions.rb` -- SQL pattern over `game_holdings` ⨝ `catalog_card_seasons` ⨝ `catalog_seasons`, `quantity > 0`, `rarity IS NOT NULL`, rarity via `Catalog::Rarity::TIERS`.
- `app/helpers/card_details_helper.rb#card_detail_edition_lines` -- reuse to spell a friend's other editions.
- `app/helpers/friends_helper.rb#friend_name` -- display name.
- `config/locales/{en,fr}.yml` `card_details` -- new strings.
- Tests: `test/controllers/cards_controller_test.rb`, `test/system/card_detail_test.rb`; query test beside the other Game query tests.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/friends_owning.rb` -- `Game::FriendsOwning.call(viewer, card_id:, card_season_id:)` → `Owners(same:, other:)`; each owner `(player, copies, editions)` where `editions` are `[rarity, season_number, quantity]` like `HeldEditions`; one SQL query for all friend ids; sorting per Decisions.
- [ ] query test -- every matrix row.
- [ ] `app/controllers/cards_controller.rb`, `app/views/cards/show.html.erb` -- load and pass `friend_owners`.
- [ ] `app/views/cards/_friend_owners.html.erb`, `app/views/cards/_detail.html.erb` -- render the fact.
- [ ] card detail stylesheet -- `.card-detail__owners` list, sub-heading, copies.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- fact label, "another edition" heading, copies "×%{count}", empty line, fold "+N more".
- [ ] `test/controllers/cards_controller_test.rb` -- both sections render, private friend and stranger absent, tokens in links.

**Acceptance Criteria:**
- Given a signed-in viewer whose friend holds the viewed edition, when they open the card detail, then the friend's name links to their profile with their copy count.
- Given the signed-out public card page, when it renders, then no owners fact appears.

## Review Triage Log

Pass 1 (quick): high 0, medium 0, low 1, false 0, maybe-false 0, rejected 2.

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| `friends_owning.rb#sorted` sorts on raw `persona_name`, not the displayed name | low | patch | A nameless friend sorted as "" but shows the fallback; now sorts on `Accounts::PersonaName.clean`. |
| Query test lacks the "Many" row and visible friends owning nothing | low | reject | "Many" is covered by the controller fold test; "none" by private, stranger and quantity-0 cases. |
| No system test for the new fact | low | reject | The plan asks only that the existing system test passes; it does. |

## Implementation Notes

- Query budgets in the card detail request test rose by one (the friendships read) and the query test counts 3 (friendships, friends, holdings).
- `bin/ci` schema steps fail locally on the Postgres check-constraint dump format; unrelated, no migration here.

## Verification

The implementer writes the code and tests but does not run the suites; the main session runs them afterwards.

**Commands:**
- `bin/rails test test/controllers/cards_controller_test.rb` and the new query test -- pass
- `bin/rails test test/system/card_detail_test.rb` -- pass
- `bundle exec packwerk check`, `bin/ci`, `npm run lint:css`, `script/check_file_sizes`, `script/check_planning_references` -- pass
