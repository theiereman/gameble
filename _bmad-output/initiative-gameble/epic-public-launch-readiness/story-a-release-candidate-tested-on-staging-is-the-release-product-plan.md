---
title: 'A release candidate tested on staging is the release production runs'
type: 'feature'
ticket: '58'
created: '2026-10-15'
status: 'built'
baseline_revision: '4582ccb61d892b603f600d403c16bb3b392455e2'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/RELEASING.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Any GitHub release on `develop` deploys staging, production has no release flow at all, and the version shown is baked into the image at build time, so an image tested on staging could not be shown as a production release without being built again.

**Approach:** Build once, promote the same image. A pre-release `vX.Y.Z-rc.N` on `develop` runs the full CI, deploys staging and marks its commit with a `staging` status. `bin/promote` fast-forwards `main` to an accepted candidate and publishes `vX.Y.Z` on the same commit. That release starts a production workflow that copies the candidate's image to a release package, waits for the author's approval, and deploys it with `--skip-push`. `RELEASING.md` (already drafted at the repo root) is the documentation and lands in this change.

## Boundaries & Constraints

**Always:**
- Production never builds an image: it runs `ghcr.io/theiereman/gameble-releases:<sha>`, copied registry-side from the staging image `ghcr.io/theiereman/gameble:<sha>`.
- The copy and every gate run in a job before the approval, so a rejected run still leaves the image for a hand-run `kamal setup`.
- The version shown is computed at deploy time from the tags of the deployed commit; a release tag wins over a candidate tag on the same commit (the same rule as `release_at` in the post-deploy hook).
- `main` only moves by fast-forward to a candidate's commit.
- Decision (author, 2026-10-15): the approval in the GitHub environment `production` stands for the manual acceptance; the first production version is `v1.0.0`; the first production `kamal setup` is run by hand, and the workflow never runs `setup`.

**Never:**
- No merge commit on `main`, no PR from `develop` to `main`.
- No planning ids in code, workflows or comments.
- Do not change the post-deploy announcement's content or its Discord behaviour, beyond the production webhook file the workflow writes.
- Do not create the GitHub environment or its secrets from code: the author does it.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Candidate | pre-release `v1.0.0-rc.1` on `develop` | full CI, then staging deploy, then status `staging=success` on the sha | CI failure: no deploy, no status |
| Not a pre-release | release `v1.0.0` | staging workflow deploys nothing | — |
| Off develop | pre-release whose commit is not on `develop` | nothing deployed, said in the log | — |
| Promote ok | `bin/promote v1.0.0-rc.2`, status ok, `main` ancestor | `main` fast-forwarded, release `v1.0.0` published on the sha, notes since the previous `vX.Y.Z` | — |
| Promote refused | not `-rc.N`; not on develop; no `staging` status; `v1.0.0` exists; `main` not an ancestor | exit non-zero, reason printed, nothing pushed | — |
| Production gate | release whose sha is not `origin/main`, or no `staging` status, or tag not `vX.Y.Z` | workflow fails before approval | — |
| Production deploy | approved | `kamal deploy -d production --skip-push`, Discord announcement | Kamal keeps the old version on failure |
| Rollback | `workflow_dispatch` with `rollback_to: v1.0.0` | after approval, `kamal rollback -d production <sha>` | unknown tag: fails |
| pre-deploy, production | deploy of a sha not tagged `vX.Y.Z` or not `origin/main` | refused | rollback let through |

</frozen-after-approval>

## Code Map

