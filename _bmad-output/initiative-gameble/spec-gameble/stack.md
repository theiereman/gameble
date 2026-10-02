# Stack and infrastructure direction

Referenced by Constraints. The architecture phase picks the concrete libraries within these bounds.

## Stack

- **Framework:** Ruby on Rails, with server-rendered pages. The author knows it well. Rust and TypeScript were considered and dropped.
- **Interactive parts:** React components embedded in Rails pages for highly interactive screens such as the pack opening. This keeps that code readable instead of one large JavaScript file. The app is not a single-page application.
- **Database:** PostgreSQL.
- **Translation:** Rails' built-in internationalisation, for French and English.
- **Real time:** the feed and the goal gauge use Rails' built-in live updates. The exact mechanism is chosen in architecture.
- **Share previews:** shareable pages (a pull, a profile) are server-rendered, so they carry their `og:*` tags directly. The preview image is the game's Steam image; nothing is generated.
- **Catalog importer:** offline import scripts in the same codebase, run as background jobs separately from the web app. They read the Steam API.
- **Mobile later:** wrap the web app for the App Store and Play Store. The wrapper is chosen at that time.

## Infrastructure path

1. **Start:** Docker Compose on one VPS, optionally behind an admin UI (Dokploy or Coolify), with Cloudflare in front for edge bot protection. Rails' built-in deployment tooling is an alternative; architecture decides.
2. **Grow:** several VPS, with redundancy, zero-downtime deploys and processes split across machines. K3s is the likely target.
3. **The move from 1 to 2 changes deployment only, not code.** The Constraints in the spec (stateless services, expand/contract migrations, env config, one image per service, separable processes) guarantee it.
4. **Message queue** (e.g. Kafka): introduced only when measured load justifies it. Until then, processes communicate through PostgreSQL.
