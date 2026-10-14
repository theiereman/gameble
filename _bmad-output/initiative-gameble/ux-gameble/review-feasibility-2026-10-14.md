---
title: 'Feasibility review: the visitor landing (2026-10-14 spine additions)'
lens: feasibility
created: '2026-10-14'
scope:
  - DESIGN.md and EXPERIENCE.md, the 2026-10-14 landing diff
  - mockups/landing.html (review toolbar ignored)
  - .memlog.md, 2026-10-14 entries
checked_against:
  - AGENTS.md
  - architecture-gameble.md (AD-11, AD-14, AD-16, AD-18, AD-27, AD-28)
  - config/initializers/content_security_policy.rb, rack_attack.rb, config/routes.rb
  - app/controllers (application, pages, sessions, accounts, feeds, locales), PublicRead concern
  - app/models/live_stream.rb, app/jobs/live_feed_job.rb, app/views/live_streams, app/views/shell, layouts
  - app/components/card_component.rb, app/frontend (controllers, lib/events.ts, fonts, styles)
  - .dockerignore, epic-public-launch-readiness/story-public-pages-throttled-or-cached-plan.md
---

# Feasibility review: the visitor landing

## Verdict

The landing can be built cleanly under the repository's rules. It needs no React island: everything is server HTML plus Stimulus controllers, it writes nothing on GET, and the CSP holds as long as per-element values go through CSSOM or CSS classes. The mock is not a safe blueprint, though, for three pieces. The lamp repaints a mask on every frame and never stops, which breaks AD-27. The moving cards can cover controls and focused links. And the live data has no caching story on what will be the most visited page. The landing also depends on three pieces of work outside the page: the roadmap sync, the lore text (French and English) and an app-wide switch to JetBrains Mono. Expect about ten stories, not one.

Counts: 0 critical, 5 high, 11 medium, 8 low.

## Findings

**[high]** The lamp as mocked breaks AD-27 and never goes idle (DESIGN.md Landing, Lamp field; EXPERIENCE.md Landing, Lamp field; mock `heroLamp`). The mock moves the veil's hole by rewriting `--lx`/`--ly`/`--r1..3` inside a `mask-image: radial-gradient(...)` on every rAF frame. That is a repaint of the whole masked layer on every frame, not a compositor-only change. AD-27 allows infinite animations to animate only `transform` or `opacity`, and loops must stop when nothing moves. Once every card is found, the spine has the lamp "wander across the field" forever, so on a phone the paint loop runs for as long as the tab stays open. The mock's frame loop also keeps running, writing transforms, while the hero is off-screen. *Fix:* draw the veil as one oversized element with a fixed radial hole (the three hard steps baked into its gradient) and move it with `translate3d`. Run the five-step power-on as five class swaps. The lit and found tests are plain math on six rectangles. Run the rAF loop only while the hero intersects the viewport and `document.visibilityState` is visible. When every card is found, settle on the last one and stop, and drop the endless wander from the spine. Replace the field's 18% bottom fade, which uses `mask-image` on the parent, with a ground-colour gradient overlay. Put the motion maths in a pure `lib/` module with vitest coverage, as `booster_keyframes.ts` does.

**[high]** The moving cards can rest over text, links and calls to action (DESIGN.md Landing, Moving cards; EXPERIENCE.md Landing, Moving cards and Accessibility). The cards catch the pointer (grab), sit wherever the scroll leaves them "near the left and right edges" over the 1120px column, and below about 1540px they overlap content. They can come to rest on the hero's lime button, 08's « Soutenir » or Valve's image, and a click there drags the card instead. When a keyboard user tabs, the browser scrolls the focused link into view, the scroll moves the cards, and a card can land on the focused element. That fails WCAG 2.2 SC 2.4.11 (Focus Not Obscured, AA). The spine's `[ASSUMPTION]` that "a user scrolls past" holds while scrolling, not at rest. *Fix:* pick one rule and write it into the spine. (a) The cards live only in the gutters outside `{spacing.landing-content-max}` and appear only when both gutters can hold a `card-m`. (b) Or the controller keeps exclusion zones around interactive elements, and any card that intersects `document.activeElement` while `:focus-visible` fades and stops catching the pointer. Option (a) is cheaper and testable.