- `.github/workflows/deploy-staging.yml` -- release-triggered staging deploy; gate step on `develop`, secret files, `bin/kamal deploy -d staging`, image cleanup with `actions/delete-package-versions@v5` (keeps 5 of package `gameble`). Restructure into jobs gate → ci → deploy.
- `.github/workflows/ci.yml` -- jobs scan_ruby (skipped on push to develop through `github.event_name`), lint, test; system-test is `if: false`. Add `workflow_call`; when called, `github.event_name` is the caller's (`release`), so the scans run.
- `.kamal/hooks/pre-deploy` -- POSIX sh; refuses untagged or dirty versions for any destination, lets rollback through. Add the production rule.
- `.kamal/hooks/post-deploy` -- Ruby; `Repository#release_at` already sorts with `versionsort.suffix=-`, so a release names the commit over its candidate. Reads `config/discord_webhook.<destination>.key`. No change expected.
- `config/deploy.yml` -- `builder.args.GAMEBLE_VERSION` ERB (`git describe --exact-match`); move it to `env.clear` with the release-wins rule.
- `config/deploy.production.yml` -- add `image: theiereman/gameble-releases`; update the header comment's deploy line.
- `Dockerfile` (lines ~79-81) -- remove `ARG`/`ENV GAMEBLE_VERSION`.
- `app/helpers/shell_helper.rb:44-48` -- comment says the version comes from builder args; reword. `test/helpers/shell_helper_test.rb:115` stays valid.
- `.kamal/secrets.production` -- the key files the production workflow must write: `master.key`, `secret_key_base.production.key`, `sentry_dsn.key`, `database_password.production.key`, `steam_api.key`, `registry_password.key`.
- `test/lib/post_deploy_hook_test.rb` -- throwaway repo with a bare origin; `pre_deploy(version:, command:, destination:)` helper. Extend for the production rule, with an `origin/main` ref in the throwaway repo.
- `README.md` "Branches and deployment" -- rewrite to point at `RELEASING.md`; drop the statements the new flow contradicts (any release deploys staging, manual production deploy, builder args).
- `RELEASING.md` -- the documentation; adjust it to what is built.

## Tasks & Acceptance

**Execution:**
- [x] `config/deploy.yml`, `Dockerfile`, `app/helpers/shell_helper.rb` -- version as `env.clear.GAMEBLE_VERSION` at deploy time, release tag over candidate tag, short sha without a tag -- one image, two names.
- [x] `config/deploy.production.yml` -- `image: theiereman/gameble-releases`, header comment pointing at `RELEASING.md` -- production pulls the release package, never cleaned.
- [x] `.github/workflows/ci.yml` -- add `workflow_call` -- staging runs the full CI.
- [x] `.github/workflows/deploy-staging.yml` -- gate job (pre-release and on `develop`), `ci` job calling `ci.yml`, deploy job needing both; after the deploy, POST a commit status `context=staging state=success` (`statuses: write`) -- the proof promotion requires.
- [x] `.github/workflows/deploy-production.yml` -- new: `release` (published, not pre-release) → job `release-image` (gates: tag `^v\d+\.\d+\.\d+$`, sha equals `origin/main`, latest `staging` status success; `docker buildx imagetools create` to `gameble-releases:<sha>`) → job `deploy` (`environment: production`, SSH and secret files from `PRODUCTION_*` and environment secrets, `bin/kamal deploy -d production --skip-push`); `workflow_dispatch` input `rollback_to` → job `rollback` (`environment: production`, checkout of that tag, `bin/kamal rollback -d production <sha>`); `concurrency: deploy-production`.
- [x] `bin/promote` -- new executable, written so a test can load it without running it (as the post-deploy hook is), every refusal of the matrix, a y/N confirmation unless `--yes`, `gh` through an overridable command for tests.
- [x] `.kamal/hooks/pre-deploy` -- production: the version carries a `vX.Y.Z` tag and equals `origin/main` after a quiet `git fetch origin main` (a failed fetch compares to the local ref); rollback still passes.
- [x] `test/lib/post_deploy_hook_test.rb`, `test/bin/promote_test.rb` (new) -- the pre-deploy production rule and the promotion refusals and happy path against a throwaway repo and a stub `gh`.
- [x] `README.md`, `RELEASING.md` -- README points at RELEASING.md; RELEASING.md matches what is built (release package, rollback reach, first setup).

