# Forged idea: seasons carry the collection over

Problem: publishing a season leaves the player with an empty collection, set progress back to zero and the total counter at 0. Lost set progress is what hurts.

## Decisions

- **Season = reprint.** A set (theme, franchise, studio, hall of fame, UFOs) is the same set across seasons; a copy of a game counts for it whatever its minted season. A new season recomputes rarities and brings games in; progress carries on.
- **Editions.** Each copy keeps its minted rarity and season (its edition). The destruction value is fixed by the minted rarity, so a season change creates no arbitrage. Market value is left to players; listings show the edition.
- **Earned stays earned.** A tier reached and its reward are never lost and carry the mark of the season they were earned in. A tier that falls below its threshold can be earned again with the new season's mark; collecting each season's marks is what veterans chase.
- **Live percentage.** A set's percentage is computed on the current season's set and may drop when the set grows, shown as new cards to find, never as a loss. A copy whose game left a set stops counting for that set only.
- **Seasonal allocation screen.** At the first visit after a publication, a dedicated screen (Rocket League style) recaps what the player unlocked in the season that ended and the sets that follow them. One Brotherhood line heads it ("seasonal allocation"). Nothing is written at publication.
- **Counter and grid.** The total counter counts distinct games across editions and never drops between seasons. One tile per game, best owned rarity, an edition count when several are held; the card page lists owned editions grouped by rarity, folded.
- **No clutter at 30 seasons.** No season chips in the grid; a set shows its latest mark and a count ("Gold · 12 seasons") with per-season detail on demand; the equipped back shows only the chosen season's mark.

## Rejected

- **Season = expansion** (per-season sets kept side by side): sets are themes and franchises, not dated expansions; several "Roguelike" sets would confuse.
- **Displaying the highest tier ever reached**: replaced by the live tier plus past season marks.
- **A chip season selector in the collection**: loses its purpose and saturates; at most an edition filter.

## Amends beyond this idea

- `brotherhood-tone.md`: the one-line rule is too strict. The Brotherhood speaks at collective moments (weekly goal, seasonal allocation), at most one line per screen.
- `plan-collection-season-selector.md` (ready-for-dev): hold it; rethink or cancel.

## Open

- Whether production already has real players: sets the migration cost of today's per-season set and tier rows.
- Season mark look (watermark over the existing back vs a new style): cost decided in UX.
- First discoveries, counted per card-season today: per game or per edition.
- V2: average sale price per game, per minted rarity or per edition.
