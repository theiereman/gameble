# Adversarial review: the 2026-10-05 update

Spine reviewed: `architecture-gameble.md` (working tree, updated 2026-10-05), with its `.memlog.md`, the spec, `EXPERIENCE.md`, `ux-gameble.md` and the existing code (schema at `2026_10_03_060001`, the `packs/` tree, `PacksController`, `CardsController`, `PublicProfilesController`).

Method: for each AD the update added or changed, I built two units one level down (stories or epics built in separate sessions by different agents). Each unit obeys every AD to the letter, and the two still build incompatibly. Each pair names the hole and gives the rule text that closes it.

**Verdict:** not ready to slice. The new ADs name where things live, but they don't say who writes them, in what order, or in what shape. I found 19 holes: 4 critical, 8 high, 7 medium or low. Most close with one or two sentences added to an existing AD. None needs a new paradigm.

Severity: **critical** means data is lost or corrupted, or the main flow breaks. **High** means two units ship incompatible schemas or behaviour. **Medium/low** means a visible inconsistency or rework.

---

## Critical

### H1. A published card is still rewritten by the next import, and its genre leaves its tome (AD-5, AD-19)

- **Unit A, "Season 2 import" (Steam/Catalog):** follows AD-4 and AD-19, as `Catalog::UpsertDraftCard` already does. The import writes the draft season and updates the card's identity in place: texts, publisher, release date, `genres`, `image_url`. These fields live on `catalog_cards`, which every season shares. The draft gets its own card-season row, so nothing on the published card-season changes, and AD-5's "rarity and number never change" holds.
- **Unit B, "Card face rework" (web/Catalog):** follows AD-5 ("a card's genre is the first of its Catalog genres, the genre of its tome"). It renders `card.genres.first` live.
- **Clash:** a re-import with the new genre mapping (commit `d1a1cdb` added five tome genres and rescored development) changes `genres` on season-1 cards. Season-1 tome sets were built at publication from the old genres and stay frozen. Card faces in season 1 now show a genre different from the tome they sit in. Title and publisher drift the same way. AD-5's "the only field of a published card that may change is its `image_url`" contradicts the code that exists, and two sessions will each "fix" it their own way. There are also two writers of `image_url` (the draft upsert and AD-19's refresh operation), and nothing names both.
- **Rule (replace AD-5 bullets 3 and 4):**
  > Rarity, number, genre and set memberships belong to the card-season and never change after publication. `PublishSeason` writes the card-season's `genre` as the key of the tome it places the card in. Faces, details and filters read the genre from the card-season, never from `catalog_cards.genres`. The card's identity (texts, publisher, release date, store and image URL) belongs to the card, is shared by its seasons, and may be refreshed only by `Catalog::UpsertDraftCard` and by AD-19's image refresh operation.

### H2. Card numbers: who assigns them, when, and with what constraint (AD-5, AD-28)

- **Unit A, "Data expand/contract" (AD-28):** reads "the season number is added and given to the draft season too". It adds `catalog_card_seasons.number NOT NULL` with a unique index on `(season_id, number)`, and backfills both the published season 1 and the draft season 2 by shuffling.
- **Unit B, "PublishSeason numbering" (AD-5):** at publication, it shuffles with `SecureRandom` and updates the numbers row by row.
- **Clash:** Unit B's row-by-row updates hit Unit A's unique index on transient duplicates, so publication fails. Cards that the import upserts into the draft after the backfill violate `NOT NULL`, so the import fails. If Unit B skips cards that already have a number, season 2 keeps the backfill's numbers and newer cards get none. AD-28's "season number" also reads as `catalog_seasons.number`, a column that already exists.
- **Rule (AD-5, replacing the numbering clause; AD-28 reworded to "card number"):**
  > A card-season's `number` is NULL while its season is a draft. It is set once, by `PublishSeason`, in one bulk statement assigning a `SecureRandom` permutation of 1..n over the season's card-seasons; the unique index is `(season_id, number)`. The expand migration numbers already-published seasons once, the same way, and never a draft. A draft card shows `S<n> · #—` in the back-office preview. No other code writes `number`.

### H3. `Game::SetCompleted`: who publishes it, a write skew, and repeats (AD-10, AD-25)

