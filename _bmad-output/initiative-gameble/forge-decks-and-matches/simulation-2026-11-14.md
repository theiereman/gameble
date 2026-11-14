# Duel simulation — reworked live rules

Simulated 2026-11-14 against `spec-gameble/duel-rules.md` (live duel: both decks open, hands of 3 hidden, ten alternating calls, the caller's card shown and the call hidden, one hand for calling and answering). The model reuses the approach of `../ux-gameble/review-duels-abuse-2026-11-14.md`. Scripts: `/tmp/claude-1000/-home-teyermann-projets-gameble/6da6cf13-58ae-4d00-8c2d-cd6904b85acd/scratchpad/sim/` (not kept in the repo).

## Verdict

The rework fixes what made the old duel solved: decisions now matter, and they matter a lot. A player who reads the shown card and the open decks beats the automatic play 88 % of the time. Each step up the skill ladder beats the one below it by 60 to 93 %, and the equilibrium caller calls its card's trump only half the time, so there is real bluffing. Collection size matters far less than before: a 150-card newcomer at equal skill wins 39 to 48 %, against 26 % under the old rules. But two things do not hold as written. **First, the points are still solved between competent players.** With ten stat-directions against three hidden answer cards, a competent caller finds a call no answer beats in 94 to 100 % of rounds. So 73 % of skilled duels end 5–5 and go to the percentile margin, which the scoreline does not show. The real game is the margin, and nobody sees it. **Second, deck building has a dominant archetype.** A deck that covers all ten stat-directions beats every other recipe tried, 83 to 99 % of the time. The trump sort the editor offers is a trap, and single-stat decks lose 75 to 83 % of the time. Three small rule changes fix most of this:
- each player calls each of the five stats once;
- the first caller also calls the last round;
- ties are broken on exact values.

With them, 5–5 falls to about 30 %, the late rounds become real reads, skill still pays 72 to 74 % against automatic play, and the first-caller gap shrinks to 48.5/51.5. Newcomers pay for it: at equal skill they drop from 48 % to 36 %. The coverage archetype stays dominant either way, so the editor should teach coverage rather than sort by trump. Build after these changes; no further prototype is needed for the rules, but the margin needs a place on the duel screen.

## Results

Win rates are for the first-named side. Lines have 800 to 2,000 duels each: ±1.2 to 1.8 points (one standard error); deck tournaments ±2.9. "Skilled" is the margin-aware equilibrium player (see Model). Decks are each side's own 12 by trump unless named.

| Measure | Old rules, automatic (this model) | Reworked, as written | + each stat once | + once, exact ties, last two cards face down* |
|---|---|---|---|---|
| Rounds won by the caller, skilled vs skilled | ~95 % | 94–100 % (rounds 1–10) | 95 % early → 72–75 % in rounds 9–10 | 95 % early → 70–76 % in rounds 9–10 |
| Duels with equal scores (decided on margin), skilled | 37 % | **73 %** | 32 % | 33 % |
| Duels ending 5–5, skilled | 33 % | **73 %** | 27 % | 31 % |
| Draws | 0.03 % | 0 % (0 of 1,600) | 0 % | 0.06 % |
| First caller's win rate, skilled mirror | — | **43–45 %** | 47 % | 45 % (the call-order fix alone gives 48.5 %, finding 3) |
| Skilled vs automatic play | 62/38 (scouting ceiling, previous review) | **88.5 %** | 74 % | 72 % |
| Reader vs automatic play | — | 93 % | 82 % | — |
| Anticipating caller vs reader | — | 71 % | 78.5 % | 65.5 % |
| Skilled vs reader | — | 61 % | 55 % | 54 % |
| Knowing the opponent's hand vs not (cheat ceiling) | — | 83 % | 79 % | 81 % |
| Skilled reading the open decks vs ignoring them | — | 72 % | — | 61 % |
| Skilled tracking struck cards vs not | — | 61 % | — | — |
| Newcomer vs established, both automatic | 26 % | 9.5 % | 17 % | 18 % |
| Newcomer vs established, both skilled, trump decks | 26 % | **48 %** | 39 % | 36 % |
| Newcomer vs established, both skilled, both coverage decks | — | **39 %** | — | 34 % |
| Newcomer skilled vs established automatic | — | 82 % | 58 % | — |
| Established vs veteran (~4,000 cards), both skilled | — | 39 % | 39 % | — |
| Best deck archetype, skilled play (mean vs field) | trump sort | **coverage 90.5 %** (min 83 %) | coverage 85 % | coverage 82 % (min 69 %) |
| Best deck archetype, automatic play | trump sort | trump sort 88 % | — | — |
| Null rounds per duel, skilled | — | 0.21 | 0.67 | 0.39 (0.14 with exact ties alone) |

\* The combined run used "two cards set aside face down" for the last round instead of the call-order fix, which was measured on its own afterwards (finding 3); the face-down rule changes nothing else measurably.

Old-rule figures from the previous review's model, for reference: 52/48 between established decks, 48 % 5–5, 56 % on margin, newcomer 33 %.

Deck tournament, skilled play, reworked rules as written (mean win rate against the eight other recipes): coverage 90.5 %, random 12 owned cards 62.7 %, trump sort 59.6 %, best-two-stats 57.2 %, sum of extremeness 54.8 %, best-three-stats 46.1 %, two-stat split 43.7 %, single stat 17–18 %.

## Findings and smallest fixes

### 1. [critical] The points are solved; the margin decides three duels in four

**What happens.** A caller holds three cards, each with ten stat-directions. The answerer's three cards are hidden, but they are a random three of the answerer's open deck. The caller picks the call on which every likely answer is weakest. Against established decks, whose cards all sit at 99.6 or beyond in some direction, no answer beats that call 95 to 100 % of the time, whatever the answerer guesses. Each player wins their own five calls, so 73 % of skilled duels end 5–5, and the total percentile margin decides them. The answerer's choice still matters, but only for the margin: it plays the card that loses by least. That is why margin-aware play beats margin-blind play 79 % of the time. The points the players see are a formality, and the hidden tie-break is the game.

**Smallest fix: each player calls each of the five stats once in a duel, in either direction.** The caller then has to spend its weak stats somewhere. The answerer knows which stats the caller has left, and on the caller's last call it knows the stat. Rounds 9 and 10 become real reads: the answerer wins 15 to 25 % of them, against 0.1 % before. 5–5 falls from 73 % to 27–31 %, and skill still pays (72 to 74 % against automatic play, 65 to 78 % for the anticipating caller over the reader). The cost is that collection depth counts again: a newcomer at equal skill drops from 48 % to 36–39 %. That is still well above the old rules' 26 %.

**Alternative: make the margin the score.** The duel goes to the larger total signed percentile margin, and a round's point is shown only as a mark. This is honest about what decides, and newcomers stay at 47 %. But "I won 6 rounds and lost the duel" will read as a bug, and the margin is a sum of decimals no player can track. Not recommended.

**Either way, show the running margin on the duel screen.** Even with the fix, it settles about a third of duels.

### 2. [high] Coverage is the dominant deck; the trump sort is a beginner trap

The deck that covers all ten stat-directions wins:
- 83–99 % against every other recipe under the rules as written (90.5 % mean);
- 85 % with each stat once;
- 82 % with all three fixes (69 % against its closest rival).

That deck takes the best owned card for each direction in turn, then two spares. With hidden calls and open decks, a caller looks for a direction the answerer's deck cannot cover, so a deck with no gap wins as answerer and finds gaps as caller. Under automatic play the ranking flips: the trump sort wins 88 % and coverage 71 %. So the editor's "sort by trump" builds exactly the deck that skilled players beat. Single-stat decks lose 75–83 % of the time. A random 12 of one's own cards holds even with the trump sort under skilled play (52/48 head to head).

This is not a solved meta in the old sense, because which card covers which direction depends on each collection. But it is one recipe. **Smallest fix (editor, not rules):** show the deck's best value in each of the ten stat-directions as a coverage strip, and flag empty or weak directions. Offer "fill the gaps" rather than "sort by trump". If the author wants single-stat decks to be viable, no small rule change found here does it.

### 3. [high] The second caller wins 55 % because they call the open last round

At equal skill and equal decks, the first caller wins 43–45 % (automatic play 47–49 %, veterans 44 %), with ±1.25 per line. The edge comes from calling last, when the answerer's hand is fully known and the margin can be maximised. Changing only the order of calls, over 1,600 duels each:

| Order of callers | First caller wins |
|---|---|
| A B A B A B A B A B (as written) | 43.2 % |
| A B A B A B A B **B A** | 48.5 % |
| A B B A B A A B B A (Thue–Morse) | 51.9 % |

Setting two cards aside face down, so that the last round is not open, barely helps (46.8 %).

**Smallest fix:** "The first caller is drawn at random; calls alternate, except that the first caller also calls the last round, after the other player calls round 9." Each player still makes five calls.

### 4. [medium] Ties on rating and circulation void rounds

Whole-number Steam ratings give about 80 distinct values, and holder counts give 13 to 18 per tier. Under the spec, two cards with equal percentile and equal exact value score nothing:
- "worst rated" voids 6.7 % of its rounds;
- "most widespread" voids 9.6 %.

There is also a skew. Circulation is ranked within the tier over the whole catalog, and most Rare, Epic and Legendary cards are held by nobody. So any owned high-tier card ranks near the top on "most widespread": a 150-card newcomer's best "most widespread" card is at 99.9.

**Smallest fix**, as the previous review proposed:
- rating's exact value is positive reviews over total reviews;
- circulation is ranked within the tier over cards held by at least one player.

Null rounds fall from 0.21 to 0.14 per duel, and the two directions' void rates to 0.5 % and 6 %. The fix changes no other result above by more than noise.

### 5. [medium] Hidden information is the whole skill, so it must stay server-side

A player who knows the opponent's hand beats an equal player 79–87 % of the time. Reading the open deck is worth 61–72 % over ignoring it, and tracking struck-out cards 61 %. All of the decision value sits in what is hidden. **Fix:** a requirement for the architecture, not the rules. The opponent's hand, the locked call and both deck orders never reach the other client before the reveal; the client receives only the shown card, then the reveal.

### 6. [low] Discovery's "ranks last" is ambiguous

A card nobody has pulled "ranks last on discovery", which does not say at which end. Either way, owned cards never reach the undiscovered block. In the model, the best owned "discovered last" card sits near 95 while other directions reach 99.9, so the direction is weaker but still used (11 % of skilled calls). **Fix:** "Discovery ranks over the season's discovered cards."

### Checked and not broken

- **No stat or direction always wins.** Under skilled play every direction's call wins 89–99 % of the time, so the caller, not the direction, wins. "Most popular" is called most (12–18 %), and "hardest to find" and "discovered last" least under the trump sort.
- **The hidden call cannot be exploited.** The equilibrium caller calls the shown card's trump in 49 % of rounds, its second-best stat in 19 %, and something else in 32 %, so nothing in the shown card gives the call away. The reader's model of "the trump, mostly" beats automatic play 75–93 % of the time but loses to the anticipating caller 29–35 % of the time.
- **The open last round is not trivial on its own.** Every round is already a near-certain caller win under the rules as written. The open round's effect is the first-caller gap (finding 3). With each stat once, the last call's stat is forced and public, and that round becomes the most contested of the duel.
- **Draws are almost impossible**, as the previous review found: 1 in 1,600 or fewer. Keep the column.
- **Automatic play is weak.** It loses 88 % of the time to a skilled player. A disconnect costs the duel, which is fine because no stake or capsule depends on an automatic move.

## The model and its limits

- **Catalog:** 12,434 cards. Review counts are mapped to the published tier floors (Rare about 9,300, Epic about 35,000, Legendary about 171,000), and rarity is cut at 60/85/95/99 %. Rating is a whole-number percent loosely correlated with popularity (r ≈ 0.3), with 80 distinct values. Release dates are continuous and skewed recent.
- **Population and collections:** four worlds, each with 36 players (6 newcomers with 150 pulls, 6 casual, 16 established with 850–1,500 pulls, 8 veterans with 3,000–6,000), pulling at the drop odds over time. Discovery is the first pull time, and circulation is holders ranked within the tier, giving 15 distinct values among Commons. Percentiles are midranks to one decimal. Established collections hold about 1,100 distinct cards, veterans about 3,800, newcomers about 149. Trading, the market and duplicates bought on purpose are not modelled.
- **Strategies, in order of skill:**
  - **random**;
  - **automatic play:** the spec's timeout rule;
  - **reader:** predicts the call as a softmax over the shown card's extremeness, answers with the best expected card minus a cost for spending a strong future caller, and calls the best win chance against the opponent's remaining deck;
  - **anticipating caller:** the reader's answers, plus a caller that best-responds to a reader over every possible hand of the opponent;
  - **skilled (equilibrium):** each round is solved as a zero-sum game by fictitious play, over every possible three-card hand the opponent may hold among its remaining cards. The caller mixes over calls, picks the card with the best equilibrium value, and answers best-respond to the equilibrium call mix with its real hand.

  The reader, the anticipating caller and the skilled player value the margin as well as the round (payoff = point + percentile difference / 100), which beats margin-blind play 79 % of the time.
- **Simplifications:**
  - play is myopic per round, with a fixed keep-cost heuristic (0.6 × a card's win chance as a future caller, tuned; results barely move between 0 and 1);
  - no inference about which cards the opponent kept from what they played;
  - no psychology, timing tells or timer pressure;
  - the margin weight is fixed and does not react to the running score.

  A stronger search could find more skill. It is unlikely to change the round-level result, because the caller's edge comes from the structure (ten directions against three hidden cards), not from weak answering.
- **Decks:** nine fixed recipes, with no search for an optimal deck. "Coverage dominates" holds against these recipes; a cleverer deck might counter a specific coverage deck, but none here did.
- **Not modelled:** later catalog seasons, decks built from cross-season editions, and Monday stat changes.
