---
id: SPEC-gameble
companions:
  - catalog-and-rarity.md
  - brotherhood-tone.md
  - later-roadmap.md
  - ../ux-gameble/DESIGN.md
  - ../ux-gameble/EXPERIENCE.md
  - ../ux-gameble/ux-gameble.md
  - ../architecture-gameble/architecture-gameble.md
sources:
  - ../brief-gameble/brief-gameble.md
  - ../brief-gameble/addendum.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# gameble — MVP

## Why

The idea is a vision, and it seizes an opportunity. Gamers have no real trading card game (TCG) made of their games: Steam Trading Cards drop only from games you own, are sold for real money, and have no pack-opening moment. "Collect Wikipedia" card games (WikiMasters, Wikigacha) prove the loop is fun (pull a pack, land something prestigious, show it off, trade it), but they are slow under load, flat to open, generic-looking, padded with hollow features, and pushy about money.

gameble is an open-source passion project, and the game its author wants to play: that loop, done properly, where every card is a Steam game. It serves French- and English-speaking gamers who have a Steam account. Its lasting edge is not execution but community: every player belongs to *La Grande Confrérie des Gamblers* (the Brotherhood). The first players are the author's friends who play WikiMasters and love video games.

## Capabilities

- **CAP-1**
  - **intent:** A visitor can sign in with their Steam account, and only that way, to get a player account.
  - **success:**
    - Steam sign-in creates the account or reuses the one tied to that Steam account. No other sign-in method exists, and gameble stores no password.
    - The only link to Steam's sign-in is Valve's official "Sign in through Steam" image, unmodified. A game-styled call to action that needs an account opens a sign-in panel holding one title line and that image.
    - Signing in lands on the hub; signing out lands on the hub, signed out.
- **CAP-2**
  - **intent:** The system builds a card catalog from the Steam catalog, keeping established games only.
  - **success:** An import run produces cards that match the inclusion and exclusion rules in `catalog-and-rarity.md`, each with its title, short description, release date, genre, store tags, sets and Steam image address, all stored in gameble's own database. An administrator starts an import by hand and can watch its progress.
- **CAP-3**
  - **intent:** Every card has a rarity that reflects the game's prestige, so a player can guess why a card is rare.
  - **success:**
    - Rarity is computed only from the game's Steam review score and review count, as specified in `catalog-and-rarity.md`. Metacritic is not used.
    - The five tiers, from the most common, are Commune, Peu commune, Rare, Épique and Légendaire. Each shows with its name, colour and shape, never by colour alone.
- **CAP-4**
  - **intent:** A player earns one free 5-card pack every 10 minutes, banking up to 10 unopened packs, and opens them one at a time.
  - **success:**
    - A new account starts with 10 packs banked.
    - Packs are opened one by one; there is no bulk opening.
    - Packs are drawn in advance on the server; opening only delivers them.
    - No pack promises a rarity. The only guarantee: a new player gets a Rare or better by their 10th pack, with no visible sign.
    - Pack credit is computed server-side. Opening without a banked pack is refused, whatever the client does.
    - Packs accrue while the player is away, up to a cap of 10.
    - Draws pick a rarity tier first, then a card within it.
    - Opened cards are added to the player's collection, each copy carrying its minted rarity and season.
- **CAP-5**
  - **intent:** Opening a pack is a staged reveal: the five cards are dealt face down, and each reveals its rarity and its game in one surprise.
  - **success:**
    - The reveal behaves as specified in `EXPERIENCE.md` on desktop and mobile: a single click, tap or Enter reveals a card's rarity and game together. There is no dust, rarity seal or wipe.
    - "Tout révéler" reveals the remaining cards, and a Légendaire still plays its full sequence.
    - The five cards join the collection when the pack is opened. Leaving in the middle of a reveal loses nothing and does not resume.
