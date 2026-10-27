# Architecture

This page is the map of the code: where things live, how a request becomes a
write, and the rules that keep the parts apart. For the vocabulary of the
game (card, season, set, holding, bank...) see [glossary.md](glossary.md). For
running and releasing the app see [operations.md](operations.md).

gameble is a Rails 8 application with Hotwire, TypeScript Stimulus controllers
and Postgres. The server renders every screen; script only enhances it.

## Layout

```
app/
  domains/<name>/app/...   domain code: models, operations, queries, events, handlers, jobs
  domains/<name>/lib/      rake tasks and domain-only helpers
  controllers/             web layer, back_office/ for staff screens
  policies/                one Pundit policy per controller
  components/              ViewComponents
  views/                   ERB, turbo streams and <template>s for script
  models/                  web-layer models that are not domain tables (streams, feed items, exports)
  jobs/                    broadcast jobs
  frontend/                Vite entrypoint, Stimulus controllers, TypeScript state modules
lib/                       shared base classes: ApplicationOperation, ApplicationRecord
test/domains/<name>/       domain tests; test/system for browser tests
```

## Domains

Domain code lives in four [packwerk](https://github.com/Shopify/packwerk)
packages under `app/domains/` (declared by `packs.yml`). Each has a
`package.yml`, and `bundle exec packwerk check` fails on a dependency the
diagram does not allow.

| Domain | Owns | Depends on |
| --- | --- | --- |
| `accounts` | players, roles, moderation, reports, data export, retention | `lib` |
| `catalog` | cards, seasons, sets and tiers, themes, the public roadmap | `lib` |
| `steam` | the Steam client, sign-in identity, the staged import of the catalog | `lib`, `catalog` |
| `game` | packs, holdings, bank, showcase, trades, friends, goals, achievements, the activity feed | `lib`, `accounts`, `catalog` |

No domain depends on the web layer (controllers, views, components, `app/models`).
`lib/` holds what every domain may inherit: `ApplicationRecord`
(`lib/application_record.rb`) and `ApplicationOperation`
(`lib/application_operation.rb`). Models are namespaced by domain (`Game::Pack`)
and tables are prefixed the same way (`game_packs`).

Inside a domain, `app/` has these folders (not every domain has each one):

- `models/`: Active Record models and plain objects (value tables such as `Catalog::TierTable`).
- `operations/`: every write.
- `queries/`: every read the web layer needs.
- `events/`: event classes published by operations.
- `handlers/`: subscribers to events (`Game::Handlers::*`).
- `jobs/`: background work of the domain.
- `clients/`: external HTTP clients (`Steam::WebApi`, `Steam::Cdn`).

## Writing: operations, events, handlers

All writes go through an operation. An operation is a class named
`Domain::VerbNoun` that inherits `ApplicationOperation` (built on dry-operation),
and returns `Success(value)` or `Failure(:code)`.

- `call` takes keyword arguments. In `game`, `Game::Operation` also requires a
  `player:` keyword and offers `require_player`, `lock_bank` and `stream_name`.
- Writes and the published event sit inside `transaction do ... end`. A
  `Failure` returned through `step` rolls back the rows and the event together.
- An operation calls another operation of its domain only through `step`, so
  the inner failure halts the outer flow.
- Failure codes have a translation at `errors.<domain>.<code>` in both
  `config/locales/en.yml` and `fr.yml` (`ApplicationOperation.failure_message`).
  `i18n-tasks` cannot see these dynamic keys, so add both by hand.
- Controllers, jobs, handlers and components never write a model directly.

Example, `Game::CollectDailyBonus`: check the player, take the bank lock,
check the day is unclaimed, top up the bank, create the bonus pack, publish
`Game::DailyBonusCollected`, return the pack.

Each operation publishes one event, inside its transaction, with
`publish(Event.new(data: {...}), stream_name: ...)`. Events are classes under
`app/domains/<domain>/app/events` and carry identifiers only. The store is
[Rails Event Store](https://railseventstore.org), configured once in
`config/initializers/event_store.rb`.

Handlers subscribed in that initializer run synchronously, inside the
publishing transaction: a handler that raises rolls the operation back.
Handlers never publish events. Examples: `Game::Handlers::PackOpened` counts
an opening toward the weekly goal, `Game::Handlers::PlayerRegistered` fills a
new player's bank, `Game::Handlers::Achievements` unlocks achievements.
Subscription order matters and is commented in the initializer.

Concurrency is handled with Postgres advisory locks: `Game::BankLock` serialises
everything that touches one player's packs and holdings, and `Game::TradeLocks`
takes the locks of several players in ascending id order.

## Reading: queries and policies

A query is a module or class under `queries/` with a `call` method, named for
what it returns (`Game::Reserve`, `Game::CollectionSummary`,
`Catalog::PublishedSeason`, `Accounts::PlayerByToken`). Controllers and views
read through queries; they do not build ad hoc relations on domain models.
Queries never write.

Every controller action has a Pundit policy in `app/policies` (the base is
`ApplicationPolicy`, with `visitor?`, `player?`, `moderator?`, `administrator?`).
Roles are `player`, `moderator`, `administrator` (`Accounts::Player::RANKS`).

Database ids never leave the server: URLs, HTML, JSON, DOM ids and stream names
use tokens (`has_secure_token`, `param: :token` in `config/routes.rb`).

## Web layer

`ApplicationController` is the base of every controller. It switches the
locale, enforces the read/write rule below, applies rate limits and records
player presence. Routes live under `scope ":locale"`, so the locale is the first
URL segment (`en` or `fr`). Staff screens are under `back-office`, in
`app/controllers/back_office`.

Views are ERB with ViewComponents (`app/components`). Server HTML carries no
`style` attribute. Strings go in both `config/locales/en.yml` and `fr.yml`.

## Read and write database roles

`ApplicationRecord` declares two roles, `writing` and `reading`, both pointing at
the primary database (`connects_to database: { writing: :primary, reading: :primary }`),
so a read replica can be added later without touching callers.

`ApplicationController#read_only_unless_writing` runs every GET and HEAD action
inside `ApplicationRecord.connected_to(role: :reading, prevent_writes: true)`.
A GET therefore cannot write: a write behind a GET raises. Put the write behind
a POST, or enqueue a job. Enqueueing from a GET is allowed because Solid Queue
uses its own connection (see `note_presence`, which enqueues
`Accounts::NoteLastSeenJob`). The role is switched on `ApplicationRecord` only,
never on `ActiveRecord::Base`, so Solid Queue and Solid Cache stay writable.

Production also has `cache`, `queue` and `cable` databases (`config/database.yml`).
`lib/connection_budget.rb` counts the pools against Postgres.

## Jobs and broadcasts

- A job is enqueued only after commit. Never call `perform_later` from inside
  an operation's transaction body.
- A broadcast goes through a job, never inside a transaction.
- Two event-driven broadcasters, both subscribed in `config/initializers/event_store.rb`:
  - `LiveStream` (`app/models/live_stream.rb`) turns pack openings, reposts,
    trades and set tiers into the shared activity feed. It collects notices and
    delivers them after commit through `AfterCommitBatch`, which enqueues
    `LiveFeedJob` once per transaction.
  - `PlayerStream` (`app/models/player_stream.rb`) notifies a single player's
    pages (trades, friends, achievements) through `PlayerStreamJob`.
- Jobs render the Turbo Stream once per locale and broadcast with
  `Turbo::StreamsChannel.broadcast_stream_to`. Stream names are built from
  tokens and the locale (`PlayerStream.streamables`, `LiveStream.feed_streamables`).
- Domain jobs (`Game::ExpireTradesJob`, `Steam::ImportStepJob`,
  `Accounts::ApplyRetentionJob`...) live in their domain and call operations.

## Frontend: Stimulus screens

`app/frontend/entrypoints/application.ts` starts Stimulus and registers every
`app/frontend/controllers/**/*_controller.ts`. There is no React.

Rules:

- The server renders HTML. Script never builds markup from strings; a controller
  clones a server-rendered `<template>` (`app/frontend/lib/templates.ts`,
  `cloneTemplate`).
- A rich screen has one root controller. It holds its state in a pure module
  `app/frontend/lib/<screen>.ts`, written as functions over a state value and
  tested with vitest. The root controller applies the state to the DOM.
- Child controllers talk to the root by `this.dispatch(...)`; the root drives
  them through Stimulus outlets (`static outlets`).
- A screen talks to the page chrome (toasts, the bank chip, navigation lock)
  only through the `gameble:*` window events declared in
  `app/frontend/lib/events.ts` (`dispatchGameble`, `onGameble`).

The two large examples:

| Screen | Root controller | State module | Children (outlets) |
| --- | --- | --- | --- |
| Trade board | `trade_board_controller.ts` | `lib/trade_board.ts` | `trade_board_side`, `trade_board_picker`, `trade_board_send` |
| Booster | `booster_controller.ts` | `lib/booster_state.ts` | `booster_info`, `booster_actions`, `booster_canister`, `booster_stage`, `booster_plate`, `booster_tray`, `booster_zoom`, `booster_celebration` |

`live_refresh_controller.ts` reacts to Turbo Stream signals that
`PlayerStreamJob` sends, so a page reloads its data when the server says it
changed.

## Checks

Run on what you touch (see `AGENTS.md` for the full list):

- `bundle exec packwerk check`: domain dependencies.
- `script/check_planning_references`: no planning ids in code.
- `script/check_file_sizes`: size limits per file.
- `npm run format:check`, `npm run lint:css`, `npm run test:js`.
- `bin/rails zeitwerk:check`, `bin/rails test`, and the system tests of the screen you changed.
