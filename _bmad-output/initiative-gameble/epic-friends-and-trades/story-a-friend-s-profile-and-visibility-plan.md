---
title: "A friend's profile and visibility"
type: 'feature'
ticket: '10'
created: '2026-10-07'
status: 'built'
baseline_revision: '03a1649c139d3c67794f76e26ce00f2987968f34'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      PROPOSER UN ÉCHANGE on the friend profile is shown disabled with "Bientôt disponible": it does not yet open the trade in progress with that friend or a new draft.
    evidence: |-
      No trade screen, board or draft exists on develop at this story's baseline (stories 5.6 to 5.8, 5.6 built in parallel); the ticket's verify asks that a trade can be started from the profile. Wire the button (app/views/friend_profiles/show.html.erb) to the trade with that friend or a new draft once the board's entry exists.
    location: >-
      app/views/friend_profiles/show.html.erb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** `Game::Visibility` counts no friend (its `friend?` is a stub until epic 5), so a friends-only profile is hidden from friends too; and a friend row on the Friends screen opens nothing, there is no friend profile with its showcase, PROPOSER UN ÉCHANGE and SIGNALER (EXPERIENCE.md, Friend profile; DESIGN.md, Friend profile).

**Approach:** Plug a Game friendship query into `Game::Visibility.friend?`, so every surface that asks the one question (public profile, report, feed) lets a friend see a friends-only player. Add the friend profile dialog: a friend's name in the friends list opens a modal whose body is a lazy Turbo frame loaded from `GET /:locale/friends/:token`, showing the avatar, name, card count, "VITRINE" with three cards, PROPOSER UN ÉCHANGE and SIGNALER (the report dialog and `Accounts::ReportPlayer` of story 7.4, reused).

**Decisions (autonomous run, author away):** the showcase's three cards are the friend's three highest-tier cards held in the published season (copies > 0), the most recently gained first on a tie, then by card-season id; fewer show when fewer are held, none shows the line "Aucune carte en vitrine."; the friend profile is open only to a friend of its owner, and a token that is unknown, not a friend's, banned, or hidden by `Game::Visibility` (a private friend) answers the same "not available" frame with a 404; PROPOSER UN ÉCHANGE is shown as the primary button but disabled with "Bientôt disponible" written beside it, because no trade screen or draft exists on this branch (stories 5.6 to 5.8): wiring it to "the trade in progress with that friend, or a new draft" is deferred; presence on the profile waits for story 5.3; a report sent from the friend profile returns to the Friends screen (`from=friends`), from the public profile as before; the coding is done in this session.

## Boundaries & Constraints

