# Accessibility review of the market UX contract (2026-11-09)

Scope: the market part of `EXPERIENCE.md` and `DESIGN.md`, and the chosen options in `mockups/market-options.html` and `mockups/market-screens.html` (1A, 2A, 3A, 4B, 5A, 6A, 7A, 8B). Target WCAG 2.2 AA. `review-accessibility-2026-11-09.md` was read to avoid repeating what it settled. Line numbers are those of the working copy on 2026-11-09. Where a mock departs from a spine the spine wins, and the finding says so.

## Overall verdict

The contract gets the visual layer right: every active text colour clears 4.5:1, status is written in words, and auctions are covered by the 2.2.1 real-time exception. It is not buildable yet for a screen reader or keyboard user, because incoming auction events are not separated from the player's own bid, the Focus table has no market row at all, the Confier stepper cannot be reached as specified, and the usual one-gesture bid never says it is final. All of it is fixable in the documents before the build, mostly by adding rows and copy, with no change to the author's choices of 4B or 2A.

## Verdict per area

| # | Area | Verdict | In one line |
|---|---|---|---|
| 1 | Screen readers and live updates | **broken** | The floor bullet has the right throttle, but the events that land mid-typing are classed as "bid results" that take focus and replace the form's foot. The status line has no copy, and an outbid never reaches a screen reader. |
| 2 | Keyboard and focus | **broken** | No market row in Focus after each step; the Confier stepper contradicts the single tab stop; two rules disagree on focus after a beaten bid. |
| 3 | Time limits and irreversible actions | **thin** | 2.2.1 is met and the soft close is a real help. Finality is stated only in the rare dialog; Confier's is stated nowhere. |
| 4 | Perception | **adequate** | No failing active text pair. One colour-only mark (the leader's history row) and amounts locked inside disabled buttons. |
| 5 | Text and reflow | **thin** | No spoken form for compact amounts, a separator conflict between DESIGN and the mocks, large figures that overflow at 320 px, and no English copy. |
| 6 | Touch and motion | **thin** | The floor's sizes are right, but the 44px stepper does not fit the phone grid and pinned bars take half a zoomed viewport. Nothing moves, so motion is clean by silence. |
| 7 | Forms | **thin** | The label and minimum are well placed. There is no refusal copy, no association rule and no input specification. Visitors get grey buttons with no reason. |

**On 3.3.4:** PiCoins are not money, so the criterion may not bind strictly on bids, but it also covers actions that "modify or delete user-controllable data", which fits Confier and listings. The contract arguably meets its letter through the "Checked" branch (minimum, balance and 3× checks). The findings below are about the user not being told, not about a formal failure.

**On 2.2.1:** auctions are the example WCAG itself gives for the real-time exception. This area passes. "Mon maximum" is a genuine alternative for a user who cannot react in time, and the soft close is more than the criterion asks for.

## Contrast ratios

Computed with WCAG relative luminance from the hex values in `DESIGN.md`'s frontmatter. "Needed" is 4.5:1 for text at these sizes and 3:1 for non-text.

| Pair | Where used | Ratio | Needed | Result |
|---|---|---|---|---|
| `gold` #f4c542 on `ground` #0b0f15 | PRIX ACTUEL at 30px, Annonce column | 11.81 | 4.5 | Pass |
| `gold` on `panel` #121a24 | recap total, what the seller receives, leader's edge | 10.77 | 4.5 / 3 | Pass |
| `gold` on `panel-sunken` #0e141b | card value in the Confier and sale pickers | 11.38 | 4.5 | Pass |
| `gold` on `panel-raised` #1b2838 | dialog amount as drawn in the mock | 9.18 | 4.5 | Pass |
| `gold` on `steam-bar` #171a21 | total in the phone bar | 10.70 | 4.5 | Pass |
| `alert` #e8833a on `ground` | time under one hour, tile and Annonce | 7.08 | 4.5 | Pass |
| `alert` on `panel` | time in rows, DÉPASSÉ chip, its frame | 6.45 | 4.5 / 3 | Pass |
| `alert` on `panel-raised` | as drawn in toast and panels | 5.50 | 4.5 | Pass |
| `alert` on a tenth of itself over `ground` (#211b19) | suspended banner title | 6.26 | 4.5 | Pass |
| `text` on that tint | suspended banner body | 11.35 | 4.5 | Pass |
| `lime` #a4d007 on `panel` | EN TÊTE chip, its frame, result edge | 9.68 | 4.5 / 3 | Pass |
| `accent` #66c0f4 on `panel` | EN COURS chip, linked names | 8.68 | 4.5 | Pass |
| `accent` on `panel-sunken` | Rare-or-better note | 9.18 | 4.5 | Pass |
| `accent` on `ground` | "Achat immédiat" on a tile | 9.52 | 4.5 | Pass |
| `muted` #8f98a0 on `panel` | PERDUE, SANS OFFRE, history time, labels | 5.98 | 4.5 | Pass |
| `muted` on `ground` | "n offres" | 6.55 | 4.5 | Pass |
| `muted` on `panel-sunken` | committed amount in the balance chip | 6.32 | 4.5 | Pass |
| `muted` on `panel-raised` | small text in the mock's dialog and bell | 5.09 | 4.5 | Pass |
| `muted` on `steam-bar` | phone bar small line | 5.94 | 4.5 | Pass |
| `text-max` on `ground` / `panel` / `panel-sunken` | prices, balance, amounts | 19.21 / 17.52 / 18.51 | 4.5 | Pass |
| `text` #c7d5e0 on `panel` | the live sentence | 11.70 | 4.5 | Pass |
| `on-lime` on `primary` | ENCHÉRIR, RELEVER when filled | 6.23 | 4.5 | Pass |
| `text-bright` on `line` | secondary buttons, ACHETER MAINTENANT | 8.29 | 4.5 | Pass |
| `on-alert` on `alert` | orange count badge | 6.90 | 4.5 | Pass |
| `on-gold` on `gold` | the π mark (decorative, hidden) | 11.89 | none | Fine |
| Rarity text on `panel`: commune / peu commune / rare / épique / légendaire | rows | 5.98 / 8.78 / 8.68 / 6.06 / 10.77 | 4.5 | Pass |
| Rarity text on `panel-raised` (card band) | same order | 5.09 / 7.48 / 7.40 / 5.16 / 9.18 | 4.5 | Pass |
| `accent` on `input` #0b1015 | My maximum frame | 9.47 | 3 | Pass |
| `line-deep` on `input` / `panel` | required control border | 3.49 / 3.20 | 3 | Pass |
| `disabled-text` #56636f on `disabled-bg` #18212a | grey actions | 2.64 | exempt if inactive | Note, see Part A (amount in a greyed control) |
| `disabled-bg` on `panel` / `ground` | grey control's edge | 1.08 / 1.18 | exempt if inactive | Note |
| `muted` on `disabled-bg` | alternative for what a grey control must say | 5.56 | 4.5 | Pass |
| `line` #2a475e on `panel` | balance chip border, not interactive | 1.80 | decoration | Fine |
| `line` on `ground` / `input` as field frame in the mock | `.field`, `.chip`, `.sel` | 1.97 / 1.96 | 3 | Mock fails, see Part A (mock departures) |
| `#fff` on `#8a5cff` | bell count in the mock | 4.15 | 4.5 | Mock fails, see Part A (mock departures) |
| `dim` on `panel` | not used by the market | 3.20 | n/a | Keep it out |

`{colors.dim}` appears nowhere in the market sections. Keep it so.

## Findings

Severity is user harm. Part A lists what the contract gets wrong or contradicts. Part B lists what it has not said.

### Part A. Failures of the contract

- **[critical]** Incoming events are classed as the player's own "bid result". Copy deck "Bid results" holds "outbid later", "extended" and "won" alongside the two answers to the player's own bid. Row 343 makes any bid result replace the form's foot, and floor 690 makes it take focus, while the same bullet says live updates "never move focus" and row 340 says "what the player is typing is never touched". As written, an extension or an outbid in the last three minutes can pull focus out of the field or remove ENCHÉRIR while the player is typing, exactly when bidding matters. (`EXPERIENCE.md`:174, 340, 343, 690, 4.1.3, 3.2.1.) *Fix:* split the row in two. "Answer to my bid" (leading, beaten at once, refused) replaces the foot and moves focus as the table below says. "Event" (outbid later, extended, won, auction ended) never moves focus and never replaces the foot, the field or the button while the field has focus, holds text, or a dialog is open: it posts to the status line and shows in a panel above the form. Only "auction ended" removes the form, under B2.

- **[critical]** The usual bid is final and nothing on the one-gesture path says so. "L'offre ne peut pas être annulée" exists only in the unusual-maximum dialog, shown at 3× or more. The live sentence says PiCoins are "bloqués, puis rendus", which reads as temporary, and ENCHÉRIR carries no amount (option C's "ENCHÉRIR · 35 000" was not kept, and 4B's mock shows the bare label). A player commits PiCoins without being told it cannot be undone. (`EXPERIENCE.md`:173, 342, `market-options.html` choice 4B, 3.3.4, 3.3.2.) *Fix:* add a fixed sentence next to the button, visible and not live, in both languages: "Une offre ne peut pas être annulée." Tie it to the button with `aria-describedby`. Give the button the amount in its name, starting with its visible text so 2.5.3 holds: "Enchérir, maximum 35 000 PiCoins", and show the amount on the button once the field is valid, as ACHETER already does. An author who wants the bare label keeps it visible and keeps the amount in the name.

- **[high]** Two rules disagree on focus after a beaten bid. Floor 690: "a bid's result is announced and takes focus on its heading." Row 343 and Flow 7's failure line: "keeps the field, cleared and focused." Moving focus also announces it, so "announced and takes focus" would speak twice. (`EXPERIENCE.md`:343, 690, 880, 2.4.3, 4.1.3.) *Fix:* floor 690 becomes: "Leading, won by buying at once: focus on the result's heading (`tabindex=-1`), no separate announcement. Beaten at once: focus stays on the cleared field, the panel's text is its `aria-describedby`, and the text is posted once to the status line."

- **[high]** The Confier grid is "one tab stop with arrow keys inside", but its cards carry steppers, and arrows inside a stepper change the quantity. A stepper in such a grid is unreachable by Tab, and arrows cannot do both. Doubles are the screen's purpose, so quantity is the main task. The card picker has the same latent conflict. (`EXPERIENCE.md`:346, 369, 605, 690, 2.1.1, 4.1.2.) *Fix:* add to row 346: "Arrow keys move between cards; Space or Enter ticks; + and − on a ticked card change its copies, whose value is in the card's name and announced by the status line. The stepper's buttons are for pointers, with `tabindex=-1`. A visible hint gives the keys." Apply the same to the card picker, or state why it differs.

- **[high]** Confier never says the player loses the card for good. The only sentence on the subject, "La Confrérie conserve chaque carte dans ses Archives, où elle ne sera jamais détruite", can be read as recoverable. An only copy and a Légendaire pass with no per-card confirmation (the author's choice, which this keeps), and Flow 8 describes adding one "without thinking". (`EXPERIENCE.md`:175, 346, 884, 3.3.4, 3.3.2.) *Fix:* add to the recap, above the button and tied to it by `aria-describedby`: "Les cartes confiées ne vous sont pas rendues." Keep the Rare-or-better line inside the button's description, so a screen reader user hears it at the moment of validating.

- **[medium]** Cancelling a buy-now dialog "returns to the field", because row 342 uses one rule for both dialogs. The opener of the buy-now dialog is ACHETER MAINTENANT, and table row 722 says focus returns to the opener. (`EXPERIENCE.md`:342, 722, 2.4.3.) *Fix:* "Cancelling returns to the control that opened the dialog: the field for an unusual maximum (or a maximum reaching buy-now), ACHETER MAINTENANT for buy-now."

- **[medium]** The history marks the leader by colour alone, against the floor's "the 'En tête' marks are words". Row 344 and the DESIGN history row give a 3px gold edge and no word, and the mock has none. It is also unclear which line is "the leader's": in Flow 7 step 2 the newest line belongs to a beaten bid while Léa still leads. (`EXPERIENCE.md`:344, 690, 875, `DESIGN.md`:1234, 1.4.1, 1.3.1.) *Fix:* the leader's row prints "En tête" after the name, and its accessible text includes it. State that the mark goes on the most recent line by the current leader, whichever position it holds.

- **[medium]** Visitors get "every action greyed and disabled, with nothing else", against the DESIGN rule "A disabled button never carries information on its own; its reason is written next to it". Native `disabled` also removes the buttons from the tab order, so a screen reader user finds a form with no explanation. Row 295's "greyed for a copy fully reserved" has the same gap. (`EXPERIENCE.md`:295, 592, `DESIGN.md`:754, 3.3.2, 1.3.1.) *Fix:* one line in the form's place for visitors: "Connectez-vous pour enchérir", with the sign-in link, and "n exemplaires réservés" beside a fully reserved copy's greyed action. If the author insists on "nothing else" for visitors, DESIGN 754 needs a stated exception, and a visually hidden sentence still gives the reason.

- **[medium]** Information sits only inside a greyed control: "CONFIER · 5 000" on a fully reserved copy in the card detail shows the amount at 2.64:1. Contrast is exempt for inactive controls, but the amount is not repeated elsewhere. (`EXPERIENCE.md`:295, `DESIGN.md`:754, `market-options.html` choice 2A shortcut, 1.4.3.) *Fix:* write the amount in the card's facts, or drop it from the greyed label.

- **[medium]** The whole live sentence is the polite status, about 30 words re-read after each 500ms pause. The fixed explanation drowns out the only part that changes. (`EXPERIENCE.md`:173, 690, 4.1.3.) *Fix:* split it. The first two sentences are static and tied to the field by `aria-describedby`. Only "<amount> PiCoins seront bloqués" is in the status region, with the buy-now and leader variants. When the status text is unchanged, nothing is posted.

- **[medium]** The phone stepper does not fit the grid as drawn. Three columns on a 390px phone give 112px per cell, and 2 × 44px buttons, the ×N figure and the floor's 8px gaps need about 120px. At 360px the cell is 103px and at 320px 89px. A builder will shrink the targets. (`EXPERIENCE.md`:693, `DESIGN.md`:517, 693, 1051, 1235, `market-options.html` `.g3p`, 2.5.8.) *Fix:* state in DESIGN 1235 that the phone Confier grid has two columns (174px at 390, 139px at 320), with the stepper across the cell's full width.

- **[medium]** Mock amounts use U+202F and plain spaces, mixed: 80 and 69 U+202F in the two files, against DESIGN's U+00A0. Screen readers do not treat them alike, and builders copy from mocks. (`DESIGN.md`:650, mocks, 1.3.1.) *Fix:* one shared amount helper emits U+00A0 only, and the digit-grouping rule names market amounts. Correct the mocks.

- **[medium]** The Esc primitive sends the player to the hub whenever no text field has focus and "no edit is pending". The market does not say that a typed maximum or ticked cards count as pending. A keyboard user pressing Esc on ENCHÉRIR or in the Confier grid loses the work, and an auction screen. (`EXPERIENCE.md`:606, 3.3.4, 2.1.1.) *Fix:* add to row 606: "A typed maximum, ticked cards or a filled sale form count as a pending edit; Esc does nothing on Annonce, Confier and Mettre en vente beyond closing the topmost overlay."

- **[medium]** Rows "Count badge" and the Bell give no name for the market badge. "Its number is part of the item's accessible name" produces "Marché, 3", a sum of outbids and unseen outcomes that says nothing a player can act on, the same defect the earlier review fixed for the player menu. (`EXPERIENCE.md`:255, 80, 4.1.2, 2.4.6.) *Fix:* add a Copy deck row: "Marché, 2 enchères dépassées, 1 résultat à voir"; "Mes enchères, 2 dépassées"; both hidden at zero parts.

- **[medium]** The installed web app locks portrait (`"orientation": "portrait"`) and "held sideways, nothing changes". This is product-wide and was not raised by earlier reviews; the market inherits it, on the bid form most of all. (`EXPERIENCE.md`:738, `DESIGN.md`:692, 1.3.4.) *Fix:* drop the manifest lock, or record it as a stated exception. A phone mounted sideways must still reach the form.

- **[low]** Mock departures that builders may copy: `.field`, `.chip` and `.sel` frames in `line` (1.80:1) where DESIGN 593 requires `line-deep`; the bell count violet at 4.15:1 where row 253 says the alert colour; the phone field 42px tall; tab labels at 9px and status chips at 10px where the tokens say 11px. (`EXPERIENCE.md`:253, 693, `DESIGN.md`:593, 1237, 1.4.11, 1.4.3.) *Fix:* correct the mocks, or add a line to both market mocks saying their control borders, badge colours and small sizes are not to be copied.

- **[low]** Mock text at 12px and below is often not bold, against floor 694: `.bv small` (labels "Prix", "Mon maximum", 10px), `.hist small` (the time), `.fine` (the end time and the rule on extensions), `.bal small` (the committed amount), `.sf-sum small` ("payé maintenant, jamais remboursé"), and `.cap-g`. DESIGN does not give these styles, so the mock is what a builder has. (`EXPERIENCE.md`:694, `DESIGN.md`:1231 to 1239.) *Fix:* add to DESIGN: "Every market line at 12px or below uses `{typography.label}` or `{typography.body-small}`."

- **[low]** `{components.balance-chip.height}` is a fixed 34px against "Rows holding text use a minimum height", and the phone chip drops the committed amount when space is short, with no rule for its accessible text. (`DESIGN.md`:511, 652, 908, 1.4.12, 1.3.1.) *Fix:* a minimum height; and the accessible text always holds both amounts, written in full (see B9).

### Part B. What the contract has not said

- **[high]** B1. *Focus after each step* has no market row. A builder has only the generic "Back or dialog closed" and "Sub-view opened". (`EXPERIENCE.md`:703 to 731, floor 678, 2.4.3.) *Fix:* add these rows:

| Step | Focus goes to |
|---|---|
| Annonce opened | Its h1, the card's title |
| "ENCHÉRIR" accepted, or a raise accepted | The "VOUS ÊTES EN TÊTE" heading |
| Beaten at once | The field, cleared |
| "RÉESSAYER" or "RELEVER MON MAXIMUM" | The field |
| Refused inline, or a concurrent change | The field, keeping what was typed |
| Unusual-maximum or buy-now dialog opened | The dialog's title, so the amount is read before any button; never "CONFIRMER" |
| Dialog confirmed | As the bid's result, or the outcome heading after buying |
| Auction ended while in the field or dialog | The outcome's heading |
| "RELEVER" in a row | The Annonce, on the field |
| Row or tile opened | The Annonce's h1 |
| "CONFIER ▸" (phone sheet) | The sheet's title; closing returns to "CONFIER ▸" |
| Confier validated | The result's heading |
| "SUIVANT" (sale, phone) | Step 2's heading; back returns to the chosen card |
| Listing created | The new Annonce's h1 |
| Listing cancelled | The next row's title, or the group heading |

- **[high]** B2. Nothing covers the auction ending while the player is acting. "The form gives way to the outcome" removes a focused field, and a modal may still be open offering "CONFIRMER 700 000" on a dead auction. A price change also makes the dialog's "n fois" stale. A refetch can also close a dialog or drop a focused history link. (`EXPERIENCE.md`:340, 342, 594, 678, 2.4.3, 3.3.4, 4.1.3.) *Fix:* add to row 594: "When the auction ends with a dialog open, it closes itself; the outcome's heading takes focus, the status line says the auction has ended, and the typed amount is not submitted. A refusal because the auction ended is its own message, never 'try again'. A dialog's amount is what is submitted; if the price moves, its multiple updates, and if the price passes the maximum the dialog closes and the field shows the refusal. The page's refetch uses morphing and leaves the open dialog and the focused element alone."

- **[high]** B3. An outbid never reaches a screen reader. Option 6A rules out a toast; the sighted player has an orange badge on every page, but the bell's name changes silently. Row 253's list of what reloads the bell live does not include market notices, although Flow 7 step 3 assumes it. This is the most time-sensitive signal in the feature. (`EXPERIENCE.md`:253, 255, 876, 4.1.3.) *Fix:* add to row 253: "The bell and badges reload live on market notices. An outbid posts its bell line once to a polite status region present on every signed-in page, as a status and not a toast, at most one message per listing per 30s."

- **[high]** B4. The refusals have no copy, no timing and no association. Row 341 and row 348 say "refused inline"; the Copy deck has no refusal for the market (the trades have "Trade refusals", line 139), and row 593 gives only "asks to try again". Agents will invent text in two languages. (`EXPERIENCE.md`:173, 176, 341, 348, 593, 3.3.1, 3.3.3, 1.3.1.) *Fix:* add a Copy deck row "Market refusals (inline)", one string per cause and both languages: below the minimum (naming it), above what can be committed (naming the amount available), buy-now not above the start, below the rarity minimum, stamp unavailable, concurrent change, auction ended. Add to floor 690: "A refusal is checked on submit, shown under its field, with `aria-invalid` and `aria-describedby`, and cleared on the next edit."

- **[high]** B5. The polite status line has no text, no merge rule, and cannot be heard from a dialog. The floor gives only the throttle; the Copy deck has no row. Throttled updates could lose the last value, and `inert` content is ignored by assistive technology, so a status region outside the modal says nothing while it is open. (`EXPERIENCE.md`:173, 690, 679, 4.1.3.) *Fix:* add a Copy deck row: "Prix <amount>, en tête <name>. Fin à <time>." ("Vous êtes en tête" when so). Add to floor 690: "One region, empty at load; a post carries the latest state, so the last update is never dropped; an extension and the end bypass the 10s; a dialog holds its own status line."

- **[high]** B6. Enter is not specified, and native forms submit on it. Typing an amount and pressing Enter would place an irrevocable bid, possibly before the 500ms sentence has spoken, with no button seen. (`EXPERIENCE.md`:341, 605, 690, 3.3.4, 3.2.2.) *Fix:* add to row 341: "Enter in the field moves focus to the action button, whose name carries the amount; it does not submit. The submit uses the field's current value and the same checks as the button, and a double activation submits once." State the same for the sale form.

- **[medium]** B7. Auto-updating content has no way to be quietened. A busy auction speaks every 10s for hours, and the feed's rule that "ANIMATIONS RÉDUITES" stops announcements is not extended here. (`EXPERIENCE.md`:681, 690, 2.2.2.) *Fix:* add a labelled switch on the Annonce, "Annoncer les offres" (`aria-pressed`, on by default, remembered), which stops the status line but never the result of the player's own bid or the end.

- **[medium]** B8. The countdown's format and the last minutes are undefined. The contract gives nothing below "18 min" (whether seconds appear under a minute), no copy for the accessible end time, and no time zone, while the cap resets "à 00:00 UTC". A screen reader user gets no equivalent of the orange turning on. (`EXPERIENCE.md`:339, 689, 690, `DESIGN.md`:1231, 2.2.1, 4.1.3.) *Fix:* add a Copy deck row for the time: visible minutes, then "moins d'une minute"; an accessible "Se termine aujourd'hui à 22:14", in the player's local time, in a `<time>` element. For a bidder, the status line posts once at the last hour and once at 3 minutes left.

- **[medium]** B9. Compact amounts have no spoken form: "31,5k" and "7,2M" read as "31 virgule 5 k", the exact value is lost, and DESIGN only adds "PiCoins". 3.1.4 is AAA, so this is not an AA failure, but MES ENCHÈRES shows a player's own maximum this way. (`EXPERIENCE.md`:97, `DESIGN.md`:1228, `market-screens.html` choice 7A, 1.3.1, 3.1.4.) *Fix:* one shared amount component, as for Names: the compact text visible and hidden from assistive technology, the exact amount and "PiCoins" visually hidden, in the language of the page ("31.5k" in English). Rows show "Mon maximum" exact, since the player decides on it.

- **[medium]** B10. Rows and tiles have no accessible structure. A row "opens the Annonce" and also holds RELEVER or ANNULER, which invites nested interactive elements; "RELEVER" repeats with no target; the listing tile's name is undefined. (`EXPERIENCE.md`:339, 349, 350, 684, 4.1.2, 2.4.4.) *Fix:* reuse the Trade suggestions pattern: the opener a link stretched over the row, the action a sibling after it. Add to the Copy deck: tile name "Hollow Knight, Rare, saison 2, 31 500 PiCoins, 3 offres, se termine à 22:14, achat immédiat 60 000 PiCoins"; action names "Relever, Hollow Knight" and "Annuler la vente, Hollow Knight".

- **[medium]** B11. Ticking a card changes the recap, the count, the total and the cap in silence, and the sale form's "each line updates" likewise. (`EXPERIENCE.md`:346, 348, 4.1.3.) *Fix:* one polite status per screen, after 500ms without change: "4 exemplaires, 10 000 PiCoins"; for the sale, "Vous recevez 18 000 PiCoins".

- **[medium]** B12. "ANNULER" on a listing has no confirmation rule, and the stamp is "jamais remboursé". (`EXPERIENCE.md`:176, 350, 595, 3.3.4.) *Fix:* state that it confirms in the same dialog as a bid, naming the card and "Le timbre n'est pas remboursé", with focus on the title and the safe action on Esc.

- **[medium]** B13. The money fields have no input specification. Nothing says what the field accepts, on either the bid or the sale form, and a `type=number` rejects the separator. (`EXPERIENCE.md`:341, 348, 1.3.5, 3.3.2.) *Fix:* add: "`type=text`, `inputmode=numeric`, `autocomplete=off`, a stated unit in the name ('Mon maximum, en PiCoins'); spaces accepted on paste; the minimum in `aria-describedby`; no prefilled amount on a bid. A relisting may prefill the start and buy-now, and says so."

- **[medium]** B14. Choosing a card for sale can reload the form as focus moves. A single-choice grid with arrow keys, side by side with a form that depends on the card's rarity, invites a change on each arrow press. (`EXPERIENCE.md`:348, 605, 690, 3.2.2.) *Fix:* "Arrows only move focus; Space or Enter chooses, and only then do the form and its minimum change. The status line names the chosen card and its minimum."

- **[medium]** B15. The pinned bars take half of a zoomed viewport. At 400% on 1280 × 1024 the viewport is 320 × 256, and the phone layout applies: 58px tab bar and about 66px Confier bar leave about 130px. The floor's scroll padding keeps focus clear but cannot make room. (`EXPERIENCE.md`:346, 678, `DESIGN.md`:292, 1235, 2.4.11, 1.4.10.) *Fix:* reuse the back picker's threshold (line 743): "The Confier and sale bars pin only from 560 CSS px of viewport height; below, they sit at the end of the content."

- **[medium]** B16. The 30px figures overflow at 320 px. PRIX ACTUEL and FIN DANS stand side by side with no wrap rule: "7 500 000" with its mark (about 190px) plus "2 h 14" (about 108px) and a 12px gap needs 310px of the 288px available, and Légendaires start at 7 000 000. (`DESIGN.md`:1231, `market-options.html` `.pblock`, 1.4.10.) *Fix:* "The two figures stack under 400 CSS px of content."

- **[low]** B17. The sale form on the phone has no step indication. (`EXPERIENCE.md`:348, 2.4.8 is AAA, 1.3.1.) *Fix:* "Étape 1 sur 2" in the heading's name; back from step 2 keeps the card and amounts.

- **[low]** B18. The price shown under a card when sorted by price is not placed in the card's name, and the price range filter has no specified labels. (`EXPERIENCE.md`:310, 687, 338, 1.3.1, 3.3.2.) *Fix:* add to floor 687: "Sorted by price, the name ends with the average price or 'sans vente'." Add: two labelled fields, "Prix minimum" and "Prix maximum", never a slider alone.

- **[low]** B19. No English for the market's rows, including every accessible name. Row 172 flags it, but the agents have only the documents. (`EXPERIENCE.md`:172 to 180, 931, 3.1.2.) *Fix:* write the English in those rows, and the new rows above, before the build.

- **[low]** B20. Player names that are links in the history and the Annonce are small on the phone, about 20px tall. 2.5.8 passes by spacing, but floor 693 asks 44px of every phone target. (`EXPERIENCE.md`:345, 693, 2.5.8.) *Fix:* the Names component gets a 44px hit area on the phone by padding or a pseudo-element, or row 693 states the inline exception.

- **[low]** B21. The back-office has no form rules. Each field in the rarity table needs a name made of its row and column; the reason must be tied to its field; the mock's checkboxes are 18px. (`EXPERIENCE.md`:351, `DESIGN.md`:1208 to 1210, 1.3.1, 3.3.1, 2.5.8.) *Fix:* add to row 351: "Names by `aria-labelledby` from the row and column headers; a refusal in `aria-describedby`; 'Préparer ce changement' moves focus to the first changed field; 24px minimum targets; the settings table may scroll sideways within its own container."

- **[low]** B22. The market says nothing on motion. No sale, close or price change animates, so there is nothing to fail. A builder may add a flash on a live price. (`EXPERIENCE.md`:609 to 657, 692, 2.3.1.) *Fix:* add one line: "Live changes in the market do not animate beyond a colour change of under a second; with 'ANIMATIONS RÉDUITES' they do not animate at all."

## Clean

- **2.2.1:** covered by the real-time exception; the maximum and the soft close go beyond it. No session or form timeout was found in these pages.
- **Contrast of active text:** every pair in use passes, the orange under one hour included (7.08 on the ground, 6.45 on a panel).
- **Status in words:** chips, result headings and rarity all print a word; colour is never the sole carrier, the history's leader row aside (Part A).
- **The π mark:** hidden from assistive technology with the amount carrying "PiCoins", and the mocks' `aria-hidden` is right.
- **Label of the maximum:** a visible, permanent label, with the minimum beside it.
- **Names with no link:** plain text rather than a disabled link is the right call, and "anonyme" follows it.
- **Focus ring and general scroll padding:** the existing rules cover the market's sticky bars at normal zoom (2.4.11).
- **Desktop stepper:** 24 × 26 meets 2.5.8.
- **Ticked state:** the lime frame comes with a check mark, so it does not rest on colour.
- **Unusual-maximum dialog:** naming the amount and multiple, with Esc returning to an unchanged field, is the right pattern once its focus row exists.
