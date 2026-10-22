---
title: 'An administrator curates the theme list in the back-office before publishing'
type: 'feature'
ticket: '2'
created: '2026-10-22'
status: 'built'
baseline_revision: 'cef5431088da85201a9c6e6c0463875abd7812af'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/catalog-and-rarity.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The theme list is a constant in code (`Catalog::Themes`): after an import, a new Steam tag changes nothing until a developer edits code, the French and English names live in locale files, and the draft can be published with the UFOs above the agreed share.

**Approach:** `Catalog` owns the themes (a key, a French and an English name) and the classification of each Steam tag (attached to a theme, or not a theme). A back-office page lists the tags the draft's cards carry, with their game count, so the administrator attaches, creates or dismisses them and edits the names. Publishing is refused while such a tag is unclassified or the UFOs exceed the share. The stored classification replaces the constant, seeded from it.

Decisions (author, 2026-10-22): a theme is a named group of tags, so several tags can point to one theme; classifying a tag means choosing an existing theme, creating one named after the tag (English tag name by default, French typed by hand), or "not a theme". Only the tags the draft's cards carry among their five most-voted must be classified before publishing, with a bulk "not a theme" for the rest of the page. The UFOs' limit stays the fixed 5 % of the code and blocks the publication.

## Boundaries & Constraints

**Always:**
- Writes go through operations that each publish one event; controllers read through queries; a Pundit policy per action; tokens, never ids, in URLs; every string and every failure code in `en.yml` and `fr.yml`.
- `Catalog` reads nothing from `Steam`; the Steam pack provides the tags with their game counts, and the web layer composes the page.
- A classification change reaches the draft only through the existing rescore; it never edits draft cards in place.
- A published season's cards, tiers, numbers and sets never change.
- Expand/contract migrations (strong_migrations), with the schema regenerated as the repository says.

**Never:**
- No change to the player screens beyond the card's genre showing the stored name.
- No change to rarity, import staging or the 5 % limit's value.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Attach a tag | "Roguelite" unclassified, theme Roguelike exists | The tag counts toward Roguelike once rescored; the page shows it classified | No error |
| New theme from a tag | A tag, English name defaulted, French typed | Theme created with both names; tag attached | Blank name: refused with the reason |
| Dismiss a tag | A tag marked "not a theme" | It stops blocking the publication | No error |
| Publish, tag left | A draft card carries an unclassified tag | Publication refused, the reason names the count | `:unclassified_tags` |
| Publish, UFOs high | UFOs above 5 % of the draft | Publication refused, the reason names the share | `:ufo_share_over_limit` |
| Rename a theme | New French or English name | Cards' genres show the new name | No error |
| Preview | Classification changed, no rescore yet | The page says a rescore is needed | No error |

</frozen-after-approval>

## Code Map

