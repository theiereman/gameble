- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-walking-skeleton-live-in-production-plan.md`
  summary: Deploy gameble to production with Kamal 2 — Dockerfile changes for the Vite build, `config/deploy.yml` and `.kamal/secrets`, the PostgreSQL 18 accessory with its four databases, HTTPS through the Kamal proxy with Let's Encrypt, and the first `bin/kamal setup`, run by the author.
  evidence: Split from story 1.1 on 2026-10-02 at the author's request. There is no production server, no domain and no Cloudflare setup yet; the author will deploy once a working version exists. Story 1.1's Verify and the epic's Done when checks 1, 4 and 6 name production and wait on this work.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-walking-skeleton-live-in-production-plan.md`
  summary: The generated Dockerfile installs no Node, so `assets:precompile` (which vite_ruby extends with `vite:install_dependencies` and `vite:build_all`) fails and no production image can be built until Node is added.
  evidence: The app was generated with `--skip-javascript`; vite_ruby-3.11.1 `lib/tasks/vite.rake` lines 57–70 hook the Vite build into `assets:precompile`. Story 1.1 keeps the Docker and Kamal files as generated.
  resolved: Story 1.10 (refactor sweep) installs Node 24.15.0 in the Docker build stage and runs `npm ci` before `assets:precompile`; `docker build` succeeds and the image carries the Vite assets without `node_modules`.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-walking-skeleton-live-in-production-plan.md`
  summary: The generated `.github/workflows/ci.yml` test job sets up no Node and runs no `npm install`, so the root-page test fails in CI (Vite `autoBuild` in test needs `node_modules`); story 1.2 must add Node to CI, not just adapt it.
  evidence: `config/vite.json` sets `autoBuild: true` for test and the layout's Vite tags trigger a build; the CI job runs only `bin/rails db:test:prepare test`. Story 1.1 leaves the generated CI files for story 1.2.
  resolved: Story 1.2 added `actions/setup-node` (from `.tool-versions`) and `npm ci` to the test and system-test jobs.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: Behind Cloudflare, `request.ip` is a Cloudflare address unless real client IPs are restored (trusted proxies from Cloudflare's ranges, or `CF-Connecting-IP`), so the Rack::Attack sign-in throttle would put every visitor under one shared limit.
  evidence: Story 1.9 throttles by `request.ip` and leaves real-IP handling to deployment; there is no Cloudflare setup yet.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: If Cloudflare or the Kamal proxy terminates TLS, Rails must treat requests as HTTPS (`config.assume_ssl`, `force_ssl`) so the Steam OpenID `return_to` and secure cookies use `https`.
  evidence: Story 1.6 builds the OmniAuth return URL from the request host and scheme; the production TLS setup does not exist yet.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: Production checks owed by the author (hitl): a real Steam sign-in on the production URL, twice, reusing the player (story 1.6); a Sentry test event with the release (story 1.9, README "Production checks"); `/back-office/jobs` renders with Mission Control's own assets (story 1.9).
  evidence: These need a deployed app, a real Steam account and a Sentry project; each story verified locally only.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: `config/initializers/omniauth.rb` prepends onto `OpenID::Consumer::AssociationManager`, an internal of ruby-openid 2.9.2, to keep the consumer stateless; a ruby-openid upgrade must re-check it, or the OpenID check can be written inside `Steam` as AD-20 allows.
  evidence: Story 1.6 Implementation Notes and residual risks.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: The OpenID nonce store relies on `Rails.cache` `unless_exist`, which is not strictly atomic under a race of milliseconds; a table with a unique index in `Steam` would close it.
  evidence: Story 1.6 residual risks; Steam's own check_authentication is a second guard.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: Links built by route helpers for routes outside the locale scope (`/up`, `/auth/*`, Mission Control) gain a `?locale=` query from `default_url_options`.
  evidence: Story 1.4 and 1.9 residual risks; harmless today, untidy in URLs.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: Cloudflare's cache ignores `Vary: Accept-Language`, so the `/` redirect must never be cached at the edge (keep it out of cache rules, or send `Cache-Control: private, no-store` from `LocalesController#redirect`) when Cloudflare is configured.
  evidence: Story 1.10 review; Rails sends `Cache-Control: max-age=0, private, must-revalidate` on the redirect today, which standard caches respect.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: The seasons page's import check (`Steam::UnfinishedImportRun`) and the publish lock can race: a run started or resumed between the check and `Catalog::PublishSeason`'s lock could write cards after the publication.
  evidence: Story 2.6 review finding 2, rejected (low). It needs two administrator actions in the same instant; closing it needs a lock across `Steam` and `Catalog`, which AD-2 forbids.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-refactor-sweep-plan.md`
  summary: The rescore variant of the publish-lock race (epic 2 retrospective, F2): `Steam::RescoreCards.refusal` reads the draft and published seasons without the season lock, so a rescore committed between the seasons page's check and `Catalog::PublishSeason`'s lock lets the publication through; its later pages then find no draft, open draft N+1, and the run spans two seasons.
  evidence: Epic 2 retrospective F2, deferred; recorded by story 4.6. As with the 2.6 entry above, it needs two administrator actions in the same instant, and closing it needs a lock across `Steam` and `Catalog`, which AD-2 forbids.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-refactor-sweep-plan.md`
  summary: The AD-5 freeze (a published season's card-seasons, sets and memberships never change) is enforced only in models, by validations and `before_destroy` callbacks; a later bulk write (`update_all`, `insert_all`, raw SQL) could change rarities under owned cards without any error. A database trigger is the option; its frozen columns need design first.
  evidence: Epic 2 retrospective F5, deferred; recorded by story 4.6. `card_season.rb`, `set.rb` and `set_membership.rb` hold the freeze; no migration adds a trigger or check, and the only bulk writes in `Catalog` today (`PublishSeason`) run on the locked draft before the flip.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-refactor-sweep-plan.md`
  summary: The run's error log keeps the last 20 lines (`Steam::ImportRun::ERROR_LIMIT`) and the cards step writes one per refused card, so on a real run with many refusals the failure that triggered a resume falls off, and the refused games cannot all be listed during calibration.
  evidence: Epic 2 retrospective F7, deferred; recorded by story 4.6. Waits on the real import's refusal count: revisit if it refuses more than a handful of cards.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: On a run's page, the "Rescore the cards" button reappears only after a full reload once the rescore completes: the polled frame does not hold it.
  evidence: Story 2.8 review finding 4, rejected (low, cosmetic). The run page is reloaded after a calibration anyway.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: In the calibration preview, a genre literally keyed `none` would share the "no genre" row (`_preview.html.erb` keys a nil genre as `none`).
  evidence: Story 2.8 review finding 5, rejected (low). Steam's genre keys never produce `none`; the row is only read by the author during calibration.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: The first real Steam import and the calibration are not done: the full run's duration per step, the kept count (story 2.3), the details and genres steps against real Steam (story 2.4), the real prestige scores and `Steam::PrestigeScore::COUNT_WEIGHT` (story 2.5), and the tier shares, tome size and the author's approval of the calibration (story 2.8). Story 2.1's manual check (kill the import worker mid-run, restart, no duplicate app) belongs to the same real run.
  evidence: Story 2.3 review finding 4 (deferred) and its Implementation Notes; story 2.4 Implementation Notes ("Manual check (real Steam) not done"); story 2.8's hitl check. Both runs wait in `pending-approvals.md` (full real import in development; deploy to the test LXC and import there).
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: `Catalog::UpsertDraftCard`'s slug-index race (two new cards taking the same slug at once) has no test of its own.
  evidence: Story 2.2 review finding 6, rejected (low). Handled by the shared `RecordNotUnique` retry loop; a concurrent slug collision is unlikely with one import writer, and the test needs plumbing only.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: `Catalog::UpsertDraftCard` given texts under both `"en"` and `:en` keeps one silently.
  evidence: Story 2.2 review finding 7, rejected (low). `Steam::CardMapping`, the only caller, builds string keys; a guard would add a branch for no current caller.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: No test makes the real `Catalog::UpsertDraftCard` fail inside its own transaction under `Steam::ImportCardsPage`'s per-card savepoint; the refused-card test uses a double that fails after a real upsert.
  evidence: Story 2.5 review note, rejected (low). The path is covered by the double's rollback and by the reading of dry-operation's ActiveRecord `transaction`.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: Findings of epic 2 rejected as false, kept for the record, no action: `bin/packwerk` has no binstub (story 2.1, finding 6: CI runs `bundle exec packwerk check`); no index on `(import_run_id, appid)` for the review pages (story 2.3, finding 5: the page walks the unique `appid` index from the cursor); a later run's exclusion makes `ready_by(earlier_run)` lose an app (story 2.4, finding 5: rows hold the latest run's results by design, and `ready_by` is only read for the run in progress).
  evidence: The Review Triage Logs of stories 2.1, 2.3 and 2.4.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-pack-reveal-island-plan.md`
  summary: Re-run `game:benchmark_open_pack` and update the epic Notes, since the result page now builds CardViews, CardStrings and BankSummary.
  evidence: Story 3.6 review row 8; the 3.9 GET figure (p95 ~4.7 ms) predates the reveal page.
  resolved: Re-run in story 3.10: POST p95 8.8 ms, result page GET p95 7.5–8.1 ms; recorded in the epic Notes.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-open-a-pack-end-to-end-plan.md`
  summary: A signed-out owner opening their own pack link gets a 404 rather than a sign-in prompt.
  evidence: Story 3.1 review row 4, rejected as deliberate (unknown, foreign or unopened tokens are 404); revisit if pack links are ever shared or bookmarked.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-card-component-plan.md`
  summary: The large card back is the 80 × 120 back drawn at ×3 (3 CSS px per art pixel) until the author decides on a redrawn 120 × 180 back.
  evidence: Story 3.5 assumption, listed in pending-approvals.md.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-pack-reveal-island-plan.md`
  summary: The reveal is lost (faces shown) when another request of the same session consumes the flash between the opening and the result page.
  evidence: Story 3.6 review row 7, accepted known edge.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-pack-reveal-island-plan.md`
  summary: The "leave during flip all" system test cannot observe live timers; the guarantee rests on the Vitest cancel test and the unmount cleanup.
  evidence: Story 3.6 review row 6, rejected (React ignores state updates on an unmounted root without an error).
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-pack-reveal-island-plan.md`
  summary: Wiping by sliding a finger on a real phone is not covered by an automated test.
  evidence: Story 3.6 matrix row "Touch slide", a manual check; Selenium cannot drive touch pointer events.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-replacement-packs-and-the-timer-plan.md`
  summary: The attic countdown shows mm:ss only; a pack scheduled more than an hour ahead (test-built or odd data) would read like "1440:00".
  evidence: `app/views/pages/home.html.erb` formats `"%02d:%02d", *@next_pack_in.divmod(60)`; packs made by the replacement rule are never more than ten minutes away (story 3.2 plan, Boundaries).
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-first-session-guarantee-plan.md`
  summary: Kept for the record, no action: the forced card's position uses `tenth.size` rather than `Pack::SIZE`.
  evidence: Story 3.3 review, judged false — equal for every bank pack.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-signed-out-attic-plan.md`
  summary: Kept for the record, no action: the visitor tests live in the packs, daily-bonus and a new system test file rather than the Code Map's files.
  evidence: Story 3.8 review, rejected — coverage complete.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/epic-steam-catalog-retrospective.md`
  summary: Deferred from the epic 2 retrospective (2026-10-03), for the next sweep: the rescore variant of the publish-lock race (F2, next to the 2.6 entry); the AD-5 freeze enforced only in models, a database trigger being the option (F5); set membership versus live card fields for epic 4's set screens (F6); the capped refusal log (F7); tests for the store request spacing, the queue configuration and the retry-versus-stall timing, and the stale rate-limit comment in `import_genres_page.rb` (gone with story 2.10).
  evidence: Retrospective findings F2, F5, F6, F7 and action item 4; the draft pruning, malformed apps and run abandonment went to story 2.11.
  resolved: Story 4.6 (refactor sweep). F6 is resolved by epic 4 as built: `SetLabel` names every set from `catalog_sets.params`; only the tome heading's year range and the detail's publisher read live card fields, which are the card's own identity. The queue configuration (`config/queue.yml` dispatches and serves `default`, the queue of `Game::HealBanksJob` and of `Steam::RecoverStalledImportsJob`) and the retry-versus-stall timing (`Steam::ImportStepJob`'s waits sum to less than `STALL_AFTER`) are tested in `test/config/queue_config_test.rb` and `test/jobs/steam_import_step_job_test.rb`. The store request spacing test and the stale `import_genres_page.rb` comment went with story 2.10 (no `StoreApi`, no genres page). F2, F5 and F7 are recorded as entries of their own.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/epic-packs-and-reveal-retrospective.md`
  summary: Deferred from the epic 3 retrospective (2026-10-03): D1 (the pack-row hash built in three places), O2 (`card_season_ids` has no database check on length or kind) and O5 (`HealBanksJob` walks every player on each publication) for a sweep; B4–B6 (bankless players, unretried heal failures, healed-bank schedule) are epic 7 Done when 6; B7–B8 (countdown keying, UTC-only screen-reader text) go to the UX redesign.
  evidence: Retrospective findings D1, O2, O5, B4–B8; the phone "flip all" defect went to story 3.11.
  resolved: Story 4.6 (refactor sweep) did D1, O2 and O5. D1: `Game::Pack.row` builds the row for `Game::FillBank`, `Game::TopUpBank` and `Game::CollectDailyBonus`. O2: the check `game_packs_card_season_ids_check` (migrations `20261003060000` and `20261003060001`) refuses a list that is not one-dimensional, empty or holding a NULL, and any size but five for a regular pack and three for a bonus pack. O5: `Game::HealBanksJob` reads each batch's banks in one grouped query and skips a full bank without another query. B4–B8 stay with epic 7 and the UX redesign.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-import-without-the-store-api-plan.md`
  summary: Contract migration owed for story 2.10 (expand/contract): drop `steam_apps.genres`, `credit`, `app_details`, `genres_run_id` (with its foreign key to `steam_import_runs`) and `genres_exclusion` (with its check `steam_apps_genres_exclusion_check`), and `catalog_cards.credit`; then remove them from `Steam::App.ignored_columns` and `Catalog::Card.ignored_columns`.
  evidence: Story 2.10 removed the genres step and the store API and ignores these columns without dropping them, so a deployed version still running the old code keeps working during the rollout.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-import-hardening-before-season-1-plan.md`
  summary: Two malformed inputs still fail a page after story 2.11: a store title long enough to break the slug's unique index (about 2.7 kB) still fails the cards page that writes it, and a whole Steam answer that is not valid JSON still fails the page that asked for it (retried, then the run fails, as before).
  evidence: Story 2.11 hardens the values inside a well-formed answer (`Steam::RawValue`, `Steam::ReviewPolicy`, `Steam::DetailsPolicy`, `Steam::WebApi`, `Steam::ImportAppListPage`) and leaves the slug index and the JSON parse error out of its scope.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-card-detail-plan.md`
  summary: An empty slot's link was named by `card_details.open` ("<title>, <rarity>, season n"), which replaced its visible text for screen readers: "Missing card" was not announced and an empty slot sounded like an owned face.
  evidence: Story 4.3 review finding 2, deferred (medium); in pending-approvals.md.
  resolved: Story 4.6 (refactor sweep): `link_to_card_detail` names an empty slot by its visible text (title, year, "Missing card"), with no `aria-label`; owned faces and the pack page's faces keep their label. Asserted in `test/controllers/library_set_test.rb` and `test/controllers/public_profiles_controller_test.rb`.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-card-detail-plan.md`
  summary: Two low findings of story 4.3, kept for the record: `card_detail_store_url` puts Steam's `l=french` in the web layer (AD-4) and re-encodes an existing query; and a face's link name ("<title>, <rarity>, season n") leaves out the year the face carries as visually hidden text.
  evidence: Story 4.3 review finding 3, rejected (the intent asks for `l=french`, every store URL is a Steam URL, and moving it into `Steam` adds surface for a fork that does not exist), and the face-link half of finding 2, deferred; story 4.6 left both as they are, outside a cleanup.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-public-profile-plan.md`
  summary: The persona lookup at sign-in (`GetPlayerSummaries`) sets `timeout: 5` and `open_timeout: 5` separately, so a Steam slow both to connect and to answer could hold a sign-in about 10 s rather than 5 s.
  evidence: Story 4.4 review finding 5, rejected (low): rare, still bounded and retry-free; an exact total bound needs a wrapping timer.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-public-profile-plan.md`
  summary: A banned player's sign-in still makes the persona lookup's Steam call (nothing is stored; the ban check refuses it after), and sign-in tests that do not stub the lookup report a harmless stub miss (`Faraday::Adapter::Test::Stubs::NotFound`) through `Rails.error.report`.
  evidence: Story 4.4 residual risks and Implementation Notes: `SessionsController#persona_name` runs before `Accounts::SignIn` for every verified Steam id.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-library-of-sets-plan.md`
  summary: AD-11's `reading` database role is not configured: the library, profile and card detail pages, read-only and tolerant of delay, run on the primary's default role.
  evidence: Story 4.1 Boundaries ("AD-11's reading role is not configured yet; deferred"); the architecture's Deferred section adds a replica only when the primary's read load is measured as the limit.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-tome-slots-plan.md`
  summary: The player's own library has no "set complete" styling: only the public profile marks a fully owned set ("Complete", `mark_complete: true`).
  evidence: Story 4.2 Boundaries ("'Set complete' styling is deferred (EXPERIENCE marks it an assumption)"); story 4.4 kept the library's three tabs and no label.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/epic-collection-and-sharing.md`
  summary: The status band's counts per rarity (EXPERIENCE.md) are not built.
  evidence: Epic 4 Notes, Decision 2026-10-02: not in this epic's Done when; left for a later story.
