---
title: 'Hub and sign-in panel'
type: 'feature'
ticket: '2'
created: '2026-10-05'
status: 'built'
baseline_revision: '783c82acb7aa06d7fd974cfcb35198a2000e946b'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-space-terminal-redesign/story-shell-and-tokens-plan.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The home page is still the medieval attic (CSS room, lectern, chest, `SampleIsland` plaque, "Confrère" copy); Steam sign-in is reached from game-styled buttons posting to `/auth/steam` (attic chest, attic bonus, card page) and a sign-in returns to its origin page, all contradicting DESIGN.md/EXPERIENCE.md (hub "Pont de commandement", sign-in panel) and AD-14 (only Valve's image links to sign-in; signing in and out are full page loads landing on the hub).

**Approach:** Replace the attic with the hub (kicker, numbered menu 01–06, showcase or its empty state, daily booster panel, set progress; a signed-out variant with an invitation), add a sign-in panel (native `<dialog>` holding only its title line, the official image and ✕) that every account-needing call to action opens, land sign-in and sign-out on the hub, and rewrite the shell's, hub's and hub-toasted messages in "vous". Delete the attic page, styles, controller, its island and tests.

## Boundaries & Constraints

**Always:**
- DESIGN.md / EXPERIENCE.md (`_bmad-output/initiative-gameble/ux-gameble/`) win over mocks; mocks are look references only, never copied.
- AD-11: GET /:locale stays read-only (no write in the hub's queries). AD-15: no database id in HTML (sets by kind/key, cards by slug). AD-16: no `style` attribute in server HTML; behaviour in named Stimulus controllers (`dialog`, `hub-menu`…) that remove listeners on disconnect.
- AD-18: every string in both `config/locales/fr.yml` and `en.yml`, natural case (uppercase by CSS), French says "vous", never "tu"/"Confrère"/a title; no "!" ; numbers via `number_with_delimiter`.
- Tiers are read by integer (`Catalog::Rarity::TIERS`, `t("catalog.rarity.#{code}")` through TIERS); never hard-code `steel`…`gold` or `common`…`legendary` (story 8.3 renames them concurrently).
- Every focusable element keeps the 8.1 focus ring; phone targets ≥ 44px; no horizontal page scroll at 360 / 390 / 1400 px.
- Work only inside this worktree (`/home/teyermann/projets/gameble/.claude/worktrees/agent-a88b2abe81b5ee8df`), never in `/home/teyermann/projets/gameble` itself; never push or deploy; do not commit (the orchestrator commits).

**Never:**
- No community goal panel, LIVE ticker, planet, rays or glow (epic 6 / story 8.8 assets); leave their slots out, never fake content. No redesign of the daily booster panel beyond its position, copy and states listed here ("RÉCUPÉRÉ" + countdown is story 10.4: once collected the panel stays hidden, as today).
- No booster screen, no change to `PackReveal` behaviour, `CardComponent`, `Card.tsx`, tier code names, the reveal, library or profile screens (beyond the copy/prop renames listed). No CSP change.
- No link to `/auth/steam` other than `SteamSignInComponent` (Valve's image).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player hub, desktop | GET `/fr` signed in, packs available, an Épique+ pulled | h1 "Pont de commandement" + subtitle; menu 01–06 (01 posts `/packs` with a lime count badge, 02 links `library_path` with meta "owned/total", 03–06 `aria-disabled` "bientôt disponible"); showcase kicker "Dernière obtention", that card (`CardComponent` large), its title, rarity icon + name, secondary "Voir la fiche" → `card_path(slug)`; daily booster panel under the menu; "Progression des sets" with ≤ 4 set rows (link `library_set_path(kind:, key:)`) and "Tout voir" → `library_path` | — |
| No notable pull | player whose opened packs hold no tier ≥ 4 card of the published season | Empty showcase: "Ouvrez votre premier booster", "Votre plus belle carte s'affichera ici.", primary "Ouvrir un booster" (POST `/packs`); the daily panel's "Récupérer" becomes secondary | Reserve empty: that button disabled with "Réserve vide" written beside it |
| Reserve empty | player, 0 available | Menu 01 `aria-disabled`, badge "0" greyed, accessible text includes "Réserve vide"; the packs chip countdown on the hub refreshes the page by morph at zero (others keep `refresh: false`) | — |
| Daily panel | bonus collectable / reserve full / collected or no season | "Booster quotidien" + "Prêt" + "Un booster offert chaque jour. Il rejoint votre réserve." + "Récupérer" (POST `daily_bonus_path`) / "Réserve pleine" (orange) + "Ouvrez un booster pour récupérer celui du jour." + disabled "Récupérer" / panel absent | — |
| Signed-out hub | GET `/en` as a visitor | Same kicker and menu (01 opens the sign-in panel; 02 links the library); invitation in place of the showcase ("Vos jeux Steam, en cartes à collectionner." / "Ouvrez des boosters, complétez des sets, échangez avec vos amis." / primary "Ouvrir mes premiers boosters" opening the sign-in panel); no daily panel; set rows with 0 owned; top bar holds the official image | No published season: no set rows, no collection meta |
| Sign-in panel | activate any account-needing CTA (hub menu 01, invitation, card page invitation) | `<dialog id="sign-in-panel">` opens modal: title "Connectez-vous pour jouer", `SteamSignInComponent` (focused first), ✕ "Fermer"; ✕, Esc or a scrim click closes it and focus returns to the opener; page unchanged, still signed out | Without JS the CTA does nothing; the top bar image still signs in |
| Sign in | Steam callback success, any valid origin | Redirect to `home_path` in the origin's locale with the welcome toast; the hub focuses menu item 01 (phone: the h1) | Failure / refused callback: unchanged (back to the origin, alert) |
| Sign out | player menu "Se déconnecter" | Full page load (`data-turbo=false`), lands on the signed-out hub with the farewell toast | — |
| Phone | 390×844 and 360×740 | One column: kicker, showcase (or invitation), daily panel, set rows; menu hidden (tab bar navigates); no horizontal scroll; dialog shown as a bottom sheet | — |
| Menu keys | focus inside the menu, key 1–6 | Activates the matching enabled item (`aria-keyshortcuts`); no effect outside the menu or on a disabled item; returning to the hub after using an item focuses that item | Storage unavailable: no focus restore, no error |

</intent-contract>

## Code Map

- `app/views/pages/home.html.erb`, `app/controllers/pages_controller.rb` -- the attic view to replace; controller sets `@bank` (`Game::BankSummary`, reused by `ShellHelper#shell_bank`), `@next_pack_in`, `@season_published` (drop). Keep `turbo_exempts_page_from_cache` and `turbo_refreshes_with method: :morph, scroll: :preserve`.
- `app/frontend/styles/attic.css`, `app/frontend/controllers/attic_controller.ts`, `app/frontend/components/SampleIsland.tsx` (registered in `app/frontend/entrypoints/application.ts`, only mounted by the attic), `test/system/{attic,signed_out_attic,sample_island}_test.rb` -- delete; drop the `attic.css` import in `app/frontend/entrypoints/application.css` and add `hub.css`.
- `app/views/shell/{_top_bar,_packs_chip,_player_chip,_tab_bar}.html.erb`, `app/views/layouts/application.html.erb`, `app/helpers/shell_helper.rb`, `app/frontend/styles/shell.css`, `app/frontend/styles/tokens.css` (`--modal-scrim`, `--modal-width`, `--overlay-shadow`, `--space-menu-item-height` or its DESIGN equivalent) -- the 8.1 shell; reuse its tokens, `pixel_icon`, `PanelComponent(brackets:)`, `ButtonComponent`, `SteamSignInComponent`.
- `app/frontend/controllers/countdown_controller.ts` -- `refresh` value; the packs chip passes `refresh: true` only on the hub (`controller_path == "pages"`).
- `app/controllers/sessions_controller.rb` -- `create` redirects to `return_path`; make success go to `home_path` (locale from `requested_locale`), failure paths unchanged.
- `app/views/cards/show.html.erb:13-20` -- visitor invitation with a game-styled `/auth/steam` button: replace by a sign-in panel opener.
- `packs/game/app/queries/game/{collection_summary,set_progress,tier_counts}.rb` -- SQL/query patterns (Game may read Catalog tables, AD-2); `Catalog::PublishedSeason`, `Catalog::SetTotals`, `Catalog::CardViews`, `SetLabel.for`, `CardStrings.for`, `CardComponent.new(card:, strings:, size: :large)`. `game_packs.card_season_ids` is `bigint[]` in draw order, `opened_at` set once opened; `catalog_card_seasons.rarity` is the integer 1–5.
- `app/controllers/packs_controller.rb:51-55`, `app/views/packs/show.html.erb`, `app/frontend/components/PackReveal.tsx` -- `backToAttic`/`atticUrl`/`back_to_attic` to rename (`backToHub`/`hubUrl`/`back_to_hub`, "Retour au pont" / "Back to the bridge"); behaviour unchanged.
- Tests using the attic: `test/controllers/{pages,daily_bonuses,packs,card_preview_tags,sessions}_controller_test.rb`, `test/controllers/back_office/*` (test names only), `test/system/{countdown,daily_bonus,pack_reveal,library,card_preview,share_card,shell}_test.rb`; helpers in `test/application_system_test_case.rb` (`click_steam_sign_in` is scoped to `.top-bar`), `test/support/game_packs.rb` (`create_pack`).
- Comments mentioning the attic: `app/controllers/{daily_bonuses,packs,library}_controller.rb`, `config/routes.rb`, `lib/application_record.rb`, `app/frontend/controllers/countdown_controller.ts`.

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/queries/game/notable_pull.rb` (+ `test/packs/game/notable_pull_test.rb`) -- `Game::NotablePull.call(player)` → card-season id or nil: the player's most recently opened pack holding a card of tier ≥ 4 in the published season, its highest tier, first by draw position (one SQL with `unnest … WITH ORDINALITY`); nil for nil player / none.
- [x] `packs/game/app/queries/game/hub_sets.rb` (+ test) -- `Game::HubSets.call(player, season:, limit: 4)` → rows `(set, owned, total)` (`set` a `Catalog::Set`): sets the player has started, in progress before complete, then by owned/total desc, owned desc, id; filled up to `limit` with unstarted sets (tomes first, then by id) at 0. Read only the player's held rows plus totals of the chosen sets (no full-season aggregation); a nil player gets the fill only.
- [x] `packs/catalog/app/queries/catalog/card_count.rb` (+ test) -- cards of a season with a rarity (the "/16 480" of menu 02).
- [x] `app/controllers/pages_controller.rb` -- load `@season`, `@bank`/`@next_pack_in` (player), `@showcase` (`Catalog::CardView` or nil via `NotablePull` + `CardViews`), `@collection` (owned via `Game::CollectionSummary`, total via `Catalog::CardCount`; nil without season), `@sets` (`HubSets` rows labelled with `SetLabel.for`; empty without season).
- [x] `app/views/pages/home.html.erb` + partials under `app/views/pages/` (`_menu`, `_showcase`, `_invitation`, `_daily_booster`, `_set_progress`) -- the hub per the I/O matrix; menu as `<nav aria-label>` with an ordered list of `.menu-item` (number, label, badge or meta, arrow icon `arrow-small-right`), `aria-keyshortcuts` 1–6, current hub marker not needed; badge lime, greyed at zero; menu 03–06 `aria-disabled="true"` spans with visually hidden "bientôt disponible".
- [x] `app/frontend/styles/hub.css` -- grid per DESIGN Layout (≥1180: 340px | fluid | 340px with sets in the right column; 720–1179: left column 260–300px holding menu, daily panel and sets, showcase alone in the centre; <720: one column kicker, showcase/invitation, daily, sets, menu hidden); kicker (Silkscreen accent + VT323 subtitle), menu item (DESIGN Menu item: 50px rows, hover fill accent + 10px slide + arrow shown, pressed accent-press; motion off under reduced motion), showcase (kicker gold square, `card-xl` area, ground shadow bar, name in `--font-showcase-name`, empty state hatched frame with dashed card outline and dimmed logo), daily panel (quiet panel, state word colours), set rows (name, owned/total, a 6px bar drawn by a native `<progress value max aria-hidden>` styled with tokens, so no `style` attribute is needed), "Tout voir ▸" link style.
- [x] `app/views/shell/_sign_in_panel.html.erb` + `app/views/layouts/application.html.erb` -- rendered for visitors outside the back-office: `<dialog id="sign-in-panel" aria-labelledby>` with `PanelComponent(brackets: true)`, title row (accent, "Connectez-vous pour jouer"), square ✕ (`pixel_icon("close")`, name "Fermer"), `SteamSignInComponent.new(origin: request.path, autofocus: true)`; styles in `shell.css` (scrim `--modal-scrim`, width `--modal-width`, bottom sheet under 720px with a grab handle and top line).
- [x] `app/components/steam_sign_in_component.rb/.html.erb` -- optional `autofocus:` on the button. `app/components/button_component.rb/.html.erb` -- `opens: "sign-in-panel"` renders `<button type="button" aria-haspopup="dialog" data-controller="dialog-opener" data-action="dialog-opener#open" data-dialog-opener-dialog-value="…">`. Component tests for both.
- [x] `app/frontend/controllers/dialog_controller.ts`, `dialog_opener_controller.ts` -- opener calls the dialog's `showModal()` and records itself; dialog closes on ✕, Esc (native cancel) and a click on the backdrop (target is the dialog), returns focus to the opener on `close`, closes itself before Turbo caches (`turbo:before-cache`) and on disconnect.
- [x] `app/frontend/controllers/hub_menu_controller.ts` -- keys 1–6 (no modifier) inside the menu click the matching item unless `aria-disabled`; clicking an item stores its number in `sessionStorage` (try/catch); on connect (not a Turbo preview) focus the stored item once and clear it, or with `focus-first` value (set when `flash[:signed_in]`) focus item 01, or the h1 (`tabindex="-1"`) when the menu is hidden.
- [x] `app/views/shell/_packs_chip.html.erb` -- `refresh` true on the hub. `app/views/shell/_player_chip.html.erb` -- sign-out form `data-turbo=false`.
- [x] `app/controllers/sessions_controller.rb` -- success: `redirect_to home_path, notice: t(".welcome"), flash: { signed_in: true }`; comments updated.
- [x] `app/views/cards/show.html.erb` -- visitor invitation: copy-deck line + `ButtonComponent(opens: "sign-in-panel")` "Ouvrir mes premiers boosters".
- [x] `config/locales/fr.yml`, `en.yml` -- replace `pages.home.*` with the hub keys (kicker title/subtitle, menu labels and a11y strings, showcase, invitation, daily, sets); add `shell.sign_in_panel.{title,close}`; rewrite in "vous" (FR) / plain "you" (EN) every message the hub shows as a toast: `sessions.*`, `daily_bonuses.create.*` (collected = copy deck "Un booster rejoint votre réserve. Le prochain sera prêt à minuit (UTC)."), `packs.create.throttled`, `errors.game.{player_required,no_pack_available,already_collected,no_season}`, `authorization.*`, `rate_limit.throttled`, `errors.accounts.*`, `errors.steam.{invalid_claimed_id,sign_in_failed}`; `cards.show.{invitation,sign_in}`, `card_details.preview.description` (no attic); `packs.show.back_to_attic` → `back_to_hub`. Remove unused keys (`i18n-tasks unused` should not grow).
- [x] Deletions and renames listed in the Code Map; attic comments reworded.
- [x] Tests -- rewrite `pages_controller_test.rb` for every I/O row server-side (player, empty showcase, reserve empty, daily states, visitor, no season, sign-in panel only for visitors, the only `/auth/steam` forms are `.steam-sign-in`); `sessions_controller_test.rb` (success → hub in origin locale for any origin, failures unchanged); port the attic assertions of the other listed tests to the hub (menu 01 form, packs chip countdown, `.daily-booster`…); new `test/system/hub_test.rb` (desktop 1400, phones 390×844 and 360×740, signed in and out: no horizontal scroll, menu hidden on phone, sign-in panel opened from menu 01 and the invitation, closed by ✕ and Esc with focus back on the opener, menu key "2" opens the collection and returning focuses item 02, signing in lands on the hub with item 01 focused, signing out lands on the signed-out hub, screenshots); port `countdown_test.rb` to the hub's packs chip.

**Acceptance Criteria:**
- Given the repository, when searched case-insensitively for `attic` in `app/`, `config/`, `lib/`, `packs/` and `test/`, then nothing is found, and `SampleIsland` is gone.
- Given any page, when searched for forms posting to `/auth/steam`, then each is the `SteamSignInComponent` holding `sits_01.png`.
- Given `config/locales/fr.yml`, when the keys this story touches are read, then none says "tu", "toi", "ton", "ta", "tes" or "Confrère".
- Given all checks of the verification list, when run, then they pass.

## Implementation Notes

- The six attic files (`attic.css`, `attic_controller.ts`, `SampleIsland.tsx`, `test/system/{attic,signed_out_attic,sample_island}_test.rb`) were removed with `git rm` by the orchestrator (the implementing subagent's `rm` was refused by the permission classifier).
- `@next_pack_in` is no longer loaded: no hub view uses it; the packs chip computes its own countdown (`ShellHelper#shell_next_pack_in`).
- `hub_menu_controller.ts` reads the digit from `event.key` or the physical key (`event.code`, `Digit1`…`Numpad6`) and allows Shift, so AZERTY keyboards (digits on Shift) work; under test Chrome sent "2" as Shift+"@".
- When menu 01 is disabled (empty reserve), the focus after sign-in goes to the first enabled item (02).
- The empty showcase shows no "Dernière obtention" kicker; the English copy ("Command bridge", "Sign in to play", …) is new.
- `lib/dialog.ts` keeps the opener per dialog (WeakMap) so focus returns to it on close.
- Menu 02's count uses `Game::CollectionSummary`, which also computes complete sets over the season (one extra subquery per hub load).
- Verification (orchestrator, after the deletions): rubocop clean, packwerk validate/check clean, i18n-tasks missing none, typecheck clean, test:js 114 passed, `bin/rails test` 1111 runs 0 failures, `bin/rails test:system` 65 runs 0 failures; `grep -rniI attic app config lib packs test` empty. The implementing subagent saw `pack_reveal_test` fail intermittently in 2 of 4 full system runs (not reproduced here).

## Plan Change Log

## Review Triage Log

### 2026-10-05 — Review pass
- verdicts: 7 findings — high 0, medium 3, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A number left in sessionStorage beat the post-sign-in focus (`hub_menu_controller.ts` connect), so a visitor who used menu 02 then signed in from the library landed with item 02 focused, against EXPERIENCE.md "Return from Steam sign-in → the hub's first menu item" — fixed: the stored key is always consumed and `focus-first` always focuses item 01 (h1 on the phone); system test added.
  - `[low]` `[patch]` The `event.code` fallback accepted `Numpad1`–`Numpad6`, so numpad arrows with NumLock off opened menu items — fixed: the fallback reads `Digit1`–`Digit6` only.
  - `[low]` `[reject]` A refused POST /packs from menu 01 redirects to the hub as a morph refresh, so the stored "1" survives until a later hub visit focuses it — real but rare (a refusal needs a race or the throttle) and the fix adds a `turbo:morph` restore path; not worth the added branch.
  - `[medium]` `[patch]` `Game::NotablePull` unnested the player's whole pack history on every hub load and countdown refresh — fixed: a first query looks at the 50 latest opened packs only, the full query runs only when none qualifies; test for an older pull added.
  - `[medium]` `[patch]` The hub's collection meta ran `Game::CollectionSummary`, whose complete-sets subquery aggregates every set membership of the season, then discarded it — fixed: `Game::CollectionSummary.distinct_cards` runs only the distinct-card count (one query, tested).
  - `[low]` `[patch]` The sign-in panel had no opening motion (EXPERIENCE.md Motion: 160ms scrim, 220ms panel rising 16px) — fixed: backdrop fade, panel rise, bottom sheet slide on the phone, fade only under reduced motion.
  - `[low]` `[patch]` A hovered, keyboard-focused menu item lost the focus ring's gap (hover box-shadow out-specified `:focus-visible`) — fixed: a `:focus-visible:hover` rule keeps the gap.

## Design Notes

- Menu 01 for a player is the existing open-pack form (`button_to packs_path`, Turbo) styled as a menu item, not a link to a booster screen (none yet); deferred-work records it with the disabled 03–06 items.
- One lime action per view: menu badges are not buttons; the empty showcase's "Ouvrir un booster" is the primary, the daily "Récupérer" then turns secondary.
- Transitional choices to record in `_bmad-output/initiative-gameble/deferred-work.md`: menu 01 opens a pack directly; 03–06 disabled; no planet/rays/float under the showcase (story 8.8 assets, 8.6 effects); the showcase line lacks genre and number (8.3, 8.6); the phone hub shows no packs chip / rarity counter block (the top bar's chip stays); the collected daily panel stays hidden (10.4).
- Showcase pick example: packs opened at 10:00 [Rare, Épique(pos 2)] and 11:00 [Commune×5] → the 10:00 Épique.

## Verification

Run from the worktree root with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w82 CHROME_BIN=/usr/bin/chromium` (never the default test or development databases).

**Commands:**
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails test` -- 0 failures, 0 errors
- `bin/rails test:system` -- 0 failures, 0 errors
- `grep -rniI attic app config lib packs test` -- no output

**Manual checks (if no CLI):**
- View the hub system-test screenshots (desktop signed in / out, 390, 360, sign-in panel open): dark shell, menu, showcase or invitation, panel with the official image.

## Auto Run Result

- **Summary:** the attic is replaced by the hub "Pont de commandement": kicker (h1 + subtitle), numbered menu 01–06 (01 opens a booster or, signed out, the sign-in panel; 02 the collection with unique/total; 03–06 disabled until their screens exist; keys 1–6 inside the menu, last-used item refocused on return), the showcase of the latest Épique-or-better pull or its empty state, the daily booster panel (ready / full reserve; hidden once collected), "Progression des sets" (up to four rows and "Tout voir"); a signed-out variant with an invitation instead of the showcase and no daily panel. A sign-in panel (`<dialog>`, title line, Valve's image focused first, ✕, Esc and scrim close, focus back to the opener, bottom sheet on the phone) is opened by every account-needing call to action (hub menu 01, invitation, card page invitation). Sign-in lands on the hub (focusing menu 01), sign-out is a full page load landing on the signed-out hub. The packs chip countdown refreshes the hub by morph. Shell, hub and hub-toasted copy rewritten in "vous". Attic page, styles, controller, `SampleIsland` and their tests removed.
- **Files:** `app/views/pages/{home,_menu,_showcase,_invitation,_daily_booster,_set_progress}.html.erb` and `app/controllers/pages_controller.rb` (the hub); `app/frontend/styles/hub.css` (new) and `shell.css` (modal); `app/views/shell/_sign_in_panel.html.erb`, `layouts/application.html.erb`, `_packs_chip`, `_player_chip` (shell); `app/frontend/controllers/{dialog,dialog_opener,hub_menu}_controller.ts`, `lib/dialog.ts`; `app/components/{button,steam_sign_in}_component.*` (`opens:`, `autofocus:`); `app/controllers/sessions_controller.rb` (land on the hub); `packs/game/app/queries/game/{notable_pull,hub_sets,collection_summary}.rb`, `packs/catalog/app/queries/catalog/card_count.rb`; `app/views/cards/show.html.erb`, `packs/show`, `PackReveal.tsx` (hub renames); `config/locales/{fr,en}.yml`; attic files deleted; tests rewritten or ported (pages, sessions, daily bonus, packs, card preview tags, countdown, daily bonus, pack reveal, library, share card, shell, new hub system test and query tests).
- **Review:** quick lens, 7 findings: 6 patched (3 medium, 3 low), 0 deferred, 1 rejected (stale stored menu item after a refused open's morph: rare path, fix adds a branch).
- **Follow-up review:** recommended (`true`) — three medium findings were patched on this first pass. The specific unverified risk: the `NotablePull` two-step query and the hub's per-load query count are checked only by tests on small fixtures, never against a long pack history; and the hub menu's focus restore interacts with Turbo morph refreshes (countdown, refused opens) in ways only partly covered by system tests.
- **Verification:** `bin/rubocop` no offenses; `packwerk validate` and `check` clean; `i18n-tasks missing` none; `npm run typecheck` clean; `npm run test:js` 114 passed; `bin/rails test` 1113 runs, 0 failures; `bin/rails test:system` 66 runs, 0 failures (after the patches); `grep -rniI attic app config lib packs test` empty.
- **Residual risks:** the implementing subagent saw `test/system/pack_reveal_test.rb` fail intermittently (2 of 4 full system runs; never alone, never in the orchestrator's runs), cause unknown, recorded in deferred-work.md; the showcase card is the medieval face until story 8.6; a new player with no notable pull runs two showcase queries per hub load; the English copy is new and unreviewed.
