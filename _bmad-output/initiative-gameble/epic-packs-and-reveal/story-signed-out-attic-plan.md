---
title: 'Signed-out attic'
type: 'feature'
ticket: '8'
created: '2026-10-02'
status: done
baseline_revision: 'de6247a53c399a70acd6377b9f57cb4b3c4016c1'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A signed-out visitor sees the chest without a way in, and no daily bonus panel at all, while CAP-18 says a visitor sees everything that needs no account and is led to Steam sign-in when acting (epic 3, R9).

**Approach:** Show a visitor the chest and the daily bonus panel as they would look, each with a "Sign in with Steam to …" button that starts the existing Steam sign-in (the OmniAuth POST form) and brings the visitor back to the attic; keep the server refusing a visitor's opening or collection whatever the client sends.

## Boundaries & Constraints

**Always:**
- The visitor's chest shows "Open a pack" and the panel "Collect the daily booster" as buttons of a form posting to the existing Steam sign-in path (the one the attic's sign-in button uses), with the return path set to the attic, in `fr` and `en`; no pack count or countdown for a visitor.
- `POST /<locale>/packs` and `POST /<locale>/daily-bonus` from a visitor stay refused (Pundit, `ApplicationController#refuse`), writing nothing — asserted by tests.
- The panel is shown to a visitor only when a season is published (the same condition as for a player, minus the claim).

**Never:** no new sign-in path; no visitor state stored; no change for signed-in players.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor attic | signed out, season published | chest and panel with sign-in buttons; no count, no countdown | — |
| No season | signed out, nothing published | chest with its sign-in button, no panel | — |
| Visitor POSTs | open or collect | refused, nothing written | policy |
| Sign in from the chest | button pressed (OmniAuth test mode) | signed in, back on the attic with the player's chest | — |

</frozen-after-approval>

## Code Map

- `app/views/pages/home.html.erb` (`bonus_panel` local from 3.7), `app/views/sessions/*` or the attic's existing sign-in button, `app/controllers/sessions_controller.rb` (return path), `test/controllers/pages_controller_test.rb`, `test/system/attic_test.rb`.

## Implementation Notes

Oneshot: views, copy and tests; the server refusals already exist (3.1, 3.7). `PagesController#home` sets `@season_published` for a visitor; both visitor buttons are the status band's sign-in form (`/auth/steam`, `origin` the attic path, `turbo: false`). New system test `test/system/signed_out_attic_test.rb`.

## Plan Change Log

- Build (orchestrator, with the author's delegation): the visitor buttons read "Enlist through Steam to open a pack" / "… to take it" ("S'enrôler via Steam …"), in the voice of the existing sign-in button ("Enlist through Steam"), rather than the plan's literal "Open a pack" / "Collect the daily booster"; the intent — a button that starts the Steam sign-in — is unchanged.

## Review Triage Log

- low, change log: visitor labels differ from the plan's literal wording — deliberate, in the sign-in button's voice; recorded above.
- low, patch: French said "par Steam" while the sign-in button says "via Steam" — now "via".
- low, patch: the view comment claimed the panel's condition lived in the local alone — rewritten.
- low, patch: the visitor opening test only counted opened packs — now packs, opened packs and holdings; a French visitor test added.
- low, rejected: tests not in the Code Map's files — coverage complete; the new system test file is part of the commit.

## Verification

**Commands:**
- `bin/rails test && bin/rails test:system` -- expected: all green.
- `bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.
