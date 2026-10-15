---
title: "Player screens show times in the player's own time zone"
type: 'feature'
ticket: '52'
created: '2026-10-14'
status: 'built'
baseline_revision: 'b121dfef6003b002a61fd4d9272b0d8b66d54f24'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Player screens print clock times in UTC and say « UTC » (next booster, daily booster messages, feed entries, last export, how-it-works), which forces a player to convert in their head.

**Approach:** The server keeps sending each instant as UTC ISO 8601 in a `<time datetime>` element whose text is a locale-neutral UTC fallback; one Stimulus controller rewrites that text in the browser's time zone, formatted for the page's locale with `Intl.DateTimeFormat`. Server renders, Turbo Stream responses and broadcasts all go through it. Game rules stay in UTC.

## Boundaries & Constraints

**Always:** The time zone is the browser's (`Intl`); nothing is stored on the player and no migration. An instant is shown as its localized date and time, with no relative word (« demain »). The day still changes at midnight UTC and the week starts Monday 00:00 UTC; countdowns keep counting to the same instant. Without JavaScript the UTC fallback still reads. No « UTC » remains in a player-facing string of en.yml or fr.yml; the fallback's « UTC » comes from the helper.

**Never:** Change the back-office's times (`back_office/import_runs/_time.html.erb` and its callers), the export file's name or the timestamps inside the export. A relative-time library or a stored time zone. A time computed per viewer on the server (broadcasts are per locale).

**Decisions (author, 2026-10-14):** the browser's time zone; the back-office keeps UTC; localized date and time, no relative word; the export file keeps its UTC dates.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Next booster, Paris | instant 2026-10-15T00:00Z, fr | « 15 oct., 02:00 » | No error expected |
| Local date differs | 2026-10-14T23:30Z in Europe/Paris | the 15th, not the 14th | No error expected |
| Other zone | same instant in America/New_York | « 14 oct., 20:00 » | No error expected |
| English page | en | « Oct 15, 02:00 » style | No error expected |
| No JavaScript | any | the fallback « 2026-10-15 00:00 UTC » | No error expected |
| Feed broadcast | entry prepended by Turbo Stream | rewritten like the server-rendered ones | No error expected |
| Day and week rule | how-it-works | « à 02:00, heure locale »; the week's start as a local weekday and time (« lundi 02:00 », « dimanche 20:00 » in New York) | No error expected |

</frozen-after-approval>

## Code Map

- Locale keys with UTC or midnight (en and fr): `shell.packs.next_at`, `pages.home.daily.next_at`, `pages.how_it_works.daily.once`, `pages.how_it_works.goal.week`, `boosters.island.next_at`, `settings.show.data.time_format`, `feeds.show.time_format`, `daily_bonuses.create.collected`, `errors.game.already_collected`. The two `time_format` strftime keys go; the sentences take a `%{time}`.
- Server sites: `app/views/shell/_packs_chip.html.erb:23`; `app/views/pages/_daily_booster.html.erb:24,30` (next change from `Game::BankSummary` `next_bonus_at`); `app/views/feeds/_entry.html.erb:4` (also broadcast by `app/jobs/live_feed_job.rb` through `live_streams/_feed.turbo_stream.erb`); `app/views/settings/show.html.erb:76-92`; `app/views/pages/how_it_works.html.erb:52,60`.
- Toasts: `DailyBonusesController#create` builds the message (success `t(".collected")`, refusal `Game::CollectDailyBonus.failure_message`) for `daily_bonuses/create.turbo_stream.erb` (ToastComponent) and for the no-JS flash redirect. Through Turbo Stream the toast's time is a local-time element; the flash carries the plain UTC fallback.
- New helper (e.g. `app/helpers/local_time_helper.rb`): `local_time_tag(time, style)` renders `<time datetime=ISO data-controller="local-time" data-local-time-style-value=style>` with the fallback `YYYY-MM-DD HH:MM UTC` (style `time`: `HH:MM UTC`).
- New `app/frontend/lib/local_time.ts` (pure, tested) and `app/frontend/controllers/local_time_controller.ts` (thin; auto-registered by `entrypoints/application.ts` glob). Locale from `document.documentElement.lang`. Styles: `datetime` (day, short month, time: chip, booster, toasts, feed), `date-time-year` (settings), `time` (day rule), `weekday-time` (week rule).
- Booster island: `app/frontend/lib/booster.ts:201-206` `utcTime` and `BoosterView.tsx:130,278` use the lib's `datetime` style instead.
- Settings export: `data_export_controller.ts:132-136` `showTime()` and `lib/data_export.ts:71-81` `formatUtc` are replaced by the lib; drop the `timeFormat` value.
- Tests asserting today's UTC text: `test/integration/shell_test.rb:140`, `test/controllers/packs_controller_test.rb:251,269,295`, `daily_bonuses_controller_test.rb:44,97`, `pages_controller_test.rb:243-257`, `settings_controller_test.rb:63,73-97`. Vitest: `lib/*.test.ts` beside the module, node environment, pass `timeZone` explicitly.
- Do not touch: `countdown_controller.ts` (durations), `daily_bonus_claim.rb`, `weekly_goal.rb`, back-office views.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/local_time.ts` + `.test.ts` -- format an ISO instant for a locale, zone and style; tests cover every matrix row
- [x] `app/frontend/controllers/local_time_controller.ts` -- rewrite the `<time>` text on connect
- [x] `app/helpers/local_time_helper.rb` + test -- the tag and its UTC fallback
- [x] Views, `DailyBonusesController`, toasts -- every site in the Code Map uses the tag
- [x] `lib/booster.ts`, `BoosterView.tsx`, `data_export_controller.ts`, `lib/data_export.ts` + tests -- the lib replaces the UTC formatting
- [x] `config/locales/en.yml`, `fr.yml` -- sentences take `%{time}`, no « UTC », drop the `time_format` keys
- [x] Ruby tests listed in the Code Map -- assert the ISO `datetime` and the fallback
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md:71,88,163` -- voice examples without « minuit (UTC) »

