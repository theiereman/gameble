---
title: "The capsule's enlarged reveal card shows no game category"
type: 'bugfix'
ticket: "bug-the-capsule-reveal-card-shows-no-game-category"
created: '2026-10-19'
status: done
baseline_revision: 'ac80a01a6e3a085a6db0c78ac87e610b8a280f51'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      The UFO share after the change, the tags beyond Adventure and the main themes moved to adventure are not measured on staging.
    evidence: |-
      The ticket asks for the drop measured on staging's catalog and for Story Rich or other narrative tags only if staging's tag counts show they fit. No local copy of the catalog exists (the local databases hold no steam_apps) and this build must not touch staging, so only the spike's before figure (4.35 %) is recorded. The author settles it by running bug-the-capsule-reveal-card-shows-no-game-category-probe.rb on staging.
    location: >-
      packs/catalog/app/models/catalog/themes.rb
    severity: medium
  - summary: >-
      The spec still lists Adventure among the broad tags that are never themes.
    evidence: |-
      spec-gameble/catalog-and-rarity.md, Themes line: "Broad tags (Action, Adventure, Casual, Indie, Singleplayer, Multiplayer, Free to Play) are never themes." The author's decision of 2026-10-19 (pending-approvals.md) adds an Adventure theme; the spec is the author's to amend.
    location: >-
      _bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md
    severity: low
---

<intent-contract>

## Intent

**Problem:** Dreamfall: The Longest Journey shows no genre on its enlarged capsule card because none of its five most-voted Steam tags (Adventure, Female Protagonist, Story Rich, Fantasy, Sci-fi) belongs to a theme, so it is a UFO and its card-season has no main theme. Adventure games of this kind keep landing in the UFOs.

