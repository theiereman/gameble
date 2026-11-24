---
type: change-proposal
title: "The Archive shop becomes the PiCoin sink, priced by a thermostat"
date: 2026-11-24
trigger: author, manual test of 1.4.0-rc.2 on 2026-11-24; forged in forge-archive-shop
mode: batch
scope: moderate
status: approved
approved: 2026-11-24, by the author ("ok enchaine tout automatiquement" after the forge)
supersedes: the weekly 12-card showcase and the falling-price list drafted earlier the same day
---

# Sprint Change Proposal: the Archive shop becomes the PiCoin sink

## 1. Issue summary

Testing 1.4.0-rc.2, the author found the Archive shop too cheap (sets too easy to complete), open to rebuying one card in a loop, and blind to other buyers' purchases. A day of patches (showcase, budget list, falling price, per-rarity caps) went in circles because the shop had no measurable purpose. The forge (`forge-archive-shop/forge-archive-shop.md`) fixed one, with production figures and outside research (`forge-archive-shop/recon-archive-shop.md`).

Evidence (production, 2026-11-24, read-only): 43k–56k PiCoins minted a week, 1.8k–9k destroyed (4–16 %); 80k in circulation for 21 active players; Archive stock 4,620 Common editions, 804 Uncommon, 67 Rare, 1 Epic, 1 Legendary; 90-day sale medians Common 34 (4 sales), Uncommon 100, Rare 150, Epic 1,654, Legendary none.

## 2. Impact analysis

- **Spec:** CAP-48 rewritten (below). `market-economy.md`: the Archive price rule moves from a multiple of the entrustment value to the thermostat.
- **Code (uncommitted work in the chevron-cues worktree):** the falling price, the list budget and the 1/5/10 weekly caps go; the per-rarity per-period purchase caps leave the shop and the back-office (columns kept, dropped in a later contract migration); a list-size setting comes in; the Archive price becomes a free reference, prefilled.
- **Epics and Legendaries as Brotherhood auctions:** a listing with no player seller whose payment is destroyed. It touches the auction close, notifications, feed and views, so it ships as its own story after the fixed-price list.
- **UX:** the tile shows the week's price only; no "tomorrow" line, no "N left" cap line.

## 3. Recommended approach

Direct adjustment inside 1.4 (the shop is not in production yet). Effort: the fixed-price list and thermostat, about a day; the Brotherhood auctions, a separate story. Risk: the thermostat may chase low demand upward; floors and the wanted-first list contain it, and the back-office alert hands the faucet to the author.

## 4. Detailed change

**CAP-48, success (new):**
- The shop exists to destroy PiCoins: its measure is PiCoins destroyed over minted (market and shop, rolling 4 weeks), set point 60 %.
- Every Monday 00:00 UTC the Brotherhood lists the same editions for every player, 20 by default (back-office): up to 10 wanted cards, most sought first, then Rares up to 10, then Uncommons and Commons drawn for the week. Epics and Legendaries are not in this list.
- An edition keeps one price all week: a coefficient times its rarity's reference. The reference is the rarity's median auction sale over 90 days, the top and bottom tenth left out, from 5 sales; under 5 sales it is the back-office reference (free, prefilled Common 35, Uncommon 100, Rare 150, Epic 1,650, Legendary 4,000).
- Each Monday the coefficient moves toward the set point by at most 20 %, from 6, between 2 and 10, and a price never falls under 5 times the entrustment value. At 10 with the ratio still under 60 %, the economy alert proposes lowering the entrustment amounts.
- Epics (up to 5 a week) and the Legendary (1 a week) go to Brotherhood auctions on the market, about 48 hours, reserve at 2 times the reference and never under 5 times the entrustment value, payment destroyed.
- A player buys an edition once a week and at most 5 Archive cards a week. A purchase updates every open market and shop page at once; a sold-out edition's place in the market panel is refilled.
- The back-office shows the list's sell-through.

## 5. Implementation handoff

Minor/moderate: Developer, in the chevron-cues worktree, two commits: (1) fixed-price list, thermostat, limits, back-office reference and list size, texts; (2) Brotherhood auctions for Epics and Legendaries. Success: domain tests for the thermostat, the list order and the limits; the shop's system tests green; "How it works" and the shop page describe the rules.