**[high]** The most visited page has no caching or throttling story (EXPERIENCE.md Landing, Live feed list and Goal panels; DESIGN.md 04). Signed out, every hit on /fr or /en would read the published season, the goal, `Game::FeedEntries.call(nil)` (up to ten passes of 90 rows), card views for five feed entries and some 15 to 30 sample cards, three new aggregate counts, the odds and the roadmap. The page cannot be cached at the edge. Valve's image is a `button_to` POST form that needs the CSRF token. The CSP nonce is derived from the session id. The response sets the session cookie. `story-public-pages-throttled-or-cached` chose throttling for those same reasons. Even so, `PublicReadThrottle` does not cover the root: `"/fr".split("/",4)[1,2]` yields no page segment. On top of that, every visitor opens an Action Cable websocket (`turbo_stream_from`) to Solid Cable. *Fix:* in the landing ticket, fragment-cache each data block with `Rails.cache`, per locale. Key the feed on the latest feed entry id, the goal on its count, the sample cards on the published season and the roadmap on its file digest, with a TTL of 30 to 60s for the aggregates. Extend the throttle to signed-out GETs of `/:locale`. Have a Stimulus controller insert the cable stream source only when module 04 comes into view, or poll a cached Turbo Frame every 30 to 60s instead. Record the choice in the plan.

**[high]** The roadmap sync collides with three repo rules and with parallel work (EXPERIENCE.md Landing, Roadmap; Implementation notes, Landing roadmap data; memlog "Roadmap sync" assumption). The generated data has to carry French and English player-facing wording, but AGENTS.md puts every string in `en.yml` and `fr.yml`. It must not carry planning ids (no "epic 7", no CAP-n), yet epics are identified by them today. The status source is unstated: the plan's `status:`, `tickets.toml` or the GitLab tracker. A committed generated file changes on nearly every story PR, when a plan turns `done`. Parallel sessions would conflict on it, and a CI drift check fails every PR that forgets to regenerate. *Fix:* shape the ticket like `script/pixel_art/export.mjs`:
- Opt-in frontmatter on the epic or story: `roadmap: { key, order, fr, en }`, with the key a slug.
- Status derived from the plan's `status:` only: no plan means "à venir", a plan not yet done means "en cours", `done` means "fait".
- A generator writes `config/roadmap.yml` (structure, keys and statuses) and `config/locales/roadmap.{fr,en}.yml` (the strings). Configure `i18n-tasks` to read them and amend the AGENTS.md i18n rule to name them.
- `--check` runs in CI, which has `_bmad-output` in its checkout.
- Only opted-in entries are written, so most PRs leave the file untouched.

The alternative is to generate it in a Kamal pre-build hook and never commit it, trading conflicts for an unreproducible build. The author must decide between the two.

**[high]** The lore gate does not fit a develop-to-main release train (EXPERIENCE.md Landing, Lore panel; States, "Lore text not written"). Whatever merges to `develop` ships with the next release to `main`, and the repo uses no feature flags (AD-28). If the root switch merges before the lore exists, the landing ships with an empty slot. The lore also needs an English text, which neither the spine nor the memlog mentions. Its unknown length decides whether the 8-column lore panel balances the 4-column goal panel, as the balance rule demands. *Fix:* make the routing switch its own last story, after the lore story. Until then, serve the landing on a route whose Pundit policy admits staff only. Ask the lore session for French and English text and a length bound (for example, at most N words).

**[medium]** Mock patterns the CSP blocks (DESIGN.md Landing, Lamp field and Side gauge; mock `<head>`). The mock depends on:
- an inline `<script>` that adds `.js` before first paint;
- inline `<style>`;
- `style="--k:…"`, `--r`, `--fr` and `--fx` written through `innerHTML`;
- `el.style.left/top`;
- fonts as `data:` URIs: the full, unsubsetted 92KB JetBrains Mono, twice.

