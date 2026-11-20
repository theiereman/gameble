#!/usr/bin/env python3
"""Archive resale, capacity slots and buy orders on top of the market-economy simulation.

Run with: uv run --with numpy python simulate_shop.py [scenario filter] [seeds]
(plain python3 works where numpy is installed, as for the simulator it builds on).

Reuses ../forge-market-economy/simulate_economy.py (catalog, odds, behaviour segments, churn, demand)
with the launch rules the spec kept, at today's scale: every amount there is a tenth of today's PiCoins.
Behaviour added here is assumed, never measured; read results as orders of magnitude.
"""
import math
import sys as _sys
_sys.dont_write_bytecode = True
import sys
from dataclasses import dataclass, replace
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "forge-market-economy"))
from simulate_economy import (  # noqa: E402
    ACTIVE_ODDS, CAPSULE, DAYS, DEMAND_WEIGHT, HARDCORE, KEEP_DUPLICATES, MAX_PLAYERS, NCARDS, ODDS,
    SPEND_RATE, UNITS_PER_DAY, churn_hazard, unique_from_draws,
)

# Today's values (market-economy.md).
ENTRUST = np.array([10, 20, 50, 150, 1000], dtype=float)
STAMP = np.array([1, 10, 20, 50, 100], dtype=float)
MINIMUM = np.array([13, 34, 78, 223, 70_000], dtype=float)
COMMISSION = 0.10
DAILY_CAP = 12_000.0
CAPSULES_PER_DAY = np.array([10.0, 45.0, 100.0])
LEGENDARY_FLIPPERS = 0.30
FIRST_COPY_NEWCOMERS = 0.5
NEWCOMER_DAYS = 30
FRIEND_TRADE_CARDS_PER_PLAYER_WEEK = 1100 / 30
PRICE_SPREAD = 0.5  # lognormal spread of single sales around the day's clearing price (assumed)
SLOT_KINDS = ("goal", "set", "deck")


@dataclass(frozen=True)
class Shop:
    name: str
    archive: tuple = (0, 0, 0, 0, 0)          # fixed Archive price per rarity, 0 = absent from the shop
    archive_market_multiple: float = 0.0       # > 0: price follows k x typical market price, floored at the minimum
    captive_share: float = 0.5                 # buyers whose wanted card has no player listing
    wtp_median: float = 2.0                    # a captive buyer pays up to this multiple of the rarity's market price
    wtp_sigma: float = 0.7
    list_share: float = 0.5                    # share of spare copies listed when listing pays
    entrust_unlisted: bool = False             # True: copies not listed are entrusted at once (thin supply)
    orders: bool = False
    order_share: float = 0.5                   # unserved captive buyers who place an order
    order_fill: float = 0.7                    # a matching seller sells to the order rather than entrust or list
    order_premium: float = 1.2                 # order price = premium x typical market price, at least the minimum
    goal_prices: tuple = ()                    # goals 6 to 10
    set_prices: tuple = ()                     # custom sets 6 to 10
    deck_prices: tuple = ()                    # decks 4 and 5
    slot_days: float = 0.0                     # > 0: every slot costs this many days of standard income
    slot_wtp_days: float = 3.0                 # median worth of one more slot, in days of the player's own income
    slot_wants: tuple = ((0.31, 0.6), (0.05, 0.5), (0.25, 0.5))  # (share wanting one more, chance of wanting each next)


def above(entries, threshold):
    """Share of units sold above a threshold, each day's price spread lognormally."""
    units = sum(u for u, _ in entries)
    if units == 0 or threshold <= 0:
        return float("nan")
    z = [(math.log(threshold) - math.log(p)) / PRICE_SPREAD for _, p in entries]
    return sum(u * 0.5 * math.erfc(x / math.sqrt(2)) for (u, _), x in zip(entries, z)) / units


