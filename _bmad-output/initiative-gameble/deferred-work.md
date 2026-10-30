- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-walking-skeleton-live-in-production-plan.md`
  summary: Deploy gameble to production with Kamal 2 — Dockerfile changes for the Vite build, `config/deploy.yml` and `.kamal/secrets`, the PostgreSQL 18 accessory with its four databases, HTTPS through the Kamal proxy with Let's Encrypt, and the first `bin/kamal setup`, run by the author.
  evidence: Split from story 1.1 on 2026-10-02 at the author's request. There is no production server, no domain and no Cloudflare setup yet; the author will deploy once a working version exists. Story 1.1's Verify and the epic's Done when checks 1, 4 and 6 name production and wait on this work. Author, 2026-10-12: production goes up once everything is built and validated on staging.
  resolved: production deploy is already done (author, 2026-10-28).
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: `config/initializers/omniauth.rb` prepends onto `OpenID::Consumer::AssociationManager`, an internal of ruby-openid 2.9.2, to keep the consumer stateless; a ruby-openid upgrade must re-check it, or the OpenID check can be written inside `Steam` as AD-20 allows.
  evidence: Story 1.6 Implementation Notes and residual risks.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: The OpenID nonce store relies on `Rails.cache` `unless_exist`, which is not strictly atomic under a race of milliseconds; a table with a unique index in `Steam` would close it.
  evidence: Story 1.6 residual risks; Steam's own check_authentication is a second guard.
- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-refactor-sweep-plan.md`
  summary: Links built by route helpers for routes outside the locale scope (`/up`, `/auth/*`, Mission Control) gain a `?locale=` query from `default_url_options`.
  evidence: Story 1.4 and 1.9 residual risks; harmless today, untidy in URLs.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: The seasons page's import check (`Steam::UnfinishedImportRun`) and the publish lock can race: a run started or resumed between the check and `Catalog::PublishSeason`'s lock could write cards after the publication.
  evidence: Story 2.6 review finding 2, rejected (low). It needs two administrator actions in the same instant; closing it needs a lock across `Steam` and `Catalog`, which AD-2 forbids.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-refactor-sweep-plan.md`
  summary: The rescore variant of the publish-lock race (epic 2 retrospective, F2): `Steam::RescoreCards.refusal` reads the draft and published seasons without the season lock, so a rescore committed between the seasons page's check and `Catalog::PublishSeason`'s lock lets the publication through; its later pages then find no draft, open draft N+1, and the run spans two seasons.
  evidence: Epic 2 retrospective F2, deferred; recorded by story 4.6. As with the 2.6 entry above, it needs two administrator actions in the same instant, and closing it needs a lock across `Steam` and `Catalog`, which AD-2 forbids.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-refactor-sweep-plan.md`
  summary: The AD-5 freeze (a published season's card-seasons, sets and memberships never change) is enforced only in models, by validations and `before_destroy` callbacks; a later bulk write (`update_all`, `insert_all`, raw SQL) could change rarities under owned cards without any error. A database trigger is the option; its frozen columns need design first.
  evidence: Epic 2 retrospective F5, deferred; recorded by story 4.6. `card_season.rb`, `set.rb` and `set_membership.rb` hold the freeze; no migration adds a trigger or check, and the only bulk writes in `Catalog` today, `PublishSeason`'s `update_all` (before the flip) and `PruneDraft`'s `delete_all` (which skips the `before_destroy` callbacks), run on the locked draft only.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: On a run's page, the "Rescore the cards" button reappears only after a full reload once the rescore completes: the polled frame does not hold it.
  evidence: Story 2.8 review finding 4, rejected (low, cosmetic). The run page is reloaded after a calibration anyway.
  issue: GitHub #33, opened 2026-10-12 to be built.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: `Catalog::UpsertDraftCard`'s slug-index race (two new cards taking the same slug at once) has no test of its own.
  evidence: Story 2.2 review finding 6, rejected (low). Handled by the shared `RecordNotUnique` retry loop; a concurrent slug collision is unlikely with one import writer, and the test needs plumbing only.
  issue: GitHub #39, opened 2026-10-12 to be built.
  resolved: PR #40 (2026-10-13) forces the slug collision beneath the real `create_card` in `Catalog::UpsertDraftCard`'s test; issue closed.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: `Catalog::UpsertDraftCard` given texts under both `"en"` and `:en` keeps one silently.
  evidence: Story 2.2 review finding 7, rejected (low). `Steam::CardMapping`, the only caller, builds string keys; a guard would add a branch for no current caller.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-refactor-sweep-plan.md`
  summary: No test makes the real `Catalog::UpsertDraftCard` fail inside its own transaction under `Steam::ImportCardsPage`'s per-card savepoint; the refused-card test uses a double that fails after a real upsert.
  evidence: Story 2.5 review note, rejected (low). The path is covered by the double's rollback and by the reading of dry-operation's ActiveRecord `transaction`.
- source_plan: `_bmad-output/initiative-gameble/epic-packs-and-reveal/story-replacement-packs-and-the-timer-plan.md`
  summary: The attic countdown shows mm:ss only; a pack scheduled more than an hour ahead (test-built or odd data) would read like "1440:00".
  evidence: `app/views/pages/home.html.erb` formats `"%02d:%02d", *@next_pack_in.divmod(60)`; packs made by the replacement rule are never more than ten minutes away (story 3.2 plan, Boundaries).
  issue: GitHub #35 (the packs chip's countdown, where the clock now lives), opened 2026-10-12 to be built.
  resolved: PR #45 (2026-10-13, `_bmad-output/backlog/bug-the-packs-chip-reads-the-countdown-in-total-minutes-1440-00-plan.md`) shows H:MM:SS from an hour on the server-rendered chip and the client tick, through the shared `formatClock`.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-import-hardening-before-season-1-plan.md`
  summary: Two malformed inputs still fail a page after story 2.11: a store title long enough to break the slug's unique index (about 2.7 kB) still fails the cards page that writes it, and a whole Steam answer that is not valid JSON still fails the page that asked for it (retried, then the run fails, as before).
  evidence: Story 2.11 hardens the values inside a well-formed answer (`Steam::RawValue`, `Steam::ReviewPolicy`, `Steam::DetailsPolicy`, `Steam::WebApi`, `Steam::ImportAppListPage`) and leaves the slug index and the JSON parse error out of its scope.
  issue: GitHub #37 (the long title only; the invalid JSON answer stays here), opened 2026-10-12 to be built.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-card-detail-plan.md`
  summary: Two low findings of story 4.3, kept for the record: `card_detail_store_url` puts Steam's `l=french` in the web layer (AD-4) and re-encodes an existing query; and a face's link name ("<title>, <rarity>, season n") leaves out the year the face carries as visually hidden text.
  evidence: Story 4.3 review finding 3, rejected (the intent asks for `l=french`, every store URL is a Steam URL, and moving it into `Steam` adds surface for a fork that does not exist), and the face-link half of finding 2, deferred; story 4.6 left both as they are, outside a cleanup.
  issue: GitHub #34 (the face's link name only; `l=french` stays here), opened 2026-10-12 to be built.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-public-profile-plan.md`
  summary: A banned player's sign-in still makes the persona lookup's Steam call (nothing is stored; the ban check refuses it after), and sign-in tests that do not stub the lookup report a harmless stub miss (`Faraday::Adapter::Test::Stubs::NotFound`) through `Rails.error.report`.
  evidence: Story 4.4 residual risks and Implementation Notes: `SessionsController#persona_name` runs before `Accounts::SignIn` for every verified Steam id.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: `Accounts::SignIn` writes the persona name (`update!`) inside the sign-in transaction, so a write that fails (a future validation on `Player`, a check constraint) would roll the whole sign-in back rather than keep the stored name.
  evidence: Epic 4 retrospective O2, deferred (latent: nothing validates `persona_name` today, and `Accounts::PersonaName.clean` leaves no NUL byte). Story 4.7 kept the write where it was.
- source_plan: `_bmad-output/initiative-gameble/epic-collection-and-sharing/story-fixes-from-the-epic-retrospective-plan.md`
  summary: Two small edge cases: `og_locale` reads `OG_LOCALES` with `fetch`, so a third locale added to the routes without its Open Graph name makes every card page a 500; and `SetLabel.for` gives a nil label for a publisher set whose `params` has no `publisher` name.
  evidence: Epic 4 retrospective O5, deferred (the import always sets the publisher name; adding a locale is a deliberate change). The third O5 point, a holder's own `/cards/…` address without preview tags, is resolved by story 4.7: the card's page is the share link and carries them.
  issue: GitHub #36, opened 2026-10-12 to be built.
  resolved: The fix (2026-10-13) makes `og_locale` fall back to the locale's own code and pins `OG_LOCALES` on `I18n.available_locales` with a test; `SetLabel.for` refuses a publisher set without its name and reads nil `params` as an empty hash; the collection's filter chips stop reaching `SetLabel` when the params are absent.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md`
  summary: Transitional: the packs chip's countdown stops at 00:00 and never refreshes the page (`countdown` controller with `refresh: false`); the new count appears on the next visit or when the hub's own countdown refreshes it.
  evidence: Story 8.1 Design Notes; `app/frontend/controllers/countdown_controller.ts`.
  issue: GitHub #32 (every page but the hub), opened 2026-10-12 to be built.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-architecture-conformance-plan.md`
  summary: Enqueuing from a GET under the read-only role is proven only with the test queue adapter: in development and production Solid Queue writes through `SolidQueue::Record`, its own connection class (`config.solid_queue.connects_to`), which the `reading` role switch on `ApplicationRecord` does not touch. No GET enqueues today; check it in development the first time one does.
  evidence: `test/controllers/read_only_requests_test.rb` ("a GET may enqueue a job") runs on the `:test` adapter; the test environment configures no Solid Queue database.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-architecture-conformance-plan.md`
  summary: No test builds the CSP `report-uri` (Sentry) or the development Vite policy; both are decided at boot. Before reading the report-only release's violations, check once that the deployed response's `Content-Security-Policy-Report-Only` header carries `report-uri https://…/api/<project>/security/?sentry_key=…`. Mission Control's inline scripts will report on every `/back-office/jobs` load meanwhile (administrators only).
  evidence: Story 8.4 review (verification gap); `test/initializers/sentry_test.rb` keeps `SENTRY_DSN` blank in the suite, so the branch never runs.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-tier-names-and-season-numbers-plan.md`
  summary: Contract step for card numbers (AD-28): once `catalog:number_seasons` has run on every database, add a migration making `catalog_card_seasons.number` required for published card-seasons (e.g. a check `rarity IS NULL OR number IS NOT NULL`, added `validate: false` then validated), and drop the nil case of `CardView#number`/`number_label` and the TypeScript `number: number | null`.
  evidence: Story 8.3 shipped the expand step only (nullable column); seasons published before it stay unnumbered until the backfill (pending-approvals.md, "Number the published seasons"). Author, 2026-10-12: no production yet; the contract step waits for it.
  resolved: moved to ticket 27.1 (author, 2026-10-28: do it now).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-single-card-face-plan.md`
  summary: A phone's long press on a card face inside a link (tome, pack result) may open the browser's link context menu or a text selection after about 500 ms, cancelling the pointer and ending the finger's tilt early; if so, suppress it while a finger tilts (`contextmenu` prevented, `-webkit-touch-callout: none`, `user-select: none` on `.card`).
  evidence: Story 8.6 review (unverified, medium if true): `attachTilt` (`app/frontend/lib/tilt.ts`) handles no `contextmenu` and `.card` sets no callout or selection rule; settle it with a long press on a tome face on an Android Chrome and an iOS Safari device. Author, 2026-10-12: confirmed, a long press selects text on an iPhone.
  issue: GitHub #31, opened 2026-10-12 to be built.
  resolved: `app/frontend/lib/tilt.ts` handles `contextmenu` and the card stylesheet sets `-webkit-touch-callout: none`, both asserted in `tilt.test.ts` (checked 2026-10-28).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-phone-plan.md`
  summary: The phone booster's gestures (the swipe that stores the top card, a tap after the 400 ms guard, the 150 ms tilt hold that is never a swipe, the pile's `touch-action: none` beside the page's panning on the plate, tray and actions) were verified only with synthetic pointer events in headless Chromium; check them on an iOS Safari and an Android Chrome device, with the card zoom (native dialog, Esc or the scrim) and the Légendaire's sequence on a real phone.
  evidence: Story 8.12; `test/system/booster_test.rb` (`drag_top`, the tilt-hold test), `app/frontend/components/useCardSwipe.ts`.
  resolved: The author checked the gestures on a real iPhone and Android (2026-10-12): ok.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-booster-island-phone-plan.md`
  summary: On the phone the stage leaves about 16px above the large card at 510px, so a Légendaire's jump is about 9px (60 % of that room) and every reveal's swell is damped to a quarter (`phoneSwell`) to stay clear of the caption plate 8px below; a taller stage on taller phones would give the jump its room.
  evidence: Story 8.12; `app/frontend/lib/booster.ts` (`phoneJump`, `phoneSwell`), `app/frontend/styles/booster.css` (the phone's `.booster__shake` rows).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/story-card-detail-plan.md`
  summary: The phone sub-view's swipe, step View Transition and "◀ Grille" history back were verified only in headless Chromium with synthetic pointer events; check them on an iOS Safari and an Android Chrome device (swipe beside the 150ms tilt hold, the card's turn, Back to the grid at its scroll).
  evidence: Story 10.2 review, follow-up recommended; `test/system/card_detail_test.rb`.
  resolved: The author checked the swipe, transition and Back on a real iPhone and Android (2026-10-12): ok.
