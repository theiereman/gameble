---
name: gameble
status: final
created: 2026-10-01
updated: '2026-10-06'
sources:
  - ../spec-gameble/spec-gameble.md
  - ../spec-gameble/catalog-and-rarity.md
  - ../spec-gameble/brotherhood-tone.md
  - ../brief-gameble/brief-gameble.md
---

# gameble — Experience Spine

## Foundation

A responsive web game for desktop and phone (portrait only), in French and English. Every flow works on both form factors; the layouts differ: a hub with a numbered menu on desktop, a bottom tab bar on the phone. This document names no UI component library: the stack renders pages on the server and embeds interactive components for the booster opening and the trade board (see the spec's architecture and `ux-gameble.md`, For the architecture). `DESIGN.md` is the visual identity reference; this document is the experience. Tokens are referenced by name, for example `{colors.accent}`; component names are the same in both documents.

Visual references: [mockups/key-screens.html](mockups/key-screens.html) (desktop prototype: every screen, the chosen "Explosion A" opening on the booster screen, the signed-out public card page) and [mockups/mobile.html](mockups/mobile.html) (phone prototype). DESIGN.md and EXPERIENCE.md take precedence over any mock when they conflict. The mocks are a reference for look and timing, never source code. Their sample data (a 16 480-card season, three-hour timers, demo odds, a scripted first pack) is illustrative; the spec's numbers rule.

In this document, "booster" is the player-facing word for the spec's "pack", and "réserve" for its "bank". Items tagged `[ASSUMPTION]` are not confirmed in the decisions log. Open questions close the file.

## Information Architecture

| Surface | Reached from | Purpose |
|---|---|---|
| Pont de commandement (hub) | Landing after sign-in; "◀ PONT" from any screen; PONT tab | Status at a glance and the way to everything else |
| Ouverture de booster | Menu 01, the packs chip, the BOOSTER tab, the empty showcase | Open one booster at a time and reveal its five cards |
| Collection | Menu 02, a set progress row on the hub, COLLECTION tab | Browse cards by set and genre, see progress and missing cards |
| Card detail ("FICHE DE LA CARTE") | A card in the collection, a revealed booster card, the showcase's "VOIR LA FICHE", the card zoom | Full card facts, Steam link, share |
| Share sheet | "PARTAGER" in the card detail | Copy the share link, open the public page |
| Échanges | Menu 03, "PROPOSER UN ÉCHANGE", ÉCHANGES tab | Trade list and trade board |
| Card picker | "PLACER MES CARTES" / "CHOISIR SES CARTES" on the trade board | Choose cards and copies for one side |
| Amis | Menu 04; PLUS on the phone | Invite by link or code, answer invitations, list friends with their presence |
| Friend profile | A friend row | Showcase, propose a trade, report |
| Report dialog | "SIGNALER" in a friend profile | Report a username or profile |
| Fil d'activité | Menu 05; PLUS on the phone; open without an account | Pulls, first discoveries, trades and reposts; tabs TOUS and AMIS (friends only) |
| Succès | Menu 06; PLUS on the phone | Achievements, earned and to earn |
| Profil et paramètres | The player chip; PLUS on the phone | Public profile summary, settings, card-back picker, "Mentions légales" |
| Public card page | A shared link, without an account | Show the shared card and invite the visitor to play |
| Public profile | A player's link | A player's collection and set progress, per their visibility (spec CAP-8) `[ASSUMPTION: shown as the collection screen in read-only mode; not mocked]` |
| Sign-in panel | Any game-styled action that needs an account | One title line and Valve's official Steam sign-in button |
| Steam sign-in | The official image, wherever it appears | Create or reuse the account (Steam's own page) |
| Legal page | "Mentions légales" in Profil et paramètres and the public page footer | No-affiliation notice, ownership notice ("Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons."), terms of use, privacy notice |
| Plus (phone only) | PLUS tab | PLUS rows: Amis, Fil d'activité, Succès, Profil et paramètres |
| Back-office | Staff accounts only | Out of the redesign's scope: unchanged behavior (spec CAP-2, CAP-15), plain functional style, designed later |

**Desktop navigation.** The hub is the only menu: 01 OUVRIR UN BOOSTER (boosters badge), 02 COLLECTION (unique cards owned / total), 03 ÉCHANGES (orange badge when a trade waits for the player), 04 AMIS ("n en ligne"), 05 FIL D'ACTIVITÉ ("En direct"), 06 SUCCÈS (earned / total). The player chip opens Profil et paramètres. Every other screen has "◀ PONT" at the left of its top bar. There is no permanent sidebar.

**Phone navigation.** A bottom tab bar: PONT · BOOSTER · COLLECTION · ÉCHANGES · PLUS. Tab roots have no back button; tapping the current tab returns to its root or scrolls it to the top. Sub-views slide over their screen with a contextual back: "◀ GRILLE" (card detail), "◀ LISTE" (trade board), "◀ PLUS" (Amis, Fil, Succès, Profil). The public card page has no tab bar.

**Hub content.** Top bar: logo, rarity counter, packs chip, player chip. Left: kicker "PONT DE COMMANDEMENT" with the subtitle "Vaisseau-bibliothèque « Archiviste »", the menu, the daily booster panel. Center: the showcase. Right: the community goal panel and "PROGRESSION DES SETS" (four set progress rows, "TOUT VOIR ▸"). Bottom: the LIVE ticker. On the phone the same blocks stack in one scrolling column without the menu.

**Signed-out visitors** see everything that needs no account and cannot act: any such action opens the sign-in panel, and the collection shows every slot empty. The signed-out hub is described in `DESIGN.md` (see Signed-out hub) `[ASSUMPTION: not mocked]`.

## Voice and Tone

This section covers microcopy only. Brand voice lives in `DESIGN.md` (see Brand & Style). All copy ships in French and English; the French below is the product's approved copy.

- **Terminal labels:** short uppercase labels for actions and states ("OUVRIR LE BOOSTER", "TOUT RÉVÉLER", "◀ PONT", "SCELLÉ", "RÉSERVE VIDE").
- **Plain sentences:** short and factual, always addressing the player as "vous", never "tu".
- **The Brotherhood is discreet:** one line, on the community goal only. None in the feed. No title for the player.
- **Errors say what happened and what to do,** inline where the action is.

| Do | Don't |
|---|---|
| "Un booster rejoint votre réserve. Le prochain sera prêt à minuit (UTC)." | Exclamation marks ("!" is reserved for the Légendaire banner) |
| "Léa a 7 jours pour répondre. Vos cartes sont réservées d'ici là." | Vague errors ("Erreur", "Échec de l'opération") |
| "Vous n'avez plus assez d'exemplaires de Celeste." | "Tu", "Confrère", "Capitaine" or any title |
| "Merci. L'équipe de modération examinera ce profil. Léa ne verra pas qui l'a signalé." | Helldivers terms ("Ordre majeur", "Super Earth", "Démocratie") |
| Name the rarity in words next to its shape | Name a real company in the copy (publishers appear only as card credits and set names) |

### Copy deck

The single source for every message the interface shows. Other sections name the control or state and point here; button labels stay with their controls.

| Key | Copy |
|---|---|
| Community goal | "Toute la Confrérie ouvre 50 000 boosters, ensemble." |
| Booster hints | "Cliquez une carte pour la révéler · n restantes" (phone: "Touchez la carte pour la révéler", then "Glissez la carte pour la ranger · ou touchez-la") · "Booster inventorié · +5 cartes dans la collection" |
| Booster states | "SCELLÉ" · "ARMEMENT" · "ÉJECTION" · "INVENTAIRE" · "SIGNAL LÉGENDAIRE" · "INVENTAIRE COMPLET" · "EN ATTENTE" · "RÉSERVE VIDE · Prochain booster dans …" · "Cartes révélées : n / 5" · "Réserve pleine" |
| Booster live region | "Carte 2 : Hades — Supergiant Games, 2020, Roguelite. Épique." · "Signal légendaire" |
| Face-down card name | "Carte 2 sur 5, face cachée. Révéler." |
| Daily booster | "Un booster offert chaque jour. Il rejoint votre réserve." · "Un booster rejoint votre réserve. Le prochain sera prêt à minuit (UTC)." · full reserve: "RÉSERVE PLEINE" · "Ouvrez un booster pour récupérer celui du jour." |
| Empty showcase | "OUVREZ VOTRE PREMIER BOOSTER" · "Votre plus belle carte s'affichera ici." · "OUVRIR UN BOOSTER" |
| Collection | "Aucune carte de ce genre dans ce set pour l'instant." · "IMAGE INDISPONIBLE" |
| Trade board lines | "Léa vous propose cet échange." · "En attente de la réponse de Léa." · "Choisissez les cartes de chaque côté." · "Modifiez ce que vous donnez et ce que vous demandez, puis renvoyez." · "Échange en cours…" · "Échange conclu." · "Échange clos." · "Valable 7 jours après l'envoi" · "Expire dans n j" |
| Trade toasts | "PROPOSITION ENVOYÉE" · "Léa a 7 jours pour répondre. Vos cartes sont réservées d'ici là." · "ÉCHANGE REFUSÉ · Votre réponse a été envoyée à Léa." · "PROPOSITION ANNULÉE · Vos cartes ne sont plus réservées." · "ÉCHANGE CONCLU · Dead Cells ×2 rejoint votre collection." |
| Trade refusals (inline) | "4 CARTES AU PLUS · Retirez une carte avant d'en placer une autre." · "UN ÉCHANGE À LA FOIS · Un échange est déjà ouvert avec Léa." · "EXEMPLAIRES INSUFFISANTS" · "Vous n'avez plus assez d'exemplaires de Celeste." |
| Card picker | "n cartes · n exemplaires (4 cartes au plus)" · "n disponibles" · `[ASSUMPTION]` "Aucune carte disponible." |
| Friends | "PAR LIEN" · "VOTRE CODE AMI" · "AJOUTER AVEC UN CODE" · "Sam vous invite" · "Envoyée à KAI-8F2D" · "NOUVEL AMI · Sam fait maintenant partie de vos amis." · "Aucune invitation en cours." |
| Invite code messages | "Format attendu : ABCD-1234." · "C'est votre propre code." · "Invitation déjà envoyée." · "Invitation envoyée à KAI-8F2D." |
| Presence | "En ligne" · "Ouvre un booster" · "Il y a 3 h" |
| Report | "Pseudo ou avatar inapproprié" · "Triche ou abus" · "Harcèlement" · "Autre" · "Merci. L'équipe de modération examinera ce profil. Léa ne verra pas qui l'a signalé." |
| Feed | "Rien pour l'instant dans ce filtre." · Friends tab without friends: `[ASSUMPTION]` "Ajoutez des amis pour suivre leurs tirages." with "AJOUTER DES AMIS" · repost entry: `[ASSUMPTION]` "Hugo a reposté Elden Ring." · tag "REPOST" |
| Repost | Action `[ASSUMPTION]` "REPOSTER" · confirmation toast `[ASSUMPTION]` "Carte repostée dans le fil." |
| Back picker | "Vous seul le voyez, sur vos cartes face cachée à l'ouverture." · "DOS VERROUILLÉ" · "DOS ÉQUIPÉ" · "« Aurore » apparaîtra sur vos cartes face cachée." |
| Profile visibility | "Visible par tous les joueurs" · "Visible par vos amis seulement" · "Profil privé : vous seul le voyez" |
| Settings | "PRÉPARATION…" · "EXPORT PRÊT" · delete word: "SUPPRIMER" ("DELETE" in English) |
| Share and copy | "COPIÉ ✓" · `[ASSUMPTION]` "Copiez le lien manuellement." |
| Public page | "Vos jeux Steam, en cartes à collectionner." · "Ouvrez des boosters, complétez des sets, échangez avec vos amis." · "LIVE · En ce moment sur gameble" |
| Sign-in panel | "CONNECTEZ-VOUS POUR JOUER" |
| PLUS | "Le reste du vaisseau" |
| Links | "(nouvel onglet)" |

`[ASSUMPTION]` Shorter phone labels are allowed where the mock uses them ("ÉCHANGER", "SIGNALER CE PROFIL", "SUPPRIMER", "PROFIL"). The English copy is not written yet; it follows the same rules.

## Component Patterns

Behavior only. Visual specs live in `DESIGN.md` (see Components), under the same names and in the same order.

### Primitives

| Component | Behavioral rules |
|---|---|
| Buttons | One primary per view. A pressed button gives visual feedback at once. A disabled button states its reason in words next to it. |
| Link | Links that leave gameble or open a new tab say so in their accessible name (see Copy deck, Links). |
| Tabs and filters | One choice at a time, `aria-pressed`. Changing a filter re-lays the grid and keeps focus on the filter. |
| Modal | One level deep. Named by its title; initial focus on its first control, never on "✕" (named "Fermer"). Esc or the scrim closes it; focus returns to the opener. Phone: a bottom sheet (the card picker full height). |
| Toast | Confirms an action and is never the only place an error appears. Shown at least 5s plus 1s per 10 words; pauses on hover and focus; has a close button; announced politely. |
| Text field | Errors appear on the line below until the next edit. |
| Radio list | One choice; arrow keys move within it. |
| Steam sign-in | The official image opens Steam's sign-in (its accessible name says so). On return the player lands on the hub. |

### Cards

| Component | Behavioral rules |
|---|---|
| Card face | Tilts toward the pointer, or under a finger held still for 150ms on the phone; vertical drags scroll the page. Opens the card detail where it makes sense. |
| Face-down card | One activation (click, tap, Enter, Space) reveals its rarity and game together. Wears the player's active card back. Accessible name: see Copy deck. |
| Revealed card | Ignores activation for 400ms after its flip. Then, desktop: opens its card detail in the collection. Phone: tap, swipe or "RANGER" stores it in the tray. |

### Chrome

| Component | Behavioral rules |
|---|---|
| Rarity counter | Copies owned per rarity; a count updates as each card is revealed, never before. Activating it opens the "RARETÉS" legend (icon, name, count per tier); Esc or a second activation closes it. |
| Packs chip | Reserve count and the countdown to the next booster, or "Réserve pleine" at 10. Opens the booster screen. |
| Player chip | Opens Profil et paramètres. |
| Menu item | Opens its screen. Keys 1 to 6 open the matching item only while focus is inside the menu (`aria-keyshortcuts`). Coming back to the hub focuses the item last used. |
| Count badge | Boosters in reserve (lime); trades waiting for the player (orange). Grayed at zero in the menu; hidden at zero in the tab bar. Its number is part of the item's accessible name. |
| Back button | Returns to the hub (desktop) or the parent view (phone). Disabled during an opening. |
| Tab bar | Switches between the five roots. Disabled during an opening. Hidden on the public card page. |
| PLUS rows | Open Amis, Fil d'activité, Succès, Profil et paramètres. |

### Hub

| Component | Behavioral rules |
|---|---|
| Showcase | The player's latest pull of Épique rarity or better `[ASSUMPTION: threshold as mocked]`. "VOIR LA FICHE" opens its card detail. Empty showcase: its copy (see Copy deck) and "OUVRIR UN BOOSTER", which opens the booster screen. |
| Community goal panel | The shared weekly gauge for all players, the count and the reward. Fills with every booster opened and, a little, with trades. States: see State Patterns. |
| Daily booster panel | "RÉCUPÉRER" sends one booster into the reserve (a small canister flies to the packs chip; on the phone, to the BOOSTER tab). Then "PROCHAIN DANS" with a countdown to the day change (midnight UTC). At 10 boosters the button is disabled, with the full-reserve state and line, until a booster is opened. Signed out: opens the sign-in panel. |
| Set progress row | Opens the collection filtered on that set (hub) or filters the grid (collection). |
| LIVE ticker | Scrolls notable activity: pulls of Épique or better, trades, set completions, hourly totals `[ASSUMPTION: thresholds and the last two kinds as mocked; the spec lists pulls, first discoveries and trades]`. New items join at the loop boundary. Pauses on hover and focus; stops with "Animations réduites". Hidden from assistive technology (the feed carries the same events). |

### Booster

| Component | Behavioral rules |
|---|---|
| Booster canister | Click, tap, Enter, Space or "OUVRIR LE BOOSTER" sends the opening request; the trigger locks until the answer (see Opening protocol). Disabled when the reserve is empty. |
| Booster information panel | Reserve, pips, status light and word, revealed counter. "+1 dans …" becomes "Réserve pleine" at 10. |
| Tout révéler | Reveals the remaining cards one after another (on the phone, also stores each in the tray). A Légendaire plays its full sequence; the others wait. |
| Ouvrir le suivant | Enabled once all five cards are revealed. The cards sink away and a new canister docks in. |
| Result banner | Plays on an Épique (small) and a Légendaire (large). Decorative: the booster live region carries the result. |
| Reveal caption plate | Phone: shows the top card's rarity, title and year once revealed; hosts the Épique and Légendaire banners. Never covers the card. |
| Tray | Phone: receives each stored card in order, "CARTE n / 5". A filled slot opens the card zoom. |
| Card zoom | Phone: shows the stored card large; "VOIR LA FICHE" opens its detail; "FERMER" or Esc returns to the booster with focus on the slot. |

### Collection

| Component | Behavioral rules |
|---|---|
| Card detail | Title, publisher, rarity, genre, year, short description, minted season, sets, copies owned. "VOIR SUR STEAM" opens the store page in a new tab (said in its accessible name). "PARTAGER" opens the share sheet; absent for a card not owned. Phone: ◀ ▶ buttons and swipe move to the previous or next card. |
| Missing-card slot | Shows the missing game's name and year; opens the card detail with the faded active card back. |
| Copy badge / NOUVEAU tag | "x3" shows copies owned. "NOUVEAU" marks cards obtained since the player last saw them `[ASSUMPTION: cleared once seen]`. |
| RAPPORT panel | Totals and copies per rarity. Folds on the phone; the fold toggle announces whether it is expanded. |
| Share sheet | Copies the link on opening and says so ("COPIÉ ✓", announced politely). The link's preview on Discord, X and WhatsApp shows the title and rarity, never the image. "VOIR LA PAGE PUBLIQUE ▸" opens the public card page. |

### Échanges

| Component | Behavioral rules |
|---|---|
| Trade list row | Three groups: "EN ATTENTE DE VOUS", "EN ATTENTE DE LEUR RÉPONSE", "TERMINÉS RÉCEMMENT". Opens its trade board. |
| Trade board | A proposal holds an offer and a request. At most 4 different cards per side. Actions by state: see State Patterns. |
| Add slot | Opens the card picker for its side. |
| Remove | Removes that card (all its copies) from the side. |
| Card picker | The player's side lists the player's cards with copies owned and reserved elsewhere; the friend's side lists the friend's collection. Picking adds a card with 1 copy; a fifth card is refused inline (see Copy deck, Trade refusals). "PLACER" commits, "ANNULER" discards. The grid is one tab stop with arrow keys inside. |
| Quantity stepper | A spinbutton shown when more than one copy is available. The player's maximum is copies owned minus copies reserved in other trades; the friend's maximum is what they own. Keys: arrows or + and −. |
| Stack | Several copies of one card; moves as one unit in the swap. |
| Reserved tag | Copies held by a proposal waiting for an answer. A fully reserved card cannot be picked. |
| Status chip | Names the state in words; never relies on color alone. |

### Amis

| Component | Behavioral rules |
|---|---|
| Invite panel | "COPIER" copies the invite link. The code field accepts the format of the codes in use (for example "HUGO-7K2Q", "KAI-8F2D") `[ASSUMPTION: 3 to 5 characters, a dash, 4 characters, as mocked]`, submits on Enter and answers on the line below. A valid code sends an invitation. |
| Invitation row | Received: "ACCEPTER" creates the friendship for both; "IGNORER" dismisses it. Sent: "EN ATTENTE" until answered. The invite link sends an invitation the same way `[ASSUMPTION]`. |
| Friend row | Shows the friend's presence (see Copy deck, Presence). The avatar or name opens the friend profile; "PROPOSER UN ÉCHANGE" opens the trade already in progress with that friend, or a new draft. |
| Friend profile | A dialog: showcase of three cards `[ASSUMPTION: the three rarest, automatically]`, "PROPOSER UN ÉCHANGE", "SIGNALER". |
| Report dialog | A reason must be chosen before "ENVOYER LE SIGNALEMENT". The reported player never learns who reported them. |

### Fil d'activité and Succès

| Component | Behavioral rules |
|---|---|
| Feed tabs | TOUS shows everyone's events; AMIS shows only the viewer's friends' pulls, trades and reposts. The tab and the type filter combine ("AMIS · TIRAGES" shows friends' pulls). The AMIS tab is read when the screen opens and when it is revisited, not updated live. Signed out, AMIS opens the sign-in panel. A player without friends sees the Friends-tab line and "AJOUTER DES AMIS", which opens Amis. |
| Feed entry | One event per row (also on the public card page). Filters: TOUT, TIRAGES, DÉCOUVERTES, ÉCHANGES, REPOSTS. New entries arrive at the top. A repost is an entry naming the player and the card, tagged "REPOST"; it never appears in the LIVE ticker. |
| Repost action | "REPOSTER" on a card the player owns, in three places: the card detail (beside "PARTAGER"), a revealed card at the end of a booster opening (desktop under the revealed row's card, phone in the card zoom), and the hub showcase under the best card. Any rarity, no limit, no message, reactions or comments. The action posts the repost and confirms with the repost toast; the button stays available (a card can be reposted again). Absent for a card not owned and for a visitor. |
| Achievement tile | Earned or to earn, with progress where countable, and the card back it unlocks if any. |

### Profil et paramètres

| Component | Behavioral rules |
|---|---|
| Settings row | "LANGUE" (FRANÇAIS / ENGLISH) switches at once. "VISIBILITÉ DU PROFIL" (PUBLIC / AMIS UNIQUEMENT / PRIVÉ, default PUBLIC) applies at once. "ANIMATIONS RÉDUITES" follows the system by default. "EXPORTER", "SE DÉCONNECTER", "SUPPRIMER MON COMPTE": see State Patterns. |
| Back picker | Choosing an unlocked card back makes it active at once; a locked one states its condition inline. |
| Delete dialog | The field is labeled with the word to type; "SUPPRIMER DÉFINITIVEMENT" enables once the field holds that word (case-insensitive, paste allowed). |
| Mentions légales link | Opens the legal page (also in the public card page footer). |

### Public pages and sign-in

| Component | Behavioral rules |
|---|---|
| Public card page | The card tilts under the pointer. "VOIR SUR STEAM ↗" opens the store page. "OUVRIR MES PREMIERS BOOSTERS" opens the sign-in panel. The LIVE strip shows the three latest feed entries. |
| Sign-in panel | Holds only its title line (see Copy deck) and Valve's horizontal official button, the only link to Steam's sign-in. "✕", Esc or the scrim returns to the page, still signed out. |

## Opening protocol

1. Activating the canister sends the opening request and locks the trigger: a second activation does nothing, and each request carries an idempotency key.
2. The canister charges ("ARMEMENT", about 300ms of squash) while the answer arrives; this masks the wait.
3. **Success:** LEDs and hazard band turn orange, the caps blow off and the five cards are dealt.
4. **Refusal** (no booster in reserve, or any error): the canister disarms without blowing its caps, the status returns to "SCELLÉ" or "EN ATTENTE", and the reason appears inline under the open button and in a toast. Nothing opens.
5. The art of each card starts loading on the answer; a card never flips before its art is ready or known to be missing.
6. During the opening and each reveal, in-app back controls, the tab bar and Esc navigation are disabled. Browser Back is allowed and loses nothing: the five cards are already in the collection.

## State Patterns

Messages quoted by key are in the Copy deck.

| State | Surface | Treatment |
|---|---|---|
| Signed out | Everywhere | Everything visible. An action that needs an account opens the sign-in panel; closing it returns to the same page, still signed out. |
| First session | Hub, booster | The reserve holds 10 boosters. A Rare or better is guaranteed by the 10th booster, without any visible sign. No booster ever promises a rarity. |
| Reserve full | Hub, booster | 10 pips lit; the countdown is replaced by "Réserve pleine" (packs chip, booster panel). The daily booster claim is disabled until a booster is opened (Copy deck, Daily booster). |
| Special booster in the reserve | Hub, booster | `[ASSUMPTION]` The daily booster (better odds) and the goal's rare booster join the same reserve and open with the same ritual; they are not told apart among the canisters. Whether a goal reward is added above 10 is open. |
| Reserve empty | Booster | The canister is replaced by the empty-reserve line (Copy deck, Booster states); the open button reads "RÉSERVE VIDE" and is disabled. |
| Opening refused | Booster | See Opening protocol, step 4. |
| Opening in progress | Booster | Navigation disabled (see Opening protocol, step 6). |
| Cards dealt | Booster | The reveal hint and the revealed counter (Copy deck, Booster hints and Booster states). |
| Booster inventoried | Booster | The inventoried hint; status "INVENTAIRE COMPLET". |
| Reveal abandoned | Booster | The cards joined the collection at opening; leaving loses nothing; nothing resumes on return. |
| Daily booster ready / collected | Hub | "PRÊT" with "RÉCUPÉRER", then "RÉCUPÉRÉ" with the countdown. A second collection the same day is refused. |
| No notable pull yet | Hub | The empty showcase (Copy deck, Empty showcase). While it shows, the daily booster's "RÉCUPÉRER" turns secondary, so the hub keeps one lime action. |
| Goal in progress | Hub | Gauge, "TOUS LES JOUEURS n / target", reward line. |
| Goal reached | Hub | `[ASSUMPTION]` The gauge is full and the panel reads "OBJECTIF ATTEINT"; every contributor receives the rare booster (and the week's card back, when the goal has one) with a toast; a non-contributor sees the reached state only. |
| Goal missed | Hub | `[ASSUMPTION]` At the week's end the panel shows the final count; nothing is granted. |
| Week rollover | Hub | `[ASSUMPTION]` A new goal with a new target starts at the week boundary; the gauge empties. |
| Image missing / loading | Any card | "IMAGE INDISPONIBLE" in the art box / a dark hatched box until the filtered cover is ready. |
| Collection empty | Collection | Every slot is a missing-card slot naming its game. |
| Filter empty | Collection | The empty-filter line (Copy deck, Collection). |
| Set complete | Collection, hub | `[ASSUMPTION]` The set row shows owned = total; if the set unlocks a card back, a toast announces it. |
| Trade draft | Trade board | "BROUILLON", both sides editable, with the validity line. "ENVOYER LA PROPOSITION" enables once each side holds a card; "ABANDONNER" deletes the draft. |
| Trade waiting for the player | Trade board, list, badge | "À VOUS", the proposal line and the expiry. The friend's offered copies are tagged reserved. Actions: "ACCEPTER", "CONTRE-PROPOSER", "REFUSER". |
| Counter-proposal in progress | Trade board | Both sides become editable, marked "EN ÉDITION", with the counter-proposal line. "RENVOYER LA CONTRE-PROPOSITION" enables once each side holds a card; "ANNULER LES MODIFICATIONS" restores the received proposal, after a confirmation if anything changed. |
| Counter-proposal sent | Trade board | `[ASSUMPTION]` The 7-day expiry restarts; the player's reserved copies become exactly those on the player's side; copies the player removed are released. |
| Trade waiting for the friend | Trade board, list | "EN ATTENTE", the waiting line, the player's copies tagged "RÉSERVÉE". Action: "ANNULER LA PROPOSITION". |
| One trade per pair | Friend row, friend profile | Proposing to a friend with a trade in progress opens that trade, with the one-at-a-time refusal. |
| Not enough copies | Trade board | Accepting when a copy is no longer available: "EXEMPLAIRES INSUFFISANTS" inline and in a toast; nothing moves. |
| Nothing to place | Card picker | `[ASSUMPTION]` The no-card line (Copy deck, Card picker) with the reason (none owned, or all reserved). |
| Trade done | Trade board, list | The swap plays; "CONCLU" and the concluded line; received cards tagged "NOUVEAU". The trade appears in the feed and counts toward the goal. |
| Trade declined, canceled, expired | Trade board, list | "CLOS", with the outcome and its age ("refusé il y a 4 j"). Reserved copies are released. A proposal expires after a fixed 7 days. Action: "NOUVEL ÉCHANGE AVEC LÉA". |
| Friend banned or deleted mid-trade | Trade board, list | `[ASSUMPTION]` The trade closes ("CLOS") and every reserved copy is released. |
| Invite code invalid / own / repeated / sent | Amis | The matching line (Copy deck, Invite code messages). |
| Invitation received / accepted / ignored | Amis | Received: the invitation row with "ACCEPTER" / "IGNORER". Accepted: the "NOUVEL AMI" toast and the friend in the list. Ignored: the row disappears. |
| No invitation | Amis | The no-invitation line (Copy deck, Friends). |
| No friend, no trade | Amis, Échanges | `[ASSUMPTION]` One line pointing to the invite panel. Not mocked. |
| Friend presence | Amis, menu 04 | Online, current activity, or last seen. |
| Quiet feed | Fil d'activité, ticker | With few players, lower-tier pulls fill in on a quieter background. Never empty while any activity exists. |
| Feed filter empty | Fil d'activité | The empty-filter line (Copy deck, Feed). |
| Profile visibility | Profile, public pages | PUBLIC: anyone, signed out included, sees the profile and its shared cards. AMIS UNIQUEMENT: friends only. PRIVÉ: nobody else. The summary states it. |
| Profile not visible to this visitor, or banned | Public card page, public profile, friend profile | `[ASSUMPTION]` The page says the profile is not available. |
| Card back locked / equipped | Back picker | Locked: the condition inline and the "DOS VERROUILLÉ" toast. Equipped: the preview turns to the new card back; the "DOS ÉQUIPÉ" toast. |
| Export | Profil et paramètres | `[ASSUMPTION: asynchronous, as mocked]` "PRÉPARATION…" on the button, then the "EXPORT PRÊT" toast with the download; a failure says so inline with a retry. |
| Sign out | Profil et paramètres | Lands on the hub in signed-out mode. |
| Account deleted | Delete dialog | `[ASSUMPTION]` Lands on the signed-out hub with a toast confirming the deletion. |
| Language switched | Profil et paramètres | The interface and card text change at once; `<html lang>` follows. |
| Clipboard refused | Share sheet, invite panel | `[ASSUMPTION]` The link stays selected in its field with the manual-copy line inline. |
| Cold load | Every screen | `[ASSUMPTION]` Panels appear as their data arrives; counts show "—" until known. Not mocked. |
| Network or server error | Everywhere | `[ASSUMPTION]` Inline where the action was, and a toast; nothing was lost; the screen stays usable. Not mocked. |
| Banned account | Steam sign-in | `[ASSUMPTION]` Sign-in is refused with a one-line explanation (spec CAP-15). Not mocked. |
| Not staff | Back-office | `[ASSUMPTION]` The address answers as if it did not exist. |
| Phone held sideways | Every screen (phone) | Nothing happens (see Responsive & Platform). |

## Interaction Primitives

- **One activation reveals:** click, tap, Enter or Space on a face-down card reveals rarity and game together. One surprise per card.
- **Guard:** a just-revealed card ignores activation for 400ms, so a double activation never skips the reveal or leaves the screen.
- **Tilt:** cards lean toward the pointer, up to about 10° (16° in the booster); on the phone only under a finger held still for 150ms. Cards in scrolling content keep vertical panning (`touch-action: pan-y`); only the booster stage captures every gesture.
- **Hover is a lift; touch is a press.**
- **Swipe, always with a button:** on the phone a revealed card swipes into the tray ("RANGER" does the same); in the card detail, swipe or the ◀ ▶ buttons move between cards. Long-press is never required.
- **Keyboard:** Tab order follows reading order. Keys 1 to 6 open menu items only while focus is in the hub menu. Arrow keys move focus within the collection grid (Up and Down move one row, whatever the column count), the card picker grid, and radio and segmented groups; in a stepper they change the quantity. Enter submits the friend code.
- **Esc:** closes the topmost overlay (dialog, sheet, zoom, legend, toast) and nothing else. With no overlay open, it cancels a counter-proposal edit after confirmation. Otherwise, when no edit is pending and no text field has focus, it returns to the hub (except during an opening).
- **Not in the MVP:** bulk opening, live trades, card marks, a guide, and any input at opening that improves the odds (noted for later).

## Motion

Movement is fluid at 60fps (transforms and opacity only; continuous loops never animate layout or background position). Small effects tick in steps. Only genuinely live things blink (the LIVE marker, once per second). Short and snappy everywhere. Opening and reveal timings are those of the "Arcade" opening study, multiplied by 1.18. Easings: `{components.motion.ease-out}`, `{components.motion.ease-lock}`, `{components.motion.ease-spring}`.

| Moment | Duration | What happens |
|---|---|---|
| App start | 340ms, once per session | A brief power-on brightening of the screen (overshoot capped at 1.1). |
| Screen change | about 300ms | The old screen slides 32px away and fades (170ms); the new one slides in from 48px (260ms, 40ms later); the star field shifts sideways (1.1s). Panels lock into place with a short overshoot, staggered over 400ms at most. |
| Phone sub-view | 260ms in, 200ms out | Slides over its screen. |
| Phone sheet | 240ms | Rises from 60px. |
| Canister at rest | loop | Breathes 2px over 6s; a light band sweeps across it; rays turn slowly behind it. |
| Booster opening (Explosion A) | about 1.2s | ARMEMENT squash while the request runs, then LEDs and hazard band orange, the caps blow off up and down with smoke jets ("ÉJECTION"), a ring, one short warm flash and a shake. Desktop: the five cards burst out in an arc and land in a row, 45ms apart, squashing with a little dust. Phone: they land as a stacked pile, bottom card first, with 5px offsets, ±1.4° tilt and 1.5 times the desktop stagger. |
| Reveal, Commune | about 0.7s | A small lift, a flip with overshoot, a burst of pixels in the tier color, a settle. |
| Reveal, Peu commune | about 0.8s | A short tremble first, one ring, a slightly bigger burst. |
| Reveal, Rare | about 1.0s | Longer tremble, ring, bigger burst with confetti, holo on the face. |
| Reveal, Épique | about 1.2s | Tremble with particles converging, two rings, purple rays, small "ÉPIQUE" banner. |
| Reveal, Légendaire | about 2.45s | The stage dims ("SIGNAL LÉGENDAIRE", gold light); the card jumps up and charges (on the phone the jump stays inside the play area, 50px at most); a one-and-a-half spin; impact with a gold and confetti burst, three rings, a gold fan of rays, one flash and a strong shake; banner "LÉGENDAIRE !" with title and year; the card drops back with a bounce. |
| Tout révéler | about 180ms between cards | Each card plays its own tier reveal; a Légendaire plays in full before the next. Flashes never overlap: at most one full-screen flash per sequence. |
| Tray (phone) | 260ms | A stored card shrinks into its slot; the slot pops; an Épique or better adds a spark burst. The caption plate pops in 320ms (380ms for a Légendaire). |
| Next booster | about 0.5s | The cards sink and fade (160ms, staggered); a new canister rises into place (260ms). |
| Idle float | 14s loop | Showcase card, planet, detail card, public card and back preview drift 2px at most with ±0.5° rotation over a breathing ground shadow. |
| Card detail re-entry | 260ms | The card turns slightly as it comes in. |
| Daily booster | 480ms (phone 520ms) | A small canister arcs to the packs chip (phone: the BOOSTER tab); the count brightens. |
| Trade swap | about 0.75s | Both sides' cards arc across the central strip, one over, one under, squash on landing; a ring and confetti at mid-point; a faint flash. Stacks travel as one. |
| Card back equip | about 0.35s | The preview turns edge-on and back as the new card back; the tile hops; a small burst. |
| Locked card back | 220ms | A short sideways shake of the tile. |
| Toast | 250ms in | Rises into place. |
| Dialog | 160ms scrim, 220ms panel | The panel rises 16px into place. |
| Feed entry | 280ms | Slides down from the top. |

**Reduced motion.** Applies when the system asks for it or when "ANIMATIONS RÉDUITES" is on in Profil et paramètres (default: follow the system). The rule: nothing translates, rotates, scales, shakes, flashes, blinks, sweeps or loops; state changes are 150 to 220ms crossfades; the ticker stops and shows its latest items still; the LIVE marker stays lit; the star field, rays, holo, sheen, canister breathing and idle floats stop; flashes are removed (not dimmed); tilt is off. Exceptions, spelled out:

- **Opening:** the canister fades out in 200ms and the cards fade in (240ms, 40ms apart).
- **Reveal:** each card crossfades to its face in 220ms; a Légendaire shows a still "LÉGENDAIRE !" banner for 1.4s instead of its sequence.
- **Trade swap:** the two sides crossfade to their new contents.
- **Locked card back:** no shake; the condition appears inline.
- **Screen changes, sheets, sub-views, toasts, feed entries:** instant or crossfaded, no slide.
- **App start:** no brightening.

## Card backs

- **What it is:** the image on the player's own face-down cards at opening, and the faded image of a card not owned in the card detail. Only the player sees it. Every account starts with "Standard".
- **Earning:** product rules (completing a set, a successful community goal, some achievements, events or seasons) are listed in `ux-gameble.md`.
- **Choosing:** one active card back at a time, in Profil et paramètres; it applies from the next booster, including when chosen during an opening.
- **Locked card backs** are listed with their unlock condition ("Compléter le set Roguelite · vol. 1"); an achievement that unlocks one shows it on its tile.
- **The prototype's eight** are examples; the shipping list is open (see `DESIGN.md`, Card backs).

## Accessibility Floor

Behavior only. Contrast values live in `DESIGN.md` (see Colors).

- **Keyboard:** every action works with the keyboard; focus order follows reading order; the focus ring (`{components.focus-ring.css}`) shows on every focusable element, distinct from hover; scroll padding keeps it clear of sticky bars. Focus destinations: see Focus after each step.
- **Screens and dialogs:** inactive screens are inert and hidden from assistive technology; each screen has one h1, a main region and a navigation region; dialogs are named by their title, trap focus and return it on close.
- **Booster live region:** a dedicated polite region announces each reveal (Copy deck, Booster live region). "Tout révéler" posts one summary of the cards it revealed. A Légendaire posts its signal at the start and the result on landing. Opening refusals are announced there too.
- **Feed and ticker:** the feed list is not a live region; while the feed is not focused, a status line announces new entries in batches at most every 30s; with "ANIMATIONS RÉDUITES" on, these announcements stop. The ticker is hidden from assistive technology.
- **Toasts** are polite status messages; errors also stay inline until the next action.
- **Rarity** is never carried by color alone: shape and name accompany it; where only the icon fits (rarity counter, tray, thumbnails), the name is in the accessible name and in the "RARETÉS" legend.
- **Card text order:** title, publisher, year, genre, rarity, number, then state (copies, NOUVEAU, reserved count). Cover canvases, thumbnails, rays and particles are hidden from assistive technology; avatars have empty alt text next to a visible name; rarity icons are hidden when the name is beside them.
- **Gauges** are progress bars with a text value. Countdowns are not live; their accessible text changes at most once a minute.
- **No information only in a tooltip** (`title`).
- **Moving content:** the ticker pauses on hover and focus and stops with "ANIMATIONS RÉDUITES"; every looping or blinking effect stops with it; nothing blinks faster than once a second.
- **Touch:** at least 44 × 44 CSS px for every phone target, 8px apart.
- **Readability:** no meaningful information below 10px in the pixel fonts; `{colors.dim}` is decorative only.
- **Zoom and text spacing:** breakpoints are in CSS px of the viewport, so browser zoom reaches the phone layout; text is in rem; text rows use a minimum height so user text spacing never clips them.
- **Language:** `<html lang>` follows the chosen language; text in another language (a Steam description) carries its own `lang`. `[ASSUMPTION]` A first visit uses the browser's language.
- **Links and sign-in:** links that open a new tab or leave gameble say so; the Steam image's accessible name says it opens Steam.

### Focus after each step

| Step | Focus goes to |
|---|---|
| Booster screen opened | "OUVRIR LE BOOSTER" (or "◀ PONT" when the reserve is empty) |
| Cards landed | Card 1 |
| A card revealed | Stays on that card |
| All five revealed (one by one or with Tout révéler) | "OUVRIR LE SUIVANT" |
| Card stored in the tray (phone) | The next card, or "OUVRIR LE SUIVANT" after the fifth |
| Card zoom closed | Its tray slot |
| Trade board opened | The board heading |
| "CONTRE-PROPOSER" | The add slot on the player's side |
| Card removed with "✕" | The next card on that side, or its add slot |
| Card picker closed | The add slot that opened it |
| Swap finished | The board's status line |
| Sub-view opened (phone) | Its heading |
| Back or dialog closed | The element that opened it |
| Return from Steam sign-in | The hub's first menu item (phone: the PONT heading) |

## Responsive & Platform

The layout rules (no scaling, page scroll, breakpoints at 720 and 1180px, content capped at 1280px `[ASSUMPTION: exact value; decided "below 1440px"]`, per-screen reflow, collection grid sizing, phone column) live in `DESIGN.md` (see Layout & Spacing). Tablets follow the width rules. Behavior specific to each form factor:

- **Desktop:** the card detail is a right-hand panel; dialogs are centered; toasts appear at the bottom. After a resize, the collection grid re-measures its cards and re-runs the pixel filter at the rendered size, and the booster stage re-lays dealt cards in place without replaying.
- **Phone:** portrait only; held sideways, nothing changes, and the installed web app declares `"orientation": "portrait"` in its manifest (a browser tab cannot be locked). Document scroll; sub-views slide over their screen; dialogs are bottom sheets; toasts appear at the top; safe areas are respected. Checked at 390 × 844 and 360 × 740.
- **Hub on the phone:** kicker, packs chip and rarity counter, showcase, community goal panel, daily booster panel, set progress rows, LIVE ticker. The menu lives in the tab bar and the PLUS rows (no numbers).
- **Booster on the phone:** the cards land as a pile; one large card at a time; tap to reveal; the caption plate shows rarity, title and year; tap, swipe or "RANGER" stores the card in the tray; "Tout révéler" reveals and stores the rest; a filled slot opens the card zoom.
- **Collection on the phone:** two columns with the publisher visible; set and genre chip rows; the RAPPORT panel folds; the card detail slides over with "◀ GRILLE", ◀ ▶ buttons and a position line.
- **Trades on the phone:** the list first; the trade board slides over ("◀ LISTE") with the friend's side on top and actions pinned at the bottom; the card picker is a full-height sheet.
- **Browsers:** the modern-browser floor of the architecture (AD-27); the public pages a link opens also serve older browsers. Native store apps stay possible later.

## Inspiration & Anti-patterns

Visual inspirations and rejections live in `DESIGN.md` (see Brand & Style and Do's and Don'ts). Behavioral ones:

- **Lifted from the "Arcade" opening study:** card burst, bounce landing, tiered reveals and the Légendaire sequence.
- **Lifted from the author's canvas (`imports/claude-design-concepts/`):** the hub with its numbered menu as the only navigation.
- **Rejected — the medieval direction's navigation through scenery objects** ("looks cheap"), and a permanent sidebar: replaced by the hub.
- **Rejected — dust and two surprises per card:** one activation reveals everything.
- **Rejected — the stratagem-like arrow code to open a pack.**
- **Rejected — the generator's filler mechanics:** combat, decks, card stats, market, sales, currencies, recycling.
- **Rejected — a guide, and opening every booster at once.**

## Key Flows

### Flow 1 — First session (Léa, on her PC, clicks a link Hugo posted on Discord)

1. Léa clicks Hugo's link. Discord's preview showed the card's title and rarity, no image.
2. Signed out, she lands on the public card page: Hollow Knight large and tilting under her pointer, its publisher, "LÉGENDAIRE", genre, year, number, the short description and "VOIR SUR STEAM ↗".
3. Below, the LIVE strip shows pulls and trades with their rarities. She can open the feed and browse the sets, all slots empty.
4. She presses "OUVRIR MES PREMIERS BOOSTERS". The sign-in panel opens with its title line and Valve's official button; she signs in with Steam.
5. She lands on the Pont de commandement. The packs chip reads 10 BOOSTERS with "Réserve pleine"; menu 01 carries a lime "10"; the empty showcase invites her to open her first booster.
6. She opens the booster screen and activates the canister: it charges, the caps blow off, five cards land face down wearing the Standard card back.
7. She reveals one: a Commune, announced as she sees it. She reveals the next, then presses "TOUT RÉVÉLER" for the rest.
8. "OUVRIR LE SUIVANT". Booster after booster, the rarity counter ticks up.
9. **Climax:** before her tenth booster ends, a card trembles, rings and bursts in blue light: a Rare or better, the first prize her collection holds.
10. The reserve runs out and the booster screen shows when the next one arrives. She goes back to the Pont, opens 02 and browses her sets: owned cards with "NOUVEAU", missing ones naming the game and its year.
11. The next day, the daily booster panel says "PRÊT"; she collects it and opens it.

Failure: she closes the sign-in panel or Steam refuses → she stays on the public card page, signed out.

### Flow 2 — A trade with quantities (Hugo and Léa, a few days later)

1. Léa entered Hugo's code HUGO-7K2Q in Amis; Hugo saw her invitation and pressed "ACCEPTER". They are friends.
2. In Amis, Hugo presses "PROPOSER UN ÉCHANGE" on Léa's row. The trade board opens as "BROUILLON".
3. "CHOISIR SES CARTES": from Léa's collection he picks Disco Elysium, one copy.
4. "PLACER MES CARTES": he picks Slay the Spire; he owns three, so a stepper appears; he sets ×2 ("/3") and presses "PLACER". His side shows a stack with "×2" and "1 carte · 2 ex.".
5. "ENVOYER LA PROPOSITION". The "PROPOSITION ENVOYÉE" toast confirms; his two copies are tagged "2 RÉSERVÉES".
6. That evening on her phone, Léa sees an orange "1" on the ÉCHANGES tab. The trade board slides over: "À VOUS", Hugo's proposal, "Expire dans 7 j".
7. She wants to keep Disco Elysium. "CONTRE-PROPOSER": both sides open ("EN ÉDITION"). She removes Disco Elysium from what she gives, places Dead Cells ×2, and on Hugo's side lowers Slay the Spire to ×1. "RENVOYER LA CONTRE-PROPOSITION".
8. Hugo sees the orange badge on 03 ÉCHANGES, opens the trade and presses "ACCEPTER".
9. **Climax:** the two stacks arc across the central strip, one over, one under, and squash as they land; a ring and confetti burst between them. The "ÉCHANGE CONCLU" toast: Dead Cells ×2 joins his collection, tagged "NOUVEAU".
10. The trade appears in the feed and the LIVE ticker and counts a little toward the community goal.

Failure: Léa refuses, Hugo cancels, or 7 days pass → "CLOS", reserved copies released. If a copy is no longer available when Hugo accepts → "EXEMPLAIRES INSUFFISANTS", nothing moves.

### Flow 3 — Equipping a card back earned by completing a set (Inès, after a lucky week)

1. Inès reveals the last missing card of "Roguelite · vol. 1". The set row reaches 30/30 `[ASSUMPTION: a toast announces the back "Aurore"]`.
2. From her player chip she opens Profil et paramètres. In "DOS DE CARTE", Aurore is no longer grayed.
3. She chooses it: the preview turns to Aurore, "DOS ACTIF"; the "DOS ÉQUIPÉ" toast.
4. **Climax:** at her next booster, the five cards land face down under an aurora sky. Only she sees it.

Variants: she completes the set through a trade rather than a booster → the card back unlocks the same way. She chooses it while a booster is open → it applies to the next one.

### Flow 4 — Sharing a pull (Hugo, right after a Légendaire)

1. Hugo's booster ends on a Légendaire: Hollow Knight. He activates the revealed card; its card detail opens.
2. "PARTAGER": the share sheet copies the link ("COPIÉ ✓").
3. He pastes it in his friends' Discord channel.
4. **Climax:** Discord unfurls the preview with "Hollow Knight" and "Légendaire", without the game image; his friends click through to the public card page (Flow 1).

Failure: the clipboard is refused → the link stays selected in its field with the manual-copy line.

## Implementation notes

Build rules found while prototyping and reviewing; they bind the build. Architecture-level items are listed in `ux-gameble.md` (see For the architecture).

- **Mocks are never source code.** Port the look and the timings, not the scripts. Listeners and timers are registered when a component connects and removed when it disconnects; caches are bounded.
- **Tokens are CSS values.** Use the exact values in `DESIGN.md` frontmatter (pixel outlines, borders, bevels, scanlines) as custom properties.
- **3D card stack:** never put 3D transforms on a `<button>` that holds card faces, and never put a grouping property (opacity below 1, filter, overflow, clip-path, mask, mix-blend-mode, isolation) on or between the tilt and flip layers: either one flattens the 3D and shows the mirrored back. Use plain layers (tilt, then flip), both faces with `backface-visibility: hidden`, and a flat transparent button on top for focus and activation. One reveal path for a single activation and for "Tout révéler". A visual regression test covers a tilted, revealed card.
- **Hide every descendant of an inactive screen,** not only the screen: a child made visible on purpose (a dealt card) otherwise shows through.
- **Content timing:** card content reaches the browser when the booster is opened; the reveal is only an animation; counters update at each reveal so the interface never spoils a card.
- **Dialogs and Esc:** every modal and bottom sheet is a native `<dialog>` opened with `showModal()`, in Stimulus and React; the hotkeys controller ignores events already handled, events while a dialog is open and events from form fields, so one Esc never both closes a dialog and navigates. Single-key shortcuts can be turned off.
- **No inline style:** server HTML carries no `style` attribute (the CSP blocks it); progress bars and gauges get their values as CSS custom properties set by a controller.
- **Large grids:** a collection grid beyond about 60 slots is paginated or virtualized, and only visible cards are filtered.
- **Fonts:** the three font files are preloaded with `font-display: block` and a short block period, so a fallback swap never reflows two-line card titles.
- **Daily booster arc:** runs from `turbo:before-stream-render` (both positions known before the DOM is replaced) and dispatches `gameble:bank-changed`.
- **Daily bonus booster:** it holds 3 cards, so the revealed counter and hints count to 3 for it ("Cartes révélées : n / 3").

## Open questions

Non-blockers, left open.

- **Achievements:** the mock's 40 are illustrative; which exist, and which unlock card backs.
- **Card backs:** which ship, and whether every successful community goal grants one.
- **Ticker events** beyond CAP-13 (set completions, hourly totals) and the ticker and feed thresholds.
- **Special boosters:** whether the daily and goal boosters look different in the reserve, and whether a goal reward can exceed 10.
- **Weekly goal lifecycle:** where the week boundary shows, and the reached, missed and rollover states (tagged above).
- **Unmocked states:** cold load, offline, network error, banned account, non-staff back-office.
- **Public profile page** (CAP-8) and the **signed-out hub** are not mocked.
- **Avatars:** the source (Steam avatar through the pixel filter?) is not decided.
- **English copy** and English rarity names are not written.
- **Skip control:** whether a "Passer" control (and Esc) jumps an opening or reveal sequence to its end state (accessibility review M11).
