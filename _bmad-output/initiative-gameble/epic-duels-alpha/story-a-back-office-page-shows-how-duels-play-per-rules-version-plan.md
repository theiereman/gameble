---
title: 'A back-office page shows how duels play, per rules version'
type: 'feature'
ticket: '6'
created: '2026-11-20'
status: 'built'
baseline_revision: 'ba9cee48117fecaa2935090dc51b49c9de558054'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The duels alpha exists to learn whether the duel is fun and which deck recipes hold, but nothing reads the duel tables back: the author cannot see, per rules version, how duels end or which recipes win.

**Approach:** A staff-only back-office page `/back-office/duels`, with its dashboard tile and pixel icon, reads the finished duels of one rules version (the current one unless another is picked) through one `Game` query and shows live duels (figures, win rate by deck recipe, stats called) apart from practice duels (the same figures by bot archetype, and their stats called).

## Boundaries & Constraints

**Always:**
- Live = `practice: false`, practice = `practice: true`; only `state: "finished"` duels at the selected `rules_version`.
- Forfeit rule: a forfeited duel (`forfeited_by` set) counts in "duels finished" and in its own "forfeited" figure, and is left out of every rate and of the stats called. Rates divide by the played-out duels (finished − forfeited); a draw is never a win.
- First caller win = `result == first_caller`. Decided on the margin = `challenger_score == opponent_score` and `result != "draw"`. Automatic move = any of the duel's rounds with `caller_automatic` or `answer_automatic`. Stats called = count of rounds per `[stat, direction]`.
- Recipe win rate (live only): each played-out duel gives two decks, `Game::DeckArchetypes.classify(duel.cards(role))` for `challenger` and `opponent`; a deck wins when `result == role`. `classify` already returns `"other"` for a deck matching no archetype.
- Practice rows group by `bot_archetype` (nil, from duels started before archetypes were stored, reads as `"other"`); the bot is `Game::PracticeBot::ROLE` (`:opponent`), so the bot's win = `result == "opponent"`. Practice never feeds the recipe rows.
- Staff = `moderator?` in the policy, as the other read-only pages (`MarketHealthPolicy`). Every string in `en.yml` and `fr.yml`; tables with `<caption>`, `<th scope="col">`/`scope="row"`; no `style` attribute; no database id in the HTML.

**Never:** stored or precomputed figures, a job, a migration, JavaScript, a chart; any write on the GET; mixing practice into recipe rows; touching `DeckArchetypes`, `DuelRules` or the player-facing duel screens; running tests, linters, packwerk, i18n-tasks or migrations, or committing, in this build (the coordinator runs them; the pixel-art export is not a test and runs); git other than `/usr/bin/git`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two versions | finished duels at version 1 and `VERSION - 1` | page at `VERSION` counts only its duels; `?version=<older>` counts only the older ones | No error expected |
| Bad version | `?version=abc` or a version with no finished duel | current `DuelRules::VERSION` selected | No error expected |
| Forfeit | a finished duel with `forfeited_by` | counted in finished and forfeited, in no rate, no recipe deck, no stat call | No error expected |
| Unfinished | active, challenged, cancelled duels | counted nowhere | No error expected |
| No duels | version with no live (or no practice) duel | one quiet panel line per empty section | No error expected |
| Nil archetype | practice duel with `bot_archetype` nil | row "other" | No error expected |
| Non-staff | signed-in player | unknown address (404 page) | `BaseController#hide_from_non_staff` |

</intent-contract>

## Code Map