def run(shop, seed):
    rng = np.random.default_rng(seed)
    kind = np.zeros(MAX_PLAYERS, dtype=int)
    joined = np.zeros(MAX_PLAYERS, dtype=int)
    alive = np.zeros(MAX_PLAYERS, dtype=bool)
    balance = np.zeros(MAX_PLAYERS)
    drawn = np.zeros((MAX_PLAYERS, 5))
    disposed = np.zeros((MAX_PLAYERS, 5))
    bought = np.zeros((MAX_PLAYERS, 5))
    listed = np.zeros((MAX_PLAYERS, 5))
    income_today = np.zeros(MAX_PLAYERS)
    income_average = np.zeros(MAX_PLAYERS)
    flips_legendaries = rng.random(MAX_PLAYERS) < LEGENDARY_FLIPPERS
    gives_up_first_copies = rng.random(MAX_PLAYERS) < FIRST_COPY_NEWCOMERS
    slot_prices = [np.array(p, dtype=float) for p in (shop.goal_prices, shop.set_prices, shop.deck_prices)]
    wanted_slots = np.zeros((MAX_PLAYERS, 3), dtype=int)
    owned_slots = np.zeros((MAX_PLAYERS, 3), dtype=int)
    slot_worth = rng.lognormal(math.log(shop.slot_wtp_days), 1.0, MAX_PLAYERS)

    floor = np.maximum((ENTRUST + STAMP) / (1.0 - COMMISSION), MINIMUM)
    price_estimate = floor * 2.0
    archive_on = np.array(shop.archive, dtype=float) > 0
    archive_stock = np.zeros(5)
    book = [[] for _ in range(5)]  # open orders per rarity: (price, owner, expiry day)
    standard_income = 0.0

    created = np.zeros(DAYS)
    burned = {key: np.zeros(DAYS) for key in ("stamp", "commission", "archive", "slot")}
    auction_units, direct_units, archive_units, diverted_units = (np.zeros((DAYS, 5)) for _ in range(4))
    slot_units = np.zeros((DAYS, 3))
    sales = [[] for _ in range(5)]  # (day, units, price) of player sales
    archive_price_log = np.zeros((DAYS, 5))
    snapshots = {}
    used = 0

    for day in range(DAYS):
        for _ in range(min(rng.poisson(25.0), MAX_PLAYERS - used)):
            kind[used] = rng.choice(3, p=[0.45, 0.42, 0.13])
            joined[used], alive[used] = day, True
            for k, (share, again) in enumerate(shop.slot_wants):
                if slot_prices[k].size or shop.slot_days:
                    ceiling = 2 if k == 2 else 5
                    wants = int(rng.random() < share)
                    while wants and wants < ceiling and rng.random() < again:
                        wants += 1
                    wanted_slots[used, k] = wants
            used += 1

        leaving = alive & (rng.random(MAX_PLAYERS) < churn_hazard(day - joined, kind))
        alive[leaving] = False
        listed[leaving] = 0.0

        active = alive & (rng.random(MAX_PLAYERS) < ACTIVE_ODDS[kind])
        idx = np.flatnonzero(active)
        capsules = rng.poisson(CAPSULES_PER_DAY[kind[idx]])
        drawn[idx] += rng.poisson(capsules[:, None] * CAPSULE * ODDS)
        income_today[:] = 0.0

        duplicates = np.maximum(drawn[idx] - unique_from_draws(drawn[idx]) - disposed[idx], 0.0)
        spare = duplicates * (1.0 - KEEP_DUPLICATES[kind[idx]])[:, None]
        flipping = flips_legendaries[idx]
        spare[flipping, 4] = np.maximum(drawn[idx][flipping, 4] - disposed[idx][flipping, 4], 0.0)
        sacrificing = gives_up_first_copies[idx] & (day - joined[idx] < NEWCOMER_DAYS)
        spare[sacrificing, :2] = np.maximum(drawn[idx][sacrificing, :2] - disposed[idx][sacrificing, :2], 0.0)

        for r in range(5):
            if not book[r]:
                continue
            chance = min(1.0, len(book[r]) / NCARDS[r]) * shop.order_fill
            matched = rng.binomial(np.floor(spare[:, r]).astype(int), chance)
            while matched.sum() > len(book[r]):
                matched = np.floor(matched * 0.9).astype(int)
            if not matched.sum():
                continue
            served = rng.choice(len(book[r]), matched.sum(), replace=False)
            prices = np.array([book[r][i][0] for i in served])
            owners = np.array([book[r][i][1] for i in served])
            sellers = np.repeat(idx, matched)
            np.add.at(balance, sellers, prices * (1.0 - COMMISSION))
            np.add.at(income_today, sellers, prices * (1.0 - COMMISSION))
            np.add.at(bought[:, r], owners, 1.0)
            burned["commission"][day] += prices.sum() * COMMISSION
            spare[:, r] -= matched
            disposed[idx, r] += matched
            direct_units[day, r] += matched.sum()
            sales[r] += [(day, 1.0, p) for p in prices]
            gone = set(served.tolist())
            book[r] = [o for i, o in enumerate(book[r]) if i not in gone]

        worth_listing = price_estimate * (1.0 - COMMISSION) - STAMP > ENTRUST * 1.2
        to_list = np.where(worth_listing, spare * shop.list_share, 0.0)
        to_destroy = spare - to_list if shop.entrust_unlisted else np.where(worth_listing, 0.0, spare)
        stamp_cost = to_list @ STAMP
        too_poor = stamp_cost > balance[idx]
        to_destroy[too_poor] += to_list[too_poor]
        to_list[too_poor] = 0.0
        stamp_cost[too_poor] = 0.0

        earned = to_destroy @ ENTRUST
        scale = np.minimum(1.0, DAILY_CAP / np.maximum(earned, 1e-9))
        to_destroy *= scale[:, None]
        earned *= scale
        balance[idx] += earned - stamp_cost
        income_today[idx] += earned
        disposed[idx] += to_destroy + to_list
        archive_stock += to_destroy.sum(axis=0)
        listed[idx] += to_list
        created[day] = earned.sum()
        burned["stamp"][day] = stamp_cost.sum()

        if shop.archive_market_multiple:
            archive_price = np.where(archive_on, np.maximum(MINIMUM, np.ceil(shop.archive_market_multiple * price_estimate)), 0.0)
        else:
            archive_price = np.array(shop.archive, dtype=float)
        archive_price_log[day] = archive_price

        buyers = np.flatnonzero(active & (balance > 0))
        missing = np.maximum(NCARDS - unique_from_draws(drawn[buyers]) - bought[buyers], 0.0)
        wants = DEMAND_WEIGHT * (missing >= 1)
        wants_total = wants.sum(axis=1, keepdims=True)
        cumulative = np.divide(wants, wants_total, out=np.zeros_like(wants), where=wants_total > 0).cumsum(axis=1)
        target = (cumulative < rng.random(buyers.size)[:, None]).sum(axis=1)
        willing = balance[buyers] * SPEND_RATE[kind[buyers]]

        for r in range(5):
            supply = listed[:, r].sum()
            who = np.flatnonzero((target == r) & (wants_total[:, 0] > 0))
            cap = np.minimum(np.floor(missing[who, r]), UNITS_PER_DAY[r])
            bids = willing[who]
            captive = rng.random(who.size) < shop.captive_share
            unserved = captive.copy()

            price = archive_price[r]
            if price > 0 and archive_stock[r] >= 1 and who.size:
                in_stock = rng.random(who.size) < 1.0 - math.exp(-archive_stock[r] / NCARDS[r])
                worth = price_estimate[r] * rng.lognormal(math.log(shop.wtp_median), shop.wtp_sigma, who.size)
                diverts = ~captive & (price < price_estimate[r])
                buy = ((captive & in_stock & (worth >= price)) | diverts) & (bids >= price) & (cap >= 1)
                excess = int(buy.sum() - math.floor(archive_stock[r]))
                if excess > 0:
                    buy[rng.choice(np.flatnonzero(buy), excess, replace=False)] = False
                balance[buyers[who[buy]]] -= price
                bought[buyers[who[buy]], r] += 1.0
                bids[buy] -= price
                cap[buy] -= 1.0
                archive_stock[r] -= buy.sum()
                burned["archive"][day] += buy.sum() * price
                archive_units[day, r] += buy.sum()
                diverted_units[day, r] += (buy & diverts).sum()
                unserved &= ~buy

            if shop.orders and who.size:
                order_price = math.ceil(max(floor[r], shop.order_premium * price_estimate[r]))
                place = unserved & (cap >= 1) & (bids >= order_price) & (rng.random(who.size) < shop.order_share)
                for owner in buyers[who[place]]:
                    book[r].append((order_price, owner, day + 7))
                balance[buyers[who[place]]] -= order_price
                cap[place] = 0.0  # the wanted card is not on the market: the order waits for it
                bids[place] -= order_price

            def demand(at):
                return np.minimum(np.floor(np.maximum(bids, 0.0) / at), cap).sum()

            if supply < 1:
                if who.size:
                    price_estimate[r] *= 1.10
                continue
            if who.size == 0 or demand(floor[r]) == 0:
                price_estimate[r] *= 0.90
                continue
            low, high = floor[r], max(bids.max(), floor[r])
            if demand(low) <= supply:
                clearing = low
            else:
                for _ in range(40):
                    middle = (low * high) ** 0.5
                    low, high = (middle, high) if demand(middle) > supply else (low, middle)
                clearing = high
            units = np.minimum(np.floor(np.maximum(bids, 0.0) / clearing), cap)
            if units.sum() > supply:
                units = np.floor(units * supply / units.sum())
            sold = units.sum()
            if sold == 0:
                price_estimate[r] *= 0.90
                continue
            balance[buyers[who]] -= units * clearing
            bought[buyers[who], r] += units
            share_sold = sold / supply
            proceeds = listed[:, r] * share_sold * clearing * (1.0 - COMMISSION)
            balance += proceeds
            income_today += proceeds
            burned["commission"][day] += sold * clearing * COMMISSION
            listed[:, r] *= 1.0 - share_sold
            auction_units[day, r] += sold
            sales[r].append((day, sold, clearing))
            price_estimate[r] = 0.8 * price_estimate[r] + 0.2 * clearing

        unsold_back = listed * 0.33
        listed -= unsold_back
        disposed -= unsold_back

        for r in range(5):
            expired = [o for o in book[r] if o[2] <= day]
            for order_price, owner, _ in expired:
                balance[owner] += order_price
            book[r] = [o for o in book[r] if o[2] > day]

        income_average[alive] = 0.9 * income_average[alive] + 0.1 * income_today[alive]
        regulars = alive & (kind == 1)
        earners = regulars & active & (income_today > 0)
        if earners.any():
            standard_income = float(np.median(income_today[earners]))

        for k in range(3):
            ceiling = 2 if k == 2 else 5
            if not (slot_prices[k].size or shop.slot_days):
                continue
            ready = idx[(owned_slots[idx, k] < wanted_slots[idx, k]) & (day - joined[idx] >= 7)]
            if shop.slot_days:
                price = np.full(ready.size, math.ceil(shop.slot_days * standard_income))
            else:
                price = slot_prices[k][np.minimum(owned_slots[ready, k], ceiling - 1)]
            buys = (price <= slot_worth[ready] * income_average[ready]) & (price <= balance[ready] * SPEND_RATE[kind[ready]])
            balance[ready[buys]] -= price[buys]
            owned_slots[ready[buys], k] += 1
            burned["slot"][day] += price[buys].sum()
            slot_units[day, k] += buys.sum()

        if day + 1 in (30, 90, 180, 365):
            escrow = sum(o[0] for r in range(5) for o in book[r])
            destroyed = sum(b[: day + 1].sum() for b in burned.values())
            assert abs(balance.sum() + escrow - (created[: day + 1].sum() - destroyed)) < 1e-6 * max(created.sum(), 1.0), "PiCoins leaked"
            window = slice(max(0, day - 29), day + 1)
            recent = slice(max(0, day - 89), day + 1)
            players = alive.sum()
            weeks = (window.stop - window.start) / 7
            regular_income = np.median(income_average[regulars]) if regulars.any() else 0.0
            player_sold = auction_units[window].sum() + direct_units[window].sum()
            entries = [[(u, p) for d, u, p in sales[r] if recent.start <= d < recent.stop] for r in range(5)]
            last_price = archive_price_log[day]
            snapshots[day + 1] = {
                "players": players,
                "money_per_player": balance[alive].sum() / max(players, 1),
                "escrow_per_player": escrow / max(players, 1),
                "income_day": regular_income,
                "ratio_30d": sum(b[window].sum() for b in burned.values()) / max(created[window].sum(), 1e-9),
                "ratio_all": destroyed / max(created[: day + 1].sum(), 1e-9),
                "archive_week_per_100": burned["archive"][window].sum() / weeks / max(players, 1) * 100,
                "slot_week_per_100": burned["slot"][window].sum() / weeks / max(players, 1) * 100,
                "slot_total_per_player": burned["slot"][: day + 1].sum() / max(used, 1),
                "commission_stamp_week_per_100": (burned["stamp"][window].sum() + burned["commission"][window].sum()) / weeks / max(players, 1) * 100,
                "price": price_estimate.copy(),
                "days_of_income": price_estimate / max(regular_income, 1e-9),
                "archive_days": last_price / max(regular_income, 1e-9),
                "archive_units_week_per_100": archive_units[window].sum(axis=0) / weeks / max(players, 1) * 100,
                "player_sales_week_per_player": player_sold / weeks / max(players, 1),
                "direct_share": direct_units[window].sum() / max(player_sold, 1e-9),
                "market_share": player_sold / max(player_sold + FRIEND_TRADE_CARDS_PER_PLAYER_WEEK * weeks * players, 1e-9),
                "diverted": diverted_units[recent].sum(axis=0) / np.maximum(auction_units[recent].sum(axis=0) + direct_units[recent].sum(axis=0) + diverted_units[recent].sum(axis=0), 1e-9),
                "undercut": np.array([above(entries[r], last_price[r]) for r in range(5)]),
                "arbitrage": np.array([above(entries[r], (last_price[r] + STAMP[r]) / (1 - COMMISSION)) if last_price[r] else float("nan") for r in range(5)]),
                "slots_owned_per_100": owned_slots[alive].sum(axis=0) / max(players, 1) * 100,
            }
    return snapshots


