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
