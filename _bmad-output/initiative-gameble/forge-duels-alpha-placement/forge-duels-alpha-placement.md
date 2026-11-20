# Forged idea: the duels alpha and its place in the interface

Outcome: hardened, 2026-11-20. Builds on `../forge-decks-and-matches/forge-decks-and-matches.md` (and its simulation) and `../forge-market-volume/forge-market-volume.md`. Reopens the navigation of 2026-11-14 and changes the scope of release 1.4.

## Scope of the alpha

- Open to every player, labelled ALPHA; the global `duels` feature flag and its back-office switch are removed, with every branch it gates.
- Live challenges between friends, plus the practice duel against the bot. No rewards: the duel capsule, the ten duel achievements and the Duelliste back leave the alpha.
- Asynchronous (deferred) duels move to the beta: they need parallel duels per player, a duel screen one may leave, "your turn" bell lines and a list of duels in progress, and serve neither alpha question.
- Decks: 3 free (`forge-market-volume`), beyond that bought with PiCoins.

## What the alpha must answer

- Is the designed duel fun to play, and do players enjoy building varied decks? Not retention.
- It is a test bench for the rules: if one deck dominates (the simulation predicts the coverage deck wins 82 to 90 %), the author changes the rules.

## Practice bot

- Plays skilled: reads both open decks and the shown card, margin-aware (the simulation's skilled player), instead of today's half-automatic, half-random play.
- Plays a named archetype deck that changes each game ("the bot plays a Popularity deck"), so the player knows which strategy they face.

## Measurement

- A back-office page from the start, human duels and practice duels read separately (practice measures a deck against the bot, not against another deck).
- New data: the bot's archetype per practice duel; the rules version each duel was played under. Everything else is already stored (deck snapshots, result, margins, every round).
- The ALPHA banner says games are analysed to balance the rules. Written feedback stays the main signal for "is it fun".

## Navigation (option E')

- Phone tabs: PONT · CAPSULE · SETS · ÉCHANGES · DUELS; DUELS carries an ALPHA tag; desktop menu 03 ÉCHANGES, 04 DUELS.
- ÉCHANGES keeps its name; MARCHÉ becomes its first sub-tab and the default (`Game::ExchangesTab::DEFAULT`).
- A backfill, through an operation, keeps ENTRE AMIS for every player with a friend trade in the last 30 days, so the goals-to-suggestions trade flow is not broken.
- The native apps get the DUELS tab back, matching the web.

## Duels elsewhere in the app

- The win/loss/draw record leaves the public profile during the alpha and stays on the player's own Duels screen; it counts only duels under the rules in force (practice excluded, as built).
- The duel profile stays on every card detail for everyone, below the collection facts, as built; card stats are card data, not rules, so they carry no ALPHA tag.
- The Monday "Le cours des cartes a bougé." feed entry ships as built; withdraw it if its moves read as noise.

## Rejected

| Rejected | Why |
|---|---|
| Keep the global flag | It gates all or nobody, forks 15 places including the tab bar, and the native apps already ignore it |
| Invite-only alpha | Needs a per-player flag, more code than an honest ALPHA label |
| B: no tab, entry from the hub and a friend | The hub menu is hidden on the phone and the native apps navigate by tabs only: no way to the deck editor or the practice duel |
| D: a Duels block on the phone hub, Market keeps its tab | New UX to hide what the alpha needs played |
| E: the tab renamed MARCHÉ | Friend traders land on the market; E' serves both with the kept sub-tab |
| F: market alone in its tab, friend trades moved to Amis | Hides the trade-suggestion flow, ~1,100 cards a week against ~50 market sales |
| Async in the alpha | An epic of work that tests retention, not the two alpha questions |
| A stronger bot on a random deck | Tests no strategy in particular |
| A public record during the alpha | Pushes players to the dominant deck and mixes rules versions |

## Weak points that survived

- A skilled bot may teach every player the coverage deck: the varied-decks reading must separate what players build against the bot from what they build against friends.
- Sample size: about 30 active players give a few dozen human duels; per-archetype win rates come mostly from practice.
- Live duels need two friends online at once; practice is the only answer until the beta.
- Removing the rewards undoes built work (44.1 swapped checks on `game_packs`), which is migration work, not a hidden branch.

## Before the alpha ships (from the three duel retrospectives)

- Staging play of the live duel (two phones, two desktops, refused, cancelled, lapsed, timeout, reload, drop, ban, deletion mid-duel) and the screen-reader pass.
- Build and run both native apps with the DUELS tab: the native tab code was never compiled.
- The broadcast-level secrecy test (no other hand, unrevealed call or draw order in a seat's HTML) and the nil-rating case in the rules test.
- F2 and F4 have landed on `develop`; confirm F3 (a stale acceptor deck token refuses inline without lapsing the challenge).
