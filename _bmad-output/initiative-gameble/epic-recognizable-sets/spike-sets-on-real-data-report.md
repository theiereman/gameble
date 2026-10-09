# Sets on real data — spike report

Measured on 2026-10-09 on staging's published season 2: 12,329 card-seasons joined to their `steam_apps` row. The join is inner; the rarity sizes sum to the same 12,329, so no card was left out. Tags and review counts are read from `steam_apps`, which holds the latest import: run 3 finished on 2026-10-09, after season 2's publication on 2026-10-08. They may differ slightly from the season's snapshot, and `catalog_cards.tags` drops tags unknown to `steam_tags` where the probes read `tag_ids` raw. The probes are read-only (`while_preventing_writes`) and sit in `spike-sets-on-real-data-probes/`. To rerun one: `ssh -p 2224 root@gameble.dotsncircles.com 'docker exec -i $(docker ps -q --filter label=service=gameble --filter label=role=web | head -1) bin/rails runner -' < probe-N.rb`.

Rarity sizes of the season: Commune 7,397, Peu commune 3,082, Rare 1,233, Épique 493, Légendaire 124.

## 1. Developers and franchises in `steam_apps.details`

Confirmed: both sit in `details->'basic_info'`, as lists of `{ "name": … }`.

| Field | Cards with it | Notes |
|---|---|---|
| developers | 12,311 (99.9 %) | 1,224 games name several; 48 games have a name with `&amp;` (other entities not counted) |
| franchises | 2,688 (21.8 %) | 270 games name several; 35 games have a name with `&amp;` |

Story 2 can read both from the stored item. It must unescape HTML entities and strip whitespace.

## 2. Franchises

Steam's franchise field is noisy. Many entries are a publisher's page ("EA Play" 83, "GrabTheGames Publishing" 20, "Team17 Digital" 17, "PlayWay S.A." 12, "WB Games" 9) or a cross-promotion between unrelated games ("Elf Shift": Clothing Store Simulator / Estate Agent Simulator / Supercar Collection Simulator).

Two filters were tried, together:
- **Not a company:** the franchise's normalized name is not the name of any developer or publisher in the catalog.
- **Titles:** more than half of its games' titles contain a word of its name, at least 3 letters long and not a stopword. The probe tests a substring ("war" matches "Warhammer"); story 3 should match whole words, and the counts may move.
- Franchises are grouped by their raw name, so case or suffix variants ("FINAL FANTASY", "Tom Clancy Franchise") were not merged; merging them may also move the counts.

| Filter | min 2 | min 3 | min 4 |
|---|---|---|---|
| none | 511 sets / 1,834 cards | 259 / 1,398 | 163 / 1,153 |
| both filters | 375 / 1,359 | **188 / 1,009** | 115 / 805 |

Kept, top: Warhammer 45, Star Wars 32, FINAL FANTASY 29, Call of Duty 20, Tom Clancy 19, Assassin's Creed 17, Tomb Raider 17, Total War 16, Resident Evil 16, Sonic 14, Five Nights at Freddy's 11, Fallout 10, Metal Gear 10. A random sample of the kept sets reads as real series (Hitman, Risen, Psychonauts, Silent Hill, Ace Attorney, Hearts of Iron, Frog Detective).

Known misses, for story 3 to fix:
- **Wrongly dropped:** "Ys" (a 2-letter name; a one-word name should accept short words), "WatchDogs Franchise" ("Watch_Dogs" in the titles), "Science Adventure Series", "World of Darkness", "Yu-Gi-Oh!".
- **Wrongly kept:** cross-promotions that share a generic word ("Table Battle Simulator", "Estate Agent Simulator"). Add "simulator" to the stopwords.
- **Name suffixes:** strip " Franchise", " Series" and " - Official" from the displayed name ("Tom Clancy Franchise" → "Tom Clancy").

