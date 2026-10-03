---
epic: epic-collection-and-sharing
date: 2026-10-03
verdict: accepted-with-open-items
criteria: declared
headless: true
---

# Retrospective: Collection and sharing (epic 4)

## Epic summary

**Epic:** `epic-collection-and-sharing` (id 4), `_bmad-output/initiative-gameble/epic-collection-and-sharing/epic-collection-and-sharing.md`. It covers CAP-6, CAP-7, CAP-8, CAP-9 and CAP-18, requirements R1–R7, and five Done-when criteria.

**Tickets.** From `tickets.py status <folder>`, in build order. All six tickets have `status = built` and `state = review`, so `pending_tickets` is empty. None is marked done, because the author has not closed them. All six are still at `built`.

| Ref | Title | Risk | Plan baseline | Own code commit (from subject) | Review |
|---|---|---|---|---|---|
| 4.1 | Library of sets | medium | `9fcb676` | `e4debcf` | quick, pinned: 6 findings, 6 patched |
| 4.2 | Tome slots | low | `e4debcf` | `12c93b7` | quick, pinned: 2 findings, 2 patched |
| 4.3 | Card detail | low | `b818a88` | `ba8a19a` (+ `66e6ba1` docs) | quick, pinned: 3 findings (1 patched, 1 deferred, 1 rejected) |
| 4.4 | Public profile | low | `aa79a41` | `2101a70` (+ `d39bbdc`, `530566b` docs) | quick, pinned: 5 findings (3 patched, 1 deferred, 1 rejected) |
| 4.5 | Share a card | medium | `d1c4c3c` | `84a8613` (+ `4b1dfe4` docs) | quick, pinned: 5 findings (4 patched, 1 deferred) |
| 4.6 | Refactor sweep | low | `da3c974` | `91a7ea7`, `ba618a7` (+ `77eec31`, `bee4272` docs) | thorough, four lenses, plus a follow-up pass: 27 + 25 findings |

**Ranges.** Each range runs from a plan's `baseline_revision` to the next baseline, oldest first. The baselines are all distinct and in ticket order. `git_evidence.py` ran once per range, and no range contains a merge (`merge_count 0`).

| Range | Ticket | Commits in range | Epic-4 commits | Other commits in the range |
|---|---|---|---|---|
| `9fcb676..e4debcf` | 4.1 | 1 | `e4debcf` | none |
| `e4debcf..b818a88` | 4.2 | 4 | `12c93b7`, `c9cd92f`, `d297605` | `b818a88` (spec: friends feed, CAP-19) |
| `b818a88..aa79a41` | 4.3 | 3 | `ba8a19a`, `66e6ba1` | `aa79a41` (settling pending approvals) |
| `aa79a41..d1c4c3c` | 4.4 | 6 | `2101a70`, `d39bbdc`, `530566b` | `4f1601a` (epic 2 and 3 retros), `9a662fd` (ticket 3.11), `d1c4c3c` (3.11 docs) |
| `d1c4c3c..da3c974` | 4.5 | 8 | `84a8613`, `4b1dfe4` | `5540b45`, `2d90876` (story 2.10); `21e511c`, `c1427ac`, `2286751`, `da3c974` (story 2.11) |
| `da3c974..HEAD` (`bee4272`, inferred) | 4.6 | 4 | `91a7ea7`, `77eec31`, `ba618a7`, `bee4272` | none; HEAD is still epic 4's last commit |

The epic's own code commits come to about 6,300 inserted lines across 7 commits, plans included:

| Commit | Ticket | Lines added / removed |
|---|---|---|
| `e4debcf` | 4.1 | +1,175 / −9 |
| `12c93b7` | 4.2 | +1,011 / −37 |
| `ba8a19a` | 4.3 | +879 / −26 |
| `2101a70` | 4.4 | +1,631 / −72 |
| `84a8613` | 4.5 | +983 / −36 |
| `91a7ea7` | 4.6 | +592 / −214 |
| `ba618a7` | 4.6 (follow-up) | +59 / −6 |

Stories 2.10, 2.11 and 3.11 were built in the middle of the epic, so the 4.4 and 4.5 ranges hold other epics' work (finding P2). Story 2.10 also changed epic 4 code: `5540b45` removed the card detail's credit and added the ownership notice (finding R-1).

**Evidence inventory.**

