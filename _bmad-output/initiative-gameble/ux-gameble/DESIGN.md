---
name: gameble
description: Pixel-art trading card game of Steam games, dressed as the secret archives of the Brotherhood. Light parchment, brass and leather, one pixel size everywhere.
status: final
created: 2026-10-01
updated: 2026-10-02
colors:
  bg: '#e9dcc0'
  surface: '#f4ead2'
  surface-sunken: '#e2d1ad'
  ink: '#2b1d10'
  ink-muted: '#6b5640'
  accent: '#8a3b12'
  on-accent: '#f4ead2'
  danger: '#a3241c'
  success: '#3f6b2a'
  leather: '#7a3410'
  leather-dark: '#64290c'
  brass-dark: '#5c4026'
  brass: '#8f6a43'
  brass-light: '#c4a173'
  brass-highlight: '#ecdcb8'
  gold-dark: '#a8741a'
  gold: '#f0b429'
  gold-light: '#ffe08a'
  dust: '#a89676'
  dust-light: '#c9b994'
  rarity-steel: '#7d8a99'
  rarity-steel-dark: '#56616e'
  rarity-steel-light: '#aab6c2'
  rarity-emerald: '#2e9e4f'
  rarity-emerald-dark: '#1d6e36'
  rarity-emerald-light: '#63cf7e'
  rarity-sapphire: '#2b6fd6'
  rarity-sapphire-dark: '#1c4a99'
  rarity-sapphire-light: '#6aa3f2'
  rarity-amethyst: '#8e44c9'
  rarity-amethyst-dark: '#612b8f'
  rarity-amethyst-light: '#b97be8'
typography:
  title:
    fontFamily: Jost
    fontWeight: 700
    fontSize: 20px
  body:
    fontFamily: Jost
    fontWeight: 400
    fontSize: 15px
    lineHeight: 1.3
  label:
    fontFamily: Jost
    fontWeight: 700
    fontSize: 13px
  card-title:
    fontFamily: Jost
    fontWeight: 700
  card-mark:
    note: 'Pixel-drawn digits and letters, 5 art pixels tall: year tag and season seal only.'
rounded:
  DEFAULT: 0px
spacing:
  unit: 2px
  '1': 2px
  '2': 4px
  '3': 8px
  '4': 12px
  '5': 16px
  '6': 24px
  '7': 32px
  plate-padding-y: 4px
  plate-padding-x: 12px
components:
  card:
    size-small: 160px x 240px
    size-large: 240px x 360px
    frame: '{colors.brass}'
    frame-legendary: '{colors.gold}'
    plate: '{colors.surface}'
    text: '{colors.ink}'
  card-back:
    leather: '{colors.leather}'
    metal: '{colors.brass}'
    metal-legendary: '{colors.gold}'
    medallion: '{colors.surface-sunken}'
  card-art:
    pixel-size: '{spacing.unit}'
    palette-size: 16
  dust:
    fill: '{colors.dust}'
    speck: '{colors.dust-light}'
  text-plate:
    background: '{colors.surface}'
    border: '{colors.ink}'
    padding: '{spacing.plate-padding-y} {spacing.plate-padding-x}'
  button-primary:
    background: '{colors.accent}'
    text: '{colors.on-accent}'
    border: '{colors.ink}'
  goal-gauge:
    track: '{colors.bg}'
    fill: '{colors.accent}'
    border: '{colors.ink}'
---

## Brand & Style

gameble looks like the secret archives of *La Grande Confrérie des Gamblers*: parchment, worn leather bindings, brass fittings, wax seals and dust. Art is 16-bit pixel art; text is a clean modern sans-serif that sits quietly beside it.

One pixel size rules all art: one art pixel is 2 CSS pixels (`{spacing.unit}`). Frames, shadows, scenery and card art all sit on that grid. Nothing is drawn finer, nothing coarser.

Pixel art is also a production choice. Interface art is AI-generated, and realistic AI images quickly look like slop; pixel art holds up.

Two screens are decorated rooms: the attic, where packs are opened, and the library, where the collection lives. Every other screen is plain parchment without room decor.

