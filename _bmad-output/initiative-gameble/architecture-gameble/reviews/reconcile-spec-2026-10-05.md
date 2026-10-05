# Reconcile — spec package against the spine (2026-10-05)

Inputs: `spec-gameble.md`, `catalog-and-rarity.md`, `brotherhood-tone.md`, `later-roadmap.md`, checked against `architecture-gameble.md` (updated 2026-10-05). Read-only; nothing was edited.

Verdict: **landed with gaps.** Every capability CAP-1..CAP-21 has a home in the map, and no non-goal is built. Seven gaps leave a spec rule without an invariant that a build session would follow (gaps 1 to 7). Eight more are smaller holes (gaps 8 to 15), and four are low (gaps 16 to 19). None needs a rework of the paradigm.

## Gaps (the spine should hold these)

### Missing invariants

1. **Shared card page (CAP-9).** The spine does not say that the shared page shows the card only, or that the preview has a title and rarity and no image. AD-15 could lead a session to put the sharer's player token in the URL. **Fix:** add a rule to AD-15, or a new AD mapped to CAP-9: the share URL names only the card-season (slug, plus season), never a player or holding. The page renders no owner or sharer. Open Graph and Twitter meta hold the title and the rarity name only, with no `og:image` and no server-generated image (this ties to "images never copied").
2. **Feed visibility (CAP-13, CAP-14, CAP-15, CAP-19 assumption).** AD-13 makes feed streams public, but no rule keeps out the entries of private, friends-only, banned or deleted players. The spec assumes a repost disappears with a hidden or banned profile. **Fix:** in AD-13 or AD-10, state that the feed query and the feed broadcast apply the same visibility rule as the profile policy (AD-14). Entries of non-public, banned or deleted players are filtered when read, so changing visibility hides past entries without rewriting rows.
3. **Steam profile data minimisation (constraint).** Nothing says that the persona name is the only Steam profile data stored, or that it is refreshed at each sign-in. AD-4 says "keeps raw Steam responses in its own tables", which a session could read as covering player summaries. Nothing forbids reading the library either ("owning a game never grants its card"). **Fix:** in AD-14, state that sign-in stores only the Steam id and the persona name on the `Accounts` player, refreshed at each sign-in, and keeps no raw profile response. No Steam avatar, real name, country or library is ever read or stored. The persona name is covered by export, deletion and reports.
4. **Pack kinds (CAP-12, CAP-16).** AD-7 says each pack has "its 5 cards" drawn "by the published odds", and AD-23 returns "the five cards". The daily bonus is a 3-card booster with its own odds (no Commune; 70/24/5/1), and the weekly-goal rare pack has its own odds. **Fix:** in AD-7, give a pack a kind (standard, daily, weekly reward) that fixes its card count and odds table, each table defined once in code. AD-23 returns the pack's cards (3 or 5).
5. **Player-facing words leak into code (constraint).** AD-23 returns a "reserve count" and AD-16 declares `gameble:reserve-changed`. The spec keeps "bank" in code and uses "réserve" only in the UI. "Reserve" also collides with AD-6's `reserved` trade count. **Fix:** rename these to "bank count" and `gameble:bank-changed`, and add a naming row to Conventions: code says pack, bank, weekly goal, and "reserved" means only a trade reservation.
6. **Reduced motion behaviour (constraint).** AD-27 stores the "Animations réduites" preference, but does not say what it switches off. The spec requires it to stop the LIVE ticker and every looping or blinking effect. **Fix:** in AD-27, make the shared motion module (AD-16) the single switch, read by every Stimulus controller, by every island, and by CSS through one root attribute. When on, it stops the ticker and every infinite or blinking animation. The Légendaire sequence and the reveal follow `EXPERIENCE.md`'s reduced variant.
7. **Zero-downtime ready (constraint).** AD-21 has no health check, no graceful shutdown and no expand/contract rule. AD-28 cites "expand/contract (AD-21)", but AD-21 only names `strong_migrations`. **Fix:** in AD-21, add the health endpoint (`/up`, used by the Kamal proxy) and graceful shutdown on SIGTERM for web (Puma drain) and jobs (Solid Queue finishes or requeues; import resumes per AD-19). Every schema change is expand/contract, so the old and new code run side by side.

### Smaller holes

