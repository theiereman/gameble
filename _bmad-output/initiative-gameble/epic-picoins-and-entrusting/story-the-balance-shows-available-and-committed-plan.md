---
title: 'The balance shows available and committed'
type: 'feature'
ticket: '38.8'
created: '2026-11-10'
status: 'ready-for-dev'
baseline_revision: 'd6e400a8f01160a3801895026c1408242f9ffe2b'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/epic-picoins-and-entrusting.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A player who entrusts copies sees PiCoins minted on the result page and then nowhere: no screen shows what they hold, how much of it is available or committed to auctions, and nothing refreshes when it changes. Epic requirement R11.

**Approach:** Add a `Game::Market::Balance` query over the wallet, one shared Balance chip partial drawn with `PicoinAmountComponent` in compact form (available, a divider, "<amount> engagés"), shown before the bell on every signed-in desktop page and in the header of Confier on the phone, hidden for visitors and before the market's first opening. The chip is redrawn in the Confier answer and, through a balance notice added to `PlayerStream` and rendered by `PlayerStreamJob`, whenever `CardsEntrusted` commits.

## Boundaries & Constraints

**Always:** the wallet is read on the reading role through a query, zero and zero with no row; the chip needs the market's first opening (`MarketState#first_opened?`, still true while the market is suspended) and a signed-in player; amounts are compact, truncated and never rounded up, with the exact amount and "PiCoins" as accessible text through `PicoinAmountComponent`, and the committed text reads exact for assistive technology; "engagé" (singular) at 0 and 1 and "engagés" above in French, with a `zero` form; the chip is one partial rendered by the top bar and by the market screens' headers, and one inner partial redrawn by the stream; the stream path is `EntrustCards` event, `PlayerStream` notice, `AfterCommitBatch`, `PlayerStreamJob` after commit, a Turbo Stream the player's own channel receives in both locales; later events join by adding to `PlayerStream`, never a new job; every string in `en.yml` and `fr.yml`; server HTML carries no `style` attribute and no database id.

