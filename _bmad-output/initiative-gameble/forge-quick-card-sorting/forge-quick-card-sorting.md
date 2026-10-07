# Quick card sorting from the booster opening (V2)

**Problem.** Acting on a card (sell, discard) means leaving the booster screen and searching the collection. The action must be possible in place.

**Decisions**
- Marking happens in place, during the opening, one card at a time; the player stays active (no automatic default sorting).
- Desktop: drag a card into the "to process" zone. Phone: swipe or buttons on the card; buttons stay for accessibility.
- Marking only moves a card to "to process"; nothing is irreversible. One validation sells or discards everything in the zone.
- Cards in "to process" no longer count in the collection. A card can be taken back until validation.
- Marking the only copy of a card needs an extra confirmation; spare copies need none.
- "To process" can be its own screen, on desktop too, and must be as legible as possible so reviewing every pending card is fast.
- Nothing is built before V2: it needs currency, card destruction and the market.

**Rejected**
- Immediate swipe that sells or discards on phone: too dangerous.
- Automatic sorting of duplicate commons by default: the player must decide, since some commons are kept for a set or a loved game.

**Open for V2**
- A per-copy "to process" state must fit the V2 copy model without a heavy migration; check in the architecture.
- Show what the zone would yield, so it does not become a chore.
