# Later roadmap (not MVP)

Context for MVP design decisions that must not block these. Nothing here is built in the MVP.

## After the market

The market and its economy are now CAP-29 to CAP-38 of the spec, with their rules in `market-economy.md`.

- **Archive resale (author, 2026-11-09: built later, important):** the Brotherhood resells entrusted cards at a high price, enabled per rarity from the back-office. It creates neither PiCoins nor cards and destroys what buyers pay. The Archives stock is counted from the market's first day so it can open later. Simulated at 5 times the entrustment value on Commons and Uncommons, assuming half of buyers seek a card absent from the market, it supplies about a third of the PiCoins destroyed. The price is still open.

- **Quick sorting from the opening:** while a pack is opened, the player marks cards in place into a "to process" zone: drag on desktop, swipe or buttons on phone (buttons always available). One validation then entrusts or sells everything in it. Marking is reversible until validation; cards in the zone no longer count in the collection; only copies carry no extra confirmation, and the recap flags them from Rare upward without blocking (author, 2026-11-09). The "to process" screen must be easy to scan so reviewing stays quick.
  - **Rejected:** an immediate swipe that sells or discards (too dangerous), and default automatic sorting of duplicate commons (some are kept for a set or a loved game).
  - **To check before building it:** a per-copy "to process" state must fit the copy model without a heavy migration.

- **More economy charts (author, 2026-11-10: later):** the first build ships the public Reactor, the rarity prices in days of capsules with their index, the edition's sales on its card, and the back-office indicators (mockup `ux-gameble/.working/market-charts.html`). Later: an edition compared with the game's other editions on its card, the rarity floor line on more screens, market volume per day, the week's largest rises and falls with sparklines for the hub or the feed, a player's collection value over time, a player's own flows (entrusted, sold, bought, fees paid), and a Lorenz curve of wealth in the back-office.
  - **To decide before building them:** how a collection's value counts cards with no sale, and where per-player daily figures are stored.

## V3 — Seasons and community content

- ***Pass de la Confrérie* / Brotherhood Pass:** a collective parody battle pass whose tiers are advanced by market fees. Each tier rewards contributors with packs, never currency.
- **Seasons:** moved to the MVP rules (`catalog-and-rarity.md`, Seasons). Left for V3: the season cadence (e.g. quarterly).
- **Themed sets:** community-proposed and voted (20–100 cards each, with rewards), created in a back-office without code changes.

## Later

- **Odds input at opening:** an input the player makes at opening that improves the odds of a good card. The stratagem-like arrow code is rejected as too close to Helldivers; the form is open.
- **Steam library bonuses:** bonuses on the cards of games a player owns, from playtime and achievements. They are bonuses only; the library never grants a card. Steam shares a player's library only when their profile's game details are public; the Steam library set (CAP-27, release 1.1.0) reads it first.
- **Library info on a shared card:** show the owner's Steam library info when they own the game.
- **Live trades:** both players at the trade board at the same time.
- **Trade discussion:** a free-text discussion between the two players on a trade, raised while forging the open trade request (2026-10-15); to be forged on its own. Player-written text needs reports, hiding and back-office reading (CAP-15), export and erasure with the account (CAP-14), bans, private profiles, an unread badge, live delivery and rate limits.
- **Card marks:** favourite, to trade, personal categories.
- **Brotherhood sets (author, 2026-10-30):** a community page where players publish custom sets (CAP-27) and others add them to their own library; custom sets and goals on them then show on profiles. Player-written set names need reports, hiding and back-office reading (CAP-15), export and erasure with the account (CAP-14), and bans. To be refined.
- **Trade suggestions beyond friends (#64):** suggestions among other players willing to trade, with privacy controls.
- **Secret achievements (#66):** achievements whose title and condition stay hidden until earned, some opening hidden branches, explored once active goals (CAP-28) ship; sensitive ones private by default.
- **Targeted capsules (#64):** capsules aimed at a goal, to explore in their own issue.
- **Feed reactions:** reacting to or commenting on a friend's pull or repost.
- **Knowledge battles** (parked idea, unscheduled; detail in the brief addendum): three-round matches on themes drawn from Steam data, played with cards picked from a random hand. Release 1.4's Top Trump duel (CAP-41) already plays on Steam data with decks; a themed round could become a duel variant. Live play and card stakes stay out (spec non-goals).
- **Daily Pixel (#62):** a daily solo puzzle, guessing a game from a pixelated cover that sharpens with each wrong answer, rewarded with a themed capsule. It needs no deck; planned after release 1.4.
- **Living duel stats:** stats drawn from the Brotherhood's activity (entrusted copies, reactions and reposts, custom-set picks, trades, a card's duel win rate) were too sparse on 2026-11-14 (36 players). Remeasure at each new catalog season; a dense enough one may replace a Steam stat (`duel-rules.md`).
- **Duel extras:** decks shown on the profile, a solo practice duel, more than two players at once (#352).
- **Delisted games:** manual curation, since the store API returns little for them.
- **Native apps:** App Store and Play Store. Store review may object to third-party art and random rewards, and iOS sign-in rules may apply. Reassess then.
