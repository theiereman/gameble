# Mobile web audit

Date: 2026-11-02. Purpose: find what makes the phone experience poor before any native app work. This is a findings document; no direction is chosen here.

## Method and limits

- Chrome emulating an iPhone 13 (390 × 844, device pixel ratio 2, touch), signed in as a test player, via a throwaway system test (not committed). 21 screens, full-page captures plus measurements (tap targets under 44 px, text under 12 px, horizontal overflow, fixed or sticky elements).
- Data: a first pass on the bare fixtures, then a second pass with 111 cards (70 owned, 36 duplicates), four sets, six packs in reserve, one friend and generated cover images.
- Limits:
  - Chrome emulation, not Safari: notch safe areas, the retracting address bar, the on-screen keyboard and `100vh` behaviour are not covered. A real iPhone pass is still needed.
  - Full-page captures draw the fixed tab bar and the version footer in the middle of the image; that is a capture artefact, not a defect.
  - Not exercised with data: the pack reveal sequence, a populated trade board with cards on both sides, the landing page, a card with a rare treatment. Pages measured but not looked at: roadmap, sign-in, how-it-works, legal, achievements, personalization.

## Findings

| # | Finding | Evidence | Weight |
|---|---|---|---|
| 1 | Destinations are buried under "More". The tab bar has five entries; "More" holds eight: All cards, Friends, Activity feed, Achievements, How it works, Profile and settings, Personalization, Support. "Collection" and "All cards" are two entries for one thing. | more.png, collection.png | High: matches the reported difficulty finding screens |
| 2 | The header carries too much. Back button, page title, two counters and the avatar compete for 390 px; on several screens the title is clipped ("CAPSUL", "ACTIVIT"). | booster.png, feed.png | High, on every sub-screen |
| 3 | The "All cards" page is 10 screens tall for 106 cards (two columns, large cards), with no sticky search or filters, no jump aid, tiny text on the mini faces of the set tiles. | all-cards.png | High with real collections |
| 4 | The collection screen is a long stack: search box with no visible placeholder, goals, my sets, then one big tile per set with a large empty band between the title and the thumbnails. 2.5 screens for four sets. | collection.png | Medium to high; grows with the number of sets |
| 5 | The trade screen stacks two large empty drop zones (about 400 px each) plus a send bar; a filled trade will be much longer. Two sides never fit on one screen. | new-trade.png | Medium; to be re-tested with cards placed |
| 6 | The fixed version and legal-notice line sits over content just above the tab bar (over the weekly mission text, over the card detail's buttons). | hub.png, card-detail.png | Low effort, visible everywhere |
| 7 | The activity feed filters are two groups of chips in one row, cut at the right edge with no cue that it scrolls. | feed.png | Medium |
| 8 | On a new account the hub opens on a large empty capsule slot and the daily capsule collect button is below the first screen. With cards it reads better (latest acquisition, then mission, then daily capsule), but the first action is still under the fold. | hub.png | Medium |
| 9 | Measured text under 12 px: 29 to 153 text nodes per screen, 434 on "All cards". Tap targets under 44 px: 15 on "All cards", 11 on the legal page, 2 to 4 on most others. No horizontal page scroll anywhere measured. | JSON metrics | Medium |
| 10 | Profile and settings is one long form (about 1.7 screens); every future sign-in provider will add to it. | settings.png | Low to medium |

## What already works

- The five-entry tab bar and the back-button pattern are consistent.
- The card detail fits one screen with its two actions and a swipe hint.
- Card faces stay legible in the two-column grid; no sideways page scroll.

## Open questions for the ideation step

- Which five destinations deserve the tab bar, and where do friends, feed and achievements live?
- Is "Collection" one screen with sets and cards as two views, instead of two entries?
- What is the minimum header on a phone (title and back only, counters elsewhere)?
- How does a long list of cards stay navigable (sticky search, set shortcuts, sections)?
- How does a trade fit a one-handed flow (one side at a time, a bottom sheet picker)?
- Which screens need a real device test first (reveal, keyboard on the trade and search fields)?

Captures are in `screens/`; they are half-scale crops of the first screens of each page.