8. **Data export and deletion effects (CAP-14).** Export has no home. `Accounts` depends on no pack, but an export needs `Game` data (holdings, trades, friends, feed). Deletion's effects in `Game` are not named either. **Fix:** name the export's home, for example a web-layer composer over `Accounts` and `Game` queries, or `Game` reacting to an export-requested event. List what the `Game` handler on `Accounts::PlayerDeleted` does: it cancels open trades and releases their reservations, removes friendships and invitations, and hides feed entries.
9. **Trade reservation and the friendship check (CAP-11).** AD-8 says "placing cards raises `reserved`" without saying which side. The spec caps the requested side at "what the friend owns" (not minus reserved), which suggests requested cards are not reserved. Then acceptance can meet a friend who no longer has the card. AD-8 also never states that non-friends are refused. **Fix:** in AD-8, state that only the proposer's offered cards are reserved (after a counter, the counter-proposer's offer). Acceptance re-checks the other side and fails with a code. Every trade operation requires an existing friendship.
10. **Image refresh against "a card keeps its data" (constraint, AD-19).** The weekly refresh updates `image_url` from `GetItems`. For a delisted game, Steam returns little, and the refresh could blank the address. **Fix:** in AD-19, the refresh only replaces an address with a valid new one and never clears it.
11. **Genre equals tome genre (catalog-and-rarity).** AD-5 says "the first of its `Catalog` genres", but nothing fixes the order (the most-voted tag from the curated list). It does not say that a game in no tome shows no genre, or where the curated list of about 25 genres lives. **Fix:** in AD-4 and AD-5, state that `Steam` maps tags to genres through the curated list kept in its code, ordered by vote weight. The first genre is the tome genre. A card with no listed tag has no genre and no tome.
12. **Catalog source rules (constraint, CAP-2).** The spine does not state that only the keyed, batched Steam Web API is used, with the key from an environment variable. It does not forbid the keyless store API (`appdetails`). It does not say where the inclusion filters live (type `game`, at least 500 reviews, no DLC, soundtracks, demos or tools), that every season re-imports every game, or that card text is fetched once per UI language. **Fix:** add these to AD-19.
13. **Prestige inputs (CAP-3).** AD-4 says that `Steam` "computes a prestige score" but does not pin its inputs: review score and count only, no Metacritic, and never rare for obscurity. The "best rated of the year" sets, built in `Catalog` (AD-5), need a source-neutral rating on the card-season, which AD-4 does not name. **Fix:** state the inputs in AD-4. Name the neutral fields that `Steam` writes into `Catalog` (prestige score, rating, publisher, release date).
14. **Friend code (CAP-10).** AD-15 gives invitations a token, but a friend code has no home and no format. **Fix:** in AD-8 or AD-15, the friend code is a short random code held by `Game` (or `Accounts`), never derived from an id, unique, and resolved to an invitation.
15. **Back-office scope (non-goal "back-office beyond moderation", CAP-15).** AD-25's administrator operation that grants a card back to a group, and AD-16's back-office card-preview island, go beyond the staff powers in CAP-15 (moderate, ban, import, publish a season). **Fix:** either confirm both in the spec (CAP-15 or CAP-20 "events or seasons"), or mark the grant as an operation run from the console with no back-office screen.

### Low

16. **No real money (constraint).** No invariant says it. **Fix:** add one line to AD-1 or AD-20: no payment, purchase, ad or cash-out code or dependency, and the CSP (AD-27) admits no payment or ad host.
17. **Repo text in English (constraint).** This is missing from Conventions. **Fix:** add a row: code, comments and docs are in English, and player copy lives only in locale files.
18. **p95 < 200 ms has no check.** AD-7 argues that the budget holds, and AD-22 and Deferred measure only the device side. **Fix:** add a server-side load measurement of `POST /packs` before launch to Deferred (or AD-22).
19. **New account starts with 10 packs available (CAP-4).** AD-7 fills the bank but does not say that all ten are available at once. **Fix:** state that the ten initial packs have an availability time of the registration time.

## Landed (no action)

- Steam-only sign-in with Valve's image (AD-14).
- Forkable engine (AD-2, AD-4).
- Packs pre-drawn and server-credited (AD-7, AD-23).
- Card copies per card and season (AD-6).
- Card number per season (AD-5, Conventions).
- Images never copied, with the 32-colour, 2 px, no-dithering filter (AD-17).
- Stateless, one image, env-only configuration, three processes (AD-21).
- CI rules (AD-22).
- Bots: Cloudflare and `rate_limit`.
- Portrait-only, never-scaled layout (AD-27).
- FR/EN completeness check (AD-18).
- Tone via `brotherhood-tone.md` (AD-18).
- Legal page home (web layer, map row).
- Card backs (AD-25).
- Presence (AD-24).
- Daily bonus uniqueness and cap (AD-7, AD-9).
- Ownership counted, not numbered per copy (non-goal respected).

## Spec-side note

The spec's Architecture constraint ("predates the 2026-10-05 redesign") and its Open Question "Architecture conflict" are stale. The spine now has 32 colours, the Commune…Légendaire codes, no dust tier, per-season numbers, card backs, invitations and presence. The spec should drop both.