- `app/controllers/back_office/base_controller.rb` -- parent: hides the back-office from non-staff as a 404; reuse, do not change.
- `app/controllers/back_office/market_signals_controller.rb`, `app/policies/back_office/market_health_policy.rb` -- read-only page pattern: `authorize [ :back_office, :x ], :show?`, policy `def show? = moderator?`.
- `app/views/back_office/market_signals/show.html.erb` -- table pattern: `content_for :back_button`, `div.stack`, `h1`, intro `PanelComponent.new(tag: :p)`, `div.ledger-scroll > table.ledger` with `caption.visually-hidden` and `th scope="col"`. Empty state = `PanelComponent.new(tag: :p)`.
- `app/views/back_office/players/index.html.erb:23` -- GET form pattern: `form_with url:, method: :get, class: "ledger-search"`, visually-hidden label, field class `ledger-search__field`, `ButtonComponent.new(variant: :secondary, type: :submit)`.
- `app/helpers/back_office_dashboard_helper.rb` -- `back_office_groups`: add a `duels:` group between `communication:` and `market:` holding `back_office_tile(:duels, back_office_duels_path, action: :show?)`.
- `app/components/back_office_tile_component.rb` -- icon `office-duels`, texts `back_office.dashboard.show.tiles.duels.{title,text}`; group label `back_office.dashboard.show.groups.duels`.
- `script/pixel_art/back_office_icons.mjs` -- add a `duels` entry (`look` + 11 × 11 grid of `c`/`.`); then run `node script/pixel_art/export.mjs` and `node script/pixel_art/export.mjs --check`; never hand-edit `app/frontend/images/pixel/`.
- `config/routes.rb` -- inside `scope "back-office", module: :back_office`: `resource :duels, only: :show` with a one-line comment as its neighbours have.
- `app/domains/game/app/models/game/duel.rb` -- `cards(role)` builds `DuelCard`s from the snapshot; `has_many :rounds`.
- `app/domains/game/app/models/game/deck_archetypes.rb` -- `NAMES`, `OTHER`, `classify(cards)`.
- `app/domains/game/app/models/game/duel_stat.rb` -- `STATS`, `DIRECTIONS` (symbols); rounds store `stat`/`direction` as strings.
- `app/domains/game/app/queries/game/duel_record.rb` -- sibling query style (module, `self.call`, `Data.define`).
- Locales: `duels.archetypes.<name>` (nine names; add `other`: "other" / "autre" in both files, already ignored by i18n-tasks as `duels.archetypes.*`), `duel_stats.names.<stat>`, `duel_stats.directions.<stat>.<direction>` exist; reuse them.
- `test/controllers/back_office/dashboard_controller_test.rb:53-64` -- moderator sees `%w[Modération Marché]`, 5 tiles; administrator 5 groups, 14 tiles: both change with the new group.
- `test/controllers/back_office/feedbacks_controller_test.rb` -- controller test pattern (`HiddenBackOffice`, `SteamSignIn`, `assert_unknown_address`).
- `test/controllers/own_profiles_controller_test.rb:29` -- `written_statements` recorder for "the GET writes nothing".
- `test/support/duels.rb` -- `duel_card(id, **percentiles)`, `active_duel(challenger:, opponent:, first_caller:)` (unsaved); `test/domains/game/duel_record_test.rb` `finished_duel` shows saving a finished duel with seats.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/duel_balance.rb` -- new `Game::DuelBalance`: `versions` and `call(rules_version)` -- see Design Notes.
- [ ] `app/policies/back_office/duels_policy.rb` -- `def show? = moderator?`.
- [ ] `app/controllers/back_office/duels_controller.rb` -- `show`: authorize, pick the version (Design Notes), `@report = Game::DuelBalance.call(@version)`.
- [ ] `config/routes.rb` -- the route.
- [ ] `app/views/back_office/duels/show.html.erb` (+ partials as needed, e.g. `_figures.html.erb`, `_stats_called.html.erb`) and `app/helpers/back_office_duels_helper.rb` (`duel_share(count, total)` → `number_to_percentage(count * 100.0 / total, precision: 0)`, or the "no value" word when total is 0) -- the page (Design Notes).
- [ ] `app/helpers/back_office_dashboard_helper.rb` -- the `duels` group and tile.
- [ ] `script/pixel_art/back_office_icons.mjs` + generated `app/frontend/images/pixel/office-duels.svg` (and whatever else the export rewrites) -- the icon.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `back_office.duels.show.*`, the tile and group, `duels.archetypes.other`.
- [ ] `test/domains/game/duel_balance_test.rb` -- query tests (Acceptance).
- [ ] `test/controllers/back_office/duels_controller_test.rb` -- controller tests (Acceptance); update `test/controllers/back_office/dashboard_controller_test.rb` counts and group lists.

**Acceptance Criteria:**
- Given live duels at `VERSION` (a rating deck vs an even deck won by the first caller; a coverage deck vs a rating deck tied on score and won on the margin with one automatic round; a draw; a forfeit) and one live duel at `VERSION - 1`, when `DuelBalance.call(VERSION)` runs, then finished = 4, forfeited = 1, first caller wins = 1, decided on margin = 1, with automatic move = 1, the stats called tally exactly the saved rounds of the three played-out duels, and the recipe rows give coverage 1 deck / 1 win, rating 2 decks / 1 win, other 2 decks / 0 wins (the forfeited duel's decks absent); `call(VERSION - 1)` counts only the older duel.
- Given practice duels (two `rating`, one won by the bot; one with `bot_archetype` nil) at `VERSION`, when the query runs, then practice rows are `rating` (2 finished, 1 bot win) and `other` (1), and none of their decks appears in the recipe rows.
- Given those duels, when a moderator GETs `/en/back-office/duels`, then each figure shows in its table cell (counts and percentages), practice archetypes appear only in the practice table, no `[style]`, and no INSERT/UPDATE/DELETE runs during the GET; with `?version=<older>` the older figures show and the select has the older version selected.
- Given a signed-in non-staff player, when they GET the page, then they get the unknown-address 404; given a moderator, the dashboard shows the Duels tile linking to the page.

## Implementation Notes

- Three played-out duels give six decks, so the first acceptance criterion's three recipe rows (five decks) cannot be the whole list: the draw is played between a popularity deck and an even deck, and the recipe rows are coverage 1/1, popularity 1/0, rating 2/1, other 2/0. Practice duels use trump decks, so a leak would show a `trumps` row.
- The scenario lives in `test/support/balance_duels.rb`, shared by the query and controller tests.
- Partials use static locale keys (the stats heading is passed in) so i18n-tasks sees every new key.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` a version whose live (or practice) duels were all forfeited shows "—" rates and an empty recipe table instead of the empty-state line — the counts finished and forfeited still read correctly and the rates say "no value"; a version where every duel was forfeited is unlikely, and the fix adds a branch.
  - `[low]` `[patch]` the intro says every rate is a share of the duels played out, but the recipe win rate is a share of decks — the sentence in `back_office.duels.show.intro` now names the recipe rate's denominator, in `en.yml` and `fr.yml`.
  - `[low]` `[reject]` `Integer(params[:version], exception: false)` reads `010` as octal — the version comes from the page's own select, which sends plain decimals; the `@versions.include?` guard keeps any other value on a real version.
  - `[low]` `[reject]` practice duels load their deck snapshots though only live decks are classified — wasted payload at the alpha's volume only, already under the `shortcut:` note on in-memory aggregation.
  - `[low]` `[reject]` no test of a version with practice duels and no live duel — the two empty states are each covered (`data-duel-empty=live` in the fallback test, `=practice` in the previous-rules test); the combination adds no new branch.

