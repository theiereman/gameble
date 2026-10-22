---
title: 'Another player''s full collection, read-only'
type: 'feature'
ticket: '7'
created: '2026-10-22'
status: 'built'
baseline_revision: '9598184bf26f445fb2206e61a180a71c1feec8e9'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      The grid-loading concern now holds viewer-only methods (watermark) that the card detail controller inherits without calling.
    evidence: |-
      collection_grid_loading.rb shown_watermark uses current_player; harmless today, easy to break.
    severity: low
---

<intent-contract>

## Intent

**Problem:** A profile cannot open another player's collection, the friend profile still shows a showcase and no way to the collection, and a card opened from someone else's cards cannot lead back to them.

**Approach:** A read-only collection page per player, reusing the viewer's own grid (search, filters, set filter, pages) over the owner's holdings; the public profile and the friend profile link to it; a card opened from it walks that grid and leads back to it.

## Boundaries & Constraints

**Always:** Same rules as the viewer's own grid except: tiles, states, rapport and "not owned" faces follow the owner's holdings, never the viewer's; no "new" state, no "Nouveau" badge, no collection-seen post, no top-bar unique-cards status (those are the viewer's watermark). A GET writes nothing. The owner is addressed by token only. Visibility follows `Game::Visibility` exactly as the profile does: an unknown token or a hidden profile renders the existing unavailable page with 404. Open to any browser (visitor included), noindex. Every string in `en.yml` and `fr.yml`; a Pundit policy for the action. Copy: « VOIR LA COLLECTION COMPLÈTE » / "SEE THE FULL COLLECTION" on the public profile (after its SETS section, absent with no season), « VOIR LA COLLECTION » / "SEE THE COLLECTION" on the friend profile beside « VOIR LE PROFIL » (the existing link), both absent for a private friend.

**Never:** No write action on this page. Do not touch the viewer's own library, its entry or albums. Do not keep the friend profile's showcase (view, loads, locale keys, CSS and tests of it go). Do not expose ids.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Public owner | GET brothers/:token/library, any viewer | the owner's grid, cards not owned faded and locked by the owner's holdings | none |
| Hidden owner | private, banned or unknown token | unavailable page, 404 | same page as profile |
| Filters | q, rarity, sets, genre, state owned/missing/duplicates/all | filtered, paginated as the own grid | unknown state ignored; state new ignored |
| Card from it | card link carries the grid and the owner's token | the detail walks that grid, back "Grille" leads to this page and page | context ignored when the owner is not visible |
| No season | no published season | the same no-season line as the own grid | none |

</intent-contract>

## Code Map

- `config/routes.rb` -- add `get "brothers/:token/library" => "public_profiles#collection", as: :brother_collection` with the token constraint, next to `brother_set`.
- `app/controllers/public_profiles_controller.rb` -- new `collection` action (includes `CollectionGridLoading`); loads the grid like `LibraryController#cards` but for `@owner`.
- `app/controllers/concerns/collection_grid_loading.rb` -- every `current_player` becomes a `grid_owner` hook (default `current_player`); the grid context carries `brother: token` when the owner is another player; `new` state ignored for another's grid.
- `app/controllers/library_controller.rb` -- reference for `load_grid`, `load_set_filter`, `load_summary` (extract what both controllers share rather than copy).
- `app/controllers/cards_controller.rb` -- `grid_browse`: when the grid context names a `brother` visible to the viewer, walk that owner's grid, back to `brother_collection_path` with the page; `grid_page_path` accordingly.
- `app/views/public_profiles/collection.html.erb` (new), `app/views/library/_collection.html.erb`, `_grid.html.erb`, `_filters.html.erb` -- reuse; parametrise the clear link (`library_cards_path`), the `Nouveau` badge and the state group.
- `app/views/public_profiles/_profile.html.erb` or `_sets.html.erb` -- the full-collection link.
- `app/views/friend_profiles/show.html.erb`, `app/controllers/friend_profiles_controller.rb`, `app/frontend/styles/friends.css` -- drop the showcase, add « VOIR LA COLLECTION » (hidden when the friend's profile is not open to the viewer as today's profile link is).
- `app/policies/page_policy.rb` -- the existing `show?` serves; verify before adding one.
- `packs/game`: `Game::CollectionTiles`, `Game::CollectionStates`, `Game::HeldGames`, `Game::TierCounts` already take a player; no pack change expected.
- Tests: `test/controllers/public_profiles_controller_test.rb`, `friend_profiles_controller_test.rb`, `cards_controller_test.rb`, `library_controller_test.rb`, system tests `public_profile_test.rb`, `friends_test.rb`, `library_test.rb`, `card_detail_test.rb`.
- The old profile index of sets: confirm no route, view or test still serves a sets index under `brothers/:token` other than the profile itself and albums; remove any leftover.