- source_plan: `_bmad-output/initiative-gameble/epic-friends-and-trades/story-trade-board-island-the-draft-the-counter-and-the-swap-plan.md`
  summary: A trade board waiting for the player (`/trades` when that trade comes first, `/trades/:token`) and the counter page carry, in the TradeBoard island's props, a card-s face (about 1.5 KB of HTML) for every card both players hold, so a very large collection makes a heavy page.
  evidence: Deferred by stories 5.7 and 5.8 (medium, unverified) and kept by the epic 5 refactor sweep (story 5.12). `TradesHelper#trade_board_props` renders `CardComponent` for each `Game::HeldCopies` row of both players. What would settle it is the page weight of `/trades` for a player holding several hundred distinct cards; a fix would load the picker's faces when the edition opens (an endpoint per side) or page them.
  resolved: The island's props carry no per-card face, only the faces of the cards on the lines; the picker renders its matches a page at a time and fetches their faces from `GET /:locale/trades/faces` (2026-10-19). Seeded players holding 3,000 distinct cards each (4,000-card season): the counter page went from 21.0 MB (384.7 KB gzipped, 1.25 s server) to 1.5 MB (69.7 KB, 0.12 s), and at 390 px with a 4× CPU slowdown opening the friend's picker from 8.8 s to 0.05 s.
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-popularity-led-prestige-score-plan.md`
  summary: To verify (author, 2026-10-08) that a full import writes its draft cards with the current prestige formula (log10(review count) + 4 × Wilson), not the earlier Wilson + 0.01 × log10(count).
  evidence: On staging (v0.0.1-beta.1, which carries story 2.12), the season 2 draft after an import still showed scores from 0.113 to 1.039 (Stardew Valley 1.039, the old formula; the new one gives about 9.8); "Rescore the cards" on the latest run fixed them. Whether the import had not reached its cards step yet or ran on an image older than 2.12 was not established. Check: after the next full import completes, the draft preview's scores run from about 2.7 to 10 without a rescore; otherwise trace the import role's image and the cards step. Author, 2026-10-12: ok.
  resolved: the prestige formula has been verified since (author, 2026-10-28).
- source_plan: none
  summary: Make the special packs (daily bonus and community/reward packs) easier to tell apart from regular packs, above all while they are being opened.
  evidence: Author, 2026-10-08. Decide the look of the special pack and of its opening with a UX conversation (bmad-ux) before planning. Author, 2026-10-12: a bmad-ux workshop settles it before planning.

- source_plan: `_bmad-output/initiative-gameble/epic-friends-and-trades/story-fixes-from-the-epic-retrospective-plan.md`
  summary: "One unanswered invitation per sender and recipient" is enforced only by app code under the pair lock; the unique index covers pending rows only.
  evidence: `index_game_invitations_one_pending_per_pair` is partial on `status = 'pending'`, while `SendInvitation` now refuses `:already_sent` for ignored rows too. An index on `status IN ('pending', 'ignored')` needs an expand/contract migration.
- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-a-searchable-list-of-players-in-the-back-office-plan.md`
  summary: The back-office players search reads `persona_name ILIKE '%…%'` with no index, so each search scans `accounts_players`.
  evidence: Story 7.18 added no migration (its plan rules out a search index); a scan is instant at launch's player count. Once players number in the hundreds of thousands, a `pg_trgm` GIN index on `persona_name` (the extension in one migration, the index built concurrently in its own) keeps the search fast.

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-races-between-bank-operations-plan.md`
  summary: `Game::CreatePlayerState` and `Game::CreateFriendCode`, run by the backfill jobs, take no bank lock and do not re-check deletion, so an account deleted while a backfill runs can be left with a state row or a friend code.
  evidence: Both insert under `require_account` only, after `BackfillPlayerStatesJob` or `BackfillFriendCodesJob` read the players in batches. The backfills are one-off deploy tasks, so the window is one deploy run. The fix is `lock_bank` in both operations, as story 7.9 did for `Game::MarkCollectionSeen`.
  issue: GitHub #38, opened 2026-10-12 to be built.
- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/spike-sets-on-real-data-plan.md`
  summary: Percentage tiers make a player cross bronze, then silver, on most themes in the same few days, and "EN COURS" sorted by closeness shows near-equal bars.
  evidence: The spike's pack simulation (report section 6) puts 25 % of any theme, 48 or 2,084 cards, at 610 to 850 packs, because the share of a theme held follows the share of the catalog drawn. The agreed 10 / 25 / 50 % keeps this. Stories 5 and 6 (celebration, "EN COURS") should decide how to spread or group these crossings.
  resolved: percentage tiers are no longer current (author, 2026-10-28).

