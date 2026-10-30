# Review: reality check of the 2026-10-30 amendment (release 1.1.0: AD-35 to AD-39, AD-4, AD-15, AD-17 and AD-21 amended)

Independent reviewer, 2026-10-30. Lens: was every technical claim the amendment commits to checked against reality, or asserted from memory? Scope: the working-tree diff of `architecture-gameble.md` against its 2026-10-27 state (the scratchpad `architecture-1.1.0.diff`). The spine was not edited.

Read: `Gemfile`, `Gemfile.lock`, `Dockerfile`, `.dockerignore`, `config/storage.yml`, `config/recurring.yml`, `config/queue.yml`, `config/queue_import.yml`, `config/deploy.yml`, `config/deploy.production.yml`, `config/environments/production.rb`, `config/application.rb`, `db/schema.rb`, `app/domains/steam/app/clients/steam/web_api.rb`, and the HEAD commit `46a61856` (*a shared card's link previews with a generated image of the card*), which landed three minutes before the amendment: `app/jobs/card_share_image_job.rb`, `app/models/card_share_image{,/art,/composition}.rb`, `app/controllers/share_images_controller.rb`, `app/views/cards/_share_tags.html.erb`, `db/migrate/20261030093935_create_catalog_share_images.rb`, its tests and its `pending-approvals.md` entry.

Probes: the RubyGems API (aws-sdk-s3, ruby-vips, solid_queue) on 2026-10-30, and a throwaway `docker run ruby:4.0.7-slim` container (the Dockerfile's base) with Debian's libvips installed, checked with `vips --vips-config` and test renders.

**Verdict: pass with fixes.** The external facts mostly hold. The 100,000-calls-a-day quota is Valve's own wording. GetOwnedGames exists and honours game-details privacy. aws-sdk-s3 1.237.0, ruby-vips 2.3.0 and Solid Queue 1.7.0 are current. The image's libvips (8.16.1, Debian trixie) has text, fontfile, imagequant, cgif and spng. Recurring schedules and one-worker queues work as assumed. The problem is AD-39 and AD-21: they describe a design that is not the one shipped in HEAD. The amendment commits the project to S3 and aws-sdk-s3, but neither is in the code. It also names a job, a route and a staleness model that the commit implemented differently. Four smaller external points are missing: a GetOwnedGames parameter that drops games, PNG's palette depth limit, the checksum defaults of aws-sdk-s3 against S3-compatible stores, and an image byte budget for WhatsApp.

---

## Findings

### F1 — AD-39 and AD-21 contradict the shipped code (high)

HEAD `46a61856` built the share image before this amendment was written, and the two disagree:

| Spine (amendment) | Shipped code |
| --- | --- |
| `Catalog::RenderShareImageJob` | `CardShareImageJob` in `app/jobs`, with the render in `app/models/card_share_image/` (web layer); `Catalog` holds only the row, `Catalog::StoreShareImage` and three queries |
| Row "with the cover URL and title it was rendered from" | Row with `token` and `fingerprint` (SHA-256 of `RENDER_VERSION`, the locale, the whole card view and the drawn words); no cover or title columns |
| "served by a route under the card-season's slug, season and locale" | `GET /share-images/:token.png`, outside the locale scope, `Cache-Control: public, max-age=31536000, immutable`, `X-Robots-Tag: noindex`, no session cookie |
| Re-render when an import or AD-19 changes cover or title | The card page compares fingerprints and enqueues at most once an hour (`Rails.cache` throttle); a failure holds off for a day; an identity change re-renders stale rows |
| AD-21: "Files go to the author's S3-compatible object storage … Only AD-39's share images are stored there"; Stack: aws-sdk-s3 1.237.0 | `config.active_storage.service = :local` in production, the `gameble_storage:/rails/storage` volume (`config/deploy.yml`), no aws-sdk-s3 in `Gemfile`/`Gemfile.lock`, no S3 entry in `config/storage.yml` (only the commented generator example) |

`pending-approvals.md` (Open) already notes the cost of the local disk: a lost volume leaves tags that point at missing files until `RENDER_VERSION` is bumped.

The brief's premise "Active Storage tables not yet installed" is also out of date. `db/schema.rb` now has `active_storage_blobs`, `_attachments` and `_variant_records`, from HEAD's migration. The commit also sets `config.active_storage.draw_routes = false`. That matches the Rails guide (it stops blobs being served through the built-in public controllers, whose URLs carry signed blob ids) and AD-15, but the spine does not record it.

**Fix:** decide which way it goes, then make spine and code agree:
- **(a) The spine follows the code.** Rename the job to `CardShareImageJob` (web layer, `app/jobs`, since it reads `Catalog` views and I18n). Replace "cover URL and title" with "a fingerprint of the card view and render version". Name the route `/share-images/<token>.png`. Record `draw_routes = false`. Change AD-21 to "Active Storage on the local disk service, on the `gameble_storage` volume, backed up with the host", drop the aws-sdk-s3 row, and move S3 to Deferred ("when a second web host or a lost volume is a real risk").
- **(b) S3 is the target.** Keep AD-21, but mark it as not built and add the missing pieces to the rule: `gem "aws-sdk-s3", require: false`; a `storage.yml` S3 entry with `endpoint`, `region`, `bucket`, credentials from ENV and, for most self-hosted stores, `force_path_style: true` (passed through: `S3Service#initialize(bucket:, upload: {}, public: false, **options)` hands `**options` to `Aws::S3::Resource.new`); the secrets in `env.secret` of `config/deploy.yml`; `production.rb` switched to it; the story that migrates existing blobs. See F3 before choosing a store.

Sources: Rails guide https://edgeguides.rubyonrails.org/active_storage_overview.html (S3 service, `endpoint`, `draw_routes`); `S3Service` source https://github.com/rails/rails/blob/v8.1.0/activestorage/lib/active_storage/service/s3_service.rb.

### F2 — GetOwnedGames: `skip_unvetted_apps` and the free-game flags are not in the rule (medium)

Verified: `IPlayerService/GetOwnedGames/v1` exists and takes `key`, `steamid`, `include_appinfo`, `include_played_free_games` and `appids_filter`. It returns games "if their owned games/game details are visible to you", so a private profile or private game details produces an empty answer. Community reports show `{"response":{}}` sometimes coming back for public profiles too. AD-36's rule (an empty answer is never an empty library, `Failure(:library_unavailable)`, keep the last list) is therefore right.

Not in the rule:
- Games that Steam flags as profile-limited or "unvetted" are left out unless `skip_unvetted_apps=false` is sent. The fix was confirmed in a June 2024 thread (Street Fighter 6, Air Twister). Some popular catalog games would quietly be missing from the library set.
- Free-to-play games show up only with `include_played_free_games=true`, and only if they have been played. The set would miss free catalog cards otherwise.
- `include_appinfo` is not needed: the sync maps appids through `source_key`. Sending `false` keeps the answer small.

**Fix:** add to AD-36: "called with `include_played_free_games=true`, `skip_unvetted_apps=false`, `include_appinfo=false`; a played free game counts as owned, an unplayed one does not." Add it to the story's acceptance criteria as well.

Sources: https://partner.steamgames.com/doc/webapi/IPlayerService (GetOwnedGames); https://steamcommunity.com/discussions/forum/1/4333105935814636670 (`skip_unvetted_apps=false`); https://github.com/TeemoCell/SteamWebAPI/wiki/Profile-Privacy and https://developer.valvesoftware.com/wiki/Steam_Web_API/Feedback (empty `response` for private and, at times, public profiles; community sources).

### F3 — aws-sdk-s3's checksum defaults break several S3-compatible stores (medium, only if F1 goes the S3 way)

aws-sdk-s3 1.237.0 is current (RubyGems, 2026-10-30). Since aws-sdk-s3 1.178 (early 2025; Discourse's mitigation is a pin to 1.177.0), the Ruby SDK defaults to `request_checksum_calculation: "when_supported"` and `response_checksum_validation: "when_supported"`. It now sends CRC32 checksum headers and trailers that several S3-compatible servers reject, among them Ceph RGW, older MinIO, Garage, NetApp ONTAP and some versions of Backblaze and R2. Discourse's pin to 1.177 and GitLab Runner's change are the public cases. The amendment does not name the store ("the author's S3-compatible object storage"), so whether it is affected cannot be checked.

**Fix:** if S3 is chosen, add to AD-21: "the S3 service sets `request_checksum_calculation: when_required` and `response_checksum_validation: when_required` unless the store is verified to accept the SDK's default checksums". Both are `Aws::S3::Client` options and pass through `storage.yml`, or the `AWS_REQUEST_CHECKSUM_CALCULATION`/`AWS_RESPONSE_CHECKSUM_VALIDATION` env vars. Also add an upload-and-download smoke test against the real bucket on staging to `pending-approvals.md`.

Sources: https://rubygems.org/api/v1/versions/aws-sdk-s3/latest.json; aws-sdk-core checksum plugin https://sources.debian.org/src/ruby-aws-sdk-core/3.242.0-1/lib/aws-sdk-core/plugins/checksum_algorithm.rb; https://docs.aws.amazon.com/sdkref/latest/guide/feature-dataintegrity.html; https://meta.discourse.org/t/cant-rebuild-due-to-aws-sdk-gem-bump-and-new-aws-data-integrity-protections/354217; https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/6691.

### F4 — "reduced to 32 colours without dithering" cannot be done by pngsave; the shipped code goes through gifsave (low, wording)

Probed in `ruby:4.0.7-slim` (Debian 13 trixie) with Debian's libvips 8.16.1-1+deb13u2. `vips --vips-config` reports "text rendering with pangocairo: true, font file support with fontconfig: true, PNG load/save with spng: true, image quantisation with imagequant: true, GIF save with cgif: true". The Dockerfile's `apt-get install --no-install-recommends libvips` pulls these through `libvips42t64`'s hard dependencies (`libpangoft2-1.0-0`, `libfontconfig1`, `libimagequant0`, `libcgif0`, `libspng0`). `fonts-dejavu-core` comes along with fontconfig, and `.dockerignore` does not exclude `vendor/fonts`, so the vendored VT323 and JetBrains Mono TTFs reach the image.

Test renders:
- `resize --kernel nearest`: works.
- `text --fontfile … --font "DejaVu Sans 30" --dpi 72`: works.
- `pngsave palette, bitdepth=8, dither=0`: works, but PNG only takes bit depths 1, 2, 4, 8 and 16.
- `pngsave palette, bitdepth=5`: fails with "invalid bit depth", so PNG output cannot cap the palette at 32. The old `colours` option is no longer exposed in 8.16.
- `gifsave bitdepth=5, dither=0`: works. `CardShareImage::Art#quantise` uses exactly this (a gifsave round-trip, then `extract_band(0, n: 3)`), and the test asserts at most 32 colours.

libvips quantises with libimagequant, not `pixelcrush`'s median cut, so the art's palette is close to the card's but not the same. "As on the card" is approximate.

The pending-approvals entry says the render "has run only against the development and CI builds of libvips, never inside the Docker image". The probe above confirms the image's libvips has every feature the render uses; the staging check is still worth doing for the fonts.

**Fix:** AD-39 wording: "pixelated as on the card (nearest neighbour) and quantised by libvips (libimagequant) to 32 colours without dithering, through a GIF palette, since PNG palettes take 2, 4, 16 or 256 colours". Optionally add "libvips' text, fontfile and imagequant support are required in the image" next to the ruby-vips Stack row.

Sources: https://packages.debian.org/trixie/libvips42t64; libvips `pngsave` docs https://www.libvips.org/API/current/method.Image.pngsave.html; container probe above.

### F5 — Preview image byte budget and crawler details (low)

Verified:
- X: `summary_large_image` needs an absolute URL; JPG, PNG, WEBP or the first frame of a GIF; under 5 MB. 1200 × 630 is within the commonly cited minimum of 300 × 157 and the ~2:1 to 1:1 ratio (third-party guides; X's own page returns 402 to automated fetches).
- Twitterbot obeys `robots.txt` (already in `pending-approvals.md`).
- Cloudflare caches `.png` by default, honours `public, max-age>0`, and does not cache a response with `Set-Cookie`. The shipped controller skips the session, so this works.
- The shipped tags are correct: absolute URL through `public_url_for`, `og:image:type`, `:width`, `:height`, `:alt`, `twitter:card summary_large_image`, `twitter:image`.

Not verified, and missing from the rule:
- WhatsApp has no official page that sets an image size limit. Third parties report about 300 KB in practice (Wix, Branch) and some cite 600 KB. Above the limit, WhatsApp shows a small thumbnail or no preview.
- The shipped `pngsave_buffer(compression: 9, strip: true)` writes a truecolour PNG of anti-aliased text, gradients and frame, and no test bounds its size.
- Discord publishes no unfurl spec. It is known to read `og:*` and `twitter:card summary_large_image`, but that is unverified.

**Fix:** add to AD-39: "the PNG stays under 300 KB". Add a test that asserts the bytesize of a worst-case render (long title, busy cover). If it fails, save the final canvas with `palette: true` (8-bit, 256 colours: the art is already 32 and the frame is flat) instead of truecolour.

Sources: https://developer.x.com/en/docs/x-for-websites/cards/overview/summary-card-with-large-image; https://developers.cloudflare.com/cache/concepts/default-cache-behavior/; https://help.branch.io/faq/docs/why-are-some-quick-link-thumbnails-not-shown-in-whatsapp; https://support.wix.com/en/article/wix-editor-recommended-ogimage-size.

### F6 — The "throttled queue" needs a worker entry, and must not use `limits_concurrency` (low)

Verified: Solid Queue 1.7.0 is current. Recurring tasks are `class` (or `command`) plus `schedule`, parsed by Fugit ("every day at 4am" is already used by `apply_retention`). Solid Queue has no rate limiting per time window: its README advises "relying on a limited number of workers per queue instead". `limits_concurrency` caps jobs running at once, not calls per period. It is also a Solid Queue extension called in job code, which AD-12 forbids ("No code calls Solid Queue … directly").

The project's `config/queue.yml` lists queues by name (`[ default ]`) because Solid Queue cannot exclude one. A new queue with no worker entry never runs.

**Fix:** AD-36 should say where the queue runs. Either:
- add it after `import` in `config/queue_import.yml` (`queues: [ import, steam_library ]`, one thread). All Steam calls are then serialised in one process, and queues are polled in order, so the library sync runs only while the import is idle; or
- add a separate one-thread worker for it in `config/queue.yml`.

Pacing between calls (Steam answers 429 to bursts, which `WebApi` already retries) then comes from that single thread.

The daily cap ("stops for the day at a configured number of calls") needs a counter shared by all processes (`Rails.cache.increment` on a per-day key fits AD-12). Note that sign-in's `GetPlayerSummaries` spends the same key's quota.

Sources: https://github.com/rails/solid_queue/blob/main/README.md (recurring tasks, concurrency controls, queue order); https://rubygems.org/api/v1/versions/solid_queue/latest.json.

### F7 — Valve's terms: disclosure of the stored library (low)

The quota is primary-sourced: "You are limited to one hundred thousand (100,000) calls to the Steam Web API per day". The same terms say: "You will only retrieve Steam Data about a Steam end user as requested by the end user". A daily background sync is defensible once the player opts in by creating the set. The terms also require telling end users which Steam Data is stored, and storing it in the countries the privacy policy names. AD-14 adds the library to the export and the deletion, but no rule names the privacy page, as AD-34 does for the email hash.

**Fix:** add to AD-36: "the privacy page names the Steam library list, its daily refresh, and that it is kept only while the library set exists".

Source: https://steamcommunity.com/dev/apiterms.

---

## What holds

- **Daily quota:** 100,000 calls a day, quoted from Valve's Steam Web API Terms of Use (above). No other rate limit is published.
- **GetOwnedGames:** listed in the current Steamworks reference and served from `api.steampowered.com` like the import's other calls. The key comes from `Rails.configuration.x.steam.api_key` (`STEAM_API_KEY`), as AD-36 says.
- **ruby-vips 2.3.0:** latest on RubyGems, matches `Gemfile.lock`. The `image_processing` 2.2.0 gem is also locked.
- **libvips in the image:** 8.16.1 with every feature the render uses (F4 probe).
- **Active Storage on Rails 8.1.4:** tables migrated; S3 service options pass through to the AWS client; `endpoint` documented; private by default (the bucket "stays private" is the default).
- **Solid Queue 1.7.0:** recurring syntax and per-queue workers as the spine assumes, with the caveats of F6.
- **Open Graph / X tags:** the shipped tags meet the published requirements; 1200 × 630 PNG is accepted by X, Facebook-family and Discord crawlers.
