---
title: 'Repost'
type: 'feature'
ticket: '6'
created: '2026-10-08'
status: done
baseline_revision: '787645219d6fa24c222b3da7fa0685c5937aab15'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 1
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The feed already knows a `repost` kind (`Game::FeedEntry::KINDS`, the `reposts` filter, the DB check) but nothing writes one: a player cannot share a card they own to the feed.

**Approach:** A `Game::RepostCard` operation checks server-side that the player holds the card (any rarity, no limit, repeatable) and publishes `Game::CardReposted`; a handler writes a notable `repost` feed entry with no pack. The feed shows it as "Hugo a reposté Elden Ring." with a "REPOST" tag in the accent colour and the thumbnail framed in the card's rarity colour. "REPOSTER" (secondary) appears on cards the player owns in three places — the card detail beside "PARTAGER", a revealed card at the end of a booster opening (desktop under the revealed card, phone in the card zoom), and the hub showcase under its card — and confirms with the toast "Carte repostée dans le fil." / "Card reposted to the feed."; the button stays available.

## Boundaries & Constraints

**Always:** the write goes through the operation (one event inside its transaction; the handler writes the row in that transaction and publishes nothing). Ownership is held copies (`quantity > 0`, reserved copies included). The card is addressed by slug and season number, never a database id. A repost is a past event: it stays after the card is traded away, and `Game::Visibility` hides it with a hidden, banned or deleted profile (the feed already filters by owner). Every string in `en.yml` and `fr.yml`; the failure code `card_not_owned` gets `errors.game.card_not_owned` in both by hand. Schema changes expand/contract (strong_migrations), `db/schema.rb` regenerated on Postgres 18 (`RAILS_ENV=test bin/rails db:drop db:create db:migrate`), never hand-edited. Every action has a Pundit policy. A GET writes nothing.

**Never:** no message, reactions or comments on a repost; no limit or cooldown on reposts beyond a request rate limit; no button for a visitor or a card not owned; reposts never in the LIVE ticker (not built yet; nothing to change now); no change to the trade or pull rows; no `style` attribute in server HTML; no planning ids in code or tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Repost an owned card | player holds ≥1 copy (any rarity) | one `repost` FeedEntry (player, card-season, rarity, notable, now), `CardReposted` event; toast "Carte repostée dans le fil." | — |
| Repost again | same card, again | a second entry; no limit | — |
| Card not owned | quantity 0 or no holding | `Failure(:card_not_owned)`, nothing written | toast/JSON error with `errors.game.card_not_owned` |
| Only reserved copies | quantity = reserved > 0 | allowed (the player owns it) | — |
| Unknown card / season | bad slug or number | not found | 404 (HTML/turbo), JSON `{error:{code:"not_found"}}` |
| Visitor | no session | refused | redirect to sign-in (HTML), 401 JSON |
| Traded away later | holding drops to 0 | the entry stays in the feed | — |
| Hidden / banned owner | visibility private or banned | entry hidden from others | — |
| Feed filter | `?filter=reposts` | only repost entries, with the REPOST tag | — |

</intent-contract>

## Code Map

