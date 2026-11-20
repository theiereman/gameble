# Validation Report — gameble, market volume

- **DESIGN.md** (`ux-gameble/DESIGN.md`): goal colours 6 to 10 and their table, the reserved-colour rule, the Gold rule, the goal bookmark, the market-volume component tokens and the Marché bullets (tags, Wanted count, Shop panel and screen, Vos cartes voulues, Confier wanted table, Best-order banner and direct sale, Order form and its result, Slot purchase, Average price)
- **EXPERIENCE.md** (`ux-gameble/EXPERIENCE.md`): IA rows, phone navigation, the tab bar and visitor lists, the market-volume Copy deck rows and the Bourse lines, Bell, Card detail and the market, Goal suggestion, Goal button, Slot purchase, the Marché rows from Balance chip to Back-office (Wanted copy now the one definition of a wanted copy), the Delete dialog, State Patterns, the Esc primitive, Focus after each step, the Key Flows waiver, Flow 13, Open questions
- **Run at:** 2026-11-20
- **Scope:** the market-volume update of 2026-11-20 only (wanted cards, the Confier wanted table, buy orders, selling to an order, the Archives shop, PiCoin capacity slots), not the whole spine pair

## Overall verdict

The happy path was buildable before the review: Flow 13's numbers were right, every token resolved, and no buy-now was left. Eight high gaps sat where the new money paths met the old rules; all are fixed in the spines (High findings below), following the author's eight decisions below. Goals 6, 7, 8 and 10 got new hexes that meet the ΔE rule against the Légendaire's iridescence. The skipped findings each need a product decision and are listed under "Left open".

## Findings by lens

| Lens | Critical | High | Medium | Low | Fixed | Skipped | File |
|---|---|---|---|---|---|---|---|
| Rubric | 0 | 1 | 9 | 11 | 19 (one through Spec changes needed) | 2 | `review-market-volume-rubric-2026-11-20.md` |
| Accessibility | 0 | 2 | 12 | 12 | 26 | 0 | `review-market-volume-accessibility-2026-11-20.md` |
| Coherence | 0 | 3 | 11 | 8 | 22 (one through Spec changes needed) | 0 | `review-market-volume-coherence-2026-11-20.md` |
| Abuse and privacy | 0 | 3 | 9 | 4 | 8, and 2 settled by the author | 6 | `review-market-volume-abuse-2026-11-20.md` |

Notes on the counts:

- Rubric "spec drift not handed off" and coherence "the spec and the forge still state what the author overrode" are fixed through "Spec changes needed" below, which `ux-gameble.md`'s "Changes this run asks of the spec" points to.
- Coherence "the same rules are written in several places" is fixed for the wanted definition, now stated once in Wanted copy (Marché), and for the ceilings, now stated in Slot purchase. The other rows point to those two. The chip list is still written in four places.
- Abuse "the wanted count is cheap to inflate" is settled by the author, who kept every goal (decision 3); its banned and deleted part was applied.
- Abuse "the wanted count reveals private goals" is settled by the author, who kept every goal (decision 3).
- Abuse "export, deletion and feed" is fixed for deletion, and the export goes to the spec. Its feed part is settled by the author for direct sales and Archive purchases (decision 7); whether private players stay out is left open.
- Abuse "best rival order spoofing", skipped, was later settled in part by the author (decision 6); its remaining questions stay under "Left open".
- Abuse "wash sales through orders", skipped, was later settled in part by the author: direct sales count in the average price (decision 7); whether flagged sales are dropped stays under "Left open".

## Author decisions taken on the findings

