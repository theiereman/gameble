---
title: 'A shared card link previews with a generated image'
type: 'feature'
ticket: 'story-a-shared-card-link-previews-with-a-generated-image'
created: '2026-10-30'
status: 'built'
baseline_revision: '0a00ddafa1f61c609855cfc57c276e75b64c3758'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/backlog/story-a-shared-card-link-previews-with-a-generated-image.md'
warnings: [oversized]
deferred:
  - summary: >-
      The render has never run against the Docker image's libvips (Debian slim, --no-install-recommends).
    evidence: |-
      CI and development use other libvips builds. If the image's libvips lacks pango text, every render raises Vips::Error,
      is reported and stores nothing, so previews stay text-only; without a GIF writer the art ships unquantised.
      Settled by one render on staging (pending-approvals entry).
    location: >-
      Dockerfile:19, app/models/card_share_image/composition.rb
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** A shared card link previews as text only on Discord, X and WhatsApp; the author lifted the "no image" rule (2026-10-21) and wants the preview to show the card.

**Approach:** A job composes a 1200 × 630 PNG per published card-season and language with libvips (the card's frame, rarity colours and fonts around its pixelated Steam art, title and rarity in that language), stores it through Active Storage on the local disk, and the card page's tags point at it through a token URL of the app's own, served signed out with a long cache lifetime. A GET only reads and, when the image is missing or stale, enqueues the job.

## Decisions (author, 2026-10-30)

- One image per published card-season and language; nothing about the sharer or holder in it.
- The image looks like the in-game card: Steam art in the card frame, rarity colours, the game's fonts (VT323, JetBrains Mono), title and rarity in the share link's language.
- Rendering: a job with libvips (`ruby-vips`, already in the Gemfile, `require: false`; libvips is in the Docker image), stored through Active Storage on the `local` disk service (production's `/rails/storage` is the persisted `gameble_storage` Kamal volume). Installing Active Storage's tables is an expand migration; its own routes are not drawn (signed blob ids carry database ids); the image is served from `/share-images/<token>.png`.
- Steam's terms on reusing store art: the author checks before release; an open entry in `pending-approvals.md` asks for it.
- Cloudflare: settled; the image URL must be reachable by the preview crawlers as the page is (noted in the same entry).
- The spec's and the architecture's "no image" wording (CAP-9, AD-15, AD-17's "never stored") is updated by the author, not by this build.

## Boundaries & Constraints

**Always:** writes through `Catalog` operations publishing one event in their transaction; GET never writes (enqueuing and `Rails.cache` are allowed); jobs enqueued after commit; no database id in any URL, tag or file name; every action authorized with Pundit; strings in `en.yml` and `fr.yml`; files under 400 lines; strong_migrations.

**Never:** change the preview's title, description, canonical URL, locale or `noindex`, the public profile tags, the card page body or its ownership notice; name a player in the image, its URL or its row; render inside a request; draw Active Storage's routes; fetch an art URL outside Steam's image hosts (`Steam::Cdn::IMAGE_SOURCES`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First open | no image row | text-only tags (`twitter:card` summary), render job enqueued once per hour per card-season, locale and fingerprint | none |
| Image current | row whose fingerprint matches the card's current view | `og:image`, `og:image:width` 1200, `og:image:height` 630, `og:image:type`, `og:image:alt`, `twitter:card` summary_large_image, `twitter:image`, `twitter:image:alt`, absolute on `PUBLIC_URL` | none |
| Art or title changed | stored fingerprint differs | text-only tags, job enqueued; `Catalog::CardIdentityUpserted` of a card with images also enqueues it; the job stores the new image under a new token | old blob purged later |
| Job rerun | fingerprint already stored | no render, nothing written | none |
| Unusable art | URL off Steam's hosts, HTTP failure, undecodable, under 300 × 450, flat grey | nothing stored, page stays text-only | `Rails.error.report` |
| Image fetch | `GET /share-images/<token>.png`, signed out, any browser or crawler | 200 `image/png`, `Cache-Control: public, max-age=31536000, immutable` | unknown token: 404 |

</intent-contract>

## Code Map

- `app/controllers/cards_controller.rb`, `app/views/cards/show.html.erb`, `app/views/cards/_share_tags.html.erb` -- the card page and its tags; `@detail.view` (`Catalog::CardView`) and `@detail.card_season_id` feed the fingerprint.
- `app/helpers/public_urls_helper.rb` (`public_url_for`), `app/helpers/card_details_helper.rb` -- absolute URLs on `PUBLIC_URL`; a route outside `:locale` needs `locale: nil` against `default_url_options`.
- `app/controllers/concerns/public_read.rb` -- lets crawlers and old browsers through `allow_browser`.
- `app/models/live_stream.rb`, `app/jobs/live_feed_job.rb`, `config/initializers/event_store.rb` -- web-layer subscriber and job patterns.
- `app/domains/catalog/app/operations/catalog/upsert_card_identity.rb`, `.../card_writing.rb` -- operation and retry-on-unique pattern; `lib/application_operation.rb`.
- `app/domains/steam/app/clients/steam/web_api.rb` -- `class_attribute :adapter` for Faraday, stubbed in `test/test_helper.rb`.
- `app/components/card_component.*`, `app/frontend/styles/card.css`, `tokens.css` -- card geometry and colours (xl: 240 × 360, frame 6, padding 5, art 218 × 224, art pixel 2 px, lines 18 and 24); `app/frontend/lib/card_art/placeholder.ts`, `downscale.ts` -- missing-art rules and the 42 % crop anchor.
- `app/frontend/images/pixel/rarity-<tier>.svg` -- rarity icons.
- `test/controllers/card_preview_tags_test.rb` -- asserts "no image"; rewrite those assertions.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/<ts>_create_active_storage_tables.active_storage.rb`, `db/migrate/<ts+1>_create_catalog_share_images.rb`, `db/schema.rb` -- Active Storage's tables; `catalog_share_images` (card_season fk, locale checked en/fr, unique token, fingerprint, unique card_season + locale).
- [ ] `config/application.rb` -- `config.active_storage.draw_routes = false`.
- [ ] `app/domains/catalog/app/models/catalog/share_image.rb`, queries `share_image_for.rb`, `share_image_by_token.rb`, `share_images_of_card.rb`, operation `store_share_image.rb`, event `share_image_stored.rb` -- the row and its PNG; the operation replaces the image and token when the fingerprint changes, does nothing when it matches, refuses a card-season outside a published season.
- [ ] `vendor/fonts/` -- TTF copies of `app/frontend/fonts/vt323-{latin,latin-ext}-400-normal.woff2` and `jetbrains-mono-{latin,latin-ext}-700-normal.woff2` (libvips' text ignores woff2; `uvx --from "fonttools[woff]" fonttools ttLib.woff2 decompress <file>` converts one) with copies of the two OFL licences; each passed to `Vips::Image.text` through `fontfile:` (`font: "VT323 <px>"` or `"JetBrains Mono Bold <px>"`, `dpi: 72`).
- [ ] `app/models/card_share_image.rb` and `app/models/card_share_image/{art,composition,refresh}.rb` -- fingerprint, page lookup with throttled enqueue, art fetch and pixelation, the composition, the identity-change subscriber.
- [ ] `app/jobs/card_share_image_job.rb` -- render, store, report failures.
- [ ] `app/controllers/share_images_controller.rb`, `config/routes.rb` -- the token route, signed out, long cache, no session write.
- [ ] `app/views/cards/_share_tags.html.erb`, `show.html.erb`, `cards_controller.rb`, `config/locales/{en,fr}.yml` -- image tags and their alt text.
- [ ] Tests: `test/domains/catalog/store_share_image_test.rb`, `test/models/card_share_image_test.rb`, `test/jobs/card_share_image_job_test.rb`, `test/controllers/share_images_controller_test.rb`, `test/controllers/card_preview_tags_test.rb`.
- [ ] `_bmad-output/initiative-gameble/pending-approvals.md` -- open entry: Steam's terms before production, crawler reach of `/share-images/*`.

**Acceptance Criteria:**
- Given a published card with a current image, when its share link is opened in either language, then the page carries the image tags with an absolute URL, 1200 × 630 and an alt naming the card, and its title, description, canonical, locale and robots tags are unchanged.
- Given the image URL, when fetched signed out by any user agent, then it answers a 1200 × 630 PNG, publicly cacheable for a year, whose URL holds a token only.
- Given a card page GET, then no render runs in the request and nothing is written to the primary.

## Implementation Notes

- libvips' SVG loader is blocked as untrusted once Active Storage loads (`Vips.block_untrusted(true)`), so the rarity icon is drawn from the pixel SVG's runs by `app/models/card_share_image/rarity_icon.rb` (an extra file beside art, composition and refresh) rather than through `svgload`.
- libvips quantises only through a palette writer: the art goes through a 5-bit GIF round trip (32 colours, no dither); a `Vips::Error` there keeps the plain pixels.
- `ShareImagesController` also skips `set_sentry_user`, nils `pundit_user` and sets `session_options[:skip]`: the CSP nonce generator reads `session.id`, which otherwise re-sends a signed-in visitor's session cookie on a response meant to be cached publicly. `max-age` is `365.days` (31536000), not `1.year` (31556952).
- `StoreShareImage` serialises writers on the card-season row (`FOR NO KEY UPDATE OF catalog_card_seasons`), so two jobs never race on the unique (card_season, locale) index.
- The card page costs one query more (the share image lookup): `test/controllers/cards_controller_test.rb`'s query counts move by one.

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 43 findings — high 0, medium 9, low 26, false 6, maybe-false 2
- findings:
  - `[medium]` `[patch]` (blind) An unusable art is re-fetched and re-reported every hour forever — job now reports, then `CardShareImage.hold_off` blocks the page's re-enqueue of that fingerprint for a day; MemoryStore test.
  - `[medium]` `[patch]` (blind) Fingerprint ignores the drawn words (theme rename, rarity wording) — fingerprint now hashes `view.to_h` plus rarity name, genre label and number label under the image's locale; theme-rename test.
  - `[low]` `[patch]` (blind) `VIEW_FIELDS` repeats `CardView`'s members — removed; the whole `view.to_h` is hashed.
  - `[false]` `[reject]` (blind) Untrusted libvips loaders are not blocked — Active Storage's `active_storage/vips.rb` calls `Vips.block_untrusted(true)` at boot; checked under a production boot: an SVG buffer is refused ("not in a known format").
  - `[low]` `[reject]` (blind) The download is buffered before the 8 MB check — the host is Steam's CDN only, covers are ~100 kB; streaming adds complexity for no met case.
  - `[low]` `[reject]` (blind) A lost storage volume never heals — needs a lost volume with the database kept; the recovery (clear rows or bump `RENDER_VERSION`) is in the pending-approvals entry.
  - `[low]` `[reject]` (blind) The PNG is uploaded inside the transaction, orphaning a file on rollback — a rollback after a successful upload needs a failed save or publish; the orphan is a ~30 kB file; moving the upload adds cleanup branches.
  - `[low]` `[reject]` (blind) Every card request, Turbo-frame browsing included, does the lookup — one indexed query; warming images of browsed cards is wanted, so the card is rendered before it is shared.
  - `[low]` `[reject]` (blind) No backfill or pre-render — the share button sits on the card page, whose GET enqueues the render before the link is pasted; a catalog-wide render is a long real job for the author to decide.
  - `[medium]` `[patch]` (blind) The image could be indexed in production (SEARCH_INDEXING on) — `ShareImagesController` always sends `X-Robots-Tag: noindex`; tested with indexing on.
  - `[low]` `[reject]` (blind) Non-Latin titles may show boxes — accepted limitation in Design Notes; DejaVu (pulled in by fontconfig) covers Cyrillic and Greek; CJK titles are rare in the en and fr texts; vendoring a CJK font is a separate decision.
  - `[low]` `[reject]` (blind) `register_fonts` memoized per instance — libvips keeps a set of added font files, so a repeat costs four tiny renders (~1 ms) per image.
  - `[low]` `[reject]` (blind) `image/png` defined in two places — the operation validates the PNG signature, so both constants always agree; cosmetic.
  - `[false]` `[reject]` (blind) No bound on PNG byte size, WhatsApp may drop large images — measured renders are 20–40 kB, far under any client's limit.
  - `[medium]` `[patch]` (blind) `Refresh` runs CardViews and fingerprint work inside every import transaction — now one query and one enqueue per stored image; the job skips current ones; tests adjusted.
  - `[low]` `[patch]` (blind) The job's `NotStored` and failure paths are untested — `NotStored` test added (a draft card-season with a rarity).
  - `[medium]` `[patch]` (edge) Permanently unusable art retried and reported hourly — same root cause as the first row; same fix.
  - `[medium]` `[patch]` (edge) Theme rename or label wording never refreshes the image — same root cause as the second row; same fix.
  - `[medium]` `[patch]` (edge) Flat-grey check ran on the full cover, unlike the face's palette-size check — now runs on the cropped 109 × 112 art; noisy grey JPEG fixture.
  - `[low]` `[reject]` (edge) Body buffered before the size check — as the blind row above.
  - `[low]` `[reject]` (edge) Orphaned PNG on rollback; `save!` raises — as the blind row above; a raise fails the job visibly in Solid Queue.
  - `[low]` `[reject]` (edge) Turbo-frame visits enqueue renders — as the blind row above.
  - `[low]` `[reject]` (edge) Missing blob file keeps advertising a 404 image — as the blind row above.
  - `[low]` `[reject]` (edge) An older job finishing after a newer one stores a stale image — needs a card change during a sub-second render; the next page view after the hour throttle re-renders it.
  - `[low]` `[reject]` (edge) A token rotated between page and crawler fetch gives a 404 — only on a card change, in a seconds-long window.
  - `[low]` `[reject]` (edge) Non-Latin glyphs fall back — as the blind row above.
  - `[low]` `[patch]` (edge) Control characters make the Pango markup invalid — stripped before escaping; test title holds "\u0007".
  - `[low]` `[reject]` (edge) Cache key written but the enqueue fails — Solid Queue enqueue failures are exceptional; the render waits at most an hour.
  - `[false]` `[reject]` (edge) "A GET only reads" while it writes a cache entry — the plan's Design Notes state the cache and the queue are allowed; the primary is untouched (read-only test passes).
  - `[low]` `[patch]` (verification-gap) Nothing checks Active Storage's routes stay off — routing test: no `/rails/active_storage` path; `POST .../direct_uploads` is 404.
  - `[medium]` `[patch]` (verification-gap) The composition is checked only for size — pixel test: art pixels zoomed ×3 and the frame in the rarity colour.
  - `[maybe-false]` `[defer]` (verification-gap) The production image's libvips is never exercised — would be medium if its libvips lacks pango text; settled by a render on staging (added to the pending-approvals entry).
  - `[low]` `[patch]` (verification-gap) The `NotStored` report is never exercised — same as the blind row; test added.
  - `[low]` `[reject]` (verification-gap) `COPY vendor/* ./vendor/` in the Dockerfile flattens the fonts into the gem layer — harmless duplicate files; touching the Dockerfile's layer order is outside this change.
  - `[low]` `[reject]` (intent) No test opens a page after a failed render — the page never reads the job's outcome: a missing row gives the text-only tags, which the first-open test asserts.
  - `[false]` `[reject]` (intent) AC6 "enqueued after commit" vs an enqueue from a GET — a GET has no transaction; the refresh's enqueue runs after commit (`enqueue_after_transaction_commit`).
  - `[low]` `[reject]` (intent) Renders are triggered by any card view, not only share links — as the Turbo-frame row above.
  - `[low]` `[reject]` (intent) A crawler's first visit to an unrendered card gets the text preview — as the backfill row above.
  - `[false]` `[reject]` (intent) AC7's old URL answers 404 rather than serving the new image — the page's next fetch points at the new token by design, so year-long caches never serve a stale image under one URL.
  - `[medium]` `[patch]` (intent) "Looks like the card" is not compared — same root cause as the composition pixel row; fixed there.
  - `[low]` `[patch]` (intent) Active Storage routes untested — same as the routing row; fixed there.
  - `[maybe-false]` `[reject]` (intent) The throttle is untested on Solid Cache — `unless_exist` is part of Solid Cache 1.0.10's `write_entry`; if wrong, only extra no-op jobs (low).
  - `[false]` `[reject]` (intent) The pending entry adds an unasked storage-volume item — informative for the author, not a defect.

## Design Notes

- Fingerprint: SHA-256 of the card view's fields (slug, title, publisher, year, season, rarity, art URL, number, genre), the locale and a render version; bumping the version re-renders every image lazily. A new token per render keeps year-long caches correct.
- Geometry: the xl card at 1.5× (360 × 540, art 327 × 336 from 109 × 112 art pixels, 32-colour palette where libvips quantises, plain pixels otherwise) left of a column with the title in VT323, the rarity in its colour and the card number.
- Page lookup: one query for the row's token and fingerprint; on a miss or a stale fingerprint, `Rails.cache.write(key, true, unless_exist: true, expires_in: 1.hour)` gates `CardShareImageJob.perform_later(card_season_id, locale)` (the cache and the queue are not the primary).
- Job: loads the view with `Catalog::CardViews` under `I18n.with_locale`, returns when the stored fingerprint already matches, fetches the art through a Faraday connection with a `class_attribute :adapter` (stubbed with empty test stubs in `test/test_helper.rb`, as `Steam::WebApi`), validates it like `placeholder.ts`, crops at the 42 % anchor, composes, stores; an unusable art or a render error is reported with `Rails.error.report` and stores nothing. Missing SVG or palette support in libvips degrades (no icon, no palette), never fails the render.
- Storage: the operation uploads the blob with `metadata: { analyzed: true, identified: true, width:, height: }` so no analyse job runs; replacing the attachment purges the old blob after commit.
- Image controller: includes `PublicRead`, `authorize :page, :show?`, skips `note_presence` so no session is written, `expires_in 1.year, public: true, immutable: true`, `send_data` inline as `image/png`. Its route sits outside `:locale`; build its path with `locale: nil`.
- Refresh: a web-layer subscriber on `Catalog::CardIdentityUpserted` enqueues the job for each stored image of that card whose fingerprint no longer matches (one indexed query; nothing when the card has none).
- Non-Latin titles fall back to the image's system fonts (DejaVu in the Debian image); CJK may show boxes.

## Verification

Work in `/home/teyermann/projets/gameble/.claude/worktrees/agent-a468fbd0dfce20ddf` (a git worktree) with absolute paths. Prefix every test, migration and rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_wimg CHROME_BIN=/usr/bin/chromium` (Postgres on 5433, up; `npm ci` done). Migration timestamps from today's clock (2026-10-30, after 093240). Do not commit. Use `/usr/bin/git` if a hook refuses a git command; never a shell variable in a command.

**Commands:**
- `bin/rails test test/controllers/card_preview_tags_test.rb test/controllers/share_images_controller_test.rb test/jobs/card_share_image_job_test.rb test/models/card_share_image_test.rb test/domains/catalog/store_share_image_test.rb` -- expected: green
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`, `bundle exec i18n-tasks missing`, `script/check_planning_references`, `script/check_file_sizes` -- expected: green
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && diff -u db/schema.rb tmp/migrated_schema.rb` -- expected: no diff after regenerating

## Auto Run Result

**Summary:** A shared card's page carries `og:image` and a large Twitter card once its 1200 × 630 PNG exists. `CardShareImageJob` composes the PNG with libvips: the xl card at 1.5× with its pixelated Steam art, rarity frame, VT323 and JetBrains Mono, beside a column with the title, rarity and number, in the link's language. `Catalog::StoreShareImage` stores it through Active Storage on the local disk, under a new token each time the fingerprint changes. `/share-images/<token>.png` serves it signed out with a year-long immutable cache and `noindex`. A GET only reads the row and, when it is missing or stale, enqueues the render (throttled through the cache). A card identity change re-enqueues its stored images.

**Files:**
- `db/migrate/20261030093934_create_active_storage_tables.active_storage.rb`, `db/migrate/20261030093935_create_catalog_share_images.rb`, `db/schema.rb`: Active Storage's tables and `catalog_share_images`.
- `config/application.rb`: Active Storage's routes are not drawn.
- `app/domains/catalog/app/{models,queries,operations,events}/catalog/*share_image*`: the row, its three queries, the store operation and its event.
- `app/models/card_share_image.rb`, `app/models/card_share_image/{art,composition,rarity_icon,refresh}.rb`: fingerprint, page lookup, art fetch, composition, rarity icon and the identity-change subscriber.
- `app/jobs/card_share_image_job.rb`: the render job.
- `app/controllers/share_images_controller.rb`, `config/routes.rb`: the token route.
- `app/controllers/cards_controller.rb`, `app/helpers/card_details_helper.rb`, `app/views/cards/{show,_share_tags}.html.erb`, `config/locales/{en,fr}.yml`: the tags and their alt text.
- `config/initializers/event_store.rb`: subscribes the refresh.
- `vendor/fonts/`: the TTF fonts and their OFL licences.
- Tests: `test/test_helper.rb`, `test/support/share_image_art.rb`, the new model, job, operation and controller tests, plus `card_preview_tags_test.rb` and `cards_controller_test.rb` (query counts up by one).
- `_bmad-output/initiative-gameble/pending-approvals.md`: the open entry.

**Review:** 43 findings.
- 12 rows patched, 7 root causes: failure hold-off, the fingerprint of the drawn words, the refresh outside the import's work, `noindex` on the image, the grey check at art size, control characters, and missing tests (routes, pixels, `NotStored`). By verdict: 6 medium and 6 low rows.
- 1 deferred: the Docker image's libvips is unverified, so a staging render check was added to the pending entry.
- The rest were rejected with the reasons in the triage log.

**Follow-up review:** recommended. Six medium rows were patched after the lenses ran: the hold-off, the fingerprint words, the refresh rewrite and the grey check moved to art size. These were checked only by the tests the patcher wrote and the full suite, not by a second review.

**Verification:**
- `bin/rails test`: 3662 runs, 0 failures.
- System tests `share_card_test.rb` and `card_detail_test.rb`: 20 runs, 0 failures.
- All clean: `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, brakeman (no warnings), `i18n-tasks missing`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`.
- The schema rebuilt from the migrations matches `db/schema.rb`.
- Sample renders were inspected by eye.

**Residual risks:**
- The production libvips is unverified (deferred).
- CJK titles may show boxes.
- A lost storage volume needs the rows cleared by hand.
- The image's colours are copied from `tokens.css`.
- Steam's terms and crawler reach await the author.
