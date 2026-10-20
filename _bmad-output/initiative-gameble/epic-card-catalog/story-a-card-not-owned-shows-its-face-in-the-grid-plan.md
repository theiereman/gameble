---
title: 'A card not owned shows its face in the grid'
type: 'feature'
ticket: 2
created: '2026-10-20'
status: 'built'
baseline_revision: 'c3fd99438ce45f5723b393ed8be055d400697201'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** In "Toutes les cartes" (`/:locale/library/cards`) a game the viewer does not hold renders as a locked missing slot (title, year, padlock), so nobody can see what a card they lack looks like; the author decided (2026-10-20) the grid becomes the catalog.

**Approach:** Render every grid slot through `CardComponent`; a new `owned: false` option draws the author's not-owned treatment (face at 45 % opacity, fully grey, rarity effects and tilt off, the pixel lock bare at the centre of the art, in text-bright with a 1px backdrop outline, about a third of the art's width). The grid applies it only for a signed-in player; a visitor's faces are plain. A not-owned face's link adds "not owned" / "non possédée" to its accessible name. Set albums keep their missing slots.

## Boundaries & Constraints

**Always:** owned-first order, copies badge ("x n") and edition count and NOUVEAU on owned cards only, the state filter's "missing" choice, each slot's link to the detail with the grid context; the visitor's grid runs no holdings query and keeps its query counts; no `style` attribute; no database id; strings in both `en.yml` and `fr.yml`; no planning ids in code or tests.

