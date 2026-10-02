# Validation Report — gameble

- **DESIGN.md:** `DESIGN.md`
- **EXPERIENCE.md:** `EXPERIENCE.md`
- **Run at:** 2026-10-02T12:34:42+02:00

## Overall verdict
The spine pair is a usable contract for the card, the attic, the pack reveal, the library and trades: decisions are committed, tokens resolve and each key screen has a mock. Its weak point is upstream: the spec still describes the earlier design and must adopt these files. Three areas remain thin and are flagged: how friends are made, what the achievements are, and the card detail view.

## Category verdicts
- Flow coverage — adequate
- Token completeness — adequate
- Component coverage — adequate
- State coverage — adequate
- Visual reference coverage — strong
- Bloat & overspecification — strong
- Inheritance discipline — thin
- Shape fit — strong

## Findings by severity

### Critical (0)
None.

### High (1)
**Inheritance discipline** — The spec contradicts the spines on thirteen points (ux-gameble.md, Changes this run asks of the spec)
Reveal by glow, sets by genre, decade and publisher, no daily bonus, no achievements, a feed that is not public, and more.
Fix: Run bmad-spec to adopt the spines and apply the listed changes.

### Medium (4)
**Flow coverage** — No flow shows how two players become friends (EXPERIENCE.md, Key Flows, Flow 2 step 1)
Flow 2 assumes the friendship exists. The spec offers an invite link or a friend code (CAP-10).
Fix: Narrate the friend invitation, or accept the assumption when the spec is updated.

**Flow coverage** — Achievements have no flow and no defined content (EXPERIENCE.md, Component Patterns)
The author asked for simple achievements on their own screen; none is named.
Fix: List the achievements before the screen is built.

**Token completeness** — Gold values are provisional (DESIGN.md, Colors)
Legendary cards use gold values chosen for the mocks.
Fix: Confirm or replace the three gold tokens.

**Component coverage** — The card detail view has no visual spec and no mock (DESIGN.md, Components)
Its content is listed in the Information Architecture; the shared-card mock shows a close cousin.
Fix: Mock it, or state that it follows the shared-card layout.

### Low (7)
**Flow coverage** — Data controls and moderation have no flow (EXPERIENCE.md, Information Architecture)
CAP-14 and CAP-15 are described plainly from the spec, by decision.
Fix: None needed unless these screens grow.

**Token completeness** — Card title size is not a token (DESIGN.md, typography)
The mocks use 15px on the large card and 12px on the small one.
Fix: Add the two sizes if implementers need them.

**Token completeness** — Scene colours are not tokens (DESIGN.md, The attic)
Brick and parquet colours belong to the art, not to the interface.
Fix: Leave to the final art.

**Component coverage** — The feed entry is an assumption without a mock (DESIGN.md, Other components)
The feed excerpt was removed from the shared-card page.
Fix: Mock the feed screen when it is designed.

**State coverage** — No empty state for the friends list, the trade list and achievements (EXPERIENCE.md, State Patterns)
These screens were not narrated.
Fix: Add them when the screens are designed.

**State coverage** — No loading state for card art (EXPERIENCE.md, State Patterns)
Art is fetched from Steam and filtered in the browser, so a card exists briefly without its image.
Fix: State what the art window shows meanwhile.

**Bloat & overspecification** — "Not in the MVP" restates scope (EXPERIENCE.md, Interaction Primitives)
The list repeats product scope, yet it stops implementers from adding those interactions.
Fix: Keep.

## Reviewer files
- `review-rubric.md`
