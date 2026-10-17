# Pending approvals

Operations and decisions waiting for the author's go-ahead, kept since 2026-10-02. Open items first; settled ones are listed by date at the end.

- **Cloudflare and link previews (epic 4; author 2026-10-08: when production is set up).** When Cloudflare is set up: Bot Fight Mode off, or a WAF skip rule for Discordbot, Twitterbot and WhatsApp on `/*/cards/*` (the share link since story 4.7) and `/*/brothers/*` (public profiles, and the old share links that redirect to the card), or previews fail.
- **After the next deploy: `bin/rails game:drop_friends_and_trades` (story 5.11, 2026-10-07).** Closes the trades, friendships and invitations of accounts deleted before 5.11 and of bans set from the console; run once after deploying, and again after any console ban until story 7.5's ban action publishes `Accounts::PlayerBanned`.
- **After the next deploy: `bin/rails game:backfill_achievements` (2026-10-12).** Grants, silently, the achievements players met before the achievements engine shipped. Run it right after deploying: until then a veteran's first opening, trade or repost grants their past milestones live, each with a toast and not marked retroactive. A rerun grants nothing twice.
- **After the deploy that carries the new prestige formula (rarity follows the review count, 2026-10-13): rescore the draft on staging.** In the back-office, open the latest completed import run and press "Recalculer les cartes" ("Rescore the cards"). When its pass completes, the season preview shows the new tiers and no mixed-version verdict. Expect Légendaire from about 174,000 reviews and Épique from about 36,000: PUBG, Apex Legends, War Thunder and Overwatch enter Légendaire, and Balatro, Stray and Dead Cells leave it. Look also at the hall of fame sets' rarity mix in the preview: Les Phénomènes (200,000 reviews or more) becomes almost all Légendaire, Les Pépites (under 1,000 reviews) all Commune. Publish when satisfied. If the rescore is refused because the run's season is already published, the next import scores with the new formula by itself. A published season is never rescored. To run by the author on staging.

- **On staging, after the collection opens on sets in progress (epic-recognizable-sets, ticket 13.7, 2026-10-17): the author's check.** With a player who has sets in progress, publish a new season on staging and open their collection: their sets in progress keep their progress, less what the grown sets add (the rows count a game held in any edition against the new season's sets). Also look at the collection entry signed in and at `/library/cards` on the desktop and the phone, which the build did not view in a browser.

