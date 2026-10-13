---
title: 'Persona names are cut on whole characters'
type: 'bugfix'
ticket: '28'
created: '2026-10-13'
status: done
baseline_revision: '1f4d44e8a2bb74fb2585682c8edaf9f2e8609443'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      Planning ids (CAP-8, epic 4 retrospective B4) remain in the comments of persona_name.rb, sign_in.rb and persona_name_test.rb.
    evidence: |-
      Pre-existing, not added by this change; the same kind of leftover is already logged in deferred-work.md for a repo-wide sweep (about 250 files still hold CAP-n or AD-n).
    location: >-
      packs/accounts/app/operations/accounts/sign_in.rb:6, test/packs/accounts/persona_name_test.rb:3
    severity: low
---

<intent-contract>

## Intent

**Problem:** `Accounts::PersonaName.clean` cuts a name to 64 code points (`String#first`), so a cut can land between a letter and its combining mark, an emoji and its skin-tone modifier, or the two regional indicators of a flag, leaving a stray mark or half a flag at the end of the shown name.

**Approach:** Cut the cleaned name to its first `LENGTH` (64) extended grapheme clusters instead of code points; a name of 64 graphemes or fewer is unchanged. Verify: a name longer than 64 graphemes ending in combining marks, modified emoji and flags is cut to 64 whole graphemes; a name under the limit is unchanged.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] `packs/accounts/app/models/accounts/persona_name.rb` -- cut with `grapheme_clusters.first(LENGTH).join` (after the invisible characters are dropped and spaces squished, as now) and say graphemes in its comment -- the bug.
- [x] `packs/accounts/app/operations/accounts/sign_in.rb` -- its comment says the name is cut to `LENGTH` characters; say graphemes.
- [x] `test/packs/accounts/persona_name_test.rb` -- names past the limit whose 64th/65th graphemes are a letter with combining marks, an emoji with a skin-tone modifier, and a flag are cut to 64 whole graphemes; the same kinds of names at or under 64 graphemes (but over 64 code points) are unchanged.

**Acceptance Criteria:**
- Given a name of more than 64 graphemes made of letters with combining marks, modified emoji and flags, when it is cleaned, then the result is its first 64 graphemes, each whole.
- Given a name of 64 graphemes or fewer that holds more than 64 code points, when it is cleaned, then it is unchanged.

## Implementation Notes

Oneshot: a one-line change to how the cleaned name is cut, plus its tests and two comments. `Accounts::PlayerSearch::MAX_QUERY` reuses `LENGTH` as the search field's HTML `maxlength` (UTF-16 units); a query is cleaned the same way, so the server-side cut only gets more permissive and nothing else depends on the code-point count. The column `persona_name` has no length limit.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` A 64-grapheme cut no longer bounds code points (one grapheme can carry thousands of combining marks), and `grapheme_clusters` builds the whole array before keeping 64 — patched the allocation with `each_grapheme_cluster.first(LENGTH)`; the length itself is unbounded by the intent's own choice of graphemes, the inputs are a Steam persona name (Steam caps its length) and a staff-only back-office query already bounded by the request size and an HTML maxlength, and a second code-point cap would add a new constant and a bound nobody chose, so that part is rejected as a low not met in everyday use. The Implementation Notes' "only gets more permissive" holds for what is kept, not for how long it may be.
  - `[low]` `[patch]` The existing test "a long name is cut to 64 characters, then stripped" still says characters — renamed to "cut to 64 graphemes".
  - `[low]` `[defer]` Planning ids remain in the edited comment blocks of `sign_in.rb` and `persona_name_test.rb` — pre-existing, logged in deferred-work.md with the repo-wide planning-id sweep.
  - `[low]` `[reject]` Execution checkboxes unticked in the plan — the fix is an edit of this plan; ticked at finalization as bookkeeping.

## Verification

**Commands:**
- `bin/rails test test/packs/accounts/persona_name_test.rb` -- expected: all pass
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: all pass

## Auto Run Result

- **Summary:** `Accounts::PersonaName.clean` now cuts a cleaned name to its first 64 extended grapheme clusters instead of 64 code points, so a letter keeps its combining marks, an emoji its skin-tone modifier and a flag both regional indicators; a name of 64 graphemes or fewer is unchanged.
- **Files changed:**
  - `packs/accounts/app/models/accounts/persona_name.rb` -- cut with `each_grapheme_cluster.first(LENGTH).join`; comment says graphemes.
  - `packs/accounts/app/operations/accounts/sign_in.rb` -- comment says graphemes.
  - `test/packs/accounts/persona_name_test.rb` -- names past the limit ending in combining marks, a modified emoji and a flag are cut after a whole grapheme; a mixed 66-grapheme name keeps 64; three names of 64 graphemes in 128 to 192 code points are kept.
  - `_bmad-output/initiative-gameble/deferred-work.md` -- planning ids left in the touched comment blocks, folded into the existing sweep.
- **Review:** quick lens, 4 findings; 2 patches applied (lazy grapheme cut, stale test name), 1 deferred (pre-existing planning ids), 1 rejected (plan edit). Patched by verdict: high 0, medium 0, low 2.
- **Follow-up review recommended:** false (no high or medium patched).
- **Verification:** `bin/rails test` 2361 runs, 0 failures; `npm run test:js` 225 tests in 24 files pass; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 693 files, no offenses.
- **Residual risk:** a single grapheme holding very many combining marks is kept whole, so the stored or searched name is bounded in graphemes, not in code points; Steam's own name limit and the request size bound it in practice.
