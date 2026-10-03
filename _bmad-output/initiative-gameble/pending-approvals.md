# Pending approvals

Operations set aside while the author was away (2026-10-02): each waits for an explicit go-ahead. Nothing here has been run.

- **Full real Steam import in development (story 2.3's manual check, story 2.8).** About 1,900 `GetItems` calls for the review pass, plus the details and roughly one `appdetails` call per kept game at 2 s each (several hours) on the author's API key. Measures the duration, the kept count and the real prestige scores for calibration.
- **Deploy to the test LXC (`bin/kamal deploy`) and run the first real import there (story 2.8).** Needs `config/steam_api.key` on the deploying machine (`.kamal/secrets` reads it) and adds the `import` role.
- **Cloudflare and link previews (epic 4).** When Cloudflare is set up: Bot Fight Mode off, or a WAF skip rule for Discordbot, Twitterbot and WhatsApp on `/*/brothers/*`, or previews fail.
- **Manual preview check (story 4.5).** Paste a share link in Discord, X and WhatsApp once a public HTTPS host exists (the LXC's LAN address cannot be reached by their servers).
- **Card detail links from the reveal (epic 4, story 4.3).** "Cards anywhere lead to it", but the PackReveal island's cards are not links: a click there flips or wipes the card. Built on the assumption that only server-rendered faces link (tome slots and the pack page's later visits); the reveal leads to the detail through the pack page once revealed. Decide whether the island should link its revealed cards too (a React change in `RevealCard.tsx`).
- **Empty slots name the missing card's rarity (epic 4, story 4.3).** An empty slot links to the card's detail and its link is named "<title>, <rarity>, season n"; the detail page shows the rarity of any card, owned or not. Built on the assumption that a card's rarity is public catalogue information, not a surprise to keep. Decide otherwise and the rarity would be left out of the empty slot's link name and of the detail for non-holders. Note also that, as the plan asks, that link name replaces the slot's visible text for screen readers, so "Missing card" is no longer announced and an empty slot sounds like an owned face (review finding, deferred): decide whether the empty slot's link name should be its visible text (title, year, "Missing card") instead.

## Deferred to the UX redesign (bmad-ux)

The author will redo the UX with menus and a screen per feature (2026-10-03); these stay as built until then.

- **Large card back (epic 3, story 3.5, card component).** DESIGN.md sizes the large card at 120 × 180 art pixels, but only the 80 × 120 back is drawn. Built on the assumption: the large back is the 80 × 120 back shown at ×3 (240 × 360 CSS pixels), as `mockups/key-screens.html` does for the phone reveal, so its pixels are 3 CSS pixels where the rest of the screen uses 2. Decide whether a 120 × 180 back is redrawn; it would replace `app/frontend/images/card/back-<rarity>.svg` for the large size (and the seals and dust overlays drawn over it).
- **Tier cues on a dusty card back (epic 3, story 3.6, pack reveal).** Before a card is wiped, only its rarity seal is hidden (whatever the dust level, even with no dust); the rest of the back keeps the tier cues DESIGN.md draws: the gems in the rarity colour and, on a legendary, the gold fittings, rays and rounded corners. Built on the assumption that these cues stay; the alternative is a neutral back (one brass back for every tier) until the wipe, which keeps the rarity a surprise until then. Decide; the alternative needs a neutral back asset and a swap on wipe in `RevealCard.tsx` / `reveal.css`.
- **Phone layout of the reveal (epic 3, story 3.6, pack reveal).** The reveal shows one large card at a time below `max-width: 600px`, and small cards side by side above. Built on the assumption of that width (a large card is 240 CSS pixels; two small ones fit from about 360). Confirm or give the breakpoint; it lives in one place, `--reveal-phone-query` in `app/frontend/styles/reveal.css`.

## Settled on 2026-10-03

- GitHub issues #1–#11 of epic 1 closed.
- Daily bonus booster odds confirmed (spec CAP-16).
- AD-7 amended: replacement packs drawn inline by `Game::TopUpBank`.
- Public profile title: the Steam persona name, stored at each sign-in, with "Brother <code>" as fallback (story 4.4 plan updated).
- Share previews carry no image at all (spec CAP-9).
- Epics 3 and 4 breakdowns: judged through their retrospectives instead.
- The import drops the store API (story 2.10); a degraded local import of 1,000 games was run in development.
