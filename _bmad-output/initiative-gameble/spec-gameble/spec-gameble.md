---
id: SPEC-gameble
companions:
  - catalog-and-rarity.md
  - brotherhood-tone.md
  - later-roadmap.md
  - ../ux-gameble/DESIGN.md
  - ../ux-gameble/EXPERIENCE.md
  - ../architecture-gameble/architecture-gameble.md
sources:
  - ../brief-gameble/brief-gameble.md
  - ../brief-gameble/addendum.md
  - ../ux-gameble/ux-gameble.md
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
  - **success:** An import run produces cards that match the inclusion and exclusion rules in `catalog-and-rarity.md`, each with its title, short description, release date, store tags, sets and Steam image address, all stored in gameble's own database. An administrator starts an import by hand and can watch its progress.
- **CAP-3**
  - **intent:** Every card has a rarity that reflects the game's prestige, so a player can guess why a card is rare.
  - **success:** Rarity is computed only from the game's Steam review score and review count, as specified in `catalog-and-rarity.md`. Metacritic is not used.
- **CAP-4**
  - **intent:** A player earns one free 5-card pack every 10 minutes, banking up to 10 unopened packs, and opens them one at a time.
  - **success:**
    - A new account starts with 10 packs banked.
    - Packs are opened one by one; there is no bulk opening.
    - Packs are drawn in advance on the server; opening only delivers them.
    - A new player gets at least one sapphire or better by their 10th pack.
    - Pack credit is computed server-side. Opening without a banked pack is refused, whatever the client does.
    - Packs accrue while the player is away, up to a cap of 10.
    - Draws pick a rarity tier first, then a card within it.
    - Opened cards are added to the player's collection, each copy carrying its minted rarity and season.
- **CAP-5**
  - **intent:** Opening a pack is a staged reveal with two surprises per card: its rarity, then the game.
  - **success:**
    - The reveal behaves as specified in `EXPERIENCE.md` on desktop and mobile: dust by the age of the game, wipe to see the rarity seal, flip to see the game.
    - "Flip all" never skips a legendary's reveal.
    - The five cards join the collection when the pack is opened. Leaving in the middle of a reveal loses nothing and does not resume.
- **CAP-6**
  - **intent:** A player can browse their collection by set, see their progress in each set, and see which cards are missing.
  - **success:**
    - The sets are those defined in `catalog-and-rarity.md`: publisher sets, tomes and "best rated of the year" sets.
    - Each set shows owned / total distinct cards. A card in several sets counts in each. Duplicates are counted per card.
    - An empty slot names the missing game.
- **CAP-7**
  - **intent:** A player can open a card's detail view to see the game and its credits.
  - **success:** The detail view shows the title, short description, release year, rarity, minted season, sets, publisher, a notice that the game and its image belong to their owners, and a link to the game's Steam store page. Card text appears in the player's UI language. The description appears only in this view, not on the card.
- **CAP-8**
  - **intent:** Each player has a public collection profile reachable by link.
  - **success:** A logged-out visitor opening the profile link sees that player's collection and set progress, titled with the player's Steam persona name, refreshed at each sign-in.
- **CAP-9**
  - **intent:** A player can share a pull as a link that previews nicely on Discord, X and WhatsApp.
  - **success:** Pasting the link on each of the three platforms shows a preview with the card title and its rarity, and no image at all.
- **CAP-10**
  - **intent:** Players can become friends through an invite link or a friend code.
  - **success:** Using a valid link or code creates a mutual friendship, visible to both players.
- **CAP-11**
  - **intent:** Friends can trade cards directly and asynchronously, one or several cards on each side, with no currency.
  - **success:**
    - The recipient can accept a proposal, decline it, or answer with a counter-proposal. A counter-proposal can be accepted, declined or countered in turn.
    - Neither player needs to be connected at the same time as the other.
    - The proposer can cancel it, and sets its expiry, up to 7 days.
    - A card placed in an open trade is reserved: it cannot be used elsewhere until the trade ends.
    - Two friends have at most one open trade at a time.
    - On acceptance, all cards swap owners atomically with their minted rarity and season.
    - Non-friends cannot trade.
- **CAP-12**
  - **intent:** The Brotherhood has a weekly shared goal that every player's pack openings advance, and trades to a lesser degree.
  - **success:**
    - The target scales with the number of weekly active players.
    - A shared gauge shows progress.
    - When the goal is reached, every contributing player receives a rare pack.
- **CAP-13**
  - **intent:** A live Brotherhood feed shows what other players are doing, so the platform feels inhabited.
  - **success:**
    - The feed shows notable pulls, first discoveries of a card, trades and reposts (CAP-19).
    - The feed is readable without an account.
    - With few players, it falls back to lower-rarity events and is never empty while any activity exists.
    - A signed-in player has a Friends tab showing only their friends' pulls, trades and reposts.
- **CAP-14**
  - **intent:** A player can manage their personal data from their profile.
  - **success:** From the profile, a player can delete their account, export their data, and hide their public profile. Each action works end to end.
- **CAP-15**
  - **intent:** Players can report a username or profile, and a moderator can review reports in a back-office and ban accounts.
  - **success:**
    - A report appears in the back-office queue.
    - A ban made there blocks the account's sign-in and hides its public profile.
    - Only staff accounts can reach the back-office. Moderators review reports and ban; administrators also run the catalog import and publish a season.
