---
title: 'The booster records how each capsule was revealed'
type: 'feature'
ticket: '3'
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
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Lazy Opener and Hardworking achievements (a later entry) need to know whether each capsule was revealed with "Reveal all" or card by card, and nothing records it today.

**Approach:** Store `game_packs.reveal_mode` (null, `all`, `one_by_one`), set once by a new `Game::RecordReveal` operation behind `POST /:locale/packs/:token/reveal`, which the booster sends for every pack kind when its last card turns face up; the player data export lists each pack's mode.

## Boundaries & Constraints

**Always:**
- Mode is `all` when "Reveal all" actually started for that capsule before its last card turned face up, `one_by_one` otherwise; sent once per opening, at the transition to every card face up, for regular, bonus and reward packs alike, on phone and desktop layouts.
- Accepted only for the player's most recently opened pack (by `opened_at`, then `id`) while its mode is null; a repeat on that pack answers 204 and changes nothing (no write, no event). The mode is trusted from the client (it moves no card).
- The operation takes the bank lock, writes inside its transaction and publishes exactly one `Game::PackRevealed` (data `player_id`, `pack_id`, `mode`) on the player's stream when it writes.
- Expand/contract: migration `20261101150000` adds the nullable string column and the check `reveal_mode IS NULL OR reveal_mode IN ('all', 'one_by_one')` with `validate: false`; migration `20261101150100` validates it. Regenerate `db/schema.rb` from the migrations.
- Every new string in both `en.yml` and `fr.yml`; `errors.game.<code>` keys added by hand.