- **On staging, after the set album (epic-recognizable-sets, ticket 13.8, 2026-10-17): the author's check on a device.** Open a theme in progress from the collection's EN COURS on the desktop and the phone: the header (name, kind, count, the BRONZE · ARGENT · OR gauge with the tiers reached lit), the cards in set order with the missing games named, sixty to a page; open a completed franchise and look at the COMPLET stamp; open the same album signed out from a public profile. Check the back button names where the album was opened ("◀ SETS" from the collection or its search, "◀ FICHE" from a card's sets, "◀ PROFIL" from a profile, none on the desktop and "◀ PONT" on the phone from the hub), that coming back focuses the row and marks it with the accent bar, and that the arrow keys move through the grid. Settle too: a slot shows the best edition held in any season, its copies summed over editions, the badge from x2; New shows on the player's own album only and the album moves no watermark; the tiers come from the cards held now (a tier reached earlier and lost through trades reads as not reached, as on the rows).

## Settled on 2026-10-13

Settled by the author through the triage page of 2026-10-13.

- Trades screen and board choices (stories 5.6 to 5.9): confirmed as built. The friend row now has its trade button (story 7.21).
- Moderation choices (story 7.5), moderation by rank and staff reading profiles (story 7.17), the players list (story 7.18) and the moderation history (story 7.19): confirmed as built.
- Console bans after story 7.5: merged into the `game:drop_friends_and_trades` entry above, which it only explained.
- `bin/rails steam:fill_card_sources` after the deploy that brings themes: already run on staging; closed.
- Weekly goal reward pack odds (story 6.5): the reward pack's own odds were built by story 6.16 (one Légendaire in 50); the daily bonus keeps about one Légendaire in 34 packs.
- A friend's showcase (story 5.10): becomes the backlog ticket `backlog/story-a-player-chooses-their-showcase.md`, designed in UX first.
- First discoveries in the feed (story 6.7): becomes the backlog ticket `backlog/story-the-activity-feed-reworked.md`, which starts with a UX session and reruns the opening benchmark.
- Account deletion copy (story 7.8): becomes ticket 48 of epic-public-launch-readiness, which checks the dialog against what deletion erases and corrects it.
- Tomes to rethink (story 10.5): done by epic-recognizable-sets (themes, franchises, studios and hall of fame replaced the tomes). The opened pack page's « Ton paquet, Confrère » becomes ticket 49 of epic-public-launch-readiness.

## After the UX redesign merge (2026-10-05)


## Settled on 2026-10-03

- GitHub issues #1–#11 of epic 1 closed.
- Daily bonus booster odds confirmed (spec CAP-16).
- AD-7 amended: replacement packs drawn inline by `Game::TopUpBank`.
- Public profile title: the Steam persona name, stored at each sign-in, with "Brother <code>" as fallback (story 4.4 plan updated).
- Share previews carry no image at all, not even a card back, even if X shows a bare link (spec CAP-9; built in story 4.5).
- Epics 3 and 4 breakdowns: judged through their retrospectives instead.
- The import drops the store API (story 2.10); a degraded local import of 1,000 games was run in development.
- Shared links show the card only (spec CAP-9, story 4.7); epic 4's R5 and Done when 3 reconciled.

## Settled on 2026-10-05

- Superseded by the UX redesign (`DESIGN.md`, `EXPERIENCE.md`, final 2026-10-05), to apply when the reveal is rebuilt: the large card back size, tier cues on a dusty back (dust, rarity seal and wipe are dropped; one click reveals rarity and game together), the reveal's phone layout (phone pile with a tray; breakpoints 720 and 1180 px) and flip all on a phone ("Tout révéler").
- `main` pushed with the UX redesign merge, and the remote `ux-redesign` branch deleted.
- Ownership notice: no notice or copyright on the card; the legal page says, in substance, « Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons. », beside the no-affiliation notice (spec Legal constraint, epic 7). The built per-card notice (`card_details.notice`, story 2.10) stays until the legal page exists.
- Card genre: the card shows its tome's genre; the genre list grows with specific genres only (Third-Person Shooter, Stealth, Rhythm, Shoot 'Em Up, Arcade), never Action, Adventure or Casual; a game in no tome shows no genre.
- Development database: the migrations of stories 2.10, 2.11 and 4.6 were already applied; "Rescore the cards" ran on import run 4 (no Steam call): 498 cards written, none refused, every draft card with a genre (the five new genres in use). The re-timed degraded import is no longer needed. The next deploy still runs the 4.6 check validation on its database (`bin/docker-entrypoint` runs `db:prepare`).
- A new player cannot take the daily bonus before opening a pack: their ten starting packs fill the reserve (AD-7, story 8.4); confirmed by the author.
- Development's published season 1 numbered with `catalog:number_seasons` (story 8.3).
- An older browser opening a shared card sees a line asking to update the browser instead of the invitation to sign in (author; story 10.3).
- The library's pages stay open to any browser, as the profile and card pages (story 4.7); confirmed by the author.
- The booster's revealed cards do not link to their detail (author).
- The card detail shows any card's rarity, owned or not: rarity is public catalogue information (author).
- The 25 tome genres confirmed as listed in `Steam::GenreTags` (author); folding neighbours stays open above.
- The architecture spine absorbed the redesign (AD-1 to AD-28, final); epics 8 and 10 rework the built screens, card backs (CAP-20) have epic 9 and presence (CAP-21) joins epic 5.

## Staging and production (2026-10-06)

- **Production later (after the author validates the MVP on staging).** Fill `config/deploy.production.yml` (VPS address, registry such as ghcr.io), create `.kamal/secrets.production` with its own keys, point gameble.com at the VPS (Cloudflare in Full mode if used), then `bin/kamal deploy -d production`.
- **Log retention before production (story 7.14, 2026-10-09; author 2026-10-12: with the production setup).** On the production VPS: install the journald drop-in the README gives (30-day retention, `MaxFileSec=1day`), then `bin/kamal accessory reboot db -d production` and `docker container prune -f` after the first deploy, so no container keeps json-file logs. Still to decide then: whether staging's size-rotated json-file logs get an age limit too, and which Sentry plan production uses, so the legal page's "90 days at most, depending on the plan" names the plan's real retention (Developer 30 days, Team 90 days).
- Staging deployed and the first full real import run there (2026-10-06, 55 min, 12,307 cards); season 1 published on staging with the starting calibration (epic 2 Notes).

