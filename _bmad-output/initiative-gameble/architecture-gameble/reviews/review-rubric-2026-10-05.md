# Review — good-spine rubric, update run of 2026-10-05 (independent reviewer)

Spine reviewed: `architecture-gameble.md` (updated 2026-10-05, AD-1 to AD-28), its `.memlog.md`, `spec-gameble.md` (CAP-1 to CAP-21), and a spot-check of the code on `main` (packs/game, packs/catalog, packs/accounts, packs/steam, app/, config/, db/schema.rb, .github/workflows/ci.yml).

**Verdict:** a solid spine with a good paradigm, and the new ADs (AD-23 to AD-28) close most of the UX hand-off. It is **not yet safe to slice from**. Five rules contradict either each other or the brownfield code in places where separately built stories will meet: GETs that write, the reserve/bonus count, the published-card mutation, player-less Game operations, and the "one event per operation" rule. Each fix is a one- or two-sentence amendment. No finding is critical, because the code already holds the line in most of these places, but a session that follows the spine to the letter would break working code or ship divergent behaviour.

## What the spot-check ratified (no change needed)

- AD-2: `packs/*/package.yml` declare exactly the arrows of the diagram; CI runs `packwerk validate && packwerk check`.
- AD-3: `ApplicationOperation` (`lib/application_operation.rb`) wraps dry-operation + transaction + `publish`. No controller, job or handler writes a model directly (the only `.delete` calls in controllers are on `session`).
- AD-6 / AD-7: `Game::OpenPack` takes the advisory `Game::BankLock`, upserts holdings in ascending card-season order, and tops up inline (`Game::TopUpBank`). `Game::DrawPool` is the in-memory pool. Replacement timing matches the rule.
- AD-10: `config/initializers/event_store.rb` subscribes handlers synchronously inside the publishing transaction. `Game::Handlers::PlayerRegistered` fills the bank.
- AD-14: `Game::Operation` raises at class load when `call` lacks `player:`. `ApplicationController` reloads the player, signs out a banned one, and runs `verify_authorized`.
- AD-15: players, packs and import runs are addressed by tokens, cards by slug plus the season number.
- AD-19: the `import` queue has one worker with one thread (`config/queue_import.yml`).
- AD-22: CI runs brakeman, rubocop, packwerk, `i18n-tasks missing`, typecheck, Vitest, schema diff, unit tests and system tests.
- Conventions: failure keys `errors.<pack>.<code>`, the JSON error shape and the event names all match the code.

## Critical

None.

## High

### H1 — AD-11 and AD-24 contradict each other, and AD-11 is neither built nor enforced
- **Location:** AD-11 ("A GET never writes"), AD-24 ("touched by an operation on the player's requests"), AD-26.
- **Problem:** Most of a player's requests are GETs, so AD-24's last-seen touch writes inside the GETs that AD-11 forbids. Once a replica exists, those GETs run under the `reading` role and the touch fails. Neither rule is enforced: `config/database.yml` has no reading role, no code calls `connected_to(role: :reading)`, and nothing stops a GET from writing. The story that builds presence and the story that wires the read path will each pick the reading that suits them.
- **Fix:** Make AD-11 enforceable and give presence an explicit exception. Wrap every GET action in `ActiveRecord::Base.while_preventing_writes` (an `around_action` in `ApplicationController`, tested). Then add to AD-24: "the last-seen touch is the one write a GET may cause. It runs after the response, through `Accounts::TouchLastSeen` enqueued as a job (or under `connected_to(role: :writing)`), at most once a minute per player, keyed by a `Rails.cache` entry." Also say that `connects_to database: { writing: :primary, reading: :primary }` is declared on the base record now, so "at the start that role points to the primary" is true in code.

