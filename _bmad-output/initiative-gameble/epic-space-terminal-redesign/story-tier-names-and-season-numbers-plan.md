---
title: 'Tier names and season numbers'
type: 'feature'
ticket: '3'
created: '2026-10-05'
status: 'built'
baseline_revision: '783c82acb7aa06d7fd974cfcb35198a2000e946b'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The five rarity tiers still carry the retired medieval code names (`steel`, `emerald`, `sapphire`, `amethyst`, `gold`) and player-facing names (Acier … Or), card-seasons have no number within their season, and nothing reads a card's genre from its tome (R2, R3; AD-5, AD-28).

**Approach:** Rename the code names to `common`, `uncommon`, `rare`, `epic`, `legendary` everywhere (integers 1-5 unchanged, so no data changes), with Commune … Légendaire / Common … Legendary in the locales. Add a nullable `number` to card-seasons (expand), have `Catalog::PublishSeason` give every card of the season a `SecureRandom` shuffle of 1..n, and give it a second entry that numbers an already-published, never-numbered season once by the same shuffle, run by a rake task. `Catalog::CardView` gains `number` (and its "S1 · #4 215" label) and `genre`, the `genre` param of the card-season's tome set in that season, nil when in no tome.

## Boundaries & Constraints

**Always:**
- Only `Catalog::PublishSeason` assigns numbers (both entries live in that class and share one shuffle method). Randomness is `SecureRandom`, injectable as `random:` in `initialize` (as `Game::OpenPack` does) for tests.
- Rarity, number and set memberships never change after publication: `number` joins `CardSeason::SEASON_DATA`. The backfill writes with `update_all` inside the operation's transaction, under a `FOR UPDATE` lock of the season.
- Migrations follow strong_migrations: nullable column; check constraint `number > 0` added `validate: false` then validated in the next migration; unique index `(season_id, number)` built `algorithm: :concurrently` with `disable_ddl_transaction!`. Comment each migration like the existing ones.
- Card number format, per the convention: `S<season> · #<number>`, digits of the number grouped by three with U+00A0, no total ("S1 · #4 215", "S12 · #7", "S1 · #1 000 000").
- Locale names: fr Commune, Peu commune, Rare, Épique, Légendaire; en Common, Uncommon, Rare, Epic, Legendary. Repo text (code, comments) in English.
- Keep the existing UI working: classes `card--rarity-<code>`, sprite symbols `seal-<code>` and back images `back-<code>.svg` renamed in step with the code names.

**Never:**
- Never remove `dust_tier` or `Catalog::Dust` (story 8.7); never redesign the card face, `CardComponent` markup, `Card.tsx` layout or the reveal (story 8.6); never show number or genre on the face yet.
- Never write in a GET (story 8.4); never enqueue jobs inside a transaction.
- Never run the backfill against development or production data, never `git commit`, `git push` or deploy. Running `bin/rails db:migrate` on development is fine (schema only); the backfill rake task runs only in tests.
- Never add the contract step (published card-seasons NOT NULL number) in this story; it comes after the backfill runs in production.
- No colour token renames (`--color-gold`, `--color-rarity-*` stay), no game-title changes ("Golden Crown", "Tin Soldier" are sample titles, not code names).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Publish numbers | draft of n card-seasons, `PublishSeason#call(number:)` | every card-season has a distinct number in 1..n, order given by `(1..n).to_a.shuffle(random:)` over card-seasons by id | existing failures unchanged (`no_draft`, `stale_draft`, `empty_season`, `empty_tier`) roll everything back, no number written |
| Backfill once | published season, all numbers NULL, `PublishSeason#number_published(number:)` | every card-season gets a distinct number in 1..n by the same shuffle; `Success(season)` | — |
| Backfill twice | published season already numbered | nothing written | `Failure(:already_numbered)` |
| Backfill a draft or unknown season | draft number, or no season with that number | nothing written | `Failure(:no_published_season)` |
| Frozen number | published card-season, `update(number: …)` | refused | validation error `frozen_once_published` |
| Genre in a tome | card-season member of a tome set `{genre: "puzzle"}` in its season | `CardView#genre == "puzzle"` (CardViews and CardDetail) | — |
| Genre in no tome | card-season in no tome (only publisher/best_of_year sets, or none) | `genre` nil | — |
| Number label | season 1, number 4215 / number nil | `"S1 · #4 215"` / `nil` | — |
| Rake backfill | two published seasons, one numbered, one not | the unnumbered one is numbered, the other reported as already numbered; exits 0 | a failure other than `already_numbered` aborts with its code |

