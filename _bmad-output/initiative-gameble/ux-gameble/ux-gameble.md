---
title: "UX: gameble"
status: final
created: 2026-10-01
updated: 2026-10-02
sources:
  - ../spec-gameble/spec-gameble.md
  - ../brief-gameble/brief-gameble.md
---

- [DESIGN.md](DESIGN.md): visual identity (how it looks).
- [EXPERIENCE.md](EXPERIENCE.md): structure, behavior, flows (how it works).

## Changes this run asks of the spec

Decisions taken during the UX work that change the product contract. They reach the spec through `bmad-spec`.

- **Reveal (CAP-5):** dust and rarity seal replace the rarity glow.
- **Images:** never copied; pixelated and reduced to 16 colours in the browser at display time. The spec says "never copied or transformed".
- **Catalog (CAP-2):** games without a vertical Steam image are excluded. The release date is imported.
- **Card text:** the description is in the detail view only, not on the card.
- **Share preview (CAP-9):** no game image in the preview.
- **Sets (CAP-6):** publisher sets, tomes (each genre in volumes of about thirty games by release year) and "best rated of year X" sets of 10. Empty slots name the missing game.
- **Packs (CAP-4):** a new account starts with 10 packs banked. A sapphire or better is guaranteed by the 10th pack.
- **Draw odds:** about one legendary every 400 packs. Proposed per card: common 76%, emerald 19%, sapphire 4.3%, amethyst 0.65%, legendary 0.05%.
- **Trades (CAP-11):** asynchronous, with counter-proposals. Live trades come later.
- **Weekly goal (CAP-12):** trades count a little, alongside pack openings.
- **Feed (CAP-13):** public, readable without an account.
- **New in the MVP:** a daily login bonus (a small booster with better odds) and simple achievements.
- **Signed-out visitors:** they can see everything that needs no account, but cannot act (no pack opening, no trade); acting opens the Steam sign-in.
- **Packs:** opened one at a time, never in bulk.
- **Not in the MVP:** a guide.
- **Later:** card marks (favourite, to trade, personal categories), the owner's Steam library info on a shared card, sets built from Steam tags.