Available:
- the epic file, the initiative file, `tickets.toml`, and the spec (CAP-6 to CAP-9, CAP-18);
- the architecture spine (AD-2, AD-11, AD-15, AD-16, AD-18);
- six plans, each with a Review Triage Log, Verification and an Auto Run Result (4.3–4.6);
- `deferred-work.md` and `pending-approvals.md`;
- git history;
- the previous retrospectives (`epic-packs-and-reveal-retrospective.md`, `epic-steam-catalog-retrospective.md`);
- two orchestrator session logs:
  - `~/.claude/projects/-home-teyermann-projets-gameble/16906cad-8d2e-44f7-b728-8e8e3d26e2ca.jsonl` (2026-10-02, slicing and stories 4.1–4.2);
  - `aab0038f-e32f-4b36-939a-df613f44918a.jsonl` (2026-10-03, stories 4.3–4.6). Only the author's own messages were read from them.

Missing:
- story files: no ticket was refined, and `file = null` for all six;
- dated `### <date>` Code Review blocks;
- the transcripts of the subagents that built each story (only their hand-back reports exist);
- each plan's own commit (no `built_revision`; see P2).

## Findings

Every finding has two dispositions:
- **for this instance:** fix now, defer, or accept;
- **for the next one:** the upstream lesson.

The lens findings come from `bmad-review`, run on `git diff 9fcb676..HEAD`. The diff covers the 104 files that epic 4's commits touched, except `Gemfile.lock`, `db/schema.rb` and `README.md` (staged as `epic4.diff`). Three lenses ran in parallel:
- adversarial (ADV, 14 findings);
- edge-case-hunter (EC, 10 findings);
- verification-gap (VG, 3 findings).

Every finding used below was re-checked against the source at `bee4272`. One was dropped (see "Dropped").

### Aggregate view: architecture delta

- **A1. The pack boundaries held (positive).**
  - `packs/accounts/package.yml` still depends only on `lib`. The Steam persona lookup is orchestrated by the web layer (`SessionsController#persona_name`), which passes the name into `Accounts::SignIn`, so Accounts never calls Steam.
  - `packs/game/package.yml` keeps `lib, accounts, catalog`. `Game::SetProgress`, `StartedSets` and `CollectionSummary` read Catalog's membership table, which AD-2 allows (4.1 plan, Boundaries).
  - `bundle exec packwerk check` was re-run by this retrospective: "No offenses detected".
  - Disposition: accept.
- **A2. The views read controller constants.**
  - `ShelvesHelper#profile_shelf_links` and `public_profiles/set.html.erb` read `PublicProfilesController::STARTED` and `::TABS`.
  - `library/_shelf.html.erb` defaults to `LibraryController::KINDS`, which resolves through `ShelfLoading`.
  - This existed before 4.6, and the sweep rejected it as false (4.6 plan, triage row "ShelvesHelper makes views depend on controller constants").
  - Disposition: accept. The UX redesign will replace these views.

### Aggregate view: duplication map

- **D1. The sweep removed the epic's duplication (positive).**
  - One tome loader, `ShelfLoading#load_set`.
  - One card-detail loader, `CardDetailLoading`.
  - Shelf link builders in `ShelvesHelper`.
  - The set-link rule in `cards/_detail`.
  - Shared request-test helpers in `test/support/library_requests.rb` (all from `91a7ea7`).

  Disposition: accept.
- **D2. `hold` and request `sign_in` remain copied in about 11 test files outside epic 4.** The 4.6 follow-up review rejected this as out of scope (4.6 plan, follow-up triage). Disposition: defer, for a later sweep.

### Aggregate view: size growth

- **S1. No god-class.**
  - The largest files the epic produced or grew:
    - `app/frontend/styles/library.css` (371 lines);
    - `card-detail.css` (188);
    - `app/controllers/public_profiles_controller.rb` (95);
    - `app/views/cards/_detail.html.erb` (79).
  - The locale files grew to 405 lines (`en`) and 412 lines (`fr`), mostly from `catalog.genres.*` and `library.*`.
  - Every query object stays under 65 lines.
  - Disposition: accept.

### Aggregate view: pattern divergence

- **PD1. Steam knowledge sits in the web layer.** `card_detail_store_url` adds Steam's `l=french` in the web layer (AD-4). This is recorded in `deferred-work.md` (4.3, rejected). Disposition: accept as recorded.
- **PD2. The code follows the established patterns (positive).**
  - Queries are module `call`s returning `Data` structs, and `Catalog::CardDetail` follows `CardViews`' pluck pattern.
  - Every page asserts its exact query count:
    - library 6/4, set 9/6;
    - profile 7/8, profile set 9/10;
    - card 4/2, shared card 10/11.
  - Disposition: accept.

### Aggregate view: spec-to-implementation reconciliation

- **R-1. The epic's R3 still says "publisher and copyright".**
  - Story 2.10 (`5540b45`) replaced the stored credit with a generic ownership notice (`card_details.notice`). The author decided this on 2026-10-03 (session log `aab0038f`, 08:21: "afficher une info pour dire que l'image nous appartient pas et oui le nom de l'éditeur").
  - The spec's CAP-7 was updated to "a notice that the game and its image belong to their owners" (`spec-gameble.md:62`). The epic file was not (`epic-collection-and-sharing.md:29`).
  - Done-when 2 does not name the copyright, so the criterion is unaffected.
  - Disposition: defer, as a spec reconciliation (action item 5).
