# Card and reveal

Referenced by CAP-5, CAP-7, CAP-9.

## Card

- **Identity:** a gameble-designed frame carries the identity, with a rarity effect and the Brotherhood house style. It must not look generic or template-made.
- **Art style:** 16-bit pixel art for the frame and interface. How untouched, full-colour Steam art sits inside it is settled in the UX work.
- **Image:** the game's official Steam art is inset in the frame, loaded as-is from Steam's CDN.
- **Text:** the title and a short description, in the player's UI language.
- **Credits:** the publisher and copyright are shown on the card.
- **No image:** there is no fallback art. A card whose image no longer loads still shows its frame and title.

## Pack reveal

- **Layout:** 5 cards land face down. Each glows in its rarity colour, always visible, which works on mobile.
- **Desktop:** hovering intensifies the glow with a slight 3D tilt.
- **Order:** the player chooses the order and flips each card with a click or tap.
- **Timing:** reveal duration and intensity scale with rarity. Commons flip in a blink; a legendary gets an over-the-top reveal.
- **Flip all:** a "flip all" control reveals the remaining cards quickly, except that a legendary always plays its full reveal.