### H2 — "Reserve", "bank" and "available" are not defined, and the daily-bonus rule contradicts the code
- **Location:** AD-7 (third and sixth bullets), AD-23 ("the reserve count"), Deferred ("Reward packs and the cap of ten"); code in `Game::CollectDailyBonus`, `Game::BankSummary` and `Game::Pack.bank`.
- **Problem:** In the code, "bank" means the 10 unopened *regular* packs, available or scheduled. Bonus and reward packs sit outside the cap, so a player can have 11 or more available. The claim is never refused for a full reserve; the bonus story planned "added to the bank outside the cap of ten". AD-7 now says "the claim is refused while 10 packs are available" but does not say which packs count. Under the code's definition the bank always holds 10 (TopUpBank refills it to 10 scheduled packs), so a literal reading refuses the claim forever. `BankSummary#bonus_collectable` duplicates the claim check for the UI. So the operation, the summary query, the booster island's reserve count (AD-23) and the future reward grant can each count differently. AD-28's rework list does not mention this behaviour change either.
- **Fix:** Add one definition to AD-7 (or Conventions): "The *reserve* is the player's unopened packs of every kind whose availability time has passed. The *bank* is the 10 regular packs on the schedule. `Game::CollectDailyBonus` fails with `:reserve_full` while the reserve is ≥ 10. Bonus and reward packs never move the regular schedule. The UI reads the claimability from one `Game` query that the operation also uses." Then add "the daily bonus refuses a full reserve" to AD-28's rework list.

### H3 — AD-5 says a published card is frozen except `image_url`, but the code updates every card field on each import
- **Location:** AD-5 (third and fourth bullets), AD-19 (third bullet); code in `Catalog::Card` ("updated in place by every import, published seasons included") and `Catalog::UpsertDraftCard`.
- **Problem:** `catalog_cards` is shared across seasons. Each import into the next draft rewrites the title, texts, publisher, genres, `store_url` and `image_url` of cards that are also in the published season. Only the card-season record (scores, rarity, dust) and the sets are frozen. Following the spine, a session would either block those updates (which breaks the import) or build AD-19's "image_url only" refresh while the import silently changes everything else. It also breaks AD-5's last bullet: once a later import reorders a card's genres, "first of its genres" no longer names the tome the card sits in for the published season, because set memberships are frozen.
- **Fix:** Ratify the code. "A card's identity fields (texts, publisher, release date, store and image URLs, genres) follow the source and may change. What a season froze — rarity, number, scores, sets and memberships — never changes." Restate the genre rule as "the genre shown for a card-season is its tome's genre in that season (from its set membership)". Alternatively, freeze `genres` on the card-season at publication. Choose one; do not leave both readings open.

### H4 — AD-14's "every Game operation requires a player", which the code enforces, has no room for system operations the spine itself asks for
- **Location:** AD-14 (third bullet), AD-25 ("one administrator operation that grants a back to a group of players"), AD-8 (expiry job), AD-10 (gauge job), CAP-12 (reward pack to every contributor), AD-19 (weekly image refresh, Catalog — not affected).
- **Problem:** `Game::Operation.method_added` raises if `call` has no `player:` keyword. A group grant, closing expired trades, summing the gauge and distributing weekly rewards have no single acting player. Each session will invent its own escape: subclassing `ApplicationOperation` directly, passing a dummy player, or writing from the job.
- **Fix:** Add to AD-14: "A system task (expiry, gauge, weekly rewards, group grant) is a job that calls one per-player `Game` operation per affected player (`Game::ExpireTrade(player:, trade:)`, `Game::GrantBack(player:, back:)`), each in its own transaction. The only player-less Game operations derive from `Game::SystemOperation` and write only rows that belong to no player (the weekly goal row)."

### H5 — "Each operation publishes one event" is contradicted by the code and by the new ADs
- **Location:** AD-10 (first and third bullets), AD-24, AD-26; code in `Accounts::SignIn` and `Game::FillBank` / `Game::HealBank`.
- **Problem:** (a) `Accounts::SignIn` publishes nothing on an ordinary sign-in, even though it writes the persona name, and FillBank/HealBank publish nothing on a no-op. (b) `Game::SetCompleted` is a second event from OpenPack or AcceptTrade, and a trade can complete sets for two players. (c) Taken literally, AD-24's touch publishes an event per active player per minute, and AD-26 publishes one per collection visit. That floods `event_store_events` and wakes AD-24's activity handler on non-game actions.
- **Fix:** Reword: "An operation that changes game or account state publishes its event inside its transaction, and only when it changed something. It may also publish derived events such as `Game::SetCompleted`, one per player and set. Housekeeping operations — `Accounts::TouchLastSeen`, the NOUVEAU watermark, the persona-name refresh — publish none."