Under `script-src 'self'` there is no pre-paint hook, so module content hidden before its power-on would flash or stay hidden. *Fix:*
- Modules are visible by default. The power-on controller arms, at connect, only the modules not yet in view, and the hero entrance is a pure CSS animation.
- The lamp cards are a fixed set, so their slots and rotations go in `landing.css` as nth-child or modifier classes.
- Gauge staggers come from nth-child rules or from `el.style.setProperty` in a controller. CSSOM writes are not governed by `style-src`; `setAttribute('style')` and `style` inside `innerHTML` are.
- Self-hosted subsetted woff2, never `data:` fonts.

**[medium]** JetBrains Mono is not in the app (DESIGN.md Typography; `app/frontend/fonts/`). The app ships Space Mono. DESIGN.md has named JetBrains Mono since 2026-10-13, but no ticket in the tree covers the switch. Built alone, the landing would be the only page in JetBrains Mono, or it would carry an app-wide font change that moves every fixed-width chip. *Fix:* a shell story before the landing: fontsource latin and latin-ext subsets at 400 and 700 with the OFL text, preload of the two latin files, Space Mono removed, and a pass over the fixed-width chips and top-bar titles.

**[medium]** The signed-out root switch leaves many entry points undecided (EXPERIENCE.md Information Architecture, Signed-out visitors, States; DESIGN.md Signed-out hub). The spine settles the GAMEBLE link, sign-out, deletion, the root and the public card page. It does not settle:
- the signed-out hub's own URL;
- where `refuse_in_locale` sends a signed-out deep link (today `home_path` with a "sign in required" alert, which would then appear on the landing);
- the phone tab bar's PONT on the signed-out hub;
- Esc "returns to the hub";
- the back button's "hidden when the previous screen is the hub";
- `sessions#failure`'s fallback;
- whether a signed-in player can ever see the landing.

Two builders will route these differently. The landing GET must also be `public_read?` (the PublicRead concern) so link previews and older browsers get the root, and the spines give no `<title>`, meta description or Open Graph image for it. *Fix:* add a table to EXPERIENCE.md listing each entry point and its target, landing or signed-out hub (`/:locale/bridge` or similar). Implement it as one `hub_path` helper and branch `PagesController#home` on `current_player`. The pages_controller signed-out-hub tests move to the new route. Add the meta copy to the copy deck.

**[medium]** The live module's data is underspecified (DESIGN.md 04; EXPERIENCE.md Landing, Live feed list; Open questions). Several definitions are missing:
- "Joueurs actifs cette semaine": a calendar week or the last seven days, in which time zone? Presence is written only with throttling (`note_presence`).
- "Boosters ouverts aujourd'hui": whose day?
- "Premières découvertes cette semaine": same question.
- Whether these figures update live. The mock ticks them every 8s and the spine says they "follow the game", but no broadcast exists.
- How a new entry slides in at the top while the oldest leaves. `LiveFeedJob` replaces `#live-strip` wholesale with the latest three entries, and a replace cannot slide one entry in.

*Fix:* settle each figure as a UTC goal week (Monday) or a rolling 24h. Read the figures at page load, cached for 60s at most, with no live update. Extend `LiveFeedJob` to prepend to a `landing-feed` target and trim it to five with a custom stream action, registered with the others through `registerStreamActions`. With fewer than five entries, use the feed's own empty copy.

**[medium]** Nothing says where the sample cards come from (memlog "Landing content"; DESIGN.md Lamp field, 01, Moving cards; EXPERIENCE.md Reveal demo). The page shows cards in the lamp (6, or 5 on the phone), in 01 (one per rarity), as moving cards (5), as reveal samples, and as thumbnails in 02, 03 and 05. The spine says "chosen" but not by whom or how: fixed slugs, config, a random pick per request, the published season? A random pick defeats caching and tests, and a fixed slug can disappear when seasons change. *Fix:* `config/landing.yml` names a slug per slot, with a fallback to the published season's top card of the slot's rarity. A test checks the list against fixtures.

