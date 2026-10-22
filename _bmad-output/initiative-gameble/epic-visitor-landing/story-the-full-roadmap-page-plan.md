---
title: 'The full roadmap page'
type: 'feature'
ticket: '12'
created: '2026-10-22'
status: 'built'
baseline_revision: 'd49fccb518fd6a5aebc3d8de7e367b0030dee4d8'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      The page has no date column value and no sentence under a milestone's title: the roadmap data has neither field.
    evidence: |-
      catalog_roadmap_milestones has wording, status, shown and position only; the design shows a date label and a sentence.
    severity: medium
  - summary: >-
      The date column's status word is coloured per status, where the design sets it muted.
    evidence: |-
      roadmap.css `.roadmap-milestone__when`; the plan reduces the column to the status word.
    severity: low
---

<intent-contract>

## Intent

**Problem:** Module 06 of the landing shows at most six milestones with two stories each and has no way to see the rest; the roadmap page that holds every shown milestone and story is designed but not built, and the module has no link to it.

**Approach:** A public, indexable page at `/:locale/roadmap` renders every shown milestone and every shown story from the database, as a vertical rail in the landing's family (landing top bar without the motion switch, shared landing footer, star field); module 06 gets an always-visible link to it.

## Boundaries & Constraints

**Always:** Read through a new query in the catalog pack (`Catalog::PublicRoadmap.call(locale:)`, all shown milestones in staff order, each with all its shown stories in order, wording in the locale, cached per locale like `Catalog::LandingRoadmap`), never a model from the controller. A GET writes nothing; the controller authorizes through a Pundit policy and opens GET/HEAD to any browser (`PublicRead`); the route is `get "roadmap"` under the locale scope; add the page to the public-read throttle list. Page design (the rules win over the mock): `DESIGN.md` "Roadmap page" and `EXPERIENCE.md` Roadmap page rows (Copy deck, Screens table, Semantics, Accessibility, States): kicker "Feuille de route"/"Roadmap", one h1 "Les changements à venir"/"What's coming" and the intro line, an ordered list named "Étapes de la feuille de route, des plus anciennes aux plus lointaines" (en: "Roadmap milestones, from the oldest to the most distant"), one h2 per milestone (its wording), status badge as text ("Fait"/"En cours"/"À venir", en "Done"/"In progress"/"Upcoming"), sentence not available (no field exists; omit it), each visible story as a row with its marker (decorative, hidden from assistive technology) and its status word as text; node, rail line and bracket corners decorative and hidden from assistive technology; node/line/panel styling per status exactly as the design table; the last milestone's line fades out over 96px; a milestone without visible stories ends after its title (no empty list); phone layout under 640px (rail on the left, status word above the panel); content column at most the landing content width, 96px above and 112px below on desktop (56px/64px phone). The landing's top bar without the motion switch (visitor), `content_for :public_page`, the footer partial `landings/_footer`, links show focus. Every new string in both `en.yml` and `fr.yml` (French strings exactly as in the Copy deck; English as in the deck). No JavaScript needed. The page title and a meta description in both languages. The module 06 link "Voir toute la feuille de route"/"See the whole roadmap" is always rendered, even with no milestones, as a link-styled button after the legend.

**Never:** Do not show hidden milestones or stories. Do not add a date column value: the data has no dates, so the date column shows only the status word (the date label is deferred until the data carries one). Do not change the back-office, the roadmap data, the landing's other modules or the existing `Catalog::LandingRoadmap` limits. No planning ids in code, no comments except one-line external constraints, English repo text. No `style` attribute in server HTML. No database ids in URLs or HTML.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Many milestones | 8 shown milestones, one with 4 shown stories | all 8 and all 4 stories listed in staff order | none |
| Hidden items | a hidden milestone, a hidden story | neither appears | none |
| No visible stories | milestone with all stories hidden | panel ends after the title; no `ul` | none |
| Single milestone | one shown milestone | node and its fading line render | none |
| Statuses | done, in progress, to come | badge and story word written in text per status | none |
| Locale | /fr/roadmap and /en/roadmap | wording and copy in that language | none |
| Signed in | a signed-in player opens it | the page renders (public page) | none |
| Module 06 link | landing with or without milestones | link to the page always present | none |

</intent-contract>

## Code Map

