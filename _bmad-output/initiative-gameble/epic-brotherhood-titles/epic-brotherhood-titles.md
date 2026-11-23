---
tracker_id: ""
key: ""
type: epic
title: "The Brotherhood names its members"
parent: initiative-gameble
covers: ["CAP-22", "CAP-13", "CAP-17", "CAP-23"]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# The Brotherhood names its members

## Description

Profile titles stop being one per set and become job titles in the Brotherhood's hierarchy. Five services each measure one activity and give five grades on floating percentile thresholds that never take a grade back; the player wears the post of their highest grade, a seat per service is contested at each season publication, staff wear their own titles, and every title opens the service star. The player alone sees their performance metrics. The contract is CAP-22 and its companion `brotherhood-titles.md`.

## Outcome

For the players: a title says what a member has done for the Brotherhood and for how long, and the race for a grade or a seat gives a reason to come back. For the author: titles stop being generic (about 60 per player today) and only part of the active members carry one.

## Requirements

- R1 — The five service measures and days of service are read per member from existing data: sets completed, turnover in PiCoins (sale proceeds, purchases paid, PiCoins minted by entrusting), trades accepted, pioneer first discoveries, duels finished without practice; days of service are distinct days with the daily bonus claimed; active means a bonus claimed in the last 30 days, banned, deleted and bot accounts excluded. (CAP-22; brotherhood-titles.md, Services, Grades)
- R2 — A nightly job sets each service's thresholds at p50, p75, p90 and p97 of active members with the floors 14, 30, 90 and 180 days, and raises each member's stored grade per service; a stored grade never drops. (CAP-22; brotherhood-titles.md, Grades)
- R3 — Grade 5 also needs the service's top feat: Open 5,000 capsules, Insider Trading, Have 25 friends, De Facto Monopoly (withheld until the duels beta), and a new achievement, finish a week first on the pioneer ranking, frozen at the week's end like the Chattomètre's verdict. (CAP-22, CAP-17; brotherhood-titles.md, Top feats; achievements.md, Title feats)
- R4 — The worn post is the job title of the member's highest grade; another service replaces it only with a strictly higher grade; an inactive member shows no title until they are active again; grade 1 shows none. (CAP-22; brotherhood-titles.md, Grades)
- R5 — The title shows alone, with no middle-dot format and no grammatical agreement, on the public and friend profile, in the feed, in trades and in settings; the picker offers the post or no title, and staff also their staff title ("Conservateur des Archives", "Officier"); set tiers give no title any more and the per-set titles are retired. (CAP-22; brotherhood-titles.md, Staff titles, Where titles show)
- R6 — A promotion to grade 3 or more makes a feed entry, a lower one a bell notice to the player; the first run of the job assigns every grade silently and the Direction publishes one announcement of a reorganisation of services. (CAP-13, CAP-22; brotherhood-titles.md, Where titles show)
- R7 — Clicking a title opens the service star: the member's percentile per service as a five-branch radar rendered on the server, each service's post and raw figure, and any seat; it shows only where the viewer may see the profile. (CAP-22, CAP-8; brotherhood-titles.md, Where titles show; mock section 2)
- R8 — A weekly snapshot stores each active member's percentile and figure per service and each threshold. (CAP-22; brotherhood-titles.md, Where titles show)
- R9 — On their own profile the player alone sees Mes indicateurs: the career track, one gauge per condition of the next grade with the current and next thresholds and the threshold's 4-week rise, the nearest possible mutation, and a 12-week evolution of their position per service with promotions and feats marked. (CAP-22; mock section 5)
- R10 — At each season publication, each service's number one over the season that ended, among members of grade 3 or more in that service, takes the service's seat and wears "Direction de …" until the next publication; a service with no candidate leaves its seat vacant; the dethroned holder returns to their grade with a private bell notice. (CAP-22; brotherhood-titles.md, Seats)
- R11 — The season recap screen shows the Comité de direction of the new season, and the Direction publishes one feed entry naming it. (CAP-23, CAP-13; brotherhood-titles.md, Seats)
- R12 — Mes indicateurs shows the season race for the seat in the member's service: the number one, the member and the member behind, with the gap. (CAP-22; mock section 5)

## Done when

1. After the nightly job, every active member wears the post of their highest grade wherever a title shows; no per-set title remains; raising a threshold lowers no stored grade.
2. A promotion to grade 3 or more appears in the feed and a lower one only in the bell; the first run creates no promotion entry and one Direction announcement.
3. Clicking a title opens the service star with the profile's visibility, and the owner sees Mes indicateurs on their own profile and nobody else does.
4. Publishing a season names the Comité de direction on the season recap and in one Direction feed entry, and the dethroned holder gets a private notice.
5. A member at p97 without the service's top feat stays at grade 4; the week's first pioneer earns the new achievement.

## Boundaries

The title, its grades, seats, star and metrics, and the feed, bell, achievement and season-recap lines they need. Not the set tiers, card backs or menu themes, which keep reading set tiers; not a new duel or market rule; English copy waits on the author.

## References

- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-22, CAP-13, CAP-17, CAP-23
- spec — _bmad-output/initiative-gameble/spec-gameble/brotherhood-titles.md
- spec — _bmad-output/initiative-gameble/spec-gameble/achievements.md, Title feats
- constraint — _bmad-output/initiative-gameble/spec-gameble/brotherhood-tone.md, Writing rules
- design — _bmad-output/initiative-gameble/ux-gameble/.working/profile-titles-stats-star.html
- input — _bmad-output/initiative-gameble/forge-confrerie-titles/forge-confrerie-titles.md (forge record and calibration.sql)

## Notes

- Decision: release 1.5.0, after the duels (1.4.0) and market volume (1.3.x); briefly moved to 1.3.x, then back (author, 2026-11-23).
- Decision: the architecture spine and EXPERIENCE.md are brought up to date before the build, through bmad-architecture (grade and threshold storage, the nightly job, the weekly snapshot, seats) and bmad-ux (picker, star, Mes indicateurs, season recap section); the build waits on both (author, 2026-11-23).
- Decision: the tracer bullet is entry 1, measures to thresholds to stored grade to the title on the public profile; entries 3, 4 and 5 can run beside each other after entry 2, then entries 6 and 7 in separate lanes (2026-11-23).
- Decision: a closing refactor sweep, entry 9 (2026-11-23).
- Open question: the English job titles and the new achievement's French and English titles; entry 2 and entry 4 wait on them.
- Unknown: Bourse and Stratégie thresholds are guesses until those services have production volume; the job recomputes them, so no entry waits on it.
- Source conflict: architecture-gameble.md, the set-tier read model of profile titles (near line 306) — titles are read from set-tier rows vs stored grades per CAP-22 as rewritten 2026-11-23; settled by the bmad-architecture pass above.
