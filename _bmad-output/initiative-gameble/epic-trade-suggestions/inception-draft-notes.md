# Epic 29 (Trade suggestions): notes on the draft breakdown

Draft: `epic-29-draft.toml`, 7 entries. Nothing has been written to the repo.

## Questions for the author

1. **Page budget for suggestions (epic's Unknown).** The architecture sets no page budget; only pack opening has one (p95 < 200 ms), and AD-38 defers a suggestion cache "only if the query is measured past the page budget". *Recommend:* the suggestions read stays under 200 ms of server time on a seeded worst case of 100 friends, each with 5 goals of 50-game sets, and its query count does not grow with friends (entry 3 checks this). If it goes over, `bmad-architecture` designs the deferred cache before entry 3 ships, as a new entry. *Why:* this uses the one budget already set, and the query-count test catches an N+1 in CI.
2. **Spare when a copy is reserved.** AD-38 counts free copies (`quantity - reserved`) beyond "the one its holder keeps", but does not say whether that kept copy can be the reserved one. *Recommend:* the kept copy is always a free one, so spares = free copies - 1. A holder with 2 copies, 1 of them reserved, has no spare. *Why:* the reserved copy may leave in the open trade, and a suggested trade must never take a holder's last copy (spec: "a copy beyond their first").
3. **The epic's open question, what "spare" means when a friend's own goals need it.** *Recommend:* record it as settled by AD-38. A goal misses only games its holder has no copy of, and the kept copy already counts for the holder's own sets, because any edition counts. So a spare can never be a card the holder's goals need. *Why:* no extra rule is needed. A `Decision:` line closes the question.
4. **Which four cards a prefill keeps** when a suggestion names more than AD-8's 4 card-seasons per side (entry 4's unknown). *Recommend:* the player's goal order (position 1 first), then the rarest card. *Why:* the player chose that order, so the trade moves their top goal first.
5. **Order inside each group** (mutual first is settled). *Recommend:* friends with more needed cards first, then the friend's name. Entry 1's design can override this. *Why:* it is simple, and it puts the most useful trade at the top.
6. **Keep entry 5, a goal's line leading to its suggestions?** The Done when is met on the trade side alone. *Recommend:* keep it, if entry 1's design keeps it. *Why:* players work from their goals, so without this line they may never find the suggestions, and the outcome signal depends on them finding it.
7. **Keep entry 7, the closing end-to-end suite?** The epic says it "needs much work and testing", but it has no test plan. *Recommend:* keep it. *Why:* the privacy matrix and the full mutual trade cross three entries, and a single suite proves Done when 4 in one place.
8. **Outcome signal (trades started from a suggestion and accepted).** Nothing records where a trade came from, and doing so would mean an architecture change and a schema column. *Recommend:* defer it and say so in the epic's Notes. Read the signal from accepted trades between friends with goals for now. *Why:* this keeps a migration out of an epic the author wants able to slip on its own.

## Tracer bullet

Entry 2. It runs `Game::TradeSuggestions` (one-sided, privacy filtered, with AD-38's spare rule), shows the list where the design puts it, and its start action opens the trade board prefilled. That passes through the domain query, the page and the trade board's draft. The prefill takes both a give and a take side from the start, so entry 3 only fills the give side.

## Sequencing and parallel work

- Entry 1 (design, hitl) waits on 28.2 (the goals' design). Entry 2 waits on 1 and 28.9 (`Game::GoalNeeds`).
- After 2, entries 3 (mutual, query and suggestion partial) and 4 (prefill rules, trades controller `new` and the board's TypeScript) run in parallel, because they share no code.
- Entry 5 waits on 3, since it reads the query's final shape, and on 28.11 (goals on the bridge). It can run beside 4.
- Entry 6 (sweep) waits on 1 to 5. Entry 7 (suite) closes the epic.
- Longest chain: 28.2 → 28.3 → 28.9 → 29.2 → 29.3 → 29.5 → 29.6 → 29.7.
- Watch: 28.10 and 29.5 have no path between them, and both may touch the collection's goals area. In practice epic 28 is finished first; if not, put 28.10 in 29.5's `after`.
- File sizes: `trade_board.ts` (377 lines) and `trade_board_controller.ts` (354) are close to the 400-line limit, so entries 2 and 4 will likely need to extract the prefill into its own module.

## High-risk entries and their outside checks

- **Entry 2** (new core query, privacy E4). Outside check: before 3 and 4 start, the author checks on staging with a private friend, a friends-only friend and a banned friend, and a `bmad-review` adversarial pass looks for anything that names a hidden player.
- **Entry 3** (the cost unknown, and friends' custom-set goals must stay hidden). Outside check: the author confirms the measured worst-case figure against the budget agreed in question 1, and `bmad-review` checks that no friend's custom-set goal reaches the result.

## Coverage

- E1 (friends holding a spare of each missing card): entry 2 (list), entry 5 (from the goals), entry 7.
- E2 (mutual first): entry 3, entry 7.
- E3 (start a trade with cards placed): entry 2 (prefill), entry 3 (give side), entry 4 (open trade, 4-card cap, stale cards, crafted URLs), entry 7.
- E4 (private never suggested, sees none): entry 2 (private player and private/banned/deleted friend), entry 3 (friends' custom-set goals never read), entry 5 (no line for a private player, none on the profile), entry 7 (matrix).
- Done when 1 (EN/FR, friends per missing card): entries 1 and 2. Done when 2 (mutual first): entry 3. Done when 3 (proposal placed, then runs as any trade): entries 2 to 4, end to end in 7. Done when 4 (no private player named, no hidden collection revealed): entries 2, 3 and 7.
- Not owned here: production delivery is not in the epic's Done when (the tree check expects it; release 1.1.0 ships with epic 28).

## Set checks run

- Each covers id exists (E1 to E4) and each requirement is covered. The sweep comes after all other work, and the suite comes after the sweep.
- `tickets.py status` was run on a sandbox copy of the initiative with this draft as epic 29's `tickets.toml`. Epic 29 has no cycle, `unpinned_after`, `order_conflict` or `blocks`. The only `undeclared_after` is an existing one in epic 22.
- References open: `ux-gameble/ux-gameble.md`, `spec-gameble/brotherhood-tone.md`, and AD-8, AD-11, AD-35, AD-38 in the architecture.
- AD-35 and AD-38 carry no `[ADOPTED]` mark in the architecture, unlike AD-1 to AD-34 and AD-39. It is worth checking whether that was intended before entry 2 builds on them.
