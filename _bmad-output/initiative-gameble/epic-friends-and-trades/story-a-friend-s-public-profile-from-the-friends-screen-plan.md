---
title: "A friend's public profile from the Friends screen"
type: 'feature'
ticket: '13'
created: '2026-10-08'
status: 'built'
baseline_revision: 'a3bb38cbbbe0d79bdc483824e5a99bbce48d4027'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/epic-friends-and-trades/epic-friends-and-trades.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** From the Friends screen a player can open a friend's profile dialog (presence, showcase, trade, report) but cannot reach that friend's public profile page (`/brothers/:token`, their collection), which `Game::Visibility` already lets a friend see when the friend is public or friends-only.

**Approach:** Each friend row on the Friends screen (`app/views/friends/show.html.erb`) and the friend profile dialog (`app/views/friend_profiles/show.html.erb`) get the same secondary small link "See the profile" / "Voir le profil" to `brother_path(token:)`, named for screen readers with the friend's name ("See Lea's profile" / "Voir le profil de Lea"). A friend whose profile is private shows no link (author's decision); as every listed friend is a friend in good standing, that is `!visibility_private?`, asked through a `Game::Visibility` predicate so the rule stays in one place and the list costs no query per friend. Controller tests: link present for public and friends-only friends with its href and name, absent for a private friend, present in the dialog. System test: from the Friends screen a player presses the link beside a friends-only friend and lands on that friend's public profile; the dialog's link reads the same.

</intent-contract>

## Implementation Notes

Oneshot: two views, one predicate, two locale keys per language, tests.

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 5 findings — high 0, medium 1, low 4, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `shown_to_a_friend?` copied the good-standing guard of `visible?`, so a new exclusion would leave a Friends link leading to a 404 — fixed: both use one private `in_good_standing?`.
  - `[low]` `[patch]` The new predicate had no unit test for its missing, banned and deleted branches — fixed: one test covers public, friends-only, private, banned, missing and deleted.
  - `[low]` `[patch]` In English the link's accessible name ("See Lea's profile") did not contain its visible text, failing label-in-name — fixed: "See the profile of %{name}".
  - `[low]` `[patch]` New comments explained code rather than an external constraint (AGENTS.md) — fixed: the Visibility note and the partial's header removed.
  - `[low]` `[patch]` At 320 px a long presence and the link crowded one unwrapping flex row — fixed: `.friends__actions` wraps and centres its items.

## Verification

All Ruby commands need Ruby 4.0.7 from rbenv: prefix them with `export PATH=/opt/rbenv/shims:$PATH && `; system tests also need `CHROME_BIN=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/chrome.sh SE_CHROMEDRIVER=/tmp/claude-0/-home-user-gameble/96db6eff-e0bb-4199-b5a2-a5d6ae5aadb8/scratchpad/cd/chromedriver`.

**Commands:**
- `bin/rails test` -- expected: all green
- `bin/rails test test/system/friends_test.rb test/system/public_profile_test.rb` (system env above) -- expected: green
- `bin/rubocop && bundle exec packwerk check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

**Summary.** Each friend on the Friends screen and the friend profile dialog carry the same "See the profile" / "Voir le profil" link to the friend's public profile, named with the friend's name; a friend whose profile is private shows none (`Game::Visibility.shown_to_a_friend?`, no query per friend).

**Files.**
- `app/views/friends/_public_profile_link.html.erb` (new) -- the link, or nothing for a private profile.
- `app/views/friends/show.html.erb`, `app/views/friend_profiles/show.html.erb` -- the link beside each friend and in the dialog.
- `packs/game/app/models/game/visibility.rb` -- `shown_to_a_friend?`, sharing the good-standing guard with `visible?`.
- `app/frontend/styles/friends.css` -- the row's actions wrap.
- `config/locales/en.yml`, `fr.yml` -- `friends.public_profile.label`/`named`.
- Tests: `friends_controller_test.rb`, `friend_profiles_controller_test.rb`, `visibility_test.rb`, `system/friends_test.rb`.

**Review.** One quick pass: 5 patches (1 medium, 4 low), nothing deferred or rejected.

**Follow-up review recommended:** false.

**Verification.** `bin/rails test` 1752 runs green; `bin/rubocop`, `packwerk check`, `i18n-tasks missing`/`unused` clean; `test/system/friends_test.rb` green.

**Residual risks.** None known.
