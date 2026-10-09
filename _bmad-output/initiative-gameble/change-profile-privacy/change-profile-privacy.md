---
title: "Sprint Change Proposal: a private profile closes its social side"
date: 2026-10-09
status: approved
scope: moderate
trigger: epic-friends-and-trades retrospective, findings F4 and F13; the author's decision in its Team discussion (2026-10-09)
---

# A private profile closes its social side

## 1. Issue summary

The spec gives profile visibility three levels (CAP-8): public, friends only and private. It says a private profile is seen by "nobody else", but it never says what that means for friends, trades or presence. The epic 5 retrospective found the gap in the running code:
- A friend's trade picker lists a private player's whole collection (F4).
- A private player shows online to every friend, with their current activity, and counts in "n en ligne" (F13).
- A private player can propose, counter and accept trades, since `TradeSteps#friends` checks only friendship and standing.

The friend profile, the public profile and the feed already hide a private player correctly, through `Game::Visibility.visible?`.

On 2026-10-09 the author settled the rule:

- **Friends only** is unchanged: friends see everything and trade as usual.
- **Private** means:
  - the player keeps their friends and can still add new ones;
  - a friend sees nothing beyond the friendship: no presence or activity, no collection, no profile, no trade in either direction;
  - going private cancels the player's open trades at once and releases the reserved copies;
  - a private player still sees what their friends show them;
  - where a trade would start, the screen says trades are closed while that profile is private.

## 2. Impact analysis

**Epics**

| Epic | State | Impact |
|---|---|---|
| 5 Friends and trades | 12 done, 5.14 built | R5 and Done when 6 (presence) conflict, and R4 needs the private rule. The built work is not wrong, only incomplete under the new rule. Its stories are not reopened; the epic records the amendment in Notes. |
| 7 Ready for the public | in progress; 7.2 (visibility setting) built | It owns `Game::Visibility` and the setting, so the new work lands here: two stories. R1 gains the rule. |
| 6 The Brotherhood | in progress | Story 4 (the LIVE ticker) and story 8 (the Friends tab) are not built; they state the private exclusion. Story 6 (repost) is already consistent ("disappears with a hidden or banned profile"). |
| 9, 10, 11, 12 | — | No impact. |

**Documents:** the spec (CAP-8, 11, 13, 14, 19, 21); the architecture (AD-8, AD-13, AD-14, AD-24 and the capability map); EXPERIENCE.md (Copy deck, Component Behavior, State Patterns); DESIGN.md (friend row, friend profile).

**Code**

| Area | What changes |
|---|---|
| `Accounts::SetVisibility` | Publishes nothing today; gains `Accounts::VisibilityChanged`. |
| `Game` | Gains a handler that cancels the player's open trades. |
| `Game::Visibility` | Gains the question trades and presence ask. |
| `TradeSteps#friends` and `TradesController#tradable?` | Refuse a private party. |
| `Game::FriendsPresence` | Hides a private friend and leaves them out of `online_count`. |
| The friend profile and the trades board | Show the "trades closed" line. |

There is no migration. One caveat: `DropFriendsAndTrades` locks partners out of order (retrospective F12), so the new handler must not reuse it as it is.

**Other:** none of the deployment, CI or infrastructure needs a change.

## 3. Recommended approach

**Direct adjustment.**
- Amend the documents.
- Add two stories to epic 7.
- State the private exclusion in two unbuilt stories of epic 6.

No rollback, because nothing built contradicts the rule; it only falls short of it. The MVP scope stays as it is: the rule narrows behaviour and adds no feature beyond the friend row's button, which the retrospective had already asked for (action item 23).

Effort: medium. Risk: medium, because the cancellation on going private touches trade locks.

## 4. Detailed change proposals

All were approved by the author: 1 to 3 one by one, 4 to 11 in batch.

### Spec (`spec-gameble/spec-gameble.md`)

**1. CAP-8, success**

OLD:
```
- Friends only: only the player's friends see it. Private: nobody else sees it.
```
NEW:
```
- Friends only: only the player's friends see it, and they trade as usual.
- Private: nobody else sees it, friends included. The player keeps their friends and can still add new ones, but a friend sees nothing beyond the friendship: no presence or activity, no collection, no profile, and no trade either way. A private player still sees what their friends show them.
```

**2. CAP-11, success**

OLD:
```
- Non-friends cannot trade.
```
NEW:
```
- Non-friends cannot trade, and neither can a private player (CAP-8): nobody proposes to them and they propose to nobody. Where a trade would start, the screen says trades are closed while that profile is private, naming whose profile it is.
- Going private cancels the player's open trades at once: every reserved copy is released and the friend sees the trade closed.
```

**3. CAP-21, success**

OLD:
```
- **success:** Friends see each other's status: online, current activity, or last seen. The friends menu item shows how many friends are online.
```
NEW:
```
- **success:** Friends see each other's status: online, current activity, or last seen. A private friend (CAP-8) shows "profil privé" instead, and never counts among those online. The friends menu item shows how many friends are online.
```