- **R-2. The epic order now conflicts.**
  - Story 2.10 is `after = [9, "4.3"]` (`epic-steam-catalog/tickets.toml:115`), while epic 4 is `after` epic 2.
  - `tickets.py status` reports `order_conflict: epic-steam-catalog after epic-collection-and-sharing` and `undeclared_after` for 2.10.
  - The re-sequencing is recorded at ticket level, as the epic 2 retro asked (lesson 8c). It is not reconciled at epic level.
  - Disposition: defer, as a reconciliation (action item 5).
- **R-3. Behavior was added beyond the requirements, and each addition is recorded.**
  - The profile's "Started" tab and "Complete" labels (4.4 Design Notes).
  - The persona-name title (the author's decision of 2026-10-03, in the epic Notes).
  - `noindex` on profile pages.
  - Disposition: accept.
- **R-4. Some requirements were deferred, and each deferral is recorded.**
  - The status band's per-rarity counts.
  - AD-11's reading role.
  - "Set complete" styling in the player's own library.
  - Links from the reveal island to the detail: `pending-approvals.md`. The ticket says "cards anywhere lead to it", but the island's cards are not links.

  All of them are in `deferred-work.md` or `pending-approvals.md`. Disposition: accept as recorded.
- **R-5. The attic, lectern and shelf presentation will change.** The author will redo the UX with bmad-ux (initiative Notes, 2026-10-03). R1's "reached from the attic's lectern" and the shelf/tome metaphor are expected to change; the queries, routes and sharing stay. Disposition: accept. Presentation findings go to the redesign (action item 6).

### Diff-scope review: cross-story boundaries

These are defects at the seams between stories. No single story's quick review saw both sides of them.

- **B1. A card opened from a profile tome leaves the profile** (ADV 1, EC 2; two lenses). *Verified.*
  - Location: `app/views/library/_tome.html.erb:25,30` and `app/helpers/card_details_helper.rb:28`.
  - Story 4.4 reused 4.2's `_tome` on the profile. `link_to_card_detail` always links to `card_season_path`, the viewer's own `/cards/:slug/seasons/:n`. Story 4.5 later added `brother_card_season_path`, but did not rewire the profile's tome.
  - A visitor who clicks the owner's card on a profile therefore:
    - loses the owner's context (no owner line);
    - sees their own copies and share button instead;
    - leaves the `public_read?` area. `CardsController` is still modern-browser only, and `public_profiles_card_test.rb:241` shows `/cards/…` answers 406 to iOS 16 Safari.
  - The 4.4 intent asked for faces to "link to their card-season detail (4.3)", so this is as specified. The seam appeared only once 4.5 existed.
  - Disposition: **fix now** (action item 1).
- **B2. A shared-card URL can claim any card for any player** (ADV 3, EC 3). *Verified.*
  - Location: `PublicProfilesController#card` and `cards/_detail.html.erb:30`.
  - `/brothers/:token/cards/:slug` answers 200, with full preview tags, for any card of the season. When the owner does not hold it, it says "No longer in X's collection", even if they never held it, or hold it only in another season.
  - The 4.5 intent chose this behavior ("traded away, or a crafted URL … status 200"). But "no longer" asserts a past holding that the code never checks, and the preview carries the owner's name.
  - Disposition: **fix now**, with an author decision (action item 2).
- **B3. An older browser hits a dead end after following a shared link** (ADV 2).
  - `public_read?` lets an older browser read a shared card, but the invitation's Steam callback and the attic answer 406.
  - This was already found by 4.5's review and is recorded in `pending-approvals.md` ("Older browsers signing in from a shared card").
  - Disposition: defer (the author's decision is pending).
- **B4. A Steam persona name can look blank or spoof another** (ADV 7, EC 4). *Verified.*
  - Location: `packs/accounts/app/operations/accounts/sign_in.rb:47-48`.
  - `gsub(/[[:cntrl:]]/, "")` removes only Cc characters. These survive and pass `present?`:
    - zero-width characters (U+200B);
    - bidi overrides (U+202E, U+2066);
    - U+3000.
  - Effects on the profile title:
    - it can look empty, and the "Brother <code>" fallback is never used;
    - an unclosed right-to-left override reorders "From the collection of %{owner}" on shared cards;
    - a name can imitate another player's fallback.
  - 4.4's review fixed the NUL byte case only.
  - Disposition: **fix now** (action item 4).

### Diff-scope review: PUBLIC_URL (one cluster, three lenses)

- **U1. A missing `PUBLIC_URL` makes the whole card page fail, not just sharing** (ADV 5, EC 5). *Verified.*
  - `CardsController#show` builds `share_url` for every holder (`cards_controller.rb:19`). `public_url_for` raises `MissingPublicUrl` in production (`public_urls_helper.rb:20`).
  - So an unset `PUBLIC_URL` makes every holder's card detail a 500, not only the share button. The same applies to every shared-card page (og:url).
  - This is known and documented in `pending-approvals.md`. `config/deploy.yml:71` sets the value today.
  - Disposition: **fix now**, in a small hardening story (action item 3): fail at boot, or degrade only the share button.
- **U2. `PUBLIC_URL` is not validated, and its parsing is untested** (ADV 6, EC 6, VG 2). *Verified.*
  - `config/initializers/public_url.rb:7` keeps any non-blank string after `chomp("/")`. A value without a scheme, or with a path, gives malformed share links, og:url and canonical.
  - No test loads the initializer: every test assigns `Rails.configuration.x.public_url` directly.
  - Disposition: **fix now** (action item 3).
- **U3. Nothing pins `PUBLIC_URL` in `deploy.yml`** (VG 1). *Verified.*
  - `test/config/queue_config_test.rb:43-48` checks deploy.yml's import role and Steam key, not `PUBLIC_URL`.
  - Removing the entry when moving to the HTTPS host would fail no test. Production would then break at request time while `/up` stays green.
  - Disposition: **fix now** (action item 3).
- **U4. The share system test breaks when `PUBLIC_URL` is exported in the shell** (VG 3). *Verified.*
  - `test/system/share_card_test.rb:12-24` does not reset `Rails.configuration.x.public_url`.
  - 4.5's review patched the controller and helper tests for this case, but not the system test, which is the only browser-level check of Done-when 3.
  - Disposition: **fix now** (action item 3).
- **U5. Shared links today point at a LAN address** (ADV 4).
  - `PUBLIC_URL: http://192.168.1.6` means every link copied now points at an address nobody outside the LAN can reach, and stays broken after the move.
  - This is known (`pending-approvals.md`, "`PUBLIC_URL` for the public host").
  - Disposition: defer (it waits on a public HTTPS host).

### Diff-scope review: other findings

- **O1. The persona lookup is slow when Steam is slow** (ADV 8, EC claim).
  - The lookup can hold sign-in about 10 s.
  - It runs before the ban check.
  - A missing or invalid key is only logged as a warning, so production profiles would silently fall back to "Brother <code>".
  - The first two points are already in `deferred-work.md` (4.4 entries). The warn-only key failure is new.
  - Disposition: defer, adding the warn-only key failure to the existing entry (action item 7).
- **O2. A name write that fails rolls back the sign-in** (ADV 9). `store_persona_name` runs `update!` inside the sign-in transaction, so a future validation on `Player` would roll back the sign-in. Disposition: defer (latent, nothing validates it today).
- **O3. Profiles are public by default, with no opt-out or token rotation until epic 7** (ADV 10). This is the planned scope: epic 7's "hide profile", recorded in the epic Notes (4.4). Disposition: accept. Epic 7 Done-when 1 covers hiding.
- **O4. Public pages are neither throttled nor cached** (ADV 12).
  - `config/initializers/rack_attack.rb:4` says "Page reads are never throttled".
  - Each profile request runs about ten queries, including a season-wide grouped read.
  - Disposition: defer, to launch readiness (action item 7).
- **O5. Smaller edge cases.** Disposition: defer (action item 7) or accept.
  - `og_locale` uses `fetch`, so a third locale would make shared cards a 500 (ADV 13).
  - A holder who copies their own `/cards/…` address gets no preview tags (ADV 14).
  - A profile whose owner holds only older-season cards reads "0 cards collected" under a card they shared (EC 7).
  - `SetLabel` gives a nil label for a publisher set without a name (EC 8). The import always sets it.
  - A set link from the card detail opens the shelf at page 1, not on the set's own page (EC 9). This is presentation, for the redesign.
  - The shelf counts every member while the tome counts only cards with rarity and text (ADV 11). This cannot happen in a published season: publication rates every card-season, and every card has a text in each locale.
- **Dropped.** EC 1 claimed that an unknown token requested as JSON gives a 500 (`MissingTemplate`). A probe on the test database returned 404 for `/en/brothers/<unknown>.json` and for `Accept: application/json`, and 406 for a known token as `.json`.

### Process lessons (plans, commits and session logs)

- **P1. The cross-story lens pass that epic 3's retro asked for did not run.**
  - Stories 4.1–4.5 each ran one pinned quick review. That fits their risk, since none is `high`.
  - The epic 3 retro's item 8 also asked for "one cross-story lens pass before the refactor sweep". It did not run. The sweep's thorough review covered the sweep's own diff (`91a7ea7`), not the epic's.
  - The three-lens pass here found B1, B2, B4 and the PUBLIC_URL test gaps U2–U4, none of which any story review saw.
  - This is the same lesson as epic 3's P1.
  - Disposition: process change (action item 8).
- **P2. Plans still do not record their own commit, and other epics' builds landed inside epic 4's ranges.**
  - No plan has a `built_revision`.
  - 3.11, 2.10 and 2.11 were built between 4.4 and 4.6, so their commits sit in the 4.4 and 4.5 ranges. Attribution had to be done from commit subjects again.
  - One commit per story held throughout, and each story's code commit carries its plan, which made attribution easy.
  - Disposition: process change (action item 8).
- **P3. A story in another epic changed built behavior without reconciling this epic's text.**
  - Story 2.10 removed the card detail's credit (`5540b45`). The spec was updated, but epic 4's R3 was not (R-1).
  - The epic-level `after` was not reconciled either (R-2).
  - Disposition: process change (action item 8).
- **P4. Deferrals reached `deferred-work.md` only through the sweep.**
  - 4.1's AD-11 role, 4.2's "set complete" styling and the status band counts were deferred in the plans' Boundaries or the epic Notes. They reached `deferred-work.md` only in the sweep (`91a7ea7`, the first commit whose diff adds them), not in each story's commit as epic 2's lesson 8a asked.
  - Partly landed: nothing was lost, but the gap lasted for the whole epic.
  - Disposition: process change (action item 8).
- **P5. A pending-approval entry disappeared without a "Settled" line.**
  - "Development database migration (story 4.4)" (`persona_name`) was added in `d39bbdc` and deleted in `530566b`, whose subject only concerns the epic Notes.
  - No "Settled" line records that development was migrated.
  - Disposition: open question; process change (action item 8).
- **P6. Story 4.5 was not marked `hitl`, though Done-when 3 needs a person.**
  - Done-when 3 needs real Discord, X and WhatsApp previews, which only a person on a public HTTPS host can check. The story has `hitl = false`.
  - Epic 3's lesson 8c asked for `hitl = true` in such cases.
  - Disposition: process change (action item 8); the manual check is in `pending-approvals.md`.
- **P7. What worked (positive).**
  - Every deviation and deferral is recorded where a reader finds it: plan Design Notes, `pending-approvals.md`, `deferred-work.md`.
  - The 4.4 build saw that `config/steam_api.key` exists locally. It added a test-wide safety net: empty Faraday adapters for both Steam clients in `test/test_helper.rb`. No test can now reach the real Steam API.
  - The sweep cleared every epic 2 and epic 3 retro item addressed to it (D1, O2, O5, F8, F6), fixed the schema drift that would have failed CI, and checked it on CI's `postgres:18` image.
  - Each story kept to its own commit (owner's rule).

## Behavior verification

Exercised by this retrospective, on the test database only, with `PUBLIC_URL` unset:

- `bin/rails test` gave 932 runs, 15,251 assertions, 0 failures, 0 errors and 0 skips.
- `bin/rails test test/system/{library,tome,card_detail,public_profile,share_card}_test.rb` gave 17 runs, 135 assertions and 0 failures. These system tests drive a headless browser through:
  - the lectern to the library and its tabs;
  - a tome with owned faces and named empty slots;
  - a card's detail from a tome, with the Steam link and sets back to the tome;
  - a phone layout;
  - the "Your public profile" link and a visitor reading it;
  - a holder copying the share link, a visitor opening it, then signing in from the invitation and landing in the attic.
- The tests' own screenshots were inspected:
  - `tmp/screenshots/1_test_a_player_opens_a_tome_from_the_shelf…png` shows 3 / 25, a ×2 badge, and empty slots naming each game, its year and "Missing card".
  - `2_test_a_holder_copies_the_link…png` shows the shared card with "From the collection of Gabe the Brave", the ownership notice, the visitor invitation and the owner's Started shelf with "Complete".
  - `1_test_a_player_opens_an_owned_card…png` shows every field, "You hold 2 copies" and the share field.
- `bundle exec packwerk check` reported no offenses.
- A probe test, written to the scratchpad and run on the test database, checked non-HTML profile requests (EC 1, dropped).

Not exercised:
- The development app, because the development database lacks the 4.6 migrations (`pending-approvals.md`) and was not to be touched.
- Real link previews on Discord, X and WhatsApp, which need a public HTTPS host.
- Any real catalog: no season 1 has been published from a real import (epic 2 retro, criterion 3), so every criterion is shown on seeded and fixture seasons.
- The real Steam API (never called).

## Previous-retro follow-through

The previous epic in `epics` order is `epic-packs-and-reveal` (id 3). Its file, `epic-packs-and-reveal-retrospective.md`, has nine action items. The author also asked to follow up epic 2's process items (`epic-steam-catalog-retrospective.md`, item 8), so they are listed below the epic 3 items.

**Epic 3 action items.**

| # | Item (owner) | Landed? | Evidence |
|---|---|---|---|
| 1 | Phone reveal: every card reachable after flip all, focus kept (dev loop) | **Yes** | Ticket 3.11, `9a662fd` "flip all on a phone leaves every card reachable, forward and back, with focus kept"; the navigation choice is queued in `pending-approvals.md` (Deferred to the UX redesign) |
| 2 | Boundary tests: bank-operation races across stories; reveal fallback hidden and error boundary (dev loop) | **Partly routed, not done** | The races are now epic 7 Done-when 6 (`epic-public-launch-readiness.md:36`); no new concurrency test exists (`test/packs/game/` holds only `open_pack_` and `collect_daily_bonus_concurrency_test.rb`). The reveal failure-path tests (B3) have no evidence and no route: no test references `RevealErrorBoundary`, and `packs_controller_test.rb:76` still only asserts that the fallback exists |
| 3 | Commit the AD-7 amendment (author) | **Yes** | `architecture-gameble.md:94` (inline `Game::TopUpBank`), committed in `aa79a41` / `4f1601a` |
| 4 | Hand the countdown and attic items to the UX redesign (author) | **Yes, as a record** | `pending-approvals.md`, "Deferred to the UX redesign"; `deferred-work.md` epic-3 entry: "B7–B8 … go to the UX redesign" |
| 5 | Reconcile documents with the 2026-10-03 decisions (author) | **Yes** | Epic 3 R4 names `Game::TopUpBank` "as amended 2026-10-03" (`epic-packs-and-reveal.md:30`) and Notes record the odds (line 59); AD-16 lists the back-office card preview (`architecture-gameble.md:164`); "booster odds" gone from the architecture's Deferred section; `pending-approvals.md` "Settled on 2026-10-03" |
| 6 | Bank healing robust before the first deploy (author, dev loop) | **Routed** | Epic 7 Done-when 6 (`epic-public-launch-readiness.md:36`); not built yet |
| 7 | Build the Docker image in CI or pre-deploy (dev loop) | **Routed, not done** | Epic 7 Done-when 7 (line 37); `.github/workflows/ci.yml` still has no image build |
| 8 | Process changes: full lenses for high-risk stories and a cross-story pass before the sweep; `built_revision`; `hitl` for real-device or real-service checks; reconcile documents when settling an approval (author, orchestrator) | **Mostly not landed** | No high-risk story in epic 4 (n/a); no cross-story pass before 4.6 (P1); no plan has `built_revision` (P2); 4.5 `hitl = false` (P6); reconciliation done for epic 3's decisions but missed 2.10 → epic 4 R3 (R-1) |
| 9 | Manual checks owed: touch slide on a real phone, a real Steam image, production p95 (author) | **Recorded only for the touch slide** | `deferred-work.md:83` records the touch slide; no evidence found for the real-Steam-image check or a production p95 |

**Epic 2 process items (item 8), where they apply to epic 4.**

| Lesson | Landed? | Evidence |
|---|---|---|
| (a) A plan's Never deferring work writes a `deferred-work.md` entry in the same commit | **Partly** | The epic 4 deferrals were recorded, but only by the sweep `91a7ea7` (P4) |
| (b) Idempotency stories need a re-run row over a different input | Not applicable | No idempotent import story in epic 4 |
| (c) Record re-sequencing that departs from `after` | **Partly** | 2.10's `after = [9, "4.3"]` is recorded (`epic-steam-catalog/tickets.toml:115`); the epic-level order conflict remains (R-2) |
| (d) Keep Implementation Notes current at commit time | **Yes** | Every plan's notes carry their review patches (for example, the path-only season number in 4.3, and the 4.6 follow-up's notes) |
| (e) Run a retrospective when an epic is built | **Yes** | `4f1601a` (epics 2 and 3) and this file |

Epic 2's items 4 and 6, addressed "to the next sweep", were done by 4.6. The queue and retry tests are in `test/config/queue_config_test.rb` and `test/jobs/steam_import_step_job_test.rb`, and F2, F5, F6 and F7 are recorded or resolved in `deferred-work.md`.

## Action items

Each item is proposed, not applied. This retrospective changed no code, ticket, plan, spec, `deferred-work.md` or `pending-approvals.md`.

1. **Keep the owner's context when opening a card from a profile** (B1). Proposed remediation. Owner: dev loop (`bmad-build`), as a small story.
   - Give `library/_tome` a `card_url:` lambda, as `_shelf` takes `set_url`.
   - The library passes `card_season_path`, and the profile passes `brother_card_season_path(token, …)`, so the card opens on the owner's profile, open to any browser.
   - Add a profile-tome test that asserts the face's href.
2. **Decide what a shared-card URL shows for a card the owner never held** (B2). Proposed remediation after an author decision. Owner: author, then the dev loop. The options are:
   - the unavailable page or a 404;
   - a neutral "Not in X's collection" line, without preview tags;
   - "No longer in …" only when a holding row exists, and accounting for other seasons of the same card.
3. **Harden `PUBLIC_URL`** (U1–U4). Proposed remediation. Owner: dev loop. The public-host switch itself stays with the author in `pending-approvals.md`.
   - Parse it at boot: an absolute `http(s)` URL with a host and no path, query or fragment. Fail at boot in production when it is missing or malformed, or else degrade only the share button.
   - Test the initializer's normalisation.
   - Pin `PUBLIC_URL` in `deploy.yml` in `test/config/queue_config_test.rb`.
   - Reset `Rails.configuration.x.public_url` in `test/system/share_card_test.rb`, as the controller tests do.
4. **Clean persona names fully** (B4). Proposed remediation. Owner: dev loop.
   - Also strip `\p{Cf}` (bidi and zero-width characters) and normalise `\p{Zs}`.
   - Treat a name with no letter, digit, symbol or punctuation as blank, so the "Brother <code>" fallback applies.
   - Add sign-in tests with U+200B, U+202E and U+3000.
5. **Reconcile the epic and the epic order** (R-1, R-2). Proposed spec reconciliation. Owner: author, or the orchestrator through `bmad-ticket` with the author's go-ahead.
   - In R3, replace "publisher and copyright" with "publisher and the ownership notice", as the spec's CAP-7 says.
   - Resolve `tickets.py`'s `order_conflict`: declare that epic 2's 2.10 follows epic 4's 4.3 at epic level, or record that this one ticket crosses the order.
6. **Hand the presentation findings to the bmad-ux redesign.** Proposed input. Owner: author (bmad-ux), then the dev loop. The redesign should decide:
   - how a set opened from a card detail shows its place on the shelf (EC 9);
   - what the profile's counts cover when the owner holds only older seasons (EC 7);
   - the deferred "set complete" styling, the status band's rarity counts and links from the reveal to a card's detail;
   - what an older browser is offered after a shared link (B3, pending approval).

   The queries, routes and sharing stay as built.
7. **Record the deferred findings in `deferred-work.md`.** Proposed entries for whoever next edits it. Owner: dev loop, next sweep.
   - O1's warn-only Steam key failure, added to the existing persona entry.
   - O2: the name write inside the sign-in transaction.
   - O4: throttling or caching public profile pages, before launch (epic 7).
   - O5: `og_locale`, the own-page preview, and `SetLabel`'s nil publisher.
   - D2: the copied test helpers.
   - Epic 3's B3: the reveal failure-path tests, which nothing tracks today.
8. **Process changes for the next epics** (P1–P6). Proposed. Owner: author (bmad configuration) and orchestrator. This carries forward epic 3's item 8, which did not land.
   - Run one cross-story lens pass (adversarial, edge-case, verification-gap) over the whole epic diff before its refactor sweep starts, and give its findings to the sweep.
   - Record each story's own commit in its plan (a `built_revision`).
   - Set `hitl = true` when a Done-when needs a real external service or device (4.5's previews).
   - Write `deferred-work.md` entries in the story's own commit.
   - When a story in another epic changes built behavior, reconcile that epic's requirement text in the same change.
   - When a pending-approval entry is removed, add its "Settled" line.
9. **Checks still owed.** Owner: author.
   - Real previews on Discord, X and WhatsApp once a public HTTPS host and the Cloudflare rule exist (`pending-approvals.md`).
   - Confirm whether the development database has `20261003030000_add_persona_name_to_accounts_players` (P5).
   - Once season 1 is published from the real import, open the library and a profile on it. All of epic 4's criteria were shown on seeded seasons only.

## Acceptance verdict

**Machine verdict: accepted-with-open-items**, against declared criteria (the epic file's Done when). Every ticket is finished (`built`), and `pending_tickets` is empty.

| # | Done when | Evidence | Met |
|---|---|---|---|
| 1 | The library shows publisher sets, tomes and "best rated of the year" sets, each with owned / total and empty slots naming the missing game | `LibraryController`, `library/_shelf`, `_tome`; `library_controller_test.rb`, `library_set_test.rb`; system tests and screenshot (this run) | Yes, on seeded seasons; no real season 1 exists yet |
| 2 | A card's detail shows its title, description, year, rarity, season, sets, publisher and a link to its Steam page | `Catalog::CardDetail`, `cards/_detail`; `cards_controller_test.rb`, `card_detail_test.rb` (system), French and English | Yes; the copyright row became the ownership notice by the author's decision (R-1) |
| 3 | A shared link opens the sharer's public profile with the card shown; its preview on Discord, X and WhatsApp carries the title and rarity and no game image | `PublicProfilesController#card`, `_share_tags`; `public_profiles_card_test.rb` (Discordbot, Twitterbot, WhatsApp, old Firefox, iOS 16 Safari user agents; no `og:image`, `twitter:image` or `image_src`); `share_card_test.rb` (system) | Yes in simulation; real previews unchecked (U5, action item 9); open items U1–U4 and B2 |
| 4 | Signed out, a visitor can open the library with empty sets, a public profile and a card's detail | Visitor rows in each controller test; `PagePolicy#show?`; system tests | Yes; the card detail stays modern-browser only (B1, B3) |
| 5 | No URL, page or response exposes a database id | "no database id" tests in `cards_controller_test.rb:255`, `public_profiles_controller_test.rb:320`, `public_profiles_card_test.rb:264` and the library tests; routes by slug, kind and key, and token | Yes |

No finding blocks acceptance. The open items are:
- B1, B2 and B4, at the seams between stories;
- the `PUBLIC_URL` hardening (U1–U4);
- the reconciliations R-1 and R-2;
- the real-world checks (real previews and a real season).

All of them are routed above.

No human decision was taken on this verdict in this headless run, and the author may override it. Closing the epic (marking the tickets done) belongs to `bmad-ticket`, with the author's confirmation. This run changed no status.

## Open questions

- **B2.** What should a shared-card link show when the owner never held the card: the unavailable page, a neutral line, or the current "No longer in …"?
- **B3.** What should an older browser that follows a shared link be offered: hide the invitation, let it sign in and see the attic, or keep it as is? This is pending in `pending-approvals.md`.
- **P5.** Was the development database migrated for `persona_name` before its pending-approval entry was removed in `530566b`?
- **U1.** Should a missing `PUBLIC_URL` stop the app at boot in production, or only hide the share button?
- **Ticket closure.** Does the author want epic 4's tickets marked done now, with action items 1–4 as new work, or held at `built` until they land?
- **Real data.** Epic 4 depends on a published season (epic 2, `rejected` until season 1 is published). Should the library and profile be re-checked on season 1 before the epic is called done?

## Assumptions

Made without the user in this headless run:

- **Epic resolution:**
  - The reference `epic-collection-and-sharing` resolved by slug to `_bmad-output/initiative-gameble/epic-collection-and-sharing/` (epic id 4 in `tickets.py status`).
  - `pending_tickets` was empty, because all six tickets are `built`, so no unfinished ticket forced the verdict.
- **The verdict:** the machine verdict **accepted-with-open-items** was rendered with no human decision.
- **Ranges:**
  - They came from the plans' baselines.
  - The last range runs to HEAD (`bee4272`), which is still epic 4's last commit.
  - Commits of stories 2.10, 2.11 and 3.11 inside the 4.4 and 4.5 ranges were attributed by subject and left out of epic 4's change volume.
- **The review diff:**
  - It is `git diff 9fcb676..HEAD` restricted to the files epic 4's commits touched, excluding `Gemfile.lock`, `db/schema.rb` and `README.md`.
  - It therefore also carries the small 2.10, 2.11 and 3.11 changes in shared files.
  - The three lenses ran as parallel subagents. Their findings were treated as unverified until re-checked against the source.
- **Aggregate views** were computed inline:
  - change volume from `git_evidence.py` and `git show --stat`;
  - `wc -l` at HEAD;
  - `packwerk check`.

  No dependency-graph tool beyond packwerk was run.
- **The owner's statements** relayed for this run were taken as decisions already recorded:
  - persona-name titles;
  - no preview image;
  - the bmad-ux redesign replacing the attic, lectern and shelf presentation while queries, routes and sharing stay.

  The routing of presentation findings to the redesign (action item 6) follows from the last of these.
- **Behavior check:**
  - It ran on the test database only, through `bin/rails test`, five system test files, and one throwaway probe test kept in the session scratchpad (not in the repository).
  - The development database and the real Steam API were not touched.
- **Session logs:** only the author's own messages in the two orchestrator logs were read. The subagents' transcripts were not.
- **Action items:** every action item is a proposal. None was applied, and this document is the only file written in the repository.
- **Team discussion (Phase 3):** did not run (headless).
