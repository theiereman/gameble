# Forged idea: the Brotherhood's shop

Status: hardened, 2026-11-24. Research: `recon-archive-shop.md`. Prod figures: `.memlog.md`.

## Purpose
- The shop is the PiCoin sink. Success = PiCoins destroyed / minted (market + shop, rolling 4 weeks), set point **60 %** (today 4–16 %).
- It sells what players look for (wanted cards), not what overflows.

## Rules
- **Weekly list, same for everyone, renewed Monday 00:00 UTC: 20 editions** (back-office setting). Fill order: up to 10 wanted cards (most sought first), then Rares up to 10, then Uncommons then Commons drawn for the week.
- **Fixed price all week** = coefficient × reference of the rarity.
- **Reference**: median of the rarity's sales over 90 days, 10 % trimmed each side, from 5 sales; under 5 sales, a free back-office reference, prefilled Common 35, Uncommon 100, Rare 150, Epic 1650, Legendary 4000.
- **Thermostat** sets the coefficient each Monday from last week's ratio: start 6×, ±20 % a week at most, between 2× and 10×, never under 5× the entrustment value. At 10× with the ratio still under 60 %, the back-office economy alert proposes lowering the entrustment amounts; the shop never goes further on its own.
- **Epics (up to 5/week) and the Legendary (1/week)** are sold as Brotherhood auctions on the regular market, about 48 h, reserve = floor (2× reference), payment destroyed.
- **Per player**: one copy of an edition per week, at most 5 shop purchases a week.
- Real-time stock and panel refill for everyone; the back-office shows the list's sell-through (under 50 % shrink it, over 90 % grow it).

## Dropped, and why
- Nightly price drop and the "tomorrow" line: waiting game, end bunching, complexity; a price above the market already stops the rush.
- List budget at 50 % of minted PiCoins: quantity is fixed, the price does the regulating.
- Per-rarity caps per period and the "N left" line: redundant; replaced by 5 purchases a week.
- Rarest-first list, 12-card showcase, fixed 5×/6× multiples: guesses with no measure behind them.

## Known weak points
- Raising prices when the ratio is low can lower purchases; the floor and the wanted-first list limit it, not remove it.
- 10 Rares a week empty the 67 Rares in stock in ~7 weeks unless players entrust more.
- 60 % and 20 editions are starting values: no source sets a sink target.
- Brotherhood auctions need a listing with no player seller whose payment is destroyed: a real change to the auction code.
