# Market UX contract: completeness and consistency review, 2026-11-09

Scope: the market parts of `EXPERIENCE.md` and `DESIGN.md`, checked against `spec-gameble/spec-gameble.md` (CAP-29 to CAP-37, constraints), `spec-gameble/market-economy.md`, `architecture-gameble/architecture-gameble.md` (AD-40 to AD-50), `.memlog.md` (2026-11-09) and the two market mocks. Line numbers are those of the files as read on 2026-11-09. Abbreviations: EXP = `EXPERIENCE.md`, DES = `DESIGN.md`, ECO = `market-economy.md`, SPEC = `spec-gameble.md`, ARCH = `architecture-gameble.md`.

## Overall verdict

The happy path is well carried: the auction arithmetic is right, every author decision is present, tokens resolve and the navigation was updated cleanly. The contract is not ready to build from, because the unhappy paths around money are unspecified or wrong: which edition a card-detail shortcut entrusts or lists, what happens to an open form when a setting changes, what players see when a participant is removed, and most refusal messages. Two of the three new flows (8 and 9) describe things the rules make impossible, and the soft-close copy tells players the wrong rule.

## Verdict per check

| Check | Verdict | In one line |
|---|---|---|
| 1. Coverage | thin | Every CAP has a surface, but removal of a participant, cancelled or withdrawn listings, the staleness of settings and the buy-now button have no complete behaviour or copy. |
| 2. States | thin | Suspended, visitor, not open and own listing are specified; the empty states, nearly every refusal, the ended Annonce and the seconds around the close are not. |
| 3. Numbers | thin | Every auction computation is correct (table below); Flows 8 and 9 cannot happen under the rules, and the soft-close sentence is wrong. |
| 4. Tokens and names | adequate | All tokens resolve; several components are named differently in the two spines or have only one of the two rules. |
| 5. Contradictions | adequate | Tab bar, menu numbering and "Un joueur anonyme" are clean; AD-50 against the suspended state, the delete dialog, the Reserved tag and a leftover Don't are not. |
| 6. Decisions | adequate | 1A to 8B, the average price and the names are all carried; 6A's badge and 8B's filter drifted, and four `[ASSUMPTION]` tags block a builder. |

## Check 1: where each rule lands

| Source | Lands at | Status |
|---|---|---|
| CAP-29 Entrusting | EXP 56, 175, 346, 347, Flow 8; DES 1235 | Partial: edition, selection order and recap over the cap missing |
| CAP-30 Listing | EXP 57, 176, 348, 350; DES 1236 | Partial: buy-now rule inverted, short stamp has no copy, cancel has no outcome |
| CAP-31 Bidding | EXP 173, 174, 341 to 343; DES 1232, 1233 | Partial: raise minimum, equal maximums, buy-now path, refusals |
| CAP-32 Close | EXP 174, 177, 178, 594 | Partial: ended Annonce copy, the window between end and settlement |
| CAP-33 Market, history | EXP 54, 55, 338 to 345, 592; DES 1230, 1231, 1234 | Mostly covered: extension and voided lines have no copy, `n offres` undefined |
| CAP-34 Average price | EXP 179, 295, 310, 340, 348; DES 1248 | Partial: which edition in a grid; no visual rule |
| CAP-35 Settings | EXP 351, Flow 9; DES 1210 | Partial: announcement language, scope of "new listings", concurrent change |
| CAP-36 Indicators | EXP 351, Flow 9 | Partial: no-data state, how a proposal is chosen, "Ignorer" |
| CAP-37 Signals | EXP 351 | Covered |
| Money integrity, no real money | EXP 97; no player surface needed | Covered |
| Market and personal data (SPEC 305), AD-46 | EXP 447 omits it | Missing in the delete dialog |
| Friend trades stay free (SPEC 303) | No fee in Échanges | Covered |
| ECO Words | EXP 97, 175, 176 | Covered, except the 100-6-Tron, which appears nowhere |
| ECO Values by rarity | EXP 176, 346, 348; mocks | Covered; the exact/compact rule is incomplete |
| ECO Durations, increment, displayed price, computation | EXP 176, 340, 341 | Covered |
| ECO Minimum bid | EXP 341 | Partial: leader, capped at buy-now |
| ECO Equal maximums | EXP 174 | Copy false in this case |
| ECO Raising one's own maximum | EXP 341, 343 | Partial |
| ECO Unusual maximum | EXP 173, 342 | Covered, except interaction with buy-now |
| ECO Soft close | EXP 173, 174, 877 | Copy wrong |
| ECO Buy-now | EXP 173, 341, 342, 348 | Partial, one rule inverted |
| ECO Escrow | EXP 173, 337 | Covered |
| ECO Average price | EXP 179, 295, 310 | Covered except typical price per rarity (undecided) |
| ECO Indicators | EXP 351 | Covered |
| ECO Setting bounds | EXP 351 | Covered, but Flow 9 breaks the floor |
| ECO Sales in the feed | EXP 389, DES 1072 | Partial: no sentence in the Copy deck, AMIS scope |
| ECO Alt-account signals | EXP 351 | Covered |
| ECO Known limits, Rejected | No surface needed | Respected (visible names, no gate, no welcome bonus) |