**[medium]** Cover weight on phones (DESIGN.md Landing; AD-27 budget). Production art is Steam's `library_600x900.jpg` (roughly 80 to 200KB each) run through the pixel filter. The mock uses tiny placeholder PNGs, so its smoothness proves nothing. Counted naively the landing shows about 30 covers, five of them on the phone's first screen. *Fix:* reuse a curated set of 8 to 10 games across every module, so the browser cache and the filtered-bitmap cache are hit. Keep `card_art_controller`'s lazy drawing and set `content-visibility: auto` on modules. Measure on the reference low-end Android (AD-27): LCP, frame time while the lamp sweeps, and bytes transferred.

**[medium]** The star-field drift `[ASSUMPTION]` contradicts AD-27 (EXPERIENCE.md Motion, Landing star field). The app's star field is one fixed, still, `data-turbo-permanent` layer. The mock draws two page-tall box-shadow layers, about 9000px tall, and translates them on scroll. Those are huge composited layers, and a transform left on the permanent layer would follow the visitor into the hub. *Fix:* drop the drift. If the author keeps it, use a landing-only, viewport-fixed, tileable layer translated modulo its tile height, removed when the controller disconnects, and amend AD-27.

**[medium]** The roadmap module's size and target are open (DESIGN.md 06; EXPERIENCE.md Roadmap, Open questions). It is unclear whether "one row of six" is a cap or the initiative's own count. "A few stories (two in the mock)" clashes with the balance rule once the data varies. "Voir toute la feuille de route" points to a page that is "decided, not designed". *Fix:* show at most six milestones, chosen by `order`, with exactly two stories each in the data. Hide the link until the roadmap page exists, or build a plain list page inside the sync ticket.

**[medium]** The English copy is unwritten and has no review gate (EXPERIENCE.md Open questions). About 150 strings, and the English rarity names, which are still open app-wide. The builder would write them at build time against a tone the author polices closely, and `i18n-tasks` checks presence, not voice. *Fix:* mark the landing's copy as HITL in its plan, so the author approves the English in the PR, or write it in a copy ticket ahead of the build.

**[medium]** Auto-moving content, and no way to stop it for a signed-out visitor (EXPERIENCE.md Landing; Accessibility). The lamp sweeps for well over 5s and the live list updates by itself (WCAG 2.2.2, Pause, Stop, Hide). The only signed-out control is the system's reduced-motion setting, because « Animations réduites » lives in the signed-in settings. *Fix:* the lamp stops once every card is found (see the lamp finding). Give the live list a pause, or make it update only when the module comes into view. Write whichever is chosen into the spine.

**[medium]** "Desktop" and "touch" are defined by width in one place and by input in another (EXPERIENCE.md Landing, Moving cards "from 720px"; Lamp field "Phone and touch"; mock gates on `pointerType === "mouse"`). On a 1024px iPad or a touchscreen laptop, a card that can be dragged by touch needs `touch-action: none`, and then a scroll that starts on a card drags the card instead. *Fix:* gate the moving cards and the pointer-driven lamp on `(min-width: 720px) and (hover: hover) and (pointer: fine)`, and write that into the spine.

**[low]** `CardComponent` has no `xs` face (`SIZES = %i[s m l xl]`), but the lamp field uses two `card-xs`. One is a back, which already has `-xs` PNGs. *Fix:* add `xs` to the component, or use `card-s`.

**[low]** `{spacing.breakpoint-landing-gauge}` (1440px) and the 1120px cap fall outside AD-27's 720/1180/1280 set. *Fix:* note them as a landing exception in the architecture.