- **Unit A, "Card backs" (AD-25):** adds a handler on `PackOpened`. The handler checks whether a set is now complete and publishes `SetCompleted`. AD-10 says "each operation publishes one event", so the second event can't come from the operation. A handler-published event is the only reading left.
- **Unit B, "Trades" (AD-8):** `AcceptTrade` locks the two players' holdings in AD-6 order and publishes `TradeAccepted`. It has its own completion check, because AD-10 says "an opening or a trade completes a set". It doesn't take the bank lock, because no AD asks it to.
- **Clash:**
  1. **Write skew.** An opening and an acceptance for the same player each bring one of a set's last two missing cards. They lock different holding rows, so under READ COMMITTED neither transaction sees the other's credit. No `SetCompleted` is published, and the card back is never unlocked.
  2. **Repeats.** A player trades a set's card away and gets it back. The set is "completed" again, the unlock is inserted again, and the unique violation from AD-9 aborts the acceptance. A second feed entry, "set complete", also appears.
  3. **Two detectors.** Unit A detects completion in a handler, Unit B in an operation. The two codepaths can disagree on what "complete" means, for example whether a quantity-0 row counts as owned.
- **Rule (AD-10, replacing the SetCompleted bullet):**
  > An operation publishes one primary event. An operation that raises a player's quantities then publishes one `Game::SetCompleted` for each set it brought to complete for the first time for that player. This is decided by inserting a `game_set_completions` row (unique per player and set, `ON CONFLICT DO NOTHING`); the insert is the only test. Before touching holdings, every operation that raises or lowers a player's quantities (`OpenPack`, `AcceptTrade`, grants) takes that player's advisory lock (today's `BankLock`, renamed the player lock). For several players it takes the locks in ascending player id. Handlers never publish events. A set is complete when every card-season it lists has `quantity > 0`.

### H4. A duplicate row in a handler aborts the opening (AD-9, AD-10)

- **Unit A, "First discovery feed":** follows AD-9 ("uniqueness is left to the database"). Its handler does `FirstDiscovery.create!`, and on `RecordNotUnique` it rescues and skips.
- **Unit B, "OpenPack":** runs that handler inside its transaction, as AD-10 requires.
- **Clash:** two players open the same never-found card at the same moment. The second insert fails. PostgreSQL has already aborted the transaction, so the rescue cannot save it, and the second player's opening returns a 500. The same race hits achievements, unlocks, reward rows and set completions.
- **Rule (AD-9, added):**
  > Every unique per-player or per-card row (first discovery, daily-bonus claim aside, reward, unlock, achievement, set completion) is written with `INSERT … ON CONFLICT DO NOTHING`, and its effect follows only when the insert returned a row. No code rescues a unique violation inside a transaction without a savepoint. A handler never fails the operation that published its event over a duplicate.

---

## High

### H5. Only holdings have a lock order (AD-6, AD-8, AD-24)

- **Unit A, "Counter-proposal":** locks the holdings of both players (AD-6), then `SELECT … FOR UPDATE` on the trade row to swap its sides.
- **Unit B, "Accept trade":** locks the trade row first, to check its state and turn, then the holdings.
- **Clash:** a counter-proposal and an acceptance arrive at the same moment on the same trade and deadlock. Adding the activity handler's `UPDATE` on per-player state (AD-24), plus the bank advisory lock that `OpenPack` already takes, gives four lock kinds with no order between them.
- **Rule (AD-6, replacing its last sentence):**
  > Locks in `Game` are taken in this order and never backwards. First, player advisory locks, in ascending player id. Second, the trade or invitation row (`FOR UPDATE`). Third, holdings, in ascending player then card-season. Fourth, per-player state rows (H6), in ascending player id, written last and only by handlers or by operations that touch nothing else.

### H6. Per-player state has no single owner or location (AD-24, AD-25, AD-26)