- `packs/catalog/app/models/catalog/themes.rb` -- the constant to replace (TAGS, `of`, `key?`, `keys`) and the seed source; `UFO_SHARE_LIMIT` stays.
- `packs/catalog/app/models/catalog/set_builder.rb`, `packs/steam/app/models/steam/card_mapping.rb`, `packs/steam/app/operations/steam/rescore_cards.rb`, `fill_card_sources.rb`, `unfilled_sources.rb`, `card_writing.rb` -- readers of the list; load the classification once per page or run, never per game.
- `packs/catalog/app/operations/catalog/publish_season.rb` -- add the two refusals before the write; its class doc lists the failures.
- `packs/catalog/app/queries/catalog/score_panel.rb`, `draft_preview.rb`, `app/views/back_office/seasons/_preview.html.erb` -- the preview's theme sizes and UFO share; one verdict per new refusal.
- `app/components/set_label.rb` -- `SetLabel.genre`: the locale lookup becomes the stored names, falling back to the humanized key.
- `app/controllers/back_office/roadmap_milestones_controller.rb`, `app/policies/back_office/roadmap_policy.rb`, `app/views/back_office/roadmap_milestones/index.html.erb` -- the curated-list conventions to copy; `config/routes.rb` back-office scope; the dashboard link.
- `packs/steam/app/models/steam/tag.rb`, `steam_apps.tag_ids` -- tags and per-game counts, to read as a Steam query.
- `test/support/catalog_seeds.rb` (`seed_sets_draft`: 10 % UFOs) -- lower it under 5 % so publish tests hold once the limit blocks.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/*` and `db/schema.rb` -- `catalog_themes` (token, key unique, English and French names) and `catalog_tag_classifications` (tag key unique, theme or not-a-theme), with a data seed from `Catalog::Themes::TAGS` and the locale names -- expand/contract, regenerated schema
- [ ] `packs/catalog/app/operations/catalog/` -- operations to create, rename and attach to a theme, and to dismiss tags (single and bulk) -- one event each
- [ ] `packs/catalog/app/models/catalog/themes.rb` and the readers above -- read the stored classification instead of the constant -- no per-game queries
- [ ] `packs/steam/app/queries/steam/` -- the tags of the draft's cards with their game counts -- the page's source
- [ ] `packs/catalog/app/operations/catalog/publish_season.rb`, `score_panel.rb`, `_preview.html.erb` -- the two refusals and their preview verdicts -- locale failure codes in both languages
- [ ] `app/controllers/back_office/`, policy, routes, views, dashboard link, locales -- the themes page and its forms
- [ ] `app/components/set_label.rb` -- stored names for the genre
- [ ] tests -- operations, queries, publish refusals, policy, controller, system test of the verify case, fixture under 5 %

**Acceptance Criteria:**
- Given Roguelite unclassified, when the administrator marks it a theme and rescores, then its games move into it in the preview and the UFOs' share drops.
- Given a new unclassified tag on a draft card, or UFOs above 5 %, when publishing, then it is refused with the reason.
- Given a renamed theme, when a card of it shows, then its genre shows the new name in the viewer's language.

## Implementation Notes

## Plan Change Log

## Review Triage Log

Quick review, one reviewer, 2026-10-22.

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| Genres use the first five tag ids then drop unknowns, stored tags are all deduplicated, readers take `first(5)` of them | medium | patch | `CardMapping.genres` takes `first(TOP_TAGS)` of tag ids before `tag_keys`; the stored list is the full deduplicated list; a sixth stored key can be read as one of the five |
| `@theme_names` unused in the themes index | low | patch | the view reads names through `SetLabel.genre` |
| `Themes.key?` has no caller | low | patch | grep over app, packs and lib finds only tests and the comment |
| Attach select has no blank option | medium | patch | the first theme is preselected, so a click without a choice attaches the tag |
| A theme left without tags still counts in `Themes.keys` and the public themes count | low | rejected | needs an admin to move the only tag of a theme; the fix adds a query and an operation |
| `SetLabel.genre` adds one query per request | low | rejected | the names table is read once per request by design; the plan allows the genre to show the stored name |
| A publish refusal recomputes the whole preview for its message | low | rejected | admin-only, a few queries; returning the values in the failure adds surface |
| French names in `db/default_themes.yml`, the seed migration and fixtures | medium | defer | the rule keeps French in `fr.yml`; stored theme names are data and the locale names the plan seeded from are removed; the author should confirm the exception |
| Race on a new theme's key | low | rejected | one administrator at a time; fails on the unique index |

## Design Notes

Check first which tag identifier the draft's cards store (`catalog_cards.tags` holds parameterized keys), since `Catalog` must decide "unclassified" without reading `Steam`: classify by that key, with the display name read from the Steam query on the page; if the cards do not store their five top tags, have the Steam pack hand `PublishSeason`'s caller the plain list.

## Verification

**Commands:**
- `bin/rails test test/packs/catalog test/packs/steam test/controllers/back_office test/policies` -- expected: green
- `bin/rails test test/system/<themes page file>.rb` -- expected: green
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run test:js`, `bundle exec i18n-tasks missing unused` -- expected: clean