1. **Wanted:** a copy is wanted when its game is missing from another player's goals or when another player's eligible buy order targets it. The seller's count counts each player once. This is now defined once, in Wanted copy (Marché), and used by the DEMANDÉE badge, Vos cartes voulues, the Confier recap's set-apart copies, the card detail line, the wanted table's JOUEURS and the bell's grouped line. Flow 13 now has Inès counted once, through her goal and her order.
2. **Archive prices:** the back-office refuses an Archive price below the rarity's player minimum price; its refusal copy is in the Back-office row. A rarity whose Archive price is not set is absent from the shop: shop screen, Shop panel, the market's Archive offer tiles and the order form's Archives line. There is no daily purchase limit.
3. **Wanted count and privacy:** every goal counts, custom sets and private players included. The abuse review's privacy fix was not applied, and the Open questions bullet records the author's choice.
4. **Prefill with no average price:** the line is prefilled ENCHÈRES at the order's price, the order stays visible and À L'ORDRE is one press away. This replaces the earlier "order preferred whenever one exists".
5. **Goal colours 6 to 10:** accepted as recoloured: Moutarde #b8b000, Sarcelle #00b4bc, Rose saumon #fca8b0, Capucine #ff775c, Pistache #9cc474. DESIGN's Goal colours section no longer marks them as an assumption.
6. **Best rival order:** "Meilleur ordre en cours" on the order form counts only orders placed more than an hour ago, and never one from an account tied to the viewer. The Order form row says so.
7. **Direct sales and Archive purchases:** a direct sale to an order counts in the edition's average price and follows the feed's rule for sales; an Archive purchase never shows in the feed. The Best-order banner and direct sale row, the Edition chart row, the Archive purchase confirmation row and the feed row (Fil d'activité) say so.
8. **Accepted assumptions:** the market-volume tags written before the review now read "(accepted 2026-11-20)": 55 in EXPERIENCE.md and 4 in DESIGN.md (counted after the editorial pass), plus the goal colours of decision 5. The copy tags "copy drafted in the mock, author to approve" stay, since that copy is not approved, and so do the tags this review added (New assumptions to confirm).

## High findings and their fix

- **An order outside any goal never reached a seller** (rubric, coherence): decision 1, with the order's owner counted once.
- **The wanted table had no refusal on its own fields** (accessibility): fields are checked on submit and nothing is applied. Each field shows its refusal under it with `aria-invalid` and `aria-describedby`. The dock gives a count ("2 prix à corriger", or the stamp line), posted politely, and focus goes to the first invalid field. A State Patterns row and a Focus row were added. After a refusal caused by a change elsewhere, the dock's line names the changed lines and is posted politely, and each changed line names its new choice in words.
- **The order form hid the next rarity's price** (accessibility): the sentence now names the rarities reached and the price that reaches the next one ("Les épiques à partir de <amount>."), with forms for "every rarity reached" and "under the Commune minimum".
- **Shop spending was missing from "destroyed"** (coherence): the Bourse legend now reads "Détruits (timbres, efforts et achats à la Confrérie)", and the Reactor line in French and English names purchases. The Slot purchase row says the price is destroyed. The spec lines are below.
- **The best order could change between drawing and pressing** (coherence): a new row, Best order behind an open form, covers an order served, withdrawn or outbid by a better one. The direct sale is refused from the banner and from the wanted table, the new best order is drawn, and nothing is sold or paid. The banner, the table, Order already served and the Copy deck ("Un meilleur ordre vient d'arriver…") point to it. Settings behind an open form now also covers the wanted table, the Archive purchase, the Slot purchase and the order form's rarity minimums.
- **The Archive price could undercut a player's minimum** (abuse): decision 2.
- **The Archives were a laundering route with no signal** (abuse): staff keep which account entrusted each Archive copy, and players never see it. A Back-office signal flags an Archive purchase of a copy that an account tied to the buyer entrusted, and its row shows the purchase and the entrusting account.
- **Orders of banned or deleted players** (abuse): Participant removed now covers orders. They are withdrawn like bids: a banned owner's held PiCoins return to their balance, and a deleted owner's are destroyed with the balance. Their goals and orders stop counting as wanted. The Delete dialog names the open buy orders withdrawn.

## Goal colours

Goals 6, 7, 8 and 10 sat ΔE 6.1, 2.4, 3.2 and 5.0 (CIEDE2000) from the Légendaire's iridescence, which the "every reserved colour" rule had left out. The iridescence fills the pastel band, and a search of the sRGB cube found no pink or lilac at ΔE 12 or more. The hexes were redrawn to keep the contrast floors, ΔE 12 from every reserved colour (iridescence and danger text included) and from every other goal, and to avoid red-green merges:

| Goal | Was | Now | On panel / raised / number | Nearest reserved | Nearest goal |
|---|---|---|---|---|---|
| 6 | Citron #ffff8a | Moutarde #b8b000 | 7.7 / 6.6 / 8.8 | lime 12.3, Légendaire 12.8 | 10, 16.8 |
| 7 | Menthe #85ffda | Sarcelle #00b4bc | 6.9 / 5.9 / 7.8 | accent 17.0 | 1, 12.1 |
| 8 | Rose bonbon #f692c4 | Rose saumon #fca8b0 | 9.5 / 8.1 / 10.8 | danger text 12.0, iridescence-1 13.2 | 4, 12.2 |
| 10 | Lilas #d7a1f2 | Pistache #9cc474 | 8.8 / 7.5 / 10.0 | lime 12.0, primary 12.7 | 5, 15.6 |

Goals 1 to 5 predate the rule and were not changed: goal 3 sits ΔE 10.1 from capsule-duel and goal 5 sits 11.6 from iridescence-5, and DESIGN now says so. The colour-vision note was rewritten from a Machado 2009 simulation of the new palette. The worst red-green pair among the new goals is 9–10 deuteranopia at ΔE 5.0; the previous palette had pairs at 4.2. The worst pair overall is still 4–9 tritanopia at 2.2. The palette loses its pink and lilac, and goals 6 and 10 sit near the minimum distance from lime and gold; the author accepted the hexes on 2026-11-20 (decision 5).

## Spec changes needed

`spec-gameble.md` and `market-economy.md` must carry these; `ux-gameble.md`'s "Changes this run asks of the spec" points here.

**`spec-gameble.md`**

- **Wanted definition (CAP-44):** a card is wanted when it is missing from another player's current goals or when another player's eligible open buy order targets it. Each player counts once. Banned and deleted players and the viewer's own goals and orders do not count. Near-complete sets no longer count. Drop the stale Known limit "A near-complete set missing a Légendaire flags it as wanted". The privacy limit stays accepted, now naming custom sets and private players.
- **CAP-46:** drop the buy-now clause; the order form offers no buy-now. State that a direct sale always serves the best eligible order (best price, then oldest), never the seller's own, and that a sale is refused when that order changed after drawing. The best order shown to a buyer on the order form counts only orders placed more than an hour ago, never one from an account tied to the buyer, and shows only its price.
- **CAP-49:** drop "slots may also be listed in the shop"; in the spec's line matching `market-economy.md`'s Money, "PiCoins spent in the shop (Archive cards, slots)" becomes "PiCoins spent on Archive cards and slots", since slots are never sold in the shop.
- **Ceilings:** 10 goals (5 free, CAP-28), 10 custom sets (5 free; the player who held six keeps the sixth free, CAP-27) and 5 decks (3 free, CAP-40).
- **Orders of banned or deleted players:** withdrawn at once; a banned owner's held PiCoins are returned, a deleted owner's destroyed with the balance. Their goals and orders stop counting as wanted.
- **Export (Constraints, market and personal data):** the export includes buy orders, sales to orders, Archive purchases and bought slots.
- **Reachable rarities:** an order's reachable rarities are those of the minimums when it was placed, as CAP-30 has for listings; this is marked as an assumption in the UX.

**`market-economy.md`**

- **Charts:** the Destroyed row becomes "Stamps, commissions, Archive card and slot purchases, and a deleted account's balance (held order money included)".
- **Money:** "PiCoins spent in the shop (Archive cards, slots)" becomes "PiCoins spent on Archive cards and slots".
- **Setting bounds:** an Archive price is never below its rarity's player minimum price.
- **The shop:** a rarity whose Archive price is not set is absent from the shop, and there is no daily purchase limit.
- **Alt-account signals:** add "an Archive purchase of a copy that an account tied to the buyer entrusted". Staff keep the entrusting account of each Archive copy, never shown to players.
- **Average price and Sales in the feed:** a direct sale to an order counts in the edition's average price and follows the feed's rule for notable sales; an Archive purchase never makes a feed entry.

## New assumptions to confirm

These were added by this run and are tagged `[ASSUMPTION]`; copy is marked "to approve":

- Reopening Confier's second step shows the copies still set apart, or the market.
- The buyer's VOULUE tag also marks the viewer's own ordered games.
- The "listed above your order" bell line is one per order, has no name, and is removed when the listing ends; order lines count in the bell only.
- Wanted table: lines are ordered best order, then seekers, then value, with no paging. The phone dock holds TOUT CONFIER. A line that would not fit the cap is prefilled ENCHÈRES. The stamps may be paid from the same validation's proceeds.
- An order keeps running when its owner gets the game another way. A raised minimum brings the Archive price up with it.
- The goal suggestion names at most two cards, then "+ n". The PASSER DES ORDRES chain ends on the album with a one-line result.
- Bookmarks are capped at three or five per card, then a "+n" chip. "10" widens the small bookmark.
- Copy: the "DEMANDÉE" badge, field-refusal lines, "Un meilleur ordre vient d'arriver", the extended suspended banner, the slot price description, the Archive price refusal, and "à commander" in the goal line.

## Left open

- **Vos cartes voulues on every chip, and the Archive offers repeated** (rubric, low): should the panel show only on ANNONCES and MES VENTES? Should the grid's first row leave out the offers the Shop panel already shows, given that memlog entry 947 mixes them under every sort?
- **Best rival order spoofing** (abuse, medium): the hour and the tied accounts are settled (decision 6). Should cancelled money stay held for an hour, and should a quick-cancel signal be added?
- **Signals for the new flows** (abuse, medium): should an order sale be measured against the serving copy's rarity minimum, and should every sale signal include both direct-sale entry points? Should signals be added for spoofing, repeated listing and cancelling of a game, and goals that overlap a tied account's listings? Should the grouped wanted bell line return at most once per card per day?
- **Private players in the feed** (abuse, medium): direct sales and Archive purchases are settled (decision 7). Do private players' direct sales stay out of the feed?
- **Flagged sales in the average price** (abuse, medium): direct sales count in the average price (decision 7). Are sales between flagged accounts dropped from it?
- **Unusual order price** (abuse, medium): should an order price far above the lowest rarity it reaches ask a confirmation, reusing the Unusual maximum dialog, and from what threshold?
- **The seller's name on the buyer's SERVI line** (abuse, low): should "Vendue par <name>" become the edition and date alone, since a direct sale has no public listing?
- **"Les plus récentes" for Archive offers** (abuse, low): sort by week rather than by day, so the date of entrusting cannot be read?
- **A visitor's PASSER UN ORDRE** (accessibility, medium): the card detail's PASSER UN ORDRE for a visitor stays greyed with nothing else, under the visitors rule of 2026-10-20. The accessibility review asked for a sign-in line there, as the Annonce has.

Outside scope: Flow 8 still quotes amounts from before the division by 100 (1 150 000, 100 000, 50 000, 5 000).
