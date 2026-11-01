# Adversarial review: the 2026-11-01 amendment (AD-8, AD-38)

Spine reviewed: `architecture-gameble.md` (updated 2026-11-01), the working-tree delta against HEAD: AD-8 (any number of open trades between two friends; one unsent browser draft per friend, keyed by the two player tokens) and AD-38 (at most 3 suggestions, one per friend, ordering, card choice, prefill replaces the stored draft whatever trades are open, nothing stored). Read with spec CAP-11 (2026-11-01), the last entries of `.memlog.md`, and `ux-gameble/EXPERIENCE.md` (Échanges: Friend chooser, Suggestions section, Suggestion row, Several trades with one friend, Accessibility Floor "Trade suggestions", Focus after each step, Open questions "Trade suggestions").

Code read: `Game::ProposeTrade`, `AcceptTrade`, `CounterTrade`, `CloseTrade` with `CancelTrade` / `DeclineTrade` / `ExpireTrade`, `CancelOpenTrades`, `RemoveFriend`, `DropFriendsAndTrades`, `TradeSteps`, `TradeLocks`, `Game::Trade`, `ExpireTradesJob`, `TradesOf`, `TradesWaiting`, `OpenTradeCount`, `OpenTradesByFriend`; `TradesController`, `TradesHelper` (`trade_draft_key`, `trade_counter_key`), `app/frontend/lib/trade_board_draft.ts`, `trade_board_controller.ts`; `FriendsController`, `FriendProfilesController`, `PublicProfilesController` and their views (`friends/_friend_row`, `friends/_remove_dialog`, `public_profiles/_action`); `PlayerStream`, `PlayerStreamJob`; `db/schema.rb` (`game_trades`, `game_holdings`, `accounts_players`).

Method: two units one level down, each obeying every AD to the letter, that still build incompatibly; and event sequences that break an invariant once the per-pair limit is gone.

Severity: **critical** an invariant on cards breaks (a card promised twice, reserved above quantity, moved one way); **high** two units ship behaviour that cannot coexist, or a player loses work or sends trades they did not mean; **medium** a visible inconsistency or a rule two builders will settle differently; **low** a wording gap or leftover that a builder would probably settle alike.

**Verdict: the card invariants survive the amendment; the suggestion and draft rules do not yet form a build contract. No critical, two high, five medium, four low.** Lifting the per-pair limit breaks nothing in the reservation arithmetic: every reserve and release is per trade, `game_holdings_quantity_check` (`quantity >= reserved AND reserved >= 0`) backs it in the database, acceptance re-checks the request as free under both bank locks, and every trade operation on a pair serialises on those locks. The holes are where AD-38 meets the trade board and the send: a sent suggestion never leaves the list, so the send is not idempotent, and the draft rules leave open who writes the prefill, when, and what it may overwrite.

---

## What was attacked and holds

- **A card promised twice across two open trades of one pair.** Only the current proposal's offer is reserved, raised up to `quantity - reserved` under the holdings lock (`enough_copies` in `ProposeTrade` and `CounterTrade`); a second trade offering the same copy is refused `insufficient_copies`. Requests are not reserved, and `AcceptTrade` checks the request against `quantity - reserved` of the recipient under the lock, so a copy the recipient offers in trade T2 cannot leave through trade T1.
- **Reservations above quantity.** `AcceptTrade#move` lowers `quantity` by the given count and `reserved` by the released count of that trade only; the check constraint refuses any row where the sum would break.
- **A counter-proposal on T1 releasing T2's reservations.** `CounterTrade` releases `side_of(trade, "offer")` of that trade only, by quantity; `reserved` is a sum, so T2's share stays. `CancelOpenTrades` sums the offers per proposer across the cancelled trades before releasing.
- **Two trades of one pair accepted or countered concurrently.** `lock_trade` takes both bank locks in ascending id (`TradeLocks.players`) before the trade row, so the two transactions serialise; holdings are locked after, in ascending player then card-season. No new lock cycle.
- **Friend removal, going private, account deletion.** `CancelOpenTrades` cancels every open trade of the pair (or of the player), `FriendRemoved` carries all `trade_ids`, and `PlayerStream` sends one `trades` notice per party. Nothing is keyed by friend.
- **Private stream and toasts.** The stream carries the waiting count and a `trades-updated` signal; toasts are flashes of the acting request. Nothing assumes one trade per friend.
- **The expiry job against a counter-proposal.** A counter needs `not_expired` and pushes `expires_at`; `ExpireTrade#closable` re-reads it on the locked row. Unchanged by the amendment.

