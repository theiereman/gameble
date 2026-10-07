---
title: 'Daily booster panel and settings screen with one motion switch'
type: 'feature'
ticket: '4'
created: '2026-10-07'
status: 'built'
baseline_revision: '9823293ae75561ad358f80b57a6ca1047bad1c27'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The hub's daily booster panel vanishes once collected and has no arc to the packs chip; there is no settings screen, and "Animations réduites" has no stored value nor one switch read by CSS, Stimulus, islands and View Transitions.

**Approach:** Complete the daily panel on the existing claim path, add a player settings screen (language, motion, sign-out), and store motion on the player, mirrored in a cookie, rendered server-side as `html[data-motion]` and read by everything through that one switch.

## Boundaries & Constraints

**Always:** CAP-16 rules stay server-side (3 cards, once per UTC day, refused at a full reserve). The motion preference follows the system by default. The `view-transition` meta renders only when motion is allowed (AD-27). GET requests stay read-only (AD-11); writes are POST or PATCH.

**Decided by the author (2026-10-07):** signed out, the hub shows the invitation that leads to the sign-in panel (`DESIGN.md` wins over `EXPERIENCE.md` line 152). After a claim the panel stays with "RÉCUPÉRÉ" and the countdown to 00:00 UTC. The claim answers in Turbo Stream, falling back to the redirect without JS, so the arc runs from `turbo:before-stream-render`. Motion is SYSTÈME / OUI / NON, stored nullable on the player (empty follows the system) and mirrored in a cookie written on change and at sign-out; a visitor who was never signed in follows the system, with no control.

The ticker does not exist yet (epics 5 and 6): this story covers its hooks and every existing loop only.

**Never:** No visibility, export, delete or legal page (epic 7). No card-back picker (epic 9). No LIVE ticker build (epics 5 and 6). Do not rebuild the claim operation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Claim | Signed in, reserve below 10, not claimed today | 3-card pack added, arc to the packs chip, panel shows collected with countdown | No error expected |
| Already claimed | Claimed today | Refused, panel shows the countdown to 00:00 UTC | Alert from `failure_message` |
| Full reserve | Reserve at 10 | Claim disabled, "RÉSERVE PLEINE", nothing lost | Refused server-side too |
| Motion on | Setting or system reduced | No loop, ticker hooks still, no view transitions, crossfades only | Cookie read when signed out |

</frozen-after-approval>

## Code Map

- `app/views/pages/_daily_booster.html.erb`, `home.html.erb`, `app/frontend/styles/hub.css` -- panel states; `home.html.erb` hides the panel once collected today.
- `app/controllers/daily_bonuses_controller.rb`, `packs/game/app/operations/game/collect_daily_bonus.rb` -- claim path to reuse.
- `app/frontend/controllers/countdown_controller.ts`, `app/frontend/lib/events.ts` (`gameble:bank-changed`) -- reuse for the countdown and the arc.
- `app/frontend/lib/motion.ts`, `starfield_controller.ts` (checks once at line 78) -- the switch and its live reads.
- `app/views/layouts/application.html.erb`, `layouts/_head.html.erb` -- `data-motion` and the view-transition meta.
- `app/views/shell/_player_chip.html.erb`, `_tab_bar.html.erb` -- entry point to settings.
- `packs/accounts/` (`sign_in.rb` as model), `db/migrate` (latest 20261006141010) -- new column and operation.
- CSS pairs `prefers-reduced-motion` + `html[data-motion=reduced]`: `shell.css`, `card.css`, `booster.css`, `card-detail.css`, `hub.css`.
- Tests: `test/system/{daily_bonus,hub}_test.rb` (the panel-gone assertion changes), `test/controllers/{daily_bonuses,sessions}_controller_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_reduced_motion_to_accounts_players.rb`, `db/schema.rb` -- nullable `reduced_motion` boolean -- stored preference
- [x] `packs/accounts/app/operations/accounts/update_settings.rb` -- sets the motion value -- modelled on `sign_in.rb`
- [x] `config/routes.rb`, `app/controllers/settings_controller.rb`, `app/policies/settings_policy.rb` -- `show` and `update` for a signed-in player; PATCH writes Accounts and the cookie -- GET stays read-only
- [x] `app/controllers/application_controller.rb` -- one helper resolving motion (player, else cookie, else system) -- single source for the layout
- [x] `app/views/layouts/application.html.erb`, `layouts/_head.html.erb` -- `data-motion="reduced"` when forced; view-transition meta only when motion is allowed -- AD-27
- [x] `app/controllers/sessions_controller.rb` -- write the motion cookie from the player at sign-out -- a signed-out hub keeps it
- [x] `app/views/settings/show.html.erb`, `app/frontend/styles/settings.css`, `config/locales/{fr,en}.yml` -- LANGUE, ANIMATIONS RÉDUITES segments, SE DÉCONNECTER, copy deck wording -- R5
- [x] `app/views/shell/_player_chip.html.erb`, `_tab_bar.html.erb` -- link to settings, PLUS row on phone -- entry points
- [x] `app/views/pages/_daily_booster.html.erb`, `home.html.erb`, `hub.css`, `Game::BankSummary` -- collected state with countdown and bar to midnight UTC, full state in orange -- R4
- [x] `app/controllers/daily_bonuses_controller.rb`, `app/views/daily_bonuses/create.turbo_stream.erb` -- Turbo Stream response with redirect fallback
- [x] `app/frontend/controllers/bonus_arc_controller.ts` -- 480ms arc (520ms phone) from the panel to the packs chip or BOOSTER tab, skipped when motion is reduced, dispatches `gameble:bank-changed`
- [x] `app/frontend/lib/motion.ts`, `starfield_controller.ts` -- read the switch at the moment of use, live when the attribute changes
- [x] CSS audit -- every looping animation covered by the media query and `html[data-motion=reduced]`; the ticker's hooks (`.live-marker__dot`, `--space-ticker-height`) covered
- [x] Tests -- Accounts operation, settings controller and policy, cookie precedence, panel states (the "panel gone" assertions change), arc skipped under reduced motion, system test forcing `data-motion` and checking `getAnimations()`