**Never:** a write from a GET or from the chip's query; a new job or channel; a second amount component or script that builds markup (the stream replaces server-rendered HTML); the chip for a visitor or before the first opening; the chip in the back-office or the native top bar (the apps' bar is a bridge component and is not part of this story); the market screen's own header (epic 39 renders the same partial); a banner or toast for a balance change; compact text without an exact accessible twin.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Balance, no wallet | A player who never entrusted, market opened | Query gives `Balance(0, 0)`; chip shows "0" and "0 committed" | No error expected |
| Balance read | Wallet 31,599 available, 12,000 committed | Visible "31.5k" and "12k committed"; accessible "31,599 PiCoins" and "12,000 committed" | No error expected |
| French small committed | Committed 0 or 1 | "0 engagé", "1 engagé"; 2 reads "2 engagés" | — |
| Desktop page | Signed in, market first opened (open or suspended) | The chip stands before the bell in the top bar | — |
| Phone Confier | Same, under 720px | Top-bar chip hidden; the same chip shows in Confier's header, both amounts always | — |
| Phone elsewhere | Same, any other page | No chip | — |
| Visitor | Signed out | No chip anywhere, no query | — |
| Before the opening | `first_opened_at` empty | No chip, wallet not read | — |
| After entrusting | Confier POST succeeds | The answer page renders the chip with the new available amount | — |
| Stream | `CardsEntrusted` commits | One `PlayerStreamJob` after commit; every open chip of that player is redrawn in the player's locale | Job skips a removed or missing player like every notice |
| Rolled back | `EntrustCards` fails after publishing | No job enqueued, no broadcast | `AfterCommitBatch` drops the batch |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/wallet.rb`, `ledger.rb` -- wallet row (`available`, `committed`, per player, unique) written only by `Ledger`; the query reads it.
- `app/domains/game/app/queries/game/market/cap_left.rb`, `current_settings.rb`, `minted_today.rb` -- model of a `Game::Market` query module with `self.call`; `models/game/market/market_state.rb` -- `MarketState.call.first_opened?`.
- `app/domains/game/app/operations/game/market/entrust_cards.rb` -- publishes `Game::Market::CardsEntrusted` (`data[:player_id]`) inside its transaction; nothing to change.
- `app/models/player_stream.rb` -- `EVENTS`, `notices(event)`, `BATCH`; subscribed at `config/initializers/event_store.rb` through `PlayerStream::EVENTS`, so adding an event to `EVENTS` wires it.
- `app/jobs/player_stream_job.rb`, `app/views/player_streams/_update.turbo_stream.erb` -- builds `locals` per player and renders the stream per locale with `ApplicationController.render`; the partial takes every local unconditionally, so `balance:` must always be passed.
- `app/views/shell/_top_bar.html.erb` -- `top-bar__end`: rarity counter, packs chip, then `shell/bell`; `status_in_bar`, `native_top_bar?`, `back_office_page?` guard the chips.
- `app/helpers/shell_helper.rb` (214 lines) -- memoised `shell_bank`; keep new helper code out of it, in a new helper.
- `app/components/picoin_amount_component.rb` -- `PicoinAmountComponent.new(amount:, compact:, size:, **html_options)`, role img with exact `aria-label`; `app/frontend/styles/picoin-amount.css`.
- `app/views/market/entrustments/new.html.erb`, `create.html.erb`, `app/frontend/styles/market-entrust.css` (`.market-entrust__header`) -- Confier and its answer headers; the answer is a full page (`turbo: false`), so its chip is rendered by the layout after the commit.
- `app/frontend/styles/shell-top-bar.css` (chip look: `.packs-chip`, `--font-number`, `--color-panel-sunken`, `--control-border`, `--space-chip-height`), `shell-header-phone.css` (`max-width: 719px` rules hiding top-bar chips), `app/frontend/entrypoints/application.css` (imports).
- `_bmad-output/initiative-gameble/ux-gameble/DESIGN.md` (Balance chip: `balance-chip.min-height` 34px, sunken background, 2px divider, available `text-max` mono bold, committed `muted`), `EXPERIENCE.md` (Balance chip rows, Copy deck "balance \"<amount> engagés\", \"<amount> engagé\" at 0 or 1").
- `test/support/market.rb` (`open_market!(**overrides)` sets no `first_opened_at`: pass it), `test/models/player_stream_test.rb`, `test/jobs/player_stream_job_test.rb` (`received`, `streams`, `template` helpers), `test/controllers/market/entrustments_controller_test.rb`, `test/system/market_entrust_test.rb` (sign-in and `hold` helpers).
- `config/i18n-tasks.yml` -- unused-key ignore list; keys used only by the stream partial are literal, so they need no entry.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/balance.rb` -- create `Game::Market::Balance.call(player)` returning `Balance = Data.define(:available, :committed)`, read with `Wallet.where(player_id:).pick(:available, :committed)`, `Balance.new(0, 0)` with no row -- the one reader of the wallet for screens.
- [ ] `app/helpers/balance_chip_helper.rb` -- create `shell_balance`: memoised, nil without `current_player`, nil unless `Game::Market::MarketState.call.first_opened?`, else `Game::Market::Balance.call(current_player)`; and `balance_chip_label` helpers only if the partial needs them -- one gate for every placement.
- [ ] `app/views/shell/_balance_figures.html.erb` -- create, locals `balance:`: `PicoinAmountComponent` compact (class `balance-chip__available`), `span.balance-chip__divider` `aria-hidden`, `span.balance-chip__committed` holding `span[aria-hidden=true]` with `t("shell.balance_chip.committed", count: balance.committed, amount: picoins(balance.committed, compact: true))` and a `visually-hidden` twin with the exact amount -- what the stream redraws.
- [ ] `app/views/shell/_balance_chip.html.erb` -- create, local `placement:` (`:bar` or `:header`): renders nothing when `shell_balance` is nil, else `div.balance-chip.balance-chip--<placement>` with `role="group"` and `aria-label` "Balance"/"Solde" around `shell/balance_figures` -- the shared partial epic 39 reuses.
- [ ] `app/views/shell/_top_bar.html.erb` -- render `shell/balance_chip` with `placement: :bar` right before `shell/bell`, skipped when `back_office_page?` or `native_top_bar?` -- desktop placement.
- [ ] `app/views/market/entrustments/new.html.erb`, `create.html.erb` -- render `shell/balance_chip` with `placement: :header` inside `.market-entrust__header` -- phone placement on Confier and its answer.
- [ ] `app/frontend/styles/balance-chip.css`, `app/frontend/entrypoints/application.css` -- create and import: inline-flex chip at `min-height: var(--space-chip-height)` (34px token), sunken background, `--control-border`, gap, the 2px divider in the line colour, available in `--color-text-max` with `--font-number`, committed in `--color-muted`, `white-space: nowrap`; `.balance-chip--bar` hidden under 720px, `.balance-chip--header` hidden from 720px, header chip aligned at the end of the header -- tokens only, no `style` attribute.
- [ ] `app/models/player_stream.rb` -- add `BALANCE_EVENTS = [ Game::Market::CardsEntrusted ]` to `EVENTS` and a `balance_notice(player_id)` returning `{ player_id:, balance: true }` for them in `notices`; keep the file under 400 lines -- the notice later events join.
- [ ] `app/jobs/player_stream_job.rb` -- add `balance: (Game::Market::Balance.call(player) if own.any? { it[:balance] })` to `locals` -- read once per player, after commit, in the job.
- [ ] `app/views/player_streams/_update.turbo_stream.erb` -- unless `balance.nil?`, `turbo_stream.update_all ".balance-chip"` with `shell/balance_figures` -- every open chip, desktop and header, follows.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- add `shell.balance_chip.label` ("Balance" / "Solde") and `shell.balance_chip.committed` (en `one`/`other` "%{amount} committed"; fr `zero`, `one` "%{amount} engagé", `other` "%{amount} engagés"), keys in alphabetical order -- copy of the Copy deck.
- [ ] `test/domains/game/market/balance_test.rb` -- no row gives 0 and 0; a ledger-posted wallet gives both amounts; another player's wallet is not read -- the query.
- [ ] `test/models/player_stream_test.rb` -- `CardsEntrusted` yields one `{ player_id:, balance: true }` notice, is in `EVENTS`, and a successful `EntrustCards` enqueues one `PlayerStreamJob` only after commit (`assert_enqueued_with`, batch empty), a failed one none -- the wiring.
- [ ] `test/jobs/player_stream_job_test.rb` -- a balance notice broadcasts an `update` of `.balance-chip` with compact available, divider and committed in en and fr ("12k committed"; "1 engagé", "0 engagé", "2 engagés"), the exact accessible texts, and no balance stream without the notice -- the render.
- [ ] `test/controllers/market/balance_chip_test.rb` -- integration: signed in after the first opening, a page has `.balance-chip--bar` and the Confier header chip with the compact amounts and `aria-label`; closed-after-opened still shows it; before the opening and for a visitor neither; a GET writes no wallet row; the answer to a POST shows the new available amount -- placement and gate.
- [ ] `test/system/market_entrust_test.rb` -- one test: after the first opening a signed-in player sees the chip on a desktop page, entrusts a copy, and the chip shows the new available amount with the old nothing committed; a second assertion on a fresh visit before the opening and as a visitor finds no chip (retrying matchers only) -- the end-to-end check.

