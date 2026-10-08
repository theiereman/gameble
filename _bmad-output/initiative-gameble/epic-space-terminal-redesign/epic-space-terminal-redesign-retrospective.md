---
epic: epic-space-terminal-redesign
date: 2026-10-08
verdict: rejected
criteria: declared
headless: false
---

# Retrospective: Space terminal: shell, card and booster (epic 8)

## Epic summary

**Epic file:** `epic-space-terminal-redesign.md`. It has a declared Done when with 5 criteria, so the verdict is declared, not profiled.

**Tickets** (from `tickets.py status`, build order; 14 total, counts `review` 11, `done` 1, `dropped` 1, `planned` 1):

| Ref | Ticket | status / state |
|---|---|---|
| 8.1 | Shell and tokens | built / review |
| 8.2 | Hub and sign-in panel | built / review |
| 8.3 | Tier names and season numbers | built / review |
| 8.4 | Architecture conformance | built / review |
| 8.5 | Pixel filter v2 | built / review |
| 8.6 | Single card face | built / review |
| 8.7 | Drop dust_tier | built / review |
| 8.8 | Remaining pixel-art assets | done / done |
| 8.9 | Performance on the reference phone (spike) | dropped / dropped |
| 8.10 | Opening exchange | built / review |
| 8.11 | Booster island, desktop | built / review |
| 8.12 | Booster island, phone | built / review |
| 8.14 | Typography: VT323 / Space Mono | built / review |
| 8.13 | Refactor sweep | (no plan) / planned |

**Tickets still at `built` (finished by the build, not called done):** 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.10, 8.11, 8.12, 8.14.

**Unfinished tickets (`pending_tickets`):** 8.13 (Refactor sweep). It has no plan file, and its `after` list covers every other ticket. The user chose to retro the epic with 8.13 outstanding (they picked it from the list that marked it partly finished). The machine verdict is therefore **rejected** (see Acceptance verdict). The user has given no override.

**Going-in concerns:** none were given.

### Evidence inventory