**4. CAP-13 and CAP-19**

OLD (CAP-13):
```
- A signed-in player has a Friends tab showing only their friends' pulls, trades and reposts.
```
NEW:
```
- A signed-in player has a Friends tab showing only their friends' pulls, trades and reposts; a private friend's never show (CAP-8).
```

OLD (CAP-19):
```
- A repost appears in the global feed and in the Friends tab of the player's friends.
```
NEW:
```
- A repost appears in the global feed and in the Friends tab of the player's friends, unless the player's profile hides it (CAP-8).
```

**5. CAP-14, success**

OLD:
```
… and set their profile's visibility (public, friends only, private). Each action works end to end.
```
NEW:
```
… and set their profile's visibility (public, friends only, private); going private cancels their open trades (CAP-11) and says so before applying. Each action works end to end.
```

### Architecture (`architecture-gameble/architecture-gameble.md`)

**6. AD-8, AD-13, AD-14, AD-24 and the capability map**

AD-8, OLD:
```
- Every trade operation requires the two players to be friends.
```
NEW:
```
- Every trade operation requires the two players to be friends and neither to be private (AD-13's `open_to_friends?`).
```

AD-13, added after line 163:
```
- A second question, `Game::Visibility.open_to_friends?(player)`, is false for a private player (and a banned or deleted one). Trades (AD-8), presence (AD-24) and the trade actions on the friend row and friend profile ask it; nothing else needs it, since `visible?` already hides a private player from friends.
```

AD-14, OLD:
```
- Profile visibility is public, friends only or private, stored in `Accounts`. The profile policy and AD-13's visibility question combine it with `Game`'s friendship query.
```
NEW:
```
- Profile visibility is public, friends only or private, stored in `Accounts`. The profile policy and AD-13's visibility questions combine it with `Game`'s friendship query. Setting it to private publishes `Accounts::VisibilityChanged`; `Game` handles it by cancelling the player's open trades and releasing their reservations under AD-10's lock order (bank locks of both players in ascending id, taken before any trade row), and `PlayerStream` tells the partners, as it does for a deletion.
```

AD-24, OLD:
```
- Presence is not built on Action Cable connections. It is read when the friends page or menu renders (AD-13).
```
NEW:
```
- Presence is not built on Action Cable connections. It is read when the friends page or menu renders (AD-13). A private friend's presence is never read: the row says "profil privé" and the online count skips them.
```

Capability map, OLD:
```
| CAP-8 Profile and visibility | web layer, `Accounts`, `Game` | AD-11, AD-14, AD-15 |
```
NEW:
```
| CAP-8 Profile and visibility | web layer, `Accounts`, `Game` | AD-8, AD-11, AD-13, AD-14, AD-15, AD-24 |
```

### UX (`ux-gameble/EXPERIENCE.md` and `DESIGN.md`)

**7. EXPERIENCE.md, Copy deck**

OLD:
```
| Presence | "En ligne" · "Ouvre un booster" · "Il y a 3 h" |
```
NEW:
```
| Presence | "En ligne" · "Ouvre un booster" · "Il y a 3 h" · "Profil privé" |
| Trades closed | "Votre profil est privé : les échanges sont fermés." (link "RÉGLAGES") · "Le profil de Léa est privé : échanges fermés." |
| Going private | "Passer en privé annule vos 2 échanges en cours." · "PASSER EN PRIVÉ" · "ANNULER" |
```

**8. EXPERIENCE.md, Component Behavior**

Friend row, OLD:
```
| Friend row | Shows the friend's presence (see Copy deck, Presence). The avatar or name opens the friend profile; "PROPOSER UN ÉCHANGE" opens the trade already in progress with that friend, or a new draft. |
```
NEW:
```
| Friend row | Shows the friend's presence (see Copy deck, Presence), or "Profil privé" for a private friend. The avatar or name opens the friend profile; "PROPOSER UN ÉCHANGE" opens the trade already in progress with that friend, or a new draft. When either profile is private, the "Trades closed" line replaces the button. |
```

Friend profile, OLD:
```
| Friend profile | A dialog: showcase of three cards, "PROPOSER UN ÉCHANGE", "SIGNALER". |
```
NEW:
```
| Friend profile | A dialog: showcase of three cards, "PROPOSER UN ÉCHANGE", "SIGNALER". A private friend's dialog shows the name and says the profile is not available; when the viewer is private, the "Trades closed" line replaces "PROPOSER UN ÉCHANGE". |
```

Settings row, OLD:
```
… "VISIBILITÉ DU PROFIL" (PUBLIC / AMIS UNIQUEMENT / PRIVÉ, default PUBLIC) applies at once. …
```
NEW:
```
… "VISIBILITÉ DU PROFIL" (PUBLIC / AMIS UNIQUEMENT / PRIVÉ, default PUBLIC) applies at once; choosing PRIVÉ with trades open first asks to confirm (see Copy deck, Going private). …
```

