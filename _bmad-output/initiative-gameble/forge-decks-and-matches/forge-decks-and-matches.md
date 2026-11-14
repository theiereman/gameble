# Forged idea: decks and the Top Trump duel (release 1.4)

Hardened with the author on 2026-11-14. Source ideas: GitHub #352 (Top Trump Duel). Daily Pixel (#62) and knowledge questions come later and do not shape the deck.

## Scope of 1.4

Decks, the weekly card stats they are built on, and the Top Trump duel with its ranking. The spec's "Combat" non-goal and the "no stats on the card face" rule are rewritten (stats show on the card detail, the deck editor and the duel; the face itself is unchanged).

## Duel

- Asynchronous only. A duel is two halves: each player makes 5 calls in one sitting against the opponent's deck; 10 rounds in all.
- A call: a card from a hand of 3, a stat, and a direction (higher or lower wins). The defender's card comes from their shuffled deck; the defender does nothing.
- Players alternate calls, and the caller picks the direction. Why: with "the winner calls" or a fixed direction, a deck stacked on one stat (all Legendaries) never loses; this way an extreme card wins its own calls and loses the opponent's.
- One point per round; nothing is captured; decks are untouched by a duel. A tied round compares the exact value, then scores nothing. A tied duel goes to the larger total percentile margin, then is a draw.
- Every stat value is frozen at the duel's start. Why: shifting values would reward dragging out a losing duel.
- Opponents: a friend, or an open challenge matched at random among players who named a defence deck. The challenger plays at once; the opponent has 48 h, then their half is played automatically (the most extreme card and stat of each hand). No win by forfeit.
- At most 10 duels in progress per player, one at a time between the same two players. A private player duels friends and shows as Private member in open challenges. A banned or deleted player's duels finish by automatic play.

## Stats

- Five, each played both ways: popularity (Steam review count), rating (% positive), release date, discovery (date of the first pull in gameble), circulation (copies held across the Brotherhood).
- Rarity is not a duel stat: it is the review count cut by percentile, so it would be the same stat twice.
- Circulation is ranked within its rarity tier (raw, it is rarity again); the other stats over the whole season catalog. A tied circulation round scores nothing.
- Why not only living stats (the author's wish): measured on production on 2026-11-14 (36 players, 29 active in 7 days, 12,434 cards), circulation has 18 distinct values among 7,460 Commons, and sacrifices, reactions, custom-set picks and trades are zero on 76-99% of cards. Discovery is the exception: every deck card was discovered, at a unique second. Remeasure at each new catalog season; a living stat dense enough may then replace a Steam one.
- Values and percentiles are recomputed every Monday 00:00 UTC; a duel reads its start week's values. Each card shows its percentile per stat and its trump (most extreme stat).
- Decks evolve with the game (discovery, circulation): the editor shows each card's change since last week; a Monday feed entry tells the biggest moves. Entrusting duplicates to make a card harder to find is an accepted strategy.

## Decks

- Exactly 12 cards, each card-season at most once, no rarity or theme constraint; only owned cards. Up to 5 decks; an incomplete deck is a draft and cannot duel.
- A card in any deck blocks one copy, whatever the number of decks; other copies stay free. To trade, sell or entrust it, the player takes it out of every deck; those screens name the decks. Built on holdings' reserved count; `Game::ReservedCopies` must tell a deck block from a trade.

## Reward and ranking

- The first win of the day gives one duel capsule (3 cards, daily bonus odds, no Common) in the special reserve. Nothing material beyond it, nothing for a loss or draw. No stake in PiCoins or cards.
- A win/loss/draw record on the profile; duel achievements give recognition or a card back, never a capsule.
- Ranking: an Elo-style rating from 1,000, moved only by open challenges (friend duels never count; an automatic half counts). Shown after 5 ranked duels, reset at each new catalog season with the final rank kept on the profile. Same visibility rules and layout as the Flukeometer, on its own screen.

## Rejected

- References without blocking, with a last-copy warning: the author wants deck cards blocked.
- Capture until one deck is empty (classic Top Trumps): duels would never end, worst of all asynchronously.
- 30-card decks: only 7 cards are seen per duel, so the deck becomes a lottery.
- A rarity budget or quotas on decks: alternating calls with a chosen direction already defeat single-stat decks.
- Player-specific stats (copies owned): they reward hoarding.
- Market price as a stat: tied to rarity, and within a tier prices sit at the no-loss floor or have no sale.
- Only living stats, for now: too sparse at today's player count (see Stats).
- Live duels; continuous stat updates; win by forfeit; PiCoin or card stakes; ranking by win count or win rate.

## Left to the UX

Navigation placement (the phone's five tabs are full), the deck editor, the duel screens, the card profile, the Monday feed entry, and copy.