**Acceptance Criteria:**
- Given a player claims, when the reserve is below 10, then they get 3 cards once a day and are refused at 10.
- Given motion is reduced, signed in or out, then no loop or transition runs and no view-transition meta renders.
- Given a player signs out with motion set, then the signed-out hub follows the cookie.
- Given the claim is made, then the panel shows RÉCUPÉRÉ and the countdown instead of disappearing.

## Implementation Notes

- Motion semantics: reduced motion is an OR of the server switch (`html[data-motion=reduced]`: the player's OUI, else the cookie) and the system's preference. NON (an explicit no) and SYSTÈME both leave the system's preference in charge; NON is stored (and mirrored as the `full` cookie) so a later story can let it override the system.
- A signed-in player who follows the system (empty setting) takes a stale motion cookie if there is one (player, else cookie, else system); the cookie is rewritten at each change and at sign-out, so it only differs across two players of one browser.
- The PLUS tab now opens a PLUS screen (`pages#more`, Amis, Fil and Succès disabled, "Profil et paramètres" a link): the phone's only entry to settings besides the player menu. The player chip keeps its popover and gains a "Paramètres" item.
- The claim's Turbo Stream replaces the panel, the packs chip, menu 01 and the empty showcase's action, and appends a toast. The settings form and the sign-out are full page loads (Turbo does not re-render `<html>` attributes).
- `Game::BankSummary` gained `bonus_collected` and `next_bonus_at`; the countdown controller gained `hours`, `total` and a `bar` target, and no longer leaves a Turbo Stream answer counted as a pending visit.
- The test suite is run with `bin/rails test` and `bin/rails test test/system`; `bin/rails test:system` loads libvips on this machine and aborts.

## Plan Change Log

## Review Triage Log

Pass 1 (quick):

| Verdict | Route | Finding and evidence |
|---|---|---|
| medium | patch | A signed-in player on SYSTÈME is forced to reduced motion by a stale cookie (`ApplicationController#motion_setting` falls back to the cookie when `reduced_motion` is nil); the settings screen then shows SYSTÈME pressed while `data-motion=reduced` is set. Fix: signed in, only the player's value counts; the cookie serves visitors. |
| medium | patch | The phone's PLUS tab leads visitors to a "Profil et paramètres" row that bounces to the hub (`SettingsPolicy#show?` needs a player). Fix: show that row only to a signed-in player. |
| low | rejected | The view-transition meta still renders when only the OS asks for reduced motion: the server cannot read that preference, and `shell.css` already stops every `::view-transition-*` animation under the media query; a fix needs client code. |
| low | rejected | Missing cases in `sessions_controller_test.rb` and `hub_test.rb`: the sign-out cookie is covered in `settings_controller_test.rb` and the collected state in `test/system/daily_bonus_test.rb`, `countdown_test.rb` and `pages_controller_test.rb`. |
| low | rejected | `bonus_arc_controller.ts#arrived` may dispatch `gameble:bank-changed` before the chip is replaced; the replace then applies the same count, so no visible defect. |

## Verification

**Commands:**
- `bin/rails test` and `bin/rails test:system` -- expected: pass
- `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `npm run typecheck`, `npm test` -- expected: pass
