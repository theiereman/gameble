---
name: gameble
status: final
created: 2026-10-01
updated: 2026-10-02
sources:
  - ../spec-gameble/spec-gameble.md
  - ../brief-gameble/brief-gameble.md
---

# gameble — Experience Spine

## Foundation

A responsive web game for desktop and mobile, in French and English. Every flow works the same way on both form factors. No UI system is named; the stack renders pages on the server and embeds components for highly interactive screens. `DESIGN.md` is the visual identity reference; this spine is the experience.

Items tagged `[ASSUMPTION]` were proposed by the facilitator and not yet confirmed.

## Information Architecture

| Surface | Reached from | Purpose |
|---|---|---|
| Shared card on a public profile | A shared link, without an account | Show the sharer's card and its details; invite the visitor to play |
| Attic | Sign-in (landing screen); also open to signed-out visitors | Open packs, see the timer, collect the daily bonus, travel to the other screens |
| Brotherhood feed | The notice board on the attic wall | Show pulls and trades as they happen |
| Library | The lectern with the grimoire | Browse the collection and its sets |
| Tome | A book in the library | See the slots of one set, filled and empty |
| Card detail | A card anywhere | Art, title, description, year, publisher, rarity, season, Steam link, share |
| Trade board | The trade table | Propose, answer, accept or counter a trade |
| Friends | The trade table | Invite by link or code; list friends |
| Achievements | The medal display | Simple achievements |
| Profile and settings | The standing mirror | Language, hide profile, export data, delete account |
| Report | A player's profile | Report a username or profile |
| Back-office | Staff accounts only | Moderators review reports and ban accounts; administrators also start the catalog import, watch it and publish a season |
| Steam sign-in | Any action that needs an account | Create or reuse the account |

Navigation is part of the scenery: there is no sidebar. The attic furniture leads to the other screens. Every other screen carries a back button to the attic.

A status band stays on screen everywhere: the weekly goal gauge at top left, and at top right the packs available and the number of cards owned per rarity. A credits counter joins the top right when the currency arrives with the market; the MVP has no currency. For a signed-out visitor, the band carries the Steam sign-in button instead.

Signed-out visitors can go everywhere and see everything that needs no account. They cannot act: no pack opening, no trade. Acting opens the Steam sign-in. The library shows the sets with all their slots empty.

→ Composition reference: [mockups/attic.html](mockups/attic.html) (attic, desktop and phone), [mockups/key-screens.html](mockups/key-screens.html) (reveal, library, trade board, shared card). Spines win on conflict with any mock.

## Voice and Tone

Microcopy. The Brotherhood tone is defined in the spec's `brotherhood-tone.md`: mock-solemn, players addressed as "Confrères" / "Brothers", satire in the copy only. All copy exists in French and English.

| Do | Don't |
|---|---|
| "Confrère, ta contribution a rapproché la Confrérie de la victoire." | Name a real company in the copy |
| Short, solemn lines on goals, trades and pulls | Explain the game in a guide: there is none |
| Let the card carry title, year and credit | Put a description or long text on a card |

## Component Patterns

Behavioral. Visual specs live in `DESIGN.md`, Components.

| Component | Use | Behavioral rules |
|---|---|---|
| Scenery object | Attic | Leads to a screen. Its name shows on hover and on focus. `[ASSUMPTION]` On phone the name is always shown. |
| Chest | Attic | Shows the number of packs banked. Opening it releases one pack of 5 cards. Packs are opened one at a time, never in bulk. |
| Pack timer | Attic | Counts down to the next pack. `[ASSUMPTION]` Hidden when the bank is full at 10. |
| Face-down card | Pack reveal | Covered in dust by the age of the game. Wiping reveals the rarity seal. Flipping reveals the game. |
| Card face | Reveal, library, trade board, public pages | Opens the card detail. |
| Flip all | Pack reveal | Flips the remaining cards quickly. A legendary always plays its full reveal. |
| Daily bonus panel | Attic | Once a day it gives a small booster with better odds. The day changes at midnight UTC. |
| Goal gauge | Status band | Fills with pack openings and, to a lesser degree, trades. |
| Tome | Library | Opens onto the slots of its set. Shows owned / total. |
| Empty slot | Tome | Names the missing game. |
| Trade board | Trades | Two sides face to face. Each player places cards on their own side; a placed card is reserved. Two friends have one open trade at a time. |
| Share | Card detail | Produces a link. Its preview on Discord, X and WhatsApp carries no game image. |
| Back button | Every screen but the attic | Returns to the attic. |
| Feed entry | Brotherhood feed | Says who did what, with the rarity. The feed lists notable pulls, first discoveries of a card, and trades. |
| Achievement | Achievements | `[ASSUMPTION]` A simple list, each achievement earned or not. The list of achievements is not defined. |

A pack's five cards reach the browser when the pack is opened and join the collection at once. The reveal is an animation in the browser.

## State Patterns

