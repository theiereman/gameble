# Contributing to gameble

You do not need to code to help gameble grow: playing, reporting what goes wrong and suggesting ideas is enough.

gameble is a free web trading card game where every card is a Steam game. You open capsules, complete sets in your album and trade cards with your friends.

## Before you start

You need two free accounts: Steam to play, GitHub to send feedback.

1. **Play the test version** at [gameble.dotsncircles.com](https://gameble.dotsncircles.com), signing in with your Steam account.
2. **Create a GitHub account** at [github.com/signup](https://github.com/signup) if you do not have one.
3. **Open the feedback page**: [New issue](https://github.com/theiereman/gameble/issues/new/choose), then pick a form.

The forms are in English, but you can fill them in French.

## Report a bug

Something broke, or did not do what you expected: pick **Bug report**. [Reporting a problem](docs/reporting-problems.md) tells how to fill it in.

## Suggest a feature

Something is missing, or could be better: pick **Feature idea**.

Start from the moment in the game when you missed something. The problem you met matters more than the solution you imagine, so describe it first, then your idea.

## Suggest a set of cards

Cards are grouped into sets you complete in your album: pick **Set idea**.

A set only works if a player recognizes it from its name alone. Two kinds can be suggested:

- **Theme**: games sharing a Steam tag, such as Souls-like, Pirates or Cyberpunk. Broad tags (Action, Adventure, Casual, Indie, Multiplayer) never make a theme. A game's tags are on its Steam store page, under "Popular user-defined tags".
- **Hall of fame**: games picked by their Steam reviews, such as Les Pépites (at least 98 % positive and under 1,000 reviews).

Give a few example games: they show quickly whether the set holds up.

## Suggest lore

Players belong to *La Grande Confrérie des Gameblers*, the Great Brotherhood of Gameblers, and play from a space terminal: pick **Lore idea** to add to that world.

Keep it light and short: a wink at the games industry, never a long saga, with no real company names and no terms borrowed from other games. The form gives the rules and asks where players could meet your idea.

## What happens next

Every form becomes an issue on GitHub. Its author reads each one, may ask you questions in the comments, and labels it once it is planned. Not every idea gets built, but every one is read.

## Build with an AI agent (Claude, ChatGPT and others)

You can also change the game itself without knowing how to code, by asking an AI coding agent to do it for you. The author reviews every change before it reaches the game.

### What you need

- Access to the repository: accept the author's invitation on GitHub.
- An AI agent that works on a GitHub repository, such as [Claude Code on the web](https://claude.ai/code) or [Codex in ChatGPT](https://chatgpt.com/codex). Both need a paid plan of their tool; nothing to install on your computer.

Connect the agent to your GitHub account, then open a session on the `gameble` repository, starting from the `develop` branch.

### What to work on

Start small, and grow from there:

- **A bug or an idea from the issues**: give the agent the issue's link.
- **The look and the texts**: a colour, a spacing, a sentence that reads wrong. The French texts live in `config/locales/fr.yml`.
- **Set ideas**: a theme or a hall of fame, with its games.
- **Designing the game**: a new mechanic, a screen, a reward. Talk it through with the agent before any code.

Leave the database and the game's rules (anything under `db/` or `app/domains/`) for later, or ask the author first.

### How a session goes

1. Tell the agent what you want in plain words, in French if you like: what you saw, what you want instead.
2. Let it work. It reads `AGENTS.md`, the repository's rules, which tell it to work on its own branch and never on `develop` or `main`.
3. Ask it to run the tests. If it cannot, say so in the pull request: GitHub runs them anyway.
4. Ask it to open a **pull request** to `develop`: the proposed change, waiting for the author.
5. The author reads it, may ask questions in its comments, and merges it or not. The game on the test site changes at the author's next release, not at the merge.

### Designing with Claude

In Claude Code, the repository brings its own planning tools (the BMad skills in `.claude/skills/`). Ask for them by name:

| You want to | Ask for |
| --- | --- |
| Find ideas on a topic | `bmad-brainstorming` |
| Test an idea before anyone builds it | `bmad-forge-idea` |
| Hear several points of view argue it out | `bmad-party-mode` |
| Sketch how a screen looks and behaves | `bmad-ux` |

What they write lands in `_bmad-output/` and comes to the author through the same pull request. Other agents can read those files too.

### Licensing your contribution

By opening a pull request, you agree that your contribution is released under the license of the files it changes (the GNU AGPL v3.0 for code, Creative Commons BY-NC-SA 4.0 for artwork; see the License section of the README), and you grant Thomas Eyermann the right to release it under other license terms as well, so the project can change its license later without asking every contributor.

### Never

- Push to `develop` or `main`, or merge your own pull request.
- Commit a key or a password, such as the files `config/*.key`.
- Mark a plan as approved: only the author approves plans.
