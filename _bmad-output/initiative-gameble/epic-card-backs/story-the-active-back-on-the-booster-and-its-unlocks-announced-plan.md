---
title: 'The active back on the booster and its unlocks announced'
type: 'feature'
ticket: '5'
created: '2026-10-28'
status: done
baseline_revision: '6c4cae84'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [self-review]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The booster only knows the Standard back (a hard-coded key list in `booster_motion.ts` and one CSS rule per layout), so a player who equipped another back still sees the Standard one on the face-down cards, a back unlocked by an opening or a trade is never announced, and the landing still tags the card backs tile as soon.

**Approach:** The server renders each opened pack's back as three asset URLs (the booster's three layouts: card-s, card-m, card-xl) in the opening answer and in the opened page's pack template; the booster hands them to the stylesheet as custom properties on each face-down card and falls back to the Standard rules when a pack carries none. `PlayerStream` turns `CardBackUnlocked` into a toast that waits for the reveal, as it does `AchievementUnlocked`; a retroactive unlock announces nothing. The landing's card backs tile loses its soon tag.

</frozen-after-approval>

## Implementation Notes

Oneshot. `PacksHelper#pack_card_back` resolves the pack's stored key through `Game::CardBacks` (an unknown or missing key becomes Standard) and returns `{ key, urls: { s, m, xl } }` built with `vite_asset_path` from the catalogue's asset name; the same data goes to the JSON answer and, as `data-card-back-*`, to the opened page's pack template, so both entries of the booster agree. In the front end `CardBackView` carries `urls: null` when the dataset lacks a size, and `cardBackClass` then keeps the Standard class; otherwise the class is `booster-card__back--custom` and `cardBackProperties` sets `--card-back-s|m|xl` on the back element, which three layout rules read. No `style` attribute is written by the server. The toast reuses the achievement toast shape (`after_reveal`), named through `card_back_name`; the unlock operation already marks retroactive unlocks, so allocation and backfill unlocks stay silent. A back unlocked by an opening crosses the opening's own transaction, the handler enqueues its grant job after commit, and the toast then waits for the reveal.

## Plan Change Log

## Review Triage Log

Own diff review (no subagent, and no test or check was run in this worktree by the author's instruction). Checked: the key-to-assets lookup falls back to Standard for a stored key the catalogue no longer holds; the data attributes become `cardBackS|M|Xl` in the dataset and the reader needs all three; `style.setProperty` on the cloned back is a script write, not server markup; the custom class beats nothing it should not (same specificity as the Standard rule at each layout, one class per back); `PlayerStream` notice carries the key only, the job resolves the name per locale; `Game::CardBacks.find` returning nil for a stale notice would raise in the partial, accepted because the key comes from an unlock the operation just validated.
- low, rejected: preloading the three images before the deal (the pack's backs load with the cards' art, and the stylesheet already requests the Standard sizes the same way).
- low, accepted: the unlock toast does not name the set for set backs beyond the back's name; the picker shows the condition.

## Verification

**Commands (to run in the main tree):**
- `bin/rails test test/models/player_stream_test.rb test/jobs/player_stream_job_test.rb test/controllers/packs_controller_test.rb test/controllers/boosters_controller_test.rb test/controllers/landing_page_test.rb` -- expected: pass
- `bin/rails test test/system/booster_test.rb -n /back_equipped/` -- expected: pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css`, `npx tsc --noEmit` -- expected: clean
- `bundle exec rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `script/check_planning_references`, `script/check_file_sizes` -- expected: clean
