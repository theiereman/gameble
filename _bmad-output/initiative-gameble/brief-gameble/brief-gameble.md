---
title: "Product Brief: gameble"
status: final
created: 2026-10-01
updated: 2026-10-02
---

# Product Brief: gameble

## Executive Summary

gameble is a free web trading card game (TCG) where every card is a Steam game. Every 10 minutes, players open a 5-card booster pack drawn from the whole Steam catalog. The more acclaimed a game is, the rarer its card. Players show off their best pulls and trade with friends. gameble ships in French and English.

"Collect Wikipedia" card games such as WikiMasters proved that this loop is fun. gameble brings it to gamers, with cards they care about and the execution those games lack. Its lasting edge is community: every player joins *La Grande Confrérie des Gamblers* (the Brotherhood). It is an open-source passion project and the game its author wants to play. Success means he plays it daily alongside at least ten other players.

## Why gameble

Gamers have no real TCG made of their games. Steam Trading Cards drop only from games you already own, are sold for real money, and have no pack-opening moment.

WikiMasters and Wikigacha show the pull-brag-trade loop works with a huge catalog, but they undermine its best moments. gameble treats each flaw as a lesson:

- **They're slow under load.** The pack you were excited to open hangs, and the hype dies.
- **Opening a pack is flat.** Cards appear one after another, with no build-up or reveal. That wastes the most satisfying moment in any TCG.
- **They have no identity.** Generic, template-looking sites with no art direction make cards feel cheap and not worth showing off.
- **Their extra features are broken or hollow.** Guilds bug out, and combat is a trivia quiz you can google.
- **They push in-game purchases** with no visible legal framework.

## The Solution

On desktop and mobile, gameble is built around the genre's three key moments:

- **The pull.** One free pack every 10 minutes, and ten waiting at sign-up. Cards land face down under dust that tells the game's age. Wiping a card shows a seal with its rarity; flipping it shows the game. A legendary is truly rare, about one every 400 packs, and gets a reveal worth waiting for. A "flip all" button keeps the hundredth pack quick, but never skips a legendary.
- **The brag.** Rarity reflects prestige: Steam review score and number of reviews. A universally acclaimed classic is legendary, and any gamer can tell why at a glance. Every collection has a public profile, and every pull can be shared as a link on Discord, X or WhatsApp.
- **The trade.** Friends swap cards directly on a face-to-face board: "my Portal 2 for your Hades", proposed, accepted, declined or countered, without both being connected at once. No currency, no fees.

Each card frames the game's official Steam art in gameble's pixel-art house style, with a rarity colour and the publisher's credit. Cards are grouped into sets, each with its own progress to chase and empty slots that name what is missing: publisher sets, "tomes" of about thirty games per genre, and the ten best-rated games of each year.

Cards are only ever pulled or traded. They never come from a player's own Steam library.

## What Makes This Different

Execution (holding the load, a pack opening worth the wait, a real art direction) is gameble's short-term edge, but rivals can catch up.

The lasting difference is **the feeling of belonging to a community**. Every player is a member of the Brotherhood, and the game makes that visible:

- **Shared goals.** Weekly community objectives ("Brothers, open 100,000 packs this week") fill a common gauge, fed by pack openings and trades. Every contributor gets a rare booster, so just playing counts as contributing.
- **A living Brotherhood.** A live feed of notable pulls ("Brother Thomas just pulled Portal 2 — legendary") and "first discoverer" honours make other players feel present. Anyone can read it, even without an account.
- **A game the community shapes.** Players will propose and vote on themed sets.

Compared with Steam Trading Cards: the whole catalog rather than the games you own, a real pack opening, legible prestige rarity, no money at all, and a satirical tone.

## Who This Serves

- **Primary: gamers who like to collect.** French- and English-speaking players with a Steam account, especially collectors and TCG fans, who enjoy showing off a great pull and haggling over trades.
- **First players:** the author's friends who play WikiMasters, love video games and have a Steam account.

Steam games are a niche next to Wikipedia. That is accepted: the niche reaches a different public, one the author belongs to.

