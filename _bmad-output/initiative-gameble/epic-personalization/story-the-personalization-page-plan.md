---
title: 'The Personalization page'
type: 'feature'
ticket: '1'
created: '2026-10-28'
status: 'built'
baseline_revision: '234ff21a550370af83a76a1315d8492a380ad650'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The profile showcase sits in the settings' side column, where it does not belong, and the card back and title pickers have no page to live on.

**Approach:** A Personalization page behind the player menu (and the phone's PLUS list), with a section pattern the pickers fill, takes the showcase summary from the settings; the settings keep language, visibility, reduced motion, session, data, account and legal.

## Boundaries & Constraints

**Always:** GET never writes; a Pundit policy; both locales; no database ids; no style attribute.

**Never:** Add either picker or a menu theme (their own entries); change the settings rows.

</frozen-after-approval>

## Implementation Notes

Oneshot: a read-only page (controller, policy, route, view, two menu links, locale keys), the showcase part of the profile summary and its CSS moved, tests moved and added.

## Verification

**Commands:**
- `bin/rails test test/controllers/personalizations_controller_test.rb test/controllers/settings_controller_test.rb` -- expected: pass
- `bin/rails test test/system/personalization_test.rb`, `bundle exec i18n-tasks missing unused`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run format:check`, `npm run lint:css` -- expected: clean

Built: `PersonalizationsController#show` (route `/personalization`, `PersonalizationPolicy`), a `personalizations/_section` partial the pickers fill, the showcase section, links in the player menu and the PLUS list, the tab bar keeping PLUS lit, the showcase and its CSS out of the settings summary, `personalizations.show.*` and the menu keys in both locales.

## Review Triage Log

No independent review lens ran: this worker could not launch subagents. Read the diff myself against AGENTS.md (no write on GET, policy present, no ids or style attributes, no comments, both locales, no locale reformat): no finding. The full Ruby suite (3213 runs, 0 failures), the personalization and settings system tests, i18n-tasks, packwerk, zeitwerk, Prettier, Stylelint, file sizes and planning references pass.
