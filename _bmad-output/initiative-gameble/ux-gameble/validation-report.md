# Validation Report — gameble

- **DESIGN.md:** `/home/teyermann/projets/gameble/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md`
- **EXPERIENCE.md:** `/home/teyermann/projets/gameble/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md`
- **Run at:** 2026-10-14T15:45:49+02:00
- **Scope:** the 2026-10-14 update that added the visitor landing page to both spines

## Overall verdict

This run validates the 2026-10-14 update that added the visitor landing page to `DESIGN.md` and `EXPERIENCE.md`, read against the rest of the pair and the reference render `mockups/landing.html`. Issues that predate the landing and do not touch it are not reported again. The landing is well integrated in structure. It has a full DESIGN.md Landing section, a matching EXPERIENCE.md Landing component table, a Copy deck block, Motion and reduced-motion rows, Responsive bullets, two new flows, and updated IA rows for sign-out and account deletion. Every `{token}` reference resolves, and the five new tokens are well formed. A consumer still cannot build it cleanly, for three reasons. First, the source spec has no capability for the landing or the roadmap, and CAP-1 still contradicts the new sign-out destination. Second, the live modules have no empty, cold-load or failure states, and the root route for a signed-in player is not committed. Third, the DESIGN Landing section gives about fifteen type sizes as raw px, several of which duplicate existing tokens or contradict them.

The three extra reviewers move the picture from "not yet clean to extract" to "not yet safe to build or ship". The accessibility lens found 2 critical gaps the rubric could not see from the text alone: the power-on rule leaves a module taller than about eight viewports invisible (which happens at 400% zoom), and a signed-out visitor has no way to pause the lamp, the self-updating feed and the other moving content (WCAG 2.2.2, Level A), which brings back the old C3 finding. Its 3 high findings are moving cards that can hide the focused element, hero text over lamp-lit art at 1.2 to 3.4:1 on the phone, and Valve's sign-in image whose accessible name does not contain its visible words. The feasibility lens finds the landing buildable under the repo's rules (no React island, no write on GET, CSP holds through CSSOM), but the mock is not a safe blueprint: the lamp repaints a mask every frame and never idles (AD-27), the moving cards cover controls, and the most visited page has no caching or throttling story. The roadmap sync and the lore gate also collide with the repo's rules and its develop-to-main release train; expect about ten stories, not one. The copy lens finds the voice rules intact, but the landing promises what launch does not have (the pioneer's engraved name, card backs and set rewards, a free licence on a repository that is still private) and shows the live weekly goal twice, word for word.

Several findings converge across lenses: the moving cards (accessibility, feasibility, rubric), the missing visitor motion control (accessibility, feasibility), the undefined live data and its states (rubric, feasibility), the signed-in root and signed-out entry points (rubric, feasibility), the source of the sample cards (rubric, feasibility), the hero title size (rubric, feasibility), the star-field drift (rubric, feasibility, accessibility) and the final call's hub link label (rubric, accessibility, copy, feasibility). Across all four reviewers: **2 critical, 16 high, 38 medium, 44 low** (15 distinct high findings once the moving-cards high, raised by both accessibility and feasibility, is merged).

## Category verdicts

- Flow coverage — adequate
- Token completeness — thin
- Component coverage — adequate
- State coverage — thin
- Visual reference coverage — strong
- Bloat & overspecification — adequate
- Inheritance discipline — thin
- Shape fit — strong

## Severity totals

| Reviewer | Critical | High | Medium | Low |
|---|---|---|---|---|
| Rubric walker | 0 | 4 | 10 | 11 |
| Accessibility | 2 | 3 | 5 | 7 |
| Feasibility | 0 | 5 | 11 | 8 |
| Copy | 0 | 4 | 12 | 18 |
| **Total** | **2** | **16** | **38** | **44** |

## Findings by severity

### Critical (2)

**[Accessibility]** — C1 — A module taller than about eight viewports never powers on, so its content stays invisible (spine and mock) (§ EXPERIENCE.md › Landing › Module; Motion › Landing module power-on; mock IntersectionObserver threshold 0.12)  
An IntersectionObserver ratio is a share of the target's area. A module taller than viewport / 0.12 (8.3 viewports) can never reach 0.12, so its title and content stay at opacity 0. At 1280 × 720 at 400% (a 320 × 180 CSS px viewport) the limit is 1 500px; modules 02 and 05 in one column, and most modules with English copy or user text spacing, exceed it. Fails 1.4.10, 1.4.4, and 2.4.7 for keyboard users tabbing onto invisible links.  
Fix: Replace the Module's first sentence: power on once when the top edge passes 85% of the viewport height, whatever the module's height, and at once when the module holds focus, is a jump target or is above the viewport on load; content is never held invisible longer than the power-on (about 0.6s); without JavaScript or the observer, modules are on from the start. Reduced motion keeps the 180ms fade under the same trigger.

**[Accessibility]** — C2 — Signed out, nothing on the landing can pause what moves, blinks or updates (spine; brings back C3) (§ EXPERIENCE.md › Motion › Reduced motion; Accessibility Floor › Moving content; Landing › Lamp field, Live feed list, Moving cards)  
"Animations réduites" lives in Profil et paramètres, which a visitor cannot reach; only the OS `prefers-reduced-motion` applies. The lamp sweeps forever beside (on the phone, behind) the h1; the live list adds an entry every 8s; the LIVE marker blinks; the 03 countdown ticks; rays turn behind the Épique and Légendaire moving cards; stars twinkle and drift. Fails 2.2.2 Pause, Stop, Hide (A) on the first screen.  
Fix: Add a "Motion control" row: an "Animations réduites" toggle (`aria-pressed`) in the landing's top bar, first after the wordmark, 44 × 44 on the phone, applying the whole reduced-motion profile at once, kept in a first-party cookie so the server renders the reduced form, and carried into the account at sign-in. Append to Reduced motion: "For a visitor without an account: the landing's toggle when set, otherwise the system." The live list pauses on hover and focus; the lamp stops on the last card found and never runs more than 30s without a pointer.  
Also raised: Feasibility (medium): auto-moving content with no signed-out control.

### High (16)

**[Rubric · Token completeness]** — The landing's type is given as raw sizes, not tokens (§ DESIGN.md › Components › Screens › Landing)  
VT323 at 26, 22, 24, 36, 28 and 32px, and JetBrains Mono bold at 13, 16, 14, 11 and 10px, across 02–09 and the side gauge. Most match existing tokens (`screen-title` 26, `card-title-xl` 22, `screen-title-phone` 24, `banner-small` 36, `showcase-name-phone` 28, `showcase-name` 32, `button` 13/700, `card-title-l` 14/700, `kicker`/`label` 11/700, `kicker-phone` 10/700). A builder will hard-code them or guess which token was meant.  
Fix: Name the token for each size, or add a small set of landing typography tokens (for example `landing-module-title`, `landing-panel-title`, `landing-figure`) and reference them.

