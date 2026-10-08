---
title: 'The production image builds in CI'
type: 'chore'
ticket: '1'
created: '2026-10-07'
status: dropped
baseline_revision: 'e419296bcc721682f3ba0eafef14b228311cacf9'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      The CI smoke run starts `./bin/rails server` directly, so it does not cover Thruster (the image's CMD) or the entrypoint's `db:prepare`.
    evidence: |-
      bin/docker-smoke passes its own command after the image name. That replaces the Dockerfile's
      CMD ["./bin/thrust", "./bin/rails", "server"], and because the command no longer ends in
      `./bin/rails server`, bin/docker-entrypoint skips `db:prepare`. A break in bin/thrust or in
      `db:prepare` against the four production databases would pass CI and only fail at deploy.
      Closing the gap needs a Postgres service reachable from the container and the real CMD on port 80.
      This was already true of b41318813f2d76df0ddeba2a3730127feb187da2; this pass did not cause it.
    location: >-
      bin/docker-smoke:24
    severity: low
---

<intent-contract>

## Intent

**Problem:** Nothing in CI proved that the production Docker image still builds and boots, so a broken Dockerfile, a failing `assets:precompile` or an exception at production boot would only show up at `bin/kamal deploy` (epic 7, R7, Done when 7; AD-21, AD-22).

**Approach:** A `docker-image` job in `.github/workflows/ci.yml` runs `bin/docker-smoke` on every pull request and every push to `main` and `develop`. The script builds the image without pushing it, starts a container with throw-away `SECRET_KEY_BASE` and `PUBLIC_URL` and no database, and fails unless `/up` answers 200 within 60 seconds. Because `deploy-staging.yml` deploys only after a green CI run, a broken image also blocks the staging deploy.

</intent-contract>

## Implementation Notes

Oneshot: the job and the script already exist. Commit b41318813f2d76df0ddeba2a3730127feb187da2 ("feat/ci: story 7.1, the production image builds in CI and answers /up") added them on 2026-10-07 and was merged into develop, but it left no plan and no board status. This pass checks that work against the ticket, fixes the one remaining inconsistency, and records the evidence. The change is under 5 lines.

- What was already built and is kept as is:
  - `bin/docker-smoke` runs `docker build --tag gameble-smoke .`, so the image is never pushed. It then runs `./bin/rails server --binding 0.0.0.0 --port 3000` in place of the image's `CMD`. The command no longer ends in `./bin/rails server`, so `bin/docker-entrypoint` skips `db:prepare` and no database is needed. Rails' `/up` (`Rails::HealthController`) does not query one, and `config.ssl_options` excludes `/up` from the https redirect.
  - The script polls `/up` with curl for up to 60 seconds. It stops early if the container exits, prints the container logs and exits 1 on any failure. An `EXIT` trap removes the container.
  - The Dockerfile's `# check=error=true` turns BuildKit build-check warnings into build failures.
  - No real secret reaches the job: there is no `RAILS_MASTER_KEY` and no repository secret.
- Changed in this pass: the `docker-image` job in `.github/workflows/ci.yml` checked out with `actions/checkout@v6`, while every other job in both workflows uses `@v7`. Dependabot's github-actions updates had bumped the others. It now uses `@v7`.
- Evidence from CI (GitHub Actions, read-only):
  - run 37632657944 on develop at the baseline e419296: `docker-image` succeeded in 2m22s, and its log ends with "/up answered 200".
  - runs 37627869273, 37626417105, 37621196466, 37620336212 and 37618167789 on develop: `docker-image` was green each time. Those runs were red only because of `system-test`.
- Docker has no daemon in this container (`/var/run/docker.sock` is missing), so the image build and the `/up` check cannot be run here.
- Subagents: none were needed on the oneshot route.
- Review: subagents unavailable, done in-session. This session has no Agent tool, so the Quick lens ran here instead of in a context-free child. The repo has no AGENTS.md or CLAUDE.md to review against.
- Left as is:
  - shellcheck's SC2198 on `bin/docker-entrypoint`, the stock Rails entrypoint.
  - shellcheck's SC2329 info on `cleanup` in `bin/docker-smoke`, a false positive: `trap` invokes it.
- Boundary: the smoke run skips Thruster (the image's `CMD` is `./bin/thrust ./bin/rails server`) and the entrypoint's `db:prepare`. Running the real `CMD` needs a database for `db:prepare`. The ticket asks that the container boots and answers `/up`, which the Puma boot in production mode proves, and every Kamal deploy then exercises the Thruster path.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[defer]` The smoke run replaces the image's CMD (Thruster) and so skips the entrypoint's `db:prepare`. A break in either would pass CI. — Real: bin/docker-smoke:24 passes `./bin/rails server --binding 0.0.0.0 --port 3000` as the command. Pre-existing since b413188, not caused by this pass. The ticket asks only that the container boot and answer /up, which the production-mode Puma boot proves. Recorded in `deferred`.
- Acceptance checked against the diff:
  - `docker-image` runs on `pull_request` and on `push` to main and develop (top-level `on:` of ci.yml).
  - The failure paths are real: `set -euo pipefail` around `docker build`, and `exit 1` when /up never answers 200.
  - `actions/checkout@v7` is the version every other job uses, and those jobs passed in CI run 37632657944.

## Verification

**Commands:**
- `uvx --from actionlint-py actionlint .github/workflows/ci.yml .github/workflows/deploy-staging.yml` -- expected: no findings.
- `uvx --from shellcheck-py shellcheck bin/docker-smoke` -- expected: only the SC2329 info on `cleanup` (a false positive: `trap` calls it).
- `bin/docker-smoke` (needs a Docker daemon, not present in this container) -- expected: "/up answered 200" and exit 0.

**Manual checks (if no CLI):**
- Read `.github/workflows/ci.yml` and check three things: `docker-image` runs on `pull_request` and on `push` to `main` and `develop`; it uses `actions/checkout@v7`; and its only other step is `bin/docker-smoke`.
- The proof is the CI run after the orchestrator pushes this branch's merge into develop: the `docker-image` job must succeed and its log must end with "/up answered 200". A non-zero exit from `docker build`, or no 200 from `/up` within the timeout, makes the job and the run red, and `deploy-staging.yml` then does not deploy.

## Auto Run Result

- Summary: story 7.1 was already implemented in b41318813f2d76df0ddeba2a3730127feb187da2 (merged into develop by 0fcc5f2) but had no plan and no board status. This pass checked it against the ticket, aligned the `docker-image` job's checkout action with the other jobs, and recorded the CI evidence.
- Files changed:
  - `.github/workflows/ci.yml`: the `docker-image` job checks out with `actions/checkout@v7` (was `@v6`), like every other job.
  - `_bmad-output/initiative-gameble/epic-public-launch-readiness/story-the-production-image-builds-in-ci-plan.md`: this plan.
- Review findings:
  - patches applied: 0.
  - deferred: 1, low. The smoke run skips Thruster and the entrypoint's `db:prepare`.
  - rejected: 0.
- Follow-up review recommended: false. No entry was patched (high 0, medium 0, low 0).
- Verification:
  - `actionlint` on ci.yml and deploy-staging.yml: no findings.
  - `shellcheck bin/docker-smoke`: only SC2329 (info) on `cleanup`, a false positive because the EXIT trap calls it.
  - No Docker daemon is available here, so `bin/docker-smoke` was not run locally.
  - CI evidence on develop at the baseline (run 37632657944): `docker-image` was green and its log ends with "/up answered 200". The job was also green in the five runs before it.
  - The proof for this branch is the CI run after the orchestrator pushes the merge into develop: the `docker-image` job must pass and log "/up answered 200".
- Residual risks: the Thruster and `db:prepare` path is not covered (see `deferred`). Kamal's own healthcheck covers it at deploy time.
