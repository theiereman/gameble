# Card series that mean something

**Problem.** Tomes (a genre cut into volumes of ~30 by release date) are unrecognizable, and the collection's set list is unreadable: nobody browses it to see what they are completing. Rework both, even from scratch.

**Decisions**
- Every card belongs to at least one series. Recognition, not size, decides whether a series exists.
- Families: **Theme** (backbone, curated list of ~30 Steam tags, tiered); **Franchise** and **Studio** (small, finishable, "complete" only); **Hall of fame** from Steam review stats (Untouchables, Hidden Gems, Unloved, Phenomena; tiered).
- A game joins every listed theme among its 5 most-voted tags; one card can advance several series. A game with none joins **the UFOs** (Les OVNI).
- Tiers bronze / silver / gold make large series motivating without splitting them.
- The collection opens on series: "In progress" (personal, sorted by closeness to the next tier or completion), then a short "To discover" row, then search. A series opens as an album page with empty slots and its tiers.
- The full card grid with filters stays as a secondary view, for trades and sales later.
- Rewards: bronze/silver → celebration + feed line; gold → a card back of that series; complete (franchise, studio, UFOs) → "complete" stamp + feed line.
- Profile title, seen by everyone, earned on every complete and every tier ("Completionist · Dark Souls", Apprentice / Adept / Master); a no-agreement template; one active title.
- Menu theme (accent colour, contrast checked) for a rare meta goal: N series at gold.

**Rejected**
- Tomes, publisher sets, best rated of the year: replaced by themes, studios, hall of fame.
- Era series (too vague) and editorial series (stay V3).
- One theme per game (kills the "three series at once" moment); all 20 tags (fuzzy borders).
- A fixed list of major series (today's problem again); a purely personal list (empty for new players).
- A card back per completed set: hundreds of backs to draw.

**Changes to existing work**
- Spec: sets section of `catalog-and-rarity.md`; card backs rule ("completing a set unlocks a back" → "gold on a large series"); collection capability.
- Import: keep `developers` and `franchises` from GetItems (already requested via `basic_info`).
- Built: `Catalog::SetBuilder`, set kinds check, library screens, `SetCompleted` consumers.

**Open**
- Minimum size of franchise / studio series; reliability of Steam's `franchises` field (check on real data).
- The theme list; the UFOs must stay under ~5% of the catalog, else fix the list.
- Hall of fame thresholds; tier percentages; how series relate to seasons.
