---
epic: epic-friends-and-trades
date: 2026-10-09
verdict: accepted-with-open-items
criteria: declared
headless: false
---

Another retrospective of this epic, run on 2026-10-08 on the other line of history before the two were reconciled, is [epic-friends-and-trades-retrospective.md](epic-friends-and-trades-retrospective.md).

# Retrospective: Friends and trades

## Epic summary

Epic 5, `epic-friends-and-trades`: 12 stories, all at `status: built`, `state: review`. None is `done` yet; `pending_tickets` is empty. The user had no going-in concerns to weight.

### Tickets and their evidence ranges

The plans' `baseline_revision` values do not give usable ranges. The stories were built in parallel worktrees, so several plans share one baseline (`9456caa` for 5.7, 5.9 and 5.11; `03a1649` for 5.6 and 5.10; `47cea18` for 5.2 and 5.4), and the baselines of 5.1 (`fa1676d`) and 5.2/5.4 (`47cea18`) no longer exist in the repository: their worktree branches were rebased or squashed onto `develop`. Each story landed as one feature commit, named in its subject, so the range used for each story is that commit (plus its follow-up refactor for 5.7). Merge commits and the interleaved work of epics 6 and 7 fall outside those ranges.

| Ref | Story | Commits | Files | Lines + / − |
|---|---|---|---|---|
| 5.1 | Friend code and a first Friends screen | `2c76d06` | 29 | +623 / −18 |
| 5.2 | Invitations by code and by link | `257f83b` | 29 | +1051 / −14 |
| 5.3 | Friends' presence | `60e9d86` | 29 | +901 / −30 |
| 5.4 | Trade core: propose, cancel, decline and reserve | `e440b7d` | 17 | +781 / −2 |
| 5.5 | Accept, counter and expire a trade | `885f9d5` | 17 | +899 / −75 |
| 5.6 | Trades screen, server-rendered | `00a642d` | 43 | +2074 / −40 |
| 5.7 | Trade board island: the card picker and quantities | `cb37ba0`, `7108f7f` | — | — |
| 5.8 | Trade board island: the draft, the counter and the swap | `5e26846` | 32 | +1567 / −165 |
| 5.9 | A private stream and live updates | `e808e85` | 38 | +1159 / −22 |
| 5.10 | A friend's profile and visibility | `e2d8102` | 27 | +792 / −25 |
| 5.11 | Deleting or banning an account, and the empty states | `9833354` | 28 | +745 / −89 |
| 5.12 | Refactor sweep | `2d46c6a` | 130 | +361 / −1074 |

The epic's work runs from `69f995a` (the epic incepted) to `ee30ed1` (pending approvals after the sweep). Since then, `2966aaf` (the trade picker filters its cards by title and rarity, plan `_bmad-output/backlog/story-trade-picker-filters-plan.md`) has touched the same code.

### Evidence inventory

- Epic file with Requirements R1–R6 and Done when 1–6: present.
- Twelve plans, one per story: present.
- Story files: none (no story was refined).
- Previous retrospective: the previous epic in build order, `epic-public-launch-readiness`, has none.
- Session logs: Claude Code transcripts for this project under `~/.claude/projects/`.

## Findings

Sources: four analyses ran over the story commits listed above and the code at HEAD (`58ab6e4`). They were the aggregate views, the spec reconciliation, `bmad-review` (adversarial, edge-case and verification-gap lenses, weighted on the seams between stories) and process lessons from the plans, git and the local transcripts. The findings that carry an action item were re-checked against the code by the orchestrating session: F1, F2, F3, F6 and F7.

Disposition key: **fix** (an action item now), **defer** (tracked, with its owner epic), **accept** (recorded so later retros stop re-flagging it), **ask** (needs the author).

### Checked and clean

- **No card can be promised twice.** Every trade operation takes both players' bank locks in sorted order, then the holdings rows. `enough_copies` checks `quantity - reserved` (`packs/game/app/operations/game/trade_steps.rb:48`), and the database enforces `quantity >= reserved >= 0`. The offer is released on accept, cancel, decline, counter, expiry and deletion. Each path is tested (`test/packs/game/trade_accept_counter_expire_test.rb`, `trade_test.rb`, `drop_friends_and_trades_test.rb`, `trade_concurrency_test.rb`).
- **The server enforces its own limits:** 1 to 4 cards per side, quantities from 1 to 999, and the proposer's free copies (`trade_steps.rb:5-12`). One open trade per pair is enforced by both the operation and a partial unique index (`index_game_trades_one_open_per_pair`).
- **No database id leaks.** Stream names are `stream_key` plus the locale (`app/models/player_stream.rb`), and picker keys use card slugs. There are no `style=` attributes. Every epic action calls `authorize`. GET actions only enqueue the presence write (`application_controller.rb#note_presence`). Broadcasts go through `PlayerStreamJob` after commit. Every island event is declared in `app/frontend/lib/events.ts`.
- **Tooling is green:** `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js` (168 tests), and `i18n-tasks missing` / `unused`.
- **Expiry is wired.** `Game::ExpireTradesJob` runs every minute (`config/recurring.yml:26-39`) through Solid Queue in Puma on the web role, in both staging and production.

