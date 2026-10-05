# Pending approvals

Operations set aside while the author was away (2026-10-02): each waits for an explicit go-ahead. Nothing here has been run.

- **Full real Steam import in development (story 2.3's manual check, story 2.8).** About 1,900 `GetItems` calls for the review pass, plus two `GetItems` calls per 100 kept games for the details, on the author's API key; since story 2.10 no `appdetails` call is made, so it should take minutes rather than hours. Measures the duration, the kept count and the real prestige scores for calibration.
- **Deploy to the test LXC (`bin/kamal deploy`) and run the first real import there (story 2.8).** Needs `config/steam_api.key` on the deploying machine (`.kamal/secrets` reads it) and adds the `import` role.
- **Cloudflare and link previews (epic 4).** When Cloudflare is set up: Bot Fight Mode off, or a WAF skip rule for Discordbot, Twitterbot and WhatsApp on `/*/cards/*` (the share link since story 4.7) and `/*/brothers/*` (public profiles, and the old share links that redirect to the card), or previews fail.
- **Manual preview check (story 4.5).** Paste a share link in Discord, X and WhatsApp once a public HTTPS host exists (the LXC's LAN address cannot be reached by their servers).
- **`PUBLIC_URL` for the public host (story 4.5).** Share links, `og:url` and the canonical link are built on `PUBLIC_URL`, never on the request's Host header; `config/deploy.yml` sets it to `http://192.168.1.6` for the test LXC. Once a public HTTPS host exists, set `PUBLIC_URL` to it (`https://…`, no path) and redeploy, or shared links keep pointing at the LAN address. Since story 4.7, production refuses to boot when `PUBLIC_URL` is missing or malformed (`PublicUrl::Invalid`, checked by `config/initializers/public_url.rb`; the Docker build's `assets:precompile` is exempt), and `test/config/public_url_test.rb` fails if `config/deploy.yml` stops setting a valid one. A deploy with a bad value fails its health check instead of serving 500s.
- **How the hardened import treats edge cases (story 2.11).** Built on these assumptions; confirm or change:
  - A review summary with at least 500 reviews but no valid percent is excluded as `malformed_reviews`. Before, the game was kept and then refused at the cards step.
  - An app listed twice in one `GetAppList` page is kept once (its first entry), not excluded, and named in the run's errors (`repeated_in_page`).
  - A cards pass that writes no card empties the draft.
  - Once a later run is abandoned, the completed run before it can no longer be rescored, so a formula change needs a new run.
  - A run that failed after writing cards keeps publishing refused, even once later runs are abandoned, until a new run completes.
  - "Latest" for abandoning leaves abandoned runs out, as the publish gate does (follow-up review): once the latest run is abandoned, a failed run before it that wrote no card can be abandoned in turn, so it no longer keeps publishing refused with no way out but a new run.
  - A failed "Rescore the cards" that wrote no card can be abandoned: the draft keeps the run's earlier full pass with its old scores, and the run before it then decides whether publishing is allowed. If that earlier run had failed after writing cards (its cards since pruned by the rescored run's completion), publishing stays refused until a new run completes. Rare (a partial run, then a new completed run, then a rescore failing on its first page); telling a rescore apart would need a new column. Confirm, or decide that a failed rescore may not be abandoned.

## After the UX redesign merge (2026-10-05)

- **Capability numbering.** The redesign named friends' presence CAP-19, already taken by the repost (2026-10-03, covered by epic 6); the merge keeps the repost as CAP-19, card backs as CAP-20 and moves presence to CAP-21. Confirm.
- **Repost and Friends tab missing from the UX.** `DESIGN.md` and `EXPERIENCE.md` do not cover the repost action (CAP-19) or the feed's Friends tab (CAP-13). A short `bmad-ux` update before epic 6 is sliced.
- **Tome genres: fold neighbours.** The author wants neighbouring tags folded into one genre (Roguelite into Roguelike, Survival Horror into Horror, Shooter into FPS, …); to work out before the real import (spec open question), then change `Steam::GenreTags` and rescore.
- **Import into a separate draft, with rollback.** The author wants a run to build its cards beside the current draft and replace it only once validated, so a failed or bad run can be thrown away without touching the draft (supersedes "a run that wrote cards cannot be abandoned", story 2.11). Backlog story `backlog/story-import-staging-and-rollback.md`; it changes AD-5 and AD-19, so its design goes through `bmad-architecture` first.

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

## Architecture conformance (2026-10-05)

- **Backfill `game_player_states` on the test LXC.** After deploying the story that creates the table (`bin/docker-entrypoint` runs `db:prepare`, which applies the migration), run `bin/kamal app exec 'bin/rails game:backfill_player_states'` once: every existing player, banned ones included, gets their row (one transaction per player, idempotent, a failing player reported and skipped). Players registering after the deploy get theirs at sign-up. Not run.

## Tier names and season numbers (2026-10-05, story 8.3)

- **Number the published seasons.** Run `bin/rails catalog:number_seasons` on the test LXC after deploying story 8.3 (`bin/kamal app exec 'bin/rails catalog:number_seasons'`; `bin/docker-entrypoint` applies the three migrations through `db:prepare`). Every published season without numbers gets 1..n by `Catalog::PublishSeason`'s shuffle, in one transaction per season; a numbered season is reported and skipped, so it is safe to re-run. Not run. The NOT NULL contract migration waits on it (deferred-work.md). (Development was numbered on 2026-10-05.)
