# Duel rules

Rules of the Top Trump duel (CAP-39 to CAP-43). Source: `../forge-decks-and-matches/forge-decks-and-matches.md`, GitHub #352. Release 1.4 ships live duels between friends; ranked and deferred duels come later (end of this file).

## Stats

| Stat | Measure | Ranked over | Directions |
|---|---|---|---|
| Popularity | Steam review count of the edition's season | the edition's season catalog | most popular / most obscure |
| Rating | Steam % positive | the edition's season catalog | best rated / worst rated |
| Release | release date | the edition's season catalog | most recent / oldest |
| Discovery | first pull in gameble (`first discoveries`), to the second | the edition's season catalog | discovered first / discovered last |
| Circulation | distinct players holding the edition, Archives excluded | the edition's rarity tier in its season | most widespread / hardest to find |

- A stat's value is a percentile, computed when release 1.4 is deployed, then every Monday 00:00 UTC. A card's trump is its most extreme stat, in either direction.
- A card nobody has pulled ranks last on discovery.
- Rarity is not a stat: it is the review count cut by percentile (`catalog-and-rarity.md`), so it would duplicate popularity. Circulation is ranked within its tier because raw circulation follows the drop odds, hence rarity.
- Circulation counts holders, not copies, so hoarding duplicates cannot buy a trump. Entrusting copies can lower it from the next Monday on; that is accepted.
- Market price is not a stat: it follows rarity, and within a tier it sits at the no-loss floor or has no sale.
- Living-only stats are deferred: on 2026-11-14, with 36 players and 12,434 cards, circulation had 18 distinct values among 7,460 Commons, and entrusted copies, reactions and reposts, custom-set picks and trades were zero on 76–99 % of cards. Remeasure at each new catalog season; a living stat dense enough may then replace a Steam one.

## Decks

- Exactly 12 cards the player owns. A deck slot is an edition (game and season); a game appears at most once in a deck, whatever its edition. No rarity or theme constraint. Up to 5 decks per player, each named. A deck with fewer than 12 cards is a draft and cannot duel.
- A card in one or more decks blocks one copy of its edition; the player's other copies stay free. The card is freed by taking it out of every deck that holds it. The trade, sale and entrust screens name those decks.

## Starting a duel

- A player challenges a friend who is online, from the duels screen or the friend's profile, with one of their complete decks. The friend has 60 seconds to accept and pick one of their complete decks, or refuses; otherwise the challenge lapses.
- A player has one duel in progress at a time.
- A private player cannot duel, as they cannot trade (CAP-8); their friends see duels closed while the profile is private.

## A duel

- Both decks are locked, shuffled and revealed: each player sees both 12-card decks for the whole duel, played cards struck out. Hands stay hidden.
- Ten rounds. The first caller is drawn at random; calls then alternate. Each player holds a hand of 3 that serves both to call and to answer, and draws one card after each round; over ten rounds each draws their whole deck, so the last round is played with open hands.
- A round:
  1. The caller picks a card from their hand and a stat with a direction, and locks both.
  2. The caller's card turns face up with its five values; the call stays hidden.
  3. The answerer picks a card from their hand.
  4. Both cards and the call are revealed.
- The round goes to the better percentile in the called direction. Equal percentiles compare the exact value; still equal, the round scores nothing.
- One point per round won. Nothing is captured; neither deck changes. The duel goes to the higher score; equal scores go to the larger total percentile margin over the rounds won; still equal, the duel is a draw.
- Both decks and every stat value are frozen at the duel's start; a later trade, sale, Monday recomputation or deck edit never changes it.

## Time and absence

- 30 seconds to call, 20 seconds to answer. On timeout the game plays the move: a caller's strongest card and its most extreme call; an answerer's hand card strongest on the shown card's most extreme stat.
- A disconnected player has 60 seconds to return; then the game plays each of their remaining moves as on timeout. No duel is won by forfeit.
- A banned or deleted player's duel in progress finishes by automatic play.

## Reward and record

- The first win of the UTC day gives one duel capsule: 3 cards at the daily bonus odds (CAP-16), in the special reserve (CAP-4), with its own origin name and colour, only if the game played none of the winner's moves. Further wins, losses and draws give nothing material. There is no stake in PiCoins or cards.
- Duelling one's own second account is accepted: it takes ten real rounds a day for 3 cards, no more than that account opening its own capsules.
- The profile shows wins, losses and draws. Duel achievements follow CAP-17: recognition or a card back, never a capsule.
- Decks and duel history are in the player's export (CAP-14) and deleted with the account; an opponent's history then reads "anonyme".

## Later

- **Ranked duels (CAP-43):** a ranked queue among non-friends; the number of players waiting is shown; 20 seconds to confirm a match. A duel is unrated against a friend or after 2 meetings with the same opponent in 7 days. An Elo-style rating from 1,000, shown after 10 ranked duels with one in the last 14 days, reset at each new catalog season with each season's final rank kept on the profile, on its own screen with the Flukeometer's visibility rules and layout.
- **Deferred duels:** the same rounds, each move with a deadline, as chess.com's daily games. A challenge with no first move within 48 hours is cancelled, with no result, capsule or rating change; after a move's deadline the game plays it. Three challenges expired in a row withdraw a player from open matching until they rejoin it.