### Seams between stories (`bmad-review`)

| # | Finding | Source | Severity | Disposition |
|---|---|---|---|---|
| F1 | **Accept and decline act on terms the player may not have seen.** The POST carries only the trade token. A counter keeps the token and rewrites both sides, so a tab that missed the live update (dropped cable, refresh held by a dialog) accepts the friend's new terms, and the toast names the old cards. Crosses 5.5, 5.6/5.8 and 5.9. | `packs/game/app/operations/game/accept_trade.rb:5-16`; `app/controllers/trades_controller.rb:86-96`; `counter_trade.rb:25-28`; 885f9d5, 00a642d | should-fix | **fix**: post the trade's `proposed_at` (or a revision) with accept and decline, and refuse `:trade_changed` after `lock_trade` |
| F2 | **A ban strands the partner's reserved copies.** Nothing publishes `Accounts::PlayerBanned`: only its declaration, the handler and two subscriptions exist. `TradesOf` drops trades with a banned partner (`where(banned_at: nil)`), and cancel returns 404. So after a console ban, A's offer stays reserved, unseen and uncancellable, for up to 7 days, and the friendship stays. R6's ban half is therefore unproven end to end. The only cover is the manual `game:drop_friends_and_trades` task listed in `pending-approvals.md`. Crosses 5.4, 5.6 and 5.11. | `packs/game/app/queries/game/trades_of.rb:48`; `trades_controller.rb:117-119`; `packs/game/app/handlers/game/handlers/player_banned.rb`; `config/initializers/event_store.rb:15`; `deferred-work.md:341-343` | should-fix | **defer** to epic 7's moderation story (7.5): its ban operation must publish `PlayerBanned` and lock in the order `DeletePlayer` uses (see F12). Until then, schedule `DropFriendsAndTradesJob` or keep cancellable rows for a banned partner |
| F3 | **An expired trade not yet swept shows CLOS with "trade again", but sending fails with `trade_already_open`.** `ExpireTradesJob` also discards a `Failure` result without reporting it, so a trade whose expiry keeps failing would block the pair forever, unnoticed. Its sibling jobs call `value!` instead. Crosses 5.4, 5.5 and 5.6/5.8. | `propose_trade.rb:38-41`; `trades_of.rb:71-75`; `packs/game/app/jobs/game/expire_trades_job.rb:12` vs `drop_friends_and_trades_job.rb:16` | should-fix (low) | **fix**: expire the pair's due trade under the lock inside `ProposeTrade`, and report failures from the job |
| F4 | **The trade picker lists a private friend's whole collection.** `/friends/<C>` says "unavailable", but `/trades/new?friend=<C>` sends every card C holds to the island. The 5.7 plan made this choice and marked it `[maybe-false]` for the author. The architecture's adversarial review lists the picker's friend side as a visibility surface. | `trades_controller.rb:150-160`; `app/helpers/trades_helper.rb:149-166`; `architecture-gameble/reviews/review-adversarial-2026-10-05.md:103`; `pending-approvals.md` line 18 | should-fix | **ask** (Open questions) |
| F5 | **Crossing invitations leave a stale pending invitation, and accepting it publishes a second `InvitationAccepted`** (a second NOUVEL AMI toast, a second activity entry). The reverse lookup in `SendInvitation` takes no lock, and `AcceptInvitation` checks no existing friendship. Crosses 5.2 and 5.9. | `packs/game/app/operations/game/send_invitation.rb:7-13`; `accept_invitation.rb:9-11`; 257f83b | should-fix | **fix**: when the friendship already exists, close the reverse invitation and publish nothing; add a concurrency test |
| F6 | A deletion racing an invitation can leave a pending row addressed to a deleted account. | `send_invitation.rb:5-12` vs `drop_friends_and_trades.rb:13` | minor | defer to epic 12 |
| F7 | Ties dropped by the job or the rake task publish no event, so no live update reaches partners (the only path a console ban has). | `drop_friends_and_trades.rb:8-16` | minor | defer with F2 |
| F8 | `IgnoreInvitation` publishes nothing, and the sender's pending row disappears, which tells them they were ignored. | `ignore_invitation.rb:6-11` | minor | ask, with D7 |
| F9 | The stepper's maximum is not capped at `TradeItem::MAX_QUANTITY` (999), which the server refuses. | `trades_helper.rb:75-79`; `trade_steps.rb:9` | minor | accept |
| F10 | A stale draft whose card left the player's holdings is refused as `invalid_offer` instead of the "insufficient copies" message. | `trades_controller.rb:169-177` | minor | defer to epic 12 |
| F11 | The request side is never checked against the friend's free copies. This is deliberate, to keep the friend's other trades private, but an unacceptable proposal blocks the pair until it is cancelled or expires. | `trade_steps.rb:18-20` | minor | accept (the spec reconciliation found the same, D1) |
| F12 | `DropFriendsAndTrades` locks a partner found in the second loop round out of order (its comment says so), so a concurrent proposal can deadlock an account deletion. | `drop_friends_and_trades.rb:25-36` | minor | defer to epic 12 |
| F13 | Presence ignores visibility: a private player shows online, with their activity, to every friend. | `packs/game/app/queries/game/friends_presence.rb` | minor | ask |
| F15 | **Accepting an invitation from a banned sender has no test.** Because of F2, a console-banned sender's pending invitations survive, and the `!sender.removed?` guard is then the only thing that blocks the friendship. Only deleted senders are tested. | `packs/game/app/operations/game/accept_invitation.rb:19-23`; `drop_friends_and_trades_test.rb:97,106` | should-fix (test gap) | **fix** |
| F14 | Drafts in localStorage never expire, and each counter round leaves an orphan key. | `trades_helper.rb:95-96`; 5e26846 | minor | accept |

