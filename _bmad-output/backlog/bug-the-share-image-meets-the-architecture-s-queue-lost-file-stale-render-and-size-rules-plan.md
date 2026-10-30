---
title: "The share image meets the architecture's queue, lost-file, stale-render and size rules"
type: 'bugfix'
ticket: 'bug-the-share-image-meets-the-architecture-s-queue-lost-file-stale-render-and-size-rules'
created: '2026-10-30'
status: 'built'
baseline_revision: '50fb6fbd7c8a0381571b82baf3be5e51fdc14340'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/backlog/bug-the-share-image-meets-the-architecture-s-queue-lost-file-stale-render-and-size-rules.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The shared card's generated preview image (commits 46a61856, 50fb6fbd) predates AD-39 and breaks four of its rules: renders run on `default`; a row whose file is lost keeps advertising a 404 image; the PNG is uploaded inside the store's transaction (holding the card-season lock, orphaning the file on rollback) and an older render can overwrite a newer one; nothing bounds the PNG's size.

**Approach:** Move `CardShareImageJob` to a `share_images` queue served by its own one-thread worker in `config/queue.yml`; make the page's lookup and the store treat a row without its file as missing; upload the PNG before `Catalog::StoreShareImage`'s transaction and, under the card-season lock, refuse with `Failure(:stale_render)` a render whose fingerprint no longer matches the card, deleting the uploaded file on every path that does not attach it; re-save a render over 300 KB with a palette, and test the byte size.

## Boundaries & Constraints

**Always:** writes only through `Catalog::StoreShareImage`, which publishes `Catalog::ShareImageStored` once, inside its transaction, only when it attaches a new image; jobs enqueued only after commit (the page's GET has no transaction; `Refresh` runs in the upsert's transaction and Rails enqueues after commit); no database write outside the operation's transaction (the blob row is saved inside it, only the file is written before); every string in `en.yml` and `fr.yml`; no planning ids in code; no narrative comments.

**Never:** change the image's look, URL, token rule, cache headers or `noindex`; the fingerprint's content; the page's other preview tags; the hourly and daily throttles; the storage service (local disk stays); the Kamal deploy files.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Page, file lost | row with matching fingerprint, file deleted from storage | text-only tags (`twitter:card` summary, no `og:image`/`twitter:image`), render enqueued on `share_images` (once an hour) | no error |
| Job, file lost | same row | job renders again (`ShareImageFor` is nil) and the store replaces the row under a new token with the new file | no error |
| Store, current | fingerprint == current fingerprint, no row or other fingerprint | row stored or replaced, one `ShareImageStored`, old blob purged after commit | no error |
| Store, already stored | row with this fingerprint and its file | `Success(existing row)`, no event, the just-uploaded file deleted, blob count unchanged | no error |
| Store, stale | `current_fingerprint.call` ≠ `fingerprint` under the lock | `Failure(:stale_render)`, no row change, no event, uploaded file deleted | job neither reports nor holds off |
| Store, not published | draft or unknown card-season | `Failure(:card_season_not_published)`, uploaded file deleted | job reports `NotStored` as today |
| Store, invalid input | bad locale, fingerprint, PNG, size, non-callable `current_fingerprint` | `Failure(:invalid_share_image)` before any upload | as today |
| Store, raise inside the transaction | e.g. `save!` raises | transaction rolls back, uploaded file deleted, exception propagates | as today |
| Busy art | noisy Steam cover | PNG under `CardShareImage::MAX_BYTES` (300 KB) | — |
| Render over the limit | plain PNG bytesize > `MAX_BYTES` | saved again with `palette: true` (PNG colour type 3) and stored as such | `Vips::Error` reported as today |

</intent-contract>

## Code Map