- **CAP-6**
  - **intent:** A player sees at a glance which sets they are completing, opens one as an album, and sees which cards are missing.
  - **success:**
    - The sets are those defined in `catalog-and-rarity.md`: themes, franchises, studios, hall of fame sets and the UFOs. Every card belongs to at least one set.
    - The collection opens on the player's sets in progress, sorted by closeness to their next tier or completion, then a short "to discover" row, then a search over every set.
    - A set opens as an album: owned cards, an empty slot naming each missing game, and its tiers or its completion.
    - Each set shows owned / total distinct cards. A card in several sets counts in each. Duplicates are counted per card.
    - Theme and hall of fame sets have three tiers (bronze, silver, gold); franchise, studio and UFO sets are only complete or not.
    - The grid of every card, with its filters and search, stays reachable from the collection.
- **CAP-7**
  - **intent:** A player sees a card's face at a glance and can open its detail view to see the game and its credits.
  - **success:**
    - The card face shows the title, publisher, cover, genre (its main theme), release year, rarity (shape and name) and card number, and no stats.
    - The card number is the card's number within its season, without a total ("S1 · #4 215").
    - The detail view shows the title, publisher, rarity, genre, release year, short description, minted season, sets, card number, copies owned, and a link to the game's Steam store page.
    - Card text appears in the player's UI language. The description appears only in the detail view, not on the card.
- **CAP-8**
  - **intent:** Each player has a collection profile reachable by link, visible to whom they choose.
  - **success:**
    - Visibility is public (the default), friends only, or private.
    - Public: a logged-out visitor opening the profile link sees that player's collection and set progress.
    - Friends only: only the player's friends see it. Private: nobody else sees it.
    - The profile is titled with the player's Steam persona name, refreshed at each sign-in.
- **CAP-9**
  - **intent:** A player can share a pull as a link that previews nicely on Discord, X and WhatsApp.
  - **success:** Pasting the link on each of the three platforms shows a preview with the card title and its rarity, and no image at all. The shared page shows the card only, never who shared or owns it.
- **CAP-10**
  - **intent:** Players can become friends through an invite link or a friend code.
  - **success:** A valid link or code sends an invitation. Once the other player accepts it, the friendship exists and is visible to both. They can also ignore it.
- **CAP-11**
  - **intent:** Friends can trade cards directly and asynchronously, one or several cards on each side, with no currency.
  - **success:**
    - A proposal holds an offer and a request, and is sent only when each side holds a card.
    - At most 4 different cards per side. With several copies of a card, the player chooses how many to place: on their side, up to copies owned minus copies reserved in other trades; on the friend's side, up to what the friend owns.
    - The recipient can accept a proposal, decline it, or answer with a counter-proposal that may change both sides. A counter-proposal can be accepted, declined or countered in turn.
    - Neither player needs to be connected at the same time as the other.
    - The proposer can cancel it. A proposal expires after a fixed 7 days.
    - A card a player offers in an open trade is reserved: it cannot be used elsewhere until the trade ends. Cards requested from the friend are not reserved; acceptance checks they are still free.
    - Two friends have at most one open trade at a time.
    - On acceptance, all cards swap owners atomically with their minted rarity and season.
    - Non-friends cannot trade.
- **CAP-12**
  - **intent:** The Brotherhood has a weekly shared goal that every player's pack openings advance, and trades to a lesser degree.
  - **success:**
    - The week starts Monday 00:00 UTC. The target is the previous week's active players (at least one booster opened) × 50, never below 200.
    - A booster opened counts 1; a completed trade counts 1, once for both players.
    - A shared gauge shows progress.
    - When the goal is reached, every contributing player receives a reward booster of 5 cards with at least one Épique or better, held outside the bank's cap of 10 in its own zone.
- **CAP-13**
  - **intent:** A live Brotherhood feed shows what other players are doing, so the platform feels inhabited.
  - **success:**
    - The feed shows notable pulls, first discoveries of a card, trades, reposts (CAP-19), set completions and set tiers reached.
    - The feed is readable without an account.
    - With few players, it falls back to lower-rarity events and is never empty while any activity exists.
    - A signed-in player has a Friends tab showing only their friends' pulls, trades and reposts.
    - The LIVE ticker shows pulls of Épique or better, first discoveries, trades, set completions and set tiers reached, never reposts.
- **CAP-14**
  - **intent:** A player can manage their personal data from their profile.
  - **success:** From the profile, a player can delete their account, export their data, and set their profile's visibility (public, friends only, private). Each action works end to end.