Even a small franchise is slow to complete with packs alone. The median for 3 Communes (Supreme Commander) is about 2,900 packs; for Fallout (10 cards, 2 Épiques), about 12,600.

**Proposal:** minimum **3** games, both filters applied, plus the fixes above: about 188 sets covering 8 % of the cards.

## 3. Studios

The raw names split one studio into several ("CAPCOM Co., Ltd." and "Capcom") and give porting houses their own sets ("Feral Interactive (Mac)", "Aspyr (Mac)"). The probe normalizes the names: legal words (Co, Ltd, Inc, S.A., KK…, wherever they stand), platform in brackets and case are dropped. The notoriety floor in the table below is the review count of the studio's most-reviewed game.

| Rule (min 3 games) | no floor | floor 10k | floor 20k | floor 50k |
|---|---|---|---|---|
| every developer | 1,004 sets / 4,807 cards | 460 / 2,654 | 311 / 1,871 | 176 / 1,193 |
| first developer only | 876 / 4,525 | **389 / 2,439** | 254 / 1,684 | 136 / 1,044 |

- **Without a floor:** about 900 studios, most of them unknown ("Quiet River", "DSGame", "Home Net Games").
- **With the 20k floor:** recognized studios are dropped too: Frogwares (12 games), Nightdive Studios (10), Wadjet Eye Games (8), Stardock Entertainment (6).
- **First developer only:** drops the porting houses, which come second.

**Proposal:** the first developer only, names normalized, at least **3** games, and a floor of **10,000** reviews on the studio's most-reviewed game: about 389 sets covering 20 % of the cards. The floor goes beyond the spec ("at least N games").

**Agreed (author):** the first developer only, names normalized, at least 3 games, floor **20,000**: about 254 sets covering 14 % of the cards.

## 4. Themes and the UFOs

Rule as specified: a game joins every listed theme among its 5 most-voted tags; tags without a theme are ignored. One theme may group several Steam tags (Roguelike = Roguelike, Roguelite, Action Roguelike, Traditional Roguelike).

- **Draft of 35 themes** (most of today's `Steam::GenreTags` plus the spec's examples, grouped; Simulation and Third-person shooter were tested as optional groups, and Arcade was left out as broad): the UFOs are **1,528 cards (12.4 %)**.
- **Optional groups, added one at a time:**

| Added | UFOs after |
|---|---|
| Simulation (+400) | 9.1 % |
| Comedy (+154) | 7.9 % |
| Adult (+140) | 6.8 % |
| Open world (+109) | 5.9 % |
| Third-person shooter (+60) | 5.4 % |
| Idle (+50) | 5.0 % |
| Female protagonist (+48) | 4.6 % |
| Walking simulator (+39) | 4.3 % |
| VR (+34) | 4.0 % |

- **Every optional group except Adult:** 466 UFOs (3.8 %), but with 52 themes.
- **Adult content:** **895 cards (7.3 % of the catalog)** carry Sexual Content, Nudity or Hentai among their top 5 tags. 194 of them are UFOs. The catalog keeps them today; no spec line covers them.
- **The remaining UFOs** hold only broad tags (Indie, Action, Adventure, Casual, Free to Play) or adult tags: Undertale, Hotline Miami 2, Coloring Game, UBERMOSH.

