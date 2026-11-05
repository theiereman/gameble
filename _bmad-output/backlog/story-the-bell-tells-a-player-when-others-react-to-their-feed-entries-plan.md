---
title: 'The bell tells a player when others react to their feed entries, without spam'
type: 'feature'
ticket: 'story-the-bell-tells-a-player-when-others-react-to-their-feed-entries'
created: '2026-11-04'
status: done
baseline_revision: '5143c7316c218744c7d13047e4f1d427639eec83'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player never learns that someone reacted to one of their activity feed entries unless they scroll the feed. A naive "one line per reaction" bell would let one player flood another's bell by toggling a reaction on and off, and a popular entry would push every other line out.

**Approach:** The bell gets one line per feed entry of the player that other players reacted to ("Léa et 2 autres ont réagi à votre publication."). The first reaction of each distinct player to an entry is recorded once and never erased by un-reacting, so only a new distinct reactor makes the line come back as unseen or pushes the bell live; toggling or changing a kind does nothing.

## Boundaries & Constraints

**Always:** every reaction kind notifies, middle_finger included (author, 2026-11-04); the sentence never names the kind. An entry's owners are its `player_id` and, for a trade entry, its `partner_id`; a player's own reaction never notifies them. Reactors banned or deleted do not count. Only public reactors are named (as `FeedReactionSummaries` does); the rest are counted. At most 5 reaction lines, newest first, over the last 7 days, placed after the invitation lines. The line opens `feed_path` and clears like the other non-lasting lines (opening the feed, following it, "Tout marquer comme lu"). A live push to the owner happens only when a new distinct reactor is recorded, batched after commit, at most one per owner per commit.

**Never:** a line or a push per reaction; a notification for a removal or a kind change; a write on a GET; database ids in keys, DOM or streams; changing the existing bell storage format in `bell.ts`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First reaction | Léa (public) reacts to Ana's pull | Ana's bell: "Léa a réagi à votre publication.", live, count +1 | — |
| Toggle spam | Léa removes then re-adds, 20 times | No new notice, no push; the line's key is unchanged, so a seen line stays seen | — |
| Kind change | Léa changes heart → wow | Nothing new | — |
| New reactor | Ana saw the line; Max reacts | Line becomes "Max et 1 autre ont réagi…", key changes, unseen again, live | — |
| All reactions withdrawn | Léa was the only reactor and removes it | The line disappears (no current reactor) | — |
| Private reactor | Only a private player reacted | "1 joueur a réagi à votre publication." | — |
| Own reaction | Ana reacts to her own entry | No notice | — |
| Trade entry | Léa reacts to Ana↔Max trade entry | Both Ana and Max get the line | — |
| Reactor banned/deleted | Léa banned | Léa no longer counted; her notices removed on release | — |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/react_to_feed_entry.rb` -- publishes `FeedEntryReacted` {player_id, feed_entry_id, kind}; kind nil = removal. Do not change.
- `config/initializers/event_store.rb` -- subscribe the new handler to `Game::FeedEntryReacted`, before `PlayerStream`.
- `app/domains/game/app/handlers/game/handlers/` -- pattern for a handler (e.g. `card_reposted_feed.rb`).
- `app/models/player_stream.rb` -- `notices(event)` maps events to `{player_id:, topic:}`; `PlayerStreamJob` turns topics into `gameble-event` signals `"<topic>-updated"`.
- `app/frontend/lib/events.ts` (`gameble:trades-updated` declared line ~34) and `app/frontend/controllers/bell_controller.ts` `connect()` -- add `gameble:reactions-updated` and reload the frame on it.
- `app/domains/game/app/queries/game/bell_items.rb` -- add `reactions` to `Result`; model on `TradeUpdates` (`trade_updates.rb`) for window + limit.
- `app/domains/game/app/queries/game/feed_reaction_summaries.rb` -- reactor filter (`banned_at`/`deleted_at` nil) and public-name rule to reuse.
- `app/helpers/bell_helper.rb` -- `bell_lines` order; add `bell_reaction_line`; `BellLine` key/path/href/sentence/action.
- `app/domains/game/app/operations/game/release_player.rb` -- delete the released player's notices next to `FeedReaction`.
- `db/migrate/20261103184200_create_game_trade_views.rb` -- migration style to copy.
- `test/support/feed_reactions.rb` -- `feed_entry_of`, `react` helpers; `test/domains/game/react_to_feed_entry_test.rb`, `test/system/bell_test.rb` for test style.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/<ts>_create_game_reaction_notices.rb` -- table `game_reaction_notices`: `feed_entry_id` (FK, on_delete cascade), `reactor_id` (FK accounts_players), `timestamps`; unique index (feed_entry_id, reactor_id). Regenerate `db/schema.rb` per AGENTS.md -- the durable "first reaction" record.
- [x] `app/domains/game/app/models/game/reaction_notice.rb` -- model.
- [x] `app/domains/game/app/handlers/game/handlers/reaction_notices.rb` -- on a non-nil kind from a non-owner, `insert_all` with `on_duplicate: :skip` / `returning`; when a row was inserted, hand the owners to `PlayerStream` as `topic: "reactions"` notices -- only new distinct reactors push.
- [x] `config/initializers/event_store.rb`, `app/models/player_stream.rb` -- wire the handler; let the handler add notices through `PlayerStream::BATCH` (or a `PlayerStream.reacted(owner_ids)` entry point) rather than a second job.
- [x] `app/domains/game/app/queries/game/reaction_updates.rb` -- per owned entry with a notice in the last 7 days: notice count, latest notice time, current reactor count (others, in good standing), latest public reactor name; drop entries with zero current reactors; 5 newest.
- [x] `app/domains/game/app/queries/game/bell_items.rb` -- `ReactionLine(token, name, others, count, notices)` into `Result#reactions`.
- [x] `app/helpers/bell_helper.rb` -- `bell_reaction_line`, key `reaction:<entry token>:<notice count>`, path/href `feed_path`, action "Voir"; after invitations.
- [x] `config/locales/en.yml`, `fr.yml` -- `shell.bell.reaction_named` (with `zero`/`one`/`other` on `others`), `shell.bell.reaction_anonymous` (`one`/`other`, fr `zero`).
- [x] `app/frontend/lib/events.ts`, `app/frontend/controllers/bell_controller.ts` -- `gameble:reactions-updated` reloads the bell.
- [x] `app/domains/game/app/operations/game/release_player.rb` -- delete notices where `reactor_id` is the player.
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- Bell row and copy deck: the reaction line (as built, 2026-11-04).
- [x] Tests: `test/domains/game/reaction_notices_test.rb` (matrix rows: first, toggle, kind change, own, trade, banned), `test/domains/game/bell_items_test.rb` or existing equivalent (window, limit, withdrawn, private), `test/models/player_stream_test.rb` (push only on new reactor), `test/system/bell_test.rb` (line appears live and clears on opening the feed).