**Acceptance Criteria:**
- Given the market never opened, when a visitor or a signed-in player loads any page, then no `.balance-chip` exists and no wallet is read.
- Given the market opened, when a signed-in player loads a desktop page, then the chip stands before the bell showing the compact available amount, a divider and "<amount> committed", named exactly for assistive technology.
- Given a phone viewport, when the player opens Confier, then the chip shows in its header with both amounts, and on other screens none shows.
- Given an open Confier page, when `CardsEntrusted` commits, then the player's streams (both locales) receive one update that redraws every chip; when the transaction rolls back, then nothing is enqueued.
- Given a wallet with committed 1, when the French chip renders, then it reads "1 engagé".

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

Decisions settled without a checkpoint, from the spec, architecture and UX:
- The chip is gated on `first_opened?` and not `open?`: a suspended market keeps showing a player's PiCoins (State Patterns, Market suspended), only the never-opened market has no balance.
- The stream replaces the chip's content (`update_all` on `.balance-chip`) and not the chip, so one notice serves the top-bar chip and the header chip, and the placement class stays with the server-rendered wrapper. A page loaded before the first opening has no chip to update; it appears on the next load, since an opening is a rare administrator act.
- The chip is not in the native top bar (a bridge component, the apps branch's concern) nor the back-office; the Confier header chip is web content and shows in the apps like any page.
- No toast or live-region announcement on a change: the chip is the quiet source of truth, like the packs chip; the answer page already says what was minted.
- The committed figure shows no second mark: the mark leads the available amount only (DESIGN, Balance chip).

Golden stream shape for a notice `{ player_id: 1, balance: true }`:

```erb
<%= turbo_stream.update_all ".balance-chip", partial: "shell/balance_figures", locals: { balance: } %>
```

## Verification

**Commands:**
- `bundle exec rubocop app/domains/game/app/queries/game/market/balance.rb app/helpers/balance_chip_helper.rb app/models/player_stream.rb app/jobs/player_stream_job.rb` -- expected: no offense
- `/home/teyermann/projets/gameble/node_modules/.bin/stylelint app/frontend/styles/balance-chip.css` -- expected: clean
- `bundle exec packwerk check`, `script/check_file_sizes`, `script/check_planning_references` -- expected: clean
- `bin/rails test test/domains/game/market/balance_test.rb test/models/player_stream_test.rb test/jobs/player_stream_job_test.rb test/controllers/market/balance_chip_test.rb`, `bundle exec i18n-tasks health`, `bin/rails test test/system/market_entrust_test.rb -n /balance/` -- run once at the end of the market run

**Manual checks (if no CLI):**
- With the market opened, the chip sits before the bell on desktop and in Confier's header under 720px, in both languages; entrusting in a second tab updates the first tab's chip without a reload.
