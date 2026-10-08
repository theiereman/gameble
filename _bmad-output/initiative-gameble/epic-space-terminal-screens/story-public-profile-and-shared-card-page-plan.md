---
title: 'Public profile and shared card page'
type: 'feature'
ticket: '3'
created: '2026-10-06'
status: done
baseline_revision: 'fadcde2e9e9acb74d6698bd611dea3c53aba86d7'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The public profile still wears the medieval tome shelf (`library.css`, "Brother" wording) and the shared card page is the signed-in detail panel with an invitation tacked on; neither follows the space-terminal design, and an older browser is offered a sign-in it cannot use.

**Approach:** Redraw the shared card page as the design's public card page (card only, no sharer, no app chrome), replace the inline share field by a "PARTAGER LA CARTE" sheet, restyle the profile as a read-only collection, and retire the old tome styles.

## Boundaries & Constraints

**Always:** Copy only in `fr.yml`/`en.yml` ("vous"), both locales complete. No database id in URLs (AD-15); the share link keeps addressing a card-season. Preview tags keep title and rarity with no image (`_share_tags` unchanged). The shared page names no player. Pages stay open to any browser and crawler (`PublicRead`). Respect "Animations réduites" for the card tilt.

**Never:** No VITRINE, no visibility line (epic 7). No feed or legal route is built. No change to the share-link format, the `old_share_link` redirects, `CardDetailLoading`, or the collection screen files of story 10.1. No JS or user-agent sniffing for the old-browser line.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor, modern browser | GET shared card link | Public card page: tilting card, facts, "VOIR SUR STEAM ↗", sign-in pitch and primary button opening the sign-in panel, static LIVE strip and "Mentions légales" placeholders; no player named | Unknown card: existing 404 |
| Visitor, old browser | Browser without `:has()` | Same page; a line asking to update the browser replaces the invitation and button | Crawlers keep the preview tags |
| Holder shares | Signed-in holder taps PARTAGER | Sheet opens, link copied on opening and "COPIÉ ✓" announced politely; thumbnail is the card face, never the game image | Clipboard refused: link stays selected, manual-copy line shown |
| Non-holder / visitor | Card detail | No PARTAGER button | None |
| Profile | Visible profile | Avatar, Steam name (fallback "Brother <code>" replaced by the design's wording), card count, sets in read-only collection components | Hidden or banned: "not available" page, 404 |

</frozen-after-approval>

## Code Map

- `app/controllers/cards_controller.rb`, `app/views/cards/show.html.erb`, `app/views/cards/_detail.html.erb` -- the card page; branch on viewer: visitor gets the public variant, signed-in keeps the 10.2 panel.
- `app/views/cards/_share_tags.html.erb`, `app/helpers/card_details_helper.rb`, `app/helpers/public_urls_helper.rb` -- preview tags and share URL; unchanged.
- `app/views/layouts/application.html.erb`, `app/views/shell/_top_bar.html.erb` -- top-bar variant for a visitor on the card page: logo left, Steam sign-in image right, no tab bar.
- `app/frontend/controllers/share_controller.ts`, `dialog_controller.ts`, `dialog_opener_controller.ts`, `lib/dialog.ts` -- extend share for copy-on-open; reuse the dialog for the sheet. Tilt: `controllers/tilt_controller.ts`, `CardComponent` at `card-xl`.
- `app/frontend/styles/card-detail.css`, `card.css`, `shell.css` -- public page layout (card and info capped at 1180px, one column on a phone), `@supports selector(:has(*))` switch between the update line and the invitation.
- `app/controllers/public_profiles_controller.rb`, `app/helpers/public_profiles_helper.rb`, `app/views/public_profiles/{show,_profile,set,unavailable}.html.erb` -- rebuild on the 10.1 collection components in read-only mode.
- `app/frontend/styles/library.css`, `app/views/library/_shelf.html.erb`, `_tome.html.erb` -- retire after grepping for other users of `.tome`, `.shelf`, `.library__*`, `.profile__*`; keep `library/_set_row` (used by `pages/_set_progress`).
- `config/locales/{fr,en}.yml` -- new keys under `cards.show`, `card_details.share`, `public_profiles`; drop "Brother" vocabulary.
- Tests: `test/controllers/{cards_controller,card_preview_tags,public_profiles_controller}_test.rb`, `test/system/{share_card,public_profile,card_detail}_test.rb`, `test/helpers/public_urls_helper_test.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/views/cards/show.html.erb`, `_detail.html.erb`, `cards_controller.rb` -- public card page for a visitor: card, publisher, "rarity, genre, year, number" line, description, Steam link, pitch with primary button opening the sign-in panel, update line for old browsers, static LIVE strip and legal link -- R3, R6
- [ ] `shell/_top_bar.html.erb`, layout -- visitor top bar on the card page -- design: no app chrome
- [ ] `cards/_share_sheet.html.erb`, `share_controller.ts`, locales -- "PARTAGER LA CARTE" sheet replacing the inline field; holders only -- design share sheet
- [ ] `public_profiles/*`, helper, locales -- read-only collection restyle, unavailable page wording
- [ ] `library.css`, `library/_shelf`, `_tome` -- remove medieval styles and dead partials
- [ ] tests listed above -- no player named, no image tag, old-browser line markup, sheet copy and clipboard fallback, profile sets, i18n-tasks passes

**Acceptance Criteria:**
- Given a signed-out visitor, when they open a shared link, then they see the card only, no player named, and preview tags carry no image.
- Given a browser without `:has()`, when the page renders, then the update line shows and the sign-in invitation does not.
- Given a visible profile, when opened, then its sets show in the new design with no tome shelf.
- Given any locale, when CI runs i18n-tasks, then no key is missing.

## Implementation Notes

## Plan Change Log

## Review Triage Log

Quick lens, pass 1 (0 high, 0 medium, 2 low, 2 rejected):

| Verdict | Route | Finding and evidence |
|---|---|---|
| low | rejected | "Lien copié" instead of "COPIÉ ✓": DESIGN.md l.499 bans typed ✓; a pixel icon would be more than a direct correction. |
| low | patch | Dead `mark_complete` key and stale comment in `ShelvesHelper#profile_shelf_links`; removed, tests green. |
| medium | defer | No Épique/Légendaire rays on the public card page: rays exist only in `booster.css`; absent from detail and showcase too, a cross-screen job. |
| low | rejected | Empty labelled `section.profile__pick` when no sets: rare, fix adds a branch. |

## Design Notes

Old-browser switch is CSS only: the update line is visible by default; the invitation is hidden by default and revealed inside `@supports selector(:has(*))`, which an unsupporting browser ignores whole. Static LIVE strip and legal link are inert placeholders (author, 2026-10-06), to wire in epics 6 and 7.

## Verification

**Commands:**
- `bin/rails test` -- expected: green
- `bundle exec i18n-tasks missing` and `bundle exec packwerk check` -- expected: clean
- `npm run lint && npm run typecheck` -- expected: clean

**Manual checks (if no CLI):**
- Open a shared link signed out on desktop and phone width; confirm the tilt, layout and sheet.
