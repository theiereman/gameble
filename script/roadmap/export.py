#!/usr/bin/env python3
"""Writes the landing's roadmap from the initiative's ticket tree.

The author chooses what the roadmap shows with an opt-in field on the
initiative's `[[epic]]` tables and on the epics' `[[entry]]` tables:

    roadmap = { en = "Visitors meet gameble", fr = "Bienvenue à bord" }

Each chosen epic is a milestone, each chosen entry one of its stories, in
build order. Statuses come from `tickets.py status`. The script writes
config/roadmap.yml (keys and statuses) and config/locales/roadmap/{en,fr}.yml
(the wording), since the planning folder is not in the production image.

  python3 script/roadmap/export.py                    # writes the files that changed
  python3 script/roadmap/export.py --check            # exits 1 when a file differs
  any of them with --initiative <dir> or --out <dir>  # another tree, another folder than the repo root

The output is deterministic: running it again changes no file.
"""

import argparse
import json
import re
import shlex
import subprocess
import sys
import tomllib
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TICKETS_SCRIPT = ROOT / "_bmad" / "method" / "scripts" / "tickets.py"
DEFAULT_INITIATIVE = ROOT / "_bmad-output" / "initiative-gameble"
BREAKDOWN = "tickets.toml"
LOCALES = ("en", "fr")
ROADMAP_FILE = Path("config/roadmap.yml")
LOCALE_FILES = {locale: Path(f"config/locales/roadmap/{locale}.yml") for locale in LOCALES}
GENERATED_HEADER = "# Written by script/roadmap/export.py from the initiative's roadmap fields; rerun it, never edit by hand.\n"

STORY_STATUS = {
    "done": "done",
    "in-progress": "in_progress",
    "review": "in_progress",
    "planned": "to_come",
    "backlog": "to_come",
}
EPIC_STATUS = {"done": "done", "in-progress": "in_progress"}
STARTED_STATES = ("in-progress", "review", "done")
# YAML 1.1 reads these plain keys as booleans or null.
AMBIGUOUS_KEYS = {"y", "n", "yes", "no", "on", "off", "true", "false", "null"}


class RoadmapError(Exception):
    pass


def key_of(text: str) -> str:
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "_", ascii_text.lower()).strip("_")[:60].rstrip("_")


def epic_key(slug: str) -> str:
    return key_of(slug.removeprefix("epic-"))


def read_breakdown(folder: Path) -> dict:
    path = folder / BREAKDOWN
    if not path.is_file():
        return {}
    try:
        return tomllib.loads(path.read_text(encoding="utf-8-sig"))
    except tomllib.TOMLDecodeError as error:
        raise RoadmapError(f"{folder.name}/{BREAKDOWN}: {error}") from error


def wording(table: dict, where: str) -> dict | None:
    if "roadmap" not in table:
        return None
    field = table["roadmap"]
    valid = (
        isinstance(field, dict)
        and set(field) == set(LOCALES)
        and all(isinstance(field[locale], str) and field[locale].strip() for locale in LOCALES)
    )
    if not valid:
        raise RoadmapError(f'{where}: `roadmap` must be {{ en = "...", fr = "..." }}, both non-empty strings')
    return {locale: field[locale] for locale in LOCALES}


