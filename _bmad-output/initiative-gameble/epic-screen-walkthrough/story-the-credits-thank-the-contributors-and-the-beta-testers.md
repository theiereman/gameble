---
id: 14
tracker_status: done
tracker_id: 242
remote: https://github.com/theiereman/gameble/issues/242
type: story
title: "The credits thank the contributors and the beta testers"
parent: epic-screen-walkthrough
after: []
hitl: true
risk: low
---

# The credits thank the contributors and the beta testers

## Description

The credits page (`/credits`, `app/views/pages/credits.html.erb`) names only inspirations and is missing from EXPERIENCE.md's Information Architecture. Add a section crediting the repository's contributors by GitHub handle, each with one broad contribution (writing, code contribution, idea proposals) drawn from their merged pull requests and issues, a rule for crediting future contributors the same way, and a section thanking the people who tested the beta. The author and the agent settle the list and the wording together before the build; the page, both locales and EXPERIENCE.md follow (author, 2026-10-23).

## Acceptance Criteria

Verify: `/fr/credits` and `/en/credits` list the agreed contributors by handle with their contribution and the beta testers, the page is in the Information Architecture, and the credits request test and `i18n-tasks` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 1), author, 2026-10-23. Candidates from the repository: micilico (code), skyoraa (writing, ideas), Felzpath (ideas, bug reports); the beta testers' names come from the author.
- Settled by the author, 2026-10-24: the contributors are micilico (code), skyoraa (writing, ideas) and Felzpath (ideas, bug reports); the beta testers' names still come from the author before the build.
- Beta testers, given by the author on 2026-10-26: Hydrax, Skyora, Zohan, Feltpath, Micilico, Le chocotube. Skyora, Feltpath and Micilico are probably the contributors skyoraa, Felzpath and micilico: confirm each name's spelling with the author before the build, and decide whether such a person appears under both sections or once.
- The six testers also get a tribute card (ticket 16.33); the credits may point to it.
