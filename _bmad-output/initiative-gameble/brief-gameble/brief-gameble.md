---
title: "Product Brief: gameble"
status: final
created: 2026-10-01
updated: 2026-10-01
---

# Product Brief: gameble

## Executive Summary

gameble is a free, French-language web card game where every card is a subject from French Wikipedia. Every 10 minutes, players open a 5-card booster pack. The more famous a subject is worldwide, the rarer its card. Players show off their best pulls and trade with friends.

WikiMasters and Wikigacha proved the concept, but they are slow, flat to open, generic-looking and pushy about money. gameble fixes the execution. Its lasting edge, though, is community: every player joins *La Grande Confrérie des Gamblers* (the Brotherhood). It is an open-source passion project, and success means its author plays it daily alongside at least ten other players.

## The Problem

Existing "collect Wikipedia" games (WikiMasters, Wikigacha) undermine the loop's best moments:

- **They're slow under load.** The pack you were excited to open hangs, and the hype dies.
- **Opening a pack is flat.** Cards appear one after another, with no build-up or reveal. That wastes the most satisfying moment in any trading card game (TCG).
- **They have no identity.** Generic, template-looking sites with no art direction make cards feel cheap and not worth showing off.
- **Their extra features are broken or hollow.** Guilds bug out, and combat is a trivia quiz you can google.
- **They push in-game purchases** with no visible legal framework.

## The Solution

On desktop and mobile, gameble is built around the genre's three key moments, which current games short-change:

- **The pull.** One free pack every 10 minutes. Cards land face down, glowing by rarity; you flip them one by one, and a legendary gets a reveal worth waiting for. A "flip all" button keeps the hundredth pack quick, but never skips a legendary.
- **The brag.** Rarity reflects fame: the more Wikipedias cover a subject, the rarer its card, with a one-tier boost for subjects hugely popular in France. So the Eiffel Tower is legendary, and anyone can tell why at a glance. Every collection has a public profile, and every pull can be shared as a link with a rich preview on Discord, X or WhatsApp.
- **The trade.** Friends swap cards directly: "my Napoléon for your Kaamelott", proposed, accepted or declined. No currency, no fees.

Each card frames the article's credited Wikimedia Commons photo in gameble's house style, with its family colour and rarity effect. Articles without a photo get designed fallback art, never a blank. Cards fall into a dozen families (People, Places & monuments, Film & TV, Video games, Animals…), each with its own progress to chase.

## What Makes This Different

Execution (holding the load, a pack opening worth the wait, a real art direction) is gameble's short-term edge, but rivals can catch up.

The lasting difference is **the feeling of belonging to a community**. Every player is a member of the Brotherhood, and the game makes that visible:

- **Shared goals.** Weekly community objectives ("Brothers, open 100,000 packs this week") fill a common gauge. Every contributor gets a rare booster, so just playing counts as contributing.
- **A living Brotherhood.** A live feed of notable pulls ("Brother Thomas just pulled the Eiffel Tower — legendary") and "first discoverer" honours make other players feel present.
- **A game the community shapes.** Players will propose and vote on themed sets.

Also: legible rarity (worldwide fame, not Wikigacha's article-quality tiers), French niches, friends-first trading, and no money at all (no purchases, unlike WikiMasters; no ads, unlike Wikigacha).

## Who This Serves

- **Primary: French-speaking friend groups.** Discord servers, WhatsApp groups and colleagues who enjoy showing off a great pull and haggling over trades. Gamer or not, the unit is the group: one player shares a legendary, and the friends join to trade.
- **Launch beachhead: disappointed WikiMasters and Wikigacha players.** They already love the concept, are tired of slow, flat or pay-pushing versions, and will bring their groups along.

## Success Criteria

gameble is a passion project. Success doesn't depend on scale.

- **Minimal success (the one that matters):** the author plays it every day for a month, with at least 10 active players, not all of them friends. He sees their pulls and trades happening around him, and feels he is on a platform with other people.
- **Signs the community is taking hold:** most weekly Brotherhood goals are reached, trades happen every week, and pulls get shared outside gameble.
- **Infrastructure bonus:** traffic is welcome but not required. If it comes, opening a pack stays instant (p95 < 200 ms).

## Scope

### MVP (one release, ~2–4 weeks)

- **Accounts:** sign-in with Discord or Google.
- **Catalog:** imported from French Wikipedia, filtered to recognisable subjects (~100k–300k cards), with rarity, family and art computed for each.
- **Packs:** one free 5-card pack every 10 minutes, with the rarity-scaled reveal.
- **Collection:** browsable by family, with progress.
- **Social:** public profiles and share-a-pull links; friends (invite link or code) and direct card-for-card trades.
- **Brotherhood:** weekly goals scaled to active players, and the live feed.
- **French UI**, with i18n in place for English later.
- **Bot protection from day one:** edge protection, plus a server-side pack limit.

### Later

- **V2 — Auction house:** a player-run market with a closed in-game currency, gated by account seniority (see addendum).
- **V3 — Seasons and community content:** the parody *Brotherhood Pass*, the seasonal catalog recompute, community-voted themed sets managed in a back-office, and foil variants for featured and good articles.
- **Native apps** on the App Store and Play Store.

### Out

- **Combat:** trivia-style fights are hollow.
- **Real money** in any form.
- **Guilds.**
- **Rewards for editing Wikipedia:** they would invite vandalism.

## Vision

In two to three years, the Brotherhood is a lasting French-speaking community with its own rituals: seasons everyone waits for, themed sets its members voted into existence, and legends like "the first Brother to pull the Mona Lisa".

gameble is open source, and its game engine is independent of where the cards come from. Anyone can fork it to run their own card game on another catalog.

## Risks

| Risk | Severity | Response |
|---|---|---|
| Empty-community feel: solo players with no friends to trade with, or too few players overall | High | Weekly goals scale to active players; the feed falls back to rares, first discoveries and trades, so it never looks empty; family progress gives solo players a reason to stay |
| Importing Wikipedia (2.7M articles, Wikidata, pageviews, images) is harder than expected | High | Build from Wikimedia dumps rather than live APIs; tune thresholds on real data |
| Scope creep: the MVP has already grown from days to weeks | Medium | Accepted; MVP scope is frozen, and new ideas go to V2 |
| WikiMasters fixes its technical problems | Medium | See What Makes This Different |
| Bots farm packs through mass accounts or scripts | Medium, rising with traffic | Bot protection (see Scope), friends-only trades in the MVP, market seniority gate in V2 |