**Approach:** Add an `adventure` theme ("Adventure" / "Aventure") covering the Steam tag Adventure to `Catalog::Themes::TAGS`, with its names in both locales. The rule is unchanged: a game joins every theme among its five most-voted tags, and the first one in vote order is its main theme. Seasons published from now on (after the next import or a rescore rewrites the draft's genres) give such games a main theme; published seasons stay frozen, and cards without a theme keep showing no genre.

</intent-contract>

## Implementation Notes

Oneshot: about 60 lines in five files (the theme list, two locale files, two test files), no new code path.

- `packs/catalog/app/models/catalog/themes.rb` -- add `"adventure" => [ "Adventure" ]`, beside `point_and_click` (theme sets follow the list's order).
- `config/locales/en.yml`, `config/locales/fr.yml` -- `catalog.themes.adventure`: "Adventure" / "Aventure".
- `test/packs/catalog/set_builder_test.rb` -- the theme count goes from 42 to 43 (two asserts).
- `test/packs/steam/cards_test.rb` -- the "broad tags give no genre" test no longer uses Adventure; new test: a game with Dreamfall's five tags, imported and published in a season, has `adventure` as main theme, is a member of the adventure theme set and not of the UFOs.
- `how_it_works` counts the themes from the list, so its copy follows.

**Tags chosen.** Adventure only. No staging copy is reachable from here and this build may not touch staging, so the data cannot say whether Story Rich, Action-Adventure or Female Protagonist fit; per the instruction, the theme covers Adventure alone and those are reported as alternatives. `bug-the-capsule-reveal-card-shows-no-game-category-probe.rb` (beside this plan, read-only) measures each variant on the latest published season.

**UFO share.** Before: 536 of 12,329 cards, **4.35 %** (spike report, season 2, the same 42-theme list, checked equal to `Catalog::Themes::TAGS`). After: **not measured** (no local copy of the catalog; the local databases hold no `steam_apps`). The spike found the remaining UFOs hold only broad tags (Indie, Action, Adventure, Casual, Free to Play), so the share can only drop; the probe gives the figure.

**Side effect to check.** Adventure is a heavily voted tag, often ranked above specific ones (Action, Adventure, RPG…). Main themes follow vote order, so in future seasons many cards that had another main theme (RPG, Puzzle, Horror…) will show "Aventure", and the adventure set will likely be among the largest. The probe counts both.

**Spec.** `spec-gameble/catalog-and-rarity.md` still lists Adventure among the broad tags that are never themes; left for the author to amend.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 7 findings — high 0, medium 2, low 4, false 1, maybe-false 0
- findings:
  - `[medium]` `[defer]` The UFO share after the change is not measured on staging, nor the main themes moved to adventure or the set's size — real; staging is out of bounds for this build and no local copy exists; deferred to the author with the probe.
  - `[medium]` `[defer]` Adventure alone was not chosen from tag counts — same root cause as the row above (no data reachable); the instruction for this case is Adventure alone, alternatives reported; deferred with it.
  - `[false]` `[reject]` "Published seasons are unchanged" has no test — `test/packs/catalog/publish_season_test.rb` "the sets, tiers and main themes of a published season are frozen" already refuses any change to a published card-season's main theme and its sets; the theme list is read only at import and publication.
  - `[low]` `[patch]` `package-lock.json` renamed to the worktree's name by `npm install` — reverted; not in the change.
  - `[low]` `[reject]` How it works says 43 themes while the published season has no adventure set yet — the copy counts the theme list, which is the rule players read; it already differed from the live season whenever a theme had no card; tying it to the published season adds a query for a transient gap.
  - `[low]` `[patch]` The probe derives the before share from today's tags, not the season's stored UFOs — the probe now also prints the stored count of card-seasons without a main theme.
  - `[low]` `[defer]` The spec still calls Adventure a broad tag that is never a theme — the spec is the author's document; deferred.

## Verification

**Commands:**
- `bin/rails test test/packs/steam/cards_test.rb test/packs/catalog/set_builder_test.rb test/packs/catalog/publish_season_test.rb test/controllers/how_it_works_test.rb` -- expected: green
- full `bin/ci`, `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health` -- expected: green

## Earlier investigation (blocked run, superseded by the author's decision of 2026-10-19)

The enlarged reveal face does render the main theme: the phone zoom (`app/frontend/components/BoosterView.tsx`, `face={zoomed.faces.xl}`) shows the xl face rendered by `CardComponent`, which prints `.card__genre` whenever `card.genre` (the card-season's `main_theme`, from `Catalog::CardViews`) is set. Dreamfall (Steam app 6300) has the five tags above; `Steam::CardMapping` reads only the five most-voted (`TOP_TAGS = 5`), none is in `Catalog::Themes`, so `PublishSeason` stored `main_theme` NULL. Every other face omits the genre for such a card the same way. The run blocked on the choice between showing "UFO" as a genre, adding a theme, or closing; the author chose the theme.

## Auto Run Result

**Status:** built.

**Change.** A new theme `adventure` ("Adventure" / "Aventure") covers the Steam tag Adventure. A game with Adventure among its five most-voted tags joins it, and it is the game's main theme when Adventure is its first themed tag. Seasons published after the next import or rescore give Dreamfall-like games a genre; published seasons keep their frozen main themes and sets.

**Files.**
- `packs/catalog/app/models/catalog/themes.rb` -- the `adventure` theme, beside point & click.
- `config/locales/en.yml`, `config/locales/fr.yml` -- its names.
- `test/packs/steam/cards_test.rb` -- a game tagged like Dreamfall, imported and published, has `adventure` as main theme and set, and the season has no UFOs; the broad-tags test no longer uses Adventure; Adventure behind a broad tag gives the theme.
- `test/packs/catalog/set_builder_test.rb` -- 43 themes.
- `bug-the-capsule-reveal-card-shows-no-game-category-probe.rb` -- read-only staging probe: stored UFOs, the share before and with each tag variant, the adventure set's size and the main themes it takes over.

**Review.** 7 findings: 2 patched (low: lock file reverted, probe reads the stored UFOs), 3 deferred (staging measurement and tag choice, spec line), 2 rejected (published-season freeze already tested; how-it-works count follows the rule). Follow-up review: false (no high or two medium patched).

**Verification.** `bin/ci`: every step green except one error in `Game::WeeklyGoalTest` (FK violation on `game_holdings.card_season_id`); a second full run errored the same way in `Game::OpenPackTest`. Both files pass alone, and the full suite passes with the failing run's seed, with and without the change: a draw-pool flake under load, unrelated to the theme list. `npm run test:js` (476 passed), `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `i18n-tasks missing`, rubocop: green. The new Dreamfall tests fail without the theme.

**Residual risks.** The UFO share after the change is unmeasured (before: 4.35 %, spike). Adventure is heavily voted and often ranked above specific tags, so many cards may show "Aventure" instead of RPG, Puzzle or Horror in future seasons, and the set may be among the largest; the probe measures both before a season is published.
