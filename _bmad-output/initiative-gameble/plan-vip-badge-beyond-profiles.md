---
title: 'The VIP badge follows supporters into the feed, the rankings, duels and friends'
type: 'feature'
ticket: ''
created: '2026-11-25'
status: 'built'
baseline_revision: '522edc7f8a71d6d2ec9885219065e75becc44f33'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/docs/design-system.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The VIP badge granted to supporters shows only on their profile, so nobody sees it where players actually meet: the feed above all, the rankings, duels and the friends list.

**Approach:** Show a compact VIP badge right after a supporter's name in the feed (entries, ticker, live strip), the pioneer rankings and Grand Inventaire, duel opponents and the friends list, with each list learning its supporters in one batched query.

## Boundaries & Constraints

**Always:** One batch query per list (`Game::SupporterStatus.for_players(players)` returning a Set of player ids, modelled on `Game::ActiveAvatar.for_players`), never one query per name; pass the set down the way `friends:` already reaches `PlayerNameComponent` (a new `supporters:` argument, default none → no badge, no query). The badge markup comes from one helper shared with the profile (split `supporter_badge` into the status check and the markup); in lists a compact variant (smaller, keeps the gold shine and the tooltip/accessible label). A removed or nameless player shows no badge. Update the query-count assertions the extra batch query moves, one per page.

**Never:** No badge on market screens (sellers, bidders, history), the bell, settings or the player chip. No change to how VIP is granted. No denormalised column.

</frozen-after-approval>

## Code Map

- `app/helpers/public_profiles_helper.rb:2-9` -- `supporter_badge(player)`: runs `Game::SupporterStatus.call` then builds the markup; split out `supporter_badge_tag(compact: false)`.
- `app/domains/game/app/queries/game/supporter_status.rb` -- add `for_players`.
- `app/domains/game/app/queries/game/active_avatar.rb:7-10` -- batching pattern.
- `app/components/player_name_component.rb` -- add `supporters:`; append the compact badge after the name when the player's id is in the set.
- Feed: `app/domains/game/app/queries/game/feed_entries.rb` -- `Entry` Data (l.3) and `titled` (l.82-84, used by `page` l.43 and `newer` l.48) batch titles: add `player_supporter`/`partner_supporter` the same way; check `visible_feed_entry.rb` and `new_feed_entries.rb` build `Entry` through the same path or give them the flags. `app/helpers/feed_helper.rb:138` `feed_name(player, title, links:, titles:)` -- take the supporter flag; callers l.10, 14, 22, 75, 98, 117 (component), 124. Views `feeds/_entry.html.erb:16,37`, `shell/_ticker_item.html.erb:4`, `shell/_live_strip_body.html.erb:6`.
- Rankings: `app/views/pioneer_rankings/_rows.html.erb:8`, `grand_inventories/_pioneer.html.erb:7`, `pages/_grand_inventory_panel.html.erb:20` and their controllers/queries -- load the set once per list.
- Duels: `app/helpers/duels_helper.rb:13` and duel views that print the opponent name.
- Friends: `app/helpers/friends_helper.rb` and friends list views that print `persona_name`.
- `app/frontend/styles/supporter-badge.css:32-52` -- tooltip; add the compact modifier.
- Tests: feed controller/query tests with `assert_request_queries`, `test/controllers/public_profiles_controller_test.rb`, pioneer rankings, grand inventory, duels and friends controller tests.

## Tasks & Acceptance

**Execution:**
- [x] query + test -- `SupporterStatus.for_players` (empty input → empty set, no query).
- [x] helper + component + CSS -- shared badge markup, compact variant, `supporters:` on `PlayerNameComponent`.
- [x] feed query, helper, views -- supporter flags on entries, badge in entries, ticker and live strip.
- [x] rankings, duels, friends -- batch the set per list and pass it.
- [x] tests -- one per surface showing a supporter's badge and a non-supporter without; update query counts.

**Acceptance Criteria:**
- Given a supporter who sold a card, when anyone opens the feed, then the entry shows the VIP badge after the supporter's name, and the page runs one supporter query whatever the number of entries.
- Given a supporter in the pioneer ranking, a duel or a friends list, then the badge shows after their name there too.

## Verification

The implementation agent writes the tests but does not run any suite; the main session runs these once.

**Commands:**
- `bin/rails test test/controllers test/domains/game test/helpers test/components` -- expected: green
- `bundle exec packwerk check && npm run lint:css && script/check_file_sizes && script/check_planning_references` -- expected: clean

## Review Triage Log

Pass 1 (quick): high 0, medium 1, low 6, false 2.
- medium, patch — in ellipsis containers (pioneer rows, Grand Inventaire slots and panel, duel history) a long name pushes the compact badge out of view. Fix: the name shrinks, the badge keeps its width.
- low, patch — the Grand Inventaire pioneers view runs two supporter queries. Fix: skip the slot set on that view.
- low, patch — missing surface tests (duel header, online list, home panel, feed sale buyer). Added.
- low, rejected — the compact badge's hover tooltip is clipped by `overflow: hidden` in lists and has no tabindex there; the badge reads "VIP" and keeps its aria-label, and a focusable badge breaks the aria-hidden ticker.
- low, rejected — duel sentences (turn, clock, result line, lobby, challenge dialog) carry no badge; the intent names the opponent shown in duels, which the header, history and online list cover.
- low, deferred — views call `Game::SupporterStatus.for_players` directly (duel header re-renders it on every broadcast); move to helpers/controllers.
- low, rejected — the feed's nameless check uses `.presence` where others use `PersonaName.clean`; it only differs for names made of stripped characters.
- false — the feed criterion "a supporter who sold": a sale entry names the buyer; the sale path is now tested with a supporter buyer.
- false — db/schema.rb drift came from the local database and was restored before review.
- 2026-11-25, author feedback after a screenshot: the profile name row wrapped the badge under a short name. The row now keeps the badge inline right after the last word of the name (the name is inline, the badge follows it), so a title below the name never separates them. Checked on profile, Grand Inventaire boards and slots, home panel and friends, at desktop and phone width.