- `app/jobs/card_share_image_job.rb` -- `queue_as :default` → `:share_images`; passes `current_fingerprint:` to the store; `:stale_render` is neither reported nor held off.
- `config/queue.yml` -- add a second worker `{ queues: [ share_images ], threads: 1, processes: 1, polling_interval: 1 }` in the shared `default` anchor (dev, test, production inherit); keep the header's style.
- `app/models/card_share_image.rb` -- add `MAX_BYTES = 300.kilobytes`; optionally a `fingerprint_of(card_season_id, locale)` helper (view via `Catalog::CardViews`, nil when none) the job's callable uses. `current_token`, `render_later`, throttles unchanged.
- `app/models/card_share_image/composition.rb` -- `#png` (line 52–59): when the plain `pngsave_buffer(compression: 9, strip: true)` exceeds `CardShareImage::MAX_BYTES`, return `pngsave_buffer(compression: 9, strip: true, palette: true)`. File is 204 lines; limit 400.
- `app/domains/catalog/app/operations/catalog/store_share_image.rb` -- new keyword `current_fingerprint:` (a callable, validated by `respond_to?(:call)`); build the blob with `ActiveStorage::Blob.build_after_unfurling(io:, filename: "#{token}.png", content_type:, identify: false, metadata: { analyzed: true, identified: true, width:, height: })` and `blob.upload_without_unfurling(io)` (rewind or fresh `StringIO`) BEFORE `transaction`; token from `ShareImage.generate_unique_secure_token(length: 24)` before the upload; inside: lock (as now) → `step` refusing `:stale_render` when `current_fingerprint.call != fingerprint` → existing row with this fingerprint AND its file present returns it → otherwise `replace` attaches the unsaved blob (`share_image.image = blob`, the blob row saves with the attachment) and publishes. Delete the file (`blob.delete`) in an `ensure` unless it ended attached to the committed row (dry-operation's `step` halts by `throw`, so `ensure` runs on failures too).
- `app/domains/catalog/app/models/catalog/share_image.rb` -- one place that says whether a row's file is stored: e.g. `self.file_stored?(key:, service_name:)` via `ActiveStorage::Blob.services.fetch(service_name).exist?(key)` and an instance `file_stored?` using its attachment.
- `app/domains/catalog/app/queries/catalog/share_image_for.rb` -- keep ONE query: `joins(image_attachment: :blob)` and `pick(:token, :fingerprint, "active_storage_blobs.key", "active_storage_blobs.service_name")`; return `Stored` only when the file is stored, else nil. `cards_controller_test.rb` counts queries per request (lines 862–900); the count must not change.
- `config/locales/en.yml` (~line 867–875, `errors.catalog`), `config/locales/fr.yml` (~line 2223) -- `stale_render` in both; French needs no plural.
- `test/support/share_image_art.rb` -- `store_share_image` passes `current_fingerprint: -> { fingerprint }`.
- `test/lib/connection_budget_test.rb`, `lib/connection_budget.rb` -- the budget counts each `queue.yml` worker as a process (14 connections): staging and production go 65 → 79 (limit 80); the "JOB_CONCURRENCY 2 … within the limit" test becomes 93 and over the limit. Update the figures, names and that test to the new truth; do not change `lib/connection_budget.rb` or `LIMIT`.
- `test/config/queue_config_test.rb` -- existing coverage of `queue.yml`; add the `share_images` assertion here.
- `test/support` has `stub_const` available (used in `card_share_image_test.rb:38`).
- No Kamal change: jobs run inside Puma (`SOLID_QUEUE_IN_PUMA: true`, `config/deploy.yml:41`), whose Solid Queue reads `config/queue.yml`.

## Tasks & Acceptance

**Execution:**
- [x] `config/queue.yml` -- add the one-thread `share_images` worker -- AD-39 / AD-21 queue rule.
- [x] `app/jobs/card_share_image_job.rb` -- `queue_as :share_images`; pass `current_fingerprint:`; skip report and hold-off on `:stale_render` -- renders off `default`; a lost race is expected, not an error.
- [x] `app/domains/catalog/app/models/catalog/share_image.rb`, `app/domains/catalog/app/queries/catalog/share_image_for.rb` -- file-presence check; one-query lookup returning nil for a lost file -- lost file counts as missing.
- [x] `app/domains/catalog/app/operations/catalog/store_share_image.rb` -- upload before the transaction, stale refusal under the lock, lost-file replace, file deleted on every non-attaching path -- AD-39 store rule.
- [x] `app/models/card_share_image.rb`, `app/models/card_share_image/composition.rb` -- `MAX_BYTES`, palette re-save -- size rule.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- `errors.catalog.stale_render`.
- [x] Tests: `test/domains/catalog/store_share_image_test.rb` (stale refused: no row change, no event, `ActiveStorage::Blob.count` unchanged and no file left in the disk service's root — e.g. count files under `ActiveStorage::Blob.service.root` before/after; already-stored and not-published paths leave no file; lost file is replaced under a new token; `ShareImageFor` nil for a lost file; the upload happens before the transaction — e.g. the file exists when the lock step runs, or assert the service's `upload` is called outside an open transaction via `ActiveRecord::Base.connection.transaction_open?` relative to the test's own transaction); `test/jobs/card_share_image_job_test.rb` (queue name `share_images`; a stale race — card changed between render and store — stores nothing and reports nothing); `test/controllers/card_preview_tags_test.rb` (lost file → text-only tags and render enqueued on `share_images`); `test/models/card_share_image_test.rb` (busy-art render bytesize < `MAX_BYTES`; with `stub_const(CardShareImage, :MAX_BYTES, …)` lowered, the PNG is palette type 3 and smaller than the plain one; `Refresh` enqueues on `share_images`); `test/config/queue_config_test.rb` (`share_images` served by exactly one worker with one thread and one process in development, test and production, and not by the default worker); `test/lib/connection_budget_test.rb` (figures updated).

**Acceptance Criteria:**
- Given the card page enqueues a render or `Catalog::CardIdentityUpserted` refreshes one, when the job is enqueued, then its queue is `share_images`, which `config/queue.yml` serves with one thread in every environment.
- Given a stored image whose file is gone, when the card page is opened, then it carries no `og:image`, `twitter:image` or `summary_large_image` and enqueues the render (within the hourly throttle).
- Given a render whose fingerprint no longer matches the card when stored, when `Catalog::StoreShareImage` runs, then it returns `Failure(:stale_render)`, changes no row, publishes no event and leaves no file; the PNG upload happens before the transaction opens.
- Given a card with busy art, when its image is rendered, then its PNG is under 300 KB, and a render over the limit is saved with a palette.

## Implementation Notes

- The operation takes `current_fingerprint:`, a callable it runs after the lock; the job passes `-> { CardShareImage.fingerprint_of(card_season_id, locale) }`. A missing card view under the lock (text deleted mid-render) reads as `:stale_render`.
- The blob is built unsaved and its file uploaded before `transaction`; `share_image.image = blob` saves the blob row with the attachment inside it. An `ensure` deletes the file unless the returned row holds this blob, so stale, already stored, not published, a raising upload and an exception inside the transaction leave no file.
- `ShareImageFor` stays one query (inner join to the blob); `ShareImage.file_stored?` reads the blob's service through the registry's block form, so an unconfigured service counts as not stored.
- A noisy cover renders at about 47 KB truecolour, so the palette branch is exercised by lowering `MAX_BYTES` with `stub_const`.
- `test/lib/connection_budget_task_test.rb` also counts the budget and was updated with `connection_budget_test.rb`: staging and production 65 → 79 of 80; `JOB_CONCURRENCY 2` 79 → 93, now over the limit.
- No Kamal change: jobs run inside Puma, whose Solid Queue reads `config/queue.yml`.

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 26 findings — high 0, medium 2, low 20, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` (blind) A storage error in the lost-file check 500s the card page; an unconfigured service raises `KeyError` — `Registry#fetch` raises for a service missing from `storage.yml` (the planned storage move); `file_stored?` now uses the block form (`{ return false }`), tested by renaming the blob's service to "gone".
  - `[low]` `[reject]` (blind) Inside an outer transaction that rolls back, the attached file is orphaned — only the job calls the operation, never inside a transaction; guarding it adds a branch for a caller that does not exist.
  - `[low]` `[reject]` (blind) A `blob.delete` that raises in `ensure` replaces the operation's outcome — `DiskService#delete` rescues `ENOENT`; another error needs a broken disk, where the job failing visibly is acceptable; a rescue adds a branch.
  - `[low]` `[reject]` (blind) The new worker takes the connection budget to 79 of 80 and `JOB_CONCURRENCY 2` no longer fits — AD-39 asks for one thread for `share_images`, and Solid Queue sets threads per worker process; the budget tests record the new totals and the author is told; `config/deploy.yml`'s `JOB_CONCURRENCY: 3` line is Rails' commented template.
  - `[low]` `[reject]` (blind) A Refresh flood of no-op jobs can starve page renders on one thread — carried from the story's review (enqueue without fingerprint work keeps the import's transaction light); each no-op job is a few queries; the queue now isolates them from `default`.
  - `[low]` `[patch]` (blind) `stale_render`'s message promises the newer image takes its place — reworded in both locales: the card changed while its image was drawn, so that image was not kept.
  - `[low]` `[reject]` (blind) An over-limit palette render is stored silently and the busy-art test pins truecolour — a noisy cover renders at ~47 KB; the art area is 109 × 112 source pixels, so a palette render over 300 KB is not reachable; the truecolour assertion proves real busy art needs no palette.
  - `[low]` `[reject]` (blind) A row without an attachment now counts as missing, untested — the operation always attaches the blob when it saves a row; no path creates such a row.
  - `[low]` `[patch]` (blind) Duplicate and tautological queue tests, and a third hand-made `MemoryStore` swap — the job test's queue case (duplicate of the config test, and an `assert_enqueued_with` around a bare `perform_later`) deleted; moving the cache helper to `test/support` is more than a deletion for a cosmetic gain, rejected.
  - `[low]` `[reject]` (blind) The story plan still lists these rules as deferred — that plan's `deferred` list is append-only history; this ticket's plan records their resolution.
  - `[low]` `[patch]` (blind) The `config/queue.yml` comment gives a design reason — deleted; the header is back to its original wording.
  - `[false]` `[reject]` (blind) `upload` returns an unsaved blob and wraps the PNG twice — no harm named; the helper is now `build_blob` after the partial-upload patch, and a second `StringIO` replaces a rewind.
  - `[medium]` `[patch]` (edge) An unconfigured service makes `Registry#fetch` raise on every card page GET — same root cause as the first blind row; same fix.
  - `[false]` `[reject]` (edge) `exist?` raising (permissions, unreachable service) 500s the page — the disk service's `exist?` is `File.exist?`, which returns false rather than raising; a networked service is the deferred storage move's concern.
  - `[low]` `[reject]` (edge) A palette re-save still over `MAX_BYTES` is stored — as the blind palette row above.
  - `[low]` `[patch]` (edge) An upload raising after a partial write leaves `blob` nil and orphans the file — the blob is now built into the local before `upload_without_unfurling`, so the `ensure` deletes it.
  - `[low]` `[reject]` (edge) `blob.delete` raising inside `ensure` hides the real outcome — as the blind row above.
  - `[false]` `[reject]` (edge) A lost file under a day-long hold-off waits a day — the hold-off exists only after a failed render of that fingerprint, which is the designed one-day wait; otherwise the hourly throttle applies.
  - `[low]` `[reject]` (verification-gap, other) The budget is at 79 of 80 — as the blind budget row above.
  - `[low]` `[reject]` (intent) A new forked worker rather than a thread in an existing process changes the connection budget — as the blind budget row above.
  - `[low]` `[reject]` (intent) The already-stored path now uploads then deletes — reached only when two jobs race to the same fingerprint (the job skips a current image first); AD-39 asks for the upload before the transaction.
  - `[low]` `[reject]` (intent) Card edits do not take the card-season lock, so an edit landing after the check is stored stale — a milliseconds window; the page compares fingerprints on every GET and re-enqueues within the hour; AD-39 names the card-season lock.
  - `[low]` `[reject]` (intent) A card view gone under the lock reads as `:stale_render`, not `:card_season_not_published` — needs the card's text deleted mid-render; either way nothing is stored and a later render settles it.
  - `[low]` `[reject]` (intent) The size tests run on the composition, not the store, and the palette branch only under a lowered limit — as the blind palette row above; the store stores the composition's bytes unchanged.
  - `[false]` `[reject]` (intent) A storage `exist?` per card page GET — no defect claimed: read-only, a `File.exist?` on the local disk, noted in Design Notes for the storage move.
  - `[low]` `[patch]` (intent) A design-reason comment in `config/queue.yml` and new test headers — the `queue.yml` sentence deleted (same as the blind row); test headers follow the existing test files' style, kept.

## Design Notes

- The stale check needs the card's fingerprint now, which only the web layer computes (`CardShareImage.fingerprint` reads `CardStrings`, `SetLabel`, theme names); `Catalog` must not reference it (packwerk). So the caller hands the operation a callable it runs after taking the lock: `current_fingerprint: -> { CardShareImage.fingerprint_of(card_season_id, locale) }`. Comparing only the `CardView` would miss a renamed theme, which the fingerprint covers.
- The blob is built unsaved and its file uploaded before the transaction; attaching an unsaved `ActiveStorage::Blob` saves its row with the attachment inside the transaction (Active Storage's `CreateOne#upload` does nothing for a Blob attachable). Rails' `Hash` attachable would upload after commit instead — not what AD-39 asks.
- A file-presence check on every card page is a `File.exist?` on the local disk; with object storage later it becomes a HEAD request — acceptable under the hourly throttle, revisit with the S3 move.
- The palette re-save is stored whatever its size; a render still over the limit is not refused.
- The new worker is a forked process with its own pools: 14 connections, budget 79 of 80. `JOB_CONCURRENCY 2` no longer fits; the author should know.

## Verification

Use `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_wad39 CHROME_BIN=/usr/bin/chromium` on every test command; prepare with `RAILS_ENV=test bin/rails db:drop db:create db:schema:load`.

**Commands:**
- `bin/rails test test/domains/catalog/store_share_image_test.rb test/jobs/card_share_image_job_test.rb test/models/card_share_image_test.rb test/controllers/card_preview_tags_test.rb test/controllers/share_images_controller_test.rb test/controllers/cards_controller_test.rb test/config/queue_config_test.rb test/lib/connection_budget_test.rb` -- expected: green
- `bin/rails test test/system/share_card_test.rb test/system/card_detail_test.rb` -- expected: green
- `bin/rubocop` on touched files, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing` -- expected: clean
- `bin/rails test` -- expected: green

## Auto Run Result

**Summary:** The share image meets AD-39's four remaining rules. `CardShareImageJob` runs on a `share_images` queue served by its own one-thread, one-process worker in `config/queue.yml`. The card page's lookup and the store treat a row whose file is gone, or whose storage service is no longer configured, as missing: the page shows the text preview and enqueues the render within the hourly throttle, and the job stores it again under a new token. `Catalog::StoreShareImage` uploads the PNG before its transaction and, under the card-season lock, refuses with `Failure(:stale_render)` a render whose fingerprint no longer matches the card; the uploaded file is deleted on every path that does not attach it. A render over 300 KB is saved again with a palette.

**Files:**
- `config/queue.yml`: the `share_images` worker.
- `app/jobs/card_share_image_job.rb`: the queue, the `current_fingerprint:` callable, no report or hold-off on `:stale_render`.
- `app/domains/catalog/app/models/catalog/share_image.rb`, `app/domains/catalog/app/queries/catalog/share_image_for.rb`: file-presence check; one-query lookup.
- `app/domains/catalog/app/operations/catalog/store_share_image.rb`: upload before the transaction, stale refusal, lost-file replace, file cleanup.
- `app/models/card_share_image.rb`, `app/models/card_share_image/composition.rb`: `MAX_BYTES`, `fingerprint_of`, palette re-save.
- `config/locales/en.yml`, `config/locales/fr.yml`: `errors.catalog.stale_render`.
- Tests: `store_share_image_test.rb`, `card_share_image_job_test.rb`, `card_share_image_test.rb`, `card_preview_tags_test.rb`, `queue_config_test.rb`, `connection_budget_test.rb`, `connection_budget_task_test.rb`, `test/support/share_image_art.rb`.

**Review:** 26 findings: 2 medium, 20 low, 4 false.
- Patched, 5 entries: the unconfigured storage service (medium); the partial-upload orphan, the `stale_render` wording, the duplicate queue test and the `queue.yml` comment (low).
- Deferred: none.
- Rejected: the rest, each with its reason in the triage log (nested transaction, delete raising in `ensure`, connection budget, refresh flood, palette still over the limit, attachment-less row, story plan history, upload-then-delete on a race, card edits outside the lock, view gone under the lock, test placement, and four false).

**Follow-up review:** not recommended. One medium entry was patched, with a one-line guard and a test; the other patches are a reorder, a text, a test deletion and a comment deletion.

**Verification:**
- `bin/rails test`: 3677 runs, 0 failures.
- System `share_card_test.rb` and `card_detail_test.rb`: 20 runs, 0 failures.
- Clean: rubocop on the touched files, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing`.

**Residual risks:**
- The connection budget is at 79 of 80 in staging and production; `JOB_CONCURRENCY 2` no longer fits.
- The lost-file check becomes a storage request per card page once storage moves to S3; a networked `exist?` that raises would then need handling.
- The production libvips's palette writer is unverified (the story's pending staging check covers the render).