**[low]** Where the landing CSS goes is unstated. AD-28 rules out a second stylesheet, so the landing's roughly 30 to 40KB of CSS joins `application.css` for every page. *Fix:* accept that, and say so in the plan, so no one adds a tracked head asset (which would force Turbo into full reloads between the landing and the hub).

**[low]** The reveal demo must not reuse the booster island (AD-16: a new island needs an amendment, and the booster island posts packs). *Fix:* a Stimulus controller with server-rendered `CardComponent` faces for the samples, a CSS flip, and each sample's announcement rendered by the server into a polite live region. JS builds no strings.

**[low]** Settle these before the build so two builders don't diverge:
- the final call's hub link label;
- the side gauge's accessible names;
- "one lime per view, read per screenful": a very tall viewport can still show both;
- the wordmark on the landing returning to the top;
- where the public card page's two new links sit;
- the « Terminal en ligne » status in the top bar.

**[low]** The hero's title size is ambiguous (DESIGN.md Landing, Hero). The spine names the `{typography.public-title}` tokens but also quotes the mock's 42px and 38px. *Fix:* state which one binds.

**[low]** The mock's feed shows set-tier and set-completion entries. `Game::FeedEntries` has pulls, discoveries, trades and reposts only. *Fix:* none needed ("entries as in Feed"), but the builder should not add new feed kinds for the landing.

**[low]** System tests are disabled, so the landing's behaviour can only be checked through vitest and controller tests. *Fix:* keep the lamp, moving-card, gauge and power-on logic as pure `lib/*.ts` functions with vitest coverage. Controller tests check the signed-out and signed-in roots, the policies, both locales and that the HTML has no `style` attribute.

What holds without change:
- GET never writes: lamp progress and drag offsets live in memory and reset on reload.
- Pundit is a `PagePolicy#show?` that admits anyone.
- The packwerk dependencies are web layer to Game, Catalog and Accounts queries, plus one new Accounts active-player count.
- No `gameble:*` events are needed: Turbo streams carry the live list.
- No database ids appear anywhere: cards go by slug, feed entries by their DOM ids from tokens, as in the feed.
- Valve's image reuses `SteamSignInComponent`, with `origin` set to the landing path.

## Suggested build slicing

1. **The app moves to JetBrains Mono.** A shell story: subsetted woff2 files, preload, Space Mono retired, a pass over fixed-width chips.
2. **The roadmap is generated from the initiative.** Opt-in frontmatter, a generator with `--check`, `config/roadmap.yml` and `config/locales/roadmap.{fr,en}.yml`, the CI step, the AGENTS.md rule, `i18n-tasks` config. The author fills in the first entries.
3. **The landing's data, cached.** Season-figure queries (Accounts, Game), `config/landing.yml` sample cards, a landing presenter with fragment caching, the throttle extended to the signed-out root, `LiveFeedJob` feeding a five-entry `landing-feed`.
4. **The landing, static, behind a staff-only route.** The `public_page` layout with the slim top bar and the landing footer, the hero text, modules 01 to 09 at every breakpoint, FR copy and EN copy for the author's review, reduced motion, the `xs` face, the module power-on and side gauge controllers.
5. **The lamp field.** Compositor-only veil, intersection and visibility gating, the stop rule, reduced-motion form, vitest.
6. **The moving cards.** Gutter rule or exclusion rule, the fine-pointer gate, drag, vitest.
7. **The live module and the playable items.** The lazily subscribed stream (or polling), slide-in and trim, the reveal demo, the tilting rarity row.
8. **The roadmap module.** The six-milestone row; the "full roadmap" link hidden, or a minimal roadmap page.
9. **The Brotherhood's lore, French and English.** A content story fed by the lore session, with a length bound.
10. **Signed out, the root is the landing.** The signed-out hub's own route, the `hub_path` helper, sign-out and deletion landing there, the refused-deep-link target, the tab bar and Esc for visitors, the public card page's « Découvrir » and play link, `public_read?`, meta and OG tags. This story comes after stories 8 and 9.
