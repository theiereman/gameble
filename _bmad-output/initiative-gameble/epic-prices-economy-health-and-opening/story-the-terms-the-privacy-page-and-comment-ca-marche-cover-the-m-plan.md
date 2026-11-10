---
title: 'The terms, the privacy page and Comment ça marche cover the market'
type: 'feature'
ticket: '9'
created: '2026-11-10'
status: 'draft'
baseline_revision: 'a159c212dc2bd7ff6358b8173105d7665bb8a19c'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The legal page says "nothing is bought, nothing is sold" and that cards "have no value", which stops being true once cards sell at auction for PiCoins. It forbids no real-money trading of cards or PiCoins, names none of the market's data, and says nothing of what deletion does to a balance. Comment ça marche says nothing of the market. The market cannot open (AD-50 confirmation) until the terms carry the real-money clause.

**Approach:** Copy and one small read path. The legal page gains the real-money clause and a PiCoins clause, rewords the two clauses that would turn false, names the market's data, purposes, retention and deletion effects, and its updated date moves. Comment ça marche gains a market section shown only once the market has first opened, its numbers read from the settings version in force.

## Boundaries & Constraints

**Always:**
- French first in `config/locales/fr.yml`, then `en.yml` (AI-translated from the French, same meaning); every string in both. French uses a literal U+202F before `: ; ? !` and inside « ». New `<li>` and `<p>` carry a class so tests can find them.
- The terms and the privacy copy are always shown, market open or not (the legal conditions must hold before the opening); only the Comment ça marche market section waits for the first opening, and it stays once shown, even while the market is closed again (`MarketState#first_opened?`).
- The market section's numbers come from the settings version in force (`Game::Market::CurrentSettings`), never typed into copy. Amounts are integers shown exact, never with a euro sign. Words follow `market-economy.md`: PiCoin, 100-6-Tron, Archives, "confier" / "entrust", Timbre Fiscal du Gamebler / Gamebler's Tax Stamp, Effort de la Confrérie / Brotherhood Effort, Mon maximum / My maximum (never "automatic").
- The page stays a GET that writes nothing, open to visitors and players alike, and its Markdown negotiation keeps working (the section is plain HTML).
- Existing legal sentences stay except the two reworded below; the "Last updated" date becomes 10 November 2026.

**Never:** a market settings change, a new page or route, a migration, a Steam call, copy that names a planning id, a "market suspended" banner, entrusting or auction behaviour, the export or deletion code themselves (other stories build them; this story only names them), a euro or dollar sign, CSS beyond the one table modifier.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Legal page, any state | visitor or player, market never opened, French or English | terms carry the real-money clause and the PiCoins clause; privacy names the market's data, purposes, retention and what deletion does; updated 10 November 2026 | No error expected |
| How it works before the opening | no settings version, or one with `first_opened_at` nil | no market section, no market heading | No error expected |
| How it works after the first opening | settings version with `first_opened_at` set, open or closed | market section after "Completing a set": PiCoins and entrusting, rarity table, stamp and commission, auction and My maximum | No error expected |
| Settings changed by an administrator | a newer version with another commission, increment or durations | the section shows the newer version's values | No error expected |
| Markdown request | `Accept: text/markdown` after the opening | the section is in the Markdown body | No error expected |
| Settings table empty | `CurrentSettings` nil (should not happen after a deploy) | treated as never opened | No error expected |

</frozen-after-approval>

## Code Map