### H6 — Uniqueness "left to the database" will abort openings when handlers race
- **Location:** AD-9 (uniqueness list) and AD-10 (handlers run in the operation's transaction).
- **Problem:** Two players who pull the same card-season at the same moment both run the first-discovery handler inside their opening transaction. If either handler uses `create!` and rescues `RecordNotUnique`, PostgreSQL has already aborted the transaction (no savepoint), so a pack opening fails because of a feed detail. The same applies to unlock rows, reward rows and daily-bonus rows written by handlers. The code already absorbs conflicts with savepoints in `UpsertDraftCard`, but no rule makes that general.
- **Fix:** Add to AD-9 or AD-10: "Handlers write unique rows with `insert_all` / `upsert_all` and `ON CONFLICT DO NOTHING` (or an explicit savepoint), never `create!` plus `rescue`. A lost race is a no-op, never a failure of the operation."

## Medium

### M1 — AD-7's "No job draws packs" contradicts `Game::HealBanksJob`
- **Location:** AD-7, fourth bullet.
- **Problem:** On `Catalog::SeasonPublished`, `Game::HealBanksJob` (enqueued by `Game::Handlers::SeasonPublished`) walks every player and draws packs through FillBank/HealBank. The spine's absolute wording invites a later sweep to delete the job, or a story to doubt it.
- **Fix:** "No job draws packs during play. The one exception is `Game::HealBanksJob` after a season publication, which calls `FillBank` / `HealBank` per player."

### M2 — The lock order covers holdings only
- **Location:** AD-6, last sentence.
- **Problem:** The code's real order is the advisory bank lock first, then holdings in ascending card-season (`Game::BankLock`'s comment). The spine does not mention the bank lock. It also says nothing about the per-player state row (`GAME_PLAYER_STATE`, written by handlers inside OpenPack and AcceptTrade for two players), or about operations that take two players' bank locks (a reward grant, a trade that might credit packs).
- **Fix:** In AD-6: "Lock order: bank advisory locks in ascending player id, then holdings in ascending (player, card-season), then per-player state rows in ascending player id. A handler writes only after its operation's locks are taken."

### M3 — AD-8 does not say which side of a trade is reserved
- **Location:** AD-8, second to fifth bullets.
- **Problem:** "Placing cards raises `reserved` on their rows" can be read as the sender's offer only, or both sides. CAP-11 caps the friend's side at "what the friend owns", which suggests the request is not reserved. The propose, counter and accept stories will diverge: whether a counter releases and re-reserves, and what acceptance does when a requested card is now reserved elsewhere.
- **Fix:** "Only the cards a proposal offers are reserved, on the sender's rows. A counter-proposal releases the previous sender's reservation and reserves the new sender's offer. Acceptance checks the requested cards against `quantity - reserved` and fails with `:cards_unavailable`. One open trade per pair is a partial unique index on the ordered pair." Add that index to AD-9's list.

### M4 — The private Turbo Stream and `dom_id` would put database ids in HTML
- **Location:** AD-13 (second bullet), AD-15.
- **Problem:** `turbo_stream_from player` signs a GlobalID (`gid://gameble/Accounts::Player/123`). The signature is verifiable but the payload is plain base64, so the player id shows in the HTML. `dom_id(trade)` gives `game_trade_42`. Both break AD-15, and the trade and friends stories will use these defaults.
- **Fix:** In AD-13: "the private stream is named from the player's token (`[:player, player.token]`), never the record". In AD-15: "DOM ids and Turbo Stream targets use tokens or slugs, not `dom_id(record)`."

