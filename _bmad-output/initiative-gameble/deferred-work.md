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
  evidence: Epic 2 retrospective F5, deferred; recorded by story 4.6. `card_season.rb`, `set.rb` and `set_membership.rb` hold the freeze; no migration adds a trigger or check, and the only bulk writes in `Catalog` today, `PublishSeason`'s `update_all` (before the flip) and `PruneDraft`'s `delete_all` (which skips the `before_destroy` callbacks), run on the locked draft only.
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
  summary: The persona lookup at sign-in (`GetPlayerSummaries`) sets `timeout: 5` and `open_timeout: 5` separately, so a Steam slow both to connect and to answer could hold a sign-in about 10 s rather than 5 s. A missing or invalid Steam key fails that lookup with a warning in the log only (`SessionsController#persona_name` logs `Steam::WebApi::Error`), so in production every profile would silently fall back to "Brother <code>" while sign-in goes on.
  evidence: Story 4.4 review finding 5, rejected (low): rare, still bounded and retry-free; an exact total bound needs a wrapping timer. The warn-only key failure is the epic 4 retrospective's O1 (deferred, action item 7); a boot check or a reported error (as for other failures) are the options.
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
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-refactor-sweep-plan.md`
  summary: A database loaded from `db/schema.rb` dumps the three `steam_*` checks (`steam_apps_details_exclusion_check`, `steam_apps_review_exclusion_check`, `steam_import_runs_status_check`) in another form than a database migrated from scratch, so a migration run on a schema-loaded test database rewrites them in `db/schema.rb` and CI's drift step (`db:create db:migrate && git diff --exit-code -- db/schema.rb`) fails.
  evidence: Story 4.6 follow-up review (medium, pre-existing since story 2.11). `db/schema.rb` holds the fresh-migrate form (`'x'::character varying::text`), which a fresh `postgres:18` container reproduces with CI's step; recreated from `db/schema.rb`, the check deparses as `('x'::character varying)::text` (PostgreSQL 18.6). Workaround: `RAILS_ENV=test bin/rails db:drop db:create db:migrate` before committing a migration. A fix would rewrite the three checks in a form that round-trips.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: `Accounts::SignIn` writes the persona name (`update!`) inside the sign-in transaction, so a write that fails (a future validation on `Player`, a check constraint) would roll the whole sign-in back rather than keep the stored name.
  evidence: Epic 4 retrospective O2, deferred (latent: nothing validates `persona_name` today, and `Accounts::PersonaName.clean` leaves no NUL byte). Story 4.7 kept the write where it was.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: Public pages are neither throttled nor cached: a profile request runs about ten queries, a season-wide grouped read among them, and since story 4.7 a card's page and the library are read from shared links by any browser and crawler too. Throttle or cache them before launch.
  evidence: Epic 4 retrospective O4, deferred to launch readiness (epic 7); `config/initializers/rack_attack.rb` says "Page reads are never throttled".
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: Two small edge cases: `og_locale` reads `OG_LOCALES` with `fetch`, so a third locale added to the routes without its Open Graph name makes every card page a 500; and `SetLabel.for` gives a nil label for a publisher set whose `params` has no `publisher` name.
  evidence: Epic 4 retrospective O5, deferred (the import always sets the publisher name; adding a locale is a deliberate change). The third O5 point, a holder's own `/cards/…` address without preview tags, is resolved by story 4.7: the card's page is the share link and carries them.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: The request-test helpers `hold` and `sign_in` (Steam mock) are still copied in about 11 test files outside epic 4, beside `test/support/library_requests.rb`.
  evidence: Epic 4 retrospective D2, deferred; the story 4.6 follow-up review rejected it as out of scope. For a later sweep.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: The reveal's failure paths have no test: no test references `RevealErrorBoundary` (`app/frontend/components/RevealErrorBoundary.tsx`), and `test/controllers/packs_controller_test.rb` only asserts that the server-rendered fallback exists, not that it shows when the island fails to mount or throws.
  evidence: Epic 3 retrospective B3 (action item 2), which had no route; carried by the epic 4 retrospective (previous-retro follow-through, action item 7).
  resolved: Story 11 (booster island, desktop) removes PackReveal and `RevealErrorBoundary`; its successor `BoosterErrorBoundary` is untested too (new entry below).
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: A persona name is cut to 64 code points, not 64 graphemes, so the cut can split a letter from its combining mark, an emoji from its modifier or a flag's pair.
  evidence: Story 4.7 review (blind hunter, edge-case hunter), deferred as pre-existing: story 4.4 already cut with `first(64)`; `Accounts::PersonaName.clean` keeps that rule. A fix would cut with `grapheme_clusters.first(LENGTH).join`.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: The visitor invitation's `section` takes the whole visible sentence as its `aria-label`, so a screen reader reads it twice; it is also a `card-detail__` element outside the `.card-detail` block.
  evidence: Story 4.7 review (blind hunter), deferred as pre-existing: story 4.5's `public_profiles/card.html.erb` had the same markup, moved as is to `cards/show.html.erb`. A fix would use `aria-labelledby` on the plate's paragraph; the UX redesign may replace the invitation.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: An older browser let onto a card's page sees the invitation and the status band's "Back to the attic", and both lead to a 406 (Steam callback, attic).
  evidence: Story 4.5's deferred finding, now on the card's page since story 4.7 makes it the share link (story 4.7 review, intent alignment); the decision is pending in `pending-approvals.md` ("Older browsers signing in from a shared card").
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md`
  summary: Transitional: the player chip opens a small popover menu (own public profile, back-office for staff, sign out) instead of Profil et paramètres (EXPERIENCE.md, Player chip), until that screen exists.
  evidence: Story 8.1 Design Notes; `app/views/shell/_player_chip.html.erb`.
  resolved: In part by story 10.4: the popover's first entry opens Profil et paramètres (`settings_path`); the chip itself still opens the popover, not the screen.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md`
  summary: Transitional: the phone tab bar's BOOSTER, ÉCHANGES and PLUS tabs render disabled (`aria-disabled`, not links), and the top bar's packs chip is not a link to the booster screen (EXPERIENCE.md, Packs chip), until their screens ship.
  evidence: Story 8.1 Design Notes; `app/views/shell/_tab_bar.html.erb`, `app/views/shell/_packs_chip.html.erb`.
  resolved: In part by story 11: the BOOSTER tab and the packs chip link to the booster screen; ÉCHANGES and PLUS stay disabled until their screens ship. Story 10.4 makes PLUS a link to its rows (`more_path`); only ÉCHANGES stays disabled, until the trades screen (epic 5). Story 5.6 makes ÉCHANGES a link to the trades screen, with its waiting badge; no tab stays disabled.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md`
  summary: Transitional: the packs chip's countdown stops at 00:00 and never refreshes the page (`countdown` controller with `refresh: false`); the new count appears on the next visit or when the hub's own countdown refreshes it.
  evidence: Story 8.1 Design Notes; `app/frontend/controllers/countdown_controller.ts`.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md`
  summary: Transitional: the `view-transition` meta is always rendered (AD-27 wants it only when motion is allowed); there is no stored "Animations réduites" setting yet, so CSS removes the screen-change animation under `prefers-reduced-motion` or `html[data-motion=reduced]`.
  evidence: Story 8.1 Design Notes; `app/views/layouts/application.html.erb`, `app/frontend/styles/shell.css`.
  resolved: Story 10.4: `layouts/_head.html.erb` renders the meta only unless `motion_reduced?` (the stored setting or its cookie), and `html[data-motion=reduced]` is the one switch.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md`
  summary: The public card page (`cards#show` for a visitor, the share link) still wears the app chrome (back button, phone tab bar) where DESIGN.md asks for a slim top bar with the logo and the official Steam image, and EXPERIENCE.md hides the tab bar.
  evidence: Story 8.1 quick review, deferred as pre-existing (the old shell wrapped it too); the public card page belongs to epic-space-terminal-screens.
  resolved: Story 10.3: a visitor's card page renders `cards/_public` under the slim top bar (`content_for :public_page`: the logo and the official Steam image, no back button, no tab bar).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md`
  summary: The card page keeps a game-styled text button that posts to `/auth/steam` (`app/views/cards/show.html.erb:18`), while DESIGN.md makes Valve's official image the only link to Steam's sign-in.
  evidence: Story 8.1 quick review, deferred as pre-existing; story 8.2's sign-in panel replaces such calls to action.
  resolved: Story 10.3: the public card page's invitation opens the sign-in panel (`opens: "sign-in-panel"`); `SteamSignInComponent`, Valve's image, is the only link to Steam's sign-in (top bar and panel).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md`
  summary: The top bar reads `Game::BankSummary` on every signed-in page; its `bonus_collectable` part (published-season lookup, daily-claim check) is unused by the packs chip, so up to two queries per page are wasted.
  evidence: Story 8.1 quick review; the hub's duplicate read was patched (`shell_bank` reuses `@bank`), the rest needs a parameter or a narrower query.
  resolved: Story 8.13: `Game::BankSummary.reserve` (reserve count, next pack: two queries) feeds the top bar's chips, the booster screen and the pack page, which also stopped reading the summary twice; the hub and the daily claim keep `call`. A signed-in card page runs 8 queries instead of 10, a profile 11 instead of 12; the chips read the summary's `reserve_full`.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-architecture-conformance-plan.md`
  summary: Enforce the Content-Security-Policy (AD-27). It runs report-only in every environment since this story; after one release, read the violations Sentry collected (`report-uri`, only where `SENTRY_DSN` is set), fix them, then set `config.content_security_policy_report_only = false` in `config/initializers/content_security_policy.rb` for production (development keeps its own Vite policy).
  evidence: AD-27 "It runs report-only for one release first". Known violations to settle before enforcing: Mission Control Jobs (`/back-office/jobs`) renders inline importmap scripts, which `script-src 'self'` refuses (give the engine its own policy through a controller-level `content_security_policy` block, or nonce its scripts); any server-rendered `style=""` attribute (none today; React's `style` props go through the CSSOM and are not affected). The nonce is the session id; a response that never loaded the session gets a random one.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-architecture-conformance-plan.md`
  summary: Enqueuing from a GET under the read-only role is proven only with the test queue adapter: in development and production Solid Queue writes through `SolidQueue::Record`, its own connection class (`config.solid_queue.connects_to`), which the `reading` role switch on `ApplicationRecord` does not touch. No GET enqueues today; check it in development the first time one does.
  evidence: `test/controllers/read_only_requests_test.rb` ("a GET may enqueue a job") runs on the `:test` adapter; the test environment configures no Solid Queue database.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-architecture-conformance-plan.md`
  summary: The `reading` role opens a second connection pool to the primary, so each web process may hold up to 2 × `RAILS_MAX_THREADS` primary connections (a GET leases from `reading`, the event store's `ActiveRecord::Base` models from `writing`). Check Postgres `max_connections` on the test LXC against the web, Solid Queue, Solid Cache and Solid Cable pools.
  evidence: Story 8.4 review (blind, edge-case and verification-gap lenses), checked with `bin/rails runner` outside a test case; transactional tests share the pools and cannot show it.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-architecture-conformance-plan.md`
  summary: No test builds the CSP `report-uri` (Sentry) or the development Vite policy; both are decided at boot. Before reading the report-only release's violations, check once that the deployed response's `Content-Security-Policy-Report-Only` header carries `report-uri https://…/api/<project>/security/?sentry_key=…`. Mission Control's inline scripts will report on every `/back-office/jobs` load meanwhile (administrators only).
  evidence: Story 8.4 review (verification gap); `test/initializers/sentry_test.rb` keeps `SENTRY_DSN` blank in the suite, so the branch never runs.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-architecture-conformance-plan.md`
  summary: A font file under Vite's 4 KB inline limit becomes a `data:` URI, which `font-src 'self'` refuses once the CSP is enforced. None exists today; when the shell's subsetted woff2 files land, exclude fonts from `assetsInlineLimit` in `vite.config.ts` (as card images are) or check none is under the limit.
  evidence: Story 8.4 review (edge case, unverified): `vite.config.ts` excluded only `/images/card/` from inlining; story 11 removed that rule with the old card images, so `vite.config.ts` sets no `assetsInlineLimit` now.
  resolved: Story 8.13: `vite.config.ts` sets `build.assetsInlineLimit` so a `.woff`/`.woff2` file is never inlined (checked with a 1 KB probe font emitted as its own file); the six woff2 files of story 8.14 weigh 15.8 to 17.9 KB anyway.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-pixel-filter-v2-plan.md`
  summary: The Content-Security-Policy of story 8.4 must allow the pixel filter's module worker (`worker-src 'self'`) and list the Steam image hosts in `connect-src` as well as `img-src`, because the worker loads covers with `fetch`; without them every cover falls back to the plain main-thread path without palette.
  evidence: Story 8.5 moves cover loading into `packages/pixel-art-filter/src/worker-job.ts` (`fetch` with `mode: "cors"`), started by `new Worker(new URL("./worker.ts", import.meta.url), { type: "module" })` in `src/renderer.ts`; no CSP is configured yet (feasibility M8, story 8.4).
  resolved: Story 8.4: `config/initializers/content_security_policy.rb` sets `worker-src 'self' blob:` and lists `Steam::Cdn::IMAGE_SOURCES` in `connect-src` as well as `img-src`.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-tier-names-and-season-numbers-plan.md`
  summary: Contract step for card numbers (AD-28): once `catalog:number_seasons` has run on every database, add a migration making `catalog_card_seasons.number` required for published card-seasons (e.g. a check `rarity IS NULL OR number IS NOT NULL`, added `validate: false` then validated), and drop the nil case of `CardView#number`/`number_label` and the TypeScript `number: number | null`.
  evidence: Story 8.3 shipped the expand step only (nullable column); seasons published before it stay unnumbered until the backfill (pending-approvals.md, "Number the published seasons").
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-tier-names-and-season-numbers-plan.md`
  summary: Rake task tests load the tasks in `setup` outside `capture_io`; in the parallel suite some workers re-load `game_benchmark.rake` and print constant-redefinition warnings to stderr. Load the application's tasks once per process (guard on `Rake::Task.task_defined?`) in a shared test helper.
  evidence: Story 8.3 implementation (`test/lib/catalog_number_seasons_task_test.rb`); the same pattern predates it in the player-state backfill test, which does not assert on stderr.
  resolved: In part by story 8.13: `test/support/rake_tasks.rb` (`RakeTasks#rake_task`, guarded on `Rake::Task.task_defined?`) is the one loader of the three rake-task tests, called outside `capture_io`. The warnings remain, once per worker of a full or directory run, and their cause is now known: `bin/rails test` without exact file arguments first runs `test:prepare` through `Rails::Command::RakeCommand`, in a Rake application of its own, so the .rake files' constants are defined in the forked workers but no task is, and each worker's first `load_tasks` redefines `OpenPackBenchmark`'s constants (20 warning lines in the 8.13 runs, none in a run of named files). A fix would move `OpenPackBenchmark` out of `packs/game/lib/tasks/game_benchmark.rake` into a file the task `require`s once.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-hub-and-sign-in-panel-plan.md`
  summary: Transitional: the hub's menu 01 (and the empty showcase's "Ouvrir un booster") is the existing open-pack form, opening a booster straight to its reveal, not a link to the booster screen (EXPERIENCE.md, Ouverture de booster), until that screen exists.
  evidence: Story 8.2 Design Notes; `app/views/pages/_menu.html.erb`, `app/views/pages/_showcase.html.erb`.
  resolved: Story 11 makes menu 01, the empty showcase's button and the pack page's "Ouvrir un booster" links to the booster screen (`booster_path`).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-hub-and-sign-in-panel-plan.md`
  summary: Transitional: menu items 03 to 06 (Échanges, Amis, Fil d'activité, Succès) render disabled (`aria-disabled`, "bientôt disponible"), without their badge or meta, until their screens exist.
  evidence: Story 8.2 Design Notes; `app/views/pages/_menu.html.erb`.
  resolved: In part: 04 Amis opens the Friends screen (story 5.1) and 05 Fil d'activité the public feed (story 6.1); 03 Échanges (epic 5) and 06 Succès stayed disabled. Story 5.6: 03 Échanges opens the trades screen with its orange waiting badge; only 06 Succès stays disabled.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-hub-and-sign-in-panel-plan.md`
  summary: Transitional: the showcase has no planet, rays or idle float, its card is the `card-xl` face (240 × 360, story 8.6) on the phone too where DESIGN.md asks `card-l`, and its line lacks the genre and the card number (DESIGN.md, Showcase), until the pixel assets (8.8), effects (8.6) and card face (8.3, 8.6) land.
  evidence: Story 8.2 Design Notes; `app/views/pages/_showcase.html.erb`, `app/frontend/styles/hub.css`.
  resolved: In part: the card is the `card-xl` face (story 8.6), and since story 8.13 the line gives the rarity, the tome's genre and the number (`S1 · #4`), each left out when missing. The planet, the rays and the idle float (one shared piece of work with the card detail and the public card page, entries below) and `card-l` on the phone remain.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-hub-and-sign-in-panel-plan.md`
  summary: Transitional: the phone hub shows no packs chip or rarity counter block of its own (the top bar's chip stays), no community goal panel and no LIVE ticker (epic 6, story 8.8); their slots are left out.
  evidence: Story 8.2 Design Notes and Never list; `app/views/pages/home.html.erb`.
  resolved: In part by story 6.3: the community goal panel shows on the hub, phone included. The phone's own packs chip and rarity counter block and the LIVE ticker (epic 6) remain.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-hub-and-sign-in-panel-plan.md`
  summary: Transitional: once the day's booster is collected the daily booster panel is hidden until the next UTC day, where DESIGN.md shows "RÉCUPÉRÉ" with the countdown and a thin bar (story 10.4).
  evidence: Story 8.2 Design Notes; `app/views/pages/home.html.erb`.
  resolved: Story 10.4: the panel stays once collected, in its `collected` state with the countdown to the next 00:00 UTC (`pages/_daily_booster.html.erb`).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-hub-and-sign-in-panel-plan.md`
  summary: `test/system/pack_reveal_test.rb` failed intermittently in 2 of 4 full system-suite runs during story 8.2 (once in setup, the top bar's Steam button not found; once at the end-of-reveal buttons), never when run alone; cause unknown, possibly pre-existing.
  evidence: Story 8.2 implementation report; the orchestrator's full runs passed.
  resolved: Story 11 removes `pack_reveal_test.rb` with the reveal; `test/system/booster_test.rb` replaces it.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-single-card-face-plan.md`
  summary: A phone's long press on a card face inside a link (tome, pack result) may open the browser's link context menu or a text selection after about 500 ms, cancelling the pointer and ending the finger's tilt early; if so, suppress it while a finger tilts (`contextmenu` prevented, `-webkit-touch-callout: none`, `user-select: none` on `.card`).
  evidence: Story 8.6 review (unverified, medium if true): `attachTilt` (`app/frontend/lib/tilt.ts`) handles no `contextmenu` and `.card` sets no callout or selection rule; settle it with a long press on a tome face on an Android Chrome and an iOS Safari device.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-single-card-face-plan.md`
  summary: Every card face registers a non-passive `touchmove` listener (`attachTilt`, to stop the page scrolling under a tilting finger), so a touch scroll starting on a card waits for the main thread; on a 300-card tome on a low-end Android this may cost scroll latency (AD-27). Adding the listener only while a finger tilts would not work (Chrome classifies a touch sequence at its start), so a fix needs another design (e.g. one delegated listener, or `touch-action` switched before the hold ends).
  evidence: Story 8.6 review (unverified, medium if true): `app/frontend/lib/tilt.ts` adds `touchmove` with `{ passive: false }` per card; settle it with a Chrome performance trace of a touch scroll over the tome on a low-end Android device.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-single-card-face-plan.md`
  summary: The card face visual baselines (`test/fixtures/files/card_faces/*.png`, mean difference ≤ 1.5 per channel) were captured with Manjaro's Chromium; CI's `system-test` job runs ubuntu-latest's Chrome, whose font rasterisation and 3D resampling may differ enough to fail `card_face_visual_test.rb` on CI only. If it does, regenerate the baselines on CI's browser (`UPDATE_CARD_BASELINES=1`) or pin one browser build for both.
  evidence: Story 8.6 review (unverified, medium if true): `test/support/card_baselines.rb`, `.github/workflows/ci.yml` (no `CHROME_BIN`); settle it with the first CI run after the commit.
  resolved: Settled by CI: the `system-test` job, `card_face_visual_test.rb` included, passed on ubuntu-latest's Chrome with the baselines story 8.14 regenerated (pull request run 37627470120; develop run 37632657944 at e419296).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-single-card-face-plan.md`
  summary: `script/card_art/generate.mjs` cannot run any more: it reads `ux-gameble/mockups/card-backs.html`, removed by the UX redesign (5de0377); the card backs and `sprite.svg` can only be edited by hand until story 8.11 redraws the backs.
  evidence: Story 8.6: re-running the script to drop the unused season seal and glyph symbols failed with ENOENT; those symbols were removed from `app/frontend/images/card/sprite.svg` by hand and from the script.
  resolved: Story 11 removes `script/card_art/` and `app/frontend/images/card/` (the old backs and seal sprite, used only by the reveal); the booster draws the exported `images/pixel/back-standard-m.png` (story 8.8).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-opening-exchange-plan.md`
  summary: A JSON opening (AD-23) with a missing or stale CSRF token answers Rails' 422 HTML page, not the `{ error: { code, message } }` envelope; the booster island (8.11) must send `X-CSRF-Token` and decide how a stale token (another tab signed out) is answered or handled.
  evidence: Story 8.10 review: ApplicationController keeps `protect_from_forgery with: :exception` and rescues only Pundit's refusal; the test environment disables forgery protection, so no test covers it.
  resolved: Story 11: the booster island sends `X-CSRF-Token` from `meta[name=csrf-token]`; Rails' HTML 422 is read as an unknown outcome (generic reason inline, toast, live region; the idempotency key kept), covered by `booster_test.rb` ("a stale CSRF token"). The server answer stays HTML.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-drop-dust-tier-plan.md`
  summary: Remove `dust_tier` from `Catalog::CardSeason.ignored_columns` (`packs/catalog/app/models/catalog/card_season.rb`) once development and the test LXC have run `20261006100000_remove_dust_tier_from_catalog_card_seasons`.
  evidence: Story 8.7, the contract step of AD-28: strong_migrations' column removal needs the column ignored before `remove_column`, and the ignore stays until every environment has dropped it.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-collection-and-sets-plan.md`
  summary: The collection grid uses fixed `card-m` faces (160 × 240) in as many columns as fit, where DESIGN.md (Collection grid) asks cards resized between 120 and 170px wide to fill the row, the small face layout under 140px, and the pixel filter re-run at the rendered art size after a resize.
  evidence: Story 10.1 Never list; `app/frontend/styles/collection.css` (`.collection-grid`, `repeat(auto-fill, var(--card-m-width))`).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-collection-and-sets-plan.md`
  summary: A grid slot opens the card's detail page (story 10.2's "FICHE DE LA CARTE", browsing the set shown); the in-screen detail beside the grid on a tablet and desktop (340px from 1180px, 300px below; EXPERIENCE.md Responsive), which can render `cards/_detail` (its container query stacks it at 340px), and the selected card's accent frame are not built. From the whole-season collection each link names the card's tome (story 10.2's follow-up), so the detail browses that tome and fades a card not held; its "◀ Grille" and browser Back return to the season grid it was opened from (at its scroll), and lead to the tome's grid only when the detail was not opened from a grid of this tab's history.
  evidence: Story 10.1 Never list; story 10.2 Design Notes; `app/views/library/_grid.html.erb`.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-collection-and-sets-plan.md`
  summary: Transitional: the public profile keeps the first direction's shelf and tome (`library/_shelf`, `library/_tome`, `ShelvesHelper#profile_shelf_links`, `library.css`, and the keys only they use: `library.tome.*`, `library.set.back_to_shelf`, `library.show.tabs.label`, `library.show.tabs.started`, `library.show.empty.started`, `library.show.progress`, `library.show.complete`) until story 10.3 redraws it; remove them then. The `library.show.*` keys the collection also uses (`tabs.tome|publisher|best_of_year`, `empty.tome|publisher|best_of_year`, `past_the_end`, `no_season`) stay, or move under the collection's own keys.
  evidence: Story 10.1 Never list; `app/views/public_profiles/*`, `app/frontend/styles/library.css` header.
  resolved: Story 10.3 redrew the public profile on the collection's components and removed `library/_shelf`, `library/_tome`, `library.css` and the shelf's keys; story 10.5 removed the last two (`library.show.tabs.label`, `library.show.empty.started`) and reworded the shared `library.show.*` lines (empty lists, past the end, no season) without the old "Brother" wording. `library.show.tabs.*` stay: the collection and the profile both name their kind chips with them.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/tickets.toml` (entry 9, dropped)
  summary: Measure the booster, the filter worker on a 30-card page and the idle hub on a real low-end Android (AD-27's budget: frames, long tasks, at most six infinite animations per phone view); the spike 8.9 was dropped on 2026-10-06 (no physical device, emulation declined by the author).
  evidence: Epic 8 Notes, Decision of 2026-10-06; architecture Deferred, 'Reference low-end Android and the performance spike'.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md`
  summary: Dealt booster cards stay `card-m` (160 × 240) at every width; DESIGN.md (Layout & Spacing, Booster) steps them down to `card-s` (112 × 168) between 720 and 899px. Under 900px the row only wraps.
  evidence: Story 11 Never list (no width rebuild before story 8.12); the opening exchange already renders `m` and `xl` faces only (`PacksHelper::REVEAL_SIZES`), so a `card-s` deal needs an `s` face in the answer too.
  resolved: Story 8.12: the answer renders an `s` face too (`PacksHelper::REVEAL_SIZES = %i[s m xl]`); the island reads its layout from two media queries (`.booster[data-layout]`: `narrow` from 720 to 899px deals `faces.s` in 112 × 168 slots with the `s` card back, `wide` from 900px `faces.m`), and a width crossing 900px draws the same hand again at the other size, no request, nothing replayed (`booster_test.rb`, "from 720 to 899px the cards are dealt small…").
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md`
  summary: The booster's phone mode (story 8.12): the stacked pile, one `card-xl` card at a time, the reveal caption plate, the tray, the card zoom, "Touchez pour ouvrir" and the 44px information strip. Under 720px the desktop island and its wrapping row are shown as they are.
  evidence: Story 11 Never list; `app/frontend/components/Booster.tsx`, `app/frontend/styles/booster.css` (no phone layout beyond wrapping); the `revealed-xl.png` card baseline was deleted with the old reveal and returns with the phone booster.
  resolved: Story 8.12: under 720px the island draws the 44px strip (`BoosterStrip`), the canister with "Touchez pour ouvrir" and "N cartes", a pile of `card-xl` faces landing bottom card first, one activation revealing the top card, the caption plate hosting the tier, the Épique and the Légendaire's "Légendaire !" (`BoosterPlate`, never over the card), a tap, a swipe or "Ranger" storing the card into the tray (`BoosterTray`), Tout révéler storing each card, the card zoom (`BoosterZoom`, a native dialog), and a rebuild in place when the width crosses 720px. `revealed-xl.png` is back (the phone's pile, tilted); system tests in `booster_test.rb`.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md`
  summary: `BoosterErrorBoundary` (the island's fallback when its chunk fails to load or it throws) has no test: no test makes the island fail and checks the message and the reload link.
  evidence: Story 11; the same gap as the removed `RevealErrorBoundary` (epic 3 retrospective B3). A system test could block the lazy chunk's URL through CDP (`Network.setBlockedURLs`) before visiting the booster screen.
  resolved: Story 8.11 follow-up review: `booster_test.rb` "an island whose code does not load…" blocks `Booster-*.js` through CDP, checks the message, the no-JS form still offered and the reload link, which now reloads the whole page (`data-turbo="false"`: a Turbo visit kept the failed import).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md`
  summary: The booster's card backs: only `standard` is drawn (`booster-card__back--standard`); every other `pack.cardBack` key falls back to it until the card-back picker and the other backs ship (epic 9).
  evidence: Story 11 (AD-25); `app/frontend/lib/booster.ts` (`CARD_BACKS`, `cardBackClass`, tested in `booster.test.ts` since the 8.11 follow-up).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md`
  summary: Before the answer, the booster screen states the regular pack size (canister name "… 5 cartes", "Cartes révélées : — / 5", CARTES PAR BOOSTER 5) even when the next pack to open is a 3-card daily bonus (OpenPack opens the oldest available pack of any kind); the counts switch to the answer's card count at the deal. Showing the next pack's size needs it in the bank summary (or a prop) across the game pack's boundary.
  evidence: Story 11 review (rejected low: the intent sets the bonus pack's counts from the answer); `app/helpers/boosters_helper.rb` (`packSize: Game::Pack::SIZE`), `packs/game/app/operations/game/open_pack.rb`.
  resolved: Story 8.12: `Game::NextPackSize` (the card count of the pack `Game::OpenPack` would open now, nil when none) reaches the island in its props and in each answer's bank (`bank.nextPackSize`); before an answer the canister's name, CARTES PAR BOOSTER, "Cartes révélées : — / N" and the phone's "N cartes" use it (`packSize` when null), after it the answer's card count (`booster_test.rb`, "before the answer, a daily bonus pack first in line is counted as three cards").
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md`
  summary: Intermittent system-test failures seen once each under the parallel full suite and never alone — `BoosterTest` "a refusal …" failed in its setup because the hub was already signed in (no `.steam-sign-in__button`; seed 18869, not reproduced with the same seed), and `ShellTest` "the daily bonus's notice …" (both toast-through-refresh cases; seed 18869 rerun) missed their notice toast. Each passed 3 of 3 alone; four more full runs were clean.
  evidence: Story 11 verification, 2026-10-06. The signed-in setup suggests a session cookie restored after Capybara's reset by a request still in flight from the worker's previous test; the toast cases are timing-sensitive under load, like the known shell_test phone-toast flake.
  resolved: Story 8.11 follow-up review. The signed-in setups (BoosterTest's refusal, ShareCardTest's "feedback is gone" in another run) had one cause, reproduced on demand: Capybara's reset clears the cookies and only then waits for the server's pending requests, and every Rails answer re-sends the session cookie; the collection page's keepalive "seen" POST (story 10.1) outlives the page, so its answer signed the next test's browser in as the previous player. `ApplicationSystemTestCase#after_teardown` now resets, then clears the cookies again (`Network.clearBrowserCookies`) once the pending requests are over. The two ShellTest daily-bonus failures were the other kind: the failure screenshots show the notice toast arrived just after Capybara's 2 s, so those two assertions wait 6 s. TomeTest's 300-card art near the viewport (seen once) is art drawing under load, not the cookie.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md`
  summary: The booster screen's bank goes stale in two rare cases until a reload: the countdown reaching zero while cards are dealt (the refresh runs only while the island is idle, so with an empty reserve "Réserve vide · 00:00" stays and "Ouvrir le suivant" stays disabled), and a `no_pack_available` refusal keeping the page's `nextAvailableAt` (null when the reserve was full, so no countdown at all). A fresh bank once the hand is inventoried (or with the refusal) would settle both.
  evidence: Story 8.11 follow-up review (edge case, blind hunter; rejected low); `app/frontend/components/Booster.tsx` (the refresh-at-zero effect, `refuse`). A test pins that a dealt hand is never refreshed away.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-desktop-plan.md`
  summary: A pack whose cards were drawn in an earlier season (banked before a new season was published) makes the top bar's rarity counter overcount during its reveal: `tierCountsBefore` counts the published season only, the island adds one per revealed card. Corrected on the next page load; a per-card "counted" flag in the answer would fix it.
  evidence: Story 8.11 follow-up review (edge case; rejected low, season turnover only); `Game::TierCounts.before_opening`, `Booster.tsx` `mark`.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-phone-plan.md`
  summary: The phone booster's gestures (the swipe that stores the top card, a tap after the 400 ms guard, the 150 ms tilt hold that is never a swipe, the pile's `touch-action: none` beside the page's panning on the plate, tray and actions) were verified only with synthetic pointer events in headless Chromium; check them on an iOS Safari and an Android Chrome device, with the card zoom (native dialog, Esc or the scrim) and the Légendaire's sequence on a real phone.
  evidence: Story 8.12; `test/system/booster_test.rb` (`drag_top`, the tilt-hold test), `app/frontend/components/useCardSwipe.ts`.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-phone-plan.md`
  summary: The phone tray's thumbnails show the raw Steam cover scaled into 44 × 60 (`image-rendering: pixelated`), not the pixel filter's palette-reduced art that DESIGN.md (Avatars and thumbnails) asks for every thumbnail; a cover that fails to load leaves the slot's frame and rarity icon.
  evidence: Story 8.12 Code Map (the tray's "cover thumbnail from `card.coverUrl`"); `app/frontend/components/BoosterTray.tsx`. The filter worker (`packages/pixel-art-filter`) could draw them at 22 × 30 art pixels.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-phone-plan.md`
  summary: On the phone the stage leaves about 16px above the large card at 510px, so a Légendaire's jump is about 9px (60 % of that room) and every reveal's swell is damped to a quarter (`phoneSwell`) to stay clear of the caption plate 8px below; a taller stage on taller phones would give the jump its room.
  evidence: Story 8.12; `app/frontend/lib/booster.ts` (`phoneJump`, `phoneSwell`), `app/frontend/styles/booster.css` (the phone's `.booster__shake` rows).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-card-detail-plan.md`
  summary: The card detail has no rays behind an Épique or Légendaire card and no idle float with a breathing ground shadow (DESIGN.md Elevation & Depth, EXPERIENCE.md Motion "Idle float"); the hub showcase lacks them too, so they belong in one shared piece of work.
  evidence: Story 10.2 Never list; `app/frontend/styles/card-detail.css` draws a still ground shadow only.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-card-detail-plan.md`
  summary: Story 10.3: the card's faded back depends on a set in the query (a share link and the card's own page show the face to everyone, so a shared link still shows the card); once the public card page has its own layout or route, decide whether the in-app detail fades every card the viewer does not hold (AD-25) and drop the query rule.
  evidence: Story 10.2 Design Notes, "Set context and the faded back"; `CardsController#show` (`@faded`).
  resolved: Story 10.5 decided to keep the query rule. The card's own page is what a share link opens: a visitor gets the public card page (story 10.3), and a signed-in player who does not hold the card must still see it there (CAP-9), so fading every card not held would hide shared cards; the showcase and pack faces lead to owned cards anyway. Within a set (grids, ◀ ▶) a card not held stays faded.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-card-detail-plan.md`
  summary: The phone sub-view's swipe, step View Transition and "◀ Grille" history back were verified only in headless Chromium with synthetic pointer events; check them on an iOS Safari and an Android Chrome device (swipe beside the 150ms tilt hold, the card's turn, Back to the grid at its scroll).
  evidence: Story 10.2 review, follow-up recommended; `test/system/card_detail_test.rb`.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-card-detail-plan.md`
  summary: The phone system test's browser-Back leg (`test/system/card_detail_test.rb`, "on a phone, ◀ ▶ and a swipe step through the set…", the last `assert_scrolled_to grid_scroll` after `go_forward` then `go_back`) sometimes finds the grid at scroll 0 when the whole file runs in parallel; likely Turbo filing the forward-restored detail's scroll-to-top under the grid's restoration entry when Back follows quickly. Find the race (or wait on Turbo's restoration data in the test) and decide whether a quick real Back can hit it.
  evidence: Run on 2026-10-06 in the 10.2 follow-up: at commit b7776c2 alone it failed 6 of 8 file runs; after the follow-up's `contain-intrinsic-size` fix 1 of 6 and 2 of 11 file runs, always green alone (6×) and in the full suites (81 runs).
  resolved: Story 10.5 found the race in the test. Turbo files a page's scroll from `scroll` events (`ScrollObserver#onScroll` → `history.updateRestorationData`), which fire with the next frame; the test saw the restored detail at 0 and went back within that frame, so the pending event filed the detail's 0 under the grid's entry, which Turbo then restored. The test now waits two frames before going back (`wait_for_frames`); a person cannot press Back within one frame of the restore, so the app is unchanged.

- source_plan: none
  summary: A donation link somewhere in the app, since the author intends to fund gameble only through donations.
  evidence: Raised by the author on 2026-10-06 while planning story 10.3. Needs a decision on where it lives (hub, settings, public card page footer, legal page of epic 7), which platform, and a spec capability or constraint; not in the spec today.
- source_plan: none
  summary: A "back" button beside the "bridge" button in the top bar, to go back exactly one screen instead of always returning to the bridge.
  evidence: Raised by the author on 2026-10-06 while planning story 10.3. It touches the shell's top bar (`content_for :back_button`, epic 8's shell) and its navigation history behaviour, including the card detail sub-view's own Back; fits epic 10's refactor sweep or a new shell story.

- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-public-profile-and-shared-card-page-plan.md`
  summary: Rays (purple for Épique, gold for Légendaire) behind the card on the card detail, the hub showcase and the public card page, as DESIGN.md (Elevation & Depth, Rarity) requires.
  evidence: Quick review of story 10.3 (2026-10-06): the public card page has the ground shadow but no rays; the same rays are absent from the detail and the showcase, and exist only in `app/frontend/styles/booster.css` (`.booster-card__rays`), so a shared rays component is a cross-screen job, not this story's.

- source_plan: `_bmad-output/initiative-gameble/epic-brotherhood/story-feed-tracer-a-public-feed-of-notable-pulls-plan.md`
  summary: The feed reads a window of 90 rows per pass, so hidden players' entries can crowd out older public ones.
  evidence: Game::FeedEntries filters by Game::Visibility in Ruby after reading WINDOW rows; unverified at scale, would be medium.
  resolved: Story 6.2: the feed reads pages of 90 rows, up to ten, until its window of visible entries is full, so hidden players no longer crowd out older public entries; only more than 900 hidden entries in a row could still empty it.
- source_plan: `_bmad-output/initiative-gameble/epic-friends-and-trades/story-trade-board-island-the-draft-the-counter-and-the-swap-plan.md`
  summary: A trade board waiting for the player (`/trades` when that trade comes first, `/trades/:token`) and the counter page carry, in the TradeBoard island's props, a card-s face (about 1.5 KB of HTML) for every card both players hold, so a very large collection makes a heavy page.
  evidence: Deferred by stories 5.7 and 5.8 (medium, unverified) and kept by the epic 5 refactor sweep (story 5.12). `TradesHelper#trade_board_props` renders `CardComponent` for each `Game::HeldCopies` row of both players. What would settle it is the page weight of `/trades` for a player holding several hundred distinct cards; a fix would load the picker's faces when the edition opens (an endpoint per side) or page them.
- source_plan: `_bmad-output/initiative-gameble/epic-friends-and-trades/story-a-private-stream-and-live-updates-plan.md`
  summary: A ban set from the console reaches the banned player's friends and trade partners only at their next render, and their ties are dropped only when `bin/rails game:drop_friends_and_trades` runs.
  evidence: Deferred by story 5.9 (low) and kept by the epic 5 refactor sweep (story 5.12). `PlayerStream` and `Game::Handlers::PlayerBanned` listen to `Accounts::PlayerBanned`, which nothing publishes yet; the moderation ban action (epic 7) only has to publish it inside its transaction.
- source_plan: `_bmad-output/initiative-gameble/epic-friends-and-trades/story-trade-board-island-the-draft-the-counter-and-the-swap-plan.md`
  summary: The friend row on Amis has no "PROPOSER UN ÉCHANGE", which EXPERIENCE.md's Friend row gives it (the trade already in progress with that friend, or a new draft); only the friend profile carries the button.
  evidence: Story 5.8 left the row's layout to Amis ("The friend row on Amis gets no button here"); noted by the epic 5 refactor sweep (story 5.12) as a feature, not a cleanup. The link is `new_trade_path(friend: token)`, which already opens the open trade when there is one.

- source_plan: none
  summary: Replace the collection's tome (volume) system with another way to browse and organise the collection.
  evidence: Author, 2026-10-07: "il faut changer le système de collection en tome, c'est nul". The reasons and the replacement are not decided; start with a UX conversation (bmad-ux) before planning.

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-moderation-the-queue-bans-and-unbans-plan.md`
  summary: A moderator cannot read a reported profile that is private or friends only: the queue's link opens the unavailable page, since `Game::Visibility` shows a hidden profile to no one but its owner.
  evidence: Story 7.5 review (edge case; rejected low, the queue shows the name, which a name report concerns). Settling it means deciding whether staff see hidden profiles, a change to the one visibility question.
  resolved: Story 7.13: `Game::Visibility.visible?` shows staff in good standing every owner but a deleted one, private, friends-only and banned included; the public profile and the report endpoint use it, so the queue's link and the banned list's link open the profile. The feed and the friend profile opt out (`staff_sees_all: false`) and show staff what a player would see.
- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-moderation-the-queue-bans-and-unbans-plan.md`
  summary: Bans and dismissals leave no record a page reads: no ban reason, no "banned by", no history of classed reports; only the event store keeps `PlayerBanned`, `PlayerUnbanned` and `ReportsDismissed` with the staff member's id.
  evidence: Story 7.5 review (blind hunter; rejected low, not asked by the ticket). Would answer "why was I banned?" once strangers play.

- source_plan: `_bmad-output/initiative-gameble/epic-friends-and-trades/story-fixes-from-the-epic-retrospective-plan.md`
  summary: A counter-proposal carries no version of the terms seen, so a stale tab's counter replaces the friend's newer terms unseen.
  evidence: The counter form in `app/views/trades/_board.html.erb` and `Game::CounterTrade#call` take no `seen`; accept and decline now refuse `:trade_changed`, so counter is the one answer left unguarded.
- source_plan: `_bmad-output/initiative-gameble/epic-friends-and-trades/story-fixes-from-the-epic-retrospective-plan.md`
  summary: "One unanswered invitation per sender and recipient" is enforced only by app code under the pair lock; the unique index covers pending rows only.
  evidence: `index_game_invitations_one_pending_per_pair` is partial on `status = 'pending'`, while `SendInvitation` now refuses `:already_sent` for ignored rows too. An index on `status IN ('pending', 'ignored')` needs an expand/contract migration.
- source_plan: `_bmad-output/initiative-gameble/epic-friends-and-trades/story-fixes-from-the-epic-retrospective-plan.md`
  summary: About 800 planning ids remain in the repo outside the files epic 5 touched (routes, CSS, TS, other packs).
  evidence: AGENTS.md forbids them everywhere. The blind review of this story counted them; they belong to the epic 12 sweep.
- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-moderation-by-rank-a-hidden-back-office-and-staff-reading-ev-plan.md`
  summary: A member of staff reading a private, friends-only or banned profile sees it exactly as a public one: nothing says that players do not see it, so staff could share its link believing it public.
  evidence: Story 7.13 kept the profile page unchanged (no staff marker, by its plan). A line such as "Profil privé : visible des officiers seulement" needs copy in both locales and a place in the profile header.
