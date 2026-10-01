# Catalog and rarity

Referenced by CAP-2, CAP-3, CAP-4.

## Card identity

- One card per Wikidata entity whose French Wikipedia article passes the filters. The text shown comes from French Wikipedia.

## Inclusion

- **Excluded:** non-topic pages (disambiguation, lists, years, timelines, portals).
- **Kept:** a subject covered by ≥ 10 Wikipedia language editions (Wikidata sitelinks) **or** with ≥ 1,000 monthly French Wikipedia pageviews.
- **Target size:** ~100k–300k cards. Thresholds are tuned on real data.

## Rarity

- **5 rarity tiers.**
- **Base tier:** the number of Wikipedia language editions covering the subject. More editions means a rarer tier.
- **Boost:** +1 tier for subjects with high French pageviews, so French niches can rise.
- **Player-facing rule:** "The more famous a subject is worldwide, the rarer its card."
- **Not a rarity input:** article-quality labels ("Article de qualité", "Bon article"). They only give a foil variant in V3.

## Draw

- Pick a rarity tier with fixed per-tier odds, then pick a card uniformly within that tier. Catalog size never dilutes the top tiers.
- **Starting point for odds:** ~70% common, ~20% rare, with the higher tiers sharing the remainder. Odds are tuned in playtests.

## Families

About a dozen families, derived from the Wikidata nature of each subject (e.g. instance-of). Each family has its own colour and pictogram:

People · Places & monuments · Film & TV · Literature · Music · Video games · Animals · Nature · History & events · Science · Sport · Brands & objects