- `app/views/landings/_roadmap.html.erb`, `app/frontend/styles/landing.css` -- module 06 (class names `landing-roadmap__*`, `button button--link` link pattern in `_concept.html.erb`); add the link after `.landing-legend`.
- `packs/catalog/app/queries/catalog/landing_roadmap.rb` -- the pattern for the new `packs/catalog/app/queries/catalog/public_roadmap.rb` (Data structs, cache key, `I18n.with_locale`); models `Catalog::RoadmapMilestone`/`RoadmapStory` (`shown`, `ordered`, `wording`, `status`, includes `RoadmapWording::Localized`). Tests for the pack: look beside `landing_roadmap` tests under `packs/catalog/test` or `test/`.
- `app/controllers/landings_controller.rb`, `app/policies/landing_policy.rb`, `app/controllers/concerns/public_read.rb` -- controller/policy pattern for `RoadmapsController`/`RoadmapPolicy`; `config/routes.rb` line ~16 (`landing`); `config/initializers/rack_attack.rb` `PublicReadThrottle::PAGES`.
- `app/views/shell/_top_bar.html.erb` -- `controller_path == "landings"` picks the landing's wordmark (not a link) and the motion switch; the roadmap page uses the landing wordmark treatment (home link is fine on this page: the wordmark leads home, see `shell_home_path`) without the motion switch.
- `app/views/landings/show.html.erb`, `_footer.html.erb`, `app/views/layouts/application.html.erb` (`content_for :public_page`, `:page_footer`) -- page shell; landing styles for footer in `landing.css`.
- `_bmad-output/initiative-gameble/ux-gameble/mockups/key-roadmap-page.html` -- reference render (look only, not code); tokens in `app/frontend/styles/tokens.css` (`--space-landing-content-max`); add `roadmap.css`-style rules into `landing.css` or a new `app/frontend/styles/roadmap.css` imported where `landing.css` is.
- `config/locales/en.yml`, `fr.yml` -- `landings:` namespace and `i18n-tasks` (dynamic keys need care; run `bundle exec i18n-tasks missing`/`unused`).
- Tests: `test/controllers/landings_controller_test.rb` (`seed_roadmap`), `test/system/landing_roadmap_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `packs/catalog/app/queries/catalog/public_roadmap.rb` + its test -- all shown milestones with all shown stories per locale, cached
- [x] `config/routes.rb`, `app/controllers/roadmaps_controller.rb`, `app/policies/roadmap_policy.rb` (+ policy test as the repo does), `config/initializers/rack_attack.rb` -- the public page
- [x] `app/views/roadmaps/show.html.erb` (+ partials), `app/views/shell/_top_bar.html.erb` -- the page and its top bar
- [x] `app/frontend/styles/*` -- the rail, nodes, panels, badges, story rows, phone form
- [x] `app/views/landings/_roadmap.html.erb`, `config/locales/en.yml`, `config/locales/fr.yml` -- module 06 link and every new string
- [x] `test/controllers/roadmaps_controller_test.rb`, `test/system/roadmap_page_test.rb` -- the matrix rows (markup and semantics in controller tests; desktop and phone layout, link from module 06 and focus in a system test)

**Acceptance Criteria:**
- Given shown milestones and stories, when a visitor follows module 06's link, then /:locale/roadmap lists every shown milestone and story with written statuses, in both languages, on phone and desktop.
- Given hidden milestones or stories, then none of them appears.
- Given the page, then it has one h1, one h2 per milestone in an ordered list named as specified, and its decorative parts are `aria-hidden`.
- Given a phone viewport under 640px, then the page has no horizontal scroll and the rail runs down the left edge.
- Given no milestone is shown, then module 06's link is still present.

## Implementation Notes

Two tokens from the design (`roadmap-page-date-column`, `roadmap-page-rail-node`) were added to `tokens.css`. The page's English status for to-come is "Upcoming" while module 06 keeps "To come". `i18n-tasks check-normalized` already reported both locale files before this change.

## Plan Change Log

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` phone padding overridden by the public-page rule — selector made more specific
  - `[low]` `[patch]` last line fades over the panel height, not 96px — mask stop set at 100% minus 96px
  - `[low]` `[defer]` date column status word colours differ from the design — see deferred
  - `[low]` `[reject]` plan checkboxes and notes not filled — updated at finalization

## Design Notes

The sentence under each milestone's title exists in the design but not in the data, so the panel shows badge, title and stories; the date column shows the status word. Both gaps close when the data gains a sentence and a date.

## Verification

**Commands:**
- `npm run test:js`, `npx tsc --noEmit` -- pass
- `bin/rails test` for the changed pack (`packs/catalog`) and `test/controllers/roadmaps_controller_test.rb test/controllers/landings_controller_test.rb` -- pass
- `bin/rails test test/system/roadmap_page_test.rb test/system/landing_roadmap_test.rb` -- pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- clean

## Auto Run Result

- Summary: public roadmap page at /:locale/roadmap listing every shown milestone and story, a catalog query, controller, policy, throttle entry, styles, the landing top bar variant, and module 06's always-visible link.
- Files: catalog public_roadmap query, roadmaps controller/policy/views, roadmap.css, tokens.css, top bar, rack_attack, routes, locales, module 06 partial, tests.
- Review: 2 patches applied, 1 deferred, 1 rejected. The missing date and sentence are deferred (data has no such fields).
- Follow-up review recommended: false.
- Verification: see the implementation hand-back; controller, pack, policy and system tests pass; rubocop, packwerk, zeitwerk, i18n-tasks missing clean.
- Residual risk: not viewed in a real browser.