## Tasks & Acceptance

**Execution:**
- [ ] route, controller action, concern hook, shared loading -- the page over the owner's holdings
- [ ] views and locales (en, fr) -- the page, the two links, no showcase on the friend profile
- [ ] `cards_controller.rb` -- the detail walks the owner's grid and leads back to it
- [ ] request tests for each matrix row, no write route on the page, the back from a card, visibility, and the friend profile; update system tests touched

**Acceptance Criteria:**
- Given a public player, when any viewer opens their collection, then the grid shows the owner's holdings and cards they lack faded, with search and filters working.
- Given a card opened from that grid, when the viewer goes back, then they land on that owner's grid page, not their own.
- Given a private or banned owner, then the collection answers like the profile does (404 unavailable).
- Given a friend profile, then it shows no showcase, offers « VOIR LE PROFIL » and « VOIR LA COLLECTION » when the friend is open, and neither when private.
- The page offers no form that writes and no "new" state.

## Implementation Notes

New route `brother_collection` (`public_profiles#collection`); `CollectionGridLoading` gained `grid_owner` and `grid_another?` hooks and the shared `load_grid`, `load_set_filter`, `load_summary`. `Game::ShowcaseCards` had no caller left and was removed. The friends row link label is now "See the profile" and the old text moved to a `collection_link` key. No leftover sets index under `brothers/:token` was found.

## Plan Change Log

## Review Triage Log

### 2026-10-22 - Review pass
- verdicts: 6 findings - high 0, medium 2, low 3, false 0, maybe-false 1
- findings:
  - `[medium]` `patch` "new" chip still offered on another's grid - hidden through a `with_new` local, test inverted.
  - `[medium]` `patch` `seen` watermark passed through on another's grid in the card detail - nil when another's.
  - `[low]` `defer` Concern holds viewer-only methods.
  - `[low]` `reject` Friends row label change - the same link is now the profile link, as the design says; its system test passes.
  - `[low]` `reject` Library tests not touched - they pass unchanged and the new behavior is covered at request and system level.
  - `[maybe-false]` `reject` Staff exception not tested - Game::Visibility is shared and tested with the profile.

## Design Notes

Choices made where the design is silent: no "new" state and badge and no watermark post on another's grid (the watermark is the viewer's own); the RAPPORT shows the owner's figures; the top-bar unique-cards status is the viewer's own and is omitted.

## Verification

**Commands:**
- `bin/rails test` -- expected: pass
- `bin/rails test test/system/<file>.rb` for the system files named in the Code Map that your change touches -- expected: pass
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/brakeman --quiet --no-pager --exit-on-warn` -- expected: clean
- Do not commit; do not open a browser.

## Auto Run Result

Status: built

- **Change:** another player's full collection at `/:locale/brothers/:token/library`, read-only over the owner's holdings, linked from the public profile and the friend profile (which loses its showcase); a card opened from it walks that grid and leads back to it.
- **Review:** 2 patched, 1 deferred, 3 rejected. Follow-up review recommended: false.
- **Verification:** `bin/rails test` 3040 runs 0 failures, 5 system files (30 runs) pass, vitest 530, typecheck, zeitwerk, packwerk, rubocop, i18n-tasks, brakeman clean.
- **Residual risks:** the author must approve the screen; no visual check was made.
