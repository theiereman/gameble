#!/usr/bin/env python3
"""Agent-based sketch of the planned auction economy, one step per day, one year.

Run with: uv run --with numpy simulate_economy.py

Taken from the game: capsule size, rarity odds, catalog shares, 10-minute refill.
Assumed, and to be challenged: behaviour segments, churn, spend rates, demand weights.
Cards are modelled per rarity, not per title, so demand for one specific card is absent.
Read the results as directions and orders of magnitude, never as exact prices.
"""
import sys
from dataclasses import dataclass, replace

import numpy as np

CATALOG = 15_000
SHARES = np.array([0.60, 0.25, 0.10, 0.04, 0.01])
NCARDS = CATALOG * SHARES
ODDS = np.array([0.76, 0.19, 0.043, 0.0065, 0.0005])
CAPSULE = 5
DAYS = 365
MAX_PLAYERS = 40_000
RARITIES = ["common", "uncommon", "rare", "epic", "legendary"]

CASUAL, REGULAR, HARDCORE, ALT = 0, 1, 2, 3
ACTIVE_ODDS = np.array([0.30, 0.70, 0.95, 1.0])
SPEND_RATE = np.array([0.60, 0.50, 0.40, 0.0])
KEEP_DUPLICATES = np.array([0.30, 0.30, 0.15, 0.0])
DEMAND_WEIGHT = np.array([0.15, 0.20, 0.30, 0.25, 0.10])
UNITS_PER_DAY = np.array([5, 3, 2, 1, 1])


@dataclass(frozen=True)
class Rules:
    name: str
    destroy: tuple = (1, 3, 15, 75, 500)
    commission: float = 0.10
    stamp: tuple = (1, 1, 2, 5, 10)
    daily_destroy_cap: float | None = None
    joins_per_day: float = 25.0
    joins_stop_day: int | None = None
    alt_main_share: float = 0.0
    alts_per_main: int = 0
    alt_daily_transfer: float | None = None
    alt_needs_first_copies: bool = True
    legendary_flipper_share: float = 0.0
    capsules: tuple = (6.0, 10.0, 60.0, 10.0)
    min_price: tuple = (0, 0, 0, 0, 0)
    regulator: bool = False
    archive_multiple: float | None = None
    archive_rarities: tuple = (0, 1)
    archive_captive_share: float = 0.5
    first_copy_newcomer_share: float = 0.0
    newcomer_multiplier: float = 1.0
    newcomer_days: int = 30
    daily_bonus_band: float = 0.0


def unique_from_draws(drawn):
    return NCARDS * (1.0 - np.exp(-drawn / NCARDS))


def churn_hazard(tenure, kind):
    hazard = np.where(tenure < 30, 0.035, 0.004)
    return np.where(kind == ALT, 0.0, hazard)


