# Screen walkthrough findings

One session, the author and an agent, every screen of the Information Architecture. Each screen is seen signed out (where it allows it), as a player and as staff, in French and in English, on a phone and on a desktop.

Decision per finding: `ticket` (built before the release, with its id), `deferred` (entry in deferred-work.md) or `keep` (left as it is).

## Screens

Mark a screen `walked` when every applicable combination was seen.

| Screen | Walked | Notes |
|---|---|---|
| Landing | partial: visitor, FR, EN, phone and desktop | footer credits page not in the Information Architecture (16.14) |
| Pont de commandement (hub) | desktop and phone, player, author ok apart from findings 9 and 10 | staff and the other language to see |
| Ouverture de capsule | desktop, player, author ok apart from findings 12 and 13 | phone, staff, FR/EN to see |
| Collection | desktop, player, author ok apart from finding 14 (design study) | phone, staff, FR/EN to see |
| Set album | desktop, player, author: not bad, see finding 15 | phone, public profile album, staff, FR/EN to see |
| Toutes les cartes | partial: visitor, FR and EN | signed-in view and phone to see |
| Card detail | public page as a visitor (FR, EN) and signed-in detail, desktop, author ok apart from findings 7 and 17 | phone, staff, EN to see |
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
| 11 | Ouverture de capsule | The "back to the bridge" button duplicates the gameble wordmark in the top bar, which already leads to the hub. | existing request | issue #67 |
| 12 | Ouverture de capsule | REVEAL ALL is briefly active while the next capsule deals its cards, then greys out again. | ticket | 16.21 |
| 13 | Ouverture de capsule | The revealed-cards counter is useless and should go; the booster is frozen to bug fixes, so it is dropped in the Stimulus port. | ticket | 21.3 (note) |
| 14 | Collection | The screen feels average and the "EN COURS" sets display is sad; look for a livelier idea. | ticket (design study) | 16.22 |
| 15 | Set album | A large set can lose the player; add filters (owned or missing, rarity), the author is not sure. | ticket (to confirm) | 16.23 |
| 16 | Set album | Missing cards should look like the not-owned cards of Toutes les cartes (faded, locked) for consistency, not name-and-year slots. | ticket | 16.24 |
| 17 | Card detail (player) | The accumulation of buttons (Steam, share, repost, showcase) at the foot of the detail looks messy. | ticket | 16.25 |
