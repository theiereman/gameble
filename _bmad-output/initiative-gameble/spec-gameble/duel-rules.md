# Duel rules

Rules of the Top Trump duel (CAP-39 to CAP-43). Source: `../forge-decks-and-matches/forge-decks-and-matches.md`, GitHub #352.

## Stats

| Stat | Measure | Ranked over | Directions |
|---|---|---|---|
| Popularity | Steam review count of the card's season | the season's catalog | most popular / most obscure |
| Rating | Steam % positive | the season's catalog | best rated / worst rated |
| Release | release date | the season's catalog | most recent / oldest |
| Discovery | first pull in gameble (`first discoveries`), to the second | the season's catalog | discovered first / discovered last |
| Circulation | copies held by players, Archives excluded | the card's rarity tier | most widespread / hardest to find |

- A stat's value is a percentile, recomputed every Monday 00:00 UTC. A card's trump is its most extreme stat, in either direction.
- Rarity is not a stat: it is the review count cut by percentile (`catalog-and-rarity.md`), so it would duplicate popularity. Circulation is ranked within its tier because raw circulation follows the drop odds, hence rarity.
- Entrusting duplicates lowers a card's circulation from the next Monday on; it is an accepted strategy, not an abuse.
- Market price is not a stat: it follows rarity, and within a tier it sits at the no-loss floor or has no sale.
- Living-only stats are deferred: on 2026-11-14, with 36 players and 12,434 cards, circulation had 18 distinct values among 7,460 Commons, and entrusted copies, reactions and reposts, custom-set picks and trades were zero on 76–99 % of cards. Remeasure at each new catalog season; a living stat dense enough may then replace a Steam one.

## Decks

- Exactly 12 cards, each card-season at most once, only cards the player owns. No rarity or theme constraint. Up to 5 decks per player, each named. A deck with fewer than 12 cards is a draft and cannot duel.
- A card in one or more decks blocks one copy; the player's other copies stay free. The card is freed by taking it out of every deck that holds it. The trade, sale and entrust screens name those decks.
- One complete deck may be the defence deck. Without one, a player receives no open challenge.

## A duel

- A duel is two halves. In their half, a player makes 5 calls in one sitting; the duel has 10 rounds.
- The calling player draws a hand of 3 from their shuffled deck and, for each call, plays one card from it, names a stat and a direction, then draws again. The defending player's card comes from the top of their own shuffled deck; the defender does nothing.
- Calls alternate between the players' halves; the winner of a round never calls again by right. The direction is the caller's choice, so a card extreme on one stat wins its own calls and loses the opponent's.
- The round goes to the better percentile in the called direction. Equal percentiles compare the exact value; still equal, the round scores nothing.
- One point per round won. Nothing is captured; neither deck changes. The duel goes to the higher score; equal scores go to the larger total percentile margin over the rounds won; still equal, the duel is a draw.
- Both decks and every stat value are frozen at the duel's start; a later trade, sale, Monday recomputation or deck edit never changes it.

## Opponents and time

- A friend duel: the player picks a friend and a deck, and plays their half at once.
- An open challenge: the player is matched at random with a player who has a defence deck, then plays their half at once.
- The opponent has 48 h to play their half. After that, it is played automatically: each call plays the card and stat of the hand that are the most extreme, in their extreme direction. No duel is won by forfeit.
- At most 10 duels in progress per player, and one at a time between the same two players.
- A private player can duel friends and shows as "Membre discret" / "Private member" in open challenges. A banned or deleted player's duels in progress finish by automatic play, and they leave open challenges.

## Reward, record and ranking

- The first win of the UTC day gives one duel capsule: 3 cards at the daily bonus odds (CAP-16), in the special reserve (CAP-4), with its own origin name and colour. Further wins, losses and draws give nothing material. There is no stake in PiCoins or cards.
- The profile shows wins, losses and draws. Duel achievements follow CAP-17: recognition or a card back, never a capsule.
- The ranking is an Elo-style rating that starts at 1,000 and moves after each open challenge by the gap between the two ratings. Friend duels never move it; an automatically played half counts. A player appears after 5 ranked duels. The rating resets at each new catalog season, and the profile keeps the final rank of each season.
- The ranking screen follows the Flukeometer's rules: a private profile is absent, a friends-only player is "Membre discret" to non-friends, banned and deleted players leave it; same layout.

## Launch

- Duels open on the first Monday after release 1.4, once the first stat computation has run; decks can be built from the release.