**Never:**
- No subscriber to `Game::PackRevealed` (the achievements entry adds it), no achievement metric, no change to `Game::Achievements`.
- No Rails `enum` for the mode (its `all` value would clash with `Pack.all`); no database id in the URL, JSON or DOM.
- No growth of `app/frontend/controllers/booster_controller.ts` (already at the 400-line limit); no markup built in script.
- A capsule restored from markup (`/booster?pack=TOKEN`, cards already face up) or left before its last card is face up sends nothing.
- No legal page change: its deletion line already names "your capsules", which carry the mode.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First reveal | latest opened pack, mode null, `mode: "all"` or `"one_by_one"` | 204, column set, one `PackRevealed` | none |
| Repeat | latest pack already has a mode, any mode | 204, nothing changes, no event | none |
| Older pack | token of an opened pack that is not the latest | nothing changes | 422 `not_latest_pack` JSON error |
| Unknown token | another player's, unopened or missing pack | nothing changes | 404 `pack_not_found` JSON error |
| Bad mode | missing, `"fast"`, non-string | nothing changes | 400 `invalid_reveal_mode` JSON error |
| Signed out / banned | no session or banned player | nothing changes | 401 `sign_in_required` (as packs#create) |
| Burst | over 30 POSTs a minute per player | nothing more | 429 `throttled`, `Retry-After` |

</intent-contract>

## Code Map

- `db/migrate/20261029150000_*`, `20261029150100_*` -- golden pair for "check added then validated".
- `app/domains/game/app/models/game/pack.rb` -- add `REVEAL_MODES = %w[all one_by_one].freeze` and an inclusion validation allowing nil.
- `app/domains/game/app/operations/game/open_pack.rb`, `choose_card_back.rb` -- operation style: `step require_player`, `transaction do step lock_bank(player) ... end`, `next value` for a no-op inside the transaction, `publish(Event.new(data:), stream_name: stream_name(player.id))`. Base class `operation.rb` enforces a `player:` keyword.
- `app/domains/game/app/events/game/pack_opened.rb` -- event class shape (`< RubyEventStore::Event`).
- `app/controllers/collection_seen_controller.rb` + `app/policies/collection_seen_policy.rb` -- golden JSON POST controller: `authorize`, `rate_limit ... with: :throttled`, `FAILURES` map, `head :no_content`, `render_json_error`.
- `config/routes.rb` line ~33 (`resources :packs`) -- add `post "packs/:token/reveal" => "pack_reveals#create", as: :pack_reveal, constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }`.
- `app/helpers/packs_helper.rb` `pack_opening_json` -- add `revealUrl: pack_reveal_path(pack.token)` to `pack:`.
- `app/domains/game/app/queries/game/export_of.rb` `PackRow`/`self.packs` + `app/models/player_export.rb#packs` -- add `reveal_mode` / `revealMode`.
- `app/frontend/lib/booster_types.ts` (`BoosterState`), `booster_state.ts` (`start`), `booster_opening.ts` (`openingAnswered`, `revealAllStarted`, `revealMarked`) -- the pure state module; `booster_rules.ts#allRevealed`.
- `app/frontend/lib/booster_reflect.ts#reflectChange` -- called by the controller's `apply` with `(before, after)` on every transition: the hook point, so the controller does not change.
- `app/frontend/lib/opening.ts` (`OpeningAnswer.pack`), `booster_markup.ts#openedFrom` (restored answer has no reveal URL), `booster_page.ts#csrfToken`, `repost.ts` (golden fire-and-check fetch module), `booster_fixtures.ts` (vitest answer fixture).
- `test/system/booster_test.rb` -- setup (sign-in, `reduce_motion`, `open_screen`, `open_canister`, `assert_dealt`, `hit`, "Reveal all" button) to copy into a new file; `test/support/game_packs.rb#create_pack(kind:)`, `game_events`.
- `test/controllers/packs_controller_test.rb`, `test/domains/game/choose_card_back_test.rb`, `test/models/player_export_test.rb` -- request, operation and export test styles.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261101150000_add_reveal_mode_to_game_packs.rb`, `db/migrate/20261101150100_validate_game_packs_reveal_mode_check.rb`, `db/schema.rb` -- column + unvalidated check, then validation; regenerate schema as AGENTS.md says and keep only this diff.
- [x] `app/domains/game/app/models/game/pack.rb` -- `REVEAL_MODES` and validation.
- [x] `app/domains/game/app/events/game/pack_revealed.rb`, `app/domains/game/app/operations/game/record_reveal.rb` -- `Game::RecordReveal#call(player:, token:, mode:)` per the matrix; failures `invalid_reveal_mode`, `pack_not_found`, `not_latest_pack`.
- [x] `config/routes.rb`, `app/controllers/pack_reveals_controller.rb`, `app/policies/pack_reveal_policy.rb` (`create? = player?`) -- reads `params[:mode]` from the JSON body, maps failures as the matrix says.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- `errors.game.{invalid_reveal_mode,pack_not_found,not_latest_pack}` and `pack_reveals.create.throttled` (mirror the existing "Too many requests in a minute. Try again in a moment." / "Trop de requêtes en une minute. Réessayez dans un instant.").
- [x] `app/helpers/packs_helper.rb` -- `revealUrl` in the opening JSON.
- [x] `app/domains/game/app/queries/game/export_of.rb`, `app/models/player_export.rb` -- `revealMode` per pack (null when unopened or unrevealed).
- [x] `app/frontend/lib/booster_types.ts`, `booster_state.ts`, `booster_opening.ts` -- `revealAllUsed: boolean` in state (false at start and on each new answer, true when `revealAllStarted` takes effect); export `revealModeReached(before, after): "all" | "one_by_one" | null`, non-null only when the same non-null answer goes from not all revealed to all revealed.
- [x] `app/frontend/lib/opening.ts` -- `pack.revealUrl?: string`; `app/frontend/lib/reveal.ts` -- `sendReveal({ url, mode, csrfToken, fetch? })`: POST JSON `{ mode }`, `Accept`/`Content-Type` JSON, CSRF header, `credentials: "same-origin"`, `keepalive: true`, never throws.
- [x] `app/frontend/lib/booster_reflect.ts` -- when `revealModeReached` gives a mode and the answer has a `revealUrl`, `void sendReveal(...)` with `csrfToken()`.
- [x] Tests: `test/domains/game/record_reveal_test.rb` (every matrix row at operation level, event data, concurrency-safe no-op), `test/controllers/pack_reveals_controller_test.rb` (status codes and JSON errors, CSRF-protected POST, opening JSON carries `revealUrl`), `test/models/player_export_test.rb` (`revealMode`), vitest for `revealModeReached` (one-by-one, Reveal all, Reveal all started after some single reveals, restored answer, no-op transitions) and `reveal.test.ts` (request shape, failure swallowed), `test/system/booster_reveal_mode_test.rb` (desktop regular pack card by card stores `one_by_one`; a bonus pack with "Reveal all" stores `all`; phone "Reveal all" stores `all`; `/booster?pack=TOKEN` of a pack sends nothing), asserting the stored mode with a retrying wait.

**Acceptance Criteria:**
- Given a signed-in player on the booster, when they open a regular capsule and turn every card one by one, then that pack's `reveal_mode` is `one_by_one` once the last card is face up.
- Given a special (bonus) capsule, when the player uses "Reveal all" (also after turning some cards by hand), then its `reveal_mode` is `all`.
- Given a revealed pack, when the player downloads their data export, then that pack's entry shows `revealMode`.
- Given the migrations run on an empty Postgres 18, when `db/schema.rb` is regenerated, then the only schema diff is the column and the validated check.

## Implementation Notes

- Built by the implementation subagent as planned; `booster_controller.ts` is untouched. Added a `Game::Pack.latest_opened` scope (by `opened_at`, then `id`) for the latest-pack rule.
- The system test for a restored capsule reaches `/booster?pack=TOKEN` through `Turbo.visit`, so the fetch recorder installed on the previous page still sees the screen's requests.
- On a phone, Reveal all pressed while the last face-down cards are already turning by hand records `all` ("Reveal all used at all"); accepted as the intended reading.
- Rails tests ran with `PARALLEL_WORKERS=1`: parallel workers hit Postgres "too many clients" because other builds share the server. `bin/ci` itself was not run (it runs `bin/setup` and drops databases); its steps were run one by one.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 3, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` `record_reveal_test.rb` checks the lowercase "translation missing", which i18n 1.15 never produces — fixed to "Translation missing", as sibling tests write it; the test file reran green.
  - `[low]` `[reject]` The route's token constraint gives a malformed token the router's HTML 404 instead of the JSON `pack_not_found` — the booster only posts the `revealUrl` the server built, so no player meets it, and the other token routes (brothers, custom sets) answer a malformed token the same way.
  - `[low]` `[reject]` The restored-capsule system test reads "no POST" once and cannot fail while `openedFrom` builds no `revealUrl` — the logic is covered in vitest; the system test still guards the end-to-end regression where the restored markup gains a reveal URL. Hardening it would add waits for an absence, for little gain.
  - `[false]` `[reject]` The non-transactional concurrency class shares a file with the transactional tests — it is its own class with `use_transactional_tests = false` and its own teardown, and runs correctly; no harm named beyond a file-naming convention.

## Design Notes

The booster's controller cannot grow, so the POST hangs off `reflectChange`, which already receives every `(before, after)` pair. Detecting the edge in a pure function keeps it testable in vitest:

```ts
export function revealModeReached(before: BoosterState, after: BoosterState): RevealMode | null {
  if (!after.answer || after.answer !== before.answer) return null
  if (allRevealed(before) || !allRevealed(after)) return null
  return after.revealAllUsed ? "all" : "one_by_one"
}
```

The latest-pack rule reads inside the bank lock (which `OpenPack` also takes), so an opening cannot slip between the check and the write.

## Verification

**Commands:**
- `bin/rails test test/domains/game/record_reveal_test.rb test/controllers/pack_reveals_controller_test.rb test/controllers/packs_controller_test.rb test/models/player_export_test.rb test/controllers/read_only_requests_test.rb` -- expected: green
- `bin/rails test test/system/booster_reveal_mode_test.rb test/system/booster_test.rb test/system/booster_reserves_test.rb test/system/booster_screen_test.rb` -- expected: green
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_file_sizes`, `script/check_planning_references` -- expected: pass

## Auto Run Result

Status: built

**Summary:** Each opened capsule now records how it was revealed. `game_packs.reveal_mode` (null, `all`, `one_by_one`, with a check added and then validated) is set once by `Game::RecordReveal` behind `POST /:locale/packs/:token/reveal`. It is accepted only for the player's latest opened pack while its mode is null; a repeat answers 204 and changes nothing. It publishes `Game::PackRevealed` (`player_id`, `pack_id`, `mode`). The booster sends the reveal for every pack kind, on phone and desktop, as the last card turns face up: `all` if Reveal all started for that capsule, `one_by_one` otherwise. The player data export lists `revealMode` for each pack.

**Files changed:**
- `db/migrate/20261101150000_add_reveal_mode_to_game_packs.rb`, `db/migrate/20261101150100_validate_game_packs_reveal_mode_check.rb`, `db/schema.rb`: the column and its check, with the schema regenerated from the migrations.
- `app/domains/game/app/models/game/pack.rb`: `REVEAL_MODES`, the inclusion validation and a `latest_opened` scope.
- `app/domains/game/app/operations/game/record_reveal.rb`, `app/domains/game/app/events/game/pack_revealed.rb`: the operation and its event.
- `config/routes.rb`, `app/controllers/pack_reveals_controller.rb`, `app/policies/pack_reveal_policy.rb`: the endpoint, its policy and its rate limit.
- `app/helpers/packs_helper.rb`: `revealUrl` in the opening JSON.
- `config/locales/en.yml`, `config/locales/fr.yml`: three `errors.game` messages and the throttled message.
- `app/domains/game/app/queries/game/export_of.rb`, `app/models/player_export.rb`: `revealMode` in the export.
- `app/frontend/lib/booster_types.ts`, `booster_state.ts`, `booster_opening.ts`: the `revealAllUsed` state and `revealModeReached`.
- `app/frontend/lib/opening.ts`, `reveal.ts`, `booster_reflect.ts`: `revealUrl` on the answer, `sendReveal`, and the hook that sends it.
- Tests: `test/domains/game/record_reveal_test.rb`, `test/controllers/pack_reveals_controller_test.rb`, `test/controllers/packs_controller_test.rb`, `test/models/player_export_test.rb`, `app/frontend/lib/booster_reveal_mode.test.ts`, `app/frontend/lib/reveal.test.ts`, `test/system/booster_reveal_mode_test.rb`.

**Review:** quick lens, 4 findings.
- 1 low patched: the missing-translation assertion.
- 2 low rejected: the HTML 404 for a malformed token, and the weak restored-capsule system test (reasons in the triage log).
- 1 false rejected: the shared concurrency test file.
- Nothing deferred.

**Follow-up review recommended:** false. Only one low was patched.

**Verification:**
- Targeted Ruby tests: 73 runs, 0 failures.
- Full `bin/rails test` (implementer, `PARALLEL_WORKERS=1`): 3836 runs, 0 failures.
- Booster system tests (`booster_reveal_mode`, `booster`, `booster_reserves`, `booster_screen`): 62 runs, 0 failures.
- `npm run test:js`: 767 passed.
- Passing: format check, CSS lint, `script/check_file_sizes`, `script/check_planning_references`, packwerk, `zeitwerk:check`, rubocop, `i18n-tasks missing`.
- `bin/ci` was not run as a whole (it runs `bin/setup` and drops databases); its steps were run one by one.

**Copy the UX did not specify:**
- `errors.game.invalid_reveal_mode`, `errors.game.pack_not_found` and `errors.game.not_latest_pack`, in English and French.
- `pack_reveals.create.throttled`, which mirrors the existing "Too many requests" lines.
- None of them is shown to a player: the booster ignores the answer.

**Residual risks:**
- A capsule left before its last card is face up, or shown again from `/booster?pack=TOKEN`, keeps a null mode and breaks both reveal streaks.
- On a phone, Reveal all pressed while the last face-down cards are already turning by hand records `all`.
- The staging check by the author is still owed: a regular and a special capsule, revealed both ways.