- `db/migrate/` (latest `20261007193002_*`) -- `game_feed_entries.pack_id` and `.position` are NOT NULL with a unique index `(pack_id, position)` (NULLs distinct, keep it). New migration 1: `change_column_null :game_feed_entries, :pack_id, true` and `:position, true`, and add a check `(kind = 'repost') = (pack_id IS NULL AND position IS NULL)` with `validate: false`; migration 2: validate it. Copy the style of `20261007140600..140602` (the kind column) for naming.
- `packs/game/app/models/game/feed_entry.rb` -- `KINDS` (L18) includes `repost`; `record_pack` (L28-45) writes pulls with `insert_all`. Add the repost write here or in the handler.
- `packs/game/app/handlers/game/handlers/pack_opened_feed.rb` + `config/initializers/event_store.rb` L74 -- model for a handler and its subscription: add `Game::Handlers::CardRepostedFeed` subscribed to `Game::CardReposted`.
- `packs/game/app/events/game/daily_bonus_collected.rb` -- event style (identifiers only): `Game::CardReposted` with `{ player_id:, card_season_id: }`.
- `packs/game/app/operations/game/operation.rb` (`require_player`, `stream_name`), `packs/game/app/operations/game/collect_daily_bonus.rb` L32-49 -- operation shape. New `Game::RepostCard#call(player:, card_season_id:)`: `require_player`, holding check, `transaction { publish(...) }`.
- `packs/game/app/queries/game/feed_entries.rb` -- reads `notable: true` rows by kind with owner visibility; no change expected beyond what the repost row needs (notable true, a rarity).
- `packs/catalog/app/queries/catalog/card_detail.rb` `call(slug:, locale:, season_number:)` -- resolves a card-season from slug and season number (published season when nil); reuse or add a lighter Catalog lookup returning the card-season id.
- `app/controllers/daily_bonuses_controller.rb` + `app/views/daily_bonuses/create.turbo_stream.erb` + `app/policies/daily_bonus_policy.rb` -- POST with rate_limit, turbo_stream toast append to `#toasts`, html redirect with flash; `app/controllers/collection_seen_controller.rb` -- JSON error shape `{ error: { code:, message: } }` and throttled answer. New `RepostsController#create` answering turbo_stream, html and json; route under `scope ":locale"`, e.g. `post "cards/:slug/repost"` with an optional `season` param (or nested under `card_season`), plus `RepostPolicy#create? = player?`.
- `app/views/feeds/show.html.erb` L34-45 -- `kind == "discovery"` branch vs `pulled_html`; the right-hand tag is the rarity. Add a repost branch: sentence `feeds.show.reposted_html` ("%{name} a reposté %{card}." / "%{name} reposted %{card}."), tag "REPOST" (`feeds.show.repost_tag`) in accent, thumbnail framed in rarity colour. `app/frontend/styles/feed.css` (`.feed__tag` L88, `.feed__chip` L71).
- `app/views/cards/_detail.html.erb` L136-147 `.card-detail__actions` -- "Partager" shows `if share_url` (set only when the viewer holds copies and is signed in): REPOSTER (`button_to`, secondary, turbo stream) beside it under the same condition.
- Booster island: `app/helpers/boosters_helper.rb#booster_props` (add `repostUrl` and strings `boosters.island.repost`, `reposted`), `app/frontend/lib/booster_props.ts`, `app/frontend/lib/opening.ts` L56-79 (fetch with CSRF, JSON errors), `lib/booster_page.ts#csrfToken`, `lib/events.ts` (`gameble:toast` `{message, title?, tone}`), `app/frontend/components/BoosterCard.tsx` L141-150 (under the revealed card's label, desktop/narrow layouts), `BoosterZoom.tsx` `.booster-zoom__actions` (phone). The island knows each card's `slug` and the props' `season` number. The button shows once the card is revealed.
- `app/views/pages/_showcase.html.erb` L22 (the card's "Voir la fiche") and `PagesController#showcase` -- REPOSTER under the showcase card when the player holds it (`Game::Quantities`).
- `config/locales/en.yml`, `fr.yml` -- `reposts.create.reposted` ("Card reposted to the feed." / "Carte repostée dans le fil."), button "Repost"/"Reposter", feed sentence and tag, `errors.game.card_not_owned` ("You do not own this card." / "Vous ne possédez pas cette carte.").
- Tests: `test/packs/game/` (operation: owned, any rarity, repeat, not owned, reserved-only, visitor nil; handler row; feed query shows repost, stays after traded away, hidden when private/banned) — `test/packs/game/feed_test.rb#add_entries` needs a pack today; `test/controllers/feeds_controller_test.rb` (sentence, REPOST tag, filter); new `test/controllers/reposts_controller_test.rb` (turbo_stream toast, json success/failure, not owned, unknown card, visitor, rate limit via `test/support/counting_rate_limit.rb`); system: `test/system/card_detail_test.rb` (REPOSTER on an owned card, toast, absent on a missing card / visitor), `test/system/booster_test.rb` (desktop revealed card and phone zoom repost toasts), `test/system/hub_test.rb` (showcase repost).

## Tasks & Acceptance

**Execution:**
- [x] Migrations + `db/schema.rb` (regenerated) -- nullable pack/position for reposts, the paired check added then validated.
- [x] `packs/game/app/events/game/card_reposted.rb`, `packs/game/app/operations/game/repost_card.rb`, `packs/game/app/handlers/game/handlers/card_reposted_feed.rb`, `config/initializers/event_store.rb`, `feed_entry.rb` -- the operation, event, handler writing the notable repost row (rarity of the card-season).
- [x] `app/controllers/reposts_controller.rb`, `app/policies/repost_policy.rb`, `config/routes.rb`, `app/views/reposts/create.turbo_stream.erb` -- POST resolving the card-season by slug and season number, rate-limited, turbo_stream/html/json answers.
- [x] `app/views/feeds/show.html.erb`, `feed.css` -- repost sentence and REPOST tag.
- [x] `app/views/cards/_detail.html.erb` (+ `cards/show.html.erb` locals if needed) -- REPOSTER beside PARTAGER.
- [x] Booster island (`boosters_helper.rb`, `booster_props.ts`, a small `lib/repost.ts` for the POST + vitest, `BoosterCard.tsx`, `BoosterView.tsx`, `BoosterZoom.tsx`, `Booster.tsx`, styles) -- REPOSTER on revealed cards and in the zoom, toast via `gameble:toast`.
- [x] `app/views/pages/_showcase.html.erb`, `pages_controller.rb` -- REPOSTER under an owned showcase card.
- [x] `config/locales/en.yml`, `fr.yml` -- all strings above.
- [x] Tests listed in the Code Map, every matrix row covered.
- [x] Follow-up review fixes, loop 1 (2026-10-08, see Plan Change Log; leave every task above as it is):
  - [x] The repost toast on top of the phone card zoom: the zoom is a modal `<dialog>` in the top layer with an 88% backdrop, so `#toasts` (a fixed, z-indexed element) is drawn under it and is inert. Make the toast region able to sit above an open modal dialog while keeping it the one shared toast region: e.g. `#toasts` becomes `popover="manual"` and `toast_controller.ts` shows it as a popover (`showPopover()`, re-shown when a toast is added while a modal is open, so it lands above that dialog's top layer), styled as today; where `popover` is unsupported, behaviour stays as now. System test (phone): repost from the zoom, the toast is visible (no `visible: :all`) and on top (e.g. `document.elementFromPoint` at the toast's centre is inside `#toasts`), the zoom still open.
  - [x] The feed-entry check (`db/migrate/20261008090000_allow_repost_game_feed_entries.rb`, not pushed yet: edit it in place and regenerate `db/schema.rb` on Postgres 18): a pack and a position belong to pulls and discoveries only, so a future trade row (no pack) is not rejected — `(kind IN ('pull', 'discovery')) = (pack_id IS NOT NULL AND position IS NOT NULL)`. Model test: a repost with a pack and a pull without one are rejected by the database.
  - [x] `packs/game/app/models/game/feed_entry.rb` -- the header and `KINDS` comments still describe every entry as an opened pack's card written only by `PackOpenedFeed`: make them true for reposts (no pack, written by `CardRepostedFeed`).
  - [x] New comments that explain code rather than an external constraint (AGENTS.md): drop or shorten the ones this diff added (`RepostsController`, `Game::RepostCard`, `Game::Handlers::CardRepostedFeed`, `Game::CardReposted`, `Catalog::PublishedCardSeasonId`, `lib/repost.ts` headers; the one-liners in `BoosterCard.tsx`, `Booster.tsx`, `booster.css`), keeping a name or an extracted method where the intent would otherwise be lost.

**Acceptance Criteria:**
- Given a signed-in player on the detail of a card they own, when they press REPOSTER, then the toast "Carte repostée dans le fil." shows, the button stays, and the feed's first entry reads "<name> a reposté <card>." with a REPOST tag.
- Given a player at the end of a booster opening, when they press REPOSTER under a revealed card (desktop) or in the card zoom (phone), then the same toast shows and the feed holds that repost.
- Given a player whose hub showcase shows a card they hold, when they press REPOSTER under it, then the toast shows.
- Given a visitor or a card the viewer does not own, when the detail renders, then no REPOSTER shows; a forged POST for a card not owned is refused and writes nothing.

## Implementation Notes

- Route: one season-qualified POST, `cards/:slug/seasons/:number/repost` (`card_repost`); the island's `repostUrl` uses the props' published season with SLUG replaced. Card-season lookup: new `Catalog::PublishedCardSeasonId`.
- `Game::FeedEntry.record_repost` reads the rarity from the card-season; the handler stamps the event's timestamp.
- Controller: turbo_stream toast (200 / 422 / 404 / 429), html redirect back with flash (404 raised for an unknown card), json `{ message }` or `{ error: { code, message } }`; rate limit 30/min.
- Booster: REPOSTER kept in the row's layout but hidden until the card is revealed (no layout shift); an extra string `repost_card` gives each button its own accessible name, `repost_failed` covers a lost answer.
- Hub: the showcase reads the player's copies once more (hub budget 17 → 18 queries).
- Card detail on a phone: the holder's three actions wrap to two pinned rows; scroll padding follows.
- Toast over the zoom (loop 1): `#toasts` is `popover="manual"`, shown on connect and shown again after any open modal dialog when a toast is tracked; its CSS resets the UA popover box, so without JS or `popover` it shows as before. A modal dialog leaves everything outside it inert, a popover drawn above it included, so `elementFromPoint` cannot see the toast: the phone test asserts the region was opened while the zoom was modal (its `toggle` event) instead. While the zoom is open the toast is visible but its "✕" cannot be clicked and the region is outside the accessibility tree; it still times out by itself.
- Feed-entry check (loop 1): named `game_feed_entries_pack_check`; `db/schema.rb` holds Postgres's round-tripped form of the expression, the one CI's load-and-dump drift check produces.

## Plan Change Log

- 2026-10-08 — Review pass 1. Triggering findings: (1) on a phone the repost toast is drawn under the open card zoom's modal backdrop; (2) the feed-entry check `(kind = 'repost') = (pack_id IS NULL AND position IS NULL)` would reject trade rows, which have no pack; (3) the FeedEntry comments describe only pack entries; (4) new explanatory comments against AGENTS.md. Amended: the task group "Follow-up review fixes, loop 1" and the check expression (Code Map's migration line is superseded by it). Known-bad state avoided: a phone player getting no visible confirmation; the trades-in-feed story blocked by a constraint; stale model docs. KEEP: everything in the working tree (operation, event, handler, controller and route, policy, Catalog lookup, the feed's repost sentence and tag, the three REPOSTER places and their tests, the locale keys, the hub query budget of 18); the revert before re-derivation is empty.

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 5 findings — high 0, medium 2, low 2, false 0, maybe-false 1
- findings:
  - `[medium]` `[bad_plan]` The phone zoom's repost toast is drawn under the modal dialog's 88% backdrop and is inert — verified: the zoom is opened with `showModal()` (top layer), `#toasts` is `position: fixed; z-index: 20`, and the system test only passes with `visible: :all`; plan amended (loop-1 task 1).
  - `[medium]` `[bad_plan]` The feed-entry check rejects any non-repost row without a pack, so trade rows (in KINDS, shown by the feed per the epic) cannot be written — verified in the migration; plan amended (loop-1 task 2).
  - `[low]` `[bad_plan]` FeedEntry's header and KINDS comments still say every entry is an opened pack's card written only by PackOpenedFeed — verified; folded into the amended plan (loop-1 task 3).
  - `[low]` `[bad_plan]` New explanatory comments against AGENTS.md's no-comments rule — verified in the listed files; folded (loop-1 task 4).
  - `[maybe-false]` `[reject]` On 430–719 px phones the three detail actions may fit one row while the scroll padding reserves two — would need a browser check at those widths; if true only a few pixels of extra bottom padding (low).


### 2026-10-08 — Review pass (loop 1)
- verdicts: 7 findings — high 0, medium 2, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` A pack shown again (`?pack=`) offers REPOSTER on a card traded away since — real but rare (a trade between the opening and coming back from its card's detail); the press is refused server-side with "You do not own this card."; hiding it needs current holdings in the island's props.
  - `[medium]` `[patch]` The booster's repost URL used the published season, so a pack of an older season shown again reposted to the wrong card-season — fixed: each card of the opening answer carries its `season`, and the island builds `/cards/SLUG/seasons/NUMBER/repost` from it (the repost route's digit constraint dropped so the template builds; the controller 404s a non-numeric number); controller, helper and vitest cover it.
  - `[medium]` `[patch]` In the phone zoom the toast is inert and unannounced while the modal is open — fixed: the zoom holds a visually hidden `role="status"` region that receives the repost's message; the phone system test waits for it.
  - `[low]` `[reject]` No in-flight guard on the island's REPOSTER: a double tap writes two reposts — reposts are unlimited by design, so a second entry is a repeat the player could make anyway; a guard adds state.
  - `[low]` `[patch]` Explanatory comments still added (BoosterView, BoosterZoom, booster_props, feed.css, card-detail.css, RepostPolicy, record_repost, RepostsController) — fixed: dropped.
  - `[low]` `[patch]` The card-detail.css comment above the actions named two actions — fixed: names the three.
  - `[low]` `[patch]` (same root as the medium zoom finding: the popover approach alone leaves the toast unpressable while the zoom is modal) — covered by the in-dialog status; the toast closes on its own timer.

## Verification

All Ruby commands need Ruby 4.0.7 from rbenv: prefix them with `export PATH=/opt/rbenv/shims:$PATH && `; system tests also need `CHROME_BIN=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/chrome.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/cd/chromedriver`. Postgres 18 runs in docker on 5433. Never run `npm install`.

**Commands:**
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` then `git diff db/schema.rb` -- expected: only the feed-entry changes
- `bin/rails test` -- expected: all green
- `bin/rails test test/system/card_detail_test.rb test/system/booster_test.rb test/system/hub_test.rb test/system/feed_test.rb` (system env above) -- expected: green (run touched files 3×; `library_test.rb:188` fails on the baseline too)
- `npm run test:js && npm run typecheck` -- expected: pass
- `bin/rubocop && bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

**Summary.** A player reposts a card they hold (any rarity, any number of times) through `Game::RepostCard`, which checks holdings server-side and publishes `Game::CardReposted`; `Game::Handlers::CardRepostedFeed` writes a notable `repost` feed entry with no pack. The feed shows "Hugo a reposté Portal." with a REPOST tag in the accent and the thumbnail framed in the rarity colour. REPOSTER sits beside PARTAGER on the card detail, under each revealed card at the end of an opening (desktop) and in the card zoom (phone), and under the hub showcase's card while held; it confirms with "Carte repostée dans le fil.".

**Files.**
- `db/migrate/20261008090000_allow_repost_game_feed_entries.rb`, `20261008090001_validate_game_feed_entries_pack_check.rb`, `db/schema.rb` -- nullable pack/position; a pack and a position for pulls and discoveries only.
- `packs/game/app/{events,operations,handlers,models}` -- `CardReposted`, `RepostCard`, `CardRepostedFeed`, `FeedEntry.record_repost`; `config/initializers/event_store.rb`.
- `packs/catalog/app/queries/catalog/published_card_season_id.rb` -- card-season by slug and season number.
- `app/controllers/reposts_controller.rb`, `app/policies/repost_policy.rb`, `config/routes.rb`, `app/views/reposts/create.turbo_stream.erb` -- the POST (turbo stream, HTML, JSON), rate-limited.
- `app/views/feeds/show.html.erb`, `feed.css` -- the repost entry.
- `app/views/cards/_detail.html.erb`, `card-detail.css`, `app/views/pages/_showcase.html.erb`, `pages_controller.rb` -- REPOSTER on the detail and the showcase.
- Booster island (`boosters_helper.rb`, `packs_helper.rb`, `lib/repost.ts`, `lib/opening.ts`, `booster_props.ts`, `Booster*.tsx`, `booster*.css`) -- REPOSTER on revealed cards and in the zoom, each card's own season.
- `app/views/shell/_toasts.html.erb`, `toast_controller.ts`, `shell.css` -- the toast region as a manual popover, raised above an open modal.
- Locales and tests (operation, policy, controllers, feed, system tests for detail, booster desktop and phone, hub).

**Review.** Two quick passes. Pass 1: 2 medium + 2 low `bad_plan` (zoom toast, feed check, stale and explanatory comments), 1 rejected maybe-false (phone scroll padding). Pass 2: 4 patched (2 medium: each card's season, an in-zoom status; 2 low: comments), 1 grouped with the zoom finding, 2 rejected (traded-away card in a pack shown again; no in-flight guard). Patched by verdict on the last pass: medium 2, low 2.

**Follow-up review recommended:** false (a follow-up after a loop; no high patched).

**Verification.** `bin/rails test` 1781 runs green; vitest 192, typecheck, rubocop, packwerk, zeitwerk, i18n-tasks clean; system tests card_detail, booster, hub, feed, shell, friends, trades, daily_bonus: 107 runs green; `db:drop db:create db:migrate` reproduces `db/schema.rb`.

**Residual risks.**
- The toast region now lives in the browser's top layer on every page; a toast already showing when a modal opens stays under it until the next toast.
- While the phone zoom is open the toast's ✕ cannot be pressed (the toast still times out; the zoom announces the result itself).
- The repost route accepts any `:number` and 404s a non-numeric one in the controller.
