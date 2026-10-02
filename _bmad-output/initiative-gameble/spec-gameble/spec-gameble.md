---
id: SPEC-gameble
companions:
  - catalog-and-rarity.md
  - card-and-reveal.md
  - brotherhood-tone.md
  - later-roadmap.md
  - stack.md
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
  - **success:** Steam sign-in creates the account or reuses the one tied to that Steam account. No other sign-in method exists, and gameble stores no password.
- **CAP-2**
  - **intent:** The system builds a card catalog from the Steam catalog, keeping established games only.
  - **success:** An import run produces cards that match the inclusion and exclusion rules in `catalog-and-rarity.md`, each with its title, short description, store tags, sets and Steam image address, all stored in gameble's own database.
- **CAP-3**
  - **intent:** Every card has a rarity that reflects the game's prestige, so a player can guess why a card is rare.
  - **success:** Rarity is computed only from the game's Steam review score and review count, as specified in `catalog-and-rarity.md`. Metacritic is not used.
- **CAP-4**
  - **intent:** A player earns one free 5-card pack every 10 minutes, banking up to 10 unopened packs.
  - **success:**
    - Pack credit is computed server-side. Opening without a banked pack is refused, whatever the client does.
    - Packs accrue while the player is away, up to a cap of 10.
    - Draws pick a rarity tier first, then a card within it.
    - Opened cards are added to the player's collection, each copy carrying its minted rarity and season.
- **CAP-5**
  - **intent:** Opening a pack is a staged reveal that builds tension in proportion to rarity.
  - **success:** The reveal behaves as specified in `card-and-reveal.md` on desktop and mobile. "Flip all" never skips a legendary's reveal.
- **CAP-6**
  - **intent:** A player can browse their collection by set and see their progress in each set.
  - **success:** Each set shows owned / total distinct cards. A card in several sets counts in each. Duplicates are counted per card.
- **CAP-7**
  - **intent:** A player can open a card's detail view to see the game and its credits.
  - **success:** The detail view shows the title, short description, rarity, sets, publisher and copyright, and a link to the game's Steam store page. Card text appears in the player's UI language.
- **CAP-8**
  - **intent:** Each player has a public collection profile reachable by link.
  - **success:** A logged-out visitor opening the profile link sees that player's collection and set progress.
- **CAP-9**
  - **intent:** A player can share a pull as a link that previews nicely on Discord, X and WhatsApp.
  - **success:** Pasting the link on each of the three platforms shows a preview with the game's Steam image, the card title and its rarity. No image is generated.
- **CAP-10**
  - **intent:** Players can become friends through an invite link or a friend code.
  - **success:** Using a valid link or code creates a mutual friendship, visible to both players.
- **CAP-11**
  - **intent:** Friends can trade cards directly, one or several cards on each side, with no currency.
  - **success:**
    - The recipient can accept or decline a proposal.
    - The proposer can cancel it, and sets its expiry, up to 7 days.
    - On acceptance, all copies swap owners atomically with their minted rarity and season. If any copy is no longer owned, the trade fails without partial transfer.
    - Non-friends cannot trade.
- **CAP-12**
  - **intent:** The Brotherhood has a weekly shared goal that every player's pack openings advance.
  - **success:**
    - The target scales with the number of weekly active players.
    - A shared gauge shows progress.
    - When the goal is reached, every contributing player receives a rare pack.
- **CAP-13**
  - **intent:** A live Brotherhood feed shows what other players are doing, so the platform feels inhabited.
  - **success:**
    - The feed shows notable pulls, first discoveries of a card, and trades.
    - With few players, it falls back to lower-rarity events and is never empty while any activity exists.
- **CAP-14**
  - **intent:** A player can manage their personal data from their profile.
  - **success:** From the profile, a player can delete their account, export their data, and hide their public profile. Each action works end to end.
