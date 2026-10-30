---
id: SPEC-gameble
companions:
  - catalog-and-rarity.md
  - achievements.md
  - brotherhood-tone.md
  - later-roadmap.md
  - lore.md
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

gameble is an open-source passion project, and the game its author wants to play: that loop, done properly, where every card is a Steam game. It serves French- and English-speaking gamers who have a Steam account. Its lasting edge is not execution but community: every player belongs to *La Grande Confrérie des Gameblers* (*The Great Brotherhood of Gameblers*, the Brotherhood). The first players are the author's friends who play WikiMasters and love video games.

## Capabilities

- **CAP-1**
  - **intent:** A visitor can sign in with their Steam account, and only that way, to get a player account.
  - **success:**
    - Steam sign-in creates the account or reuses the one tied to that Steam account. No other sign-in method exists, and gameble stores no password.
    - The only Steam-branded sign-in is Valve's official "Sign in through Steam" image, unmodified. The game-styled sign-in buttons (the landing's « Embarquer sur le pont » and its boarding module, the public card page's « Ouvrir mes premières capsules ») sign in through Steam directly; beside each of them, a line says that signing in accepts the terms of use and acknowledges the privacy notice. There is no sign-in panel (author, 2026-10-20).
    - Signing in lands on the hub. Signed out, the root (/fr, /en), signing out and deleting the account land on the visitor landing (CAP-24); a signed-in player never sees it. A visitor reaches only the pages CAP-18 lists; there is no signed-out hub (author, 2026-10-20).
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
    - Packs accrue while the player is away, up to a cap of 10 standard packs.
    - Every pack that is not a standard pack (today the daily bonus and the weekly goal reward) waits in a special reserve with no cap, counted as one total apart from the standard reserve; the hub shows both counts, and the pack screen switches between the two reserves. A special pack shows its origin, by name and colour, wherever it is opened; within a reserve the oldest pack opens first, whatever its origin (author, 2026-10-28).
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
    - A set is the same set from one season to the next (same kind and key). A copy of a game counts for the set whatever season it was minted in. Only the published season's sets earn tiers; a tier earned stays earned, marked with the season it was earned in, and can be earned again in a later season with that season's mark.
    - A set's progress is read against the published season's set and may drop when the set grows; it is shown as new cards to find, never as a loss. A game that leaves a set stops counting for that set only.
    - The collection shows one card per game: its best minted rarity among the copies owned, the copies owned across editions, and a mark when several editions are held. The total counter counts distinct games across editions and never drops when a season is published.
    - Every set has one to five tiers before completion, named by rank (Novice, Apprenti, Adepte, Expert, Maître) counted from the top, so the last before completion is always Maître and a larger set adds lower ranks (table in catalog-and-rarity.md); a set of 3 or 4 cards is only complete or not.
    - The grid of every card, with its filters and search, stays reachable from the collection.
    - The collection counter in the top bar opens, right under it, a rarity legend: for each rarity, the distinct cards owned and the total the game holds, for the published season and overall, then the same totals across rarities; choosing a rarity filters the card grid on it (#221, author, 2026-10-30).
- **CAP-7**
  - **intent:** A player sees a card's face at a glance and can open its detail view to see the game and its credits.
  - **success:**
    - The card face shows the title, publisher, cover, genre (its main theme), release year, rarity (shape and name) and card number, and no stats.
    - The card number is the card's number within its season, without a total ("S1 · #4 215").
    - The detail view shows the title, publisher, rarity, genre, release year, short description, minted season, sets, card number, copies owned, the editions owned grouped by rarity (folded beyond a few lines), and a link to the game's Steam store page.
    - Card text appears in the player's UI language. The description appears only in the detail view, not on the card.
- **CAP-8**
  - **intent:** Each player has a profile reachable by link that shows off their collection, visible to whom they choose.
  - **success:**
    - Visibility is public (the default), friends only, or private.
    - Public: a logged-out visitor opening the profile link sees that player's showcase, stats, latest achievements and started sets, and can open the albums of their sets, read-only (author, 2026-10-20: a visitor reaches public profiles with their albums).
    - The player puts up to five owned cards in their showcase and orders them; with none chosen the profile shows no showcase.
    - Friends only: only the player's friends see it, and they trade as usual.
    - Private: nobody else sees it, friends included. The player keeps their friends and can still add new ones, but a friend sees nothing beyond the friendship: no presence or activity, no collection, no profile, and no trade either way. A private player still sees what their friends show them.
    - The profile is titled with the player's Steam persona name, refreshed at each sign-in.
- **CAP-9**
  - **intent:** A player can share a pull as a link that previews nicely on Discord, X and WhatsApp.
  - **success:**
    - Pasting the link on each of the three platforms shows a preview with the card title, its rarity and a generated image of the card (its Steam art, title and rarity), one image per card and language, rendered once and served from storage (author, 2026-10-30).
    - A failed render leaves the text-only preview; the page never waits for a render.
    - The shared page and its image show the card only, never who shared or owns it.
- **CAP-10**
  - **intent:** Players can become friends through an invite link, a friend code, or another player's profile.
  - **success:** A valid link or code, or the add-friend action on a player's profile, sends an invitation. Once the other player accepts it, the friendship exists and is visible to both. They can also ignore it.
- **CAP-11**
  - **intent:** Friends can trade cards directly and asynchronously, one or several cards on each side, with no currency, and the game suggests the trades that move their active goals forward.
  - **success:**
    - A proposal holds an offer and a request. At every send, proposal or counter-proposal, the side asked of the other player holds at least one card; the sender's own side may be empty, which asks the other player to choose what they want in return.
    - At most 4 different cards per side. With several copies of a card, the player chooses how many to place: on their side, up to copies owned minus copies reserved in other trades; on the friend's side, up to what the friend owns.
    - The recipient can accept a proposal, decline it, or answer with a counter-proposal that may change both sides. A counter-proposal can be accepted, declined or countered in turn.
    - A trade with an empty side cannot be accepted: the recipient chooses at least one card from the sender's collection and counters, or declines, and the screen says so where accepting would be. Cards never change hands one way.
    - Neither player needs to be connected at the same time as the other.
    - The proposer can cancel it. A proposal expires after a fixed 7 days.
    - A card a player offers in an open trade is reserved: it cannot be used elsewhere until the trade ends. Cards requested from the friend are not reserved; acceptance checks they are still free.
    - Two friends have at most one open trade at a time.
    - On acceptance, all cards swap owners atomically with their minted rarity and season.
    - Non-friends cannot trade, and neither can a private player (CAP-8): nobody proposes to them and they propose to nobody. Where a trade would start, the screen says trades are closed while that profile is private, naming whose profile it is.
    - Going private cancels the player's open trades at once: every reserved copy is released and the friend sees the trade closed.
    - For the missing cards of a player's active goals (CAP-28), the game lists the friends who hold a spare copy: a copy beyond their first of that game, not reserved in an open trade.
    - Mutual suggestions come first: the friend spares a card the player's goals miss, and the player spares one the friend's goals miss.
    - Starting a trade from a suggestion opens a proposal with its cards placed; it then runs under the rules above.
    - A private player is never suggested and sees no suggestions; suggestions name friends only. The Brotherhood presents itself as the go-between (`brotherhood-tone.md`).
- **CAP-12**
  - **intent:** The Brotherhood has a weekly shared goal that every player's pack openings advance, and trades to a lesser degree.
  - **success:**
    - The week starts Monday 00:00 UTC. The target is the previous week's active players (at least one pack opened) × 125, never below 500 (author, 2026-10-29).
    - A pack opened counts 1; a completed trade counts 1, once for both players.
    - A shared gauge shows progress.
    - The goal's panel and its reward notice speak as the Brotherhood (`brotherhood-tone.md`); their copy is in `EXPERIENCE.md`.
    - When the goal is reached, every contributing player receives a reward pack of 5 cards with at least one Épique or better; it joins the special reserve, which has no cap, so a full standard reserve never refuses it.
- **CAP-13**
  - **intent:** A live Brotherhood feed shows what other players are doing, so the platform feels inhabited.
  - **success:**
    - The feed shows notable pulls, first discoveries of a card, trades, reposts (CAP-19), set completions and set tiers reached.
    - The feed is readable without an account.
    - With few players, it falls back to lower-rarity events and is never empty while any activity exists.
    - A signed-in player has a Friends tab showing only their friends' pulls, trades and reposts; a private friend's never show (CAP-8).
    - The LIVE ticker shows pulls of Épique or better, first discoveries, trades, set completions and set tiers reached, never reposts.
    - The set tiers and completions one opening reaches make one feed entry and one ticker item, naming the highest and the count.
    - The first player to discover a card of a season is its pioneer, shown in the card's details to every later viewer allowed to see that player's profile (CAP-8), a signed-out visitor included when that profile is public (author, 2026-10-21); anyone else sees « anonyme », as for a banned or deleted account. Each edition has its own pioneer.
- **CAP-14**
  - **intent:** A player can manage their personal data from their profile.
  - **success:** From the profile, a player can delete their account, export their data, and set their profile's visibility (public, friends only, private); going private cancels their open trades (CAP-11) and says so before applying. Each action works end to end.
- **CAP-15**
  - **intent:** Players can report a username or profile, and a moderator can review reports in a back-office and ban accounts.
  - **success:**
    - A report appears in the back-office queue.
    - A ban made there blocks the account's sign-in and hides its public profile.
    - Only staff accounts can reach the back-office. Moderators review reports and ban; administrators also run the catalog import and publish a season.
- **CAP-16**
  - **intent:** A player who comes back gets a daily bonus.
  - **success:**
    - Once a day, a player can collect one small pack of 3 cards with better odds than a normal pack (no Commune; Peu commune 70 %, Rare 24 %, Épique 5 %, Légendaire 1 %). It joins the special reserve (CAP-4).
    - A second collection the same day is refused, whatever the client does. The day changes at midnight UTC.
    - The claim is never refused because the standard reserve is full.
- **CAP-17**
  - **intent:** A player earns achievements that mark their progress and their memorable moments, in the Brotherhood's voice.
  - **success:**
    - An achievement is granted once, when its condition is met, and shows as earned on the achievements screen.
    - Conditions read cumulative progress, one capsule's contents, streaks of openings or days, the collection with the games' metadata (studio, release year), and community actions (discoveries, reposts, repeated trades with one player). The catalog is in `achievements.md`.
    - Every achievement shows a title in the Brotherhood's tone, a short condition and a flavor text, in French and English (`brotherhood-tone.md`).
    - The ten launch achievements (first pack, first Épique, first Légendaire, first complete set, first trade, 10, 100 and 500 packs opened, three complete sets, first repost) are renamed in that tone; their conditions are unchanged and no player loses one they earned (author, 2026-10-30).
    - A new achievement is granted at its release to every player whose recorded history already meets it; one with no recorded history counts from its release.
    - An achievement rewards with recognition and, for some, a card back (CAP-20); never with a pack or a currency.
- **CAP-18**
  - **intent:** A visitor without an account can look at the game's public pages, but cannot act.
  - **success:**
    - Signed out, a visitor reaches only the landing, Toutes les cartes and its card detail (every card's face, with no ownership data), the public card page, public profiles with their albums, the activity feed read-only, Comment ça marche, the legal page and invitation links. Every other page, the hub and the collection included, leads to the landing (author, 2026-10-20).
    - An action that needs an account shows greyed and disabled. Opening a pack, trading and collecting the bonus are refused without an account, whatever the client does (author, 2026-10-20).
    - A visitor signs in only through Steam (CAP-1), with the line that signing in accepts the terms of use and the privacy notice (author, 2026-10-20).
- **CAP-19**
  - **intent:** A player can repost a card they own to the Brotherhood feed to show it off, so flexing a collection happens in gameble rather than on Discord.
  - **success:**
    - Any card the player owns can be reposted, whatever its rarity, with no limit on the number of reposts.
    - A repost appears in the global feed and in the Friends tab of the player's friends, unless the player's profile hides it (CAP-8).
    - Reposting a card the player does not own is refused, whatever the client does.
    - Feed events carry no reactions or comments.
- **CAP-20**
  - **intent:** A player earns card backs and chooses the one their face-down cards wear.
  - **success:**
    - Every account starts with the "Standard" card back.
    - More are unlocked by reaching a theme or hall of fame set's back tier, its first tier at or above half its cards (one back per such set), contributing to a successful weekly goal, the hardest achievements (`achievements.md`), and events or seasons. A locked back states its unlock condition. A back earned on a set carries the mark of each season it was earned in; the player picks which season's mark the active back wears.
    - The player picks one active back on the Personalization page in one step; it applies from the next pack opened. Each earned back says how it was earned (which set and season, weekly goal or achievement), and a locked one how to earn it (author, 2026-10-30).
    - Only the player sees it, on their own face-down cards at opening: never on the detail of a card, nor on another player's cards or profile (author, 2026-10-28).
    - The back catalogue is in `DESIGN.md`.
- **CAP-21**
  - **intent:** A player can see which of their friends are around.
  - **success:** Friends see each other's status: online, current activity, or last seen. A private friend (CAP-8) shows "profil privé" instead, and never counts among those online. The friends menu item shows how many friends are online.
- **CAP-22**
  - **intent:** A player shows their collecting through a profile title and dresses their menus with a rare theme.
  - **success:**
    - Each tier of a set and its completion unlock a profile title built from a template that needs no grammatical agreement: the tier's rank for a tier ("Adepte · Roguelike"), "Complétiste" for completion ("Complétiste · Dark Souls"). Bronze, silver and gold reached in an earlier season give the titles Apprenti, Adepte and Maître, the same titles as the Apprenti, Adepte and Maître tiers: a set has one title per rank, earned by either (author, 2026-10-19). A title is earned once per set and rank, whatever the seasons; it shows the latest season it was earned in.
    - The player picks one active title; it shows on their profile, in the feed and in trades.
    - Completing 3, 10 and 25 sets, of any kind, unlocks a menu theme each: an accent colour applied to the interface, with contrast checked. Only the player sees it.
- **CAP-23**
  - **intent:** When a new season is published, a returning player receives the Brotherhood's seasonal allocation: the tiers they reached in the season that ended, the card backs and achievements they unlocked in it, and their tiers in the next season.
  - **success:**
    - At a player's first visit after a publication, before the hub and before any opening, a dedicated screen recaps the season that ended: the tiers reached during it and, in a section of their own, the card backs and achievements unlocked during it (author, 2026-10-28; weekly goal rewards stay off the screen, and the section is omitted when the player unlocked neither).
    - A second section, "Vos paliers dans la saison suivante", lists the tiers the player still meets in the new season's sets, received at once.
    - Tiers carried into the new season are never celebrated at an opening or announced in the feed; an opening or a trade celebrates only the tiers it crosses itself.
    - No sentence heads the screen: only its title names the season.
    - A player with no card from an earlier season, traded ones included, sees no allocation.
    - A tier shows no season mark and no count of seasons (author, 2026-10-19), and no season chip appears in the collection grid.
- **CAP-24**
  - **intent:** A signed-out visitor meets a landing that gives the Brotherhood's mission, says what gameble is and makes them want to play.
  - **success:**
    - Signed out, /fr and /en show the landing in their language; its sign-in actions, « Embarquer sur le pont » included, sign in through Steam directly (CAP-1), and it links Toutes les cartes and Comment ça marche, the visitor's way to the pages CAP-18 lists (author, 2026-10-20).
    - It shows live activity from the game (the feed's latest entries, the season, the weekly goal) and sets out how the game works, what there is to unlock, the open-source project with its call for artists, narrators and developers through the repository, and the free, ad-free, data-respecting model kept alive by support.
    - It works on phone and desktop under the enforced CSP, with its own « Animations réduites » switch for visitors, remembered and carried into the account at sign-in.
    - Look, copy and behaviour follow `DESIGN.md` and `EXPERIENCE.md` (Landing).
- **CAP-25**
  - **intent:** A visitor sees where the game is going: what is done, in progress and to come.
  - **success:**
    - The landing's roadmap shows epics and, under each, a few player-facing stories with their status (done, in progress, to come).
    - Its milestones are created automatically, one per epic of the BMad initiative; staff curate them in the back-office (player-facing wording in both languages, visibility, status, order, and the stories under each); a roadmap left stale is accepted.
    - A link leads to the full roadmap page, designed later.
- **CAP-26**
  - **intent:** Every player is welcomed by the Brotherhood once, with the story of how the games came back.
  - **success:**
    - At a new player's first arrival, and at the next visit of a player whose account existed before it shipped, a short welcome message from the Brotherhood shows in their language, on desktop and phone; its copy is in `EXPERIENCE.md`.
    - It never shows again, at later sign-ins or on another device, and does not stack with the sign-in welcome notice.
    - It changes no mechanic: the player can start collecting at once.
- **CAP-27**
  - **intent:** A player composes sets of their own from the cards they want and follows them like the game's sets.
  - **success:**
    - A player creates, renames, edits and deletes custom sets: 3 to 50 games of the catalog each, owned or not, at most 10 per player (author, 2026-10-30).
    - A custom set shows owned / total distinct cards and opens as an album with an empty slot naming each missing game; a copy counts whatever edition it was minted in.
    - It shows the rank tiers a game set of its size has (`catalog-and-rarity.md`), with no reward: no title, back, celebration, feed line or seasonal allocation.
    - Only its author sees a custom set or its name (author, 2026-10-30).
    - A player can create one Steam library set: the catalog games they own on Steam, with no size cap, synced with their library once a day. It is a special set, apart from the 10 custom sets: it cannot be an active goal (CAP-28) and never feeds trade suggestions (CAP-11). It grants no card. When Steam does not share the library (game details not public), the screen says so (author, 2026-10-30).
- **CAP-28**
  - **intent:** A player picks a few sets to aim at, and the game keeps their progress and missing cards in front of them.
  - **success:**
    - A player holds up to five active goals at once, among the game's sets and their own custom sets, the Steam library set excepted, and changes them freely (#64, author, 2026-10-30).
    - Each goal shows its progress, and its missing cards are highlighted wherever the collection shows them.
    - The bridge shows the player's goals. The profile shows their goals on game sets, under its visibility (CAP-8); a goal on a custom set never shows there (author, 2026-10-30).
    - Goals never change draw odds nor guarantee a card: pack draws are the same with or without goals.

## Constraints

- **No real money**, anywhere: no purchases, no ads, no cash-out.
- **French and English UI**, both complete at launch. Card text is available in every UI language. The English copy is translated by AI from the French. All repo text (code, comments, docs) is in English.
- **Launch scope:** CAP-20, CAP-22 and CAP-23 are built after the public launch; every other capability up to CAP-26 is live at launch. CAP-23 is live before the second season is published in production. Release 1.1.0 ships CAP-27, CAP-28 and the 2026-10-30 changes to CAP-6, CAP-9, CAP-17 and CAP-20; the trade suggestions of CAP-11 may follow in a later release.
- **Landing ship conditions:** CAP-24 and CAP-25 go live only once the lore text exists in French and English (`lore.md`), the pioneer (CAP-13) is built, the repository is public with a license file, the roadmap's milestones are created from the initiative's epics and curated by staff in the back-office, and the app uses JetBrains Mono.
- **Steam profile data:** only the persona name is stored, as personal data covered by export, deletion and reports, and, while a player keeps a Steam library set (CAP-27), the catalog games of their library, covered by export and deletion.
- **Player-facing words:** the interface says "capsule" for pack (French and English), "réserve" for bank and "objectif communautaire" for the weekly goal, and keeps "carte" / "card" (in the lore, an archive card: `lore.md`). The spec, the code, the database, stored events and URLs keep pack, bank and weekly goal.
- **Cards are only pulled or traded.** Owning a game on Steam never grants its card.
- **Card copies:** a player can own several copies of a card. Copies are counted per card and season, so each keeps the rarity and season it was minted with, and a V2 market needs no migration. The minted season is the copy's edition. Draws give only the published season's cards; earlier editions change hands only by trade.
- **Forkable engine:** the game engine (packs, rarity tiers, collection, trades, goals, feed) is independent of the catalog source. Steam is one adapter.
- **Open source.** Infrastructure components (queues, caches, streaming) are added only when measured load justifies them.
- **Architecture:** the rules of `architecture-gameble.md` bind every build. The stack is Ruby on Rails and PostgreSQL, with server-rendered pages and Hotwire, Stimulus included, for every screen; versions and deployment are in that file.
- **Stateless services:** several app instances can run in parallel. Pack credit and trades are transactional in PostgreSQL.
- **Zero-downtime ready:** health checks, graceful shutdown, and backward-compatible (expand/contract) migrations.
- **CI/CD ready:** one reproducible container image, run as web, jobs and import processes; configuration by environment variables only; automated tests in CI from day one.
- **Separable processes:** the web app, the catalog importer and background workers are parts of one modular monolith that can be deployed separately.
- **Pack opening:** p95 latency < 200 ms.
- **Catalog source:** the Steam Web API (keyed, batched), read only by offline import scripts that copy the data into gameble's database, except a player's own library, read by a background job for their Steam library set (CAP-27); the keyless store API is not used. Play never depends on a live Steam API call, and a card keeps its data if Steam changes or removes the game.
- **Images:** loaded from Steam's CDN, never copied, except the shared link's preview image (CAP-9), rendered from the Steam art and stored by gameble. In the browser, at display time, the vertical cover is cropped to the card's art box, pixelated at 2 CSS px per image pixel and reduced to about 32 colours, with no dithering. The publisher is shown on the card; the ownership notice is on the legal page. There is no fallback art.
- **Legal:** the notice that gameble has no affiliation with Steam or Valve, the ownership notice (in substance: « Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons. »), the terms of use and the privacy notice live on a legal page reached from "Mentions légales" (profile, public page footer and landing footer; author, 2026-10-20).
- **Look and behaviour** follow `DESIGN.md` and `EXPERIENCE.md`. The back-office is outside them: plain functional style, behaviour unchanged, designed later.
- **Reduced motion:** an in-app "Animations réduites" setting follows the system preference by default. When on, it also stops the LIVE ticker and every looping or blinking effect. Signed-out visitors get the same switch on the landing (CAP-24).
- **Bots:** edge bot protection from day one; trades are limited to friends.
- **Platforms:** responsive desktop and phone web. Phones are portrait only, with no landscape layout and no overlay; the installed web app is locked to portrait by its manifest. On every size the interface is never scaled: pages scroll and reflow by width. Native store apps must remain possible later.
- **Tone and naming** follow `brotherhood-tone.md`; the world follows `lore.md`. Both derive from GitHub issue #57, which is the reference on the lore.

## Non-goals

- Combat or any card battle mechanic (a "knowledge battles" idea is parked in `later-roadmap.md`).
- A guide or tutorial.
- Bulk pack opening.
- Any input at opening that improves the odds (later).
- Live trades with both players connected (later).
- Gifts: giving cards with nothing in return.
- A discussion window on trades, or any free-text message between players (later, see `later-roadmap.md`).
- Card marks: favourite, to trade, personal categories (later).
- Reactions or comments on feed events (later).
- Sign-in methods other than Steam.
- Catalogs other than Steam.
- Back-office features beyond moderation (set creation is V3).
- Guilds.
- Numbered or otherwise unique individual copies of a card.
- Any currency, auction house, card destruction, tax or fee (listing fee, sale commission, a levy on trades) (V2, see `later-roadmap.md`).
- Brotherhood Pass, community-voted themed sets (V3).
- Bonuses from the player's Steam library, playtime or achievements (later).
- Curation of games delisted from Steam (later).
- Native App Store and Play Store apps.
- Targeted capsules, or any odds shaped by a player's goals (#64).
- Trade suggestions beyond friends (later, with privacy controls, `later-roadmap.md`).
- Secret achievements (later, `later-roadmap.md`).
- Custom sets seen by other players, and a Brotherhood sets page to publish and adopt them (later, `later-roadmap.md`).

## Success signal

The author plays gameble every day for a month alongside at least 10 active players, not all of them friends, and sees their pulls and trades appear in the Brotherhood feed.

## Assumptions

- Per-card draw odds are those in `catalog-and-rarity.md` and are tuned in playtests.
- Card text translations come from Steam's own localized store text, imported once per UI language.
- When Steam stops sharing the library, the Steam library set keeps its last list; deleting it stops the sync and erases the stored list (CAP-27).
- A repost is a past event: it stays in the feed after the card is traded away, and disappears with a hidden or banned profile (CAP-14, CAP-15).

## Open Questions

- **Card backs (CAP-20):** beyond one back per theme or hall of fame set at its back tier and the achievement backs of `achievements.md`, which goal and event backs ship, and does every successful weekly goal grant one?
- **Preview image (CAP-9):** do Steam's terms allow its store art in a derived, stored image? The author checks before it ships.
- **Shared cards and visibility (CAP-8, CAP-9):** `EXPERIENCE.md` assumes a shared card page of a friends-only or private profile shows "not available". Should a share link work for those players? Since 2026-10-03 the shared page shows the card only, with no owner, so it no longer reveals a profile.
