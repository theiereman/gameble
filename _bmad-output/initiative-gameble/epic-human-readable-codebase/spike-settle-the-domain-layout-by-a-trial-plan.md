---
title: 'Settle the domain layout by a trial'
type: 'chore'
ticket: '1'
created: '2026-10-27'
status: 'in-review'
baseline_revision: '6c1f1612'
route: 'oneshot'
route_source: 'pinned'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
warnings: []
deferred: []
---

# Settle the domain layout by a trial

A spike, hitl: the trial ran on branch `build/12-1-layout-trial`; the author decides before the spine is amended and the move generalises. Only `accounts` moved.

## Finding

Recommended layout: `app/domains/<name>/app/<kind>/<Namespace>/...`, the pack's current tree moved one level down with its `package.yml`, and `app/domains` kept out of Rails' autoload roots. `Accounts::Player` stays at that constant.

What the trial changed (git renames, no code edits):

- `packs/accounts` to `app/domains/accounts`; `test/packs/accounts` to `test/domains/accounts`.
- `packs.yml` (new, root): `pack_paths: [packs/*, app/domains/*]` so `Packs.all` finds both during the migration (the end state is `app/domains/*` alone). packs-rails then adds `app/domains/accounts/app/*`, `lib/tasks`, `config/*` as paths by itself, so the accounts rake task is still listed.
- `config/application.rb`: Rails' default `app/*` glob made `app/domains` an autoload root (constants would be shaped like `Accounts::App::Models::...`). One line removes it: `config.paths["app"].instance_variable_get(:@exclude) << "domains"`. `Path#exclude` has no public reader, and re-adding the `app` path with `paths.add` drops the entries packs-rails injected (the trial broke `Game::Handlers` that way), so the instance variable is the least bad hook. It is the one wart of the layout.
- `package.yml`, `packs/game/package.yml`, `test/packs_test.rb`: dependency name `packs/accounts` becomes `app/domains/accounts`. Packwerk names a package by its path.

Alternative not kept: domain code directly in `app/domains/<name>/{models,operations,...}` (no inner `app/`). packs-rails only injects `<pack>/app/*`, so it needs hand-written autoload paths in `application.rb` for every domain; it saves one directory level but replaces a convention with configuration.

## Verification (trial branch, accounts moved)

- `bundle exec packwerk validate`: successful. `bundle exec packwerk check`: no offenses, no stale violations.
- `bin/rails zeitwerk:check`: all good. Autoload dirs for accounts are the five `app/domains/accounts/app/*` roots, no `app/domains` root.
- `bin/rails test test/packs test/domains`: 1604 runs, 0 failures. Full `bin/rails test`: 3214 runs, 0 failures. rubocop and `i18n-tasks missing` clean (`config/i18n-tasks.yml` already searches `app/`).
- `bin/rails -T` still lists `accounts:set_role`.

## For the move entries

- A domain test directory can follow the domain (`test/domains/<name>`); `bin/rails test test/packs` in this ticket's verify line covers the remaining packs only.
- On the full move: `packs.yml` shrinks to `app/domains/*`; `config/i18n-tasks.yml` drops `packs/`; Dockerfile, CI and docs mentioning `packs/` follow.
- Not done here, waiting on the decision: the Decision line in the epic Notes and the spine amendment (Modules, AD-1, AD-2, layer table) through bmad-architecture. Both are the unchecked half of this ticket's verify line.