### M5 — AD-23's error codes do not match the existing refusal path, and statuses are unspecified
- **Location:** AD-23 (third bullet); code in `ApplicationController#refuse_in_locale` and `PacksController`'s `rate_limit`.
- **Problem:** A signed-out or banned visitor is refused by Pundit before `Game::OpenPack` runs, so the JSON code is `sign_in_required` (401), never `player_required`. `forbidden` (403) is also possible. The current `rate_limit` handler redirects instead of answering JSON. No HTTP status is fixed for `no_pack_available` or `throttled`. A replay (repeated key) does not say whether the reserve, times and "per-tier counts before" are the original or current values, and must be looked up under the bank lock to be safe against an in-flight first request.
- **Fix:** List the codes and statuses: `sign_in_required` 401, `forbidden` 403, `no_pack_available` 409, `throttled` 429. Drop `player_required` from the island's list. Then: "a replay returns the same five cards with the current reserve and times; the key is checked under the bank lock".

### M6 — AD-26 does not define "a holding changed"
- **Location:** AD-26.
- **Problem:** A holding's `updated_at` moves when `reserved` rises or falls (trade proposals, declines, expiry) and when copies leave in a trade. Read literally, proposing a card makes it NOUVEAU again, and receiving it in a trade might or might not, depending on which story wrote the update.
- **Fix:** "A holding is new when copies were *added* after the watermark. Holdings carry `acquired_at`, set only when `quantity` increases (pack or trade)." If no column is wanted, say instead that only quantity increases may touch `updated_at` — but that is fragile.

### M7 — Account deletion, bans and export have no cross-pack rule
- **Location:** AD-10 ("Deleting an account anonymises the player record"; handlers "write only rows of that player"), AD-14, capability map rows for CAP-14 and CAP-15.
- **Problem:** Deleting or banning a player with an open trade has to release the *friend's* reservations, but a handler may write only the deleted player's rows. CAP-14 export is a read across `Accounts` and `Game`, and `Accounts` cannot read `Game`; the map's "Game (by event)" cannot produce an export. The spec says reposts vanish with a hidden or banned profile, but nothing says whether the feed filters at read time or a handler deletes them.
- **Fix:** Add to AD-10 or AD-14:
  - On `Accounts::PlayerDeleted` and `Accounts::PlayerBanned`, a `Game` handler closes the player's open trades through `Game::CancelTrade`, which may release the other side's reservations.
  - Feed reads exclude hidden, banned and deleted players at query time.
  - The export is assembled in the web layer (or a job there) from one export query per pack.

### M8 — The friends model has open divergence points
- **Location:** AD-8 (first bullet), ER diagram, CAP-10.
- **Problem:** Nothing fixes whether a friendship is one row per pair (lower id first) or two directed rows. The profile policy, the Friends feed tab, presence and the trade guard will all query it. The *friend code* (CAP-10) is not mentioned anywhere: who owns it, its format, and whether it is the 24-character player token. Nor is whether an invite link carries an invitation token or the inviter's code.
- **Fix:**
  - "A friendship is one row per pair, the lower player id first, with a unique index. `Game::Friends.of(player)` is the only query of it."
  - "The friend code is a short, regenerable code on the `Game` player-state row, distinct from the profile token."
  - "An invite link carries the inviter's friend code; opening it creates the pending invitation."

### M9 — AD-7's p95 justification no longer holds by construction
- **Location:** AD-7, last bullet.
- **Problem:** "Writes at most 5 counted rows" was true before AD-10, AD-24 and AD-25. The opening transaction now also runs synchronous handlers: feed entry, weekly contribution, up to 5 first-discovery inserts, a set-completion check over sets and holdings, back unlocks, achievements, the activity row and the idempotency key. Nothing re-measures it.
- **Fix:** Reword: "Opening stays within 200 ms p95 with its handlers. The set-completion check is one indexed query per opened card. The story 3.9 measurement is re-run as a benchmark when the handlers land, and any later handler on `Game::PackOpened` must keep it."

### M10 — Deployment and environments: AD-21 does not ratify what runs, and environments are unnamed
- **Location:** AD-21, Deferred ("Staging environment…"); code in `config/deploy.yml` and `config/initializers/public_url.rb`.
- **Problem:** The deployment runs two Kamal roles (web, import). Jobs run inside Puma (`SOLID_QUEUE_IN_PUMA: true`), so AD-21's three processes are not what ships. The live target is a LAN host with `ssl: false` and Postgres as a Kamal accessory on the same host; Cloudflare is not in front yet. `PUBLIC_URL` is a boot-time invariant that share links depend on (CAP-9), yet the spine does not mention it. Health checks and graceful shutdown, a spec constraint, are not stated.
- **Fix:**
  - Add an "Environments" line: development, test, the LAN preview (current Kamal target) and public production (Cloudflare, TLS). For each, say what differs.
  - Ratify "jobs may run in Puma until a measured need; the `jobs` role is then a configuration change".
  - Add "public links are built from `PUBLIC_URL`, never the request host; boot fails without it".
  - Add "Kamal's health check on `/up`; processes stop gracefully on SIGTERM".