### Aggregate views

**Architecture delta**

| # | Finding | Source | Severity | Disposition |
|---|---|---|---|---|
| A1 | **Packwerk is green only because no pack sets `enforce_privacy`.** Game reads `Accounts::Player` directly in at least 9 places, although `Accounts::PlayerById` exists and two epic operations use it. | `trades_of.rb:48`, `friends_of.rb:6`, `friends_presence.rb:28`, `invitations_of.rb:11`, `trades_waiting.rb:9`, `accept_trade.rb:16`, `counter_trade.rb:20`, `expire_trades_job.rb:10`, `drop_friends_and_trades_job.rb:10-11` | should-fix | defer to epic 12 |
| A2 | A web-layer job queries a pack model directly. AGENTS.md: "read through the pack's queries". | `app/jobs/player_stream_job.rb:28` (added by the sweep, 2d46c6a) | should-fix | defer to epic 12 |
| A3 | `PlayerStream`, an event handler living in `app/models`, works only because it is subscribed before the ban and deletion handlers. | `config/initializers/event_store.rb:11-25` | minor | accept |
| A4 | Several writing operations publish no event: `IgnoreInvitation`, `CreateFriendCode`, `DropFriendsAndTrades`, `Accounts::NoteLastSeen`. | `ignore_invitation.rb`, `drop_friends_and_trades.rb:12` | minor | defer to epic 12, F7 with F2 |
| A5 | `TradesController` builds operation failures itself (`Failure(:invalid_offer)`), maps form keys through view helpers and composes the toast. | `trades_controller.rb:47`, `:91-93`, `:156-177` | should-fix | defer to epic 12 |
| A6 | Trade operations take database ids (the controller passes `trade.id`); invitation operations take tokens. | `trades_controller.rb:74,90,102,111` | minor | defer to epic 12 |

**Duplication map**

| # | Finding | Source | Severity | Disposition |
|---|---|---|---|---|
| D1 | **"Is this player still usable?" has six forms after the sweep that announced "one standing rule".** They are `removed?`, `banned?` alone, `banned_at: nil`, `in_good_standing`, `require_player` and `require_account`. | `send_invitation.rb:34,39`; `invite_links_controller.rb:25`; `trades_of.rb:48`; `operation.rb:51-61` | should-fix | defer to epic 12 |
| D2 | **One trade side has three representations:** server ERB, React and the props built for the island. Count wording, "nothing to place" and the board middle are each written twice. | `_side.html.erb`; `TradeBoard.tsx:157-240`; `trades_helper.rb:66-89,144-147` | should-fix | defer to epic 12 |
| D3 | The test helpers `befriend` (13 files) and `propose` (8 files) are copy-pasted, although `test/support/` exists. | `test/packs/game/trade_test.rb:16` and others | should-fix | defer to epic 12 |
| D4 | Smaller duplications: `minmax` pair ordering ×4, free copies ×2, the trade state compared as symbols in 14 places, `MAX_CARDS` copied into TypeScript, `browserStorage` copied from `lib/toast.ts`, the dialog lifecycle copied from `BoosterZoom`, and the page kicker CSS ×6. | aggregate report (scratchpad) | minor | defer to epic 12 |