Named events: ban or deletion during an auction **missing**; a holding lost through removal **missing**; the daily cap reset **covered** (EXP 175); a settings change during a live auction **covered for the auction, missing for open forms**; closing while typing **partial** (EXP 594); bids at the minimum **partial** (equal maximums); the seller bidding on their own listing **covered** (EXP 595); insufficient balance for the stamp **rule only, no copy or path** (EXP 348).

## Check 2: states per surface

"Yes" is specified, "no" is absent, "part" is specified without copy or incompletely. Loading, offline and network error inherit the app's general rules and remain unmocked (EXP 946); they are not listed as gaps here.

| Surface | Empty | Concurrent change | Not open | Suspended | Visitor | Nothing to act on | Stale page |
|---|---|---|---|---|---|---|---|
| Marché | part: filter case only | n/a | yes | yes | yes | n/a | yes: refresh on arrival |
| Annonce | yes: history ends at creation | part: no copy | yes | yes | yes | yes: own listing | part: ended state has no copy |
| Confier | no | part: no copy | yes | yes | n/a | no: no copies, cap full | no: settings change |
| Mettre en vente | no | part: no copy | yes | yes | n/a | no: no copies, short stamp | no: settings change |
| Mes enchères | no | n/a | yes | part: RELEVER unstated | part: chip | no | n/a |
| Mes ventes | no | part: ANNULER race | yes | part: ANNULER, REMETTRE unstated | part: chip | no | n/a |
| Balance | part: zero not stated | yes: private stream | yes | n/a | yes | n/a | yes |
| Bell lines | n/a | part | yes | n/a | yes | n/a | part: seen state |
| Card detail | yes: no-sale states | n/a | yes | yes | yes | yes: fully reserved | n/a |
| Back-office | no: indicators before data | no: settings race | yes: closed state | part: reopening | yes: not staff | n/a | no |

## Check 3: numbers recomputed

| Example | Computation | Result |
|---|---|---|
| Rarity minimums (ECO 29) | (entrustment + stamp) / 0.9, up to the hundred: 1,300 · 3,400 · 7,800 · 22,300; Legendary floor 122,300, set at 7M | Correct |
| Feed thresholds (ECO 75) | 10 × minimum: 13,000 · 34,000 · 78,000 | Correct |
| Flow 7, Bruno (EXP 875) | 25,000 + 1,300 (5% = 1,250) = 26,300, under Léa's 30,000 | Correct |
| Flow 7, Hugo (EXP 876) | 30,000 + 1,500 = 31,500 | Correct |
| "Au moins 33 100" (EXP 173) | 31,500 + 1,600 (5% = 1,575) | Correct |
| Flow 7, Léa (EXP 877, 878) | 40,000 + 2,000 = 42,000; surplus 3,000; 42,000 less 4,200 = 37,800; 45,000 is under 94,500 (3 × 31,500) | Correct |
| Flow 7, end moved | "three minutes on", with two minutes left | Wrong or ambiguous: the end moves one minute, to three minutes after the bid |
| ECO worked example, won panel in the mock | 31,500, surplus 8,500, seller 28,350 | Correct |
| Mock beaten panel | 35,000 + 1,800 = 36,800; 36,800 + 1,900 = 38,700 | Correct |
| Mock sale form, Mes ventes | 20,000 less 2,000 = 18,000; 48,000 less 4,800 = 43,200 | Correct |
| Mock Confier recap | 1,000 + 4,000 + 5,000 = 10,000 for 4 copies | Correct |
| Flow 8 (EXP 884 to 886) | 1,000 + 4,000 + 100,000 = 105,000, cap 1,200,000 | Impossible as told (finding below) |
| Mock Confier result | "340k / 1,2M" on the gauge, yet a 100,000 card "exceeds the cap" | Impossible as drawn |
| Flow 9 (EXP 890 to 892) | Rare stamp 3,000: floor (5,000 + 3,000) / 0.9, up = 8,900, above the 7,800 minimum | Save is refused (finding below) |
| Mock unusual maximum (option 4B) | 700,000 on a listing with a 60,000 buy-now | Wrong outcome (finding below) |

