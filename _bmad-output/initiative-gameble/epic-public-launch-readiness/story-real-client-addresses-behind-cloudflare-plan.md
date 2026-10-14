---
title: 'Real client addresses behind Cloudflare'
type: 'feature'
ticket: '25'
created: '2026-10-14'
status: 'built'
baseline_revision: '236faa0264f9332f70cf222eb77dc00c11ea1f30'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Behind Cloudflare every request reaches the app from a Cloudflare address, and the Rack::Attack sign-in throttle keys on `request.ip`, so every visitor would share one limit; Rails' own `request.remote_ip` (used by the controllers' `rate_limit`) would equally stop at the Cloudflare hop.

**Approach:** Trust Cloudflare's published ranges as proxies, in addition to Rails' default private ranges, so `request.remote_ip` walks X-Forwarded-For past the Cloudflare hop to the client; key the sign-in throttle on `remote_ip`; have the production kamal-proxy forward the incoming X-Forwarded-For (`forward_headers: true`), which it drops by default when it terminates TLS. An address outside Cloudflare's ranges stays the rightmost untrusted hop, so a client that writes its own header cannot choose its address.

</frozen-after-approval>

## Verification

**Commands:**
- `bin/rails test test/integration/rate_limit_test.rb` -- expected: pass, including a client behind a Cloudflare hop and a forged header from outside Cloudflare
- `bin/ci` and `bin/rails zeitwerk:check` -- expected: green

## Implementation Notes

Oneshot: about 70 lines across an initializer, the throttle, the production proxy setting and the throttle's tests. Cloudflare's ranges were read from https://www.cloudflare.com/ips-v4 and /ips-v6 on 2026-10-14.

- `config/initializers/trusted_proxies.rb` (new): Rails' private ranges plus Cloudflare's, as `action_dispatch.trusted_proxies`; set in an initializer, read when the middleware stack is built.
- `config/initializers/rack_attack.rb`: the sign-in throttle keys on `ActionDispatch::Request#remote_ip`; the controllers' `rate_limit` already used `remote_ip`, so they gain the client's address too.
- `config/deploy.production.yml`: `forward_headers: true`, since kamal-proxy drops the incoming X-Forwarded-For when it terminates TLS. Thruster's own hop is a private address, already trusted.
- `test/integration/rate_limit_test.rb`: two clients behind one IPv4 edge, a client behind an IPv6 edge, a forged header from outside Cloudflare. Without the Cloudflare ranges the first two fail.

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 1, low 1, false 0, maybe-false 0

- `low` patch — the trusted proxies initializer opened with a five-line comment restating the code, against AGENTS.md's one-line rule; cut to the ranges' source and date.
- `medium` patch — `SignInThrottle.client_ip` read `env["action_dispatch.remote_ip"].to_s`, which would turn into "" and put every client in one bucket if Rack::Attack ever ran before ActionDispatch::RemoteIp; now `ActionDispatch::Request.new(request.env).remote_ip`, which falls back to `ip`.
- Checked with no issue: the published ranges, the initializer's timing, the production proxy setting; the `IpSpoofAttackError` on a request carrying both Client-IP and X-Forwarded-For predates this change.