**Size growth and pattern divergence**

| # | Finding | Source | Severity | Disposition |
|---|---|---|---|---|
| S1 | `trades_controller.rb` (202 lines, 8 actions, 11 private methods) is now the largest controller, and `trades_helper.rb` (178 lines) the largest helper. The helper mixes formatting with island-props assembly. | — | should-fix | defer to epic 12 |
| S2 | `trades.css` (+940 lines, five concerns) reopens selectors further down the file (`.trade-board__middle` at `:187`/`:880`, `.trade-board__swap` at `:198`/`:754`). About 11 classes in the epic's markup have no rule. | — | should-fix | defer to epic 12 |
| P1 | **Planning ids remain in code and tests** despite the sweep's commit subject ("without planning ids"). AGENTS.md forbids them. Examples: `app/controllers/sessions_controller.rb:31` (CAP-10) and `:107` (AD-8); `packs/game/app/handlers/game/handlers/player_registered.rb:5`; `packs/game/app/models/game/player_state.rb:11`; `packs/game/app/operations/game/release_player.rb:2-15` (the sweep itself added "story 6.7"); tests named "(story 5.10)" (`test/packs/game/feed_test.rb:100`, `public_profiles_controller_test.rb:350`, `reports_controller_test.rb:138`). | git blame on the epic commits | should-fix | **fix** in the epic's own lines; the rest goes to epic 12 |
| P2 | **`trades.side.cards` has no French `zero` form and renders "0 cartes"** for an empty side, both on the server (`_draft_board.html.erb:15,17` → `trades_helper.rb:69`) and in the island (`TradeBoard.tsx:159`). This is an AGENTS.md known pitfall. Thirteen other epic plural keys lack `zero` but are never rendered with 0. | `config/locales/fr.yml` `trades.side.cards` | should-fix | **fix** |
| P3 | `errors.accounts.invalid_time` is missing in both locales. It is only reached through a job, so no user sees it. | `packs/accounts/app/operations/accounts/note_last_seen.rb:20` | minor | defer to epic 12 |
| P4 | Trade tests are named after story bundles (`trade_accept_counter_expire_test.rb`) instead of the class under test. | `test/packs/game/` | minor | defer to epic 12 |

### Spec reconciliation

All six Done when criteria are met in code and tests. Done when 6 (presence) has no system test. Of the requirements, R6's ban half is unproven (F2).

| # | Divergence | Source | Disposition |
|---|---|---|---|
| R1 | The friend row has no PROPOSER UN ÉCHANGE button. EXPERIENCE (Amis row, State Patterns "One trade per pair") asks for one; only the friend profile has it. | 5.8 plan Decisions; `deferred-work.md` | ask: a follow-up story, or reconcile EXPERIENCE |
| R2 | Sending an invitation to someone who already invited you accepts their invitation. Nobody specified this. | 5.2 plan Decisions; `send_invitation.rb` (reverse → `AcceptInvitation`); `invitation_test.rb:117` | ask |
| R3 | An ignored invitation can be sent again at once, bounded only by the rate limit. | 5.2 plan Decisions; `ignore_invitation.rb` | ask, with F8 |
| R4 | Several trade rules were decided in autonomous runs and never queued in `pending-approvals.md`: the same card allowed on both sides, 999 per line, an unban that does not restore ties, deletion and ban closing trades as `cancelled`, trades with a banned partner left out of the list. | 5.4, 5.6 and 5.11 plans | ask |
| R5 | AD-16's `trade-badge` island event was never built. A server Turbo Stream partial moves the badge instead. | `architecture-gameble.md` AD-16; `app/frontend/lib/events.ts:37-40` | reconcile AD-16 to the as-built |
| R6 | The picker's title and rarity filters (2966aaf) are author-approved but missing from EXPERIENCE's card picker rules. | `_bmad-output/backlog/story-trade-picker-filters-plan.md` | reconcile EXPERIENCE |
| R7 | The concluded board's columns changed meaning between 5.6 and 5.8 (each side as proposed, then crossed: "VOUS AVEZ REÇU"). | 5.8 plan Decisions | accept |
| R8 | The refactor sweep added presence on the friend profile, which its own frozen Boundaries list under "Never: new features", and logged no Plan Change Log entry. | `story-refactor-sweep-plan.md`, Boundaries vs Implementation Notes | accept the feature; the lesson is under process (L9) |
| R9 | Two `pending-approvals.md` entries are stale: the 5.10 showcase entry says the trade button is disabled until 5.8, and the 7.8 entry says "revisit with 5.11". | `pending-approvals.md` lines 12, 15 | fix (doc hygiene) |
| R10 | `TradeAccepted` reaches neither the feed nor the weekly goal. | `config/initializers/event_store.rb` | out of scope: tracked by `epic-brotherhood` ticket 9 "Trades in the feed and the goal" |

