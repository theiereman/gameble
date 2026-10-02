# Later roadmap (not MVP)

Context for MVP design decisions that must not block these. Nothing here is built in the MVP.

## V2 — Auction house

- **Currency:** a single in-game currency, earned only by destroying cards to the system for a tiny fixed amount per rarity. It is spent bidding on rarer cards at auction.
- **Sinks:** both are destroyed and shown before listing. They are the only currency sinks.
  - Listing fee: *Timbre Fiscal du Gambler* / Gambler's Tax Stamp.
  - ~10% sale commission: *Effort de la Confrérie* / Brotherhood Effort.
- **Market gate:** access is gated by gameble seniority (account age or packs opened). The threshold is TBD.
- **Money:** no real money; currency is never purchasable or withdrawable.

## V3 — Seasons and community content

- ***Pass de la Confrérie* / Brotherhood Pass:** a collective parody battle pass whose tiers are advanced by market fees. Each tier rewards contributors with packs, never currency.
- **Seasons:** the catalog and rarities are recomputed per season (e.g. quarterly), and new games enter only at season start. Owned copies keep their minted rarity and season.
- **Themed sets:** community-proposed and voted (20–100 cards each, with rewards), created in a back-office without code changes.

## Later

- **Steam library bonuses:** bonuses on the cards of games a player owns, from playtime and achievements. They are bonuses only; the library never grants a card. Reading a player's library may depend on their Steam profile privacy settings; verify before designing.
- **Delisted games:** manual curation, since the store API returns little for them.
- **Native apps:** App Store and Play Store. Store review may object to third-party art and random rewards, and iOS sign-in rules may apply. Reassess then.
