---
id: story-a-shared-card-link-previews-with-a-generated-image
type: story
title: "A shared card link previews with a generated image"
parent: none
covers: [CAP-9]
after: []
assignee: ""
refined: false
hitl: false
risk: medium
estimate: ""
---

# A shared card link previews with a generated image

## Description

A card's share link carries a generated image in its Open Graph and Twitter tags, so Discord, X and WhatsApp show the card with its art, title and rarity instead of a text-only preview. The image is rendered once per card and language and served from storage afterwards. The card page's other preview rules stay as they are.

## Acceptance Criteria

1. **The card page points at an image**
   **Given** a published card
   **When** a crawler or a browser opens its share link
   **Then** the page carries `og:image`, `twitter:image` and a large-image `twitter:card`, with an absolute URL, the image's width and height, and a text alternative naming the card
2. **The image shows the card**
   **Given** a card with its Steam art
   **When** its image is fetched
   **Then** it is a PNG or JPEG at the size the platforms recommend for large previews, showing the card's art, title and rarity in the share link's language
3. **The image is generated once**
   **Given** a card whose image was already generated
   **When** the image or the card page is requested again
   **Then** no new render happens and the same image is served
4. **A failed render never breaks the page**
   **Given** the render fails, or the card has no usable art
   **When** the share link is opened
   **Then** the page still answers 200 with the text-only preview it has today, and the failure is reported to error tracking
5. **A crawler can fetch it signed out**
   **Given** no session
   **When** the image URL is requested
   **Then** it answers 200 with a long cache lifetime; the URL carries no database id and nothing about who shared or holds the card
6. **A GET never renders**
   **Given** an image not generated yet
   **When** the card page is opened
   **Then** the page does not wait for the render: the render is enqueued after commit by a job, and the tags appear once the image exists
7. **An art change refreshes the image**
   **Given** a card whose art or title changed after its image was generated
   **When** the change is saved
   **Then** the old image is replaced and the next fetch returns the new one

## Boundaries

- Must not change: the preview's title, description, canonical URL, locale and `noindex`; the page showing no owner and no sharer; the card page's notice that the game and its image belong to their owners.
- Must not change: the tags of the public profile pages.

## References

- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-9 (shared card)
- pending — _bmad-output/initiative-gameble/pending-approvals.md, the Cloudflare entry on link-preview crawlers

## Notes

- Decision (2026-10-21, author): the image shows the game's Steam art. This lifts the rule that the preview carries no game image, which the share-tags view, the spec's CAP-9 and the collection-and-sharing epic still state. The author updates the spec and the architecture; the build rewrites the view's header comment and the tests that assert no image.
- Assumption: one image per card and language, not per sharer, so nothing personal enters it. Confirm.
- Assumption: the card frame and rarity colours of the in-game card are reused in the image so it looks like the card. Confirm.
- Open question: how the image is rendered (server-side image library, a headless browser on the card's markup, or a canvas in a job) and where it is stored. The builder proposes one and records the reason; the host's memory and storage limits decide.
- Open question: Steam's terms on reusing store art in a derived image; the author checks before this ships.
- Open question: Cloudflare must let the preview crawlers reach the image URL as well as the page (see the pending Cloudflare entry).