Still open from the plans: the island props carry a card face for every card held (5.7/5.8, medium, `deferred-work.md:338-340`); a console ban is not live (5.9); the phone-width check of the picker filters sheet (`_bmad-output/backlog/story-trade-picker-filters-plan.md`, no record that it was done).

### Process lessons

Sources: the plans, git, and the local transcripts. The build transcripts were not available. Stories 5.3 and 5.5–5.12 and the merges were built in a claude.ai/code cloud session, and the morning build of 5.1, 5.2 and 5.4 left no local transcript. So these lessons come from the record, not from the build dialogue.

| # | Lesson | Source | Upstream fix |
|---|---|---|---|
| L1 | **Review depth was pinned to `quick` on all 12 stories,** including the three rated `risk = "high"` (5.4, 5.5, 5.7). The orchestration rule says high-risk tickets get `thorough`. | every plan's frontmatter `review: 'quick'`, `review_source: 'pinned'`; `tickets.toml` risk fields | derive review depth from the ticket's `risk`, not from a pinned value |
| L2 | **Ten stories (5.3, 5.5–5.12) were reviewed by the session that wrote them.** The plans say "Subagents unavailable, done in-session", while build-auto says to halt with `no subagents` instead. | 5.3 and 5.5–5.12 plans, Implementation Notes; `bmad-build-auto` workflow §Subagents | a lane that cannot spawn a reviewer blocks or queues an outside review |
| L3 | **5.1 had no review** (`lenses_ran: []`), and a worktree agent marked it `done`, which had to be reverted. | 5.1 plan; 3e17d81 | before merging a lane, check `lenses_ran` and `status` |
| L4 | **No review of the whole epic's diff ran before the sweep.** This repeats the gap the epic 2–4 retrospectives found. This retrospective's review is the first time the seams were seen together, and F1, F3 and F5 come from those seams. | memory `orchestration-process.md`; 5.12 plan | make the whole-epic review a step of the sweep ticket itself |
| L5 | **Merge resolutions designed behaviour that was never reviewed:** the `data-live-refresh-hold` mechanism and an 87-line system test (ce64050), the deleted-partner guards (1a7fa69), and `trade_steps.rb` (4d72912). | remerge-diffs; 5.6 and 5.8 plans, "Merge of develop" | merge develop into the lane before the review step, or re-review non-trivial resolutions |
| L6 | **The 5.9 follow-up review was replaced by a passing test run,** and a fix in the flagged area (`live_refresh_controller.ts`) landed six minutes after the merge, with no plan and no test (0bb5424). | 5.9 plan `followup_review_recommended: true`; 5.12 plan | a recommended follow-up is a real review; post-merge fixes go through a plan |
| L7 | **Loose `after` dependencies let overlapping lanes run in parallel.** Examples: 5.9 and 5.11 alongside 5.6–5.8 on the same controller and views; 5.10 needing 5.8's button. The sweep then removed four copies of the friendship lookup and up to ten of the standing rule, and D1 shows it did not finish. | `tickets.toml` `after`; 5.12 plan Problem | encode UI dependencies in `after`; serialize stories that touch the same surfaces |
| L8 | **The rule against planning ids and comments arrived mid-epic** (AGENTS.md, 6d5d550, after 5.1–5.6 and 5.10 were built). The sweep spent about 148 id lines and 781 comment lines on it (2d46c6a, +361/−1074) and still missed some (P1). | 6d5d550; 7108f7f; 2d46c6a | settle conventions before an epic; a new rule applies at once, not in the sweep |
| L9 | **The sweep broke its own frozen boundary** (R8) without a Change Log entry. | 5.12 plan | a boundary breach forces a Change Log entry or a pending approval |
| L10 | **The full system suite never ran during the epic.** CI stopped running system tests on develop mid-epic (68ebe9a). 5.1 and 5.2 added screens with no system test. A sibling story broke the hub test, and its own verification did not catch it (9456caa). | 68ebe9a; 5.1 and 5.2 plans; 9456caa | an end-of-epic `bin/rails test:system`; a story that changes a screen needs a system test |
| L11 | **Parallel lanes collided again on migrations and the schema dump.** | ea48b54, c3b939d; 5.3, 5.6 and 5.9 plans | per-lane migration timestamp ranges; a scripted PG18 regeneration step at merge |
| L12 | **Rewriting the remote history orphaned two plan baselines** (`fa1676d`, `47cea18`) and left the local checkout without a common ancestor. | transcript `148cde2c` around line 155 | never rewrite pushed history, or re-stamp `baseline_revision` when it happens |
| L13 | **Ten of twelve plans carry `warnings: ['oversized']`.** 5.6 (+2074), 5.8 (+1567) and 5.9 (+1159) are the largest, and one cloud session built about 19 stories across five epics that day. | plan frontmatter; commit trailers | split stories like these; bound one orchestrating session's load |
| L14 | **No ticket was marked `hitl`,** although 5.7 and 5.8 were checked visually by throwaway screenshots, and 5.9's review found that live updates never reached a browser in development (`cable.yml` used `async`). | `tickets.toml`; 5.7, 5.8 and 5.9 plans | flag realtime, animation and phone stories for an author check |
| L15 | **The orchestration rules lived in local auto-memory, which the cloud build session did not have.** The memory also said "commit on main". That note was replaced by "work on develop" during this retrospective, but the rules are still outside the repo. | `~/.claude/projects/…/memory/`; `MEMORY.md` | move review depth, follow-ups, the epic review and lane rules into the repo (AGENTS.md or the build-auto customize file) |
| L16 | **Players asked for picker filters right after the epic, and neither the spec nor any review had raised them.** The plan was filed at the initiative root, outside the epic tree. | transcript `2acbfdff` line 49; `_bmad-output/backlog/story-trade-picker-filters-plan.md` (`ticket: ''`) | the picker spec states how a large collection is narrowed; file follow-ups under their epic |