- **Unit A, "Presence" (AD-24):** reads "a `Game` handler on the player's own row". AD-24's first bullet calls `accounts_players` "the player's own row", and AD-2 allows `Game` to call `Accounts`. Unit A therefore adds `activity_kind` and `activity_at` to `accounts_players` and writes them through an `Accounts` operation called from the `Game` handler. The watermark story reads AD-26 (no location given), follows the memlog's "on the player's own row", and puts `collection_seen_at` there too.
- **Unit B, "Card backs" (AD-25) and the ER diagram:** create `game_player_states` (active back, watermark, activity), with each writer creating the row lazily on first write.
- **Clash:** the watermark and the activity end up in two tables, read by two different queries. Lazy creation races: a handler inside `OpenPack` and `ChooseBack` both INSERT the same row, and one of them aborts. If Unit A wins, `accounts_players` (reloaded on every request for the ban check) is row-locked by every opening, and the opening queues behind the last-seen touch.
- **Rule (AD-24 and AD-26 reworded; AD-25 points to it):**
  > `Accounts`' player row holds identity, role, ban, visibility, preferences and `last_seen_at`, nothing else. Everything per player that `Game` writes (active back, collection-seen watermark, latest activity and its time) lives in one `game_player_states` row per player. That row is created by the `Accounts::PlayerRegistered` handler and by a backfill, never lazily. Each writer `UPDATE`s only its own columns, through a `Game` operation or handler. The kinds of activity are one constant next to the activity handler; an event not listed there changes no activity.

### H7. NOUVEAU depends on what "changed" and "seen" mean (AD-26, AD-11)

