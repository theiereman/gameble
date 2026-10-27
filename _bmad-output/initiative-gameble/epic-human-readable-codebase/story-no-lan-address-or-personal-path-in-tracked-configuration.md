---
id: 25
tracker_status: done
tracker_id: 293
remote: https://github.com/theiereman/gameble/issues/293
type: story
title: "No LAN address or personal path in tracked configuration"
parent: epic-human-readable-codebase
covers: [R8]
after: [9, 10, 11]
hitl: false
risk: low
---

# No LAN address or personal path in tracked configuration

## Description

Removes the LAN addresses (`192.168.x.x`) and any personal path from tracked files outside the AI tooling: the comments of `config/deploy.production.yml`, `config/deploy.staging.yml` and `config/deploy.yml`, and the fixed `http://192.168.1.6` URL pinned by `test/config/public_url_test.rb`, rewriting each comment to describe the role of the host rather than its address, and reading a value that must stay from the environment. The staging domain `gameble.dotsncircles.com`, `theiereman` (image, repository, donation URL) and the `LEGAL_*` personal name are accepted as they are and not touched.

## Acceptance Criteria

Verify: `git grep -nE '192\.168\.|/home/[a-z]+/' -- . ':(exclude)_bmad' ':(exclude)_bmad-output' ':(exclude).claude' ':(exclude).agents'` returns nothing; `bin/kamal config -d staging` and `-d production` still render; `bin/rails test test/config` passes.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
