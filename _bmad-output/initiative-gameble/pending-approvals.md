# Pending approvals

Operations and decisions waiting for the author's go-ahead, kept since 2026-10-02. Open items first; settled ones are listed by date at the end.

- **Cloudflare and link previews (epic 4; author 2026-10-08: when production is set up).** When Cloudflare is set up: Bot Fight Mode off, or a WAF skip rule for Discordbot, Twitterbot and WhatsApp on `/*/cards/*` (the share link since story 4.7) and `/*/brothers/*` (public profiles, and the old share links that redirect to the card), or previews fail.
- **Weekly goal reward pack odds (story 6.5, 2026-10-07; author 2026-10-08).** Too generous as built: with the bonus odds per card and the forced Épique or better, about one reward pack in 6 holds a Légendaire. The author's target: one Légendaire in 50 reward packs. The reward pack needs its own odds in `Game::DrawOdds` instead of the bonus ones; a short story to plan. Still open: whether the daily bonus, at about one Légendaire in 34 packs, comes down too.
- **A friend's showcase (story 5.10, 2026-10-07; author 2026-10-08).** Built as the friend's three highest tiers held in the published season (`Game::ShowcaseCards`). The author wants each player to choose their own showcase: a new feature for the spec and UX, then a story (the default before any choice, where it is chosen, a chosen card that leaves the collection). PROPOSER UN ÉCHANGE stays disabled ("Bientôt disponible") until story 5.8.
- **First discoveries in the feed (story 6.7, 2026-10-07; author 2026-10-08).** The author will rework the activity feed in detail (through UX first), which covers DÉCOUVERTES crowding TOUT at a season's launch and late SetCompleted events. The timed opening benchmark (`RAILS_ENV=test bin/rails game:benchmark_open_pack`) is to run again after that rework.
- **Account deletion (story 7.8, 2026-10-07; author 2026-10-08).** Deleting an account erases the account and every piece of data tied to it. The dialog's copy says so, and the deletion covers trades, friendships, invitations, feed entries and card backs; to check against what story 5.11 deletes and to fix in 7.8's copy.
- **Tomes to rethink (story 10.5, 2026-10-07; author 2026-10-08).** The author no longer wants tomes as the way sets are grouped and will rework them; this touches the spec's sets (catalog-and-rarity.md), the genre on the card, the library and collection screens, and genre curation (epic-season-preparation, story 2). The opened pack page (`packs.show`) saying "Ton paquet, Confrère" with "tu" waits on the same rework.
- **After the next deploy: `bin/rails game:drop_friends_and_trades` (story 5.11, 2026-10-07).** Closes the trades, friendships and invitations of accounts deleted before 5.11 and of bans set from the console; run once after deploying, and again after any console ban until story 7.5's ban action publishes `Accounts::PlayerBanned`.
- **Trades screen and board choices (stories 5.6 to 5.9, 2026-10-07).** Finished trades stay listed 14 days (20 at most); the card picker lists a friend's whole collection whatever their profile visibility (trading needs it); the live stream is per locale; a dialog open or text not yet sent holds a live refresh back; an incoming proposal moves only the badge, with no toast; the draft's validity line, the discard confirmation and the English trade copy are drafts. The friend row on Amis has no PROPOSER UN ÉCHANGE button yet (the friend profile has it). To confirm.
- **Moderation choices (story 7.5, 2026-10-09).** The queue (`/<locale>/back-office/reports`) shows one row per reported player with the open reports counted per reason, never the reporters; CLASSER sets a player's reports aside without a ban (not in the ticket, added so the queue can empty); a ban marks the player's open reports handled; lifting a ban gives back sign-in and profile, not the friendships and trades the ban dropped; staff roles are set with `bin/rails "accounts:set_role[<steam id>,<role>]"` (README, Staff accounts and moderation). The moderation copy and its English are drafts. To confirm. Who may ban whom, the back-office's 404, staff reading hidden profiles and the history were settled on 2026-10-09 (below).
- **Console bans after story 7.5 (2026-10-09).** A ban from the back-office now publishes `Accounts::PlayerBanned`, so `bin/rails game:drop_friends_and_trades` is needed only once after the next deploy (older data) and after a ban set by hand in the console, which the README now advises against.
- **Moderation by rank and staff reading profiles (story 7.17, 2026-10-09).** Staff read every profile but a deleted one on the public profile and may report what they read there; the feed and the friend profile show staff what a player would see (`staff_sees_all: false`), the shared card page names no owner. One refusal for every rank case, "Ce joueur a un rang égal ou supérieur au vôtre, officier : vous ne pouvez pas agir sur lui." (English a draft), shown in the queue and, new, in the banned list, whose names now link to the profile. The profile's visibility line now names the officers: "Visible par vos amis et les officiers de la Confrérie seulement", "Profil privé : vous seul et les officiers de la Confrérie le voyez". The back-office's 404 is the same page as an unknown address and comes before the browser, forgery and rate-limit checks; a moderator on an administrator's page keeps the 403. To confirm.
- **The players list (story 7.18, 2026-10-09).** `/<locale>/back-office/players` ("Les joueurs", first link of the back-office) lists every player whose account is not deleted, banned ones included, the newest account first, 50 a page; the search matches part of the name in any case, or the full Steam id exactly (a part of a Steam id finds no one), and is a plain form with a CHERCHER button, not search-as-you-type. A row shows name, role, visibility and standing ("En règle" / "Banni"), never the Steam id; BANNIR and LEVER LE BAN from the list come back to the list with its search and page. The page's copy and its English are drafts. To confirm.
- **The moderation history (story 7.19, 2026-10-09).** The ban's reason is typed in a field beside BANNIR on every ban form, one line, 500 characters at most, required by the browser and refused by the server ("Indiquez la raison du bannissement, officier."); unban and CLASSER ask no reason. The history (`/<locale>/back-office/history`, "L'historique") is a table written by the moderation operations, not read from the event store, since a typed reason is free text an event must not hold; a data migration copied, at deploy, the bans, unbans and dismissals the events recorded since story 7.5, shown "Raison non consignée"; a ban set by hand in the console never appears, and an action made by the old code during the deploy's switch-over would be missed. The history shows every action to every member of staff, filtered by the player acted on (each row of the players list links it), not by the staff member; rows are never edited and outlive a deleted account ("Compte supprimé"), the reason included, and the player's data export does not include them. The copy and its English are drafts. To confirm.
- **After the next deploy: `bin/rails game:backfill_achievements` (2026-10-12).** Grants, silently, the achievements players met before the achievements engine shipped. Run it right after deploying: until then a veteran's first opening, trade or repost grants their past milestones live, each with a toast and not marked retroactive. A rerun grants nothing twice.

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