## Colors

The base is the light theme "Parchemin au grand jour".

- **Parchment (`{colors.bg}`, `{colors.surface}`, `{colors.surface-sunken}`)** carries every screen and the text plate of a card.
- **Ink (`{colors.ink}`)** draws all outlines, shadows and primary text. Contrast on parchment is 12:1 or more.
- **Muted ink (`{colors.ink-muted}`)** is for secondary text such as the publisher credit. Contrast on parchment is 5.1:1 or more.
- **Rust (`{colors.accent}`)** marks the primary action, the gauge fill and the season seal. Text on rust uses `{colors.on-accent}` (6.5:1).
- **Leather and brass** build the bindings: card backs, card frames, straps and corners.
- **Gold** replaces brass on legendary cards only. The values are provisional.
- **Dust (`{colors.dust}`, `{colors.dust-light}`)** is laid semi-transparent over card backs.

Rarity has five colours, used on the seal, the gems of the card back, the piping of the card face and the counters of the status band:

| Tier | Name | Colour |
|---|---|---|
| 1 | Steel (common) | `{colors.rarity-steel}` |
| 2 | Emerald | `{colors.rarity-emerald}` |
| 3 | Sapphire | `{colors.rarity-sapphire}` |
| 4 | Amethyst | `{colors.rarity-amethyst}` |
| 5 | Gold (legendary) | `{colors.gold}` |

Rarity colours are never used for text on parchment: steel, emerald and gold fall below 3:1 there.

## Typography

- **Jost** is the only typeface: a modern sans-serif under an open licence (OFL), with French accents. It sets titles, labels, running text and card titles.
- Card titles wrap to two lines at most.
- Two small marks on the card stay pixel-drawn: the year tag and the season seal.
- The font file lives in the repository.

## Layout & Spacing

The spacing scale is built on the 2px unit: 2, 4, 8, 12, 16, 24, 32.

- **Text plates need air.** Any text on its own background (caption, timer, counter, button, panel) keeps at least 4px above and below and 12px on each side. Text never touches the edge of its plate.
- **Cards** come in two sizes, both in a 2:3 ratio: small (80 × 120 art pixels, shown at 160 × 240) for grids, and large (120 × 180 art pixels, shown at 240 × 360) for the detail view and the phone reveal.
- **The status band** sits above every screen: the weekly goal gauge at top left, wide enough to read at a glance; at top right, the packs available and the cards owned per rarity.
- **The attic on desktop** is one wide room: objects spread across the width, the chest in the middle.
- **The attic on phone** is the same wide room, panned sideways with a finger. It opens centred on the chest.

## Elevation & Depth

Depth is a hard shadow: an ink offset of one unit down and to the right, never blurred. Raised elements are cards, buttons and panels. There are no soft shadows, glows or gradients.

## Shapes

Corners are square (`{rounded.DEFAULT}`). Round shapes exist only as pixel-drawn objects: seals, medallions, gems and scenery.

## Components

### Card face

The art fills the card inside the binding frame. Reference: [mockups/card-face.html](mockups/card-face.html), layout A, with titles in Jost as in [mockups/key-screens.html](mockups/key-screens.html).

- **Frame:** brass, then an ink line, a 2-pixel piping in the rarity colour, and an ink line.
- **Art:** the game's vertical Steam image. It is pixelated at the application's pixel size and reduced to 16 colours computed per image, without dithering. The treatment runs in the browser at display time.
- **Text plate:** at the bottom, on `{colors.surface}`: the title, then the publisher credit in `{colors.ink-muted}` on the large size. The small size drops the credit.
- **Year tag:** the release year, top left of the art.
- **Season seal:** a small round rust seal with the season number, bottom right of the art.
- **Legendary:** gold frame, a light band sweeping across the card, and blinking sparkles.
- The description is not on the card.

### Card back

A leather binding with brass fittings. Reference: [mockups/card-backs.html](mockups/card-backs.html). The structure follows the author's reference image, `imports/hearthstone-card-back-reference.png`; `reconcile-hearthstone-card-back-reference.md` lists what was kept.