## Behavior verification

Run on 2026-10-09 against HEAD `58ab6e4`, on Postgres 18.6. Scripts, logs and screenshots were kept in the session scratchpad and are not in the repo.

**Tests (all green):**

| Suite | Result |
|---|---|
| Ruby tests of the epic (24 files: friends, invitations, trades, presence, player stream, deletion and ban, policies) | 208 runs, 0 failures |
| `test/system/trades_test.rb` and `friends_test.rb` | 14 runs, 0 failures |
| `test/system/live_updates_test.rb` | 5 runs, 0 failures |
| `npm run test:js` | 168 tests |
| `bin/rails zeitwerk:check` | clean |

The full `bin/rails test:system` suite was not run here. The last full run on record is 131 runs, 0 failures, in the session that built the picker filters.

**The running system:** a development server driven over HTTP with real session cookies and CSRF tokens, posting the trade board's own fields. A headless Chromium checked that the island mounts. `bin/rails runner` was used for time travel and bans. The dev DB was migrated (24 pending epic migrations) without rewriting `db/schema.rb`. Five players each opened 10 packs from the published season.

| Flow | Observed |
|---|---|
| Friend code, invitation by code (lowercase input), acceptance | pass: both sides see the friendship |
| Proposal with an offer and a request, with quantities | pass: the offered copies are reserved |
| Offering more than owned minus reserved elsewhere | pass: refused with the "not enough free copies" message; exactly the free count is accepted |
| Counter that changes both sides | pass: the old offer is released, the new one reserved, the turn flips and the 7 days restart |
| Acceptance | pass: every card swapped, reservations released, totals preserved |
| Expiry (time travel past `expires_at`) | pass: `ExpireTradesJob` closes the trade as expired; nothing moved; the offer is released; one `TradeExpired` is recorded |
| Decline | pass: nothing moved; the offer is released; a second decline gets "already closed" |
| Non-friends, and yourself | pass: 404 on the board, `:not_friends` on POST |
| A second open trade for the same pair | pass: redirected to the open trade, `:trade_already_open` in both directions |
| Account deletion through `DELETE /en/account` | pass: trades cancelled, offer released, friendship and invitations gone; the partner sees "Nameless officer … cancelled" |
| Ban through a hand-published `PlayerBanned` | pass: ties dropped at once |
| Ban by setting `banned_at` from the console | as F2 says: the trade disappears for the partner (404); friendship, trade and reservation stay until `bin/rails game:drop_friends_and_trades` runs |
| Live notices | 22 `PlayerStreamJob` and 13 `NoteLastSeenJob` ran with 0 failures |