## Design Notes

Query (one module, two reads; at the alpha's volume the duels are aggregated in Ruby, as the architecture allows):

```ruby
Figures = Data.define(:finished, :forfeited, :first_caller_wins, :decided_on_margin, :with_automatic_move, :stats_called) do
  def played = finished - forfeited
end
Recipe = Data.define(:name, :decks, :wins)
Practice = Data.define(:archetype, :figures, :bot_wins)
Report = Data.define(:rules_version, :live, :recipes, :practice, :practice_total)
```

- `versions` = distinct `rules_version` of finished duels, plus `DuelRules::VERSION`, sorted descending.
- `call(v)`: `Duel.where(state: "finished", rules_version: v)` (selecting the columns needed), and its rounds `DuelRound.where(duel_id: <that relation>.select(:id))` grouped by `duel_id`. `stats_called` is a Hash `{ [stat_sym, direction_sym] => count }`. Recipes and practice rows are ordered as `DeckArchetypes::NAMES + [OTHER]` and list only what was played. A `shortcut:` comment states the in-memory aggregation limit and when to move it to SQL.

Controller version pick: `version = Integer(params[:version], exception: false)`; `@versions = Game::DuelBalance.versions`; `@version = @versions.include?(version) ? version : Game::DuelRules::VERSION`.

Page, top to bottom: `h1`; intro panel stating the forfeit rule in one sentence; the version GET form (label "Rules version", `select_tag :version` of `@versions`, submit "Show"); section "Live duels" (`h2`): figures table (one row; columns Duels finished, Forfeited, First caller wins, Decided on the margin, With an automatic move), recipes table (Recipe, Decks played, Wins, Win rate), stats called table (Stat, Direction, Calls; one row per `[stat, direction]` of `STATS × DIRECTIONS`, zero included, stat from `duel_stats.names`, direction from `duel_stats.directions`); section "Practice duels" (`h2`): table by bot archetype (Bot archetype as `th scope="row"`, the figure columns, Bot wins as a rate), then its stats called table from `practice_total`. Each empty section shows one panel line instead of its tables. Rates show as percentages of `played` (or of decks played); counts as integers. Hooks for tests: `data-duel-figures="live"`, `data-duel-recipe="<name>"`, `data-duel-practice="<archetype>"`, `data-duel-call="<stat>-<direction>"` inside `data-duel-stats="live|practice"`.

Assumptions (recorded for the author):
- Forfeits: counted as finished and as forfeited, left out of every rate and of the stats called, since a forfeit says nothing about how the rules played (rule above).
- A draw is not a win in any rate; win rates divide by played-out duels or decks.
- A practice duel with no stored archetype reads as "other".
- The version selector lists versions that have finished duels plus the current one; anything else falls back to the current version.
- The page is open to every staff member (moderators included), as the other read-only back-office pages; it sits in its own "Duels" group on the dashboard.

## Verification

**Commands (run by the coordinator, not this build):**
- `bin/rails test test/domains/game/duel_balance_test.rb test/controllers/back_office/duels_controller_test.rb test/controllers/back_office/dashboard_controller_test.rb` -- expected: pass
- `node script/pixel_art/export.mjs --check` -- expected: pass (this one the build runs)
- `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing` -- expected: pass

## Auto Run Result

**Summary:** a staff-only back-office page, `/back-office/duels`, in its own Duels group on the dashboard with a crossed-swords tile icon. It reads the finished duels of one rules version through `Game::DuelBalance`: the current version by default, any version with finished duels from a select. Live duels show duels finished, forfeited, first caller's win rate, share decided on the margin, share with an automatic move, the win rate by deck recipe (each played-out deck classified by `Game::DeckArchetypes.classify`, unmatched as "other") and the stats called. Practice duels show the same figures, plus the bot's win rate, in their own table by `bot_archetype` (nil reads as "other"), with their own stats called. Practice never feeds the recipe rows. Forfeit rule: a forfeited duel counts as finished and as forfeited, and in no rate and no stat called.

**Files changed:**
- `app/domains/game/app/queries/game/duel_balance.rb` -- new query: `versions`, `call(rules_version)`.
- `app/controllers/back_office/duels_controller.rb`, `app/policies/back_office/duels_policy.rb` -- the page, staff (`moderator?`).
- `config/routes.rb` -- `resource :duels, only: :show`.
- `app/views/back_office/duels/show.html.erb`, `_figure_headings`, `_figure_cells`, `_stats_called` -- the tables and the version form.
- `app/helpers/back_office_duels_helper.rb` -- `duel_share`.
- `app/helpers/back_office_dashboard_helper.rb` -- the Duels group and tile.
- `script/pixel_art/back_office_icons.mjs`, `app/frontend/images/pixel/office-duels.svg` -- the icon, exported.
- `config/locales/en.yml`, `config/locales/fr.yml` -- page strings, tile, group, `duels.archetypes.other`.
- `test/support/balance_duels.rb`, `test/domains/game/duel_balance_test.rb`, `test/controllers/back_office/duels_controller_test.rb` -- the scenario and tests.
- `test/controllers/back_office/dashboard_controller_test.rb` -- group lists and tile counts.

**Review findings:** 1 low patched (intro wording). Nothing deferred. 4 lows rejected, each with its reason in the triage log.

**Follow-up review recommended:** false. Only one low was patched.

**Verification:** no tests or linters were run, by the coordinator's instruction. These checks passed: `node script/pixel_art/export.mjs --check`, `ruby -c` on the new Ruby files, ERB compiled and syntax-checked, and a YAML load of both locales. The coordinator still has to run the commands under Verification, plus `npm run format:check`.

**Residual risks:**
- The tests expect English percentages such as "33%" from the default number format.
- The tests save duels at `rules_version` 0 (`VERSION - 1`).
- The page aggregates in Ruby, which is fine at the alpha's volume.