**Never:** touch set albums (`library/_album`, `.missing-slot` CSS stays for them), the card detail (`cards/_detail`, `CardsController`, the faded back: ticket 3), the visitor's ownership parts (state filter group, RAPPORT, owned count: ticket 4), or build another player's full collection (not built yet; epic-screen-walkthrough story 7 will pass its owner's holdings through the same partial local). No opacity or filter on the `.card` root of a tilting face.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player, mixed | signed in, holds 3 of 150 | 3 owned faces first with badges, then 57 `.card.card--not-owned` faces with lock, link label ends ", not owned" | none |
| Visitor | signed out | 60 plain `.card` faces, no `.card--not-owned`, no lock, no badges, label without "not owned"; no holdings query | none |
| Banned since sign-in | session of a banned player | treated as visitor (plain faces) | none |
| State "missing" | player, `state[]=missing` | only not-owned faces | none |
| Search for a game not held | player, `q=` its title | its not-owned face | none |
| Set album | `/library/:kind/:key` | missing slots unchanged | none |

</intent-contract>

## Code Map

- `app/views/library/_grid.html.erb` -- the grid partial; the `else` branch draws `.missing-slot`. Replace it with `link_to_card_detail(card, strings:, context: { grid: context }, owned: !set_apart)` wrapping `render CardComponent.new(card:, size: :grid, owned: !set_apart)`; new local `set_apart` (true for a signed-in player). Update the header comment.
- `app/views/library/_collection.html.erb` -- renders `library/grid`; pass `set_apart:` through (new local, document it).
- `app/views/library/cards.html.erb` -- renders `library/collection`; pass `set_apart: current_player.present?` (`current_player` is a helper_method; nil for a visitor and a banned player).
- `app/components/card_component.rb` / `.html.erb` -- add `owned: true` keyword. When false: class `card--not-owned`, no `data-controller="tilt"`/`data-tilt-max-value`, no `.card__effects` span, and a `<span class="card__lock">` holding `helpers.pixel_icon("lock")` (already aria-hidden) as the root's last child.
- `app/frontend/styles/card.css` -- new block "A card not owned": root `background: none; box-shadow: none`; a `::before` (absolute, inset 0) drawing the frame as `box-shadow: var(--pixel-outline-4), var(--card-face-bevel), inset 0 0 0 var(--card-frame) var(--card-rarity)`; `::before` and `> .card__body` get `opacity: 0.45; filter: grayscale(1)`, body `position: relative`. `.card__lock` absolute, centred on the art: `left: 50%`, `bottom: calc(var(--card-frame) + var(--card-padding) + var(--card-rarity-line-height) + 2 * var(--card-gap) + var(--card-line-height) + var(--card-art-height) / 2)`, `transform: translate(-50%, 50%)`, width `round(down, calc(var(--card-art-width) / 3), 10px)` and height 1.2 × that on its svg, `color: var(--color-text-bright)`, four 1px `drop-shadow`s in `var(--color-backdrop)`. Keep the header comment true (the root of a not-owned face does not tilt). Do not change the `.card {` rule body (tilt.test.ts reads it).
- `app/helpers/card_details_helper.rb` -- `link_to_card_detail(view, strings: nil, context: {}, number:, owned: true)`; `card_detail_open_label(view, strings, owned: true)` uses `card_details.open_not_owned` when not owned.
- `config/locales/en.yml`, `fr.yml` -- `card_details.open_not_owned`: "%{title}, %{year}, %{rarity}, season %{season}, not owned" / "%{title}, %{year}, %{rarity}, saison %{season}, non possédée".
- `app/controllers/library_controller.rb` -- class comment "sees every slot missing" becomes true to the new rule.
- `test/controllers/library_controller_test.rb` -- `slots` helper: owned face (has `.collection-slot__copies`) → `[:owned, title, "xn", new]`; `.card--not-owned` → `[:not_owned, title, year from .card__year]`; plain face → `[:plain, title, year]`. Replace every `:missing` expectation of the grid accordingly (player → `:not_owned`, visitor/banned → `:plain`), and the `.missing-slot` asserts at the first test, "carry the grid's filters" and French copy test.
- `test/components/card_component_test.rb` -- cases for `owned: false`.
- `test/controllers/library_set_test.rb`, `public_profiles_controller_test.rb` -- albums: must still pass unchanged.

## Tasks & Acceptance

**Execution:**
- [x] `app/components/card_component.rb`, `card_component.html.erb` -- add `owned:` option -- the treatment lives on the face.
- [x] `app/frontend/styles/card.css` -- not-owned block -- faded grey face, lock bright.
- [x] `app/helpers/card_details_helper.rb`, `config/locales/en.yml`, `config/locales/fr.yml` -- not-owned label -- accessible name.
- [x] `app/views/library/cards.html.erb`, `_collection.html.erb`, `_grid.html.erb`, `app/controllers/library_controller.rb` -- faces for every slot, `set_apart` for a player -- the catalog.
- [x] `test/components/card_component_test.rb` -- not-owned face: class, lock, no tilt, no effects; owned default unchanged.
- [x] `test/controllers/library_controller_test.rb` -- update helpers and expectations; add: a player's not-owned link label ends ", not owned" (en) / ", non possédée" (fr); a visitor's grid has no `.card--not-owned` and no `.card__lock`; a search for a game not held finds its not-owned face.

**Acceptance Criteria:**
- Given a player holding a few cards, when they open Toutes les cartes, then owned faces come first with their "xn", then every other card's face with `.card--not-owned` and a lock, and no `.missing-slot` in the grid.
- Given a visitor, when they open it, then every slot is a plain face, and the request runs no `game_holdings`/`game_player_states` query at the visitor's seven queries.
- Given a set album with missing cards, when opened, then its missing slots are unchanged.

## Implementation Notes

- Every grid slot is a `CardComponent` face; `owned: false` drops the tilt controller and the effects layer and adds `.card__lock`. The frame moved to a `::before` ring so the root carries no opacity or filter and the lock stays bright.
- `set_apart` is `current_player.present?` in `library/cards`; a banned player's `current_player` is nil, so they see plain faces as a visitor does.
- Another player's full collection is not built yet (epic-screen-walkthrough story 7); it can pass its owner's holdings through the same `set_apart` local.

## Plan Change Log

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` A not-owned face has no hover feedback (the old missing slot's accent ring on hover is gone, and the face does not tilt) — DESIGN.md's Card not owned specifies no hover state and says it opens the detail like any card; adding one would invent design the author has not approved; focus and the link still work.

## Design Notes

The lock must not fade, so the root keeps no opacity: the frame moves to a `::before` ring and the body fades on its own (fading the whole root would also fade the lock, and the root of a tilting face must not carry opacity or filter). A not-owned face does not tilt, as its rarity effects are off.

## Verification

**Commands:** (prefix every Rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w14 CHROME_BIN=/usr/bin/chromium`, this worktree's own test database; never run system tests; call git as `/usr/bin/git`; do not commit)
- `bin/rails test test/controllers/library_controller_test.rb test/components/card_component_test.rb test/controllers/library_set_test.rb test/controllers/public_profiles_controller_test.rb` -- pass
- `npm run test:js` -- pass

## Auto Run Result

- Summary: in Toutes les cartes every card is its face; a signed-in player's cards not owned are faded, grey, without rarity effects or tilt, with a bright pixel lock centred on the art, their links named "…, not owned" / "…, non possédée"; a visitor's faces are plain; set albums keep their missing slots.
- Files: `app/components/card_component.rb`, `.html.erb` (the `owned:` option); `app/frontend/styles/card.css` (the not-owned block); `app/helpers/card_details_helper.rb` and both locales (the not-owned label); `app/views/library/cards.html.erb`, `_collection.html.erb`, `_grid.html.erb`, `app/controllers/library_controller.rb` (faces for every slot, `set_apart`); `test/components/card_component_test.rb`, `test/controllers/library_controller_test.rb`.
- Review (quick): 1 finding, rejected as low (no hover state for a not-owned face; not in the design). No patch, no deferral.
- Follow-up review recommended: false (nothing patched).
- Verification: `bin/rails test` 2880 runs, 0 failures; `npm run test:js` 486 passed; typecheck, zeitwerk, packwerk, rubocop (846 files), i18n-tasks missing and brakeman clean.
- Residual risk: the lock's position and size were checked by formula, not in a browser (system tests are disabled).
