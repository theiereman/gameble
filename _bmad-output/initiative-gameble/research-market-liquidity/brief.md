# Research brief: market liquidity vs free suggested peer trades

**Mode:** run here (native web research), unattended. **Date:** 2026-11-19.

## Decision this research serves

gameble is a free web trading card game (every card is a Steam game) with about 30 active players. Its currency (PiCoin) is closed and not real money: it is minted only when a player entrusts a card to the in-game Archives; its sinks are a listing stamp and a 10% commission. The player market runs auctions (12h, 24h, 3d) with optional buy-now, per-rarity minimum prices and an average price per edition. Friend-to-friend card trades are free, and the app suggests them by matching a player's set goals with friends' duplicates. Players use the suggested trades and ignore the market, which has almost no volume.

The author is considering promoting the market to a main navigation tab and demoting trades, to free a tab for a new live duel mode. The question: **what makes a player market attractive and liquid in a game with a tiny population, compared with free, suggested peer trades?**

## Research questions

1. **Market mechanisms (competitive):** which mechanisms create liquidity in thin markets: buy orders and standing bids (Steam Community Market, EVE Online, Path of Exile currency exchange), NPC or house market makers and system sell-back, fixed price vs auction, fees and their effect on volume.
2. **Trades vs market positioning and pushing demand (competitive):** how games that have both direct trades and a market position them (Pokémon TCG Pocket, Marvel Snap, MTG Arena, Hearthstone, Gods Unchained, Steam trading cards, Neopets, Eco), and how they push demand to players (wishlist matching, "someone wants your duplicate" notifications, crafting or trade-up sinks).
3. **User voice and economics of thin markets (user-voice + academic-lit):** players' complaints about empty or dead markets, how small or early-stage games bootstrap liquidity, and what market-design literature says about thickness and congestion.

## Choices made (unattended run)

- **Types:** competitive and user-voice, plus a little academic-lit on market thickness. Shape: explore (no candidate selection).
- **Pruned dimensions:** dropped the competitive pack's pricing, trajectory and messaging dimensions. They do not bear on how to design a market in a free game with no real money.
- **Effort:** standard preset with 3 researcher subagents running breadth-first, one per question above, depth 1 to 2 rounds, validation `normal`, red team off.
- **Firewall:** researchers receive only the questions and the decision context above; gameble's own code and planning documents are not used as evidence.
- **Freshness:** mechanism descriptions are accepted whatever their age when they come from official documentation, with the date flagged. Player sentiment older than about 18 months is flagged as dated, not discarded, because many relevant games (Gods Unchained, Neopets, early EVE) are old.
- **Output:** a short, decision-oriented `research-market-liquidity.md`: the mechanisms, the evidence, how each applies at about 30 players, and what to avoid. No HTML briefing because the run is unattended.
