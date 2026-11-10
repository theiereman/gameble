---
tracker_id: ""
key: ""
type: epic
title: "An auction runs and settles"
parent: initiative-gameble
covers: ["CAP-30", "CAP-31", "CAP-32", "CAP-33"]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# An auction runs and settles

## Description

Players sell and buy cards at auction. A seller lists an unreserved copy with a stamp, a duration and an optional buy-now price; bidders state a maximum held in escrow; the displayed price follows the second-highest maximum; a late bid extends the auction; a job closes each due auction and settles it exactly once: the winner gets the copy and the surplus, the seller the price less the commission, which is destroyed. The settlement also refreshes the edition's average price and stores it on the sold listing. The market screen, the Annonce with its bid history, MES ENCHÈRES and MES VENTES let players follow it.

## Outcome

For the players: a card they want can be won at auction without overpaying, and a card they sell pays them without them coming back. For the author: no PiCoin or copy ever moves twice.

## Requirements

- R1 — Any unreserved copy of a card-season with a rarity can be listed, an only copy included; a listing is one copy, reached by token, with status `open`, `sold`, `unsold`, `cancelled` or `withdrawn`, and an open listing carries `reserved + 1` on the seller's holding, so the copy cannot be traded or entrusted while it runs. (CAP-30; AD-44, AD-6, AD-8, AD-40)
- R2 — The stamp is shown before listing, charged at listing as a `stamp` entry and never refunded; the starting price and any buy-now price are refused below the rarity's minimum, and a buy-now must be above the start; the seller picks one of the three durations, 24 H preselected. The listing stores its settings version, which sets that auction's durations, increment, soft close and commission; a form drawn before a settings change is refused with `Failure(:amounts_changed)`, charging nothing. (CAP-30; market-economy.md, Values by rarity, Auction rules; AD-42)
- R3 — The seller can cancel only while no bid stands and gets the copy back, also while the market is closed; an auction with no bid returns the copy to the seller, who relists it in one action as a new listing with a new stamp, its start and buy-now prefilled. (CAP-30, CAP-32; AD-44, AD-45, AD-50)
- R4 — `Game::Market::AuctionMath` is the only computation, pure and with no loop: the increment (the version's percent, rounded up to the hundred), the displayed price (second-highest maximum plus its increment, capped at the highest, the starting price with one bidder), the minimum bid (never above buy-now; the starting price with no leader) and the commission (integer floor). (CAP-31; market-economy.md, Auction rules; AD-41, AD-44)
- R5 — `Game::Market::PlaceBid` applies one of four branches under AD-10's lock order (buy-now, new leader, beaten at once, leader's raise), holds the whole maximum or the difference from `available`, releases the outbid leader in the same post, and refuses a bid above what the player can commit, on their own listing, below the minimum, or at or past `ends_at`. A bid is firm and can only be raised; equal maximums lead in time order; a removed seller refuses and a removed leader counts as no leader and is released. Each validated bid writes one `game_market_bids` row and publishes `BidPlaced`, or `AuctionSold` on buy-now, carrying the player outbid. (CAP-31; market-economy.md, Auction rules; AD-44, AD-41)
- R6 — A bid in the last minutes of the auction's soft-close window that changes the price or the leader moves the end to that window after the bid and fills `extended_until`; a leader raising their own maximum moves neither the price nor the end. (CAP-32; market-economy.md, Auction rules; AD-44)
- R7 — A maximum reaching the buy-now price buys at once at that price, stated before validation, holding the buy-now less any maximum the player already holds; no held maximum ever reaches it. (CAP-31; market-economy.md, Auction rules; AD-44)
- R8 — `Game::Market::CloseDueAuctionsJob`, every 10 seconds, runs `CloseAuction(player: seller, listing_id:)` once per due listing, one per transaction, reporting an error and moving on; `CloseAuction` rechecks under the bank locks and the listing lock that the listing is open, due and has that leader, and otherwise does nothing. With no leader the listing becomes `unsold` and the reservation is released; a removed seller makes it `withdrawn` and releases the leader's maximum; a removed leader's maximum is released and the listing becomes `unsold`. (CAP-32; AD-45, AD-50)
- R9 — The settlement runs exactly once: it reads the published season, receives the winner's allocation, moves one copy with its `reserved` through `AcceptTrade#move`, records set tiers with `reached_by: "trade"`, removes unheld showcase entries, and returns `purchase`, `release` of the surplus, `sale` and `commission` for the caller's single `Ledger.post`; the commission is destroyed; one `AuctionSold` is published. Running the close twice, or a bid landing at the close, never moves a PiCoin or a copy twice, and the ledger still reconciles. (CAP-32; AD-45, AD-41, AD-10)
- R10 — `game_market_edition_prices` holds one row per card-season with the average and the sales used; `Game::Market::EditionPrice` is the only formula (the last sales of the window, highest and lowest dropped, none dropped under 3, floored); the settlement upserts and locks the row before the ledger post, then stores its new average on the sold listing as `average_after_sale`. (CAP-32, its edition price for epic 41's CAP-34; market-economy.md, Average price; AD-47)
- R11 — `AuctionSold` is heard by `GoalsReached` and `Achievements`, never by `WeeklyContribution`; events carry identifiers only. (CAP-32; AD-45, AD-10; spec Assumptions, a market sale and the weekly goal)
- R12 — `Game::Market::CheckMarketHealthJob`, every 5 minutes, reports to the error tracker when the oldest due open listing is over 5 minutes old, and that age is readable by a query for the back-office. (CAP-32; AD-50)
- R13 — Once a first opening is recorded, the market address shows the market screen instead of the teaser; a closed version then shows the suspended banner above readable listings, every listing and bidding action disabled with the banner as its reason, ANNULER kept; entrusting, listing and bidding refuse with `Failure(:market_closed)`. A visitor reads the market and every Annonce, and every action shows greyed with "Connectez-vous pour enchérir" in the form's place; listing, bidding and buying need an account whatever the client does. (CAP-33; AD-50; EXPERIENCE.md, State Patterns, Market not yet open, Market suspended, Visitor on the market)
- R14 — The market screen opens on ANNONCES: one tile per open listing (card, price compact, "n offres" counting public validated bids, time left in alert colour under an hour, "Achat immédiat" when set), the whole tile one link named by the Market accessible text, ending soonest first, with the four sorts and "Charger plus"; it refreshes on arrival, not live. (CAP-33; EXPERIENCE.md, Market screen, Listing tile, Copy deck, Market feed and lists)
- R15 — The Annonce shows the card and its facts (seller; the place epic 41 fills with the average price), PRIX ACTUEL, "En tête", FIN DANS counting down per minute from the server's end time with the end time beside it, the buy-now price and the history; "Clôture en cours…" between the end and the settlement, then the outcome for that viewer. (CAP-33; EXPERIENCE.md, Annonce, Copy deck, Annonce and Auction outcomes; DESIGN.md, Marché)
- R16 — The bid history has one line per validated bid, newest first, with the name, the price after that bid and the time, live and after close, ending with the listing's creation; the current leader's latest line reads "En tête"; an extension adds a line; a raise adds a line for its owner only; the leader's maximum is never shown except to its owner. (CAP-33; AD-44; EXPERIENCE.md, History row)
- R17 — One component names a player in the bid history, the Annonce and the pioneer row: the persona name, linked to the profile only when `Game::Visibility.visible?(viewer, owner)`, the anonymous locale key with no link for a banned or deleted account, a 44px hit area on the phone. (CAP-33, CAP-8, CAP-13; AD-49; EXPERIENCE.md, Names)
- R18 — The My maximum form, the bid answers and their focus follow the UX: one numeric text field with its minimum, the fixed and live sentences, Enter moving to the button whose name carries the amount, a double activation submitting once, refusals inline with the Copy deck's words, the answer panels (leading, beaten at once, equal maximum, raise accepted, bought), the leader's raise, one polite status region, and no form on one's own listing. (CAP-31; EXPERIENCE.md, My maximum form, Bid result, Copy deck, Answer to my bid and Market refusals, Accessibility Floor, Market, Focus after each step)
- R19 — The unusual-maximum dialog asks confirmation only when a maximum reaches the settings' multiple of the current price and stays below any buy-now; ACHETER MAINTENANT and a maximum reaching buy-now open the buy-now dialog, which takes precedence, and is disabled with the available amount when the player cannot pay it. (CAP-31; market-economy.md, Auction rules; EXPERIENCE.md, Unusual maximum dialog, Buy-now)
- R20 — Mettre en vente: a single-choice grid of unreserved copies, one cell per edition, then the form with the starting price and its minimum, the optional buy-now, the durations, the stamp, the commission and what the seller receives at the starting price, each line updating as amounts change, inline refusals, the settings version submitted; reached from the market, from a card detail on that card's editions, and from REMETTRE EN VENTE; two steps on the phone; focus on the new Annonce's h1. (CAP-30; AD-42; EXPERIENCE.md, Mettre en vente, Settings behind an open form; DESIGN.md, Marché)
- R21 — MES ENCHÈRES lists the player's auctions in EN COURS and TERMINÉES RÉCEMMENT (7 days) with status chip in words, price, my maximum, time left and RELEVER, filled only when outbid; MES VENTES lists the seller's listings as EN COURS, VENDUE with the amount received, SANS OFFRE, ANNULÉE and RETIRÉE, with ANNULER while no bid stands behind a dialog naming the unrefunded stamp, and REMETTRE EN VENTE after an auction with no bid; a visitor sees both chips greyed. (CAP-31, CAP-32; EXPERIENCE.md, MES ENCHÈRES row, MES VENTES row, Copy deck, Mes enchères, mes ventes)
- R22 — Every market operation answers a deadlock with `Failure(:market_busy)`; listing and bidding are rate limited per player; no database id appears in a URL, the HTML, a DOM id or a stream name; every amount goes through epic 38's PiCoin amount component. (CAP-30, CAP-31; AD-40, AD-15, AD-14)

## Done when

1. A player lists a copy, two players bid, the leader is outbid by a higher maximum, a bid in the last 3 minutes extends the auction, and at close the winner holds the copy with the surplus returned and the seller holds the price less the commission.
2. A maximum reaching the buy-now price buys at once; an auction with no bid returns the copy and can be relisted in one action; a seller cancels while no bid stands.
3. Running the close twice or bidding at the close never moves a PiCoin or a copy twice, and the ledger still reconciles.
4. Once the market has opened, its address shows the market screen; a closed market shows the suspended banner above readable listings.
5. Shipped to production with the market closed at deploy; the staging exercise of items 1 to 4 is the author's, in epic 41's opening story.

## Boundaries

No outbid notice, bell line, live refresh of the Annonce, sale feed entry, market filters or search, and no `DropPresenceJob`, voided bid line, forfeit or export for banned or deleted players: epic 40 (the removed seller and leader checks AD-44 and AD-45 put inside `PlaceBid` and `CloseAuction` are this epic's). No average price display, sort or filter by average price, or indicator: epic 41, which fills the average price facts this epic lays out on the Annonce and Mettre en vente.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-30, CAP-31, CAP-32, CAP-33
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-8, AD-10, AD-44, AD-45, AD-47 (table, EditionPrice, upsert at settlement, average_after_sale), AD-49, AD-50 (CloseDueAuctionsJob, CheckMarketHealthJob)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché, Market screen, Listing tile, Annonce, My maximum form, Unusual maximum dialog, Buy-now, Bid result, History row, Names, Mettre en vente, MES ENCHÈRES row, MES VENTES row; Flow 7
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/market-options.html, _bmad-output/initiative-gameble/ux-gameble/mockups/market-screens.html

## Notes

- Decision (2026-11-10, author): epics 38 to 40 ship to production with the market closed behind the teaser; the first opening is the final hitl story of epic 41, so daily snapshots start on day one.
- Needs from epic 38: wallets and `Ledger.post`, settings versions, the open state and the first opening, `AcceptTrade#move`, the PiCoin amount component.
- Contract with epic 41: this epic lays out the average price facts on the Annonce and Mettre en vente; epic 41 fills them. It produces the age of the oldest due listing (`CheckMarketHealthJob`), which epic 41's health page shows.
- Touch points: the settlement receives the winner's allocation, records set tiers with `reached_by: "trade"` and removes unheld showcase entries (AD-10, AD-45); `AuctionSold` reaches `GoalsReached` and `Achievements`, never `WeeklyContribution`; `config/recurring.yml`.
- Decision (2026-11-10): story 1 is the tracer: the listings table, `ListCard`, the switch from the teaser to the market screen after the first opening, the ANNONCES list and a read-only Annonce, through schema, operation, ledger, query, policy, controller and view; a listing is created by the operation in its test and by a development seed.
- Decision (2026-11-10): the settlement (2) follows the tracer as the least certain piece; the domain lane runs 2, 3, 4 in order (close, edition price, bidding) and owns `db/schema.rb` in that order. Mettre en vente (5) runs beside it. The Annonce lane runs 6, 7, 8 (history and outcomes, the form, the dialogs); MES VENTES (9), MES ENCHÈRES (10) and the suspended market (11) follow; the refactor sweep (12) closes.
- Decision (2026-11-10): `PlaceBid` and `CloseAuction` carry the removed-player branches AD-44 and AD-45 give them (a removed seller refuses a bid or withdraws at close; a removed leader is released); `DropPresenceJob`, the voided history line, forfeits, notices and the export stay in epic 40.
- Decision (2026-11-10): AD-45 names only `AuctionSold`; the other state changes publish their own event: `Game::Market::CardListed`, `ListingCancelled`, `AuctionUnsold` and `ListingWithdrawn`, heard by nobody in this epic.
- Decision (2026-11-10): the Annonce and Mettre en vente render their facts without an average price row; epic 41 inserts "Prix moyen" before the seller row. `EditionPrice.rarity_average` and the nightly refresh are epic 41's (AD-47, AD-48).
- Decision (2026-11-10): `config/routes.rb`, `config/locales/en.yml` and `fr.yml` take additive edits to distinct key subtrees from stories with no dependency path between them (5 beside 2 to 4 and 6); a merge conflict there is resolved by keeping both sides; any other shared file has one lane. Story 5 has its own controller, policy and `app/frontend/lib/listing_form.ts`, and story 8 its own fixture, so neither collides with the Annonce lane.
- Decision (2026-11-10): this epic ships to production closed at deploy, with no hitl story of its own; its staging exercise is epic 41's opening story.
- Decision (2026-11-10): story 1 adds the ledger's listing foreign key (not valid, then validated) and AD-41's partial unique index, concurrently in its own migration; the bid outcome check includes `voided` from story 4.
- Decision (2026-11-10): the check outside the high-risk stories' own criteria (1 to 4) is the nightly reconciliation of epic 38 over the staging exercise, and the author's staging exercise in epic 41's opening story.
- Decision (2026-11-10, Claude's; the author may revisit): Mettre en vente's live lines (commission, what the seller receives) and the unusual-maximum multiple are computed in the browser for display only from the version's values in the markup, `AuctionMath` staying the only authority on what is posted, tested against it through a shared fixture, as the charts' picoins form is (AD-51).
- Assumption: `GoalsReached` and `Achievements` hear `AuctionSold` for the winner only; the seller's achievements are not reread.
- Decision (2026-11-10): the Balance chip and its `PlayerStream` balance notice are epic 38's (story 8); this epic wires `CardListed` (1), `AuctionSold`, `AuctionUnsold` and `ListingWithdrawn` (2) and `BidPlaced` (4) to the notice, and places the chip in the phone header of the market screen, the Annonce and Mettre en vente.
- Decision (2026-11-10): events carry what epic 40's notices need: `AuctionUnsold` and `ListingCancelled` the listing and seller; `ListingWithdrawn` the leader and the amount released; `BidPlaced` the player outbid and their released amount; `AuctionSold` the surplus and the outbid player's release.
- Decision (2026-11-10): this epic keeps the Annonce's status region (7) and the four sorts (1); epic 40's stories 3 and 7 extend them, and the countdown's last-minute wording stays story 1's.
- Decision (2026-11-10): the market section of Comment ça marche is epic 41's, before the opening.
- Source conflict: EXPERIENCE.md, Names — the shared name component covers the Chattomètre vs AD-49, which names only the bid history, the pioneer row and a sale's feed entry; this epic moves the pioneer row and leaves the Chattomètre as built.
