# Pending approvals

Operations set aside while the author was away (2026-10-02): each waits for an explicit go-ahead. Nothing here has been run.

- **Close the GitHub issues of epic 1 (#1–#11).** Optional since tracking moved to the repo store; the issues are still open with the `backlog` label. Command: `for n in 2 3 4 5 6 7 8 9 10 11 1; do gh issue edit $n --remove-label backlog && gh issue close $n --reason completed; done`.
- **Full real Steam import in development (story 2.3's manual check, story 2.8).** About 1,900 `GetItems` calls for the review pass, plus the details and roughly one `appdetails` call per kept game at 2 s each (several hours) on the author's API key. Measures the duration, the kept count and the real prestige scores for calibration.
- **Deploy to the test LXC (`bin/kamal deploy`) and run the first real import there (story 2.8).** Needs `config/steam_api.key` on the deploying machine (`.kamal/secrets` reads it) and adds the `import` role.
- **Daily bonus booster odds (epic 3, story 3.7).** The spec leaves them open. Built on the assumption: 3 cards, no steel, emerald 70 %, sapphire 24 %, amethyst 5 %, gold 1 %. Confirm or give the real odds; they live in one constant.
- **Epic 3 breakdown (`epic-packs-and-reveal/tickets.toml`).** Ten stories sliced by the orchestrator under your standing instruction; review the order and scope when you are back.
- **Large card back (epic 3, story 3.5, card component).** DESIGN.md sizes the large card at 120 × 180 art pixels, but only the 80 × 120 back is drawn. Built on the assumption: the large back is the 80 × 120 back shown at ×3 (240 × 360 CSS pixels), as `mockups/key-screens.html` does for the phone reveal, so its pixels are 3 CSS pixels where the rest of the screen uses 2. Decide whether a 120 × 180 back is redrawn; it would replace `app/frontend/images/card/back-<rarity>.svg` for the large size (and the seals and dust overlays drawn over it).