## Settled on 2026-10-06

- Staging (gameble.dotsncircles.com) deployed by the author with the Traefik route fixed; the first full real import ran there and season 1 was published (epic 2 Notes). Epic 2 marked done.
- On staging's fresh database, `db:prepare` applied every migration at boot (dust_tier dropped, numbers column, player states), season 1 was numbered by its own publication, and players get their `game_player_states` row at sign-up: the backfills `catalog:number_seasons` and `game:backfill_player_states` are not needed there. They stay available for any older database.
- Prestige formula: log10(review count) + 4 × Wilson (story 2.12); season 1 on staging keeps the old scores and is not republished.
- Pixel-art sheet of story 8.8 reviewed and approved by the author (82 files); story 8.8 marked done.
- Capability numbering confirmed by the author: CAP-19 repost (epic 6), CAP-20 card backs (epic 9), CAP-21 friends' presence (epic 5).
- Repost (CAP-19) and the feed's Friends tab (CAP-13) added to DESIGN.md and EXPERIENCE.md by the author through bmad-ux: REPOSTER on the card detail, at the end of an opening and on the hub showcase; TOUS / AMIS tabs combined with the type filters plus REPOSTS; reposts in the feed only, never in the ticker; invitation to add friends, sign-in panel when signed out.
- Folding neighbouring genres becomes a back-office tool (epic-season-preparation, story 2): after an import, the author classifies every tag (merge into a genre, own genre, ignored), English name by default with editable French and English labels, publishing refused while a tag is unclassified; needed before the next season's import.
- Import staging with rollback and genre curation grouped in a new epic, epic-season-preparation (id 11), to incept before the next season's import.
- Story 2.11's edge-case rules: kept by the author — malformed review percent excluded (`malformed_reviews`), an app listed twice in a page kept once and reported, a pass writing no card empties the draft; the rules on abandoning runs, rescoring the previous run and refusing publication after a failure are left to epic-season-preparation, whose staging-with-rollback replaces them.
- Share link previews checked by the author on staging (Discord, X, WhatsApp): title and rarity shown, no image (story 4.5's manual check done).

## Settled on 2026-10-08

- Staging auto-deploy secrets set by the author.
- `PUBLIC_URL` set per destination: `https://gameble.dotsncircles.com` in `config/deploy.staging.yml`, `https://gameble.com` in `config/deploy.production.yml`.
- AD-7 amended to match story 7.6: an opening replaces only the regular pack it opened; a bank left short stays short until the next season's publication gives every missing pack at once (author).
- Trade rules of story 5.5 confirmed: the expiry job every minute, accepting or countering refused past 7 days, the `trade_expired` and `requested_cards_unavailable` error lines (author).
- Friends' presence windows of story 5.3 confirmed: online within 5 minutes, an activity shown for 3 minutes (author).
- Hub showcase line "rarity · genre · number" confirmed (story 8.13, author).

## Settled on 2026-10-07

- Epic 9, card backs (CAP-20), is out of the MVP, built after the public launch (author).
- English copy is translated by AI from the French, not written by hand (author); it settles the spec's open question on who writes the English copy.
- Dependabot: the four actions bumps and image_processing 2.2.0 merged into develop; the staging deploy workflow follows actions/checkout 7. CI's test job no longer eager loads (a zeitwerk:check step does), which fixes the two read-only guard tests that failed only in CI.

## Settled on 2026-10-09

- Moderation, after story 7.5 (author): a staff member bans only a lower rank, so a moderator bans players and an administrator bans players and moderators; no one bans an administrator or themselves. The back-office answers 404 to anyone who is not staff, signed out included. Staff read every profile whatever its visibility. The back-office gets a searchable list of players to ban from without waiting for a report, and a history of bans. Built by stories 17 to 19 of epic 7.

## Settled on 2026-10-12

- `bin/rails steam:fill_card_sources` (epic-recognizable-sets, story 2): run by the author on staging after v0.0.4-beta, which carries its migrations. Not needed on production: its first import stores developers, franchises and review counts.
