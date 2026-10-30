# Later roadmap (not MVP)

Context for MVP design decisions that must not block these. Nothing here is built in the MVP.

## V2 — Auction house

- **Currency:** a single in-game currency, earned only by destroying cards to the system for a tiny fixed amount per rarity. It is spent bidding on rarer cards at auction.
- **Sinks:** both are destroyed and shown before listing. They are the only currency sinks.
  - Listing fee: *Timbre Fiscal du Gamebler* / Gamebler's Tax Stamp.
  - ~10% sale commission: *Effort de la Confrérie* / Brotherhood Effort.
- **Market gate:** access is gated by gameble seniority (account age or packs opened). The threshold is TBD.
- **Money:** no real money; currency is never purchasable or withdrawable.
- **Taxes and fees (author, 2026-10-15):** they arrive with the market and the economy, never before. The Brotherhood announces and justifies each one in its tone (`brotherhood-tone.md`): issue #57's examples, such as a contribution on trades or processing fees, are tone samples to draw on then, not commitments.
- **Average sale price in the collection (author, 2026-10-07):** each card shows its average sale price on the market, and the collection can be filtered and sorted by it, to see what is worth something. The price is the average of that card's most recent sales (the card itself, not its rarity); a card never sold shows "sans vente" ("no sale"); the price is shown per card, and a typical price per rarity may also be shown as an indication (optional). How many sales count is still open, and so is whether the average is per game, per minted rarity or per edition (market liquidity against an edition premium). It needs completed sales, so it waits for the auction house; the price is in the in-game currency, never real money.
- **Quick sorting from the opening:** while a pack is opened, the player marks cards in place into a "to process" zone: drag on desktop, swipe or buttons on phone (buttons always available). One validation then destroys or sells everything in it. Marking is reversible until validation; cards in the zone no longer count in the collection; marking a card's only copy asks for an extra confirmation. The "to process" screen must be easy to scan so reviewing stays quick.
  - **Rejected:** an immediate swipe that sells or discards (too dangerous), and default automatic sorting of duplicate commons (some are kept for a set or a loved game).
  - **To check before V2:** a per-copy "to process" state must fit the copy model without a heavy migration.

## V3 — Seasons and community content

- ***Pass de la Confrérie* / Brotherhood Pass:** a collective parody battle pass whose tiers are advanced by market fees. Each tier rewards contributors with packs, never currency.
- **Seasons:** moved to the MVP rules (`catalog-and-rarity.md`, Seasons). Left for V3: the season cadence (e.g. quarterly).
- **Themed sets:** community-proposed and voted (20–100 cards each, with rewards), created in a back-office without code changes.

## Later

- **Odds input at opening:** an input the player makes at opening that improves the odds of a good card. The stratagem-like arrow code is rejected as too close to Helldivers; the form is open.
- **Steam library bonuses:** bonuses on the cards of games a player owns, from playtime and achievements. They are bonuses only; the library never grants a card. Steam shares a player's library only when their profile's game details are public; the Steam library set (CAP-27, release 1.1.0) reads it first.
- **Library info on a shared card:** show the owner's Steam library info when they own the game.
- **Live trades:** both players at the trade board at the same time.
- **Trade discussion:** a free-text discussion between the two players on a trade, raised while forging the open trade request (2026-10-15); to be forged on its own. Player-written text needs reports, hiding and back-office reading (CAP-15), export and erasure with the account (CAP-14), bans, private profiles, an unread badge, live delivery and rate limits.
- **Card marks:** favourite, to trade, personal categories.
- **Brotherhood sets (author, 2026-10-30):** a community page where players publish custom sets (CAP-27) and others add them to their own library; custom sets and goals on them then show on profiles. Player-written set names need reports, hiding and back-office reading (CAP-15), export and erasure with the account (CAP-14), and bans. To be refined.
- **Trade suggestions beyond friends (#64):** suggestions among other players willing to trade, with privacy controls.
- **Secret achievements (#66):** achievements whose title and condition stay hidden until earned, some opening hidden branches, explored once active goals (CAP-28) ship; sensitive ones private by default.
- **Targeted capsules (#64):** capsules aimed at a goal, to explore in their own issue.
- **Feed reactions:** reacting to or commenting on a friend's pull or repost.
- **Knowledge battles** (parked idea, unscheduled; detail in the brief addendum): live three-round matches on themes drawn from Steam data, played with cards picked from a random hand, rewarding knowledge of games rather than collection size; optionally a challenge market where players stake cards. It conflicts with the Combat non-goal and with the rule that currency comes only from destroying cards.
- **Delisted games:** manual curation, since the store API returns little for them.
- **Native apps:** App Store and Play Store. Store review may object to third-party art and random rewards, and iOS sign-in rules may apply. Reassess then.
