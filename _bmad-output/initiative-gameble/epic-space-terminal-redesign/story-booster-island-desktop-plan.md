---
title: 'Booster island, desktop'
type: 'feature'
ticket: '11'
created: '2026-10-06'
status: 'built'
baseline_revision: '0574a2640f0a1a2d7940f367d38b5e764a1a9658'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
warnings: [oversized]
deferred:
  - summary: >-
      BoosterErrorBoundary (the island's fallback when its chunk fails or it throws) has no test.
    evidence: |-
      No test references BoosterErrorBoundary; breaking getDerivedStateFromError or the reload link fails nothing. Recorded in deferred-work.md with a suggested CDP Network.setBlockedURLs system test.
    location: >-
      app/frontend/components/BoosterErrorBoundary.tsx
    severity: low
---

<intent-contract>

## Intent

**Problem:** Openings still go through the first direction's PackReveal (HTML form, redirect, wipe-and-flip with tier seals). Story 8.10 built AD-23's JSON exchange, but no client sends it, the hub has no booster screen, and the top bar's counters never move during a reveal.

**Approach:** Add the booster screen (`GET /:locale/booster`) holding a new `Booster` React island in its desktop mode: the canister sends the opening exchange and charges while it runs, then blows and deals the server faces face down under the pack's card back; one activation reveals a card; "Tout révéler", "Ouvrir le suivant", the live region, and `gameble:*` events update the top bar. Menu 01, the empty showcase, the packs chip and the BOOSTER tab lead there. PackReveal and everything only it used are removed; the pack page stays "mon dernier booster", face up.

## Boundaries & Constraints

**Always:**
- AD-16: faces only from the answer's server HTML (`faces.m`); the island draws the back, the flip and the choreography; no `style` attribute in server HTML (React's `style` prop for custom properties and WAAPI are fine, as tilt.ts does); the island talks to the chrome only through `gameble:*` events declared in `app/frontend/lib/events.ts`; no global store, no router.
- AD-23 / Opening protocol: one activation (canister click, Enter or Space on it, or "Ouvrir le booster") sends `POST` to `packs_path` with `Accept: application/json`, `Idempotency-Key` (a `crypto.randomUUID()`), `X-CSRF-Token` from `meta[name=csrf-token]` when present; the trigger locks until the answer. A key is kept and resent by the next activation after an unknown outcome (network failure, non-JSON answer, 5xx) or a 429 `throttled`; it is dropped after a success or any other refusal code. Refusal of any kind (envelope or not): the canister disarms without blowing, status back to SCELLÉ (reserve > 0) or EN ATTENTE (reserve 0, empty state), the reason inline under the open button and in a `gameble:toast` (tone alert) and in the live region; nothing is dealt. A non-envelope answer (Rails' HTML 422 for a stale CSRF token, a 500, a network error) shows the generic reason `boosters.island.failed`.
- AD-27: only `transform`/`opacity` animate (WAAPI `element.animate` or CSS keyframes); no rAF loop; infinite effects (canister breath, sweep, rays, back sheen, epic/legendary rays) are CSS animations stopped under reduced motion; timers and listeners removed on unmount; the countdown timer pauses while `document.hidden`. Reduced motion is read through `motionReduced()` (lib/motion.ts) at each step. The booster page is exempt from Turbo's cache. In-app back controls (top bar back button, island "Retour au pont", tab bar) are disabled from activation until the cards are dealt, and during each reveal; browser Back is never blocked.
- AD-18: every word comes from locale files (fr and en) through props; plural templates (`zero`/`one`/`other`, `%{n}`-style placeholders) read by one shared `t()`; numbers grouped by one shared helper with the locale's delimiter (`number.format.delimiter`: U+00A0 in fr, "," in en). Strings in natural case; uppercase by CSS.
- AD-25: the back image comes from the answer's `pack.cardBack` (CSS class per key, `standard` only, unknown key falls back to standard), art `app/frontend/images/pixel/back-standard-m.png` (80×120 art px shown at 160×240, `image-rendering: pixelated`).
- The daily bonus pack (3 cards) opens in the same island: counters, hints and the deal use the answer's card count.
- Timings: EXPERIENCE.md Motion; mock (key-screens.html, `openA`, `revealV3`, `legendV3`, `arcadeDeal`, `openRM`, `revealRM`) durations multiplied by 1.18, all in one pure module.

**Never:**
- No phone pile, tray, caption plate, card zoom or width rebuild (story 8.12): under 720px the same island and row (wrapping) must work, plainly.
- No change to the opening exchange's semantics (8.10) beyond adding per-card display fields; no new error code; no server endpoint besides the booster screen's GET.
- No canvas particle engine, no mock code copied; no rarity promise anywhere; no blinking LEDs (steady).
- Do not touch the collection, card detail (story 10.2, built in another worktree), profile or trade code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open | player, ≥1 available pack, activation | ARMEMENT, one POST with a new key; on 200: armed (orange), caps blow, cards dealt face down (standard back), focus card 1, status INVENTAIRE, reserve chip and pips show `bank.available` (bank-changed) | — |
| Reveal one | Enter/Space/click on a face-down card | rarity and game together; label under card shows tier; live region "Carte n : <label>. <Tier>."; top bar rarity counter +1 for that tier (tier-revealed, from `tierCountsBefore`); "Cartes révélées : n / N" | art not ready: flip waits for `.card__art[data-art]` (max 6 s) |
| Revealed card | activation ≥400 ms after its flip | Turbo visit to its card page (`card_path(slug)`) | <400 ms: ignored |
| Tout révéler | some face down | remaining in order, ~180 ms apart; a Légendaire plays its full sequence before the next; one summary in the live region; focus "Ouvrir le suivant" | input on cards ignored while it runs |
| Légendaire (motion) | legendary revealed | stage dims, status SIGNAL LÉGENDAIRE, live "Signal légendaire" at start, jump+charge, 1.5 spin, impact (rings, burst, rays, one flash, shake), banner "Légendaire !" with title · year, drop back; ≈2.45 s | reduced motion: crossfade + still banner 1.4 s |
| Next | all revealed, reserve > 0 | "Ouvrir le suivant": cards sink, canister docks, and the next opening starts (new key) | reserve 0: button reads "Réserve vide", disabled |
| Bonus pack | oldest available is a bonus pack | 3 cards dealt; "Cartes révélées : n / 3"; hints count 3 | — |
| Empty reserve | 0 available on load | canister replaced by "Réserve vide · Prochain booster dans …"; open button "Réserve vide" disabled; focus on the island's "Retour au pont" | — |
| Refused | 422 `no_pack_available` (reserve emptied elsewhere) | disarm, EN ATTENTE, empty state, inline reason + toast + live region; nothing dealt | key dropped |
| Throttled | 429 | disarm, SCELLÉ, reason inline + toast | key kept for the next activation |
| Lost answer | fetch rejects / non-JSON / 5xx | disarm, generic reason inline + toast | key kept: the next activation replays the same pack (server opens nothing more) |
| Stale CSRF | Rails 422 HTML | generic reason inline + toast; nothing opened | key kept |
| Visitor | GET /booster signed out | redirect to the hub with the sign-in alert (existing `refuse`) | — |
| No JS | island not mounted | server fallback: HTML form "Ouvrir le booster" (POST → pack page face up) and "Retour au pont" | — |

</intent-contract>

## Code Map

- `config/routes.rb` -- add `resource :booster, only: :show` inside the locale scope (`booster_path` → `/:locale/booster`).
- `app/controllers/boosters_controller.rb` (new) -- `show`: `authorize :booster, :show?`; `@bank = Game::BankSummary.call(current_player)` (keys `available`, `reserve_full`, `next_available_at`, `bonus_collectable`), `@season = Catalog::PublishedSeason.call` (`number`). GET runs read-only (AD-11).
- `app/policies/booster_policy.rb` (new) -- `show? = player?` (pattern: `pack_policy.rb`, `daily_bonus_policy.rb`).
- `app/helpers/boosters_helper.rb` (new) -- `booster_props(bank:, season:)`: `openUrl: packs_path`, `hubUrl: home_path`, `cardUrl: card_path(slug: "SLUG")` (island replaces `SLUG` with `encodeURIComponent(slug)`), `delimiter: t("number.format.delimiter")`, `bank: { available, reserveFull, nextAvailableAt (iso8601(3) or nil), serverTime }`, `packSize: Game::Pack::SIZE`, `rarityNames` (`catalog.rarity.*` by code name), `rarityIcons` (code name → `pixel_icon` HTML), `strings` (every `boosters.island.*` key; plural keys passed as their hash). Times via the same format as `PacksHelper#opening_time`.
- `app/views/boosters/show.html.erb` (new) -- `content_for :back_button, true`; `content_for :screen_title` (`boosters.show.title`); `content_for :booster_top_bar, true`; `turbo_exempts_page_from_cache`; `turbo_mount("Booster", props: booster_props(...), class: "booster-island")` followed by a server fallback (`.booster__fallback`: the form button `ButtonComponent.new(href: packs_path, method: :post)` when `available > 0`, and "Retour au pont"), hidden by CSS once the island renders (`.booster-island:has(.booster) + .booster__fallback { display: none }`, the pattern of the old reveal).
- `app/views/shell/_top_bar.html.erb` -- when `content_for?(:booster_top_bar)`: rarity counter + `shell/reserve_chip` (static "n en réserve") instead of the packs chip. Add `data-controller="navigation-lock"` on `.top-bar__start` (it holds only the back button and the title): the controller locks every `a[href], button` inside its element (ButtonComponent takes no data option).
- `app/views/shell/_reserve_chip.html.erb` (new) -- `.packs-chip.packs-chip--static` with the canister icon, the count (`data-reserve-chip-target="count"`), label `shell.packs.in_reserve` (plural); `data-controller="reserve-chip"` and `data-reserve-chip-delimiter-value`.
- `app/views/shell/_packs_chip.html.erb` -- becomes a link to `booster_path` (keep its content, countdown and classes; `data: { turbo_prefetch: false }`); update its header comment.
- `app/views/shell/_rarity_counter.html.erb` -- `data-controller="rarity-counter"`, `data-rarity-counter-delimiter-value`; each count span (button and legend) gets `data-rarity-counter-target="count"` and `data-tier="<code name>"` (TIERS maps integer → code).
- `app/views/shell/_tab_bar.html.erb` -- BOOSTER tab links to `booster_path` (current when `controller_path == "boosters"`); `data-controller="navigation-lock"` on the nav (locks every tab link inside).
- `app/views/pages/_menu.html.erb` -- menu 01 for a player: a link to `booster_path` (same classes, badge, `aria-keyshortcuts`, `hub-menu#remember`, `turbo_prefetch: false`), badge greyed at zero (`menu-item__badge--zero`, add CSS in `hub.css`); visitor branch unchanged. Update the header comment.
- `app/views/pages/_showcase.html.erb` -- empty showcase's "Ouvrir un booster": `ButtonComponent.new(href: booster_path)` (link) when available > 0; disabled branch unchanged.
- `app/controllers/packs_controller.rb` -- HTML branch: open and `redirect_to pack_path(token)` (no `flash[:reveal]`); `show`: drop `@reveal`/`no_store`/`@strings` if unused; update the class comment (the booster island sends the JSON; the form is the no-JS fallback).
- `app/views/packs/show.html.erb` -- only the face-up branch; "open next" becomes a link to `booster_path` (label `packs.show.open_booster`, new key) when a pack is available.
- `app/helpers/packs_helper.rb` -- delete `pack_reveal_props`; keep `pack_faces`, `REVEAL_SIZES` (rename comment); `pack_opening_json` cards gain `title`, `year`, `label` (spoken text: `t("boosters.island.card_label", title:, details:)` where details = publisher, year, genre label (`SetLabel.genre(card.genre)`) compacted and joined with ", "; without details just the title).
- `app/frontend/entrypoints/application.ts` -- replace the PackReveal registration by `Booster` (lazy + Suspense + a `BoosterErrorBoundary` whose fallback is a short message and a reload link, strings from props).
- `app/frontend/lib/events.ts` -- add `"gameble:tier-revealed": { tier: Rarity; counts: Record<Rarity, number> }`, `"gameble:bank-changed": { available: number; reserveFull: boolean; nextAvailableAt: string | null; serverTime: string }`, `"gameble:navigation-locked": { locked: boolean }`.
- `app/frontend/lib/i18n.ts` (new) -- `type Template = string | { zero?: string; one?: string; other: string }`; `t(template, vars)`: picks `zero` when `count === 0` and present, `one` when `count === 1`, else `other` (the app's I18n default rule, used by both locales here), interpolates `%{name}`; `formatNumber(n, delimiter)`.
- `app/frontend/lib/booster.ts` (new, pure) -- `TIME_SCALE = 1.18`, every duration (Design Notes), `dealOrder(count)` (centre out: 5 → [2,1,3,0,4], 3 → [1,0,2]), `planRevealAll(tiers, revealed)`, `keyAfter(outcome, key)`, `countsAfterReveal(counts, tier)`, `revealSummary(tiers, strings)`, `formatClock(seconds)` ("H:MM:SS" from an hour, else "MM:SS"), `burstPixels` (port from lib/reveal.ts, counts per tier), `secondsUntil(nextAvailableAt, serverTime)`.
- `app/frontend/lib/opening.ts` (new) -- `sendOpening({ url, key, csrfToken, fetch })` → `{ kind: "opened", answer } | { kind: "refused", code, message } | { kind: "failed" }`, types of the answer (8.10 Design Notes shape + card `title`, `year`, `label`).
- `app/frontend/components/Booster.tsx`, `BoosterCanister.tsx`, `BoosterCard.tsx`, `BoosterErrorBoundary.tsx` (new) -- the island (Design Notes).
- `app/frontend/controllers/rarity_counter_controller.ts`, `reserve_chip_controller.ts`, `navigation_lock_controller.ts` (new) -- listen with `onGameble`, remove on disconnect.
- `app/frontend/styles/booster.css` (new), imported from `app/frontend/entrypoints/application.css` in place of `reveal.css`; `shell.css` -- packs chip as a link (no underline, focus ring, hover), `.packs-chip--static`, rarity count brighten (`[data-changed]`), locked controls (`[aria-disabled]` 40 % opacity, `cursor: not-allowed`).
- Remove: `app/frontend/components/PackReveal.tsx`, `RevealCard.tsx`, `RevealErrorBoundary.tsx`, `app/frontend/lib/reveal.ts`, `reveal.test.ts`, `app/frontend/styles/reveal.css`, `app/frontend/images/card/` (old backs and seal sprite, used only by the reveal), `script/card_art/` (broken generator of those files), the `assetsInlineLimit` rule in `vite.config.ts`, `test/system/pack_reveal_test.rb`, `CardStrings#to_props` and `lib/card_types.ts`'s `CardStrings` type if nothing else uses them (keep `Rarity`), and the locale keys only the reveal used (candidates `packs.show.flip_all|next|previous|progress|all_flipped|failed|reload|open_next_pack`: remove each one `rg` finds no use of once the reveal is gone).
- Locales `config/locales/{fr,en}.yml` -- new `boosters.show.title` ("Ouverture de booster" / "Booster opening"), `boosters.island.*` (see Design Notes, Copy), `shell.packs.in_reserve` (one/other "%{number} en réserve" / "%{number} in reserve"), `packs.show.open_booster`.
- Mock reference only (never source): `_bmad-output/initiative-gameble/ux-gameble/mockups/key-screens.html` lines 349-404 (canister and card CSS), 1005-1060 (booster markup), 1754-2000 (choreography).
- Test helpers: `test/support/game_packs.rb` (`create_pack`, `fixture_tier_ids`), `test/application_system_test_case.rb` (`click_steam_sign_in`, `SCREEN_SIZE`), `test/support/card_baselines.rb`, fixtures `catalog_card_seasons(:common_card_one|uncommon_card_one|rare_card_one|portal_one(epic)|legendary_card_one)` (titles "Tin Soldier", "Green Hills", "Blue Depths", "Portal", "Golden Crown").

## Tasks & Acceptance

**Execution:**
- [x] `config/routes.rb`, `app/controllers/boosters_controller.rb`, `app/policies/booster_policy.rb`, `app/helpers/boosters_helper.rb`, `app/views/boosters/show.html.erb` -- the booster screen and its props -- R5, AD-16, AD-27.
- [x] `app/views/shell/*` (top bar, reserve chip, packs chip link, rarity counter, tab bar), `app/views/pages/_menu.html.erb`, `_showcase.html.erb`, `app/frontend/styles/hub.css`, `shell.css` -- entries to the screen, the booster top bar, controller hooks.
- [x] `app/frontend/lib/{events,i18n,booster,opening}.ts` + `*.test.ts` -- typed events, `t()`/numbers, pure timing and rules, the exchange -- AD-18, AD-23.
- [x] `app/frontend/components/Booster*.tsx`, `app/frontend/entrypoints/application.ts`, `app/frontend/styles/booster.css`, `application.css` -- the island.
- [x] `app/frontend/controllers/{rarity_counter,reserve_chip,navigation_lock}_controller.ts` -- the chrome's side of the events.
- [x] `app/controllers/packs_controller.rb`, `app/views/packs/show.html.erb`, `app/helpers/packs_helper.rb` -- face-up only, card display fields in the answer.
- [x] Removals listed in the Code Map; `config/locales/{fr,en}.yml` keys added and removed.
- [x] Tests: `test/system/booster_test.rb` (new; reduced motion emulated except the Légendaire test, as `pack_reveal_test.rb` did with `Emulation.setEmulatedMedia`) covering every matrix row except Visitor/No JS (controller tests) -- the lost answer by wrapping `window.fetch` so its first call rejects after the server answered (assert two requests with the same `Idempotency-Key`, one opened pack); stale CSRF by `ActionController::Base.allow_forgery_protection = true` set after sign-in and restored in `ensure`/teardown, with the page's `meta[name=csrf-token]` content overwritten; refusal by opening the only pack in the database after the page loaded; navigation lock (top bar back button `aria-disabled` while the opening runs, enabled after); phone viewport 390×844 opens and reveals; hub menu 01 and packs chip lead to the screen. `test/controllers/boosters_controller_test.rb` (new): visitor redirected with the alert; player gets the island with props (bank, strings, no database id), the booster top bar (rarity counter + reserve chip, no packs chip link), no `[style]` in the HTML, the Turbo no-cache meta, the fallback form. Update `packs_controller_test.rb` (HTML flow lands face up, no island; JSON card keys now `slug tier coverUrl title year label faces`), `daily_bonuses_controller_test.rb`, `pages_controller_test.rb`, `hub_test.rb`, `shell_test.rb` where they assert the form, the reveal or the chip's tag. `test/system/card_face_visual_test.rb`: the revealed case goes through the booster at `m` only (desktop), screenshotting the dealt slot; rewrite `test/fixtures/files/card_faces/revealed-m.png` with `UPDATE_CARD_BASELINES=1` after checking the image by eye; delete `revealed-xl.png` (the phone booster returns in 8.12).
- [x] `_bmad-output/initiative-gameble/deferred-work.md` -- mark resolved: the menu 01 transitional entry, the `script/card_art/generate.mjs` entry, the CSRF entry (handled client side as any error), the RevealErrorBoundary test entry, the pack_reveal_test flakiness entry; add entries for anything deferred here (at least: `card-s` deal under 900px, the phone mode 8.12).

**Acceptance Criteria:**
- Given a signed-in player on the hub with packs, when they choose menu 01 (or the packs chip, or the BOOSTER tab), then the booster screen shows the canister, the information panel (kicker, title, CARTES PAR BOOSTER, EN RÉSERVE, ÉTAT SCELLÉ, pips, "+1 dans …" or "Réserve pleine", actions, "Cartes révélées : — / 5") and the top bar's rarity counter and "n en réserve" chip.
- Given dealt cards, when each is revealed by click or Enter, then the top bar's count for its tier rises by one at that reveal and not before, and the live region says the card.
- Given any refusal, when the answer arrives, then no card is dealt, the canister is back at rest, and the reason shows inline and in a toast.
- Given the full suite, when run, then the checks in Verification pass and no file references PackReveal, RevealCard, `lib/reveal`, `images/card/` or the `dusty` state.

## Implementation Notes

Built in two runs (the first was cut off; the second inspected its uncommitted work against every Code Map item, kept it and finished it).

Decisions:
- The navigation lock marks each locked control `aria-disabled="true"` plus `data-navigation-locked` (shell.css styles the latter at 40 % opacity, `cursor: not-allowed`), and swallows clicks in the capture phase; controls already disabled are left alone and restored as they were. The island's own "Retour au pont" follows the same lock.
- `canister_label_plain` ("Ouvrir le booster, grand catalogue, %{count} cartes") added beside `canister_label` for a page without a published season, as `kicker_plain` is.
- `boosters.island.*` is passed whole (`t("boosters.island")`), so `config/i18n-tasks.yml` ignores it for `unused`.
- Menu 01 for a player is always the link (greyed `menu-item__badge--zero` at 0, never `aria-disabled`): the booster screen itself states an empty reserve.
- The revealed card's sheen loop (`.booster-card__back::after`) stops once the card is revealed: it is turned away, and the card-face visual test needs the slot still.
- `countdown_test.rb`'s "refresh waits for a submission" now submits the daily booster's "Récupérer" (the hub's only POST form left); the countdown controller's comment says so.
- `.vitest/` is Vitest's output directory (the JSON reporter, which the RTK proxy turns on, writes `.vitest/json/output.json`; attachments and blobs go there too): gitignored and the stray file deleted.

Files touched (beyond the Code Map): `config/i18n-tasks.yml`, `.gitignore`, `app/components/card_strings.rb` (`to_props` and the face-down labels removed; `rarity_name` kept for the card links), `app/frontend/controllers/countdown_controller.ts` (comment), `test/components/card_component_test.rb`, `test/integration/shell_test.rb`, `test/system/{hub,shell,countdown,card_face_visual}_test.rb`, `test/fixtures/files/card_faces/revealed-m.png` (rewritten through the booster, checked by eye: same face as before, tilted), `revealed-xl.png` deleted, `_bmad-output/initiative-gameble/deferred-work.md`.

Surprises:
- The old `cards.face_down*` keys were used only by `CardStrings#to_props`; removed with it.
- `bin/rails test` refuses `-n` (Minitest 6): use `-i`.
- The screenshots showed an Épique's and a Légendaire's rays painted over the next cards (later siblings in the row): dealt cards now sit at `z-index: 1` and Épique/Légendaire slots at 0, so rays pass behind the neighbours (a running Légendaire still rises to 6, above the dim).

Verification (second run): `node script/pixel_art/export.mjs --check` (82 files up to date), `bin/rubocop` (no offenses), `packwerk validate` and `check` (clean), `i18n-tasks missing` (none; `unused` clean too), `npm run typecheck` and Vitest (137 tests) pass, `bin/rails db:test:prepare test` 1194 runs, 0 failures; `bin/rails test:system` 77 runs, 0 failures (no flaky rerun needed), then `booster_test.rb` and `card_face_visual_test.rb` again after the last CSS change, 17 runs, 0 failures; the removals `rg` finds nothing. Manual: headless Chromium screenshots at 1400×900 (rest, dealt, Légendaire impact, revealed, complete) and 1000×900 (info above the stage) under `tmp/screenshots/booster-*.png`: the canister assembled from its three parts and pixelated, no sideways overflow.

Review follow-ups (after the first report):
- The countdown reaching zero while the screen shows (clock > 0 at the previous tick) refreshes the page a second later (`Turbo.visit(location.href, { action: "replace" })`, else `location.reload()`), only while the island is idle (phase sealed or empty, no lock, no opening, no reveal); a clock already at 0 when the page drew never refreshes. New system test "an empty reserve whose next booster arrives while the screen shows" (passed 3 runs of 3 alone).
- `reveal()` takes the navigation lock, and for a Légendaire the hold (`legendaryRunning`), before the art wait; the reduced-motion path clears the hold after its still banner.
- A revealed card's activation is ignored while the navigation is locked, an opening runs or Tout révéler runs.
- A `no_pack_available` refusal sets `reserveFull: false` with `available: 0`.
- The cards' rays loop only once revealed (`.booster-card[data-revealed] .booster-card__rays`); the reduced-motion rules match that selector.
- French `boosters.island.reserve_count` gains `zero` ("0 booster"); no other island plural renders 0.
- `lib/booster.ts` header: the RM_* durations are EXPERIENCE.md's own, unscaled.
- Tests added: no published season (`boosters_controller_test.rb`), the genre in the spoken label (`packs_controller_test.rb`, Portal in an action tome: "Portal — Valve, 2007, Action"), the reserve chip at 0 after a refusal (`booster_test.rb`).

## Plan Change Log

## Review Triage Log

### 2026-10-06 — Review pass
- verdicts: 39 findings — high 0, medium 4, low 26, false 9, maybe-false 0
- findings:
  - `[low]` `[patch]` (intent-alignment) RM_* durations are not ×1.18 although the intent names openRM/revealRM — the values are EXPERIENCE.md's explicit reduced-motion exceptions (200, 240/40, 220, 1.4 s, also the matrix's 1.4 s), so behaviour is right; the `lib/booster.ts` header comment wrongly claimed them scaled: comment corrected.
  - `[low]` `[reject]` (intent-alignment) durations also live outside the timing module (inline `scaled(...)` effect durations in Booster.tsx, CSS loop durations, CHANGED_MS) — inline values still go through `scaled()`, CSS loops are ambient not mock timings; moving them is churn with no user-visible effect.
  - `[low]` `[reject]` (intent-alignment) the arming squash runs ARM_MS then holds its pose rather than "charging" for the whole request — status ARMEMENT and the held pose last the whole request, as the plan's "await both" design says; nobody meets a difference.
  - `[medium]` `[patch]` (intent-alignment) `reveal()` locks navigation only after the art wait (up to 6 s) — grouped with edge-case "Légendaire hold after art wait" and blind "reveal stalls 6 s unlocked": `lock()` and the Légendaire hold now taken before `artReady`; the reduced-motion Légendaire path now holds and clears it too.
  - `[false]` `[reject]` (intent-alignment) client-created burst/ring spans set `element.style.*`, outside the intent's style exception — the constraint is "no `style` attribute in server HTML"; these are client CSSOM writes on transient decorative spans (CSP-safe), and server HTML has none (tested).
  - `[false]` `[reject]` (intent-alignment) after Tout révéler the focus goes to "Retour au pont" at reserve 0 — the plan's Design Notes and EXPERIENCE's focus rule say exactly that (the open button is disabled then).
  - `[false]` `[reject]` (intent-alignment) menu 01 at zero is a live link with a greyed badge while the empty showcase stays disabled — the Code Map specifies both; the screen itself shows the empty state.
  - `[low]` `[reject]` (intent-alignment) before the answer the canister label and "— / 5" use the regular pack size even when the next pack is a 3-card bonus — grouped with blind/edge-case pack-size findings below.
  - `[false]` `[reject]` (intent-alignment) `card_strings.rb` edited near the collection/card-detail boundary — only `face_down`/`to_props`, used by PackReveal alone, were removed as the Code Map asks; 10.2's worktree does not touch the file.
  - `[low]` `[reject]` (intent-alignment) motion paths (common–epic tremble/flip, sink/dock, AD-27 rules, countdown pause) not exercised by tests — the Légendaire motion path has a system test, the rest is visual choreography checked by manual screenshots; adding motion assertions would be brittle timing tests.
  - `[low]` `[defer]` (verification-gap) BoosterErrorBoundary has no test — already recorded in deferred-work.md with a suggested CDP `Network.setBlockedURLs` test.
  - `[low]` `[patch]` (verification-gap) the no-published-season branch of the booster screen is untested — added a BoostersControllerTest case with season 1 unpublished (200, `season` nil, plain strings, fallback).
  - `[low]` `[patch]` (verification-gap) the genre part of the spoken card label never runs (no fixture card has a genre) — the daily-bonus JSON test now puts Portal in an action tome and asserts "Portal — Valve, 2007, Action".
  - `[low]` `[patch]` (verification-gap) the reserve chip is not checked after a no_pack_available refusal — the refusal system test now asserts the chip reads 0.
  - `[medium]` `[patch]` (blind) the countdown reaching zero changes nothing: "Réserve vide · 00:00" with a disabled button until a manual reload — grouped with edge-case same finding: one second after the clock goes from >0 to 0 with the island idle (sealed or empty, nothing running), the page refreshes in place (Turbo replace visit), as the hub's countdown does; never at mount at 0; new system test.
  - `[low]` `[reject]` (blind) the pack size shown before the answer is wrong for a bonus pack (canister name "5 cartes", "— / 5") — real when the reserve is empty and the daily bonus is the only pack; the intent fixes the bonus pack's counts to the answer's card count, and showing the next pack's size needs a new bank field across the game pack boundary; noted in deferred-work.md for 8.12.
  - `[low]` `[reject]` (blind) RESERVE_PIPS = 10 duplicates BANK_SIZE and hides a reserve above 10 — DESIGN.md fixes ten pips with "Réserve pleine" at ≥10; the count row shows the exact number.
  - `[low]` `[reject]` (blind) `sendOpening` has no timeout, a hung request keeps the lock — browsers end hung connections and Browser Back is never blocked; adding an abort deadline is new state for a rare case.
  - `[low]` `[reject]` (blind) a 429 ignores Retry-After and the canister is re-activatable at once — the reason is shown inline and in a toast, and a retry only meets the same throttle; disabling on Retry-After is new state.
  - `[low]` `[reject]` (blind) sign_in_required / stale CSRF offer only a retry — grouped with edge-case sign_in_required: the server's message says to sign in, the generic message says to reload, and "Retour au pont" stays usable; no data is lost.
  - `[low]` `[reject]` (blind) nothing on the booster screen links to "mon dernier booster" — not in the intent; the cards are in the collection and the pack page stays reachable from its own entries.
  - `[low]` `[patch]` (blind) `.booster-card__rays` spins (infinite) on face-down Épique/Légendaire cards at opacity 0, against AD-27's loop budget — the spin now runs only on revealed cards; reduced-motion overrides kept.
  - `[low]` `[reject]` (blind) the island's strings have no contract with the locale files (`boosters.island.*` ignored for unused; a missing key would crash) — `ignore_unused` does not affect `i18n-tasks missing`, which keeps fr/en in parity, and the controller test asserts every key reaches the props; `card_label` riding along is harmless.
  - `[low]` `[patch]` (blind) French shows "0 boosters" in the empty state — fr `reserve_count` gains `zero: "%{n} booster"`, as other French plurals in fr.yml do; no other island plural renders 0.
  - `[low]` `[reject]` (blind) BoosterErrorBoundary reports nothing (no componentDidCatch, no frontend error reporting) — the app has no client error reporting anywhere (pre-existing); the boundary's job is the fallback.
  - `[low]` `[patch]` (blind) a reveal can stall silently for up to 6 s, unlocked, during the art wait — grouped with the lock-before-art-wait patch above.
  - `[false]` `[reject]` (blind) `slotRefs` is hard-coded to 8 slots — packs hold 5 (regular, reward) or 3 (bonus) cards (Game::Pack::SIZE/BONUS_SIZE); no pack reaches 8.
  - `[low]` `[reject]` (blind) `isAnswer` checks too little of the answer — the answer is the app's own server JSON, contract-tested in packs_controller_test; a deeper validator adds code for no reachable case.
  - `[low]` `[reject]` (blind) the reserve chip's label is built with `number: ""` and trim — works for both locales' templates; only a hypothetical mid-sentence translation breaks it.
  - `[false]` `[reject]` (blind) the French island copy uses "vous" and drops "Confrère", unlike the old pack page — EXPERIENCE.md requires "vous", never "tu", no title; the old "tu" copy predates the spines.
  - `[medium]` `[patch]` (edge-case) a Légendaire waiting for its art lets another card or Tout révéler run during its sequence — grouped with the lock-before-art-wait patch above.
  - `[low]` `[patch]` (edge-case) a no_pack_available refusal with reserveFull true leaves "Réserve pleine" next to 0 boosters — the refusal now sets `reserveFull: false` too.
  - `[low]` `[patch]` (edge-case) a revealed card navigates to its page while another reveal, Tout révéler or an opening runs (lock on) — activation of a revealed card is now ignored while anything holds the lock, opens, or reveals all.
  - `[low]` `[reject]` (edge-case) canister label and counter say 5 for a bonus pack before the deal — grouped with the blind pack-size finding (rejected, noted for 8.12).
  - `[low]` `[reject]` (edge-case) sign_in_required leaves the canister sealed with no route to sign in — grouped with the blind retry-only finding.
  - `[false]` `[reject]` (edge-case) more than 8 cards get no slot ref — grouped with blind slotRefs: no pack holds more than 5.
  - `[false]` `[reject]` (edge-case, claim) "any refusal → canister back at rest" but no_pack_available shows the empty state — the intent's matrix row for that refusal says "EN ATTENTE, empty state".
  - `[false]` `[reject]` (edge-case, claim) the rarity counter writes `tierCountsBefore + n` over the page-load count and may jump by more than one — the intent asks for counts from `tierCountsBefore` (the server's truth at opening); a jump only corrects a count that was stale.
  - `[medium]` `[patch]` (edge-case) countdown at zero leaves "Réserve vide · 00:00" forever — grouped with the blind countdown finding above (refresh at zero).

## Design Notes

**Layout** (DESIGN.md Booster, Layout): `.booster` grid `300px minmax(0,1fr)`, gap 32px; under 1260px one column, the info column becomes a wrapping row above the stage and the title 26px. Info column: hazard stripe, kicker `Booster · Saison %{number}` (season from props; without one, "Booster"), title "Grand catalogue" (`--font-hero`), bracketed panel (rows CARTES PAR BOOSTER `packSize`, EN RÉSERVE `n boosters`, ÉTAT with an 8px steady status light: accent at rest, alert when arming/ejecting, gold for SIGNAL LÉGENDAIRE, lime for INVENTAIRE COMPLET), RÉSERVE head with "+1 dans <clock>" (aria-hidden clock; visually hidden "Prochain booster à HH:MM (UTC)") or "Réserve pleine" at ≥10, ten 10px pips (lit = min(available, 10)), actions (primary "Ouvrir le booster" / "Ouvrir le suivant" / "Réserve vide"; secondary "Tout révéler"; secondary "Retour au pont" link), the inline reason line (`role="alert"` not needed: the live region speaks it; plain text, alert colour), counter "Cartes révélées : n / N" ("—" before a deal). Stage (min-height ≈ 520px, `position: relative`, one grid cell holding the canister zone and the deal row on top of each other): canister zone centred (rays behind, 200×300 canister, hint "Cliquez pour ouvrir" below; empty state line instead when reserve 0); result head "Résultat du booster" between hazard stripes; deal row (`ol`, flex, centred, wrap, gap `var(--space-deal-gap-max)`, dropping to `var(--space-deal-gap-min)` under 1260px); hint line under the row; banner (aria-hidden); flash overlay; dim overlay.

**Canister** (`BoosterCanister.tsx`): a flat `<button class="booster-canister">` (accessible name `boosters.island.canister_label` "Ouvrir le booster Saison %{season}, grand catalogue, %{count} cartes") holding plain layers: `__idle` (breath 2px / 6s, CSS) › `__move` (WAAPI squash) › `__body` (bg `canister-body.png` 200×220 at top 40px), `__cap--top` (bg `canister-cap-top.png`, 200×40, top 0, one LED), `__cap--bottom` (bg `canister-cap-bottom.png`, top 260px); DOM layers on the body: label lines ("Saison %{n}" / "Grand catalogue", Silkscreen/Pixelify, `--color-on-accent`), hazard band (`repeating-linear-gradient(-45deg, accent 0 6px, panel-sunken 6px 12px)`, alert colour when `[data-armed]`), three LEDs (steady accent, alert when armed), sweep band (CSS, transform), rays element behind (CSS rotate, steps). All PNGs `image-rendering: pixelated`, `background-size: 100% 100%`. While busy it carries `aria-disabled="true"` and ignores activation (not `disabled`, so focus stays on it).

**Opening sequence** (motion): activation → lock, `navigation-locked {locked:true}`, status ARMEMENT, squash keyframes (mock `openA` first `kanim`) for `ARM_MS` while the request runs (await both). Success → `[data-armed]`, status ÉJECTION, caps fly (top: translate(-60,-300) rotate(-230deg) → (-76,-360,-290) opacity 0; bottom mirrored) `CAPS_MS`, body pop/fade `BODY_MS`, rays fade, a ring + 12–16 pixel sparks + 6 smoke puffs (spans, transform/opacity), stage flash (opacity .35 peak, `FLASH_MS`) and shake (`SHAKE_MS`, 8 steps decaying 5px); after `HEAD_DELAY` show the result head and deal: each slot's travel layer animates from the canister centre (measured with `getBoundingClientRect` of zone and slot) along the mock `arcadeDeal` keyframes (offsets .42/.7/.86) for `DEAL_MS`, `DEAL_STAGGER` apart in `dealOrder`, landing shake 1.5px. Then canister zone hidden, status INVENTAIRE, unlock, focus card 1 (`preventScroll`). Reduced motion: canister fades out `RM_CANISTER_FADE`, cards fade in `RM_CARD_FADE` `RM_FADE_STAGGER` apart.
The faces are inserted on the answer (slots present but `opacity: 0` until dealt) so their art starts loading at once. `bank-changed` is dispatched with the answer's bank as soon as it arrives.

**Card slot** (`BoosterCard.tsx`, EXPERIENCE Implementation notes, 3D stack): `li.booster-card[data-tier][data-revealed][data-revealed-at]` › `__travel` (deal WAAPI) › `__hover` (CSS lift 8px on hover/focus of the hit button while face down, via `:has()`) › `__lift` (`perspective: 1000px`; reveal WAAPI translate/rotate/scale) › `__flip` (`transform-style: preserve-3d`; class `is-up` = `rotateY(180deg)`; WAAPI spins) › `__back` (back image, `backface-visibility: hidden`, outline, sheen `::after` CSS) and `__front` (`rotateY(180deg)`, `backface-visibility: hidden`, the face HTML via `dangerouslySetInnerHTML` memoised so React never rewrites it). No grouping property (opacity < 1, filter, overflow, clip-path, mask, blend, isolation) on `__flip` or `__front`/`__back`'s ancestors between lift and faces (opacity crossfades go on `__lift` or `__travel`). A flat transparent `button.booster-card__hit` covers the slot (z-index above): face down its name is "Carte %{position} sur %{total}, face cachée. Révéler."; revealed it is "<label>, <Tier>. Voir la fiche." and gets `pointer-events: none` so the pointer reaches the face's own tilt (`.card` tilt controller), the slot's `onClick` catching clicks on the face. Rays (epic purple, legendary gold, CSS rotate) and a static blurred gold glow (legendary) sit in `__lift` behind `__flip`, shown once revealed (not under reduced motion for rays). Holo/foil of a face-down card are stopped (`.booster-card:not([data-revealed]) .card__holo, .card__foil { animation: none }`). Label under the card: "? ? ?" in `--color-line`, then the outlined rarity icon and the tier name in the tier colour (Légendaire with " !"). The icons come in props: `rarityIcons` maps each code name to `pixel_icon("rarity-<n>", class: "booster-card__label-icon")` HTML (decorative, `aria-hidden` already), inserted with `dangerouslySetInnerHTML`.

**Reveal** (one path for a single activation and Tout révéler): guard (busy, already revealed, opening running) → await art (`.card__art[data-art]` in the front, poll 50ms, cap `ART_WAIT_MAX = 6000`) → lock navigation → motion per tier t (0 common … 3 epic): tremble `TREMBLE[t]` (0/90/170/280 ×1.18) with lift `L[t]` (0/8/16/26 px; common: 70ms lift of 4px), flip `rotateY 0→200→172→180` over `(300+40t)×1.18`, mark revealed at 42 % of the flip (label, name, live region unless Tout révéler, counts → `tier-revealed`), pixel burst in tier colours (`burstPixels`), rings (0/1/1/2), epic: shake + small banner "Épique"; settle `(380+60t)×1.18`. Légendaire: `legendV3` (Intent matrix), stage `[data-legendary]` dims the others, status SIGNAL LÉGENDAIRE, live "Signal légendaire" at start (even in Tout révéler), mark at spin + 90ms, impact hold 760ms, banner large "Légendaire !" + "<title> · <year>", status back to INVENTAIRE, drop with bounce 380ms; one flash only. Reduced motion: `is-up` set, `__lift` opacity .2→1 over 220ms; Légendaire: still banner 1.4s. Then unlock; when all are revealed: status INVENTAIRE COMPLET, hint "Booster inventorié · +N cartes dans la collection", focus "Ouvrir le suivant" (or "Retour au pont" when reserve 0). Set `data-revealed-at` (performance.now() at mark) for tests.

**Tout révéler**: `planRevealAll` → for each face-down card in order start its reveal; await it fully if legendary, else wait `REVEAL_ALL_GAP = 180`; then await all; announce `revealSummary` once ("%{count} cartes révélées : Légendaire × 1, Commune × 2." built from templates); button disabled while running and once all revealed.

**Next**: retract (cards sink 80px and fade, 160ms, 22ms stagger; RM instant), dock a new canister (rise 220px→0, 260ms), status SCELLÉ, then run the opening with a new key.

**Live region**: a dedicated `role="status" aria-live="polite"` visually hidden list, a new node per message (keep the last 5), as PackReveal did. Opening refusals are announced there too.

**Copy** (`boosters.island.*`, fr / en; uppercase by CSS): `kicker` "Booster · Saison %{number}" / "Booster · Season %{number}", `kicker_plain` "Booster", `title` "Grand catalogue" / "Grand catalogue", `cards_per_pack` "Cartes par booster" / "Cards per booster", `in_reserve` "En réserve" / "In reserve", `reserve_count` one "%{n} booster" other "%{n} boosters", `state` "État" / "State", states `sealed` "Scellé"/"Sealed", `arming` "Armement"/"Arming", `ejecting` "Éjection"/"Ejection", `inventory` "Inventaire"/"Inventory", `legendary_signal` "Signal légendaire"/"Legendary signal", `complete` "Inventaire complet"/"Inventory complete", `waiting` "En attente"/"Waiting"; `reserve` "Réserve"/"Reserve", `next_in` "+1 dans"/"+1 in", `next_at` "Prochain booster à %{time} (UTC)", `reserve_full` "Réserve pleine"/"Reserve full", `open` "Ouvrir le booster"/"Open the booster", `open_next` "Ouvrir le suivant"/"Open the next one", `reserve_empty` "Réserve vide"/"Reserve empty", `empty_next` "Prochain booster dans %{time}"/"Next booster in %{time}", `reveal_all` "Tout révéler"/"Reveal all", `back` "Retour au pont"/"Back to the bridge", `revealed_count` "Cartes révélées : %{revealed} / %{total}"/"Cards revealed: %{revealed} / %{total}", `canister_label`, `canister_hint` "Cliquez pour ouvrir"/"Click to open", `canister_season` "Saison %{number}", `result` "Résultat du booster"/"Booster result", `hint_remaining` one/other "Cliquez une carte pour la révéler · %{n} restante(s)", `hint_done` one/other "Booster inventorié · +%{n} carte(s) dans la collection", `face_down` "Carte %{position} sur %{total}, face cachée. Révéler."/"Card %{position} of %{total}, face down. Reveal.", `face_up` "%{card}, %{rarity}. Voir la fiche."/"%{card}, %{rarity}. See the card.", `card_label` "%{title} — %{details}", `announce_card` "Carte %{position} : %{card}. %{rarity}."/"Card %{position}: %{card}. %{rarity}.", `summary` one/other "%{n} carte révélée : %{tiers}." / "%{n} cartes révélées : %{tiers}.", `summary_tier` "%{rarity} × %{n}", `legendary_banner` "%{rarity} !"/"%{rarity}!", `banner_line` "%{title} · %{year}", `refused_title` "Ouverture annulée"/"Opening cancelled", `failed` "L'ouverture n'a pas abouti. Vérifiez votre connexion ou rechargez la page, puis réessayez."/"The opening did not go through. Check your connection or reload the page, then try again.", `island_failed` "Le booster n'a pas pu s'afficher. Vos cartes sont dans votre collection."/…, `reload` "Recharger"/"Reload". Server refusal messages come from the envelope's `message`.

**Timings** (`lib/booster.ts`, ms, already ×1.18 where from the mock): ARM 378, CAPS 732, BODY 177, FLASH 201, SHAKE 354, HEAD_DELAY 71, DEAL 543, DEAL_STAGGER 53, reveal per tier from the bases above, LEGENDARY JUMP 614, SPIN 661, MARK_IN_SPIN 106, IMPACT 897 (from 420×1.18 into the spin), DROP 448, REVEAL_GUARD 400, REVEAL_ALL_GAP 180, SINK 160, SINK_STAGGER 22, DOCK 260, RM_CANISTER_FADE 200, RM_CARD_FADE 240, RM_FADE_STAGGER 40, RM_REVEAL_FADE 220, RM_LEGENDARY_STILL 1400, ART_WAIT_MAX 6000. Export a `scaled(base)` helper and test that the constants equal `Math.round(base × 1.18)`.

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- exit 0
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails db:test:prepare test` -- 0 failures, 0 errors
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- 0 failures, 0 errors (known flaky: tome_test, shell_test phone toasts: rerun alone and record)
- `rg -n "PackReveal|RevealCard|lib/reveal|images/card/|dusty" app test script config vite.config.ts` -- no match

**Manual checks:**
- Headless Chromium screenshots of the booster screen at 1400×900 (rest, dealt, a revealed Légendaire) and 1000×900 (info above the stage): the canister assembled from its three parts, pixelated, no layout overflow; save under `tmp/screenshots/` and look at them.

## Auto Run Result

**Summary.** The booster screen (`GET /:locale/booster`) with the `Booster` React island in its desktop mode replaces PackReveal: the canister sends the AD-23 opening exchange (JSON, Idempotency-Key kept after an unknown outcome or a 429, dropped otherwise; CSRF header; Rails' HTML 422 read as a generic failure), charges, blows and deals the server faces face down under the standard back; one activation reveals a card (tier choreography, Légendaire sequence, reduced-motion crossfades); "Tout révéler", "Ouvrir le suivant", the live region and the `gameble:tier-revealed` / `bank-changed` / `navigation-locked` events drive the top bar's rarity counter, a static reserve chip and the navigation lock. Menu 01, the empty showcase, the packs chip and the BOOSTER tab lead to the screen; the pack page stays "mon dernier booster", face up; the no-JS fallback is the HTML form. This run resumed a cut-off build: most code was present; the implementer finished the test updates (shell, hub, countdown, card face visual + `revealed-m.png`), two CSS fixes, the i18n-tasks ignore, `.vitest/` ignore and deferred-work entries.

**Files changed** (main ones):
- `config/routes.rb`, `app/controllers/boosters_controller.rb`, `app/policies/booster_policy.rb`, `app/helpers/boosters_helper.rb`, `app/views/boosters/show.html.erb` — the booster screen and its props.
- `app/frontend/components/Booster*.tsx`, `app/frontend/styles/booster.css`, `app/frontend/entrypoints/application.{ts,css}` — the island.
- `app/frontend/lib/{booster,opening,i18n,events}.ts` (+ tests) — timings/rules, the exchange, `t()`/numbers, typed events.
- `app/frontend/controllers/{rarity_counter,reserve_chip,navigation_lock}_controller.ts`, `app/views/shell/*`, `app/views/pages/_{menu,showcase}.html.erb`, `hub.css`, `shell.css` — chrome side and entries.
- `app/controllers/packs_controller.rb`, `app/helpers/packs_helper.rb`, `app/views/packs/show.html.erb` — face-up pack page; answer cards gain `title`, `year`, `label`.
- Removed: PackReveal, RevealCard, RevealErrorBoundary, `lib/reveal.ts`, `reveal.css`, `images/card/*`, `script/card_art/`, `pack_reveal_test.rb`, `revealed-xl.png`, `CardStrings#to_props`.
- Locales fr/en, `config/i18n-tasks.yml`, `.gitignore`, tests (`booster_test.rb`, `boosters_controller_test.rb`, packs/pages/daily bonus/shell/hub/countdown/card face visual), `deferred-work.md`.

**Review** (thorough; 4 lenses, 39 findings: medium 4, low 26, false 9).
- Patched (10 fixes): countdown reaching zero refreshes the idle screen (medium); reveal takes the navigation lock and the Légendaire hold before the art wait, reduced-motion Légendaire holds too (medium, 3 grouped findings); a revealed card does not navigate while the lock/opening/Tout révéler runs (low); no_pack_available refusal clears `reserveFull` (low); rays spin only once revealed (low); French `zero` form for `reserve_count` (low); `lib/booster.ts` header comment on RM durations (low); tests for the no-season screen, the genre in the spoken label, the reserve chip after a refusal (low ×3).
- Deferred: BoosterErrorBoundary has no test (low; in deferred-work.md).
- Rejected (low, not worth the added state/surface, or settled by the intent/design): pre-answer pack size for a bonus pack (noted in deferred-work.md), durations outside the module, fixed arming squash, untested motion paths, ten pips, no fetch timeout, Retry-After, retry-only recovery for sign_in_required / stale CSRF (×2), no link to the last pack, i18n key contract, no client error reporting, `isAnswer` depth, reserve chip label trim. False: client span `style`, focus at reserve 0, menu 01 live at zero, card_strings edit, slotRefs 8 (×2), French "vous" voice, refusal empty state claim, counter from `tierCountsBefore`.

**Follow-up review recommendation: true.** Patched by verdict: medium 2 entries (countdown refresh; reveal lock/Légendaire hold reorder), low 8. Unverified risk: no test asserts the navigation lock or the Légendaire hold during a slow art wait (the reorder is only covered indirectly by the existing lock and Tout révéler tests), and the refresh-at-zero is covered for the empty reserve only, not for a sealed canister counting down.

**Verification** (after the patches): `node script/pixel_art/export.mjs --check` ok; `bin/rubocop` no offenses; packwerk validate + check clean; `i18n-tasks missing` none; typecheck ok; Vitest 137 passed; `bin/rails db:test:prepare test` 1195 runs 0 failures; `bin/rails test:system` 78 runs — clean on 4 full runs; one run had 1 error (BoosterTest refusal setup found the hub already signed in) and a seeded rerun had 2 ShellTest daily-bonus toast failures, each passing 3/3 alone (recorded in deferred-work.md); a further run had 1 error not reproduced with its seed. The removals search finds nothing. Manual screenshots at 1400×900 and 1000×900 checked by the implementer (`tmp/screenshots/booster-*.png`).

**Residual risks.** The intermittent system-test failures above; `revealed-m.png` captured with Manjaro's Chromium (existing deferred entry about CI's Chrome); phone mode and `card-s` deal deferred to 8.12; rarity readable in DevTools before reveal (by AD-16's design).