## Findings

### Critical

- **[critical]** A card-detail shortcut does not say which edition it acts on. "CONFIER" shows "the amount of the copy" and each action "opens its screen on that card", and Confier's grid is not stated to be per edition, while a card's editions can have different rarities and so different values. A builder must guess whether a player with a Common S1 and a Legendary S2 entrusts or lists one or the other, on an irreversible action with no per-card warning (EXP:295, EXP:346, EXP:348; rule ECO:32, SPEC:241). The Confier mock adds confusion by showing one game at two rarities in the same season. *Fix:* state that Confier is one cell per edition, as Mettre en vente is. In the card detail, name the edition the actions apply to: one pair of actions per owned edition in ÉDITIONS, or open the picker filtered to that card with no edition preselected when several are owned.
- **[critical]** A form open across a settings change has no rule. The Confier values, stamp, minimum and commission are shown on a form, and the operation reads the current version when it runs, so a player can be charged a stamp other than the one on the button "METTRE EN VENTE · <amount>", or be paid another value than the recap says (EXP:176, EXP:346, EXP:348, EXP:593; ARCH:525; SPEC:249 "shown before listing"). "Busy market" covers lock contention only and keeps what was typed. *Fix:* add a state: the form submits the settings version it showed; a mismatch refuses inline, redraws the new amounts and charges nothing, with its own copy line. Add the version check to AD-42 or AD-44.

### High

