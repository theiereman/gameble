---
title: 'French copy puts a narrow no-break space before : ; ? ! and inside « »'
type: 'chore'
ticket: '14'
created: '2026-11-01'
status: done
baseline_revision: 'ded021fb11ba64766b8b94ed5924bd3ab41808de'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** French copy mixes spacing: about 230 values of `config/locales/fr.yml` put a plain space (one a U+00A0) before « : ; ? ! » and inside « », only 15 use the narrow no-break space U+202F the voice rules require, so a sign can wrap onto a line of its own and the copy reads unevenly.

**Approach:** Rewrite every such space in the French locale values to U+202F (the literal character, as the 15 compliant values already do), keep every key, value text and YAML layout otherwise byte-identical, and add a test that walks the French locale files and fails on a plain or no-break space before those marks or inside « », naming the key. Update the tests that assert the old French spacing.

## Boundaries & Constraints

**Always:** Change only the space character, line by line, in place: no key reordered, no quoting style changed, no line rewrapped (six parallel builds add keys to fr.yml and must merge cleanly). The loaded YAML tree after the change equals the tree before with the substitution applied to its string values. French `zero` plural forms stay. Test strings that spell the new space use the `\u202F` escape, not the invisible literal.

**Never:** No change to `en.yml`, to key names, or to wording. No space added where a mark has none (`steam:fill_card_...` in `errors.catalog.unfilled_sources` is a task name). No change to the post-deploy Discord announcement (`lib/`, not a view or mailer), to digit grouping (U+00A0 by rule), or to the static error pages (they hold no such mark). No planning ids.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Colon in prose | `"Filtres actifs :"` | `"Filtres actifs\u202F:"` | — |
| Guillemets | `"« %{query} »"` | `"«\u202F%{query}\u202F»"` | — |
| Leading separator | `announce_separator: " ; "` | `"\u202F; "` | — |
| Exclamation | `legendary_banner: "%{rarity} !"` | `"%{rarity}\u202F!"` | — |
| No-break space | the one U+00A0 before `:` | U+202F | — |
| Already compliant | the 15 U+202F values | unchanged | — |
| Regression | a fr value with `"Prix :"` or `"« x »"` | the check test fails, naming the key path and fragment | — |
| No space at all | `steam:fill_card` | not flagged, unchanged | — |

</intent-contract>

## Code Map

- `config/locales/fr.yml` -- 2341 lines; counts at baseline: plain space before `:` 136, `;` 60, `?` 16, `!` 1, `»` 15; plain space after `«` 15; U+00A0 before `:` 1. Comments (lines 1-2, and "French keeps the singular for 0…") are English and hold no such pattern. No block scalars. Substitute in the raw text: `[  ]([:;?!»])` → `\u202F\1`, `«[  ]` → `«\u202F`; verify by loading the YAML before and after.
- `config/locales/pagy/fr.yml` -- Pagy's French words; holds no such mark today, but the check covers it (glob `config/locales/**/fr.yml`).
- `test/config/` -- home of config checks (`legal_settings_test.rb`, `queue_config_test.rb`); the new test goes here as `test/config/french_typography_test.rb`.
- `test/controllers/library_controller_test.rb:1541` -- the model for spelling U+202F in a test: `"Aucun set trouvé pour «\u202FZZZ\u202F»."`.
- Tests asserting French text with the old spacing (found by grep; the Rails suite run finds any others): `test/controllers/{trades_controller,pages_controller,cards_controller,friend_profiles_controller,friends_controller,accounts_controller,public_profiles_controller,settings_controller,library_set,card_preview_tags}_test.rb`, `test/controllers/back_office/{players_controller,roadmap_milestones_controller}_test.rb`, `test/domains/catalog/upsert_card_identity_test.rb`, `test/domains/game/add_to_showcase_test.rb`, `test/system/card_detail_test.rb`. Tests reading copy through `I18n.t` need nothing.
- `app/frontend/lib/celebration.test.ts` -- its `fr` fixture (lines ~28-60) mirrors fr.yml wording ("As config/locales/fr.yml words them"); bring the fixture and its French expectations (e.g. lines ~344, 550-551) to U+202F with `\u202F` escapes so it keeps mirroring fr.yml.
- Not to change: `test/lib/post_deploy_hook_test.rb` and its hook (Discord text, out of scope); `app/frontend/lib/*.test.ts` fixtures that do not mirror fr.yml; `app/views/boosters/_card.html.erb` "? ? ?" (a placeholder glyph row, not French prose).

