---
id: 34
tracker_status: done
tracker_id: ""
type: story
title: "A player's reposts are capped and a card is not reposted twice in a day"
parent: epic-human-readable-codebase
after: [5]
hitl: false
risk: medium
---

# A player's reposts are capped and a card is not reposted twice in a day

## Description

Today only the request throttle (30 a minute per player in `RepostsController`) limits a repost, while each one publishes an entry in the public LIVE feed with no ceiling and no duplicate guard. `Game::RepostCard` refuses a repost beyond 10 in the last hour by the same player (`Failure(:repost_limit_reached)`) and a second repost of the same card by the same player within 24 hours (`Failure(:already_reposted)`), both counted from the player's `CardReposted` events or a query beside them, inside the operation's transaction so two concurrent requests cannot both pass. The controller maps both codes to a 422 with a message in `en.yml` and `fr.yml` (`errors.game.repost_card.<code>`, added by hand), and the booster zoom's repost control shows the refusal as it already shows `card_not_owned`. The limits are named constants of the operation. Author's choice, 2026-10-27: a cap per player plus a duplicate guard; the numbers 10 an hour and 24 hours are a proposal for the author to confirm or change.

## Acceptance Criteria

Verify: Operation tests: the 11th repost within an hour fails with `:repost_limit_reached` and the 11th succeeds again after the hour; a second repost of the same card within 24 hours fails with `:already_reposted`, another card and another player succeed; a repost refused publishes no event. A controller test shows the 422 with the translated message in both locales; the booster system test (repost from the zoom) still passes; `i18n-tasks missing` and `unused` are clean.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md

## Notes

- Unknown: The numbers (10 an hour, one per card a day) are the agent's proposal; whether staff reposts or a deleted event count.