**Acceptance Criteria:**
- Given a commit tagged `v1.0.0-rc.1` and `v1.0.0`, when the deploy config is rendered, then `GAMEBLE_VERSION` is `v1.0.0`; with only the candidate tag, `v1.0.0-rc.1`; untagged, the short sha.
- Given the workflows, when `actionlint` (if available) or a YAML parse runs, then all three parse and the production deploy and rollback jobs name `environment: production`.
- Given `bin/kamal config -d production`, then the image is `ghcr.io/theiereman/gameble-releases`, and staging's stays `ghcr.io/theiereman/gameble`.

## Implementation Notes

- Implemented by a subagent; every task checked. Targeted tests 74/74, full suite 2559/0, rubocop clean, actionlint 1.7.7 (Docker) clean on the four workflows, shellcheck clean on pre-deploy; `bin/kamal config` gives `gameble-releases` for production and `gameble` for staging.
- Matrix audit: the promotion rows, the pre-deploy production row and the version naming are covered by `test/bin/promote_test.rb` and `test/lib/post_deploy_hook_test.rb`, which ran and passed. The rows that live in GitHub workflows (candidate, not a pre-release, off develop, production gate, production deploy, rollback) have no runnable test in the repository: they are checked statically by actionlint, the gate's jq was run against the real status API (`missing` for a commit with no staging status), and the first real candidate is the manual check.
- Beyond the Code Map: `close-main-pull-requests.yml` comment and closing message say main moves by promotion; README's Sentry step and journald recipe updated to the release flow (`--skip-push`).
- Rollback detects Kamal's "is not available as a container" message, because Kamal exits 0 when the version has no container left.
- RELEASING.md asks the environment `production` to allow the branch `main` too, since a rollback run is dispatched from a branch.
- The Implementation Notes, Plan Change Log and Review Triage Log sections were missing from the plan as written at planning time and are added here.

## Plan Change Log

## Review Triage Log

Pass 1 (quick): high 0, medium 2, low 1, false 0, maybe-false 0.

| Finding | Verdict | Route | Evidence |
|---|---|---|---|
| Both deploy workflows fire on every `release: published` with one workflow-level concurrency group, so a no-op run (a pre-release in production, a release in staging) joins the group and cancels a real run pending behind one waiting for approval | medium | patch | Workflow-level `concurrency` applies when the run is created, before job `if:`s skip; GitHub keeps one pending run per group and cancels the older pending one. Fix: production `types: [ released ]`, staging `types: [ prereleased ]`. |
| Staging cleanup counts provenance attestation manifests as package versions, so "five images" can be one or two and an older candidate's image can lose its manifest before promotion copies it | medium | patch | Kamal 2.12 passes `--provenance` only when `builder.provenance` is set (`commands/builder/base.rb#builder_provenance`), and it is unset, so buildx's default attestation turns each push into an index plus attestation manifests that ghcr lists as separate versions. Fix: `provenance: false` in `config/deploy.yml`'s builder. Registry not inspected (no read:packages token). |
| RELEASING.md tells the author to delete a rejected release, which leaves the tag, so `bin/promote` refuses every later candidate of that version and the Never section forbids deleting a tag | low | patch | `release_exists?` checks `refs/tags/<release>`; `gh release delete` keeps the tag. Fix: a rejected release is re-run later or followed by the next patch candidate. |

## Design Notes

A separate package `gameble-releases` exists because the staging cleanup keeps only the last five versions of `gameble`, and `delete-package-versions` matches a container version by digest, not by tag, so it cannot spare release images. A package the workflow creates with `GITHUB_TOKEN` is linked to the repository.

The staging status is a commit status rather than a workflow-run lookup, because a release on the same commit also triggers the staging workflow (skipped), which would make a run lookup ambiguous.

## Verification

**Commands:**
- `bin/rails test test/lib test/helpers/shell_helper_test.rb test/bin` -- expected: pass
- `bin/kamal config -d production` and `-d staging` -- expected: images as above
- `bundle exec rubocop bin/promote test` -- expected: no offenses
- `actionlint` if installed, else `ruby -ryaml -e 'YAML.load_file(...)'` on each workflow -- expected: parse

**Manual checks (if no CLI):**
- The first real candidate after merge: staging deploys, the commit shows a `staging` status on GitHub.
