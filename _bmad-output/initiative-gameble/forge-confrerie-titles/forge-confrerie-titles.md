# Forged idea: Brotherhood job titles

Replaces the per-set profile titles (CAP-22). Mock: `ux-gameble/.working/profile-titles-stats-star.html`. Calibration query: `calibration.sql`.

## Decisions

- A title is a job title in the Brotherhood's hierarchy, earned through long-term investment and feats; never generic, not for everyone. The Brotherhood never addresses a player by title: amend `brotherhood-tone.md` to forbid the address, not the hierarchy.
- Five services, one measure each, counted cumulatively since sign-up:

  | Service | Measure | Grades 2 / 3 / 4 | Grade 5 | Seat |
  |---|---|---|---|---|
  | Archives | sets completed | Archiviste junior / Archiviste / Archiviste senior | Responsable des Archives | Direction des Archives |
  | Bourse | turnover in PiCoins (sales, purchases, PiCoins minted by entrusting) | Comptable junior / Comptable / Comptable senior | Responsable de la Bourse | Direction de la Bourse |
  | Échanges | trades accepted | Spécialiste des échanges junior / … / … senior | Responsable des échanges | Direction des échanges |
  | Exploration | pioneer first discoveries | Cartographe junior / Cartographe / Cartographe senior | Responsable de l'Exploration | Direction de l'Exploration |
  | Stratégie | duels finished | Stratège junior / Stratège / Stratège senior | Responsable de la Stratégie | Direction de la Stratégie |

- Grades per service: 1 hidden; 2 = p50 and 14 days of service; 3 = p75 and 30 days; 4 = p90 and 90 days; 5 = p97, 180 days and the service feat. Days of service = distinct days with the daily bonus claimed.
- Percentiles are taken among active members (a bonus claimed in the last 30 days) and set floating thresholds that rise with the population; a grade is a stored high-water mark and never drops. Early members are privileged, on purpose (satire). Nightly job recomputes and promotes.
- The player wears the post of the service where their grade is highest; a mutation happens only when another service's grade strictly passes it.
- An inactive member is "en disponibilité": title hidden, restored on return.
- Top feats, earned once: Archives 5,000 capsules opened; Bourse "Délit d'initié"; Échanges 25 friends; Stratégie "Monopole de fait" (100 wins); Exploration finish a week first on the pioneer ranking (new, built like the Chattomètre's employee of the week).
- Seats: one per service, a Comité de direction of five, awarded at each season publication (about every 3 months) to the service's number one over the season that ended, among members of grade 3 or more in that service. The dethroned holder returns to their grade. Shown in the season recap screen and one Direction feed entry.
- Staff titles outside the ladder, given by role: administrator "Conservateur des Archives", moderator "Officier"; a staff member may wear either.
- Titles carry no grammatical agreement and no "X · Y" middle-dot format; plain French job words a reader understands without looking up.
- Feed: launch assignment is silent plus one Direction announcement ("réorganisation des services"); promotions from grade 3 reach the feed, lower grades the bell only; seat nominations get one Direction entry.
- Set titles are removed (set tiers stay for card backs, themes and the season screen); the picker shrinks to show my post / no title (plus staff title). About half the active members show no title at launch: accepted.
- Clicking a title anywhere opens the service star: a five-branch radar of percentiles, raw figures and posts per service; visibility follows the profile's.
- Owner-only "Mes indicateurs": career track, a gauge per next-grade condition with threshold marks and the threshold's 4-week rise, the season race for the seat with the gap to the next member, the nearest mutation, a 12-week evolution (needs a weekly snapshot of percentiles).

## Rejected

- Per-set titles: generic, about 60 per player.
- A composed "Post · Distinction" title and parallel ladders worn by choice: too many titles; the author prefers assignment and mutation.
- Demotion, a monthly review, a double threshold: a multinational does not demote; floating thresholds and seats carry the pressure instead.
- A capped seat without seasons, a 90-day rolling seat: replaced by the season-publication event.
- Grandiloquent titles (Plénipotentiaire, Main invisible), English job words (Trader, Scout, Head of), Duelliste (swords), Contentieux (conflict), Grand Maître (too grand; the Direction stays faceless), Directeur (gender agreement).
- Pioneer of a Legendary as a top feat: nearly every player has it.

## Open

- English titles.
- Thresholds for Bourse and Stratégie are guesses until the market and duels have production volume; market orders join the Bourse measure once in production.