---

## H1 (high): a sent suggestion stays in the list, identical, and its "ENVOYER" sends it again

- **Units:** `Game::TradeSuggestions` (AD-38) and the suggestion row with its "ENVOYER" (`EXPERIENCE.md` Suggestion row; Focus after each step).
- **How both obey:** the query reads spares as `quantity - reserved` beyond the kept copy, exactly as AD-38 says. The row sends the suggestion through `Game::ProposeTrade`, exactly as AD-38 says.
- **The hole:** the friend's cards are the request, and requests are never reserved (AD-8). After the send, the friend's spares are unchanged, so the next render shows the same suggestion for that friend: identical when one-sided; for a mutual one, the player's offered spares are now reserved, so it comes back one-sided with the same friend cards. The UX says "the suggestion leaves the list" after "ENVOYER" and moves focus to the next row; under AD-38 it cannot leave. Before the amendment the rule "with an open trade, a suggestion opens that trade" closed this; it left with the per-pair limit. Sequence: Hugo presses "ENVOYER" on Léa's one-sided suggestion; the list re-renders with the same row at the top; Hugo presses again (or the focus lands back on it after a re-render); two identical open requests reach Léa, neither reserving anything. If Léa accepts both after countering, Hugo pays twice for the one copy his goal needed.
- **Closing text (AD-38, after the spare rule):** "A game already on the friend's side of an open trade between the two players, whoever's turn it is, is not a spare of that friend for the player's suggestions; a game already on the player's side of such a trade is not one of the player's spares for that friend. A suggestion left with no friend card is not shown, and the next friend takes its place."

## H2 (high): the send is no longer idempotent

- **Units:** `Game::ProposeTrade` (AD-8, now without the per-pair refusal) and any sender: "ENVOYER LA PROPOSITION" on the board, "ENVOYER" on a suggestion row, Back to a prefill address (see M1).
- **How both obey:** AD-8 allows any number of open trades; the controller throttle (20 sends per window) is the only brake.
- **The hole:** today `index_game_trades_one_open_per_pair` and `no_open_trade` make a double submit harmless: the second POST is refused `trade_already_open`. Without them, a double click, a network retry of the form POST, or a held Enter (flagged in `review-accessibility-2026-10-31.md` S1) creates a second trade. An offer that reserves stops the second only when the copies run out; an empty offer (the open request, every one-sided suggestion) reserves nothing, so every repeat succeeds.
- **Closing text (AD-8, after "any number of open trades"):** "`Game::ProposeTrade` refuses, under the two bank locks, a proposal whose offer and request equal those of an open trade the same player proposed to the same friend (`Failure(:trade_already_sent)`), so a repeated send creates nothing." (A submission nonce stored unique on the trade closes it as well; the equal-terms refusal needs no column.)

---

## M1 (medium): who writes the prefilled draft, and when, is unsaid; a look destroys a hand-built draft and Back re-applies a sent suggestion

