---
title: 'Stable system tests on CI: the window size restored for every test, chromedriver stale nodes retried'
type: 'bugfix'
ticket: 'bug-stable-system-tests-on-ci-the-window-size-restored-for-every'
created: '2026-10-07'
status: 'done'
baseline_revision: 'a1ca4cc7f9c8d70e976ba76570e589c2a48c9a0d'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The CI `system-test` job fails on about four runs out of five, each time on a different test (runs 39 to 48 of the CI workflow on `develop`). Two causes account for every failure since the author's last timing fixes. First, `share_card_test.rb` ("on a 360 × 740 phone the public card page…") resizes the browser window and never restores it, so every later test in that worker runs on a phone viewport, where the hub menu is `display: none`: `hub_test.rb:116`, `library_test.rb:50`, `countdown_test.rb:24` and `:66` all fail on their first look at `.hub-menu` or its badge (Capybara's "Also found ''" is the visible text of a hidden element). Which test follows depends on the seed and the worker, hence a different victim each run. Second, Chrome 154's chromedriver reports a node removed during a Capybara query as `Selenium::WebDriver::Error::UnknownError` "unhandled inspector error: Node with given id does not belong to the document" instead of `StaleElementReferenceError`; Capybara 3.40 retries only the latter, so a query that straddles a full page load (`settings_test.rb:64` after the motion form's redirect; `library_test.rb:139`'s `<<ERROR>>` matches after a filter visit) errors instead of waiting.

**Approach:** In `ApplicationSystemTestCase`, restore the window to `SCREEN_SIZE` in a teardown shared by every system test, and move the `resize_to` helper there, dropping the per-class copies so there is one source of truth. Map chromedriver's stale-node `UnknownError` to `StaleElementReferenceError` at the Selenium response level (a small prepend in `test/support/`), so Capybara's own retry handles it. Raise `Capybara.default_max_wait_time` to 5 s for the CI runner's pace. No retries, no skipped test, no sleep.

</frozen-after-approval>

## Implementation Notes