- **[high]** The buy-now validity rule is written backwards: "a buy-now not above the start and at or above the minimum, is refused". Read literally it refuses a valid-looking range and accepts a buy-now under the minimum (EXP:348; ECO:51, SPEC:250). *Fix:* "A starting price under the minimum, a buy-now not above the start, or a buy-now under the minimum is refused inline", each with its copy.
- **[high]** Flow 9 cannot complete. Raising the Rare stamp to 3,000 moves the no-loss floor to 8,900, above the current minimum of 7,800, and the whole candidate is validated, so "Préparer ce changement" with only 3,000 is refused on save. Rare is the only rarity whose stamp can be raised to 3,000 within the double-or-halve bound, and every rarity but Legendary sits exactly on its floor, so this hits any stamp raise (EXP:891, EXP:892, EXP:351; ECO:29, ECO:35, ECO:71; ARCH:523). The mock draws this refusal (minimum 8,000 against a floor of 8,900) while the flow says Thomas saves. *Fix:* the proposal prefills the stamp and the raised minimum together (Rare: 3,000 and 8,900), Flow 9 says so, and the alert's explanation names both.
- **[high]** The suspended state contradicts the architecture. EXP and the accepted mock keep listings readable behind a banner when an administrator closes the market, while AD-50 shows the teaser whenever the current version is closed, with a single `open` flag that cannot tell "never opened" from "closed" (EXP:590, EXP:591; ARCH:622, ARCH:623; memlog 851). The author accepted the suspended screen, so the architecture is the stale side. *Fix:* amend AD-50: the teaser only until a first opening is recorded, the suspended banner after it.
- **[high]** Removal of a participant has no visible consequence anywhere. Banned or deleted leader: maximum released, a `voided` line, the auction back at its starting price with no leader, end unchanged. Banned or deleted seller: listing `withdrawn`, leader's maximum released. EXP has no state row, history copy, chip, bell line or Annonce outcome, and does not say what earlier bidders' rows or the seller then see (SPEC:374; ARCH:586, ARCH:587; EXP:177, EXP:178, EXP:344, EXP:591 to 595). *Fix:* add a "Participant removed" state row, a voided history line, a "RETIRÉE" chip, bell lines for the released leader and the seller, and the Annonce's outcome text.
- **[high]** Cancelled and withdrawn listings have no end state. MES VENTES lists EN COURS, VENDUE and SANS OFFRE only, though ARCH has `cancelled` and `withdrawn`. "ANNULER" has no confirmation or result copy, and nothing says the stamp is lost at that moment or how a bid racing the cancel is answered (EXP:177, EXP:350, EXP:595; ARCH:542, ARCH:543; SPEC:249, SPEC:253). *Fix:* give a cancelled listing a chip and copy ("ANNULÉE, timbre conservé"), specify a confirmation naming the kept stamp, and state the race's refusal.
- **[high]** Nearly every refusal lacks copy. There is no text for a bid under a moved minimum, insufficient balance for a new bid or a raise, an auction already ended, a removed seller, a closed market, a busy market, a rate limit, a stamp the player cannot pay, a card no longer free, or a batch where nothing fits. Flow 7's failure reuses the beaten-at-once panel for a case where it is untrue (EXP:341, EXP:348, EXP:593, EXP:880, EXP:103 "Vague errors"; ARCH:487, ARCH:546, ARCH:565, ARCH:622). *Fix:* add a "Market refusals" Copy deck row with one line per failure code, in both languages, each saying whether the field keeps its value. For a short stamp, link to Confier.
- **[high]** The raise has no defined minimum or copy. The field's minimum is "written beside it", and "Au moins" is the current price plus increment, but a leader only has to exceed their own maximum, which can be lower than that figure. Their sentence ("the difference held") has no copy, the button label is unstated, and "RELEVER MON MAXIMUM" and "RELEVER" have no stated effect (EXP:173, EXP:174, EXP:341, EXP:349; ECO:46, ECO:48; ARCH:553). *Fix:* state the leader's minimum, the sentence, the button label and that RELEVER focuses the field.
- **[high]** The soft-close sentence is false. "Une offre dans les 3 dernières minutes prolonge l'enchère de 3 minutes" and Flow 7's "moves three minutes on" add three minutes, whereas the rule moves the end to three minutes after the bid, and only when the bid changes the price or the leader (EXP:173, EXP:877; ECO:50). The sentence and "10 %", "12 H", "24 H", "3 JOURS" are also written as constants, though each is a setting frozen per listing (EXP:173, EXP:176; ARCH:525). *Fix:* "Une offre dans les 3 dernières minutes reporte la fin à 3 minutes après cette offre", with interpolated values read from the listing's version or the current one.
- **[high]** "ACHETER MAINTENANT" has no behaviour. It is in the Copy deck and both mocks as a button on the buy-now line, while the rows describe only the field route and its different label "ACHETER · <amount>"; the suspended row says "ACHETER" (EXP:173, EXP:341, EXP:342, EXP:591; DES:1232). *Fix:* add a rule: the button opens the confirm dialog at the buy-now price, it is the same action as a maximum reaching that price, and name its label once.
- **[high]** Buy-now confirmation is underspecified and the chosen mock is wrong. The dialog body speaks only of a multiple and a hold, the sentence "stated before validation" has no copy, and precedence over the unusual dialog is unstated. Option 4B draws 700,000 typed on a listing with a 60,000 buy-now, holding 700,000, where the rule buys at once at 60,000 and holds only that (EXP:173, EXP:341, EXP:342 `[ASSUMPTION]`; ECO:51; ARCH:550; `market-options.html`, choice 4, B). *Fix:* write the buy-now dialog and sentence, state that buy-now takes precedence, that the amount held is the buy-now less any held maximum, and mark or correct the mock.
- **[high]** The ended Annonce has copy for the winner only. A losing bidder, a viewer, the seller, and a sale at buy-now, an unsold end, a cancelled and a withdrawn listing all need outcome text, and the won panel always announces a surplus that may be zero (EXP:174, EXP:594). *Fix:* add one line per outcome and a variant of the won sentence with no surplus.
- **[high]** The seconds around the close are unspecified. FIN DANS is not said to count down visually, or to show seconds, in the final minutes, and its formats ("18 min", "2 h 14") are only in the mock. The closing job runs every 10 seconds, so a listing can sit past its end, still open, with no state. EXP:340 promises typing is never touched while EXP:594 replaces the form (EXP:339, EXP:340, EXP:594, EXP:690; ARCH:565, ARCH:629). *Fix:* define the countdown (what ticks, from what threshold, against server time), a "clôture en cours" state, and make EXP:594 the stated exception, telling the player their typed amount was not placed.
- **[high]** Selection order and what the recap shows over the cap are undefined, though the outcome depends on them. SPEC says selection order, EXP never says what that is (tick order, grid order, unticking), whether a multi-copy line partly fits, whether "VOUS RECEVEZ" shows the full or capped sum, whether the gauge previews the selection, or what a full cap looks like (EXP:346, EXP:347; SPEC:377; ARCH:533). *Fix:* order is tick order, shown in the recap; state partial quantity handling; the recap warns when the sum exceeds what remains; a full cap disables validation with its copy.
- **[high]** DOUBLONS is undefined and conflicts with the shortcut. Nothing says whether doubles are counted per card or per edition, or whether it filters cells or caps the stepper, and "on by default" would hide the only copy that a card detail opens already ticked. The mock shows "1 sur 1" cells under an active chip (EXP:346 `[ASSUMPTION]`, EXP:56, EXP:884). *Fix:* define the chip, and turn it off when the screen opens from a card detail.
- **[high]** Seen state of market notices is undefined. The badge counts ended auctions "not yet seen", without saying what counts as seeing, while the bell clears non-trade lines per browser under a pending assumption, although notices are server rows (EXP:253, EXP:255; ARCH:558). Two devices would show different badges. *Fix:* record seen on the notice server-side, and state that opening the listing or the line marks it.
- **[high]** The delete dialog "names everything deletion erases" but omits the PiCoin balance, which is destroyed, and the market's listings and leading bids (EXP:447; SPEC:305; ARCH:586, ARCH:588). The privacy notice must name them too (ARCH:590, EXP:68). *Fix:* add them to the note, in the dialog's own wording, and to the privacy notice copy.

