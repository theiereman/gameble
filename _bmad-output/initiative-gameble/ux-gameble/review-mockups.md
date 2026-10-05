# Review — mockups vs spines

Reviewer Gate lens: mockups vs spines. Run 2026-10-05.

- **Mocks:** `mockups/key-screens.html` (desktop, identical to `.working/key-screens-v3-4.html`), `mockups/mobile.html` (phone, identical to `.working/mobile-v1-3.html`).
- **Spines:** `DESIGN.md` and `EXPERIENCE.md` (draft, 2026-10-05).
- **Decisions log:** `.memlog.md`, entries from "Update started 2026-10-05" (line 157) onward.

## Verdict

The spines and the approved mocks agree on structure, tokens, motion and almost every behaviour. All 50 colour tokens in `DESIGN.md` appear in both mocks. The mocks' CSS uses only a handful of colours that are not tokens. Every timing in the Motion table matches the code within rounding (×1.18 applied). No divergence blocks the build.

The divergences that matter are spine text that went stale after the v3-3 / v3-4 / mobile-v1-3 rounds:

- the canister is still described with notched caps and as "to be redrawn";
- the counter-proposal note and the visibility labels still say "the mock" lacks them;
- the `motto` colour token contradicts the goal panel.

Some decided states also lack their copy in the spines: the daily booster with a full reserve, and the empty showcase. The phone booster also has many details that the spines leave out.

The mocks have three real faults:

- the card detail has no description, season, sets or copyright;
- the empty-showcase state shows two lime buttons at once;
- the phone zoom draws rays behind low tiers.

**Counts:** (a) 6 · (b) 22 · (c) 5 · (d) 15.

## Token check (programmatic)

| Check | Result |
|---|---|
| Colour tokens of `DESIGN.md` present in the mocks | 50 / 50 in both mocks |
| Non-token colours in the CSS, desktop | `#3d4a57` (disabled stepper text), `#16202d` (art loading hatch), `#3a2412` (armed LED, off phase), `#ff3cac` / `#4cf0ff` (foil gradient) |
| Non-token colours in the CSS, phone | The desktop ones, plus `#17140a` (Légendaire caption plate, see b11) and the phone frame colours `#0d141d #222b37 #10151c #0c1016 #171d26` (mock convenience) |
| Non-token colours in the JS | Pixel-art palettes only (card backs, canister, planet, avatars, achievement glyphs). Acceptable as art, not UI tokens |
| `motto #b9a46a` | Present only in dead CSS (`.g-motto`, `.fd-motto`). No element uses it (see b4) |
| Typography, desktop | Every `DESIGN.md` size matches the mocks: screen-title 20, hero 34/38, banner 42/48 (Épique 28), showcase-name 26, card titles 9/12/15/17, publisher 13/16/18, menu 14, button 13/11, label 10, body 20, body-small 17 |
| Typography, phone | The phone uses a smaller ramp that `DESIGN.md` does not list (see b12) |
| Spacing, desktop | top bar 56, ticker 32, menu item 50, button 44 / 34, modal 520 / 760, stepper 24×26: all match |
| Spacing, phone | tab bar 58 + safe area matches. Other phone values differ (see b12) |
| Motion | All rows of the Motion table match the code within rounding: app start 340, screen change 170/260/40, canister breath 6 s / 2 px, sweep 2.8 s, opening ≈1.2 s, reveals ≈0.68 / 0.79 / 0.98 / 1.2 / 2.45 s, Tout révéler 177 ms, next booster 160+260, idle float 14 s / 2 px, daily 480, swap ≈0.75 s, back equip 110+220, toast 250 / 2800, dialog 160/220, feed 280, holo 3.4 s steps(34), back sheen 5.2 s, ticker 60 s. Phone differences: see b11 and b14 |

## (a) Spine right, mock convenience — no action on the spines