- **CAP-15**
  - **intent:** Players can report a username or profile, and a moderator can review reports in a back-office and ban accounts.
  - **success:**
    - A report appears in the back-office queue.
    - A ban made there blocks the account's sign-in and hides its public profile.
    - Only staff accounts can reach the back-office. Moderators review reports and ban; administrators also run the catalog import and publish a season.
- **CAP-16**
  - **intent:** A player who comes back gets a daily bonus.
  - **success:**
    - Once a day, a player can collect one small booster of 3 cards with better odds than a normal pack (no Commune; Peu commune 70 %, Rare 24 %, Épique 5 %, Légendaire 1 %). It joins their bank.
    - A second collection the same day is refused, whatever the client does. The day changes at midnight UTC.
    - When the bank holds 10 packs, the claim stays disabled until a pack is opened; nothing is lost.
- **CAP-17**
  - **intent:** A player has simple achievements that mark their progress.
  - **success:**
    - An achievement is granted when its condition is met and shows as earned on the achievements screen.
    - Ten ship at launch: first booster, first Épique, first Légendaire, first complete set, first trade, 10, 100 and 500 boosters opened, three complete sets, first repost.
- **CAP-18**
  - **intent:** A visitor without an account can look at everything that needs no account, but cannot act.
  - **success:**
    - Signed out, a visitor can open the hub, the feed, public profiles, card details and the sets with their empty slots.
    - Opening a pack, trading and collecting the bonus are refused without an account and lead to Steam sign-in.
- **CAP-19**
  - **intent:** A player can repost a card they own to the Brotherhood feed to show it off, so flexing a collection happens in gameble rather than on Discord.
  - **success:**
    - Any card the player owns can be reposted, whatever its rarity, with no limit on the number of reposts.
    - A repost appears in the global feed and in the Friends tab of the player's friends.
    - Reposting a card the player does not own is refused, whatever the client does.
    - Feed events carry no reactions or comments.
- **CAP-20**
  - **intent:** A player earns card backs and chooses the one their face-down cards wear.
  - **success:**
    - Every account starts with the "Standard" card back.
    - More are unlocked by reaching gold on a theme or hall of fame set (one back per such set), contributing to a successful weekly goal, some achievements, and events or seasons. A locked back states its unlock condition.
    - The player picks one active back in the profile; it applies from the next pack opened.
    - Only the player sees it: on their own face-down cards at opening, and faded on the detail of a card they do not own.
    - The back catalogue is in `DESIGN.md`.
- **CAP-21**
  - **intent:** A player can see which of their friends are around.
  - **success:** Friends see each other's status: online, current activity, or last seen. The friends menu item shows how many friends are online.
- **CAP-22**
  - **intent:** A player shows their collecting through a profile title and dresses their menus with a rare theme.
  - **success:**
    - Completing a franchise, studio or UFO set, and each tier of a theme or hall of fame set, unlocks a profile title built from one template per kind that needs no grammatical agreement ("Complétiste · Dark Souls"; Apprenti, Adepte, Maître for tiers).
    - The player picks one active title; it shows on their profile, in the feed and in trades.
    - Reaching gold on 3, 10 and 25 sets unlocks a menu theme each: an accent colour applied to the interface, with contrast checked. Only the player sees it.

## Constraints

