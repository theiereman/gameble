# Validation Report — gameble, Le Grand Inventaire

- **DESIGN.md:** `ux-gameble/DESIGN.md`, section Grand Inventaire, hub layout row, gold rule
- **EXPERIENCE.md:** `ux-gameble/EXPERIENCE.md`, section Le Grand Inventaire, IA rows, Copy deck row, State Patterns rows, Focus after each step, Flow 12, visitor lists, hub orders, profile visibility
- **Run at:** 2026-11-19
- **Scope:** the Grand Inventaire addition only, not the whole spine pair

## Overall verdict

The main screen was buildable from the start: its behaviour was precise and every token resolved. The review found gaps around it: visitors were not allowed on the new screens, the hub order disagreed across three places, the ranking page, tile and pinned bar had no visual rule, the pinned bar and scroll paging had no accessibility rules, and the privacy exception was stated once only. All were fixed in the spines on 2026-11-19, apart from the author's choices below.

The abuse review's main finding stands by the author's choice: private and friends-only players stay named, without a link, under their cards and in the boards; the visibility setting now says so.

## Findings by lens

| Lens | Critical | High | Medium | Low | File |
|---|---|---|---|---|---|
| Rubric | 0 | 1 | 13 | 13 | `review-grand-inventaire-rubric-2026-11-19.md` |
| Accessibility | 0 | 4 | 11 | 6 | `review-grand-inventaire-accessibility-2026-11-19.md` |
| Coherence | 0 | 5 | 13 | 13 | `review-grand-inventaire-coherence-2026-11-19.md` |
| Abuse and privacy | 0 | 1 | 6 | 3 | `review-grand-inventaire-abuse-2026-11-19.md` |

## Author decisions taken on the findings

- Private and friends-only players: kept, named without a link; the settings carry a note.
- Copy count: withdrawn, no count on any card (resolves the market-mapping and edition-mismatch findings).
- Banned and deleted players: neither ranked nor counted; "anonyme" under their cards.
- Season: scope chips TOUTES SAISONS (default) and SAISON EN COURS.

## High findings and their fix

- Visitors redirected to the landing: the new screens joined both signed-out lists.
- Hub order: DESIGN's duplicated "weekly mission" removed; the phone stack in Hub content gained the panel.
- Edition and season of "found": defined per scope.
- VOUS badge over the copy badge: the copy badge is gone.
- Pinned row focus and overlap: one persistent link, focus to the row, `scroll-padding-bottom`, not pinned under 560px of height.
- Scroll paging: a page `nav` of real links, Tab never loads, the address follows the page, a polite status.
- Focus steps: six rows added.
- Private activity exposed: kept by the author (see above).

## Open, deliberately not fixed here

- No spec capability or architecture note covers the new aggregates (two rankings, a viewer's position in a paginated ranking, all-season discovery reads); the build plans them.
- Rate limiting and caching of the public ranking for scrapers: an architecture concern, left to the build.
- Remaining `[ASSUMPTION]` tags: games no longer in the catalog, the second board following the scope, English copy and post-review lines, the tile's icon.
