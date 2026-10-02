# Art prompts: the attic

Prompts for an image generator, to produce the final pixel art of the landing room. The composition and the list of objects come from `mockups/attic.html`; `DESIGN.md` wins on conflict.

## Rules for every image

- 16-bit pixel art, no anti-aliasing, no blur, no gradients.
- Hard outline in dark brown `#2b1d10`. Light comes from the top left.
- Warm palette: parchment `#e9dcc0` `#f4ead2`, brass `#5c4026` `#8f6a43` `#c4a173` `#ecdcb8`, leather `#7a3410`, rust `#8a3b12`, gold `#f0b429`, with small accents in emerald `#2e9e4f`, sapphire `#2b6fd6` and amethyst `#8e44c9`.
- Draw at the size given in art pixels, then scale by exactly 2 with nearest-neighbour. One art pixel is 2 screen pixels everywhere in the application.
- Mood: the chapter hall of a secret brotherhood. Mystical, ancient, castle-like. Nothing realistic.

## Background (500 × 220 art pixels)

> 16-bit pixel art game background, side view of a room, 500x220 pixels, no characters, no furniture. Back wall of old bricks, richly detailed: worn bricks, a few pale stone bricks, uneven mortar, small cracks. A dark wooden baseboard. Floor of detailed chevron parquet in warm brown wood, about 48 pixels tall. At the far left edge, a stone gothic window cut in half by the border of the image, showing only a pale blue sky and distant mountains, nothing flying. Warm sepia palette, hard dark-brown outlines, light from the top left, no anti-aliasing.

## Objects (transparent background, one image each)

Common ending for each prompt: `16-bit pixel art game sprite, front view, transparent background, hard dark-brown outline, light from the top left, warm sepia and brass palette, no anti-aliasing.`

| Object | Leads to | Size (art px) | Prompt |
|---|---|---|---|
| Lectern | Library | 66 × 80 | A wooden lectern holding a huge open grimoire with a red ribbon bookmark. No chain. |
| Notice board | Brotherhood feed | 66 × 62 | A wooden notice board hung on a wall by a rope and a nail, covered with pinned parchments and small red wax seals. No legs. |
| Medal display | Achievements | 54 × 70 | A gold-framed wall display with three medals on red cloth, their ribbons in sapphire, amethyst and emerald, and a small parchment label. |
| Standing mirror | Profile | 48 × 92 | An ornate oval mirror in a brass frame on a brass stand. |
| Trade table | Trades and friends | 98 × 66 | A carved dark-oak table with a red cloth runner hanging at the front, edged in gold with a gold ring emblem; on the table a brass balance scale in the middle and a deck of cards at each end. No chairs. |
| Chest | Pack opening | 74 × 54 | An iron-bound wooden chest with a rounded lid and a brass lock, standing on the floor. |

## Checks before use

- Every edge sits on the 2-pixel grid once scaled.
- Each object reads at its real size on the brick wall.
- Object names stay as interface text beside the object; nothing is written inside the art.