- **No real money**, anywhere: no purchases, no ads, no cash-out.
- **French and English UI**, both complete at launch. Card text is available in every UI language. The English copy is translated by AI from the French. All repo text (code, comments, docs) is in English.
- **Launch scope:** CAP-20 and CAP-22 are built after the public launch; every other capability is live at launch.
- **Steam profile data:** only the persona name is stored, as personal data covered by export, deletion and reports.
- **Player-facing words:** the interface says "booster" for pack, "réserve" for bank and "objectif communautaire" for the weekly goal. The spec and the code keep pack, bank and weekly goal.
- **Cards are only pulled or traded.** Owning a game on Steam never grants its card.
- **Card copies:** a player can own several copies of a card. Copies are counted per card and season, so each keeps the rarity and season it was minted with, and a V2 market and V3 seasons need no migration.
- **Forkable engine:** the game engine (packs, rarity tiers, collection, trades, goals, feed) is independent of the catalog source. Steam is one adapter.
- **Open source.** Infrastructure components (queues, caches, streaming) are added only when measured load justifies them.
- **Architecture:** the rules of `architecture-gameble.md` bind every build. The stack is Ruby on Rails and PostgreSQL, with React components embedded for the booster and the trade board; versions and deployment are in that file.
- **Stateless services:** several app instances can run in parallel. Pack credit and trades are transactional in PostgreSQL.
- **Zero-downtime ready:** health checks, graceful shutdown, and backward-compatible (expand/contract) migrations.
- **CI/CD ready:** one reproducible container image, run as web, jobs and import processes; configuration by environment variables only; automated tests in CI from day one.
- **Separable processes:** the web app, the catalog importer and background workers are parts of one modular monolith that can be deployed separately.
- **Pack opening:** p95 latency < 200 ms.
- **Catalog source:** the Steam Web API (keyed, batched), read only by offline import scripts that copy the data into gameble's database; the keyless store API is not used. Play never depends on a live Steam API call, and a card keeps its data if Steam changes or removes the game.
- **Images:** loaded from Steam's CDN, never copied. In the browser, at display time, the vertical cover is cropped to the card's art box, pixelated at 2 CSS px per image pixel and reduced to about 32 colours, with no dithering. The publisher is shown on the card; the ownership notice is on the legal page. There is no fallback art.
- **Legal:** the notice that gameble has no affiliation with Steam or Valve, the ownership notice (in substance: « Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons. »), the terms of use and the privacy notice live on a legal page reached from "Mentions légales" (profile and public page footer).
- **Look and behaviour** follow `DESIGN.md` and `EXPERIENCE.md`. The back-office is outside them: plain functional style, behaviour unchanged, designed later.
- **Reduced motion:** an in-app "Animations réduites" setting follows the system preference by default. When on, it also stops the LIVE ticker and every looping or blinking effect.
- **Bots:** edge bot protection from day one; trades are limited to friends.
- **Platforms:** responsive desktop and phone web. Phones are portrait only, with no landscape layout and no overlay; the installed web app is locked to portrait by its manifest. On every size the interface is never scaled: pages scroll and reflow by width. Native store apps must remain possible later.
- **Tone and naming** follow `brotherhood-tone.md`.

## Non-goals

- Combat or any card battle mechanic (a "knowledge battles" idea is parked in `later-roadmap.md`).
- A guide or tutorial.
- Bulk pack opening.
- Any input at opening that improves the odds (later).
- Live trades with both players connected (later).
- Card marks: favourite, to trade, personal categories (later).
- Reactions or comments on feed events (later).
- Sign-in methods other than Steam.
- Catalogs other than Steam.
- Back-office features beyond moderation (set creation is V3).
- Guilds.
- Numbered or otherwise unique individual copies of a card.
- Any currency, auction house, card destruction, listing fee or sale commission (V2, see `later-roadmap.md`).
- Brotherhood Pass, seasonal catalog recompute, community-voted themed sets (V3).
- Bonuses from the player's Steam library, playtime or achievements (later).
- Curation of games delisted from Steam (later).
- Native App Store and Play Store apps.

## Success signal

The author plays gameble every day for a month alongside at least 10 active players, not all of them friends, and sees their pulls and trades appear in the Brotherhood feed.

## Assumptions

- Per-card draw odds are those in `catalog-and-rarity.md` and are tuned in playtests.
- Card text translations come from Steam's own localized store text, imported once per UI language.
- A repost is a past event: it stays in the feed after the card is traded away, and disappears with a hidden or banned profile (CAP-14, CAP-15).

## Open Questions

- **Card backs (CAP-20):** beyond one back per theme or hall of fame set at gold, which goal, achievement and event backs ship, and does every successful weekly goal grant one?
- **Shared cards and visibility (CAP-8, CAP-9):** `EXPERIENCE.md` assumes a shared card page of a friends-only or private profile shows "not available". Should a share link work for those players? Since 2026-10-03 the shared page shows the card only, with no owner, so it no longer reveals a profile.
- **Sets on real data (CAP-6):** the minimum size of franchise and studio sets, the reliability of Steam's franchise field, the hall of fame thresholds and the tier percentages are set on staging data; the UFOs stay under about 5 % of the catalog, else the theme list changes.
