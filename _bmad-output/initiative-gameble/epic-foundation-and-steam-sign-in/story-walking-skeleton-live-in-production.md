---
id: 1
type: story
title: "Walking skeleton live in production"
parent: epic-foundation-and-steam-sign-in
covers: [R2, R7]
after: []
hitl: true
risk: medium
tracker_id: 2
remote: https://github.com/theiereman/gameble/issues/2
tracker_status: backlog
---

# Walking skeleton live in production

## Description

Creates the Rails 8.1 application with PostgreSQL, Vite and the four empty packs, and deploys one placeholder page with Kamal 2 behind Cloudflare.

## Acceptance Criteria

Verify: The production URL serves the placeholder page and `/up` answers healthy.

## References

- parent — _bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/epic-foundation-and-steam-sign-in.md
- architecture-gameble/architecture-gameble.md#ad-21--one-image-three-processes-adopted
- architecture-gameble/architecture-gameble.md#stack

## Notes

- Unknown: Whether every pinned gem runs on Ruby 4.0.7; the spine's fallback is Ruby 3.4.11.
