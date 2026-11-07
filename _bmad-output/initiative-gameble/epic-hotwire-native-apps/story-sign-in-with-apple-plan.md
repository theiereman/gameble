---
title: 'Sign in with Apple'
type: 'feature'
ticket: '4'
created: '2026-11-04'
status: 'in-progress'
baseline_revision: 'dc14af1e4ee85275be0aa28f0ac69d5994fec333'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The store requires Sign in with Apple once an app offers other third-party sign-ins, and the sign-in screens offer Discord, Google and an email code only.

**Approach:** Add Apple as a Clerk OAuth provider beside Discord and Google on the web and in the apps, as an identity provider with its check constraint, its copy and its tests; Apple's own configuration in Clerk and in the Apple developer account is a person's step.

</frozen-after-approval>

## Implementation Notes

The code side is done and tested: provider list, check constraint (added not validated, then validated in its own migration), the button, the strategy in the script, the labels, the known-email message and the privacy copy in both languages. Left to a person: enable Apple in the Clerk dashboard with a Services ID and a key from the Apple developer account, and try it once on a device. The status stays in-progress until then.