- **Unit A, "Collection rework":** "a holding is new when it changed after the watermark" becomes `holdings.updated_at > seen_at`. The page POSTs, and the operation sets `seen_at = now`. The public profile story reuses the same collection view, read-only, with the same Stimulus controller.
- **Unit B, "Trades":** placing or releasing a reservation, and giving copies away, update the holding, which bumps `updated_at`.
- **Clash:**
  1. Proposing a trade puts NOUVEAU on cards the player is giving away, and a card traded down to 0 shows as "new".
  2. Cards gained between the render and the POST (another tab, a trade accepted by a friend, replica lag once AD-11's replica exists) are cleared without ever being shown.
  3. Viewing a friend's or a public profile POSTs and clears the viewer's own NOUVEAU tags.
- **Rule (AD-26, replaced):**
  > A holding has `last_gained_at`, set only when its quantity rises (opening, trade received, grant). It is new when `quantity > 0` and `last_gained_at` is after the player's watermark. The page sends the largest `last_gained_at` among the holdings it rendered. The operation sets `watermark = greatest(watermark, that value)`, capped at now, never the server clock at POST time. Only the viewer's own collection page posts it. NOUVEAU is never rendered on another player's cards.

### H8. Which side of a trade is reserved, and when it expires (AD-8)

- **Unit A, "Propose trade":** reads "placing cards raises `reserved` on their rows" for both sides. It reserves the proposer's offer and the friend's requested copies.
- **Unit B, "Counter-proposal":** follows `EXPERIENCE.md` ("the player's reserved copies become exactly those on the player's side"). It reserves the counter-proposer's new side and releases what they removed. It leaves the original proposer's reservations alone, because AD-8 says only that the counter "replaces both sides".
- **Clash:** reserved counts drift. The friend's copies end up locked by a proposal they never agreed to. After two counters, the original proposer still holds reservations on cards that are no longer on their side, and `quantity >= reserved` eventually refuses a legitimate acceptance. Separately, AD-8's "a periodic job closes expired trades" lets `AcceptTrade` accept an expired proposal before the job runs, because the operation only checks `state = open`.
- **Rule (AD-8, added):**
  > Only the side of the player who sent the current proposal is reserved. Sending, whether a first proposal or a counter, releases every reservation the trade held and reserves the sender's side, in one transaction (lock order H5). Acceptance takes the sender's copies out of their reservation and the acceptor's copies out of `quantity − reserved`, or fails with `insufficient_copies`. A trade stores whose turn it is and `expires_at = sent_at + 7 days`, reset by each send. Every trade operation refuses with `expired` once `now ≥ expires_at`, whether or not the closing job has run. "At most one open trade per pair" is a unique partial index on `(least(a, b), greatest(a, b))` where the trade is open.

### H9. Friendship and invitation shapes (AD-8, AD-15)

- **Unit A, "Friends list and presence":** stores a friendship as two directed rows and queries `where(player_id: me)`.
- **Unit B, "Accept invitation":** creates one row per pair, `(player_id, friend_id)`, and queries both columns. Invitation links follow AD-15 ("invitations by a token"): each link carries an invitation token, so a link pasted on Discord is one invitation row with no recipient.
- **Clash:** each unit's friend query misses half of the other unit's friends. Two players who invite each other create two pending invitations; accepting the second inserts a duplicate friendship or fails. A per-invitation token cannot back a reusable invite link, and the friend code ("HUGO-7K2Q") has no owner or table.
- **Rule (AD-8, first bullet replaced):**
  > A friendship is one row per unordered pair with `player_low_id < player_high_id` (check constraint, unique index). An invitation is one row from sender to recipient, with at most one pending invitation per unordered pair (unique partial index). Inviting a player who already invited you accepts their invitation. Each player has one friend code, stored in `Game` and unique. The invite link carries that code; an invitation's token addresses only its accept and ignore actions.

### H10. Visibility stops at the profile page (AD-14, AD-13)

- **Unit A, "Profile visibility" (AD-14):** the profile policy combines visibility with the friendship query, as written.
- **Unit B, "Feed and repost" (AD-13, CAP-19):** the feed handler writes entries, and the batching job broadcasts them on the public stream. The global feed, ticker and public-page LIVE strip read entries as they are. The trade picker's friend side lists the friend's whole collection.
- **Clash:** a friends-only or private player's pulls, trades and reposts appear in the public feed with their name, are broadcast to signed-out visitors, and stay there after the player hides their profile. The spec's assumption says a repost "disappears with a hidden or banned profile". A private friend's collection is fully shown in the trade picker. The public card page is also caught between the spec (CAP-9: "never who shared or owns it") and `EXPERIENCE.md` (Flow 1: "PARTAGÉE PAR HUGO", and a "profile not available" state for the card page). A share-story agent will put the sharer's token in the URL; a card-page agent will not.
- **Rule (AD-14, added):**
  > Every surface that names a player beside their cards asks one question: `Game::Visibility.visible?(viewer, owner)`, built on `Accounts` visibility and ban plus `Game` friendship. The surfaces are the profile, the friend profile dialog, the trade picker's friend side, and feed entries on every surface and stream. Visibility is checked when a page renders or a broadcast is sent, never stored on the entry. Public surfaces (global feed, ticker, LIVE strip, public streams) show an entry only when every player it names is public and not banned at that moment; otherwise it is left out. The Friends tab shows a friend's entries when that friend is public or friends-only. A private player's collection shows to nobody else, including in the trade picker, where the friend side then offers no cards (product to confirm). The public card page addresses a card-season only, names no sharer, and never depends on visibility.

### H11. The last-seen touch is a write inside a GET (AD-24 vs AD-11)

- **Unit A, "Presence":** puts the touch in `ApplicationController`, through an operation, as AD-24 says ("touched by an operation on the player's requests"). It runs on every request, GETs included.
- **Unit B, "Read path" (AD-11):** wraps every GET in `connected_to(role: :reading)` and enforces "a GET never writes", for example with a test that fails on any write inside a GET.
- **Clash:** the two ADs contradict each other. Once a replica exists, the touch fails on the read-only connection, and until then Unit B's guard test fails.
- **Rule (AD-11, added; AD-24 points to it):**
  > The one write a GET may cause is the last-seen touch. It runs after the response is rendered, on the writing role, outside any request transaction, as one conditional `UPDATE … WHERE last_seen_at < now() − 1 minute` that never waits on a lock.

### H12. Opening replay: ordering, throttling and what is replayed (AD-23)

- **Unit A, "Opening endpoint":** follows AD-23. Rails `rate_limit` runs first, then `OpenPack` looks for a pack to open, then stores the key. A repeated key is looked up in a query before the operation.
- **Unit B, "Booster island":** treats every failure code as final, per `EXPERIENCE.md` step 4 ("nothing opens").
- **Clash:**
  1. A retry after a lost response arrives once the reserve is empty or the limit is hit. It gets `no_pack_available` or `throttled`, and the island says nothing opened when one pack did.
  2. Two requests with the same key both miss the lookup outside the lock. One opens a pack and the other hits the unique index with a 500.
  3. The replay's "active back" and "per-tier counts before the opening" are recomputed against later state, so a back chosen in between shows on an old pack. That breaks "it applies from the next pack opened". The "mon dernier booster" page and the replay can also disagree.
- **Rule (AD-23, added):**
  > `OpenPack` takes the player lock, then looks the key up, before any refusal. A found key returns its pack with `replayed: true`. Rate limiting does not count a request whose key is already stored. `throttled` is retryable: the island retries the same key after `Retry-After`. Only `no_pack_available` and `player_required` are final. The back in use is copied onto the pack at opening (`back_key`), and the replay reads it from there. The replay's per-tier counts before the opening are the current counts minus that pack's cards. The key is a client UUID, unique on `(player_id, idempotency_key)` where it is not null.

---

## Medium and low

### H13. The bank, the reserve and the daily claim are counted differently (AD-7)

- **Unit A, "Hub daily panel":** follows AD-7 ("refused while 10 packs are available"). It enables "RÉCUPÉRER" from `BankSummary[:available] < 10`, which counts packs of every kind.
- **Unit B, "CollectDailyBonus":** counts the ten bank rows, or (as the code does today) doesn't check the cap at all.
- **Clash:** the button and the operation disagree, so the player gets a refusal on a lit button, or a bonus while showing "Réserve pleine". AD-7 also never says whether bonus and reward packs count toward "ten pre-drawn packs". The code says they don't, but a new session reading only AD-7 would make the top-up count them, and a bonus would then swallow the next regular pack.
- **Rule (AD-7, added):**
  > The bank is the player's ten unopened regular packs. Bonus and reward packs sit outside it, never move its schedule, and are never counted by `TopUpBank`. The reserve the player sees is every unopened pack available now, of any kind, so it can exceed 10. The daily claim is refused while the reserve is 10 or more. One query answers it for both the panel and `CollectDailyBonus`.

### H14. The trade badge has two writers, and private-stream messages can arrive out of order (AD-13, AD-16)

- **Unit A, "Private stream":** a job broadcasts a Turbo Stream `replace` of the badge element. The payload is computed from the event ("+1").
- **Unit B, "Trade board island":** after an accept or decline, dispatches `gameble:trade-badge` with a count it decremented locally. The booster island disables the tab bar during an opening by setting `disabled` on its buttons.
- **Clash:** the two writers race, and the badge drifts by one. Two broadcast jobs run out of order (propose, then cancel), and the badge stays at 1. A stream `replace` arriving during an opening swaps the tab bar and re-enables it, breaking "disabled during an opening".
- **Rule (AD-13, added):**
  > Private-stream messages carry absolute values read from the primary when the job sends them, never deltas or event payloads. They update only content nodes (a badge count, a list), never chrome elements whose state an island or controller sets. One Stimulus controller owns each badge and accepts the same absolute count from the stream and from `gameble:trade-badge`; an island takes that count from its operation's response. Navigation lock during an opening is one attribute on `<body>`, set and cleared by the booster island through a DOM event.

### H15. The server-rendered face inside an island (AD-16, AD-27)

- **Unit A, "Card ViewComponent":** the face carries `data-controller="card-art tilt"`, the copy badge and NOUVEAU, and `style="--art-anchor:…"`.
- **Unit B, "Booster island":** inserts the faces from the JSON and applies the shared `tilt` and filter modules itself, as AD-16 says.
- **Clash:** Stimulus connects inside the React subtree, so tilt runs twice and the filter runs twice. A React re-render resets the inserted HTML, and the controllers disconnect and reconnect. The opening JSON carries viewer state ("×3", NOUVEAU) that is wrong at reveal time and differs on replay. Once AD-27's CSP is enforced, inline `style` attributes are blocked (nonces don't cover attributes).
- **Rule (AD-16, added):**
  > The card component renders a face with no viewer state, no `data-controller` and no inline `style` attribute; variable values go in `data-*` attributes and classes. The host attaches behaviour: a Stimulus controller on a wrapper on server pages, the shared `lib` modules inside an island. Copy badge, NOUVEAU and reserved tags are siblings rendered by the page or the island. An island inserts each face's HTML once and never re-renders it.