- **Units:** the suggestion row's opener (a link, "opening writes nothing", `EXPERIENCE.md` Accessibility Floor) and the trade board root controller with `trade_board_draft.ts` (AD-30: browser storage is read and written only by that module).
- **How both obey:** AD-38 says starting from a suggestion "replaces the stored draft for that friend and opens the trade board prefilled". One builder carries the cards in the opener's address and has the board replace the draft on connect; another writes the draft from the row's controller before navigating. Both obey.
- **The hole:** (a) "starting a trade" is not defined. If opening the board counts, a tap anywhere on a suggestion row (the opener is stretched over it) silently replaces the draft Hugo built for Léa by hand; suggestions cannot be dismissed, so this happens on every look. (b) If the prefill rides in the address, a reload after editing re-applies the prefill over the edits, and Back from the sent trade's page (trade pages are never cached by Turbo, so the address is fetched again) shows the sent suggestion again as a fresh draft, one press from H2's duplicate. (c) AD-38 also settles the UX's open question "a suggestion opened on the board and left unsent: what it becomes" without saying so.
- **Closing text (AD-38, last rule):** "The opener's address carries the friend's token and the suggestion's card-seasons (slug and season, AD-15), quantity 1 each; the board renders that prefill and does not write it. The stored draft for that friend is replaced only when the player changes the prefilled board or sends it; the board then replaces its address with the friend's plain new-trade address, so a reload or Back resumes the stored draft and never re-applies the suggestion. A suggestion left unsent stays a suggestion."

## M2 (medium): "one unsent draft per friend" erases the per-trade counter draft that already exists

- **Units:** AD-8's draft rule and the counter editor (`trade_counter_key` = player token, trade token, `expires_at`, in `TradesHelper`).
- **How both obey:** AD-8 names one draft per friend and nothing else. A builder who reads it as exhaustive folds the counter edits into the friend key; AD-38's "replaces the stored draft for that friend" then wipes a counter in progress, and editing counters on T1 and T2 of the same friend overwrite each other.
- **Closing text (AD-8):** "The browser keeps two kinds of unsent edits: one new-proposal draft per friend, keyed by the player's token then the friend's token, and one counter draft per trade and proposal, keyed by the player's token, the trade's token and the proposal's expiry. A suggestion replaces only the friend's new-proposal draft." (This also fixes "the two player tokens", which leaves their order open; a builder who sorts them splits the key from the one `trade_draft_key` writes today.)

## M3 (medium): "ÉCHANGE" and a suggestion's "ENVOYER" each act on the friend's draft in a way AD-8 does not settle

