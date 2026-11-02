# Mobile web UX: intent

## 1. Intent

Make the phone web experience of gameble phone-first before any native app. A mobile session runs in a fixed order: open every capsule, check set progress, handle social (friends, trades), then cosmetics. The tab bar, header, lists and trade flow are reshaped around that order. Problems from the mobile web audit that this solves:

- Destinations buried under "More"; "Collection" and "All cards" are two entries for one thing.
- Header overloaded (back button, title, two counters, avatar); titles clipped on 390 px.
- "All cards" is about 10 screens tall with no sticky search or filters; the collection screen is a long stack.
- Trade screen stacks two large drop zones; no one-handed flow.
- Activity feed filter chips cut at the edge with no scroll cue.
- Hub opens on an empty capsule slot with the daily collect below the fold.
- Profile and settings is one long form.
- Fixed version/legal line overlaps content (quick fix).
- Many text nodes under 12 px and tap targets under 44 px.

## 2. Clusters and decided behaviour

### Shell (tabs, header)
- Four tabs in session order: Capsule, Sets, Social, Me. "All cards" becomes a view inside Sets.
- Header stays on top-level screens, reduced to: a G home button, one merged capsule counter, the bell. No page title.
- Merged counter tells standard and special capsules apart by shape or icon as well as colour; tapping it opens a small detail.
- Drill-down screens shrink the header to a back button.
- On long lists the header hides on scroll down and returns on scroll up.
- Fix the version/legal line overlapping content; raise small text and tap targets.

### Capsule flow
- The capsule screen is the default landing screen, replacing the hub.
- The daily capsule shows as a ready slot in the reserve and is collected with a tap (no auto-collect).
- Next capsule is preselected; one tap opens it; a Next capsule button chains until the reserve is empty.
- Large readable card; end-of-capsule grid of all cards; short skippable animation honouring reduced motion; warm the next capsule's art during the current reveal; one primary thumb button at the bottom.
- Empty reserve state proposes, in order: collection/sets, friends/trades, personalization/achievements. Each carries a live hook (sets close to complete, a friend holding a card you need, a new cosmetic or achievement). Also applies on desktop.
- Weekly community goal lives in Social; next daily time and sets close to complete show in the empty state.
- Rare-card feeling is visual only, same as desktop.

### Lists and filters
- Sets first screen: progress of my goals (max five) as compact tiles with progress and missing cards as thumbnails, each leading to Trade. With no goal, suggest the closest-to-complete sets with a one-tap Set as goal.
- Other sets: search, sorted by closeness to completion, grouped by type.
- Long card list: infinite pagination, server-rendered pages appended on demand; scroll position restored when returning from a card detail.
- Quick filters as three pastilles: goal, rarity, state. Search stays at the top; each pastille opens a bottom sheet. One row replaces today's stacked search and filters.
- The goal filter acts as a to-do list; missing cards a friend holds lead into trades.

### Social and trades
- Social home: trades in progress first (those waiting on you at the top), then friends list; the activity feed is a demoted section or third view with a single Friends/Everyone toggle and type filters in a bottom sheet.
- Add-friend and new-trade actions stay at the bottom, in thumb reach.
- Trade row shows only the person (avatar, name), one status chip ("your turn" / "their turn", derived; expired or accepted shown quietly), and the highest rarity among the cards in the trade. No card thumbnails.
- One-handed trade: tap a missing card, Trade proposes possible trades with friends who hold it, send with our own side empty, then wait. A notification on return opens the trade directly to validate or edit.
- Friend pick and card pick use the bottom sheet.

### Bell
- Bell icon in the header with an indicator; opens a dropdown from the top under the bell (read-only glance), shared with desktop.
- Three types at launch: trade updated, friend request, daily and community goal. Achievements wait.
- One sentence plus one action per line; an item clears when its target is opened; the counter uses the existing pixel digits; the bell icon is drawn in the pixel-art source and exported.
- A daily item replaces itself and vanishes once collected.
- Trade items deep link straight into the trade.

### Me page
- Me tab equals the public profile merged with the personalization page, so changes show live.
- Everything editable by touching the element, through bottom sheets; inline previews (achievement progress, current card back) instead of bare links.
- No entry deeper than two taps.
- A single entry to the account settings page at the bottom.

## 3. Build order (agreed at convergence)

1. Shell and quick fixes.
2. Bottom sheet with lists and filters.
3. Capsule flow and empty state.
4. Social and trade rows.
5. Bell.
6. Me merge.

Threads: the bottom sheet is the single grammar for filters, friend pick, card pick and profile edits; the goal links Sets to filters to trades; the empty-capsule state and the bell are shared with desktop.

## 4. Superseding decisions

- Account settings (language, sign-ins, data, delete, support, legal) stay a separate page; the rest merges into Me. This replaces "no separate settings page".
- The header stays on top-level (home) screens; elsewhere it shrinks to a back button. This replaces "header almost always disappears".
- Social priority: trades in progress and friends list first; the feed is nice to have.
- Notifications drop from the top, not a bottom sheet: bottom sheets for choosing, a top dropdown for glancing.

## 5. Constraints to carry

- A GET never writes: the daily capsule needs a POST tap; any "seen" marker is written behind a POST or a job.
- Server-rendered HTML with Stimulus; no markup built in script, no React. Sheets, infinite pages and the bell render on the server and are driven by controllers.
- Bottom sheet and bell are shared components with desktop; the screen talks to page chrome only through `gameble:*` events.
- No database ids in URLs, HTML or DOM ids; use tokens (including the trade deep link).
- Every string in `en.yml` and `fr.yml`; every action behind a Pundit policy.
- Pixel icons (bell, tab icons) come from `node script/pixel_art/export.mjs`; never hand-edit `app/frontend/images/pixel/`.
- Accessibility: the page title is kept as a visually hidden h1; colour is never the only cue; reduced motion honoured; tap targets at least 44 px.
- Art pixelation cost (2-4 jobs at once) bounds list smoothness and capsule pre-warming.

## 6. Open questions

- Real iPhone test (Safari): safe areas, retracting address bar, on-screen keyboard on search and trade fields, `100vh`, and the unexercised reveal sequence.
- Where the bell and bottom sheet live once the app moves to Hotwire Native; the trade deep link is what a native push would reuse.
- Last-seen marker for "trade updated since you last looked": where it is stored and how it respects the GET rule.
- Rare-card haptics and sound: deferred.
- Whether the reserve count also shows as a badge on the Capsule tab; the author only chose the merged counter in the header.
