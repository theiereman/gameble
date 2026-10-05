---
title: "Reconcile: UX redesign inputs against the architecture spine"
reviewed: 2026-10-05
mode: read-only
spine: ../architecture-gameble.md (updated 2026-10-05) with ../.memlog.md
inputs:
  - ../../ux-gameble/ux-gameble.md (For the architecture, items 1-14)
  - ../../ux-gameble/review-feasibility.md (C1-C2, H1-H5, M1-M12, L1-L12, For the architecture, Epic 1 rework)
  - ../../ux-gameble/EXPERIENCE.md (Opening protocol, State Patterns, Implementation notes)
  - ../../ux-gameble/DESIGN.md (checked where a build rule was expected to land)
  - code (read only, to confirm what is built): packs/game, packs/steam
---

# Reconcile: UX redesign → architecture spine

## Verdict

**Mostly landed. Fix 7 spine points before slicing; move 6 build rules to the UX spines or stories.**

All 14 "For the architecture" items have a home in the spine (AD-5, AD-8, AD-13, AD-14, AD-16 to AD-19, AD-23 to AD-28, conventions, Deferred). The memlog's 2026-10-05 author choices override the inputs as intended:
- the palette is not computed at import (AD-17);
- presence is not built on connection tracking (AD-24);
- card numbers come from a random shuffle (AD-5).