Available:
- Epic file, `tickets.toml`, 12 plans (8.9's is a 5-line dropped stub), the initiative's `deferred-work.md` and `pending-approvals.md`. No story files exist, since no ticket was refined into one.
- Plan sections read: Review Triage Log verdicts and `[defer]` rows. The 11 built plans record 12 review passes: **0 high-severity findings**. Medium counts: 8.1 six (two passes), 8.2 five (two passes), 8.4 five, 8.11 four, 8.5 one, 8.6 one. Many findings were patched in place, and the rest are routed below.
- `git_evidence.py` ran on the two ranges below.

Missing or narrowed (recorded so "checked and clean" is distinguishable from "never checked"):
- **Plan baselines are unreachable for 11 of the 12 plans that record one.** Every recorded `baseline_revision` except 8.14's (`69577d6`) is absent from the repository's history, even after `git fetch --unshallow` (235 commits): `3ba5bcf` (8.1, 8.4, 8.5), `783c82a` (8.2, 8.3), `e319f0a` (8.6), `102a5f7` (8.7, 8.10), `0574a26` (8.11), `264d96c` (8.12) and `a26b1d7` (8.8). They were likely worktree commits that never reached `develop`. Per-plan ranges cannot be established for those tickets.
- **Fallback ranges used** (inferred, not recorded):
  - **Range A** `74e43f4~1..b48a939` — 35 commits, from the commit that placed the epics in the ticket tree to the commit approving 8.8. It covers stories 8.1 to 8.8 and 8.10 to 8.12 by commit subject (`feat(8.N)`).
  - **Range B** `69577d6~1..a1ca4cc` — 3 commits, story 8.14 (recorded baseline).
- **Range A is not clean.** It also contains other epics' work: 10.1, 10.2 (epic 10), 2.12 and the epic-2 retrospective commits, the Kamal destinations commit, and several docs commits. The `files` churn figures include them. Attribution to this epic rests on commit subjects and file paths, not on the range alone.
- Merges: none measured (`merge_count` 0). The built plans' worktree merges are absent from this history.
- Commit `6c6ee61` (card art via the `pixelcrush` npm package) landed **after** 8.14, outside both ranges, and changes 8.5's output. It is read directly below.
- **Session logs:** none for this epic's tickets (only the current session exists). Process-lesson analysis from sessions is skipped.
- **`bmad-review` was not run** over the epic diff. The diff-scope review lens therefore reuses each ticket's own recorded review pass (blind, edge-case, verification-gap and intent lenses) and was not re-run across ticket boundaries. This is a narrowing, not a clean result.
- **Behavior check:** not performed (see Behavior verification).

## Findings

Each finding has a source and a disposition: **fix now**, **defer** or **accept**.

### Spec-to-implementation reconciliation (checked against the tree at `a05d0eb`)

| # | Done-when criterion / requirement | Evidence | Result |
|---|---|---|---|
| S1 | (1) Jost, parchment, Pixelify Sans, Silkscreen gone | A case-insensitive grep of `app config lib test packages script` for `jost\|parchment\|pixelify\|silkscreen` returns nothing; `app/frontend/styles/` lists no `attic.css`; `git diff` over Range A shows `attic.css` −572 | Met |
| S2 | (2) One card face; `Card.tsx` and `dust_tier` gone | `app/frontend/components/` has no `Card.tsx`; `grep dust_tier app db lib config` is empty. The only remaining hits are the migration test `test/packs/catalog/schema_test.rb:31-56`, which asserts the column is absent after the contract step | Met |
| S3 | (4) Tier codes renamed | A grep for `steel\|bronze\|silver\|gold` in `app config/locales lib` finds only visual `gold` flash/ray tones in `Booster.tsx` and `booster.css`, not tier codes | Met |
| S4 | (4) CSP report-only, worker allowed | `config/initializers/content_security_policy.rb:42-43` has `worker_src :self, :blob` and `connect_src` with the Steam image host | Met; resolves the 8.5-time risk logged at `deferred-work.md:196` |
| S5 | (3) Opening protocol; a lost response replays | Plan 8.10: idempotency key replayed before the throttle; `opening.ts:56-79` treats any 5xx, network failure or non-JSON answer as unknown (`FAILED`), so a stale-CSRF 422 HTML page degrades safely | Met by plan evidence; the browser path was not exercised here |
| S6 | (5) p95 ≤ 200 ms | Plan 8.10 `Benchmark`: worst JSON POST p95 **16.9 ms** over 3 runs (dev machine, 22 queries/POST); `game:benchmark_open_pack` is the gate | Met per plan record; not re-run in this retro |
| S7 | (5) Frame budget on a real low-end phone "measured later" | Spike 8.9 dropped 2026-10-06 (epic Notes); the open entry is at `deferred-work.md:254` | Accepted deviation, recorded by the author. Still unmeasured |
| S8 | R4 / AD-17 / ticket 8.5: "Rewrites `packages/pixel-art-filter`" | `6c6ee61` removed `packages/pixel-art-filter` (−973 lines) and moved the worker, renderer and fallbacks to `app/frontend/lib/card_art/` using the `pixelcrush@0.2.0` npm package (`package.json:11`). `aa35bbd` had made the in-repo package publishable only a day earlier | **Spec drift.** See F1 |
| S9 | 8.13 Refactor sweep: "every deferred finding is fixed, recorded or dropped" | No plan, no commits. The deferred list is below | Not delivered |

### F1 — The filter moved out of the epic's own contract after 8.5 was `built` (spec reconciliation)

Source: `6c6ee61`, `app/frontend/lib/card_art/index.ts:2` ("with pixelcrush (AD-17)"), `story-pixel-filter-v2-plan.md` (status `built`), epic R4 and AD-17.

The epic's ticket 8.5 and its verify line name `packages/pixel-art-filter`. The shipped code quantises through an external dependency, and the in-repo package (including its tests) is gone. The code still honours AD-17's behaviors (the worker, the cache, the fallbacks and the placeholder tests all live in `card_art/`). But nothing in the epic file or the plan records the decision.

Disposition: **fix now** (documentation only). Reconcile 8.5's plan and the epic wording with `pixelcrush`. Also confirm that the architecture's AD-17 and its "packages" references name where the filter now lives.

### F2 — Size growth concentrated in the booster and the shell (god-class / size)

Source: Range A `git_evidence.py` (`added` / `deleted` / `net`), then current sizes with `wc -l`.

| File | Net churn in Range A | Current lines |
|---|---|---|
| `app/frontend/components/Booster.tsx` | +1616 | 1616 |
| `app/frontend/styles/booster.css` | +1564 | 1575 |
| `script/pixel_art/export.mjs` | +1262 | 1262 |
| `app/frontend/styles/shell.css` | +1161 | 1209 |
| `test/system/booster_test.rb` | +934 | 969 |
| `app/frontend/lib/booster.ts` | +407 | 407 |

`Booster.tsx` is a single 1,616-line component file next to eight sibling files (`BoosterCanister`, `BoosterCard`, `BoosterPanel`, `BoosterPlate`, `BoosterStrip`, `BoosterTray`, `BoosterZoom`, `BoosterErrorBoundary`), so 8.12 extracted pieces without shrinking the orchestrator. It is the clearest candidate for the sweep. The churn figures count only non-merge commits and Range A includes other epics, but these files are this epic's by name.

Disposition: **defer** to ticket 8.13 (the sweep exists for this). I did not inspect function-level structure, so "god-class" is a candidate, not a verdict.

### F3 — Open review deferrals the sweep must close (verification gaps)

Source: `[defer]` rows in the plans, cross-checked against `deferred-work.md`. Each is still open unless marked.

| Item | Source | Status |
|---|---|---|
| The `reading` role opens a second pool: up to 2 × `RAILS_MAX_THREADS` primary connections per process, never sized | 8.4 plan:149,159,161,167; `deferred-work.md:187` | Open. Medium operational risk at launch |
| No test builds the CSP `report-uri` (Sentry) or the dev Vite policy; both are decided at boot | 8.4 plan:154,158; `deferred-work.md:190` | Open; the plan says to check the deployed header once |
| `vite.config.ts` has no `assetsInlineLimit`; font files are now 15.8 to 17.9 KB (`app/frontend/fonts/*.woff2`), above Vite's 4 KB default, so the plan's "maybe-false" risk does not apply today | 8.4 plan:162; `ls -l app/frontend/fonts` | Effectively settled: **drop** |
| Phone long-press on a tilting card may open the context menu or selection | 8.6 plan:144; `deferred-work.md:225` | Open, needs a real device |
| Non-passive `touchmove` per card may delay scrolling on long pages | 8.6 plan:145; `deferred-work.md:228` | Open, needs a low-end device trace |
| Visual baselines captured with Manjaro Chromium may fail on CI's Chrome | 8.6 plan:147; `deferred-work.md:231` | Unverified here. No `CHROME_BIN` or visual-test mention was found in `.github/workflows/ci.yml`, and commit `e419296` later stabilised other system tests. Confirm against a CI run |
| `BoosterErrorBoundary` untested | 8.11 plan:173 | **Resolved**: `booster_test.rb` blocks `Booster-*.js` through CDP (`deferred-work.md:267`) |
| CSRF failure answers Rails' 422 HTML | 8.10 plan:127,138 | **Resolved** by 8.11 sending `X-CSRF-Token`, with the HTML 422 read as an unknown outcome (`opening.ts:56-79`; `deferred-work.md:240`) |
| Public card page keeps the app chrome; a game-styled sign-in button remains on it | 8.1 plan:144,145 | Owned by `epic-space-terminal-screens`; defer there |

Disposition: **defer** the open rows to 8.13 (or record them there with a reason), and carry the device-dependent ones as the author's owed checks.

### F4 — Plans left at `built` and the board at `review` with no recorded built commit (process)

Source: `tickets.py status` counts (`review` 11); plan frontmatter (only `baseline_revision` exists); commit subjects such as `feat(8.10)` / `feat(8.7)` carrying the story id.

Eleven baselines resolve to no commit in `develop`'s history (Evidence inventory). No plan records the commit that built it, so an auditor can neither reconstruct a ticket's diff nor tell whether it is merged. This is the same gap that the previous retro proposed to close (item 8 below).

Disposition: **fix now** for the process (record the built commit in each plan); **accept** for the missing ranges in this retro (nothing to repair retroactively).

### F5 — Intent held, two "transitional" hub shortcuts to confirm (spec-to-implementation, low)

Source: `deferred-work.md:212-216` (8.2 Design Notes). The hub showcase lacked the planet, rays and idle float, and the phone hub lacked the goal panel and LIVE ticker "until" 8.8 / epic 6. 8.8 is done and epic 6's goal panel (`_goal.html.erb`) now exists in `app/views/pages/`, so this transitional note is probably stale rather than a defect.

Disposition: **accept**; ask for a fresh `deferred-work.md` pass at the sweep.

### Diff-scope review lenses

The lenses were not re-run. All findings above come from ticket-time passes and the tree reads. In those recorded passes, **no ticket produced a high-severity finding that remained open**, and the one confirmed medium-risk class that crosses tickets is F3's reading-pool sizing.

### Duplication map and architecture delta

**Not derived.** No dependency tool was run before/after, and no near-duplicate scan was done. Record: never checked. The `packwerk` and `typecheck` gates named in 8.13's verify were also not run here.

## Behavior verification

Runtime behavior was **not exercised**. I did not start the app, the system tests or the benchmark in this retro run. What stands in for it is the recorded evidence in the plans (e.g. the 16.9 ms p95 benchmark, system tests such as `booster_test.rb`, `shell_test.rb` and `card_face_visual_test.rb` named in the commits), plus the tree reads above. A person who needs the user-visible claim ("from the hub to a revealed booster, on desktop and phone") confirmed should run `bin/rails test:system` and open a booster on both layouts.

## Previous-retro follow-through

Previous epic in the `epics` order: `epic-collection-and-sharing` (epic 4). Its retrospective exists (`epic-collection-and-sharing/epic-collection-and-sharing-retrospective.md`, verdict `accepted-with-open-items`) and has 9 action items. Checked against the tree:

1. **Keep the owner's context when opening a card from a profile** (B1; dev loop) — no evidence found. `app/views/library/_tome.html.erb` no longer exists after the redesign, so the target moved.
2. **Decide what a shared-card URL shows for a card the owner never held** (B2; author, then dev loop) — no evidence found.
3. **Harden `PUBLIC_URL`** (U1 to U4; dev loop) — **landed**: `config/initializers/public_url.rb` parses the value and fails with a message naming `PUBLIC_URL` when it is missing in production. The `deploy.yml` pin and test were not checked.
4. **Clean persona names fully** (B4; dev loop) — no evidence found. A search for `\p{Cf}` in `app` and `lib` Ruby files found nothing.
5. **Reconcile the epic and the epic order** (R-1, R-2; author or orchestrator) — no evidence found; not checked.
6. **Hand the presentation findings to the bmad-ux redesign** (author) — the redesign happened (epic 8 and `ux-gameble/DESIGN.md`); whether each listed question was settled was not checked.
7. **Record the deferred findings in `deferred-work.md`** (dev loop) — not checked item by item.
8. **Process changes (P1 to P6)** — cross-story lens pass before the sweep: not found. Record each story's own commit (`built_revision`): **not landed**. No plan here carries it (F4). `deferred-work.md` entries in the story's own commit: partly (the 8.x entries cite their stories).
9. **Checks still owed** (author) — Discord / X / WhatsApp previews depend on a public host (`pending-approvals.md`): not checked.

"No evidence found" means I looked and could not point at a source, not that the item is confirmed undone.

## Action items

All items are proposed. The retrospective applied none of them and changed no code, ticket, plan, spec or `deferred-work.md`.

1. **Run the refactor sweep (ticket 8.13) from this list.** Proposed remediation. Owner: dev loop (`bmad-build`).
   - Shrink or split `Booster.tsx` (1,616 lines) and review `booster.css` (1,575) and `shell.css` (1,209) for splitting.
   - Close or record every open row of F3.
   - Run the full suite, lint, packwerk and typecheck, which 8.13's verify requires and this retro did not.
2. **Reconcile 8.5 / R4 / AD-17 with the `pixelcrush` package.** Proposed spec reconciliation. Owner: author (applies it to the contract); evidence: F1, commit `6c6ee61`.
3. **Size the reading pool and test the CSP `report-uri`.** Proposed remediation. Owner: dev loop, before launch (epic 7). Check the deployed CSP header once.
4. **Measure on a real low-end phone** the booster frame budget, the touch-scroll cost of the non-passive `touchmove`, and the long-press behavior. Owner: author, when a device exists (S7, F3).
5. **Confirm the visual baselines on CI** (one run on a clean runner). Owner: dev loop.
6. **Decide the epic's closing state.** Owner: author, via `bmad-ticket`.
   - Either run 8.13 and then mark the built tickets `done`, or
   - override this verdict and close the epic with 8.13 moved to a later epic.
7. **Process:** add a recorded built commit to every plan (`built_revision`), and have ticket builds run in the shared history or note their branch. Owner: author (BMad configuration) and orchestrator. This carries forward epic 4's item 8.
8. **Process:** when a story is replaced by a dependency or another design after it is `built` (as `6c6ee61` did to 8.5), record the decision in the epic Notes in the same change.

Action-item count: **8**.

## Acceptance verdict

**Rejected** (machine verdict, criteria declared, no human override yet).

Evidence:
- **Unfinished delivery.** Ticket **8.13 (Refactor sweep)** is `planned`, with no plan and no commits. A non-empty `pending_tickets` forces **rejected** by rule, regardless of the other criteria. Eleven further tickets are still `built / review`, not `done`.
- **Done-when against the tree:** criteria 1 to 4 are demonstrably met (S1 to S5). Criterion 5's p95 half is met per the plan's benchmark (S6, 16.9 ms against 200 ms). The frame-budget half is unmeasured by the author's recorded decision (S7).
- **Blocking findings:** none open. No high-severity finding remained in any recorded review. The open items are medium operational or verification gaps (F3), a documentation drift (F1) and a size concentration (F2).

If the author accepts the open items and closes 8.13 (or moves it), the content supports **accepted-with-open-items**: the open items are F2, F3 and the unmeasured device budget. That is a judgment for the author. It is not recorded as the verdict.

## Open questions

1. Where did the seven missing baseline commits go (worktree branches that were deleted or squashed)? Any answer would let a re-run recover per-ticket diffs.
2. Was swapping `packages/pixel-art-filter` for `pixelcrush` meant to count as 8.5's final shape? If not, F1 becomes a defect rather than a documentation fix.
3. Does CI run the card-face visual baselines on a Chrome other than the author's Chromium?
4. Is 8.13 to be run before epic-space-terminal-screens and epic-card-backs build on this shell, or after?

## Assumptions

Interactive run, so the choices were confirmed with the user or recorded above:
- The epic was chosen by the user by name after the unfinished-epic caveat was shown. No going-in concerns were given.
- The two inferred ranges and the narrowed review and behavior scope are listed under Evidence inventory.