### Medium

- **[medium]** Flow 8 cannot happen under the numbers. The batch is worth 105,000 and the cap is 1,200,000, so the Légendaire is refused only if she already entrusted more than 1,095,000 that day, implausible a week in. The mock's result is equally impossible at 340k on the gauge (EXP:884 to 886; ECO:27, ECO:34; `market-options.html`, choice 2; `market-screens.html`, Après avoir confié). *Fix:* say she has already entrusted a large amount that day, or use a gauge near the cap, and make the mock agree.
- **[medium]** "UN AUTRE JOUEUR AVAIT UN MAXIMUM PLUS HAUT" is false for equal maximums, where the earlier one leads at that maximum (EXP:174, EXP:875; ECO:47). *Fix:* a variant such as "Un autre joueur avait déjà proposé ce maximum".
- **[medium]** The accepted feed mock shows a Rare sold at 31,500 with a VENTE tag, below the 78,000 threshold, so a builder could read it as "every sale" (`market-screens.html`, Les ventes dans le fil; ECO:75). *Fix:* correct the example or annotate it.
- **[medium]** The sale feed entry is incomplete. Its sentence is missing from the Copy deck, its link conflicts (Annonce at EXP:55, the card page at EXP:389), AMIS lists only pulls, trades and reposts so the VENTES chip is always empty there, and the LIVE ticker is not addressed (EXP:148, EXP:388, EXP:389). *Fix:* add the sentence, name the link target, and state the AMIS and ticker rules.
- **[medium]** A banned buyer's sale entry is hidden by AD-49 but "anonyme" under the Names row, and EXP:389 mentions only deletion (EXP:345, EXP:389; ARCH:614). *Fix:* align on hidden and say so.
- **[medium]** A raise's visibility has loose ends. `n offres` is undefined; if it counts raises it reveals them, which CAP-33 forbids. "The leader's line" is unclear after a beaten bid, when the newest line is not the leader's, or when the leader has several lines. The owner's own raise line and the extension line have no copy (EXP:339, EXP:343, EXP:344; SPEC:274). *Fix:* define `n offres` as public validated bids, the gold line as the leader's latest, and add the two lines' copy.
- **[medium]** Empty states are missing for ANNONCES with no filter, MES ENCHÈRES, MES VENTES, Confier with nothing to entrust and Mettre en vente with no free copy. The one line present speaks of filters, and "TERMINÉES RÉCEMMENT" has no window (EXP:338, EXP:349, EXP:350). *Fix:* add the lines and the window.
- **[medium]** Suspension leaves actions unstated. RELEVER and REMETTRE EN VENTE are not listed as disabled, and whether ANNULER stays is open, AD-50 not refusing cancellation (EXP:591; ARCH:622). Closing does not say whether it needs the announcement that every settings save requires, or how reopening works (EXP:351; ARCH:523, ARCH:524, ARCH:623). *Fix:* list every action, and specify closing and reopening.
- **[medium]** Settings copy overstates "applies to new listings". Entrustment values, the cap, the feed threshold, the average-price window and the unusual threshold apply at once, the stamp and minimum at listing (EXP:351, EXP:892; `market-screens.html`; ARCH:525). *Fix:* say per value when it applies.
- **[medium]** The Brotherhood's announcement is "typed by staff in both languages", while EXP and the mock show one field. The second administrator's save refusal (`settings_changed`) has no state (EXP:351; ARCH:522, ARCH:524). *Fix:* two fields and a refusal line.
- **[medium]** The back-office omits AD surfaces and states: the age of the oldest due listing, the reconciliation result, durations and the unusual threshold in the settings, an indicator with no data yet (34% of nothing at opening), how a proposal's value is chosen and how long "Ignorer" lasts (EXP:351; ARCH:515, ARCH:605, ARCH:637; SPEC:285). *Fix:* add each to the Back-office row.
- **[medium]** Average price in grids does not say which edition a grid cell's price is, nor sort direction, and whether no-sale cards come last in both directions. The Filter zone row, which lists every group, does not include price, and the two grids have no sort control specified to attach it to (EXP:307, EXP:310). *Fix:* name the edition (published season, or best owned), list the sorts, add the group.
- **[medium]** Market sort options are unspecified beyond the default, while ARCH leaves them to the UX (EXP:172, EXP:338; ARCH:855). *Fix:* list them with their copy.
- **[medium]** Amount formatting is incomplete and conflicts with AD-40's single compact helper. Compact versus exact is given in principle only (bell and feed differ across mocks), compact thresholds and rounding are absent, and rounding can show "2k" to a player who holds 1,950 and cannot pay a 2,000 stamp. Input parsing is unstated: spaces, "31,5k", non-integers (EXP:97, EXP:341; ECO:21; ARCH:489). *Fix:* a table per surface, truncation for compact amounts, and a helper with both forms.
- **[medium]** DES:908 drops the committed amount on a tight phone header, while EXP:337, SPEC:245 and memlog 843 require both figures. *Fix:* keep both, or state the fallback in EXP and move committed under the chips.
- **[medium]** The native top bar is an exhaustive table that "looks the same everywhere but for its left side" and has no balance, while the phone rule puts one on market screens (EXP:337, EXP:754, EXP:756 to 762). *Fix:* add a row.
- **[medium]** The Reserved tag and card picker speak only of proposals, though a listing also reserves a copy (EXP:368, EXP:371; ARCH:542). *Fix:* extend the rule and give a listed copy its own tag text.
- **[medium]** Card detail has no visual rule for the "Prix moyen" fact or the two new buttons, including the phone's pinned action rows, and the grid price has no visual rule at all (DES:1038, DES:1248; EXP:295, EXP:310). *Fix:* add them to DES.
- **[medium]** Components differ by name or lack a rule. Named differently: PiCoin balance / Balance chip, Market screen / Market chips and actions, My maximum / My maximum form, History / History row, Mettre en vente / Sale form, Confier / pickers. No visual rule: MES VENTES, Unusual maximum dialog, Confier result, teaser. "Status chip (market)" and "Suspended banner" have no matching behavioural row (EXP:337 to 351, EXP:591; DES:908, DES:1228 to 1239). *Fix:* one name per component in both spines, and fill the missing halves.
- **[medium]** "Comment ça marche", whose stated job is the rules with every number read from the game, covers neither PiCoins, fees nor auctions (EXP:59; DES:1202). *Fix:* add a market panel, or record that it is left out.
- **[medium]** DES:1269's Don't still forbids showing "a market, sales, currencies", now the opposite of the spec. *Fix:* drop those three words or scope them to the generated canvas's versions.
- **[medium]** 6A drifted. The author chose a badge "counting the auctions that need action" (memlog 848), EXP:255 adds won, sold and unsold auctions with no tag, and the mock shows a badge of 3 for four lines and a chip of 2 for one DÉPASSÉ row. *Fix:* confirm the wider count with the author and correct the mock.
- **[medium]** 8B drifted. The memlog shows the price when the player "sorts or filters by price", but EXP:310 hides it "with any other sort", so a price filter on a name sort shows none (memlog 850). *Fix:* "shown when sorted or filtered by price".
- **[medium]** Blocking `[ASSUMPTION]` tags: the English of every market line (EXP:172), needed for `en.yml`; the teaser content, for which only a title exists (EXP:333, EXP:931); the buy-now dialog (EXP:342); DOUBLONS (EXP:346). Also the suspended sentence awaiting approval (EXP:180). *Fix:* the author settles or writes these before the build starts.
- **[medium]** An outbid caused by a buy-now has no fitting copy: the line invites a raise on an auction that is over (EXP:174, EXP:178; ARCH:556). The sale line target is also ambiguous ("the listing or MES VENTES", EXP:253), and the live reload sentence of the bell omits market notices though Flow 7 needs it (EXP:253, EXP:876). *Fix:* a variant line, one target per kind, add market notices to the reload list.