| State | Surface | Treatment |
|---|---|---|
| Signed out | Everywhere | Everything is visible. Actions that need an account ask to sign in with Steam. |
| First session | Attic | The bank is full: 10 packs. A sapphire or better is guaranteed by the 10th pack, without any visible sign. |
| Packs banked | Attic | The chest shows the count. |
| No pack banked | Attic | The chest is closed; the timer shows when the next pack arrives. |
| Daily bonus ready / collected | Attic | The panel is shown, then gone until the next day. |
| Set incomplete | Tome | Empty slots name the missing games. |
| Set complete | Tome | `[ASSUMPTION]` Marked as complete; no reward is defined. |
| Trade waiting for me | Trade board | The other side's cards are already placed. I can accept, place mine and send a counter-proposal, or decline. |
| Trade waiting for them | Trade board | My proposal is shown as sent. I can cancel it. |
| Trade done | Trade board | The swap animation plays; the cards join each collection. |
| Card in a trade | Library, trade board | A card placed in an open trade is reserved: it cannot be placed in another trade until this one ends. |
| Reveal abandoned | Attic | The cards are already in the collection; nothing resumes. The chest shows the next pack. |
| Trade expired | Trade board | The proposal closes at its expiry, 7 days at most. |
| Goal reached | Status band | Every contributor receives a rare pack. |
| Opening refused | Attic | The server refuses an opening without a banked pack; the chest stays closed. |
| Empty collection | Library | Every slot is empty and names its game. |
| Quiet feed | Brotherhood feed | With few players, the feed falls back to lower-rarity events. It is never empty while any activity exists. |
| Profile hidden or banned | Shared card, public profile | `[ASSUMPTION]` The page says the profile is not available. |
| Image missing | Any card | The card still shows its frame and title. |
| Focus | Everywhere | A visible outline in `{colors.ink}`. |

## Interaction Primitives

- **Wipe:** hovering on desktop, sliding a finger on mobile, or keyboard focus wipes the dust off a face-down card and reveals its seal.
- **Flip:** click, tap or Enter flips the card and blasts the remaining dust off in a burst of pixels.
- **Two surprises per card:** the rarity when wiping, the game when flipping. Reveal length and intensity grow with rarity; a legendary is the longest.
- **Touch an object to travel:** attic furniture opens the other screens.
- **Place a card:** on the trade board, a player picks cards from their collection and places them on their side.
- **Not in the MVP:** bulk pack opening, live trades with both players at the board, card marks (favourite, to trade, personal categories), a guide.

## Accessibility Floor

Behavioral. Contrast values live in `DESIGN.md`.

- Every action works with the keyboard: focus wipes, Enter flips, and scenery objects are focusable in a sensible order.
- Scenery objects carry a text name, never a picture alone.
- Rarity is never carried by colour alone: each seal has its own shape, and the rarity name is available to screen readers.
- Each card exposes its title as text, since the art is an image.
- Reduced motion: the legendary shimmer stops, and sparkles stay still. `[ASSUMPTION]` The dust burst and the swap animation are replaced by an instant change.
- `[ASSUMPTION]` Touch targets are at least 44 CSS pixels, including scenery objects on phone.
- Language follows the player's choice in settings. `[ASSUMPTION]` The first visit uses the browser's language.

## Responsive & Platform

- Desktop and phone share the same screens, flows and pixel size.
- **Pack reveal on phone:** one card at a time at the large size, with a progress mark for the five cards and the "flip all" control.
- **Attic on phone:** the same wide room, panned sideways with a finger. It opens centred on the chest.
- **Trade board on phone:** the two sides are stacked, the other player on top.
- A small card is 160 CSS pixels wide, so two fit side by side on a phone.
- The status band stays visible on both form factors.

## Inspiration & Anti-patterns

- **Lifted from "collect Wikipedia" card games:** the pull, brag, trade loop.
- **Lifted from Balatro:** pixel art across the whole interface.
- **Lifted from Hearthstone card backs:** a richly built back, with a frame, a strap, a medallion and ornaments.
- **Lifted from shiny cards in Pokémon:** the shimmer on a legendary.
- **Rejected — a flat pack opening where cards simply appear (WikiMasters):** the reveal is the best moment of the game.
- **Rejected — a sidebar menu:** navigation must feel like a game.
- **Rejected — a guide:** players work it out on their own.
- **Rejected — opening every pack at once:** it removes the suspense.
- **Rejected — a pixel font, then serif fonts:** text is a modern sans-serif.
- **Rejected — a vertical tower for the attic on phone, flying elements in the window view, an hourglass card back, text on the legendary back.**

## Key Flows

### Flow 1 — First session (Léa, on her PC, clicks a link Hugo posted on Discord)

1. Léa clicks the link to the card Hugo shared.
2. Without an account, she lands on Hugo's public profile with the shared card open: art, title, description, year, publisher and a link to Steam.
3. A call to action invites her to open packs too. Still signed out, she can also walk into the attic and read the Brotherhood feed: pulls and trades of other players, with their rarities.
4. She signs in with Steam.
5. She lands in the attic. Ten packs wait in the chest.
6. She opens the first pack. Five cards land face down, dusty.
7. She wipes a card: the seal shows its rarity. She flips it: the game appears.
8. She opens the next packs one by one.
9. **Climax:** before her tenth pack is done, she wipes a card and finds a sapphire seal or better, then flips it.
10. The chest is empty; the timer shows when the next pack arrives.
11. She goes to the lectern and browses her tomes: filled slots, and empty ones naming what is missing.
12. The next day, the daily bonus brings her back.

Failure: Steam sign-in is refused or cancelled → she returns to the page she was on, still signed out.

### Flow 2 — A trade between friends (Hugo and Léa, a few days later)

1. `[ASSUMPTION]` Hugo and Léa are already friends, through an invite link or a friend code.
2. Hugo goes to the trade table and opens a trade with Léa. The board shows two sides face to face.
3. He places cards from his collection on his side and sends the proposal.
4. Later, Léa opens the trade and sees Hugo's cards already placed.
5. She places her own cards and sends that proposal back.
6. Hugo accepts it. He could instead have made a counter-proposal, which Léa would then accept or counter.
7. **Climax:** an animation shows the cards passing from one player to the other. Each now owns the new cards.
8. The trade appears in the Brotherhood feed and counts toward the weekly goal.

Failure: Léa declines, or the trade expires → the reserved cards are released and nothing moves.