**Surprises:**
- **Players created before the friend code migration have no code until `bin/rails game:backfill_friend_codes` runs,** while the empty state still says "Invite one with your link or your code". That task is not queued in `pending-approvals.md`, unlike `game:drop_friends_and_trades`. It is action item 6.
- The picker always shows the friend's cards with 0 reserved (F11, by design).

## Previous-retro follow-through

There was nothing to follow through on: `epic-public-launch-readiness`, the epic before this one in build order, has no retrospective file. That epic is still unfinished (5 of 12 stories built).

## Action items

All of these are proposed and none has been applied. Code fixes go through the normal build loop; spec and doc changes wait for the author.

**Fix now** (one bug ticket under this epic, built with a `thorough` review):

1. **Accept and decline check the terms the player saw** (F1): send the trade's revision with the POST, refuse `:trade_changed` under the lock, and add a test that accepts after a counter from another tab. Owner: dev loop.
2. **An expired but unswept trade no longer blocks a new proposal, and `ExpireTradesJob` reports failures** (F3). Owner: dev loop.
3. **Crossing invitations:** accepting when the friendship already exists closes the reverse invitation and publishes nothing; add a concurrency test (F5), plus a test that a banned sender's invitation cannot be accepted (F15). Owner: dev loop.
4. **French `zero` form for `trades.side.cards`** (P2). Owner: dev loop.
5. **Remove the planning ids from this epic's own lines** (P1): `sessions_controller.rb:31,107`, `player_registered.rb:5`, `player_state.rb:11`, `release_player.rb`, `accounts_controller.rb` ("story 7.8"), and the three tests named "(story 5.10)". Owner: dev loop.

**Operations:**

6. **Queue `bin/rails game:backfill_friend_codes` in `pending-approvals.md`** for staging now and for the first production deploy. Owner: author.

**Routed to other epics:**

7. **Epic 7, moderation story (7.5):** its ban operation publishes `Accounts::PlayerBanned`, takes the bank locks in the order `DeletePlayer` uses, and lets a partner see and cancel a trade with a banned player (F2, F7, F12). Until it ships, either schedule `DropFriendsAndTradesJob` or keep running the rake task after each console ban, as `pending-approvals.md` line 17 says. Owner: author, when refining 7.5.
8. **Epic 12 (readable codebase):** the deferred structure findings are A1, A2, A4–A6, D1–D4, S1, S2, P3, P4, F6, F10 and F12. Pack privacy (A1) and the six forms of the standing rule (D1) matter most. Owner: author, when slicing epic 12.

**Spec and doc reconciliation:**

9. Amend AD-16 to the as-built badge (a server Turbo Stream, no `trade-badge` island event) (R5). Owner: author.
10. Add the picker's title and rarity filters to EXPERIENCE's card picker rules (R6). Owner: author.
11. Remove or update the two stale `pending-approvals.md` entries (R9). Owner: author.
12. Move `_bmad-output/backlog/story-trade-picker-filters-plan.md` under this epic as a ticket, or record why it stays at the root (L16). Owner: author.

**Process (for the build loop, before epic 7 continues):**

13. **Review depth follows `risk`:** `thorough` for `high`, never pinned to `quick` (L1). Owner: orchestrator.
14. **No self-review:** a lane without subagents blocks or queues an outside review (L2, L3). Owner: orchestrator.
15. **The sweep ticket opens with a review of the whole epic's diff,** and a recommended follow-up review is a real review (L4, L6). This is the third retrospective to ask for it. Owner: orchestrator.
16. **Merge develop into a lane before its review step** (L5). Owner: orchestrator.
17. **End each epic with a full `bin/rails test:system` run,** and require a system test for a story that changes a screen (L10). Owner: orchestrator.
18. **Tighter `after` dependencies** for stories that share a controller, views or locales; per-lane migration timestamp ranges (L7, L11). Owner: author and `bmad-ticket`.
19. **Move the orchestration rules from local memory into the repo** (AGENTS.md or the `bmad-build-auto` customize file), so a cloud session follows them (L15). Owner: author.
20. **Mark realtime, animation and phone stories `hitl`** (L14). Owner: `bmad-ticket`.

