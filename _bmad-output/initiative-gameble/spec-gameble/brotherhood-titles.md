# Brotherhood titles

Referenced by CAP-22, CAP-13, CAP-17 and CAP-23. Source: `forge-confrerie-titles/forge-confrerie-titles.md`, hardened with the author on 2026-11-23. Mock: `ux-gameble/.working/profile-titles-stats-star.html`.

## Principle

A profile title is the player's job title in the Brotherhood's hierarchy. It rewards long-term investment and feats, so not every member has one. The Brotherhood never addresses a player by it (`brotherhood-tone.md`). Titles carry no grammatical agreement, no "X · Y" middle-dot format, and use plain French job words a reader understands without looking up.

## Services

Each service has one measure, counted cumulatively since sign-up.

| Service | Measure | Grade 2 | Grade 3 | Grade 4 | Grade 5 | Seat |
|---|---|---|---|---|---|---|
| Archives | sets completed | Archiviste junior | Archiviste | Archiviste senior | Responsable des Archives | Direction des Archives |
| Bourse | turnover in PiCoins: sale proceeds, purchases paid, PiCoins minted by entrusting (market orders once live) | Comptable junior | Comptable | Comptable senior | Responsable de la Bourse | Direction de la Bourse |
| Échanges | trades accepted | Spécialiste des échanges junior | Spécialiste des échanges | Spécialiste des échanges senior | Responsable des échanges | Direction des échanges |
| Exploration | pioneer first discoveries (CAP-13) | Cartographe junior | Cartographe | Cartographe senior | Responsable de l'Exploration | Direction de l'Exploration |
| Stratégie | duels finished, practice excluded | Stratège junior | Stratège | Stratège senior | Responsable de la Stratégie | Direction de la Stratégie |

English titles (author, 2026-11-23):

| Service | Grade 2 | Grade 3 | Grade 4 | Grade 5 | Seat |
|---|---|---|---|---|---|
| Archives | Junior Archivist | Archivist | Senior Archivist | Head of the Archives | Archives Directorate |
| Bourse | Junior Accountant | Accountant | Senior Accountant | Head of the Exchange | Exchange Directorate |
| Échanges | Junior Trade Specialist | Trade Specialist | Senior Trade Specialist | Head of Trades | Trades Directorate |
| Exploration | Junior Cartographer | Cartographer | Senior Cartographer | Head of Exploration | Exploration Directorate |
| Stratégie | Junior Strategist | Strategist | Senior Strategist | Head of Strategy | Strategy Directorate |

Staff: "Archives Curator" (administrator), "Officer" (moderator). Until the duels beta, Stratégie stops at grade 4: its top feat is withheld (author, 2026-11-23).

## Grades

| Grade | Activity in the service | Days of service | Also | Shown |
|---|---|---|---|---|
| 1 | — | — | | no title |
| 2 | p50 | 14 | | yes |
| 3 | p75 | 30 | | yes, promotion in the feed |
| 4 | p90 | 90 | | yes |
| 5 | p97 | 180 | the service's top feat | yes |

- Days of service: distinct days with the daily bonus claimed (CAP-16).
- Percentiles are taken among active members: a bonus claimed in the last 30 days; banned, deleted and bot accounts excluded.
- Thresholds float: a nightly job recomputes them and promotes. A grade is a stored high-water mark and never drops, so early members keep grades later members must work harder for. This privilege is intended.
- The player wears the post of the service where their grade is highest. A mutation happens only when another service's grade strictly passes it; a tie keeps the current service.
- An inactive member is "en disponibilité": the title is hidden and comes back on return.

## Top feats

Earned once and kept. They are achievements (CAP-17, `achievements.md`).

| Service | Feat |
|---|---|
| Archives | Open 5,000 capsules |
| Bourse | Insider Trading: resell 5 different editions for at least twice the price paid |
| Échanges | Have 25 friends |
| Exploration | Finish a week first on the pioneer ranking (new) |
| Stratégie | De Facto Monopoly: win 100 duels (withheld until the duels beta) |

## Seats

- One seat per service, together the Comité de direction of five.
- At each season publication (about every three months), the seat goes to the service's number one over the season that ended, among members of grade 3 or more in that service. The seat title replaces the post.
- The holder keeps it until the next publication. A dethroned holder returns to their grade and gets a private notice.
- A seat with no candidate stays vacant, and the Direction says so.

## Staff titles

Outside the ladder, given by role, never earned: administrator "Conservateur des Archives", moderator "Officier". A staff member wears either their staff title or their post. The faceless Direction is never a person.

## Where titles show

- The title shows alone on the profile, in the feed and in trades. The picker offers the post or no title, plus the staff title for staff.
- Feed (CAP-13): launch assignment is silent, with one Direction announcement of a "reorganisation of services". After that, promotions from grade 3 reach the feed and lower grades notify the player in the bell. Seat nominations make one Direction entry. There is no demotion.
- Season recap (CAP-23): a section shows the Comité de direction for the new season.
- Clicking a title opens the service star: a five-branch radar of the player's percentile per service, with each service's post, raw figure and any seat. Visibility follows the profile's (CAP-8).
- On their own profile, the player alone sees the next grade's conditions and "Mes indicateurs": a career track, a gauge per condition with the current and next thresholds and the threshold's 4-week rise, the season race for the seat (number one, the player, the member behind and the gap), the nearest possible mutation, and a 12-week evolution of their position per service with promotions marked. The evolution needs a weekly snapshot of each player's percentiles.

## Calibration

Production on 2026-11-23: 33 members, 26 days after launch. Trades are common (median 10, p90 106), completed sets rarer (median 1, p90 31), market sales small, no duels yet. Bourse and Stratégie thresholds stay guesses until those services have production volume. Calibration query: `forge-confrerie-titles/calibration.sql`.
