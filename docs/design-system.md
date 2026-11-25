# Design system

Every screen of Gameble follows these rules. Read this file before you build or restyle a screen. When a screen disagrees with it, the screen is wrong. Values live in `app/frontend/styles/tokens.css`. This file says how to use them.

The rules sit above the visual identity (console frame, pixel art, VT323 and JetBrains Mono, the colours in the tokens) and never change it. They only cover layout, hierarchy and the shared components.

## Principles

- **The essentials stand out, the rest is decor.** What the player has to read or act on (a count, a price, a balance, the main action) is the largest and brightest thing on the screen. Lore and flavour text is rare, short, small and muted. Never add a sentence that only repeats what the screen already shows.
- **One shape per screen, whatever the state.** A new player and a regular see the same structure; only the values change. A counter shows `0`; it is never replaced by a welcome block.
- **"Go there" cue.** A link, a tile or a panel title that leads somewhere ends with the Lucide chevron-right (`chevron_icon`, `app/frontend/images/lucide/chevron-right.svg`), never a ▸ in the text or a pixel arrow. A pixel arrow is kept only where it is the control itself (previous/next, the phone back button), on what folds (its chevron turns), and on the hub menu entries.
- **Same job, same component.** Before you write a new class for a panel, a heading, a tile, tabs or a sort, use the shared component below.

## Page layout

- A screen's root takes one of three widths, always centred, never pinned to the left. Give the root `page page--wide`, `page page--regular` or `page page--reading` (`page.css`, widths `--page-width-*` in the tokens):

  | Width | Value | For |
  | --- | --- | --- |
  | wide | 1280px | grids and dashboards: Bridge, Market, Feed, Capsule, all cards |
  | regular | 960px | Collection, Me, Settings, Friends, Trades, Achievements, sale and entrust flows |
  | reading | 720px | legal, how it works, season allocation, register, card detail |

- A screen's root never adds its own padding: `.main` already pads the page. Two paddings stacked make that screen narrower and lower than the others.
- Blocks on a screen are `--space-stack-page` apart (24px, 20px on a phone), laid out by `.page`'s `gap`, not with margins.
- Three breakpoints only: phone under 720px, tablet under 1180px, desktop. A component that adapts to its own width uses a container query, not a new media query.
- Spacing comes from the `--space-*` scale (2, 4, 8, 12, 16, 20, 24, 32px). Values such as 6, 10, 14 or 18px are off the scale. Colours come from `--color-*`; never write a hex or rgba value outside `tokens.css`.

## Screen name and top bar

- A screen shows no title at the top of its content. Its name is in the top bar, on every screen, on a phone too. Set `content_for :screen_title` on every screen. Keep a visually hidden `h1` for screen readers.
- The top bar shows the same elements on every screen:
  - desktop: rarity counter, capsule counter, PiCoin balance, bell, profile;
  - phone, one system on every screen: a back button when the screen has a parent, then the G, then the screen name, then bell and profile. The back button is an arrow, never the G. The capsule count moves to a badge on the Capsule tab.
- The duel screen is the one screen with no tab bar and no back button (`content_for :no_tab_bar` and `:no_back`). Its name stays in the top bar.
- No screen hides, adds or replaces a counter. The Collection does not swap the counters for a unique-cards meter, and a sub-screen does not drop the rarity counter.

## Headings

- **A panel on its own carries its heading inside, at the top**, with any figure (`0 / 5`) or link aligned to the right. Examples: Goals, Invitations, the market's exchange preview.
- **A heading above panels only heads a group of several panels or tiles**, for example "In progress" and "My sets" in the Collection, or "All listings" in the Market. It uses the kicker style: `--font-kicker`, accent colour, uppercase.
- The two placements never mix for the same job.
- Both placements use one style: `--font-kicker`, accent colour, uppercase, `--tracking-kicker`. A panel's heading is never white, grey or another size.
- The hero and banner styles (`--font-hero`, `--font-banner`) are only for showcase screens: landing, roadmap, set album, public profile.

## Components

Some forms are plain CSS classes rather than components: use the class as written. The components marked *to build* do not exist yet. Build them before you restyle a screen that needs them, then use them everywhere.

| Component | Status | Rule |
| --- | --- | --- |
| `PanelComponent` | exists | The only way to draw a framed box. Use its heading slot and padding option (*to add*: `padding: :compact` for 12px 16px) instead of a hand-made background and border. |
| `ButtonComponent` | exists | Every button. An action that opens the rest of a preview ("see all") is `variant: :link`: accent text, underlined, and a chevron on a link that goes somewhere (drawn by the stylesheet, never by hand). A link button is never muted grey. |
| `.page` | exists (`page.css`) | Screen root: `.page--wide`, `.page--regular` or `.page--reading`. A sidebar layout (360px column + content, stacked on a phone) stays on the screen's own grid for now. |
| `SectionComponent` | to build | A group heading above several panels, with a right slot for a count or a see-all link. |
| `TileComponent` | to build | A clickable tile is one `<a>`: icon + title, a figure, optional art, and no arrow or chevron: the whole tile is the affordance (a chevron belongs only to what folds). It never holds a button or anything that looks like one. Tiles sit in an `auto-fit` grid (280px minimum), so "All my cards" and "All sets" share one row. |
| `.tabs` | exists (`tabs.css`) | A `nav.tabs` of `.tabs__tab` (current: `.tabs__tab--current` or `[aria-selected=true]`, greyed: `.tabs__tab--disabled`), followed by a `.tabs__panel`. Tabs sit on the panel that holds the tab's content; the current tab merges into that panel. Inside the panel, cards and rows have no border of their own. |
| `SortComponent` | exists | `prefix:`, `label:`, `options:` (`label`, `href`, `current`). Sorting is one button in the filter row ("Sort: Ending soon ▾") that opens a menu and ticks the current option. Never a row of underlined links. |
| `FigureComponent` | to build | A number with its unit and label (`10 /60 unique cards`, Me stats, exchange figures). |
| `SegmentedComponent` | to build | Two or three exclusive choices side by side (All / Friends, Français / English, This week / All time). |
| `[data-tip]` | exists (`tooltip.css`) | The one tooltip, the bubble on a revealed capsule card's buttons: put the text in `data-tip` on the host and the bubble shows above it on hover and keyboard focus (`data-tip-align="start"` at the left edge of a layout). Every hint, help or "i" info uses it; never a popover, a `title` attribute or a screen's own bubble. The bubble is not read aloud, so the host also carries the text for screen readers (`aria-label`, or `aria-describedby` to a visually hidden copy). |
| `EmptyStateComponent` | exists | `line:`, and an `action` slot when there is one: one quiet line in place of a list that is empty. |
| `.dock` | exists (`dock.css`) | Add `dock` to the summary block. In a pick-then-confirm flow (entrust, sale), the summary and the confirm button float at the bottom of the screen over the grid, above the tab bar on a phone. The grid takes the full width. It is never a side column stuck to the top. It hovers `--dock-lift` above the bottom edge (never flush with it) and stays there while the grid scrolls; every screen with such a summary uses `.dock` or the same lift. The dock is wider than the content column (24px past each side, 8px on a phone) and casts a drop shadow, so it reads as floating over the content. Entrust and sale use the same dock. |

## Hotwire Native

Everything here is server-rendered HTML and CSS, so the native app needs nothing special. Keep the native rules in `native.css` working: a clickable tile is a single link, which avoids the stretched-link workaround, and the screen name stays in the top bar even when the native shell shows only the G.
