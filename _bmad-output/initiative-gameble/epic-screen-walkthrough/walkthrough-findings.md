# Screen walkthrough findings

One session, the author and an agent, every screen of the Information Architecture. Each screen is seen signed out (where it allows it), as a player and as staff, in French and in English, on a phone and on a desktop.

Decision per finding: `ticket` (built before the release, with its id), `deferred` (entry in deferred-work.md) or `keep` (left as it is).

## Screens

Mark a screen `walked` when every applicable combination was seen.

| Screen | Walked | Notes |
|---|---|---|
| Landing | partial: visitor, FR, EN, phone and desktop | footer credits page not in the Information Architecture (16.14) |
| Pont de commandement (hub) | partial: desktop right and left columns seen by the author | top bar, menu, showcase, LIVE ticker, phone to see |
| Ouverture de capsule | | |
| Collection | | |
| Set album | | |
| Toutes les cartes | partial: visitor, FR and EN | signed-in view and phone to see |
| Card detail | partial: public page as a visitor, FR and EN | signed-in detail to see |
| Seasonal allocation | | |
| Share sheet | | |
| Échanges (list and board) | | |
| Card picker | | |
| Amis | | |
| Friend profile | | |
| Report dialog | | |
| Fil d'activité | partial: visitor, FR and EN, author ok | player view (AMIS tab) to see |
| Succès | | |
| Comment ça marche | partial: visitor, FR and EN, author ok | player and staff views to see |
| Profil et paramètres | | |
| Public card page | | |
| Public profile | | |
| Full collection (another player's) | | |
| Steam sign-in | | |
| Legal page | walked as a visitor, FR, author ok | |
| Soutenir | external link, checked | |
| Roadmap page | walked as a visitor, FR and EN, author ok | |
| Plus (phone) | | |
| Back-office | | |

## Findings

| # | Screen | Finding | Decision | Ticket |
|---|---|---|---|---|
| 1 | Landing | The credits page (`/credits`, linked from the landing footer) lists only inspirations and is missing from the Information Architecture. It should also credit the repository's current contributors and, in future, each contributor for their own contribution. | ticket | 16.14 |
| 2 | Landing | Module 09 (Soutenir) sits in a striped frame like "Soutenir gameble", which repeats it and differs from the plain look of modules 07 and 08. It should lose the striped frame. | ticket | 16.12 |
| 3 | Landing | The demo cards show "Image indisponible" in the fetched HTML; the author sees the cards fine in the browser. | keep | |
| 4 | Toutes les cartes | The page title reads "Toutes les cartes · Collection · gameble"; it should be "Toutes les cartes · gameble". | ticket | 16.13 |
| 5 | Toutes les cartes | The grid would gain infinite scroll. | ticket | 16.15 |
| 6 | Landing | On a phone the "Animations réduites" switch covers the gameble wordmark; remove it there. | ticket | 16.16 |
| 7 | Card detail (public page) | The Steam and share buttons sit on the card information's background; the background should wrap the information only. | ticket | 16.17 |
| 8 | Public profile | The started sets list is too long; show only the 20 most complete sets. | ticket | 16.18 |
| 9 | Hub | A wide gap separates the community goal and "SETS EN COURS"; the daily capsule should sit under the goal and the sets take its place in the left column. | ticket | 16.19 |
| 10 | Hub top bar | The player chip is not as tall as the rarity counter and the capsules chip. | ticket | 16.20 |