### Low

- **[low]** The 100-6-Tron, a player-facing term with a stated role, appears nowhere in the spines, and the fees are stated plainly though "the Brotherhood announces and justifies each fee in its tone" (ECO:10, ECO:17; SPEC:241; EXP:176). *Fix:* one line in the Confier result and each fee's hint.
- **[low]** "Timbre conservé" can read as the player keeping the stamp (EXP:177). *Fix:* "Le timbre n'est pas remboursé."
- **[low]** "VENDRE" and "CONFIER" as phone labels are in DES only, and "Vendue par", "Fondé sur n ventes" and the "CONFIER · <amount>" label are only in the mock (DES:1229; EXP:173, EXP:295, EXP:340). *Fix:* add them to the Copy deck.
- **[low]** The multiple in "C'est <n> fois" has no rounding rule (the mock's 22 is 22.2) (EXP:173). *Fix:* truncate, stated once.
- **[low]** Beaten-at-once clears and focuses the field and also offers "RÉESSAYER", with no stated effect (EXP:174, EXP:343). *Fix:* drop the button or give it one.
- **[low]** Copy deck singular and plural forms are missing for several lines ("<n> carte", "CONFIER <n> EXEMPLAIRES", "12k engagés", the mock's "0 engagé"), and French plural keys need a zero form (EXP:172, EXP:175). *Fix:* list the forms.
- **[low]** Visitors' MES ENCHÈRES and MES VENTES chips are unstated, and Annonce is missing from the two lists of what a visitor reaches (EXP:84, EXP:519, EXP:592). *Fix:* add Annonce and state the chips.
- **[low]** A price filter or sort while the market is not open is not excluded, since EXP:590 lists only Marché and card detail (EXP:310, EXP:590). *Fix:* add the two grids.
- **[low]** "Annonce, Confier and Mettre en vente name their way back, ◀ MARCHÉ" is unconditional, though they open from the feed, the bell and the card detail; the mocks' "◀ CONFIER" and "◀ VENDRE" differ (EXP:80). *Fix:* say whether it names the previous screen.
- **[low]** The Typical price per rarity is left undecided though ARCH leaves it to the UX (ECO:58; ARCH:855). *Fix:* record "not at launch".
- **[low]** "Toutes les cartes … later the trade and sale view" is a leftover, and the "not part of these flows" sentence now sits between Flow 6 and Flow 7 (EXP:40, EXP:870). *Fix:* remove the first, move the second to the section's end.
- **[low]** "Seul vous le voyez" is untrue when the price is capped at the leader's maximum, an accepted limit (EXP:174; ECO:88). *Fix:* drop the sentence in that case.
- **[low]** Hard-coded values in new market text (17px, 30px, 330px, a tenth of a colour, the bevel, `#2a475e` in the balance chip's border) have no tokens (DES:514, DES:1228, DES:1230, DES:1231, DES:1239). *Fix:* add tokens or use `{colors.line}`.

## Clean

- Every `{path.to.token}` in the market text of both spines resolves in the frontmatter.
- Menu numbering (01 to 08, keys 1 to 8), five phone and native tabs (EXP 78, 80, 254, 752; DES 929) and the desktop hub mock agree.
- "Un joueur anonyme" survives only as the note recording its replacement (EXP:164).
- "Any tax or fee before the market" (EXP:107) and the no-price card face (DES:793) are consistent with the market.
- Key Flows are numbered 1 to 9 with no gap.
- The seller cannot bid on their own listing (EXP:595), and the daily reset is stated (EXP:175).
- Export of market data needs no new surface (EXP:577; ARCH:590).
