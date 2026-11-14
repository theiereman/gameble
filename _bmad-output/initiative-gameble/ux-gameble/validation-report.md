# Validation Report — gameble 1.4 duels

- **DESIGN.md:** `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md`
- **EXPERIENCE.md:** `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md`
- **Run at:** 2026-11-14
- **Scope:** the release 1.4 additions (decks, weekly card stats, the Top Trump duel, the duel capsule, MARCHÉ merged into ÉCHANGES) from commits `1c796569` (spec) and `3f6e8b09` (UX)

## Overall verdict

The rubric walker finds the additions lean, their tokens all resolved, and Flow 11 a believable first duel, so the pair is a sound sketch of the Duels screen and the friend duel. It is not yet buildable. No source says which deck the challenged friend plays. The spec's "one sitting" and the UX's "resume within 48 hours" disagree. Whether a deck slot is a card, a card-season or an edition is undecided. The release-day state, when decks open but no stats exist, is missing. Several screens (the duel half, the result, the merged Échanges sub-tabs) have rules on one side of the pair only.

The other three reviewers agree that the safety rules hold: nothing moves between players, every value freezes at the start, no duel is won by forfeit, a capsule comes only from the first win of the day, and friend duels are unranked. They change the picture in three ways. First, the abuse review shows that the duel's call is solved: against an unseen card the best call is always the hand's most extreme stat in its extreme direction, which is exactly the automatic play. Established decks win about 95 % of their own calls, and about half of their duels end 5–5 and are settled by the defender's random card, so the ranking cannot measure skill as CAP-43 intends; either the defender answers the call (to prototype) or the ranking becomes a prestige ladder. Second, an automatically played winning half pays the daily capsule, so an idle alt with a defence deck farms capsules into an uncapped reserve without logging in; throwing, friend-duel rings, forced meetings in a small pool and frozen ratings follow from the same rules. Third, coherence and abuse join the rubric on rules a builder hits on day one that no source settles: which deck a challenged friend plays, one sitting against a resumable half, which edition a deck slot is, release-day stats, private players against CAP-8, deck blocks in the reserved count (which would break `Game::ReservedCopies` as built), and export and deletion. Accessibility adds the duel half's missing interaction model: focus destinations, semantics for the stat choice, a guard on the irreversible call, and an outcome that the focus move would silence.

Across the four reviewers, 129 findings merge into 95: **3 critical, 19 high, 39 medium, 34 low**. A finding raised by several reviewers names all of them and keeps the highest severity given.

| Reviewer | Critical | High | Medium | Low |
|---|---|---|---|---|
| Rubric | 1 | 7 | 26 | 18 |
| Accessibility | 0 | 4 | 12 | 10 |
| Coherence | 0 | 5 | 11 | 11 |
| Abuse | 2 | 5 | 9 | 8 |
| **Merged** | **3** | **19** | **39** | **34** |

## Category verdicts

