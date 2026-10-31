# Accessibility review of the 2026-10-31 spine update

Scope: the 2026-10-31 diff to `DESIGN.md` and `EXPERIENCE.md` (trade suggestions, the reworked Personnalisation page and back picker, the four achievement backs, goal bookmarks on trade boards) and the three mocks it links. The bar is the existing floor: `EXPERIENCE.md` Accessibility Floor and Focus after each step, `DESIGN.md` Colors. Line numbers are those of the working files on 2026-10-31.

Severity: **blocker**: the spines as written would ship a WCAG 2.2 A/AA failure or contradict the floor in a way a builder cannot settle alone. **should-fix**: a gap or ambiguity that is likely to produce a defect. **note**: checked and fine, or a refinement.

Contrast measured from the token hexes in `DESIGN.md` (WCAG relative luminance).

---

## Blockers

### B1. The back picker's sticky strip has a fixed height and is not in the scroll padding

- **Where:** `DESIGN.md` 1078 ("one strip 64px tall (96px on the phone …), sticking to the top of the screen while the section scrolls"); `EXPERIENCE.md` 610 (phone: "sticks under the top bar"); floor 548 ("scroll padding keeps it clear of sticky bars"); mock `personalization.html`, frame "Téléphone : toucher un dos" (`.strip{height:64px}`, phone `height:96px`).
- **Problem:** two failures. (1) The strip is a new sticky bar the floor's scroll-padding rule does not list, so when a player tabs through the mosaic, a back (98px target on the phone) can scroll under the top bar plus the 96px strip and be hidden entirely (2.4.11 Focus Not Obscured). (2) A fixed height clips the strip's text under user text spacing and at zoom (1.4.12; the floor's own "text rows use a minimum height"). At 200% zoom the desktop reaches the phone layout, and a long sentence ("Gagné avec le succès A Strictly Professional Relationship · Trois échanges conclus avec le même joueur" plus the chip, the name and the date) runs past three lines at 360px. At 400% zoom (320 × 256 CSS px), the top bar, the 96px strip and the tab bar leave almost no room for the mosaic (1.4.10).
- **Fix (spine rule, `DESIGN.md` Back picker and floor Keyboard):** "The strip's 64px (phone 96px) is a minimum height, never a fixed one: its text wraps and the strip grows. While it sticks, the page's scroll padding adds the strip's current height, so a focused back is never under it. The strip sticks only while the viewport is at least 560 CSS px tall; below that it scrolls with the section."

### B2. A locked set back's progress shows only in the strip, which is hidden from assistive technology

- **Where:** `EXPERIENCE.md` 555 ("the strip repeats that name and is hidden from assistive technology"), 323 ("a set back's 'plus que N' progress shows in the strip only"), Copy deck 139 (accessible names); mock `personalization.html`: the Souls-like button is named "Souls-like, verrouillé. Atteignez la moitié du set Souls-like." while its hidden strip adds "11 / 38 cartes · plus que 8".
- **Problem:** the strip shows more than the back's name: the set progress, and the "DÉBLOQUÉ"/"VERROUILLÉ" chip. Hidden from AT, the progress is lost to a screen-reader user (1.3.1). The floor's "repeats that name" is untrue for set backs.
- **Fix (floor, Back picker):** "A back's accessible name holds everything the strip shows for it, in the strip's order: name, state, the sentence, then the date or the set progress ('Souls-like, verrouillé. Atteignez la moitié du set Souls-like, 11 cartes sur 38, plus que 8.'). The strip shows nothing the name lacks, so it can stay hidden from assistive technology." Add the progress form to the Copy deck row (139), in `en.yml` and `fr.yml`.

---

## Should-fix

### S1. The focus destination after "ENVOYER" points at a heading that does not exist and can cause a double send

- **Where:** `EXPERIENCE.md` 585 ("The next suggestion, or the trade list's heading when none is left `[ASSUMPTION]`"); 288 (after the send the suggestion leaves and the trade tops "EN ATTENTE DE LEUR RÉPONSE"); mock frame 4.
- **Problem:** the trade list has no heading of its own (its groups are h2s, the screen's h1 is "Échanges"); when the last suggestion goes, the whole SUGGESTIONS section disappears with its h2. "The next suggestion" doesn't say which of its two controls. If focus lands on the next row's "ENVOYER", a held or repeated Enter sends a second trade that reserves cards, with no confirmation.
- **Fix (focus table):** "'ENVOYER' on a suggestion row → the next suggestion row's opener (never its 'ENVOYER'); when none is left, the row of the trade just sent, at the top of 'EN ATTENTE DE LEUR RÉPONSE'." In the floor: "A list update that removes the focused element moves the focus as the table says; it never leaves it on `body`." That also covers a Turbo Stream that replaces the list.

### S2. In browse mode a suggestion row is read twice

- **Where:** `EXPERIENCE.md` 554 (the row is one control named by its accessible name; bookmarks, "×n" and avatar hidden); mock `trade-suggestions.html`, rows: an empty stretched `<a class="sg-open" aria-label="Suggestion de Hugo_B : Hades (…), Dead Cells (…) contre RimWorld">`, then the visible "Hugo_B", "En ligne", "Envoyer", "Hades, Dead Cells contre RimWorld" as plain text.
- **Problem:** a screen reader reading the list hears the long name, then the friend's name and the summary again. Only the presence is new information, and it is missing from the name a Tab user hears.
- **Fix (floor, Trade suggestions):** "The opener's name is the Copy deck's row name followed by the presence ('…, Léa_K choisit en retour. En ligne.'). The visible name, presence and summary lines, which the name repeats, are hidden from assistive technology, so each word of the row is read once; 'ENVOYER' stays exposed."

### S3. The key line loses the goal numbers for assistive technology

- **Where:** `DESIGN.md` 1044 and Copy deck 120 ("Pour vos objectifs :" followed by each goal's bookmark and set name); floor 553 (bookmarks are hidden from AT); mock: the key's bookmarks are *not* hidden there, so it reads "1 Roguelike 2 Metroidvania".
- **Problem:** with the bookmarks hidden, as the floor requires, the key reads "Pour vos objectifs : Roguelike, Metroidvania, Mes favoris, Supergiant Games". It loses the numbers that the rows' names use ("objectif 1 : Roguelike"), and the key is the only place that maps numbers to sets.
- **Fix (Copy deck, Trade suggestions):** "Each key item's accessible text is 'objectif n : <set>', the bookmark hidden and the number given in visually hidden text, as the OBJECTIFS chips are named."

### S4. The opener's role and nesting are not stated

- **Where:** `EXPERIENCE.md` 554 ("one control that opens its draft"), 288; `DESIGN.md` 1045; mock: `<a href="#">` stretched over the row (`position:absolute; inset:0`), "ENVOYER" a sibling `<button>` above it (`z-index:2`).
- **Problem:** the mock's pattern is correct: "ENVOYER" sits beside the opener, not inside it. The spines' wording ("a click or tap anywhere else on the row") would also allow a clickable `<li>` or a button wrapping "ENVOYER", which is invalid nesting that screen readers flatten. Link or button decides what a screen reader says ("lien" or "bouton") and whether middle-click works. A GET never writes, so if opening a suggestion creates a draft the opener cannot be a link.
- **Fix (floor, Trade suggestions):** "The opener is a sibling of 'ENVOYER', stretched over the row by CSS, never an element that contains it. It is a link when opening writes nothing, and a form button when it creates the draft. The opened row carries `aria-current="true"`, as the album row does."

### S5. Phone targets: season buttons and back spacing fall under the floor

- **Where:** floor 564 ("at least 44 × 44 CSS px for every phone target, 8px apart"); `DESIGN.md` 1078 (backs "6px on the phone"; season buttons "44px tall on the phone"); mock (phone: `.mk{height:44px;min-width:36px}`, 4px between S1 and S2, 6px under the back; backs' buttons 78 × 98, 6px apart).
- **Problem:** the season buttons are 36px wide and 4px apart, and the backs' hit areas are 6px apart, which contradicts the floor. "ENVOYER" lies inside the row's target, so the "8px apart" rule cannot apply as written there.
- **Fix (`DESIGN.md` Back picker and Suggestion row):** "On the phone each season button is at least 44 × 44, the buttons 8px apart and 8px under the back's target; the backs' targets are 8px apart (the art may sit closer inside them). 'ENVOYER' keeps at least 8px of the row's own target on every side."

### S6. Equipping has no failure state now that the toast is gone

- **Where:** `EXPERIENCE.md` 452, 323, 555 ("Equipping is confirmed by the highlight moving in place, never a toast"); Copy deck 139.
- **Problem:** the only confirmation is visual, plus a hidden status message. Nothing says what happens when the server refuses (a back just locked by a season change, a network failure). If the frame moves optimistically and the save fails, nobody knows (4.1.3), and the floor's "errors also stay inline" has nowhere to go.
- **Fix (State patterns, Card back locked / equipped):** "On a refusal or a failure the lime frame stays on, or returns to, the previous back, the strip shows the error in `{colors.alert}`, and the hidden status message says it ('Le dos n'a pas pu être équipé. Réessayez.' / 'The card back could not be equipped. Try again.'); the focus stays on the back."

### S7. The hidden announcement and the season buttons need build rules

- **Where:** floor 555; focus table 593; mock (`<span class="sr" role="status">` pre-filled in the page).
- **Problem:** (1) A status region inserted or replaced whole by a Turbo Stream, or filled at page load, is often not announced. Equipping the same back twice posts identical text, which some screen readers skip. (2) Choosing a season button also equips ("Équiper Roguelike avec la marque de la saison 1"), yet neither the announcement nor the focus table covers it.
- **Fix (floor, Back picker):** "The equip status region is in the page from load, empty; each announcement changes its text only (cleared first, so a repeat is announced again). A season button announces the same message with the season ('Dos équipé. « Roguelike », marque de la saison 1, …') and keeps the focus." Add to the focus table: "Season button under a back → stays on that button."

### S8. Back and achievement names in the other language cannot be marked inside an `aria-label`

- **Where:** floor 567 ("text in another language carries its own `lang`"); Copy deck 139 ("Gagné avec le succès <nom> · <condition>"); `DESIGN.md` 855–861; `../spec-gameble/achievements.md` (the four achievements have English names: "Luck Is a Marketing Concept" …). The mock builds every name with `aria-label`.
- **Problem:** if back names ("Trèfle fané", "Siège social") stay French in the English interface, or the satirical achievement names stay English in the French one, a screen reader speaks them with the wrong voice. An `aria-label` string cannot carry `lang` on part of it (3.1.2).
- **Fix (floor, Language):** "Every back name and achievement name has an entry in both `en.yml` and `fr.yml`. Where one is kept in its original language, the back's name is built with `aria-labelledby` on visually hidden spans, the foreign part carrying its own `lang`, never as an `aria-label` string."

### S9. The word printed on the Contrat back is not in its name

- **Where:** `DESIGN.md` 861 (Contrat, word "PACTE"); `achievement-backs.html`, candidate 4B (word "CONTRAT", dropped at the small size).
- **Problem:** on the phone the art is the only visible text on the back's button until a tap, which also equips. A voice-control user who says "Pacte" matches nothing, since the name starts "Contrat" (2.5.3 Label in Name). The other three are fine: TREFLE/Trèfle fané, ASSIDU/Assidu, SIEGE/Siège social.
- **Fix (`DESIGN.md` Card backs, beside the six-letter rule):** "A back's printed word is a word of its name, accents aside." Here: rename the back "Pacte", or give it a word taken from "Contrat" that fits six letters.

### S10. "No focus ring after a tap" must be worded so it cannot suppress the keyboard ring

- **Where:** floor 555 ("After a tap no focus ring is drawn on the back … the keyboard focus ring is unchanged"); `DESIGN.md` 1078 ("no focus ring shows after a tap"); `EXPERIENCE.md` 22 (the mock's ring on a tapped back is dropped; mock `.ta.tap .ta-b{outline:3px solid #fff}`).
- **Problem:** the intent meets 2.4.7 only if it rests on `:focus-visible`. Built as `blur()` after a tap, `outline:none` on `:focus`, or a "touched" class, it removes the ring for keyboard users who also use a pointer, or for a phone with a keyboard. With `blur()`, the focus also drops to `body`, which breaks "Stays on that back". The rule also says nothing of a mouse click on the desktop.
- **Fix (floor, Back picker):** "The ring follows `:focus-visible` alone: it shows on keyboard focus and not after a click or a tap. The focus stays on the back (no `blur()`, no `outline:none` on `:focus`), and the ring comes back with the next key press."

---

## Notes

- **N1. Faded suggestion rows pass contrast.** On `{colors.panel-sunken}`: `{colors.text}` 12.4:1, `{colors.text-bright}` 15.8:1, `{colors.muted}` 6.3:1, the lime and accent presences 10.2:1 and 9.2:1, `{colors.goal-2}`/`goal-4` 7.0:1. The dashed `{colors.line-deep}` edge reads 3.4:1 on the sunken ground and 3.2:1 on the panel (at least 3:1). The mock fades only the avatar, which is hidden from AT. To keep it that way, add to `DESIGN.md` 1045: "The row's fade is its ground, its dashed edge and the avatar's opacity only; no opacity or filter on the row, its text, its bookmarks or 'ENVOYER'."
- **N2. The row name is long.** With four cards in several goals each, and a mutual side, it passes 250 characters, read again at every Tab. That is acceptable and the author's choice. An alternative is a short name, "Suggestion de Hugo_B : 2 cartes contre 1", with the full list as `aria-describedby`.
- **N3. "PROPOSITION TRANSMISE" names nobody.** The row has gone and the focus has moved (S1), so a screen-reader user gets no confirmation of who received the trade. Consider a visually hidden "à Hugo_B" in the toast, keeping the visible toast "alone" as ruled.
- **N4. Recomputing suggestions.** The open questions (742) leave open when suggestions are worked out again. Whatever the answer, a recomputation must never remove the focused row under the player; it waits, or moves the focus as S1 says.
- **N5. The active back is not marked by colour alone.** It has the lime frame, the "ACTIF" plate (`{colors.on-lime}` on `{colors.lime}` 9.9:1, 10px bold, at the floor), the strip chip and "actif" in its name. Spell out the stacking so the focus ring never merges with the lime: outline 2px, lime frame 3px, then the ring's 3px `{colors.outline}` gap and 3px ring outside it, the "ACTIF" plate uncovered. White against lime is only 1.8:1, so the gap is what separates them.
- **N6. Back button semantics.** State in the name ("Aurore, actif.", "Centurion. … Équiper.") is workable. When equipping renames the focused button, VoiceOver may also read the new name on top of the status message. Rule: no `aria-live` on the mosaic or the strip; the status region is the only announcement. Note that the Menu theme picker (325) is "the same grid as the back picker" but a radio group. Pick one model; if radios, arrow keys must move without equipping, since every choice is a server write.
- **N7. Tab stops.** 55 backs plus season buttons make about 60 Tab stops before the end of the page. The h3 group headings allow skipping. Consider a roving tabindex per group: arrows move, Enter/Space equips, arrows never equip.
- **N8. Counts read as "slash".** "2 / 3" inside the h3s and "14 / 55 débloqués" in the header read as "2 barre oblique 3". Give them visually hidden text, "2 sur 3" / "2 of 3".
- **N9. The scope tag looks like a control.** "VISIBLE PAR TOUS" / "VOUS SEUL" is a 24px plate with `{components.control-border.css}`, the frame of interactive boundaries, so it invites a click. A `{colors.line}` frame, or no frame, would keep the control look for controls.
- **N10. On the phone, learning an earned back's story equips it.** A sighted touch user cannot read how an earned back was earned without equipping it. This is reversible and not a WCAG failure. Make sure equipping happens on `click` (pointer up), never on `pointerdown`/`touchstart`, so a scroll that starts on a back cancels (2.5.2).
- **N11. Hover against focus in the strip.** When the pointer rests on one back and the keyboard focus is on another, the spines don't say which one the strip names. Suggested rule: the latest of hover and focus wins; leaving hover returns the strip to the focused back, else the active one.
- **N12. Reduced motion.** "Nothing translates" already stops the 3px hover lift (504), but say so on that row. The exception at 521, "Locked card back: no shake; the condition appears inline", is stale: there is no shake any more and the condition is in the strip. Reword or drop it.
- **N13. The new backs.** The art is decorative inside a named button, which is fine, and the unaccented pixel words are art, not text. Their frames read only 2.2 to 2.8:1 on the panel (sage, moss, copper, taupe), and Trèfle fané is washed out by design, so on the small mosaic the padlock alone separates locked from earned. The padlock must reach 3:1 over the darkened art of every back, the dark fields of Assidu and Trèfle fané included.
- **N14. Goal bookmarks on trade boards** (`DESIGN.md` 1039, `EXPERIENCE.md` Goal bookmark): covered by the existing rule that a card's accessible name ends with its goals. Confirm that it applies to the friend's side of the board too, where the viewer's goals are the point.
- **N15. Mock divergences builders should not copy:** the mock's blue `:has()` outline around a focused row (the spine asks for the focus ring); the at-rest strip not hidden from AT; the white ring on a tapped back; `href="#"` openers.