**[Rubric · State coverage]** — The live modules have no empty, low-activity, cold-load or failure states (§ EXPERIENCE.md › State Patterns; Open questions › Landing live module)  
04's feed list ("five latest entries") has no rule for zero to four entries. The season facts can be zero (« Premières découvertes cette semaine ») or have no active season. The goal panels in 02 and 04 have no state for a missing goal, and the roadmap has none for missing data. The landing is the root for every signed-out visitor and goes live when the community is smallest.  
Fix: Add State Patterns rows for the landing: feed with 0–4 entries, season or goal unavailable, zero counts (French `zero` plural forms), roadmap data missing, cold load (does the generic "—" rule apply?).  
Also raised: Feasibility (medium): the live module's data definitions are also underspecified.

**[Rubric · State coverage]** — The root route for a signed-in player is not committed (§ EXPERIENCE.md › IA, Landing and hub rows; Open questions › Signed-in players and the landing)  
The hub's IA row no longer says it is the root after sign-in. The landing row covers only signed-out visitors, and "/fr and /en open the hub for them" is an `[ASSUMPTION]`. Routing is load-bearing for the first build ticket.  
Fix: Commit the rule in the IA and in State Patterns (for example "Signed in: /fr and /en open the hub; the landing is not reachable" or "reachable through …").  
Also raised: Feasibility (medium): many other signed-out entry points are also undecided.

