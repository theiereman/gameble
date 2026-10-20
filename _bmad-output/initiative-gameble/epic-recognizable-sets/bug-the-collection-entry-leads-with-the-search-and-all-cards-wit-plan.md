---
title: 'The collection entry leads with the search and all cards, without À DÉCOUVRIR'
type: 'bugfix'
ticket: '18'
created: '2026-10-20'
status: 'built'
baseline_revision: 'f6183872d091ffd58b61ba16a6d2a6b564e769af'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The first build of this ticket (2026-10-19) put the collection entry in the order search, EN COURS, RÉSULTATS. Reviewing it on 2026-10-20, the author asked for the set search results to show before EN COURS, so a search answers right under the field. Everything else from that build was accepted.

**Approach:** On the collection entry (`/library`, public and friends' profiles), the results frame moves between the search section and EN COURS (or the pointer line), so the order becomes CHERCHER UN SET, its status line, RÉSULTATS when there is a query, then EN COURS. The search's behaviour, the hub, the album and the grid are unchanged. EXPERIENCE.md and DESIGN.md record the new order.

</frozen-after-approval>

## Implementation Notes

Oneshot: a few lines move in one partial, three assertions on the order change in the tests, and two doc lines are updated.

- The previous build (dc48b5b2 and the build commit after it) kept EN COURS still while typing. Now the results push EN COURS down as they arrive. This is the author's choice.
- `.set-entry > turbo-frame { display: contents; }` in `collection.css`: with no query the frame holds only a hidden span, and between the search and EN COURS it would otherwise add a second flex gap.
- Changed: `app/views/library/_entry.html.erb`, `app/frontend/styles/collection.css`, `test/controllers/library_controller_test.rb`, EXPERIENCE.md (Collection opening, Set album's h2s, Set search), DESIGN.md (Collection entry).

## Plan Change Log

- 2026-10-20: re-planned from the author's review of the built ticket. The order is now search, status, RÉSULTATS, EN COURS. The rest of the first build's plan (the board without discover, the primary button, the pointer line, the phone stacking) is kept as built.

## Review Triage Log

### 2026-10-20 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 0, maybe-false 0; 1 rejected
- `[low]` `[patch]` EXPERIENCE.md's Set search row still said results sit below EN COURS and never move it — rewritten to the new order.
- `[low]` `[patch]` Nothing pinned the results above the pointer line for a player with no set in progress — `library_controller_test.rb` asserts `.set-search + turbo-frame#set-search-results + p.set-entry__empty` on a search.
- `[reject]` `display: contents` removes the frame's box for later scrolling or measuring — no code scrolls to or measures the frame (no `autoscroll` in `app/views/library`), and the rule is recorded in the Implementation Notes.

## Verification

**Commands:**
- `bin/rails test test/controllers/library_controller_test.rb test/controllers/public_profiles_controller_test.rb test/controllers/library_set_test.rb` -- expected: green
- `bin/rails test` and `npm run test:js` -- expected: green

**Manual checks (if no CLI):**
- `/fr/library?q=souls`: the h2s read "Chercher un set", "Résultats", "En cours".
