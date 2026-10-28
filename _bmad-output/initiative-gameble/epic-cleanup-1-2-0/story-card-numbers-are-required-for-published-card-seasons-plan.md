---
title: 'Card numbers are required for published card-seasons'
type: 'chore'
ticket: '1'
created: '2026-10-28'
status: 'built'
baseline_revision: '0763d9cee6bf068012dd5fd7127f7585934fbe6d'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `catalog_card_seasons.number` is nullable since its expand step, so `CardView#number`, `number_label` and the views keep a nil branch for seasons published before the numbering existed.

**Approach:** Contract step: a check that a card-season with a rarity (which is how a published one is told apart from a draft) has a number, added without validation then validated in a second migration, and the nil cases removed from the code.

</frozen-after-approval>

## Implementation Notes

Oneshot: one constraint in two migrations plus removing nil branches, well under 100 lines.

- A published card-season is told apart from a draft one by its rarity: `Catalog::PublishSeason` sets rarity on every card-season of the season at publication, and numbers them in the same step; a draft has neither.
- The validating migration does not run the numbering itself (a migration must not call the operations of the app). It fails first with a message naming `bin/rails catalog:number_seasons` when a published card-season has no number, so a database where the backfill has not run stops with an instruction instead of a bare Postgres error. The backfill must have run on staging, production and development before this deploys; put it in the pull request's deploy notes.
- `TypeScript number: number | null`: no card type with a nullable `number` exists in `app/frontend`; nothing to remove there.

- Decision: the validating migration fails first with a message naming `bin/rails catalog:number_seasons` instead of numbering the seasons itself, so it never runs app code. `catalog:number_seasons` stays, as it is what a database still carrying unnumbered published seasons runs before this deploys.
- Exposed bug fixed: `Catalog::PublishSeason#write_season_data` set the rarities before numbering the card-seasons, which the check refuses; it numbers first now.
- `db/schema.rb` is regenerated as AGENTS.md says. The regeneration also corrected the dump of `game_set_tiers_reached_by_values_check`, which the previous ticket had committed in another form: CI would have reported that drift.
- The back-office card preview's epic specimen carried no number; it has one now.
- Tests: a new helper `rate` (`test/support/rated_cards.rb`, included in every test case) numbers card-seasons before giving them a rarity, as publishing does; about thirty fixtures that inserted a rarity without a number use it or pass `number:`. The tests that built an unnumbered published card (nil number on the card face, label, position line, glitter seed, showcase line) are removed or changed, since the state no longer exists; a schema test covers the new constraint. The numbering task and `number_published` tests clear the rarity along with the number to build their unnumbered season.

## Review Triage Log

No independent review: a fork cannot spawn reviewers. Self-review of the diff: the nil branches removed (`number_label`, the card face, the detail header and position line, the glitter seed) have no caller left that can pass a nil number, as `CardViews`, `CardDetail` and the back-office specimens read published card-seasons only or give a number. The constraint is `rarity IS NULL OR number IS NOT NULL`: a draft holds neither. No finding to defer.

## Verification

**Commands:**
- `bin/rails test` -- result: 3244 runs, 0 failures; system tests of card detail, library, collection set, personalization, public profile, friends, booster screen, trade board: green
- `npm run typecheck`, `npm run test:js` (723 passed), `npm run format:check`, `npm run lint:css` -- expected: green
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing` -- expected: clean
- `script/check_file_sizes`, `script/check_planning_references` -- expected: clean
