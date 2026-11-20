# Duel rules

Rules of the Top Trump duel (CAP-39 to CAP-43). Source: `../forge-decks-and-matches/forge-decks-and-matches.md`, GitHub #352. Release 1.4 ships live duels between friends; ranked and deferred duels come later (end of this file).

## Stats

| Stat | Measure | Ranked over | Directions |
|---|---|---|---|
| Popularity | Steam review count of the edition's season | the edition's season catalog | most popular / most obscure |
| Rating | Steam % positive (whole number), then the review count | the edition's season catalog | best rated / worst rated |
| Release | release date | the edition's season catalog | most recent / oldest |
| Discovery | first pull in gameble (`first discoveries`), at the stored time | the season's editions someone has pulled | discovered first / discovered last |
| Circulation | distinct players holding the edition, Archives excluded | the editions of its rarity tier and season that at least one player holds | most widespread / hardest to find |

- A stat's value is a percentile, computed when release 1.4 is deployed and when a season is published, then every Monday 00:00 UTC. A card's trump is its most extreme stat, in either direction.
- An edition nobody has pulled has no discovery or circulation value; it cannot be in a deck anyway. Breaking an equal rating on the review count and ranking circulation among held editions only keeps exact ties rare (author, 2026-11-14, from the simulation; Steam gives the rating as a whole percent).
- An edition pulled for the first time after the last computation has no stats until the next one and cannot enter a deck until then (author, 2026-11-14).
- A percentile is the share of the ranked cards a card beats, equal values counting half (midrank), stored to one decimal.
- Rarity is not a stat: it is the review count cut by percentile (`catalog-and-rarity.md`), so it would duplicate popularity. Circulation is ranked within its tier because raw circulation follows the drop odds, hence rarity.
- Circulation counts holders, not copies, so hoarding duplicates cannot buy a trump. Entrusting copies can lower it from the next Monday on; that is accepted.
- Market price is not a stat: it follows rarity, and within a tier it sits at the no-loss floor or has no sale.
- Living-only stats are deferred: on 2026-11-14, with 36 players and 12,434 cards, circulation had 18 distinct values among 7,460 Commons, and entrusted copies, reactions and reposts, custom-set picks and trades were zero on 76–99 % of cards. Remeasure at each new catalog season; a living stat dense enough may then replace a Steam one.

## Decks

- Exactly 12 cards the player owns. A deck slot is an edition (game and season); a game appears at most once in a deck, whatever its edition. No rarity or theme constraint. Up to 5 decks per player, each named. A deck with fewer than 12 cards is a draft and cannot duel.
- A card in one or more decks blocks one copy of its edition; the player's other copies stay free. The card is freed by taking it out of every deck that holds it. The owner's trade, sale and entrust screens name those decks; nobody else sees them.
- A deck takes a free copy: a card whose copies of that edition are all reserved (a trade, a listing) cannot enter a deck, and the editor shows it with the Reserved tag. A deck-blocked copy counts as reserved wherever free copies are counted: trades, listings, entrusting and the spares of trade suggestions. Going private releases trade reservations only, never deck blocks.
- The deck editor lists one entry per edition the player owns, its season shown beside its trump. A card's detail shows the duel profile of the edition its "Prix moyen" reads.

## Starting a duel

- A player challenges a friend who is online, from the duels screen or the friend's profile, with one of their complete decks. The friend has 60 seconds to accept and pick one of their complete decks, or refuses; otherwise the challenge lapses.
- A player has one duel in progress at a time.
- A private player cannot duel, as they cannot trade (CAP-8); their friends see duels closed while the profile is private.

## A duel

- Both decks are locked, shuffled and revealed: each player sees both 12-card decks for the whole duel, played cards struck out. Hands stay hidden.
- Ten rounds. The first caller is drawn at random; calls alternate, except that the first caller also calls round 10, after the other player calls round 9 (A B A B A B A B B A), since the last round, played with open hands, favours its caller. Each player calls five times and calls each of the five stats once, in either direction; both players see which stats each has left. Each player holds a hand of 3 that serves both to call and to answer, and draws one card after each round; over ten rounds each draws their whole deck, so the last round is played with open hands.
- A round:
  1. The caller picks a card from their hand and a stat with a direction, and locks both.
  2. The caller's card turns face up with its five values; the call stays hidden.
  3. The answerer picks a card from their hand.
  4. Both cards and the call are revealed.
