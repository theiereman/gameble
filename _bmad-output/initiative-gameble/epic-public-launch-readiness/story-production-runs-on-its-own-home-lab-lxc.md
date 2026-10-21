---
id: 57
tracker_status: done
tracker_id: 119
remote: https://github.com/theiereman/gameble/issues/119
type: story
title: "Production runs on its own home lab LXC"
parent: epic-public-launch-readiness
covers: [R7]
after: []
hitl: true
risk: medium
---

# Production runs on its own home lab LXC

## Description

The author brings up the production destination on its own home lab LXC, reached only through a Cloudflare Tunnel: cloudflared on the LXC forwards gameble.net to the LXC's kamal-proxy, so no inbound web port is open and Cloudflare holds the certificate; production's own session secret and database password are generated and kept off the deploying machine; the legal page names the host; the LXC's disk is grown for the images and the database; then the first deploy runs from a tagged release. Every step is the author's, on the home lab, Cloudflare and the deploying machine.

## Acceptance Criteria

Verify: https://gameble.net answers through Cloudflare with a valid certificate and Steam sign-in returns to it; two clients are counted apart by the rate limits; a session cookie taken from staging is refused on production; the containers log to journald; the two production secrets are kept in the author's password manager; the legal page shows the host lines.

## References

- parent — _bmad-output/initiative-gameble/epic-public-launch-readiness/epic-public-launch-readiness.md

## Notes

- Done on 2026-10-15: the LXC gameble-production (192.168.1.44), cloned from staging, was emptied of staging's containers, volumes, images and database copy, given new SSH host keys and machine-id, and journald keeps 30 days; Kamal reaches it on gameble.dotsncircles.com:2225 through Traefik, since gameble.net is proxied by Cloudflare and carries no SSH.
- Done on 2026-10-15: config/deploy.production.yml, .kamal/secrets.production and config/deploy.yml (ghcr.io shared) describe this destination; production adds SECRET_KEY_BASE so no staging session is valid there.
- Decision (author, 2026-10-16): production is reached through a Cloudflare Tunnel instead of a Traefik route, so the app cannot be reached around Cloudflare; Kamal's SSH keeps its Traefik entrypoint :2225.
- Done on 2026-10-16: the tunnel gameble-production created under Networking > Tunnels, cloudflared installed on the LXC as a systemd service, and its published application gameble.net -> http://localhost:80; https://gameble.net answers Cloudflare's 502 until the first deploy. The tunnel token belongs in the password manager.
- To do on the deploying machine: config/master.key, sentry_dsn.key, steam_api.key and registry_password.key as staging has them, plus `bin/rails secret > config/secret_key_base.production.key` and `openssl rand -hex 32 > config/database_password.production.key`, both saved in the password manager; LEGAL_HOST_NAME and LEGAL_HOST_ADDRESS set in config/deploy.production.yml.
- First deploy: `bin/kamal setup -d production` from a tagged release (the pre-deploy hook refuses an untagged commit).
- To do tonight (author, 2026-10-15), with the rest of this server setup: run the first production `bin/kamal setup -d production --skip-push` by hand from the author's machine, as RELEASING.md's Setup section says (the release flow of entry 58 never runs setup); and create the GitHub environment production, its secrets and the deploy key that entry 58 needs.