### M11 — AD-28's rework list is incomplete and one item is ambiguous
- **Location:** AD-28.
- **Problem:**
  - Behaviour changes that will each be met by a different story are missing: the opening exchange moves from POST, redirect and flash (`PacksController#create`) to AD-23's JSON; the bonus refusal (H2); the filter moves from 16 colours to 32 and into a worker (AD-17); the copy changes from the medieval "Brother/officer" to "vous" (AD-18).
  - "The season number is added" is ambiguous: seasons already have a `number` column. The intent is the per-season *card* number.
  - "Given to the draft season too" contradicts AD-5, which numbers cards at publication. Back-filling numbers on the published season 1 is a one-time change after publication, which AD-5 forbids unless it is called out.
- **Fix:** Rename the item to "the card number is added to the card-season record". Add: "season 1 gets its numbers once by a backfill shuffle; later seasons get them at publication". Append the four behaviour changes, or point to `review-feasibility.md`'s Epic 1 rework list as binding.

## Low

- **L1 — AD-16's third island.** The back-office card preview exists to compare two renderers, and AD-28 removes the second renderer. The Deferred list also keeps the back-office as plain Rails pages, and the UX hand-off (item 3) names only two islands. Either drop it (two islands) or state what it previews (back and flip at both sizes). `SampleIsland.tsx` and its system test are leftovers to remove in the shell story.
- **L2 — Presence windows (Deferred).** Two read sites, the friends page and the menu count, could tune different windows. Add "the online window and the activity display time are constants in `Accounts` / `Game`, read by both".
- **L3 — Player-state row wording.** AD-24 and AD-26 say "the player's own row", which could mean `accounts_players`. The ER diagram puts activity, active back and watermark on `GAME_PLAYER_STATE`. Name the table in the rules.
- **L4 — AD-10, last bullet.** Reacting to an event still requires referencing the publisher's event class, so it works only *along* the allowed direction (Game reacts to Accounts or Catalog). Reword: "a pack that may not be called reacts to the events of a pack it depends on".
- **L5 — AD-12.** `config/recurring.yml` runs `SolidQueue::Job.clear_finished_in_batches` as a command. Harmless, but note it as the accepted exception, since configuration may name the backend.
- **L6 — Accessibility floor (Conventions).** No CI check enforces it. Either add an axe check to the system tests (AD-22) or say it is enforced by review only.
- **L7 — Spec housekeeping (outside the spine).** The spec's Open Question "Architecture conflict" and its Constraints note ("It predates the 2026-10-05 redesign") are now stale; close them when the spine is finalised.

## Rubric summary

| Criterion | Result |
| --- | --- |
| Fixes the real divergence points | Mostly. The open ones are the reserve definition (H2), system operations (H4), trade reservation (M3), the friends model (M8) and delete/ban consequences (M7). |
| Every Rule enforceable and preventing its divergence | AD-11 is unenforced and contradicted (H1). AD-10's wording is unenforceable as written (H5). AD-9/AD-10 leave a race trap (H6). The others hold. |
| Deferred cannot let units diverge | Holds, except presence windows (L2). The reward-cap deferral depends on H2. |
| Ratifies the brownfield code | Contradicted in AD-5 (H3), AD-7 (M1, H2), AD-10 (H5), AD-21 (M10) and AD-23 (M5). Elsewhere it matches. |
| Covers CAP-1 to CAP-21 | Every capability is mapped. CAP-10's friend code and CAP-14's export have no architectural home (M8, M7). |
| Every owned dimension decided, deferred or open | Environments, health checks, graceful shutdown and `PUBLIC_URL` are missing (M10). The rest is covered. |
