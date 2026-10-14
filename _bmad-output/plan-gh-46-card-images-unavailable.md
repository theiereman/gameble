---
title: 'Fix grayscale card artwork being rejected as unavailable'
type: 'bugfix'
ticket: ''
created: '2026-10-14'
status: 'built'
baseline_revision: '30b630953109893329ff6078aa022dde3991cbc5'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context:
  - '_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Legitimate grayscale Steam covers, including Gato Roboto, Hidden Folks and 100 Hidden Cats 2, are classified as Steam's grey placeholder by the filtered card-art pipeline. Their raw booster tray thumbnails load, but the shared card face used by booster reveal, collection and detail shows "IMAGE UNAVAILABLE".

**Approach:** Narrow placeholder detection to reject only near-uniform grey images while allowing grayscale artwork with meaningful tonal variation. Preserve minimum-size checks, palette filtering, CORS fallback, and the shared `CardComponent` rendering path.

</frozen-after-approval>

## Implementation Notes

The fix is routed as oneshot because it is a focused TypeScript predicate and regression-test change, estimated below 100 modified lines. Update the adopted architecture wording from "single channel" to the narrower placeholder rule so code and design remain consistent. Do not add system tests because this repository currently disables them; cover behavior at the pure predicate and worker-job levels.

- Replaced the all-grayscale rejection with `isFlatGrey`: pixels must stay grey and within a 24-level tonal range. The known Steam placeholder spans 18 tone values; the reported Gato Roboto and Hidden Folks covers span the full 0–255 range.
- Updated `placeholder.ts`, its unit tests, the worker job and its regression tests, plus AD-17's wording. The raw booster thumbnail and all server/catalog paths remain unchanged.
- Verification: targeted Vitest suites passed (26 tests), the full JavaScript suite passed (279 tests), and TypeScript typechecking passed.

## Plan Change Log

## Review Triage Log

- `low` / patched -- `placeholder.ts` retained the planning identifier `AD-17` in a rewritten code comment, contrary to the repository policy. Removed the identifier; the external Steam constraint remains stated without planning vocabulary.

## Verification

**Commands:**
- `npm run test:js` -- expected: all Vitest suites pass, including grayscale-cover and flat-grey-placeholder regressions
- `npm run typecheck` -- expected: TypeScript reports no errors
