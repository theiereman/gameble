#!/usr/bin/env python3
"""Mirror the local BMad ticket tree onto GitHub issues and the "Gamble Kanban" project board.

One way only: the local tree stays the source of truth (store = "repo"), GitHub shows it.
Dry run by default; --apply runs the gh calls. Issue numbers are kept in a map file, so ticket
files are never edited. Bodies are rewritten for human readers: planning ids dropped, ticket refs
turned into issue links, repo paths into file links.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import tomllib
from pathlib import Path
from typing import NamedTuple

REPO = "theiereman/gameble"
OWNER = "theiereman"
BLOB = f"https://github.com/{REPO}/blob/develop/"
PROJECT_NUMBER = "1"
PROJECT_ID = "PVT_kwHOCGlW2M4BnwZM"
STATUS_FIELD = "PVTSSF_lAHOCGlW2M4BnwZMzhmThPo"
STATUS_OPTION = {
    "backlog": "f75ad846",
    "ready": "61e4505c",
    "in-progress": "47fc9ee4",
    "review": "df73e18b",
    "done": "98236657",
    "dropped": "98236657",
}
STATE_LABELS = ("backlog", "in-progress", "review")
FINISHED = ("done", "dropped")
# GitHub throttles bursts of content creation with secondary rate limits.
CREATE_PAUSE_SECONDS = 3
WRITE_ATTEMPTS = 4

PLANNING_ID = r"(?:CAP|AD|R)-?\d+"
REQUIREMENT_PREFIX = re.compile(r"^(\s*-\s+)R\d+(?:\s*\([^)]*\))?:\s*(\w)", re.M)
ID_ONLY_PARENS = re.compile(rf"\s*\((?:\s*(?:{PLANNING_ID}|[\w.-]+\.md)\s*[,;]?)+\s*\)")
LOOSE_ID = re.compile(rf"(?:,\s*)?\b{PLANNING_ID}\b(?:\s*,)?")
EMPTY_PARENS = re.compile(r"\s*\(\s*[,;]?\s*\)")
TICKET_REF = re.compile(r"(?<![\w.#/-])(\d+\.\d+)(?![\w.]|\d)")
SLUG_REF = re.compile(r"(?<![\w/-])(epic-[a-z0-9-]+)(?![\w/-]|\.md)")
REPO_PATH = re.compile(r"`?(?<![\w/])((?:_bmad-output|app|packs|test|config|script|db|lib|docs)/[\w./-]*[\w/])`?")


class Gh:
    def __init__(self, apply: bool):
        self.apply = apply

    def read(self, *args: str) -> str:
        return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout

    def write(self, *args: str) -> str:
        print("  gh " + " ".join(_shell(a) for a in args)[:300])
        if not self.apply:
            return ""
        for attempt in range(WRITE_ATTEMPTS):
            done = subprocess.run(["gh", *args], capture_output=True, text=True)
            if done.returncode == 0:
                return done.stdout
            if args[:2] == ("issue", "create"):
                break
            time.sleep(CREATE_PAUSE_SECONDS * 2 ** attempt)
        raise subprocess.CalledProcessError(done.returncode, ["gh", *args], done.stdout, done.stderr)


def _shell(arg: str) -> str:
    return arg if re.fullmatch(r"[\w.,:/=@#-]+", arg) else json.dumps(arg)


SNAPSHOT_QUERY = """
query($owner: String!, $name: String!, $after: String) {
  repository(owner: $owner, name: $name) {
    issues(first: 50, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number state stateReason body
        labels(first: 30) { nodes { name } }
        parent { number }
        blockedBy(first: 100) { nodes { number } }
        projectItems(first: 10) {
          nodes {
            id project { id }
            fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { optionId } }
          }
        }
      }
    }
  }
}
"""


class Published(NamedTuple):
    closed: bool
    reason: str
    body: str
    labels: set[str]
    parent: int | None
    blocked_by: set[int]
    item_id: str | None
    status_option: str | None


def snapshot(gh: Gh) -> dict[int, Published]:
    owner, name = REPO.split("/")
    published: dict[int, Published] = {}
    after: list[str] = []
    while True:
        page = json.loads(gh.read("api", "graphql", "-f", f"query={SNAPSHOT_QUERY}", "-F", f"owner={owner}",
                                  "-F", f"name={name}", *after))["data"]["repository"]["issues"]
        for node in page["nodes"]:
            item = next((i for i in node["projectItems"]["nodes"] if i["project"]["id"] == PROJECT_ID), None)
            published[node["number"]] = Published(
                closed=node["state"] == "CLOSED",
                reason=node["stateReason"] or "",
                body=node["body"],
                labels={label["name"] for label in node["labels"]["nodes"]},
                parent=(node["parent"] or {}).get("number"),
                blocked_by={b["number"] for b in node["blockedBy"]["nodes"]},
                item_id=item and item["id"],
                status_option=item and (item["fieldValueByName"] or {}).get("optionId"),
            )
        if not page["pageInfo"]["hasNextPage"]:
            return published
        after = ["-f", f"after={page['pageInfo']['endCursor']}"]


def tickets(project_root: Path, folder: Path, *args: str) -> dict:
    script = project_root / ".agents/skills/bmad-ticket/scripts/tickets.py"
    out = subprocess.run(
        [sys.executable, str(script), *args[:1], str(folder), *args[1:]],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out.splitlines()[0])


def without_frontmatter(text: str) -> str:
    return re.sub(r"\A---\n.*?\n---\n", "", text, count=1, flags=re.S).strip()


def entry_body(found: dict) -> str:
    if found.get("story_file"):
        return without_frontmatter(Path(found["story_file"]).read_text())
    parts = [found.get("description") or ""]
    if found.get("verify"):
        parts.append("## Verify\n\n" + found["verify"])
    if found.get("references"):
        parts.append("## References\n\n" + "\n".join(f"- {r}" for r in found["references"]))
    if found.get("notes"):
        parts.append("## Notes\n\n" + "\n".join(f"- {n}" for n in found["notes"]))
    return "\n\n".join(p for p in parts if p).strip()


def humanize(text: str, mapping: dict[str, int]) -> str:
    def issue_link(match: re.Match) -> str:
        number = mapping.get(match.group(1), 0)
        return f"#{number}" if number > 0 else match.group(0)

    def file_link(match: re.Match) -> str:
        path = match.group(1)
        return f"[{path.rsplit('/', 1)[-1] or path}]({BLOB}{path})"

    text = REQUIREMENT_PREFIX.sub(lambda m: m.group(1) + m.group(2).upper(), text)
    text = ID_ONLY_PARENS.sub("", text)
    text = LOOSE_ID.sub(lambda m: ", " if m.group(0).startswith(",") and m.group(0).endswith(",") else "", text)
    text = EMPTY_PARENS.sub("", text)
    text = re.sub(r"[ \t]+([,;.:)])", r"\1", text)
    text = re.sub(r"\([ \t]+", "(", text)
    text = re.sub(r",\s*,", ",", text)
    text = re.sub(r"(?m)[,;][ \t]*$", "", text)
    text = TICKET_REF.sub(issue_link, text)
    text = SLUG_REF.sub(issue_link, text)
    return REPO_PATH.sub(file_link, text)


BODY_LIMIT = 65_000
ENTRY_FIELDS = ("description", "verify", "references", "notes", "unknown")
TICKET_FIELDS = ("ref", "epic", "id", "type", "title", "covers", "after", "hitl", "estimate", "refine", "refined",
                 "blocked_at", "blocked_reason", "file")


class Issue(NamedTuple):
    ref: str
    title: str
    body: str
    source: Path
    labels: list[str]
    release: str
    meta: dict
    raw: str


def fenced(text: str, info: str) -> str:
    longest = max((len(m) for m in re.findall(r"~{3,}", text)), default=2)
    fence = "~" * max(4, longest + 1)
    return f"{fence}{info}\n{text.rstrip()}\n{fence}"


def source_block(issue: Issue, project_root: Path) -> str:
    path = issue.source.relative_to(project_root).as_posix()
    meta = json.dumps({"source": path, **issue.meta}, ensure_ascii=False, indent=2)
    return (
        "\n\n---\n<details><summary>BMad source (for agents)</summary>\n\n"
        f"Mirrored from [{issue.source.name}]({BLOB}{path}). The text above drops planning ids for readers; "
        "the ticket's fields and its original text are below, verbatim.\n\n"
        f"{fenced(meta, 'json')}\n\n{fenced(issue.raw, 'json' if issue.source.suffix == '.toml' else 'markdown')}\n\n</details>"
    )


def board_status(state: str, ref: str, ready: set[str]) -> str:
    if state in ("backlog", "planned"):
        return "ready" if ref in ready else "backlog"
    return state


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--map", type=Path, help="JSON file: BMad ref -> issue number")
    parser.add_argument("--all", action="store_true", help="also mirror finished epics, as closed issues")
    parser.add_argument("--epic", help="mirror only this epic slug")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    root = args.project_root.resolve()
    folder = root / "_bmad-output/initiative-gameble"
    args.map = args.map or folder / "github-board.json"
    gh = Gh(args.apply)
    mapping: dict[str, int] = json.loads(args.map.read_text()) if args.map.exists() else {}
    status = tickets(root, folder, "status")
    nxt = tickets(root, folder, "next")
    ready = {t["ref"] for t in nxt["ready_to_start"]}

    epics = {e["slug"]: e for e in status["epics"]}
    rows = status["tickets"]
    open_epics = {r["epic"] for r in rows if r["state"] not in FINISHED}
    scope = [s for s in epics if (args.all or s in open_epics) and args.epic in (None, s)]
    rows = [r for r in rows if r["epic"] in scope]
    declared = tomllib.loads((folder / "tickets.toml").read_text())["epic"]
    titles = {e["slug"]: e["title"] for e in declared}
    releases = {e["slug"]: e.get("release", "") for e in declared}
    unreleased = [s for s in scope if not releases[s]]
    if unreleased:
        sys.exit(f"no release in tickets.toml for: {', '.join(unreleased)}")

    declared_by_slug = {e["slug"]: e for e in declared}
    issues: list[Issue] = []
    for slug in scope:
        epic_file = folder / slug / f"{slug}.md"
        raw = epic_file.read_text() if epic_file.exists() else ""
        meta = {"ref": slug, "type": "epic", **declared_by_slug[slug]}
        issues.append(Issue(slug, titles.get(slug, slug), without_frontmatter(raw), epic_file, ["epic"],
                            releases[slug], meta, raw))
    for row in rows:
        found = tickets(root, folder, "find", row["ref"])
        story_file = Path(found["story_file"]) if found.get("story_file") else None
        source = story_file or folder / row["epic"] / "tickets.toml"
        raw = story_file.read_text() if story_file else json.dumps(
            {k: found[k] for k in ENTRY_FIELDS if found.get(k)}, ensure_ascii=False, indent=2)
        meta = {k: row[k] for k in TICKET_FIELDS if row.get(k) not in (None, "", [])}
        labels = [row["type"]] + (["hitl"] if row["hitl"] else [])
        issues.append(Issue(row["ref"], row["title"], entry_body(found), source, labels, releases[row["epic"]],
                            meta, raw))

    def rendered(issue: Issue) -> str:
        text = humanize(issue.body, mapping) + source_block(issue, root)
        if len(text) > BODY_LIMIT:
            sys.exit(f"{issue.ref}: body of {len(text)} characters is over GitHub's limit")
        return text

    for issue in issues:
        if issue.ref in mapping:
            continue
        print(f"create {issue.ref}: {issue.title}")
        url = gh.write("issue", "create", "-R", REPO, "--title", issue.title, "--body", rendered(issue),
                       "--label", ",".join(issue.labels), "--milestone", issue.release).strip()
        mapping[issue.ref] = int(url.rsplit("/", 1)[-1]) if url else -1
        if args.apply:
            time.sleep(CREATE_PAUSE_SECONDS)
        if args.apply:
            args.map.write_text(json.dumps(mapping, indent=2, sort_keys=True) + "\n")

    published = snapshot(gh)
    absent = Published(False, "", "", set(), None, set(), None, None)

    def on_github(ref: str) -> Published:
        return published.get(mapping[ref], absent)

    for issue in issues:
        number = mapping[issue.ref]
        wanted = rendered(issue)
        if on_github(issue.ref).body.strip() != wanted.strip():
            print(f"body {issue.ref}")
            gh.write("issue", "edit", str(number), "-R", REPO, "--body", wanted)

    for row in rows:
        number = str(mapping[row["ref"]])
        same_epic = row["ref"].split(".")[0]
        refs = [a if isinstance(a, str) and "." in a else f"{same_epic}.{a}" for a in row["after"]]
        blockers = [mapping[r] for r in refs if r in mapping]
        current = on_github(row["ref"])
        edit = []
        if current.parent is None:
            edit += ["--parent", str(mapping[row["epic"]])]
        missing = [str(b) for b in blockers if b not in current.blocked_by]
        if missing:
            edit += ["--add-blocked-by", ",".join(missing)]
        if edit:
            print(f"relate {row['ref']}")
            gh.write("issue", "edit", number, "-R", REPO, *edit)

    def sync_state(ref: str, state: str) -> None:
        number = str(mapping[ref])
        current = on_github(ref)
        column = board_status(state, ref, ready)
        if state in FINISHED:
            reason = "NOT_PLANNED" if state == "dropped" else "COMPLETED"
            if not current.closed or current.reason != reason:
                print(f"close {ref}")
                gh.write("issue", "close", number, "-R", REPO, *(["--reason", "not planned"] if state == "dropped" else []))
        else:
            if current.closed:
                print(f"reopen {ref}")
                gh.write("issue", "reopen", number, "-R", REPO)
            label = "backlog" if state == "planned" else state
            stale = sorted(current.labels & set(STATE_LABELS) - {label})
            if label not in current.labels or stale:
                print(f"label {ref} -> {label}")
                gh.write("issue", "edit", number, "-R", REPO, "--add-label", label,
                         *(["--remove-label", ",".join(stale)] if stale else []))
        item = current.item_id
        if item is None:
            print(f"board add {ref}")
            item = gh.write("project", "item-add", PROJECT_NUMBER, "--owner", OWNER, "--url",
                            f"https://github.com/{REPO}/issues/{number}", "--format", "json", "-q", ".id").strip()
        if current.status_option != STATUS_OPTION[column]:
            print(f"board {ref} -> {column}")
            gh.write("project", "item-edit", "--project-id", PROJECT_ID, "--id", item or "<item id>",
                     "--field-id", STATUS_FIELD, "--single-select-option-id", STATUS_OPTION[column])

    for slug in scope:
        sync_state(slug, "done" if epics[slug].get("status") == "done" else "in-progress")
    for row in rows:
        sync_state(row["ref"], row["state"])

    if not args.apply:
        print(f"\ndry run: {len(scope)} epics, {len(rows)} tickets; rerun with --apply")


if __name__ == "__main__":
    main()
