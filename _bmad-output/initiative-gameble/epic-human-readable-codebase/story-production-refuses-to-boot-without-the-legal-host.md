---
id: 32
tracker_status: done
tracker_id: ""
type: story
title: "Production refuses to boot without the legal host"
parent: epic-human-readable-codebase
covers: [R8]
after: [8, 9, 12, 25]
hitl: false
risk: medium
---

# Production refuses to boot without the legal host

## Description

Makes the app refuse to boot in production when a `LEGAL_*` variable is missing (`config/initializers/legal.rb`), removes the legal page's `access_publisher` fallback, and names the host in the privacy notice's processors line, from `LEGAL_HOST_NAME: Thomas Eyermann` and `LEGAL_HOST_ADDRESS: France` already in `config/deploy.production.yml` (the author hosts it, so no host choice is awaited). The check must not break the image build (`assets:precompile` runs in production mode with a dummy secret) or staging (which keeps the `LEGAL_*` variables commented out): the builder skips it during precompile and gives staging values or a dedicated flag, and records which.

## Acceptance Criteria

Verify: A production-mode boot without `LEGAL_HOST_NAME` fails with a message naming it; the legal page test shows the host from the variables; the processors line of the privacy notice names the host, in English and French; `docker build` and a staging-style boot still succeed.

## References

- parent — _bmad-output/initiative-gameble/epic-human-readable-codebase/epic-human-readable-codebase.md
