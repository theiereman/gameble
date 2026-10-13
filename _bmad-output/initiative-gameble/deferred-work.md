- source_plan: `_bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/story-walking-skeleton-live-in-production-plan.md`
  summary: Deploy gameble to production with Kamal 2 — Dockerfile changes for the Vite build, `config/deploy.yml` and `.kamal/secrets`, the PostgreSQL 18 accessory with its four databases, HTTPS through the Kamal proxy with Let's Encrypt, and the first `bin/kamal setup`, run by the author.
  evidence: Split from story 1.1 on 2026-10-02 at the author's request. There is no production server, no domain and no Cloudflare setup yet; the author will deploy once a working version exists. Story 1.1's Verify and the epic's Done when checks 1, 4 and 6 name production and wait on this work. Author, 2026-10-12: production goes up once everything is built and validated on staging.
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
  resolved: PR #45 (2026-10-13, `plan-packs-chip-hours.md`) shows H:MM:SS from an hour on the server-rendered chip and the client tick, through the shared `formatClock`.
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
- source_plan: `_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-single-card-face-plan.md`
  summary: A phone's long press on a card face inside a link (tome, pack result) may open the browser's link context menu or a text selection after about 500 ms, cancelling the pointer and ending the finger's tilt early; if so, suppress it while a finger tilts (`contextmenu` prevented, `-webkit-touch-callout: none`, `user-select: none` on `.card`).
  evidence: Story 8.6 review (unverified, medium if true): `attachTilt` (`app/frontend/lib/tilt.ts`) handles no `contextmenu` and `.card` sets no callout or selection rule; settle it with a long press on a tome face on an Android Chrome and an iOS Safari device. Author, 2026-10-12: confirmed, a long press selects text on an iPhone.
  issue: GitHub #31, opened 2026-10-12 to be built.
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
- source_plan: `_bmad-output/initiative-gameble/epic-steam-catalog/story-popularity-led-prestige-score-plan.md`
  summary: To verify (author, 2026-10-08) that a full import writes its draft cards with the current prestige formula (log10(review count) + 4 × Wilson), not the earlier Wilson + 0.01 × log10(count).
  evidence: On staging (v0.0.1-beta.1, which carries story 2.12), the season 2 draft after an import still showed scores from 0.113 to 1.039 (Stardew Valley 1.039, the old formula; the new one gives about 9.8); "Rescore the cards" on the latest run fixed them. Whether the import had not reached its cards step yet or ran on an image older than 2.12 was not established. Check: after the next full import completes, the draft preview's scores run from about 2.7 to 10 without a rescore; otherwise trace the import role's image and the cards step. Author, 2026-10-12: ok.
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
- source_plan: `_bmad-output/initiative-gameble/plan-packs-chip-hours.md`
  summary: No vitest covers a Stimulus controller, so `countdown_controller.ts`'s tick and refresh logic has no unit test of its own; its clock formats are the tested `formatClock` and `formatDailyClock`.
  evidence: This plan's quick review finding 2, patched by reusing `formatClock`; the repo still has only `app/frontend/lib/*.test.ts` in a node environment, with no Stimulus-controller test harness.
- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-db-schema-rb-round-trips-the-steam-checks-plan.md`
  summary: Nothing stops a new migration from writing a check as `col IN (...)` on a varchar column, whose dumped form CI's load-and-dump drift step rewrites; a line under "Known pitfalls" in AGENTS.md (write list checks as `col = 'a' OR col = 'b'`) or a lint rule would close it.
  evidence: This plan's quick review; the only guard is the comment in `db/migrate/20261002210000_create_catalog.rb`, which twelve later migrations missed. The fix edits agent-context files, which the build defers to the author.
- source_plan: `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-db-schema-rb-round-trips-the-steam-checks-plan.md`
  summary: CI's drift step (`bin/rails db:create db:migrate && git diff --exit-code -- db/schema.rb`) never runs the existing migrations: on an empty database Rails 8.1's `db:migrate` loads db/schema.rb first, so the step checks only that a load dumps the same file; pointing `SCHEMA` at a missing file for the migrate and diffing that dump would test the migrations themselves.
  evidence: `ActiveRecord::Tasks::DatabaseTasks#initialize_database` (activerecord 8.1.4) loads the schema file when `schema_migrations` does not exist; the same applies to AGENTS.md's regeneration command. Found while building this ticket, 2026-10-13.