**Acceptance Criteria:**
- Given a player whose browser is in Europe/Paris, when they open the hub, booster, feed, settings and how-it-works, then every time reads local, without « UTC », and the countdowns still reach zero at the same instant.
- Given the back-office, when staff open import runs, then times still read UTC.

## Implementation Notes

- `LocalTimeHelper#local_time_sentence(time, style) { |fallback| t(key, time: fallback) }` splices the tag into a translated sentence (escaping the rest), so the keys keep plain names; the same block gives the flash its plain UTC text through `local_time_fallback`.
- `local_time_controller.ts` also re-renders on `turbo:morph-element`, since a morph refresh (the hub at zero) writes the server's UTC text back into an element whose controller stays connected.
- `Game::BankSummary.next_bonus_at(now)` added (used by `call`) so the no-JS redirect gets the next day change without loading the whole bank.
- How-it-works: « heure locale » / "local time" (`pages.how_it_works.local_time`) is a suffix the tag passes to the controller (`data-local-time-suffix-value`), appended only when the script rewrites the time, so no-JS reads « à 00:00 UTC. ». The instants come from `Game::BankSummary.next_bonus_at` and the new `Game::CurrentGoal.next_week_start`.
- Sentences read « Prochain booster : %{time} » / "Next booster: %{time}" and « Le prochain sera prêt le %{time} » / "ready on %{time}", since a time now carries a date; the controller uses the absolute `daily_bonuses.create.collected` key (i18n-tasks reads a relative key against the private method's name).

## Plan Change Log

- 2026-10-15, after the author's staging review: French times read « 16 oct. à 02h00 » (date, « à », hours « h » minutes) instead of « 16 oct., 02:00 »; a time alone reads « 02h00 » and a weekday « lundi à 02h00 ». English is unchanged.

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 2, low 2, false 0, maybe-false 0

- `medium` patch — without JavaScript the how-it-works sentences read « 00:00 UTC, heure locale », calling a UTC time local; the « heure locale » words now come with the script's rewrite only.
- `medium` patch — `HowItWorksHelper#next_day_start` / `#next_week_start` read `Game::DailyBonusClaim` and `Game::WeeklyGoal` directly, against the rule that the web layer reads through the pack's queries; the day comes from `Game::BankSummary.next_bonus_at`, the week from a Game query.
- `low` patch — five system test calls of the reworded keys pass no `time:` and would raise; system tests are disabled but the fix is direct.
- `low` patch — new explanatory comments in the helper, controller, lib and island against AGENTS.md's comment rule; removed.


## Verification

**Commands:**
- `npm run test:js` -- expected: pass, `local_time.test.ts` included
- `bin/ci` -- expected: green
- `bin/rails zeitwerk:check` -- expected: all is well
- `grep -n "UTC" config/locales/en.yml config/locales/fr.yml` -- expected: no match (the back-office formats its own UTC in its template)
