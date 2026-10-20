#!/usr/bin/env python3
"""Keep the BMad ticket tree and GitHub in step; GitHub is the source of truth.

Tickets live as GitHub issues (one milestone per release, sub-issues, blocked-by) on the "Gamble Kanban"
board, whose Status column decides each ticket's state. The ticket files are the agents' working copy:
a sync creates the issues of new tickets, refreshes their text, moves a card forward when a build has
moved since the last sync, and writes the board's word back into each file's `tracker_status`.

  sync.py [--apply]                       sync everything (dry run without --apply)
  sync.py set <ref> <state> [--apply]     move one ticket: backlog, in-progress, review, done, dropped
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
ISSUE_URL = f"https://github.com/{REPO}/issues/"
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
STATE_OF_OPTION = {
    "f75ad846": "backlog",
    "61e4505c": "backlog",
    "47fc9ee4": "in-progress",
    "df73e18b": "review",
    "98236657": "done",
}
STATE_OF_BUILD = {
    "": "backlog",
    "draft": "backlog",
    "ready-for-dev": "backlog",
    "in-progress": "in-progress",
    "blocked": "in-progress",
    "in-review": "review",
    "built": "review",
    "done": "done",
    "dropped": "dropped",
}
STATES = ("backlog", "in-progress", "review", "done", "dropped")
STATE_LABELS = ("backlog", "in-progress", "review")
FINISHED = ("done", "dropped")
TRACKER_KEYS = ("tracker_id", "remote", "tracker_status", "status", "assignee")
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
SOURCE_META = re.compile(r"<summary>BMad source \(for agents\)</summary>.*?~{4,}json\n(.*?)\n~{4,}", re.S)

BODY_LIMIT = 65_000
ENTRY_FIELDS = ("description", "verify", "references", "notes", "unknown")
TICKET_FIELDS = ("ref", "epic", "id", "type", "title", "covers", "after", "hitl", "estimate", "refine", "refined",
                 "blocked_at", "blocked_reason", "file")

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


class Published(NamedTuple):
    closed: bool
    reason: str
    body: str
    labels: set[str]
    parent: int | None
    blocked_by: set[int]
    item_id: str | None
    status_option: str | None

    @property
    def state(self) -> str:
        if self.closed:
            return "dropped" if self.reason == "NOT_PLANNED" else "done"
        if self.status_option in STATE_OF_OPTION:
            return STATE_OF_OPTION[self.status_option]
        return next((label for label in STATE_LABELS if label in self.labels), "backlog")

    @property
    def meta(self) -> dict:
        found = SOURCE_META.search(self.body)
        return json.loads(found.group(1)) if found else {}


ABSENT = Published(False, "", "", set(), None, set(), None, None)


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


class Tree:
    def __init__(self, root: Path):
        self.root = root
        self.folder = root / "_bmad-output/initiative-gameble"
        self.script = root / ".agents/skills/bmad-ticket/scripts/tickets.py"

    def run(self, command: str, *args: str, folder: Path | None = None) -> dict:
        out = subprocess.run(
            [sys.executable, str(self.script), "--project-root", str(self.root), command,
             str(folder or self.folder), *args],
            check=True, capture_output=True, text=True,
        ).stdout
        return json.loads(out.splitlines()[0])


def without_frontmatter(text: str) -> str:
    return re.sub(r"\A---\n.*?\n---\n", "", text, count=1, flags=re.S).strip()


def without_tracker_fields(text: str) -> str:
    match = re.match(r"\A---\n(.*?)\n---\n", text, flags=re.S)
    if not match:
        return text
    kept = [line for line in match.group(1).split("\n") if line.split(":", 1)[0] not in TRACKER_KEYS]
    return "---\n" + "\n".join(kept) + "\n---\n" + text[match.end():]


def with_frontmatter(text: str, fields: dict[str, str]) -> str:
    match = re.match(r"\A---\n(.*?)\n---\n", text, flags=re.S)
    lines = match.group(1).split("\n") if match else []
    rest = text[match.end():] if match else text
    insert_at = 1 if lines and lines[0].startswith("id:") else 0
    for key, value in fields.items():
        line = f"{key}: {value}"
        index = next((i for i, l in enumerate(lines) if l.split(":", 1)[0] == key), None)
        if index is None:
            lines.insert(insert_at, line)
            insert_at += 1
        else:
            lines[index] = line
    return "---\n" + "\n".join(lines) + "\n---\n" + rest


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
        f"Synced from [{issue.source.name}]({BLOB}{path}). The text above drops planning ids for readers; "
        "the ticket's fields and its original text are below, verbatim.\n\n"
        f"{fenced(meta, 'json')}\n\n{fenced(issue.raw, 'json' if issue.source.suffix == '.toml' else 'markdown')}\n\n</details>"
    )


def column(state: str, ref: str, ready: set[str]) -> str:
    return "ready" if state == "backlog" and ref in ready else state


class Sync:
    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.tree = Tree(args.project_root.resolve())
        self.gh = Gh(args.apply)
        self.map_path = self.tree.folder / "github-board.json"
        self.mapping: dict[str, int] = json.loads(self.map_path.read_text()) if self.map_path.exists() else {}
        self.changed_files: set[Path] = set()

    def on_github(self, ref: str) -> Published:
        return self.published.get(self.mapping.get(ref, 0), ABSENT)

    def run(self, overrides: dict[str, str]) -> None:
        tree = self.tree
        status = tree.run("status")
        declared = tomllib.loads((tree.folder / "tickets.toml").read_text())["epic"]
        releases = {e["slug"]: e.get("release", "") for e in declared}
        epics = {e["slug"]: e for e in status["epics"]}
        rows = status["tickets"]
        known = set(self.mapping)
        scope = [s for s in epics if s in known or any(
            r["epic"] == s and r["state"] not in FINISHED for r in rows)]
        rows = [r for r in rows if r["epic"] in scope]
        unreleased = [s for s in scope if not releases[s]]
        if unreleased:
            sys.exit(f"no release in tickets.toml for: {', '.join(unreleased)}")
        missing = [ref for ref in overrides if ref not in {r["ref"] for r in rows}]
        if missing:
            sys.exit(f"no ticket {', '.join(missing)} in a synced epic")

        self.published = snapshot(self.gh)
        targets = {r["ref"]: self.target(r, overrides.get(r["ref"])) for r in rows}
        for row in rows:
            self.write_back(row, targets[row["ref"]])
        if self.changed_files:
            status = tree.run("status")
            rows = [r for r in status["tickets"] if r["epic"] in scope]
        ready = {t["ref"] for t in tree.run("next", "--synced")["ready_to_start"]}

        issues = self.issues(scope, rows, {e["slug"]: e for e in declared}, releases)
        self.create(issues)
        self.refresh_bodies(issues)
        self.relate(rows)
        for slug in scope:
            self.move(slug, "done" if epics[slug].get("status") == "done" else "in-progress", ready)
        for row in rows:
            self.move(row["ref"], targets[row["ref"]], ready)
        self.write_epic_ids(scope)

        for path in sorted(self.changed_files):
            print(f"local {path.relative_to(tree.root)}")
        if not self.args.apply:
            print(f"\ndry run: {len(scope)} epics, {len(rows)} tickets; rerun with --apply")

    def target(self, row: dict, override: str | None) -> str:
        if override:
            return override
        current = self.on_github(row["ref"])
        if row["ref"] not in self.mapping:
            return STATE_OF_BUILD[row["status"]]
        build_moved = row["status"] != current.meta.get("build_status")
        if build_moved and current.state not in FINISHED:
            return STATE_OF_BUILD[row["status"]]
        return current.state

    def write_back(self, row: dict, state: str) -> None:
        derived = row["tracker_status"] or STATE_OF_BUILD[row["status"]]
        number = self.mapping.get(row["ref"])
        if not row["file"]:
            if state == derived or row["state"] == "planned" and state == "backlog":
                return
            print(f"pull {row['ref']}")
            if not self.args.apply:
                return
            pulled = self.tree.run("pull", str(row["id"]), folder=self.tree.folder / row["epic"])
            row["file"] = pulled["file"]
        path = self.tree.folder / row["epic"] / row["file"]
        fields = {"tracker_status": state}
        if number:
            fields |= {"tracker_id": str(number), "remote": f"{ISSUE_URL}{number}"}
        self.update_file(path, fields)

    def update_file(self, path: Path, fields: dict[str, str]) -> None:
        text = path.read_text()
        updated = with_frontmatter(text, fields)
        if updated != text:
            self.changed_files.add(path)
            if self.args.apply:
                path.write_text(updated)

    def write_epic_ids(self, scope: list[str]) -> None:
        for slug in scope:
            number = self.mapping.get(slug, 0)
            epic_file = self.tree.folder / slug / f"{slug}.md"
            if number > 0 and epic_file.exists():
                self.update_file(epic_file, {"tracker_id": str(number), "remote": f"{ISSUE_URL}{number}"})

    def issues(self, scope: list[str], rows: list[dict], declared: dict, releases: dict) -> list[Issue]:
        folder = self.tree.folder
        issues = []
        for slug in scope:
            epic_file = folder / slug / f"{slug}.md"
            raw = without_tracker_fields(epic_file.read_text()) if epic_file.exists() else ""
            meta = {"ref": slug, "type": "epic", **declared[slug]}
            issues.append(Issue(slug, declared[slug]["title"], without_frontmatter(raw), epic_file, ["epic"],
                                releases[slug], meta, raw))
        for row in rows:
            found = self.tree.run("find", row["ref"])
            story_file = Path(found["story_file"]) if found.get("story_file") else None
            source = story_file or folder / row["epic"] / "tickets.toml"
            raw = without_tracker_fields(story_file.read_text()) if story_file else json.dumps(
                {k: found[k] for k in ENTRY_FIELDS if found.get(k)}, ensure_ascii=False, indent=2)
            meta = {k: row[k] for k in TICKET_FIELDS if row.get(k) not in (None, "", [])}
            meta["build_status"] = row["status"]
            labels = [row["type"]] + (["hitl"] if row["hitl"] else [])
            issues.append(Issue(row["ref"], row["title"], entry_body(found), source, labels,
                                releases[row["epic"]], meta, raw))
        return issues

    def rendered(self, issue: Issue) -> str:
        text = humanize(issue.body, self.mapping) + source_block(issue, self.tree.root)
        if len(text) > BODY_LIMIT:
            sys.exit(f"{issue.ref}: body of {len(text)} characters is over GitHub's limit")
        return text

    def create(self, issues: list[Issue]) -> None:
        for issue in issues:
            if issue.ref in self.mapping:
                continue
            print(f"create {issue.ref}: {issue.title}")
            url = self.gh.write("issue", "create", "-R", REPO, "--title", issue.title, "--body",
                                self.rendered(issue), "--label", ",".join(issue.labels),
                                "--milestone", issue.release).strip()
            self.mapping[issue.ref] = int(url.rsplit("/", 1)[-1]) if url else -1
            if self.args.apply:
                self.map_path.write_text(json.dumps(self.mapping, indent=2, sort_keys=True) + "\n")
                self.changed_files.add(self.map_path)
                time.sleep(CREATE_PAUSE_SECONDS)

    def refresh_bodies(self, issues: list[Issue]) -> None:
        for issue in issues:
            wanted = self.rendered(issue)
            if self.on_github(issue.ref).body.strip() != wanted.strip():
                print(f"body {issue.ref}")
                self.gh.write("issue", "edit", str(self.mapping[issue.ref]), "-R", REPO, "--body", wanted)

    def relate(self, rows: list[dict]) -> None:
        for row in rows:
            same_epic = row["ref"].split(".")[0]
            refs = [a if isinstance(a, str) and "." in a else f"{same_epic}.{a}" for a in row["after"]]
            current = self.on_github(row["ref"])
            edit = []
            if current.parent is None:
                edit += ["--parent", str(self.mapping[row["epic"]])]
            missing = [str(self.mapping[r]) for r in refs if r in self.mapping and self.mapping[r] not in current.blocked_by]
            if missing:
                edit += ["--add-blocked-by", ",".join(missing)]
            if edit:
                print(f"relate {row['ref']}")
                self.gh.write("issue", "edit", str(self.mapping[row["ref"]]), "-R", REPO, *edit)

    def move(self, ref: str, state: str, ready: set[str]) -> None:
        number = str(self.mapping[ref])
        current = self.on_github(ref)
        if state in FINISHED:
            if current.state != state:
                print(f"close {ref} -> {state}")
                self.gh.write("issue", "close", number, "-R", REPO,
                              *(["--reason", "not planned"] if state == "dropped" else []))
        else:
            if current.closed:
                print(f"reopen {ref}")
                self.gh.write("issue", "reopen", number, "-R", REPO)
            stale = sorted(current.labels & set(STATE_LABELS) - {state})
            if state not in current.labels or stale:
                print(f"label {ref} -> {state}")
                self.gh.write("issue", "edit", number, "-R", REPO, "--add-label", state,
                              *(["--remove-label", ",".join(stale)] if stale else []))
        item = current.item_id
        if item is None:
            print(f"board add {ref}")
            item = self.gh.write("project", "item-add", PROJECT_NUMBER, "--owner", OWNER, "--url",
                                 f"{ISSUE_URL}{number}", "--format", "json", "-q", ".id").strip()
        wanted = STATUS_OPTION[column(state, ref, ready)]
        if current.status_option != wanted:
            print(f"board {ref} -> {column(state, ref, ready)}")
            self.gh.write("project", "item-edit", "--project-id", PROJECT_ID, "--id", item or "<item id>",
                          "--field-id", STATUS_FIELD, "--single-select-option-id", wanted)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", nargs="?", choices=["sync", "set"], default="sync")
    parser.add_argument("ref", nargs="?")
    parser.add_argument("state", nargs="?", choices=STATES)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.command == "set" and not (args.ref and args.state):
        parser.error("set needs a ticket ref and a state")
    Sync(args).run({args.ref: args.state} if args.command == "set" else {})


if __name__ == "__main__":
    main()
