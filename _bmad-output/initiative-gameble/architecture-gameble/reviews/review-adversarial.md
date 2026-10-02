# Review — two units that obey every AD and still clash

Verdict: six holes found and closed in the spine; two remain open by choice.

Closed:
- **Lock order.** A pack opening and a trade acceptance could deadlock on the same card rows. AD-6 now fixes one lock order.
- **Week and day boundaries.** Two units could cut the week differently. Conventions now fix UTC days and ISO weeks.
- **Account deletion.** `Accounts` cannot call `Game`. AD-10 now says packs react to each other's events, and events carry ids only.
- **First packs of a new player.** Same boundary problem; AD-7 now fills the bank through `Accounts::PlayerRegistered`.
- **Replacement pack timing.** Two units could compute the next availability differently. AD-7 now states the rule.
- **Nested operations.** AD-3 now says when an operation may call another.

Open by choice:
- **Feed selection thresholds** and **weekly target formula** are product tuning; each lives in one place, so two units cannot diverge on them.