| # | Mock / screen | What differs | Note |
|---|---|---|---|
| a1 | Desktop, every screen | A fixed 1280×720 scaled stage with absolute positions. The collection grid moves ±5 on ArrowUp/Down (five fixed columns) | The spine is fluid and moves by one row whatever the column count (memlog 249) |
| a2 | Both, all data | 13 sample games, a 16 480-card season, set totals, friends, feed, ticker, 40 achievements, 8 backs, 3 h pack timer, a goal that ticks up at random | Illustrative. `DESIGN.md` Menu item still gives the old example "87/412" (the mock shows "87/16 480"); harmless |
| a3 | Both, booster | Demo odds `[64,24,9,2.5,.5]` and a scripted first pack that holds one card of each tier, a Légendaire included | The spec's odds and first-session rule apply (memlog 77, 88, 243) |
| a4 | Both | Simulated Steam sign-in, export, delete, English toast, clipboard. DEV menu. Phone bezel, status bar, home bar, page label | Prototype only |
| a5 | Both, CSS | Dead rules from earlier rounds: `.g-motto` and `.fd-motto` (brass Brotherhood lines), `.tgl` (old hide toggle), `@keyframes bob` (10 px bob), `.g-time` / `.g-you` (goal countdown and per-player share) | Must not be carried into the build: they encode dropped decisions (memlog 210, 214, 246, 248) |
| a6 | Both, feed / public page | A fake stream adds an entry every 5 s | Illustrative |

## (b) Mock embodies an approved decision the spine misses or states differently — fix the spine