### H16. Card backs: `standard`, set-based rules, and the back at opening (AD-25)

- **Unit A, "Back picker":** lists unlocks from rows and inserts a `standard` row for every player.
- **Unit B, "Unlock handlers":** treats `standard` as implicit. A rule names its set by key, `tome:roguelite-1`.
- **Clash:** players created after one unit and before the other have no `standard` back. Set keys belong to a season (`catalog_sets` is unique per season), so a rule matches the same key in every season or in the wrong one. A rule written before publication names a set that doesn't exist yet, and nothing catches it.
- **Rule (AD-25, added):**
  > `standard` is never a row: code unlocks it for everyone, and the active back is `NOT NULL DEFAULT 'standard'`. A set rule names its set by season number, kind and key, and a test fails when a rule names a set absent from every published season. `Game::ChooseBack` refuses a locked back. The back in use is copied onto the pack when it opens (H12).

### H17. A handler that must change another player's rows (AD-10)

- **Unit A, "Ban / delete" (Accounts):** publishes `PlayerBanned` and `PlayerDeleted`.
- **Unit B, "Trades":** adds a `Game` handler on those events that closes the player's open trades. Closing a trade releases the friend's reservations, which are rows of another player. AD-10 limits handlers to "rows of that player or new rows", so Unit B's reviewer rejects the handler, or a different session writes it anyway. Multi-player events (`TradeAccepted`) make "that player" ambiguous too.
- **Rule (AD-10, reworded):**
  > A handler writes rows of the players named in its event, and new rows. When an event calls for a change to anyone else's rows (closing a banned or deleted player's trades releases the friend's reservations), the handler enqueues, after commit, a job that runs the owning operation.

