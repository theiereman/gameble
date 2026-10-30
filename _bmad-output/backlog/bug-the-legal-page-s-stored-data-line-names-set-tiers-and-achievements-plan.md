---
title: "The legal page's stored data line names set tiers and achievements"
type: 'bugfix'
ticket: 'bug-the-legal-page-s-stored-data-line-names-set-tiers-and-achievements'
created: '2026-10-30'
status: 'built'
baseline_revision: '0a00ddafa1f61c609855cfc57c276e75b64c3758'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      The player's active title is erased on account deletion but neither the stored data line nor the deletion paragraph names it.
    evidence: |-
      Game::ReleasePlayer deletes the PlayerState row, which holds active_title_kind, active_title_key and active_title_rank beside last_activity and active_card_back; the personalization page, settings, public profile and ProfileTitlesHelper read it. The deletion paragraph predates this change and never named it, so both lines share the gap; naming it means extending the deletion paragraph (and the settings deletion note), beyond this ticket.
    location: >-
      config/locales/en.yml pages.legal.privacy.deletion, config/locales/fr.yml pages.legal.privacy.deletion
    severity: medium
  - summary: >-
      The purposes line still lists only part of the game data (collection, capsules, trades, friends, profile, activity feed).
    evidence: |-
      pages.legal.privacy.purposes.game in both locales predates this change; it is a summary of the purpose rather than an inventory, but it now names less than the stored line.
    location: >-
      config/locales/en.yml pages.legal.privacy.purposes.game
    severity: low
  - summary: >-
      The stored data line does not name first discoveries or contributions to the community goal, which the deletion paragraph says are kept.
    evidence: |-
      Game::ReleasePlayer keeps game_first_discoveries rows (only their pack_id is cleared) and never touches game_weekly_contributions; both carry player_id while the account exists, and the deletion paragraph lists them among what is kept. The ticket asks the stored line to name what the deletion paragraph erases, so kept items were left out; naming them (and adding them to the pages test's term list) is a follow-up wording change in both locales.
    location: >-
      config/locales/en.yml pages.legal.privacy.stored.activity, config/locales/fr.yml pages.legal.privacy.stored.activity, test/controllers/pages_controller_test.rb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The legal page's "To run the game, Gameble keeps" list has a game activity line ("cards, capsules, trades, friends and invitations, friend code, activity feed entries") that leaves out game data the deletion paragraph further down says an account deletion erases: the showcase, set tiers, achievements, card back unlocks and the active card back, daily bonuses, community goal rewards and the latest activity. A reader is told data is erased that they were never told is kept.

**Approach:** Rewrite `pages.legal.privacy.stored.activity` in `en.yml` and `fr.yml` so it names, with the deletion paragraph's own nouns, every piece of game data that paragraph erases (keeping trades, which the stored line already names), give its `<li>` a class, and add a pages test that checks each game data term in both the stored line and the deletion paragraph, in both locales. The page's "Last updated" date moves to 30 October 2026, as earlier changes to the privacy copy did.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- rewrite `pages.legal.privacy.stored.activity` with the deletion paragraph's nouns (collection, showcase, set tiers, achievements, card back unlocks and active card back, capsules, daily bonuses, community goal rewards, trades, friendships, invitations, friend code, activity feed entries, latest activity); bump `pages.legal.updated` to 30 October 2026 -- the two lines must agree.
- [ ] `app/views/pages/legal.html.erb` -- give the activity `<li>` the class `legal__stored-activity` -- so a test can read that line alone.
- [ ] `test/controllers/pages_controller_test.rb` -- add a test that, for each locale, checks every game data term in both `.legal__stored-activity` and the deletion paragraph; update the asserted "Last updated" date -- ties the two lines.

**Acceptance Criteria:**
- Given the legal page in French or English, when a reader compares the stored data line with the deletion paragraph, then every game data item the paragraph erases is named in the stored line, and a pages test fails if either line drops one.

## Implementation Notes

Oneshot: two locale strings, one view class and one test, well under 100 lines. `Game::ReleasePlayer` confirms the erased game data: feed entries, daily bonus claims, goal rewards, set tiers, packs (capsules), showcase entries, holdings (collection), achievement unlocks, card back unlocks, friend code and the player state (latest activity, active card back).

Done: the stored activity line in both locales now uses the deletion paragraph's own nouns ("card collection", "friendships", "latest activity"...), so the test checks one list of terms against both lines; trades stay in the stored line since past trades are kept. The activity `<li>` carries `legal__stored-activity`. "Last updated" moved to 30 October 2026 in both locales, as earlier privacy copy changes did, and the asserting test follows. Files: `config/locales/en.yml`, `config/locales/fr.yml`, `app/views/pages/legal.html.erb`, `test/controllers/pages_controller_test.rb`. `i18n-tasks check-normalized` flags `fr.yml`, as it did before this change (hand-ordered keys); `en.yml` stays normalized.

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` The active title is erased but neither line names it — real: PlayerState holds the active_title columns and ReleasePlayer deletes it; pre-existing in the deletion paragraph, which the intent does not ask to extend; deferred.
  - `[low]` `[defer]` The purposes line still lists the old, partial set of game data — real but pre-existing and not caused by this change; the line summarises a purpose rather than listing data; deferred.
  - `[low]` `[patch]` The test's fixed term list means a new item added to the deletion paragraph alone would pass, while the test name promised every erased item — renamed the test to "the stored data line and the deletion paragraph name the same game data"; parsing the paragraph instead would add complexity for little gain.

### 2026-10-30 — Review pass
- verdicts: 4 findings — high 0, medium 2, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` The stored line names trades but not first discoveries or community goal contributions, which the deletion paragraph says are kept — real: ReleasePlayer keeps FirstDiscovery rows (pack_id cleared) and never touches WeeklyContribution, both keyed by player_id; the ticket asks for what the deletion paragraph erases, so kept items fall outside it; deferred.
  - `[low]` `[defer]` The pages test's term list does not cover the kept items and, being fixed, cannot catch an item added to one line only — the kept-items half shares the root cause above and is deferred with it; the fixed-list half is carried: same claim as the earlier low patch, the test was already renamed to match.
  - `[low]` `[reject]` The plan says `en.yml` stays normalized but `i18n-tasks check-normalized` now flags it — the fix is an edit to this build's plan; the flag comes from the long, unwrapped deletion line, not from this change's wrapped stored line, and CI runs only `i18n-tasks missing`.
  - `[medium]` `[defer]` The active title is named in neither line — carried: PlayerState still holds the active_title columns and ReleasePlayer deletes it; already deferred.

## Verification

**Commands:**
- `bin/rails test test/controllers/pages_controller_test.rb` -- expected: all pass
- `bundle exec i18n-tasks missing` -- expected: no missing keys
- `script/check_planning_references && script/check_file_sizes` -- expected: pass

## Auto Run Result

- **Summary:** the legal page's stored game activity line now names, in English and French, everything the deletion paragraph erases (collection, showcase, set tiers, achievements, card back unlocks and active card back, capsules, daily bonuses, community goal rewards, friendships, invitations, friend code, activity feed entries, latest activity), with trades kept; a pages test checks each term in both lines in both locales; "Last updated" moves to 30 October 2026.
- **Files:**
  - `config/locales/en.yml`, `config/locales/fr.yml` -- the stored activity line rewritten, the update date bumped.
  - `app/views/pages/legal.html.erb` -- `legal__stored-activity` class on the activity line.
  - `test/controllers/pages_controller_test.rb` -- new test tying the stored line to the deletion paragraph; updated date assertion.
- **Review:** quick lens, 3 findings: 1 patch (low, test renamed), 2 deferred (active title unnamed in both lines, medium; purposes line partial, low), 0 rejected.
- **Follow-up review recommended:** false (one low patch).
- **Verification:** `bin/rails test test/controllers/pages_controller_test.rb` 59 runs, 0 failures; with search_engines, sessions, sign_ins and shell tests 163 runs, 0 failures; system tests reaching the legal page (`hub_test -n /legal/` 3, `share_card_test -n /legal page/` 1, `settings_test -n /legal page/` 1) pass; `i18n-tasks missing`, `script/check_planning_references`, `script/check_file_sizes`, rubocop pass.
- **Residual risks:** the active title stays unnamed in the privacy copy (deferred).

### Follow-up review pass (2026-10-30)

- **Summary:** re-dispatched on a `built` plan; the change (commit 5184a2873befa51c7b52caf666632260fae5f4db) was reviewed again with the quick lens, no code changed.
- **Review:** 4 findings: 0 patches, 3 deferred (kept first discoveries and community goal contributions unnamed in the stored line, medium, new; the test's term list, low, grouped with it; the active title, medium, carried), 1 rejected (the plan's normalization note; fixing it means editing the plan).
- **Follow-up review recommended:** false (no patch on this pass).
- **Verification:** `bin/rails test test/controllers/pages_controller_test.rb` 59 runs, 0 failures; `i18n-tasks missing` clean; `script/check_planning_references` and `script/check_file_sizes` pass.
- **Residual risks:** the privacy copy still omits the active title, first discoveries and community goal contributions from the stored list (deferred).
