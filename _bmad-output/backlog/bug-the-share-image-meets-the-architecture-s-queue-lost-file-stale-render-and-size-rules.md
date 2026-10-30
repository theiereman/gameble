---
id: bug-the-share-image-meets-the-architecture-s-queue-lost-file-stale-render-and-size-rules
type: bug
title: "The share image meets the architecture's queue, lost-file, stale-render and size rules"
parent: none
covers: []
after: []
assignee: ""
refined: true
hitl: false
risk: medium
severity: P2
estimate: ""
---

# The share image meets the architecture's queue, lost-file, stale-render and size rules

## Description

The shared card's generated preview image (commit 46a61856, follow-up 50fb6fbd) shipped before the architecture's AD-39 was written (commit 27c5fb02). AD-39 ratifies that build and adds four rules the code does not meet yet:

1. Renders run on a `share_images` queue with one thread. `CardShareImageJob` is on `default`, and `config/queue.yml` lists no such queue; its header says every new queue must be listed there.
2. A stored row whose file is missing counts as missing: the card page drops the image tags and enqueues the render. Today the page keeps advertising an image that answers 404.
3. The PNG is uploaded before `Catalog::StoreShareImage`'s transaction; under the card-season row's lock, the store refuses with `Failure(:stale_render)` a render whose fingerprint no longer matches the card. Today the blob is uploaded inside the transaction (holding the lock, and leaving an orphan file on rollback) and a stale render racing a newer one can be stored. The new failure code needs `errors.catalog.stale_render` in both locales.
4. The image stays under 300 KB, checked by a test on its byte size; a larger render is saved with a palette.

The author asked for this follow-up on 2026-10-30.

## Acceptance Criteria

1. **Renders run on their own queue**
   **Given** the card page enqueues a render, or `Catalog::CardIdentityUpserted` refreshes one
   **When** the job is enqueued
   **Then** it goes to the `share_images` queue, which `config/queue.yml` lists with one thread in every environment
2. **A lost file counts as missing**
   **Given** a stored share image whose file is gone from storage
   **When** the card page is opened
   **Then** the page carries no `og:image`, `twitter:image` or large-image `twitter:card`, and enqueues the render (within the hourly throttle)
3. **The upload is outside the transaction and a stale render is refused**
   **Given** a render whose fingerprint no longer matches the card when it is stored
   **When** `Catalog::StoreShareImage` runs
   **Then** it returns `Failure(:stale_render)`, stores no row change, publishes no event and leaves no orphan file; the PNG upload happens before the transaction opens
4. **The image stays light**
   **Given** a render of a card with busy art
   **When** it is stored
   **Then** its PNG is under 300 KB, a test asserts the byte size, and a render over the limit is saved again with a palette

## Boundaries

- Must not change: the image's look, its URL, token rule, cache headers and `noindex`; the fingerprint's content; the card page's other preview tags; the hourly and daily throttles.
- Must not change: local disk storage (object storage is a deferred architecture item).

## References

- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-39
- plan — _bmad-output/backlog/story-a-shared-card-link-previews-with-a-generated-image-plan.md, the deferred AD-39 entry and its triage rows

## Notes

- Filed on 2026-10-30 at the author's request, from the follow-up review of the share image.
