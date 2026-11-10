---
tracker_id: ""
key: ""
type: epic
title: "Following one's auctions, and removed players"
parent: initiative-gameble
covers: ["CAP-31", "CAP-33"]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Following one's auctions, and removed players

## Description

The market keeps players informed and stays clean. An outbid player is told at once, on the page and in the bell; the Annonce refreshes live while open; a sale worth noticing appears in the feed; the market screen gets its filters and search. A banned or deleted player leaves the market: their listings are withdrawn, their leading bids voided and released, a deleted player's balance is forfeited, and the data export and deletion cover the market.

## Outcome

For the players: they never miss being outbid, and they see the market move. For the author: removing an account never leaves a card or PiCoins stuck.

## Requirements

- R1 — An outbid player is notified and can raise their maximum by hand; nothing bids for them. The notice is a `game_market_notices` row owned by the player, written by a handler of `BidPlaced`, and of `AuctionSold` when someone was outbid, shown by the bell and sent on the player's private stream. Later notices use the same table and channel. (CAP-31; AD-44, AD-45, AD-13)
- R2 — On the Annonce, a market event is a panel above the form that never moves focus and never replaces the field or the button: outbid ("VOUS AVEZ ÉTÉ DÉPASSÉ", with "VOIR L'ANNONCE") and extended ("ENCHÈRE PROLONGÉE", the new end). (EXPERIENCE.md, Bid result; Copy deck, Market events)
- R3 — The bell has one market line per listing: outbid or won ("Voir", to the Annonce); a sale, an auction ended with no bid, or a removed participant ("Voir", to MES VENTES, or the Annonce for a bidder); bought over a bid. Lines follow Copy deck, Market bell lines, clear as the bell's other lines do, and reload the bell live; there is no toast. An outbid also posts its line once to a polite status region present on every signed-in page, at most once per listing per 30 s. (EXPERIENCE.md, Bell; Copy deck, Market bell lines)
- R4 — An orange count badge gives the running auctions where the player is outbid, on menu 04, the MARCHÉ tab and the MES ENCHÈRES chip, named by Copy deck, Market accessible text; it falls when the player raises or the auction ends. The balance chip updates on the private stream. (EXPERIENCE.md, Count badge, Balance chip)
- R5 — The Annonce's price, leader, history and end refresh live: the listing's public stream, named by its token, only asks each viewer to refetch, sent by a batched job after commit; the page refetches by morphing, leaving an open dialog, the focused element and what the player is typing alone. (CAP-33; AD-44, AD-13, AD-15; EXPERIENCE.md, Annonce)
- R6 — An auction that ends while a viewer reads or types shows "Clôture en cours…", then that viewer's outcome; an open dialog closes, the outcome's heading takes focus, the status line says the auction has ended, and a typed amount is not submitted ("Votre montant n'a pas été enregistré."). (EXPERIENCE.md, State Patterns, Auction ended while reading or typing; Copy deck, Auction outcomes)
- R7 — The Annonce has one polite status region, empty at load, carrying the latest Market accessible text at most every 10 s, never dropping the last update; an extension and the auction's end bypass the 10 s; "ANIMATIONS RÉDUITES" stops its posts about other players' bids; a bidder's status line posts once at the last hour and once at 3 minutes left. (EXPERIENCE.md, Accessibility Floor, Market)
- R8 — Once the market is open, the feed shows every sale of an Épique or Légendaire, and any sale at the feed threshold times its rarity's minimum price or more, both read from the current settings version. A sale's entry has kind `sale`, names the buyer as `player_id` and is unique per listing; the `game_feed_entries` kind check gains `sale`, expand then validate. (CAP-13; market-economy.md, Sales in the feed; AD-42, AD-45, AD-49, AD-50)
- R9 — A sale's entry shows whatever the buyer's visibility, unless the buyer is banned or deleted, and names the buyer through the one names component; a feed broadcast renders it with no viewer, so with no link, and the page render links. `FeedEntries.visible`, `NewFeedEntries` and `VisibleFeedEntry` let this kind through. (CAP-33; AD-13, AD-49)
- R10 — A sale entry reads "<name> a acheté <card> pour <amount>." with the tag "VENTE", is kept by the feed's VENTES filter, shows in AMIS for a friend's purchase, and never appears in a ticker. (EXPERIENCE.md, Feed entry; Copy deck, Market feed and lists)
- R11 — The market screen searches by game and filters with FILTRES (the Filter zone's rarity, set and genre groups, plus season and price) and sorts by ending soonest, price ascending, price descending and most recent; with no match it says "Aucune annonce ne correspond à ces filtres."; `Game::Market` queries own the filters. (CAP-33; EXPERIENCE.md, Market screen; architecture Deferred, Market browsing filters)
- R12 — `Game::Market::DropPresenceJob`, every minute in both blocks of `config/recurring.yml`, finds banned or deleted players with an open listing, a leading bid or, once deleted, a wallet holding PiCoins, and runs one operation per listing, one per transaction, as `CloseAuction` does. (AD-46, AD-50)
- R13 — A removed seller's listing becomes `withdrawn`: the leader's maximum is released, the stamp is kept, the leader is told by the bell, MES VENTES shows RETIRÉE and the Annonce the withdrawn outcome. Releasing the reservation of a deleted player is a no-op on the missing holding. (CAP-15; AD-46; EXPERIENCE.md, State Patterns, Participant removed)
- R14 — A removed leader's maximum is released, a voided line ("Offre annulée : joueur retiré") joins the history, and the auction resumes at its starting price with no leader, its end unchanged; the seller is told by the bell. Releasing a leader never depends on the seller. (CAP-15; AD-46; EXPERIENCE.md, State Patterns, Participant removed)
- R15 — A final `Game::Market::ForfeitBalance` posts `forfeit` for a deleted player with no open listing or lead left, the retention job's deletions included; a banned player's wallet stays; the ledger still reconciles. (CAP-14; AD-41, AD-46; spec Constraints, Money integrity and Market and personal data)
- R16 — `Game::ReleasePlayer` also deletes the player's market notices and, as for every feed entry, their sale entries. (CAP-14; AD-46, AD-49)
- R17 — The data export adds the player's wallet, ledger entries, listings and bids with their own maximums. (CAP-14; AD-14, AD-46; spec Constraints, Market and personal data)
- R18 — The delete dialog's note names the PiCoin balance and the purchases among the feed entries erased, and says running listings are withdrawn and bids released. (CAP-14; EXPERIENCE.md, Delete dialog)

## Done when

1. An outbid player sees the notice on the Annonce and a bell line, and the Annonce they have open refreshes when another player bids.
2. An Epic or Legendary sale, or one over the feed threshold, shows in the feed under VENTES, never in a ticker.
3. The market screen filters by rarity, set, genre, season and price, and searches by game.
4. Banning a seller withdraws their listings; banning or deleting a leader voids their bid and the auction resumes; a deleted player's balance is forfeited and the ledger still reconciles; the export lists their wallet, entries, listings and bids.
5. Shipped to production with the market closed at deploy; the staging exercise of items 1 to 4 is the author's, in epic 41's opening story.

## Boundaries

No new auction rule. The notices beyond the outbid one stay as the UX sets them.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-31, CAP-33, CAP-14, CAP-15
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-13, AD-14, AD-46, AD-49, AD-50 (DropPresenceJob)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché, Market events, Bid result, Feed entry, Names, Market screen; State Patterns, Market
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/market-options.html, _bmad-output/initiative-gameble/ux-gameble/mockups/market-screens.html

## Notes

- Decision (2026-11-10, author): epics 38 to 40 ship to production with the market closed behind the teaser; the first opening is the final hitl story of epic 41, so daily snapshots start on day one.
- Needs from epic 39: listings, bids, `AuctionSold`, `BidPlaced`, the Annonce and the market screen.
- Touch points: the `game_feed_entries` kind check gains `sale` (expand then validate); `FeedEntries.visible`, `NewFeedEntries` and `VisibleFeedEntry`; `Game::ReleasePlayer`; the data export.
- Decision (2026-11-10): the tracer is story 1, the outbid notice through every layer (table, handler, query, bell, private stream, Annonce panel). Story 2, the live Annonce by morphing, follows as the least certain piece; stories 3 to 5 build on them. The sale feed entry (6), the market filters (7) and the export (11) are separate lanes that can run beside the notices. The removal stories run in one lane (8, 9, 10) because they share `DropPresenceJob`.
- Decision (2026-11-10): this epic owns the outbid count badge, the badge's update on the private stream, the Annonce's live status region and the "auction ended while reading" behaviour, since all depend on the live refresh or the notices; epic 39 renders each outcome and the history.
- Decision (2026-11-10): the delete dialog's note is updated here with the deletion it describes; the privacy and retention pages that name the market's data are epic 41's (its Done when 4).
- Decision (2026-11-10): the existing deletion of every feed entry naming the player already removes a buyer's sale entries; story 10 proves it with a test instead of new code.
- Decision (2026-11-10): high-risk stories (1, 6, 8, 9, 10) are checked outside their own tests by the author's staging run of Done when 1, 2 and 4, and by the nightly reconciliation staying clean after a deletion with a balance.
- Decision (2026-11-10): `config/initializers/event_store.rb` and the two locale files take additive edits to distinct key subtrees from stories that may run side by side (1, 6, 11); a merge conflict there is resolved by keeping both sides. `db/schema.rb` is owned in the order 1, 6, 13, 7. The market screen's chip row: story 5 (the MES ENCHÈRES badge) waits for story 7 (filters).
- Decision (2026-11-10): this epic ships to production closed at deploy, with no hitl story of its own; its staging exercise is epic 41's opening story.
- Decision (2026-11-10): story 6 (the sale entry's domain) and story 13 (its display) split the feed entry so neither carries both; story 1's notice table has its full kind check and replacing upsert, so stories 4, 8 and 9 never migrate it.
- Decision (2026-11-10): the Balance chip refreshes through epic 38's `PlayerStream` balance notice; story 5 extends its rendering, story 8 wires `LeadVoided`, and epic 39 wires `ListingWithdrawn` and its other events.
- Decision (2026-11-10): no entry names epic 38 in `after`; the initiative declares only epic 39 for this epic, and epic 39 itself waits for epic 38, so stories 5, 8, 10 and 11, which use epic 38's balance chip, `Ledger.post` and wallets, reach it through epic 39.
- Handoff from epic 39: `AuctionUnsold`, `ListingCancelled` and `ListingWithdrawn` (listing, seller, leader and amount released) and `BidPlaced` (the player outbid and their released amount); stories 2, 4 and 9 hear them.
- Handoff from epic 39: the market screen ships the ANNONCES list, the chip row, "Charger plus" and the four sorts; story 7 adds search and filters to them. The Annonce's status region and countdown are epic 39's; stories 2 and 3 keep them live and extend the region.
- Assumption: epic 39 builds the one names component (bid history), the history's line rendering and the Annonce's outcome panels; this epic reuses them for the sale entry and the voided line.
- Decision (2026-11-10): the Filter zone's PRIX group is built by story 7; epic 41's story 4 reuses it unchanged and waits for it.
- Open question: whether the extended panel shows to every viewer of the Annonce or only to bidders; story 2 shows it to every viewer while the latest bid's extension is the current end.
