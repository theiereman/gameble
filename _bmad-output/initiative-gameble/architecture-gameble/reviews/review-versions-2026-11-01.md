# Review: reality check of the 2026-11-01 amendment (AD-8 and AD-38)

Independent reviewer, 2026-11-01. Lens: was every claim in the changed text checked against reality, or just asserted? Scope: `git diff HEAD -- architecture-gameble.md` (frontmatter `updated`, one AD-8 bullet, two AD-38 bullets). The spine was not edited.

Read: `app/helpers/trades_helper.rb`, `app/controllers/trades_controller.rb`, `app/frontend/lib/trade_board_draft.ts`, `app/frontend/lib/trade_board.ts` (`start`), `app/frontend/controllers/trade_board_controller.ts`, `app/views/trades/_draft_board.html.erb`, `app/domains/game/app/operations/game/{propose_trade,counter_trade,accept_trade,trade_steps}.rb`, `app/domains/game/app/queries/game/{open_trades_by_friend,trade_locks}.rb`, `app/domains/game/app/models/game/trade_item.rb`, `app/domains/catalog/app/queries/catalog/{card_views,published_card_season_ids}.rb`, `db/schema.rb` (`game_trades`), `Gemfile.lock` (strong_migrations 2.8.0 and its installed source), `config/locales/en.yml`, and the trade tests that assert the old rule.

The changed text names no new technology or library. The only storage it names is the browser's, and the code already uses it (`localStorage`). So nothing needed checking on the web.

**Verdict: pass with one fix.** Every claim the amendment makes about existing code holds. The draft key, the reservation bound and the acceptance check are as stated. The fix: AD-8 now permits several open trades per pair, but the code and the database enforce one, and the amendment records nothing about undoing that. AD-38's new rules describe code that does not exist yet (`Game::TradeSuggestions`, `Game::GoalNeeds`, `game_goals`). Those are design commitments, so nothing in the code can confirm or contradict them; their references to existing code do hold.

---

## Findings

### F1: "any number of open trades" reverses a rule the code and the database enforce, and the cost is not recorded (medium)

The new AD-8 bullet works as a prescription, but the spine gives no Costs or Supersedes line for it. Today the old rule lives in six places:

| Where | What enforces one open trade per pair |
| --- | --- |
| `db/schema.rb:570` | partial unique index `index_game_trades_one_open_per_pair` on `(low_player_id, high_player_id) WHERE status = 'open'` |
| `Game::ProposeTrade` | `no_open_trade` step, and `rescue ActiveRecord::RecordNotUnique` → `Failure(:trade_already_open)` |
| `Game::ProposeTrade#expire_due_trade` | `.pick`s one due trade of the pair before proposing; it exists only to free the index slot |
| `TradesController#new` | redirects to the open trade with the `trades.one_at_a_time` notice |
| `Game::OpenTradesByFriend` | returns friend id → **one** token, read by `FriendsController`, `FriendProfilesController`, `PublicProfilesController` |
| locales and tests | `errors.game.trade_already_open`, `trades.one_at_a_time` (en and fr); `test/domains/game/trade_test.rb:99-100`, `trade_concurrency_test.rb:170`, `trade_accept_counter_expire_test.rb:438` |

Fix: add a Costs line to AD-8. Removing the partial index needs its own migration. strong_migrations 2.8.0 leaves `remove_index` out of its enabled checks, so it will not complain, but `algorithm: :concurrently` is still the safe form. `OpenTradesByFriend` changes shape (a friend may have several tokens, or the profile and friends pages need a rule for which one they link). `ProposeTrade` loses `no_open_trade`, the rescue and `expire_due_trade`. The two locale keys and three tests go. Without that line, a builder reading AD-8 alone would meet a database refusal they were not warned about.

### F2: "reservations and the acceptance check keep a card from being promised twice across them" (verified)

- Propose and counter: `enough_copies` (`trade_steps.rb`) checks each offered line against `quantity - reserved` on rows locked `FOR UPDATE` (`TradeLocks.holdings`), then `reserve` adds to `reserved`. This matches "up to `quantity - reserved`".
- Accept: `AcceptTrade` checks the request against the recipient's `quantity - reserved` (`:requested_cards_unavailable`). The recipient's own outgoing offers in other trades are therefore excluded.
- Requests are not reserved. Two trades in one pair may ask for the same copy, and the second acceptance is refused. This is the behaviour the sentence promises.
- Locks are per player (`BankLock`, ascending id), not per trade. Several trades in one pair take the same locks in the same order, so no new deadlock path appears.

### F3: "The browser keeps one unsent draft per friend, keyed by the two player tokens" (verified)

`TradesHelper#trade_draft_key` is `"#{player.token}:#{friend.token}"`. `_draft_board.html.erb` passes it as `trade_board_draft_key_value`. `trade_board_draft.ts` stores the draft in `localStorage` under `gameble:trade-draft:<key>`, and `TradesController#create` forgets it after a successful send. Two nuances are accurate to "the browser keeps":
- The draft is per browser, not per account across devices.
- It is best effort: when storage is refused, the board still works, unsaved.

Counter drafts are a separate key (`trade_counter_key`: player token, trade token, expiry), so several open trades per pair do not collide.

### F4: AD-38 "replaces the stored draft for that friend" needs an explicit write, because today the draft wins (low)

The statement is correct as a requirement. Note for the builder: `start()` in `app/frontend/lib/trade_board.ts:207` takes the stored draft over the server-provided lines whenever a draft exists. A suggestion prefill passed as the board's initial lines would therefore be hidden by an older draft. To replace the draft, the board has to save or forget it before `start` reads it, for example from a prefill flag. No spine change is needed; a ticket should carry this note.

### F5: AD-38 references to existing code (verified)

- "at most AD-8's 4 card-seasons per side": `Game::TradeItem::MAX_CARDS_PER_SIDE = 4`.
- "by slug and season, AD-15": `CardView#id` is the slug (`card_views.rb:21`), the board keys are `"<slug>--s<n>"` (`trade_card_key`), and `Catalog::PublishedCardSeasonIds` resolves `(slug, season)` pairs.
- "sent through `Game::ProposeTrade`": this is the only trade-creating operation.
- "lowest-numbered goal": AD-35 gives goals a `position` from 1 to 5. Not built: `game_goals` is absent from `db/schema.rb`.
- "rarest minted rarity": the naming table has rarity integers from 1 (common) to 5 (legendary), so rarest is the highest integer.

### F6: wording (low, optional)

- "lowest-numbered goal": AD-35's term is `position`, and AD-35 says a goal is "never addressed by position". "the goal at the lowest position" would tie the text to the column without contradicting that.
- "also holds every spare of the player … up to 4": "every" and "up to 4" pull against each other. "holds up to 4 of the player's spares that …" says the same thing.
- "the friend bringing the most cards": this counts card-seasons, which are capped at 4, so ties will be common and the name tiebreak will often decide. That is fine, but "card-seasons" would say which is meant.
