# Review — good-spine rubric (run inline by the author of the spine, no independent subagent)

Verdict: sound as a build substrate for the level below.

- **Divergence points covered:** state mutation (AD-3), ownership of shared data (AD-5, AD-6), pack granting (AD-7), trades (AD-8), derived data (AD-10), identity (AD-14), public ids (AD-15), browser split (AD-16), copy (AD-18).
- **Enforceable rules:** AD-2, AD-18, AD-21 and AD-22 are enforced by CI tools; AD-6 and AD-9 by database constraints; the rest by review and tests.
- **Operational envelope:** covered by AD-19, AD-21 and the Deferred list (staging, backups).
- **Spec coverage:** all 18 capabilities appear in the Capability map.
- **Finding (medium):** AD-11 relies on developers choosing the reading role per request; nothing checks it automatically. Accepted: it only matters when a replica is added.
- **Finding (low):** the Stack table is long for a spine; it is seed and the code owns it after scaffold.
- **Limit of this review:** an inline self-check is weaker than an independent reviewer.