**Always:** `Game::Visibility.visible?` stays the one visibility question (AD-13) and the only caller of the friendship query for visibility; GETs never write (AD-11); no database id in a URL or the DOM (AD-15: the friend's token); a friendship is read as one row, lower id first; English copy written beside the French.

**Never:** trades screen, board, draft or picker; presence; a second visibility check; changing ProposeTrade, TradeSteps or SendInvitation's friendship checks (epic 8 sweep runs in parallel); the hub showcase.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Friend, public or friends only | friend opens GET /fr/friends/:token | frame: name, card count, VITRINE of up to 3 cards (highest tier first), PROPOSER UN ÉCHANGE disabled + "Bientôt disponible", SIGNALER opening the report dialog | n/a |
| No card held | friend owns nothing in the season | "Aucune carte en vitrine.", count 0 | n/a |
| Private friend | friend's visibility private | same "not available" frame | 404 |
| Not a friend | public owner, viewer not a friend; unknown token; banned friend | "not available" frame | 404 |
| Visitor | signed out | refused, sent home to sign in | sign_in_required |
| Friends-only public profile | friend vs stranger opens /brothers/:token | friend sees it, stranger and visitor get the unavailable page | 404 for them |
| Report from friend profile | POST report with from=friends | report stored, back to the Friends screen with the thank-you | refusals as story 7.4 |
| Feed | friends-only player's pull | shown to their friend, hidden from a stranger | n/a |

</intent-contract>

## Code Map

- `packs/game/app/models/game/visibility.rb` -- replace the `friend?` stub with `FriendshipBetween.call(viewer, owner)`; update its comment.
- `packs/game/app/queries/game/friendship_between.rb` -- new, `Game::FriendshipBetween.call(a, b)` => true/false; false for nil or the same player; one `exists?` on `Friendship` (low_player_id, high_player_id). Model on `friends_of.rb`.
- `packs/game/app/queries/game/showcase_cards.rb` -- new, `Game::ShowcaseCards.call(player, season:)` => up to 3 card-season ids: `game_holdings` with quantity > 0 joined to `catalog_card_seasons` of the season, ordered rarity DESC, last_gained_at DESC NULLS LAST, card_season_id; [] for nil player or season. Style of `notable_pull.rb` / `collection_summary.rb` (AD-2 read of Catalog card-seasons).
- `packs/game/app/queries/game/feed_entries.rb` -- memoize `Visibility.visible?` per player id within one call, so friends-only owners do not cost one friendship query per entry.
- `packs/accounts/app/models/accounts/player.rb:27` -- comment "nobody until epic 5" updated.
- `config/routes.rb` -- `get "friends/:token" => "friend_profiles#show", as: :friend_profile` with the token constraint, under the Friends block.
- `app/controllers/friend_profiles_controller.rb` -- new; `authorize :friend, :show?`; owner by `Accounts::PlayerByToken`; unavailable (404) unless `Game::FriendshipBetween` and `Game::Visibility.visible?`; else `Game::CollectionSummary.distinct_cards`, `Game::ShowcaseCards` -> `Catalog::CardViews` in order.
- `app/views/friend_profiles/show.html.erb`, `unavailable.html.erb` -- each wraps its content in `turbo_frame_tag "friend-profile-#{token}"`, target `_top`; also readable as a page (title, back button like `friends/show`).
- `app/views/friends/show.html.erb` -- the friend row's name becomes a button opening `dialog#friend-<token>` (`data-controller="dialog-opener"`, as `ButtonComponent#opener_options`); after the list, one `friends/_profile_dialog` per friend: the `modal` dialog shell (head, ✕, `data-controller="dialog"`) holding the lazy frame (`src: friend_profile_path`, `loading: :lazy`) with a loading line.
- `app/views/reports/_dialog.html.erb` -- optional locals `id:` (default `report-dialog`) and `from:` (hidden field); `app/controllers/reports_controller.rb` -- redirect to `friends_path` when `params[:from] == "friends"`.
- `app/frontend/styles/friends.css` -- friend name button, profile body (64px avatar, name, count, VITRINE row of three `card--s`, actions, phone fits 360px).
- `config/locales/{fr,en}.yml` -- `friend_profiles.*`, `friends.show.open_profile`, loading line.
- Reuse: `pixel_icon("avatar-default")`, `CardComponent.new(card:, size: :s)`, `ButtonComponent` (`disabled: true`, `variant: :link, opens:`), `PanelComponent`, `.modal*` from `shell.css`, `reports.open` copy.

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/queries/game/friendship_between.rb`, `showcase_cards.rb`, `models/game/visibility.rb`, `queries/game/feed_entries.rb`, `accounts/player.rb` comment -- the domain
- [x] `config/routes.rb`, `app/controllers/friend_profiles_controller.rb`, views, `friends/show.html.erb`, report dialog/controller `from`, CSS, locales -- the surface
- [x] tests: `test/packs/game/visibility_test.rb` (friend sees friends-only; private stays hidden from a friend), `test/packs/game/friend_profile_queries_test.rb` (FriendshipBetween, ShowcaseCards order/limit/season/zero quantity), `test/controllers/friend_profiles_controller_test.rb` (every matrix row), `public_profiles_controller_test.rb` (friends-only seen by a friend), `reports_controller_test.rb` (from=friends), `friends_controller_test.rb` (row opens the dialog, lazy frame src), feed test (friends-only for a friend), `test/system/friends_test.rb` (open a friend's profile from the list on desktop and 390px phone, see three cards, SIGNALER opens the report dialog)

**Acceptance Criteria:**
- Given two friends, when one presses the other's name on the Friends screen, then the friend profile dialog opens with their showcase and PROPOSER UN ÉCHANGE, and SIGNALER opens the report dialog.
- Given a friends-only player, when a friend opens their public profile, then it shows; when a stranger or visitor does, then the unavailable page shows.
- Given `Game::Visibility`, then it is the only place the friendship decides visibility.

## Implementation Notes

Subagents unavailable, done in-session (implementation and the quick review lens). Decisions as in the intent. `Game::FriendshipBetween` is the friendship question; `Game::Visibility` asks it for a friends-only owner, and the friend profile asks it to gate who opens the profile (a different question: who may open a friend's profile, not who may see a player). `Game::FeedEntries` now asks visibility once per player per call, so a friends-only player costs one friendship query, not one per entry (query count tested). The friend profile dialog body is a lazy Turbo frame (`friend-profile-<token>`, target `_top`), so the report form inside it navigates the page; the report dialog partial gained `id:` and `from:` locals, and its radios ids are now unique per dialog (`<dialog id>-<reason>`). On a 360 to 390px phone the three `card--s` faces wrap two and one inside the bottom sheet (3 × 112px does not fit 342px); the card face sizes belong to the card face. Files: `packs/game/app/queries/game/{friendship_between,showcase_cards}.rb`, `models/game/visibility.rb`, `queries/game/feed_entries.rb`, `packs/accounts/app/models/accounts/player.rb` (comment), `config/routes.rb`, `app/controllers/{friend_profiles,reports}_controller.rb`, `app/policies/friend_policy.rb` (comment), `app/helpers/friends_helper.rb`, `app/views/friend_profiles/{show,unavailable}.html.erb`, `app/views/friends/{show,_profile_dialog}.html.erb`, `app/views/reports/_dialog.html.erb`, `app/frontend/styles/friends.css`, `config/locales/{fr,en}.yml`, tests.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 5 findings — high 0, medium 1, low 2, false 2, maybe-false 0
- findings:
  - `[medium]` `[defer]` PROPOSER UN ÉCHANGE does not start a trade (the ticket's verify) — real, but the trade screen, board and draft do not exist at the baseline (stories 5.6 to 5.8); the button is shown disabled with its reason and the wiring is deferred in frontmatter.
  - `[low]` `[patch]` two friend profiles opened on one page hold two report dialogs whose reason radios share ids (`reason_cheating`…) — fixed: each radio's id is `<dialog id>-<reason>`.
  - `[low]` `[reject]` on a 360 to 390px phone the three showcase cards wrap two and one — the sheet scrolls and stays usable; fitting three needs a smaller card face size, which is the card face's (story 8.6 territory), not a direct correction.
  - `[false]` `[reject]` the friend profile asks friendship besides Game::Visibility, a second visibility check — it gates who may open a friend's profile (only a friend), not whether a player may be seen; visibility is still decided only by Game::Visibility, the only caller of the friendship query for it.
  - `[false]` `[reject]` a click on the report dialog's scrim closes the friend dialog too — `closeOnScrim` closes only when the event target is its own dialog element; the bubbling click's target is the inner dialog.

## Design Notes

The dialog body is a lazy frame so the Friends screen does no per-friend reads: the frame loads when the dialog opens and becomes visible. Its endpoint is the friend profile surface, where friendship gates who may open it and `Game::Visibility` what it shows.

## Verification

**Commands:**
- `bin/rails test` (PARALLEL_WORKERS=2, non-system) -- green
- `bin/rails test test/system/friends_test.rb test/system/public_profile_test.rb` (PARALLEL_WORKERS=1) -- green
- `bin/rubocop` on changed Ruby files, `bin/packwerk check`, `bundle exec i18n-tasks missing` -- clean

## Auto Run Result

- **Summary:** `Game::Visibility` counts friends now (`Game::FriendshipBetween`), so a friends-only player shows to their friends on the public profile, the report and the feed. A friend's name on the Friends screen opens the friend profile dialog, its body a lazy Turbo frame from `GET /:locale/friends/:token`: avatar, name, card count, "VITRINE" with their three highest-tier cards, PROPOSER UN ÉCHANGE (disabled, "Bientôt disponible") and SIGNALER, the report dialog of story 7.4 coming back to the Friends screen. A non-friend, unknown, banned or private friend gets the same "not available" frame with a 404.
- **Files changed:** the Game queries and Visibility (friendship, showcase, feed memo); route, FriendProfilesController, views, helper, dialog partial; report dialog `id`/`from` and ReportsController's way back; friends.css; locales fr/en; tests (queries, visibility, feed, controllers, system `test/system/friends_test.rb`).
- **Review:** quick lens in-session: 1 patch (low), 1 deferred (medium, the trade action's wiring), 3 rejected (1 low, 2 false), reasons in the Review Triage Log.
- **Follow-up review recommended:** false (one low patched).
- **Verification:** `bin/rails test` (PARALLEL_WORKERS=2) 1500 runs green; `bin/rails test test/system/friends_test.rb test/system/public_profile_test.rb` (PARALLEL_WORKERS=1) green; `bin/rubocop` on the changed Ruby files, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused`, `bin/rails zeitwerk:check` clean. No TypeScript changed.
- **Residual risks:** PROPOSER UN ÉCHANGE waits for the trade board (deferred); `app/views/friends/show.html.erb` and `friends.css` are also changed by story 5.3 (presence) in parallel, a merge conflict on the friend row is likely and should keep both the name button and the presence.
