# Review — are named technologies verified current?

Verdict: yes for versions; two fits are unverified.

- Every version in the Stack table was read from the RubyGems or npm registry API on 2026-10-02; Ruby from ruby-lang.org; PostgreSQL from a web search (18.4 latest stable, 19 in beta in June 2026).
- **Unverified fit (medium):** `omniauth-openid` 2.0.2 on Rails 8.1 and Rack 3. Recorded under Deferred with a fallback.
- **Unverified fit (low):** all gems on Ruby 4.0.7. A fallback to Ruby 3.4.11 is recorded under Stack.
- **Corrected during the run:** an early search suggested Packwerk was inactive since 2024 and Rails Event Store was at 2.18; the registries show Packwerk 3.3.1 (August 2026) and Rails Event Store 3.2.0 (September 2026).
- **Not verified:** the user's statement that Solid Cable gained batching. The spine does not depend on it: batching is done by the broadcast job (AD-13).