## Tasks & Acceptance

**Execution:**
- [x] `config/locales/fr.yml` -- apply the substitution in place; confirm the YAML tree equals the baseline tree with the substitution applied to string values, and `git diff --stat` shows only changed lines, no added or removed ones -- the design's French punctuation rule.
- [x] `test/config/french_typography_test.rb` -- new test: walk every string of `config/locales/**/fr.yml` and fail with the key paths and fragments of any space other than U+202F (plain space or U+00A0) before `: ; ? !` or `»`, or after `«`; plus a test feeding the detector sample strings (flagged: `"Prix : 1"`, `"« x »"`, `"Oui ?"`; not flagged: `"Prix\u202F: 1"`, `"steam:fill"`, `"https://x"`) -- the regression guard the ticket asks for.
- [x] the test files of the Code Map, and any other the Rails suite shows failing -- assert the new spacing with `\u202F` escapes.
- [x] `app/frontend/lib/celebration.test.ts` -- fixture and French expectations on U+202F.

**Acceptance Criteria:**
- Given `config/locales/fr.yml` and `config/locales/pagy/fr.yml`, when the new test runs, then it passes, and it fails naming the key when a plain space is put back before a `:` of any value.
- Given a French page with a colon or guillemets (the trade board's "Le profil de Lea est privé : échanges fermés.", the set search's "Aucun set trouvé pour « … »"), when it renders, then the text carries U+202F at those places.
- Given `bundle exec i18n-tasks missing` and `unused`, when run, then both are clean.

## Implementation Notes

- `config/locales/fr.yml`: substituted by a Ruby script on the raw text (`[ \u00A0]([:;?!»])` and `«[ \u00A0]` to U+202F), which first checked that the loaded YAML tree equals the baseline tree with the same substitution applied to its strings, and that the line count is unchanged. Result: 180 lines changed (180+/180-), 244 spaces replaced (137 `:` including the U+00A0 one, 60 `;`, 16 `?`, 1 `!`, 15 `»`, 15 after `«`); the file now holds 263 U+202F (19 before). No comment line touched; `steam:fill_card_...` untouched; `pagy/fr.yml` held nothing to change.
- `test/config/french_typography_test.rb`: walks every string of `config/locales/**/fr.yml`, reports `file key.path: "fragment"` (up to 12 characters before the mark); a second test feeds the detector the sample strings of the plan, plus a U+00A0 case and an array value (path `e.0`). Planting `"Cartes uniques :"` back made it fail with `config/locales/fr.yml fr.library.status.label: "rtes uniques :"`; restored byte-identical.
- Ruby tests brought to `\u202F` escapes (from the full-suite failures plus a literal-only rewrite script over the Code Map files, then reviewed line by line): accounts, back_office/players, back_office/roadmap_milestones, boosters (the `announceSeparator` value), card_preview_tags, cards, friend_profiles, friends, invitations, library, library_set, packs_chips, packs, pages, public_profiles, settings, trades controllers; `test/domains/game/add_to_showcase_test.rb`; `test/integration/shell_test.rb`; `test/system/card_detail_test.rb`. Test names (`test "... « le 1er mars 2026 » ..."`) left alone.
- Left as is: `test/domains/catalog/upsert_card_identity_test.rb` ("Portal 2 : Remasterisé" is a Steam title fed in and read back, not locale copy; it passes); `test/system/booster_test.rb` "? ? ?" (placeholder glyph row); `test/lib/post_deploy_hook_test.rb` (Discord text).
- `app/frontend/lib/celebration.test.ts`: fixture `announceTier`, `announceComplete`, `announceFolded`, `announceSeparator` and the French expectations moved to `\u202F`; Prettier rewrapped one expectation.
- Verified: `bin/rails test` 3814 runs, 0 failures, 0 errors (two earlier runs had environmental errors only: Postgres connection refused and a Vite manifest being rebuilt mid-run, none French-related); the 11 French-reading system test files 121 runs green; `npm run test:js` 756 green; `npm run format:check`, `bin/rubocop`, `script/check_planning_references`, `script/check_file_sizes`, `i18n-tasks missing` and `unused` clean.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 0, false 1, maybe-false 0
- findings:
  - `[false]` `[reject]` `app/frontend/lib/booster_motion.test.ts:104-114` copies the `revealSummary` wording of fr.yml with the old plain space (filed by the reviewer as outside the plan, not a defect) — no bad outcome: the test feeds its own fixture strings to the function under test and never reads fr.yml, so its results do not depend on the locale's spacing, and the file does not claim to mirror fr.yml as `celebration.test.ts` does.

