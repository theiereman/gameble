---
title: 'No player screen speaks of officers or the Brotherhood'
type: 'feature'
ticket: '50'
created: '2026-10-14'
status: done
baseline_revision: '47391d3'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Three player-facing strings still carry the Brotherhood voice that EXPERIENCE.md keeps out of player screens ("The Brotherhood is discreet: one line, on the community goal only"; "No title for the player"): the nameless fallback « Officier sans nom » / "Nameless officer" on the feed, the friends list and the trades (`feeds.show.nameless`, `friends.show.nameless`); the public profile's visibility lines naming « les officiers de la Confrérie » (`public_profiles.show.visibility.friends_only`, `.private`, `.banned`); and the staff refusal « Seuls les officiers de la Confrérie… » (`errors.accounts.staff_required`).

**Approach:** Rewrite them in the plain vous voice, in French and English: the fallback names a player, not an officer; the visibility lines and the refusal name « la modération » / "the moderation team", so they still say truthfully that staff see a private or banned profile; update the tests that assert them. The back-office's own officer voice, the community goal line and the `/:locale/brothers/:token` addresses stay (author, 2026-10-13).

</frozen-after-approval>

## Implementation Notes

Oneshot: six locale values and the tests that assert them.

- `feeds.show.nameless`, `friends.show.nameless`: « Joueur sans nom » / "Nameless player" (the trades screen reaches it through `FriendsHelper`).
- `public_profiles.show.visibility.friends_only`, `.private`, `.banned`: « la modération » / "the moderation team" instead of the officers, so the lines still tell the truth that staff see a private or banned profile; the wording matches the report dialog's "The moderation team will review this profile". EXPERIENCE.md's copy deck lines leave staff out; the app's lines already differed from it (the public line too), and the deck is not changed here.
- `errors.accounts.staff_required`: « Seule la modération peut faire cela. » / "Only the moderation team can do that."
- Tests: `public_profiles_controller_test.rb` and `trades_controller_test.rb` assert the new copy. The back-office's officer voice and the community goal line are untouched.

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — no findings

## Verification

**Commands:**
- `bin/rails test test/controllers/public_profiles_controller_test.rb test/controllers/trades_controller_test.rb` -- expected: 0 failures
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check` -- expected: green
