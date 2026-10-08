---
title: 'Remove the CI production image job'
type: 'chore'
ticket: '13'
created: '2026-10-08'
status: blocked
baseline_revision: '5df87f9982b712eed9333e2cab05ca6e912dfd7e'
route: 'oneshot'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
blocked_at: "2026-10-08"
blocked_reason: "no subagents"
---

<intent-contract>

## Intent

**Problem:** The `docker-image` job in `.github/workflows/ci.yml` builds the production image and checks `/up` through `bin/docker-smoke` on every pull request and push to `main`. The Kamal deploy to staging (`deploy-staging.yml`, `bin/kamal deploy -d staging`) already builds the same image and kamal-proxy checks `/up` before the new version takes traffic, so the CI job only duplicates it and spends Actions minutes (author decision, 2026-10-08).

**Approach:** Delete the `docker-image` job from `ci.yml`, delete `bin/docker-smoke`, and update the CI header comment so it no longer lists the production image among the jobs. Leave the staging deploy, the Dockerfile and the Kamal configuration untouched. Done when the CI workflow has no image job and no file references `docker-smoke`, `docker-image` or `gameble-smoke` outside the planning history.

</intent-contract>

## Implementation Notes

Oneshot: two files, under 20 lines removed, no code or test touches them.

- `.github/workflows/ci.yml`: remove the `docker-image` job (lines 38-50 at baseline) and drop "production image" from the header comment's list of jobs that run only on main, pull requests and on demand.
- `bin/docker-smoke`: delete. Its only reference is the job above (`git grep docker-smoke` at baseline: `ci.yml:50` and the script's own comment).
- Kept: `deploy-staging.yml` (builds with Buildx through `bin/kamal deploy -d staging`), `Dockerfile`, `config/deploy*.yml` (kamal-proxy's default healthcheck path is `/up`, not overridden).
- The dropped story 7.1 plan (`story-the-production-image-builds-in-ci-plan.md`) is history and stays as is; its deferred item (the smoke run skipped Thruster and `db:prepare`) lapses with the script.
- Done: the job and the script are gone; the header comment now says the image is built and checked by the Kamal deploy to staging. Removing the job also dropped a whitespace-only line after `scan_ruby`'s last step.
- No Ruby or JS test references the script or the job (`git grep` over `test/` and `spec/` returns nothing), so no test is affected.
- Docker has no daemon here; the staging deploy cannot be run from this container.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `uvx --from actionlint-py actionlint .github/workflows/ci.yml .github/workflows/deploy-staging.yml` -- expected: no findings.
- `git grep -n -E 'docker-smoke|docker-image|gameble-smoke' -- . ':(exclude)_bmad-output' ':(exclude)_bmad'` -- expected: no output.
- `ruby -ryaml -e 'puts YAML.load_file(".github/workflows/ci.yml")["jobs"].keys'` -- expected: scan_ruby, lint, test, system-test.
- `bin/rubocop` -- expected: no offenses.

**Manual checks (if no CLI):**
- The proof is the CI run on the pull request after the orchestrator pushes: it must pass with no `docker-image` job, and the next staging deploy from a release must still build the image and pass kamal-proxy's `/up` healthcheck.

## Auto Run Result

- Status: blocked. Blocking condition: no subagents. This session has no tool to launch a context-free reviewer, so the review step's Quick lens could not run. The workflow makes subagents mandatory, so the run halted before review instead of reviewing in-session.
- Summary: the implementation is complete and verified. The `docker-image` job is removed from CI and `bin/docker-smoke` is deleted. The CI header comment now says the Kamal deploy to staging builds and checks the image.
- Files changed:
  - `.github/workflows/ci.yml`: the `docker-image` job is removed and the header comment is updated.
  - `bin/docker-smoke`: deleted.
  - This plan.
- Review findings: none, because no review ran.
- Verification:
  - `actionlint` on ci.yml and deploy-staging.yml: exit 0, no findings.
  - `git grep` for docker-smoke, docker-image and gameble-smoke outside `_bmad` and `_bmad-output`: no output.
  - The CI job keys are now scan_ruby, lint, test and system-test.
  - `bin/rubocop`: 546 files inspected, no offenses.
  - No Docker daemon is available here, so the staging deploy cannot be exercised.
- Residual risks: none known in the repo. The GitHub plan of this private repository has no branch protection (the API answers 403), so no required `docker-image` status check can keep pull requests waiting.
- To unblock: re-dispatch this plan in a session that can launch subagents, which then runs only the review (status `in-review`). Alternatively, the author reviews the commit and sets the status himself.