**Decided by the author after the discussion:**

21. **Run `bmad-correct-course` for the privacy rule the author settled in the team discussion** (F4, F13; see Team discussion). It changes CAP-10, CAP-11 and CAP-21, the visibility setting of epic 7 (story 7.2, built), and the remaining social stories of epic 6. Owner: author.
22. **Ignored invitations stay pending for the sender:** `InvitationsOf` keeps showing the sender's ignored invitation as sent and pending, and `SendInvitation` refuses a re-send as `already_sent`. Test both. Add this to the bug ticket of items 1–5. Owner: dev loop.
23. **A story for the friend row's PROPOSER UN ÉCHANGE button,** showing the "trades closed" message when a profile is private. Slice it after the privacy course correction (item 21). Owner: `bmad-ticket`.
24. **Builds that need an independent review run locally, not in claude.ai/code,** which has no subagents. The thorough reviews the three high-risk stories (5.4, 5.5, 5.7) never got can run locally on their code at HEAD; this retrospective's `bmad-review` covered only the seams between stories. Owner: author.

## Acceptance verdict

**accepted-with-open-items** (machine verdict; criteria declared). No human decision has been recorded yet.

- **Every ticket is finished:** 12 of 12 at `built`, none unfinished.
- **Done when 1–6 are met in code and tests, and were observed in the running system.** Done when 6 (presence) has no system test.
- **No blocking finding.** Five should-fix findings stay open: F1, F3 and F5 become a bug ticket (action items 1–3); F2 goes to epic 7; F4 was settled by the author as a spec change (action item 21).
- **The "no card ever promised twice" outcome holds** under the locks, the database constraint and the concurrency tests, and was seen working at runtime.
- **One part of R6 is unproven:** that banning cancels trades and drops friendships. The handler works when the event is published, but nothing in the app publishes it yet, so that part waits for epic 7 (F2).

## Team discussion

`bmad-party-mode` ran on 2026-10-09 with the installed agents (Mary, John, Sally, Winston, Amelia), seeded with the findings above. It ran in session mode: one model voiced every agent, so the disagreement was not independent. The room argued F1, the process lessons L1, L2 and L15, and F4.

**The author's decision on profile privacy (2026-10-09):**

- **A private player can still add friends and have friends.** Invitations by code and by link stay open both ways.
- **Their friends see nothing beyond the friendship:** no presence or activity, no collection, no profile, no trade. This settles F4 (the picker) and F13 (presence).
- **Nobody can trade with a private player,** and a private player cannot propose a trade.
- **Going private cancels the player's open trades at once** and releases the reserved copies.
- **A private player still sees their public friends' presence and collection.** Where the trade action would be, the screen explains that trades are closed while the profile is private.

The room raised two points for the change:
- **The rule belongs in one gate.** `Game::Visibility` should be asked by every social operation, including `TradeSteps#friends`, not by six variants (D1).
- **Cancelling trades on going private reuses the drop path,** so F12's out-of-order lock must be fixed before a third caller uses it.

John routed the change to `bmad-correct-course` (action item 21), since it amends shipped capabilities across epics 5, 6 and 7.

## Open questions

The author answered every open question on 2026-10-09.

**Rules decided in autonomous runs:**

| Rule | Decision |
|---|---|
| Sending an invitation to someone who already invited you accepts their invitation (R2) | **kept** |
| An ignored invitation (R3, F8) | **changed:** the sender keeps seeing it as pending, so they never learn they were ignored, and a re-send is refused as `already_sent`. If the ignoring player later invites the sender, a new invitation is created as usual. The author confirmed this. |
| The same card on both sides of a trade (R4) | **kept** |
| 999 copies per trade line (R4) | **kept** |
| An unban does not restore friendships or trades (R4) | **kept:** the player starts from zero |
| Deletion and ban close trades as `cancelled` (R4) | **kept** |
| A trade with a banned partner leaves the list (R4, F2) | **changed:** it shows as CLOS and the copies are released (action item 7) |

**The friend row's PROPOSER UN ÉCHANGE button (R1):** add it, as EXPERIENCE asks. Simple actions win. With a private profile on either side, the row shows the "trades closed" message instead (action item 23).

**Why the lanes did not use subagents (L2):** this was a limit of the claude.ai/code cloud environment, which offered no subagents. A build that needs an independent review runs locally (action item 24).