def run(rules, seed):
    rng = np.random.default_rng(seed)
    kind = np.zeros(MAX_PLAYERS, dtype=int)
    joined = np.zeros(MAX_PLAYERS, dtype=int)
    alive = np.zeros(MAX_PLAYERS, dtype=bool)
    balance = np.zeros(MAX_PLAYERS)
    drawn = np.zeros((MAX_PLAYERS, 5))
    disposed = np.zeros((MAX_PLAYERS, 5))
    bought = np.zeros((MAX_PLAYERS, 5))
    listed = np.zeros((MAX_PLAYERS, 5))
    main_of = np.full(MAX_PLAYERS, -1)
    income_today = np.zeros(MAX_PLAYERS)
    income_average = np.zeros(MAX_PLAYERS)
    flips_legendaries = rng.random(MAX_PLAYERS) < rules.legendary_flipper_share

    destroy = np.array(rules.destroy, dtype=float)
    stamp = np.array(rules.stamp, dtype=float)
    commission = rules.commission
    destroy_cap = rules.daily_destroy_cap
    capsules_per_day = np.array(rules.capsules)
    min_price = np.array(rules.min_price, dtype=float)
    floor = np.maximum((destroy + stamp) / (1.0 - commission), min_price)
    price_estimate = floor * 2.0
    faucet_at_last_check = burned_at_last_check = 0.0
    archive_stock = np.zeros(5)
    legendary_sales = np.zeros(DAYS)
    burned_archive = 0.0
    gives_up_first_copies = rng.random(MAX_PLAYERS) < rules.first_copy_newcomer_share
    used = 0
    faucet = burned_commission = burned_stamp = 0.0
    snapshots = {}

    for day in range(DAYS):
        if rules.regulator and day and day % 30 == 0:
            burned = burned_commission + burned_stamp + burned_archive
            ratio = (burned - burned_at_last_check) / max(faucet - faucet_at_last_check, 1e-9)
            faucet_at_last_check, burned_at_last_check = faucet, burned
            if ratio < 0.6:
                destroy_cap = max((destroy_cap or 250.0) * 0.8, 30.0)
                commission = min(commission + 0.01, 0.15)
            elif ratio > 0.95 and destroy_cap is not None:
                destroy_cap = None if destroy_cap * 1.25 > 400.0 else destroy_cap * 1.25
                commission = max(commission - 0.01, 0.05)
            floor = np.maximum((destroy + stamp) / (1.0 - commission), min_price)

        joins = 0 if rules.joins_stop_day is not None and day >= rules.joins_stop_day else rng.poisson(rules.joins_per_day)
        for _ in range(min(joins, MAX_PLAYERS - used)):
            kind[used] = rng.choice([CASUAL, REGULAR, HARDCORE], p=[0.45, 0.42, 0.13])
            joined[used] = day
            alive[used] = True
            mine = used
            used += 1
            if kind[mine] == HARDCORE and rules.alts_per_main and rng.random() < rules.alt_main_share:
                for _ in range(rules.alts_per_main):
                    if used >= MAX_PLAYERS:
                        break
                    kind[used], joined[used], alive[used], main_of[used] = ALT, day, True, mine
                    used += 1

        leaving = alive & (rng.random(MAX_PLAYERS) < churn_hazard(day - joined, kind))
        alive[leaving] = False
        listed[leaving] = 0.0

        active = alive & (rng.random(MAX_PLAYERS) < ACTIVE_ODDS[kind])
        idx = np.flatnonzero(active)
        capsules = rng.poisson(capsules_per_day[kind[idx]])
        drawn[idx] += rng.poisson(capsules[:, None] * CAPSULE * ODDS)
        income_today[:] = 0.0

        unique_drawn = unique_from_draws(drawn[idx])
        duplicates = np.maximum(drawn[idx] - unique_drawn - disposed[idx], 0.0)
        spare = duplicates * (1.0 - KEEP_DUPLICATES[kind[idx]])[:, None]
        alts = kind[idx] == ALT
        if rules.alt_needs_first_copies:
            spare[alts] = np.maximum(drawn[idx][alts] - disposed[idx][alts], 0.0)
        flipping = flips_legendaries[idx] & ~alts
        spare[flipping, 4] = np.maximum(drawn[idx][flipping, 4] - disposed[idx][flipping, 4], 0.0)
        sacrificing = gives_up_first_copies[idx] & (day - joined[idx] < rules.newcomer_days) & ~alts
        spare[sacrificing, :2] = np.maximum(drawn[idx][sacrificing, :2] - disposed[idx][sacrificing, :2], 0.0)

        worth_listing = price_estimate * (1.0 - commission) - stamp > destroy * 1.2
        to_list = np.where(worth_listing, spare * 0.5, 0.0)
        to_list[alts] = 0.0
        to_destroy = np.where(worth_listing, 0.0, spare)
        to_destroy[alts] = spare[alts]

        stamp_cost = to_list @ stamp
        too_poor = stamp_cost > balance[idx]
        to_destroy[too_poor] += to_list[too_poor]
        to_list[too_poor] = 0.0
        stamp_cost[too_poor] = 0.0

        earned = to_destroy @ destroy
        earned *= np.where(day - joined[idx] < rules.newcomer_days, rules.newcomer_multiplier, 1.0)
        earned += np.minimum(earned, rules.daily_bonus_band)
        if destroy_cap is not None:
            scale = np.minimum(1.0, destroy_cap / np.maximum(earned, 1e-9))
            to_destroy = to_destroy * scale[:, None]
            earned = earned * scale

        balance[idx] += earned - stamp_cost
        income_today[idx] += earned
        disposed[idx] += to_destroy + to_list
        archive_stock += to_destroy.sum(axis=0)
        listed[idx] += to_list
        faucet += earned.sum()
        burned_stamp += stamp_cost.sum()

        alt_idx = np.flatnonzero(alive & (kind == ALT))
        if alt_idx.size:
            amount = balance[alt_idx].copy()
            if rules.alt_daily_transfer is not None:
                amount = np.minimum(amount, rules.alt_daily_transfer)
            live_main = alive[main_of[alt_idx]]
            amount = np.where(live_main, amount, 0.0)
            balance[alt_idx] -= amount
            np.add.at(balance, main_of[alt_idx], amount * (1.0 - commission))
            burned_commission += (amount * commission).sum()

        buyers = np.flatnonzero(active & (kind != ALT) & (balance > 0))
        unique_now = unique_from_draws(drawn[buyers]) + bought[buyers]
        missing = np.maximum(NCARDS - unique_now, 0.0)
        wants = DEMAND_WEIGHT * (missing >= 1)
        wants_total = wants.sum(axis=1, keepdims=True)
        chance = np.divide(wants, wants_total, out=np.zeros_like(wants), where=wants_total > 0).cumsum(axis=1)
        target = (chance < rng.random(buyers.size)[:, None]).sum(axis=1)
        willing = balance[buyers] * SPEND_RATE[kind[buyers]]

        for r in range(5):
            supply = listed[:, r].sum()
            who = np.flatnonzero((target == r) & (wants_total[:, 0] > 0))
            cap = np.minimum(np.floor(missing[who, r]), UNITS_PER_DAY[r])
            bids = willing[who]

            if rules.archive_multiple is not None and r in rules.archive_rarities and who.size and archive_stock[r] >= 1:
                archive_price = destroy[r] * rules.archive_multiple
                captive = rng.random(who.size) < rules.archive_captive_share
                goes_to_archive = captive | (archive_price <= price_estimate[r])
                units = np.where(goes_to_archive, np.minimum(np.floor(bids / archive_price), cap), 0.0)
                if units.sum() > archive_stock[r]:
                    units = np.floor(units * archive_stock[r] / units.sum())
                paid = units * archive_price
                balance[buyers[who]] -= paid
                bought[buyers[who], r] += units
                bids -= paid
                cap -= units
                archive_stock[r] -= units.sum()
                burned_archive += paid.sum()

            def demand(price):
                return np.minimum(np.floor(bids / price), cap).sum()

            if supply < 1:
                if who.size:
                    price_estimate[r] *= 1.10
                continue
            if who.size == 0 or demand(floor[r]) == 0:
                price_estimate[r] *= 0.90
                continue

            low, high = floor[r], max(bids.max(), floor[r])
            if demand(low) <= supply:
                price = low
            else:
                for _ in range(40):
                    middle = (low * high) ** 0.5
                    if demand(middle) > supply:
                        low = middle
                    else:
                        high = middle
                price = high

            units = np.minimum(np.floor(bids / price), cap)
            if units.sum() > supply:
                units = np.floor(units * supply / units.sum())
            sold = units.sum()
            if sold == 0:
                price_estimate[r] *= 0.90
                continue
            spent = sold * price
            if r == 4:
                legendary_sales[day] = sold
            balance[buyers[who]] -= units * price
            bought[buyers[who], r] += units
            share_sold = sold / supply
            proceeds = listed[:, r] * share_sold * price * (1.0 - commission)
            balance += proceeds
            income_today += proceeds
            burned_commission += spent * commission
            listed[:, r] *= 1.0 - share_sold
            price_estimate[r] = 0.8 * price_estimate[r] + 0.2 * price

        unsold_back = listed * 0.33
        listed -= unsold_back
        disposed -= unsold_back

        income_average[alive] = 0.9 * income_average[alive] + 0.1 * income_today[alive]

        if day + 1 in (30, 90, 180, 365):
            honest = alive & (kind != ALT)
            total = balance.sum()
            ranked = np.sort(balance[kind != ALT])[::-1]
            top_one_percent = ranked[: max(1, ranked.size // 100)].sum() / max(ranked.sum(), 1e-9)
            regulars = alive & (kind == REGULAR)
            median_income = np.median(income_average[regulars])
            tenure = day - joined
            newcomers = regulars & (tenure >= 7) & (tenure < 30)
            newcomer_income = np.median(income_average[newcomers]) if newcomers.any() else 0.0
            mains = np.unique(main_of[main_of >= 0])
            is_main = np.zeros(MAX_PLAYERS, dtype=bool)
            is_main[mains] = True
            honest_hardcore = alive & (kind == HARDCORE) & ~is_main
            snapshots[day + 1] = {
                "players": int(honest.sum()),
                "money_per_active": balance[honest].mean() if honest.any() else 0.0,
                "inactive_share": balance[~alive].sum() / max(total, 1e-9),
                "price": price_estimate.copy(),
                "income_day": median_income,
                "newcomer_income": newcomer_income,
                "days_of_income": price_estimate / max(median_income, 1e-9),
                "newcomer_days": price_estimate / max(newcomer_income, 1e-9),
                "burn_vs_faucet": (burned_commission + burned_stamp + burned_archive) / max(faucet, 1e-9),
                "archive_share_of_burn": burned_archive / max(burned_commission + burned_stamp + burned_archive, 1e-9),
                "top_1pct": top_one_percent,
                "legendary_sold_30d": legendary_sales[max(0, day - 29): day + 1].sum(),
                "legendary_listed": listed[:, 4].sum(),
                "main_rare_plus": bought[mains, 2:].sum(axis=1).mean() if mains.size else 0.0,
                "hardcore_rare_plus": bought[honest_hardcore, 2:].sum(axis=1).mean() if honest_hardcore.any() else 0.0,
            }
    return snapshots


def median_of_runs(rules, seeds=3):
    runs = [run(rules, seed) for seed in range(seeds)]
    result = {}
    for day in runs[0]:
        result[day] = {key: np.median([r[day][key] for r in runs], axis=0) for key in runs[0][day]}
    return result


BASE = Rules("roadmap: 10% commission, stamp, steep destroy values")
HEAVY_30 = replace(BASE, capsules=(6.0, 10.0, 30.0, 10.0))
CANDIDATE = replace(HEAVY_30, name="CAND base: deposit 1/2/5/15/100, proportional stamp, legendary minimum 420",
    destroy=(1, 2, 5, 15, 100), stamp=(0.1, 0.2, 0.5, 2, 10), min_price=(0, 0, 0, 0, 420))
FIT = replace(CANDIDATE, first_copy_newcomer_share=0.5)
REAL = replace(FIT, capsules=(10.0, 45.0, 100.0, 10.0), stamp=(0.1, 1, 2, 5, 10))
SCENARIOS = [
    BASE,
    replace(BASE, name="no fees at all (control)", commission=0.0, stamp=(0, 0, 0, 0, 0)),
    replace(BASE, name="commission 5%", commission=0.05),
    replace(BASE, name="commission 15%", commission=0.15),
    replace(BASE, name="flat destroy values 1/2/5/15/50", destroy=(1, 2, 5, 15, 50)),
    replace(BASE, name="launch spike: joins stop at day 90", joins_per_day=60.0, joins_stop_day=90),
    replace(BASE, name="alts: 30% of hardcore run 5 alts", alt_main_share=0.30, alts_per_main=5),
    replace(BASE, name="alts + daily destroy cap 100", alt_main_share=0.30, alts_per_main=5, daily_destroy_cap=100.0),
    replace(BASE, name="alts + cap 100 + transfer limit 20/day", alt_main_share=0.30, alts_per_main=5, daily_destroy_cap=100.0, alt_daily_transfer=20.0),
    replace(BASE, name="daily destroy cap 100, no alts", daily_destroy_cap=100.0),
    replace(BASE, name="legendary flippers 10%: sell every legendary pulled", legendary_flipper_share=0.10),
    replace(BASE, name="legendary flippers 30%: sell every legendary pulled", legendary_flipper_share=0.30),
    replace(BASE, name="legendary flippers 60%: sell every legendary pulled", legendary_flipper_share=0.60),
    replace(HEAVY_30, name="H30 base"),
    replace(HEAVY_30, name="H30 destroy cap 30", daily_destroy_cap=30.0),
    replace(HEAVY_30, name="H30 destroy cap 60", daily_destroy_cap=60.0),
    replace(HEAVY_30, name="H30 flat destroy 1/2/5/15/100", destroy=(1, 2, 5, 15, 100)),
    replace(HEAVY_30, name="H30 alts, no regulator", alt_main_share=0.30, alts_per_main=5),
    replace(HEAVY_30, name="H30 alts, regulator", alt_main_share=0.30, alts_per_main=5, regulator=True),
    replace(HEAVY_30, name="H30 no alts, regulator", regulator=True),
    CANDIDATE,
    replace(CANDIDATE, name="CAND archive shop x5 commons and uncommons", archive_multiple=5.0),
    replace(CANDIDATE, name="CAND newcomers give up first commons (half of them)", first_copy_newcomer_share=0.5),
    replace(CANDIDATE, name="CAND welcome rate x3 for 30 days", newcomer_multiplier=3.0),
    replace(CANDIDATE, name="CAND first 10 deposited each day paid double", daily_bonus_band=10.0),
    replace(CANDIDATE, name="CAND welcome x3 with alts, no regulator", newcomer_multiplier=3.0, alt_main_share=0.30, alts_per_main=5),
    replace(CANDIDATE, name="CAND welcome x3 with alts and regulator", newcomer_multiplier=3.0, alt_main_share=0.30, alts_per_main=5, regulator=True),
    replace(CANDIDATE, name="CAND all: welcome x3, shop x5, regulator, alts, 30% flippers", newcomer_multiplier=3.0, archive_multiple=5.0, regulator=True, alt_main_share=0.30, alts_per_main=5, legendary_flipper_share=0.30),
    replace(REAL, name="FLOOR none, flippers 30%", legendary_flipper_share=0.30),
    replace(REAL, name="FLOOR none, flippers 60%", legendary_flipper_share=0.60),
    replace(REAL, name="FLOOR 3500, flippers 30%", legendary_flipper_share=0.30, min_price=(0, 0, 0, 0, 3500)),
    replace(REAL, name="FLOOR 3500, flippers 60%", legendary_flipper_share=0.60, min_price=(0, 0, 0, 0, 3500)),
    replace(REAL, name="FLOOR 7000, flippers 30%", legendary_flipper_share=0.30, min_price=(0, 0, 0, 0, 7000)),
    replace(REAL, name="FLOOR 7000, flippers 60%", legendary_flipper_share=0.60, min_price=(0, 0, 0, 0, 7000)),
    replace(REAL, name="FLOOR 12000, flippers 30%", legendary_flipper_share=0.30, min_price=(0, 0, 0, 0, 12000)),
    replace(REAL, name="FLOOR 12000, flippers 60%", legendary_flipper_share=0.60, min_price=(0, 0, 0, 0, 12000)),
    replace(REAL, name="FINAL cap 1200, floor 7000, flippers 30%", daily_destroy_cap=1200.0, legendary_flipper_share=0.30, min_price=(0, 0, 0, 0, 7000)),
    replace(REAL, name="FINAL cap 1200, floor 12000, flippers 30%", daily_destroy_cap=1200.0, legendary_flipper_share=0.30, min_price=(0, 0, 0, 0, 12000)),
    replace(REAL, name="REAL base 45 capsules"),
    replace(REAL, name="REAL 40 capsules", capsules=(10.0, 40.0, 100.0, 10.0)),
    replace(REAL, name="REAL 50 capsules", capsules=(10.0, 50.0, 100.0, 10.0)),
    replace(REAL, name="REAL regulator", regulator=True),
    replace(REAL, name="REAL deposit cap 150", daily_destroy_cap=150.0),
    replace(REAL, name="REAL deposit cap 150 and regulator", daily_destroy_cap=150.0, regulator=True),
    replace(REAL, name="REAL values 1/5/20/80/400", destroy=(1, 5, 20, 80, 400)),
    replace(REAL, name="REAL regulator, 30% flippers", regulator=True, legendary_flipper_share=0.30),
    replace(REAL, name="REAL regulator, alts", regulator=True, alt_main_share=0.30, alts_per_main=5),
    replace(FIT, name="FIT base"),
    replace(FIT, name="FIT regulator", regulator=True),
    replace(FIT, name="FIT deposit cap 20", daily_destroy_cap=20.0),
    replace(FIT, name="FIT deposit cap 30", daily_destroy_cap=30.0),
    replace(FIT, name="FIT deposit cap 50", daily_destroy_cap=50.0),
    replace(FIT, name="FIT commission 15%", commission=0.15),
    replace(FIT, name="FIT stamp doubled", stamp=(0.2, 0.4, 1, 4, 20)),
    replace(FIT, name="FIT stamp spared on commons only", stamp=(0.1, 1, 2, 5, 10)),
    replace(FIT, name="FIT cap 30, stamp spared on commons", daily_destroy_cap=30.0, stamp=(0.1, 1, 2, 5, 10)),
    replace(FIT, name="FIT cap 30 with 30% flippers", daily_destroy_cap=30.0, legendary_flipper_share=0.30),
    replace(FIT, name="FIT cap 30 with alts", daily_destroy_cap=30.0, alt_main_share=0.30, alts_per_main=5),
    replace(FIT, name="FIT cap 30 with alts and regulator", daily_destroy_cap=30.0, alt_main_share=0.30, alts_per_main=5, regulator=True),
]


def main():
    np.set_printoptions(suppress=True, precision=1, linewidth=140)
    wanted = sys.argv[1] if len(sys.argv) > 1 else ""
    seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    for rules in SCENARIOS:
        if wanted not in rules.name:
            continue
        result = median_of_runs(rules, seeds)
        print(f"\n=== {rules.name}")
        for day, s in result.items():
            print(f"d{day:>3} players={s['players']:>6.0f} money/active={s['money_per_active']:>9.0f} "
                  f"median income/day={s['income_day']:>7.1f} newcomer={s['newcomer_income']:>6.1f} burn/faucet={s['burn_vs_faucet']:.2f} "
                  f"inactive={s['inactive_share']:.2f} top1%={s['top_1pct']:.2f} archive-burn={s['archive_share_of_burn']:.2f} legendary sold/30d={s['legendary_sold_30d']:.0f} listed={s['legendary_listed']:.0f}")
            print(f"     price {np.round(s['price'], 1)}  days-of-income {np.round(s['days_of_income'], 1)}  newcomer-days {np.round(s['newcomer_days'], 1)}")
        final = result[365]
        if final["main_rare_plus"] > 0:
            print(f"     rare-or-better bought: alt-running main {final['main_rare_plus']:.0f} vs honest hardcore {final['hardcore_rare_plus']:.0f}")


if __name__ == "__main__":
    main()