## Deferred from: code review of story-themes-franchises-studios-hall-of-fame-and-the-ufos-replace-plan (2026-10-12)

- Planning ids (AD-n, CAP-n, story n.n) remain in comments of `config/routes.rb`, `packs/catalog/app/queries/catalog/set_neighbours.rb`, `packs/game/app/queries/game/hub_sets.rb`, `packs/steam/app/operations/steam/rescore_cards.rb` and `packs/catalog/app/queries/catalog/season_summaries.rb`, against the AGENTS.md policy; pre-existing, the themes change added none. A sweep across the repo would settle it.
- No test renders the French back-office season preview with zero UFOs, which relies on the plural `zero` form of `back_office.seasons.preview.ufos`; add it to the French verdict test of `test/controllers/back_office/seasons_controller_test.rb` with a draft whose every card has a theme.
- Planning ids also remain in comments of `app/helpers/collection_helper.rb`, `app/views/library/_set_list.html.erb`, `app/views/public_profiles/_set_list.html.erb`, `app/views/library/_collection.html.erb` and `app/views/public_profiles/show.html.erb`; pre-existing, to fold into the same sweep.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/bug-the-collection-grid-hides-the-missing-cards-by-default-where-plan.md`
  summary: `Game::TradesOfTest` "finished trades are recent … for 14 days" and `SessionsControllerTest` "signing in keeps the player signed in for 30 days" fail when the 14 or 30 days cross a daylight saving change, as from 2026-10-11 to 2026-10-25.
  evidence: Both fail on the baseline of this bug, untouched by it: the session expiry is one hour off `30.days.from_now` (3600 s against a 1 s delta) and the 14-day window drops the accepted trade, so a calendar-day duration meets a fixed-seconds one across the change of hour. Run on 2026-10-13.
  resolved: `test/test_helper.rb` sets `TZ=UTC` (2026-10-13, 0b489fa); both tests pass with TZ=Europe/Paris and TZ=UTC on 2026-10-13, whose windows cross 2026-10-25.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/bug-the-collection-grid-hides-the-missing-cards-by-default-where-plan.md`
  summary: The disabled system test "the FILTRES zone: chips narrow the grid…" in `test/system/library_test.rb` still pins the old owned default (3 slots on opening, a count of 2 after MISSING, "Back to the owned cards"); rewrite it for the every-slot default when system tests are rebuilt.
  evidence: The collection now opens on every slot, and a state chip switched on from TOUT replaces it; the test was left as it is because system tests are disabled and cannot be run to verify an edit.
  resolved: the test was rewritten and passes (checked 2026-10-29).
- source_plan: `_bmad-output/backlog/bug-the-packs-chip-reads-the-countdown-in-total-minutes-1440-00-plan.md`
  summary: No vitest covers a Stimulus controller, so `countdown_controller.ts`'s tick and refresh logic has no unit test of its own; its clock formats are the tested `formatClock` and `formatDailyClock`.
  evidence: This plan's quick review finding 2, patched by reusing `formatClock`; the repo still has only `app/frontend/lib/*.test.ts` in a node environment, with no Stimulus-controller test harness.
- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-db-schema-rb-round-trips-the-steam-checks-plan.md`
  summary: Nothing stops a new migration from writing a check as `col IN (...)` on a varchar column, whose dumped form CI's load-and-dump drift step rewrites; a line under "Known pitfalls" in AGENTS.md (write list checks as `col = 'a' OR col = 'b'`) or a lint rule would close it.
  evidence: This plan's quick review; the only guard is the comment in `db/migrate/20261002210000_create_catalog.rb`, which twelve later migrations missed. The fix edits agent-context files, which the build defers to the author.
  decision: Author, 2026-10-13: no AGENTS.md rule; the CI step of ticket 43 catches such a check.
  resolved: Ticket 43 (2026-10-13, `story-ci-s-drift-step-replays-the-migrations-plan.md`): CI's "Check the migrations build db/schema.rb" step fails on a new `IN` check when db/schema.rb holds the load-stable form, and the round-trip step fails when it holds the migrated form.
- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-db-schema-rb-round-trips-the-steam-checks-plan.md`
  summary: CI's drift step (`bin/rails db:create db:migrate && git diff --exit-code -- db/schema.rb`) never runs the existing migrations: on an empty database Rails 8.1's `db:migrate` loads db/schema.rb first, so the step checks only that a load dumps the same file; pointing `SCHEMA` at a missing file for the migrate and diffing that dump would test the migrations themselves.
  evidence: `ActiveRecord::Tasks::DatabaseTasks#initialize_database` (activerecord 8.1.4) loads the schema file when `schema_migrations` does not exist; the same applies to AGENTS.md's regeneration command. Found while building this ticket, 2026-10-13.
  decision: Author, 2026-10-13: fix the CI step, ticket 43 of epic-public-launch-readiness.
  resolved: Ticket 43 (2026-10-13, `story-ci-s-drift-step-replays-the-migrations-plan.md`): CI runs every migration with `SCHEMA` at a missing file and diffs that dump against db/schema.rb, then checks the load round trip on an empty database; `bin/ci` runs the same two checks. AGENTS.md's regeneration command still loads the schema first, unchanged by decision.