**9. EXPERIENCE.md, State Patterns**

Added after "Friend banned or deleted mid-trade":
```
| Friend goes private mid-trade | Trade board, list | The trade closes ("CLOS") and every reserved copy is released; the board says the friend's profile is now private. |
```

Friend presence, OLD:
```
| Friend presence | Amis, menu 04 | Online, current activity, or last seen. |
```
NEW:
```
| Friend presence | Amis, menu 04 | Online, current activity, or last seen; "Profil privé" for a private friend, never counted online. |
```

Profile visibility, OLD:
```
… PRIVÉ: nobody else. The summary states it. |
```
NEW:
```
… PRIVÉ: nobody else, friends included; friendships stay and trades close (CAP-11). The summary states it. |
```

**10. DESIGN.md, components**

Friend row, added sentence:
```
A private friend's row shows the name, the muted "Profil privé" in place of the presence and no card count; when either profile is private, the muted "Trades closed" line stands where "PROPOSER UN ÉCHANGE" was.
```

Friend profile, added sentence:
```
A private friend's dialog shows the avatar, the name and the "not available" line only.
```

### Epics and tickets

**11. Epics 5, 6 and 7**

Epic 5 (`epic-friends-and-trades.md`), Notes, added:
```
- Amended (2026-10-09, change-profile-privacy): a private player cannot trade and a private friend's presence shows "profil privé", outside the online count; R4, R5 and Done when 5 and 6 read with that exception. Built by epic 7 (stories 20 and 21).
```

Epic 7 (`epic-public-launch-readiness.md`), R1, appended:
```
… Private closes the social side: a private player keeps and adds friends, but friends see nothing of them and nobody trades with them, and going private cancels their open trades (CAP-8, CAP-11, CAP-21; AD-8, AD-13, AD-24).
```

Epic 7, two new entries in `tickets.toml`:
```
[[entry]]
id = 20
type = "story"
title = "A private profile closes its social side"
description = "Going private publishes Accounts::VisibilityChanged, and Game cancels the player's open trades, releasing every reserved copy under the lock order, while the private stream tells the partners; the settings row asks to confirm when trades are open. Game::Visibility answers open_to_friends?, which every trade operation and the trades screen ask in both directions, refusing with a message that names whose profile is private. A private friend's presence reads \"Profil privé\" and never counts online, and the friend profile shows the trades-closed line when the viewer is private."
verify = "Going private with two open trades cancels both, releases the copies and updates the partners live; nobody proposes, counters or accepts with a private player, from the screen or a forged POST; a private friend shows \"Profil privé\" and is left out of \"n en ligne\"; friends-only friends still trade."
covers = ["R1"]
after = [2]
hitl = false
risk = "high"

[[entry]]
id = 21
type = "story"
title = "Trade from the friend row"
description = "Adds PROPOSER UN ÉCHANGE to each friend row of the Friends screen, opening the trade in progress with that friend or a new draft, and the trades-closed line in its place when either profile is private."
verify = "From the Friends screen a player opens the trade in progress with a friend or starts one; with a private friend, or while private, the row shows the trades-closed line instead."
covers = ["R1"]
after = [20]
hitl = false
risk = "low"
```
Both go before the refactor sweep (12) in build order, and the sweep's `after` gains 20 and 21.

Epic 6 (`epic-brotherhood/tickets.toml`):
- Story 4 (the LIVE ticker), appended to verify: "an entry naming a private or friends-only player never reaches the ticker."
- Story 8 (the Friends tab), appended to verify: "a private friend's pulls, trades and reposts never show under AMIS."

## 5. Implementation handoff

- **Scope: moderate.** Documents are amended directly; the backlog gains two stories and two story precisions.
- **Documents (applied by the orchestrator on approval):** proposals 1 to 10 and the epic Notes and R1 text of 11.
- **Backlog (`bmad-ticket`):** add entries 20 and 21 to epic 7 (build order before the sweep); amend the verify of epic 6 stories 4 and 8.
- **Build (`bmad-build`):** 7.20, then 7.21, locally, with a `thorough` review for 7.20 (risk high: trade locks).
- **Success criteria:**
  - the spec, the architecture and the UX state one rule;
  - after 7.20 and 7.21, a private player is invisible to friends beyond the friendship, cannot trade, and loses their open trades on going private;
  - friends-only behaves as before.

## Notes

- **The confirmation before going private (proposals 5, 7 and 8) is the orchestrator's addition,** approved in batch. Cancelling trades is not reversible, so the setting asks first when trades are open.
- **Another session changed epic 7 while this correction ran** (stories 7.5, 7.17 and 7.18 were built). Story 7.5's `Accounts::BanPlayer` now publishes `Accounts::PlayerBanned`, so the retrospective's finding F2 is resolved there. New entries take ids 20 and 21, since 13 to 19 exist.
