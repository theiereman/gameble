# Triage of the duel validation report — 2026-11-14

Walks every finding of `validation-report.md` (95: 3 critical, 19 high, 39 medium, 34 low) against the documents as they stand after the live-duel rework (commits `0afcdffa`, `f3822f00`, `fa47c392`): `spec-gameble/spec-gameble.md` (CAP-39 to CAP-43, Constraints, Non-goals, Assumptions, Open Questions), `spec-gameble/duel-rules.md`, `spec-gameble/achievements.md`, `ux-gameble/EXPERIENCE.md`, `ux-gameble/DESIGN.md`, and, for flags only, `architecture-gameble/architecture-gameble.md`.

Finding ids follow the report's order within each severity: C1–C3, H1–H19, M1–M39, L1–L34. New items found while walking the documents are N1–N7 (fixable) and A3–A4 (author). No file other than this one was edited.

While this triage ran, another session left uncommitted edits in `DESIGN.md` and `EXPERIENCE.md` (boards 10 to 12 of "Écrans des Duels": the blades drawn, the Duelliste back accepted, the desktop layouts). The triage reads those edits as current: they close L7 and part of M4 and N3.

## Counts

| Class | Critical | High | Medium | Low | Total |
|---|---|---|---|---|---|
| Obsolete | 0 | 6 | 7 | 3 | 16 |
| Fixed | 3 | 6 | 7 | 7 | 23 |
| Still open, fixable without the author | 0 | 7 | 25 | 23 | 55 |
| Still open, needs the author | 0 | 0 | 0 | 1 | 1 |
| **Total** | **3** | **19** | **39** | **34** | **95** |

New since the rework: 7 fixable inconsistencies (N1–N7), 2 author questions (A3, A4), and 9 architecture flags (section at the end). Fixable items in all: 55 + 7 = 62, plus the trademark line split out of L28.

## Still open — needs the author (3)

**A2 (L28) — A success signal for release 1.4.** The spec's Success signal covers the MVP and the market; duels have none (the Open question "Live duel load" names what 1.4 tests, not what counts as success).
- Question: what tells the author that live friend duels worked?
- Options: (a) "30 days after release 1.4, at least 10 players have finished a live duel with no automatic move, and half of them duel again in a later week"; (b) a volume target, such as 50 finished duels a week; (c) no signal, only the Open question's measurements.
- Recommendation: (a): it measures repeat play among friends, which is what the live format bets on, and it is readable from duel records alone.

**A3 (new) — Live timers and players who need more time.** 30 seconds to call and 20 to answer, with no extension, while a call means reading three hand cards' five values, both decks and the opponent's card (Accessibility Floor, Duels, says nothing about time). WCAG 2.2.1 admits a real-time exception, and the duel is a real-time event between two people, so nothing fails formally; screen-reader and cognitive users will still time out into automatic moves, which also cost the capsule.
- Question: does 1.4 offer a slower pace?
- Options: (a) keep one pace and write the real-time exception into the Floor; (b) the challenger picks "Rythme normal" / "Rythme lent" ("Normal pace" / "Slow pace", for example 90 s to call, 60 s to answer) in Défier un ami, shown to the friend before they accept, for both players; (c) a personal setting that lengthens only the player's own timers.
- Recommendation: (b): one choice per duel, fair to both, no new screen, and it keeps automatic moves meaningful. (c) is unfair to the opponent; (a) leaves the problem.