Agreed list: **42 themes**, with an Adult theme (the author's choice over excluding those games). The English / French names below are proposals for story 3's locale files. The exact Steam tags of each theme are the `themes` hash of `probe-3.rb`, which is authoritative; the table only hints at the groupings. Every tag name resolved against `steam_tags` ("names not found: []").

| | | |
|---|---|---|
| Souls-like / Souls-like | Metroidvania / Metroidvania | Roguelike / Roguelike (4 tags) |
| Deckbuilder / Deckbuilding (5 tags) | Cosy / Cosy (Cozy, Wholesome, Relaxing, Life Sim) | Farming / Vie à la ferme |
| Horror / Horreur (+ Lovecraftian) | Zombies / Zombies | Pirates / Pirates |
| Space / Espace | Cyberpunk / Cyberpunk | FPS / FPS (4 tags) |
| Third-person shooter / Tir à la troisième personne | Platformer / Plates-formes (5 tags) | Puzzle / Réflexion |
| Racing / Course | Sports / Sport | Strategy / Stratégie (6 tags) |
| RPG / RPG (7 tags) | Survival / Survie | City builder / City builder (+ Colony Sim, Base Building) |
| Visual novel / Visual novel | Point & click / Point & click | Fighting / Combat |
| Stealth / Infiltration | Rhythm / Rythme | Shoot 'em up / Shoot 'em up |
| Hack and slash / Hack and slash | Post-apocalyptic / Post-apocalyptique | War / Guerre |
| Medieval / Médiéval | Anime / Anime | Sandbox / Bac à sable |
| Tower defense / Tower defense | Mystery / Enquête | Simulation / Simulation (+ Management, Economy, Cooking…) |
| Comedy / Humour | Open world / Monde ouvert | Idle / Idle |
| Walking simulator / Walking simulator | VR / Réalité virtuelle | Adult / Adulte (Sexual Content, Nudity, Hentai) |

Measured with this list (probe 3): **536 UFOs, 4.35 %**. A few themes can go and stay under 5 %, but not down to about thirty. Without VR the share is 4.62 %; without VR and Walking simulator, 4.95 %; dropping Idle as well, 5.35 %. Removing one small theme (Farming, Pirates, Tower defense) costs under 0.1 point each; removing RPG, Horror or FPS costs 2.6 to 3.6 points.

The list departs from the spec in two ways. It holds 42 themes where the spec says about thirty. Simulation, Open world and Comedy are wide tags the probes first classed as broad, while the spec names only Action, Adventure, Casual and Indie as broad. Under R4, cards whose genre is `arcade` today lose it.

Theme sizes are uneven: RPG 2,084, Simulation 2,029, Strategy 1,842, Horror 1,256, Visual novel 1,105 cards; Cyberpunk 106, Pirates 48.

## 5. Hall of fame

Review counts: median 1,644; p90 16k; p99 174k; the minimum is 500, the import's floor. Score: 8,403 cards at 80 % or more; 1,560 Mixed (40–69 %); 92 under 40 %.

| Set | Proposed rule | Cards | Rarities (C/PC/R/É/L) |
|---|---|---|---|
| Les Intouchables | ≥ 97 % and ≥ 20,000 reviews | 90 | 41 / 0 / 0 / 24 / 25 |
| Les Pépites | ≥ 98 % and < 1,000 reviews | 87 | 4 / 83 / 0 / 0 / 0 |
| Les Mal-aimés | 40–69 % and ≥ 20,000 reviews | 92 | 20 / 42 / 24 / 4 / 2 |
| Les Phénomènes | ≥ 200,000 reviews | 104 | 51 / 1 / 2 / 7 / 43 |

Each set is about 90 to 100 cards. Alternatives measured:
- Intouchables at ≥ 96 % and ≥ 50k: 91 cards.
- Pépites at ≥ 97 % and < 1,000: 165.
- Mal-aimés at ≥ 10k: 170.
- Phénomènes at ≥ 300k: 60.

**Anomaly: season 2 mixes two prestige formulas.** The rarities are bimodal in the two popular sets: 41 of the 90 Intouchables and 51 of the 104 Phénomènes are **Communes**, almost none Peu commune or Rare (none among the Intouchables, 3 among the Phénomènes). Probe 3 found the cause.
- **The low scores are the old formula's.** Counter-Strike 2 scores 0.92, Stardew Valley 1.04, Terraria 1.03. That is Wilson + 0.01 × log10(count), the earlier formula, where the current one (log10 + 4 × Wilson) gives 6 to 10.
- **Effect on the tiers:** the Commune tier spans scores 0.18 to 6.46, so every card still on the old formula sits in it. Among the games with at least 200,000 reviews, 51 store a score below log10(review count) alone, which the current formula cannot give.
- **Not measured:** how far it reaches beyond those games. The current formula never gives less than log10(500) ≈ 2.70, so counting the cards scored below that would size it. The 4 Commune Pépites suggest it reaches smaller games too.
- **Not visible here:** `prestige_score_version` does not exist on staging's database, so the probe cannot tell which cards were scored by which formula.

The hall of fame rules above stand: they read review counts and score percentages, not rarities. Once rarities are right, Les Intouchables and Les Phénomènes get much **slower**: their roughly 45 to 50 Communes become Épiques and Légendaires, so even 10 % of them means drawing several given high-rarity cards (thousands of packs). Logged in `deferred-work.md`.

## 6. Tiers: packs to bronze, silver and gold

Simulated with the published odds (a tier, then a card uniformly within it), regular 5-card packs only, median of 31 runs. The daily bonus pack and the weekly goal's reward pack are left out, so the figures are slightly pessimistic for sets rich in Rares and better:

| Set | 25 % | 50 % | 100 % |
|---|---|---|---|
| any group measured by probe 2 (48 to 2,084 cards) | 610–850 packs | 1,580–2,160 | 24,000–165,000 |
| Les Pépites (87) | 925 | 2,116 | 14,575 |
| Les Mal-aimés (92) | 908 | 2,498 | 68,682 |
| Les Intouchables (90) | 1,292 | 4,492 | 172,394 |
| Les Phénomènes (104) | 1,161 | 4,214 | 187,376 |

Findings:
- **Size does not matter:** the share of a theme a player holds is close to the share of the catalog they have drawn. Bronze costs about 700 packs whether the theme has 48 cards or 2,000.
- **Simultaneous tiers:** with percentages, a player crosses bronze on most themes in the same few days, then silver the same way. "EN COURS" sorted by closeness would show near-equal bars.
- **Gold at 100 % is out of reach through packs:** it needs every Légendaire of the set, and one given Légendaire costs about 50,000 packs. Only trades can get there.
- **Pace:** a pack every 10 minutes and a bank of 10. A player who opens about 30 packs a day reaches 25 % in about 3–4 weeks and 50 % in about 2 months. For 10 % of a theme, about 200 packs, roughly a week: a closed-form estimate, not simulated.

**Agreed (author):** bronze **10 %**, silver **25 %**, gold **50 %** of a theme's or hall of fame set's distinct cards.
- **Themes,** at about 30 packs a day: roughly a week, a month and two months.
- **Les Pépites and Les Mal-aimés:** slower, since 50 % takes 2,100 to 2,500 packs.
- **Les Intouchables and Les Phénomènes:** 50 % takes about 4,200 to 4,500 packs (about 5 months), even with today's broken rarities, and more once fixed.

Percentages keep the simultaneous tiers above; that stays open (`deferred-work.md`).

## Decisions (author, 2026-10-09)

- Developers and franchises are read from `details->'basic_info'`, HTML entities unescaped.
- Franchises: at least 3 games; dropped when named like a developer or publisher of the catalog, or when no more than half of their games' titles share a whole word of their name; the fixes listed in section 2 apply. About 188 sets.
- Studios: the first developer only, names normalized, at least 3 games, the most-reviewed game with at least 20,000 reviews. About 254 sets.
- Themes: the 42 themes of `probe-3.rb`, Adult included; UFOs 4.35 %.
- Hall of fame: Les Intouchables ≥ 97 % and ≥ 20,000 reviews; Les Pépites ≥ 98 % and < 1,000 reviews; Les Mal-aimés 40–69 % and ≥ 20,000 reviews; Les Phénomènes ≥ 200,000 reviews.
- Tiers: 10 %, 25 %, 50 %.
