---
title: "The capsule's enlarged reveal card shows no game category"
ticket: "bug-the-capsule-reveal-card-shows-no-game-category"
status: blocked
blocked_at: "2026-10-19"
blocked_reason: "intent gap: the reveal face does render the main theme; Dreamfall: The Longest Journey has none (a UFO card), so showing its category needs an author decision on what a theme-less card shows"
---

## Auto Run Result

**Status:** blocked (intent gap). No code changed.

**Cause found.** The enlarged reveal face does render the main theme. The phone zoom (`app/frontend/components/BoosterView.tsx`, `face={zoomed.faces.xl}`) shows the xl face that `PacksHelper#pack_faces` renders with `CardComponent`. That component prints `.card__genre` whenever `card.genre` (the card-season's `main_theme`, from `Catalog::CardViews`) is set, and no stylesheet hides it in the booster or the zoom. So the card has no main theme. Dreamfall: The Longest Journey (Steam app 6300) has these five most-voted tags on SteamSpy: Adventure, Female Protagonist, Story Rich, Fantasy, Sci-fi. `Steam::CardMapping` reads only those five (`TOP_TAGS = 5`), and none of them belongs to a `Catalog::Themes` theme. The card is therefore a UFO, and `PublishSeason` stored `main_theme` as NULL. Every other face omits the genre for such a card in the same way: the grid, the card detail, the public card page and the hub showcase. The same NULL would come from a season published before themes existed. Staging's database was not read to tell the two apart, and `main_theme` is frozen once the season is published.

**Why blocked.** The acceptance asks that "Dreamfall shows its category on staging" and also that a card with no main theme "shows the same fallback as the other card faces", which today means no genre at all. Meeting both needs a product decision the intent does not make. Each option gives a visibly different result:
1. A theme-less card shows the UFO kind as its genre ("OVNI" / "UFO") on every card face and in the detail. This is the only option that changes Dreamfall on staging, because the stored data stays as it is.
2. The theme list gains a theme that covers these tags (for example Adventure / Story Rich). That only reaches seasons published afterwards: Dreamfall's published card-season keeps no theme.
3. Close as working as designed.
