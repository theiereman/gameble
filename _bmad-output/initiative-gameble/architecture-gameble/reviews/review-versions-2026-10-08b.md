# Review — reality check of the 2026-10-08 amendments (recognizable sets)

Independent reviewer, 2026-10-08. Lens: is every committed decision checked against reality rather than asserted from memory? The 2026-10-08 update names no new technology, so this review checks it against the code and data already in the repo, and checks Steam's API shape against the published protobuf definitions. Scope: AD-5, AD-9, AD-10, AD-25, the data model and the last nine `.memlog.md` entries (commit `5c2c0c3`). The spine was not edited.

**Verdict: pass with fixes.** Four things hold against reality: Steam's GetItems shape, the ON CONFLICT pattern, the RES event and handler pattern, and the numbering precedent. Three gaps should be fixed before epic-recognizable-sets is sliced into stories. Nothing in Catalog carries the review count the hall of fame needs. AD-4 still describes the retired genre and best-of-year design. The rebuild-once handler, as worded, breaks AD-10's handler rule and the code's own freeze guards.

Method: I read `packs/steam/app/models/steam/details_policy.rb`, `card_mapping.rb`, `genre_tags.rb`, `import_details_page.rb`, `test/support/steam_api_stubs.rb`, `packs/game/app/models/game/set_completion.rb`, `packs/game/app/operations/game/operation.rb`, `open_pack.rb`, `accept_trade.rb`, `config/initializers/event_store.rb`, `packs/game/app/handlers/game/handlers/*`, `packs/catalog/app/operations/catalog/publish_season.rb`, `packs/catalog/lib/tasks/catalog.rake`, the Catalog `Set`, `SetMembership` and `CardSeason` models, `db/schema.rb` and `Gemfile.lock`. I downloaded `SteamDatabase/Protobufs` `webui/common.proto` (master, 2026-10-08). A live GetItems call was refused by the sandbox proxy (403), so Steam's shape comes from the protobuf only.

---

## What holds

### OK1 — Steam's GetItems returns developers and franchises, and they are already stored raw

- **Steam shape:** In `webui/common.proto`, `StoreItem_BasicInfo` has `short_description = 1`, `repeated StoreItem_BasicInfo_CreatorHomeLink publishers = 2`, `developers = 3`, `franchises = 4` and `capsule_headline = 5`. `CreatorHomeLink` is `{ optional string name = 1; optional uint32 creator_clan_account_id = 2; }`. `StoreBrowseItemDataRequest.include_basic_info = 10` returns that block. Source: https://raw.githubusercontent.com/SteamDatabase/Protobufs/master/webui/common.proto (lines 7195-7216, 7335-7347).
- **The code:** `Steam::ImportDetailsPage::DATA_REQUEST` asks for `include_basic_info: true` (`import_details_page.rb:32`). `DetailsPolicy.verdict` stores the whole English item in `steam_apps.details` (`RawValue.scrub(english.merge("french" => …))`), so `basic_info.developers` and `basic_info.franchises` are kept raw whenever Steam sends them. The claim in the change proposal, "read from the raw item already stored, without a new import", is technically sound.
- **Caveats the spike must check (not settled by the protobuf):**
  - Both fields are `repeated`, so a game can have several developers and several franchises. The spine does not say whether a card joins every such set or only the first. Today's publisher sets keep only `Array(app.publishers).first` (`card_mapping.rb`).
  - `name` is optional. A link with no name, or an empty `franchises` list, is likely for many games, and the protobuf cannot say how often.
  - `details` is NULL for apps whose details step said `unavailable`. Those apps are not cards, so this is harmless.
  - The test stub (`test/support/steam_api_stubs.rb:109`) has `developers` but no `franchises`, so no test exercises a franchise today.

### OK2 — ON CONFLICT DO NOTHING on a unique (player, set, tier) row matches how completions work today

- `Game::SetCompletion::RECORD_SQL` already inserts one row per completed set with `ON CONFLICT (player_id, set_id) DO NOTHING RETURNING set_id`, backed by the unique index `index_game_set_completions_on_player_id_and_set_id` (`db/schema.rb:290`). `Game::Operation#publish_completions` publishes one `Game::SetCompleted` per returned id, after the operation's own event. It is called from `OpenPack` and `AcceptTrade`.
- Widening the key to (player, set, tier) and computing each tier's threshold in the same statement is a direct extension. A tier "stays reached when cards leave" for the same reason a completion does today: rows are never deleted except by `ReleasePlayer`.
- Today the SQL counts any held copy, including reserved ones (`quantity > 0`). The tier SQL should do the same, and the spine could say so in one clause.

### OK3 — RES events and handlers fit the code

- The repo runs `rails_event_store 3.2.0` (`Gemfile.lock:406`) with a `JSONClient`. Handlers are subscribed synchronously in `config/initializers/event_store.rb`, and the comment there says they run inside the publishing transaction. `Game::SetCompleted` exists (`packs/game/app/events/game/set_completed.rb`) and is published by the operation, never by a handler. `Game::SetTierReached` follows the same pattern.
- A Game handler on a Catalog event already exists: `Game::Handlers::SeasonPublished` on `Catalog::SeasonPublished`. So "a Catalog operation publishes, Game answers" has a precedent. Note that nothing subscribes to `Game::SetCompleted` today. The new feed and back-unlock handlers are its first subscribers.