- `app/views/pages/legal.html.erb` -- terms `<ol>` (`terms.free` .. `terms.law`), privacy lists: stored, purposes, retention (`.legal__retention`, followed by the deletion `<p>` the existing tests target with `.legal__retention + p`), rights; add the new items and one paragraph here.
- `config/locales/fr.yml` (`pages.legal` at ~340, terms ~352, privacy ~364, `how_it_works` at ~431, `completion` ~533) and `config/locales/en.yml` (`pages.legal` at ~2514, `terms.no_money` ~2709, `how_it_works` ~2378) -- fr.yml is one quoted line per key; en.yml is i18n-tasks normalized (alphabetical, folded): after adding keys run `bundle exec i18n-tasks normalize` and check the diff holds only the new keys.
- `app/views/pages/how_it_works.html.erb` -- sections as `PanelComponent` panels with `how-it-works__*` classes; add the conditional render of the market section after `completion`.
- `app/helpers/how_it_works_helper.rb` -- `share_percent`, `rarity_shares`, `odds_rows`; add the market formatting helpers (public methods; `share_percent` stays private).
- `app/helpers/picoins_helper.rb` -- `picoins(amount)` exact form with thousands separators; reuse.
- `app/controllers/pages_controller.rb` -- `how_it_works` action (`authorize :page, :show?`, markdown negotiation); add the read of the published rules.
- `app/domains/game/app/models/game/market/market_state.rb`, `current_settings.rb`, `settings.rb` (`entrustment(rarity)`, `stamp(rarity)`, `minimum_price(rarity)`, `commission_basis_points`, `daily_cap`, `duration_short_hours`, `duration_medium_hours`, `duration_long_hours`, `increment_basis_points`, `soft_close_seconds`, `unusual_maximum_multiple`) and `starting_settings.rb` -- what the section reads.
- `app/domains/game/app/queries/game/market/entrustable_copies.rb` -- shape of a market query on the reading role, a model for the new one.
- `app/domains/catalog/app/models/catalog/rarity.rb` -- `TIERS` (1..5 to common..legendary), the same names as the settings columns.
- `app/frontend/styles/settings-pages.css` (319 lines) -- `.how-it-works__odds` table styles (`max-width: 420px`); one modifier for the wider table.
- `test/controllers/pages_controller_test.rb` -- legal tests: retention count `11` asserted at ~722 and ~731, updated date asserted at ~707, ~767 and ~772; deletion paragraph test at ~738 requires `"<list>, "` to stay in the deletion paragraph and the stored/deletion game-data terms to stay.
- `test/controllers/how_it_works_test.rb` -- French and English headings lists (`FRENCH_HEADINGS`, `ENGLISH_HEADINGS`, nine each) and the visitor tests; `test/controllers/markdown_negotiation_test.rb` (~71) for the Markdown page.
- `test/support/market.rb` -- `open_market!`, `close_market!`; `test/domains/game/market/market_state_test.rb` -- how a first opening is set in tests (`first_opened_at:`).

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/published_rules.rb` -- new query `Game::Market::PublishedRules.call`: nil unless `MarketState.call.first_opened?`, else a `Data` with the current version's entrustment, stamp and minimum price by rarity (hash keyed by rarity symbol), commission basis points, daily cap, the three duration hours (in order), preselected hours, increment basis points, soft-close seconds and the unusual-maximum multiple -- one read of `CurrentSettings` shared with the state; keeps the page free of model reads and of any number typed in copy.
- [ ] `app/controllers/pages_controller.rb` -- in `how_it_works`, `@market_rules = Game::Market::PublishedRules.call` before the markdown branch -- the view and the Markdown render both see it.
- [ ] `app/helpers/how_it_works_helper.rb` -- public `basis_points_percent(basis_points)` (via `share_percent(basis_points, 10_000)`, so 500 reads "5 %" in French and "5%" in English), `market_duration(hours)` (whole days from 48 hours up, else hours, through plural keys under `pages.how_it_works.market`), `market_rarity_rows(rules)` (tier, key, entrustment, stamp, minimum price in `Catalog::Rarity::TIERS` order, as the odds rows) and `soft_close_minutes(rules)` -- helper methods hold no business rule, only formatting.
- [ ] `app/views/pages/_market_rules.html.erb` -- new partial, a `PanelComponent` section `how-it-works-market` with classes `how-it-works__section`, heading `how-it-works__heading` and: the PiCoins paragraph (`how-it-works__picoins`: minted only when a card is entrusted, never bought or withdrawn, no value outside Gameble); the entrusting paragraph with the daily cap in exact PiCoins; a table `how-it-works__odds how-it-works__odds--market` with `data-market="rarities"` (columns Rareté, Confier rapporte, Timbre, Prix minimum, rows built like `_odds_table`, with the rarity icon and name; cells are bare exact numbers, the caption says PiCoins); the stamp and commission paragraph (`how-it-works__fees`); the auction paragraph (durations from the settings, buy-now optional); the "Mon maximum" list (`how-it-works__maximum`: whole maximum held and released when outbid, displayed price = second-highest maximum plus one increment capped at the highest, equal maximums the earlier leads, unusual-maximum confirmation, buy-now at once, soft close, raising one's own maximum while leading moves neither price nor end); the close paragraph (winner pays the price and recovers the surplus, seller receives the price less the commission, no bid returns the card and the stamp is not refunded).
- [ ] `app/views/pages/how_it_works.html.erb` -- `<%= render "pages/market_rules", rules: @market_rules if @market_rules %>` after the completion section.
- [ ] `app/frontend/styles/settings-pages.css` -- `.how-it-works__odds--market { max-width: none; }` with tighter cell padding on narrow widths so four columns fit a phone; run `npm run lint:css` and `npm run format:check`.
- [ ] `app/views/pages/legal.html.erb` -- terms: after `terms.no_property` add `<li class="legal__real-money">` (`terms.real_money`) and `<li class="legal__picoins">` (`terms.picoins`); stored: after `stored.activity` add `<li class="legal__stored-market">` (`stored.market`) and `<li class="legal__stored-signals">` (`stored.signals`); after `.privacy.visibility` add `<p class="legal__market-visibility">`; retention: after `retention.account` add `<li class="legal__retention-market">` and, after `retention.moderation`, `<li class="legal__retention-signals">`; after the deletion `<p>` add `<p class="legal__market-deletion">` -- every other line untouched, apart from the listed wording edits to `terms.no_money`, `terms.no_property`, `privacy.purposes.game`, `privacy.purposes.moderation` and `privacy.rights.access` (the only existing legal lines this story may change, besides the date); a test or reviewer must not reject those edits.
- [ ] `config/locales/fr.yml` (French first), then `config/locales/en.yml` -- the copy below, plus the `pages.how_it_works.market.*` keys for the partial (title, picoins, entrust, table caption and column heads, fees, auction, maximum items, close, plural `hours` and `days`; fr.yml carries `zero`, `one` and `other` for `hours` and `days`, en.yml `one` and `other`, so i18n-tasks and the French typography checks stay clean), written in the same register as the neighbouring sections (plain, "vous", a light Brotherhood touch only in the fee line). Legal copy:
  - `terms.no_money` (reworded; "nothing is sold" stays true) FR « Aucun argent réel n'y circule : rien ne s'y achète avec de l'argent, et les cartes se vendent contre des PiCoins, la monnaie du jeu, jamais contre de l'argent. » EN "No real money flows through it: nothing is bought with money, and cards are sold for PiCoins, the game's currency, never for money."
  - `terms.no_property` (reworded; the last sentence moves to the new clause) FR « Les cartes, capsules et dos de cartes sont des éléments du jeu : ils ne sont pas votre propriété et n'ont aucune valeur en argent, ni dans Gameble ni en dehors. Leur prix en PiCoins n'est qu'une règle du jeu. » EN "Cards, capsules and card backs are parts of the game: they are not your property and have no value in money, in Gameble or outside it. Their price in PiCoins is only a rule of the game."
  - `terms.real_money` FR « Il est interdit d'échanger des cartes ou des PiCoins contre de l'argent réel, dans Gameble ou en dehors : ni vente, ni achat, ni cession, ni intermédiaire. Un compte qui le fait peut être suspendu. » EN "Trading cards or PiCoins for real money is forbidden, in Gameble or outside it: no sale, no purchase, no transfer, no go-between. An account that does so may be suspended."
  - `terms.picoins` FR « Les PiCoins sont la monnaie du jeu : ils ne se gagnent qu'en confiant des cartes à la Confrérie ou en vendant aux enchères, ne s'achètent jamais et ne se retirent jamais. » EN "PiCoins are the game's currency: they are earned only by entrusting cards to the Brotherhood or by selling at auction, and they are never bought and never withdrawn."
  - `privacy.stored.market` FR « votre activité sur le marché : votre portefeuille de PiCoins (solde disponible et solde engagé), chaque mouvement de PiCoins, vos annonces, vos enchères avec les maximums que vous avez fixés, et vos notifications du marché ; » EN "your market activity: your PiCoin wallet (available and committed balance), every PiCoin entry, your listings, your bids with the maximums you set, and your market notices;"
  - `privacy.stored.signals` FR « des signaux de comptes multiples, calculés chaque jour à partir de votre activité de capsules, d'échanges, de ventes et d'enchères, que seul le personnel de modération consulte, et dont aucune décision n'est tirée automatiquement ; » EN "alt-account signals, worked out each day from your capsule, trade, sale and bid activity, which only the moderation staff read and from which no decision is taken automatically;"
  - `privacy.market_visibility` FR « Sur le marché, votre nom de profil figure sur vos annonces, dans l'historique des enchères où vous misez et dans les entrées du fil qui annoncent vos ventes, visibles de tous, y compris des visiteurs non connectés, quel que soit le réglage de votre profil. Vos maximums, eux, ne sont jamais montrés aux autres joueurs. » EN the same in English.
  - `privacy.purposes.game` and `privacy.purposes.moderation`: insert "marché" / "market" in the first list and "signaux de comptes multiples" / "alt-account signals" in the second, nothing else changed.
  - `privacy.retention.market` FR « votre portefeuille, vos mouvements de PiCoins, vos annonces, vos enchères et vos notifications du marché : tant que le compte existe ; à la suppression du compte, les notifications du marché et les entrées du fil qui annoncent vos ventes sont supprimées, votre nom est effacé des historiques d'enchères et le solde est détruit, mais le registre des PiCoins reste, sans identité, tant que le jeu existe ; » EN "your wallet, your PiCoin entries, your listings, your bids and your market notices: as long as the account exists; when the account is deleted, the market notices and the feed entries announcing your sales are deleted, your name is erased from the bid histories and the balance is destroyed, but the PiCoin record stays, without identity, as long as the game exists;". `privacy.retention.signals` FR « les signaux de comptes multiples : remplacés chaque jour, ils ne gardent que les faits du dernier calcul ; » EN "alt-account signals: replaced every day, they keep only the facts of the latest calculation;". The retention list goes from 11 to 13 items.
  - `privacy.market_deletion` FR « Sur le marché, la suppression de votre compte supprime vos notifications du marché et les entrées du fil qui annoncent vos ventes, efface votre nom des historiques d'enchères, retire vos annonces en cours et libère vos maximums. Votre solde de PiCoins est détruit sans remboursement, une fois vos annonces et vos enchères en tête réglées. Le registre des PiCoins est conservé sans identité, pendant la durée indiquée plus haut. » EN "On the market, deleting your account deletes your market notices and the feed entries announcing your sales, erases your name from the bid histories, withdraws your open listings and releases your maximums. Your PiCoin balance is destroyed without refund, once your listings and leading bids are resolved. The PiCoin record is kept without identity, for the period stated above."
  - `privacy.market_deletion` must not say the name is erased from notifications: the notices are deleted outright, not anonymised.
  - `privacy.rights.access` (unconditional): after the Steam library words add FR « , ainsi que vos données du marché : votre portefeuille, vos mouvements de PiCoins, vos annonces et vos enchères avec vos propres maximums » and EN ", and your market data: your wallet, your PiCoin entries, your listings and your bids with your own maximums". These are the data the export covers (wallet, PiCoin entries, listings, bids with the player's own maximums; the spec's Market and personal data constraint and the architecture's export decision). Keep the `<list>` Steam-library words in the line, since the existing deletion/access test targets them.
  - `pages.legal.updated`: FR « Dernière mise à jour : 10 novembre 2026 », EN "Last updated: 10 November 2026".
- [ ] `test/domains/game/market/published_rules_test.rb` -- nil with no version and with a never-opened version; the starting values after `open_market!(first_opened_at: ...)`; a newer version's changed commission and increment are returned; still returned when `close_market!`.
- [ ] `test/controllers/how_it_works_test.rb` -- visitor in French and a player in English: no market section before the opening (headings list unchanged, ten headings after); after the opening the section shows the rarity table rows equal to the settings (entrustment, stamp, minimum price for the five rarities, computed from `Game::Market::Settings` in the test, not through the helper), the commission and increment percents, the durations, the soft-close minutes, the daily cap; a changed settings version changes the numbers; a closed market after a first opening still shows it; add the market heading to both headings lists used after the opening.
- [ ] `test/controllers/pages_controller_test.rb` -- legal page, both locales: the real-money clause and the PiCoins clause exact text, the two reworded terms, the stored market and signals items, the visibility and deletion paragraphs, both new retention items with the count updated 11 to 13, the signals "replaced every day" line, the new date (lines ~707, ~767, ~772), the market data present with the market never opened; the deletion wording (market notices and sale feed entries deleted, name erased from bid histories, balance destroyed without refund once listings and leads are resolved) in `privacy.market_deletion` and `retention.market` asserted by text, and a negative assertion that the market deletion paragraph does not say the name is erased from notifications; `privacy.rights.access` carries both the Steam library words and the market data words (wallet, PiCoin entries, listings, bids with your own maximums), in both locales; existing tests (game-data terms, Steam library, deletion `"<list>, "`) still pass.
- [ ] `test/system/market_rules_pages_test.rb` -- new small system test class using `MarketSettings` from `test/support/market.rb`, a visitor, no sign-in: `visit legal_path(locale: :en)` asserts the real-money clause (`.legal__real-money`) and the market deletion paragraph (`.legal__market-deletion`) with retrying Capybara matchers; then at phone width (resize the window as `card_trade_test.rb` does, restoring it in `ensure`) `open_market!(first_opened_at: Time.current)`, `visit how_it_works_path(locale: :en)`, `assert_selector "[data-market='rarities'] tbody tr", count: 5` and a retrying check that the table fits: `eventually("the market table fits the page") { page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth") }`; then `close_market!` is not needed. It makes the phone-width and legal verification real instead of matching no test.
- [ ] `test/controllers/markdown_negotiation_test.rb` -- the Markdown how-it-works body carries the market heading after the opening and not before.

**Acceptance Criteria:**
- Given a visitor, when they open the legal page in French or English with the market never opened, then the terms forbid trading cards or PiCoins for real money and say PiCoins are never bought or withdrawn, and no clause still says cards have no value or that nothing is sold in a way the market makes false.
- Given the privacy section, when read in either language, then it names the wallet, the PiCoin entries, listings, bids with the player's own maximums, market notices and the staff-only alt-account signals with their purposes, says deletion forfeits the balance and erases the name from bid histories while the PiCoin record stays without identity, and says the signals are replaced every day.
- Given the market has never opened, when anyone opens Comment ça marche, then the page is exactly the nine sections it has today.
- Given the market has opened at least once, when anyone opens Comment ça marche, then a market section explains PiCoins and entrusting, the stamp and the commission, an auction and My maximum, with the numbers of the settings version in force.
- Given an administrator changes the commission, when the page is read next, then it shows the new value.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

The gate is the first opening, not the market being open: a suspended market keeps its rules readable, as the readable listings do (AD-50). The query returns the rules or nil so the view never decides, and the numbers are the version's, so the page cannot drift from what `ChangeSettings` applies. Table cells hold bare numbers under a caption that says PiCoins, to fit a phone.

```erb
<%= render "pages/market_rules", rules: @market_rules if @market_rules %>
```

Decisions settled without a human checkpoint, each the choice closest to the spec, architecture and UX:
- The terms and privacy clauses are shown from this release on, not gated: the opening requires the terms to carry the clause (AD-50), and wallets and ledger rows exist as soon as the market code deploys.
- The "no real money" clause is a new term (`terms.real_money`) beside the PiCoins term instead of folding into `no_property`, so the prohibition reads on its own and a test finds it.
- The market's names in bid histories are said to be visible to visitors, since the market and the Annonce are readable signed out (EXPERIENCE, Signed-out visitors); the maximums stay private except as the market-economy known limits state.
- The alt-account signals are named in the privacy section as staff-only data with no automatic decision, matching `purposes.no_automation`.
- The access right names the market data unconditionally (wallet, PiCoin entries, listings, bids with the player's own maximums): the export story in epic 40 fixes exactly those data and the spec says the privacy pages name them.
- Deletion copy follows the architecture: market notices and the player's sale feed entries are deleted outright, the name is erased from bid histories, the balance is destroyed without refund once listings and leading bids are resolved; the copy never says the name is erased from notifications.
- The only existing legal lines this story may change, besides the date and the two terms reworded in the tasks, are `privacy.purposes.game`, `privacy.purposes.moderation` and `privacy.rights.access`, each by the insertion named in the tasks, plus the new stored, retention, visibility and deletion lines.
- French plural keys for hours and days carry `zero`, `one` and `other`.
- The date is the day the plan is written, 10 November 2026.

## Verification

**Commands:**
- `bin/rails test test/controllers/pages_controller_test.rb test/controllers/how_it_works_test.rb test/controllers/markdown_negotiation_test.rb test/domains/game/market/published_rules_test.rb test/config/french_typography_test.rb` -- expected: pass (run once at the end of the run, not by the build agent)
- `bin/rails test test/system/market_rules_pages_test.rb` -- expected: pass (a visitor reads the legal page and the market table at phone width)
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bundle exec i18n-tasks normalize` (diff limited to new keys), `script/check_planning_references`, `script/check_file_sizes`, `npm run lint:css`, `npm run format:check` -- expected: clean

**Manual checks (if no CLI):**
- Read both legal and Comment ça marche pages in French and English, before and after `open_market!` in the console, at phone width: the market table fits without horizontal scroll and no sentence contradicts another.
