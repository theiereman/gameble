# Forged idea: decks and the Top Trump duel (release 1.4)

Hardened with the author on 2026-11-14, then reworked the same day after a four-lens review (`../ux-gameble/validation-report.md`): the first design's call was solved (the best call was always the hand's most extreme stat, which the automatic play also made) and idle alts could farm capsules. Source ideas: GitHub #352 (Top Trump Duel). Daily Pixel (#62) and knowledge questions come later and do not shape the deck.

## Scope of 1.4

Decks, the weekly card stats they are built on, and live duels between friends, shipped to test the game. Ranked duels and deferred duels come in later releases (see Later). The spec's "Combat" non-goal and the "no stats on the card face" rule are rewritten (stats show on the card detail, the deck editor and the duel; the face itself is unchanged).

## Duel

- Live, between two friends online. One challenges with a complete deck; the friend has 60 s to accept and pick their deck, or refuses. One duel in progress per player.
- Both decks are locked, then revealed: each player sees both 12-card decks for the whole duel, played cards struck out. Hands stay hidden.
- Ten rounds. The first caller is drawn at random, then calls alternate, the first caller also calling round 10 (A B A B A B A B B A); each player calls each of the five stats once (simulation of 2026-11-14: without these, the caller won nearly every round and 73 % of skilled duels went to the margin). Each player holds a hand of 3 from their shuffled deck that serves both to call and to answer, and draws after each round; over ten rounds each draws their whole deck, so the last round is played with open hands.
- A round: the caller picks a card and a stat with its direction (higher or lower wins) and locks both; the card turns face up with its five values; the answerer, not knowing the call, picks a card from their hand; then all is revealed. Why: the answerer reads the caller's intent and the caller reads the answerer's likely hand, so no move is always best; a card strong on two or three stats is worth more than a one-stat extreme, so deck building is more than one sort.
- One point per round; nothing is captured; decks are untouched by a duel. A tied round compares the exact value, then scores nothing. A tied duel goes to the larger total percentile margin, then is a draw.
- Every stat value is frozen at the duel's start.
- Timers: 60 s to call, 45 s to answer (author, 2026-11-14; 30 s and 20 s were too short to look over the opponent's deck on a phone). On timeout the game plays: the caller's strongest card and call; the answerer's hand card strongest on the shown card's best stat. A disconnected player has 60 s to return, then the game plays each of their remaining moves. No win by forfeit.
- A private player cannot duel, as they cannot trade (CAP-8); their friends see duels closed while the profile is private.

## Stats

- Five, each played both ways: popularity (Steam review count), rating (% positive), release date, discovery (date of the first pull in gameble), circulation (distinct players holding the edition).
- Rarity is not a duel stat: it is the review count cut by percentile, so it would be the same stat twice.
- A deck slot is an edition (game and season); its values rank within its own season's catalog. Circulation ranks within its rarity tier (raw, it is rarity again). It counts holders, not copies, so hoarding duplicates buys nothing. A card nobody has pulled ranks last on discovery.
- Why not only living stats (the author's wish): measured on production on 2026-11-14 (36 players, 29 active in 7 days, 12,434 cards), circulation has 18 distinct values among 7,460 Commons, and sacrifices, reactions, custom-set picks and trades are zero on 76-99% of cards. Discovery is the exception: every deck card was discovered, at a unique second. Remeasure at each new catalog season.
- Values and percentiles are computed at the release's deploy, then every Monday 00:00 UTC. Each card shows its percentile per stat and its trump (most extreme stat).
- Decks evolve with the game (discovery, circulation): the editor shows each card's change since last week; a Monday feed entry tells the biggest moves.

## Decks

- Exactly 12 cards, a game at most once whatever its edition, no rarity or theme constraint; only owned cards. Up to 5 decks; an incomplete deck is a draft and cannot duel.
- A card in any deck blocks one copy of its edition, whatever the number of decks; other copies stay free. To trade, sell or entrust it, the player takes it out of every deck; those screens name the decks. Built on holdings' reserved count; `Game::ReservedCopies` must tell a deck block from a trade or a sale.
- Decks and duel history are in the player's export and deleted with the account; an opponent then reads "anonyme".

## Reward

- The first win of the UTC day gives one duel capsule (3 cards, daily bonus odds, no Common) in the special reserve, only if the game played none of the winner's moves. Nothing for a loss or draw. No stake in PiCoins or cards.
- Accepted risk: a player duelling their own alt in two tabs plays ten real rounds a day for 3 cards, no more than the alt opening its own capsules.
- A win/loss/draw record on the profile; duel achievements give recognition or a card back, never a capsule.

## Later

- **Ranked duels** (after 1.4 is tested): a ranked queue, 20 s to confirm a match, the number of players waiting shown. Unrated against a friend or after 2 meetings with the same opponent in 7 days. Elo from 1,000, shown after 10 ranked duels with one in the last 14 days, reset each catalog season, the Flukeometer's layout and visibility.
- **Deferred duels**: the same rounds with a deadline per move, as chess.com's daily games. 48 h to make a first move, else cancelled; then a deadline per move, after which the game plays. Repeated expired challenges withdraw a player from open matching.

## Rejected

- The first design (asynchronous halves, the defender's top card or an automatic "weakest card that still wins"): the call was solved and an answerer in person had nothing to decide.
- The call shown, the caller's card hidden: the answer reduces to "my best on that stat or my worst".
- Both hands visible: the caller finds a call no hand card beats; the bluff is gone. Nothing visible: no reading of the opponent's deck, a flat endgame.
- Automatic play that starts a half no one began: it rewards absent players and idle alts.
- References without blocking, with a last-copy warning: the author wants deck cards blocked.
- Capture until one deck is empty (classic Top Trumps): duels would never end.
- 30-card decks: the deck becomes a lottery.
- A rarity budget or quotas on decks; player-specific stats (copies owned); market price as a stat (tied to rarity); circulation by copies (bought by hoarding).
- Continuous stat updates; win by forfeit; PiCoin or card stakes; ranking by win count or win rate.

## Left to the UX

The duel screen (hand, both decks, the face-up card, the timers), the challenge and its acceptance, the deck editor, the card profile, the Monday feed entry, copy; the navigation decided on 2026-11-14 (DUELS tab, Marché under Échanges) stands.
