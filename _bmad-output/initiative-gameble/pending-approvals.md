# Pending approvals

Operations and decisions waiting for the author's go-ahead, kept since 2026-10-02. Open items first; settled ones are listed by date at the end.

## Open

- Shared card link previews with a generated image (backlog story `story-a-shared-card-link-previews-with-a-generated-image`), before it reaches production:
  - Steam's terms on reusing store art: the image shows the card's Steam cover, pixelated in the card frame. The author checks the Steam terms allow it.
  - Crawler reach of `/share-images/<token>.png`: the image sits outside the locale scope, served signed out with `Cache-Control: public, max-age=31536000, immutable`. Cloudflare must let Discordbot, Twitterbot, WhatsApp and facebookexternalhit fetch it as it lets them fetch the card page. While `SEARCH_INDEXING` is off, `robots.txt` answers `Disallow: /`, which Twitterbot obeys for images too: check an X preview on staging.
  - The render has run only against the development and CI builds of libvips, never inside the Docker image: on staging, open a card page, wait a few seconds, reload, and check the page carries `og:image` and the image shows the card's title in VT323 and a pixelated art. A missing text or palette feature in the image's libvips shows as a Sentry report from `CardShareImageJob` or as unquantised art.
  - The images are stored by Active Storage on the `local` service, under `/rails/storage` (the `gameble_storage` volume): a lost volume with the database kept leaves each stored image's tags pointing at a missing file until the `catalog_share_images` rows are cleared or `CardShareImage::RENDER_VERSION` is bumped, after which each card page enqueues its render again.

## Settled on 2026-10-29

Settled by the author in conversation on 2026-10-29.

- The app's PostgreSQL role: `script/database/hand_over_to_app_role` run by the author on staging, then on production before v1.0.0 was promoted; staging checked running as `gameble_app`.
- Cloudflare and link previews (epic 4): link previews of shared cards and public profiles work behind Cloudflare; no rule change was needed or made beyond what the author did.

## Settled on 2026-10-20

Settled by the author on 2026-10-20: the staging checks, then the production setup.

- Rescore of the draft with the prestige formula that follows the review count: done, the tiers and the hall of fame sets' rarity mix as expected.
- The collection on sets in progress (ticket 13.7): progress kept across a new season's publication; the collection entry and `/library/cards` fine on the desktop and the phone.
- The set album (ticket 13.8): header, set order, missing games, COMPLET stamp, signed-out album, back button labels, return focus and arrow keys confirmed; the best edition per slot, New on the player's own album only and tiers from the cards held now are kept.
- Every edition counts in the collection (ticket 13.15): one tile per game at its best edition with its copies and editions, counters unchanged by a new season, page time acceptable.
- Trade filters across both collections (ticket 18.2): checked on the desktop and the phone, placed cards hidden by a chip stay placed, another season's edition is not "Absente de ma collection".
- Production set up, deployed and its log retention in place (journald drop-in, db accessory rebooted, json-file containers pruned): done by the author.
- `bin/rails game:drop_friends_and_trades` and `bin/rails game:backfill_achievements`: run by the author on staging and on production. The cleanup is still rerun after any console ban.
- Sentry's retention: 30 days (the Developer plan); the legal page and the README say so, the legal page dated 20 October 2026.

## Settled on 2026-10-19

Settled by the author in conversation on 2026-10-19.

- The card detail beside the grid (ticket 13.14) and its waiting detail (13.24): superseded; entry 13.25 brought back the card detail page and aligned the grids.
- Trade filters (ticket 18.2): duplicates count by game across editions; the chip labels and the "Collections" legend stay as built.
- Results of one opening at the same earlier-season metal rank by the share of their set (ticket 13.22): kept.
- The fill grid's 185 px card cap is gone (ticket 13.25): kept, cards grow to fill the phone's width.
- Roadmap milestones created automatically start hidden (ticket 20.19): kept.
- The LIVE ticker always reaches the window's horizontal edges, at every width from 720 px (ticket 6.15): kept as built.
- Bug #77 (no category on Dreamfall): the card is a UFO; a theme for adventure games is added for the seasons to come, and cards without a theme keep showing no genre.
- Bug #52 (language back): back after a language change must keep the previous screen's scroll position, and only a language chosen in the settings carries over to the history; a follow-up bug in the backlog.
- `game_set_completions`, written by nothing since tiers, is dropped, and the feed's member-count fallback for sets without a complete tier is removed (entry 13.26).
- A signed-out visitor reaches the card catalog from the landing (ticket 14.5).

- Showcase kicker (ticket 16.8): "Latest acquisition" in English, « Dernière obtention » in French.
- Public profile empty states (ticket 16.3): SUCCÈS reads « 0 / 10 » with an unlit gauge and no « Derniers obtenus »; SETS reads « 0 set entamé » with no rows. Kept. CARTES is capped at the season's total, and staff see a banned player's line again (ticket 16.9).
- The legal page's date moves to the latest clarification (ticket 13.26, 19 October 2026): kept.
- Bug #77: Adventure stays a broad tag; the adventure theme becomes a fallback for games no other theme claims, covering Adventure, Action-Adventure, Story Rich and Female Protagonist (backlog bug).

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