def median_of_runs(shop, seeds):
    runs = [run(shop, seed) for seed in range(seeds)]
    return {day: {key: np.nanmedian([r[day][key] for r in runs], axis=0) for key in runs[0][day]} for day in runs[0]}


def production_slots(prices, wtp_days=3.0, income=200.0, at_cap=5, again=0.6, trials=4000, seed=0):
    """One-off slot spending at today's ~30 players: wallets fitted to median 965 and 50,822 over 20 wallets."""
    rng = np.random.default_rng(seed)
    sigma = math.sqrt(2 * math.log((50_822 / 20) / 965))
    spent, buyers = [], []
    for _ in range(trials):
        wallet = rng.lognormal(math.log(965), sigma, at_cap)
        worth = rng.lognormal(math.log(wtp_days), 1.0, at_cap) * rng.lognormal(math.log(income), 0.8, at_cap)
        total = bought_any = 0
        for player in range(at_cap):
            wants = 1
            while wants < len(prices) and rng.random() < again:
                wants += 1
            for slot in range(wants):
                price = prices[slot]
                if price > worth[player] or price > 0.5 * wallet[player]:
                    break
                wallet[player] -= price
                total += price
                bought_any += slot == 0
        spent.append(total)
        buyers.append(bought_any)
    return float(np.mean(spent)), float(np.mean(buyers))