</intent-contract>

## Code Map

- `packs/catalog/app/models/catalog/rarity.rb` -- `TIERS` 1..5 → `:common, :uncommon, :rare, :epic, :legendary`; the single definition.
- `packs/catalog/app/models/catalog/card_season.rb` -- enum `rarity` from TIERS; add `number` to `SEASON_DATA`; doc comment.
- `packs/catalog/app/operations/catalog/publish_season.rb` -- `call(number:)`: add number writes in `write_season_data` (one UPDATE … FROM unnest(ids, numbers), or slices); new public `number_published(number:)` via dry-operation `operate_on :call, :number_published` (must precede method definitions); private `shuffle(ids)` shared. No event for the backfill.
- `packs/catalog/app/queries/catalog/card_view.rb` -- add `number`, `genre` members, `number_label`, and both in `to_props` (`number`, `genre`).
- `packs/catalog/app/queries/catalog/card_views.rb`, `card_detail.rb` -- pluck `catalog_card_seasons.number` and the tome genre: correlated subquery `(SELECT s.params->>'genre' FROM catalog_set_memberships m JOIN catalog_sets s ON s.id = m.set_id WHERE m.card_season_id = catalog_card_seasons.id AND s.kind = 'tome' LIMIT 1)`, defined once and reused.
- `packs/catalog/app/models/catalog/rarity_thresholds.rb`, `queries/catalog/draft_preview.rb`, `packs/game/app/models/game/draw_odds.rb`, `first_session_guarantee.rb` -- comments only (steel → common, …).
- `db/migrate/` -- two or three new migrations after `20261005000000_create_game_player_states.rb`; `db/schema.rb` regenerated by `bin/rails db:migrate`.
- `lib/tasks/catalog.rake` (new) -- `catalog:number_seasons`: each published season with a NULL number, `PublishSeason.new.number_published(number:)`, prints one line per season.
- `config/locales/en.yml`, `fr.yml` -- `catalog.rarity.*` renamed and renamed values; `back_office.cards.index.samples.*` keys renamed (values kept); intro's "emerald's art" → "uncommon's art" wording; new `errors.catalog.already_numbered`, `errors.catalog.no_published_season` in both.
- `app/components/card_component.rb` -- `legendary?` compares `"legendary"`. `card_strings.rb` comment.
- `app/controllers/back_office/cards_controller.rb` -- sample hashes keyed by new names; sample `CardView`s get `number:` and `genre:` (e.g. `nil` and a sample number).
- `app/frontend/components/Card.tsx` -- `Rarity` union and `CardView` type (`number: number | null`, `genre: string | null`); `"gold"` checks. `RevealCard.tsx`, `PackReveal.tsx`, `lib/reveal.ts`, `lib/reveal.test.ts` -- names and comments.
- `app/frontend/styles/card.css` -- `.card--rarity-*` selectors and back image URLs.
- `app/frontend/images/card/back-*.svg` -- `git mv` to `back-common.svg` … `back-legendary.svg`; `sprite.svg` symbol ids `seal-<old>` → `seal-<new>`.
- `script/card_art/generate.mjs` -- `RARITIES` array and comments (the mockup it reads is gone; do not run it).
- `test/fixtures/catalog/card_seasons.yml` -- rarity values renamed; labels `steel_card_one` → `common_card_one`, `emerald_card_one` → `uncommon_card_one`, `sapphire_card_one` → `rare_card_one`, `gold_card_one` → `legendary_card_one`; numbers 1..5. `cards.yml`, `card_texts.yml` -- labels `steel_card` → `common_card` etc. (slugs and titles unchanged). Every test referencing them (`rtk proxy grep -rln` for the old names under `test/`).

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*` -- add `number` (integer, nullable), check `number > 0` (validated separately), concurrent unique index `(season_id, number)`; run `bin/rails db:migrate` -- expand step of AD-28.
- [x] `packs/catalog/...` -- rename TIERS, add number to SEASON_DATA, numbering in PublishSeason and `number_published`, CardView/CardViews/CardDetail number and genre -- AD-5.
- [x] `lib/tasks/catalog.rake` -- the one-time backfill entry.
- [x] `config/locales/*.yml` -- tier names and error keys.
- [x] `app/`, `app/frontend/`, `script/card_art/generate.mjs` -- mechanical renames, asset renames.
- [x] `test/` -- fixture renames and numbers; update references; new tests: `test/packs/catalog/publish_season_test.rb` (numbers 1..n distinct, deterministic with injected random, rollback on failure writes none, `number_published` once/twice/draft/unknown, number frozen), `card_views_test.rb` and `card_detail_test.rb` (number, genre from tome or nil, `number_label` incl. nil and grouping), `schema_test.rb` (unique index and check), a rake task test, `card_component_test.rb` legendary.

**Acceptance Criteria:**
- Given the repository, when grepping `app packs config lib test script db/migrate` for the words steel, emerald, sapphire, amethyst, gold, then only non-tier uses remain (colour token `--color-gold`, "Golden Crown"/`golden-crown`, "golden angle", the pixel-art export's "steel caps"/"gold mark"/"gold emblem").
- Given a signed-in player opening a pack and the back-office card preview, when the pages render, then the cards show their tier colours and backs (`card--rarity-common` … `card--rarity-legendary`), and the French rarity names read Commune … Légendaire (system and controller tests pass).
- Given the card detail page of a card in a published season, when it renders, then it still works and its `CardView` carries the card-season's number and tome genre.

## Implementation Notes

- Rename done by a scripted word-boundary replace over `app packs config lib test script db/migrate` (lowercase, Capitalized, `STEEL` → `COMMON` for `RarityThresholds::COMMON`), excluding `script/pixel_art/export.mjs` and the `--color-gold`/`--color-on-gold` tokens; the sample title "…Amethyst Archive…" (capitalised, not matched by the AC grep) and `backs.GOLD` in `generate.mjs` (the retired mockup's variable name) are kept. The card.css sparkle comment now reads "golden light".
- Numbers are written by `number_card_seasons(ids, now)` (shared by both entries): one `update_all` on a relation joined to `unnest(ARRAY[ids]::bigint[], ARRAY[numbers]::integer[])`, which Rails turns into `UPDATE … FROM` on PostgreSQL. `updated_at` is set too.
- `CardViews::GENRE` holds the tome-genre subquery; `CardDetail` reuses it. `CardView#to_props` gains `number` and `genre` (not the label).
- Back-office samples: `NUMBERS` per tier (the epic's nil), `genre: nil`.
- Migrations: `20261005010000` (column + check `validate: false`), `20261005010001` (validate), `20261005010002` (concurrent unique index). Unrelated schema-dump churn on the steam check constraints (local PostgreSQL version) was reverted by hand.
- Rake test loads tasks in `setup`, outside `capture_io`: in the full parallel run the task list is empty in some workers while `game_benchmark.rake` was already loaded, so a reload warns on stderr.

## Plan Change Log

- 2026-10-05: the rake task lives in `packs/catalog/lib/tasks/catalog.rake`, not `lib/tasks/catalog.rake`: the `lib` package depends on no pack (AD-2), so packwerk refused `Catalog::*` references from it; pack-local tasks follow `packs/game/lib/tasks/game.rake`. The task test is `test/lib/catalog_number_seasons_task_test.rb`.

## Review Triage Log

### 2026-10-05 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 0, false 1, maybe-false 0
- findings:
  - `[false]` `[reject]` New files (renamed card backs, three migrations, `packs/catalog/lib/tasks/catalog.rake`, the rake test) untracked and old backs shown as unstaged deletions, so a `git commit -a` would lose them — the index state came from the orchestrator unstaging after building the review diff; the story commit stages the whole tree (`git add -A`), and `card.css` points at the new back files, which are present on disk.

## Design Notes

Shuffle shared by both entries:

```ruby
def number(ids) # ids sorted ascending
  numbers = (1..ids.size).to_a.shuffle(random: @random)
  # one UPDATE catalog_card_seasons SET number = v.n FROM unnest(ARRAY[...]::bigint[], ARRAY[...]::int[]) v(id, n) WHERE id = v.id
end
```

`number_published` locks `Season.published.where(number:).lock("FOR UPDATE").take`, returns `Failure(:no_published_season)` when nil, `Failure(:already_numbered)` when any of its card-seasons has a number, else numbers all of them. `number_label`: `ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: " ")`.

## Verification

**Commands:** (all must pass; `CHROME_BIN=/usr/bin/chromium` for system tests; the test database `gameble_test` is free to use)
- `bin/rails db:migrate` -- expected: schema.rb gains `number`, its check and unique index
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- no missing keys
- `npm run typecheck && npm run test:js` -- green
- `bin/rails test` -- green
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- green
- `rtk proxy grep -rnwE "steel|emerald|sapphire|amethyst|gold" app packs config lib test script db/migrate` -- only the non-tier uses listed in the AC

## Auto Run Result

**Summary:** the rarity tiers are `common`, `uncommon`, `rare`, `epic`, `legendary` (integers 1-5 unchanged) everywhere in code, assets and tests, named Commune … Légendaire / Common … Legendary in the locales. Card-seasons gain a nullable `number` (expand step): `Catalog::PublishSeason` numbers every card of a season 1..n by a `SecureRandom` shuffle, and its second entry `number_published` numbers a season published before numbers existed once, by the same shuffle (rake `catalog:number_seasons`). `Catalog::CardView` carries `number`, `number_label` ("S1 · #4 215", U+00A0 grouping) and `genre` (the card-season's tome genre in that season, nil in no tome). The face is unchanged (story 8.6); `dust_tier` stays (story 8.7).

**Files changed:**
- `packs/catalog/app/models/catalog/rarity.rb`, `card_season.rb`, `rarity_thresholds.rb` -- new code names; `number` frozen with the season data.
- `packs/catalog/app/operations/catalog/publish_season.rb` -- numbering shuffle, `number_published`, injectable `random:`.
- `packs/catalog/app/queries/catalog/card_view.rb`, `card_views.rb`, `card_detail.rb` -- number, label, tome genre.
- `packs/catalog/lib/tasks/catalog.rake` -- the one-time backfill task.
- `db/migrate/20261005010000..02_*`, `db/schema.rb` -- column, check (validated separately), concurrent unique index `(season_id, number)`.
- `config/locales/en.yml`, `fr.yml` -- tier names, back-office sample keys, two catalog error messages.
- `app/` (card component, strings, back-office card preview, helpers, React card and reveal, CSS), `app/frontend/images/card/back-*.svg` (renamed), `sprite.svg` (seal ids), `script/card_art/generate.mjs` -- renames.
- `packs/game/...` -- comments only.
- `test/` -- fixtures renamed and numbered; new tests for numbering, backfill, number label, tome genre, schema, rake task.

**Review:** quick lens, 1 finding, rejected as false (index state, not code). No patch, no deferral from review.

**Follow-up review recommended:** false (no patch applied: 0 high, 0 medium, 0 low).

**Verification:** `bin/rails db:migrate` (development, schema only), `bin/rubocop` clean, `packwerk validate` and `check` clean, `i18n-tasks missing` none, `npm run typecheck` ok, `npm run test:js` 114 passed, `bin/rails test` 1101 runs 0 failures, `bin/rails test:system` 62 runs 0 failures; the AC grep leaves only `--color-gold`/`--color-on-gold` and the pixel-art export's comments.

**Residual risks:** the backfill has not run on any real database (pending approval); published card-seasons may hold NULL numbers until it does, and the NOT NULL contract is a later migration (deferred-work). The numbering UPDATE inlines id and number arrays as SQL literals (a few hundred KB for a 20k-card season).
