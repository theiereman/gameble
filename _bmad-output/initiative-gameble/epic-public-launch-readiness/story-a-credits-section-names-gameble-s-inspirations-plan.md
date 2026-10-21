---
title: 'A credits section names gameble’s inspirations'
type: 'feature'
ticket: 59
created: '2026-10-21'
status: 'draft'
baseline_revision: ''
route: 'oneshot'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** gameble names none of the works that inspired it, and nothing in the app thanks them.

**Approach:** A public « Crédits » page (`GET /:locale/credits`, readable signed out like the legal page) lists each inspiration with what it inspired, under a line saying they are inspirations and never affiliations; it is linked from the legal page and the landing footer. English and French copy.

**Decisions (author, 2026-10-21):** the list holds WikiMasters (the collect-and-show loop), Helldivers 2 (panels, readouts and the mock-solemn tone), Balatro and Dead Cells (fine pixel art over detailed material) and Hearthstone (the structure of ornamental card backs). Wikigacha, Steam Trading Cards, Steam's client colors and the author's canvas are not listed. The lore contributors are named later by the author, in their own change: no contributors section yet. The credits page may name these companies' works, an exception to the tone's ban on real company names limited to this page.

## Boundaries & Constraints

**Always:** Pundit `PagePolicy#show?`; every string in `en.yml` and `fr.yml`; no `style` attribute; no planning id in code; the existing no-affiliation notice stays untouched.

**Never:** Name Steam or Valve on the page, list rejected references (the stratagem arrow code, the medieval direction), judge any work (WikiMasters is credited for what it inspired only), or add a contributors section.

</frozen-after-approval>

## Implementation Notes

Oneshot: `PagesController#credits` + route, `app/views/pages/credits.html.erb` (same panel and `legal__*` layout as the legal page), a « Crédits » link in `landings/_footer.html.erb` and at the end of the legal page, `public_read?` extended to `credits`, locales in both files, a controller test (renders signed out, names the four works, the footer and legal page link to it).

## Verification

**Commands:**
- `bin/rails test test/controllers/pages_controller_test.rb` -- expected: pass
- `bin/rails test && bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing` -- expected: pass

**Manual checks:**
- The author approves the page's wording and its list before release.