### H18. Tiers and card addresses across boundaries (AD-15, AD-16, AD-23, AD-28)

- **Unit A, "Opening JSON":** sends `tier: 5`.
- **Unit B, "Booster island and DOM events":** expects `tier: "legendary"`, and CSS uses `.tier-legendary`.
- **Clash:** the island mis-renders tiers. AD-15 also says "cards by a slug". The code already uses `/cards/:slug/seasons/:number` for share links, but a new feed or repost story following AD-15 links `/cards/:slug`. Once season 2 is published, that link shows season 2's rarity for a season-1 Légendaire.
- **Rule (Conventions and AD-15):**
  > Outside Ruby and the database, a tier is always its code name: JSON, DOM event details, data attributes, CSS classes. A card-season is addressed by slug plus season number. `/cards/:slug` means the card in the published season. Every link built from a holding, a pack, a feed entry, a repost or a share is the season-qualified form.

### H19. Small seams (AD-13, AD-16, AD-24, deferred items)

- **DOM events:** dispatched on `document`, never `window`. `detail` is typed in the one file. Times are ISO-8601 UTC strings. Stimulus listeners are removed on disconnect, or Turbo visits stack duplicates.
- **Presence windows:** the "online" window and the activity's display time should be constants in one place (`Game::Presence`), so the friends page and the menu's "n en ligne" can't count differently.
- **Weekly reward and back for contributors:** the gauge job must grant through one operation per player (`Game::GrantReward`, unique per player and week). Each call publishes its event, which unlocks the week's back through the handler. A single transaction for every contributor would break AD-3's scale assumptions, and an unlock outside a handler would break AD-25.

---

## What held

- AD-6's counted holdings with check constraints, and AD-7's pre-drawn bank under one advisory lock. The code already serialises a player's bank operations, and H3 and H5 only extend that lock's reach.
- AD-17's filter and AD-27's layout rules are self-contained. I found no cross-unit clash in them.
- The code already resolves two seams the spine leaves open: share links address card-seasons (H18), and bonus packs sit outside the bank (H13). Writing both into the spine stops a new session from undoing them.

## Contradictions to carry upstream

- `EXPERIENCE.md` Flow 1, "PARTAGÉE PAR HUGO", and the "profile not available" state on the public card page contradict spec CAP-9 (H10).
- Today's `Game::CollectDailyBonus` has no full-reserve refusal, which CAP-16 and AD-7 require (H13).
- `Catalog::UpsertDraftCard` updates published cards' identity fields, which AD-5 as written forbids (H1).