Some feasibility recommendations were already overruled by the UX spines themselves, and the spine follows the UX:
- no scaled logical booster stage (C2);
- 1280 px cap rather than 1440;
- the back-office stays functional, not restyled (Epic 1 rework #9).

What is left are seven spine points. One contradicts DESIGN.md, two contradict the spec or code, and four are invariants stated too loosely, so two sessions could build them differently. Six build rules from the feasibility review reached neither the spine nor the UX spines. That is correct for the spine, but they still need a home.

## Dropped or landed wrong

### Belongs in the architecture spine (invariants)

| # | Item | Source | Problem | Where |
|---|---|---|---|---|
| S1 | Top bar stickiness | UX #6, feasibility M12, DESIGN.md Layout | AD-27 says "the top bar is sticky". DESIGN.md says "the top bar and LIVE ticker scroll with it (they are not fixed)", and UX #6 agrees ("top bar and ticker scrolling"). The memlog (line 106) adopted M12's sticky without recording it as an override. | The author settles it. Then either AD-27 keeps only "document scroll, fixed phone tab bar with safe-area padding" and leaves the top bar to DESIGN.md, or DESIGN.md is changed to match. |
| S2 | Daily booster has 3 cards and its own odds | EXPERIENCE State Patterns ("Special booster in the reserve"), spec CAP-16 | AD-7 says each pack has "its 5 cards" and is drawn "by the published odds". AD-23 returns "the five cards", and AD-7 counts "at most 5 counted rows". The spec and the built code (`Game::Pack::BONUS_SIZE = 3`, `DrawOdds::BONUS`, `kind` enum) have 3-card bonus packs with their own odds table. | AD-7: a pack has a kind, and the kind fixes its card count and odds table. AD-23: return the pack's cards (3 or 5) and its kind. Separately, EXPERIENCE's "Cartes révélées : n / 5" needs a note (UX). |
| S3 | Last-seen write versus "a GET never writes" | UX #7, AD-24 vs AD-11 | AD-24 touches last seen "on the player's requests", and most of those are GETs. AD-11 says a GET never writes and runs on the `reading` role. Both rules are in the spine and they contradict each other. | AD-11 or AD-24: name the throttled last-seen touch as the one allowed write, on the writing role, outside the read path. Or touch it from a POST or beacon, as AD-26 does. |
| S4 | NOUVEAU and the meaning of "changed" | UX #8, AD-26, EXPERIENCE ("received cards tagged NOUVEAU") | AD-26 calls a holding new "when it changed after" the watermark. But a holding row also changes when `reserved` moves (placing a card in a trade) or when copies leave (a trade given away). With `updated_at`, those cards would show NOUVEAU. The memlog also forbids a column on holdings. | AD-26: define new as "quantity increased after the watermark", and say what records that. This needs the author, because it may reopen "no column on holdings". |
| S5 | Which side is reserved after a counter-proposal | UX #8, EXPERIENCE State Patterns ("Counter-proposal sent", "Trade waiting for the player"), AD-8 | AD-8 says "placing cards raises `reserved`" and "a counter replaces both sides". It does not say whose cards stay reserved. EXPERIENCE reserves only the sender's offer. Under that reading, a counter releases the first proposer's copies, which are now on the requested side. The reading is not stated, and the `quantity >= reserved` invariant depends on it. | AD-8: the reserved copies are always exactly the current proposal's offer, which is the sender's side. A counter releases the previous offer and reserves the new one. |
| S6 | Telling the player about an unlock | EXPERIENCE State Patterns ("Set complete … a toast announces it"), Flow 3 | `Game::SetCompleted` unlocks a card back inside `OpenPack`, but AD-23's response does not carry it. When a set is completed by a trade the friend accepted, AD-13's private stream carries "only what calls for an answer", so it cannot carry the unlock either. Without a rule, sessions will each invent a way to announce it. | AD-23: add "unlocks earned by this opening (back, achievement, set)" to the response. AD-13: say whether unlock notices ride on the trade state change or show at the next render. |
| S7 | Active back shown outside the opening | EXPERIENCE Card backs ("the faded image of a card not owned in the card detail") | AD-25 says the active back "is read at opening and given to the booster island". The card detail of a missing card, drawn by the card ViewComponent, needs it too, for the viewer only. | AD-25: one sentence saying the active back is read wherever the viewer's face-down or missing card is drawn. |

Smaller wording fixes in the spine:

- **AD-27 asset list.** The list names backs, canister, icons, avatars and logo. It omits the **planet** (UX #12, DESIGN.md "the planet"). Write "every pixel-art asset (…)" so that no runtime procedural drawing slips in.
- **AD-27 CSP.** It "allows the Steam image hosts". The filter worker reads images with `fetch()`, so those hosts must be in `connect-src` as well as `img-src`, and Action Cable needs its `wss:` origin (M8). The memlog (line 109) says so; the spine lost it.
- **Deferred, weekly goal.** "Reached, missed and rollover" are deferred, but granting the reward pack and the week's card back to every contributor is a fan-out. AD-10's per-player handlers and AD-25's "only handlers on events" do not cover it. Name it in that Deferred line so it is not decided ad hoc.

### Build rules: belong in DESIGN.md, EXPERIENCE.md or a story, not the spine

| # | Item | Source | Where |
|---|---|---|---|
| B1 | Use native `<dialog>` with `showModal()` for every modal and sheet, in both Stimulus and React. The hotkeys controller ignores `defaultPrevented` events, events while a dialog is open, and events from form fields. | Feasibility L3 | EXPERIENCE.md Implementation notes. EXPERIENCE now defines Esc precedence but not how to keep one Esc from both closing a dialog and navigating. |
| B2 | No inline `style=` attributes, which an enforced CSP blocks: gauge and progress widths are set as CSS custom properties from Stimulus. Steam hosts go in `connect-src` and `wss:` is allowed. | Feasibility M8 | EXPERIENCE.md Implementation notes (it binds every component author), plus the CSP story. |
| B3 | Holo and foil only on cards in the viewport; offscreen grid cards get `content-visibility: auto`. | Feasibility M4, memlog line 110 (dropped from AD-27) | DESIGN.md Rarity effects, or EXPERIENCE.md Implementation notes. |
| B4 | Collection grid beyond about 60 slots is paginated (Pagy) or virtualised; only visible cards are filtered. | Feasibility L12 | EXPERIENCE.md Collection, and the collection story. |
| B5 | Fonts: preload the three files; `font-display: block` with a short block period. | Feasibility L5 | DESIGN.md Typography, and the fonts story in the epic 1 rework. |
| B6 | The daily-booster arc runs from `turbo:before-stream-render` (or animates and then replaces), and dispatches `gameble:reserve-changed`. | Feasibility L11 | The daily bonus story. |

Housekeeping: EXPERIENCE.md Responsive & Platform still tags the browser floor `[ASSUMPTION] … recorded in the architecture`. AD-27 now records `allow_browser :modern`, so the tag can go.

## Item-by-item status

Status values: **Landed** (AD, convention or Deferred), **Overridden** (memlog author choice, or a UX decision taken over feasibility), **Elsewhere** (a build rule that correctly lives in DESIGN.md or EXPERIENCE.md), **Wrong** or **Dropped** (listed above).

### ux-gameble.md › For the architecture

| # | Item | Status |
|---|---|---|
| 1 | Pixel filter | Landed, AD-17. "Palettes at import" overridden (memlog line 88). |
| 2 | Cover source | Landed, AD-19 + AD-4 + AD-17 (placeholder rule). The import uses `library_capsule`, not `_2x`; this was built in story 2.10 (memlog line 101, `packs/steam`). The 300 × 450 source covers `card-xl` at 2 CSS px, so this is acceptable. |
| 3 | Islands | Landed, AD-16. A third island (back-office preview) was added. |
| 4 | Opening endpoint | Landed, AD-23. The charge phase and caps-on-success are in EXPERIENCE Opening protocol. Card count: see S2. Unlocks: see S6. |
| 5 | Navigation and motion on Turbo | Landed, AD-27. Flicker once per session and the 400 ms stagger cap are in EXPERIENCE Motion. |
| 6 | Layout system | Landed, AD-27, with the screen detail in DESIGN.md Layout. **Wrong on the top bar (S1).** |
| 7 | Real-time | Landed, AD-13. Connection tracking overridden (memlog line 91, AD-24). Ticker at loop boundary: EXPERIENCE Hub. Last-seen write: see S3. |
| 8 | New domain data | Landed: backs (AD-25), invitations (AD-8), visibility (AD-14), number (AD-5), tome genre (AD-5), NOUVEAU (AD-26), trades (AD-8). **Loose on NOUVEAU (S4) and reservations (S5).** |
| 9 | Conventions | Landed, conventions table. |
| 10 | Security | Landed, AD-27. **CSP wording loose** (see the wording fixes). |
| 11 | i18n in islands | Landed, AD-18. |
| 12 | Pixel-art assets | Landed, AD-27. **The planet is missing** (see the wording fixes). |
| 13 | Performance | Landed: AD-27 budget and browser floor; device and spike in Deferred. |
| 14 | Epic 1 rework | Landed as strategy (AD-28). The individual items are story work. Back-office "stays functional" is in Deferred. |

### review-feasibility.md › Findings

| Finding | Status |
|---|---|
| C1 cover URL | Landed (AD-19, AD-17, AD-4). `_2x` versus `library_capsule` is the built choice. DESIGN.md now says "address recorded at import". |
| C2 layout | Landed (AD-27 + DESIGN.md). The scaled logical stage and the 1440 cap were overridden by the UX ("nothing is scaled", 1280). Short viewports scroll; phone landscape is "nothing happens"; tablets follow width rules. |
| H1 filter cost | Landed (AD-17). No flip before the art is ready: EXPERIENCE Opening protocol step 5. Import palette overridden (memlog). |
| H2 opening protocol | Landed (AD-23 + EXPERIENCE Opening protocol). |
| H3 islands and contract | Landed (AD-16). |
| H4 Turbo motion | Landed (AD-27 + EXPERIENCE Motion and Opening protocol step 6). |
| H5 missing mechanisms | Landed (AD-8, AD-14, AD-24 to AD-26, AD-5). Connection tracking overridden. The CAP-5 and CAP-11 contradictions are spec matters. |
| M1 fractional DPR | Landed, Deferred. |
| M2 glyphs, U+00A0 | Landed (AD-18, conventions) + DESIGN.md Typography (pixel SVG icons). |
| M3 CORS fallback | Landed (AD-17). "No added header" covers tracing SDKs. |
| M4 animation budget | Landed (AD-27, Deferred spike). **B3 dropped.** |
| M5 touch-action | Elsewhere: EXPERIENCE Interaction Primitives. |
| M6 lifecycles | Landed (AD-27) + EXPERIENCE Implementation notes. |
| M7 i18n | Landed (AD-18). |
| M8 CSP | Landed in principle (AD-27). **Detail dropped (B2, wording fix).** |
| M9 3D pitfall | Elsewhere: EXPERIENCE Implementation notes, including the visual regression test. |
| M10 tokens | Elsewhere: DESIGN.md frontmatter + EXPERIENCE note. The `--color-*` naming is a spine convention. |
| M11 pixel assets | Landed (AD-27, AD-25). |
| M12 shell and safe areas | Landed (AD-27). `dvh` is moot since the stage grows. **Top bar: S1.** |
| L1 one palette | Landed (AD-17). |
| L2 grid arrows | Elsewhere: EXPERIENCE Interaction Primitives. |
| L3 Esc and dialogs | Precedence elsewhere (EXPERIENCE). **Native dialog and hotkeys guard dropped (B1).** |
| L4 ticker | Elsewhere: EXPERIENCE Hub ("join at the loop boundary"). |
| L5 fonts | Self-hosting landed (AD-27); OFL in DESIGN.md. **Preload and font-display dropped (B5).** |
| L6 hotlinking | Landed (AD-17 no-referrer, no storage; AD-19 refresh from the import data). |
| L7 countdowns | Landed (Time convention, AD-23). |
| L8 accessibility | Elsewhere: EXPERIENCE Accessibility Floor. |
| L9 pedestal drift | Elsewhere: EXPERIENCE Motion ("2px at most"). |
| L10 browser floor | Landed (AD-27). The EXPERIENCE tag is stale (housekeeping). |
| L11 daily arc | **Dropped (B6).** |
| L12 grid scale | Pagy convention landed. **Grid rule dropped (B4).** |

### review-feasibility.md › For the architecture and Epic 1 rework

- **For the architecture, items 1-13:** the same items as the UX list above, with the same status. Item 8's "first-listed Steam genre" was superseded by the tome genre (AD-5, spec).
- **Item 14, housekeeping:** landed. `stack.md` is gone from `sources`, and the UX spines and both reviews are listed.
- **Epic 1 rework 1-12:** these are stories, under AD-28's shell-first strategy. Item 9 (restyle the back-office) was overridden by UX #14 and the spine's Deferred ("stays functional, outside the redesign"). Item 11 (CSP) is AD-27.

### EXPERIENCE.md › Opening protocol, State Patterns, Implementation notes (architecture-relevant rows)

| Row | Status |
|---|---|
| Opening protocol 1-6 | Landed (AD-23, AD-27 "Browser Back is always allowed"). |
| Special booster in the reserve | **Wrong (S2).** |
| Reserve full, daily claim | Landed (AD-7, AD-9). |
| Counter-proposal sent | **Loose (S5).** |
| Not enough copies, trade done | Landed (AD-8, AD-26). |
| Friend banned or deleted mid-trade | Landed through AD-10 ("a pack reacts to another pack's event"). The story must add the handler. |
| Set complete, back unlock toast | **Missing (S6).** |
| Goal reached | Deferred. The fan-out needs naming (see the wording fixes). |
| Friend presence | Landed (AD-24). Write path: see S3. |
| Profile visibility, not visible | Landed (AD-14). |
| Export (asynchronous) | Landed (AD-12 jobs, AD-10 ids only). |
| Language switched | Landed (AD-18). |
| Implementation notes | Elsewhere (EXPERIENCE). They agree with AD-16, AD-23 and AD-27. "Content timing" matches AD-23. |
| Card backs: faded back in the card detail | **Missing (S7).** |