- **CAP-16**
  - **intent:** A player who comes back gets a daily bonus.
  - **success:** Once a day, a player can collect one small booster of 3 cards with better odds than a normal pack (no common; emerald 70 %, sapphire 24 %, amethyst 5 %, legendary 1 %). A second collection the same day is refused, whatever the client does. The day changes at midnight UTC.
- **CAP-17**
  - **intent:** A player has simple achievements that mark their progress.
  - **success:** An achievement is granted when its condition is met and shows as earned on the achievements screen.
- **CAP-18**
  - **intent:** A visitor without an account can look at everything that needs no account, but cannot act.
  - **success:**
    - Signed out, a visitor can open the attic, the feed, public profiles, card details and the sets with their empty slots.
    - Opening a pack, trading and collecting the bonus are refused without an account and lead to Steam sign-in.
- **CAP-19**
  - **intent:** A player can repost a card they own to the Brotherhood feed to show it off, so flexing a collection happens in gameble rather than on Discord.
  - **success:**
    - Any card the player owns can be reposted, whatever its rarity, with no limit on the number of reposts.
    - A repost appears in the global feed and in the Friends tab of the player's friends.
    - Reposting a card the player does not own is refused, whatever the client does.
    - Feed events carry no reactions or comments.

## Constraints

- **No real money**, anywhere: no purchases, no ads, no cash-out.
- **French and English UI**, both complete at launch. Card text is available in every UI language. All repo text (code, comments, docs) is in English.
- **Steam profile data:** only the persona name is stored, as personal data covered by export, deletion and reports.
- **Cards are only pulled or traded.** Owning a game on Steam never grants its card.
- **Card copies:** a player can own several copies of a card. Copies are counted per card and season, so each keeps the rarity and season it was minted with, and a V2 market and V3 seasons need no migration.
- **Forkable engine:** the game engine (packs, rarity tiers, collection, trades, goals, feed) is independent of the catalog source. Steam is one adapter.
- **Open source.** Infrastructure components (queues, caches, streaming) are added only when measured load justifies them.
- **Architecture:** the rules of `architecture-gameble.md` bind every build. The stack is Ruby on Rails and PostgreSQL, with React components embedded for the pack reveal and the trade board; versions and deployment are in that file.
- **Stateless services:** several app instances can run in parallel. Pack credit and trades are transactional in PostgreSQL.
- **Zero-downtime ready:** health checks, graceful shutdown, and backward-compatible (expand/contract) migrations.
- **CI/CD ready:** one reproducible container image, run as web, jobs and import processes; configuration by environment variables only; automated tests in CI from day one.
- **Separable processes:** the web app, the catalog importer and background workers are parts of one modular monolith that can be deployed separately.
- **Pack opening:** p95 latency < 200 ms.
- **Catalog source:** the Steam Web API (keyed, batched), read only by offline import scripts; the keyless store API is not used that copy the data into gameble's database. Play never depends on a live Steam API call, and a card keeps its data if Steam changes or removes the game.
- **Images:** loaded from Steam's CDN, never copied. They are pixelated and reduced to 16 colours in the browser, at display time. The publisher is shown with a notice that the game and its image belong to their owners, and the site terms state there is no affiliation with Steam or Valve. There is no fallback art.
- **Look and behaviour** follow `DESIGN.md` and `EXPERIENCE.md`.
- **Bots:** edge bot protection from day one; trades are limited to friends.
- **Platforms:** responsive desktop and mobile web. Native store apps must remain possible later.
- **Tone and naming** follow `brotherhood-tone.md`.

## Non-goals

- Combat or any card battle mechanic (a "knowledge battles" idea is parked in `later-roadmap.md`).
- A guide or tutorial.
- Bulk pack opening.
- Live trades with both players connected (later).
- Card marks: favourite, to trade, personal categories (later).
- Reactions or comments on feed events (later).
- Sets built from Steam store tags (later).
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

- Every player has a public profile by default; they can hide it (CAP-14).
- The weekly-goal reward is one rare pack per contributor.
- Multi-card trades are allowed in both directions (N cards for M cards).
- Per-card draw odds are those in `catalog-and-rarity.md` and are tuned in playtests.
- The card detail view links to the game's Steam store page (CAP-7).
- A card whose Steam image no longer loads still shows its frame and title.
- The copy never names a real company; publisher names appear only as card credits and set names.
- Card text translations come from Steam's own localized store text, imported once per UI language.
- A repost is a past event: it stays in the feed after the card is traded away, and disappears with a hidden or banned profile (CAP-14, CAP-15).

## Open Questions

- **Prestige formula (CAP-3):** how do Steam review score and review count combine into the 5 tiers? This is calibrated on real import data.
- **Achievements (CAP-17):** which achievements exist?
- **Weekly goal pack (CAP-12):** what are the odds of the weekly goal's rare pack?
- **Weekly goal (CAP-12):** how much does a trade count compared with a pack opening?
- **Feed flooding (CAP-19):** with unlimited reposts, how does the global feed stay readable: grouping, a per-player cap in the global view, or nothing until measured?