- Flow coverage — thin. Flow 11 has a named pair, numbered steps, a climax and a two-branch failure path. It covers CAP-40 (deck, defence deck, blocked copy), CAP-41 (a friend duel, automatic half) and CAP-42 (the capsule). CAP-39 appears only as a sort in step 1, the open challenge is absent, and CAP-43 has no beat at all.
- Token completeness — adequate. Every new reference resolves to a frontmatter token with a hex (`colors.capsule-duel` #d8e3ec and thirteen others). The gaps are a broken typography rule, a misnamed role, a missing emblem spec, and no stated contrast for the new combinations; the accessibility and coherence reviewers raised the same steel, emblem, track and slot issues.
- Component coverage — thin. DESIGN names six parts, EXPERIENCE eleven, and only two names appear in both. The behavioural rules that exist are real (save on change, first empty slot, 5-point arrows, focus to "SUIVANTE"). The gaps sit on the most complex surfaces: the Échanges sub-tabs, the duel half and the duel result.
- State coverage — thin. Eight new State Patterns rows cover duels not open yet, no deck, draft, no defence deck, no open opponent, an opponent who stays away, anonymised opponents and blocked copies. Missing: release day without stats, visitors, the defence deck's lifecycle, the half's failures, Lancer un duel's edge cases and the ranking after a reset.
- Visual reference coverage — adequate. The duel, deck editor and result screens are flagged as unmocked in three places, and the desktop Duels layout is flagged too. Several other new surfaces are unmocked and unflagged, and the one mock lives outside the repository.
- Bloat & overspecification — strong. The additions are compact: one table of eleven rows, six DESIGN bullets, eight state rows. Nothing restates `duel-rules.md` beyond what a screen needs. Three spots drift toward prose that will not age well.
- Inheritance discipline — thin. Most player-facing names follow the spec ("capsule de duel", "défi ouvert", "deck de défense", "atout"; the five stats and their directions match `duel-rules.md`). The breaks are in rules, not words, and three of them change what gets built.
- Shape fit — adequate. Both spines take the additions in their usual places (IA rows, a component table, State Patterns rows, an Accessibility bullet, a Key Flow, an Open question). A few parts landed where a reader will not look for them, and the Focus after each step table has no duel rows, which accessibility rates high.

## Findings by severity

### Critical (3)

**[Flow coverage · Rubric (critical), Coherence (high)]** — Which deck a challenged friend plays is never stated (§ `duel-rules.md`:30, :38; CAP-41; EXPERIENCE.md:382 (Lancer un duel); Flow 11 step 2)  
Flow 11 challenges Hugo, but neither CAP-41, `duel-rules.md` ("A friend duel: the player picks a friend and a deck, and plays their half at once") nor the Lancer un duel row says which deck Hugo's cards come from. The defence deck governs only open challenges, and both decks freeze at the duel's start, before Hugo does anything, so the rule has to exist before a friend duel can be built. Lancer un duel greys out only a friend already in a duel with the player: a friend with no complete deck is not covered, and nothing says a player calls and defends with the same deck.  
Fix: Settle it in `duel-rules.md` and CAP-41 (for example: the friend's defence deck, else their most recently edited complete deck, else the friend is greyed "Pas de deck complet" with a reason line), and add "a player calls and defends with the deck frozen at the start". Then add it to the Lancer un duel row, to State Patterns and as a clause in Flow 11.

**[Abuse]** — The call is solved: automatic play is optimal play, and established duels are coin flips (§ `duel-rules.md` (calls, automatic half); CAP-41; CAP-43)  
A call's chance of winning against an unknown card equals the card's extremeness in that stat, so the best call is always the hand's most extreme stat in its extreme direction, which is exactly the automatic play; playing the hand's best card each time is also optimal. A 2,000-card collection has 12 cards at 99.9–100 with no effort, because the editor sorts by trump, so established decks win about 95 % of their own calls. Simulated: two established decks played automatically 52/48, with 48 % of duels ending 5–5 and 56 % going to the margin tie-break, which depends on the defender's random draw; a 150-card newcomer against an established deck 33/67; a caller who knows exactly which cards remain in the defender's deck 62/38, the whole skill ceiling, coming from scouting, not from decisions in the duel. CAP-43's intent, "players compare their skill", cannot be met; the rating ranks collection size and luck.  
Fix: The smallest rule that creates decisions: "the defender answers automatically from a hand of 3, with the weakest card that wins the call, else its weakest card". Deck coverage across the 10 stat-directions and knowledge of the opponent then matter (a scouting caller beats automatic play 45/12, 42 % equal), but newcomers fall to 1/81: prototype it before the build. If the author keeps the current rule, rewrite CAP-43's intent as a prestige ladder ("who duels well and often") and accept that it measures luck and collection. Two ideas do not help (simulated): "each stat once per half", and letting the defender's trump set the stat.

**[Abuse]** — Idle alt accounts farm duel capsules without logging in (§ CAP-42; `duel-rules.md`:46; `market-economy.md` (alt signals))  
An automatically played half that wins is still "the first win of the UTC day", and the spec does not exclude it. An alt builds 12 cards, names a defence deck and never returns; with about 90 open challenges a day over about 20 defence decks it receives 4 or 5 a day and wins at least one 95 % of the time. Its capsules pile up in the uncapped special reserve; about 30 a month give 90 cards at bonus odds, about 0.9 Legendary (7M minimum on the market), sent to the main account through free friend trades. None of the market's alt signals sees it until the transfer. One player with three alts gets about 3 Legendaries a month; at 1,000 players it is a scriptable faucet. (Coherence raised the alt farm through thrown friend duels; see the throwing finding.)  
Fix: "The duel capsule is given only for a win in a duel whose half the winner played themselves." Optionally also "and only if the player opened a capsule that UTC day".

### High (19)

**[Token completeness · Rubric]** — The duel rating is set in VT323 at a raw 34px (§ DESIGN.md:1253)  
"The rating in VT323 at 34px" breaks the Typography rule that figures are JetBrains Mono bold and never VT323, and the Accessibility Floor's Readability bullet (EXPERIENCE.md:745). It is also a raw size with no token.  
Fix: `{typography.count-large}` (`{typography.count-large-phone}` on the phone) in `{colors.text-max}`, as for the Chattomètre's index.

**[Component coverage · Rubric (high), Accessibility (medium), Coherence (medium)]** — The Échanges sub-tabs have a look but no behaviour (§ DESIGN.md:701, 785, 926, 1252; EXPERIENCE.md:37–38, 87)  
No EXPERIENCE row says which sub-tab ÉCHANGES and menu 03 open on (the last used? the one with a badge? AMIS?), whether each sub-tab keeps its own address (the market's address and its teaser rule depend on it), what their semantics are, or how the per-sub-tab badges are named. DESIGN contradicts itself: it draws them "over the Tabs and filters rules", whose parts are `aria-pressed` buttons with an accent fill, yet asks for "the active part on `{colors.panel-raised}` with an accent underline". Accessibility: MARCHÉ is its own address, so the parts are links a user follows, not filter toggles. Coherence: the Échanges top-bar subtitle "Entre amis · une proposition expire après 7 jours" is wrong on the MARCHÉ sub-tab, and the two-column Échanges layout does not place the control.  
Fix: Add a "Sub-tabs" row to EXPERIENCE's Échanges table that settles the default, the URLs, the role (a `<nav>` named "Échanges" holding two links, the current one `aria-current="page"`, Tab between them, not arrow keys), the badge names and the keyboard order, and make DESIGN say which rule wins. Make the subtitle depend on the sub-tab and lay the control out above both columns.

**[Component coverage · Rubric]** — The duel half and the duel result have behaviour but almost no visual spec (§ DESIGN.md:1257)  
DESIGN gives only "Round outcome": no card size for the hand of three, no layout for the five-stat choice and the two direction buttons, no score or "MANCHE n / 5" styling, no phone stacking, and nothing for the ten-round result list. Both are flagged unmocked, but the rules side is empty too.  
Fix: Add DESIGN bullets for the Duel and the Duel result (card sizes from the Card sizes table, the stat list as a Radio list or button group, the score in `{typography.number}`), or mark both screens as blocked until mocked.

**[State coverage · Rubric (high), Coherence (medium), Abuse (medium)]** — Release day and newly added cards have no stats (§ `duel-rules.md`:12, :53 (Stats, Launch); spec-gameble.md:356; EXPERIENCE.md:384, 385, 638)  
Decks open at the release, but stats arrive on the first Monday. Meanwhile the Deck editor "sorts by any stat … filtered by trump", the card detail's DUEL block and the change arrows have no values, the Duel profile has no "no values yet" state, and "Duels not open yet" only disables duels. The same hole opens for a card added mid-week by a new season or discovered after Monday 00:00, which can still enter a deck at once. Discovery is ranked "over the season's catalog", which includes cards nobody has pulled and so have no first-pull date, and two weeks into a season it swings over a few hundred cards. Coherence: the author never decided the launch timing; the spec memlog derived it. (Abuse raised the release-day editor separately, at low.)  
Fix: Run the first stat computation at deploy and open duels the following Monday, or add a "Stats not computed yet" row (the profile shows "Valeurs le lundi <date>", sort and trump filter hidden, cards listed by title). A card with no value yet cannot enter a deck; the editor says "Stats lundi". Rank Discovery over the season's discovered cards at computation, in `duel-rules.md`. Put the launch timing to the author in `pending-approvals.md`.

**[State coverage · Rubric (high), Coherence (medium)]** — Visitor rules contradict each other (§ EXPERIENCE.md:64, 91, 385, 559; CAP-18)  
The IA says Classement des duels is "open without an account", but the Signed-out paragraph and the Signed out state list every surface a visitor can open, the ranking is not among them, and no landing link leads there; CAP-18 lists neither it nor the Chattomètre (an older gap). Marché, which visitors may read "from the landing only", is now a sub-tab of Échanges, which they cannot open; what a visitor sees at the market's address is unsaid. Whether a visitor's card detail and the public card page show the DUEL block is also unsaid.  
Fix: Add Classement des duels (and Le Chattomètre) and an entry point to both visitor lists and to CAP-18, or drop "open without an account". A visitor's Marché shows no segmented control (or a greyed AMIS). Say "visitors included; not on the public card page" (or the opposite) for the DUEL block.

**[Inheritance discipline · Rubric (high), Accessibility (medium), Coherence (high), Abuse (low)]** — "One sitting" contradicts a resumable half, and the challenger has no deadline (§ CAP-41; `duel-rules.md`:29, :40; forge:11; EXPERIENCE.md:386)  
CAP-41 and `duel-rules.md` say each half is played "in one sitting" and the challenger "plays their half at once"; EXPERIENCE says "Leaving keeps the half where it stands; coming back within the 48 hours resumes at the same round". The only deadline is the opponent's: a challenger who leaves mid-half holds a pair slot and one of the 10 forever. Nothing says when the opponent's 48 h start or when they are notified. Accessibility: resuming is the accessible rule (a pause, a change of assistive technology, an interruption), a build following "one sitting" could add a session timeout, and the 48 h window is beyond WCAG 2.2.1's 20-hour exception.  
Fix: The author picks one rule; accessibility argues for resuming ("a player makes 5 calls, and may leave and resume"). Give the challenger the same 48 h with automatic completion, start the opponent's clock and bell line when the challenger's half ends, state in the Floor "no timer within a half; the only limit is the 48 h window, and the duel screen shows the end time", warn once by bell at 6 h left, and align CAP-41, `duel-rules.md` and EXPERIENCE.md.

**[Inheritance discipline · Rubric (high), Coherence (medium), Abuse (medium)]** — What a deck slot is: a card, a card-season or an edition (§ CAP-40; `duel-rules.md`:9, :23; spec-gameble.md:75, 85, 142; EXPERIENCE.md:385, 411)  
CAP-40 says "12 distinct cards", `duel-rules.md` "each card-season at most once" (so the S1 and S2 editions of one game can share a deck). Stats are per card-season and ranked over the season's catalog; copies carry a minted rarity and a season. The Reserved tag blocks "one copy" without saying which; neither the Deck editor nor the Duel profile says which season's stats a game owned in two seasons shows, while the card detail shows one card per game across editions. Abuse adds the unstated cross-season rules: which catalog an older edition ranks in, whether old seasons' living stats are recomputed each Monday, and that an old edition's circulation only falls once its season is no longer pulled, drifting it toward "hardest to find".  
Fix: Define the slot unit in `duel-rules.md` (card-season) and say whether two editions of a game count as two cards; say which copy it blocks (for example the lowest minted rarity of that season); make the editor list one entry per card-season and the DUEL block show the stats of the season being viewed (or of the published season, like "Prix moyen"). Add "each stat ranks a card among its own season's cards; living stats of every season are recomputed each Monday", and one line accepting the drift.

**[Shape fit · Rubric (low), Accessibility (high)]** — The Focus after each step table has no duel, deck or sub-tab row (§ EXPERIENCE.md:728, 752–795)  
The duel half replaces parts of the screen five times (stats appear, directions appear, the opponent's card turns, the hand redraws), the deck editor fills and empties slots, and the half ends on a different screen. Without destinations the build will leave focus on a removed node or on `body`, which the Floor itself forbids (2.4.3, 2.4.11).  
Fix: Add rows: "Duel opened or resumed → the round heading 'MANCHE n / 5'"; "Card chosen → stays on the card (`aria-pressed="true"`), the stats group follows it in the DOM"; "Stat chosen → stays on the stat (`aria-expanded="true"`), the directions group follows it"; "Call sent → the outcome heading"; "SUIVANTE → the card just drawn"; "Fifth call's outcome → 'VOIR LE DUEL' / the waiting panel's heading 'En attente de <name>'"; "Lancer un duel opened → the sheet's title; COMMENCER → the duel's round heading"; "Card added or removed in the deck editor → stays on that collection card"; "Deck full refusal → stays on the card, refusal announced"; "Deck deleted → the 'MES DECKS' heading"; "Sub-tab followed → the screen's h1".

**[Accessibility]** — The irreversible call can be fired by accident (§ EXPERIENCE.md:386, 650)  
"The call is sent at once, with no confirmation." Three routes: a keyboard user presses Enter on a stat and again (or holds it; buttons fire on a repeating keydown) and lands on a direction if focus moves there; on the phone the direction buttons appear right after a tap on a stat, often under the same finger, and a second tap or a ghost click commits; the two directions are adjacent, so a slip picks the losing side. The author's no-confirmation choice can stand, but the house already guards a comparable irreversible tap (Guard). (2.5.2, 3.3.4 in spirit; cognitive and motor users.)  
Fix: State in the Duel row and the Floor: (1) the card and the stat stay choosable until a direction is pressed, so only the direction commits; (2) focus never moves onto a direction button by itself; (3) direction buttons ignore activation for 400ms after they appear, as the reveal Guard; (4) they commit on `click`, never on `pointerdown`/`touchstart`; (5) on the phone they appear below the stat list, never where the stat just tapped was, stacked full width, each at least 44px tall and 16px apart; (6) each direction's name carries the stat and the card's value.

**[Accessibility]** — The outcome announcement races the focus move and says too little (§ EXPERIENCE.md:732)  
Posting to a polite status line and moving focus to "SUIVANTE" in the same tick makes VoiceOver on iOS, and often NVDA, read the button and drop or truncate the queued message, so the round's result, the core of the game, may never be heard. The example message also omits the opponent's card and the score. (4.1.3, 1.3.1.)  
Fix: On the call, render the outcome as a heading inside the round panel ("Manche 2 gagnée") and move focus to it (`tabindex="-1"`); the panel then reads "Votre carte : <game>, <value>. Carte de <name> : <game>, <value>. Sortie, la plus ancienne. Score : 2 – 0." with "SUIVANTE" next in Tab order. Drop the separate status line for this step (the Market rule: no second announcement when focus moves). Post the outcome only once the opponent's card is face up. Write the sentence in both languages in the Copy deck.

**[Accessibility]** — The duel half's controls have no stated semantics beyond the hand (§ EXPERIENCE.md:386, 732)  
"Choosing a card shows its five stats" and "choosing a stat offers its two directions" say nothing of what a stat is to assistive technology or what its name holds. A screen-reader user who hears only "Popularité" cannot play, since the choice depends on the card's values. (1.3.1, 4.1.2, 2.4.6.)  
Fix: The hand is a group named "Votre main" of three toggle buttons (`aria-pressed`), each named "<game>, atout : <stat>"; the stats are a group named "Statistiques de <game>" of five toggle buttons with `aria-expanded`, each named with the stat and its percentile in words ("Sortie : plus ancienne que 97 % des cartes"), the trump adding "atout"; the directions are a group labelled by the stat ("Sortie de <game> : choisissez le sens") of two buttons named by the direction words. State these names in the Copy deck, French and English.

**[Coherence (high), Abuse (low)]** — Private players can duel friends, which contradicts CAP-8 (§ spec-gameble.md:94, :419; `architecture-gameble.md`:183 (AD-14); `duel-rules.md`:42; EXPERIENCE.md:644)  
CAP-8: "a friend sees nothing beyond the friendship: no presence or activity, no collection, no profile, and no trade either way", and `open_to_friends?` gates "trades, presence … nothing else". Yet `duel-rules.md` says "A private player can duel friends", and a duel shows their deck cards, results and bell activity. A private name is "by name with no link" in the market but "Membre discret" in open challenges. Nothing says what going private does to duels in progress or to the defence deck. Abuse adds that a friendship or privacy change mid-duel must not touch a running duel.  
Fix: Amend CAP-8 with an explicit duel exception, or close duels for private players as trades are. Keep one rule for a private name across the market and duels, say what going private does to duels and the defence deck ("a friendship or privacy change does not affect a duel in progress"), and update AD-14's `open_to_friends?` note.

**[Coherence (high), Abuse (medium)]** — Deck blocks are missing from the reserved count, which would break built code (§ forge:31; `plan-collection-reserved-copies.md`:29; `architecture-gameble.md`:194–195; EXPERIENCE.md:411)  
The forge decided "Built on holdings' reserved count; `Game::ReservedCopies` must tell a deck block from a trade", but neither spec nor architecture carries it. The class built in `faa9c88a` derives "copies in a trade = reserved minus on sale", so a deck block would show "1 en échange", and the architecture's reservation releases (going private, deletion) would silently free deck blocks. Abuse adds: can a card whose free copies are all on sale or in a trade enter a deck (the sale would leave the deck holding a card the player no longer owns)? And a deck-blocked copy must not count as the spare copy of the friends' suggestions (CAP-11).  
Fix: Add an architecture decision before the build: a deck-block count kept apart from trade reservations, or a derived split like listings. Update `Game::ReservedCopies` to name "Dans un deck"; make going private release trade reservations only. "A deck takes a free copy; a card with none is shown reserved in the editor. A deck-blocked copy is reserved for every duplicate count."

**[Coherence (high), Abuse (low)]** — Export and deletion do not cover decks, duels or ratings (§ spec-gameble.md:146 (CAP-14), :354, :358; `duel-rules.md`:42; AD-14)  
The export and the constraints list every other kind of personal data, but not decks, duel history, the season rating or past final ranks. Deletion also has to keep a deleted player's frozen deck so that their duels in progress "finish by automatic play", then show them as "anonyme". Abuse: a deleted player's holdings vanish, so automatic play must read a snapshot of both decks and their values taken at the start; the freeze implies one, but nothing says so.  
Fix: Add a "Duels and personal data" constraint: the export includes decks, duel results and ratings; deletion drops decks and the rating once the duels in progress have finished, keeping the frozen duel snapshot and the opponent's results under "anonyme". State "a duel keeps its own copy of both decks and their values". Mirror it in AD-14's deletion handler.

**[Abuse]** — Two colluders can force an open-challenge meeting in a small pool (§ `duel-rules.md`:39, :41)  
"One duel at a time between the same two players" makes the matcher skip opponents the challenger is already dueling. A challenger fills 10 slots against everyone except the partner; when 10 or fewer other players have a defence deck, the next open challenge must land on the partner, who throws, so rating moves on demand. Feasible while the pool stays at about 15 defence decks or fewer.  
Fix: "An open challenge between two friends, or between two players who already met in an open challenge in the last 7 days, does not move the rating." Alts are almost always friends, since they must be to trade.

**[Abuse (high), Coherence (medium)]** — Throwing is free and invisible; friend-duel rings double each alt's capsules (§ CAP-42; forge:35; `duel-rules.md`:46; CAP-35 to CAP-38)  
A player can lose on purpose by calling the wrong direction with any card. Three alts who are friends duel in a ring and throw in turn, so each takes a daily win and a capsule in two minutes, doubling the daily-bonus yield per alt. Coherence: a friend duel counts toward the first win of the day and friend duels are unranked, against CAP-42's own intent "without turning duels into a capsule farm"; the market has alt signals, duels have none.  
Fix: Add to the alt signals (CAP-37) "a half that scores far below its automatic play" and "friend duels repeated between the same pair"; coherence also asks the author whether only open challenges should give the capsule. One keystroke a day cannot be blocked by rule, only seen.

**[Abuse]** — Ratings can be frozen at the top (§ CAP-43; `duel-rules.md`:48)  
No decay and no activity requirement; a player shows after 5 ranked duels, and duels are coin flips. A player who starts 5-0, removes their defence deck and stops challenging keeps first place until the reset, and the season's final rank stays on the profile forever. Very likely among 36 players.  
Fix: "A player appears in the ranking after 20 ranked duels, and only while they have played a ranked duel in the last 14 days; the season's final rank needs the same." Also cut the Elo factor as games accumulate (still unset in Open Questions).

**[Abuse (high), Coherence (medium)]** — The 10-duel cap is undefined for incoming challenges (§ `duel-rules.md`:39, :41; EXPERIENCE.md:642)  
If a received open challenge counts toward the defender's 10, at 1,000 players a defender receives about 10 a day for 48 h each and can never start a duel; if it does not count, the matcher has no bound on a defender; if full defenders are skipped, a few players at their cap can drain a small pool. Coherence: nothing says matching skips defenders at the cap or already facing the challenger, and an inactive defence deck would pile up duels. The "DÉFI OUVERT" state where every defence-deck holder already duels the player is missing (EXPERIENCE only covers "no other player has a defence deck").  
Fix: "The 10 counts duels the player started; a player has at most 10 received open challenges waiting for their half and is skipped by the matcher beyond that; with no eligible opponent, DÉFI OUVERT is disabled with its reason." (Coherence would count every duel toward both caps and draw only among defenders under it.) Update the "No open opponent" state.

**[Abuse]** — A ban does not undo what the banned account fed (§ `duel-rules.md`:42)  
A banned player's duels finish by automatic play and their past results stand, so rating gifted by a banned alt stays with the main account, and so do capsules won against it.  
Fix: "On a ban, the season's ranked duels against the banned player stop counting and the ratings they moved are replayed without them." Capsules already given are kept, as with every reward.

### Medium (39)

**[Flow coverage · Rubric]** — CAP-43's ranked play is walked by no flow (§ EXPERIENCE.md › Key Flows; CAP-43)  
The Elo rating, the 5 ranked duels before appearing, the season reset and the kept final rank have no beat in any flow.  
Fix: Add a Flow 12 for an open challenge: Hugo takes "DÉFI OUVERT", is matched with a "Membre discret", sees "Encore 4 duels classés pour entrer au classement", and later opens Classement des duels.

**[Flow coverage · Rubric]** — No flow shows the open challenge from either side (§ EXPERIENCE.md:381 (Duels screen))  
Neither the challenger matched at random nor the defender who finds a "Défi ouvert" row in "À VOUS DE JOUER" because they named a defence deck is walked.  
Fix: The Flow 12 above, with the defender's view as its variant.

**[Token completeness · Rubric]** — "LANCER UN DUEL" is named a `{colors.lime}` primary button (§ DESIGN.md:1253)  
The primary button fills with `{colors.primary}` (#7aa60a, `components.button-primary`); `{colors.lime}` is for badges, pips and state words. A builder following the token gets the wrong fill.  
Fix: "the screen's one Primary button".

**[Token completeness · Rubric (medium), Accessibility (low), Coherence (low)]** — The crossed-blades emblem has no shade, level or window contrast (§ DESIGN.md:995–997; `mockups/special-capsules/emblems.html`)  
The duel emblem has no shade hex, no level (the sun and cup are 17 × 17 "medium") and no contrast check against the emblem window, the check that ruled out the cup's 11-cell version (4.2:1). The Emblems bullet still says "Both are the medium level", and `emblems.html` holds only the sun and the cup.  
Fix: Add "The blades (B1-L2): body `{colors.capsule-duel}`, shade #…, n:1 on the window", change "Both" to "All three", and add the blades to `emblems.html` or flag them as unmocked.

**[Token completeness · Rubric (medium), Accessibility (low)]** — Steel is too close to colours already in use to mark anything (§ DESIGN.md:622, 996–997, 1254)  
#d8e3ec is ΔE 2.4 from the canister's own cap steel #dfe6ec (1.03:1) and from `rarity-commune-hi`, ΔE 4.3 and 5.3 from `{colors.text-bright}` and `{colors.text}` (1.15:1 against text, 1.30:1 against white), and 1.31:1 from `tier-silver`. The steel label band merges with the steel caps, and the steel "DÉFENSE" tag reads as an ordinary white tag, not as "the only steel mark outside the capsule". The printed names carry the meaning, so nothing fails WCAG.  
Fix: Either pick a steel with a visible hue (ΔE ≥ 10 from the caps and the text tokens, measured the way the Goal colours table measures its nearest reserved colour), or state that the label word and the emblem alone tell the origin apart and drop the claim that steel marks the defence deck. Accessibility adds a 1px `{colors.outline}` rule between the label band and the caps, and "CAPSULE DE DUEL" on every surface that shows the colour.

**[Token completeness · Rubric, Accessibility]** — The duel profile's bar has an invisible track and no stated strong end (§ DESIGN.md:613, 1062, 1256; EXPERIENCE.md:385)  
The track is `{colors.panel-sunken}`: 1.06:1 against `{colors.panel}` and 1.00:1 on the card detail's panel-sunken fact rows, so the bar's 100 % end is invisible exactly where the block lives. The Thin progress bar primitive gives tracks a `{colors.line-deep}` edge. Accessibility adds that a trump can be extreme low (3 % popularity, "la plus confidentielle"), where a short bar marks a strong card, and nothing says which end is strong.  
Fix: Give the track a 1px `{colors.line-deep}` edge (3.20:1 on panel, 3.38:1 on panel-sunken) or a `{colors.panel-raised}` fill, and state the fill ratios (accent on panel-sunken 9.2:1, text-max 18.5:1). Define for each stat which end is 100 and write the words toward the stronger side ("Plus confidentielle que 97 % des cartes", never "Plus populaire que 3 %"). Hide the bar from assistive technology, or make it `role="meter"` with `aria-valuetext` equal to the words.

**[Token completeness · Rubric (medium), Accessibility (low)]** — The empty deck slot's dashed frame is 1.43:1 (§ DESIGN.md:1255)  
"A dashed `{colors.line-soft}` frame on `{colors.panel-sunken}`" reads 1.43:1. If a slot is a target (choose, remove), Colors requires `{colors.line-deep}` (3.38:1) or brighter for interactive boundaries. The "<n> / 12" text carries the count, which is why accessibility rates it low.  
Fix: Dashed `{colors.line-deep}`. If slots are not interactive, say so in the Deck editor row.

**[Token completeness · Rubric]** — The outcome word gives lime a role the Lime bullet does not list (§ DESIGN.md:617, 1257)  
"The outcome word in `{colors.lime}` for a win" is not among lime's listed roles.  
Fix: Add "a won round's word" to the Lime bullet, or set the word in `{colors.text-max}` and let the word carry the outcome.

**[Component coverage · Rubric]** — Five surfaces have behaviour but no DESIGN bullet (§ DESIGN.md › Duels)  
Lancer un duel (a sheet), the Deck list (five rows with twelve thumbnails each), Waiting for the opponent, the Monday stats entry and the profile's duel line.  
Fix: One bullet each. The Lancer un duel sheet can point to Modal, Radio list and the friend chooser rows.

**[Component coverage · Rubric]** — The card detail was not updated on either side (§ EXPERIENCE.md:310; DESIGN.md:1062)  
Neither spine places the DUEL block among the facts or gives its phone and desktop layout. Neither says whether the card detail's "CONFIER" and "METTRE EN VENTE" show "Dans un deck" when the only free copy is blocked.  
Fix: Place the block (for example after ÉDITIONS, before the market rows) in both spines, and extend the Reserved tag's reach to the card detail's actions.

**[Component coverage · Rubric]** — The profile's duel stats exist only inside the ranking row (§ EXPERIENCE.md:390; Moi and Public profile rows; DESIGN Public profile)  
The season's rating and rank, past seasons' final ranks and the "Duels : w victoires…" line are described only in Classement des duels. The Moi and Public profile rows and DESIGN's Public profile are untouched.  
Fix: Add the duel line to Moi / Public profile in both spines, next to the Fortune section.

**[Component coverage · Rubric (medium), Accessibility (low)]** — The Monday stats entry measures nothing defined (§ EXPERIENCE.md:391)  
"Three largest rises and falls" does not say of what: a card has five percentiles, so it could mean its trump, any stat or the sum. There is no rule for the first Monday, which has no previous week. Accessibility: the rises and falls have no stated form.  
Fix: Define the measure (for example "the largest move of any one stat, naming the stat") and add "no entry on the first Monday". Write "en hausse" / "en baisse" with the old and new percentile in the text; any arrow is decorative and uncoloured, as in the deck editor.

**[Component coverage · Rubric (medium), Coherence (low)]** — Comment ça marche explains neither duels nor the duel capsule's odds (§ EXPERIENCE.md:66)  
The duel rests on rules a player cannot guess (percentile and direction, trump, tie on margin, automatic half, Elo, circulation within a tier), and the spec's constraint "the draw odds are published" now covers a third special capsule. A guide is a non-goal, so this page is the only explanation the game has.  
Fix: Add duels, stats and the duel capsule's odds to the Comment ça marche row, and link it from the Duels screen and the Duel profile.

**[State coverage · Rubric, Coherence, Abuse]** — The defence deck has no lifecycle (§ `duel-rules.md`:25; EXPERIENCE.md:384, 411)  
Undecided: how a player unnames it, what happens when "RETIRER DES DECKS" (from a trade or sale screen) or an edit turns it into an 11 / 12 draft, what deleting it does, and the five-deck cap (Ten custom sets has its own state). Abuse: the player then stops receiving open challenges without noticing. The deck name's refusals (empty, over 24 characters, a duplicate) have no rule and no copy.  
Fix: Add a "Defence deck becomes a draft" state (it keeps its tag but receives no open challenge until complete again, or loses the role; the confirmation says so), a "Five decks" state, and editor refusals mirroring Editor refusal.

**[State coverage · Rubric]** — The duel half has no failure states (§ EXPERIENCE.md:386)  
The 48 hours ending while the opponent is mid-half (resume, or automatic play from that round?), a call that fails on the network although "the call is sent at once", the opponent banned while the player is playing, and the wait between a call and the reveal.  
Fix: Add "Half expired while playing" and "Call failed" rows, and a loading treatment for the reveal.

**[State coverage · Rubric]** — Lancer un duel misses three cases (§ EXPERIENCE.md:382)  
No friend at all; a friend with no usable deck (tied to the critical friend-deck finding); an open challenge whose last eligible defender becomes unavailable between the sheet and "COMMENCER".  
Fix: One State Patterns row each, with copy.

**[State coverage · Rubric]** — Classement des duels has no post-reset empty state and no private-viewer line (§ EXPERIENCE.md:390, 1018)  
The Chattomètre has "Votre profil est privé : vous restez hors du classement."; the duel ranking has nothing. Its full-screen layout is inherited from a Chattomètre screen whose layout is itself unmocked.  
Fix: Add both lines to the Copy deck and the State Patterns, and note the dependency.

**[State coverage · Rubric (medium), Accessibility (medium), Coherence (low)]** — States promise lines the Copy deck does not hold (§ EXPERIENCE.md Copy deck (130, 178–179, 198); EXPERIENCE.md:52, 269, 732; spec-gameble.md:136)  
Missing from "the single source for every message": the 10-duel and no-complete-deck reasons under "LANCER UN DUEL", "Duel en cours", the no-defence-deck note, the "DÉFI OUVERT" disabled reason, the "SUPPRIMER LE DECK" and "RETIRER DES DECKS" confirmations, the bell's two duel lines (the Bell row adds "Jouer" and "Voir", the Bell copy has no sentences) and the status line "Manche 2 gagnée : …". Coherence adds the Special capsules copy ("EN OUVERTURE · CAPSULE DE DUEL" / "OPENING · DUEL CAPSULE", label band "DUEL CAPSULE") and the feed's content list, which omits the Monday stats entry.  
Fix: Add them to the Duels and Decks rows; add "<name> vous a défié en duel." / "Votre duel contre <name> est terminé." to the Bell row; extend the Special capsules copy and the feed's content list, in both languages.

**[Visual reference coverage · Rubric (medium), Coherence (low)]** — The only duel mock lives outside the repository, and older mocks lag (§ DESIGN.md › Duels reference; `mockups/mobile.html`; `mockups/native-top-bar.html`)  
"Navigation des Duels" (boards A1, A2) is an external claude.ai artifact; every other reference lives in `mockups/`, where builders, cloud lanes and reviewers can open it at a fixed version. Coherence: the tab-bar reference `mobile.html` and the apps' `native-top-bar.html` predate the DUELS tab.  
Fix: Export boards A1 and A2 to `mockups/duels-navigation.html` and link that file. Note on both older mockups that MARCHÉ is now a sub-tab.

**[Visual reference coverage · Rubric]** — Eight surfaces are unmocked and unflagged (§ EXPERIENCE.md:1017; DESIGN.md › Duels reference)  
The Lancer un duel sheet, the card detail's DUEL block, the Deck list rows, Classement des duels, the Monday stats entry, the Reserved tag's "Dans un deck" with "RETIRER DES DECKS", the duel canister and its emblem, and the profile's duel line.  
Fix: List them in the Duels open question and in DESIGN's Duels reference line.

**[Inheritance discipline · Rubric, Accessibility]** — Rounds show raw values though they are decided on percentiles (§ DESIGN.md:1257; EXPERIENCE.md:386, 388; Flow 11; `duel-rules.md` › Stats)  
The round shows "1998 contre 2014", but rounds are decided on percentiles within the season's catalog, and Circulation within the rarity tier. A Commune held 500 times can beat a Légendaire held 3 times on "LA PLUS INTROUVABLE"; a player who hears "50 contre 10, perdue" cannot understand the rule. Equal percentiles fall back to exact values, which nothing shows either.  
Fix: Show and announce each card's value with its percentile in words ("50 exemplaires, plus répandue que 40 % des Communes"), the raw value secondary, in the round, the result list and the status line. When the exact value broke a tie, the outcome says "départagée à la valeur exacte".

**[Inheritance discipline · Rubric, Coherence]** — The duel ranking inherits a "Membre discret" rule the Chattomètre does not have (§ EXPERIENCE.md:177, 345, 390; `duel-rules.md`:49; CAP-43)  
`duel-rules.md` says a friends-only player is "Membre discret" to non-friends, which matches the Copy deck and the built `fortune_registers/_row.html.erb`, but the Chattomètre's Rows rule says such a player shows "name, avatar and figures with no link (author, 2026-11-09)". Coherence: CAP-43 is the spec's only mention of the Flukeometer; no capability defines it.  
Fix: The author settles friends-only rows once for both rankings (correct the Rows rule to match the build, or the reverse), and the visibility rule is written into CAP-43 or `duel-rules.md` instead of a pointer.

**[Inheritance discipline · Rubric, Accessibility, Coherence]** — "AMIS" now names three things (§ EXPERIENCE.md:47, 49, 428, 822)  
The Échanges sub-tab (which holds trades, not friends), the Amis screen in the player menu (the friends list, where the bell's "Voir" leads) and the feed's AMIS tab; the apps' back example "◀ AMIS" now reads two ways.  
Fix: Rename the sub-tab after its content ("ENTRE AMIS", "ÉCHANGES ENTRE AMIS" or "PROPOSITIONS"), or keep "AMIS" visibly with the accessible name "Échanges entre amis", or confirm the clash with the author. Add the names to the Copy deck.

**[Inheritance discipline · Rubric, Accessibility]** — In English, "Rating" names both a stat and the duel rating (§ EXPERIENCE.md:178–179)  
The stat "Note" and the Elo "Cote" both become "Rating", and both appear on the ranking, the profile and a duel round read aloud.  
Fix: "Duel rating" (or "Rank points") for the Elo figure; the stat stays "Rating" or becomes "Reviews" / "Review score".

**[Inheritance discipline · Rubric]** — Deck tags on a friend's cards reveal their defence deck (§ EXPERIENCE.md:411; `duel-rules.md`)  
The Reserved tag names the decks that hold a card, and the card picker shows the friend's side too, which reveals the friend's defence deck before an open challenge or a friend duel. `duel-rules.md` only says the owner's own trade, sale and entrust screens name the decks. (The abuse review notes that the round list reveals a defence deck after about two duels anyway.)  
Fix: Deck names and the "Dans un deck" tag for the owner only; on the friend's side, a blocked copy simply counts as unavailable.

**[Accessibility, Coherence]** — No new or summed badge has an accessible name (§ EXPERIENCE.md:187, 271, 816)  
The Count badge row puts the number in the item's name, but the Copy deck has nothing for the DUELS tab and menu 04, for ÉCHANGES and menu 03 now summing trades and auctions, or for the AMIS sub-tab; "Marché, <n> enchères dépassées" was written for a tab that no longer exists. (1.3.1, 4.1.2.) The sub-tabs finding (Component coverage) asks for the sub-tab badge names too.  
Fix: Add to the Copy deck: "Duels, 2 duels à jouer" ("Duels, 2 duels to play"; zero: "Duels"); "Échanges, 1 échange et 2 enchères à traiter" (itemised, each part omitted at zero); "Entre amis, 1 échange en attente"; keep "Marché, 2 enchères dépassées" for the sub-tab. The native apps' tab items carry the same label.

**[Accessibility]** — Disabled controls hide their reason, and greyed text may fail contrast (§ EXPERIENCE.md:382, 638–642)  
"LANCER UN DUEL" and "COMMENCER" are disabled with the reason under them, "DÉFI OUVERT" is disabled, drafts and friends in a duel are "greyed". A native `disabled` button leaves the tab order, so a keyboard or screen-reader user never meets the reason; drafts and friends greyed in `disabled-text` read 2.84:1, under 4.5:1 for "<n> / 12" and "Duel en cours". (4.1.2, 1.4.3.)  
Fix: `aria-disabled="true"` with `aria-describedby` pointing to the visible reason, so the control stays focusable; a greyed draft or friend keeps its name and reason in `muted` (5.98:1) and dims only its thumbnail or avatar; each unavailable option is a radio with `aria-disabled` and its reason in its name ("Vieux briscards, brouillon, 9 sur 12").

**[Accessibility]** — The 12-slot deck editor is hard to operate without a pointer, and silent (§ EXPERIENCE.md:384; DESIGN.md:1255)  
A card can only be taken out by finding it again in the sorted, filtered collection; nothing announces "added", the slot count or "Le deck est complet."; the collection's keyboard model is not named; four rows of `card-xs` fill a 740px phone screen, so a sighted player adding from the collection below cannot see the deck change either (the rubric's mechanical notes make the same measurement); autosave failures have no feedback. (2.1.1, 4.1.3, 3.3.1.)  
Fix: Each filled slot is a button named "Retirer <game> du deck"; collection cards are toggle buttons (`aria-pressed`, "DANS LE DECK") in the card picker's grid model (one tab stop, arrow keys); a polite status region posts "<game> ajoutée, 7 sur 12", "<game> retirée, 6 sur 12", "Le deck est complet." and a save failure; on the phone a sticky line under the top bar shows the deck's name and "<n> / 12"; the name field saves on blur and shows its 1–24 refusal inline.

**[Accessibility]** — The Motion table has no duel rows (§ EXPERIENCE.md:659–706)  
The opponent's card "turns face up" (a rotation) and "SUIVANTE draws the next card"; the reduced-motion rule forbids rotation, but the house spells out every exception, and nothing says whether a Légendaire opponent card plays its reveal sequence (flash, shake). (2.3.3, 2.2.2.)  
Fix: Add "Opponent card | about 300ms | a plain flip, no burst, no flash, no shake, whatever its rarity" and "Card drawn | about 200ms | slides into the hand"; under reduced motion both crossfade in 220ms; the outcome appears and is announced once the card is face up.

**[Accessibility]** — Sizes break reflow and leave targets unsized (§ DESIGN.md:721–728, 1255; EXPERIENCE.md:386)  
"3 × 4 at the smallest card size" does not say which way: four columns of `card-xs` (424px with gaps) overflow a 360px phone, and even three (316px) overflow a 320 CSS px viewport. The hand of three plus the opponent's card has the same problem, and the long direction labels ("LA PLUS CONFIDENTIELLE", "DÉCOUVERTE EN DERNIER") will not sit two abreast at 328px under text spacing. (1.4.10, 2.5.8, 1.4.12.)  
Fix: Write "three columns, four rows"; below 340px the slots and the hand use a thumbnail tile (at least 44 × 66); directions stack full width on the phone; name a size token for the hand and the slots, and keep every slot a 44px target 8px apart.

**[Accessibility]** — Repeated actions are not told apart (§ EXPERIENCE.md:381–383)  
Each row of "À VOUS DE JOUER" has a "JOUER", each recent result opens a result, "DÉFIER EN DUEL" sits on friend rows: a screen-reader user hears "Jouer, Jouer, Jouer". (2.4.6, 2.4.4.)  
Fix: Names in the Copy deck, as for "Relever, <card>": "Jouer contre Hugo, reste 31 heures", "Victoire contre Hugo, 6 à 4", "Défier Léa en duel".

**[Accessibility]** — The change arrows' accessible names are underspecified (§ EXPERIENCE.md:384, 732; DESIGN.md:1256)  
"The previous percentile in its accessible name" gives a number without the stat, the direction or the current value, and "▲" is read as "black up-pointing triangle". Five arrows on a `card-xs` face risk text under the 10px floor. (1.1.1, 1.3.1, 1.4.4.)  
Fix: Hide the glyph from assistive technology; a visually hidden text reads "Popularité en hausse : 62, contre 55 lundi dernier"; the slot's or card's name ends with its changes; the arrows sit in a row under the card, not on its face, at 10px or more.

**[Coherence]** — The architecture is not updated for 1.4 (§ `architecture-gameble.md`:37, :113)  
Flagged only, not deep-reviewed. The `Game` domain's contents list no decks, duels, stats or ratings; "Each pack kind" lacks the duel capsule; no decision covers the weekly stat computation, the frozen duel snapshot, the 48 h automatic-play job, Elo or the open-challenge draw. Yet "the rules of `architecture-gameble.md` bind every build".  
Fix: Run an architecture update for 1.4 before slicing stories.

**[Abuse]** — Ties are mostly undefined and very frequent on two stats (§ `duel-rules.md` › Stats, ties)  
Rating is Steam's whole-number percent (about 80 values, blocks of 150 or more at 90–98 %); two cards at 97 % share both the percentile and the exact value, so the round scores nothing. Circulation has 13 to 18 values per tier. The spec never says how to rank ties, whether the stored percentile is whole or decimal, or which card and stat automatic play takes when two are equally extreme, so automatic play is not reproducible in tests.  
Fix: "A percentile is the midrank, to one decimal. Rating's exact value is positive reviews over total reviews when stored. Automatic play breaks equal extremeness by the exact value's distance from the median, then by the stat order of the table, then by card number."

**[Abuse]** — Circulation counts copies, so hoarding buys a trump (§ `duel-rules.md` › Stats (Circulation))  
One player who keeps every duplicate of a Common (or buys them at 1,300) pushes it to the top of the tier and gets a "most widespread" trump; the forge rejected player-specific stats because "they reward hoarding". Entrusting the other way pays PiCoins. If unowned cards count at 0, owned cards can never reach "hardest to find".  
Fix: "Circulation is the number of players holding at least one copy, Archives excluded, ranked within the tier over the cards held by at least one player."

**[Abuse (medium), Coherence (low)]** — Season and day boundaries mid-duel are undefined (§ `duel-rules.md`:48; CAP-42; spec Assumptions (UTC day))  
A duel started in season N finishes up to 48 h later in N+1: which season's rating does it move, and when are final ranks written? Coherence adds: which UTC day counts for the first-win capsule when a duel ends by automatic play overnight?  
Fix: "A duel moves the rating of the season it started in; that season's final ranks are written once its last duel has finished." The capsule counts on "the day the duel ends".

**[Abuse]** — Away players are rated on autopilot at no cost (§ CAP-41; CAP-43)  
Automatic play equals the best uninformed play, so being away costs nothing, and at scale most defence halves will be automatic: the ranking becomes a contest between decks running on their own.  
Fix: Folded into the activity rule of the frozen-ratings finding. Optionally, "an automatically played half moves the absent player's rating by half".

**[Abuse]** — The daily duel capsule adds about 21 % to Legendary supply (§ CAP-42; `market-economy.md`)  
Any player with a defence deck nearly always wins a duel a day: about 0.03 Legendary a day on top of 0.11 (standard) and 0.03 (daily bonus), so about 21 % more Legendaries and 10 % more Epics per active player, with about 1,800 Legendaries already waiting at the 7M minimum.  
Fix: Add the duel capsule to the Legendary supply model of `market-economy.md` before release; if it worsens the clog, give it the standard odds of 3 cards.

**[Abuse]** — Newcomers are fed to established decks (§ `duel-rules.md`:39)  
Matching ignores rating; a 150-card collection wins about 33 % against an established deck (much less with 30 cards), so a new player's first open challenges are mostly losses with no capsule, when retention is decided.  
Fix: "The matcher draws among defence decks within 200 rating points when at least 5 qualify, else from all." At 36 players the hub could also suggest friend duels first.

### Low (34)

**[Flow coverage · Rubric]** — CAP-39's visible parts are never walked (§ Flow 11 step 1)  
The card detail's DUEL block with "ATOUT", the editor's week-to-week arrows and the Monday feed entry appear in no flow.  
Fix: In step 1, Léa opens a card's detail, sees "ATOUT · Sortie" and adds it from there; or add a closing beat where Monday's entry names one of her cards.

**[Flow coverage · Rubric]** — The failure path skips the refusals a build most needs to test (§ Flow 11, failure line)  
A draft deck, the 10-duel cap, and a second win the same day that gives no capsule are not walked.  
Fix: Add one clause per refusal to Flow 11's failure line.

**[Flow coverage · Rubric]** — Flow 11 uses a two-key sort the Deck editor does not offer (§ Flow 11 step 1; EXPERIENCE.md:384)  
Step 1 sorts "by Sortie … and by Popularité", while the Deck editor offers one stat sort plus a trump filter.  
Fix: "sorts by Sortie, oldest first, then filters on the Popularité trump".

**[Token completeness · Rubric]** — The new load-bearing pairs have no stated contrast (§ DESIGN.md:622; Duels bullets)  
Every older token states its contrast. Computed for the review (and confirmed by accessibility's table): outline on steel 15.3:1, steel on panel 13.4:1, on panel-raised 11.5:1, on steam-bar 13.4:1, lime outcome on panel 9.7:1, the draft's muted text on panel 6.0:1. All pass.  
Fix: Write them into the capsule origins paragraph and the Duels bullets.

**[Token completeness · Rubric]** — Raw values and a deviating kicker (§ DESIGN.md › Duels; DESIGN.md:757–767)  
"8px bar", "44px rows", and a group kicker in "`{typography.label}` muted" where the Kicker primitive is accent `{typography.kicker}`.  
Fix: Use the tokens (`{spacing.touch-min}` for the rows), and name the muted kicker as a deliberate variant or use the primitive.

**[State coverage · Rubric]** — Older rows undercount the special capsules (§ EXPERIENCE.md:562–563)  
"Reserve full" and "Special capsule in the reserve" still list only the daily capsule and the mission reward.  
Fix: Add the duel capsule.

**[Visual reference coverage · Rubric]** — The missing mocks' status is inconsistent (§ EXPERIENCE.md:377, 1015–1017)  
The Duels section says "mock them before the build", while Open questions files them under "Non-blockers, left open".  
Fix: Mark the duel, deck editor and result mocks as a build prerequisite, as Le Chattomètre's full screen is.

**[Bloat & overspecification · Rubric, Coherence]** — Phone navigation carries rationale and a growing list of back labels (§ EXPERIENCE.md:87; `brief-gameble/addendum.md`:105; spec-gameble.md:393)  
"The author sees in it room for later social features" is rationale, and the paragraph keeps adding per-screen back labels. Coherence: the UX memlog records the merged tab as "a place for guilds later" while Guilds stays a spec non-goal, and the addendum's "The forge session rejected a battle mode" now needs a 2026-11-14 note.  
Fix: Move the rationale to `.memlog.md` (the guild remark stays there only) and the back labels to a small screen → back label table; annotate the addendum line.

**[Bloat & overspecification · Rubric]** — Two Copy deck cells pack about forty strings (§ EXPERIENCE.md:178–179)  
"Duels" and "Decks and duel stats" hold everything, while the market copy is split by surface.  
Fix: Split them by surface: Duels screen, Lancer un duel, Duel, Duel result, Classement, Deck editor, Stats.

**[Bloat & overspecification · Rubric]** — The capsule origins paragraph is a run-on (§ DESIGN.md:622)  
It now tells three tokens' history in one sentence chain.  
Fix: A small table like Goal colours (origin, token, hex, emblem, shade, text on fill, ratio, nearest colour), which also closes the contrast gaps.

**[Inheritance discipline · Rubric, Coherence]** — The spec's duel UX open question is stale (§ spec-gameble.md:434)  
"Duel UX: where duels live in navigation, the duel capsule's name and colour, and every duel string": the author settled navigation, name and colour on 2026-11-14.  
Fix: Narrow it to "duel copy pending the author's review".

**[Inheritance discipline · Rubric]** — Component names are not shared between the spines (§ DESIGN.md:751)  
DESIGN has "Defence deck", "Deck grid", "Round outcome" and "Échanges sub-tabs"; EXPERIENCE has "Deck list", "Deck editor", "Duel" and "Duel result", although DESIGN says the names are shared.  
Fix: Use the same names on both sides (DESIGN's "Deck grid" becomes the Deck editor's slots, the "Defence deck" tag sits under "Deck list").

**[Inheritance discipline · Rubric]** — Round numbering differs between the half and the result (§ EXPERIENCE.md:386, 388)  
The half counts "MANCHE <n> / 5", while the result lists ten alternating rounds, so the same round carries two numbers.  
Fix: The result labels each round "Manche n / 5 · <caller>", or the half shows the duel's round number.

**[Inheritance discipline · Rubric]** — The Player menu row dates DUELS to the wrong day (§ EXPERIENCE.md:475)  
"The MARCHÉ sub-tab and DUELS included (author, 2026-11-09)", but DUELS dates from 2026-11-14.  
Fix: Fix the date.

**[Shape fit · Rubric]** — DESIGN's Duels section sits outside Screens and holds the sub-tabs (§ DESIGN.md:1248)  
"### Duels" sits with Chattomètre, Player menu and Marché outside "### Screens", whose parts are "####", and holds the Échanges sub-tabs, which belong to the trade screen.  
Fix: Move the sub-tabs bullet to Trade board or to Chrome as a navigation part, and file Duels under Screens when the section is next tidied.

**[Shape fit · Rubric]** — A state and a cross-reference are filed as components (§ EXPERIENCE.md:387, 389)  
"Waiting for the opponent" is a state and "Duel capsule" a cross-reference.  
Fix: Move the waiting state to State Patterns, and fold the duel capsule into the Capsule section's special-capsule rules.

**[Accessibility]** — Slashes, dashes and abbreviations read badly (§ EXPERIENCE.md:178–179, 736)  
"MANCHE 2 / 5", "<n> / 12", "MES DECKS · 3 / 5", "6 – 4" and "reste 31 h" are read as "2 slash 5", "6 tiret 4", "31 h".  
Fix: Visually hidden "2 sur 5" / "2 of 5", "6 à 4" / "6 to 4", "31 heures" / "31 hours" (in a `<time>` element), in the Copy deck.

**[Accessibility]** — Direction labels written in capitals may be spelled out (§ `fr.yml`, `en.yml` (future))  
Some screen readers read a capitalised "LA" letter by letter.  
Fix: Write every new label in sentence case in the locale files and uppercase it with CSS, as the rest of the interface does.

**[Accessibility]** — `aria-current` is unclear for the new roots (§ EXPERIENCE.md:274)  
"DUELS on its own, with `aria-current="true"` there and `"page"` on the hub alone" can be read as forbidding `"page"` on the Duels screen itself.  
Fix: "`aria-current="page"` on a tab whose root is shown, `"true"` on PONT over Fil d'activité and Le Chattomètre, on DUELS over its sub-screens and on ÉCHANGES over the trade board and the Annonce".

**[Accessibility]** — Desktop menu key 4 changes meaning (§ EXPERIENCE.md:85)  
Key 4 opened MARCHÉ and now opens DUELS; the market moves to 3.  
Fix: Nothing in the shortcuts; note the change in the 1.4 release notes and in Comment ça marche.

**[Accessibility]** — The duel result's ten rounds are a list of many fields (§ EXPERIENCE.md:388)  
Each round carries caller, stat, direction, two cards, two values and an outcome.  
Fix: The summary first ("Victoire contre Hugo, 6 à 4, départagée à l'écart de 12 points"), then an ordered list where each round is one sentence, or a table with column headers; explain "Départagé à l'écart" in words the first time.

**[Accessibility]** — Esc on the duel screen is unstated (§ EXPERIENCE.md:656)  
With no overlay, Esc returns to the hub; a keyboard user pressing it to drop a chosen card leaves the half (it resumes, so nothing is lost).  
Fix: On the duel screen, Esc first clears a chosen stat, then a chosen card, and only then follows the general rule.

**[Accessibility]** — Deck list rows show twelve thumbnails (§ EXPERIENCE.md:383)  
Twelve thumbnails per row would each be announced.  
Fix: Hide the thumbnails from assistive technology; the row is one link named "<deck>, deck de défense, 12 cartes" or "<deck>, brouillon, 9 sur 12".

**[Coherence]** — The Monday stats entry has wording slips (§ EXPERIENCE.md:343, 391, 428)  
"Shown in TOUT only", but the feed's tab is "TOUS" (the Chattomètre entry has the same slip); "a Brotherhood feed entry with no card", yet "each card linked to its page".  
Fix: "TOUS", and "with no card image".

**[Coherence]** — Flow 11's score contradicts the rules' own logic (§ EXPERIENCE.md:971, 974)  
Hugo calls Popularité, "LA PLUS POPULAIRE", on his Légendaires and takes three of five rounds against a deck of "old and little-known games"; Légendaires top the review-count percentile, so he should win all five.  
Fix: Give Hugo a stat Léa's deck can contest (Note or Circulation), or let him win five, making it 4 – 6 with Léa winning on margin.

**[Coherence]** — The UX adds behaviour the forge and the author never decided (§ EXPERIENCE.md:382, 384, 390, 391; `later-roadmap.md`:39; `duel-rules.md`:23)  
An arrow when a stat "moved by 5 points or more"; deck names of "1 to 24 characters"; "the three largest rises and falls"; "the defence deck preselected, else the last used"; a "win rate" column in the ranking (the forge rejected ranking by win rate); "a card's duel win rate" as a living stat; "each named" decks.  
Fix: Tag them `[ASSUMPTION]` and list them in `pending-approvals.md`.

**[Coherence]** — The tie-break wording drifted (§ forge:14; `duel-rules.md`:33; EXPERIENCE.md Copy deck)  
Forge: "the larger total percentile margin"; `duel-rules.md`: "… over the rounds won" (a refinement); the copy "Départagé à l'écart : <n> points", where "points" clashes with score points.  
Fix: Confirm "over the rounds won" with the author, and write the margin in "points de centile" or "écart de <n>".

**[Coherence]** — The spec has no duel success signal and no trademark word rule (§ spec-gameble.md:407 onwards; EXPERIENCE.md:180)  
The market got its own success signal; 1.4 has none. "Never 'Top Trumps', a trademark" is missing from the spec's Player-facing words constraint.  
Fix: Add both.

**[Coherence]** — Older contradictions found on the way (not 1.4) (§ spec-gameble.md:180, :389; EXPERIENCE.md:269, 816)  
"Feed events carry no reactions or comments" and its non-goal contradict reactions as built; the non-goal "Native App Store and Play Store apps" contradicts EXPERIENCE's native apps section.  
Fix: Update the spec at the next pass.

**[Abuse]** — Defence decks are public after about two duels (§ EXPERIENCE.md:388)  
The result lists all ten rounds with both cards and the defence deck never changes, so one duel reveals up to 10 of its 12 cards. Knowing the deck is the only skill the current rules have (62/38).  
Fix: None. Keep the round list; it gives the duel its only depth.

**[Abuse]** — What the second half sees, and which shuffle it uses, is ambiguous (§ `duel-rules.md`:30)  
Nothing says whether the waiting player sees the challenger's score before playing, or whether a player's defending cards and calling hand come from one shuffle (which would let the first half reveal the second player's hand).  
Fix: "Each half shuffles both decks anew; the second player sees nothing of the first half until their own half ends."

**[Abuse]** — Weak "piñata" defence decks and strong idle decks gain nothing (§ CAP-41)  
A deliberately weak defence deck loses to everyone (98 % in simulation), spreading its wins over every challenger; a strong deck never played performs as well as a human. Neither is an exploit once the rules above apply.  
Fix: None.

**[Abuse]** — Draws will almost never happen (§ Duel profile; CAP-41)  
With decimal percentiles, simulation found no draws in 4,000 duels; the profile's "draws" count will read 0 for nearly everyone.  
Fix: None; keep the column for consistency.

**[Abuse]** — Stat timing gives no edge (§ `duel-rules.md` › Stats)  
Values freeze at the duel's start and are read from the start week, so starting just before the Monday recompute gains nothing; entrusting to lower circulation needs several players under the holder-count fix.  
Fix: None.

## Reviewer files

- `review-duels-rubric-2026-11-14.md`
- `review-duels-accessibility-2026-11-14.md`
- `review-duels-coherence-2026-11-14.md`
- `review-duels-abuse-2026-11-14.md`
