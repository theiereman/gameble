# Screen walkthrough findings

One session, the author and an agent, every screen of the Information Architecture. Each screen is seen signed out (where it allows it), as a player and as staff, in French and in English, on a phone and on a desktop.

Decision per finding: `ticket` (built before the release, with its id), `deferred` (entry in deferred-work.md) or `keep` (left as it is).

## Screens

Mark a screen `walked` when every applicable combination was seen.

| Screen | Walked | Notes |
|---|---|---|
| Landing | partial: visitor, FR and EN read as HTML; phone and desktop seen by the author | credits page linked from the footer is not in the Information Architecture |
| Pont de commandement (hub) | | |
| Ouverture de capsule | | |
| Collection | | |
| Set album | | |
| Toutes les cartes | | |
| Card detail | | |
| Seasonal allocation | | |
| Share sheet | | |
| Échanges (list and board) | | |
| Card picker | | |
| Amis | | |
| Friend profile | | |
| Report dialog | | |
| Fil d'activité | | |
| Succès | | |
| Comment ça marche | | |
| Profil et paramètres | | |
| Public card page | | |
| Public profile | | |
| Full collection (another player's) | | |
| Steam sign-in | | |
| Legal page | | |
| Soutenir | | |
| Roadmap page | | |
| Plus (phone) | | |
| Back-office | | |

## Findings

| # | Screen | Finding | Decision | Ticket |
|---|---|---|---|---|
| 1 | Landing | The credits page (`/credits`, linked from the landing footer) lists only inspirations and is missing from the Information Architecture. It should also credit the repository's current contributors and, in future, each contributor for their own contribution. | ticket (scoped together: contributors pulled from PRs and issues, text written with the author) | to create |
| 2 | Landing | Module 09 (Soutenir) sits in a striped frame like "Soutenir gameble", which repeats it and differs from the plain look of modules 07 and 08. It should lose the striped frame. | ticket | 16.12 |
| 3 | Landing | The demo cards show "Image indisponible" in the fetched HTML; the author sees the cards fine in the browser. | keep | |
