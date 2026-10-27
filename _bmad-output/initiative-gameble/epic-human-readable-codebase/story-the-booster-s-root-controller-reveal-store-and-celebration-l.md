---
id: 16
tracker_status: done
tracker_id: 284
remote: https://github.com/theiereman/gameble/issues/284
type: story
title: "The booster's root controller: reveal, store and celebration leave it, and it fits 400 lines"
parent: epic-human-readable-codebase
covers: [R3]
after: [15]
hitl: false
risk: high
---

# The booster's root controller: reveal, store and celebration leave it, and it fits 400 lines

## Description

Runs on develop after epic 21 is merged. Second half: moves the reveal sequences (`revealTier`, `revealLegendary`, `revealStill`, `reveal`, `revealEveryCard`, `revealAndStoreAll`), `store`, `springBack`, `leaveFor`, `repost` and the celebration step out of `booster_controller.ts` the same way, until the root controller holds only state, outlets and intents and is at most 400 lines; no markup, `data-*`, event or timing change.

## Acceptance Criteria

Verify: `npm run test:js`, `npm run typecheck`, `script/check_markup_apis` pass; `booster_controller.ts` and every new file are at most 400 lines; `bin/rails test test/system/booster_test.rb` passes unchanged.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
