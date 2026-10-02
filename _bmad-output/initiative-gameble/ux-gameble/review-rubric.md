# Spine Pair Review — gameble

## Overall verdict
The spine pair is a usable contract for the card, the attic, the pack reveal, the library and trades: decisions are committed, tokens resolve and each key screen has a mock. Its weak point is upstream: the spec still describes the earlier design and must adopt these files. Three areas remain thin and are flagged: how friends are made, what the achievements are, and the card detail view.

## 1. Flow coverage — adequate
Two key flows carry a named protagonist, numbered steps, a climax beat and a failure path: Léa's first session and the trade between Hugo and Léa. They cover sign-in, packs, reveal, collection, card detail, public profile, sharing, trades, the feed and the daily bonus.
### Findings
- **medium** No flow shows how two players become friends (EXPERIENCE.md, Key Flows, Flow 2 step 1). Flow 2 assumes the friendship exists. The spec offers an invite link or a friend code (CAP-10). *Fix:* Narrate the friend invitation, or accept the assumption when the spec is updated.
- **medium** Achievements have no flow and no defined content (EXPERIENCE.md, Component Patterns). The author asked for simple achievements on their own screen; none is named. *Fix:* List the achievements before the screen is built.
- **low** Data controls and moderation have no flow (EXPERIENCE.md, Information Architecture). CAP-14 and CAP-15 are described plainly from the spec, by decision. *Fix:* None needed unless these screens grow.

## 2. Token completeness — adequate
Every colour token has a hex value and every {token} reference resolves. Contrast is stated for the load-bearing pairs, and the rarity colours that fail on parchment are barred from text.
### Findings
- **medium** Gold values are provisional (DESIGN.md, Colors). Legendary cards use gold values chosen for the mocks. *Fix:* Confirm or replace the three gold tokens.
- **low** Card title size is not a token (DESIGN.md, typography). The mocks use 15px on the large card and 12px on the small one. *Fix:* Add the two sizes if implementers need them.
- **low** Scene colours are not tokens (DESIGN.md, The attic). Brick and parquet colours belong to the art, not to the interface. *Fix:* Leave to the final art.

## 3. Component coverage — adequate
Cards, seals, dust, the attic objects, the gauge, buttons, the bonus panel, tomes, empty slots and the trade board have a visual entry and a behavioural entry.
### Findings
- **medium** The card detail view has no visual spec and no mock (DESIGN.md, Components). Its content is listed in the Information Architecture; the shared-card mock shows a close cousin. *Fix:* Mock it, or state that it follows the shared-card layout.
- **low** The feed entry is an assumption without a mock (DESIGN.md, Other components). The feed excerpt was removed from the shared-card page. *Fix:* Mock the feed screen when it is designed.

## 4. State coverage — adequate
Signed-out, first session, packs, daily bonus, sets, the four trade states, goal reached, refused opening, empty collection, quiet feed, missing image and focus are covered.
### Findings
- **low** No empty state for the friends list, the trade list and achievements (EXPERIENCE.md, State Patterns). These screens were not narrated. *Fix:* Add them when the screens are designed.
- **low** No loading state for card art (EXPERIENCE.md, State Patterns). Art is fetched from Steam and filtered in the browser, so a card exists briefly without its image. *Fix:* State what the art window shows meanwhile.

## 5. Visual reference coverage — strong
Four mockups are linked inline where they apply: card face, card backs, attic, key screens. The imported reference image is linked with its reconciliation note. Spines-win-on-conflict is stated once.
### Findings
- None.

## 6. Bloat & overspecification — strong
Tables carry most of the content and the prose stays tied to decisions.
### Findings
- **low** "Not in the MVP" restates scope (EXPERIENCE.md, Interaction Primitives). The list repeats product scope, yet it stops implementers from adding those interactions. *Fix:* Keep.

## 7. Inheritance discipline — thin
Sources resolve and names match across the two spines. The spec, however, still describes the earlier contract.
### Findings
- **high** The spec contradicts the spines on thirteen points (ux-gameble.md, Changes this run asks of the spec). Reveal by glow, sets by genre, decade and publisher, no daily bonus, no achievements, a feed that is not public, and more. *Fix:* Run bmad-spec to adopt the spines and apply the listed changes.

## 8. Shape fit — strong
DESIGN.md follows the canonical order. EXPERIENCE.md has every default section, plus Responsive & Platform and Inspiration & Anti-patterns, both triggered.
### Findings
- None.

## Mechanical notes
- Run inline by the facilitator, without subagents.
- Findings fixed during the review are not listed: missing Inspiration & Anti-patterns section, unlinked import, missing visual entries for the trade board, secondary button, back button and rarity counter, missing states from the spec (refused opening, quiet feed, hidden or banned profile).
- Ten items in EXPERIENCE.md and one in DESIGN.md keep an `[ASSUMPTION]` tag.