## Deferred from: code review of story-persona-names-are-cut-on-whole-characters-plan (2026-10-13)

- Planning ids also remain in the comments of `packs/accounts/app/models/accounts/persona_name.rb`, `packs/accounts/app/operations/accounts/sign_in.rb` and `test/packs/accounts/persona_name_test.rb` (CAP-8, epic 4 retrospective B4); pre-existing, to fold into the same repo-wide sweep.

## Deferred from: code review of story-opening-an-invite-link-sends-the-invitation-plan (2026-10-13)

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-opening-an-invite-link-sends-the-invitation-plan.md`
  summary: A page on another site can send a signed-in player to an invite link, which now sends the invitation, or accepts the owner's pending one, without a click; once accepted, no path removes the friendship.
  evidence: The session cookie is SameSite=Lax, so a top-level cross-site GET arrives signed in and the page's own POST carries a valid CSRF token. The auto-send is what the ticket asks for, and invite links are opened from chat apps on other sites, so the page cannot tell them from a hostile redirect. Author to decide: keep it, never auto-accept the owner's pending invitation (show the button instead), or add removing a friend.
  decision: Author, 2026-10-13: add removing a friend, ticket 42 of epic-public-launch-readiness; the automatic send stays.
  resolved: Ticket 42 (2026-10-13, `story-a-player-removes-a-friend-plan.md`): each friend row has "RETIRER" behind a confirmation dialog; it ends the friendship for both, cancels the open trade between them and releases its copies, silently for the former friend.

## Deferred from: build of story-request-test-helpers-shared-plan (2026-10-13)

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-request-test-helpers-shared-plan.md`
  summary: The `hold` test helper is still copied in about 20 test files (the game pack unit tests, the trades and reposts controller tests, the integration shell test, the trades system test) beside `LibraryRequests#hold`, with differing signatures (`reserved:`, `gained_at:`, a `player:` default).
  evidence: `grep -rn "def hold" test`; named with the sign-in copies in the collection-and-sharing retrospective (D2); the request-test helpers ticket shared the sign-in helpers only.
- The `hold` comment in `test/support/library_requests.rb` still names AD-26; pre-existing, to fold into the repo-wide planning-id sweep.
  resolved: `def hold` now lives only in `test/support/holdings.rb` (checked 2026-10-28).

## Deferred from: closure of epic-space-terminal-redesign and epic-space-terminal-screens (2026-10-13)

- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens-retrospective.md`
  summary: From a card opened on another player's profile set, the contextual back ("◀ Grille") leads to the viewer's own set of that name, since the profile's set links carry no context and the fallback back is `library_set_path`.
  evidence: Retrospective B3; `app/controllers/cards_controller.rb` (fallback back). Found open by the epic's closure check.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens-retrospective.md`
  summary: A public profile's set page loads every slot of the set at once, with no paging, where the player's own collection pages.
  evidence: Retrospective B4; `shelf_loading.rb` loads every slot. Found open by the epic's closure check.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens-retrospective.md`
  summary: A visitor's collection filter zone offers the OWNED, NEW and DUPLICATES state chips, which can never match for someone who owns nothing.
  evidence: Retrospective B5; `app/views/library/_filters.html.erb` renders every `STATES` value. Found open by the epic's closure check.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens-retrospective.md`
  summary: `fr.public_profiles.set.copies` has no `zero` form, against the French plural rule; it is only called with a positive count today.
  evidence: Retrospective B6; `config/locales/fr.yml` (public_profiles.set.copies, one and other only). A one-line `zero:` addition.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-screens/epic-space-terminal-screens-retrospective.md`
  summary: The comment in `packs/game/app/models/game/holding.rb` says only `Game::OpenPack` sets `last_gained_at`, but `Game::AcceptTrade` sets it too.
  evidence: Retrospective item 6b; `accept_trade.rb` writes `last_gained_at` for the cards a trade brings.
  resolved: the comment is gone: `app/domains/game/app/models/game/holding.rb` no longer mentions `last_gained_at` (checked 2026-10-28).
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/epic-space-terminal-redesign-retrospective.md`
  summary: Entry 5 of epic-space-terminal-redesign and its plan still name `packages/pixel-art-filter`, which the `pixelcrush` npm package replaced; the architecture and the epic's closure note record the substitution.
  evidence: Retrospective item 2; commit 6c6ee61; architecture-gameble.md amended. Found open by the epic's closure check.
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/epic-space-terminal-redesign-retrospective.md`
  summary: The card tilt still registers a non-passive `touchmove` listener, which can delay scrolling on a phone.
  evidence: `app/frontend/` tilt.ts registers it; its earlier deferred entry was removed in the 2026-10-12 triage (7285ddc) with no other home. Found by the epic's closure check.

## Deferred from: build of plan-previous-screen-skips-same-screen (2026-10-13)

- source_plan: `_bmad-output/backlog/bug-the-desktop-back-button-names-the-previous-different-screen-plan.md`
  summary: Switching language on the settings screen still shows the desktop back button ("◀ PROFILE") leading back to the same settings screen in the other language, since same-screen is judged by the translated label ("Profile" vs "Profil").
  evidence: `shell_screen_label` returns `t("shell.screens.…")`; the LANGUE links in `app/views/settings/show.html.erb` are Turbo visits, so the trail is not reset. Pre-existing (the old button showed it too). A fix records a language-independent screen key on the top bar and in each trail entry and compares that key.

## Deferred from: build of story-rarity-follows-popularity-the-rating-only-orders-games-of-eq (2026-10-13)

- source_plan: `_bmad-output/initiative-gameble/epic-season-preparation/story-rarity-follows-popularity-the-rating-only-orders-games-of-eq-plan.md`
  summary: The development seeds stamp the current prestige VERSION on scores the formula never computed (`prestige_score: number.to_f`, review counts set apart), so local rarities contradict the rule the how-it-works screen states.
  evidence: `db/seeds.rb:31-34`. Pre-existing; more visible now that the score is the review count. A fix computes the score with `Steam::PrestigeScore.call(percent_positive:, review_count:)`.

## Deferred from: build of story-the-hover-light-becomes-a-studio-reflection-on-the-card-s-va-plan (2026-10-13)

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-the-hover-light-becomes-a-studio-reflection-on-the-card-s-va-plan.md`
  summary: The card face baselines (`test/fixtures/files/card_faces/*.png`) predate the studio reflection and the Légendaire's glitter, which now show on every face at rest; regenerate them with `UPDATE_CARD_BASELINES=1` when the system tests are rebuilt.
  evidence: System tests are disabled until they are rebuilt (AGENTS.md); the build could not run them to refresh the baselines.
- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-the-hover-light-becomes-a-studio-reflection-on-the-card-s-va-plan.md`
  summary: The Légendaire's glitter twinkle runs one infinite animation per flake (9 on a card-s, 18 on a card-m, 40 on a card-xl), which breaks the architecture's budget of at most six infinite animations visible at once on a phone view; that line also still names holo and foil. The author needs to decide: amend the budget for this cheap stepped opacity, or twinkle fewer flakes (only the top card, a cap per view, or one animation per card).
  evidence: `architecture-gameble.md` line 308; the author's glitter spec gives each flake its own period (2.4 to 6 s) and a negative delay, so each needs its own animation; `card.css` twinkle rule, `glitter.ts` FLAKES_PER_CARD. The booster's lower phone cards and face-down cards are kept still.
  resolved: The author chose one animation per group (2026-10-13, `_bmad-output/backlog/story-the-legendaire-glitter-twinkles-in-three-groups-plan.md`): a face's flakes twinkle in three seeded groups, each a single stepped opacity animation with its own rhythm, so a Légendaire face runs at most three; AD-27 counts the glitter apart from the six-animation phone budget and no longer names holo and foil.

## Deferred from: split of story 7.10 at the start of its build (2026-10-14)

- source_plan: none
  summary: Throttle or cache the public profile, card page and library reads without ever caching a private or hidden page (the throttling half of "Public pages throttled or cached, CSP enforced").
  evidence: The author split the ticket; this half shares no file with the CSP switch, and a per-IP throttle on page reads waits for "Real client addresses behind Cloudflare", or every visitor behind Cloudflare would share one limit.
  resolved: Became entry 55 of epic-public-launch-readiness, after real client addresses behind Cloudflare (author, 2026-10-14).

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-the-phone-tray-s-thumbnails-in-pixel-art-plan.md`
  summary: Cover the phone tray's filtered thumbnails with a test (a filled slot marked `data-art="drawn"` or `"plain"`, a failed cover leaving the canvas hidden and the frame and rarity icon).
  evidence: Vitest runs in a node environment with no DOM, so no component test can render the tray, and the system tests that would assert it are disabled until they are rebuilt; the quick review found no test of the thumbnail beyond the palette prop.

## Deferred from: slicing of epic-easier-trades (2026-10-15)

- source_plan: none
  summary: The trade list row sums each side up as "first game +n" in EXPERIENCE.md (Copy deck, Trade list summary), but `TradesHelper#trade_side_title` joins every title.
  evidence: Found while slicing the open trade request; entry 18.6 adds only "À choisir" for an empty side (author, 2026-10-15).
  resolved: the author keeps the code, all titles joined by `TradesHelper#trade_side_title`; EXPERIENCE.md now says so (2026-10-28).
- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-published-season-gets-its-new-sets-once-plan.md`
  summary: `bundle exec i18n-tasks unused` reports `rate_limit.reading_throttled` and `rate_limit.throttled` in en and fr, which `config/initializers/rack_attack.rb` reads dynamically; add them to `ignore_unused` in `config/i18n-tasks.yml`.
  evidence: The quick review of the retired set kinds removal ran the command; a clean worktree at the baseline gives the same four keys, so the check fails independently of that change.
  resolved: `config/i18n-tasks.yml` lists `rate_limit.*` under `ignore_unused` (checked 2026-10-28).
- source_plan: none
  summary: Staging moves behind its own Cloudflare Tunnel at staging.gameble.net, web and SSH (Access service token for the staging workflow), as production did, so the home lab's ports 80, 443 and 2224 can close and its address stops being published by gameble.dotsncircles.com.
  evidence: The author decided on 2026-10-16, while moving production's SSH into its tunnel, to do the same for staging later under staging.gameble.net; PUBLIC_URL, deploy.staging.yml, the staging workflow, CONTRIBUTING.md's test-version link and Steam's return URL follow the new name.

## Deferred from: refactor sweep of epic-easier-trades (2026-10-19)

- source_plan: `_bmad-output/initiative-gameble/epic-easier-trades/story-refactor-sweep-plan.md`
  summary: The trade picker's worst scroll frame stays close to the 100 ms bound 18.4 set: 78 to 94 ms at 390 px with a 4× CPU slowdown and 3,000 cards a side, the cost being a page of 36 picker cards and then their 36 faces, each with its `card-art` and `tilt` controllers, inserted at once.
  evidence: 18.4 measured 83 to 107 ms in single runs; the sweep re-measured a median of 89 ms on a re-seeded database. Levers left: smaller pages or face batches, or fewer controllers per picker face; `content-visibility` on the picker cards would clip the picked ring and the focus outline. Worth settling on a real phone on staging before acting.

## Deferred from: the collection opens on sets in progress (2026-10-17)

- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-collection-opens-on-sets-in-progress-plan.md`
  summary: The public profile's "complete sets" figure (`Game::CollectionSummary`) counts only the published season's exact editions, while the set rows beside it count a game held in any edition; entry 15 of epic-recognizable-sets should move it to `Game::HeldGames` with the other collection reads.
  evidence: The quick review found a set completed partly with earlier-edition copies marked COMPLET in the profile's rows but left out of the header's count.
  resolved: moved to ticket 27.2 (author, 2026-10-28: count any edition).
- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-collection-opens-on-sets-in-progress-plan.md`
  summary: The set progress row of the album last opened should carry the 5px accent bar and `aria-current="true"` on the collection entry; left to the set album (entry 8 of epic-recognizable-sets), which decides how the entry knows it.
  resolved: The set album (2026-10-17) records the album last opened in the tab's session storage; the collection entry, a profile and the hub mark its row.
  evidence: The design asks for it (Collection, Set progress row); this build had no album to return from, so no row is marked.
- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-collection-opens-on-sets-in-progress-plan.md`
  summary: System tests that reach the collection through the hub's menu, the tab bar or a profile and then expect the card grid now land on the collection entry (`test/system/library_test.rb`, `shell_test.rb`, `public_profile_test.rb`); update them when the system tests are rebuilt.
  evidence: The collection's entry took `/library` and the grid moved to `/library/cards`; only direct grid visits were renamed, and system tests are disabled (AGENTS.md).
  resolved: the system tests were rewritten and `library_test`, `shell_test`, `public_profile_test` and `card_detail_test` pass (checked 2026-10-29).

## Deferred from: the set album (2026-10-17)

- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-set-album-plan.md`
  summary: The set-scoped grid is gone from the screens but its support stays: `Catalog::CollectionGrid`'s `kind:`/`key:`, `CollectionGridLoading#grid_context`'s set, `CardsController#named_grid` and `grid_page_path`'s set branch, the `set:` locals of `library/_collection`, `_set_list` and `_filters`, and `CollectionHelper#collection_set_path`; entry 9 of epic-recognizable-sets, which reworks the grid and its set filter, should remove them.
  evidence: Every link to `/library/:kind/:key` now opens the album; only detail links carrying an old `grid[kind]`/`grid[key]` still walk a set's grid, and their back leads to the album.
- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-set-album-plan.md`
  summary: The album's back reads "◀ CAPSULE" through the history trail once the set celebration links its results to the album; the link itself and the capsule shown again with its results on coming back belong to ticket 13.17.
  evidence: The celebration as built links nowhere; the capsule's screen label is already "Capsule", so no album change is needed for 13.17.
- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-set-album-plan.md`
  summary: The collection grid at `/library/cards` has no arrow keys; EXPERIENCE asks it to be one tab stop with arrow keys inside, as the album's grid now is (`grid_keys_controller.ts`, `data-controller="grid-keys"` on the `<ol>`).
  evidence: The album's grid got the behaviour; the collection grid was out of this build's scope.
- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-set-album-plan.md`
  summary: System tests written for the set grid with filters (`test/system/library_test.rb` around lines 58–71 and 187–203, expecting filters and a watermark post on a set page; possibly `card_detail_test.rb`) are stale; update them when the system tests are rebuilt.
  evidence: The set page became the album, which has no filters and posts no watermark; system tests are disabled (AGENTS.md) and were not run.
  resolved: the system tests were rewritten and `library_test` and `card_detail_test` pass (checked 2026-10-29).
- source_plan: `_bmad-output/initiative-gameble/epic-visitor-landing/story-the-app-speaks-jetbrains-mono-plan.md`
  summary: Figures set in a running-text style rather than a figure token are not bold, for example the community goal's `.hub-goal__figures` ("31 420 / 50 000") on `--font-body`; audit the app's counts, odds and quantities and put them on JetBrains Mono bold as the typography rules ask.
  evidence: The JetBrains Mono build moved only the figures that were set in VT323 onto the bold figure tokens; `.hub-goal__figures` was regular Space Mono before and is regular JetBrains Mono now.
  resolved: already fine (author, 2026-10-28).

## Deferred from: the refactor sweep of epic-recognizable-sets (2026-10-19)

- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-refactor-sweep-plan.md`
  summary: `Game::SetCompletion` and its table `game_set_completions` are no longer written since tiers replaced completions; only `Game::ReleasePlayer` still deletes a player's rows, and the account deletion copy still names completed sets. Dropping them needs a migration and changes that copy and one delete query.
  evidence: `packs/game/app/models/game/set_completion.rb`, `packs/game/app/operations/game/release_player.rb:16`, `test/controllers/accounts_controller_test.rb:42`. The author decides whether the table goes before the public launch.
  resolved: Entry 13.26 (2026-10-19, `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-dead-set-completions-table-dropped-and-the-feed-s-share-plan.md`) removes `Game::SetCompletion`, drops `game_set_completions` in its own migration and stops the account deletion copy naming completed sets.