**A4 (new; caveat on C2) — Validate the new live rules before the build.** The critical "the call is solved" finding came from a simulation. The rework (hidden call, the answerer choosing after seeing the caller's card, open decks, one hand for calling and answering) answers it in principle, but no simulation of the new rules is recorded; the spec's Open question defers "how a newcomer's thin collection fares" to the release itself.
- Question: simulate the new rules before slicing stories, or learn in production?
- Options: (a) rerun the abuse reviewer's model on the new rules (first-caller advantage, a strong deck against a 150-card newcomer, the gain from reading the visible decks, how often the margin decides); (b) ship and measure, as the Open question says; (c) a paper playtest between two friends.
- Recommendation: (a): it is a few hours, the last critical finding came from exactly this, and a first-caller or collection-size imbalance is cheaper to fix in `duel-rules.md` than after release.

## Still open — fixable without the author (62)

Each item names the file and section, then the text to add or change. French copy is quoted with its English. Items that settle a value no source decided carry `[ASSUMPTION]` so the author can still overrule them.

### High

**H2 — Échanges sub-tabs: subtitle, naming, addresses.** Default (last used), semantics (a `nav` of two links) and badges are settled; three gaps remain.
- `DESIGN.md` › Chrome › Top bar table, row "Échanges": replace the right side with: `On ENTRE AMIS, "Entre amis · une proposition expire après 7 jours"; on MARCHÉ, nothing beyond the Balance chip`.
- `DESIGN.md` › Duels › "Échanges sub-tabs": replace "as a two-part segmented control at the top of the screen" with: "as two equal parts in one bar across the screen's full content width, above both columns on desktop (two links, see `EXPERIENCE.md`, Accessibility Floor, Duels; not the Settings row's segmented group, whose selected segment fills with accent)".
- `EXPERIENCE.md` › Information Architecture, row "Échanges", end of the last cell: "; each sub-tab keeps its own address, ENTRE AMIS the trade list's and MARCHÉ the market's, so the market's teaser and every link to it keep working `[ASSUMPTION]`". Then in Open questions › Duels delete "the ÉCHANGES sub-tabs' addresses and".

**H3 — Duel and duel result: the missing visual rules.** `DESIGN.md` › Duels, add:
- "**Duel header:** the friend's name in `{typography.label}` `{colors.muted}`; "MANCHE <n> / 10" in `{typography.kicker}` (`{typography.kicker-phone}` on the phone); the score "<a> – <b>" in `{typography.count-large}` (`{typography.count-large-phone}` on the phone), `{colors.text-max}`."
- "**Duel result:** the score in `{typography.count-large}` `{colors.text-max}` beside the sentence ("Victoire contre Hugo") in `{typography.body}`; "Départagé à l'écart" in `{typography.label}` `{colors.muted}`; on a capsule, a panel with the duel capsule's small canister and a 2px `{colors.capsule-duel}` edge, "CAPSULE DE DUEL GAGNÉE" and its link; then the ten rounds as an ordered list of rows at least `{spacing.touch-min}` tall on `{colors.panel}`, each the round number in `{typography.number}`, the caller, both cards as small thumbnails with their values in words, the stat and direction, the outcome word as Round outcome; "REJOUER" the screen's one primary button."

**H4 — Cards with no stats yet, and the first values' label.** Release day is settled (stats computed at deploy); a season published mid-week is not, and "Valeurs du lundi" is false for the deploy week.
- `duel-rules.md` › Stats, first bullet, replace with: "A stat's value is a percentile, computed when release 1.4 is deployed and when a season is published, then every Monday 00:00 UTC. A card's trump is its most extreme stat, in either direction."
- `spec-gameble.md` › CAP-39, second bullet: "The stats are computed when release 1.4 is deployed and when a season is published, then every Monday at 00:00 UTC, and hold until the next computation."
- `EXPERIENCE.md` › Copy deck › "Decks and duel stats": replace "Valeurs du lundi <date>" ("Values of Monday <date>") with "Valeurs du <date>" ("Values of <date>"); same change in Duels › Duel profile.

**H5 — Visitors.** The ranking part is obsolete; three gaps remain.
- `EXPERIENCE.md` › Duels › Duel profile, end of the cell: "It is not on the public card page, which stays the card alone `[ASSUMPTION]`."
- `EXPERIENCE.md` › Information Architecture, row "Marché", end of the last cell: "A visitor sees the market alone, with no ENTRE AMIS / MARCHÉ bar." Then in Open questions › Duels delete "and a visitor's way to the market" (the row already says: from the landing only).
- `spec-gameble.md` › CAP-18, first bullet: after "the market read-only (CAP-33)," insert "Le Chattomètre,".

**H7 — Which edition a deck slot and the duel profile show.** The slot unit is settled (an edition); the screens do not say which edition they show.
- `duel-rules.md` › Decks, add: "- The deck editor lists one entry per edition the player owns, its season shown beside its trump. A card's detail shows the duel profile of the edition its "Prix moyen" reads."
- `EXPERIENCE.md` › Duels › Deck editor, after "each card with its trump": insert ", one entry per owned edition with its season ("S1")".

**H8 — Three focus rows still missing.** `EXPERIENCE.md` › Focus after each step, add:
- `| "DÉFIER UN AMI" or "DÉFIER EN DUEL" | The sheet's title |`
- `| A deck refuses a card (full, or its game already there) | Stays on that card; the refusal is announced politely |`
- `| ENTRE AMIS or MARCHÉ followed | The screen's h1 |`

**H13 — Deck blocks and the reserved count (spec side; architecture flag F2 below).** `duel-rules.md` › Decks, after the bullet "A card in one or more decks blocks one copy…", add: "- A deck takes a free copy: a card whose copies of that edition are all reserved (a trade, a listing) cannot enter a deck, and the editor shows it with the Reserved tag. A deck-blocked copy counts as reserved wherever free copies are counted: trades, listings, entrusting and the spares of trade suggestions. Going private releases trade reservations only, never deck blocks."

### Medium

**M4 — The blades emblem.** The grid and its tones are now drawn (DESIGN › Special capsules › Duel pixel grids, board 10); the Emblems bullet still counts two. `DESIGN.md` › Special capsules › Emblems: replace "Both are the medium level" with "All three are the medium level", and append: "The blades (17 × 17, board 10): light steel #e8f1f8 and #7d9bb8 in the `{colors.outline}` outline, gold crossguards, dark grips; their contrast on the emblem window is measured at the build and written here, as the cup's was. `emblems.html` holds the sun and the cup only; the blades' reference is board 10." Also, in the "The canister" bullet, after ""RÉCOMPENSE DE MISSION"" insert ", "CAPSULE DE DUEL"".

**M6 — Duel profile bar: track contrast and which end is 100.** `{colors.line}` reads 1.91:1 on `{colors.panel-sunken}`, against DESIGN's own Lines rule (progress tracks use `{colors.line-deep}` or brighter).
- `DESIGN.md` › Duels › Duel profile: replace "an 8px bar on a `{colors.line}` track filled in `{colors.accent}` to the percentile" with "an 8px bar on a `{colors.panel-raised}` track with a 1px `{colors.line-deep}` edge (3.38:1 on `{colors.panel-sunken}`, 3.2:1 on `{colors.panel}`), filled in `{colors.accent}` (9.2:1 on `{colors.panel-sunken}`); the bar runs from 0 to 100 toward the stat's first direction in `duel-rules.md` (most popular, best rated, most recent, discovered first, most widespread), and the words always name the card's stronger side ("Plus confidentielle que 97 % des cartes", never "Plus populaire que 3 %")".
- `EXPERIENCE.md` › Accessibility Floor › Duels, append: "The duel profile's bars are hidden from assistive technology; each row's words carry the value."

**M8 — Lime for a won round.** `DESIGN.md` › Colors › Lime bullet: after "the active card back" insert ", and a won round's outcome word in a duel".

**M9 — Surfaces with behaviour but no DESIGN bullet.** `DESIGN.md` › Duels, add:
- "**Défier un ami:** a Phone sheet on the phone and a Modal on desktop: the deck and the friend as two Radio lists with `{spacing.touch-min}` rows, each friend with avatar and presence as Friend row; a greyed option keeps its name and reason in `{colors.muted}` and dims only its thumbnail or avatar; the waiting line in `{typography.body}`, its seconds in `{typography.number}`."
- "**Challenge received:** the Modal pattern, titled "<name> vous défie en duel.", the deck as a Radio list, "ACCEPTER" primary, "REFUSER" secondary, the seconds left in `{typography.number}`, `{colors.alert}` from 10 s."
- "**Deck list:** rows at least `{spacing.touch-min}` tall on `{colors.panel}`: the name in `{typography.label}` `{colors.text}`, a draft's "<n> / 12" as Deck slots draws it, then the twelve covers as small thumbnails in one row, two rows of six on the phone."
- "**Duel record:** a figure group in the profile's ACTIVITÉ stats: wins, losses and draws in `{typography.number}`, labelled as the other stats."
- "**Monday stats entry:** a feed entry with no card image, as Le Chattomètre's weekly entry: its line, then up to six rows, each the card's name as a link, the stat, and the old and new percentile in words; any arrow is text in `{colors.text}`, never coloured."

**M10 — Where the DUEL block sits on the card detail.**
- `EXPERIENCE.md` › Card detail: after "folded beyond three lines." insert "Then the "DUEL" block (see Duels, Duel profile)."
- `DESIGN.md` › Card detail ("FICHE DE LA CARTE"): append "The DUEL block follows ÉDITIONS as one more group of fact rows (see Duels, Duel profile), in the facts column on desktop and under ÉDITIONS on the phone."

**M11 — The duel line on the profile.** The Duel record row exists; the profile rows that own the layout do not mention it.
- `EXPERIENCE.md` › Public profile: after "ACTIVITÉ counts capsules opened, first discoveries and trades concluded." insert "Once the player has finished a duel, ACTIVITÉ also gives the "Duels" line of wins, losses and draws (see Duels, Duel record)."
- `EXPERIENCE.md` › Copy deck › Public profile: add "Duels" ("Duels") after "Échanges conclus" ("Trades concluded").

**M12 — What the Monday entry measures.** `EXPERIENCE.md` › Duels › Monday stats entry: replace "the three largest rises and falls, each card linked to its page" with "the three largest rises and the three largest falls, a card's move being its largest change of one stat's percentile since the previous computation, each card linked to its page with the stat and both percentiles in words ("Quake, popularité en hausse, de 55 à 62"; "Quake, popularity up, from 55 to 62"); the first Monday compares with the values computed at the deploy `[ASSUMPTION]`".

**M13 — Comment ça marche and duels.**
- `EXPERIENCE.md` › Information Architecture, row "Comment ça marche": after "the weekly mission's reward," insert "duels (decks, the five stats and the trump, a round, ties, automatic moves, the duel capsule and its odds),".
- `EXPERIENCE.md` › Duels › Duels screen, end of the cell: "Under the record, the link "Règles du duel" ("Duel rules") opens Comment ça marche at its duels section."

**M14 — Deck naming refusals and the five-deck cap.** `EXPERIENCE.md` › State Patterns, add:
- `| Deck name refused | Deck editor | Inline under the field, the previous name kept: empty "Donnez un nom au deck." ("Name the deck."); over 24 characters "24 caractères au plus." ("24 characters at most."); a name the player already uses "Vous avez déjà un deck de ce nom." ("You already have a deck with this name.") |`
- `| Five decks | Duels | "+ NOUVEAU DECK" leaves the list; "MES DECKS · 5 / 5" and "Cinq decks au plus : supprimez-en un pour en créer un autre." ("Five decks at most: delete one to make another.") |`

**M15 — Failure states of a live duel.** `EXPERIENCE.md` › State Patterns, add:
- `| Own connection lost | Duel | A banner "Connexion perdue… <s> s" ("Connection lost… <s> s") counting down the 60 s; on return the duel resumes where it stands; past 60 s the duel goes on with automatic moves and, on return, shows its current state or its result. |`
- `| Move not delivered | Duel | The button reads "ENVOI…" ("SENDING…") and the move is retried while its timer runs; a move the server has not received at the deadline is played automatically and marked as such. |`
- `| Waiting for the other move | Duel | The round heading says whose move it is ("Hugo répond…"); no spinner. |`

**M16 — Défier un ami edge cases.** `EXPERIENCE.md` › State Patterns, add:
- `| No friend | Duels, Défier un ami | EN LIGNE reads "Ajoutez des amis pour les défier." ("Add friends to challenge them.") with "AJOUTER DES AMIS", to Amis. |`
- `| Friend has no complete deck | Défier un ami | The challenge is sent; the friend's dialog offers "REFUSER" only (No deck); the sheet reads "<name> n'a pas de deck complet." ("<name> has no complete deck.") `[ASSUMPTION]` |`
- `| Friend no longer available | Défier un ami | Gone offline or into another duel before "DÉFIER": the sheet refuses inline "<name> n'est plus disponible." ("<name> is no longer available.") and greys the friend. |`
- `| Rematch unavailable | Duel result | "REJOUER" is `aria-disabled` with "<name> n'est plus en ligne." ("<name> is no longer online.") or "Duel en cours". |`

**M18 — Lines the states promise and the Copy deck lacks.** `EXPERIENCE.md` › Copy deck:
- Row "Duels", add: no complete deck "Il vous faut un deck complet de 12 cartes pour défier." ("You need a complete 12-card deck to challenge.") · after the dialog closes "Le défi de <name> a expiré." ("<name>'s challenge expired."), "Défi refusé." ("Challenge refused."), "<name> a annulé son défi." ("<name> cancelled the challenge.") · the reveal heading "Manche <n> gagnée : <carte>, <valeur>, contre <carte>, <valeur>, <sens>. <a> à <b>." ("Round <n> won: <card>, <value>, against <card>, <value>, <direction>. <a> to <b>."), with "perdue" / "nulle" ("lost" / "drawn") · "départagée à la valeur exacte" ("decided on the exact value") · group names "Votre main", "Caractéristique", "Sens" ("Your hand", "Stat", "Direction") · "Capsule de duel déjà gagnée aujourd'hui." ("Duel capsule already won today.").
- Row "Decks and duel stats", add: "Supprimer le deck « <deck> » ? Les cartes restent dans votre collection." ("Delete the deck "<deck>"? The cards stay in your collection.") · "SUPPRIMER" · "ANNULER" · "Retirer <carte> de <n> decks ? Un deck complet redevient un brouillon." ("Remove <card> from <n> decks? A complete deck becomes a draft again.") · "RETIRER" · "ANNULER".
- Row "Bell", add to the lines: "Votre duel contre <name> attend votre retour." ("Your duel against <name> is waiting for you.") · "Duel contre <name> terminé : <victoire|défaite|égalité>, <a> à <b>." ("Duel against <name> finished: <win|loss|draw>, <a> to <b>.") · and to the actions "Reprendre" ("Resume").
- Row "Special capsules", add: "EN OUVERTURE · CAPSULE DE DUEL" ("OPENING · DUEL CAPSULE") · the label band "CAPSULE DE DUEL" ("DUEL CAPSULE").
- `EXPERIENCE.md` › Information Architecture, row "Fil d'activité": after "set tiers and completions" insert ", the Monday stats entry".

**M19 — Mocks outside the repository.**
- `DESIGN.md` › Duels (Reference) and `EXPERIENCE.md` › Duels (intro): export "Navigation des Duels" boards A1, A2 to `mockups/duels-navigation.html` and "Écrans des Duels" boards 1 to 12 to `mockups/duels-screens.html`, and link the files in place of the claude.ai links.
- `EXPERIENCE.md` › Visual references (line 24), after the `mockups/mobile.html` link, and `EXPERIENCE.md` › Native apps, after the `mockups/native-top-bar.html` link: "(drawn before 2026-11-14: MARCHÉ is now a sub-tab of ÉCHANGES and DUELS the fifth tab)".

**M20 — Surfaces not flagged as unmocked.** `EXPERIENCE.md` › Open questions › Duels, append (after checking boards 1 to 12, keeping only what they do not draw): "Unmocked unless boards 1 to 12 draw them: the card detail's DUEL block, the Deck list rows, the Challenge received dialog, the Monday stats entry, the Reserved tag's "Dans un deck" with "RETIRER DES DECKS", the duel canister with its blades, the profile's Duels line."

**M25 — Deck names shown on a friend's cards.** The Reserved tag names the decks holding a card, and the card picker shows the friend's side too, so a friend reads another player's deck names and contents outside any duel. `EXPERIENCE.md` › Reserved tag, append: "Deck names, the "Dans un deck" tag and "RETIRER DES DECKS" show to the owner only; on a friend's side a deck-blocked copy simply counts as unavailable `[ASSUMPTION]`." `duel-rules.md` › Decks, last bullet: "The trade, sale and entrust screens name those decks" → "The owner's trade, sale and entrust screens name those decks; nobody else sees them".

**M26 — Badge names in the Copy deck.** The Count badge row holds two French names; nothing is in the Copy deck, and there is no English. `EXPERIENCE.md` › Copy deck, new row "Duel and Échanges badges (2026-11-14)": "Duels, 1 duel en cours" ("Duels, 1 duel in progress"), "Duels" at zero · "Échanges, 2 échanges et 1 enchère à voir" ("Trades, 2 trades and 1 auction to see"), each part left out at zero, "Échanges" at zero · "Entre amis, 2 échanges en attente" ("Between friends, 2 trades waiting"), "Entre amis" at zero · "Marché, <n> enchères dépassées" kept for the MARCHÉ sub-tab. French plurals with their `zero` form.

**M27 — Greyed options' contrast.** `EXPERIENCE.md` › Duels › Défier un ami: replace "drafts listed greyed with "<n> / 12"" with "drafts listed with "<n> / 12"", and replace "one already in a duel greyed with "Duel en cours"" with "one already in a duel with "Duel en cours"", then append: "An unavailable draft or friend keeps its name and reason in `{colors.muted}` and dims only its thumbnail or avatar; it is a radio with `aria-disabled`, its reason in its name ("Vieux briscards, brouillon, 9 sur 12"; "Hugo, duel en cours")."

**M28 — Deck editor without a pointer.** `EXPERIENCE.md` › Duels › Deck editor, append: "The collection is one tab stop with arrow keys inside, as the card picker's grid; each card is a toggle button (`aria-pressed`) whose name ends with "dans le deck" when it is. The status line reads "<carte> ajoutée, 7 sur 12" ("<card> added, 7 of 12"), "<carte> retirée, 6 sur 12" ("<card> removed, 6 of 12"), "Le deck est complet.". On the phone a line under the top bar stays in view with the deck's name and "<n> / 12". The name saves on blur. A failed save keeps the change on screen, posts "Enregistrement impossible, réessayez." ("Could not save, try again.") and is retried with the next change."

**M29 — Duel rows in the Motion table.** `EXPERIENCE.md` › Motion, add:
- `| Duel card face up | 200ms | The caller's card flips face up, then the answer's beside it; a plain flip whatever the rarity: no burst, flash or shake. The outcome shows once both are face up. |`
- `| Duel card drawn | about 200ms | The drawn card slides into the hand. |`
- Under Reduced motion, add: "- **Duel:** a card shows its face at once, and a drawn card appears in place."

**M31 — Repeated actions told apart.** `EXPERIENCE.md` › Copy deck › Duels, add the accessible names: "Défier <name>" ("Challenge <name>") for "DÉFIER" on an EN LIGNE row · "Défier <name> en duel" ("Challenge <name> to a duel") for "DÉFIER EN DUEL" · "Reprendre le duel contre <name>" ("Resume the duel against <name>") · a DERNIERS DUELS row "Victoire contre <name>, 6 à 4" ("Win against <name>, 6 to 4"), likewise for a loss or a draw · "Rejouer contre <name>" ("Rematch <name>").

**M32 — Change arrows' names.** `EXPERIENCE.md` › Accessibility Floor › Duels: replace "The deck editor's change arrows carry the previous percentile in their accessible name" with "The deck editor's change arrows are hidden from assistive technology; a visually hidden text reads "Popularité en hausse : 62, contre 55 lundi dernier" ("Popularity up: 62, against 55 last Monday"), and a card's name ends with its changes. The arrows sit under the card, never on its face, at 10px or more."

**M33 — The architecture is not updated for 1.4.** Not a paste: run an architecture update for release 1.4 before slicing stories; flags F1 to F9 at the end list what it must settle.

**M34 — Ties in percentiles and in automatic moves.** `duel-rules.md` › Stats, add: "- A percentile is the share of the ranked cards a card beats, equal values counting half (midrank), stored to one decimal." `duel-rules.md` › Time and absence, add: "- An automatic move between equal choices takes the larger distance of the exact value from the median, then the stat order of the Stats table, then the lower card number."

**M36 — The UTC day of a duel crossing midnight.** `duel-rules.md` › Reward and record, first bullet: after "The first win of the UTC day" insert "(the day the duel ends)". `spec-gameble.md` › Assumptions: replace "The day of the first-win duel capsule is the UTC day, as for the daily bonus (CAP-42, CAP-16)." with "The day of the first-win duel capsule is the UTC day the duel ends, as for the daily bonus (CAP-42, CAP-16)."

**M38 — The duel capsule in the supply model.** `market-economy.md` › Known limits, add: "- The duel capsule (CAP-42) adds at most one capsule a day per player, 3 cards at the daily bonus odds (about 0.03 Légendaire), as much again as the daily bonus for a player who wins a real duel each day; it was not simulated, and the Légendaire backlog indicator watches it."

### Low

**L1 — Flow 11 does not show the stats.** `EXPERIENCE.md` › Flow 11, step 1, after "cards strong on two stats.": insert "On Quake's detail she reads "ATOUT · Sortie", "Plus ancienne que 97 % des cartes"." After the climax (step 7), add: "8. The next Monday, the feed's "Le cours des cartes a bougé." names Cave Story: its circulation fell."

**L2 — Flow 11's failure line skips two refusals.** `EXPERIENCE.md` › Flow 11, Failure, append: "Léa's second deck holds 9 cards → it shows "9 / 12" in the sheet with the draft reason. Léa wins again later that evening → the result shows "Capsule de duel déjà gagnée aujourd'hui."."

**L4 — New contrast pairs not written.** `DESIGN.md` › Colors › Capsule origins, append: "`{colors.capsule-duel}` reads 9.5:1 on `{colors.panel}`, 8.1:1 on `{colors.panel-raised}`, 10.1:1 on `{colors.panel-sunken}` and 9.5:1 on `{colors.steam-bar}`; `{colors.outline}` on it 10.8:1." `DESIGN.md` › Duels › Round outcome, append: "(lime on `{colors.panel}` 9.7:1; muted 6.0:1)."

**L5 — Raw values and a kicker variant.** `DESIGN.md` › Duels: "44px rows" → "`{spacing.touch-min}` rows"; "each part 44px tall" → "each part `{spacing.touch-min}` tall"; "48px tall" → "`{spacing.button-height-phone}` tall"; "8px apart" (hand and directions) → "`{spacing.touch-gap}` apart"; "a `{typography.label}` muted kicker" → "a `{typography.kicker}` kicker (the Kicker primitive)".

**L6 — Older rows undercount the special capsules (and contradict DESIGN).** `EXPERIENCE.md` › State Patterns:
- "Reserve full": replace "the daily capsule and weekly mission rewards join the special reserve" with "the daily capsule, the weekly mission reward and the duel capsule join the special reserve".
- "Special capsule in the reserve": replace "The daily capsule (better odds) and the weekly mission's rare capsule join the same reserve and open with the same ritual; they are not told apart among the canisters." with "The daily capsule, the weekly mission's reward and the duel capsule join the special reserve and open with the same ritual; each canister wears its origin's colour, emblem and name (`DESIGN.md`, Special capsules)." (The "not told apart" clause predates the origin colours of 2026-10-28.)

**L8 — Rationale in Phone navigation.** `EXPERIENCE.md` › Phone navigation: delete "; the author sees in it room for later social features". `brief-gameble/addendum.md` › Parked idea, the bullet "The forge session rejected a battle mode, …": append "(2026-11-14: release 1.4's Top Trump duel is now the battle mode; see above)".

**L9 — Two overloaded Copy deck rows.** `EXPERIENCE.md` › Copy deck: split "Duels (2026-11-14, live friend duels)" into "Duels screen and challenges", "Duel" (from "in a duel" to "Coup joué automatiquement") and "Duel result and record"; split "Decks and duel stats" into "Decks" (to "RETIRER DES DECKS") and "Duel stats" (from "stats"). Keep each row's "(accepted with the mockups, author, 2026-11-14)".

**L10 — The capsule origins paragraph.** `DESIGN.md` › Colors: replace the Capsule origins bullet's history chain with a table under it:

| Origin | Token | Hex | Emblem | Shade | Text on fill | Nearest colour |
|---|---|---|---|---|---|---|
| Daily capsule | `{colors.capsule-daily}` | #f4c542 | sun, S1-L2 | #8f5e0a | `{colors.outline}` 12.3:1 | `{colors.gold}`, same hex, separate role |
| Weekly mission reward | `{colors.capsule-goal}` | #d6403a | cup, C1-L2 | #7a1c1f | `{colors.outline}` 4.4:1 | `{colors.live-red}`, `{colors.alert}` |
| Duel capsule | `{colors.capsule-duel}` | #9ec3e6 | blades, B1-L2 | to draw | `{colors.outline}` 10.8:1 | `{colors.accent-press}` ΔE 10.0, `{colors.accent-hi}` ΔE 11.4 |

and keep, as prose, only: "A later origin adds its own row. In duels `{colors.capsule-duel}` also marks the trump tag and a hidden call."

**L12 — Component names differ between the spines.** `DESIGN.md` › Duels: rename "Deck slots" → "Deck editor", "Duel screen" → "Duel", "Round outcome" → "Duel, reveal"; the new bullets of M9 and H3 use EXPERIENCE's names (Défier un ami, Challenge received, Deck list, Duel record, Monday stats entry, Duel result).

**L14 — Player menu date.** `EXPERIENCE.md` › Player menu: replace "the MARCHÉ sub-tab and DUELS included (author, 2026-11-09)" with "the MARCHÉ sub-tab (author, 2026-11-09) and DUELS (author, 2026-11-14) included".

**L15 — DESIGN's Duels section placement.** `DESIGN.md`: move the "Échanges sub-tabs" bullet to the trade screen's rules (beside Trade board), and file "### Duels" under "### Screens" as "#### Duels" at the next tidy.

**L16 — A cross-reference filed as a component.** `EXPERIENCE.md` › Duels: delete the "Duel capsule" row; its content is covered by L6's "Special capsule in the reserve" text and DESIGN › Special capsules.

**L17 — Slashes, dashes and units read aloud.** `EXPERIENCE.md` › Accessibility Floor › Duels, append: "Slashes, dashes and units are read as words through visually hidden text: "MANCHE 2 / 10" as "Manche 2 sur 10" ("Round 2 of 10"), "<n> / 12" as "<n> sur 12" ("<n> of 12"), "MES DECKS · 3 / 5" as "Mes decks, 3 sur 5" ("My decks, 3 of 5"), "6 – 4" as "6 à 4" ("6 to 4"), "<s> s" as "<s> secondes" ("<s> seconds")."

**L18 — Capitals in the locale files.** `EXPERIENCE.md` › Accessibility Floor › Language, append: "Duel labels are written in sentence case in `fr.yml` and `en.yml` ("La plus ancienne", "Oldest") and set in capitals by CSS, so no screen reader spells them."

**L19 — `aria-current` on the roots.** `EXPERIENCE.md` › Tab bar: replace "PONT stays current on its sub-screens Fil d'activité and Le Chattomètre, DUELS on its own, with `aria-current="true"` there and `"page"` on the hub alone" with "a tab carries `aria-current="page"` on its root and `aria-current="true"` on its sub-screens: PONT over Fil d'activité and Le Chattomètre, ÉCHANGES over the trade board and the Annonce, DUELS over the deck editor and a duel result".

**L20 — Desktop menu key 4 changes.** Release 1.4's notes (the release story): "Menu 04 now opens DUELS; the market moved under 03 ÉCHANGES." `EXPERIENCE.md` needs no change.

**L21 — The duel result read aloud.** `EXPERIENCE.md` › Accessibility Floor › Duels, append: "The Duel result reads its summary first ("Victoire contre Hugo, 6 à 4, départagée à l'écart de 12 points de centile"), then the rounds as an ordered list, each one sentence ("Manche 3, Léa annonce la plus ancienne : Quake, 1996, contre Half-Life, 1998. Gagnée.")."

**L22 — Esc during a live duel.** The general rule returns to the hub, which in a live duel is a disconnection. `EXPERIENCE.md` › Interaction Primitives › Esc, append: "On the duel screen Esc clears the latest choice of the move in progress (direction, then stat, then card) and never leaves the duel."

**L23 — Deck list thumbnails.** `EXPERIENCE.md` › Duels › Deck list, append: "The thumbnails are hidden from assistive technology; the row is one link named "<deck>, 12 cartes" ("<deck>, 12 cards") or "<deck>, brouillon, 9 sur 12" ("<deck>, draft, 9 of 12")."

**L24 — Monday entry wording.** `EXPERIENCE.md` › Duels › Monday stats entry: "with no card" → "with no card image"; "Shown in TOUS only" → "Shown under TOUS and the TOUT filter only".

**L26 — Values the UX set alone.** `EXPERIENCE.md`: tag `[ASSUMPTION]` after "moved by 5 points or more" and "(1 to 24 characters)" (Deck editor), "the last used preselected" (Défier un ami) and "their last used complete deck preselected" (Challenge received); M12's measure is already tagged. Add one entry listing the four to `pending-approvals.md` (adding an entry, not settling one). (The "win rate" column of the report is obsolete.)

**L27 — "points" in the margin line.** `EXPERIENCE.md` › Copy deck › Duels: "Départagé à l'écart : <n> points" ("Decided on margin: <n> points") → "Départagé à l'écart : <n> points de centile" ("Decided on margin: <n> percentile points").

**L29 — Older contradictions (not 1.4).** `spec-gameble.md`:
- CAP-19, last bullet: "Feed events carry no reactions or comments." → "Feed events carry reactions (as built, 2026-11-04) and no comments."
- Non-goals: "Reactions or comments on feed events (later)." → "Comments on feed events (later)."
- Non-goals: "Native App Store and Play Store apps." → delete it (the native apps are an epic, `epic-hotwire-native-apps`, and EXPERIENCE designs them); the Platforms constraint's "Native store apps must remain possible later" stays true.

**L28, fixable part — the trademark word.** `spec-gameble.md` › Constraints › Player-facing words, append: "The interface never says "Top Trumps", a trademark; the spec's "Top Trump duel" is a working name." (The success-signal part is A2.)

### New inconsistencies the rework introduced (fixable)

**N1 — Decks and card stats still listed as rejected.**
- `EXPERIENCE.md` › Design decisions: "**Rejected — the generator's filler mechanics:** combat, decks, card stats, recycling." → "combat and recycling. Decks and card stats came back with the duel of release 1.4 (author, 2026-11-14)."
- `DESIGN.md` › Do and don't, row "Leave out what is not in the spec's scope": "Show decks, combat or recycling from the generated canvas" → "Show combat or recycling from the generated canvas (decks and duel stats follow the Duels section)".

**N2 — The ten duel achievements have no French copy, and one English title addresses the player.** EXPERIENCE's table and its Open questions still say "twenty-three"; `achievements.md` now holds thirty-three, and its own rule says "The title never addresses the player", which "Ruling in Your Favour" does.
- `achievements.md` › Duel achievements: "Ruling in Your Favour" → "A Favourable Ruling".
- `EXPERIENCE.md` › Achievement titles and conditions: "Final copy of the twenty-three achievements" → "Final copy of the thirty-three achievements (24 to 33 drafted on 2026-11-14 `[ASSUMPTION: pending the author's copy review]`)", and add:

| # | Titre | Condition | Title | Condition (EN) | Back |
|---|---|---|---|---|---|
| 24 | Audience ouverte | Terminer un premier duel | Hearing Convened | Finish a first duel |  |
| 25 | Décision favorable | Gagner un premier duel | A Favourable Ruling | Win a first duel |  |
| 26 | Jurisprudence établie | Gagner 10 duels | Established Case Law | Win 10 duels |  |
| 27 | Service du contentieux | Gagner 50 duels | Litigation Department | Win 50 duels | Duelliste |
| 28 | Magistrat honoraire | Gagner 100 duels | Senior Magistrate | Win 100 duels |  |
| 29 | Vice de procédure | Gagner une manche avec une carte Commune contre une Légendaire | Procedural Upset | Win a round with a Common card against a Legendary |  |
| 30 | Verdict unanime | Gagner un duel 10 à 0 | Unanimous Verdict | Win a duel 10 to 0 |  |
| 31 | Délibéré serré | Gagner un duel à égalité de manches, à l'écart | Decided on Points | Win a duel tied on rounds, on the margin |  |
| 32 | Compétence élargie | Affronter 5 amis différents en duel | Wide Jurisdiction | Duel 5 different friends |  |
| 33 | Code intégral | Gagner une manche avec chacune des cinq caractéristiques | Full Code | Win a round with each of the five stats |  |

- `EXPERIENCE.md` › Open questions › Achievements: "the twenty-three of the copy table" → "the thirty-three of the copy table (24 to 33 pending the author's copy review)".

**N3 — "Four achievement backs" is now five.**
- `DESIGN.md` › Card backs, paragraph under the table: "The last four are the achievement backs (author, 2026-10-31): candidates 1A, 2A, 3C and 4B of …" → "The last five are the achievement backs: four chosen by the author on 2026-10-31, candidates 1A, 2A, 3C and 4B of …, and Duelliste (author, 2026-11-14, Écrans des Duels, board 10)".
- `EXPERIENCE.md` › Card backs › Earning: "Four achievements unlock a back each (author, 2026-10-31): … "Contrat"" → "Five achievements unlock a back each: … "Contrat" (author, 2026-10-31), and Litigation Department "Duelliste" (2026-11-14)". Same section, "The prototype's eight": "beyond the four achievement backs" → "beyond the five achievement backs".

**N4 — "<name> s'est déconnecté" does not agree with a feminine name** (Flow 11 writes "Léa s'est déconnecté"). Replace everywhere it appears (`EXPERIENCE.md` › Copy deck › Duels, Duels › Duel, State Patterns › Opponent disconnected, Flow 11 › Failure) with "Connexion de <name> perdue… <s> s" ("<name>'s connection lost… <s> s"); in Flow 11, "Connexion de Léa perdue… 60 s".

**N5 — A duel in the native apps.** The duel has "no tab bar and no back", but the apps' native tab bar and top bar stay over every screen. `EXPERIENCE.md` › Native apps, add after the tabs sentence: "During a duel the native bars stay; a tab or top-bar destination leaves the duel, which counts as a disconnection, and the DUELS tab's badge leads back within the 60 s `[ASSUMPTION]`."

**N6 — What "leaving" a duel means.** `EXPERIENCE.md` › Duels › Duel: replace "leaving it (another tab, closing the page) counts as a disconnection" with "leaving it (opening another screen, closing the page, losing the connection) counts as a disconnection; a page left open behind another browser tab or app stays connected for as long as the browser keeps its connection".

**N7 — "DÉFIER EN DUEL" missing from the rows the IA names.** The IA row "Défier un ami" puts it on an online friend's row, friend profile and public profile; none of those components lists it.
- `EXPERIENCE.md` › Friend row: after the "ÉCHANGE" sentence insert: "For an online friend, while neither profile is private, "DÉFIER EN DUEL" (accessible name "Défier <name> en duel", "Challenge <name> to a duel") follows "ÉCHANGE"; a friend in a duel shows "Duel en cours" instead."
- `EXPERIENCE.md` › Public profile: after "the profile action," insert "then, for an online friend, "DÉFIER EN DUEL","; `EXPERIENCE.md` › Copy deck › Public profile: add "DÉFIER EN DUEL" ("CHALLENGE TO A DUEL"; accessible name "Défier Léa en duel", "Challenge Léa to a duel").

## Fixed (23)

- C1 — Which deck a challenged friend plays: `duel-rules.md` › Starting a duel (the friend accepts with one of their complete decks within 60 s), CAP-41, EXPERIENCE › Challenge received.
- C2 — The call is solved: rules reworked (hidden call, the answerer picks after seeing the caller's card, open decks, one hand for calling and answering), `duel-rules.md` › A duel, CAP-41's intent "a real read of the other"; not simulated, see A4.
- C3 — Idle alts farm capsules: live duels only and the capsule only if the game played none of the winner's moves, CAP-42, `duel-rules.md` › Reward and record.
- H9 — The irreversible call: every choice changes until "ANNONCER", 400ms guard, fires on release (EXPERIENCE › Duels › Duel); directions stack full width, 44px, 8px apart (DESIGN › Duels › Duel screen).
- H10 — Outcome announcement: focus moves to the outcome heading holding both cards, values and score, nothing announced twice (EXPERIENCE › Accessibility Floor › Duels; Focus "Reveal"); the template's copy is in M18.
- H11 — Semantics of hand, stats and directions: three named radio groups, names holding game, trump and percentile in words (Accessibility Floor › Duels); English names in M18.
- H12 — Private players and CAP-8: a private player cannot duel (CAP-41, `duel-rules.md` › Starting a duel, State "Private profile"); AD-14's note is flag F4.
- H14 — Export and deletion: Constraints › Market and personal data, `duel-rules.md` › Reward and record (export, deletion, "anonyme"); frozen decks and values at the start; AD-14's handler is flag F5.
- H16 — Throwing and friend-duel rings: accepted explicitly (`duel-rules.md` › Reward and record, "Duelling one's own second account is accepted"), bounded by ten real rounds a day.
- M3 — "LANCER UN DUEL" in lime: now "DÉFIER UN AMI", `{colors.primary}` (DESIGN › Duels › Duels screen).
- M5 — Steel too close to other colours: blue steel #9ec3e6 (DESIGN › Capsule origins), ΔE 10.0 or more from every near token (accent-press 10.0, accent-hi 11.4, tier-silver 14.5, accent 15.1, text 16.2, cap steel 22.5).
- M7 — Empty deck slot frame: `{colors.dim}`, 3:1 or more, and an empty slot is not a target (DESIGN › Duels › Deck slots; EXPERIENCE › Deck editor, filled slots are the buttons).
- M21 — Raw values against percentiles: the reveal and the profile give values in words and raw (EXPERIENCE › Duels › Duel, Reveal; Duel profile); the exact-value tie copy is in M18.
- M23 — "AMIS" naming three things: the sub-tab is "ENTRE AMIS" (DESIGN › Duels › Échanges sub-tabs; EXPERIENCE › IA › Échanges).
- M30 — Sizes and reflow: 3 columns of 4 on the phone, scaled to fit 320 CSS px, the hand never overflowing 320, directions full width (DESIGN › Duels › Deck slots, Duel screen).
- M35 — Circulation bought by hoarding: circulation counts holders, Archives excluded (`duel-rules.md` › Stats).
- L3 — Two-key sort in Flow 11: step 1 now sorts by Sortie and picks by eye (Flow 11).
- L7 — Status of the missing mocks: the desktop Duels screen and duel are drawn and accepted (DESIGN › Duels › Desktop, boards 11 and 12), and Open questions › Duels no longer lists them.
- L11 — Stale spec open question on duel UX: removed (spec › Open Questions holds only duel rating and live duel load).
- L13 — Round numbering: "MANCHE <n> / 10" in both the duel and the result (Copy deck › Duels; Duels › Duel).
- L25 — Flow 11's impossible score: the flow was rewritten around reads, not a stat Hugo cannot lose (Flow 11).
- L33 — Draws almost never happen: no fix was asked; the record keeps draws (CAP-42).
- L34 — Stat timing gives no edge: no fix was asked; values freeze at the start (`duel-rules.md` › A duel).

## Obsolete (16)

- H1 — Duel rating in VT323 (no rating in 1.4).
- H6 — One sitting against a resumable 48 h half.
- H15 — Colluders forcing an open-challenge meeting.
- H17 — Ratings frozen at the top.
- H18 — The 10-duel cap for incoming challenges.
- H19 — A ban not undoing rating fed by the banned alt.
- M1 — No flow for CAP-43's ranked play.
- M2 — No flow for the open challenge.
- M17 — Classement des duels after a reset and for a private viewer.
- M22 — "Membre discret" in the duel ranking (to settle with CAP-43 later).
- M24 — "Rating" naming both a stat and the Elo figure in English (to settle with CAP-43 later).
- M37 — Away players rated on autopilot.
- M39 — Newcomers matched against established decks.
- L30 — Defence decks public after two duels.
- L31 — What the second half sees, and its shuffle.
- L32 — Piñata defence decks and idle strong decks.

## Architecture flags (not edited, for the 1.4 architecture pass of M33)

- **F1 — The Game domain's contents** (Design Paradigm table) list no decks, duels, duel stats or duel records.
- **F2 — AD-6 and AD-8: one `reserved` count.** A deck block needs its own count, or a derived split as listings have, so `Game::ReservedCopies` can say "Dans un deck" rather than "en échange", and so releases (going private, a removed friend) free trade reservations only (H13).
- **F3 — AD-7: "Each pack kind (regular, daily bonus, weekly reward)"** lacks the duel capsule (3 cards at the bonus odds).
- **F4 — AD-14: "`open_to_friends?` … nothing else needs it"**: duels now ask it (a private player cannot duel).
- **F5 — AD-14: the `Accounts::PlayerDeleted` handler** does not drop decks or anonymise duel history; a duel in progress must finish by automatic play first.
- **F6 — AD-13: the private stream "carries only what calls for an answer".** A challenge fits it; the rounds of a live duel need a per-duel stream for two players, which no decision names.
- **F7 — Server-side deadlines.** 30 s, 20 s, 60 s to accept and 60 s to reconnect need deadlines the server enforces (jobs or a timer process), against the constraint that queues and streaming are added only when measured load justifies them.
- **F8 — AD-24: presence is read (last seen), not tracked.** "Online" for a 60-second dialog can name a friend with no page open, whose challenge lapses unseen; the challenge needs a live channel, or "online" a stricter test.
- **F9 — No decision covers** the weekly and per-season stat computation, the frozen duel snapshot (both decks and every value at the start), or the duel record and achievements' reads (AD-37).