## Success Criteria

gameble is a passion project. Success doesn't depend on scale.

- **Minimal success (the one that matters):** the author plays it every day for a month, with at least 10 active players, not all of them friends. He sees their pulls and trades happening around him, and feels he is on a platform with other people.
- **Signs the community is taking hold:** most weekly Brotherhood goals are reached, trades happen every week, and pulls get shared outside gameble.
- **Infrastructure bonus:** traffic is welcome but not required. If it comes, opening a pack stays instant (p95 < 200 ms).

## Scope

### MVP (one release, ~2–4 weeks)

- **Accounts:** Steam sign-in only.
- **Catalog:** imported through the Steam API into gameble's own database. Only games with at least 500 Steam reviews and a vertical Steam image are included (an estimated 10k–20k cards). Each card gets its rarity, sets and art.
- **Packs:** one free 5-card pack every 10 minutes, ten at sign-up, opened one at a time with the dust-and-seal reveal. A new player is sure to find a sapphire or better in those first ten.
- **Collection:** browsable by set, with progress and named empty slots.
- **Social:** public profiles and share-a-pull links; friends (invite link or code) and direct trades with counter-proposals.
- **Brotherhood:** weekly goals scaled to active players, and the live feed.
- **Coming back:** a daily bonus booster and simple achievements.
- **Without an account:** a visitor can look at everything, but cannot open packs or trade.
- **French and English UI**, both complete at launch.
- **Bot protection from day one:** edge protection, plus a server-side pack limit.

### Later

- **V2 — Auction house:** players destroy cards for a closed in-game currency and bid on rarer ones in a player-run market, gated by account seniority (see addendum).
- **V3 — Seasons and community content:** the parody *Brotherhood Pass*, the seasonal catalog recompute (new games enter at season start), and community-voted themed sets managed in a back-office.
- **Steam library bonuses**, earned on the cards of games a player owns, from playtime and achievements.
- **Live trades, card marks** (favourite, to trade, categories) **and sets built from Steam tags.**
- **Native apps** on the App Store and Play Store.

### Out

- **Library as collection:** owning a game on Steam never gives its card.
- **Combat:** trivia-style fights are hollow. A friend's "knowledge battles" idea is parked in the addendum.
- **Real money** in any form.
- **Guilds.**
- **A guide, opening every pack at once, numbered copies of a card.**

## Vision

In two to three years, the Brotherhood is a lasting community of gamers with its own rituals: seasons everyone waits for, themed sets its members voted into existence, and legends like "the first Brother to pull Half-Life 2".

gameble is open source, and its game engine is independent of where the cards come from. Anyone can fork it to run their own card game on another catalog.

## Risks

| Risk | Severity | Response |
|---|---|---|
| Empty-community feel: solo players with no friends to trade with, or too few players overall | High | Weekly goals scale to active players; the feed falls back to rares, first discoveries and trades, so it never looks empty; set progress gives solo players a reason to stay |
| A publisher or Valve asks for game art to be removed | Medium | Accepted with no fallback: gameble is free and makes no money, so the author judges an objection unlikely. Publisher and copyright are shown on every card, and no affiliation with Valve is claimed |
| The Steam API throttles the catalog import (about 200 store requests per 5 minutes) | Medium | Import as an offline batch, never at play time; a full pass may take hours to days; measure on real data early |
| Everything depends on Steam: sign-in, catalog and art | Medium | Accepted, as there is no alternative. Import scripts copy the catalog data into gameble's own database, so cards keep their data if Steam changes or removes a game. Images are not copied: they stay on Steam's servers |
| Scope creep: the MVP has grown from days to weeks, ships in two languages, and gained sets, a daily bonus, achievements and a trade board on 2026-10-02 | High | The 2–4 week estimate is re-checked once the stories are sliced; new ideas go to V2 |
| Bots farm packs through mass accounts or scripts | Medium, rising with traffic | Steam-only sign-in raises the cost of an account; bot protection (see Scope), friends-only trades in the MVP, market seniority gate in V2 |