**Acceptance Criteria:**
- Given Ana's bell shows a seen reaction line, when the same reactor toggles 20 times, then the bell's count does not change and no stream message reaches Ana.
- Given a player is released, when their data is erased, then no `game_reaction_notices` row names them.

## Implementation Notes

- The handler stays in the Game domain and returns the owners to tell; the event store subscription in `config/initializers/event_store.rb` hands them to `PlayerStream.reacted`, since no domain may reference the web layer.
- A reaction by either owner of a trade entry records no notice and is not counted (both are its owners).
- `game_reaction_notices` names a player, so the delete dialog's table list in `test/controllers/accounts_controller_test.rb` maps it to "your reactions to feed entries"; also indexed on `reactor_id` for the release.
- `reactions-updated` joined `STREAM_SIGNALS` in `app/frontend/lib/stream_actions.ts`, which gates which `gameble-event` signals reach the page.

## Plan Change Log

## Review Triage Log

Pass 1 (quick): high 0, medium 2, low 0, false 0, maybe-false 0.

| Verdict | Route | Finding | Evidence / action |
|---|---|---|---|
| medium | patch | Key `reaction:<token>:<notice count>` can regress to a seen value after ReleasePlayer deletes a reactor's notices | `noticed_entries` counts rows that `release_player.rb` deletes; `bell.ts` keeps seen keys. Patched: key on the latest notice time. |
| medium | patch | Reactions given before deploy have no notice, so their first kind change or toggle notifies once | Handler inserts when no row exists; nothing backfills. Patched with a backfill migration, then dropped at the author's call (2026-11-04). |
| (pre-existing) | — | `BellTest` "marking all as read" and `FrenchTypographyTest` (`landings.show.share_image_alt`) fail | Both fail on baseline 5143c731 too; not caused by this change. |

## Design Notes

The key carries the latest notice time, which a removal never changes (notices outlive reactions) and a new reactor always moves forward, so un-react/re-react restores an already-seen key; reactions predating the table are not backfilled (author, 2026-11-04): each may notify once on its first change. Kind changes and removals publish the same event; the handler ignores `kind: nil` and the unique index swallows repeats. The ReactionsController rate limit (60/min) still bounds the event rate.

## Verification

**Commands:**
- `bin/rails test test/domains/game test/models/player_stream_test.rb test/helpers test/controllers/bells_controller_test.rb` -- green
- `bin/rails test test/system/bell_test.rb` -- green
- `npm run test:js && bin/ci && bin/rails zeitwerk:check && bundle exec packwerk check` -- green
