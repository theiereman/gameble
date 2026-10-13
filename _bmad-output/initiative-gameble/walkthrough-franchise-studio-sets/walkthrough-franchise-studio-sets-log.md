# Review log: franchise and studio sets

Target: commit 666f06ba66649b195dd73dd43c603499955b8496 (develop, pushed)

## 1 — Whole target — narrative created

Session: unavailable · Timestamp: 2026-10-12T17:48:03+02:00

- Action: built narrative (8 blocks) from the plan and the commit diff.
- Result: walkthrough starts at block 1 (Intent).
- Evidence: _bmad-output/initiative-gameble/epic-recognizable-sets/story-franchise-and-studio-sets-plan.md; git show 666f06b

## 2 — Block 1 (Intent) — test on staging draft

Session: unavailable · Timestamp: 2026-10-12T18:05:00+02:00

- Action: read-only probe of the new builders on staging's draft (code piped, 666f06b not deployed); user asked why "EA Play" is dropped and no "EA" studio exists.
- Result: accepted as-is by the user. Studios count the first developer only; EA is a publisher (DICE, BioWare, Respawn… develop), and publisher sets are retired by the spec. "EA Play" is a publisher page, dropped by design. A publisher-wide set would be a spec change, a new ticket.
- Evidence: scratchpad probe-bundle.rb, probe-ea-bundle.rb (EA probe prepared, not run).

## 3 — Block 5 (builders) — question

Session: unavailable · Timestamp: 2026-10-12T18:20:00+02:00

- Action: user asked whether Dark Souls and Demon's Souls share a set.
- Result: accepted as-is. Demon's Souls is not on Steam. Dark Souls games form a franchise set if Steam names the franchise; FromSoftware games share a studio set; souls-likes share the Souls-like theme. Steam's actual franchise field not verified.
- Evidence: scratchpad probe-fromsoftware-bundle.rb (prepared, not run).

## 4 — Whole target — wrap-up

Session: unavailable · Timestamp: 2026-10-12T18:03:49+02:00

- Action: all 8 blocks accepted by the user.
- Result: review done, no open finding. Plan marked done; walkthrough files committed and pushed to develop.
- Open: staging probes (probe-bundle.rb, probe-ea-bundle.rb, probe-fromsoftware-bundle.rb) prepared, not run by Claude; 666f06b not yet deployed to staging.
