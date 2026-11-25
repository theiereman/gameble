---
title: 'Back-office market settings explain themselves behind an info button'
type: 'feature'
ticket: ''
created: '2026-11-25'
status: 'built'
baseline_revision: 'c34297c0d8a94eb5084a48eb113d4c5e9aec3b1d'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/docs/design-system.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The administrator forgets what each market setting does and how it acts on the game; the settings screen shows only a label, bounds and when a change applies.

**Approach:** Put an "i" button beside each setting's label that opens a small popover explaining, in two to four plain sentences, what the setting controls, how the game uses it, and what raising or lowering it does.

## Boundaries & Constraints

**Always:** One help text per single field (29 labels) except the slot prices, which share one help on the slots group legend; one help per rarity-grid row header (5 rows). Each text is written from what the code actually does with the setting (read its readers in `app/domains/game/`), never guessed; en and fr both, under a new `back_office.markets.settings.help.<field|row|group>` tree. Use the native `popover` attribute with a `<button type="button" popovertarget>` like the shell popovers, no new script; the button has an accessible name ("About <label>"), the popover is reachable by keyboard and closes with Escape. No `style` attribute in server HTML.

**Never:** Do not reuse or change `back_office.markets.settings.hints.*` or the computed hint line. Do not move or rename fields, nor change validation or the `labelled_by` wiring of the grid inputs. No help on screens other than the market settings.

</frozen-after-approval>

## Code Map

- `app/views/back_office/markets/_settings.html.erb` -- "By rarity" fieldset (l.25-28), loop over `SINGLE_GROUPS` (l.30-39), each a fieldset with `<legend>`: slots legend gets the group help.
- `app/views/back_office/markets/_settings_field.html.erb` -- label at l.7 (skipped when `labelled_by`): add the "i" button after the label for single fields, skipped for slot fields.
- `app/views/back_office/markets/_settings_rarities.html.erb` -- row header `<th>` l.15: add the "i" button inside it.
- `app/models/back_office/market_settings_form.rb:8-23` -- `SINGLE_GROUPS`, `MOMENTS`: the full field list.
- `app/domains/game/app/models/game/market/settings*.rb` and `Game::Market::SettingsRules` -- the settings and their bounds; grep each column name across `app/domains/game` to learn its effect before writing its help.
- `app/views/shell/_bell.html.erb:3,8`, `app/views/library/_status.html.erb:1` + `app/views/shell/_rarity_legend.html.erb` -- native popover pattern and `shell-popover` class to reuse.
- `config/locales/en.yml` ~718-790 / `fr.yml` same tree -- `back_office.markets.settings.*`.
- Back-office stylesheet for the market settings (grep `market-settings__`) -- style the small round "i" button and the popover width.
- Tests: the back-office markets controller test (grep `back_office/markets` under `test/controllers`).

## Tasks & Acceptance

**Execution:**
- [ ] new partial `app/views/back_office/markets/_settings_help.html.erb` (locals: `key:`, `label:`) -- the button + popover, unique ids from the key.
- [ ] `_settings_field`, `_settings_rarities`, `_settings` -- render it beside each label, row header and the slots legend.
- [ ] `en.yml`, `fr.yml` -- 34 help texts written from the code.
- [ ] stylesheet -- button and popover look, within the size limits.
- [ ] controller test -- the page renders one help button per single non-slot field, per row and for slots, each with a matching popover, and an i18n check that every help key exists in both locales.

**Acceptance Criteria:**
- Given an administrator on the market settings, when they press the "i" beside "Commission", then a popover explains what the commission does, and Escape closes it.
- Given a screen reader user, then each "i" button is announced with the setting's name.

## Verification

The implementation agent writes the tests but does not run any suite; the main session runs these once.

**Commands:**
- `bin/rails test test/controllers/back_office` -- expected: green
- `bundle exec i18n-tasks missing && npm run lint:css && npm run format:check && script/check_planning_references` -- expected: clean

## Review Triage Log

Pass 1 (quick): high 0, medium 0, low 4, false 1, plus one pre-existing.
- low, patch — `help.*` missing from `config/i18n-tasks.yml` ignore_unused like its sibling trees. Added.
- low, patch — the popover had no role or name, unlike the shell popovers it copies. Added `role="dialog"` and `aria-labelledby` on its title.
- low, patch — the help text inside the legend and row headers inherited the label tracking. `letter-spacing: normal` on the popover.
- low, rejected — the "i" inside the slots legend and the grid's row headers adds "About …" to their accessible names; the fix means restructuring the grid headers, and only administrators meet it.
- defer — the existing labels of `feed_threshold_multiple` and `unusual_maximum_multiple` say "multiple of the average" while the code multiplies the rarity minimum price and the current price; the help texts tell the truth, so the labels contradict them.
- false — "34 help texts" in the tasks is an arithmetic slip; the frozen rule (slots share one help) gives 23, which is what shipped.