**[Rubric · Inheritance discipline]** — The spines have moved past their sources (§ spec CAP-1; brotherhood-tone.md; EXPERIENCE.md › State Patterns › Sign out / Account deleted; Open questions › Spec follow-ups)  
`spec-gameble.md` has no capability for the landing, the roadmap or the roadmap data. CAP-1 still reads "signing out lands on the hub, signed out", while EXPERIENCE now lands sign-out and deletion on the landing. `brotherhood-tone.md` ("at most one line per screen") does not record the landing exception. EXPERIENCE lists these only as non-blocking "Spec follow-ups", so a story built from CAP-1's acceptance criteria will implement the wrong redirect.  
Fix: Update the spec (a landing and roadmap capability, CAP-1's sign-out destination) and `brotherhood-tone.md` before ticketing, or mark the follow-up as blocking the landing.

**[Accessibility]** — H1 — Moving cards can hide the focused element and the text, are gated by width rather than by pointer, and block scrolling on touch (spine and mock) (§ DESIGN.md › Landing › Moving cards; EXPERIENCE.md › Landing › Moving cards; Accessibility Floor › Landing; Responsive › Landing on desktop)  
A 208 × 312 `card-l` near the edges covers the start of the 1120px column, where every heading, link and button is left-aligned; Tab scrolls a link into view and a card can rest on it (2.4.11). At 200% zoom on 1440px the viewport is 720 CSS px and the cards cover about a third of the column. Tablets from 720px get the cards, and `touch-action: none` turns a scroll into a drag. A click aimed at a link under a card grabs the card.  
Fix: Show the cards only with `(hover: hover) and (pointer: fine)` and from a width where a card overlaps the column by at most 48px (about 1440 CSS px). A card fades out while focus is inside main and never rests over a focused element, lets pointer events through outside its own box, never sets `touch-action: none`, and always moves relative to the content when scrolling. Replace the Floor's `[ASSUMPTION]` with a pointer to that rule.  
Also raised: Feasibility (high): the moving cards can rest over text, links and calls to action.

**[Accessibility]** — H2 — On the phone the hero text sits over lamp-lit card art at 1.2 to 3.4:1 (spine and mock) (§ DESIGN.md › Landing › Lamp field; Layout › Landing on the phone; EXPERIENCE.md › Responsive › Landing on the phone)  
The lamp opens the veil to 0 in its inner disc and to .38 in the next ring. Over a bright cover `{colors.text-bright}` falls to 1.17–3.35:1, below 1.4.3 and against the spine's "every overlay applied" rule. A 12px blurred halo is not a background. On the phone the lamp always sweeps, so the background behind the h1 keeps changing.  
Fix: On the phone the lamp never opens the veil behind the hero copy: the copy's box (kicker, hook, line, button, plus 8px) keeps the full `{components.lamp.veil}`, and no card's lit part falls under it. Measure text contrast over the brightest cover with the lamp at its worst position.  
Also raised: Rubric (medium): no contrast target for text over the lamp field.

**[Accessibility]** — H3 — The Steam image's accessible name does not contain its visible words (spine; app-wide) (§ EXPERIENCE.md › Copy deck › Landing › Top bar; Accessibility Floor › Links and sign-in; DESIGN.md › Steam sign-in)  
Valve's image shows "Sign in through STEAM", in English. Its accessible name, "Se connecter avec Steam (ouvre Steam)", starts with French words not in the image, so a speech-input user saying "click Sign in through Steam" gets no match (2.5.3, A) on the page's only sign-in path.  
Fix: Valve's image gets `alt=""`, and the link's name is visually hidden text that starts with the image's words: `<span lang="en">Sign in through Steam</span> : se connecter avec Steam (ouvre Steam)`, everywhere the image appears.

**[Feasibility]** — The lamp as mocked breaks AD-27 and never goes idle (§ DESIGN.md › Landing › Lamp field; EXPERIENCE.md › Landing › Lamp field; mock heroLamp)  
The mock moves the veil's hole by rewriting custom properties inside a `mask-image: radial-gradient(...)` every rAF frame: a full repaint of the masked layer, not a compositor-only change. AD-27 allows infinite animations only on `transform` or `opacity` and requires loops to stop when nothing moves. Once every card is found the lamp wanders forever, and the frame loop keeps running while the hero is off-screen.  
Fix: Draw the veil as one oversized element with a fixed radial hole and move it with `translate3d`; run the power-on as five class swaps; run the rAF loop only while the hero intersects the viewport and the tab is visible; settle on the last card and stop, and drop the endless wander from the spine; replace the 18% bottom `mask-image` fade with a ground-colour gradient overlay; put the motion maths in a pure `lib/` module with vitest coverage.  
Also raised: Accessibility C2 asks the lamp to stop for the same reason.

**[Feasibility]** — The moving cards can rest over text, links and calls to action (§ DESIGN.md › Landing › Moving cards; EXPERIENCE.md › Landing › Moving cards, Accessibility)  
The cards catch the pointer and sit "near the left and right edges" over the 1120px column; below about 1540px they overlap content and can rest on the hero's lime button, 08's « Soutenir » or Valve's image, where a click drags the card. Tab scrolls the focused link into view, the scroll moves the cards, and a card can land on the focused element (2.4.11). The "user scrolls past" `[ASSUMPTION]` holds while scrolling, not at rest.  
Fix: Pick one rule: (a) cards live only in the gutters outside `{spacing.landing-content-max}` and appear only when both gutters can hold a `card-m` (cheaper, testable); or (b) exclusion zones around interactive elements, and a card intersecting the focused element fades and stops catching the pointer.  
Also raised: Accessibility H1 (same finding).

**[Feasibility]** — The most visited page has no caching or throttling story (§ EXPERIENCE.md › Landing › Live feed list, Goal panels; DESIGN.md › 04)  
Every signed-out hit on /fr or /en reads the season, the goal, `Game::FeedEntries.call(nil)`, five feed cards, 15–30 sample cards, three aggregate counts, the odds and the roadmap. The page cannot be edge-cached (CSRF on Valve's POST form, session-derived CSP nonce, session cookie). `PublicReadThrottle` does not cover the root, and every visitor opens an Action Cable websocket.  
Fix: Fragment-cache each data block per locale (feed keyed on the latest entry, goal on its count, sample cards on the published season, roadmap on its file digest; 30–60s TTL for aggregates). Extend the throttle to signed-out GETs of `/:locale`. Subscribe to the cable stream only when module 04 comes into view, or poll a cached Turbo Frame every 30–60s. Record the choice in the plan.

**[Feasibility]** — The roadmap sync collides with three repo rules and with parallel work (§ EXPERIENCE.md › Landing › Roadmap; Implementation notes › Landing roadmap data; memlog "Roadmap sync")  
The generated data must carry French and English wording, but AGENTS.md puts every string in `en.yml` and `fr.yml`; it must not carry planning ids, yet epics are identified by them; the status source is unstated; and a committed generated file that changes on nearly every story PR would conflict across parallel sessions and fail CI drift checks.  
Fix: Shape it like `script/pixel_art/export.mjs`: opt-in frontmatter `roadmap: { key, order, fr, en }`; status from the plan's `status:` only; a generator writing `config/roadmap.yml` and `config/locales/roadmap.{fr,en}.yml`, read by `i18n-tasks`, with the AGENTS.md i18n rule amended; `--check` in CI; only opted-in entries written. The alternative (generate at Kamal pre-build, never commit) is the author's call.

**[Feasibility]** — The lore gate does not fit a develop-to-main release train (§ EXPERIENCE.md › Landing › Lore panel; States › Lore text not written)  
Whatever merges to `develop` ships with the next release, and the repo uses no feature flags (AD-28). If the root switch merges before the lore exists, the landing ships with an empty slot. The lore also needs an English text, which nothing mentions, and its unknown length decides whether the lore panel balances the goal panel.  
Fix: Make the routing switch its own last story, after the lore story; until then serve the landing on a staff-only route. Ask the lore session for French and English text and a length bound.

**[Copy]** — The « Découvrez » tile promises a feature that is not in the MVP (§ 02 · La Confrérie, « Le premier joueur à tirer un jeu y grave son nom… »)  
Recording the first discoverer's name is the « Pioneer » item of `later-roadmap.md` ("Nothing here is built in the MVP"). At launch a first discovery is only a feed entry and its « Première découverte » chip. « y » also has no clear antecedent.  
Fix: Until Pioneer is scoped: « Le premier joueur à tirer un jeu l'annonce dans le fil, pour toute la Confrérie. »

**[Copy]** — Module 05 sells post-launch features as things to unlock now (§ 05 · « Dos de cartes », « Sets et paliers »)  
CAP-20 (card backs) and CAP-22 (titles, menu themes) come after the public launch. At launch bronze and silver tiers give only a celebration and a feed line. The page contradicts itself: 06 shows « Dos de cartes et thèmes » as « À venir ».  
Fix: Make the card-back tile conditional on CAP-20 or mark it « Bientôt » to match 06; for sets: « … et franchissez les paliers bronze, argent et or. » with no reward claim.

**[Copy]** — The open-source claims are not true yet (§ 07 « Le code est entièrement libre… », « Licence libre… »; footer « Code source »; « Voir le projet »)  
The repository has no LICENSE file and is still private. Shipped as written, the landing would name a licence that does not exist and link to a private repository.  
Fix: Add a ship gate next to the lore one in State Patterns: the repository is public and licensed before the landing ships. Name the licence in the line.

**[Copy]** — The live weekly goal appears twice, word for word (§ 02 goal panel; 04 season panel; 05 tile and subtitle; 02 subtitle)  
Both 02 and 04 show « Toute la Confrérie ouvre 50 000 boosters, ensemble. », « 31 420 / 50 000 », the same gauge and « Fin lundi à … »; the goal comes up three more times. A visitor sees the same block twice within two screens, which reads like a layout bug.  
Fix: Keep the live goal in 02; give 04's right column the season facts plus one other item (the week's latest first discovery, the number of participants).

### Medium (38)

**[Rubric · Flow coverage]** — No flow walks the landing's main entry (§ EXPERIENCE.md › Key Flows 5–6; IA › Landing row)  
The IA makes the landing the root at /fr and /en, but Flows 5 and 6 both arrive through a shared card and « Découvrir ». No flow covers a visitor who types the address or follows a plain link, or the hero's « Embarquer sur le pont » → signed-out hub → sign-in panel branch.  
Fix: Add a short variant to Flow 5, or a Flow 7, for a direct visitor at /fr, including the detour through the signed-out hub and its sign-in panel.

**[Rubric · Flow coverage]** — Flow 5's climax depends on an achievement toast that is not specified (§ EXPERIENCE.md › Flow 5 step 7; Open questions › Achievement toast)  
"Toasts and her first achievements come quickly" is tagged `[GAP: no achievement-earned toast is specified yet]`. A consumer cannot build the journey's payoff.  
Fix: Specify the achievement-earned toast (Component Patterns row, Copy deck key, DESIGN toast variant), or restate the climax with existing components (set-tier toasts, the Succès counts).

**[Rubric · Token completeness]** — The title sizes contradict their tokens (§ DESIGN.md › Landing › Module header, Hero; Layout & Spacing › per-screen table, Landing row)  
The module title is "44px on a 48px line, the `{typography.hero}` size", but `hero` is 44px on a 44px line, and the 32px phone size has no token. The hero hook is at `{typography.public-title}` size, while the Layout table commits "title 42px" at 900–1179px, and the same bullet notes the mock sets 42px and 38px.  
Fix: Commit one value per width as a token (for example `public-title-medium: 42px`, a module-title token with its own line height and phone size), and drop the mock commentary once settled.  
Also raised: Feasibility (low): the hero's title size is ambiguous.

**[Rubric · Token completeness]** — No contrast target for text over the lamp field on the phone (§ DESIGN.md › Landing › Lamp field; Layout & Spacing › Landing on the phone)  
The hero text sits on the field, the lamp opens the veil (`{components.lamp.veil}`) behind it, and only a "soft `{colors.ground}` text shadow" with no value protects it. The "measured with every overlay applied" rule cannot be checked while the lamp moves.  
Fix: State that the hero text keeps 4.5:1 with the lamp fully open behind it, give the text shadow's value, or keep the lamp's opening off the text block.  
Also raised: Accessibility H2 measures it at 1.17–3.35:1.

**[Rubric · Component coverage]** — Nothing says where the sample cards come from (§ EXPERIENCE.md › Landing; memlog "Landing content")  
The lamp field cards, the moving cards, the 01 rarity cards and the reveal demo's "next sample" are all shown, and the 01 cards' accessible name must give title, studio, year, genre, rarity and number. Neither spine says who chooses them, from which pool, whether they are real catalog cards of the current season, or how they follow a season change.  
Fix: Add a "Landing sample cards" row: a curated list of real catalog cards, chosen by whom, refreshed when, and what happens if one leaves the catalog.  
Also raised: Feasibility (medium) proposes `config/landing.yml` with a slug per slot and a season fallback.

**[Rubric · State coverage]** — Focus after each step has no landing rows (§ EXPERIENCE.md › Accessibility Floor › Focus after each step)  
A side-gauge marker jump (focus to the module's h2?), « Participer à l'écriture » scrolling to 07, the reveal demo after « Révéler » / « Recommencer », and the account-deleted toast arriving on the landing.  
Fix: Add these rows.  
Also raised: Accessibility M1 proposes the gauge jump rule.

**[Rubric · State coverage]** — Touch at desktop widths is not covered for the moving cards (§ EXPERIENCE.md › Landing › Moving cards; Responsive › Landing on desktop)  
Moving cards appear "from 720px" and move by "a pointer drag", but a touch tablet at or above 720px gets no rule: does a touch drag move the card or scroll the page, and can a touch user move a card that covers text?  
Fix: Turn moving cards off for coarse pointers, or state the touch-drag rule.  
Also raised: Accessibility H1 and Feasibility (high, medium) raise the same gate.

**[Rubric · Bloat & overspecification]** — DESIGN.md › Landing duplicates the Copy deck (§ DESIGN.md › Landing; EXPERIENCE.md › Copy deck › Landing)  
About thirty French strings are quoted in DESIGN (« MISSION EN COURS », « JEUX RETROUVÉS », « ARCHIVE 001 », « SOUTENIR GAMEBLE »…), sometimes in a different form: « TROUVÉ » vs "Trouvé", « Réserve 10 / 10 » vs "Réserve : 10 / 10". Two sources for copy will drift.  
Fix: DESIGN names the slot and its style only; the strings live in EXPERIENCE › Copy deck › Landing, and one line states that kickers and labels render in capitals through style.  
Also raised: Copy (low) asks for the same sentence-case rule.

**[Rubric · Inheritance discipline]** — The landing's star-field drift contradicts DESIGN (§ EXPERIENCE.md › Motion; DESIGN.md › Elevation & Depth)  
EXPERIENCE lists the two drifting star layers as a landing-only exception under `[ASSUMPTION]`; DESIGN still says the star field "stays still … (no sideways shift)" and records no exception.  
Fix: The author decides: record the exception in DESIGN's atmosphere bullet and the Landing section, or drop the drift.  
Also raised: Feasibility (medium): the drift also contradicts AD-27; drop it.

**[Rubric · Inheritance discipline]** — The lime rule is reinterpreted, not amended (§ DESIGN.md › Colors; Buttons › Primary button; Landing › Lime)  
"Never more than one lime button per view" and "Primary button … One per view" are unchanged, while the Landing has two lime buttons under an `[ASSUMPTION]` that "view" means a screenful.  
Fix: Confirm with the author, then state the per-screenful reading once in Colors and add « Embarquer sur le pont » and « Soutenir » to the Primary button list.  
Also raised: Feasibility (low): a tall viewport can still show both.

**[Accessibility]** — M1 — Side gauge: names break Label in Name in the mock; focus after a jump, tab position and target width are open (both) (§ EXPERIENCE.md › Landing › Side gauge; Copy deck › Side gauge; Interaction Primitives › Keyboard; mock #readout-list)  
The mock's `aria-label="Mission"` replaces the visible "00" (2.5.3). Nothing says where focus goes after a jump (2.4.3). The ten links come before main in the DOM: ten tab stops before the hero's action. Markers are about 21px wide (2.5.8 passes only through the spacing exception).  
Fix: Each marker's name starts with its visible number ("00 · Mission"; drop the `[ASSUMPTION]`). A jump moves focus to the module's h2 (`tabindex="-1"`, scroll-margin), instantly under reduced motion. `aria-current="location"` on the current marker only. The gauge follows main in the DOM and each marker is at least 24 × 24.  
Also raised: Rubric (medium): focus after each step has no landing rows.

**[Accessibility]** — M2 — The live list updates under the reader with no pause and no stated announcement rule (spine) (§ EXPERIENCE.md › Landing › Live feed list; Accessibility Floor › Feed and ticker)  
2.2.2 for auto-updating content. A screen-reader user reading in browse mode loses their place when every row shifts (the mock re-renders the whole list every 8s). The spine does not say whether the Floor's 30s status line runs on the landing.  
Fix: Insert new entries as one node at the top and remove the last; never re-render. Pause while hovered, while focus is inside the module, and under the motion control; buffered entries arrive together on resume. No status line on the landing. « Boosters ouverts aujourd'hui » follows the same pause.

**[Accessibility]** — M3 — The 01 rarity row cannot be swiped sideways on the phone when the finger starts on a card (spine) (§ EXPERIENCE.md › Interaction Primitives › Tilt; Landing › Rarity cards; DESIGN.md › Layout › Landing on the phone)  
Under the house tilt rule cards accept only vertical panning (`pan-y`), so a horizontal swipe on a card is lost and the Rare, Épique and Légendaire cards cannot be reached by touch. The row's one tab stop also stays on desktop, where it does not scroll.  
Fix: In the phone's sideways row the cards do not tilt and use `touch-action: pan-x pan-y`. The row is a tab stop only while it overflows. Same for the 06 roadmap row.

**[Accessibility]** — M4 — « Embarquer sur le pont » and « Découvrir » do not say where they lead, and one destination has two names (spine) (§ DESIGN.md › Landing › Hero, Public card page; EXPERIENCE.md › Copy deck › Landing, Public page; Open questions › Landing final call)  
The hero's lime button opens the signed-out hub, but its name gives no hint of "look around without an account", next to a Steam image that does sign in (2.4.4, 2.4.6). « Découvrir » has no object. The signed-out hub is « Embarquer sur le pont » on the hero and public page but « Visiter le pont sans compte » in 09 (3.2.4).  
Fix: Hero and public page: accessible name « Embarquer sur le pont, visiter le jeu sans compte ». Public page: « Découvrir gameble ». 09's hub link uses the same visible text and name as the hero's.  
Also raised: Copy (medium) suggests the opposite resolution for 09: keep « Visiter le pont sans compte ».

**[Accessibility]** — M5 — Examples read as real events and real progress to a screen reader (both) (§ EXPERIENCE.md › Accessibility Floor › Landing; DESIGN.md › Landing › 02 tiles, 05 panels)  
04 shows the real feed in the same sentence forms as 02's tiles (« Nina a reposté Hades ») and 05's goal and achievement rows (« Premier booster obtenu »), none prefixed. A screen-reader user cannot tell illustrations from live data (1.3.1). The spine names only two examples.  
Fix: Every example (02's four tiles, 03's illustrations, 05's six visuals) is either hidden from assistive technology or named as one block starting « Exemple : ». Only 04 and the goal panels carry real data.

**[Feasibility]** — Mock patterns the CSP blocks (§ DESIGN.md › Landing › Lamp field, Side gauge; mock <head>)  
Inline `<script>` adding `.js` before first paint, inline `<style>`, `style="--k:…"` through `innerHTML`, `el.style.left/top`, and the full 92KB JetBrains Mono as `data:` URIs, twice. Under `script-src 'self'` there is no pre-paint hook.  
Fix: Modules visible by default, with the power-on armed at connect only for modules not yet in view; hero entrance in pure CSS; lamp slots as nth-child or modifier classes in `landing.css`; staggers via nth-child or `el.style.setProperty`; self-hosted subsetted woff2.

**[Feasibility]** — JetBrains Mono is not in the app (§ DESIGN.md › Typography; app/frontend/fonts/)  
The app ships Space Mono; no ticket covers the switch DESIGN.md made on 2026-10-13. Built alone, the landing would be the only JetBrains Mono page, or would carry an app-wide font change.  
Fix: A shell story before the landing: latin and latin-ext subsets at 400 and 700 with the OFL text, preload, Space Mono removed, a pass over fixed-width chips and top-bar titles.

**[Feasibility]** — The signed-out root switch leaves many entry points undecided (§ EXPERIENCE.md › IA, Signed-out visitors, States; DESIGN.md › Signed-out hub)  
Not settled: the signed-out hub's own URL; where `refuse_in_locale` sends a signed-out deep link; the phone tab bar's PONT; Esc "returns to the hub"; the back button rule; `sessions#failure`'s fallback; whether a signed-in player can see the landing. The landing GET must be `public_read?`, and there is no `<title>`, meta description or Open Graph image.  
Fix: Add a table listing each entry point and its target (landing or signed-out hub at `/:locale/bridge` or similar); one `hub_path` helper; branch `PagesController#home` on `current_player`; add the meta copy to the copy deck.  
Also raised: Rubric (high): the signed-in root is not committed.

**[Feasibility]** — The live module's data is underspecified (§ DESIGN.md › 04; EXPERIENCE.md › Landing › Live feed list; Open questions)  
« Joueurs actifs cette semaine »: calendar week or last seven days, which zone? « Boosters ouverts aujourd'hui » and « Premières découvertes cette semaine »: whose day or week? Whether figures update live (no broadcast exists). `LiveFeedJob` replaces `#live-strip` wholesale, which cannot slide one entry in.  
Fix: Settle each figure as a UTC goal week or a rolling 24h; read figures at page load, cached ≤ 60s, no live update; extend `LiveFeedJob` to prepend to a `landing-feed` target and trim to five with a custom stream action; with fewer than five entries use the feed's empty copy.  
Also raised: Rubric (high): the live modules have no empty or failure states.

**[Feasibility]** — Nothing says where the sample cards come from (§ memlog "Landing content"; DESIGN.md › Lamp field, 01, Moving cards; EXPERIENCE.md › Reveal demo)  
Cards appear in the lamp, 01, the moving cards, the reveal samples and thumbnails in 02, 03 and 05, "chosen" by no stated rule. A random pick defeats caching and tests; a fixed slug can disappear when seasons change.  
Fix: `config/landing.yml` names a slug per slot, falling back to the published season's top card of the slot's rarity; a test checks the list against fixtures.  
Also raised: Rubric (medium), same finding.

**[Feasibility]** — Cover weight on phones (§ DESIGN.md › Landing; AD-27 budget)  
Production art is Steam's `library_600x900.jpg` (about 80–200KB each) through the pixel filter; the mock's tiny placeholders prove nothing. Counted naively the landing shows about 30 covers, five on the phone's first screen.  
Fix: Reuse a curated set of 8 to 10 games across modules; keep lazy drawing and `content-visibility: auto`; measure LCP, frame time while the lamp sweeps and bytes on the reference low-end Android.

**[Feasibility]** — The star-field drift contradicts AD-27 (§ EXPERIENCE.md › Motion › Landing star field)  
The app's star field is one fixed, still, `data-turbo-permanent` layer. The mock translates two page-tall (about 9000px) box-shadow layers on scroll: huge composited layers, and a transform left on the permanent layer would follow the visitor into the hub.  
Fix: Drop the drift; if kept, use a landing-only viewport-fixed tileable layer translated modulo its tile height, removed on disconnect, and amend AD-27.  
Also raised: Rubric (medium): the drift contradicts DESIGN.

**[Feasibility]** — The roadmap module's size and target are open (§ DESIGN.md › 06; EXPERIENCE.md › Roadmap, Open questions)  
Is "one row of six" a cap? "A few stories (two in the mock)" clashes with the balance rule once data varies. « Voir toute la feuille de route » points to a page that is "decided, not designed".  
Fix: At most six milestones by `order`, exactly two stories each; hide the link until the roadmap page exists, or build a plain list page in the sync ticket.

**[Feasibility]** — The English copy is unwritten and has no review gate (§ EXPERIENCE.md › Open questions)  
About 150 strings plus the English rarity names, still open app-wide; `i18n-tasks` checks presence, not voice.  
Fix: Mark the landing's copy as HITL in its plan, or write it in a copy ticket ahead of the build.

**[Feasibility]** — Auto-moving content, and no way to stop it for a signed-out visitor (§ EXPERIENCE.md › Landing; Accessibility)  
The lamp sweeps well over 5s and the live list updates by itself (2.2.2); « Animations réduites » lives in signed-in settings.  
Fix: The lamp stops once every card is found; give the live list a pause, or update it only when the module comes into view; write the choice into the spine.  
Also raised: Accessibility C2 (critical), same gap.

**[Feasibility]** — "Desktop" and "touch" are defined by width in one place and by input in another (§ EXPERIENCE.md › Landing › Moving cards, Lamp field; mock pointerType gate)  
On a 1024px iPad or a touchscreen laptop, a touch-draggable card needs `touch-action: none`, and a scroll that starts on it drags the card instead.  
Fix: Gate the moving cards and the pointer-driven lamp on `(min-width: 720px) and (hover: hover) and (pointer: fine)` and write that into the spine.  
Also raised: Accessibility H1; Rubric (medium) touch at desktop widths.

**[Copy]** — Agreement error: « Collectionnez-les toutes » (§ 05 « Sets et paliers »)  
« les » stands for a masculine or mixed list, so it takes « tous ». Tiers are crossed, not "progressed"; franchise, studio and OVNI sets have no tiers. The phrase echoes a Pokémon slogan.  
Fix: « Complétez-les tous et franchissez leurs paliers. »

**[Copy]** — Factual slip: « Chaque booster cache cinq cartes face cachée » (§ 03)  
The daily booster holds 3 cards (CAP-16), and « cache … cachée » repeats itself.  
Fix: « Un booster contient cinq cartes face cachée. Retournez-les pour les découvrir. »  
Also raised: Rubric (low): conflicts with the rule against game figures.

**[Copy]** — The 03 subtitle does not match the steps (§ 03, « Ouvrir, révéler, collectionner, échanger. »)  
The four steps are « Rejoignez-la », « Accumulez des boosters », « Découvrez de nouvelles cartes », « Agrandissez votre collection ».  
Fix: « Rejoindre, accumuler, révéler, collectionner. », or align the step titles.

**[Copy]** — The end day can be wrong in the visitor's time zone (§ 02 and 04, « Fin lundi à {heure}. »)  
The week ends Monday 00:00 UTC; in the Americas that is still Sunday evening locally. « aujourd'hui » has the same question.  
Fix: « Fin {jour} à {heure} » with the day computed locally, or « Se termine dans {durée} »; state which day « aujourd'hui » counts.

**[Copy]** — The spec's term for the weekly goal is not used consistently (§ 04, 02, 05, 06)  
The spec makes « objectif communautaire » the player-facing term; the landing also uses « Objectif de la semaine » and « Un objectif pour tous ». « Remplissez des objectifs » clashes too.  
Fix: Label 04 « Objectif communautaire »; card backs: « Atteignez l'or d'un set ou réussissez un objectif communautaire pour en débloquer d'autres. »

**[Copy]** — The brand's case varies (§ Hero; 08; footer; public page)  
« Gameble est un jeu… » (hero) vs « gameble est gratuit et ouvert. » (08) and the spec's « gameble ».  
Fix: Pick one rule (always lowercase, or a capital at sentence start only), record it in Voice and Tone, align hero and 08.

**[Copy]** — The hero line is ambiguous (§ Hero, « … basé sur la bibliothèque publique de jeux Steam. »)  
On Steam « bibliothèque » means a player's own games, but owning a game never grants its card.  
Fix: Author's call: « … basé sur le catalogue de jeux Steam. »

**[Copy]** — The narrators' and artists' calls lead nowhere (§ 02 « Participer à l'écriture »; 07 « Artistes », « Narrateurs et scribes »)  
The link only scrolls to 07, whose only action is « Voir le projet » (GitHub).  
Fix: Name a channel for non-developers and link to it; if the link only scrolls, label it « Voir les postes ouverts ».

**[Copy]** — The feed's tier entry builds broken French (§ mock entryHTML; Copy deck › Feed)  
It produces « Léa atteint l'bronze du set … »; the copy deck gives only the argent example.  
Fix: Write all three forms: « atteint le bronze / l'argent / l'or du set {set}. »

**[Copy]** — The season note can be misread (§ 01, « Une rareté par saison » / « À chaque saison, les raretés sont recalculées. »)  
The title reads as "one rarity tier per season", and the line can make a visitor fear their cards will be downgraded, while each copy keeps its minted rarity.  
Fix: Title « Des raretés de saison »; line « … recalculées ; vos cartes gardent la leur. »

**[Copy]** — The « Contribuez » tile does not match its title (§ 02, « Tirages notables, découvertes, échanges, sets complétés : tout s'y affiche, en direct. »)  
Already flagged `[ASSUMPTION]`. « y » has no antecedent, and the text describes the feed that 04 shows in full.  
Fix: Point it at contributing (« Récit, dessin, musique, code : la Confrérie se construit aussi avec vos talents. ») and link to 07.

**[Copy]** — The hero action does not do what the hook asks (§ Hero « Rejoignez-la. » / « Embarquer sur le pont »; 09 hub link)  
The button opens the signed-out hub, so a visitor may read « Embarquer » as joining; « embarquer sur le pont » is an odd idiom. The label is author-approved. For 09, a second « Embarquer… » beside Valve's image would read as the sign-up.  
Fix: Settle 09 on « Visiter le pont sans compte »; optionally consider « Visiter le pont » for the hero.  
Also raised: Accessibility M4 recommends one name for both links instead.

### Low (44)

**[Rubric · Flow coverage]** — Flows 5 and 6 rest on four assumptions (§ EXPERIENCE.md › Flow 5 steps 1, 4, 5; Flow 6 step 2)  
Who shared the card, which items Camille plays with, which Steam entry she uses, and whether Yanis uses the gauge are all `[ASSUMPTION]`s, so the steps read as illustrative rather than committed.  
Fix: Confirm them, or rephrase as "for example" so no one reads them as required behavior.

**[Rubric · Token completeness]** — Several visual values have no token (§ DESIGN.md › Landing; Layout & Spacing › Landing on the phone)  
"Faint accent glow", "hard dark drop shadow 18px below", the soft text shadow, the lamp field's ~500px height, 224/184px illustration heights, 46px step squares, 24px roadmap nodes, 216px roadmap columns and the 176px example minimum height. The hero's "capped at 1120px" restates `{spacing.landing-content-max}` as a number.  
Fix: Move the reused ones into `components.lamp` or new `landing-*` spacing tokens, and refer to `landing-content-max` by name.

**[Rubric · Component coverage]** — The same parts have different names across the two files (§ DESIGN.md › Landing; EXPERIENCE.md › Landing)  
DESIGN "Module header" / EXPERIENCE "Module"; "Hero" / "Hero action"; "Lamp field" / "Lamp field (the lamp hero)"; DESIGN "06 · Feuille de route (the roadmap)" and "09 · Embarquement (the final call)" / EXPERIENCE "Roadmap (06)" and "Final call (09)".  
Fix: Use one name per part in both files.

**[Rubric · Component coverage]** — No in-row keyboard rule for the rarity row and the roadmap row (§ EXPERIENCE.md › Landing › Rarity cards, Roadmap; Interaction Primitives › Keyboard)  
Each row is "one tab stop", but nothing says how a keyboard user moves between the cards or milestones inside it. The Keyboard primitive lists only the gauge markers for the landing.  
Fix: Add the in-row keys (arrow keys, or "the container scrolls; items are not focusable") to the Keyboard primitive.  
Also raised: Accessibility M3 adds: tab stop only while the row overflows.

**[Rubric · State coverage]** — No way to switch language on the landing (§ EXPERIENCE.md › Landing; Accessibility Floor › Language)  
A signed-out visitor has no settings, and the landing is both /fr and /en; nothing says how a visitor who arrived on the wrong locale changes it.  
Fix: State whether the landing (or its footer) carries a FR/EN switch, or that the URL segment is the only way.

**[Rubric · Visual reference coverage]** — Inspiration cites direction letters no reader can open (§ EXPERIENCE.md › Inspiration, "Lifted from the landing renders")  
"Direction C's console" and "direction A's card field" name no file; the renders are in `.working/landing-direction-a.html` / `-c.html`.  
Fix: Link the two `.working` files, or describe what was lifted without the direction letters.

**[Rubric · Bloat & overspecification]** — A copy rule sits in Do's and Don'ts (§ DESIGN.md › Do's and Don'ts)  
The row on money, game figures and technical details repeats EXPERIENCE › Voice and Tone almost word for word. It is a copy rule, not a visual one.  
Fix: Keep it in Voice and Tone and point to it.

**[Rubric · Bloat & overspecification]** — The roadmap's build process appears twice (§ EXPERIENCE.md › Landing › Roadmap row; Implementation notes › Landing roadmap data)  
Opt-in fields, generating script, drift check and the sync rule are ticket material, not behavior.  
Fix: One line in the Roadmap row: "reads app roadmap data; its sync is a prerequisite ticket".

**[Rubric · Bloat & overspecification]** — The phone landing is spread over three places (§ DESIGN.md › Layout per-screen table; "Landing on the phone" bullet; Landing section)  
The 216px roadmap column appears only in the "Landing on the phone" bullet.  
Fix: Keep phone variants in the Landing section and point to them from Layout.

**[Rubric · Inheritance discipline]** — `lore.md` is missing from DESIGN's sources (§ DESIGN.md frontmatter)  
DESIGN's Landing framing (the Brotherhood's console, the lamp searching for lost games) draws on it, but only EXPERIENCE lists it.  
Fix: Add it to DESIGN's sources.

**[Rubric · Inheritance discipline]** — Two approved lines conflict with the rule against game figures (§ EXPERIENCE.md › Voice and Tone; Copy deck › Landing)  
03 « Chaque booster cache cinq cartes » and 04 « Récompense : un booster de cinq cartes, au moins une Épique ». Voice and Tone exempts only « Dix boosters vous attendent. »  
Fix: List them as kept exceptions, or reword.  
Also raised: Copy (medium) also finds « Chaque booster » factually wrong.

**[Accessibility]** — L1 — Module labels are outside the headings; some heading-like lines are paragraphs (both) (§ DESIGN.md › Landing › Module header, 07, 08; EXPERIENCE.md › Accessibility Floor › Landing)  
The gauge says "Concept" while the h2 says « Chaque carte est un jeu Steam. ». 07's « Nous recrutons… » and 08's support line look like headings but are paragraphs. The mock makes about thirteen region landmarks.  
Fix: Include the module label in the h2's accessible name; make 08's support line an h3; only main, the gauge's nav, the top bar and the footer are landmarks.

**[Accessibility]** — L2 — External and new-tab links lack their hidden copy (spine) (§ EXPERIENCE.md › Copy deck › Landing (07, 08, footer); Accessibility Floor › Links and sign-in)  
Only « Voir le projet » names its new tab; « Soutenir » and « Code source » also leave for another site in a new tab.  
Fix: Add hidden suffixes « (GitHub, nouvel onglet) » and « (site de dons, nouvel onglet) ».

**[Accessibility]** — L3 — Language of parts (spine) (§ EXPERIENCE.md › Accessibility Floor › Language; Copy deck › Landing)  
« LIVE » and « REPOST » are read with French pronunciation on a French page (3.1.2).  
Fix: The interface's English words carry `lang="en"`.

**[Accessibility]** — L4 — Under reduced motion the lamp freezes on « 2 / 6 » and the pointer no longer steers it (spine and mock) (§ EXPERIENCE.md › Motion › Reduced motion › Landing)  
No content is lost, but a reduced-motion visitor gets a counter that never moves and four cards no one can find.  
Fix: Under reduced motion the lamp jumps without travelling to the pointer's position, and a card under it is found; without a pointer it rests on the first card.

**[Accessibility]** — L5 — Decorative words in the lamp readout sit in the field's fade (spine and mock) (§ DESIGN.md › Landing › Lamp field)  
The readout falls inside the 82–100% mask fade and the sweep mode is `{colors.dim}` (3.51:1); acceptable only as decoration.  
Fix: State that the readout is decorative, like the field, and sits above the fade.

**[Accessibility]** — L6 — Phone targets below the house floor (mock only) (§ mockups/landing.html)  
« Révéler » at 34px on the phone, footer links wrapping with a 4px row gap, the top bar wordmark link about 24px tall.  
Fix: None in the spine; note these in the mock's header comment.

**[Accessibility]** — L7 — Visible text clipped at narrow widths (mock only) (§ mockups/landing.html (.mini__row, .tag, .chip-gold))  
At 320 CSS px, « Inès complète Dark Souls » is cut without an ellipsis (1.4.10, 1.4.12).  
Fix: Let these lines wrap; note it in the mock's header comment.

**[Feasibility]** — `CardComponent` has no `xs` face (§ app/components/card_component.rb; DESIGN.md › Lamp field)  
`SIZES = %i[s m l xl]`, but the lamp field uses two `card-xs`.  
Fix: Add `xs` to the component, or use `card-s`.

**[Feasibility]** — Landing breakpoints fall outside AD-27's set (§ DESIGN.md frontmatter)  
`{spacing.breakpoint-landing-gauge}` (1440px) and the 1120px cap are outside the 720/1180/1280 set.  
Fix: Note them as a landing exception in the architecture.

**[Feasibility]** — Where the landing CSS goes is unstated (§ AD-28)  
A second stylesheet is ruled out, so about 30–40KB of landing CSS joins `application.css` for every page.  
Fix: Accept it and say so in the plan, so no one adds a tracked head asset.

**[Feasibility]** — The reveal demo must not reuse the booster island (§ EXPERIENCE.md › Reveal demo; AD-16)  
A new island needs an amendment, and the booster island posts packs.  
Fix: A Stimulus controller with server-rendered `CardComponent` faces, a CSS flip, and server-rendered announcements in a polite live region.

**[Feasibility]** — Small decisions to settle before two builders diverge (§ EXPERIENCE.md › Copy deck, Landing; DESIGN.md › Landing)  
The final call's hub link label; the side gauge's accessible names; "one lime per view, read per screenful" on tall viewports; the wordmark returning to the top; where the public card page's two new links sit; the « Terminal en ligne » status.  
Fix: Settle each in the spine.  
Also raised: Rubric mechanical notes list the same open labels.

**[Feasibility]** — The hero's title size is ambiguous (§ DESIGN.md › Landing › Hero)  
The spine names the `{typography.public-title}` tokens but also quotes the mock's 42px and 38px.  
Fix: State which one binds.  
Also raised: Rubric (medium): the title sizes contradict their tokens.

**[Feasibility]** — The mock's feed shows entry kinds the feed does not have (§ mockups/landing.html; Game::FeedEntries)  
The mock shows set-tier and set-completion entries; `Game::FeedEntries` has pulls, discoveries, trades and reposts only.  
Fix: None in the spine; the builder should not add feed kinds for the landing.

**[Feasibility]** — The landing's behaviour can only be checked by unit and controller tests (§ AGENTS.md (system tests disabled))  
System tests are disabled, so no browser check covers the landing.  
Fix: Keep the lamp, moving-card, gauge and power-on logic as pure `lib/*.ts` functions with vitest; controller tests check both roots, the policies, both locales and that the HTML has no `style` attribute.

**[Copy]** — French typography: spaces before « : » and inside guillemets (§ Copy deck; mock)  
Plain spaces can let « : » or « » » wrap onto a line of its own.  
Fix: Use U+202F or U+00A0 in the landing's `fr.yml` strings.

**[Copy]** — Final periods are inconsistent on titles (§ 06, 07 titles)  
Most titles end with « . », two do not.  
Fix: Add the periods, or drop them everywhere.

**[Copy]** — « faites par IA » should read « par l'IA » (§ 07)  
Matches the title « développé avec l'IA »; the AI line may also read warily to artists (author's call).  
Fix: « … par l'IA ».

**[Copy]** — One destination has two labels (§ 07 « Voir le projet »; footer « Code source »)  
Both open the repository, and « Voir le projet » is vague.  
Fix: « Voir le code source », or keep the label with a fuller accessible name.

**[Copy]** — « relue par l'auteur » names an unknown person (§ 07)  
A visitor does not know who « l'auteur » is.  
Fix: « … relue par l'auteur du jeu » or « … avant d'être intégrée ».

**[Copy]** — « Nous recrutons » suggests paid jobs (§ 07)  
On a volunteer project, « Poste ouvert » reads as employment.  
Fix: « Nous cherchons des bénévoles… » / « Appel ouvert ».

**[Copy]** — « plus que nécessaire » can mean "more than needed" (§ 02)  
Author-approved.  
Fix: « indispensable » would remove the doubt.

**[Copy]** — « Un travail de longue haleine vous attend » sounds like a chore (§ 03)  
Author-approved; flagged only.  
Fix: None required.

**[Copy]** — « créez votre compte automatiquement » misstates who acts (§ 03)  
The visitor does not create anything automatically.  
Fix: « Connectez-vous avec Steam : votre compte est créé automatiquement. »

**[Copy]** — The lamp readout counts the card back and mixes verbs (§ Lamp readout)  
The mock counts the Standard card back among found "games"; the tag and counter use different verbs.  
Fix: Leave the back out (or « Cartes retrouvées ») and make the tag « Retrouvé ».

**[Copy]** — 01 notes repeat themselves and break rarity naming (§ 01)  
« Plus rare, plus vivante » says the same thing twice; « la plus courante » vs « commune »; « légendaire » lower-cased.  
Fix: A note that adds information; « De la plus commune à la Légendaire ».

**[Copy]** — 01 subtitle misdescribes the import rule (§ 01 subtitle)  
« triés sur le volet » means hand-picked; the player-facing rule speaks of review count. Author-approved.  
Fix: Optional: « … plus un jeu a d'avis sur Steam, plus sa carte est rare. »

**[Copy]** — The odds shown are the normal booster's (§ 01, « {n} % par carte »)  
The daily booster's odds differ, and odds are tuned in playtests.  
Fix: Read them from game data; optionally « par carte de booster ».

**[Copy]** — « au moins une Épique » can read as excluding a Légendaire (§ 04, 05)  
The spec says "Épique or better".  
Fix: « au moins une Épique ou mieux ».

**[Copy]** — 05 list wording (§ 05)  
« set complété » breaks the « premier… » series; collections are not completed, sets are.  
Fix: « premier set complété »; « … pour compléter vos sets. »

**[Copy]** — The mock and the copy deck disagree in small places (§ Mini rows; « {n} participants »; « Tous les joueurs »)  
Mini rows differ from the Feed copy; « participants » needs one and zero forms; « Tous les joueurs » has no clear meaning, and 1 128 appears under two labels.  
Fix: Align the mini rows; add the plural forms; drop or rename « Tous les joueurs ».

**[Copy]** — Smaller repetitions across modules (§ 02, 03, 05, 07)  
« doubles », the narrators' call, « semaine après semaine » and « Le code est ouvert » each appear two or three times.  
Fix: Say each once, where it carries the most weight.

**[Copy]** — Odds and ends (§ 06; footer; 08; DESIGN.md labels; public card page)  
06 suggests players shape the catalogue; the footer's « ni à Steam ni à Valve » order; the Valve mention needs a recorded tone exception; « ni revendues ni exploitées » is literally false; DESIGN writes labels in capitals while the deck uses sentence case; « Découvrir » is vague.  
Fix: « Le jeu se construit avec sa communauté. »; « n'est affilié ni à Steam ni à Valve »; record the exception; « ni vendues ni utilisées à d'autres fins que le jeu »; strings in sentence case with CSS capitals; « Découvrir le jeu ».

## Reviewer notes

### Accessibility review (`review-accessibility-2026-10-14.md`)

**Verdict (reviewer's words):** The landing's structure is sound: one h1 and one h2 per module, a named reveal demo with its own polite region, a side gauge built as a navigation landmark, roadmap statuses written in text, and the lamp and moving cards kept out of the accessibility tree. Two gaps block the build: the power-on rule leaves a whole module invisible once it is taller than about eight viewports (400% zoom), and a signed-out visitor cannot reach "Animations réduites", so the lamp sweep, the self-updating feed, the blinking LIVE marker and the rotating rays cannot be paused. **Not ready until both critical findings and the three high findings are written into the spines. The mediums should land before the landing's build story.**

Baseline: WCAG 2.2 AA plus the house floor. Computed contrast: `{colors.text-bright}` over a lit card falls to 1.17–1.39:1 in the lamp's inner disc and 2.21–3.35:1 in the next ring (fails); 5.91–7.86:1 in the outer ring and ≥ 13.9:1 under the full veil (pass). `{colors.muted}` on the side gauge plate 6.32:1 (pass; the spine fixes the mock's 3.38:1 dim numbers). Each finding says whether the gap is in the spine, the mock, or both.

### Technical feasibility review (`review-feasibility-2026-10-14.md`)

**Verdict (reviewer's words):** The landing can be built cleanly under the repository's rules. It needs no React island: everything is server HTML plus Stimulus controllers, it writes nothing on GET, and the CSP holds as long as per-element values go through CSSOM or CSS classes. The mock is not a safe blueprint, though, for three pieces: the lamp repaints a mask on every frame and never stops, which breaks AD-27; the moving cards can cover controls and focused links; and the live data has no caching story on what will be the most visited page. The landing also depends on three pieces of work outside the page: the roadmap sync, the lore text (French and English) and an app-wide switch to JetBrains Mono. **Expect about ten stories, not one.**

Holds without change: GET never writes; Pundit `PagePolicy#show?` admits anyone; packwerk dependencies stay web layer → Game, Catalog, Accounts queries; no new `gameble:*` events; no database ids; Valve's image reuses `SteamSignInComponent`. Suggested slicing: (1) JetBrains Mono app-wide, (2) roadmap generated from the initiative, (3) the landing's data, cached, (4) the static landing behind a staff-only route, (5) the lamp field, (6) the moving cards, (7) the live module and playable items, (8) the roadmap module, (9) the lore in French and English, (10) signed out, the root is the landing, after 8 and 9.

### Copy and tone review (`review-copy-2026-10-14.md`)

**Verdict (reviewer's words):** The landing keeps the core voice rules: « vous » throughout, no « tu », no title for the player, no exclamation mark, no Helldivers term, no money hammering, and the hook and mission premise are as approved. It does not yet match the game's facts. It promises things the launch does not have: the pioneer's name, card backs, set rewards, and a free licence that does not exist yet. It also shows the live weekly goal twice, word for word, and has one clear grammar error (« Collectionnez-les toutes »). **Settle the four high findings before the copy goes into `fr.yml`. The mediums should land before the landing's build story.**

The author's approved wording is not rewritten; every fix is a suggestion. Checked and clean: « vous » everywhere; no exclamation mark; « gratuit » appears once; no Helldivers term; the hook matches the author's wording; « Dix boosters vous attendent. » and « Réserve : 10 / 10 » match CAP-4; rarity names and house terms are spelled correctly; both spines block release until the lore is written.

## Mechanical notes

- Token references: every `{colors|typography|spacing|components|rounded.*}` reference in both files resolves against the DESIGN.md frontmatter (checked by script).
- Name inconsistencies: Module header / Module; Hero / Hero action; Lamp field / Lamp field (the lamp hero); « Réserve 10 / 10 » (DESIGN 09) vs « Réserve : 10 / 10 » (Copy deck); « TROUVÉ », « MISSION EN COURS » (DESIGN) vs « Trouvé », « Mission en cours » (Copy deck). The capitalization convention is not stated once.
- Token mismatch: module title "44px on a 48px line, the `{typography.hero}` size" vs `hero.lineHeight: 44px`.
- Open labels carried as assumptions: 09's hub link (« Visiter le pont sans compte » vs « Embarquer sur le pont »), the 02 « Contribuez » line, the side-gauge marker names, the top bar's « Terminal en ligne », and the wordmark's accessible name on the landing (« gameble, accueil ») vs the app's (« GAMEBLE, pont de commandement »).
- Frontmatter: both `updated: '2026-10-14'`. EXPERIENCE `sources` gains `lore.md` (it resolves); DESIGN `sources` does not.
- Mermaid: none in the changed content.

## Reviewer files

- `review-rubric-2026-10-14.md`
- `review-accessibility-2026-10-14.md`
- `review-feasibility-2026-10-14.md`
- `review-copy-2026-10-14.md`