- source_plan: `_bmad-output/initiative-gameble/epic-recognizable-sets/story-refactor-sweep-plan.md`
  summary: The feed's tier share falls back to counting a set's members when the set has no complete tier row, a case only test fixtures create (`COALESCE(complete.required, (SELECT COUNT(*) …))`); giving those fixtures their complete rows would let the fallback go.
  evidence: `packs/game/app/models/game/feed_entry.rb:42-43`; every set published by `Catalog::SetBuilder` has a complete row (entry 22's Implementation Notes).
  resolved: Entry 13.26 (2026-10-19, `_bmad-output/initiative-gameble/epic-recognizable-sets/story-the-dead-set-completions-table-dropped-and-the-feed-s-share-plan.md`) divides by the complete tier row only and gives the test sets their complete rows.

- source_plan: `_bmad-output/initiative-gameble/epic-season-preparation/story-an-import-builds-beside-the-draft-and-replaces-it-only-once-plan.md`
  summary: Drop the unused steam_apps.carded_run_id column with its foreign key and index in a contract migration.
  evidence: The staged import stopped writing the card marks (11.1); nothing reads the column any more, and expand/contract leaves its removal to a later migration.
  resolved: `steam_apps.carded_run_id` is absent from `db/schema.rb` (checked 2026-10-28).

- source_plan: `_bmad-output/initiative-gameble/epic-season-preparation/story-an-import-builds-beside-the-draft-and-replaces-it-only-once-plan.md`
  summary: Remove Catalog::UpsertDraftCard, or move db/seeds.rb and the tests to the staged operations.
  evidence: The import no longer calls it (11.1); only the seeds and tests do, and it still writes card-seasons straight into the draft.
  resolved: `Catalog::UpsertDraftCard` no longer exists in `app`, `test` or `db` (checked 2026-10-28).

- source_plan: `_bmad-output/initiative-gameble/epic-season-preparation/story-an-import-builds-beside-the-draft-and-replaces-it-only-once-plan.md`
  summary: Deploy the staged import only when no import run is active.
  evidence: A run in flight at deploy has no season_number and ends ready with 0, so promoting it is refused as stale and the run is abandoned; its earlier pages also wrote straight to the draft. Unverified in production, harmful only at deploy time.

## Deferred from: the retrospective of epic-brotherhood (2026-10-21)

- source_plan: `_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood-retrospective.md`
  summary: Reconcile the epic file's R2, R3 and Done when 1 with the claim model of ticket 6.17: the reward is earned as a waiting reward, claimed by a button and refused while the reserve holds ten packs; tell `epic-card-backs.md` that the pack-bearing event is `Game::GoalRewardClaimed`.
  evidence: Action item 1 (finding F4): the epic still says the reward pack lives outside the cap of ten and that every contributor receives it; the author decided otherwise in 6.17 (`claim_goal_reward.rb:39,65`, `reserve.rb:17`).

- source_plan: `_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood-retrospective.md`
  summary: Settle the product calls the epic 6 sweep left open: the public feed window's 900-row bound; the goal's 10 s broadcast without change detection; the goal's figures on a bold figure token (resizes them; the typography audit entry covers it); friends-only entries not broadcast live; the ticker's placement wording in the design document; a held achievement toast lost when leaving the booster mid-reveal; achievements granted live after an unban; one grant job per opening, trade, repost and set completion; the toast region under a modal; `game:benchmark_open_pack` still to run; a trade credited to its recipient's row; the friends tab's empty line with friends but no entries; the filter chips' `aria-current` against the design document's `aria-pressed`.
  evidence: Action item 2 (finding F19): these lived only in the Implementation Notes of `epic-brotherhood/story-refactor-sweep-plan.md`; each is a product or design call for the author.
  resolved: kept as they are (author, 2026-10-28).

- source_plan: `_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood-retrospective.md`
  summary: Fold the epic 6 leftovers into `epic-human-readable-codebase`: the planning ids still in `weekly_goal.rb`, `sum_weekly_goal_job.rb`, `grant_goal_rewards_job.rb`, `pack_opened_feed.rb`, `event_store.rb`, and the five friends-and-trades migrations; optionally read the rarity tier through `Catalog::CardSeasonTiers` in `pack_opened_feed.rb` and `trade_accepted.rb`, and share the feed visibility rule between `FeedEntries` and `NewFeedEntries`.
  evidence: Action item 3 (findings F1, F2, F3; previous-retro item 9): `pack_opened_feed.rb:15-16`, `trade_accepted.rb:15-16`, `feed_entry.rb:93` against `card_season_tiers.rb:10-13`; `feed_entries.rb:55-60` against `new_feed_entries.rb:22-23`.

- source_plan: `_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood-retrospective.md`
  summary: Process rules for the next epics: a plan's Verification records the results of the commands it lists; a plan's `baseline_revision` is a full hash of a commit that stays reachable and a ticket's commits name its ref; planning ids and new comments are checked mechanically before review.
  evidence: Action item 4 (findings F20, F21, F22): the baseline of 6.19 does not exist in the repository, and commit subjects after 6.10 stop naming the ticket, so the retrospective pre-pass cannot attribute them.
  resolved: dropped: the plans are local (author, 2026-10-28).

- source_plan: `_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood-retrospective.md`
  summary: Cover the live paths in the rebuilt system tests: the hub gauge refresh, the ticker (placement, window width, red square, loop join), the achievement toast during a reveal, the repost toast in the phone zoom; and check the three layout items the sweep did not verify.
  evidence: Action item 5 (finding F14): the live paths rest on model and vitest tests and on the author's staging walk; the system tests run only before a production release now.

## Deferred from: the retrospective of epic-public-launch-readiness (2026-10-21)

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness-retrospective.md`
  summary: Reconcile ticket 7.39 with what was built: amend its Verify and description (the suite runs once before a production release, agents run targeted tests), record the deviation in the epic notes, record the first real run of the gate after the first production release past e1cf6b75, and decide whether the release checks in `deploy-production.yml` run before the suite.
  evidence: Action item AI-2: the closed Verify asked for ten local and five CI runs; only one manual run of `system-tests.yml` exists and the path called by the production deploy has never run on a real release.

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness-retrospective.md`
  summary: Finish the record of the epic 7 sweep: put the results of the full suite, lint, packwerk and typecheck in its plan so it can leave `built`, and add `resolved:` lines to the two entries above that are already fixed (the backfills' bank lock, d7341c3e and 15fda010; the stale card-face baselines, ad0c5f89).
  evidence: Action item AI-3: the plan's three stale open items are already corrected; its verification results and the two entries' state are not.

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness-retrospective.md`
  summary: Give a banned account an erasure path: document the console steps in the README (unban, then `Accounts::DeletePlayer`, noting the history row) or allow the operation for a banned player when staff run it.
  evidence: Action item AI-4 (legal and product call): the legal page promises erasure on request (`config/locales/en.yml:243`) while `DeletePlayer` refuses a banned player (`delete_player.rb:43`).
  resolved: moved to ticket 27.3 (author, 2026-10-28: allow it when staff run it).

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness-retrospective.md`
  summary: Review the three pieces no lens saw twice: the self-dismiss refusal and the `ReportQueue.rows` skip (7.5), the idleness rule `GREATEST(last_seen_at, updated_at)` and the synchronous `last_seen_at` write in `SignIn` (7.14), and the legal page copy (7.3).
  evidence: Action item AI-5: tickets 7.3, 7.5 and 7.14 closed with `followup_review_recommended: true` and no second pass.

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness-retrospective.md`
  summary: Make builds traceable: the plan template records `built_revision`, a closing step refuses `done` when the baseline is not an ancestor of HEAD, and a `done` plan carries a review block or an explicit `review: none` reason.
  evidence: Action item AI-6: carried a fifth time; no plan of 52 has `built_revision`, four baselines are absent from the repository and four are not ancestors.
  resolved: dropped: the plans are local (author, 2026-10-28).

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness-retrospective.md`
  summary: A `hitl` sign-off records what was seen, where and when (drill output, CSP report count on staging, release run id).
  evidence: Action item AI-7: Done-when criteria 4 and 8 rest on the author's declaration for lack of it.
  resolved: dropped: the plans are local (author, 2026-10-28).

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness-retrospective.md`
  summary: Give the copy-pasted `hold` test helper an owner or a guard: a ticket that shares it, or a check that fails on a new `def hold` in a test file.
  evidence: Action item AI-8: the helper grew from about 20 to 34 test files while it was registered as deferred.
  resolved: `def hold` now lives only in `test/support/holdings.rb`, shared by every test (checked 2026-10-28).

- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness-retrospective.md`
  summary: Optional: give the Rack::Attack 429 response a themed body (`rack_attack.rb:61`) and decide whether `legal`, `credits` and `how-it-works` join `PublicReadThrottle::PAGES`.
  evidence: Action item AI-10 (low): the 429 answers in plain text and the three public pages are neither throttled nor cached.
  resolved: left as it is (author, 2026-10-28).
- source_plan: `_bmad-output/initiative-gameble/epic-season-preparation/story-an-administrator-curates-the-theme-list-in-the-back-office-b-plan.md`
  summary: French theme names live in db/default_themes.yml, the seed migration and the theme fixtures, outside config/locales/fr.yml.
  evidence: AGENTS.md keeps French in fr.yml, but the stored names of the 43 seeded themes are data and the locale lookup they came from was removed; the author should confirm the exception or choose another home.
  resolved: exception confirmed: the theme names are data (author, 2026-10-28).
- source_plan: `_bmad-output/initiative-gameble/epic-visitor-landing/epic-visitor-landing-retrospective.md`
  summary: The `deferred` entries of the epic's fourteen plans that stay at `built` never reached this file.
  evidence: Retrospective F17: only one entry for the epic is recorded here; the plans' `deferred` frontmatter (the motion switch's pixel icon, the roadmap page's date and sentence, the reveal demo's DOM test, the typography figures of the hub goal) is the rest.
- source_plan: `_bmad-output/initiative-gameble/epic-visitor-landing/epic-visitor-landing-retrospective.md`
  summary: Process rules for the next epics: a full plan baseline, the ticket named in each feature commit, the verification results recorded in the plan, a comment check before the review.
  evidence: Retrospective F18: the 20.2 baseline is not found, 20.9 has none, 20.18's has 8 characters, no feature commit names its ticket, 20.11 has no review or results recorded.
  resolved: dropped: the plans are local (author, 2026-10-28).
- source_plan: `_bmad-output/initiative-gameble/epic-visitor-landing/epic-visitor-landing-retrospective.md`
  summary: Verification gaps left open: the reveal demo has no DOM test, the caches are not seen at the request level (the cache is null in tests), and `readable` swallows `ReadOnlyError`.
  evidence: Retrospective F8, F14, F15 and F9.
- source_plan: `_bmad-output/initiative-gameble/epic-visitor-landing/epic-visitor-landing-retrospective.md`
  summary: The privacy text does not say that the public card page, indexable by search engines, names a pioneer whose profile is visible; the architecture file still cites the pioneer's old home (line 534).
  evidence: Retrospective F4 and F13: `config/locales/en.yml:216` and `architecture-gameble.md:534`.
  resolved: nothing added (author, 2026-10-28).

- source_plan: `_bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough-retrospective.md`
  summary: Epic 16 is accepted by the author on 2026-10-27 with the walkthrough's coverage left partial: seven screens were never marked (seasonal allocation, card picker, public card page, public profile, full collection, Steam sign-in, Plus) and the phone, staff and English were largely unseen; Done when 1 and 2 are not amended and no ticket is created for them yet.
  evidence: Retrospective, acceptance decision and action item 1; whether issue #67 (standardise the return button) is closed by the guard built in 16.11 is still to decide.
  resolved: moved to ticket 27.4 (author, 2026-10-28); issue #67 still to decide.
- source_plan: `_bmad-output/initiative-gameble/epic-card-catalog/epic-card-catalog-retrospective.md`
  summary: The epic's text still says a not-owned card shows the real card for everyone (R2, Done when 3) and that set albums keep missing slots (Done when 1); walkthrough tickets 16.26 and 16.24 changed both.
  evidence: Reconciliation section of the retrospective, 2026-10-27.
- source_plan: `_bmad-output/initiative-gameble/epic-season-preparation/epic-season-preparation-retrospective.md`
  summary: Epic 11 is accepted by the author on 2026-10-27 with open items: no dedicated test proves a published season never changes, and promote or discard and the themes page were never tried on staging with a real import.
  evidence: Retrospective, acceptance decision.

- source_plan: `_bmad-output/initiative-gameble/epic-human-readable-codebase/story-a-fresh-machine-follows-the-readme-plan.md`
  summary: `PixelArtExportTest` can hang on an idle `node script/pixel_art/export.mjs` child when the Ruby suite runs in parallel in a fresh container.
  evidence: in a `ruby:4.0.7` container with 8 CPUs, one worker waited 20 minutes on the "check fails and names a PNG whose pixels changed" test while its node child sat in a futex wait; the same command alone exits 0 in seconds and the suite passed once that child was killed. Seen once, not reproduced; a fix would add a timeout around the `Open3.capture2e` call.
  resolved: the test that hung was removed (author, 2026-10-29).

- source_plan: `_bmad-output/initiative-gameble/epic-card-backs/story-the-back-catalogue-unlock-rows-and-the-active-back-plan.md`
  summary: Add the card back unlocks and the active back to the player data export and to the account deletion notice, with the choice described in `fr.yml` and `en.yml`.
  evidence: `Game::ReleasePlayer` now deletes `game_card_back_unlocks` but `Game::ExportOf`, `PlayerExport` and the deletion copy (`accounts` notes) name achievements and not backs; do it with the picker, when a player first sees a back.
  resolved: moved to ticket 26.2 (the picker owns the choice; the export and deletion notice name the backs).
- source_plan: `_bmad-output/initiative-gameble/epic-card-backs/story-the-back-catalogue-unlock-rows-and-the-active-back-plan.md`
  summary: CAP-20 of the spec still says the player picks the active back "in the profile".
  evidence: the UX session of 2026-10-28 put the picker on the Personnalisation page (epic-personalization); the spec line should say so.
  resolved: moved to ticket 26.2 (spec text fix).

- source_plan: `_bmad-output/initiative-gameble/epic-seasons-carry-over/story-carried-tiers-are-received-once-per-season-silently-plan.md`
  summary: `OpenPack` locks the player state row before the holdings upsert, while AD-10 orders bank, holdings, then state rows.
  evidence: harmless today because the player's advisory bank lock serialises both operations and no operation locks holdings then state without it; an operation added later that does would deadlock with `OpenPack`.
  resolved: moved to ticket 17.4 (refactor sweep).

- source_plan: `_bmad-output/initiative-gameble/epic-seasons-carry-over/story-carried-tiers-are-received-once-per-season-silently-plan.md`
  summary: A player state row created by an upsert before `CreatePlayerState` keeps null allocation markers and publishes one extra `SeasonAllocationReceived` at the first opening.
  evidence: `RecordPlayerActivity` and `MarkCollectionSeen` upsert the row; no path was found where one runs before registration, so the effect is cosmetic (one event, no wrong tier).
  resolved: moved to ticket 17.4 (refactor sweep).

- source_plan: `_bmad-output/initiative-gameble/epic-cleanup-1-2-0/story-a-banned-account-can-be-erased-by-staff-plan.md`
  summary: `PlayerExportTest` ("a player's export holds every section…") failed once in the full parallel Ruby run on its weekly contributions line and passes alone; look for a week boundary or a time leak between tests.
  evidence: 3261 runs on 2026-10-28, one failure at `test/models/player_export_test.rb:84`, then 0 failures in the file alone, three times.
  resolved: the weekly contributions assertion was removed (author, 2026-10-29).

- source_plan: `_bmad-output/initiative-gameble/epic-special-packs/story-a-special-reserve-without-cap-plan.md`
  summary: `Game::Reserve.counts` groups unopened packs by kind, which the partial index `index_game_packs_unopened (player_id, available_at, id)` does not cover, so it reads every unopened row of the player on each hub, chip and opening response; the special reserve has no cap.
  evidence: negligible at realistic volumes (a few daily and goal capsules a week); `OpenPack` and `NextPackSize` use the index and are unaffected. Revisit if a player can hold hundreds of special capsules.
  resolved: dropped (author, 2026-10-28): a player will never hold many special capsules.

- source_plan: `_bmad-output/initiative-gameble/epic-special-packs/story-a-special-reserve-without-cap-plan.md`
  summary: Two missing safety nets: no test races two `Game::ClaimGoalReward` calls (once per goal under the bank lock), and `bank_races_test.rb` has no case that races a daily claim against an opening or a heal while 10 standard capsules are held and asserts the standard count stays at 10 and the special count is exactly 1.
  evidence: independent review of the 19.2 commit; the guards (unique indexes and `unclaimed` checks) are unchanged, so this is a missing net, not a regression.
  left in 19.6: new concurrency tests could not be run in that session; write them where `bank_races_test.rb` can run.
  resolved: the three races are in `bank_races_test.rb` (two goal reward claims; a daily claim against an opening and against a heal with ten standard capsules held).

## Deferred from: the staging deploy of the 1.2.0 candidate (2026-10-28)

- source_plan: `_bmad-output/initiative-gameble/staging-after-deploy.md`
  summary: Kamal commands the author runs on staging around the candidate deploy, in this order. Always name the destination (`-d staging`). Before the deploy: `bin/kamal app exec -d staging --roles web --reuse 'bin/rails catalog:number_seasons'` (numbers the cards of every published season; the migration that validates the card-number check refuses to run while one rated card has no number). The deploy itself comes from the candidate pre-release (`bin/kamal deploy -d staging` is what the workflow runs). Right after it: `bin/kamal app exec -d staging --roles web --reuse 'bin/rails game:backfill_player_states'` (a state row for every player, banned included; the seasonal allocation markers need it), then `bin/kamal app exec -d staging --roles web --reuse 'bin/rails game:backfill_card_backs'` (silently unlocks the set, goal and achievement backs players already earned). To check: `bin/kamal app exec -d staging --roles web --reuse 'bin/rails runner "puts Game::CardBackUnlock.count"'`; `bin/kamal console -d staging` for the console and `bin/kamal logs -d staging` for the logs. Event backs are granted to a group on demand with `bin/kamal app exec -d staging --roles web --reuse 'bin/rails "game:grant_card_back[<back>,<steam_id> <steam_id>]"' (the back is saison-1, millesime-2017 or soldes-hiver; the Steam ids are separated by spaces)`.
  evidence: all tasks are idempotent; the full list with the reasons is in `staging-after-deploy.md`.

- source_plan: `_bmad-output/initiative-gameble/epic-cleanup-1-2-0/story-sign-in-with-clerk-and-with-a-provider-other-than-steam-plan.md`
  summary: Prove that every screen renders for a player with no Steam id and a generated handle.
  evidence: No view dereferences steam_id, but no request test signs in such a player; slice 2 adds the sign-in that makes it testable.

- source_plan: `_bmad-output/initiative-gameble/epic-cleanup-1-2-0/story-the-sign-in-screen-offers-discord-google-and-email-through-clerk-plan.md`
  summary: Show the ban reason to a banned player who signed in through Clerk.
  evidence: CurrentBanReason reads a ban through a Steam id; the failed sign-in carries no player, so the banned page shows the generic text.

- source_plan: `_bmad-output/initiative-gameble/epic-cleanup-1-2-0/story-the-sign-in-screen-offers-discord-google-and-email-through-clerk-plan.md`
  summary: A Clerk user who signs in again between its erasure commit and the erasure job is deleted with its new account.
  evidence: The new sign-in registers a player keyed on the Clerk user id, then the job deletes that Clerk user; only possible within seconds of an erasure.

- source_plan: `_bmad-output/initiative-gameble/epic-cleanup-1-2-0/story-the-sign-in-screen-offers-discord-google-and-email-through-clerk-plan.md`
  summary: Hash every verified address of a Clerk user, not only the primary one, for the duplicate-email check.
  evidence: ClerkIdentities.email_hash reads the primary verified address; an external account with another verified address passes the check.

- source_plan: `_bmad-output/initiative-gameble/epic-cleanup-1-2-0/story-the-sign-in-screen-offers-discord-google-and-email-through-clerk-plan.md`
  summary: Name Clerk and the identities in the data export file itself.
  evidence: ExportOf lists identities by provider; the privacy notice names Clerk but the export carries no processor wording.

## Deferred from: code review of story-the-sign-in-screen-offers-discord-google-and-email-through-clerk-plan (2026-10-29)

- The Stimulus controller `clerk_sign_in_controller.ts` has no test of its wiring (submit on `signedIn`, buttons re-enabled after a failure, the Discord and Google strategy whitelist). A mocked vitest of the controller fits.
- Unverified (medium): the controller submits the form right after `setActive` and the server reads the `__session` cookie; settle it with a real sign-in on staging with Discord, Google and an email code.
  resolved: a real Clerk sign-in works on staging on v1.0.0-rc.2, reached from the hub through a Turbo visit, and a Steam account links from the settings (author, 2026-10-29).

## Deferred from: the author, in conversation (2026-10-29)

- A ticket is to be written to rework the layout of the personalization page (`epic-personalization/story-the-personalization-page-plan.md`). The author has not said yet what to change: ask them before writing it, and build nothing from this entry alone. Settled (2026-10-30, author): picking a back becomes simpler and each back says how it was earned; planned in `epic-more-achievements-and-easy-card-backs/` (requirement E5).
