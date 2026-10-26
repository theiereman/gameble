---
title: 'A feed entry is rebuilt for balance and legible parts'
type: 'feature'
ticket: '32'
created: '2026-10-26'
status: 'built'
baseline_revision: 'a07c0b6492aad72454a5d2911bc8b4cd032d17d5'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A feed entry puts the time, a one-colour sentence, a 112x168 card (`card-s`) and a rarity tag on one line. The player, the game, the text, the date and the rarity are not told apart, and the card takes over the line (author, 2026-10-23, on staging).

**Approach:** Rebuild `feeds/_entry` around a clear hierarchy (who, what, which game, when), with the player's name and the game's name each given their own treatment, a quiet timestamp, and a card sized to support the line. The same markup serves the feed, the landing's LIVE module and the hub's ticker items; each context's size is checked.

## Boundaries & Constraints

**Always:** Every kind keeps working: pull, discovery, trade, repost, set tier, set completion, filler. Reduced motion, the visitor's read-only view, French and English. No `style` attribute in server HTML; strings in `en.yml` and `fr.yml`. EXPERIENCE.md's Fil d'activité row and DESIGN.md's Feed entry follow.

**Never:** Restyle colours only. Change what an entry says or which entries exist. Dim a filler entry by opacity.

## Decisions (author, 2026-10-26, from the mockups)

- Layout: the card on the left, two lines to its right. Line 1: player, verb, game. Line 2: the rarity tag (or the REPOST, trade or tier tag, and the first-discovery chip), the date at its far right in muted, quiet.
- The card is card-s scaled down by CSS to about half (about 56x84), framed in its rarity colour as the repost and trade thumbnails are today.
- The player's name is a link in `{colors.accent}`, bold, to their public profile. The game's name is a link in white, bold, to its card page. The verb stays plain text. A trade names two players and two games, all linked.

</frozen-after-approval>

## Code Map

- `app/views/feeds/_entry.html.erb` -- the one entry partial, rendered by `feeds/show`, `live_streams/_feed.turbo_stream.erb` and `landings/_live.html.erb`.
- `app/helpers/feed_helper.rb` -- `feed_sentence` builds the sentence; player via `feed_name` and titles via `tag.strong`, both plain `<strong>` today, so nothing tells them apart.
- `app/frontend/styles/feed.css` -- `.feed__entry` grid (`5.5rem 1fr auto auto`, 68px min), phone grid `1fr auto`.
- `app/frontend/styles/landing.css:983-1000,1588` -- LIVE module overrides: hides thumbs, one-line ellipsis sentence, `4rem minmax(0,1fr) auto`.
- `app/components/card_component.rb`, `app/frontend/styles/card.css:29` -- `card-s` is 112x168; the entry's only card size.
- `app/views/shell/_ticker_item.html.erb` -- the hub ticker has its own item markup (`ticker__*`); it shares `feed_sentence`, so a name treatment reaches it too.
- Tests: `test/system/feed_test.rb`, `landing_live_feed_test.rb`, `live_updates_test.rb`, `card_detail_test.rb` (select `.feed__sentence`, `.feed__thumb--framed`, `.feed__tag--*`); keep those hooks or update the tests with them.
- Docs: `ux-gameble/DESIGN.md` "Feed entry" (Activity feed), `ux-gameble/EXPERIENCE.md` "Feed entry" row.

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/feed_helper.rb` -- `feed_name` and the card/set titles render links (`brother_path(token:)`, `card_path(slug: card.id)`); `feed_sentence` takes `links:` (default true) and the ticker passes `false`, since a scrolling band holds no links. A nameless player stays plain text; a set title stays plain.
- [ ] `app/views/feeds/_entry.html.erb` -- two-line body: the sentence, then a meta row (tag, chip, date); the thumbnail link keeps `aria-label`; set entries keep their tier tag and no thumbnail.
- [ ] `app/frontend/styles/feed.css`, `app/frontend/styles/landing.css` -- the new grid, the scaled card, name link styles with a visible focus ring and a 44px touch target on the phone; the LIVE module keeps its compact one-line, thumbnail-free form with the linked names.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- only if a string changes (the sentences should not).
- [ ] `test/system/feed_test.rb`, `landing_live_feed_test.rb` -- the names link to the profile and the card page; every kind renders; assertions retry.
- [ ] `ux-gameble/DESIGN.md`, `EXPERIENCE.md` -- Feed entry paragraph and Fil d'activité row follow.

**Acceptance Criteria:**
- Given a pull, a discovery, a trade, a repost, a tier and a completion, when the feed opens on desktop or phone in French or English, then the player, the game, the text and the date are told apart and the card is about 56x84.
- Given the player or the game name, when clicked, then the profile or the card page opens; a visitor's landing LIVE module links the same way.
- Given the hub ticker, then its items carry no links and look as before.

## Implementation Notes

## Plan Change Log

## Review Triage Log

| Verdict | Route | Finding and evidence |
|---|---|---|
| medium | patch | The halved card's `transform` lost to `.card[data-tilt]` and to the reduced-motion `transform: none`; the selector now outranks both and the system test measures after a hover. |
| medium | patch | The public card page's live strip also got the links, its game link pointing at its own page; it passes `links: false`. |
| low | patch | The LIVE module's `overflow: hidden` clipped the focus ring and let the meta row wrap; the ring is drawn inside and the meta row stays on one line. |
| false | rejected | The phone touch target overlapping the meta row: what it overlaps (tag, date) is not interactive. |
| false | rejected | Long linked names overflowing a trade entry: the sentence wraps normally and the body has `min-width: 0`. |
| low | rejected | Wider tests (trade links, nameless player): the helper's branches are small and the existing kinds' tests still pass. |
| defer-none | out of diff | `config/locales/fr.yml` carried another session's edits; left out of the commit. |