### OK4 — The precedent of numbers given once to an older season is real

- `Catalog::PublishSeason#number_published` numbers a published season once, under `FOR UPDATE`, and fails with `:already_numbered` on a second run. The task `catalog:number_seasons` (`packs/catalog/lib/tasks/catalog.rake`) runs it. AD-5's sentence matches the code.

---

## Findings

### F1 (high) — The hall of fame needs a review count that Catalog does not have

- **Evidence:** The spec defines the hall of fame by score and review count: very high score with very many reviews, very high score with few reviews, mixed score with very many reviews, and the most reviewed (`catalog-and-rarity.md:65`). Catalog keeps only `catalog_card_seasons.prestige_score` (documented as "opaque here and only ordered") and `rating` (percent) (`db/schema.rb:50-65`; `card_season.rb`). `Steam::CardMapping` passes no review count to `Catalog::UpsertDraftCard`. `review_count` lives only in `steam_apps` (`db/schema.rb:357`). Recovering it by inverting the prestige formula would break AD-4's opacity.
- The spine's own Deferred entry says the hall of fame thresholds are set by the spike, but it never says where the count lives.
- **Fix (amend AD-5):** add "A card-season keeps the source's review count beside its rating, frozen at publication like them; the hall of fame sets read rating and review count only." Add a `review_count` column to `catalog_card_seasons`, expand/contract: nullable, then backfilled from `steam_apps`, then validated NOT NULL. Change AD-4's second bullet to "`Steam` computes the prestige score from the review score and review count, and passes both on to `Catalog` as source-neutral figures."

### F2 (high) — AD-4 still describes the retired design and now contradicts the Layer table

- **Evidence:** AD-4 still says that `Steam` computes "a source-neutral rating for 'best rated of the year'" (a retired kind). It also says that `Steam` computes genres from "the curated list in `Steam::GenreTags`". The 2026-10-08 Layer table and memlog put "the theme list" in `Catalog` and derive the genre from the main theme. The code today matches the old AD-4: `Steam::GenreTags` holds tagids and `CardMapping` sends `genres:`.
- The memlog calls the theme list "Steam tag keys … in Catalog". Under AD-4, Catalog may not reference a Steam-specific field. The fit only holds because `catalog_cards.tags` already stores source-neutral keys: parameterized English tag names in vote order (`CardMapping.tag_keys`). The theme list must therefore be keyed by those keys, never by tagids. A Steam rename of a tag changes its key, so the spike should check that the theme keys survive a re-import.
- **Fix (amend AD-4):** replace the third bullet with "`Steam` passes each game's tag keys, most-voted first; `Catalog` decides themes and the genre from its theme list, keyed by tag key, never by a source id." Drop "best rated of the year" from the second bullet. Retire `Steam::GenreTags` in the rebuild story.

### F3 (medium) — The rebuild handler, as worded, breaks AD-10 and the freeze guards, and the precedent covers less than it seems

- **Handler:** AD-5 says that "a `Game` handler answers by dropping that season's set tiers". Handlers run synchronously in the Catalog operation's transaction, and AD-10 lets a handler write "only rows of that player or new rows". Dropping every player's rows for a season is the cross-player write that AD-9 and AD-10 forbid.
- **Precedent:** The only Catalog-to-Game handler in the code, `Game::Handlers::SeasonPublished`, only enqueues `HealBanksJob`, which works one player per transaction.
- **Freeze guards:** `number_published` fills NULL columns and publishes no event. A rebuild deletes and replaces published `catalog_sets` and `catalog_set_memberships`, which `Catalog::Set` and `SetMembership` refuse once the season is published (`frozen_once_published`, `refuse_destroy_once_published`). The `catalog_sets_kind_check` constraint (`db/schema.rb:123`) also admits only `publisher`, `tome` and `best_of_year`.
- **Fix (amend AD-5):** add these three rules.
  - "The handler enqueues a `Game` job, after commit, that drops the season's set-tier rows one player per transaction."
  - "The rebuild is the one sanctioned writer of a published season's sets, through bulk writes, and is refused once it has run (`:already_rebuilt`)."
  - "The kind check is widened first (expand), and the retired kinds are removed after the rebuild (contract)."
- `game_set_completions.set_id` has no foreign key to `catalog_sets`, so the old rows do not block the rebuild. They are orphans until the job runs.

### F4 (low) — Card identity omits developers and franchises, and "complete" versus gold is ambiguous

- AD-5 lists a card's identity as "texts, publisher, release date, store and image URL". Studio and franchise sets need developers and franchises on the card, and `catalog_cards` has only a single `publisher` string. **Fix:** "texts, publisher, developers, franchises (lists, as the source names them), release date, store and image URL".
- AD-10 publishes `SetTierReached` per tier and `SetCompleted` per completion, both from set-tier rows. For a theme set, gold is completion, but the spine does not say whether gold writes one row and one event or two. **Fix:** state "for a tiered set, gold is its completion: one row, `SetTierReached(gold)` and `SetCompleted`", or name a `complete` tier value for untiered kinds.

---

Sources: https://raw.githubusercontent.com/SteamDatabase/Protobufs/master/webui/common.proto; repo files cited inline.
