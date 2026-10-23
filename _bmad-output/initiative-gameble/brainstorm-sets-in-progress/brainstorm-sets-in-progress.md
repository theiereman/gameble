# Intent: a livelier EN COURS (sets in progress)

Input for bmad-ux or bmad-product-brief. Feeds ticket 16.22.

## Goal

Make the sets-in-progress rows on the collection entry feel alive. The same rows also serve the hub's SETS EN COURS panel and the public profile, so the result must work in all three places.

## Root cause

A set has no identity, no motion and no voice. Only the set name tells one set from another. A deliberately sad version (identical dense rows, static, impersonal, factual tone) came out as flat as the current rows. Fixing the screen means giving each set identity, motion and voice, not adding decoration to the rows.

## Central direction

The screen remembers the player's last visit and reacts to what changed, so the collection feels like it grows and completes.

Neon is the visual thread. A set is a tube with three states:
- Empty: off. Feedback is dead, like a push button that does not spring back.
- In progress: flickering and soft, with a bouncy feel.
- Complete: fully lit, hard to the touch, still, and locked. It can no longer be opened.

## MoSCoW by family

| Family | Verdict |
|---|---|
| A. Neon thread (progress bar advances with an electric effect, luminescence) | Must |
| B. Locking of a complete set | Must |
| C. Memory of the last visit | Must |
| F. Reveal the latest cards of a set | Must |
| D. Identity of each set (own frame, colours, themed decor) | Should |
| E. Brotherhood voice (comments on progress) | Should |
| G. Organisation of the screen (grid, list, gantt-style estimate) | Could |
| H. Sound | Could |
| I. Album feel and visible empty slots | Could |

## First version

- Neon progress bar that advances from its value at the last visit to the current one.
- Locked, still look for completed sets.
- Last-visit memory: a static "+N cards" indicator, and a celebration on a row whose tier was passed since the last visit.
- F reveal: hover growth on desktop shows the latest cards that entered the set. On phone, an unfold button does the same, since there is no hover.
- Idle neon glow that breathes slowly. The pace reads as progress: slow when low, faster and electric when high.

Deferred: cards flying in from everywhere and filing themselves into their sets, and the per-card bounce of the set section.

### Should (after the first version)

- D. Each set gets its own frame, colours and themed decor. Examples: a mouldy, gnawed frame for zombie sets, camouflage fabric for war sets, a crane and buildings under construction for city sets. No decor idea yet for studio sets.
- E. Brotherhood voice. Praise when the player advanced a lot, reproach when progress is small. Tone depends on the length of the absence. Examples: a complete set after an absence ("we thought we had lost you, but your efforts finally bore fruit"), a set still empty ("get to work or you risk appearing before the disciplinary council"). Many sets completed at once gets a very laudatory comment.

## Key connections

- One last-seen marker per set drives the progress animation, the +N indicator, the comment tone, the cards revealed and the breathing pace.
- Speak only when something changed. If nothing happened since the last visit, show no commentary and no animation.
- Build the static delta state first (the +N indicator), with animation as garnish on top.
- Neon states (off, flickering, lit) replace the kanban columns idea. The state is carried by light and feel.
- The last-seen marker must be written by a POST, because a GET never writes.
- Return sequence when animated: cards file in and the bar progresses together, then the Brotherhood comment appears last.

## Constraints

- Server-rendered Hotwire with TypeScript Stimulus controllers. No React, and no markup built in script.
- Works on phone and desktop. The phone has no hover, and an old phone gets the comment without the animation ceremony.
- Reduced motion: all motion has a static equivalent, including the idle glow.
- Every string in both English and French.
- Sound is Could. The author has no skills to produce it, so it is not a dependency of anything else.
- Set decors are AI-generated first. The author finds AI art not ideal, but it is the only option for now. Contributing artists replace them later, which fits the open call for artists.
- The screen must stay responsive without extra load on the back end.

## Open questions

- Layout: which one is best, and what does it look like on a phone (grid, list, gantt-style estimate)?
- Should a player with many cards be complimented more than a newcomer?
- Should the Brotherhood comment every time, or only when something changed?
- Can the Brotherhood's tone become overbearing?
- How to make completion more interesting for a player who plays little?
- What decor fits studio sets?
- How to produce sounds with no audio skills, if sound is ever pursued?
- Which of these ideas stay out of scope: the report ideas (a bilan on completion, a burn-up chart of progress over time) and the physical-album ideas (reopening to admire pieces, empty slots as a visible lack)?