- Reproduced before the fix: `PARALLEL_WORKERS=1 bin/rails test test/system/share_card_test.rb:130 test/system/hub_test.rb:116 -s 6` runs the phone share test first and the hub test errors with `Unable to find visible css ".hub-menu .menu-item[aria-keyshortcuts='1']"`, the exact CI error of run 47. Seeds 1 to 5 ran the hub test first and passed. The CI screenshot artifacts could not be downloaded from this container (the Azure blob host is denied by the proxy).
- `test/application_system_test_case.rb`: a shared `teardown` restores `SCREEN_SIZE`, `resize_to` moved up from `hub_test.rb` and `shell_test.rb`, `Capybara.default_max_wait_time = 5`, and `support/chromedriver_stale_nodes` required. The eight per-class restores (settings, shell, library, booster, card_detail, hub, tome, the `ensure` of card_face_visual) were removed; `share_card_test.rb`, which had none, is covered.
- `test/support/chromedriver_stale_nodes.rb`: prepends `Selenium::WebDriver::Remote::Response#error` so an `UnknownError` carrying "Node with given id does not belong to the document" becomes a `StaleElementReferenceError`, the class Capybara retries on (`Capybara::Node::Base#synchronize` and the selector query's filters both rescue `driver.invalid_element_errors`, which lists it). Checked with a synthetic chromedriver response: `assert_ok` now raises the stale-element error.
- After the fix the seed-6 pair passes. Two full parallel runs: the first green (117 runs), the second with one failure of a third kind: `booster_test.rb` "on a phone: a pile of large cards…" at the tap meant to land *within* the reveal's 400 ms guard (`REVEAL_GUARD`, measured on `performance.now()`); on a loaded machine the tap came after the guard and stored the card (the failure screenshot shows the tray at 2 / 5). The desktop test "a revealed card ignores activation for 400 ms" has the same clock dependence.
- `booster_test.rb`: a `within_reveal_guard` helper freezes the page's `performance.now()` around the reveal and the tap (the stamp and the check read the same frozen value, so the tap is within the guard whatever the pace; `delete performance.now` restores the clock), applied to both tests. The art-wait loop in the island sleeps between polls and the swipe hook stamps a drag end only after a real drag, so the freeze changes nothing else of consequence: the island's 6 s ceiling on waiting for a card's art is suspended inside the block (bounded by Capybara's wait, after which `ensure` restores the clock). Both tests pass three times in a row.
- `chromedriver_stale_nodes.rb`: after the review, the mapped error is raised and rescued with `cause: error`, so chromedriver's trace stays attached.
- Fourth kind, seen once in the third parallel run: `library_test.rb:103`, sixty `.collection-grid > li` expected, every node read as `<<ERROR>>` after the wait, the failure screenshot showing the grid in its expected state. A count of sixty *visible* nodes is sixty round trips to the browser; on a loaded machine one attempt outlasts the wait while the Turbo frame the chip reloads replaces the nodes under it, so every node of that attempt is stale. The seven sixty-node counts in `library_test.rb` and `tome_test.rb` now pass `visible: :all`: one call, no per-node check (the grid's slots and cards are never hidden by design; visibility stays covered by the smaller assertions and the screenshots). CI's `library_test.rb:139` failure (57 `<<ERROR>>` of 60) is this same mechanism.
- Final verification on the merged tree: typecheck and 132 JS tests green, rubocop clean, the card face baselines pass with pixelcrush, `library_test` and `tome_test` green serially, and two full parallel runs of `test:system` green (117 runs each), after the earlier sequence green, booster failure, green, library failure, green.
- Meanwhile `develop` received `6c6ee61` (card art filtered by the pixelcrush package); its CI run 50 failed on `settings_test.rb` with the stale-node `UnknownError`, the second family. No file overlaps this change; merged before the push, with `npm ci` and the card face baselines re-checked.

## Review Triage Log

### 2026-10-07 — quick lens, two passes (before and after the guard fix)

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| The stale-element error built by the shim drops the original error's `cause` (chromedriver's trace) | low | patch | Confirmed with a synthetic response; fixed by raising with `cause: error` and rescuing; `e.cause` is now the `UnknownError`. |
| The plan's "twice green" verification was not yet evidenced (the second run had a failure) | false | — | The second run's booster failure is the third kind, fixed by `within_reveal_guard`; two more parallel runs follow the fix (see Implementation Notes). |
| `develop` moved past the baseline; run 50's failure unverified | false | — | Verified from the run's log: `settings_test.rb` with the stale-node `UnknownError`, the second family; merged before the push. |
| The diff's plan hunk lacked the booster notes; the frozen Approach names two causes, the clock freeze is a third | low | — | The notes were appended after the diff snapshot; the third fix stays inside the intent (make the tests stable, no retry, no skip, no sleep) and is documented in the notes, the frozen block untouched. |
| The art-wait ceiling is suspended while `performance.now` is frozen | low | patch | True and bounded by Capybara's wait plus `ensure`; the note now says so. No code change needed. |

## Verification

**Commands:** (in this container: `export PATH=/opt/rbenv/versions/4.0.7/bin:$PATH DB_PORT=5432 CHROME_BIN=/tmp/claude-0/-home-user-gameble/115b2f08-d056-569c-824a-568a5a17ae41/scratchpad/chromium-nosandbox.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/115b2f08-d056-569c-824a-568a5a17ae41/scratchpad/chromedriver141/chromedriver-linux64/chromedriver SE_OFFLINE=true`)
- Reproduce before the fix: `PARALLEL_WORKERS=1 bin/rails test test/system/share_card_test.rb test/system/hub_test.rb` with a seed that runs the phone share test before a hub test -- expected: the hub test fails on `.hub-menu`.
- Same command after the fix -- expected: pass with the same seed.
- `bin/rubocop` -- expected: clean.
- `bin/rails test:system` with the default parallel workers, twice -- expected: 117 runs, 0 failures, 0 errors both times.