NO_SHOP = Shop("no shop (control: the launch economy at today's scale)")
GOALS = (500, 1000, 2000, 3000, 5000)
SETS = (500, 1000, 2000, 3000, 5000)
DECKS = (1000, 2000)
TABLE = (50, 100, 500, 1500, 0)
THIN = {"list_share": 0.03, "entrust_unlisted": True}
RECOMMENDED = Shop("REC Archive 50/100/500/1.5k, no Legendary; slots 500/1k/2k/3k/5k, decks 1k/2k", archive=TABLE,
                   goal_prices=GOALS, set_prices=SETS, deck_prices=DECKS)

SCENARIOS = [
    NO_SHOP,
    Shop("THIN control: thin supply (3% listed, rest entrusted), no shop", **THIN),
    Shop("ARC 5x entrustment incl. Legendary 5,000 (under its minimum)", archive=(50, 100, 250, 750, 5000)),
    Shop("ARC 3x entrustment, no Legendary", archive=(30, 60, 150, 450, 0)),
    Shop("ARC 5x entrustment, no Legendary", archive=(50, 100, 250, 750, 0)),
    Shop("ARC 10x entrustment, no Legendary", archive=(100, 200, 500, 1500, 0)),
    Shop("ARC 2x minimum, no Legendary", archive=(26, 68, 156, 446, 0)),
    Shop("ARC 3x minimum, no Legendary", archive=(39, 102, 234, 669, 0)),
    Shop("ARC 3x minimum, Legendary 210,000", archive=(39, 102, 234, 669, 210_000)),
    Shop("ARC 2x market price (floating), no Legendary", archive=(1, 1, 1, 1, 0), archive_market_multiple=2.0),
    Shop("ARC 3x market price (floating), no Legendary", archive=(1, 1, 1, 1, 0), archive_market_multiple=3.0),
    Shop("ARC table 50/100/500/1.5k, no Legendary", archive=TABLE),
    Shop("ARC table 50/100/500/1.5k, Legendary 140,000", archive=(50, 100, 500, 1500, 140_000)),
    Shop("ARC thin, 5x entrustment", archive=(50, 100, 250, 750, 0), **THIN),
    Shop("ARC thin, 10x entrustment", archive=(100, 200, 500, 1500, 0), **THIN),
    Shop("ARC thin, table 50/100/500/1.5k", archive=TABLE, **THIN),
    Shop("SENS table, captive 20%", archive=TABLE, captive_share=0.2),
    Shop("SENS table, captive 80%", archive=TABLE, captive_share=0.8),
    Shop("SENS table, buyers pay up to 1.5x market", archive=TABLE, wtp_median=1.5),
    Shop("SENS table, buyers pay up to 3x market", archive=TABLE, wtp_median=3.0),
    Shop("SENS table, thin, buyers pay up to 1.5x market", archive=TABLE, wtp_median=1.5, **THIN),
    Shop("SLOT flat 500 each", goal_prices=(500,) * 5, set_prices=(500,) * 5, deck_prices=(500,) * 2),
    Shop("SLOT flat 2,000 each", goal_prices=(2000,) * 5, set_prices=(2000,) * 5, deck_prices=(2000,) * 2),
    Shop("SLOT rising 500/1k/2k/3k/5k, decks 1k/2k", goal_prices=GOALS, set_prices=SETS, deck_prices=DECKS),
    Shop("SLOT rising, doubling 500..8k, decks 1k/2k", goal_prices=(500, 1000, 2000, 4000, 8000), set_prices=(500, 1000, 2000, 4000, 8000), deck_prices=DECKS),
    Shop("SLOT 3 days of standard income each", slot_days=3.0),
    Shop("SLOT rising, worth 1.5 days median", goal_prices=GOALS, set_prices=SETS, deck_prices=DECKS, slot_wtp_days=1.5),
    Shop("SLOT rising, worth 6 days median", goal_prices=GOALS, set_prices=SETS, deck_prices=DECKS, slot_wtp_days=6.0),
    Shop("SLOT rising, half as many players want slots", goal_prices=GOALS, set_prices=SETS, deck_prices=DECKS,
         slot_wants=((0.15, 0.5), (0.03, 0.5), (0.12, 0.5))),
    RECOMMENDED,
    replace(RECOMMENDED, name="REC thin", **THIN),
    replace(RECOMMENDED, name="ORD recommended + buy orders", orders=True),
    replace(RECOMMENDED, name="ORD orders, 30% of matching sellers sell", orders=True, order_fill=0.3),
    replace(RECOMMENDED, name="ORD orders, 90% of matching sellers sell", orders=True, order_fill=0.9),
    replace(RECOMMENDED, name="ORD orders, every unserved captive buyer orders", orders=True, order_share=1.0),
    replace(RECOMMENDED, name="ORD orders, thin", orders=True, **THIN),
    Shop("ORD orders only, no shop", orders=True),
    Shop("ORD orders only, thin, no shop", orders=True, **THIN),
]