| # | Mock / screen | Spine / section | What differs | Fix | Memlog |
|---|---|---|---|---|---|
| b1 | Both, booster canister | DESIGN, Booster canister | The spine says "Two notched metal caps". The mock caps have solid, clean edges: a crisp dark outline, a light rim, a knurled grip, a collar, and no notches or dots. The flying caps in Explosion A are the same caps | Rewrite the cap description | 260, 261 |
| b2 | Both, booster canister | DESIGN, Booster canister and `components.canister` | Stale: "The prototype drew it on a 5px unit; it is redrawn … the author reviews it". The redraw is done (100×150 art px at 2 CSS px) and approved. The anatomy the mock adds is missing: an indicator window on the top cap, rim bands, gloss, four rivets, an LED plate (3 LEDs, plus 1 on the top cap), a barcode, and an emblem window that holds the gameble logo. Token drift: the caps are a light steel gradient (≈`#dfe6ec`→`#5d6b7c`), not `{colors.muted}`, and the body is a slate-blue cylinder gradient (≈`#2f4f6c`→`#1b2838`), not flat `panel-raised` | Drop the "to be redrawn" sentence. Describe the approved art. Update the tokens or mark them as art | 259, 262 |
| b3 | Both, booster | DESIGN, Booster canister; EXPERIENCE, Motion | The canister's hazard band turns orange when armed, along with the LEDs | Add | 259 |
| b4 | Both, hub goal | DESIGN, Colors (Motto) vs Community goal panel | Colors says that `{colors.motto}` (muted brass) carries the Brotherhood line. The goal panel section says `{colors.text-bright}`. Both mocks render "Toute la Confrérie ouvre 50 000 boosters, ensemble." in `#e6eef5`, and brass appears only in dead CSS | Remove the `motto` token and its Colors bullet, or say where it is used | 214, 218, 262 |
| b5 | Both, trade board | EXPERIENCE, State Patterns "Counter-proposal in progress" | Stale: "(free negotiation; the mock only opened my side)" and `[ASSUMPTION: copy]` "Modifiez l'échange, puis renvoyez la proposition." The mocks open both sides. The status line reads "Modifiez ce que vous donnez et ce que vous demandez, puis renvoyez." "RENVOYER LA CONTRE-PROPOSITION" stays disabled until each side holds a card. Focus goes to my side's add slot | Remove the stale note and the tag. Adopt the mock copy and the enable rule | 257, 259 |
| b6 | Both, profile and settings | DESIGN, Profile and settings; EXPERIENCE, Settings row | Stale: "The mock's hide toggle is replaced…" and "replacing the mock's hide toggle; `[ASSUMPTION]` labels to write". The mocks already ship the three-way control: label "VISIBILITÉ DU PROFIL"; segments PUBLIC / AMIS UNIQUEMENT / PRIVÉ (a radio group, arrow keys, default PUBLIC). The summary header reads "Visible par tous les joueurs" / "Visible par vos amis seulement" / "Profil privé : vous seul le voyez" ("Vous seul le voyez" on the phone) | Write the labels and the summary lines in. Drop the tag on the labels | 246, 259 |
| b7 | Both, hub daily booster | DESIGN, Daily booster panel; EXPERIENCE, State "Daily booster with a full reserve" | When the reserve is full, the state word in the panel header becomes "RÉSERVE PLEINE" in orange, and the line becomes "Ouvrez un booster pour récupérer celui du jour.", besides the disabled button | Add the state word, its colour and the line. Add "full reserve" to the uses of orange in Colors | 253, 259 |
| b8 | Both, hub showcase (DEV "HUB SANS OBTENTION") | DESIGN, Showcase; EXPERIENCE, "No notable pull yet" | The mock shows a hatched frame with a dashed inner card outline and a dimmed logo. The title, in `showcase-name`, reads "OUVREZ VOTRE PREMIER BOOSTER", with the line "Votre plus belle carte s'affichera ici." and the primary button "OUVRIR UN BOOSTER". Rays are off. The spine gives neither the line nor the button label | Add the copy. For the button colour, see c4 | 254, 258 |
| b9 | Both, achievements | DESIGN, Achievements and `gauge-segmented` | The spine says the achievements total uses the 24-segment, 12 px gauge. The mock uses one segment per achievement (40), 10 px tall (gap 1 px on the phone), under "SUCCÈS OBTENUS". Tiles are grouped "OBTENUS · 12" / "À OBTENIR · 28". The tile progress bar is 4 px in `line-deep`, not accent. Tiles sit in one column on the phone | Amend the gauge rule and the tile spec | 224, 225 |
| b10 | Desktop, booster | DESIGN, Rarity icon / Result banner | A label under each dealt card reads "? ? ?" (in `line`) while face down. It turns into the outlined rarity icon and the tier name in the tier colour ("LÉGENDAIRE !") on reveal. DESIGN only mentions a "reveal label" in passing | Describe it as a component | 206, 221 |
| b11 | Phone, booster | DESIGN, Reveal caption plate / Tray; EXPERIENCE, Responsive and Motion | Phone-specific behaviour the spines omit: (1) the cards land as a stacked pile, bottom card first, 5 px offsets, ±1.4° tilt, stagger ×1.5, not in a row; (2) hints "Touchez la carte pour la révéler" / "Glissez la carte pour la ranger · ou touchez-la"; (3) a tray slot holds a 40×54 pixel thumbnail with the rarity icon, pops in 260 ms, and an Épique or better gets a spark burst; (4) the plate's hazard ticks show only on Épique and Légendaire, and the Légendaire plate sits on a dark gold `#17140a`; the plate pops in 320 / 380 ms; (5) a zoom overlay on a tray slot: `card-xl`, "VOIR LA FICHE" (primary), "FERMER", tip "Maintenez la carte pour l'incliner"; (6) "Tout révéler" also stores each card in the tray; (7) the daily-booster flyer goes to the BOOSTER tab in 520 ms; (8) the tab bar is disabled (40 %) during an opening | Add to DESIGN (plate, tray, zoom) and to EXPERIENCE (Responsive, Motion, Tab bar) | 229, 239, 240, 241 |
| b12 | Phone, all | DESIGN, frontmatter `spacing` / `typography`; Layout | The phone uses its own sizes. Buttons are 48 px (small 44). Stepper buttons are 44×36 with a 44 px hit area, and "sur N" sits below instead of "/max" in the pill. The ticker is 30 px. PLUS rows are 52 px. Set chips are 132×48, with a 4 px bar and a 4 px accent base when selected. The type ramp is smaller: screen title 19, showcase name 23, public title 30, kicker 11, achievements count 40, public description 21 | Add the phone values as tokens or as a phone note | 229, 241 |
| b13 | Both | DESIGN, Layout (card sizes); EXPERIENCE, Responsive "Pickers and back grid on the phone" | On the desktop trade board, a side with a single card uses `card-m`, otherwise `card-s`. On the phone, pickers and trade sides use `card-s` and drop to `card-xs` only under 372 px. The phone back grid is always `card-xs`. The phone back preview is `card-m` (DESIGN says `card-l`) | Align the size list and the phone rule | 228, 229 |
| b14 | Phone | DESIGN, Dialogs; EXPERIENCE, Motion and Tab bar | Every bottom sheet has a 44×4 grab handle. The card picker opens as a full-height sheet. A sheet rises from 60 px in 240 ms (the spine says 220). Sub-views slide in over 260 ms and out over 200 ms. Tapping the current tab returns to its root, or scrolls back to the top | Add | 229 |
| b15 | Phone, card detail | DESIGN, Collection (card detail) | 44×64 ◀ ▶ buttons sit beside the card. A position line reads "S1 · #4 215 · 3 / 13 · glissez pour parcourir". Actions are pinned at the bottom | Add | 229 |
| b16 | Both, top bars | DESIGN, Top bar | The spine lists only the rarity counter, packs chip and player chip. The mocks add: on the booster screen, a static "n EN RÉSERVE" chip; on the collection, "Cartes uniques : 87 / 16 480" with a 180 px bar (48 px on the phone); on Échanges, the note "Entre amis · une proposition expire après 7 jours"; on the feed, the LIVE chip. Phone titles are shortened ("BOOSTER", "PROFIL") | List the per-screen top-bar contents | 245, 259 |
| b17 | Desktop, booster | DESIGN, Panels | The booster information panel has no spec. The mock shows: kicker "BOOSTER · SAISON 1", title "GRAND CATALOGUE" (hero), a bracketed info panel (CARTES PAR BOOSTER 5 · EN RÉSERVE n BOOSTERS · ÉTAT with the LED), reserve pips with "+1 dans", and the counter "Cartes révélées : n / 5". The phone puts the same facts in a 44 px strip ("SAISON 1 · GRAND CATALOGUE", mini pips, a status chip) and adds "5 cartes" under the canister | Add a component entry | 221, 243 |
| b18 | Both, hub | DESIGN, Showcase / Shapes | The "pixel pedestal" is a ringed pixel planet: 200×200 art px drawn on the 2 px grid, bands in slate and blue, and a lit ring | Describe it | 259 |
| b19 | Both, trades / friends / public page | EXPERIENCE, State Patterns and Voice | Approved copy the spines lack. Toasts: "PROPOSITION ENVOYÉE"; "ÉCHANGE REFUSÉ · Votre réponse a été envoyée à Léa."; "PROPOSITION ANNULÉE"; "ÉCHANGE CONCLU · … rejoint votre collection."; "NOUVEL AMI · Sam fait maintenant partie de vos amis."; "4 CARTES AU PLUS · Retirez une carte avant d'en placer une autre."; "UN ÉCHANGE À LA FOIS · Un échange est déjà ouvert avec Léa.". Side labels: "LÉA DONNE / VOUS DONNEZ", "LÉA A REÇU / VOUS AVEZ REÇU", "LÉA PROPOSAIT". Picker titles: "PLACER MES CARTES" / "CHOISIR DANS LA COLLECTION DE LÉA" ("CARTES DE LÉA" on the phone), with the counter "n cartes · n exemplaires (4 cartes au plus)". Board lines: "Choisissez les cartes de chaque côté." and "Échange en cours…". Invite labels: "PAR LIEN", "VOTRE CODE AMI", "AJOUTER AVEC UN CODE". Public pitch: "Vos jeux Steam, en cartes à collectionner." / "Ouvrez des boosters, complétez des sets, échangez avec vos amis.". PLUS subtitle: "Le reste du vaisseau" | Record the strings the build needs | 224–228, 259 |
| b20 | Both, collection | DESIGN, Collection | The card selected in the grid gets a pulsing 3 px accent frame and `aria-pressed`. The phone RAPPORT fold shows "n cartes · n doublons" and adds a "CARTES UNIQUES" row | Add | 221, 232 |
| b21 | Both | EXPERIENCE, Motion | Small motion details the table lacks: the Peu commune reveal also fires one ring. The public card page also idles (2 px float) over a breathing ground shadow. The detail card re-enters in 260 ms with a slight turn | Add to the table | 211, 221 |
| b22 | Both, card backs | DESIGN, Card backs | The anatomy puts "a small word … at the bottom". In the mock, Saison 1 has "SAISON" at the top and "GAMEBLE" at the bottom, and Soldes d'hiver has "HIVER" at the top | Say "at the top or bottom" | 224 |