- **All backs:** thick frame, lozenge-grain leather, piping with studs, a strap across the middle, a central medallion that holds the rarity seal, and a fleuron above and below with a gem in the rarity colour.
- **Tiers 1 to 4:** square corners, double strap, brass.
- **Legendary:** rounded corners, studded strap, gold fittings, double piping, rays around the medallion and sparkles. No text.
- The pixel mocks fix the composition. Final art is redrawn on the same layout.

### Rarity seal

One seal per tier, each with the letter G:

| Tier | Seal |
|---|---|
| Steel | Ink stamp, single ring |
| Emerald | Ink stamp, double ring |
| Sapphire | Wax seal |
| Amethyst | Wax seal with ribbon |
| Gold | Scalloped gold seal |

### Dust

Dust covers the card back and tells the age of the game. It is semi-transparent, starts at the edges and corners, and reaches the centre as the tier rises.

| Age of the game | Dust |
|---|---|
| Under 1 year | None |
| 1 to 5 years | Light |
| 5 to 10 years | Marked |
| 10 to 20 years | Thick |
| Over 20 years | Buried: the seal is almost hidden |

### The attic

The landing room, furnished as the chapter hall of a Brotherhood: mystical, ancient, castle-like. Reference: [mockups/attic.html](mockups/attic.html).

- **Back wall:** old bricks, well detailed: worn bricks, uneven joints.
- **Floor:** a detailed chevron parquet.
- **Window:** at the very left edge, half cut by the screen. It shows sky and mountains, with nothing flying. It is decor: it only tells the player they are in a room.
- **Scenery objects:** each piece of furniture leads to a screen.

| Object | Leads to |
|---|---|
| Lectern with an open grimoire | Library |
| Notice board hung on the wall | Brotherhood feed |
| Framed medal display on the wall | Achievements |
| Standing mirror | Profile and settings |
| Carved table with a cloth runner, a brass balance scale and two decks | Trades and friends |
| Iron-bound chest, on the floor | Pack opening |

The mocks are program-drawn sketches. They fix the list of objects and the composition; the final art is generated in the same pixel style.

### Other components

- **Text plate:** caption, timer and counter backgrounds: `{colors.surface}`, ink border, padded as in Layout & Spacing.
- **Goal gauge:** a horizontal bar, rust fill, ink border, its label inside.
- **Primary button:** rust fill, ink border, hard shadow.
- **Secondary button:** parchment fill, ink border, hard shadow. It serves "flip all", counter-proposal, decline and the back button.
- **Back button:** a secondary button at the left of the status band, on every screen except the attic.
- **Rarity counter:** a small square in the rarity colour with an ink border, followed by the count.
- **Trade board:** two stacked sides. The other player's side is on `{colors.surface-sunken}`, the player's own on `{colors.bg}`; between them a `{colors.surface}` strip carries the status line and the actions. Reference: [mockups/key-screens.html](mockups/key-screens.html).
- **Feed entry:** `[ASSUMPTION]` one line of text per event, with a rarity counter square after the card name.
- **Daily bonus panel:** an interface panel beside the chest, not an object of the scenery.
- **Tome:** a book on the library shelf that opens onto the slots of a set. Reference: [mockups/key-screens.html](mockups/key-screens.html).
- **Empty slot:** a dashed frame on `{colors.surface-sunken}` with the name and year of the missing game.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Keep all art on the 2px grid | Mix pixel sizes on one screen |
| Pixelate and reduce Steam art in the browser | Store or serve modified copies of Steam art |
| Show rarity by seal shape and colour together | Rely on colour alone to tell rarity |
| Use hard ink shadows | Use blur, glow or gradients |
| Pad every text plate | Let text touch the edge of its background |
| Keep room decor to the attic and the library | Decorate the feed, trades, profile or settings as rooms |
| Use gold on legendary cards only | Use gold as a general accent |
| Credit the publisher on the large card and in the detail view | Put the description on the card |
| Use AI-generated art in pixel style | Use realistic AI-generated images |
| Keep the window view calm: sky and mountains | Put flying or floating elements in the view |
