# Releasing gameble

How a change on `develop` reaches https://gameble.net. One rule runs through all of it: **the image built and tested for a release candidate is the image production runs.** Production never builds anything: it pulls the image staging already ran and checked.

```
develop ──●──●──●────────●──●──▶
              │           │
        v1.0.0-rc.1   v1.0.0-rc.2      pre-releases: full CI, then staging
              ✗ bug       ✓ accepted
                          │
main ─────────────────────●            fast-forwarded to the candidate's commit
                          │
                       v1.0.0          release: same commit, same image, production
```

| Step | Who | Where | What happens |
|---|---|---|---|
| 1. Cut a candidate | you | GitHub release, pre-release, on `develop` | full CI, build, staging deploy, Discord |
| 2. Accept it | you | https://gameble.dotsncircles.com | the checklist below |
| 3. Promote it | you | `bin/promote` on your machine | `main` moves to the candidate, release `vX.Y.Z` published |
| 4. Approve production | you | GitHub Actions, one click | production deploy, Discord |

## Versions

Versions follow [Semantic Versioning](https://semver.org): `vMAJOR.MINOR.PATCH`.

- **Candidate**: `vX.Y.Z-rc.N`, a GitHub **pre-release** whose tag is on `develop`. `N` starts at 1 and grows with each new candidate of the same version.
- **Release**: `vX.Y.Z`, a GitHub release marked **Latest**, tagged on the exact commit of the accepted candidate. It is never tagged on any other commit.
- Which number goes up:
  - `PATCH` (`v1.0.1`): fixes only;
  - `MINOR` (`v1.1.0`): new features;
  - `MAJOR` (`v2.0.0`): a break players notice, such as a season reset or a removed feature.
- The first production version is `v1.0.0`; its candidates are `v1.0.0-rc.1`, `v1.0.0-rc.2`…
- The `v0.0.N-beta` tags are history: staging deployed them before candidates existed. No new `-beta` tag is made.
- The tags `deployed/staging` and `deployed/production` are moved by the deploy itself, to start the next Discord changelog. Never move them by hand.

The version a player sees in the bottom-left corner is read at deploy time, not baked into the image. Staging shows `v1.0.0-rc.2` and production shows `v1.0.0`, both from the same image. When a commit carries both a release tag and a candidate tag, the release tag wins.

## 1. Cut a release candidate

On GitHub: **Releases → Draft a new release**, then:

1. **Choose a tag**: type the new tag, e.g. `v1.0.0-rc.1`, and pick **Create new tag on publish**.
2. **Target**: `develop`.
3. **Generate release notes**.
4. Tick **Set as a pre-release**. Without it nothing is deployed.
5. **Publish release**.

Or from a terminal:

```sh
gh release create v1.0.0-rc.1 --target develop --prerelease --generate-notes
```

The **Deploy to staging** workflow then runs:

1. the full CI on the candidate's commit: lint, tests, and the security scans that a push to `develop` skips. A failure stops the run here;
2. the image build, pushed to `ghcr.io/theiereman/gameble`, tagged with the commit's sha;
3. `bin/kamal deploy -d staging`, which refuses an untagged commit and waits for `/up` before switching, then the Discord message on the staging channel;
4. a commit status named `staging`, set to success on the commit. It proves the candidate passed CI and runs on staging, and promotion requires it.

A release that is not a pre-release, or whose tag is not on `develop`, deploys nothing to staging.

## 2. Accept the candidate

Walk through staging at https://gameble.dotsncircles.com, on a phone and on a desktop, in French and in English:

- [ ] the bottom-left corner shows the candidate (`v1.0.0-rc.N`);
- [ ] signed out: the landing, the legal page, a shared card link and a public profile open;
- [ ] Steam sign-in returns to the app, and sign-out returns to the landing;
- [ ] a pack opens and its reveal plays; the bank count goes down;
- [ ] the collection shows the new cards; filters and the card detail work;
- [ ] a card or the collection is shared, and the link opens signed out;
- [ ] a friend invitation is sent and accepted; a trade is proposed and accepted between two accounts;
- [ ] the settings change visibility and language;
- [ ] staff: the back-office opens, and the report queue and a player search work;
- [ ] what this release changed, read from the release notes, works as its tickets say;
- [ ] Sentry shows no new `staging` issue for this candidate;
- [ ] the browser console shows no CSP violation.

A failure is fixed on `develop`, through its own pull request or commit like any change. Then cut the next candidate, `v1.0.0-rc.2`, and start again from step 1. A candidate is never fixed in place: no tag is moved and no candidate is promoted with a known failure.

## 3. Promote the candidate

From an up-to-date checkout:

```sh
bin/promote v1.0.0-rc.2
```

It refuses, and changes nothing, when:

- the tag is not a candidate (`vX.Y.Z-rc.N`) or is not on `develop`;
- the candidate's commit has no successful `staging` status;
- the release `vX.Y.Z` already exists;
- `main` is not an ancestor of the candidate. Nothing but promotions moves `main`, so this means someone committed to it.

Otherwise it:

1. fast-forwards `main` to the candidate's commit. There is no merge commit, so `main` holds exactly the tested commit, even if `develop` has moved on since;
2. publishes the release `v1.0.0` on that commit, marked Latest, with notes generated since the previous release, so they cover every candidate in between.

Done by hand, the same is:

```sh
git fetch origin --tags
sha=$(git rev-parse 'v1.0.0-rc.2^{commit}')
gh api "repos/theiereman/gameble/commits/$sha/status" --jq '.statuses[] | select(.context == "staging") | .state'   # must print success
git push origin "$sha:refs/heads/main"                     # refused if it is not a fast-forward
gh release create v1.0.0 --target "$sha" --latest --generate-notes --notes-start-tag <previous release>
```

Never open a pull request from `develop` to `main` and never merge into `main`. A merge creates a commit staging never ran, so production would build and run an image nobody tested.

## 4. Approve the production deploy

Publishing `v1.0.0` starts the **Deploy to production** workflow:

1. Before asking you anything, it checks, and stops at the first failure:
   - the tag is a release (`vX.Y.Z`);
   - its commit is `main`'s head;
   - the commit has the successful `staging` status.
2. It copies the image staging ran, `ghcr.io/theiereman/gameble:<sha>`, to the release package `ghcr.io/theiereman/gameble-releases:<sha>`, registry-side: nothing is built. The staging package keeps only its last five images; the release package is never cleaned, so every release's image stays.
3. It waits for you. On GitHub: **Actions → Deploy to production →** the waiting run → **Review deployments → production → Approve and deploy**. Approving says the checklist of step 2 is done.
4. `bin/kamal deploy -d production --skip-push` pulls the release image and switches once `/up` answers. Its pre-deploy hook checks again that the commit carries `vX.Y.Z` and is `origin/main`.
5. The Discord message on the production channel lists the changes since the version production ran before.

Then check:

- [ ] https://gameble.net shows `v1.0.0` in the bottom-left corner;
- [ ] Steam sign-in works;
- [ ] Sentry shows no new `production` issue in the first hour.

To refuse a deploy, use **Reject** in the same review. Nothing has changed on the server, the release image stays in its package, and the release stays published. To deploy that release later, re-run the rejected run from the same run. A release dropped for good stays as it is and is followed by the next patch candidate (`v1.0.1-rc.1`).

## When something goes wrong

**CI fails on a candidate.** Staging is not deployed and the candidate gets no `staging` status, so it cannot be promoted. Fix it on `develop` and cut the next candidate.

**The production run cannot copy the staging image.** The staging package keeps its last five images, so a candidate followed by five newer ones has lost its image. Cut a new candidate of the same version and promote that one.

**The staging deploy fails.** Read the run's log. `bin/kamal app logs -d staging` shows the containers. Fix it on `develop` and cut the next candidate.

**The production deploy fails before switching.** Kamal keeps the old version serving: players see nothing. Read the run's log, fix the cause and re-run the failed job from the same run. If the cause is in the code, it is a new candidate and a new patch version.

**A release in production is broken.** Roll back first, then fix.

1. Roll back: **Actions → Deploy to production → Run workflow**, with **Use workflow from** `main`, and give **rollback to** the previous release, e.g. `v1.0.0`. The run checks the tag exists, waits for the same approval, then `bin/kamal rollback -d production <sha>` starts that version's container again and Discord announces the rollback.
2. Fix it on `develop`.
3. Cut `v1.0.1-rc.1` and follow the four steps.

A rollback reaches the versions whose containers Kamal kept on the server, the last five deployed: `bin/kamal app containers -d production` lists them, and a rollback to any other fails. An older release is brought back as a new candidate (a revert on `develop`), since `main` only moves forward.

A rollback does not undo migrations. The schema only changes in expand/contract steps, so the version before can always run on the schema after.

**A fix is urgent but `develop` holds work that cannot ship yet.** This does not happen while `develop` only takes finished work. If it ever does, cut a branch `release/1.0.x` from the release, fix it there, tag `v1.0.1-rc.1` on it, and bring the fix back to `develop`. This flow is not set up yet: decide it the first time it is needed.

## Setup, once

Before the first production deploy:

1. **GitHub environment `production`** (Settings → Environments → New environment):
   - **Required reviewers**: `theiereman`;
   - **Deployment branches and tags**: selected branches and tags: the tag pattern `v*.*.*`, for the release runs, and the branch `main`, for a rollback run, which starts from a branch;
   - **Environment secrets**:

     | Secret | Value |
     |---|---|
     | `SSH_KEY` | the private key of a key pair made for the deploy (below) |
     | `SSH_KNOWN_HOSTS` | `ssh.gameble.net ` followed by the LXC's `/etc/ssh/ssh_host_ed25519_key.pub` (`ssh-keyscan` cannot pass through the tunnel) |
     | `CLOUDFLARE_ACCESS_CLIENT_ID` | the Client ID of the Access service token `github-actions deploy production` (below) |
     | `CLOUDFLARE_ACCESS_CLIENT_SECRET` | its Client Secret |
     | `RAILS_MASTER_KEY` | the same as staging's |
     | `SECRET_KEY_BASE` | `bin/rails secret`; production's own |
     | `DATABASE_PASSWORD` | `openssl rand -hex 32`; production's own |
     | `SENTRY_DSN` | the same as staging's |
     | `STEAM_API_KEY` | the same as staging's |
     | `DISCORD_WEBHOOK_PRODUCTION` | the webhook of the production announcement channel |

   Keep `SECRET_KEY_BASE` and `DATABASE_PASSWORD` in your password manager too: GitHub never shows a secret again. If you lose the database password, the app is locked out of its data; if you change the secret, every player is signed out.

2. **SSH through the tunnel.** Kamal reaches the LXC at `ssh.gameble.net`, the tunnel's SSH route, through `cloudflared access ssh` (`config/deploy.production.yml`); no port of the home lab is open. In Cloudflare Zero Trust:
   - **Networks → Tunnels →** the production tunnel **→ Public hostnames → Add**: `ssh.gameble.net`, service `SSH`, URL `localhost:22`;
   - **Access → Service auth → Service tokens → Create**: `github-actions deploy production`; its Client ID and Client Secret are the two `CLOUDFLARE_ACCESS_*` secrets above;
   - **Access → Applications → Add → Self-hosted**: domain `ssh.gameble.net`, with a policy whose action is **Service Auth** that includes that token, and a policy that **Allows** your own email, for your machine.

   On your machine, install `cloudflared`, sign in once with `cloudflared access login https://ssh.gameble.net`, and add to `~/.ssh/config`, so `ssh`, `scp` and Kamal reach the LXC as `ssh.gameble.net`:

   ```
   Host ssh.gameble.net
     User root
     ProxyCommand cloudflared access ssh --hostname %h
   ```

3. **The deploy key**, made on your machine and allowed on the production LXC:

   ```sh
   ssh-keygen -t ed25519 -N '' -C 'github-actions deploy production' -f /tmp/gameble_production_deploy
   ssh-copy-id -i /tmp/gameble_production_deploy.pub ssh.gameble.net
   gh secret set SSH_KEY --env production < /tmp/gameble_production_deploy
   rm /tmp/gameble_production_deploy /tmp/gameble_production_deploy.pub
   ```

4. **The first deploy** boots the database and kamal-proxy before the app, so it runs once from your machine and not from the workflow, which never runs `setup`. Cut and accept `v1.0.0-rc.N`, then promote it **without approving** the production run that `v1.0.0` starts: let its first job copy the image to the release package, then reject it. Then, from a checkout of `v1.0.0`, with the production key files that `.kamal/secrets.production` reads in `config/` (`secret_key_base.production.key` and `database_password.production.key` hold the same values as the environment's secrets):

   ```sh
   git checkout v1.0.0
   bin/kamal setup -d production --skip-push
   ```

   Every later release goes through the workflow.

5. **The Cloudflare Tunnel** must already route https://gameble.net to the LXC (`cloudflared` running there, its published application `gameble.net` → `http://localhost:80`): see `config/deploy.production.yml`.

## Never

- Never push or merge to `main` other than through `bin/promote`.
- Never tag a release (`vX.Y.Z`) on a commit that no candidate ran on staging.
- Never move or delete a published tag. A wrong candidate is followed by the next one; a wrong release by a patch.
- Never deploy production from a machine with `--skip-hooks`. The hooks are what refuses an untested commit.
