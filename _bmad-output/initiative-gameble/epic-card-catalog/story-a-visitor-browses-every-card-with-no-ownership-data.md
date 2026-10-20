---
id: 4
tracker_status: done
tracker_id: 191
remote: https://github.com/theiereman/gameble/issues/191
type: story
title: "A visitor browses every card with no ownership data"
parent: epic-card-catalog
covers: [R3, R4]
after: [3]
hitl: false
risk: medium
---

# A visitor browses every card with no ownership data

## Description

For a signed-out visitor, "Toutes les cartes" and the card detail it opens drop the ownership parts entry 1 lists (state filter group, copies, edition count, RAPPORT, owned count, the copies and editions rows of the detail and of its empty column) while the search and the rarity, set and genre filters keep working; the policy tests cover the visitor; PublicReadThrottle keeps counting both pages, they stay Cache-Control: private, and no database id reaches the page or its links.

## Acceptance Criteria

Verify: Signed out on staging, in fr and en, on a phone and a desktop, a visitor searches a game by name, filters by rarity and by a franchise, opens a card's detail and sees no ownership data; an empty search says so; a new case in the rate limit test shows /library/cards throttled and Cache-Control: private; a player's view is unchanged.

## References

- parent — _bmad-output/initiative-gameble/epic-card-catalog/epic-card-catalog.md
- app/views/library/_filters.html.erb
- app/views/library/_status.html.erb
- app/views/library/_collection.html.erb
- app/views/library/_report.html.erb
- config/initializers/rack_attack.rb, PublicReadThrottle
- test/integration/rate_limit_test.rb