## (c) Mock contradicts a decision — fix the mock later

| # | Mock / screen | What is wrong | Decision | Mock fix |
|---|---|---|---|---|
| c1 | Both, card detail (desktop panel, phone sub-view) | Facts are limited to title, genre, rarity, year, publisher and copies. The short description, minted season, sets and copyright are missing; the description exists only on the public card page | Memlog 63 (the description lives in the detail view); spec CAP-7; recorded as a gap in memlog 242; EXPERIENCE, Card detail | Add the four facts to both details |
| c2 | Both, booster (demo code) | `makePack()` still forces a Rare into every booster after the first (`if(Math.max(...ts)<2) ts[…]=2`). It is invisible, but anyone who ports the code inherits a per-booster guarantee | Memlog 243 (no per-booster guarantee) | Remove the line |
| c3 | Phone, booster tray | The progress beside the tray reads "1/5" (with the accessible name "Carte 1 sur 5"). The decision and EXPERIENCE, Responsive, say "CARTE n / 5" | Memlog 239 | Add "CARTE", or have the author accept "n/5" and amend the spine |
| c4 | Both, hub, empty-showcase state | Two lime primaries show at once: the showcase's "OUVRIR UN BOOSTER" and the daily booster's "RÉCUPÉRER" | DESIGN rule "Never more than one lime button per view" (no memlog entry) | Make the showcase button secondary, or write the exception into the spine |
| c5 | Phone, tray zoom | The enlarged card gets blue rays (`rays blue`) when it is Commune, Peu commune or Rare | Memlog 177 (higher tiers get glow and rays); DESIGN, Rarity effects (no rays below Épique) | No rays below Épique |