## Design Notes

Tool parameters are JSON: a `\u202F` typed into a Write or Edit call lands as the invisible literal. Do the fr.yml substitution with a script (`chr(0x202F)`), type `\\u202F` in a tool call to get the escape in a test, and confirm with `grep -cP '\x{202F}'` (literals) and `grep -c '\\u202F'` (escapes): fr.yml takes literals, tests take escapes.

## Verification

**Commands:**
- `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w28_14 CHROME_BIN=/usr/bin/chromium` -- before any rails command
- `bin/rails test test/config/french_typography_test.rb` -- expected: pass; and fail when one plain space is planted back (then restored)
- `bin/rails test` -- expected: pass
- `bin/rails test test/system/card_detail_test.rb test/system/feed_test.rb test/system/hub_test.rb test/system/landing_roadmap_test.rb test/system/library_test.rb test/system/moderation_test.rb test/system/personalization_test.rb test/system/public_profile_test.rb test/system/roadmap_page_test.rb test/system/settings_test.rb test/system/shell_test.rb` -- expected: pass (the system tests that read French)
- `npm run test:js`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/rubocop`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check` -- expected: pass

## Auto Run Result

- **Summary:** every French locale value now puts U+202F, the narrow no-break space, before `: ; ? !` and inside « »: 244 spaces replaced in place in `config/locales/fr.yml` (137 before `:`, one of them a U+00A0; 60 `;`, 16 `?`, 1 `!`, 15 before `»`, 15 after `«`) on 180 lines, no line added, removed, reordered or rewrapped, the loaded YAML tree equal to the baseline's with the substitution applied. A new test fails, naming file, key path and fragment, on any plain or no-break space at those marks in `config/locales/**/fr.yml`. Views, components, mailers and the static error pages hold no French text with these marks, so nothing else changed.
- **Files changed:**
  - `config/locales/fr.yml` -- U+202F at the marks.
  - `test/config/french_typography_test.rb` -- new: the locale walk and the detector's sample cases.
  - 17 files under `test/controllers/` (accounts, back_office/players, back_office/roadmap_milestones, boosters, card_preview_tags, cards, friend_profiles, friends, invitations, library, library_set, packs_chips, packs, pages, public_profiles, settings, trades), `test/domains/game/add_to_showcase_test.rb`, `test/integration/shell_test.rb`, `test/system/card_detail_test.rb` -- French assertions on the new spacing, written with the `\u202F` escape.
  - `app/frontend/lib/celebration.test.ts` -- its fixture, which mirrors fr.yml, and its French expectations on U+202F.
- **Review:** quick lens, 1 finding: 0 patched, 0 deferred, 1 rejected (false: the `booster_motion.test.ts` fixture never reads fr.yml).
- **Follow-up review recommended:** false (patched: high 0, medium 0, low 0).
- **Verification:** `bin/rails test` 3814 runs, 0 failures, 0 errors (a first run with default parallelism hit Postgres "too many clients" from the parallel builds; rerun with `PARALLEL_WORKERS=3` clean); the 11 French-reading system test files (card_detail, feed, hub, landing_roadmap, library, moderation, personalization, public_profile, roadmap_page, settings, shell) 121 runs, 0 failures; `npm run test:js` 756 passed; `bin/rails test test/config/french_typography_test.rb` passes and failed on a planted plain space; `i18n-tasks missing` and `unused` clean; `bin/rubocop`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bin/rails zeitwerk:check` clean.
- **Residual risks:** parallel builds that add French values with a plain space before these marks will fail `french_typography_test.rb` once merged (the intended guard), and a branch editing one of the 180 changed lines will conflict. The bundled fonts (VT323, JetBrains Mono) have no U+202F glyph, so browsers draw that space from a fallback font; it stays a narrow, unbreakable blank. The post-deploy Discord announcement in French keeps plain spaces (not a view or mailer).
