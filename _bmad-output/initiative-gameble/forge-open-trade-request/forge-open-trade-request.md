# Open trade request

**Problem.** A player knows which of a friend's cards they want but not what the friend wants in return (GitHub issue 63, point 5). Today a proposal is sent only when each side holds a card, so they guess.

**Decisions**
- At every send, proposal or counter-proposal, the sender may leave their own side empty, never the other's. An empty own side means "choose what you want from me".
- A trade with an empty side cannot be accepted: the recipient picks at least one card from the sender's collection and sends it back as a counter-proposal, or declines. The server refuses the acceptance too, not only the screen.
- In place of ACCEPTER, the recipient sees a short text asking them to choose the cards they want in return.
- No separate gesture for the sender: sending with an empty side is the open request. A mistaken empty send costs nothing (nothing reserved, cannot be accepted, cancellable).
- No stored mode, no new state, no new reservation rule: the answer is an ordinary counter-proposal (its offer reserved, the other side checked at acceptance, 7 days restarted, the sender keeps the veto). Limits, one open trade per pair, private profiles, cancel and expiry are unchanged.
- The spec changes in CAP-11: "sent only when each side holds a card" becomes "the side asked of the other player always holds a card; the sender's own side may be empty; a trade with an empty side cannot be accepted". Epic 5's "at least one card per side" follows.

**Rejected**
- Gifts (accepting an empty side as it stands): a swap always has two sides. Multi-account farming was not the reason; sign-in through Steam already adds friction.
- An empty request side or both sides empty: the friend's side always says what the sender wants; finding what to ask for is the epic 18 filters' job.
- An empty offer only on the first proposal: one rule at every send also lets a player say "not that one, pick something else".
- A note on the proposal: replaced by a separate idea, a discussion window on trades.

**Open**
- The trade list's one-line summary needs wording for an empty side.
- The trade discussion window is its own feature (reports, hiding and back-office reading, account export and erasure, bans, private profiles, unread badge, live delivery, rate limits); forge it separately.