def summary_line(name, result):
    a, b = result[90], result[365]
    pct = lambda v: "/".join("-" if np.isnan(x) else f"{x * 100:.0f}" for x in v[:4])
    return (f"{name[:58]:<58} {a['ratio_all']:>5.2f} {b['ratio_all']:>5.2f} {a['money_per_player'] / 1000:>6.1f}k {b['money_per_player'] / 1000:>5.1f}k "
            f"{a['archive_week_per_100'] / 1000:>5.1f}k {b['archive_week_per_100'] / 1000:>5.1f}k {b['slot_total_per_player']:>4.0f} "
            f"{pct(a['diverted']):>11} {pct(b['diverted']):>11} {pct(b['undercut']):>11} {pct(b['arbitrage']):>11} "
            f"{a['days_of_income'][2]:>5.1f} {a['days_of_income'][3]:>5.1f} {b['direct_share'] * 100:>4.0f}% {b['market_share'] * 100:>4.0f}%")


def show(result):
    for day, s in result.items():
        print(f"d{day:>3} players={s['players']:>5.0f} money/player={s['money_per_player']:>7.0f} escrow/player={s['escrow_per_player']:>4.0f} "
              f"income/day={s['income_day']:>6.0f} destroyed/created 30d={s['ratio_30d']:.2f} all={s['ratio_all']:.2f} "
              f"per 100 players a week: fees={s['commission_stamp_week_per_100']:>6.0f} archive={s['archive_week_per_100']:>6.0f} slots={s['slot_week_per_100']:>5.0f}")
        print(f"     market price {np.round(s['price']).astype(int)}  days of income {np.round(s['days_of_income'], 2)}  archive price in days {np.round(s['archive_days'], 2)}")
        print(f"     archive units/week/100 {np.round(s['archive_units_week_per_100'], 1)}  undercut {np.round(s['undercut'], 2)}  arbitrage {np.round(s['arbitrage'], 2)}  diverted {np.round(s['diverted'], 2)}")
        print(f"     player sales/player/week={s['player_sales_week_per_player']:.2f} direct share={s['direct_share']:.2f} market share vs friend trades={s['market_share']:.2f} "
              f"slots owned/100 players {np.round(s['slots_owned_per_100']).astype(int)} slot PiCoins per player ever joined={s['slot_total_per_player']:.0f}")


