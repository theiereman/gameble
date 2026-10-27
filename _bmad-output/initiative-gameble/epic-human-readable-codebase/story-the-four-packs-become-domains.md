---
id: 2
tracker_status: done
tracker_id: 270
remote: https://github.com/theiereman/gameble/issues/270
type: story
title: "The four packs become domains"
parent: epic-human-readable-codebase
covers: [R1]
after: [1]
hitl: false
risk: high
---

# The four packs become domains

## Description

Moves `packs/accounts`, `catalog`, `steam` and `game` to `app/domains/<name>/` by `git mv` in the layout of entry 1, updates `packwerk.yml`, the root and domain `package.yml`, the autoload configuration, `test/packs_test.rb`, `test/support/rake_tasks.rb`, `game_benchmark.rake`, and moves `test/packs/<pack>` to `test/domains/<name>`; says domain, not pack, wherever the word means the module (the booster `Game::Pack` keeps its name); updates the `packs/` mentions in `config/i18n-tasks.yml`, the `Gemfile` comment, AGENTS.md, README.md and `config/ci.rb`. Ruby namespaces, constants and behaviour are unchanged.

## Acceptance Criteria

Verify: `bundle exec packwerk validate && bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop` and `bin/rails test` pass; `git diff -M --stat` shows the Ruby files as renames with no content change other than the files named above; no `packs/<name>` path remains outside the AI tooling (`git grep -nE 'packs/(accounts|catalog|game|steam)' -- . ':(exclude)_bmad' ':(exclude)_bmad-output' ':(exclude).claude' ':(exclude).agents'`); `bin/rails test test/system` for the booster, library and trades files passes.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