- **CAP-15**
  - **intent:** Players can report a username or profile, and a moderator can review reports in a back-office and ban accounts.
  - **success:**
    - A report appears in the back-office queue.
    - A ban made there blocks the account's sign-in and hides its public profile.
    - Only moderator accounts can reach the back-office.

## Constraints

- **No real money**, anywhere: no purchases, no ads, no cash-out.
- **French and English UI**, both complete at launch. Card text is available in every UI language. All repo text (code, comments, docs) is in English.
- **Cards are only pulled or traded.** Owning a game on Steam never grants its card.
- **Card copies:** every copy stores its minted rarity and season from day one, so a V2 market and V3 seasons need no migration.
- **Forkable engine:** the game engine (packs, rarity tiers, collection, trades, goals, feed) is independent of the catalog source. Steam is one adapter.
- **Open source.** Infrastructure components (queues, caches, streaming) are added only when measured load justifies them.
- **Stack:** Ruby on Rails and PostgreSQL, with React components embedded for highly interactive parts. Details are in `stack.md`.
- **Stateless services:** several app instances can run in parallel. Pack credit and trades are transactional in PostgreSQL.
- **Zero-downtime ready:** health checks, graceful shutdown, and backward-compatible (expand/contract) migrations.
- **CI/CD ready:** one reproducible container image per service, configuration by environment variables only, automated tests in CI from day one.
- **Separable processes:** the web app, the catalog importer and background workers are parts of one modular monolith that can be deployed separately.
- **Pack opening:** p95 latency < 200 ms.
- **Catalog source:** the Steam API, read only by offline import scripts that copy the data into gameble's database. Play never depends on a live Steam API call, and a card keeps its data if Steam changes or removes the game.
- **Images:** loaded from Steam's CDN, never copied or transformed. The publisher and copyright are shown on the card, and the site terms state there is no affiliation with Steam or Valve. There is no fallback art.
- **Bots:** edge bot protection from day one; trades are limited to friends.
- **Platforms:** responsive desktop and mobile web. Native store apps must remain possible later.
- **Tone and naming** follow `brotherhood-tone.md`.

## Non-goals

- Combat or any card battle mechanic.
- Sign-in methods other than Steam.
- Catalogs other than Steam.
- Back-office features beyond moderation (set creation is V3).
- Guilds.
- Any currency, auction house, card destruction, listing fee or sale commission (V2, see `later-roadmap.md`).
- Brotherhood Pass, seasonal catalog recompute, community-voted themed sets (V3).
- Bonuses from the player's Steam library, playtime or achievements (later).
- Curation of games delisted from Steam (later).
- Native App Store and Play Store apps.

## Success signal

The author plays gameble every day for a month alongside at least 10 active players, not all of them friends, and sees their pulls and trades appear in the Brotherhood feed.

## Assumptions

- Every player has a public profile by default; they can hide it (CAP-14).
- The weekly-goal reward is one rare pack per contributor.
- Multi-card trades are allowed in both directions (N cards for M cards).
- Per-tier draw odds start at ~70% common and ~20% for the second tier, with the rest shared, and are tuned in playtests.
- The card detail view links to the game's Steam store page (CAP-7).
- The live feed and goal gauge use Rails' built-in live updates; the exact mechanism is chosen in architecture.
- A card whose Steam image no longer loads still shows its frame and title.
- The copy never names a real company; publisher names appear only as card credits and set names.
- Card text translations come from Steam's own localized store text, imported once per UI language.

## Open Questions

- **Prestige formula (CAP-3):** how do Steam review score and review count combine into the 5 tiers? This is calibrated on real import data.
- **Sets in the MVP (CAP-6):** sets can later be created from Steam store tags, probably in a second phase. Do genre, decade and publisher sets, with per-set progress, ship in the MVP, or do sets wait for that phase?
- **Pack reveal (CAP-5):** `card-and-reveal.md` keeps the rarity glow from the brief. The paused UX work explored dust and a seal, and is being revisited for Steam art. Which one is the contract? This is settled when the UX files are adopted.