## (d) Implicit decisions — confirm, or tag `[ASSUMPTION]` in the spine

| # | Mock / screen | What the mock decided | Spine today | Ask |
|---|---|---|---|---|
| d1 | Both, reserve full (DEV) | "+1 dans …" keeps counting at 10/10, and no booster is added when it reaches zero | EXPERIENCE `[ASSUMPTION]`: the countdown is hidden | Visible or hidden? |
| d2 | Both, card face | Short number "#4 215" on `card-s` **and** `card-m` (booster deal, phone collection, single trade card). "S1 · #4 215" only on `card-l` / `card-xl` | DESIGN: the full form from medium up | Pick a threshold |
| d3 | Both, collection grid | A missing-card slot ends with "NON OBTENUE" instead of the card number | DESIGN and EXPERIENCE: the slot shows its number | Number, "NON OBTENUE", or both? |
| d4 | Both, collection grid | The copy badge shows on every owned card, "x1" included | "x3 shows copies owned" | Badge from x1 or only for duplicates? |
| d5 | Both, Amis | Codes accept 3–5 characters, a dash, then 4 (e.g. "KAI-8F2D") | "Format attendu : ABCD-1234." | Fix the code format |
| d6 | Both, settings | "SE DÉCONNECTER" lands on the public card page of the last pull | Silent | Where does sign-out land? |
| d7 | Both, focus | Buttons, tabs and menu rows show focus with their hover fill plus a 6 px pale-accent halo (or a dark ring). Cards in grids, pickers and the back grid get a 3 px gold outline. The canister and dealt cards get a 3 px accent outline with an offset | EXPERIENCE: "A visible 3px accent outline (gold on cards in grids)" | Confirm and document per element |
| d8 | Both, hub | The pedestal planet drifts 6 px over 8 s | "Nothing bobs more [than 2px]" (memlog 210 is about cards) | Confirm 6 px for scenery, or cap it at 2 px |
| d9 | Both, showcase / public page | No gold glow on a Légendaire in the showcase or on the public page; the glow shows only in the booster and the detail | DESIGN, Rarity effects: glow in the detail, showcase and public page | Add the glow to the mock, or narrow the spine |
| d10 | Both, ticker / feed | The ticker sample includes a Rare pull. The player's own Épique or better goes to the ticker, Rare or better to the feed, and Commune / Peu commune fill in, dimmed | EXPERIENCE: ticker "Épique or better" `[ASSUMPTION]` | Confirm the thresholds for the ticker and the feed |
| d11 | Phone, `card-xs` | Genre and rarity lines in 6 px Silkscreen | DESIGN: 7 to 10 px on cards; legibility not checked | Confirm or raise to 7 px |
| d12 | Desktop, booster | A second back button "RETOUR AU PONT" in the actions panel, besides "◀ PONT" | Silent | Keep or drop |
| d13 | Phone, Amis / profile / public page | Shorter phone labels: "ÉCHANGER" (row), "SIGNALER CE PROFIL", "SUPPRIMER" (settings), "CONNEXION STEAM", top bar "PROFIL". Amis order: list, then invitations, then the invite panel | The desktop strings only | May phone copy differ? |
| d14 | Both, settings | Export is asynchronous: "PRÉPARATION…", then the toast "EXPORT PRÊT" | "export my data" | Confirm the async export with a ready notice (spec CAP-14?) |
| d15 | Both, friend profile | The showcase uses a fixed sample in the friend dialog. The player's own summary takes the three rarest automatically | EXPERIENCE `[ASSUMPTION: the three rarest, chosen automatically]` | Confirm automatic, or let the player choose |