def ticket_tree(initiative: Path) -> dict:
    result = subprocess.run(
        [sys.executable, str(TICKETS_SCRIPT), "--project-root", str(ROOT), "status", str(initiative)],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        raise RoadmapError(f"tickets.py status failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


def epic_status(slug: str, frontmatter_status: str, tickets: list[dict]) -> str:
    if frontmatter_status in EPIC_STATUS:
        return EPIC_STATUS[frontmatter_status]
    states = [t["state"] for t in tickets if t["epic"] == slug and t["state"] != "dropped"]
    if states and all(state == "done" for state in states):
        return "done"
    if any(state in STARTED_STATES for state in states):
        return "in_progress"
    return "to_come"


def chosen_stories(epic_slug: str, epic_chosen: bool, entries: list[dict], states: dict) -> list[dict]:
    stories, keys = [], {}
    for entry in entries:
        title = str(entry.get("title", ""))
        words = wording(entry, f'{epic_slug} entry "{title}"')
        if words is None:
            continue
        if not epic_chosen:
            raise RoadmapError(
                f'{epic_slug} entry "{title}" has a `roadmap` field but its epic {epic_slug} has none'
            )
        state = states.get(entry.get("id"))
        if state is None:
            raise RoadmapError(f'{epic_slug} entry "{title}": tickets.py status does not list it')
        if state == "dropped":
            continue
        key = key_of(title)
        if not key:
            raise RoadmapError(f'{epic_slug} entry "{title}": its title gives no key')
        if key in keys:
            raise RoadmapError(f'{epic_slug}: entries "{keys[key]}" and "{title}" both give the key {key}')
        keys[key] = title
        stories.append({"key": key, "status": STORY_STATUS[state], "wording": words})
    return stories


def milestones(initiative: Path) -> list[dict]:
    tree = ticket_tree(initiative)
    container_status = {epic["slug"]: epic["status"] for epic in tree.get("epics", [])}
    result, keys = [], {}
    listed = read_breakdown(initiative).get("epic", [])
    for epic in listed:
        slug = str(epic.get("slug", ""))
        words = wording(epic, slug)
        entries = read_breakdown(initiative / slug).get("entry", [])
        if words is not None and container_status.get(slug, "") == "dropped":
            for entry in entries:
                title = str(entry.get("title", ""))
                wording(entry, f'{slug} entry "{title}"')
            continue
        states = {t["id"]: t["state"] for t in tree["tickets"] if t["epic"] == slug}
        stories = chosen_stories(slug, words is not None, entries, states)
        if words is None:
            continue
        key = epic_key(slug)
        if key in keys:
            raise RoadmapError(f"epics {keys[key]} and {slug} both give the key {key}")
        keys[key] = slug
        status = epic_status(slug, container_status.get(slug, ""), tree["tickets"])
        result.append({"key": key, "status": status, "wording": words, "stories": stories})
    listed_slugs = {str(epic.get("slug", "")) for epic in listed}
    for folder in sorted(initiative.glob("epic-*")):
        if folder.is_dir() and folder.name not in listed_slugs:
            chosen_stories(folder.name, False, read_breakdown(folder).get("entry", []), {})
    return result


def scalar(text: str) -> str:
    # Psych refuses raw control and format characters, and YAML reads U+0085, U+2028 and U+2029 as line breaks.
    return "".join(
        character if character.isprintable() else escape(character)
        for character in json.dumps(text, ensure_ascii=False)
    )


def escape(character: str) -> str:
    code = ord(character)
    return f"\\u{code:04x}" if code <= 0xFFFF else f"\\U{code:08x}"


def mapping_key(key: str) -> str:
    plain = re.fullmatch(r"[a-z][a-z0-9_]*", key) and key not in AMBIGUOUS_KEYS
    return key if plain else scalar(key)


def roadmap_yaml(chosen: list[dict]) -> str:
    lines = [GENERATED_HEADER.rstrip("\n"), "shared:"]
    if not chosen:
        lines.append("  milestones: []")
    else:
        lines.append("  milestones:")
    for milestone in chosen:
        lines += [f"  - key: {scalar(milestone['key'])}", f"    status: {scalar(milestone['status'])}"]
        if not milestone["stories"]:
            lines.append("    stories: []")
            continue
        lines.append("    stories:")
        for story in milestone["stories"]:
            lines += [f"    - key: {scalar(story['key'])}", f"      status: {scalar(story['status'])}"]
    return "\n".join(lines) + "\n"


def locale_yaml(chosen: list[dict], locale: str) -> str:
    lines = [GENERATED_HEADER.rstrip("\n"), f"{locale}:", "  roadmap:"]
    if not chosen:
        lines.append("    milestones: {}")
    else:
        lines.append("    milestones:")
    for milestone in chosen:
        lines += [
            f"      {mapping_key(milestone['key'])}:",
            f"        name: {scalar(milestone['wording'][locale])}",
        ]
        if not milestone["stories"]:
            lines.append("        stories: {}")
            continue
        lines.append("        stories:")
        for story in milestone["stories"]:
            lines.append(f"          {mapping_key(story['key'])}: {scalar(story['wording'][locale])}")
    return "\n".join(lines) + "\n"


def outputs(chosen: list[dict]) -> dict[Path, str]:
    files = {ROADMAP_FILE: roadmap_yaml(chosen)}
    files.update({path: locale_yaml(chosen, locale) for locale, path in LOCALE_FILES.items()})
    return files


def current(path: Path) -> str | None:
    return path.read_text(encoding="utf-8") if path.is_file() else None


def rerun_command(argv: list[str]) -> str:
    return shlex.join(["python3", "script/roadmap/export.py", *[arg for arg in argv if arg != "--check"]])


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Write the landing's roadmap from the initiative's ticket tree.")
    parser.add_argument("--initiative", default=str(DEFAULT_INITIATIVE), help="the initiative folder")
    parser.add_argument("--out", help="the folder holding config/ (default: the repo root)")
    parser.add_argument("--check", action="store_true", help="compare with the committed files, write nothing")
    args = parser.parse_args(argv)
    initiative = Path(args.initiative)
    initiative = (initiative if initiative.is_absolute() else ROOT / initiative).resolve()
    out = (ROOT / args.out).resolve() if args.out else ROOT

    try:
        chosen = milestones(initiative)
    except RoadmapError as error:
        print(f"roadmap: {error}", file=sys.stderr)
        return 1

    files = outputs(chosen)
    stale = [path for path, content in files.items() if current(out / path) != content]
    counts = f"{len(chosen)} milestones, {sum(len(m['stories']) for m in chosen)} stories"

    def shown(path: Path) -> str:
        return str(path) if out == ROOT else str(out / path)

    if args.check:
        if stale:
            for path in stale:
                print(f"differs: {shown(path)}")
            print(f"run: {rerun_command(argv)}")
            return 1
        print(f"roadmap: {counts} up to date")
        return 0

    for path in stale:
        (out / path).parent.mkdir(parents=True, exist_ok=True)
        (out / path).write_text(files[path], encoding="utf-8", newline="\n")
    print(f"roadmap: {counts} {'written' if stale else 'up to date'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