- **Units:** the friend row, friend chooser and profile actions ("always opens a new draft with that friend", `EXPERIENCE.md`), `TradesController#create` (forgets the friend's draft on every successful send through `flash[:trade_forget]`), and AD-8's stored per-friend draft.
- **How both obey:** AD-8 keeps a draft per friend; the UX says "ÉCHANGE" opens a new one. One builder resumes the stored draft on "ÉCHANGE", another clears it. A suggestion's "ENVOYER" posts to `create`, which forgets Hugo's hand-built draft for Léa although that draft was not what he sent.
- **Closing text (AD-8):** "'ÉCHANGE' and 'ÉCHANGER' open the friend's stored new-proposal draft, empty when there is none. A send from the board forgets that draft; a send from a suggestion row leaves it."

## M4 (medium): AD-38's ordering and card choice are not total

- **Units:** `Game::TradeSuggestions` and anything that must agree with it across renders: the list after a send (focus moves to "the next suggestion row's opener"), the 3-row cap, the opener's address (M1), the tests.
- **The holes:**
  - "then the friend's name": names are Steam persona names (`accounts_players.persona_name`), not unique, nullable (a nameless friend is shown as a locale string, so a sort by shown name depends on the locale), and cleaned by `Accounts::PersonaName.clean` in Ruby, which SQL ordering does not see. Two friends with the same name swap between renders, and at the cap one of them enters or leaves.
  - "the friend bringing the most cards": counted before or after the cap of 4, and, for a mutual suggestion, friend side only or both sides.
  - "those of the player's lowest-numbered goal first, then the rarest minted rarity": a game in two goals (take its lowest position?), and two games of the same goal at the same rarity have no order, so the 4 placed are not determined. The same gap repeats on the mutual side "chosen the same way on the friend's goals".
  - The line quantity is unsaid (presumably 1).
- **Closing text (AD-38):** "Friends are ordered by mutual first, then the number of distinct games they spare for the player's goals before the cap of 4, then the friendship's creation, then the friend's token. A game ranks by the lowest position of the player's goals that hold it, then its placed edition's rarity, rarest first, then its slug; the mutual side ranks the same way on the friend's game-set goals. Each placed line has quantity 1."

## M5 (medium): two suggestions place the same copy of the player, or bring the same missing game twice

- **Units:** suggestion rows for Léa and for Max, computed independently by the same query.
- **How both obey:** AD-38 chooses each suggestion's cards per friend and limits only one suggestion per friend.
- **The hole:** Hugo's single spare of Celeste is placed in both mutual suggestions; the second "ENVOYER" fails `insufficient_copies` after the first, which the row does not foresee. Worse, Léa and Max both spare Hades, which Hugo's goal misses once; both suggestions bring it, and sending both (as the UX's "ENVOYER, then the next row" flow invites) makes Hugo pay twice for one needed card; no rule refuses that.
- **Closing text (AD-38):** "The query ranks the friends first, then fills the suggestions in that order: a game already placed on the friend's side of a higher suggestion, and a copy of the player's already placed on the player's side of one, is not placed again; a suggestion left with no friend card is not shown." (If the author prefers independent suggestions, AD-38 should say so and that a later send may be refused.)

---

## L1 (low): the per-pair machinery the amendment removes is not named, and the friend actions still open one arbitrary trade

- **Evidence:** the partial unique index `index_game_trades_one_open_per_pair` (`db/schema.rb`, created in `20261007130000`), the `RecordNotUnique` rescue and `no_open_trade` in `ProposeTrade`, its pre-send `expire_due_trade` (which existed to clear a due trade blocking the pair, and now expires only one of several), the `trades.one_at_a_time` redirect in `TradesController#new`, and `Game::OpenTradesByFriend`, whose `to_h` keeps one token per friend: the friend row, friend profile and public profile buttons open whichever trade the database returned last, and the remove-friend dialog speaks of one trade.
- **Hole:** AD-13 says the trade actions on the friend row and friend profile ask `open_to_friends?`, and nothing else about them; the UX's "always opens a new draft" has no spine counterpart. A builder who removes only the Ruby check still gets `trade_already_open` from the index.
- **Closing text (AD-8):** "The per-pair partial unique index on `game_trades` is dropped (concurrently, in its own migration), and `Game::ProposeTrade` neither checks nor expires a pair's trades. The trade actions on the friend row, the friend profile and the public profile open the friend's new-proposal draft, never a trade; the remove-friend dialog counts the open trades it cancels."

## L2 (low): AD-10's lock order does not list trade rows

- **Evidence:** every trade operation locks bank locks, then the trade row (`Trade.lock.find`), then holdings; `CancelOpenTrades` locks several trade rows `order(:id)` after all the bank locks. With several trades per pair, an operation that locks two trades of the pair is now ordinary.
- **Closing text (AD-10, lock order):** "... each player's advisory lock in ascending player id, then trade rows in ascending id, then holdings ..."

## L3 (low): nothing bounds open trades between two friends

- **Sequence:** Hugo sends Léa dozens of open requests (empty offer, nothing reserved, nothing at stake); each one lands in her "EN ATTENTE DE VOUS", raises her waiting count and pings her private stream. The throttle (20 sends per window) slows it; only removing the friend stops it. The same freedom lets two friends farm the community gauge and "repeated trades with one player" faster, though not in a new way.
- **Note:** the author chose no cap (CAP-11, 2026-10-31). AD-8's Prevents line should say the throttle is the accepted brake, or the author should set a cap of open trades a player has proposed to one friend.

## L4 (low): AD-8's Prevents line and AD-38's Prevents line no longer match their rules

- AD-8 still lists only "a card promised twice" etc.; it now also has to prevent "a repeated send creating a second trade" (H2) and "two edits overwriting each other" (M2). AD-38's "the list and the prefilled proposal disagreeing on what is spare" is held only once M1 says the prefill carries the list's cards rather than recomputing them on the board.
