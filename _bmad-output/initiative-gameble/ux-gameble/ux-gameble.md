---
title: "UX: gameble"
status: final
created: 2026-10-01
updated: 2026-10-05
sources:
  - ../spec-gameble/spec-gameble.md
  - ../brief-gameble/brief-gameble.md
---

- [DESIGN.md](DESIGN.md): visual identity (how it looks).
- [EXPERIENCE.md](EXPERIENCE.md): structure, behavior, flows (how it works).

**Status:** final, 2026-10-05. This run replaced the 2026-10-02 medieval direction with a space terminal in Steam's colors. Next: `bmad-spec` absorbs the changes below, then `bmad-architecture` (update mode) absorbs For the architecture, before the redesign epics are sliced. Epic 1 was built on the old direction and needs the rework listed below.

## Changes this run asks of the spec

Decisions taken during the UX work that change the product contract. They reach the spec through `bmad-spec`. Ordered by capability, then by the spec file they touch.

### Changed by the 2026-10-05 redesign

- **Glossary:** the interface says "booster" for the spec's "pack", "réserve" for its "bank", and "objectif communautaire" for the weekly goal.
- **Steam sign-in (CAP-1):** the only link to Steam's sign-in is Valve's official "Sign in through Steam" image, unmodified. Game-styled calls to action open a small sign-in panel holding one title line ("CONNECTEZ-VOUS POUR JOUER") and the horizontal official button, with no reassurance copy. Sign-out lands on the hub in signed-out mode.
- **Rarity (CAP-3, CAP-4, `catalog-and-rarity.md`):** Commune, Peu commune, Rare, Épique, Légendaire replace steel, emerald, sapphire, amethyst, gold. Each tier also has a shape (circle, double circle, diamond, triangle, star), drawn smaller on card faces. Odds unchanged.
- **Packs (CAP-4):** no per-pack rarity promise; the only guarantee is a Rare or better by a new account's 10th pack, without any visible sign.
- **Reveal (CAP-5):** one surprise per card. A single click, tap or Enter reveals the rarity and the game together. No dust, no rarity seal, no wipe, so CAP-5's intent ("two surprises per card") and its first success line must change. "Flip all" is now "Tout révéler"; it still never skips a Légendaire's full sequence.
- **Card face (CAP-7, `catalog-and-rarity.md`):** title, publisher, cover, genre, release year, rarity (shape and name) and a card number. No stats. The genre is the game's first-listed Steam genre, so the import must keep it. The release date gives the year on the card and no longer drives any dust. The card number is its number within the season, without a total (for example "S1 · #4 215"), so cards need a per-season number.
- **Profile visibility (CAP-8, CAP-14):** a three-way setting, public / friends only / private, replaces "hide the public profile". A public profile stays readable without an account; friends only limits it to friends; private to nobody else.
- **Friends (CAP-10):** a link or code sends an invitation; the friendship exists once the other player accepts it (they can also ignore it).
- **Friends' presence (new):** friends see each other's online status (online, current activity, last seen), with "n en ligne" on the Amis menu item.
- **Trades (CAP-11):** a proposal expires after a fixed 7 days; the proposer no longer chooses. A proposal holds both an offer and a request. A counter-proposal may change both sides, what the player gives and what they ask for. When a player owns several copies of a card, they choose how many to place, on both sides (the player's maximum: copies owned minus copies reserved elsewhere; the friend's maximum: what they own). At most 4 different cards per side.
- **Back-office (CAP-2, CAP-15):** out of the redesign's scope; behavior unchanged, plain functional style, designed later.
- **Daily bonus (CAP-16):** the bonus pack joins the player's bank. When the bank holds 10 packs, the claim stays disabled ("réserve pleine") until a pack is opened; nothing is lost.
- **Signed-out visitors (CAP-18):** "open the attic" becomes "open the hub"; the rest stands.
- **Custom card backs (new capability):** earned by completing a set, by contributing to a successful community goal, through some achievements, and through events or seasons. Every account starts with "Standard". The player picks one active card back in the profile; it shows only to them, on their own face-down cards at opening.
- **Reduced motion (new setting):** an in-app "Animations réduites" setting, following the system by default; when on it also stops the LIVE ticker and every looping or blinking effect.
- **Images (Constraints):** never copied; pixelated at 2 CSS px per pixel and reduced to about 32 colors per image (was 16), no dithering, in the browser at display time. The vertical cover is cropped to the card's art box.
- **Legal (Constraints):** the "no affiliation with Steam or Valve" notice, the terms of use and the privacy notice live on a legal page reached from "Mentions légales" (profile and public page footer).
- **Platforms (Constraints):** on phones, portrait only: no landscape layout and no overlay; the installed web app is locked to portrait by its manifest. On every size, the interface is never scaled; pages scroll and reflow by width.
- **Brotherhood tone (`brotherhood-tone.md`):** far more discreet. Only the community goal carries a Brotherhood line; the feed carries none. Players are not addressed as "Confrères" and get no title. All UI copy says "vous", never "tu" (the file's example line uses "ta"). Add "Ordre majeur" to the forbidden Helldivers terms.
- **Later (`later-roadmap.md`):** an input at opening that improves the odds of a good card (the stratagem-like arrow code is rejected as too close to Helldivers).

### Carried from the 2026-10-01/02 run

Still valid and already in the spec: the catalog exclusions and imported release date (CAP-2), the description only in the detail view (CAP-7), the share preview without image (CAP-9), the three kinds of sets with named empty slots (CAP-6), 10 packs at sign-up opened one at a time (CAP-4), the draw odds, asynchronous trades with counter-proposals, reserved cards and one trade per pair (CAP-11), trades counting toward the weekly goal (CAP-12), the public feed (CAP-13), the daily bonus and achievements with the day changing at midnight UTC (CAP-16, CAP-17), signed-out visitors who see but cannot act (CAP-18), no guide, and the "later" items.

### Dropped

- Dust by the age of the game, the rarity seal on the card back, the wipe-then-flip reveal (superseded by the single-click reveal).
- The attic and navigation through scenery objects (superseded by the hub "Pont de commandement" on desktop and a tab bar on the phone).
- The mock-solemn Brotherhood copy in every label (superseded by the discreet tone).

### Still open (non-blockers)

- Ticker events beyond CAP-13 (set completions, hourly totals).
- Which achievements exist and which card backs ship (spec open questions).
- Special boosters (daily, goal reward) against the 10-booster cap: does a goal reward land above 10?
- The weekly goal's reached, missed and rollover states.

## For the architecture

`architecture-gameble.md` (status final) predates the redesign; `bmad-architecture` in update mode should absorb these before the redesign epics are sliced (detail in `review-feasibility.md`, For the architecture and Epic 1 rework):

1. **Pixel filter (AD-17):** 32 colors, median cut, no dither, 2 CSS px, crop anchored at 42%; in a Web Worker with OffscreenCanvas, lazy, concurrency-capped; one palette per game; no-CORS fallback; placeholder detection; in-memory cache only; optionally palettes computed at import.
2. **Cover source:** the import stores the hashed vertical-capsule URL (the legacy `library_600x900` path fails for recent games) and refreshes it; the CAP-2 exclusion tests the API asset list; the catalog exposes an opaque image URL.
3. **Islands (AD-16):** booster (desktop row and phone pile with tray) and trade board; named controllers; a DOM event contract between islands and server-rendered chrome (tier revealed, reserve changed, toast, trade badge); shared modules for filter, tilt, reduced motion and translations.
4. **Opening endpoint:** request on click, idempotency key, charge phase masking latency, caps blow only on success; response with the five cards, reserve and availability times, server time, pre-open tier counts; error codes.
5. **Navigation and motion on Turbo:** View Transitions, permanent atmosphere layers, Turbo previews skip the panel lock-in animation, `no-cache` on booster and trade, phone sub-views as URL-advancing frames, document scroll.
6. **Layout system (decided):** no scaling anywhere; vertical page scroll with the top bar and ticker scrolling; breakpoints 720 and 1180px (booster info stacked under 1260px, dealt cards smaller under 900px); content capped at 1280px (assumed, below 1440px); collection grid cards 120–170px with fixed gaps and the filter re-run at rendered size; trade board stacking by container query under 700px; phone portrait column of at most 480px and a manifest `"orientation": "portrait"`; tokens as CSS custom properties; `viewport-fit=cover`.
7. **Real-time:** per-player stream for trade badges and invitations; feed and gauge streams; ticker updates at loop boundaries; friends' presence (connection tracking, activity signal, throttled last-seen).
8. **New domain data:** card backs (catalog, unlocks, active card back, unlock handlers); invitations; three-way profile visibility in policies; per-season card number; first-listed Steam genre; "seen" state for NOUVEAU written by an explicit operation; trades with fixed 7-day expiry, counter-proposals on both sides, 4 distinct cards per side.
9. **Conventions:** tiers renamed (code `common, uncommon, rare, epic, legendary`, French names in locales); card number "S1 · #4 215" with U+00A0.
10. **Security:** a Content-Security-Policy (Steam image hosts, workers, self-hosted fonts); fonts self-hosted.
11. **i18n in islands:** templates with plural forms, relative time, uppercase in CSS.
12. **Pixel-art assets:** an export script renders card backs, canister, icons, avatars, planet and logo to files.
13. **Performance:** a budget for continuous animations and a reference low-end device; a spike before the booster story; the supported-browser floor.
14. **Epic 1 rework:** tokens, fonts (Jost out), the attic removed for the hub, the layout shell (top bar, ticker, tab bar, atmosphere layers under content, toast region), button and panel components, locale copy in "vous", the focus ring, the official Steam sign-in image replacing epic 1's button, sign-in landing on the hub, tickets that still cite the attic. The back-office shell only needs to stay functional.
