---
name: gameble
status: final
created: 2026-10-01
updated: '2026-10-20'
sources:
  - ../spec-gameble/spec-gameble.md
  - ../spec-gameble/catalog-and-rarity.md
  - ../spec-gameble/brotherhood-tone.md
  - ../spec-gameble/lore.md
  - ../brief-gameble/brief-gameble.md
---

# gameble — Experience Spine

## Foundation

A responsive web game for desktop and phone (portrait only), in French and English. Every flow works on both form factors; the layouts differ: a hub with a numbered menu on desktop, a bottom tab bar on the phone. This document names no UI component library: the stack renders pages on the server and embeds interactive components for the capsule opening and the trade board (see the spec's architecture and `ux-gameble.md`, For the architecture). `DESIGN.md` is the visual identity reference; this document is the experience. Tokens are referenced by name, for example `{colors.accent}`; component names are the same in both documents.

Visual references: [mockups/key-screens.html](mockups/key-screens.html) (desktop prototype: every screen, the chosen "Explosion A" opening on the capsule screen, the signed-out public card page), [mockups/mobile.html](mockups/mobile.html) (phone prototype) and [mockups/landing.html](mockups/landing.html) (the visitor landing, desktop and phone, with its motion and reduced-motion form; its REVUE toolbar and note pins are a review aid, not part of the design). DESIGN.md and EXPERIENCE.md take precedence over any mock when they conflict. The mocks are a reference for look and timing, never source code. Their sample data (a 16 480-card season, three-hour timers, demo odds, a scripted first capsule) is illustrative; the spec's numbers rule.

In this document, "capsule" is the player-facing word for the spec's "pack", and "réserve" for its "bank". In the lore (`../spec-gameble/lore.md`), each card is an archive card in the Brotherhood's proprietary format and this space-terminal interface is its authorized archive card reader; the interface still says "carte". Items tagged `[ASSUMPTION]` are not confirmed in the decisions log. Open questions close the file.

## Information Architecture

| Surface | Reached from | Purpose |
|---|---|---|
| Landing | /fr and /en signed out (signed in, they open the hub: a signed-in player never sees the landing; author, 2026-10-14, triage); the GAMEBLE link signed out; after sign-out; after account deletion; "Découvrir" on the public card page (author, 2026-10-14) | The signed-out root: the Brotherhood's mission, what the game is, how it works, what happens live, what there is to do and unlock, the roadmap, open source and contributions, a free game and its support, then the call to sign in |
| Pont de commandement (hub) | /fr and /en signed in; Steam sign-in's return; the top bar's GAMEBLE link from any desktop screen (signed in); PONT tab. Signed out: "Embarquer sur le pont" (landing hero, public card page) and the final call's hub link | Status at a glance and the way to everything else |
| Ouverture de capsule | Menu 01, the capsules chip, the CAPSULE tab, the empty showcase | Open one capsule at a time and reveal its five cards |
| Collection | Menu 02, "TOUT VOIR ▸" on the hub, COLLECTION tab | Search every set, reach every card, see the sets being completed |
| Set album | A set progress row (collection, hub, search), a set in the card detail, a public profile | One set's cards in order, its missing cards and its tiers or completion |
| Toutes les cartes | Menu 03 (signed in and signed out; author, 2026-10-20), "TOUTES LES CARTES ▸" in the collection, a PLUS row on the phone | The game's catalog: every card of the published season with its face, owned or not, with FILTRES and the search; a signed-in player's cards not owned set apart, a visitor's all plain; later the trade and sale view |
| Card detail ("FICHE DE LA CARTE") | A card in the collection, a revealed capsule card, the showcase's "VOIR LA FICHE", the card zoom, a VITRINE card on a public profile | Full card facts, Steam link, share, the profile showcase choice |
| Seasonal allocation (after the launch) | The first visit after a season is published, before the hub; the hub and the capsule page lead there while it is unseen | What the ended season gave and the sets that follow into the new one |
| Share sheet | "PARTAGER" in the card detail | Copy the share link, open the public page |
| Échanges | Menu 04, "ÉCHANGE" on a friend row, friend profile or public profile, "NOUVEL ÉCHANGE" at the top of the trade list, ÉCHANGES tab | Trade list and trade board |
| Card picker | "PLACER MES CARTES" / "CHOISIR SES CARTES" on the trade board | Choose cards and copies for one side |
| Amis | Menu 05; PLUS on the phone | Invite by link or code (an invitation can also be sent from a public profile), answer invitations, list friends with their presence |
| Friend profile | A friend row | Propose a trade, open their profile or their full collection, report |
| Report dialog | "SIGNALER" in a friend profile or on a public profile | Report a username or profile |
| Fil d'activité | Menu 06; PLUS on the phone; "Ouvrir le fil d'activité" in the landing's live module; open without an account | Pulls, first discoveries, trades, reposts, set tiers and completions; tabs TOUS and AMIS (friends only) |
| Succès | Menu 07; PLUS on the phone | Achievements, earned and to earn |
| Comment ça marche | Menu 08; PLUS on the phone; open without an account | The rules of the game: which games become cards, rarity, the odds of each capsule, capsule timing, the daily capsule, the weekly goal's reward, seasons, sets and their completion; every number read from what the game applies |
| Profil et paramètres | The player chip; PLUS on the phone | Public profile summary, settings, card-back picker, "Mentions légales" |
| Public card page | A shared link, without an account | Show the shared card and invite the visitor to play; "Découvrir" leads to the landing, "Embarquer sur le pont" to the signed-out hub |
| Public profile | A player's link; "VOIR LE PROFIL" in a friend profile | Show off a player: identity, showcase, stats, achievements and started sets, and reach their full collection; shown per their visibility (spec CAP-8), a private profile never (author, 2026-10-15) |
| Full collection (another player's) | "VOIR LA COLLECTION COMPLÈTE" on a public profile; "VOIR LA COLLECTION" in a friend profile | That player's collection as the viewer's own collection screen shows it (sets and all cards, search and filters), read-only, on the owner's cards; it takes the place of the set index the public profile used to open on (author, 2026-10-15) Cards that player does not own show as Card not owned, judged by their holdings (author, 2026-10-20). |
| Sign-in panel | Any game-styled action that needs an account | One title line and Valve's official Steam sign-in button |
| Steam sign-in | The official image, wherever it appears | Create or reuse the account (Steam's own page) |
| Legal page | "Mentions légales" in Profil et paramètres, the public page footer and the landing footer | No-affiliation notice, ownership notice ("Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons."), terms of use, privacy notice |
| Soutenir | Menu 09; PLUS on the phone; "Soutenir" in the landing's module 08 and footer; open without an account | The donation page, on another site, in a new tab (the same link as the legal page and Profil et paramètres); optional, it gives no advantage in the game |
| Roadmap page | "Voir toute la feuille de route" in the landing's module 06 | The full roadmap. Decided, not designed (author, 2026-10-14; see Open questions) |
| Code repository | "Voir le projet" in the landing's module 07, "Code source" in the landing footer | The open-source project on GitHub, in a new tab. Artists, narrators and developers answer the landing's calls there, through issues, discussions and contributions (author, 2026-10-14, triage) |
| Plus (phone only) | PLUS tab | PLUS rows: Toutes les cartes, Amis, Fil d'activité, Succès, Comment ça marche, Profil et paramètres, Soutenir |
| Back-office | Staff accounts only | Out of the redesign's scope: unchanged behavior (spec CAP-2, CAP-15), plain functional style, designed later |

**Desktop navigation.** The hub is the only menu: 01 OUVRIR UNE CAPSULE (capsules badge), 02 COLLECTION (unique cards owned / total), 03 TOUTES LES CARTES (every card of the game; author, 2026-10-20), 04 ÉCHANGES (orange badge when a trade waits for the player), 05 AMIS ("n en ligne"), 06 FIL D'ACTIVITÉ ("En direct"), 07 SUCCÈS (earned / total), 08 COMMENT ÇA MARCHE, 09 SOUTENIR (the donation page in a new tab). The player chip opens Profil et paramètres. On every screen the top bar's gold GAMEBLE wordmark is a link to the hub; for a signed-out visitor it leads to the landing. Every other screen also has, after it, a back button to the previous screen (see Back button). There is no permanent sidebar.

**Phone navigation.** A bottom tab bar: PONT · CAPSULE · COLLECTION · ÉCHANGES · PLUS. Tab roots have no back button; tapping the current tab returns to its root or scrolls it to the top. Sub-views slide over their screen with a contextual back: "◀ GRILLE" (card detail opened from a grid or a set), "◀ CAPSULE" (card detail opened from an opened capsule), "◀ LISTE" (trade board), "◀ PLUS" (Amis, Fil, Succès, Comment ça marche, Profil). The public card page has no tab bar.

**Hub content.** Top bar: the wordmark, rarity counter, capsules chip, player chip. Left: kicker "PONT DE COMMANDEMENT" alone (no subtitle: the "Vaisseau-bibliothèque « Archiviste »" line was cut, author 2026-10-07), the menu, the daily capsule panel. Center: the showcase. Right: the community goal panel and "SETS EN COURS" (the player's four sets closest to their next tier, "TOUT VOIR ▸" opening the collection). Bottom: the LIVE ticker. On the phone the same blocks stack in one scrolling column without the menu.

**Signed-out visitors** meet the landing at the root (author, 2026-10-14): /fr, /en, the GAMEBLE link, after sign-out and after account deletion. From the landing ("Embarquer sur le pont") or the public card page's play link they can still browse the signed-out hub and everything that needs no account, and cannot act: any such action opens the sign-in panel. In Toutes les cartes and the card detail they see every card's face, plain, with no ownership data (author, 2026-10-20); the collection's sets show no progress. The landing and the signed-out hub are described in `DESIGN.md` (see Landing and Signed-out hub).

## Voice and Tone

This section covers microcopy only. Brand voice lives in `DESIGN.md` (see Brand & Style). All copy ships in French and English; the French below is the product's approved copy.

- **Terminal labels:** short uppercase labels for actions and states ("OUVRIR LA CAPSULE", "TOUT RÉVÉLER", "◀ COLLECTION", "SCELLÉE", "RÉSERVE VIDE").
- **Plain sentences:** short and factual, always addressing the player as "vous", never "tu".
- **The Brotherhood speaks as an institution:** a corporate, falsely benevolent voice, a satire of capitalism and corporate culture, serious and never joking on purpose. Its presence is secondary: light in the collection, capsules, navigation, system messages and hub; stronger possible in communications from Management, events, achievements and economic announcements. Functional copy stays plain, and each new Brotherhood line in the interface comes through its own issue. The player gets no title or form of address. The landing is the one approved exception (author, 2026-10-14): it presents the Brotherhood, its mission and its story to come at length; inside the app the rule stands.
- **The landing speaks in the app's voice** (author, 2026-10-14; no landing-only exception): short and factual, few or no exclamation marks, always "vous". It never hammers on money ("0 €", "pas d'argent", "pas de dépense"), never sells with game figures (the starting reserve, cards per daily capsule, a price of 0), and never cites technical details ("chaque image est pixelisée puis rendue"). The author kept two figures because they explain how an opening works: the final call's "Dix capsules vous attendent." and 03's five cards per capsule. It promises nothing the game does not have when the landing ships: what comes later carries "Bientôt" or sits in the roadmap.
- **The name** is written "gameble", in lower case everywhere, at the start of a sentence too; capitals come only from style (a kicker, the wordmark).
- **French punctuation:** a narrow no-break space (U+202F) before « : ; ? ! » and inside « », so no sign wraps onto a line of its own.
- **Errors say what happened and what to do,** inline where the action is.

| Do | Don't |
|---|---|
| "Une capsule rejoint votre réserve. La prochaine sera prête le 15 oct. à 02h00." | Exclamation marks ("!" is reserved for the Légendaire banner) |
| "Léa a 7 jours pour répondre. Vos cartes sont réservées d'ici là." | Vague errors ("Erreur", "Échec de l'opération") |
| "Vous n'avez plus assez d'exemplaires de Celeste." | "Tu", "Confrère", "Capitaine" or any title |
| "Merci. L'équipe de modération examinera ce profil. Léa ne verra pas qui l'a signalé." | Terms, slogans or elements from other games or fictional universes (e.g. Helldivers: "Ordre majeur", "Super Earth") |
| Name the rarity in words next to its shape | Name a real company in the copy (studios and publishers appear only as card credits and set names) |
| | Any tax or fee before the market (none in the MVP) |

### Copy deck

The single source for every message the interface shows. Other sections name the control or state and point here; button labels stay with their controls.

| Key | Copy |
|---|---|
| Community goal | "La Confrérie invite ses membres à unir leurs efforts pour ouvrir 50 000 capsules cette semaine." (the number is the week's target; English: "The Brotherhood invites its members to join forces and open 50,000 capsules this week.") |
| Goal reward notice | To each contributor once the goal is reached: title "OBJECTIF ATTEINT" ("GOAL REACHED") · "La Direction vous remercie pour votre participation. Une capsule rare a rejoint votre réserve." ("Management thanks you for your contribution. A rare capsule has been added to your reserve.") `[ASSUMPTION: "rare" kept as written, though Rare is also a rarity tier and the reward holds an Épique or better]` |
| Welcome message | Once, to every player: title "Bienvenue sur gameble" ("Welcome to gameble") · "Autrefois bannis de la Terre, les jeux vidéo ont été sauvés grâce aux efforts de nos illustres fondateurs." · "Aujourd'hui, la Grande Confrérie des Gameblers a l'honneur de vous donner accès à cet héritage, sous forme de cartes distribuées aléatoirement dans nos capsules, afin de garantir une parfaite équité entre nos membres." · "Il ne vous reste plus qu'à constituer votre collection." · "La Confrérie vous souhaite d'excellents tirages." (English: "Once banished from Earth, video games were saved through the efforts of our illustrious founders." · "Today, the Great Brotherhood of Gameblers is honored to grant you access to this legacy through cards randomly distributed in our capsules, ensuring complete fairness among our members." · "All that remains is for you to build your collection." · "The Brotherhood wishes you excellent pulls.") |
| Capsule hints | "Cliquez une carte pour la révéler · n restantes" (phone: "Touchez la carte pour la révéler", then "Glissez la carte pour la ranger · ou touchez-la") · "Capsule inventoriée · +5 cartes dans la collection" |
| Capsule states | "SCELLÉE" · "ARMEMENT" · "ÉJECTION" · "INVENTAIRE" · "SIGNAL LÉGENDAIRE" · "INVENTAIRE COMPLET" · "EN ATTENTE" · "RÉSERVE VIDE · Prochaine capsule dans …" · "Cartes révélées : n / 5" · "Réserve pleine" |
| Capsule live region | "Carte 2 : Hades — Supergiant Games, 2020, Roguelite. Épique." · "Signal légendaire" · "Palier adepte atteint : Roguelike, 16 cartes sur 62." · "Palier expert atteint : Roguelike, 31 cartes sur 62." · "Set complet : Dark Souls, 3 cartes sur 3." · "Set complet : Roguelike, 62 cartes sur 62." · "4 paliers atteints : Dark Souls, maître ; Metroidvania, expert ; Roguelike, adepte ; Les Pépites, apprenti." |
| Face-down card name | "Carte 2 sur 5, face cachée. Révéler." |
| Daily capsule | "Une capsule offerte chaque jour. Elle rejoint votre réserve." · "Une capsule rejoint votre réserve. La prochaine sera prête le 15 oct. à 02h00." · full reserve: "RÉSERVE PLEINE" · "Ouvrez une capsule pour récupérer celle du jour." |
| Empty showcase | "OUVREZ VOTRE PREMIÈRE CAPSULE" · "Votre plus belle carte s'affichera ici." · "OUVRIR UNE CAPSULE" |
| Collection | "Chercher un set" · "TOUTES LES CARTES ▸" · "EN COURS" · with no set in progress: "Aucun set en cours pour l'instant. Cherchez-en un ci-dessus." ("No set in progress yet. Find one above.") · "◀ SETS" · kinds "THÈME", "FRANCHISE", "STUDIO", "PALMARÈS", "OVNI" · tiers "NOVICE", "APPRENTI", "ADEPTE", "EXPERT", "MAÎTRE", "COMPLET" ("NOVICE", "APPRENTICE", "ADEPT", "EXPERT", "MASTER", "COMPLETE"), earlier seasons' "BRONZE", "ARGENT", "OR" kept · "Aucune carte de ce genre dans ce set pour l'instant." · "IMAGE INDISPONIBLE" · set search: "Aucun set trouvé pour « … »." · "1 set trouvé" · "n sets trouvés" (zero, one and other forms) · set row name: "{set}, {kind}, {owned} cartes sur {total}[, palier {tier}][, {next} à {threshold}][, complet]" |
| Set celebration | Ribbons "PALIER NOVICE", "PALIER APPRENTI", "PALIER ADEPTE", "PALIER EXPERT", "PALIER MAÎTRE", "SET COMPLET" ("NOVICE TIER", "APPRENTICE TIER", "ADEPT TIER", "EXPERT TIER", "MASTER TIER", "SET COMPLETE"); earlier seasons' "PALIER BRONZE", "PALIER ARGENT", "PALIER OR" ("BRONZE TIER", "SILVER TIER", "GOLD TIER") kept; over the set's name and count: "PALIER ADEPTE · Roguelike 16/62" · link hint a pixel arrow "▸" alone (author, 2026-10-19; "Voir le set" stays in the link name) · link name "Palier adepte atteint : Roguelike, 16 cartes sur 62. Voir le set." ("Adept tier reached: Roguelike, 16 cards out of 62. View set."; "Set complet : Dark Souls, 3 cartes sur 3. Voir le set.") · folded line "n PALIERS ATTEINTS" ("n TIERS REACHED") with the highest result only, "dont Dark Souls MAÎTRE" ("incl. Dark Souls MASTER") and the hint "EN COURS ▸" ("IN PROGRESS ▸"); its link name "4 paliers atteints : Dark Souls, maître ; Metroidvania, expert ; Roguelike, adepte ; Les Pépites, apprenti. Voir les sets en cours." ("4 tiers reached: Dark Souls, master; Metroidvania, expert; Roguelike, adept; Les Pépites, apprentice. View sets in progress.") · phone "▸" button name "Résultat suivant" ("Next result") |
| Comment ça marche, tiers | The tier sentence, in place of "bronze à 10 %, argent à 25 %, or à 50 %" (author, 2026-10-19): "Chaque set a des paliers selon sa taille, puis la complétion à 100 %. Le dernier palier avant la complétion est toujours Maître ; plus le set est grand, plus il compte de paliers en dessous : de 3 à 4 cartes, la complétion seule ; de 5 à 9, Maître à la moitié ; de 10 à 19, Expert au tiers et Maître aux deux tiers ; de 20 à 59, Adepte à 25 %, Expert à 50 % et Maître à 75 % ; de 60 à 199, Apprenti à 10 %, Adepte à 25 %, Expert à 50 % et Maître à 75 % ; à partir de 200, Novice à 10 %, Apprenti à 25 %, Adepte à 50 %, Expert à 75 % et Maître à 90 %." ("Every set has tiers by its size, then completion at 100 %. The last tier before completion is always Master; the larger the set, the more tiers below it: 3 to 4 cards, completion only; 5 to 9, Master at half; 10 to 19, Expert at a third and Master at two thirds; 20 to 59, Adept at 25 %, Expert at 50 % and Master at 75 %; 60 to 199, Apprentice at 10 %, Adept at 25 %, Expert at 50 % and Master at 75 %; from 200, Novice at 10 %, Apprentice at 25 %, Adept at 50 %, Expert at 75 % and Master at 90 %.") (author, 2026-10-19: ranks counted from the top) |
| Trade list summary | One line per side: the first game, then "+n" for the others: "Red Dead Redemption 2 +2"; an empty side reads "À choisir" |
| Trade board lines | "Léa vous propose cet échange." · "En attente de la réponse de Léa." · "Choisissez les cartes de chaque côté." · "Modifiez ce que vous donnez et ce que vous demandez, puis renvoyez." · "Échange en cours…" · "Échange conclu." · "Échange clos." · "Valable 7 jours après l'envoi" · "Expire dans n j" · open request: "Laissez ce côté vide : Léa choisira ce qui lui plaît en retour." (under the player's empty side while editing) · "Hugo vous laisse choisir. Prenez ce que vous voulez dans sa collection, puis renvoyez." · the empty side "À choisir par Léa" (sender) and "À vous de choisir" (recipient), without a card count · under a disabled send: "Placez au moins une carte du côté de Léa." |
| Trade toasts | "PROPOSITION ENVOYÉE" · "Léa a 7 jours pour répondre. Vos cartes sont réservées d'ici là." (with the player's side empty: "Léa a 7 jours pour choisir ce qui lui plaît en retour.") · "ÉCHANGE REFUSÉ · Votre réponse a été envoyée à Léa." · "PROPOSITION ANNULÉE · Vos cartes ne sont plus réservées." (with the player's side empty: "Léa n'a plus rien à choisir.") · "ÉCHANGE CONCLU · Dead Cells ×2 rejoint votre collection." |
| Friend chooser | "NOUVEL ÉCHANGE" (trade list action and chooser title) · "Choisissez l'ami avec qui échanger." · list name "Vos amis" · "ÉCHANGER" (accessible name "Échange avec Léa") · no friend: "Aucun ami pour l'instant." with the link "Invitez-en un avec votre lien ou votre code." |
| Trade refusals (inline) | "4 CARTES AU PLUS · Retirez une carte avant d'en placer une autre." · "UN ÉCHANGE À LA FOIS · Un échange est déjà ouvert avec Léa." · "EXEMPLAIRES INSUFFISANTS" · "Vous n'avez plus assez d'exemplaires de Celeste." · accepting a trade with an empty side: "Rien à recevoir pour l'instant : choisissez ce que vous voulez dans la collection de Léa, puis renvoyez." |
| Card picker | "n cartes · n exemplaires (4 cartes au plus)" · "n disponibles" · "Aucune carte disponible." · filter group "COLLECTIONS": friend's side "Ses doublons" · "Absentes de ma collection" · "En commun"; own side "Mes doublons" · "Absentes de sa collection" · "Disponibles" |
| Friends | "PAR LIEN" · "VOTRE CODE AMI" · "AJOUTER AVEC UN CODE" · "Sam vous invite" · "Envoyée à Sam" · "ANNULER" · "NOUVEL AMI · Sam fait maintenant partie de vos amis." · "Aucune invitation en cours." |
| Removing a friend | "RETIRER" · dialog "Retirer Sam ?" · "Sam quitte vos amis et vous quittez les siens. Aucun message n'est envoyé ; chacun de vous pourra réinviter l'autre." · with a trade in progress: "Votre échange en cours avec Sam est annulé et ses cartes sont libérées." · "RETIRER" · "ANNULER" · toast "AMI RETIRÉ · Sam ne fait plus partie de vos amis." · refusal "Ce joueur ne fait pas partie de vos amis." |
| Invite code messages | "Format attendu : ABCD-1234." · "C'est votre propre code." · "Invitation déjà envoyée." · "Invitation envoyée à Sam." · "Invitation annulée." |
| Presence | "En ligne" · "Ouvre une capsule" · "Il y a 3 h" · "Profil privé" |
| Trades closed | "Votre profil est privé : les échanges sont fermés." (link "RÉGLAGES") · "Le profil de Léa est privé : échanges fermés." |
| Going private | "Passer en privé annule vos 2 échanges en cours." · "PASSER EN PRIVÉ" · "ANNULER" |
| Report | "Pseudo ou avatar inapproprié" · "Triche ou abus" · "Harcèlement" · "Autre" · "Merci. L'équipe de modération examinera ce profil. Léa ne verra pas qui l'a signalé." |
| Feed | "Rien pour l'instant dans ce filtre." · Friends tab without friends: "Ajoutez des amis pour suivre leurs tirages." with "AJOUTER DES AMIS" · repost entry: "Hugo a reposté Elden Ring." · tag "REPOST" · set entries: "Léa atteint le palier Novice du set Roguelike." / "… le palier Apprenti du set …" / "… Adepte …" / "… Expert …" / "… Maître …"; earlier seasons' "Léa atteint le bronze du set Roguelike." / "… l'argent du set …" / "… l'or du set …" kept · "Léa complète le set Dark Souls." · several in one opening: "Léa atteint 4 paliers · Metroidvania ADEPTE" |
| Repost | Action "REPOSTER" · confirmation toast "Carte repostée dans le fil." |
| Achievement toast | "SUCCÈS DÉBLOQUÉ" ("Achievement unlocked" in English) · the achievement's name as the Succès screen gives it: "Première capsule", "Première Épique", "Première Légendaire", "Premier set complet", "Premier échange", "Premier repost", "10 capsules", "Trois sets complets" |
| Back picker | "Vous seul le voyez, sur vos cartes face cachée à l'ouverture." · "DOS VERROUILLÉ" · "DOS ÉQUIPÉ" · "« Aurore » apparaîtra sur vos cartes face cachée." |
| Profile visibility | "Visible par tous les joueurs" · "Visible par vos amis seulement" · "Profil privé : vous seul le voyez" |
| Settings | "PRÉPARATION…" · "EXPORT PRÊT" · delete word: "SUPPRIMER" ("DELETE" in English) |
| Share and copy | "COPIÉ ✓" · "Copiez le lien manuellement." |
| Public page | "Vos jeux Steam, en cartes à collectionner." · "Ouvrez des capsules, complétez des sets, échangez avec vos amis." · "LIVE · En ce moment sur gameble" · links "Découvrir" (accessible name "Découvrir gameble", to the landing) and "Embarquer sur le pont" (accessible name "Embarquer sur le pont, visiter le jeu sans compte", to the signed-out hub) |
| Public profile | "Membre depuis mars 2026" ("Member since March 2026") · "SIGNALER" · actions "AJOUTER EN AMI" ("ADD FRIEND"; accessible name "Ajouter Léa en ami", "Add Léa as a friend"), "EN ATTENTE" ("PENDING"), "ACCEPTER" ("ACCEPT"; accessible name "Accepter l'invitation de Léa", "Accept Léa's invitation"), "ÉCHANGE" ("TRADE"; accessible name "Échange avec Léa", "Trade with Léa") · key numbers "Cartes" ("Cards"), "Sets complets" ("Complete sets"), "Succès" ("Achievements") · "VITRINE" ("SHOWCASE") · stats "RARETÉS" ("RARITIES"), "ACTIVITÉ" ("ACTIVITY"), "Capsules ouvertes" ("Capsules opened"), "Premières découvertes" ("First discoveries"), "Échanges conclus" ("Trades concluded"), the stats region "Statistiques" ("Statistics") · "SUCCÈS" ("ACHIEVEMENTS"), "Succès obtenus" ("Achievements earned"), the count's accessible text "12 succès obtenus sur 40" ("12 achievements earned out of 40"), "Derniers obtenus" ("Latest earned") · "SETS" · "13 sets entamés" ("13 sets started"; one and other forms) · "VOIR LA COLLECTION COMPLÈTE" ("SEE THE FULL COLLECTION") · unavailable: "Profil indisponible" · "Ce profil n'est pas disponible. Le lien ne mène nulle part, ou son propriétaire ne le montre plus." ("Profile not available" · "This profile is not available. The link leads nowhere, or its owner no longer shows it.") |
| Profile showcase | "METTRE EN VITRINE" ("ADD TO SHOWCASE") · "RETIRER DE LA VITRINE" ("REMOVE FROM SHOWCASE") · beside the disabled button at five cards: "Vitrine pleine : retirez une carte pour en ajouter une autre." ("Showcase full: remove a card to add another.") · reorder buttons "◀" "▶", accessible names "Déplacer Portal 2 vers la gauche" / "Déplacer Portal 2 vers la droite" ("Move Portal 2 left" / "Move Portal 2 right") · hub kicker "VITRINE" ("SHOWCASE") for a chosen card, "DERNIÈRE OBTENTION" for the automatic one · friend profile "VOIR LE PROFIL" ("SEE THE PROFILE") and "VOIR LA COLLECTION" ("SEE THE COLLECTION") |
| Sign-in panel | "CONNECTEZ-VOUS POUR JOUER" |
| PLUS | "Le reste du vaisseau" |
| Phone top-bar titles | Profil et paramètres under 720px: "PROFIL" ("PROFILE" in English); "Profil et paramètres" on wider screens and in the browser tab |
| Links | "(nouvel onglet)" |

 Shorter phone labels are allowed where the mock uses them ("ÉCHANGER", "SIGNALER CE PROFIL", "SUPPRIMER", "PROFIL"). The English copy is not written yet; it follows the same rules.

#### Landing

Every rule in this section is the author's decision of 2026-10-14 unless tagged `[ASSUMPTION]`.

The landing's approved French copy, in page order. It speaks in the app's voice (see the bullets above); where the author's review wording and the mock differ, this table follows the decisions log. `{…}` marks live data.

| Key | Copy |
|---|---|
| Top bar | The wordmark (accessible name "gameble, accueil" `[ASSUMPTION]`) · motion switch "Animations réduites" (a toggle, `aria-pressed`) · Valve's image (see Steam sign-in name below) |
| Steam sign-in name | The link around Valve's image: "Sign in through Steam, se connecter avec Steam (ouvre Steam)", wherever the image appears (top bar, 09, sign-in panel, public card page, signed-out hub) |
| Module headers | "01 · Concept" · "02 · La Confrérie" · "03 · Comment ça marche" · "04 · En direct" · "05 · À faire et à débloquer" · "06 · Feuille de route" · "07 · Open source et contributions" · "08 · Un jeu libre" · "09 · Embarquement" |
| Hero | Kicker "Mission en cours" · hook "Des jeux ont été perdus. La Confrérie part les retrouver. Rejoignez-la." · line "gameble est un jeu de cartes à collectionner basé sur la bibliothèque publique de jeux Steam." · button "Embarquer sur le pont" (accessible name "Embarquer sur le pont, visiter le jeu sans compte") · lamp readout "Jeux retrouvés {n} / {total}" with "· Balayage auto", "· Balayage manuel" or "· Balayage fixe" · found tag "Trouvé" |
| 01 · Concept | Title "Chaque carte est un jeu Steam." · subtitle "Les jeux sont triés sur le volet et importés selon un principe simple : plus un jeu est populaire, plus sa carte sera rare." · under each card its rarity name and "{n} % par carte" (the normal capsule's odds, read from what the game applies, as in Comment ça marche) · notes "Cinq raretés" / "De la plus commune à la légendaire." · "Plus rare, plus vivante" / "Plus la carte est rare, plus elle prend vie." · "Une rareté par saison" / "À chaque saison, les raretés sont recalculées." · card row accessible name "Les cinq raretés, de la plus commune à la plus rare" |
| 02 · La Confrérie | Title "La Grande Confrérie des Gameblers" · subtitle "Votre présence est plus que nécessaire. La Confrérie avance ensemble, semaine après semaine, et son histoire s'écrit avec ses membres." |
| 02 · lore panel | "Archive 001" · "Le récit de la Confrérie" · the lore text (from the lore session) · "La suite s'écrit avec vous. La Confrérie cherche des narrateurs et des scribes pour faire vivre son histoire." · link "Participer à l'écriture" |
| 02 · goal panel | "Cette semaine" · "Un objectif pour tous" · "Chaque capsule ouverte et chaque échange conclu font avancer la même jauge. Objectif atteint : tous les participants sont récompensés." · the Community goal line · "{n} participants" (zero, one and other forms: "0 participant", "1 participant") · "Fin {jour} à {heure}. Le prochain objectif s'ouvre aussitôt." (day and hour in the visitor's own time zone, so the week's end may show as Sunday; the mock's "00:00 UTC" breaks this rule) |
| 02 · tiles | "Découvrez" / "Le premier joueur à tirer un jeu y grave son nom, pour toute la Confrérie." (kept: the pioneer feature ships first, see Implementation notes, Landing ship conditions) · "Échangez" / "Vos doubles font le bonheur d'un ami. Proposez, contre-proposez, concluez." · "Partagez" / "Une belle carte se montre. Repostez-la dans le fil et exposez vos trouvailles." · "Contribuez" / "Tirages notables, découvertes, échanges, sets complétés : tout s'y affiche, en direct." `[ASSUMPTION: the mock's line, untouched in the review; it describes the feed rather than contributing]` · the tiles' example rows use the Feed copy ("Inès complète le set Dark Souls.", "Nina a reposté Hades.") |
| 03 · Comment ça marche | Title "Un travail de longue haleine vous attend." · subtitle "Ouvrir, révéler, collectionner, échanger. Ces quatre gestes vous suffiront à faire progresser la mission de la Confrérie." · "Rejoignez-la" / "Connectez-vous et créez votre compte automatiquement avec Steam." (badge "Nouveau membre") · "Accumulez des capsules" / "Des capsules arrivent dans votre réserve au fil du temps, même quand vous n'êtes pas là." ("Prochaine capsule dans {durée}") · "Découvrez de nouvelles cartes" / "Une capsule contient cinq cartes face cachée. Retournez-les pour les découvrir." (buttons "Révéler", then "Recommencer"; live line "Carte révélée : {titre} — {studio}, {année}, {genre}. {rareté}.") · "Agrandissez votre collection" / "Chaque carte rejoint votre collection. Complétez des sets, échangez vos doubles avec vos amis." ("Set Roguelike · en cours") |
| 04 · En direct | Title "La Confrérie joue en ce moment." · subtitle "Les dernières entrées du fil d'activité, et la saison en cours." · "Fil d'activité" with the LIVE marker · entries as in Feed · link "Ouvrir le fil d'activité" · "Saison en cours" · "{saison}" ("Saison 1 · Grand Catalogue") · "Joueurs actifs cette semaine" · "Capsules ouvertes aujourd'hui" · "Premières découvertes cette semaine" (each count with its zero and one forms). No weekly goal here: it is live only in 02 (author, 2026-10-14, triage) |
| 05 · À faire et à débloquer | Title "De quoi remplir la soute." · subtitle "Des sets à compléter, des amis avec qui échanger, un objectif commun chaque semaine." |
| 05 · tiles | "Sets et paliers" (tag "Bientôt") / "Thèmes, franchises, studios, palmarès et OVNI. Collectionnez-les tous et faites progresser les paliers de sets pour débloquer des récompenses." · "Échanges entre amis" / "Échangez les cartes qui ne vous intéressent pas contre celles qui vous permettront d'avoir la collection de vos rêves." · "Objectif communautaire" / "Chaque lundi, un nouvel objectif pour toute la Confrérie. Chaque capsule ouverte et chaque échange comptent." · "Succès" / "Première capsule, première Épique, première Légendaire, premier set complet, premier échange…" · "Dos de cartes" (tag "Bientôt") / "Vos cartes face cachée portent le dos de votre choix. Remplissez des objectifs pour en débloquer de nouveaux." · "Collection" / "Voyez en un coup d'œil les cartes qui vous manquent pour compléter votre collection." · the "Bientôt" tags match the roadmap's "À venir" |
| 05 · tile examples | Objectif communautaire, a past week with no live figure: "Semaine 41" · "Atteint" · "Chaque participant a reçu une capsule avec au moins une Épique." · Succès, the achievements' own names: "Première capsule", "Premier échange", "Première Légendaire", "Premier set complet", "À obtenir" · Collection: "Cartes uniques" · example names start with "Exemple : " |
| 06 · Feuille de route | Title "Un aperçu des prochaines évolutions." · subtitle "La collection se construit avec la communauté, le jeu aussi." · statuses "Fait", "En cours", "À venir" · link "Voir toute la feuille de route" · milestones and stories in the author's player-facing wording, from the roadmap data |
| 07 · Open source | Title "Open source et développé avec l'IA." · subtitle "Le code est entièrement libre et tout le monde peut contribuer au projet. Les tâches fastidieuses sont faites par l'IA, le reste est construit par des humains, pour des humains." · "Nous recrutons des personnes dévouées à la Confrérie." · "Poste ouvert" · "Artistes" / "Musique, sons, dos de cartes, illustrations… La liste est longue. Elle attend des personnes de talent." · "Narrateurs et scribes" / "Une voix, des personnages, une histoire qui avance semaine après semaine. Nous avons besoin de vous pour relater les faits marquants de la Confrérie." · "Développeurs" / "Le code est ouvert. Chacun peut proposer une correction ou une idée, quelle qu'elle soit." · button "Voir le projet" (accessible name "Voir le projet (GitHub, nouvel onglet)") · "Licence libre. Chaque contribution est relue par l'auteur." |
| 08 · Un jeu libre | Title "Un jeu libre, qui vous respecte." · "gameble est gratuit et ouvert. Tout le monde y joue à égalité, et chacun peut voir comment il fonctionne." · "Vos données ne sont ni revendues ni exploitées. Aucune publicité ne s'intercale entre vous et vos cartes." · support panel "Soutenir gameble" · "Pour continuer de tourner, le projet a besoin de soutien." · "Si gameble vous plaît, vous pouvez l'aider." · button "Soutenir" (accessible name "Soutenir (site de dons, nouvel onglet)") |
| 09 · Embarquement | Title "Dix capsules vous attendent." · "Elles sont dans votre réserve dès votre première connexion." · "Réserve : 10 / 10" · Valve's image · hub link "Embarquer sur le pont", with the hero's accessible name (one label wherever the hub link appears) |
| Footer | "Mentions légales" · "Soutenir" (accessible name "Soutenir (site de dons, nouvel onglet)") · "Code source" (accessible name "Code source (GitHub, nouvel onglet)") · "gameble n'est affilié ni à Steam ni à Valve. Les illustrations appartiennent aux éditeurs des jeux et à leurs artistes." |
| Side gauge | Navigation "Position sur la page"; each marker named by its visible number and its module's header name: "00 · Mission" (the hero), "01 · Concept", "02 · La Confrérie" … "09 · Embarquement" (the mock's names omit the number, which breaks WCAG label-in-name) |
| Landing live states | No feed entry: "Aucune activité pour l'instant." `[ASSUMPTION: new line, not reviewed]` · a figure that cannot be read: "—" |

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
| Steam sign-in | The official image opens Steam's sign-in; its accessible name starts with the image's own words and says it opens Steam (see Copy deck, Landing, Steam sign-in name). On return the player lands on the hub. |

### Cards

| Component | Behavioral rules |
|---|---|
| Card face | Tilts toward the pointer, or under a finger held still for 150ms on the phone; vertical drags scroll the page. Opens the card detail where it makes sense. |
| Face-down card | One activation (click, tap, Enter, Space) reveals its rarity and game together. Wears the player's active card back. Accessible name: see Copy deck. |
| Revealed card | Ignores activation for 400ms after its flip. Then, desktop: opens its card detail in the collection. Phone: tap, swipe or "RANGER" stores it in the tray. |

### Chrome

| Component | Behavioral rules |
|---|---|
| Rarity counter | Copies owned per rarity, each copy at its minted rarity, every edition included; a count updates as each card is revealed, never before. The "RARETÉS" legend (icon, name, count per tier) opens below the counter on hover (desktop) and on activation, and stays open after a click; Esc, a second activation or leaving it closes it (author, 2026-10-07). Keyboard focus opens it too. |
| Capsules chip | Reserve count and the countdown to the next capsule, or "Réserve pleine" at 10. Opens the capsule screen. |
| Player chip | Opens Profil et paramètres. |
| Menu item | Opens its screen; SOUTENIR opens the donation page in a new tab and the hub stays, so it is not the item focused on the way back. Keys 1 to 8 open the matching item only while focus is inside the menu (`aria-keyshortcuts`). Coming back to the hub focuses the item last used. |
| Count badge | Capsules in reserve (lime); trades waiting for the player (orange). Grayed at zero in the menu; hidden at zero in the tab bar. Its number is part of the item's accessible name. |
| GAMEBLE link | Desktop: the top bar's wordmark opens the hub from any screen. Accessible name "GAMEBLE, pont de commandement" `[ASSUMPTION]`. Disabled during an opening. Signed out, it opens the landing (on the landing itself it returns to the page's top `[ASSUMPTION]`). |
| Back button | Desktop: returns to the previous screen, like the browser's Back, which comes back as it was left (scroll, filters, page). Its label names that screen by its short top-bar title ("◀ COLLECTION", "◀ FICHE", "◀ AMIS"; the collection entry reads "◀ SETS"). Hidden when the previous screen is the hub (the GAMEBLE link leads there) or when the tab holds no earlier gameble screen (a direct link, a new tab): a back never leaves gameble. Phone: returns to the parent view (see Phone navigation). Disabled during an opening. |
| Tab bar | Switches between the five roots. Disabled during an opening. Hidden on the public card page. |
| PLUS rows | Open Amis, Fil d'activité, Succès, Comment ça marche, Profil et paramètres; Soutenir, last, opens the donation page in a new tab. |

### Hub

| Component | Behavioral rules |
|---|---|
| Showcase | The first of the cards the player chose for their profile showcase, else automatically the card of Épique rarity or better they gained last and still hold, from a capsule or a trade, with « REPOSTER » beside it (author, 2026-10-16, extends 2026-10-15 and 2026-10-07). The player chooses up to five cards from an owned card's detail with "METTRE EN VITRINE" and takes one out with "RETIRER DE LA VITRINE" (see Card detail); with none left, the hub returns to the automatic card. "VOIR LA FICHE" opens its card detail. Empty showcase: its copy (see Copy deck) and "OUVRIR UNE CAPSULE", which opens the capsule screen. |
| Community goal panel | The shared weekly gauge for all players, the count and the reward. Fills with every capsule opened and, a little, with trades. States: see State Patterns. |
| Daily capsule panel | "RÉCUPÉRER" sends one capsule into the reserve (a small canister flies to the capsules chip; on the phone, to the CAPSULE tab). Then "PROCHAINE DANS" with a countdown to the day change (midnight UTC; every time a player reads shows in the browser's own time zone, never with "UTC"). At 10 capsules the button is disabled, with the full-reserve state and line, until a capsule is opened. Signed out: opens the sign-in panel. |
| Set progress row | Opens that set's album. |
| Welcome panel | A modal over the hub (author, 2026-10-15), shown once to every player, at a new player's first arrival on the hub or an existing player's next one: the Modal pattern (title, "✕" named « Fermer », Esc or the scrim closes it; a bottom sheet on the phone) holding the Welcome message (Copy deck) and a « Fermer » button that takes the first focus. It takes the place of the sign-in welcome toast that time and never shows again, on any device; once closed, the focus goes to the hub's heading. |
| LIVE ticker | Scrolls notable activity: pulls of Épique or better, first discoveries, trades, set tiers reached and set completions (the tiers and completions of one opening make one line, as in the feed); never reposts. New items join at the loop boundary. Pauses on hover; stops with "Animations réduites", the only way a keyboard user stops it. Hidden from assistive technology and holds nothing focusable (the feed carries the same events). |

### Capsule

| Component | Behavioral rules |
|---|---|
| Capsule canister | Click, tap, Enter, Space or "OUVRIR LA CAPSULE" sends the opening request; the trigger locks until the answer (see Opening protocol). Disabled when the reserve is empty. |
| Capsule information panel | Reserve, pips, status light and word, revealed counter. "+1 dans …" becomes "Réserve pleine" at 10. |
| Tout révéler | Reveals the remaining cards one after another (on the phone, also stores each in the tray). A Légendaire plays its full sequence; the others wait. |
| Ouvrir la suivante | Enabled once all five cards are revealed. The cards sink away and a new canister docks in. |
| Set celebration | Starts once the last card's reveal (or the Tout révéler summary, or a Légendaire's banner) has ended, and plays its entrance once (see Motion). Each result is one link, the whole banner its target, to that set's album (author, 2026-10-17); the album's back reads "◀ CAPSULE" and returns to the capsule (see Reveal abandoned). The folded "n PALIERS ATTEINTS" line links to the collection opened on "EN COURS". Never takes focus by itself; each result is reachable by Tab in reading order. Never blocks "RANGER" or "OUVRIR LA SUIVANTE". Never changes on a timer: on the phone, the "▸" button, a target separate from the result's link, shows the next result (after the last, the first again) and keeps focus. The sets it names lead "EN COURS" in the collection. |
| Result banner | Plays on an Épique (small) and a Légendaire (large). Decorative: the capsule live region carries the result. |
| Reveal caption plate | Phone: shows the top card's rarity, title and year once revealed; hosts the Épique and Légendaire banners. Never covers the card. |
| Tray | Phone: receives each stored card in order, "CARTE n / 5". A filled slot opens the card zoom. |
| Card zoom | Phone: shows the stored card large between ◀ ▶; ◀ ▶ or a swipe show the previous or next stored card in capsule order without closing (no ◀ on the first, no ▶ on the last); "VOIR LA FICHE" opens its detail, which walks the capsule; "FERMER" or Esc returns to the capsule with focus on the slot shown. |

### Collection

| Component | Behavioral rules |
|---|---|
| Card detail | Title, publisher, rarity, genre, year, short description, minted season, sets, copies owned, then "ÉDITIONS": the editions owned grouped by rarity ("Rare : S1, S4 · Épique : S2"), folded beyond three lines. "VOIR SUR STEAM" opens the store page in a new tab (said in its accessible name). The card shows as itself, never greyed or locked, owned or not, signed in or not, as on its public page (author, 2026-10-20); for a signed-in player, a card not owned reads "Aucun" in its copies row and "Aucune" in ÉDITIONS; a visitor sees neither row. "PARTAGER" opens the share sheet, on every card, for players and visitors alike (author, 2026-10-20). For a card the player owns, "METTRE EN VITRINE" adds it to their profile showcase (up to five cards; a new card joins at the end, the owner reorders them on their own profile; the hub shows the first), and on a card already there "RETIRER DE LA VITRINE" takes it out (author, 2026-10-15); absent for a card not owned and for a visitor. With five cards in the showcase, "METTRE EN VITRINE" is disabled, with the showcase-full line beside it (Copy deck, Profile showcase). ◀ ▶ buttons (every width) and swipe (phone) move to the previous or next card of where the detail was opened from: an opened capsule's cards in its order, back to the capsule ("◀ CAPSULE"); the collection grid as shown, with its filters and search, across its pages, back to that grid's page ("◀ GRILLE"); anywhere else (feed, hub showcase, shared link, public profile, capsule page), the card's tome. No ◀ on the first card, no ▶ on the last (author, 2026-10-08). A card of a grid opens its detail page at every width; browser Back and ◀ GRILLE return to the grid at its scroll (author, 2026-10-19). |
| Collection opening (author, 2026-10-19 and 2026-10-20, supersedes 2026-10-08) | Opens on "CHERCHER UN SET": a search over every set, applied as the player types, with "TOUTES LES CARTES ▸" as the primary button on the field's row (under the field, full width, on the phone; absent on a public profile) and the search's status line under them; then the search's results, right under the field; then "EN COURS": the player's sets sorted by the cards missing to their next tier or completion, plus those they just progressed in; with none (a new player, a profile owner with none), one line instead, "Aucun set en cours pour l'instant. Cherchez-en un ci-dessus.". A signed-out visitor sees no EN COURS: in its place "À DÉCOUVRIR" ("TO DISCOVER") lists popular sets of the published season, name and kind only, each opening its album (author, 2026-10-20). A set touched by one game only is found through the search. "TOUTES LES CARTES ▸" opens the card grid, which opens on every card (TOUT), the owned ones first, newest first, above the missing ones; the state filter narrows it to POSSÉDÉES, MANQUANTES, NOUVELLES or DOUBLONS (author, 2026-10-08). |
| Set album | The set's name and owned / total on one line, the COMPLET stamp beside the name once it holds every card, then its progress bar with a tick, a rank mark and the threshold in cards for each tier before completion, lit when reached (no kind and no tier list; author, 2026-10-19); a set of 3 or 4 cards has no ticks; its cards in set order, owned cards face up, missing ones as missing-card slots. A card opens its detail. The back button returns where the album was opened and names it: "◀ SETS" (collection or search), "◀ FICHE" (card detail), "◀ PROFIL" (public profile), "◀ CAPSULE" (a capsule's set celebration); opened from the hub, none on desktop (the GAMEBLE link leads there) and "◀ PONT" on the phone. The card grid is one tab stop with arrow keys inside, like the collection grid. Signed out, on a public profile, the album shows that player's cards. A tier shows no season mark and no "à reconquérir" (author, 2026-10-19). The header's bar is a progress bar named by the set's name, with the text value "31 cartes sur 62, palier expert" ("31 cartes sur 62, palier or" on an earlier season's set; untiered and done: "3 cartes sur 3, complet"). Its ticks, marks and figures are hidden from assistive technology, and no visually hidden list or sentence carries the tiers: the bar announces only what the header shows, the count and the tier reached (author, 2026-10-19). The COMPLET stamp is plain text. The album's h1 is the set's name (on a public profile: "Roguelike · Léa"), and the top bar's "COLLECTION" is not a heading there; the page title reads "Roguelike · Collection · gameble". On the collection entry the h1 is "COLLECTION", with h2s for CHERCHER UN SET, RÉSULTATS (with a query) and EN COURS, in that order; Toutes les cartes has the h1 "TOUTES LES CARTES". Reference: [mockups/key-collection-sets.html](mockups/key-collection-sets.html). |
| Set search | A `search` landmark. The field is labelled by "CHERCHER UN SET"; a placeholder never labels it. Applied after 300ms without typing, over set names and kinds. Results appear right under the field, above EN COURS, and push it down (author, 2026-10-20). A polite status line under the field gives the count once per pause in typing; it keeps its height when empty. Focus stays in the field. Esc clears the field when it has text. |
| Filter zone | A folded panel "FILTRES" with the count of active filters. Chips are switched on or off, several at once: OR within a group, AND across groups. Groups: state (absent for a signed-out visitor; author, 2026-10-20), rarity, set (a kind, then a set found by typing its name), genre. A "TOUT EFFACER" clears them. Changing a filter re-lays the grid and keeps focus on the zone. |
| Search | Free text over the card title and publisher, applied as the player types and combined with the active filters; an empty result shows the empty-filter line. |
| Missing-card slot | Set albums only (author, 2026-10-20): shows the missing game's name and year; opens the card detail, which shows the card itself. |
| Card not owned (grid) | In Toutes les cartes, for a signed-in player only, and in another player's full collection by that player's holdings: the published season's face, faded and grey, its rarity effects off, a pixel lock centred over the art (author, 2026-10-20; mock: mockups/catalog-not-owned.html, variant A's face with variant E's lock). It opens the card detail like any card. A visitor's grid sets nothing apart. |
| Copy badge / NOUVEAU tag | "x3" shows copies owned, from x2 (a single copy shows no badge; author, 2026-10-07). Copies count every edition. A card held in several editions shows an edition count ("3 éd."); the grid never shows a season. "NOUVEAU" marks cards obtained since the player last saw them. |
| Grid across editions | One card per game, showing its best minted rarity owned; a card not owned shows the published season's face, set apart as Card not owned says. |
| RAPPORT panel | Distinct games per best owned rarity, and copies across editions; absent for a signed-out visitor, with nothing in its place, as are the top bar's owned / total count on every collection page, the copy badge, the edition count and NOUVEAU (author, 2026-10-20). Folds on the phone; the fold toggle announces whether it is expanded. |
| Share sheet | Copies the link on opening and says so ("COPIÉ ✓", announced politely). The link's preview on Discord, X and WhatsApp shows the title and rarity, never the image. "VOIR LA PAGE PUBLIQUE ▸" opens the public card page. |

### Échanges

| Component | Behavioral rules |
|---|---|
| Trade list row | Three groups: "EN ATTENTE DE VOUS", "EN ATTENTE DE LEUR RÉPONSE", "TERMINÉS RÉCEMMENT". Sums up each side on one line, its first game and "+n" for the others (see Copy deck, Trade list summary); the full content shows when the trade opens. Opens its trade board. |
| Friend chooser | "NOUVEL ÉCHANGE" at the top of the trade list, with or without trades, opens it in the board's place beside the list (on the phone, alone with "◀ LISTE"). One row per friend: the name, the presence (see Copy deck, Presence) and "ÉCHANGER", which opens the draft with that friend, or the trade already in progress with them under the one-at-a-time refusal. When either profile is private, the "Trades closed" line replaces the button. With no friend, the no-friend line points to the invite panel (see Copy deck, Friend chooser). |
| Trade board | A proposal holds an offer and a request. At most 4 different cards per side. At every send the friend's side holds a card; the sender's own side may stay empty, which asks the friend to choose what they want in return (the open request, no separate gesture). A trade with an empty side cannot be accepted. Actions by state: see State Patterns. |
| Add slot | Opens the card picker for its side. |
| Remove | Removes that card (all its copies) from the side. |
| Card picker | The player's side lists the player's cards with copies owned and reserved elsewhere; the friend's side lists the friend's collection. Picking adds a card with 1 copy; a fifth card is refused inline (see Copy deck, Trade refusals). "PLACER" commits, "ANNULER" discards. The grid is one tab stop with arrow keys inside. On the phone the rarity and collection chips fold under "FILTRES" with the count of chips on, while the search, the match count and "EFFACER LES FILTRES" stay in view above the grid. Each side's filters and fold are kept across closings and reopenings while the board stays open, and start empty and folded on another trade or page. |
| Quantity stepper | A spinbutton shown when more than one copy is available. The player's maximum is copies owned minus copies reserved in other trades; the friend's maximum is what they own. Keys: arrows or + and −. |
| Stack | Several copies of one card; moves as one unit in the swap. |
| Reserved tag | Copies held by a proposal waiting for an answer. A fully reserved card cannot be picked. |
| Status chip | Names the state in words; never relies on color alone. |

### Amis

| Component | Behavioral rules |
|---|---|
| Invite panel | "COPIER" copies the invite link. The code field accepts the format of the codes in use (for example "7K2Q-F3NX", "8F2D-K9XM") (author, 2026-10-07: the code is purely random, 4 characters, a dash, 4 characters, never derived from the name), submits on Enter and answers on the line below. A valid code sends an invitation. "AJOUTER EN AMI" on a public profile sends one too (see Public profile). |
| Invitation row | Received: "ACCEPTER" creates the friendship for both; "IGNORER" dismisses it. Sent: "EN ATTENTE" until answered. The invite link sends an invitation the same way, and so does "AJOUTER EN AMI" on a public profile, which lands here like a code invitation (author, 2026-10-15). |
| Friend row | Shows the friend's presence (see Copy deck, Presence), or "Profil privé" for a private friend. "VOIR LE PROFIL" opens the friend profile; the name is not a link. "ÉCHANGE" (accessible name "Échange avec <name>") opens the trade already in progress with that friend, or a new draft. When either profile is private, the "Trades closed" line replaces the button. "RETIRER" (accessible name "Retirer <name> de vos amis"), after "ÉCHANGE" or the "Trades closed" line, opens a confirmation dialog; "RETIRER" there ends the friendship for both, cancels the trade in progress between them and releases its reserved copies; "ANNULER", "✕" or Esc closes it and nothing changes. The former friend gets no message or toast; their lists simply refresh, and either player may invite the other again. |
| Friend profile | A dialog with no showcase (author, 2026-10-15): "ÉCHANGE" (the trade in progress with that friend, or a new draft), "VOIR LE PROFIL" (the public profile) and "VOIR LA COLLECTION" (the friend's full collection, read-only), both absent when the friend's profile is private, and "SIGNALER". A private friend's dialog shows the name and says the profile is not available; when the viewer is private, the "Trades closed" line replaces "ÉCHANGE". |
| Report dialog | A reason must be chosen before "ENVOYER LE SIGNALEMENT". The reported player never learns who reported them. |

### Fil d'activité and Succès

| Component | Behavioral rules |
|---|---|
| Feed tabs | TOUS shows everyone's events; AMIS shows only the viewer's friends' pulls, trades and reposts. The tab and the type filter combine ("AMIS · TIRAGES" shows friends' pulls). The AMIS tab is read when the screen opens and when it is revisited, not updated live. Signed out, AMIS opens the sign-in panel. A player without friends sees the Friends-tab line and "AJOUTER DES AMIS", which opens Amis. |
| Feed entry | One event per row (also on the public card page). Filters: TOUT, TIRAGES, DÉCOUVERTES, ÉCHANGES, REPOSTS. New entries arrive at the top. A repost is an entry naming the player and the card, tagged "REPOST"; it never appears in the LIVE ticker. |
| Repost action | "REPOSTER" on a card the player owns, in three places: the card detail (beside "PARTAGER"), a revealed card at the end of a capsule opening (desktop under the revealed row's card, phone in the card zoom), and the hub showcase under the best card. Any rarity, no limit, no message, reactions or comments. The action posts the repost and confirms with the repost toast; the button stays available (a card can be reposted again). Absent for a card not owned and for a visitor. |
| Achievement tile | Earned or to earn, with progress where countable, and the card back it unlocks if any. |

### Profil et paramètres

| Component | Behavioral rules |
|---|---|
| Settings row | "LANGUE" (FRANÇAIS / ENGLISH) switches at once. "VISIBILITÉ DU PROFIL" (PUBLIC / AMIS UNIQUEMENT / PRIVÉ, default PUBLIC) applies at once; choosing PRIVÉ with trades open first asks to confirm (see Copy deck, Going private). "ANIMATIONS RÉDUITES" follows the system by default; a visitor's landing motion switch, when on, sets it to OUI at sign-in. "EXPORTER", "SE DÉCONNECTER", "SUPPRIMER MON COMPTE": see State Patterns. |
| Back picker | Choosing an unlocked card back makes it active at once; a locked one states its condition inline. A back earned in several seasons lists them, and the player picks the season whose mark it wears. |
| Title and theme pickers (after the launch) | Each is a radio group named by its heading. The active option is checked. A locked option stays focusable, with its condition in its accessible name ("Adepte · Pirates, verrouillé : atteindre le palier Adepte du set Pirates"); choosing it shows the condition inline. Every menu theme meets the Colors contrast floor on its own colours, never recolours rarity or tier colours, and stops its animation under ANIMATIONS RÉDUITES. A title always appears as text. |
| Delete dialog | A note names everything deletion erases: the Steam id, the name, the profile and its link, the last visit and latest activity, the collection, completed sets, achievements, capsules opened or not, daily bonuses and goal rewards, friends, invitations, friend code and every feed entry that names the player (pulls, discoveries, reposts, trades); open trades are cancelled. A second line names what stays without the Steam id or the name (past trades, first discoveries, contributions to the community goal, reports, moderation history, the log of game actions) and says the action cannot be undone. When the screen is too short for it, the dialog scrolls. The field is labeled with the word to type; "SUPPRIMER DÉFINITIVEMENT" enables once the field holds that word (case-insensitive, paste allowed). |
| Mentions légales link | Opens the legal page (also in the public card page footer). |

### Landing

Every rule in this section is the author's decision of 2026-10-14 unless tagged `[ASSUMPTION]`.

The landing is interactive but a little frustrating on purpose: the visitor scrolls to understand the game and plays with items that give a taste of it (the lamp, the moving cards, the rarity cards, the reveal demo), never the real thing, so they want an account to try it for real. Steam sign-in appears only in the top bar and the final call (09); the hero has none.

| Component | Behavioral rules |
|---|---|
| Module | Powers on once, when its top edge passes 85% of the viewport height, whatever the module's height (a fixed position, never a share of its area), and at once when it holds keyboard focus, is the target of a jump (side gauge, in-page link, URL fragment) or is above the viewport on load. Power-on (brackets, contents, gauges and pips; see Motion) never keeps content invisible longer than its own duration, and a module never powers off. The content is in the page from the start; without JavaScript every module is on. |
| Motion switch | "Animations réduites" in the landing's top bar, for every visitor: a toggle button (`aria-pressed`), first in the tab order after the wordmark. On: the whole Reduced motion profile applies at once, the landing's form included. Its state is kept in a first-party cookie, so the server renders the reduced form from the first paint of the next visit and on every signed-out page. Off: the system preference applies, read in CSS so it holds from the first frame. At sign-in an "on" switch becomes the account's "ANIMATIONS RÉDUITES" setting, OUI; off, the account's setting is unchanged. |
| Hero | "Embarquer sur le pont" opens the signed-out hub. |
| Lamp field | With a pointer that hovers and is fine: the lamp follows the pointer while it moves over the field; 2.5s after the pointer stops or leaves, it sweeps on its own. Phone and touch: it always sweeps on its own. On its own it heads for the next card not yet found and holds about 1.6s on a find. A card is found when the lamp's center passes over it: it gets its corner marks and "Trouvé", and the counter "Jeux retrouvés n / n" goes up. Once every card is found, the lamp settles on the last one and stops; it also runs only while the hero is in view and the tab visible. The sweep mode word shows the current mode: auto, manual or still. Everything resets on reload. The field is decoration: hidden from assistive technology, nothing in it focusable, and it never catches a click. |
| 01 · Concept, rarity cards | Each card tilts toward the pointer like any card face (see Card face). The row is a list named by the copy deck; each card's accessible name gives the title, studio, year, genre, rarity and number. On the phone the row scrolls sideways: there the cards do not tilt and accept sideways and vertical panning (`touch-action: pan-x pan-y`). The row is one tab stop only while it overflows (see Interaction Primitives, Keyboard). The chance under each card is the normal capsule's, read from what the game applies. |
| 02 · La Confrérie, lore panel | Holds the Brotherhood's story, in French and English. Its text waits for the dedicated lore session, with a length bound so the 8-column panel balances the goal panel; the landing ships only with its text (see Implementation notes, Landing ship conditions). "Participer à l'écriture" scrolls to 07 and moves focus to its h2. |
| 02 · La Confrérie, goal panel | The real weekly goal, the landing's only live one: its line, count, target, gauge and participants; the end day and hour in the visitor's own time zone, never with "UTC". 04 shows no goal; 05's goal tile is a fixed example of a past week, without live figures. |
| 03 · Comment ça marche, reveal demo | "Révéler" flips the face-down card to a sample card face and announces it politely (see Copy deck); the button then reads "Recommencer", which turns the card face down again and readies the next sample. Focus stays on the button. It never opens a capsule or adds a card to anything. |
| 04 · En direct, live feed list | The real activity feed's five latest entries, with the Feed entry's rules and the Quiet feed fill. A new entry is inserted as one node at the top and the last node removed; the list is never re-rendered. It receives entries only while the module is in view, and pauses while hovered or while focus is inside the module; buffered entries arrive together when it resumes. Not a live region, and no status line on the landing (the full feed is one link away). "Ouvrir le fil d'activité" opens the feed. The season facts are real data, read when the page is served (cached, see Implementation notes); they do not tick live. No LIVE ticker in this module. States: see State Patterns, Landing live data. |
| Roadmap (06 · Feuille de route) | Shows the app's roadmap data, derived from the initiative and curated by the author: epics as milestones and, under each, a few stories that matter to a player, each with its status ("Fait", "En cours", "À venir"), in the author's player-facing wording; not everything in the initiative appears. On the phone the row scrolls sideways and is one tab stop only while it overflows. Each story's status is in its text, not only in its marker. "Voir toute la feuille de route" opens the roadmap page. |
| 07 · Open source et contributions | "Voir le projet" opens the GitHub repository in a new tab (said in its accessible name). Artists, narrators and scribes, and developers all answer through it: issues, discussions, contributions. |
| 08 · Un jeu libre, support panel | "Soutenir" opens the donation page in a new tab, the same link as menu 09. |
| Final call (09 · Embarquement) | Valve's image opens Steam's sign-in; on return the player lands on the hub, as everywhere. "Embarquer sur le pont" opens the signed-out hub. |
| Landing footer | "Mentions légales" opens the legal page; "Soutenir" and "Code source" open the donation page and the repository in a new tab. |
| Moving cards | Only with a pointer that hovers and is fine (`(hover: hover) and (pointer: fine)`), only where both gutters beside the content column can hold them, never on the phone and never under "Animations réduites". A few cards pass down the gutters, never over the content column, faster than the scroll, their position driven by the scroll. A pointer drag moves a card aside; it stays where it is dropped, keeping that offset as the page scrolls, until the page reloads. A card catches the pointer only on its own visible box. While keyboard focus is inside the page content the cards fade out, so none ever rests over a focused element. They never tilt toward the pointer. Hidden from assistive technology, never focusable, no keyboard equivalent; nothing depends on moving them. |
| Side gauge | Wide desktop only (from `{spacing.breakpoint-landing-gauge}`). A navigation region named "Position sur la page", after `<main>` in the DOM and placed with CSS: each marker is a link that jumps to its module (00 to the hero) and moves focus to the module's h2 (`tabindex="-1"`, its scroll margin keeping it clear of the top bar), instantly under reduced motion. Only the current marker carries `aria-current="location"`. The track follows the scroll and is hidden from assistive technology. Accessible names: see Copy deck, Landing. |

### Seasonal allocation (after the launch)

| Component | Behavioral rules |
|---|---|
| Allocation screen | A full screen shown once at the player's first visit after a season is published, before the hub: the Brotherhood line, the ended season's unlocks (tiers reached, card backs, achievements, community goal rewards), the sets that follow ("vos sets vous suivent"), the tiers to win back, and one button to continue. The hub and the capsule page lead there while it is unseen; continuing receives the allocation if still pending and marks it seen. A player with no card from an earlier season never sees it. Its h1 names the season; each group is a list. Phone: one scrolling column. Layout drawn with the author before it is built (see `DESIGN.md`, Seasonal allocation). |

### Public pages and sign-in

| Component | Behavioral rules |
|---|---|
| Public card page | The card tilts under the pointer. "VOIR SUR STEAM ↗" opens the store page. "OUVRIR MES PREMIÈRES CAPSULES" opens the sign-in panel, beside the two links (author, 2026-10-14). "Découvrir" opens the landing; "Embarquer sur le pont" opens the signed-out hub, where every action asks for sign-in (author, 2026-10-14). The LIVE strip shows the three latest feed entries. |
| Public profile | A player's showcase (author, 2026-10-15), read in this order: identity band (name, "Membre depuis …", SIGNALER, the profile action, then the key numbers: distinct cards owned over the season's total, complete sets, achievements earned over total), VITRINE, stats (RARETÉS, ACTIVITÉ), SUCCÈS, SETS. The h1 is the player's name; VITRINE, SUCCÈS and SETS are h2s; the stats are a region named "Statistiques". No tabs, filters or visibility line. VITRINE shows the cards the player chose, in their order; each opens its card detail, with the back "◀ PROFIL". On their own profile, the owner sees "◀" and "▶" under each showcase card, which move it one place (accessible names: Copy deck, Profile showcase); no "◀" on the first, no "▶" on the last; the first card is the hub's (author, 2026-10-15). RARETÉS counts unique cards at their best owned rarity, one number per rarity, so the five add up to the cards count. ACTIVITÉ counts capsules opened, first discoveries and trades concluded. SUCCÈS gives earned over total and the four latest earned, with no date and no link to the Succès screen. SETS lists the started sets, complete ones first, then by the share of the set owned; a row opens that set's album read-only (see Set album, "◀ PROFIL"). "VOIR LA COLLECTION COMPLÈTE" opens that player's full collection (see Information Architecture). "SIGNALER" opens the report dialog; signed out, it opens the sign-in panel, like any action that needs an account. Copy: see Copy deck, Public profile. Reference: [mockups/key-public-profile.html](mockups/key-public-profile.html). |
| Profile action | One action at most, under the name, set by the viewer's relation to the player (table below). "AJOUTER EN AMI" sends the invitation in one click, with no extra limit; it lands in Amis like a code invitation, and the button becomes "EN ATTENTE". "ACCEPTER" creates the friendship, as in Amis, and the button becomes "ÉCHANGE". "ÉCHANGE" opens the trade in progress with that friend, or a new draft, as on the friend row. |
| Sign-in panel | Holds only its title line (see Copy deck) and Valve's horizontal official button, the only link to Steam's sign-in. "✕", Esc or the scrim returns to the page, still signed out. |

**Profile action by relation** (author, 2026-10-15):

| Viewer | Action | SIGNALER |
|---|---|---|
| Signed in, no friendship and no invitation | "AJOUTER EN AMI" | Yes |
| Invitation sent to the player | "EN ATTENTE", inactive | Yes |
| Invitation received from the player | "ACCEPTER" | Yes |
| Friends | "ÉCHANGE" | Yes |
| Friends, the viewer's profile private | The Trades closed line (Copy deck) in place of "ÉCHANGE" | Yes |
| The player themself | None | No |
| Signed-out visitor | None | Yes, it opens the sign-in panel |

## Opening protocol

1. Activating the canister sends the opening request and locks the trigger: a second activation does nothing, and each request carries an idempotency key.
2. The canister charges ("ARMEMENT", about 300ms of squash) while the answer arrives; this masks the wait.
3. **Success:** LEDs and hazard band turn orange, the caps blow off and the five cards are dealt.
4. **Refusal** (no capsule in reserve, or any error): the canister disarms without blowing its caps, the status returns to "SCELLÉE" or "EN ATTENTE", and the reason appears inline under the open button and in a toast. Nothing opens.
5. The art of each card starts loading on the answer; a card never flips before its art is ready or known to be missing.
6. During the opening and each reveal, in-app back controls, the tab bar and Esc navigation are disabled. Browser Back is allowed and loses nothing: the five cards are already in the collection.

## State Patterns

Messages quoted by key are in the Copy deck.

| State | Surface | Treatment |
|---|---|---|
| Signed out | Everywhere | The root is the landing (see Information Architecture). Everything else visible. An action that needs an account opens the sign-in panel; closing it returns to the same page, still signed out. |
| Signed in at the root | /fr, /en | The hub. A signed-in player never sees the landing (author, 2026-10-14, triage). |
| First session | Hub, capsule | The reserve holds 10 capsules. A Rare or better is guaranteed by the 10th capsule, without any visible sign. No capsule ever promises a rarity. |
| Reserve full | Hub, capsule | 10 pips lit; the countdown is replaced by "Réserve pleine" (capsules chip, capsule panel). The daily capsule claim is disabled until a capsule is opened (Copy deck, Daily capsule). |
| Special capsule in the reserve | Hub, capsule | The daily capsule (better odds) and the goal's rare capsule join the same reserve and open with the same ritual; they are not told apart among the canisters. Whether a goal reward is added above 10 is open. |
| Reserve empty | Capsule | The canister is replaced by the empty-reserve line (Copy deck, Capsule states); the open button reads "RÉSERVE VIDE" and is disabled. |
| Opening refused | Capsule | See Opening protocol, step 4. |
| Opening in progress | Capsule | Navigation disabled (see Opening protocol, step 6). |
| Cards dealt | Capsule | The reveal hint and the revealed counter (Copy deck, Capsule hints and Capsule states). |
| Capsule inventoried | Capsule | The inventoried hint; status "INVENTAIRE COMPLET". |
| Reveal abandoned | Capsule | The cards joined the collection at opening; leaving loses nothing. Leaving another way (hub, menu, tab bar), nothing resumes on return; coming back from one of its cards' details (Back or "◀ CAPSULE") shows that capsule with its cards face up, all in the tray on the phone, whatever was revealed before leaving (author, 2026-10-08). Coming back the same way from a set album its celebration opened shows that capsule with its set results, still, in their final state: the entrance does not replay (author, 2026-10-17). |
| Daily capsule ready / collected | Hub | "PRÊTE" with "RÉCUPÉRER", then "RÉCUPÉRÉE" with the countdown. A second collection the same day is refused. |
| No notable pull yet | Hub | The empty showcase (Copy deck, Empty showcase). While it shows, the daily capsule's "RÉCUPÉRER" turns secondary, so the hub keeps one lime action. |
| Goal in progress | Hub | Gauge, "TOUS LES JOUEURS n / target", reward line. |
| Goal reached | Hub | The gauge is full and the panel reads "OBJECTIF ATTEINT"; every contributor receives the rare capsule (and the week's card back, when the goal has one) with a toast; a non-contributor sees the reached state only. |
| Goal missed | Hub | At the week's end the panel shows the final count; nothing is granted. |
| Week rollover | Hub | A new goal with a new target starts at the week boundary; the gauge empties. |
| Image missing / loading | Any card | "IMAGE INDISPONIBLE" in the art box / a dark hatched box until the filtered cover is ready. |
| Collection empty | Collection | Every slot is a missing-card slot naming its game. |
| Filter empty | Collection | The empty-filter line (Copy deck, Collection). |
| Set tier reached | Capsule, collection, hub, feed | At opening, the set celebration after the last reveal, announced in the capsule live region; the row and the album show the tier lit. The tiers and completions one opening reaches make one feed entry and one LIVE ticker line, naming the highest and the count ("Léa atteint 4 paliers · Metroidvania ADEPTE"); a single result keeps its own entry. |
| Set complete | Capsule, collection, hub, feed | The celebration "SET COMPLET"; the row shows owned = total and the album its COMPLET stamp; on a tiered set, completion comes after its last tier: at 100 % the celebration reads "SET COMPLET · Roguelike", the album adds the COMPLET stamp beside the set's name, and the live message is "Set complet : Roguelike, 62 cartes sur 62." A back tier that unlocks a card back is announced with it. A tier stays reached when cards leave. |
| Trade draft | Trade board | "BROUILLON", both sides editable, with the validity line. "ENVOYER LA PROPOSITION" enables once the friend's side holds a card; while the player's side is empty, the open-request help line shows under it. "ABANDONNER" deletes the draft. |
| Trade waiting for the player | Trade board, list, badge | "À VOUS", the proposal line and the expiry. The friend's offered copies are tagged reserved. Actions: "ACCEPTER", "CONTRE-PROPOSER", "REFUSER". When the friend's side is empty, it reads "À vous de choisir" and the open-request line replaces "ACCEPTER"; accepting is refused by the server too. |
| Counter-proposal in progress | Trade board | Both sides become editable, marked "EN ÉDITION", with the counter-proposal line. "RENVOYER LA CONTRE-PROPOSITION" enables once the friend's side holds a card, the player's side may stay empty; "ANNULER LES MODIFICATIONS" restores the received proposal, after a confirmation if anything changed. |
| Counter-proposal sent | Trade board | The 7-day expiry restarts; the player's reserved copies become exactly those on the player's side; copies the player removed are released. |
| Trade waiting for the friend | Trade board, list | "EN ATTENTE", the waiting line, the player's copies tagged "RÉSERVÉE"; an empty side reads "À choisir par Léa" and reserves nothing. Action: "ANNULER LA PROPOSITION". |
| One trade per pair | Friend row, friend profile | With a trade in progress with that friend, "ÉCHANGE" opens that trade directly, without a refusal; a page left open from before the trade lands on it with the one-at-a-time refusal. |
| Not enough copies | Trade board | Accepting when a copy is no longer available: "EXEMPLAIRES INSUFFISANTS" inline and in a toast; nothing moves. |
| Nothing to place | Card picker | The no-card line (Copy deck, Card picker) with the reason (none owned, or all reserved). |
| Trade done | Trade board, list | The swap plays; "CONCLU" and the concluded line; received cards tagged "NOUVEAU". The trade appears in the feed and counts toward the goal. |
| Trade declined, canceled, expired | Trade board, list | "CLOS", with the outcome and its age ("refusé il y a 4 j"). Reserved copies are released. A proposal expires after a fixed 7 days. Action: "NOUVEL ÉCHANGE AVEC LÉA". |
| Friend banned or deleted mid-trade | Trade board, list | The trade closes ("CLOS") and every reserved copy is released. |
| Friend goes private mid-trade | Trade board, list | The trade closes ("CLOS") and every reserved copy is released; the board says the friend's profile is now private. |
| Invite code invalid / own / repeated / sent | Amis | The matching line (Copy deck, Invite code messages). |
| Invitation received / accepted / ignored | Amis | Received: the invitation row with "ACCEPTER" / "IGNORER". Accepted: the "NOUVEL AMI" toast and the friend in the list. Ignored: the row disappears. |
| No invitation | Amis | The no-invitation line (Copy deck, Friends). |
| No friend, no trade | Amis, Échanges | One line pointing to the invite panel. Not mocked. |
| Friend presence | Amis, menu 05 | Online, current activity, or last seen; "Profil privé" for a private friend, never counted online. |
| Quiet feed | Fil d'activité, ticker | With few players, lower-tier pulls fill in on a quieter background. Never empty while any activity exists. |
| Feed filter empty | Fil d'activité | The empty-filter line (Copy deck, Feed). |
| Profile visibility | Profile, public pages | PUBLIC: anyone, signed out included, sees the profile and its shared cards. AMIS UNIQUEMENT: friends only. PRIVÉ: nobody else, friends included; friendships stay and trades close (CAP-11). The summary in Profil et paramètres states it; the public profile page carries no visibility line (author, 2026-10-15). |
| Profile not visible to this visitor, or banned | Public card page, public profile, friend profile | The page says the profile is not available. The public profile shows one unavailable page for every case (no player with that link, a private profile, friends only and the viewer not a friend, a banned player), so a ban cannot be told from a missing player (Copy deck, Public profile). A private profile never has a public page, friends included, so the profile page never shows a private owner (author, 2026-10-15). |
| No showcase chosen | Public profile, hub | The public profile has no VITRINE section, never an empty slot; the hub shows its automatic card (see Hub, Showcase). |
| Achievement earned | Any signed-in screen | The achievement toast (Copy deck, Achievement toast), one per achievement, as the app already shows it. During a card reveal it waits until the reveal ends, so it never spoils a card; the Succès screen shows the tile earned. |
| Card back locked / equipped | Back picker | Locked: the condition inline and the "DOS VERROUILLÉ" toast. Equipped: the preview turns to the new card back; the "DOS ÉQUIPÉ" toast. |
| Export | Profil et paramètres | "PRÉPARATION…" on the button, then the "EXPORT PRÊT" toast with the download; a failure says so inline with a retry. |
| Sign out | Profil et paramètres | Opens the landing (author, 2026-10-14; supersedes the signed-out hub). |
| Account deleted | Delete dialog | Opens the landing with a toast confirming the deletion (author, 2026-10-14: the landing replaces the signed-out hub). |
| Language switched | Profil et paramètres | The interface and card text change at once; `<html lang>` follows. |
| Clipboard refused | Share sheet, invite panel | The link stays selected in its field with the manual-copy line inline. |
| Cold load | Every screen | Panels appear as their data arrives; counts show "—" until known. Not mocked. |
| Network or server error | Everywhere | Inline where the action was, and a toast; nothing was lost; the screen stays usable. Not mocked. |
| Banned account | Steam sign-in | Sign-in is refused with a one-line explanation (spec CAP-15). Not mocked. |
| Not staff | Back-office | The address answers as if it did not exist. |
| Phone held sideways | Every screen (phone) | Nothing happens (see Responsive & Platform). |
| Landing live data | Landing (02, 04) | Fewer than five feed entries: the list shows those there are, the Quiet feed fill included, and keeps its column's height. No entry at all: the no-activity line (Copy deck, Landing live states). A count of zero shows "0" with its zero form ("0 participant"). A figure or block that cannot be read shows "—" and the rest of the page renders. No weekly goal open: the 02 goal panel keeps its title and explanation and shows "—" for the line, count and gauge `[ASSUMPTION]`. The roadmap data ships with the app and is checked at build, so 06 never renders empty. |

## Interaction Primitives

- **One activation reveals:** click, tap, Enter or Space on a face-down card reveals rarity and game together. One surprise per card.
- **Guard:** a just-revealed card ignores activation for 400ms, so a double activation never skips the reveal or leaves the screen.
- **Tilt:** cards lean toward the pointer, up to about 10° (16° on the capsule screen); on the phone only under a finger held still for 150ms. The card eases toward the pointer as it enters (about 600ms to settle) and back to flat as it leaves (about 650ms); the varnish's reflection rides that eased tilt in and out, sliding opposite it, so nothing jumps and nothing fades. Cards in scrolling content keep vertical panning (`touch-action: pan-y`); in a row that scrolls sideways (the landing's 01 and 06 on the phone) cards do not tilt and keep both pannings (`pan-x pan-y`); only the capsule stage captures every gesture.
- **Hover is a lift; touch is a press.**
- **Drag (landing only):** with a fine pointer, a moving card follows a pointer drag and stays where it is dropped. Nothing else is dragged, and nothing needs a drag.
- **Swipe, always with a button:** on the phone a revealed card swipes into the tray ("RANGER" does the same); in the card detail, swipe or the ◀ ▶ buttons move between cards. Long-press is never required.
- **Keyboard:** Tab order follows reading order. Keys 1 to 8 open menu items only while focus is in the hub menu. On the landing, the side gauge's markers are ordinary links, after the page content in the tab order; a sideways-scrolling row (01 and 06 on the phone) is one tab stop only while it overflows, the arrow keys scroll it, and its items are not focusable. Arrow keys move focus within the collection grid (Up and Down move one row, whatever the column count), the card picker grid, and radio and segmented groups; in a stepper they change the quantity. Enter submits the friend code.
- **Esc:** closes the topmost overlay (dialog, sheet, zoom, legend, toast) and nothing else. With no overlay open, it cancels a counter-proposal edit after confirmation. Otherwise, when no edit is pending and no text field has focus, it returns to the hub (except during an opening).
- **Not in the MVP:** bulk opening, live trades, card marks, a guide (a tour of what to do; the rules reference "Comment ça marche" is not one, author 2026-10-13), and any input at opening that improves the odds (noted for later).

## Motion

Movement is fluid at 60fps (transforms and opacity only; continuous loops never animate layout or background position). Small effects tick in steps. Only genuinely live things blink (the LIVE marker, once per second). Short and snappy everywhere. Opening and reveal timings are those of the "Arcade" opening study, multiplied by 1.18. Easings: `{components.motion.ease-out}`, `{components.motion.ease-lock}`, `{components.motion.ease-spring}`.

| Moment | Duration | What happens |
|---|---|---|
| App start | 340ms, once per session | A brief power-on brightening of the screen (overshoot capped at 1.1). |
| Screen change | about 300ms | The old screen slides 32px away and fades (170ms); the new one slides in from 48px (260ms, 40ms later); the star field does not move (it only twinkles, a few stars at a time). Panels lock into place with a short overshoot, staggered over 400ms at most. |
| Phone sub-view | 260ms in, 200ms out | Slides over its screen. |
| Phone sheet | 240ms | Rises from 60px. |
| Canister at rest | loop | Breathes 2px over 6s; a light band sweeps across it; rays turn slowly behind it. |
| Capsule opening (Explosion A) | about 1.2s | ARMEMENT squash while the request runs, then LEDs and hazard band orange, the caps blow off up and down with smoke jets ("ÉJECTION"), a ring, one short warm flash and a shake. Desktop: the five cards burst out in an arc and land in a row, 45ms apart, squashing with a little dust. Phone: they land as a stacked pile, bottom card first, with 5px offsets, ±1.4° tilt and 1.5 times the desktop stagger. |
| Reveal, Commune | about 0.7s | A small lift, a flip with overshoot, a burst of pixels in the tier color, a settle. |
| Reveal, Peu commune | about 0.8s | A short tremble first, one ring, a slightly bigger burst. |
| Reveal, Rare | about 1.0s | Longer tremble, ring, bigger burst with confetti. |
| Reveal, Épique | about 1.2s | Tremble with particles converging, two rings, purple rays, small "ÉPIQUE" banner. |
| Reveal, Légendaire | about 2.45s | The stage dims ("SIGNAL LÉGENDAIRE", gold light); the card jumps up and charges (on the phone the jump stays inside the play area, 50px at most); a one-and-a-half spin; impact with a gold and confetti burst, three rings, a gold fan of rays, one flash and a strong shake; banner "LÉGENDAIRE !" with title and year; the card drops back with a bounce. |
| Tout révéler | about 180ms between cards | Each card plays its own tier reveal; a Légendaire plays in full before the next. Flashes never overlap: at most one full-screen flash per sequence. |
| Tray (phone) | 260ms | A stored card shrinks into its slot; the slot pops; an Épique or better adds a spark burst. The caption plate pops in 320ms (380ms for a Légendaire). |
| Set celebration | at most 0.9s per result, once; stacked results start 180ms apart (four end by about 1.4s) | The panel fades in with the set's name and an empty gauge (120ms, 3 steps). From 80ms the gauge fills to the count before this capsule, then crosses the tier tick to the new count in the tier colour (380ms, 6 steps); the count rolls to its new figure (120ms) as the crossed tick lights and rises 4px (100ms) and its notches pop (180ms). When the capsule crossed two ticks of the set, each lights as the fill passes it, lower first. From 470ms the ribbon wipes on, left to right in 8 steps (200ms), then its fold appears. The tier's juice follows (`DESIGN.md`, Set celebration): sparks fly out over 320ms in 6 steps, from the tick at 440ms and from the ribbon's end at 620ms; glints blink once from 560ms (240ms, 60ms apart); glosses sweep the ribbon at 640ms and 700ms (200ms each; a rank with one gloss sweeps it at 640ms, and a rank plays only the details its step adds, `DESIGN.md`, Juice by rank); SET COMPLET's bar turns lime at 440ms under one 200ms glow, and its stamp frame prints in a 160ms wipe from 680ms. Folded line: the marks of the tiers its results reached light one after another (from 80ms, 90ms apart, 180ms each), then the accent ribbon wipes on at 420ms. Then everything stays still: nothing loops, nothing replays on a timer. On the phone a result plays its entrance when "▸" brings it in. Results shown again on returning to the capsule appear still, without their entrance. |
| Next capsule | about 0.5s | The cards sink and fade (160ms, staggered); a new canister rises into place (260ms). |
| Idle float | 14s loop | Showcase card, planet, detail card, public card and back preview drift 2px at most with ±0.5° rotation over a breathing ground shadow. |
| Card detail re-entry | 260ms | The card turns slightly as it comes in. |
| Daily capsule | 480ms (phone 520ms) | A small canister arcs to the capsules chip (phone: the CAPSULE tab); the count brightens. |
| Trade swap | about 0.75s | Both sides' cards arc across the central strip, one over, one under, squash on landing; a ring and confetti at mid-point; a faint flash. Stacks travel as one. |
| Card back equip | about 0.35s | The preview turns edge-on and back as the new card back; the tile hops; a small burst. |
| Locked card back | 220ms | A short sideways shake of the tile. |
| Toast | 250ms in | Rises into place. |
| Dialog | 160ms scrim, 220ms panel | The panel rises 16px into place. |
| Feed entry | 280ms | Slides down from the top. |
| Landing hero entrance | 420ms each, 80ms apart | Kicker, hook, line and button rise 14px into place (`{components.motion.ease-lock}`). |
| Landing lamp | until every card is found | Powers on in five steps over 300ms, 350ms after load; follows the pointer quickly or sweeps slowly; a found card's marks lock in over 240ms in four steps. |
| Landing moving cards | scroll-driven | 1.5 to 1.9 times the scroll speed with a slow sideways sway and a slow turn, within the gutters; a dragged card lifts in 120ms and settles in 220ms; a card fades out in 150ms when keyboard focus enters the content and back when it leaves. |
| Landing module power-on | about 0.6s, once, when the module's top edge passes 85% of the viewport height | Corner brackets grow in five steps (360ms); contents fade (260ms) and rise 14px (420ms), 70ms apart; gauge segments and pips light one by one, 40 to 45ms apart. |
| Landing reveal demo | 700ms | The sample card flips (`{components.motion.ease-lock}`). |
| Landing star field | scroll-driven | The two star layers drift with the scroll at 0.12 and 0.05 of it, a landing-only exception to the still star field (author, 2026-10-14); still under reduced motion. |

**Reduced motion.** Applies when "ANIMATIONS RÉDUITES" is OUI in Profil et paramètres, or when it is SYSTÈME (the default) and the system asks for it; NON plays the full motion even when the system asks for less. For a visitor without an account, it applies when the landing's motion switch is on (its cookie), otherwise when the system asks for it. The rule: nothing translates, rotates, scales, shakes, flashes, blinks, sweeps or loops; state changes are 150 to 220ms crossfades; the ticker stops and shows its latest items still; the LIVE marker stays lit; the star field, rays, the Légendaire's glitter twinkle, sheen, canister breathing and idle floats stop; flashes are removed (not dimmed); tilt is off. Exceptions, spelled out:

- **Opening:** the canister fades out in 200ms and the cards fade in (240ms, 40ms apart).
- **Reveal:** each card crossfades to its face in 220ms; a Légendaire shows a still "LÉGENDAIRE !" banner for 1.4s instead of its sequence.
- **Trade swap:** the two sides crossfade to their new contents.
- **Locked card back:** no shake; the condition appears inline.
- **Set celebration:** no entrance: each result crossfades in over 200ms already in its final state (gauge at the new count, tick lit, ribbon in place) and stays still; no gloss, glint, spark or glow. The COMPLET stamp keeps its fixed −6° tilt (a static tilt is not motion) and never drops, bounces or rotates into place.
- **Screen changes, sheets, sub-views, toasts, feed entries:** instant or crossfaded, no slide.
- **App start:** no brightening.
- **Landing:** no moving cards; the lamp does not travel: while the pointer is over the field it jumps to the pointer and finds the card there, otherwise it rests on the first card, with the first two cards already found; modules fade in over 180ms without rising, under the same trigger as the full power-on, and their brackets, gauges and pips appear at once; the reveal demo crossfades in 220ms; new feed entries appear without sliding; the star field stays still; the 03 countdown stops (as in the mock).
- **Card reflection:** every card face keeps its studio reflection, still, at its rest position (the flat card's); a Légendaire's glitter stays as still, faint flakes.

## Card backs

- **What it is:** the image on the player's own face-down cards at opening (the card detail no longer shows it for a card not owned; author, 2026-10-20). Only the player sees it. Every account starts with "Standard".
- **Earning:** the back tier of a theme or hall of fame set, its first tier at or above half its cards (that set's back; gold in earlier seasons), a successful community goal, some achievements, events or seasons.
- **Choosing:** one active card back at a time, in Profil et paramètres; it applies from the next capsule, including when chosen during an opening.
- **Season marks:** a back shows the mark of the season chosen in the picker; the picker lists the seasons it was earned in.
- **Locked card backs** are listed with their unlock condition ("Atteindre le palier Expert du set Roguelike"); an achievement that unlocks one shows it on its tile.
- **The prototype's eight** are examples; the shipping list is open (see `DESIGN.md`, Card backs).

## Accessibility Floor

Behavior only. Contrast values live in `DESIGN.md` (see Colors).

- **Keyboard:** every action works with the keyboard; focus order follows reading order; the focus ring (`{components.focus-ring.css}`) shows on every focusable element, distinct from hover; scroll padding keeps it clear of sticky bars. Focus destinations: see Focus after each step.
- **Screens and dialogs:** inactive screens are inert and hidden from assistive technology; each screen has one h1, a main region and a navigation region; dialogs are named by their title, trap focus and return it on close.
- **Capsule live region:** a dedicated polite region announces each reveal (Copy deck, Capsule live region). "Tout révéler" posts one summary of the cards it revealed. A Légendaire posts its signal at the start and the result on landing. Opening refusals are announced there too. After the last reveal message (or the Tout révéler summary, or a Légendaire's result), the set results are posted once, as one message that lists every result in the order the banners show them, including when the banner folds them into "n PALIERS ATTEINTS". The region appends each message as a new node and never replaces one posted less than 2s earlier. The reveal caption plate and the banners are not live regions.
- **Feed and ticker:** the feed list is not a live region; while the feed is not focused, a status line announces new entries in batches at most every 30s; with "ANIMATIONS RÉDUITES" on, these announcements stop. The ticker is hidden from assistive technology.
- **Toasts** are polite status messages; errors also stay inline until the next action.
- **Rarity** is never carried by color alone: shape and name accompany it; where only the icon fits (rarity counter, tray, thumbnails), the name is in the accessible name and in the "RARETÉS" legend.
- **Card text order:** title, studio (the developer), year, genre, rarity, number, then state (copies, NOUVEAU, reserved count). A card's accessible name always holds the full title, the studio, the year and the number, whatever its face shows or cuts with an ellipsis. Cover canvases, thumbnails, rays and particles are hidden from assistive technology; avatars have empty alt text next to a visible name; rarity icons are hidden when the name is beside them. A missing-card slot reads "Manquante : Into the Breach, 2018". In a signed-in player's Toutes les cartes, a card not owned adds "non possédée" ("not owned") to the end of its accessible name; the lock is hidden from assistive technology.
- **Set celebration:** each result is a link whose accessible name repeats its live message and ends with its hint, "Palier adepte atteint : Roguelike, 16 cartes sur 62. Voir le set."; the folded line's ends with "Voir les sets en cours." (Copy deck, Set celebration). Inside the link, the ribbon's marks, the gauge and its ticks, the stamp frame, the sparks and the link's arrow are hidden from assistive technology: the name carries the tier and the count. The phone's "▸" is a button named "Résultat suivant". The focus ring goes around the whole result, inside the plate on the phone.
- **Gauges** are progress bars with a text value, except the set celebration's, decorative inside its link. Countdowns are not live; their accessible text changes at most once a minute.
- **No information only in a tooltip** (`title`).
- **Moving content:** the ticker pauses on hover and stops with "ANIMATIONS RÉDUITES"; every looping or blinking effect stops with it; nothing blinks faster than once a second. A visitor without an account stops them with the landing's motion switch (see Landing, Motion switch).
- **Touch:** at least 44 × 44 CSS px for every phone target, 8px apart.
- **Readability:** no meaningful information below 10px in the two fonts; meaningful text at 12px and below is bold; VT323 never under 20px and never for figures, which are in JetBrains Mono bold; `{colors.dim}` is decorative only (see `DESIGN.md`, Typography).
- **Zoom and text spacing:** breakpoints are in CSS px of the viewport, so browser zoom reaches the phone layout; text is in rem; text rows use a minimum height so user text spacing never clips them.
- **Language:** `<html lang>` follows the chosen language; text in another language (a Steam description, the interface's English words "LIVE" and "REPOST", the Steam image's words in its link name) carries its own `lang`. A first visit uses the browser's language.
- **Links and sign-in:** links that open a new tab or leave gameble say so (see Copy deck, Landing, for the landing's hidden suffixes); Valve's image has empty alt text, and its link's name starts with the image's own words, "Sign in through Steam", marked English (`lang="en"`), and says it opens Steam (see Copy deck, Landing, Steam sign-in name).
- **Landing:** one h1 (the hook) and one h2 per module, its accessible name holding the module label and the title ("01 · Concept, Chaque carte est un jeu Steam."); headline-sized lines are headings too: 07's recruiting line (h3, the roles under it h4) and 08's support line (h3). Landmarks are only main, the side gauge's navigation, the top bar and the footer: modules are `<section>` elements without an accessible name. The lamp field, the moving cards and the gauge's track are hidden from assistive technology. Every example (02's four tiles, 03's illustrations, 05's six visuals) is either hidden from assistive technology or named as one block starting "Exemple : " ("Exemple : Hugo a fait la première découverte de Hollow Knight"); only 04 and the 02 goal panel carry real data. The reveal demo announces its card politely. Roadmap statuses are written, not only drawn.

### Focus after each step

| Step | Focus goes to |
|---|---|
| Capsule screen opened | "OUVRIR LA CAPSULE" (when the reserve is empty: the back button, or the GAMEBLE link when there is none) |
| Set album opened (desktop and phone) | Its h1, the set's name |
| Back from a set album | The set progress row, or the set celebration result, that opened it |
| Back button (desktop) | The control that opened the screen just left, when it is still there; otherwise the h1 `[ASSUMPTION]` |
| Cards landed | Card 1 |
| A card revealed | Stays on that card |
| All five revealed (one by one or with Tout révéler) | "OUVRIR LA SUIVANTE" |
| Card stored in the tray (phone) | The next card, or "OUVRIR LA SUIVANTE" after the fifth |
| Card zoom closed | Its tray slot |
| Trade board opened | The board heading |
| "CONTRE-PROPOSER" | The add slot on the player's side |
| Card removed with "✕" | The next card on that side, or its add slot |
| Card picker closed | The add slot that opened it |
| Swap finished | The board's status line |
| Sub-view opened (phone) | Its heading |
| Back or dialog closed | The element that opened it |
| Return from Steam sign-in | The hub's first menu item (phone: the PONT heading) |
| Side gauge marker (landing) | The module's h2 |
| "Participer à l'écriture" (landing) | 07's h2 |
| "Révéler" or "Recommencer" (landing reveal demo) | Stays on the button |
| Landing after sign-out or account deletion | The landing's h1; the deletion toast is announced politely |

## Responsive & Platform

The layout rules (no scaling, page scroll, breakpoints at 720 and 1180px, content capped at 1280px, per-screen reflow, collection grid sizing, phone column) live in `DESIGN.md` (see Layout & Spacing). Tablets follow the width rules. Behavior specific to each form factor:

- **Desktop:** the card detail is its own page; dialogs are centered; toasts appear at the bottom. After a resize, the collection grid re-measures its cards and re-runs the pixel filter at the rendered size, and the capsule stage re-lays dealt cards in place without replaying.
- **Phone:** portrait only; held sideways, nothing changes, and the installed web app declares `"orientation": "portrait"` in its manifest (a browser tab cannot be locked). Document scroll; sub-views slide over their screen; dialogs are bottom sheets; toasts appear at the top; safe areas are respected. Checked at 390 × 844 and 360 × 740.
- **Hub on the phone:** kicker, capsules chip and rarity counter, showcase, community goal panel, daily capsule panel, set progress rows, LIVE ticker. The menu lives in the tab bar and the PLUS rows (no numbers).
- **Capsule screen on the phone:** the cards land as a pile; one large card at a time; tap to reveal; the caption plate shows rarity, title and year; tap, swipe or "RANGER" stores the card in the tray; "Tout révéler" reveals and stores the rest; a filled slot opens the card zoom.
- **Collection on the phone:** two columns with the studio visible; the FILTRES sheet and the search field; the RAPPORT panel folds; the card detail slides over with "◀ GRILLE" (or "◀ CAPSULE" when opened from a capsule), ◀ ▶ buttons and a position line.
- **Trades on the phone:** the list first; the trade board slides over ("◀ LISTE") with the friend's side on top and actions pinned at the bottom; the card picker is a full-height sheet.
- **Landing on desktop:** moving cards only with a fine hovering pointer and where both gutters can hold them (a touch tablet or a zoomed window gets none); the side gauge from `{spacing.breakpoint-landing-gauge}`; the lamp follows a fine hovering pointer and sweeps on its own for touch.
- **Landing on the phone:** no moving cards; the lamp sweeps on its own and is visible on the first screen (the field sits behind and around the hero text, never opening behind the copy, see `DESIGN.md`, Landing, Lamp field); the motion switch is an icon in the top bar; the 01 card row and the roadmap scroll sideways; no side gauge; sign-in through the top bar's Steam image and the final call.
- **Browsers:** the modern-browser floor of the architecture (AD-27); the public pages a link opens also serve older browsers. Native store apps stay possible later.

## Inspiration & Anti-patterns

Visual inspirations and rejections live in `DESIGN.md` (see Brand & Style and Do's and Don'ts). Behavioral ones:

- **Lifted from the "Arcade" opening study:** card burst, bounce landing, tiered reveals and the Légendaire sequence.
- **Lifted from the author's canvas (`imports/claude-design-concepts/`):** the hub with its numbered menu as the only navigation.
- **Rejected — the medieval direction's navigation through scenery objects** ("looks cheap"), and a permanent sidebar: replaced by the hub.
- **Rejected — dust and two surprises per card:** one activation reveals everything.
- **Rejected — the stratagem-like arrow code to open a capsule.**
- **Rejected — the generator's filler mechanics:** combat, decks, card stats, market, sales, currencies, recycling.
- **Lifted from the landing renders (2026-10-14):** the console with numbered modules of [.working/landing-direction-c.html](.working/landing-direction-c.html) for the page, and the card field of [.working/landing-direction-a.html](.working/landing-direction-a.html) for the hero (reworked into the lamp) and its near layer of moving cards (now kept to the gutters).
- **Rejected — a profusion of cards on the landing:** the mission is to find lost cards, so only a few cards move.
- **Rejected — a LIVE ticker in the landing's live module** (it duplicated the feed list), **a Steam button in the hero**, and **status readouts beside module titles**.
- **Rejected — a guide (a tour of what to do; the rules reference "Comment ça marche" was asked for by the author on 2026-10-13), and opening every capsule at once.**

## Key Flows

### Flow 1 — First session (Léa, on her PC, clicks a link Hugo posted on Discord)

1. Léa clicks Hugo's link. Discord's preview showed the card's title and rarity, no image.
2. Signed out, she lands on the public card page: Hollow Knight large and tilting under her pointer, its publisher, "LÉGENDAIRE", genre, year, number, the short description and "VOIR SUR STEAM ↗". The page also offers "Découvrir" (the landing) and "Embarquer sur le pont" (the signed-out hub); she follows neither (Flows 5 and 6 do).
3. Below, the LIVE strip shows pulls and trades with their rarities. Through the signed-out hub she could open the feed and browse the sets, all slots empty.
4. She presses "OUVRIR MES PREMIÈRES CAPSULES". The sign-in panel opens with its title line and Valve's official button; she signs in with Steam.
5. She lands on the Pont de commandement. The capsules chip reads 10 CAPSULES with "Réserve pleine"; menu 01 carries a lime "10"; the empty showcase invites her to open her first capsule.
6. She opens the capsule screen and activates the canister: it charges, the caps blow off, five cards land face down wearing the Standard card back.
7. She reveals one: a Commune, announced as she sees it. She reveals the next, then presses "TOUT RÉVÉLER" for the rest.
8. "OUVRIR LA SUIVANTE". Capsule after capsule, the rarity counter ticks up.
9. **Climax:** before her tenth capsule ends, a card trembles, rings and bursts in blue light: a Rare or better, the first prize her collection holds.
10. The reserve runs out and the capsule screen shows when the next one arrives. She goes back to the Pont, opens 02 and browses her sets: owned cards with "NOUVEAU", missing ones naming the game and its year.
11. The next day, the daily capsule panel says "PRÊTE"; she collects it and opens it.

Failure: she closes the sign-in panel or Steam refuses → she stays on the public card page, signed out.

### Flow 2 — A trade with quantities (Hugo and Léa, a few days later)

1. Léa entered Hugo's code 7K2Q-F3NX in Amis; Hugo saw her invitation and pressed "ACCEPTER". They are friends.
2. In Amis, Hugo presses "ÉCHANGE" on Léa's row. The trade board opens as "BROUILLON".
3. "CHOISIR SES CARTES": from Léa's collection he picks Disco Elysium, one copy.
4. "PLACER MES CARTES": he picks Slay the Spire; he owns three, so a stepper appears; he sets ×2 ("/3") and presses "PLACER". His side shows a stack with "×2" and "1 carte · 2 ex.".
5. "ENVOYER LA PROPOSITION". The "PROPOSITION ENVOYÉE" toast confirms; his two copies are tagged "2 RÉSERVÉES".
6. That evening on her phone, Léa sees an orange "1" on the ÉCHANGES tab. The trade board slides over: "À VOUS", Hugo's proposal, "Expire dans 7 j".
7. She wants to keep Disco Elysium. "CONTRE-PROPOSER": both sides open ("EN ÉDITION"). She removes Disco Elysium from what she gives, places Dead Cells ×2, and on Hugo's side lowers Slay the Spire to ×1. "RENVOYER LA CONTRE-PROPOSITION".
8. Hugo sees the orange badge on 04 ÉCHANGES, opens the trade and presses "ACCEPTER".
9. **Climax:** the two stacks arc across the central strip, one over, one under, and squash as they land; a ring and confetti burst between them. The "ÉCHANGE CONCLU" toast: Dead Cells ×2 joins his collection, tagged "NOUVEAU".
10. The trade appears in the feed and the LIVE ticker and counts a little toward the community goal.

Variant, the open request: Hugo wants Hades but has no idea what Léa would like. He places Hades on her side, leaves his own empty under "Laissez ce côté vide : Léa choisira ce qui lui plaît en retour." and sends. Léa reads "Hugo vous laisse choisir.", has no "ACCEPTER", presses "CONTRE-PROPOSER", takes Celeste from his collection and sends it back; Hugo accepts and the swap plays.

Failure: Léa refuses, Hugo cancels, or 7 days pass → "CLOS", reserved copies released. If a copy is no longer available when Hugo accepts → "EXEMPLAIRES INSUFFISANTS", nothing moves.

### Flow 3 — Equipping a card back earned at a set's back tier (Inès, after a lucky week)

1. Inès reveals the card that brings the theme Roguelike to 31 of its 62 cards. After the reveal, "PALIER EXPERT · Roguelike 31/62" plays; the album shows EXPERT lit over its 31, and Roguelike's back unlocks: Expert is its back tier. (62 cards: Apprenti 7, Adepte 16, Expert 31, Maître 47, complete 62.)
2. From her player chip she opens Profil et paramètres. In "DOS DE CARTE", the Roguelike back is no longer grayed.
3. She chooses it: the preview turns to the Roguelike back, "DOS ACTIF"; the "DOS ÉQUIPÉ" toast.
4. **Climax:** at her next capsule, the five cards land face down wearing it. Only she sees it.

Variants: she reaches gold through a trade rather than a capsule → the card back unlocks the same way. She chooses it while a capsule is open → it applies to the next one.

### Flow 4 — Sharing a pull (Hugo, right after a Légendaire)

1. Hugo's capsule ends on a Légendaire: Hollow Knight. He activates the revealed card; its card detail opens.
2. "PARTAGER": the share sheet copies the link ("COPIÉ ✓").
3. He pastes it in his friends' Discord channel.
4. **Climax:** Discord unfurls the preview with "Hollow Knight" and "Légendaire", without the game image; his friends click through to the public card page (Flow 1).

Failure: the clipboard is refused → the link stays selected in its field with the manual-copy line.

### Flow 5 — From a shared card to the first capsules (Camille, a player, through the landing)

1. Camille opens a shared card's link (who shared it, and where, does not change the flow). Signed out, she lands on the public card page.
2. She follows "Découvrir" and arrives on the landing.
3. She scrolls to understand the game: the hook "Des jeux ont été perdus. La Confrérie part les retrouver. Rejoignez-la.", the lamp finding cards in the dark, then the modules powering on one after another, from the concept to the roadmap.
4. She plays with the items, for example the lamp, a moving card she drags aside and the card she flips in 03. Each gives a taste, never the real thing; a little frustrated, as the landing intends, she wants to try it for real.
5. She creates her account with Steam, from the final call or the top bar's image, which do the same. Steam's sign-in returns her to the Pont de commandement with a full reserve.
6. She opens her first capsule; five cards land face down and she reveals them.
7. **Climax:** capsule after capsule she sees her collection and a few sets build up and progress; toasts and her first achievements come quickly (author, 2026-10-14): "SUCCÈS DÉBLOQUÉ · Première capsule" after her first opening, set celebrations as her first tiers come, and soon "Première Épique", each achievement toast waiting until the reveal on screen ends.

Failure: Steam refuses, or she leaves Steam's page → she is back on the landing, still signed out `[ASSUMPTION]`.

Variant — a direct visitor: Camille types gameble's address or follows a plain link, and meets the landing at /fr. « Embarquer sur le pont » takes her to the signed-out hub; she browses it, and the first action that needs an account opens the sign-in panel and its Steam image. Closing the panel leaves her on the hub, still signed out.

### Flow 6 — From a shared card to the code (Yanis, a developer)

1. Yanis arrives as Camille does: a shared card's link, the public card page, "Découvrir", the landing.
2. He scrolls to 07 · Open source et contributions (on a wide screen he could also jump there with the side gauge).
3. He reads that the code is entirely free, that tedious tasks are done by AI and the rest by humans, and the developers' role: anyone can propose a fix or an idea.
4. **Climax:** "Voir le projet" opens the GitHub repository in a new tab (author, 2026-10-14); the landing stays open in its own tab.

Supporting the project comes later, in a second phase, and is not part of these flows (author, 2026-10-14).

## Implementation notes

Build rules found while prototyping and reviewing; they bind the build. Architecture-level items are listed in `ux-gameble.md` (see For the architecture).

- **Mocks are never source code.** Port the look and the timings, not the scripts. Listeners and timers are registered when a component connects and removed when it disconnects; caches are bounded.
- **Tokens are CSS values.** Use the exact values in `DESIGN.md` frontmatter (pixel outlines, borders, bevels, scanlines) as custom properties.
- **3D card stack:** never put 3D transforms on a `<button>` that holds card faces, and never put a grouping property (opacity below 1, filter, overflow, clip-path, mask, mix-blend-mode, isolation) on or between the tilt and flip layers: either one flattens the 3D and shows the mirrored back. Use plain layers (tilt, then flip), both faces with `backface-visibility: hidden`, and a flat transparent button on top for focus and activation. One reveal path for a single activation and for "Tout révéler". A visual regression test covers a tilted, revealed card.
- **Hide every descendant of an inactive screen,** not only the screen: a child made visible on purpose (a dealt card) otherwise shows through.
- **Content timing:** card content reaches the browser when the capsule is opened; the reveal is only an animation; counters update at each reveal so the interface never spoils a card.
- **Dialogs and Esc:** every modal and bottom sheet is a native `<dialog>` opened with `showModal()`, in Stimulus and React; the hotkeys controller ignores events already handled, events while a dialog is open and events from form fields, so one Esc never both closes a dialog and navigates. Single-key shortcuts can be turned off.
- **No inline style:** server HTML carries no `style` attribute (the CSP blocks it); progress bars and gauges get their values as CSS custom properties set by a controller.
- **Large grids:** a collection grid beyond about 60 slots is paginated or virtualized, and only visible cards are filtered.
- **Fonts:** the app moves from Space Mono to JetBrains Mono in its own ticket (see Landing ship conditions). The three latin font files (JetBrains Mono 400 and 700, VT323) are preloaded with `font-display: block` and a short block period, so a fallback swap never reflows two-line card titles.
- **Daily capsule arc:** runs from `turbo:before-stream-render` (both positions known before the DOM is replaced) and dispatches `gameble:bank-changed`.
- **Landing ship conditions:** the landing goes live (the root switch, the landing's last story) only once all of these hold: the lore text exists in French and English; the pioneer feature is built, so the « Découvrez » tile tells the truth; the repository is public with a license file, so 07's and the footer's open-source claims hold; the roadmap sync and the switch to JetBrains Mono are built first (author, 2026-10-14, triage).
- **Landing roadmap data:** `_bmad-output` is not in the production image, so the roadmap the landing shows is app data generated from the initiative; that sync is its own build ticket (see Landing ship conditions).
- **Landing data load:** the landing is the most visited page. Each data block (feed, season facts, goal, sample cards, roadmap) is cached per locale with a short cache lifetime, and signed-out GETs of the root are throttled like the other public pages. Like them, the landing also serves link previews and older browsers. The feed list subscribes to its updates only once module 04 comes into view.
- **Landing motion cost:** the lamp's veil is one oversized element with a fixed hole, moved by `translate3d` (never a mask repainted each frame); its frame loop runs only while the lamp runs (see Component Patterns, Landing, Lamp field). The field's bottom fade is a ground-colored gradient laid over it, not a mask. Lamp, moving-card, gauge and power-on maths live in pure modules with unit tests.
- **Landing without inline style or script:** modules are visible by default and the power-on controller arms only those not yet in view when it connects; the hero entrance is pure CSS; per-element values (lamp slots, rotations, staggers) come from CSS classes or are set through the CSSOM by a controller; fonts are self-hosted subsetted woff2, never `data:` URIs. The reveal demo is a Stimulus controller over server-rendered card faces, not the booster island, and its announcements are rendered by the server.
- **Landing covers:** a small set of games is reused across the lamp, 01, the moving cards and the examples, so cached covers and filtered bitmaps are reused; covers draw lazily and modules use `content-visibility: auto`. Their cost is measured on the reference low-end phone (load, frame time while the lamp sweeps, bytes).
- **Landing mock deviations (do not copy from `mockups/landing.html`):**
  - its 34px « Révéler » on the phone (`{spacing.button-height-sm-phone}` applies);
  - its footer links wrapping with a 4px gap (`{spacing.touch-gap}` applies), and its 24px-tall wordmark link on the phone;
  - its `nowrap` example rows that clip at 320px, and its example feed rows « Inès complète Dark Souls » and « Nina a reposté Hades » without a period (the Feed copy applies);
  - its side gauge marker names without the visible number, which break WCAG label-in-name (see Copy deck, Landing, Side gauge), and its marker numbers in `{colors.dim}`: they are the markers' only visible text, so they use `{colors.muted}`;
  - its rotated 11px text in the COMPLET stamp of 05 (rotated text only in VT323 at 24px or more, see `DESIGN.md`, Collection, COMPLET stamp);
  - its goal end « Fin lundi à 00:00 UTC » (the visitor's own time zone applies, never "UTC"), and its second weekly goal (« Tous les joueurs ») in 04 (the goal is live only in 02);
  - its module power-on triggered by a share of the module's area (the fixed 85% line applies, see Component Patterns, Landing, Module), its feed list re-rendered every 8s, and its mask-repainting lamp;
  - its « TERMINAL EN LIGNE » status in the top bar: no decision settles it `[ASSUMPTION: dropped]` (see Open questions, Landing top bar).
- **Daily bonus capsule:** it holds 3 cards, so the revealed counter and hints count to 3 for it ("Cartes révélées : n / 3").

## Open questions

Non-blockers, left open.

- **Achievements:** the mock's 40 are illustrative; which exist, and which unlock card backs.
- **Card backs:** beyond one per theme or hall of fame set at its back tier, which ship, and whether every successful community goal grants one; each set back's design.
- **Ticker and feed thresholds**; hourly totals in the ticker.
- **Special capsules:** whether the daily and goal capsules look different in the reserve, and whether a goal reward can exceed 10.
- **Weekly goal lifecycle:** where the week boundary shows, and the reached, missed and rollover states (tagged above).
- **Unmocked states:** cold load, offline, network error, banned account, non-staff back-office.
- The **signed-out hub** is not mocked.
- **Public profile:** what SUCCÈS and SETS show for a player with nothing earned or started; whether a showcased card the player no longer owns leaves the showcase.
- **Roadmap page:** reached from "Voir toute la feuille de route"; decided, not designed. Whether the link is hidden until the page exists, and whether 06 caps at six milestones with two stories each.
- **Roadmap sync shape** (for its ticket): a committed generated file with a CI check, or generation at image build; where the player-facing strings live, given every string belongs in `en.yml` and `fr.yml`.
- **Landing copy in English:** written at the build, under the same rules as the French, and approved by the author in the pull request, or written first in a copy ticket.
- **Landing top bar:** the mock's "Terminal en ligne" status beside the Steam image, kept or dropped.
- **Motion switch beyond the landing:** whether the signed-out hub and the public card page also carry the switch (its cookie already applies there).
- **Landing sample cards:** settled (author, 2026-10-20): each sample slot shows the published season's top card of its rarity, no curated list.
- **Landing live figures:** what "cette semaine" (calendar goal week or the last seven days) and "aujourd'hui" (the game's UTC day or the visitor's) count for the 04 facts.
- **Signed-out entry points:** the signed-out hub's own address; where a signed-out deep link that needs an account, a failed Steam return and Esc lead (landing or signed-out hub); the phone tab bar and back button on the signed-out hub.
- **Landing language and meta:** whether the landing offers a FR/EN switch or only the URL segment; its page title, meta description and link-preview image.
- **Landing license line:** which license the repository takes, and whether 07's "Licence libre." names it.
- **Landing copy points for the author:** moved to `review-copy-2026-10-14.md`, under Copy points carried from EXPERIENCE.md (2026-10-14).
- **Avatars:** the source (Steam avatar through the pixel filter?) is not decided.
- **English copy** and English rarity names are not written.
- **Skip control:** whether a "Passer" control (and Esc) jumps an opening or reveal sequence to its end state (accessibility review M11).