def main():
    np.set_printoptions(suppress=True, linewidth=160)
    wanted = sys.argv[1] if len(sys.argv) > 1 else ""
    seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    print(f"seeds per scenario: {seeds}; amounts in today's PiCoins; rarity order Common, Uncommon, Rare, Epic, Legendary")
    summary = []
    for shop in SCENARIOS:
        if wanted in shop.name:
            print(f"\n=== {shop.name}")
            result = median_of_runs(shop, seeds)
            show(result)
            summary.append(summary_line(shop.name, result))
    if summary:
        print("\n=== SUMMARY (medians over seeds; C/U/R/E in percent)")
        print(f"{'scenario':<58} {'d/c90':>5} {'d/c365':>5} {'money90':>7} {'money365':>6} {'arc90/wk':>6} {'arc365':>6} {'slot':>4} "
              f"{'divert90':>11} {'divert365':>11} {'above365':>11} {'arbitr365':>11} {'R d90':>5} {'E d90':>5} {'direct':>5} {'share':>5}")
        print("\n".join(summary))
    if wanted in "PROD":
        print("\n=== PROD one-off slot spending today: 5 players at 5 goals, median wallet 965, assumed standard income 200")
        for label, prices in [("flat 500", (500,) * 5), ("flat 1,000", (1000,) * 5), ("flat 2,000", (2000,) * 5),
                              ("rising 500/1k/2k/3k/5k", GOALS), ("doubling 500..8k", (500, 1000, 2000, 4000, 8000)),
                              ("rising 250/500/1k/2k/3k", (250, 500, 1000, 2000, 3000))]:
            for days in (1.5, 3.0, 6.0):
                for income in (150.0, 300.0):
                    spent, first = production_slots(prices, days, income)
                    print(f"{label:<24} worth {days:>3} days, income {income:>3.0f}: {spent:>6.0f} PiCoins absorbed once, {first:.1f} of 5 buy a 6th goal")


if __name__ == "__main__":
    main()
