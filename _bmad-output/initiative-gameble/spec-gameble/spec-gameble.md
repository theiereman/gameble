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

The idea is a vision, and it answers a pain. "Collect Wikipedia" card games (WikiMasters, Wikigacha) prove the loop is fun: pull a pack, land something famous, show it off and trade it. But the existing games are slow under load, flat to open, generic-looking, padded with hollow features, and pushy about money.

gameble is an open-source passion project that does this loop properly for French-speaking friend groups. Its lasting edge is not execution but community: every player belongs to *La Grande Confrérie des Gamblers* (the Brotherhood). The launch beachhead is disappointed WikiMasters and Wikigacha players.

## Capabilities

- **CAP-1**
  - **intent:** A visitor can sign in with Discord or Google and get a player account.
  - **success:** Sign-in with either provider creates the account or reuses an existing one. No password is stored by gameble.
- **CAP-2**
  - **intent:** The system builds a card catalog from French Wikipedia, with recognisable subjects only.
  - **success:** An import run produces cards that match the inclusion and exclusion rules in `catalog-and-rarity.md`, each with a family and a Commons image or fallback art.
- **CAP-3**
  - **intent:** Every card has a rarity that reflects the subject's worldwide fame, so a player can guess why a card is rare.
  - **success:** Rarity follows the formula in `catalog-and-rarity.md`. A subject covered by more Wikipedias never ranks below one covered by fewer, unless the French-pageview boost applies.
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
  - **intent:** A player can browse their collection by family and see their progress in each family.
  - **success:** Each family shows owned / total distinct cards. Duplicates are counted per card.
- **CAP-7**
  - **intent:** A player can open a card's detail view to see the subject and its sources.
  - **success:** The detail view shows the title, summary, rarity, family, a link to the French Wikipedia article, and the image author and licence.
- **CAP-8**
  - **intent:** Each player has a public collection profile reachable by link.
  - **success:** A logged-out visitor opening the profile link sees that player's collection and family progress.
- **CAP-9**
  - **intent:** A player can share a pull as a link that previews nicely on Discord, X and WhatsApp.
  - **success:** Pasting the link on each of the three platforms shows a preview with the card image, title and rarity.
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
- **French UI only** in the MVP, with i18n infrastructure in place. All repo text (code, comments, docs) is in English.
- **Card copies:** every copy stores its minted rarity and season from day one, so a V2 market and V3 seasons need no migration.
- **Forkable engine:** the game engine (packs, rarity tiers, collection, trades, goals, feed) is independent of the catalog source. French Wikipedia is one adapter.
- **Open source.** Infrastructure components (queues, caches, streaming) are added only when measured load justifies them.
- **Stack:** full TypeScript (strict), React SPA and PostgreSQL. Details are in `stack.md`.
- **Stateless services:** several API instances can run in parallel. Pack credit and trades are transactional in PostgreSQL.
- **Zero-downtime ready:** health checks, graceful shutdown, and backward-compatible (expand/contract) migrations.
- **CI/CD ready:** one reproducible container image per service, configuration by environment variables only, automated tests in CI from day one.
- **Separable services:** the API, the catalog importer and future workers are separable deployables of one modular monolith.
- **Pack opening:** p95 latency < 200 ms.
- **Catalog source:** Wikimedia dumps, not live Wikipedia APIs.
- **Images:** Wikimedia Commons only, with author and licence attribution (CC BY-SA). Subjects without an image get designed fallback art.
- **Bots:** edge bot protection from day one; trades are limited to friends.
- **Platforms:** responsive desktop and mobile web. Native store apps must remain possible later.
- **Wikipedia edits:** never rewarded in any way.
- **Tone and naming** follow `brotherhood-tone.md`.

## Non-goals

- Combat or any card battle mechanic.
- Back-office features beyond moderation (set creation is V3).
- Guilds.
- Any currency, auction house, listing fee or sale commission (V2, see `later-roadmap.md`).
- Brotherhood Pass, seasonal catalog recompute, community-voted themed sets, back-office, foil variants (V3).
- Native App Store and Play Store apps.
- English UI, and catalogs other than French Wikipedia.

## Success signal

The author plays gameble every day for a month alongside at least 10 active players, not all of them friends, and sees their pulls and trades appear in the Brotherhood feed.

## Assumptions

- Every player has a public profile by default; they can hide it (CAP-14).
- The weekly-goal reward is one rare pack per contributor.
- Multi-card trades are allowed in both directions (N cards for M cards).
- Per-tier draw odds start at ~70% common and ~20% for the second tier, with the rest shared, and are tuned in playtests.
