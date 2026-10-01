# Stack and infrastructure direction

Referenced by Constraints. The architecture phase picks the concrete libraries within these bounds.

## Stack

- **Language:** TypeScript everywhere, in strict mode. Rust was considered and dropped.
- **Repo:** a monorepo with shared types and validation schemas used by the front, the API and the importer.
- **Front:** a React SPA built with Vite, with a client-side routing library. Served as static files; no Node SSR server.
- **API:** TypeScript on a server runtime. The runtime, framework and ORM/query builder are chosen in architecture.
- **Database:** PostgreSQL.
- **Real time:** the feed and the goal gauge use Server-Sent Events.
- **Share previews:**
  - Shareable routes (a pull, a profile) get HTML from the backend with `og:*` tags and a generated preview image, because crawlers don't run JavaScript.
  - Humans land in the SPA.
- **Catalog importer:** a separate deployable in the same repo that reads Wikimedia dumps.
- **Mobile later:** wrap the SPA (e.g. Capacitor) for the App Store and Play Store.

## Infrastructure path

1. **Start:** Docker Compose on one VPS, optionally behind an admin UI (Dokploy or Coolify), with Cloudflare in front for edge bot protection.
2. **Grow:** several VPS, with redundancy, zero-downtime deploys and services split across machines. K3s is the likely target.
3. **The move from 1 to 2 changes deployment only, not code.** The Constraints in the spec (stateless services, expand/contract migrations, env config, one image per service, separable deployables) guarantee it.
4. **Message queue** (e.g. Kafka): introduced only when measured load justifies it. Until then, services communicate through PostgreSQL.
