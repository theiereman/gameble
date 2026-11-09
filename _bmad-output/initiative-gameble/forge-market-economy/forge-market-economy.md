# Forged idea: market and economy (V2)

Outcome: hardened, 2026-11-09. Evidence: `simulate_economy.py` and `simulation-results*.txt` (agent-based, 365 days, about 2,000 players, assumed behaviour, 15,000 cards). The simulation does not model the sale format; auction rules rest on research and judgment.

## Money

- One currency, earned only by entrusting cards to the Brotherhood's Archives. The Brotherhood never injects money. No real money; never purchasable or withdrawable.
- The currency is the PiCoin. All amounts are integers, shown compact (1.2M). No euro sign. A player "confie" / "entrusts" a card.
- The 100-6-Tron, Réacteur des Briétés, mints PiCoins. It mints only when a card is entrusted; stamp and commission go back to it and are destroyed.
- Sinks: listing stamp and 10% commission. Optional third sink: resale from the Archives, off at launch, per rarity from the back-office.

| Starting values | Common | Uncommon | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Entrustment pays | 1,000 | 2,000 | 5,000 | 15,000 | 100,000 |
| Listing stamp | 100 | 1,000 | 2,000 | 5,000 | 10,000 |

Targets for a standard player (40-50 capsules a day): Rare a few hours of income, Epic 1-2 days, Legendary about 40 days, held by a 7M minimum.

## Rules

- **Entrusting:** any copy, in a multi-select batch with one validation and no per-card confirmation. The recap flags only copies from Rare upward, without blocking. Cards leave the collection and are counted per card in the Archives from day one.
- **Daily entrustment cap:** about 1.2M of currency per account. A batch beyond it entrusts what fits. Market sales are not capped.
- **Selling:** any copy, any edition. Each rarity has a minimum price set in the back-office, never below entrustment value plus fees. The Legendary minimum starts at 7M.
- **Friend trades** stay free of stamp, commission, floor and levy.
- **Format:** auction with an optional buy-now price. 12h, 24h (preselected) or 3 days.
- **Bidding:** the player states "My maximum". Displayed price = second-highest maximum + increment, capped at the highest maximum, computed once per validated bid. Increment: 5% of the second-highest maximum, rounded up to the next hundred.
- **Bid rules:** minimum bid is price + increment (first bid: starting price). Equal maximums: the earlier leads. Raising one's own maximum while leading does not move the price. A bid is firm and can only be raised. No bidding on one's own listing.
- **Soft close:** +3 minutes, only when the price or the leader changes.
- **Buy-now:** a maximum reaching it buys at once at that price, stated before validation.
- **Escrow:** the whole maximum is held and released when outbid; the winner pays the final price and gets the surplus back. The screen shows available and committed balances.
- **Close:** an unsold copy returns to the seller, one-click relist, stamp kept. The seller may cancel only before any bid, stamp kept. A listed copy is reserved: no trade, no entrustment.
- **Bid history:** one line per validated bid, showing the player name and the price after that bid. The leader's maximum is never shown.
- **Average price:** per exact edition (game + season). Last 5 sales of the last 90 days, drop highest and lowest, average the rest. Under 3 sales: few-sales mention. None in 90 days: no-sale label.
- **Alt accounts:** back-office detection (near-maximum capsule opening, repeated one-way trades, off-market sales between the same accounts, self-bidding) plus the daily cap. No seniority gate, no limit on trades.

## Back-office

- Every economy setting is editable without a deployment: bounded, traced, applied to new listings only, and announced by the Brotherhood.
- Regulation is manual with alerts. Indicators are computed automatically: destroyed vs created over 30 days, money per active player over 90 days, prices in days of income, top 1% share. Each explains in plain language what is happening and proposes an action the author validates.

## Rejected

| Rejected | Why |
|---|---|
| Auction only / fixed price only | Forced waits on common cards / seller must guess, no thrill |
| One duration / free duration | One day for a Legendary / unreadable market |
| Hold only the current bid, or nothing | A maximum silently stops counting / empty accounts inflate auctions |
| Average per game, or per game and rarity | Mixes rarities / erases old-edition value |
| Raw average | Two accounts can inflate it |
| Current-season-only market | Listings lose their goods at each season change |
| Automatic regulator at launch | Overshoots: Legendary at 11 days, with thresholds validated on no real data |
| Daily cap of 150 or below | Sits at a normal player's income, starves the money supply |
| Proportional stamp | Burn falls from 0.88 to 0.36 of money created |
| Welcome bonus | Barely helps newcomers, farmable by alts |
| Anonymous bidders | Author prefers visible rivalry |

## Weak points that survived

- **Unsold Legendaries:** about 1,800 listings waiting at 30% resellers (3 months of sales). Accepted; higher minimums clog the market.
- **Legendary price depends on resale:** 25 days with no minimum and 30% resellers, about 4 at 60%.
- **Epic resellers** were not simulated. Watch the indicators.
- **Alert threshold** around 40% of burn vs creation is a guess until real data exists; the simulated economy sits at 0.56 on target.
- **Alt accounts:** no study measures how well any countermeasure works. A seller's alt can probe the leader's maximum; winning costs it the commission and stamp.
- **Visible names** let anyone follow a player's purchases and let friends avoid bidding against each other. Accepted.
- **Legal:** ban real-money trading in the terms, publish odds, never sell anything affecting capsules, currency or auctions, and watch for real-money resale.

## To reconcile downstream

- `spec-gameble.md`: lift the market and currency non-goals, but keep friend trades free of levy; earlier editions change hands "by trade or on the market".
- `later-roadmap.md`: the only-copy extra confirmation is superseded; issue #57's "contribution on trades" tone sample conflicts with free friend trades; the no-sale label widens to 90 days.
- `notes-market-economy/wikimasters-og-ama.md`: the seniority gate is out of date.
- Spec must define how a deleted account or private profile appears in the bid history.
- Build must provide an append-only currency ledger, idempotent auction close and integer amounts.
- The code's "bank" already means the capsule reserve: the 100-6-Tron is `Mint` in code.
- Check that the "to process" zone fits the quantity-based holdings without a per-copy row.
