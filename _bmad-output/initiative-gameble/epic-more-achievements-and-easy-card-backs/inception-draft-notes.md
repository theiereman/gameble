# Epic 30 — inception notes (draft, not recorded)

Draft breakdown: `epic-30-draft.toml` beside this file. Nothing was written to the repo.

## What I read and what it changes

- Epic envelope, spec CAP-17 and CAP-20 (2026-10-30), `spec-gameble/achievements.md`, `brotherhood-tone.md`, AD-7, AD-10, AD-23, AD-25 and AD-37, issues #66 and #68, the tickets and plans of epic 9 (card backs) and epic 26 (personalization), and the code (`Game::Achievements`, `AchievementProgress`, `GrantAchievementsJob`, `BackfillAchievementsJob`, the achievement and card back handlers, `CardBacks`, `CardBackShelf`, the Personalization views, `bin/docker-entrypoint`, the schema).
- **Source conflict: Notes of the epic — "Open question: which of #66's achievements ship, and which unlock a back; the author chooses at inception" vs `spec-gameble/achievements.md` and the spec's log (`.memlog.md` line 372, 2026-10-30): "Approved by the author: achievements.md as written (the thirteen new achievements, the four back-unlocking ones, the five proposed rename titles)".** The spec records the choice as made. The draft builds on the approved list and keeps a confirmation in the hitl entry 2 (question Q1). The epic's Notes line should be updated once the author confirms.
- AD-37 already settles most of the design: one catalogue constant, one metric query (`AchievementProgress`) shared by the live grant and the backfill, `game_packs.reveal_mode` set by `Game::RecordReveal` through `POST /:locale/packs/:token/reveal` (AD-23, amended 2026-10-30), achievement backs as entries of AD-25's constant, renames as locale changes. **AD-37 is not marked `[ADOPTED]`** (nor AD-35, AD-36 and AD-38), see Q7.
- Built today: the ten achievements, live grant after events, an idempotent backfill rake (`game:backfill_achievements`, run once by hand at launch), three achievement backs (Centurion, Étoile d'or, Aurore), the back picker (one click per tile already, generic "Unlock the matching achievement." line for achievement backs, no "how it was earned" line).
- Not built: `reveal_mode`, the reveal POST, `Game::PackRevealed`, any "data step before traffic" in the deploy (the entrypoint runs only `db:prepare catalog:create_roadmap_milestones`), achievement flavor texts and their display, the four new backs' art.
- Everything the "how was it earned" line needs already exists: set backs' seasons (`CardBackSeasons`), the goal back's week (`game_goal_rewards.week_start`), the achievement behind a back (the constant) with `unlocked_at`, event backs' `unlocked_at`. E5 needs no schema change.

## Candidates from #66 and #68

Odds use the regular pack's published odds (Commune 76 %, Peu commune 19 %, Rare 4.3 %, Épique 0.65 %, Légendaire 0.05 %; 5 % of Rare or better per card). Retroactive = granted at release from what is recorded today. Cost: S under half a session, M about one session, L more than one or touching schema.

| # | Candidate | Condition (achievements.md) | Data today | Retroactive | Type | Cost | Rough odds / difficulty |
|---|---|---|---|---|---|---|---|
| 1 | Packaging Irregularity | Two copies of one game in one capsule (any kind) | `game_packs.card_season_ids` → `catalog_card_seasons.card_id`; draws are independent, so duplicates happen | Yes, every opened pack | in-capsule | S | Catalog-dependent: about 10 × Σ(tier share² / cards in tier); roughly 1–2 % a pack with a few hundred Communes, less as the catalog grows |
| 2 | Excellence in Mediocrity | Five Commune in one standard capsule | `card_season_ids` + rarity | Yes | in-capsule | S | 0.76⁵ ≈ 25 % a pack: nearly every player has it at release |
| 3 | Statistical Non-Compliance | Two Rare or better in one standard capsule | `card_season_ids` + rarity | Yes | in-capsule | S (tracer) | ≈ 2.3 % a pack, about 1 in 44 |
| 4 | Historical Asset Management | A game released before 2000 and one from 2025 in one capsule | `catalog_cards.release_date` (not null) | Yes | in-capsule + metadata | S | Catalog-dependent; the dev catalog has 49 of 558 games before 2000 and 2 from 2025: rare unless production differs |
| 5 | Luck Is a Marketing Concept | 10 standard capsules in a row with no Rare or better | `card_season_ids` + `opened_at` order | Yes | streak | M (gaps-and-islands SQL) | 0.774¹⁰ ≈ 7.7 % for a given run; the first-session guarantee rules out the first ten; most players have it by about 100 capsules |
| 6 | Leave Request Denied | Daily bonus 7 UTC days in a row | `game_daily_bonus_claims.day`, one row per player and day | Yes | streak | S–M | A week of daily visits: commitment, not luck |
| 7 | Lazy Opener (#68) | N capsules in a row opened with "Tout révéler" | None: needs `game_packs.reveal_mode` + reveal POST + booster change | No: packs before the column break the run | streak (needs new data) | L (migration, endpoint, booster) + S for the metric | Easy for players who always reveal all |
| 8 | Hardworking (#68) | N capsules in a row with every card turned one by one | Same as 7 | No | streak (needs new data) | shares 7's cost | Easy for players who like the flip |
| 9 | Diversified Portfolio | Five copies of one game held at once, summed across editions | `game_holdings.quantity` | Only from the current collection (copies traded away are not seen) | collection | S | Common for active players on Communes |
| 10 | Market Concentration | 10 different games of one studio held at once (studio as studio sets count it) | `catalog_cards.developers` + `Catalog::SetNames.company` (Ruby, so a new `Catalog` query, read by `Game`) | Current collection only | collection + metadata | M | Catalog-dependent: needs studios with 10+ published games; hard |
| 11 | First Claim, All Rights Reserved | Be the pioneer of a card in a season | `game_first_discoveries` (one row per card-season) | Yes | community | S | Easy early in a season with few players, hard late: see Q2 |
| 12 | A Discovery of Ours | Repost a card-season the player pioneered | `game_feed_entries` kind `repost` × `game_first_discoveries` | Yes, while the repost entry exists | community | S | Easy once 11 is earned: one repost |
| 13 | A Strictly Professional Relationship | Three accepted trades with one partner | `game_trades` status `accepted`, grouped by the other party (cleanups cancel only open trades) | Yes | community | S | Needs a trading friend: moderately hard |

Out of scope (Boundaries): #66 part 4, secret achievements; any currency or capsule reward.

## Proposed first selection

Recommended: ship all thirteen, as `achievements.md` already records, and keep the four backs it names with one reservation (Q2).

- Eleven of the thirteen are cheap (S or M), read data that exists today, and are granted retroactively; they cover all four condition types the spec asks for.
- Lazy Opener and Hardworking are the only costly pair (a migration, a new POST, a booster change, no retroactive grant). They are kept because #68 asks for them and the architecture already designs the column; if the release must shrink, they are the pair to defer, together with entries 3 and 10, without touching anything else.
- Backs on the hardest ones: Market Concentration and Leave Request Denied are clearly hard (catalog depth, a week of visits). Luck Is a Marketing Concept is medium (about 100 capsules), comparable to Centurion. First Claim is the doubtful one (Q2).

## Questions for the author (with my recommended answer)

- **Q1. Is the achievement list settled?** The spec says you approved the thirteen and the four backs on 2026-10-30; the epic still calls it open. *Recommended: confirm the approved list; entry 2 records the confirmation and the epic's Notes line is replaced by a Decision line.*
- **Q2. Does First Claim, All Rights Reserved keep its back?** Being a card's pioneer is easy for anyone who opens capsules early in a season while players are few, so the back may go to most early players. *Recommended: count the share of active players with a `game_first_discoveries` row on production before entry 2; above about a third, move the back to A Strictly Professional Relationship. Entry 2 carries this as its unknown.*
- **Q3. N for Lazy Opener and Hardworking?** *Recommended: 10 for both, the length of Luck's streak and about a day of play.*
- **Q4. Where does the flavor text show?** #66 and the spec say in the achievement's detail or when it is earned, never crowding the list. *Recommended: in the unlock toast, and on an earned tile as a disclosure the player opens; a locked tile shows only its condition. Entry 2 designs it.*
- **Q5. Does the Personalization rework need a UX design step?** Yes: you called the page functional but ugly, and the "how it was earned" line (set and seasons, goal week, achievement, event) has no design in DESIGN.md or EXPERIENCE.md; the four new backs and the new glyphs also need art direction. *Can it share epic 28's UX entry (28.2)?* *Recommended: run both in one `bmad-ux` session for efficiency, but keep this epic's own hitl entry (30.2) with no `after` on 28.2: 28.2 designs other screens (custom sets, goals), and its approval should not gate this epic, nor this epic's gate 28.*
- **Q6. How does a release grant history before it takes traffic?** AD-37 requires it; the deploy has no data step today. *Recommended: call the idempotent `game:backfill_achievements` from the entrypoint after `db:prepare` (it computes only unearned metrics), measured on a staging candidate (entry 4); fall back to a once-per-release step (RELEASING.md, or a recorded data step) if boot time grows, since it runs inside Kamal's health-check window and grows with the player count.*
- **Q7. Adopt AD-37?** It is the rule every entry builds on and is not marked `[ADOPTED]`. *Recommended: adopt it as written before entry 1 starts.*
- **Q8. Excellence in Mediocrity at release?** About one standard capsule in four qualifies, so nearly every player receives it silently at release. *Recommended: keep it; the joke is the point.*
- **Q9. Thirteen entries, above the typical eight to twelve.** The achievements lane (1, 5, 6, 7, 8, 9, 10, 11) is one lane with one owner, so the count is acceptable. *Recommended: keep one epic; if you prefer a split, the Personalization rework (12) and its design part of 2 can become their own epic without moving anything else.*
- **Q10. Production delivery in Done when.** The tree check expects each epic's Done when to include production delivery; this one does not say it. *Recommended: add "Release 1.1.0 is on production, its achievement backfill run" as a fifth check.*

## Breakdown summary

- **Tracer bullet:** entry 1, Statistical Non-Compliance through every layer: the catalogue, the metric query skipping earned metrics (and `GrantAchievement` re-reading only its own metric under the bank lock), the live grant after an opening, the retroactive backfill without a toast, the locale keys and the achievements screen.
- **Least sure, right after:** entry 3 (the reveal mode: schema, new POST, booster) and entry 4 (the deploy data step), both high risk and both off the achievements lane's path.
- **Parallel lanes from the start:** 1 (achievements lane), 2 (design, hitl), 3 (reveal mode on packs and the booster). After 1: 4 (deploy). After 2: 12 (Personalization page). The achievements lane runs 1 → 5 (also after 2) → 6 → 7 → 8 → 9, then 10 (also after 3) and 11 (also after 2), all through `Game::Achievements`, `AchievementProgress`, the achievements handler, the helper's glyphs and the achievements locale keys, so it stays serial. Longest chain: 1, 5, 6, 7, 8, 9, 10, 13 (eight entries).
- **Shared file tolerated across lanes:** `config/locales/en.yml` and `fr.yml`, each lane in its own keys: achievements.* (lane 1), card_backs.names.* (11), card_backs.conditions.* and personalizations.show.card_back.* with `card_backs_helper.rb` (12).
- **Handoffs written in both entries:** 3 publishes `Game::PackRevealed` with the player id, 10 follows it; 2 sets N, the copy, the glyphs, the back art and names that 5–12 use; 11 adds the four backs and leaves their condition line to 12, which names any achievement back's achievement by its locale key.
- **High risk and their outside check:**
  - Entry 3 (migration on `game_packs`, a new write path from the booster): the author opens capsules both ways, a regular and a special one, on a staging candidate and confirms the stored modes; the booster system tests across every reveal path run before merge.
  - Entry 4 (a data step on production data at every deploy): the author runs a staging candidate deploy on a copy of real history and records grants, the absence of toasts and the added boot time before 1.1.0 goes to production.
- **Hitl:** entry 2 (the author with `bmad-ux`) and entry 4 (the author on staging).
- **Deferred:** secret achievements (#66 part 4), per the Boundaries.

## Coverage

| Id | Entries | What each delivers |
|---|---|---|
| E1 | 1, 3, 6, 7, 8, 9, 10 (2 confirms the list) | 1: Statistical Non-Compliance; 6: the other three one-capsule; 7: two streaks; 8: two collection; 9: three community; 3 + 10: the reveal streaks. Thirteen in all |
| E2 | 2, 5 (1 and 6–10 ship their own keys) | 2: the approved copy; 5: the ten renamed, the tracer's copy and glyph swapped, the landing tile, the flavor text reachable from the screen |
| E3 | 1, 4, 6, 7, 8, 9 | Each metric is read by the backfill; 4 runs it before traffic. 10 has no history by design (AD-37) |
| E4 | 2, 11 | 2: art, names and the confirmed four; 11: drawn, named, wired, granted live and retroactively |
| E5 | 2, 12 | 2: the design; 12: one-step pick, earned and locked lines |

| Done when | Delivered by |
|---|---|
| 1. New achievements granted in play, once, in English and French, with title, condition and flavor text on the achievements screen | 1, 6–10 (grant, once by the unique row), 2 + 5 (copy, flavor reachable from the screen) |
| 2. Ten existing renamed, none lost | 5 (keys and rows unchanged, verified before and after) |
| 3. Retroactive where history records it | 1, 6, 7, 8, 9 (metrics read by the backfill), 4 (run before traffic at release) |
| 4. Personalization: pick in one step, read how each back was earned or can be | 12 (with 11's four backs) |

## Set check

- `tickets.py status` on a scratch copy of the initiative with this draft as the epic's `tickets.toml`: no cycle, no `unpinned_after`, `undeclared_after` or `order_conflict`; 13 planned; longest chain eight entries.
- Independent check (a fresh agent with `checks.set`, `checks.dependencies` and `checks.ticket`) confirmed coverage of E1–E5 and Done when 1–4, the tracer, no cycle, real prerequisites, hitl and risk placement, one migration owner, every referenced file. Applied from it:
  - Entry 1 also makes `GrantAchievement` re-read only its own metric (AD-37), and says its French copy is a builder draft.
  - Entry 5 swaps the tracer's glyph too, updates the landing's Succès tile (en.yml ~1359, fr.yml ~1952), and makes the flavor text reachable from the achievements screen (Done when 1), not only the toast.
  - Entry 11 adds the four backs' names to both locale files and leaves `card_backs.conditions` and the helper to entry 12, so 11 and 12 can run side by side; entry 12's test reads achievement names through I18n so entry 5 cannot break it.
  - The lane was reordered so the reveal-streak entry (now 10) comes last and the collection, community and back entries no longer wait on the migration of entry 3.
  - Entry 3 sends the reveal for every pack kind and carries an unknown on the legal page's stored-data line; entry 8 carries an unknown on the Ruby studio normalisation cost; entry 12 an unknown on naming the goal back's week.
- Raised as questions, not changed: Q1 (the list is already approved in the spec) and Q6 (the backfill on every boot inside Kamal's health-check window; the reviewer notes jobs run inside Puma, so the backfill finishes before any new-code job).