- The round goes to the better percentile in the called direction. Equal percentiles compare the exact value; still equal, the round scores nothing.
- One point per round won. Nothing is captured; neither deck changes. The duel goes to the higher score; equal scores go to the larger total percentile margin over the rounds won; still equal, the duel is a draw.
- Each player's margin so far is shown beside the score throughout the duel, since it still decides about a third of duels.
- Until the reveal, a player's hand, a locked call and both draw orders never reach the other player's device: knowing the opponent's hand is worth about 80 % of wins.
- Both decks and every stat value are frozen at the duel's start; a later trade, sale, Monday recomputation or deck edit never changes it.

Checked by simulation on 2026-11-14 (`../forge-decks-and-matches/simulation-2026-11-14.md`): with each stat called once and the last call returned to the first caller, about 30 % of skilled duels end 5–5 (73 % without), the first caller wins 48.5 %, a skilled player beats automatic play about 73 % of the time, and a 150-card newcomer at equal skill wins 36–39 % against an established collection. Adopted by the author on 2026-11-14.

## Time and absence

- 60 seconds to call, 45 seconds to answer, long enough to look over the opponent's deck on a phone (author, 2026-11-14; first 30 and 20). On timeout the game plays the move: a caller's strongest card and its most extreme call among the stats it has left; an answerer's hand card strongest on the shown card's most extreme stat among the caller's stats left.
- A disconnected player has 60 seconds to return; then the game plays each of their remaining moves as on timeout. No duel is won by forfeit.
- A banned or deleted player's duel in progress finishes by automatic play.
- An automatic move between equal choices takes the larger distance of the exact value from the median, then the stat order of the Stats table, then the lower card number.

## Reward and record (alpha)

- During the alpha a duel gives nothing material: no capsule, achievement or card back, and no stake in PiCoins or cards. The first-win duel capsule (3 cards at the daily bonus odds, CAP-16, only if the game played none of the winner's moves), the duel achievements and the Duelliste back are withheld until the beta (CAP-42).
- The player's own Duels screen shows wins, losses and draws against players under the rules in force; the public profile shows none. Practice duels never count.
- Every change to these rules raises the rules version stored on each duel (CAP-51).
- Decks and duel history are in the player's export (CAP-14) and deleted with the account; an opponent's history then reads "anonyme".

## Practice duel (CAP-50)

- Against the bot, under the rules above, 30 minutes per move; it counts for nothing.
- The bot plays as the skilled player of the 2026-11-14 simulation: it reads both open decks, the cards struck out and the shown card, and plays for the margin; it never reads the player's hand, call or draw order.
- Its deck, drawn from the current catalog at the duel's start, is one archetype, changing from one practice duel to the next and named on screen: **coverage** (the ten stat-directions each held by a card at 90 or above where the catalog allows), **single stat** (the most extreme cards on one stat, one archetype per stat), **two stats** (split between two stats), **trump sort** (the twelve most extreme trumps) and **random** (twelve editions, a game at most once).

## Later

- **Ranked duels (CAP-43):** a ranked queue among non-friends; the number of players waiting is shown; 20 seconds to confirm a match. A duel is unrated against a friend or after 2 meetings with the same opponent in 7 days. An Elo-style rating from 1,000, shown after 10 ranked duels with one in the last 14 days, reset at each new catalog season with each season's final rank kept on the profile, on its own screen with the Flukeometer's visibility rules and layout.
- **Deferred duels:** the same rounds, each move with a deadline, as chess.com's daily games. A challenge with no first move within 48 hours is cancelled, with no result, capsule or rating change; after a move's deadline the game plays it. Three challenges expired in a row withdraw a player from open matching until they rejoin it.
