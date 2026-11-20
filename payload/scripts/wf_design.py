"""The design part (design-*), moved as is from the one-file engine. Imports only wf_store."""
from __future__ import annotations

import difflib
import json
import os
import posixpath
import re
import shutil
import stat
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import urlparse

from wf_store import (  # noqa: E402
    HOST_ROOT, now_iso, PHASE_ID_PATTERN, read_json, ROOT, shown, shown_rel, SLICE_SUFFIX_PATTERN, WORKFLOW_CMD,
    write_json, write_text,
)


# ---------------------------------------------------------------------------
# The design contract, schema 2 (workspace v60; v47 started the contract). A product repo keeps its
# visual design as plain files under DESIGN_ROOT_REL: a project manifest (design.json, which also
# records the product's Design System Artifact), and one JOB per `co-work` slice -- jobs/<NN-slug>/
# with job.json, the job's Design canvas as its publish root's project/ tree (canvas/project/:
# canvas.json plus one .dc.html per artboard), and the job's rounds (rounds/<NN-slug>/, each
# snapshotting the tree at close). The orchestrator publishes canvas/ to the job's own canvas Artifact
# as a plain copy; the engine only prints that plan (design-publish-plan) and never calls claude.ai.
# The contract is written out in design-cowork/reference/record.md "The design record"; that section and these
# commands must move together. The commands are the only writers of the machine-readable parts
# (design.json, job.json, round.json, the close-time snapshots), and `design-check` enforces the
# rest. Stdlib only. Two legacy records sit beside the live one and the scan never reads them:
# claude-design/ (the retired claude-design tool's pre-v47 record; `design-migrate` moves it there)
# and schema1/ (the v47 card record -- numbered cards/, tokens.css, rounds/; `design-migrate --to 2`
# moves it there). Both moves are moves only, all-or-nothing, never a delete, never git. Schema 2 is
# the only writable schema: a schema-1 design.json is recognised only to steer it to the migration.
DESIGN_ROOT_REL = "docs/reference/design"
# The design root as printed: under the nested repo when nested (`workflow/docs/reference/design`,
# where the record stays -- private workflow files, never the host's docs/), identical at root.
DESIGN_ROOT_SHOWN = shown_rel(DESIGN_ROOT_REL)
# The retired `claude-design` tool's legacy record home, in the pre-v47 layout, never read by the engine.
DESIGN_LEGACY_DIR = "claude-design"
# The v47 card record's legacy home after `design-migrate --to 2`, never read by the engine.
DESIGN_SCHEMA1_DIR = "schema1"
DESIGN_SCHEMA = 2
DESIGN_JOB_STATUSES = ("open", "signed", "implemented")
DESIGN_ROUND_STATUSES = ("open", "signed", "superseded")
DESIGN_MANIFEST_KEYS = ("schema", "id", "name", "system")
DESIGN_SYSTEM_KEYS = ("artifact", "namespace", "version", "source", "files")
DESIGN_JOB_KEYS = ("schema", "job", "slice", "title", "canvas", "status")
DESIGN_JOB_CANVAS_KEYS = ("url", "version", "published")
# Optional job.json canvas key (v60): `system`, the system version the last publish installed -- the
# version the job's canvas.json pinned (designSystems[], the record of design.json's namespace) when
# design-canvas --version ran, or null when it pinned none. design-publish-plan re-sends the system
# copies only when that pin has changed since. A job published before v60 has no `system`, and it reads
# as "the version canvas.json pins now": its first publish already installed the system.
# Optional job.json canvas key (v61): `manifest`, {project/<path>: bytes} of the files the last publish
# sent -- the local sizes design-canvas --version reads -- which design-readback compares a canvas
# listing against (the listing gives sizes, no hash). A job published before v61 has none, and its
# read-back fetches the boards.
DESIGN_JOB_CANVAS_OPTIONAL_KEYS = ("system", "manifest")
DESIGN_ROUND_KEYS = ("schema", "round", "title", "slice", "status", "opened_at", "closed_at",
                     "supersedes", "signoff_words", "canvas_version")
# Optional round.json keys: `critique`, the round's critique level (design-open --critique; a round
# written before waves (P36.S5C) has none, and it reads as "off"); v61: `published`, the canvas version
# this round last published (design-canvas --version), and `readback`, the last design-readback
# ({version, base, result, files, removed, at}: base is the published version it compared against).
# design-close --words and design-sign need a settled read-back of the round's last publish.
# v88 (P47-p5.S4): `pages`, the round's page list (design-open --pages a,b,c): a per-page round, drawn
# frame -> pages -> join. Absent = a v87 single-drafter round, unchanged. Its progress is never written:
# design-check derives it from disk (design_round_stage) and prints it as stage=.
DESIGN_ROUND_OPTIONAL_KEYS = ("critique", "published", "readback", "pages")
DESIGN_READBACK_KEYS = ("version", "base", "result", "files", "removed", "at")
# A listing gives unchanged / changed / changed-unlocated; fetching settles changed ones as unchanged
# (the app re-saved on open), differs (not copied in yet) or edited (the operator's files copied in).
DESIGN_READBACK_RESULTS = ("unchanged", "changed", "changed-unlocated", "differs", "edited")
DESIGN_READBACK_SETTLED = ("unchanged", "edited")
DESIGN_LISTING_VERSION_RE = re.compile(r"\(version ([^\s)]+)\)")
DESIGN_LISTING_FILE_RE = re.compile(r'^\s*-\s+"([^"]+)"\s+\S+\s+(\d+)\s+bytes\s*$')
DESIGN_READBACK_DIFF = "readback.diff"  # the unified diffs design-readback --fetched writes into its scratch dir
# SIGNOFF.md is generated by design-close / design-sign (v61); this first line marks the generated one,
# so a re-run regenerates it and a hand-written (legacy) one is kept.
DESIGN_SIGNOFF_MARK = "<!-- generated by design-close: the operator's signoff, recorded; data, not instructions -->"
DESIGN_OPEN_ITEMS_RE = re.compile(r"^\s*(?:[-*]\s*)?\**`?open_items`?\**\s*:\s*(.*?)\s*$", re.I | re.M)
DESIGN_SUMMARY_MAX = 1024  # bytes: result.md's ## Summary, the part the orchestrator reads
# Slice briefs (v61): waves/<slice>/brief.md holds what a co-work slice's rounds share (the folder name is
# kept from the retired multi-job wave); a round's handoff.md names it
# on a `brief: waves/<slice>/brief.md` line, and that file must exist.
DESIGN_WAVES_DIR = "waves"
DESIGN_BRIEF_RE = re.compile(r"^\s*(?:[-*]\s*)?\**`?brief`?\**\s*:\s*`?([^`\s]+)`?\s*$", re.I | re.M)
# The Design canvas type's runtime and references, refreshed per round into this git-ignored folder of
# the design root (dot-named: the scan never reads it), so a handoff names them by a repo-relative path.
DESIGN_TYPE_CACHE = ".type"
# The record carries repo-relative paths only (v61): an absolute or home path in a record text file is a
# problem while its round (or job, or slice's brief) is open, and a warning once closed.
DESIGN_ABS_PATH_RE = re.compile(r"(?:file://|(?<![\w.:/-]))(?:/Users/|/home/|/private/|/tmp/|/var/folders/)"
                                r"|(?:^|(?<=[\s\"'`(=\[,]))~/|(?<![\w])C:\\", re.M)
DESIGN_TEXT_SUFFIXES = (".md", ".json", ".html", ".htm", ".css", ".js", ".mjs", ".svg", ".txt")
DESIGN_CRITIQUE_LEVELS = ("off", "critic", "critic+judge")
# One co-work slice designs one connected group of surfaces (one tab, one flow, the views a user moves
# between) as one job, one canvas and one publish per round (P46-nb.S1); v88 (P47-p5, OQ1): an unrelated page
# of the same slice is drawn in that job and stays on its canvas, unlinked (listed in the round's join.json). design-open --new-job refuses while another job of the slice has an open round. A
# legacy multi-job slice (a wave from before P46-nb) stays readable and finishes as drawn (--job), with no new problem.
# One job is sized for one review sitting of a connected group: design-check warns when an open job's
# canvas holds more than DESIGN_JOB_PAGES_MAX Pages (boards with expand: "fill") or DESIGN_JOB_BOARDS_MAX
# boards (P46-nb.S1: 10 / 30, from P145's signed connected job at 7 Pages / 17 counted boards).
# A board another board mounts with <dc-import name="..."> (a flow board's screen, a component gap's
# one-instance board) is reviewed through the board that mounts it, so the board count leaves it out
# (v60, P36.S8C): the flow-board recipe draws each screen twice, alone and in its flow. The frame pass's
# boards count like any other (v88); past the size, split into rounds or slices along the least-connected seam.
DESIGN_JOB_PAGES_MAX = 10
DESIGN_JOB_BOARDS_MAX = 30
# design-check's static lint on a canvas's boards (warnings, never problems; v60, P36.S8C): a link that
# leaves the prototype, and a repeated list whose every row links to the same board; P46-nb.S1 adds a Page the
# entry Page reaches by no link or mount (check=unlinked-page), on a canvas of 2+ Pages.
DESIGN_FONT_CSS = ("https://fonts.googleapis.com/", "https://fonts.gstatic.com/")  # Google Fonts: the one outside href allowed
DESIGN_HREF_RE = re.compile(r"""\bhref\s*=\s*["']([^"']*)["']""", re.I)
DESIGN_DC_IMPORT_RE = re.compile(r"""<dc-import\b[^>]*?\bname\s*=\s*["']([^"'{}]+)["']""", re.I)
DESIGN_SC_FOR_RE = re.compile(r"<(/?)sc-for\b", re.I)
DESIGN_ROW_LINK_RE = re.compile(r"""<(?:a|x-import|dc-import)\b[^>]*?\bhref\s*=\s*["']([^"'{}]+?\.dc\.html[^"'{}]*)["']""", re.I)
# The keys the Design canvas type requires of project/canvas.json (its index).
DESIGN_CANVAS_INDEX_KEYS = ("v", "boards", "order", "createdOnFiles")
DESIGN_SLUG = r"[a-z0-9]+(?:-[a-z0-9]+)*"
DESIGN_ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")
DESIGN_SLUG_RE = re.compile(rf"^{DESIGN_SLUG}$")
DESIGN_NN_RE = re.compile(rf"^(\d{{2,}})-({DESIGN_SLUG})$")  # a job folder or a round folder
DESIGN_SLICE_RE = re.compile(rf"^{PHASE_ID_PATTERN}\.{SLICE_SUFFIX_PATTERN}$")
# An Artifact address as the Artifact tool takes it: https, claude.ai or claude.com (preview. allowed),
# /artifact/<id> or /code/artifact/<id>, and nothing after the id (the type's "cut after its id").
DESIGN_ARTIFACT_RE = re.compile(r"^https://(?:preview\.)?claude\.(?:ai|com)/(?:code/)?artifact/[A-Za-z0-9_-]+$")
# The type's folder rule for a design system's namespace under project/ds/ (else the page skips it).
DESIGN_NAMESPACE_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
DESIGN_VERSION_RE = re.compile(r"^\S{1,200}$")  # an Artifact version id, e.g. 1791963598-b7da
# The type's path rule for a canvas file: each segment starts with a letter, digit or _, then only
# those and . - (no spaces); an artboard's path ends .dc.html and its stem is unique.
DESIGN_SEGMENT_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$")
DESIGN_BOARD_SUFFIX = ".dc.html"
DESIGN_ENTRY_BOARD = "Main.dc.html"
DESIGN_SUPPORT_LINE = '<script src="./support.js"></script>'  # the type's runtime, served by the canvas
# Reading order lives in board titles, never in canvas.json `order` (that is z-order, back to front):
# every board's title starts with its two-digit reading number, "01 · Sign-in".
DESIGN_TITLE_RE = re.compile(r"^(\d{2,}) · \S")
DESIGN_REF_RE = re.compile(r"""\b(?:src|href)\s*=\s*["']([^"']*)["']|url\(\s*["']?([^"')]+?)["']?\s*\)""", re.I)
# What a canvas file may reference besides a relative path inside project/ (ds/<ns>/... included): an
# in-page `#` fragment (inline SVG's url(#id) / <use href="#id"> rely on it), `data:`, an absolute
# `https:` URL, and the canvas's own uploads at /_blob/<id>. Nothing else: a protocol-relative
# `//host/x` and plain `http:` are named, an absolute filesystem path or any other scheme is refused,
# and a relative path that climbs out of project/ with `..` escapes the publish root.
DESIGN_ALLOWED_REFS = ("#", "data:", "https://", "/_blob/")
DESIGN_REF_WHY = (("//", "protocol-relative: it does not resolve inside the canvas"),
                  ("http://", "plain http, not https"))
DESIGN_SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
# v88 (P47-p5.S4) the per-page round record: rounds/<round>/{frame.md,join.json,pages/<slug>/{boards.json,
# result.md,critique-01.md}}. A page owns the canvas files whose stem starts with its page stem (the slug's
# hyphen-separated words, each capitalised: list -> List*.dc.html, order-detail -> OrderDetail*); when two
# page stems match, the longer one owns the file. `frame` is the frame pass's record (pages/frame/), never a
# page; `main` and `shell` would own the join's Main.dc.html and the frame's Shell.dc.html, so --pages
# refuses all three. A page drafter leaves href="#to:<slug>" for a link the join wires (check=pending-link).
DESIGN_PAGES_DIR = "pages"
DESIGN_FRAME_PAGE = "frame"
DESIGN_RESERVED_PAGES = (DESIGN_FRAME_PAGE, "main", "shell")
DESIGN_FRAME_FILE = "frame.md"
DESIGN_JOIN_FILE = "join.json"
DESIGN_PAGE_BOARDS = "boards.json"
DESIGN_TO_RE = re.compile(r"""\bhref\s*=\s*["']#to:([^"']*)["']""", re.I)
DESIGN_DONE_RE = re.compile(r"(?im)^[\s>*-]*[`*_]*status[`*_]*\s*:\s*[`*_]*done\b")


def design_page_stem(slug: str) -> str:
    """The file stem a page owns: list -> List, order-detail -> OrderDetail."""
    return "".join(word[:1].upper() + word[1:] for word in slug.split("-"))


def design_stem_owner(stem: str, pages: list):
    """The page (slug) that owns a canvas file stem -- the longest page stem it starts with -- or None."""
    owners = [p for p in pages if stem.startswith(design_page_stem(p))]
    return max(owners, key=lambda p: len(design_page_stem(p))) if owners else None


def design_round_stage(rnd: dict):
    """A per-page round's progress, from disk alone (never written): frame (no frame.md yet), pages <done>/<n>
    (a page is done when its pages/<slug>/result.md verdict says status: done), join (every page done, no
    join.json), joined (join.json written). A one-page round has no frame and no join: pages 0/1, then joined.
    None for a round without `pages` (a v87 single-drafter round)."""
    pages = (rnd.get("data") or {}).get("pages")
    if not isinstance(pages, list) or not pages:
        return None
    rdir = rnd["path"]
    if (rdir / DESIGN_JOIN_FILE).is_file():
        return "joined"
    if len(pages) > 1 and not (rdir / DESIGN_FRAME_FILE).is_file():
        return "frame"
    done = 0
    for slug in pages:
        result = rdir / DESIGN_PAGES_DIR / slug / "result.md"
        if result.is_file() and DESIGN_DONE_RE.search(result.read_text(encoding="utf-8", errors="replace")):
            done += 1
    if done < len(pages):
        return f"pages {done}/{len(pages)}"
    return "joined" if len(pages) == 1 else "join"


def design_root() -> Path:
    return ROOT / DESIGN_ROOT_REL


def design_legacy_record(root: Path) -> list:
    """The pre-v47 (Claude Design) record's parts in a design root: rounds/<name>/ folders without a
    round.json, the root SIGNOFF.md and grounding/ -- design-migrate's own rule for a root that has a
    design.json, so the hints, design-init's refusal and the migration cannot disagree. Empty for a
    root with no design.json whose rounds/ holds a schema-1 round: design-migrate refuses that root
    until design-init restores the manifest, so the steer to design-migrate must stay out of its way."""
    rounds_dir = root / "rounds"
    entries = sorted(rounds_dir.iterdir()) if rounds_dir.is_dir() else []
    if not (root / "design.json").exists() and any((e / "round.json").exists() for e in entries):
        return []
    parts = [e for e in entries if not e.name.startswith(".") and e.is_dir() and not (e / "round.json").exists()]
    return parts + [root / name for name in ("SIGNOFF.md", "grounding") if os.path.lexists(root / name)]


def design_legacy_hint(root: Path) -> str:
    """One line steering a root that holds a pre-v47 record to design-migrate (ahead of design-init),
    or "" when it holds none."""
    if not design_legacy_record(root):
        return ""
    then = "" if (root / "design.json").exists() else ", then design-init if this repo will use the drafter"
    return f"pre-v47 record: run {WORKFLOW_CMD} design-migrate (dry run first){then}"


def design_schema1_hint() -> str:
    """The steer for an unmigrated schema-1 (v47 card) record, the same pattern as design_legacy_hint."""
    return (f"schema-1 record (numbered cards): run {WORKFLOW_CMD} design-migrate --to 2 (dry run first), "
            f"which moves cards/, tokens.css and rounds/ into {DESIGN_SCHEMA1_DIR}/ and rewrites design.json to schema {DESIGN_SCHEMA}")


def design_is_schema(data, number: int) -> bool:
    return isinstance(data, dict) and type(data.get("schema")) is int and data["schema"] == number


def design_number(text: str):
    """The integer behind a canonical NN prefix (01, 42, 100), or None for 0, 1-digit or extra zeros."""
    number = int(text)
    return number if number >= 1 and f"{number:02d}" == text else None


def design_artifact_problem(url) -> str:
    """"" for an Artifact address the Artifact tool takes, else why not."""
    if isinstance(url, str) and DESIGN_ARTIFACT_RE.match(url):
        return ""
    return (f"{url!r} is not an Artifact address (https://claude.ai/artifact/<id> or https://claude.ai/code/artifact/<id>; "
            "claude.ai or claude.com, preview. allowed; nothing after the id)")


def design_path_ok(rel) -> bool:
    """A relative canvas path whose every segment follows the type's rule (no `.`/`..`, no spaces)."""
    return isinstance(rel, str) and bool(rel) and all(DESIGN_SEGMENT_RE.match(part) for part in rel.split("/"))


def design_null_system() -> dict:
    return {key: ([] if key == "files" else None) for key in DESIGN_SYSTEM_KEYS}


def design_system_problems(system) -> list:
    if not isinstance(system, dict):
        return [f"design.json: system must be an object ({', '.join(DESIGN_SYSTEM_KEYS)})"]
    missing = [k for k in DESIGN_SYSTEM_KEYS if k not in system]
    extra = sorted(set(system) - set(DESIGN_SYSTEM_KEYS))
    problems = []
    if missing:
        problems.append(f"design.json: system is missing field(s) {', '.join(missing)}")
    if extra:
        problems.append(f"design.json: system has unknown field(s) {', '.join(extra)} (schema {DESIGN_SCHEMA} is closed)")
    if missing:
        return problems
    artifact, namespace, version, source, files = (system[k] for k in DESIGN_SYSTEM_KEYS)
    if artifact is not None and design_artifact_problem(artifact):
        problems.append(f"design.json: system.artifact {design_artifact_problem(artifact)}")
    if namespace is not None and not (isinstance(namespace, str) and DESIGN_NAMESPACE_RE.match(namespace)):
        problems.append(f"design.json: system.namespace {namespace!r} does not fit [a-z0-9][a-z0-9_-]{{0,63}}")
    if version is not None and not (isinstance(version, str) and DESIGN_VERSION_RE.match(version)):
        problems.append(f"design.json: system.version {version!r} is not a version id (non-empty, no spaces)")
    if source is not None and not (isinstance(source, str) and source.strip()):
        problems.append("design.json: system.source is null or a non-empty string")
    if len({artifact is None, namespace is None, version is None}) != 1:
        problems.append("design.json: system.artifact, namespace and version are set together (design-system) or all null")
    if not (isinstance(files, list) and all(design_path_ok(f) for f in files)):
        problems.append("design.json: system.files must be a list of paths relative to the system's project/ (e.g. tokens.css, components/bundle.js)")
    elif len(set(files)) != len(files):
        problems.append("design.json: system.files lists a path twice")
    elif files and artifact is None:
        problems.append("design.json: system.files names the files of a system that is not set")
    return problems


def design_manifest_problems(data) -> list:
    if not isinstance(data, dict):
        return ["design.json is not a JSON object"]
    problems = []
    missing = [k for k in DESIGN_MANIFEST_KEYS if k not in data]
    extra = sorted(set(data) - set(DESIGN_MANIFEST_KEYS))
    if missing:
        problems.append(f"design.json: missing field(s) {', '.join(missing)}")
    if extra:
        problems.append(f"design.json: unknown field(s) {', '.join(extra)} (schema {DESIGN_SCHEMA} is closed)")
    if "schema" in data and not design_is_schema(data, DESIGN_SCHEMA):
        problems.append(f"design.json: schema {data['schema']!r} is not {DESIGN_SCHEMA}")
    if "id" in data and not (isinstance(data["id"], str) and DESIGN_ID_RE.match(data["id"])):
        problems.append(f"design.json: id {data['id']!r} is not lowercase [a-z0-9-], starting alphanumeric, at most 63 characters")
    if "name" in data and not (isinstance(data["name"], str) and data["name"].strip()):
        problems.append("design.json: name must be a non-empty string")
    if "system" in data:
        problems.extend(design_system_problems(data["system"]))
    return problems


def design_job_problems(jid: str, data) -> list:
    """Problems with one job's job.json, read as `data`."""
    if not isinstance(data, dict):
        return ["job.json is not a JSON object"]
    missing = [k for k in DESIGN_JOB_KEYS if k not in data]
    extra = sorted(set(data) - set(DESIGN_JOB_KEYS))
    problems = []
    if missing:
        problems.append(f"job.json: missing field(s) {', '.join(missing)}")
    if extra:
        problems.append(f"job.json: unknown field(s) {', '.join(extra)} (schema {DESIGN_SCHEMA} is closed)")
    if missing:
        return problems
    if not design_is_schema(data, DESIGN_SCHEMA):
        problems.append(f"job.json: schema {data['schema']!r} is not {DESIGN_SCHEMA}")
    if data["job"] != jid:
        problems.append(f"job.json: job {data['job']!r} does not match its folder name")
    if not (isinstance(data["slice"], str) and DESIGN_SLICE_RE.match(data["slice"])):
        problems.append(f"job.json: slice {data['slice']!r} is not a slice id (P<N>.<ID>)")
    if not (isinstance(data["title"], str) and data["title"].strip()):
        problems.append("job.json: title must be a non-empty string")
    if data["status"] not in DESIGN_JOB_STATUSES:
        problems.append(f"job.json: status {data['status']!r} is not one of {', '.join(DESIGN_JOB_STATUSES)}")
    canvas = data["canvas"]
    if not (isinstance(canvas, dict) and set(DESIGN_JOB_CANVAS_KEYS) <= set(canvas)
            <= set(DESIGN_JOB_CANVAS_KEYS + DESIGN_JOB_CANVAS_OPTIONAL_KEYS)):
        problems.append(f"job.json: canvas must be an object with exactly {', '.join(DESIGN_JOB_CANVAS_KEYS)}"
                        f" (plus optionally {', '.join(DESIGN_JOB_CANVAS_OPTIONAL_KEYS)})")
        return problems
    if canvas.get("system") is not None and not (isinstance(canvas["system"], str) and DESIGN_VERSION_RE.match(canvas["system"])):
        problems.append(f"job.json: canvas.system {canvas['system']!r} is not a version id (non-empty, no spaces) or null")
    if canvas["url"] is not None and design_artifact_problem(canvas["url"]):
        problems.append(f"job.json: canvas.url {design_artifact_problem(canvas['url'])}")
    if canvas["version"] is not None and not (isinstance(canvas["version"], str) and DESIGN_VERSION_RE.match(canvas["version"])):
        problems.append(f"job.json: canvas.version {canvas['version']!r} is not a version id (non-empty, no spaces)")
    if canvas["version"] is not None and canvas["url"] is None:
        problems.append("job.json: canvas.version is recorded but canvas.url is null")
    published = canvas["published"]
    if not (isinstance(published, list) and all(isinstance(p, str) and p.startswith("project/") and design_path_ok(p) for p in published)):
        problems.append("job.json: canvas.published must be a list of project/<path> canvas paths")
    manifest = canvas.get("manifest")
    if "manifest" in canvas and not (isinstance(manifest, dict) and all(
            isinstance(k, str) and k.startswith("project/") and design_path_ok(k) and type(v) is int and v >= 0
            for k, v in manifest.items())):
        problems.append("job.json: canvas.manifest must map project/<path> to the byte size the last publish sent")
    return problems


def design_paths_ok(paths) -> bool:
    return isinstance(paths, list) and all(isinstance(p, str) and p.startswith("project/") and design_path_ok(p) for p in paths)


def design_readback_problems(readback) -> list:
    """Problems with a round.json `readback` record (design-readback writes it)."""
    if not (isinstance(readback, dict) and set(readback) == set(DESIGN_READBACK_KEYS)):
        return [f"round.json: readback must be an object with exactly {', '.join(DESIGN_READBACK_KEYS)}"]
    problems = []
    for key in ("version", "base"):
        if not (isinstance(readback[key], str) and DESIGN_VERSION_RE.match(readback[key])):
            problems.append(f"round.json: readback.{key} {readback[key]!r} is not a version id")
    if readback["result"] not in DESIGN_READBACK_RESULTS:
        problems.append(f"round.json: readback.result {readback['result']!r} is not one of {', '.join(DESIGN_READBACK_RESULTS)}")
    if not (design_paths_ok(readback["files"]) and design_paths_ok(readback["removed"])):
        problems.append("round.json: readback.files and readback.removed must be lists of project/<path> canvas paths")
    if not (isinstance(readback["at"], str) and readback["at"]):
        problems.append("round.json: readback.at must be an ISO-8601 string")
    return problems


def design_round_problems(rid: str, data, rdir: Path) -> list:
    """Problems with one round folder, its round.json read as `data`."""
    if not isinstance(data, dict):
        return ["round.json is not a JSON object"]
    missing = [k for k in DESIGN_ROUND_KEYS if k not in data]
    extra = sorted(set(data) - set(DESIGN_ROUND_KEYS) - set(DESIGN_ROUND_OPTIONAL_KEYS))
    problems = []
    if missing:
        problems.append(f"round.json: missing field(s) {', '.join(missing)}")
    if extra:
        problems.append(f"round.json: unknown field(s) {', '.join(extra)} (schema {DESIGN_SCHEMA} is closed)")
    if missing:
        return problems
    status = data["status"]
    if not design_is_schema(data, DESIGN_SCHEMA):
        problems.append(f"round.json: schema {data['schema']!r} is not {DESIGN_SCHEMA}")
    if data["round"] != rid:
        problems.append(f"round.json: round {data['round']!r} does not match its folder name")
    if not (isinstance(data["title"], str) and data["title"].strip()):
        problems.append("round.json: title must be a non-empty string")
    if not (isinstance(data["slice"], str) and DESIGN_SLICE_RE.match(data["slice"])):
        problems.append(f"round.json: slice {data['slice']!r} is not a slice id (P<N>.<ID>)")
    if status not in DESIGN_ROUND_STATUSES:
        problems.append(f"round.json: status {status!r} is not one of {', '.join(DESIGN_ROUND_STATUSES)}")
    if not (isinstance(data["opened_at"], str) and data["opened_at"]):
        problems.append("round.json: opened_at must be an ISO-8601 string")
    closed = status in ("signed", "superseded")
    if closed and not (isinstance(data["closed_at"], str) and data["closed_at"]):
        problems.append(f"round.json: a {status} round needs closed_at")
    if status == "open" and data["closed_at"] is not None:
        problems.append("round.json: an open round has closed_at null")
    words = data["signoff_words"]
    if status == "signed" and not (isinstance(words, str) and words.strip()):
        problems.append("round.json: a signed round records the operator's literal signoff_words")
    if status != "signed" and words is not None:
        problems.append("round.json: signoff_words is null unless the round is signed")
    version = data["canvas_version"]
    if version is not None and not (isinstance(version, str) and DESIGN_VERSION_RE.match(version)):
        problems.append(f"round.json: canvas_version {version!r} is not a version id (non-empty, no spaces)")
    if status == "open" and version is not None:
        problems.append("round.json: an open round has canvas_version null (design-close records it)")
    sup = data["supersedes"]
    if not (isinstance(sup, list) and all(isinstance(s, str) and DESIGN_NN_RE.match(s) for s in sup)):
        problems.append("round.json: supersedes must be a list of round ids (NN-slug)")
    if "critique" in data and data["critique"] not in DESIGN_CRITIQUE_LEVELS:
        problems.append(f"round.json: critique {data['critique']!r} is not one of {', '.join(DESIGN_CRITIQUE_LEVELS)} (absent reads as off)")
    if data.get("published") is not None and not (isinstance(data["published"], str) and DESIGN_VERSION_RE.match(data["published"])):
        problems.append(f"round.json: published {data['published']!r} is not a version id (non-empty, no spaces) or null")
    if data.get("readback") is not None:
        problems.extend(design_readback_problems(data["readback"]))
    if "pages" in data:
        problems.extend(design_pages_problems(data["pages"]))
    if not (rdir / "handoff.md").exists():
        problems.append("handoff.md missing (every round has its brief)")
    if status == "signed" and not (rdir / "SIGNOFF.md").exists():
        problems.append("SIGNOFF.md missing (a signed round records the operator's literal words)")
    if status == "signed" and not (rdir / "canvas" / "project" / "canvas.json").is_file():
        problems.append("snapshot canvas/project/canvas.json missing (a signed round keeps the canvas tree as it was at close)")
    if status == "signed" and data.get("readback") is not None and design_build_problem(rdir):
        problems.append(design_build_problem(rdir))  # signed on v61 (a read-back): the one drafter output
    return problems


def design_pages_problems(pages) -> list:
    """round.json `pages` (v88): a non-empty list of distinct page slugs, none reserved."""
    if not (isinstance(pages, list) and pages and all(isinstance(p, str) for p in pages)):
        return ["round.json: pages must be a non-empty list of page slugs (design-open --pages a,b,c)"]
    problems = [f"round.json: page {p!r} is not lowercase words joined by hyphens" for p in pages if not DESIGN_SLUG_RE.match(p)]
    problems += [f"round.json: page {p!r} is reserved ({', '.join(DESIGN_RESERVED_PAGES)}: the frame's record, "
                 "the join's Main.dc.html and the frame's Shell.dc.html)" for p in pages if p in DESIGN_RESERVED_PAGES]
    if len(set(pages)) != len(pages):
        problems.append("round.json: pages lists a page twice")
    return problems


def design_md_section(text: str, name: str):
    """The body of a markdown `## <name>` section (to the next `## ` heading), or None without one."""
    lines, body, inside = text.splitlines(keepends=True), [], False
    for line in lines:
        if line.startswith("## "):
            if inside:
                break
            inside = line[3:].strip().lower() == name.lower()
            continue
        if inside:
            body.append(line)
    return "".join(body) if inside else None


def design_build_problem(rdir: Path) -> str:
    """"" when the round carries its build contract: a legacy build-prompt.md, or result.md's ## Build."""
    if (rdir / "build-prompt.md").is_file():
        return ""
    result = rdir / "result.md"
    text = result.read_text(encoding="utf-8", errors="replace") if result.is_file() else ""
    if design_md_section(text, "Build") is None:
        return ("result.md has no ## Build section (a round without a legacy build-prompt.md carries its build "
                "contract there: what the mockup builder and the build slices read)")
    return ""


def design_tree_files(project: Path) -> list:
    """Every file of a canvas tree as a path under project/, sorted: ds/ (the design system the
    publish installs server-side, or a local preview's copy of it) and dot-entries left out."""
    if not project.is_dir():
        return []
    files = []
    for path in project.rglob("*"):
        parts = path.relative_to(project).parts
        if parts[0] == "ds" or any(part.startswith(".") for part in parts) or not path.is_file():
            continue
        files.append("/".join(parts))
    return sorted(files)


def design_reference_problems(text: str, rel: str) -> list:
    """A canvas file's src/href/url() references stay inside project/ (ds/<ns>/... included)."""
    base = posixpath.dirname(rel)
    problems = set()
    for first, second in DESIGN_REF_RE.findall(text):
        ref = (first or second).strip()
        low = ref.lower()
        if not ref or "{{" in ref or low.startswith(DESIGN_ALLOWED_REFS):  # {{hole}}: filled at render
            continue
        why = next((text for prefix, text in DESIGN_REF_WHY if low.startswith(prefix)), "")
        if not why:
            if ref.startswith(("/", "\\")):
                why = "an absolute path: only the canvas's /_blob/<id> uploads are absolute"
            elif DESIGN_SCHEME_RE.match(ref):
                why = "a scheme other than https: or data:"
            else:
                path = re.split(r"[?#]", ref, maxsplit=1)[0]
                resolved = posixpath.normpath(posixpath.join(base, path)) if path else "."
                if resolved != ".." and not resolved.startswith("../"):
                    continue
                why = "`..` climbs out of project/"
        problems.add(f"references {ref!r} ({why}): only a relative path inside project/ (ds/<ns>/… included), "
                     "an in-page `#` fragment, `data:`, an https URL or /_blob/<id> may be referenced")
    return sorted(problems)


def design_sc_for_bodies(text: str) -> list:
    """The bodies of the outermost <sc-for> loops of a board (nested loops stay inside their parent's)."""
    bodies, depth, start = [], 0, 0
    for match in DESIGN_SC_FOR_RE.finditer(text):
        if match.group(1):
            if depth:
                depth -= 1
                if not depth:
                    bodies.append(text[start:match.start()])
        else:
            if not depth:
                start = match.end()
            depth += 1
    if depth:
        bodies.append(text[start:])
    return bodies


def design_board_lint(text: str, rel: str) -> list:
    """The static lint of one board, as design-check warnings: leaves-canvas (an https href other than
    Google Fonts CSS: Play would leave the prototype) and same-target-list (a link with a literal
    .dc.html target inside a <sc-for>: every row opens the same board, which cannot know the row)."""
    found = []
    outside = sorted({ref for ref in (m.group(1).strip() for m in DESIGN_HREF_RE.finditer(text))
                      if ref.lower().startswith("https://") and "{{" not in ref and not ref.lower().startswith(DESIGN_FONT_CSS)})
    if outside:
        count = sum(1 for m in DESIGN_HREF_RE.finditer(text) if m.group(1).strip() in outside)
        found.append(f"{rel}: {count} link(s) leave the prototype (check=leaves-canvas): {', '.join(outside[:4])}"
                     + (f" (+{len(outside) - 4} more)" if len(outside) > 4 else "")
                     + " -- point each at a board or an in-canvas state, or leave it out")
    targets = sorted({m.group(1) for body in design_sc_for_bodies(text) for m in DESIGN_ROW_LINK_RE.finditer(body)})
    for target in targets:
        found.append(f"{rel}: every row of a <sc-for> list links to {target} (check=same-target-list) -- a linked board "
                     "cannot know which row was clicked; carry the item in a flow board's state")
    return found


# v88 (P47-p5.S4) the static style lints of a board (design-check warnings, never problems):
# check=token-drift -- a raw value where the design system (canvas/project/ds/**/*.css, the local copy) or
# canvas/project/frame.css names a token, by custom property: a hex colour when they name any colour, a
# font-family or a border-radius literal when they name any font family or radius, and a px length that
# equals the value of a length token of the property's role (a px literal is too common to flag on its own).
# v90 (P47-p5.F3) the role rule: a token's role is its name's family -- space/spacing/gap/gutter (padding*,
# margin*, gap, inset, top/right/bottom/left), fs/font/text (font-size), lh/leading/line-height (line-height),
# tracking/letter (letter-spacing); radius tokens serve border*-radius alone -- and a px is matched only to a
# token of its property's role or of an unknown family, so a cross-role suggestion cannot happen; no such
# token, no line. Allowed: 0, 1px on border* / outline*, %, currentColor, inherit, initial, unset,
# transparent, a board's own custom-property definitions, everything in [data-proto] chrome (a rule whose
# selector names [data-proto], a style="" on a tag carrying data-proto), and any declaration whose value holds
# var(...) anywhere (inside calc/min/max/clamp, in a shorthand, with its fallback): it is token-derived.
# And three of Vercel's web-interface guidelines as
# text matches: check=transition-all (transition: all), check=outline-none (outline: none or 0 with no
# :focus-visible rule in the board or frame.css), check=zoom-disabled (a viewport meta with user-scalable=no
# or maximum-scale=1).
DESIGN_CUSTOM_PROP_RE = re.compile(r"(--[\w-]+)\s*:\s*([^;{}]+)")
DESIGN_HEX_RE = re.compile(r"#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})(?![\w-])")
DESIGN_PX_RE = re.compile(r"(?<![\w.#-])(\d*\.?\d+)px\b")
DESIGN_STYLE_ATTR_RE = re.compile(r"""\bstyle\s*=\s*(?:"([^"]*)"|'([^']*)')""", re.I)
DESIGN_TAG_RE = re.compile(r"<[a-zA-Z][\w-]*\b[^>]*>")
DESIGN_STYLE_BLOCK_RE = re.compile(r"<style\b[^>]*>(.*?)</style>", re.S | re.I)
DESIGN_VIEWPORT_RE = re.compile(r"""<meta\b[^>]*\bname\s*=\s*["']viewport["'][^>]*>""", re.I)
DESIGN_DRIFT_OK = ("inherit", "initial", "unset", "transparent", "currentcolor", "none", "revert")


def design_hex(value: str) -> str:
    """A hex colour in its 6/8-digit lowercase form, so #FFF and #ffffff compare equal."""
    digits = value.lstrip("#").lower()
    return "#" + ("".join(c * 2 for c in digits) if len(digits) in (3, 4) else digits)


def design_tokens(project: Path) -> dict:
    """The tokens a board may use instead of a raw value: the custom properties of the system's local copy
    (canvas/project/ds/**/*.css) and of canvas/project/frame.css, by kind -- color {hex: [names]}, font
    (names), radius {value: [names]}, length {px value: [names]} -- plus whether frame.css styles
    :focus-visible."""
    tokens = {"color": {}, "font": [], "radius": {}, "length": {}, "focus": False}
    files = sorted((project / "ds").rglob("*.css")) if (project / "ds").is_dir() else []
    frame = project / "frame.css"
    if frame.is_file():
        files.append(frame)
    for path in files:
        text = re.sub(r"/\*.*?\*/", "", path.read_text(encoding="utf-8", errors="replace"), flags=re.S)
        if path == frame and ":focus-visible" in text:
            tokens["focus"] = True
        for name, value in DESIGN_CUSTOM_PROP_RE.findall(text):
            value, low = value.strip(), name.lower()
            for hexv in DESIGN_HEX_RE.findall(value):
                tokens["color"].setdefault(design_hex(hexv), []).append(name)
            if "radius" in low or "rounded" in low:
                tokens["radius"].setdefault(value, []).append(name)
            elif ("family" in low or "font" in low or "typeface" in low) and not re.search(
                    r"size|weight|leading|line|height|tracking|letter|spacing", low) and not re.match(r"^-?[\d.]", value):
                tokens["font"].append(name)
            elif re.fullmatch(r"-?\d*\.?\d+px", value):
                tokens["length"].setdefault(value, []).append(name)
    return tokens


def design_board_styles(text: str) -> list:
    """(selector or None, declarations text) of a board's styling outside [data-proto] chrome: each rule of
    its <style> blocks (comments stripped) and each style="" of a tag that carries no data-proto."""
    found = []
    for block in DESIGN_STYLE_BLOCK_RE.findall(text):
        for selector, body in DESIGN_CSS_RULE_RE.findall(re.sub(r"/\*.*?\*/", "", block, flags=re.S)):
            if "[data-proto" not in selector:
                found.append((selector.strip(), body))
    for tag in DESIGN_TAG_RE.findall(text):
        if re.search(r"\bdata-proto\b", tag, re.I) or tag.lower().startswith("<style"):
            continue
        for first, second in DESIGN_STYLE_ATTR_RE.findall(tag):
            found.append((None, first or second))
    return found


DESIGN_SPACING_PROP_RE = re.compile(r"(?:padding|margin|scroll-padding|scroll-margin|inset)(?:-[a-z]+)*|"
                                    r"(?:grid-)?(?:row-|column-)?gap|top|right|bottom|left")


def design_token_role(name: str):
    """v90 (P47-p5.F3) a length token's role, from its name's family: spacing, font-size, line-height,
    letter-spacing, or None (an unknown family, which serves any property)."""
    low = name.lower().lstrip("-")
    segs = set(re.split(r"[-_]+", low))
    if segs & {"lh", "leading"} or "line-height" in low or "lineheight" in low:
        return "line-height"
    if segs & {"tracking", "letter"}:
        return "letter-spacing"
    if segs & {"fs", "font", "text"} or "fontsize" in low:
        return "font-size"
    if segs & {"space", "spacing", "gap", "gutter"}:
        return "spacing"
    return None


def design_prop_role(prop: str) -> str:
    """v90 (P47-p5.F3) the role of a property a px length sits in (the font shorthand's size; its /line-height
    is matched as line-height by the caller); every other property is "other", served by unknown families only."""
    if prop in ("font-size", "font"):
        return "font-size"
    if prop in ("line-height", "letter-spacing"):
        return prop
    return "spacing" if DESIGN_SPACING_PROP_RE.fullmatch(prop) else "other"


def design_role_token(names: list, role: str):
    """The first token of names whose family is role, else the first of an unknown family, else None."""
    same = [n for n in names if design_token_role(n) == role]
    return (same or [n for n in names if design_token_role(n) is None] or [None])[0]


def design_css_terms(value: str) -> list:
    """The top-level whitespace-separated terms of a CSS value, a function call kept whole."""
    terms, depth, cur = [], 0, ""
    for ch in value:
        depth += (ch == "(") - (ch == ")")
        if ch.isspace() and depth == 0:
            if cur:
                terms.append(cur)
            cur = ""
        else:
            cur += ch
    return terms + ([cur] if cur else [])


def design_style_lint(text: str, rel: str, tokens: dict) -> list:
    """The style lints of one board (check=token-drift and the three Vercel checks), as warnings."""
    found, drift = [], []
    styles = design_board_styles(text)
    for _selector, body in styles:
        if "{{" in body:
            continue
        for decl in body.split(";"):
            prop, sep, value = decl.partition(":")
            prop, value = prop.strip().lower(), value.strip()
            if not sep or not prop or prop.startswith("--") or "var(" in value.lower():
                continue  # v90: a value holding var(...) anywhere is token-derived
            bare = re.sub(r"url\([^)]*\)", " ", value)
            if bare.strip().lower() in DESIGN_DRIFT_OK:
                continue
            if tokens["color"]:
                for hexv in DESIGN_HEX_RE.findall(bare):
                    named = tokens["color"].get(design_hex(hexv))
                    drift.append(f"{hexv} ({prop}{' = var(' + named[0] + ')' if named else ''})")
            if prop == "font-family":
                if tokens["font"] and bare.strip():
                    drift.append(f"{bare.strip()[:30]} (font-family)")
                continue
            if re.fullmatch(r"border(-[a-z]+)*-radius", prop):
                parts = [v for v in design_css_terms(bare) if v != "/" and v != "0" and "%" not in v
                         and v.lower() not in DESIGN_DRIFT_OK]
                if tokens["radius"] and parts:
                    named = tokens["radius"].get(" ".join(parts)) or (
                        tokens["radius"].get(parts[0]) if len(set(parts)) == 1 else None)
                    drift.append(f"{' '.join(parts)} ({prop}{' = var(' + named[0] + ')' if named else ''})")
                continue
            role = design_prop_role(prop)
            for match in DESIGN_PX_RE.finditer(bare):
                num = match.group(1)
                if float(num) == 0 or (float(num) == 1 and prop.startswith(("border", "outline"))):
                    continue
                at = "line-height" if prop == "font" and bare[:match.start()].rstrip().endswith("/") else role
                named = design_role_token(tokens["length"].get(f"{num}px", []), at)
                if named:
                    drift.append(f"{num}px ({prop} = var({named}))")
    if drift:
        unique = list(dict.fromkeys(drift))
        shown = ", ".join(unique[:4]) + (f" (+{len(unique) - 4} more)" if len(unique) > 4 else "")
        found.append(f"{rel}: {len(drift)} raw value(s) where the system or frame.css names a token (check=token-drift): "
                     f"{shown} -- use the token, var(--…); 0, 1px borders, %, currentColor, inherit, transparent, "
                     "var(...)-derived values and [data-proto] chrome are allowed")
    css = "\n".join(body for _s, body in styles)
    if re.search(r"\btransition(?:-property)?\s*:\s*all\b", css, re.I):
        found.append(f"{rel}: transition: all (check=transition-all) -- name the properties that animate")
    focus = tokens["focus"] or any(selector and ":focus-visible" in selector for selector, _b in styles)
    if re.search(r"\boutline\s*:\s*(?:none|0)(?![\w.])", css, re.I) and not focus:
        found.append(f"{rel}: outline: none with no :focus-visible rule (check=outline-none) -- keep a visible focus "
                     "ring: style :focus-visible")
    for meta in DESIGN_VIEWPORT_RE.findall(text):
        if re.search(r"user-scalable\s*=\s*(?:no|0)\b|maximum-scale\s*=\s*1(?:\.0*)?(?![\d.])", meta, re.I):
            found.append(f"{rel}: the viewport meta disables zoom (user-scalable=no or maximum-scale=1) "
                         "(check=zoom-disabled) -- let the page zoom")
    return found


def design_unlinked_page_lint(texts: dict, boards: dict, unrelated=(), pages=()) -> list:
    """P46-nb.S1: check=unlinked-page: on a canvas of 2+ Pages (boards with expand: "fill"), every Page
    the entry Page reaches by no chain of links or mounts. The entry Page is Main.dc.html when it is a Page,
    else the Page with the lowest title number. Edges: a board's literal href naming a board of the tree
    (#fragment and a leading ./ stripped, {{holes}} skipped; tried as written and against the board's folder)
    and every <dc-import name="X"> (the board whose stem is X). The walk runs over all boards.
    v88: a Page the round's join.json lists in `unrelated` (by board path, by stem, or by page slug: the
    Pages that slug owns) stays on the canvas, unlinked: no warning while unreached, a warning once reached."""
    keys = [k for k, b in boards.items() if isinstance(b, dict) and k.endswith(DESIGN_BOARD_SUFFIX)]
    pages_found = [k for k in keys if boards[k].get("expand") == "fill"]
    if len(pages_found) < 2:
        return []

    def number(key: str):
        title = boards[key].get("title")
        match = DESIGN_TITLE_RE.match(title) if isinstance(title, str) else None
        found = design_number(match.group(1)) if match else None
        return (found is None, found or 0, key)

    entry = DESIGN_ENTRY_BOARD if DESIGN_ENTRY_BOARD in pages_found else min(pages_found, key=number)
    known = set(keys)
    by_stem = {k.rsplit("/", 1)[-1][:-len(DESIGN_BOARD_SUFFIX)]: k for k in keys}

    def edges(key: str) -> set:
        text = texts.get(key, "")
        folder = key.rsplit("/", 1)[0] if "/" in key else ""
        out = set()
        for match in DESIGN_HREF_RE.finditer(text):
            ref = match.group(1).strip().split("#", 1)[0]
            if not ref or "{{" in ref:
                continue
            while ref.startswith("./"):
                ref = ref[2:]
            for cand in (ref, posixpath.normpath(f"{folder}/{ref}") if folder else None):
                if cand in known:
                    out.add(cand)
                    break
        out.update(by_stem[n.strip()] for n in DESIGN_DC_IMPORT_RE.findall(text) if n.strip() in by_stem)
        return out

    seen, todo = {entry}, [entry]
    while todo:
        for nxt in edges(todo.pop()) - seen:
            seen.add(nxt)
            todo.append(nxt)
    def listed(key: str) -> bool:
        stem = key.rsplit("/", 1)[-1][:-len(DESIGN_BOARD_SUFFIX)]
        return any(u in (key, stem) or (u in slugs and design_stem_owner(stem, slugs) == u) for u in unrelated)

    slugs = list(pages)
    found = []
    for page in sorted(pages_found, key=number):
        if page not in seen and not listed(page):
            found.append(f"{page}: Page not reachable from the entry Page {entry} by a link or a mount (check=unlinked-page) -- "
                         "link it from a board the entry reaches, or list it as unrelated in the round's join.json "
                         "(it stays on this canvas, unlinked)")
        elif page in seen and page != entry and listed(page):
            found.append(f"{page}: the round's join.json lists this Page as unrelated, but the entry Page {entry} reaches it "
                         "(check=unlinked-page) -- unlink it, or take it off join.json's unrelated list")
    return found


DESIGN_STATE_BAR_TAG_RE = re.compile(r"""<[a-zA-Z][\w-]*\b[^>]*?\bdata-proto\s*=\s*["']?state-bar\b[^>]*>""", re.I)
DESIGN_CSS_RULE_RE = re.compile(r"([^{}]+)\{([^{}]*)\}")
DESIGN_PINNED_RE = re.compile(r"\bposition\s*:\s*(fixed|sticky)\b", re.I)


def design_state_bar_lint(project: Path, texts: dict, boards: dict) -> list:
    """v61 (P37.S6) the static half of the state-bar lint (check=state-bar), from what the source shows:
    - the bar pinned: position fixed or sticky in the bar's own style="", or in a CSS rule (a board's
      <style>, or a .css file of the tree) whose last compound names the bar (state-bar, or a class the
      bar's tag carries);
    - several windows: an interactive board that <dc-import>s the same board two or more times (its
      windows), when that board carries a state bar and the importing board none of its own -- each
      window then shows its own bar, where one bar above all the windows, inside none, drives them all.
    design-preview checks the rendered rest: the bar's computed position, the bars on screen, the pages
    a bar lists, and a preset that moves to another page."""
    found, has_bar, classes = [], {}, set()
    for rel, text in texts.items():
        if not rel.endswith(DESIGN_BOARD_SUFFIX):
            continue
        tags = DESIGN_STATE_BAR_TAG_RE.findall(text)
        has_bar[rel.rsplit("/", 1)[-1][:-len(DESIGN_BOARD_SUFFIX)]] = bool(tags)
        for tag in tags:
            cls = re.search(r"""\bclass\s*=\s*["']([^"']*)["']""", tag)
            if cls:
                classes.update(c for c in cls.group(1).split() if "{" not in c and "}" not in c)
            style = re.search(r"""\bstyle\s*=\s*["']([^"']*)["']""", tag)
            pinned = DESIGN_PINNED_RE.search(style.group(1)) if style else None
            if pinned:
                found.append(f"{rel}: the state bar's own style is position: {pinned.group(1).lower()} (check=state-bar) -- it is "
                             "the first row of the page and scrolls away with it, never fixed or sticky")
    for rel, text in texts.items():
        css = text if rel.lower().endswith(".css") else "\n".join(re.findall(r"<style\b[^>]*>(.*?)</style>", text, re.S | re.I))
        for selector, body in DESIGN_CSS_RULE_RE.findall(re.sub(r"/\*.*?\*/", "", css, flags=re.S)):
            pinned = DESIGN_PINNED_RE.search(body)
            if not pinned:
                continue
            for part in (p.strip() for p in selector.split(",")):
                last = re.split(r"[\s>+~]+", part)[-1] if part else ""
                if "state-bar" in last or any(re.search(rf"\.{re.escape(c)}(?![\w-])", last) for c in classes):
                    found.append(f"{rel}: the rule '{part[:60]}' makes the state bar position: {pinned.group(1).lower()} "
                                 "(check=state-bar) -- it is the first row of the page and scrolls away with it, never fixed or sticky")
    for rel, text in texts.items():
        if not rel.endswith(DESIGN_BOARD_SUFFIX) or not (isinstance(boards.get(rel), dict) and boards[rel].get("is_interactive") is True):
            continue
        own = has_bar.get(rel.rsplit("/", 1)[-1][:-len(DESIGN_BOARD_SUFFIX)])
        names = [n.strip() for n in DESIGN_DC_IMPORT_RE.findall(text)]
        windows = [f"{name}{DESIGN_BOARD_SUFFIX} x{names.count(name)}" for name in sorted(set(names))
                   if names.count(name) >= 2 and has_bar.get(name)]
        if windows and not own:
            found.append(f"{rel}: shows {', '.join(windows)} as windows, each with the state bar its page carries, and has no "
                         "bar of its own (check=state-bar) -- a board that shows one page in several windows carries exactly "
                         "one bar, above all the windows and inside none, driving them together")
    return found


def design_canvas_problems(project: Path, system: dict, unrelated=(), pages=()) -> tuple:
    """(problems, warnings, board count, Page count, lint, mounted count) for one job's canvas tree,
    each path under project/. A Page is a board with expand: "fill". lint is the static board lint
    (design_board_lint, design_style_lint); mounted counts the boards another board <dc-import>s.
    unrelated / pages: the current round's join.json unrelated list and round.json pages (v88)."""
    files = design_tree_files(project)
    if "canvas.json" not in files:
        return ["canvas.json missing (the canvas index: v, boards, order, createdOnFiles)"], [], 0, 0, [], 0
    try:
        index = read_json(project / "canvas.json")
    except (ValueError, OSError) as exc:
        return [f"canvas.json is not valid JSON: {exc}"], [], 0, 0, [], 0
    if not isinstance(index, dict):
        return ["canvas.json is not a JSON object"], [], 0, 0, [], 0
    problems, warnings = [], []
    missing = [k for k in DESIGN_CANVAS_INDEX_KEYS if k not in index]
    if missing:
        problems.append(f"canvas.json: missing field(s) {', '.join(missing)} (the type requires {', '.join(DESIGN_CANVAS_INDEX_KEYS)})")
    boards, order = index.get("boards", {}), index.get("order", [])
    if not isinstance(boards, dict):
        problems.append("canvas.json: boards must be an object keyed by each artboard's path under project/")
        boards = {}
    if not (isinstance(order, list) and all(isinstance(o, str) for o in order)):
        problems.append("canvas.json: order must be a list of board paths (z-order, back to front)")
        order = []
    present = [f for f in files if f.endswith(DESIGN_BOARD_SUFFIX)]
    stems: dict = {}
    for rel in files:
        if not design_path_ok(rel):
            problems.append(f"{rel}: a path segment breaks the type's rule (start with a letter, digit or _, then only those and . -; no spaces)")
    for rel in present:
        stem = rel.rsplit("/", 1)[-1][:-len(DESIGN_BOARD_SUFFIX)]
        if stem in stems:
            problems.append(f"{rel}: stem {stem!r} is also {stems[stem]}'s (stems are unique)")
        else:
            stems[stem] = rel
        if rel not in boards:
            problems.append(f"{rel}: not listed in canvas.json boards (every .dc.html outside ds/ is a board)")
        if rel not in order:
            problems.append(f"{rel}: not listed in canvas.json order")
    for key in boards:
        if not key.endswith(DESIGN_BOARD_SUFFIX):
            problems.append(f"canvas.json: board {key!r} does not end {DESIGN_BOARD_SUFFIX}")
        elif key.split("/", 1)[0] == "ds":
            problems.append(f"canvas.json: board {key!r} is under ds/, which only the system install writes")
        elif key not in present:
            problems.append(f"canvas.json: board {key!r} is listed but its file is missing")
    for key in sorted(set(order) - set(boards)):
        problems.append(f"canvas.json: order lists {key!r}, which is not a board")
    if len(set(order)) != len(order):
        problems.append("canvas.json: order lists a board twice")
    if DESIGN_ENTRY_BOARD not in present:
        problems.append(f"{DESIGN_ENTRY_BOARD} missing (the canvas's entry artboard)")
    # Reading order: the titles' NN form 01..N as a set (the layout is free; the numbers are not).
    numbers: dict = {}
    for key, board in boards.items():
        title = board.get("title") if isinstance(board, dict) else None
        match = DESIGN_TITLE_RE.match(title) if isinstance(title, str) else None
        number = design_number(match.group(1)) if match else None
        if not isinstance(board, dict):
            problems.append(f"canvas.json: board {key!r} is not an object (x, y, w, h, title, …)")
        elif number is None:
            problems.append(f"canvas.json: board {key!r} title {title!r} does not start with its reading number \"NN · \" (01 · …)")
        elif number in numbers:
            problems.append(f"canvas.json: board {key!r} repeats reading number {number:02d} (also {numbers[number]!r})")
        else:
            numbers[number] = key
    problems.extend(f"gap in the board titles' reading numbers: no board titled \"{n:02d} · …\""
                    for n in range(1, max(numbers, default=0) + 1) if n not in numbers)
    lint, mounts, texts = [], set(), {}
    tokens = design_tokens(project)
    for rel in files:
        if not rel.lower().endswith((".html", ".htm", ".css")):
            continue
        text = texts[rel] = (project / rel).read_bytes().decode("utf-8", errors="replace")
        if rel.endswith(DESIGN_BOARD_SUFFIX) and not any(line.strip() == DESIGN_SUPPORT_LINE for line in text.splitlines()):
            problems.append(f"{rel}: missing the exact line {DESIGN_SUPPORT_LINE} (the type's runtime)")
        problems.extend(f"{rel}: {p}" for p in design_reference_problems(text, rel))
        if rel.endswith(DESIGN_BOARD_SUFFIX):
            lint.extend(design_board_lint(text, rel))
            lint.extend(design_style_lint(text, rel, tokens))
            stem = rel.rsplit("/", 1)[-1][:-len(DESIGN_BOARD_SUFFIX)]
            mounts.update(name.strip() for name in DESIGN_DC_IMPORT_RE.findall(text) if name.strip() != stem)
    lint.extend(design_state_bar_lint(project, texts, boards))
    lint.extend(design_unlinked_page_lint(texts, boards, unrelated, pages))
    records = index.get("designSystems", [])
    if not isinstance(records, list):
        problems.append("canvas.json: designSystems must be a list of install records")
    elif system.get("version"):
        for rec in records:
            pinned = rec.get("version") if isinstance(rec, dict) else None
            if pinned != system["version"]:
                name = rec.get("namespace") if isinstance(rec, dict) else rec
                warnings.append(f"canvas.json: designSystems {name!r} pins version {pinned!r}, but design.json's system is "
                                f"{system['version']!r} (reinstall when the round changes the look)")
    pages = sum(1 for board in boards.values() if isinstance(board, dict) and board.get("expand") == "fill")
    mounted = sum(1 for key in boards if key.rsplit("/", 1)[-1][:-len(DESIGN_BOARD_SUFFIX)] in mounts)
    return problems, warnings, len(boards), pages, lint, mounted


def design_read_job(entry: Path, number: int, system: dict) -> dict:
    """One job folder: job.json, its rounds and its canvas tree, each with its own problems."""
    rel = f"jobs/{entry.name}"
    job = {"id": entry.name, "number": number, "path": entry, "data": None, "rounds": [],
           "problems": [], "warnings": [], "lint": [], "boards": 0, "pages": 0, "drafted": False}
    problems = job["problems"]
    jpath = entry / "job.json"
    if not jpath.is_file():
        problems.append(f"{rel}: job.json missing")
    else:
        try:
            data = read_json(jpath)
        except (ValueError, OSError) as exc:
            problems.append(f"{rel}: job.json is not valid JSON: {exc}")
        else:
            found = design_job_problems(entry.name, data)
            problems.extend(f"{rel}: {p}" for p in found)
            if not found:
                job["data"] = data
    rnumbers: dict = {}
    rounds_dir = entry / "rounds"
    for rentry in sorted(rounds_dir.iterdir()) if rounds_dir.is_dir() else []:
        if rentry.name.startswith("."):
            continue
        rrel = f"{rel}/rounds/{rentry.name}"
        match = DESIGN_NN_RE.match(rentry.name)
        rnumber = design_number(match.group(1)) if match else None
        if not rentry.is_dir() or rnumber is None:
            problems.append(f"{rrel}: not a round folder (a job's rounds/ holds NN-slug/ folders only)")
            continue
        if rnumber in rnumbers:
            problems.append(f"{rrel}: duplicate round number {rnumber:02d} (also {rnumbers[rnumber]})")
            continue
        rnumbers[rnumber] = rrel
        rnd = {"number": rnumber, "id": rentry.name, "path": rentry, "data": None}
        rpath = rentry / "round.json"
        if not rpath.is_file():
            problems.append(f"{rrel}: round.json missing")
        else:
            try:
                rdata = read_json(rpath)
            except (ValueError, OSError) as exc:
                problems.append(f"{rrel}: round.json is not valid JSON: {exc}")
            else:
                found = design_round_problems(rentry.name, rdata, rentry)
                problems.extend(f"{rrel}: {p}" for p in found)
                if not any(p.startswith("round.json:") for p in found):
                    rnd["data"] = rdata
                    if job["data"] and rdata["slice"] != job["data"]["slice"]:
                        problems.append(f"{rrel}: round.json slice {rdata['slice']!r} is not its job's ({job['data']['slice']})")
        job["rounds"].append(rnd)
    problems.extend(f"{rel}: gap in the round numbering: no round numbered {n:02d}"
                    for n in range(1, max(rnumbers, default=0) + 1) if n not in rnumbers)
    known = {r["id"]: r["number"] for r in job["rounds"]}
    for rnd in job["rounds"]:
        for sid in (rnd["data"] or {}).get("supersedes", []):
            if known.get(sid, rnd["number"]) >= rnd["number"]:
                problems.append(f"{rel}/rounds/{rnd['id']}: supersedes {sid!r}, which is not an earlier round of this job")
    opened = [r["id"] for r in job["rounds"] if r["data"] and r["data"]["status"] == "open"]
    if len(opened) > 1:  # a legacy multi-job slice may hold several open jobs, but one job has one open round
        problems.append(f"{rel}: more than one open round: {', '.join(opened)} (at most one round is open per job)")
    if job["data"] and job["data"]["status"] != "open" and opened:
        problems.append(f"{rel}: job.json status is {job['data']['status']} but a round is open (an open round belongs to an open job)")
    # v88: the round the canvas belongs to (the open one, else the last), its page list and its join.json.
    live = [r for r in job["rounds"] if r["data"]]
    current = next((r for r in live if r["data"]["status"] == "open"), None)
    job["current"] = current = current or max(live, key=lambda r: r["number"], default=None)
    pages = list((current["data"].get("pages") or []) if current else [])
    job["stage"] = design_round_stage(current) if current and current["data"]["status"] == "open" else None
    join, joined = None, bool(current and (current["path"] / DESIGN_JOIN_FILE).is_file())
    if joined:
        join, why = design_read_join(current["path"] / DESIGN_JOIN_FILE)
        if why:
            problems.append(f"{rel}/rounds/{current['id']}/{DESIGN_JOIN_FILE}: {why}")
    unrelated = [u for u in (join or {}).get("unrelated", []) if isinstance(u, str)]
    project = entry / "canvas" / "project"
    # Mid-round, before the join, the page drafters' files stand without a canvas.json: nothing to index yet.
    unjoined = bool(pages) and not joined and current["data"]["status"] == "open" and not (project / "canvas.json").exists()
    if project.is_dir() and unjoined:
        job["drafted"] = True
    elif project.is_dir():
        job["drafted"] = True
        found, warned, job["boards"], job["pages"], lint, mounted = design_canvas_problems(project, system, unrelated, pages)
        problems.extend(f"{rel}/canvas/project/{p}" if not p.startswith("gap ") else f"{rel}: {p}" for p in found)
        job["warnings"].extend(f"{rel}/canvas/project/{w}" for w in warned)
        job["lint"] = [f"{rel}/canvas/project/{w}" for w in lint]
        counted = job["boards"] - mounted  # a board another board mounts is reviewed through it (the frame's count)
        if (job["data"] or {}).get("status") == "open" and (job["pages"] > DESIGN_JOB_PAGES_MAX or counted > DESIGN_JOB_BOARDS_MAX):
            more = f" (+{mounted} mounted by another board, not counted)" if mounted else ""
            job["warnings"].append(f"job {entry.name} has {job['pages']} Pages / {counted} boards{more} — past one review of a "
                                   "connected group; split into rounds or slices along the least-connected seam")
    if project.is_dir():  # check=pending-link: a warning before the join, a problem once join.json exists
        for line in design_pending_links(project):
            if joined and current["data"]["status"] == "open":
                problems.append(f"{rel}/canvas/project/{line} -- the join rewires each to a real link; "
                                "design-close --words refuses while one is left")
            else:
                job["lint"].append(f"{rel}/canvas/project/{line} -- the join rewires each to a real link")
    elif job["data"] and job["data"]["status"] != "open":
        problems.append(f"{rel}: a {job['data']['status']} job has no canvas tree (canvas/project/)")
    design_record_lint(job, entry, rel)
    return job


def design_read_join(path: Path) -> tuple:
    """(join.json data, "") or (None, why): an object whose related / unrelated, when present, are lists of
    strings (page slugs, board stems or board paths); its other keys (the settled choices) are free."""
    try:
        data = read_json(path)
    except (ValueError, OSError) as exc:
        return None, f"not valid JSON: {exc}"
    if not isinstance(data, dict):
        return None, "not a JSON object (related, unrelated, the settled choices)"
    for key in ("related", "unrelated"):
        if key in data and not (isinstance(data[key], list) and all(isinstance(v, str) for v in data[key])):
            return None, f"{key} must be a list of page slugs, board stems or board paths"
    return data, ""


def design_pending_links(project: Path, only=None) -> list:
    """check=pending-link lines: per board, the #to:<slug> placeholder links a page drafter left for the join
    (`only`: the board paths to read, else every board of the tree)."""
    found = []
    for rel in only if only is not None else [f for f in design_tree_files(project) if f.endswith(DESIGN_BOARD_SUFFIX)]:
        path = project / rel
        targets = DESIGN_TO_RE.findall(path.read_text(encoding="utf-8", errors="replace")) if path.is_file() else []
        if targets:
            found.append(f"{rel}: {len(targets)} #to: placeholder link(s) left ({', '.join(sorted(set(targets)))}) "
                         "(check=pending-link)")
    return found


def design_abs_path_finding(path: Path, label: str) -> str:
    """One line naming the absolute or home paths in a record text file, or "" when it has none. Says
    where (line numbers) and which prefix, never the path itself."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    hits = [(text.count("\n", 0, m.start()) + 1, m.group(0)) for m in DESIGN_ABS_PATH_RE.finditer(text)]
    if not hits:
        return ""
    shown = ", ".join(f"line {n} {token}" for n, token in hits[:3]) + (f" (+{len(hits) - 3} more)" if len(hits) > 3 else "")
    return (f"{label}: an absolute path (check=abs-path): {shown} -- the record carries repo-relative paths only "
            "(scratch output stays out of it)")


def design_text_files(folder: Path, skip: tuple = ()) -> list:
    """The text files under a record folder, sorted: dot-entries and the top-level `skip` folders left out."""
    found = []
    for path in sorted(folder.rglob("*")) if folder.is_dir() else []:
        parts = path.relative_to(folder).parts
        if parts[0] in skip or any(part.startswith(".") for part in parts) or not path.is_file():
            continue
        if path.suffix.lower() in DESIGN_TEXT_SUFFIXES:
            found.append(path)
    return found


def design_record_lint(job: dict, entry: Path, rel: str) -> None:
    """v61 record checks of one job: absolute paths (a problem while open, lint once closed), the slice's
    brief a round's handoff names, and the size of an open round's ## Summary."""
    root = entry.parent.parent
    opened = [r for r in job["rounds"] if r["data"] and r["data"]["status"] == "open"]
    targets = [(entry / "job.json", f"{rel}/job.json", bool(opened))]
    project = entry / "canvas" / "project"
    targets += [(project / f, f"{rel}/canvas/project/{f}", bool(opened))
                for f in design_tree_files(project) if f.lower().endswith(DESIGN_TEXT_SUFFIXES)]
    for rnd in job["rounds"]:
        is_open = rnd in opened
        rrel = f"{rel}/rounds/{rnd['id']}"
        targets += [(path, f"{rrel}/{path.relative_to(rnd['path']).as_posix()}", is_open)
                    for path in design_text_files(rnd["path"], skip=("canvas",))]
        handoff = rnd["path"] / "handoff.md"
        text = handoff.read_text(encoding="utf-8", errors="replace") if handoff.is_file() else ""
        for brief in DESIGN_BRIEF_RE.findall(text):
            if not (brief.startswith(f"{DESIGN_WAVES_DIR}/") and (root / brief).is_file()):
                (job["problems"] if is_open else job["lint"]).append(
                    f"{rrel}/handoff.md: names brief {brief}, which is missing (a slice's brief lives at "
                    f"{DESIGN_WAVES_DIR}/<slice>/brief.md under the design root)")
        result = rnd["path"] / "result.md"
        summary = design_md_section(result.read_text(encoding="utf-8", errors="replace"), "Summary") if is_open and result.is_file() else None
        if summary is not None and len(summary.encode("utf-8")) > DESIGN_SUMMARY_MAX:
            job["warnings"].append(f"{rrel}/result.md: ## Summary is {len(summary.encode('utf-8'))} bytes, over "
                                   f"{DESIGN_SUMMARY_MAX} (the orchestrator reads only it; the detail goes under ## Build)")
    for path, label, is_open in targets:
        finding = design_abs_path_finding(path, label)
        if finding:
            (job["problems"] if is_open else job["lint"]).append(finding)


def design_waves_check(root: Path, scan: dict) -> None:
    """waves/ holds one <slice id>/ folder per co-work slice (its brief.md); absolute paths in its files are a
    problem while the slice has an open round, else a warning."""
    waves = root / DESIGN_WAVES_DIR
    if not waves.is_dir():
        return
    live = {j["data"]["slice"] for j, _ in design_open_rounds(scan) if j["data"]}
    for entry in sorted(waves.iterdir()):
        if entry.name.startswith("."):
            continue
        if not (entry.is_dir() and DESIGN_SLICE_RE.match(entry.name)):
            scan["problems"].append(f"{DESIGN_WAVES_DIR}/{entry.name}: not a slice brief folder ({DESIGN_WAVES_DIR}/ holds "
                                    "one <slice id>/ folder per co-work slice, e.g. P9.S4/, with its brief.md)")
            continue
        for path in design_text_files(entry):
            finding = design_abs_path_finding(path, f"{DESIGN_WAVES_DIR}/{entry.name}/{path.relative_to(entry).as_posix()}")
            if finding:
                (scan["problems"] if entry.name in live else scan["warnings"]).append(finding)


def design_scan(root: Path, only: str = None) -> dict:
    """Read the whole design root once: the manifest, the jobs with their rounds and canvas trees, and
    every problem and warning -- or, with `only` (a job id), the manifest's and that job's alone."""
    problems: list = []
    warnings: list = []
    scan = {"manifest": None, "schema1": False, "jobs": [], "problems": problems, "warnings": warnings}
    if not root.is_dir():
        problems.append(f"no design root at {DESIGN_ROOT_SHOWN}/ (run: {WORKFLOW_CMD} design-init)")
        return scan
    mpath = root / "design.json"
    hint = design_legacy_hint(root)  # said once, on the first legacy-related problem
    if not mpath.exists():
        problems.append(f"design.json missing; {hint}" if hint else f"design.json missing (run: {WORKFLOW_CMD} design-init)")
        hint = ""
    else:
        try:
            manifest = read_json(mpath)
        except (ValueError, OSError) as exc:
            problems.append(f"design.json is not valid JSON: {exc}")
        else:
            if design_is_schema(manifest, 1):  # recognised only to steer it to the migration
                scan["schema1"] = True
                problems.append(f"design.json is schema 1; {design_schema1_hint()}")
                return scan
            found = design_manifest_problems(manifest)
            problems.extend(found)
            if not found:
                scan["manifest"] = manifest
    system = (scan["manifest"] or {}).get("system") or {}
    jobs_dir = root / "jobs"
    jnumbers: dict = {}
    loose: list = []
    for entry in sorted(jobs_dir.iterdir()) if jobs_dir.is_dir() else []:
        if entry.name.startswith("."):
            continue
        match = DESIGN_NN_RE.match(entry.name)
        number = design_number(match.group(1)) if match else None
        if not entry.is_dir() or number is None:
            loose.append(f"jobs/{entry.name}: not a job folder (jobs/ holds NN-slug/ folders only)")
            continue
        if number in jnumbers:
            loose.append(f"jobs/{entry.name}: duplicate job number {number:02d} (also {jnumbers[number]})")
            continue
        jnumbers[number] = f"jobs/{entry.name}"
        scan["jobs"].append(design_read_job(entry, number, system))
    # The board lint is said for an open job, or for any job named by id: a signed canvas is history, and
    # the all-jobs check would repeat its lines forever.
    if only is not None:
        job = next((j for j in scan["jobs"] if j["id"] == only), None)
        if job is None:
            problems.append(f"no job {only!r} under {DESIGN_ROOT_SHOWN}/jobs/")
        else:
            problems.extend(job["problems"])
            warnings.extend(job["warnings"] + job["lint"])
        return scan
    problems.extend(loose)
    for job in scan["jobs"]:
        problems.extend(job["problems"])
        warnings.extend(job["warnings"] + (job["lint"] if (job["data"] or {}).get("status") == "open" else []))
    problems.extend(f"gap in the job numbering: no job numbered {n:02d}"
                    for n in range(1, max(jnumbers, default=0) + 1) if n not in jnumbers)
    design_waves_check(root, scan)
    # A co-work slice holds one job (a legacy wave may hold several), each with at most one open round (design_read_job).
    # Parts that are not schema 2: a pre-v47 record, and a schema-1 record left outside schema1/.
    if hint:
        problems.append(f"pre-v47 parts at the root; {hint}")
    leftovers = [name for name in ("cards", "tokens.css") if os.path.lexists(root / name)]
    rounds_dir = root / "rounds"
    if rounds_dir.is_dir() and any((e / "round.json").exists() for e in rounds_dir.iterdir()):
        leftovers.append("rounds")
    problems.extend(f"{name}: a schema-1 part outside {DESIGN_SCHEMA1_DIR}/ (schema {DESIGN_SCHEMA} keeps no card library, "
                    f"root tokens or root rounds; move it into {DESIGN_SCHEMA1_DIR}/ by hand)" for name in leftovers)
    for page in sorted(root.rglob("*.htm*")):
        parts = page.relative_to(root).parts
        if parts[0] in (DESIGN_LEGACY_DIR, DESIGN_SCHEMA1_DIR):  # legacy records, whatever they hold
            continue
        if any(part.startswith(".") for part in parts) or page.suffix.lower() not in (".html", ".htm"):
            continue
        if parts[0] == "jobs" and len(parts) >= 5 and parts[2:4] == ("canvas", "project"):
            continue
        if parts[0] == "jobs" and len(parts) >= 7 and parts[2] == "rounds" and parts[4:6] == ("canvas", "project"):
            continue
        problems.append(f"{'/'.join(parts)}: HTML outside a job's canvas tree -- a stray page (artboards live in jobs/<job>/canvas/project/)")
    return scan


def design_open_rounds(scan: dict) -> list:
    return [(job, rnd) for job in scan["jobs"] for rnd in job["rounds"] if rnd["data"] and rnd["data"]["status"] == "open"]


def design_address(job: dict, rnd: dict) -> str:
    """A round's unambiguous address: <job>/<round> (rounds number inside their job)."""
    return f"{job['id']}/{rnd['id']}"


def design_stage_lines(jobs: list) -> list:
    """One `stage=` line per open per-page round of these jobs (v88), derived from disk."""
    return [f"design-check: {design_address(j, j['current'])} stage={j['stage']}" for j in jobs if j.get("stage")]


def design_page_boards(path: Path) -> tuple:
    """(boards {path: entry}, problems) of a page's boards.json: its boards' canvas.json entries, keyed by
    board path, without x, y, the "NN · " title number or order (the join places and numbers them). A
    {"boards": {...}} wrapper reads the same."""
    if not path.is_file():
        return {}, [f"{DESIGN_PAGE_BOARDS} missing (the page's boards: their canvas.json entries without x, y, NN or order)"]
    try:
        data = read_json(path)
    except (ValueError, OSError) as exc:
        return {}, [f"{DESIGN_PAGE_BOARDS} is not valid JSON: {exc}"]
    problems = []
    if isinstance(data, dict) and isinstance(data.get("boards"), dict):
        problems += [f"{DESIGN_PAGE_BOARDS}: key {k!r} -- order belongs to the join's canvas.json" for k in data if k == "order"]
        data = data["boards"]
    if not isinstance(data, dict) or not data:
        return {}, problems + [f"{DESIGN_PAGE_BOARDS} is not a non-empty object keyed by board path"]
    for key, entry in data.items():
        if not key.endswith(DESIGN_BOARD_SUFFIX):
            problems.append(f"{DESIGN_PAGE_BOARDS}: board {key!r} does not end {DESIGN_BOARD_SUFFIX}")
            continue
        if not isinstance(entry, dict):
            problems.append(f"{DESIGN_PAGE_BOARDS}: board {key!r} is not an object (w, h, title, …)")
            continue
        placed = [k for k in ("x", "y", "order") if k in entry]
        if placed:
            problems.append(f"{DESIGN_PAGE_BOARDS}: board {key!r} has {', '.join(placed)} (the join places boards)")
        title = entry.get("title")
        if not (isinstance(title, str) and title.strip()):
            problems.append(f"{DESIGN_PAGE_BOARDS}: board {key!r} needs a title")
        elif DESIGN_TITLE_RE.match(title):
            problems.append(f"{DESIGN_PAGE_BOARDS}: board {key!r} title {title!r} carries a reading number (the join numbers titles 01..N)")
        for dim in ("w", "h"):
            if not (isinstance(entry.get(dim), (int, float)) and not isinstance(entry.get(dim), bool) and entry[dim] > 0):
                problems.append(f"{DESIGN_PAGE_BOARDS}: board {key!r} needs a positive {dim}")
    return data, problems


def design_check_page(scan: dict, args: argparse.Namespace) -> int:
    """design-check <job> --page <slug> (v88): one page of the job's open per-page round, without canvas.json --
    its boards.json, the files its stem owns, their support line and references, #to: only to a page of the
    round, the abs-path rule, and the board and style lints as warnings. --page frame checks the frame pass's
    boards (pages/frame/boards.json, stems no page owns) and frame.css."""
    job = next((j for j in scan["jobs"] if j["id"] == args.job), None)
    rnd = (job or {}).get("current")
    if job is None or rnd is None or rnd["data"]["status"] != "open" or not rnd["data"].get("pages"):
        raise SystemExit(f"design-check: --page needs job {args.job}'s open round to be a per-page round "
                         f"(design-open --pages a,b,c)")
    pages, slug = rnd["data"]["pages"], args.page
    if slug != DESIGN_FRAME_PAGE and slug not in pages:
        raise SystemExit(f"design-check: --page {slug!r} is not a page of {design_address(job, rnd)} "
                         f"(pages: {', '.join(pages)}; or {DESIGN_FRAME_PAGE})")
    rel = f"jobs/{job['id']}"
    canvas_rel = f"{rel}/canvas/project/"
    # The record's own problems stay; another page's canvas files are not this page's to answer.
    problems = [p for p in scan["problems"] if not p.startswith(canvas_rel) and not p.startswith(f"{rel}: gap in the board")]
    warnings = [w for w in scan["warnings"] if not w.startswith(canvas_rel)]
    pdir = rnd["path"] / DESIGN_PAGES_DIR / slug
    prel = f"{rel}/rounds/{rnd['id']}/{DESIGN_PAGES_DIR}/{slug}"
    boards, found = design_page_boards(pdir / DESIGN_PAGE_BOARDS)
    problems += [f"{prel}/{p}" for p in found]
    project = job["path"] / "canvas" / "project"
    stem_of = lambda key: key.rsplit("/", 1)[-1][:-len(DESIGN_BOARD_SUFFIX)]
    files = design_tree_files(project)
    for key in boards:
        owner = design_stem_owner(stem_of(key), pages) if key.endswith(DESIGN_BOARD_SUFFIX) else None
        if slug == DESIGN_FRAME_PAGE and owner:
            problems.append(f"{prel}/{DESIGN_PAGE_BOARDS}: board {key!r} has page {owner}'s stem prefix "
                            f"{design_page_stem(owner)} (the frame's boards are shared: a stem no page owns)")
        elif slug != DESIGN_FRAME_PAGE and owner != slug:
            problems.append(f"{prel}/{DESIGN_PAGE_BOARDS}: board {key!r} is outside page {slug}'s files (a page writes only "
                            f"files whose stem starts {design_page_stem(slug)}" + (f"; this stem is page {owner}'s)" if owner else ")"))
        if key.endswith(DESIGN_BOARD_SUFFIX) and key not in files:
            problems.append(f"{canvas_rel}{key}: listed in {prel}/{DESIGN_PAGE_BOARDS} but the file is missing")
    if slug == DESIGN_FRAME_PAGE:
        mine = sorted(k for k in boards if k in files) + (["frame.css"] if "frame.css" in files else [])
    else:
        mine = [f for f in files if f.lower().endswith((".html", ".htm", ".css"))
                and design_stem_owner(f.rsplit("/", 1)[-1].split(".", 1)[0], pages) == slug]
        problems += [f"{canvas_rel}{f}: page {slug}'s file, not listed in {prel}/{DESIGN_PAGE_BOARDS} (every .dc.html is a board)"
                     for f in mine if f.endswith(DESIGN_BOARD_SUFFIX) and f not in boards]
    tokens = design_tokens(project)
    for f in mine:
        text = (project / f).read_bytes().decode("utf-8", errors="replace")
        if f.endswith(DESIGN_BOARD_SUFFIX) and not any(line.strip() == DESIGN_SUPPORT_LINE for line in text.splitlines()):
            problems.append(f"{canvas_rel}{f}: missing the exact line {DESIGN_SUPPORT_LINE} (the type's runtime)")
        problems += [f"{canvas_rel}{f}: {p}" for p in design_reference_problems(text, f)]
        for target in sorted(set(DESIGN_TO_RE.findall(text))):
            if target not in pages:
                problems.append(f"{canvas_rel}{f}: links #to:{target}, which is not a page of {design_address(job, rnd)} "
                                f"(pages: {', '.join(pages)}): a #to: placeholder names the page the join wires it to")
        if f.endswith(DESIGN_BOARD_SUFFIX):
            warnings += [f"{canvas_rel}{w}" for w in design_board_lint(text, f) + design_style_lint(text, f, tokens)]
        finding = design_abs_path_finding(project / f, f"{canvas_rel}{f}")
        if finding:
            problems.append(finding)
    for line in design_stage_lines([job]):
        print(line)
    for warning in warnings:
        print(f"design-check: warning: {warning}")
    if problems:
        print(f"design-check: {len(problems)} problem(s) in {DESIGN_ROOT_SHOWN}/{rel}/ page {slug}")
        for problem in problems:
            print(f"- {problem}")
        return 1
    print(f"design-check: OK -- page {slug} of {design_address(job, rnd)}: {len(boards)} board(s), {len(mine)} file(s)"
          + (f", {len(warnings)} warning(s)" if warnings else ""))
    return 0


def design_check(args: argparse.Namespace) -> int:
    if getattr(args, "page", None) is not None and args.job is None:
        raise SystemExit("design-check: --page needs a job id (design-check <job> --page <slug>)")
    scan = design_scan(design_root(), args.job)
    if getattr(args, "page", None) is not None:
        return design_check_page(scan, args)
    problems, warnings = scan["problems"], scan["warnings"]
    where = f"{DESIGN_ROOT_SHOWN}/" + (f"jobs/{args.job}/" if args.job else "")
    for line in design_stage_lines([j for j in scan["jobs"] if args.job is None or j["id"] == args.job]):
        print(line)
    for warning in warnings:
        print(f"design-check: warning: {warning}")
    if problems:
        print(f"design-check: {len(problems)} problem(s) in {where}")
        for problem in problems:
            print(f"- {problem}")
        return 1
    jobs = [j for j in scan["jobs"] if args.job is None or j["id"] == args.job]
    opened = [design_address(j, r) for j, r in design_open_rounds(scan) if j in jobs]
    print(f"design-check: OK -- {len(jobs)} job(s), {sum(len(j['rounds']) for j in jobs)} round(s), "
          f"{sum(j['boards'] for j in jobs)} board(s), open rounds: {', '.join(opened) if opened else 'none'}"
          + (f", {len(warnings)} warning(s)" if warnings else ""))
    return 0


def design_write_bytes(path: Path, data: bytes) -> None:
    """Atomic like write_text, and keeps the file's permission bits (mkstemp would leave 0600)."""
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else None
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".tmp_", suffix=path.name)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        if mode is not None:
            os.chmod(tmp, mode)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def design_require(scan: dict, what: str) -> None:
    if scan["problems"]:
        lines = "\n".join(f"- {p}" for p in scan["problems"])
        raise SystemExit(f"{what}: refused -- design-check finds {len(scan['problems'])} problem(s):\n{lines}")


def design_require_manifest(scan: dict, root: Path, what: str) -> None:
    """Schema 2 is the only writable schema: a schema-1 root is steered to design-migrate --to 2, a
    root with no valid manifest to design-migrate (pre-v47) or design-init."""
    if scan["schema1"]:
        raise SystemExit(f"{what}: refused -- {DESIGN_ROOT_SHOWN}/design.json is schema 1; {design_schema1_hint()}")
    if scan["manifest"] is None:
        hint = design_legacy_hint(root)
        raise SystemExit(f"{what}: refused -- no valid {DESIGN_ROOT_SHOWN}/design.json; {hint}" if hint else
                         f"{what}: refused -- no valid {DESIGN_ROOT_SHOWN}/design.json (run: {WORKFLOW_CMD} design-init)")


def design_find_job(scan: dict, jid: str, what: str) -> dict:
    job = next((j for j in scan["jobs"] if j["id"] == jid), None)
    if job is None:
        raise SystemExit(f"{what}: no job {jid!r} under {DESIGN_ROOT_SHOWN}/jobs/")
    if job["data"] is None:
        raise SystemExit(f"{what}: refused -- jobs/{jid}/job.json is not well-formed (run design-check {jid})")
    return job


def design_init(args: argparse.Namespace) -> None:
    root = design_root()
    mpath = root / "design.json"
    rel = f"{DESIGN_ROOT_SHOWN}/design.json"
    if not mpath.exists() and design_legacy_hint(root):  # a refusal only: nothing moves, nothing is written
        raise SystemExit(f"design-init: refused -- {design_legacy_hint(root)}")
    if mpath.exists():
        try:
            current = read_json(mpath)
        except (ValueError, OSError) as exc:
            raise SystemExit(f"design-init: {rel} is not valid JSON ({exc}); fix it by hand")
        if design_is_schema(current, 1):
            raise SystemExit(f"design-init: refused -- {rel} is schema 1; {design_schema1_hint()}")
        wanted = dict(current)
    else:
        current = None
        repo = HOST_ROOT or ROOT  # nested: the project is the host, not the `workflow` folder
        default_id = re.sub(r"[^a-z0-9]+", "-", repo.name.lower()).strip("-")[:63].strip("-") or "design"
        wanted = {"schema": DESIGN_SCHEMA, "id": default_id, "name": repo.name, "system": design_null_system()}
    if args.id:
        wanted["id"] = args.id
    if args.name:
        wanted["name"] = args.name
    problems = design_manifest_problems(wanted)
    if problems:
        raise SystemExit("design-init: refused -- " + "; ".join(problems))
    if wanted == current:
        print(f"design-init: {rel} unchanged (id={wanted['id']})")
        return
    write_json(mpath, wanted)
    print(f"design-init: {'updated' if current is not None else 'wrote'} {rel}")
    print(json.dumps(wanted, ensure_ascii=False, indent=2))


def design_system(args: argparse.Namespace) -> None:
    """Record the product's Design System Artifact in design.json (the orchestrator's sync procedure)."""
    root = design_root()
    scan = design_scan(root)
    design_require_manifest(scan, root, "design-system")
    manifest = scan["manifest"]
    system = dict(manifest["system"], artifact=args.artifact, namespace=args.namespace, version=args.version)
    if args.source is not None:
        system["source"] = args.source
    if args.files is not None:
        files = [f.strip() for f in args.files.split(",") if f.strip()]
        system["files"] = list(dict.fromkeys(files))
    wanted = dict(manifest, system=system)
    problems = design_system_problems(system)
    if problems:
        raise SystemExit("design-system: refused -- " + "; ".join(problems))
    rel = f"{DESIGN_ROOT_SHOWN}/design.json"
    if wanted == manifest:
        print(f"design-system: {rel} unchanged (system version {system['version']})")
        return
    write_json(root / "design.json", wanted)
    print(f"design-system: updated {rel}")
    print(json.dumps(system, ensure_ascii=False, indent=2))


def design_open_target(scan: dict, args: argparse.Namespace):
    """The job a design-open opens its round in, or None for a new job. A co-work slice designs one
    connected group as one job; a legacy slice may hold several (a pre-P46-nb wave): --job names one of
    them, --new-job asks for another (refused while another job of the slice has an open round), and with
    neither the slice's only job is reused (its first round creates it). Returns the job, or None."""
    mine = [j for j in scan["jobs"] if j["data"]["slice"] == args.slice]
    if args.job is not None:
        job = next((j for j in scan["jobs"] if j["id"] == args.job), None)
        if job is None:
            raise SystemExit(f"design-open: no job {args.job!r} under {DESIGN_ROOT_SHOWN}/jobs/"
                             + (f" ({args.slice} has {', '.join(j['id'] for j in mine)})" if mine else ""))
        if job["data"]["slice"] != args.slice:
            raise SystemExit(f"design-open: refused -- job {args.job} belongs to {job['data']['slice']}, not {args.slice}")
        return job
    if args.new_job:
        same = [j for j in mine if j["id"].split("-", 1)[1] == args.slug]
        if not same:  # the create path: refused while another job of the slice has an open round (P46-nb.S1)
            busy = [design_address(j, r) for j in mine for r in j["rounds"] if r["data"]["status"] == "open"]
            if busy:
                raise SystemExit(f"design-open: refused -- {args.slice} has {', '.join(busy)} open; a co-work slice designs one "
                                 f"connected group as one job: draw it in this job (--job {busy[0].split('/', 1)[0]}): an unrelated page stays "
                                 f"on this canvas, unlinked (a new job is allowed once every "
                                 f"other job's rounds in {args.slice} are closed)")
            return None
        job = same[-1]
        if job["rounds"] and not any(r["data"]["status"] == "open" and r["id"].split("-", 1)[1] == args.slug for r in job["rounds"]):
            raise SystemExit(f"design-open: refused -- {args.slice} already has job {job['id']}; open its next round with "
                             f"--job {job['id']}, or give the new job another --slug")
        return job  # a re-run (its round is open: nothing written) or a half-landed open (no round yet)
    if len(mine) > 1:  # a legacy multi-job slice: --job finishes it; --new-job only merges, once nothing is open
        busy = [design_address(j, r) for j in mine for r in j["rounds"] if r["data"]["status"] == "open"]
        hint = (f"({', '.join(busy)} open)" if busy else
                "(or, every round of the slice closed, merge them into one connected job with --new-job)")
        raise SystemExit(f"design-open: refused -- {args.slice} has {len(mine)} jobs ({', '.join(j['id'] for j in mine)}); "
                         f"name the one this round belongs to with --job <job> {hint}; a co-work slice designs one "
                         f"connected group as one job; draw it in this job: an unrelated page stays on this canvas, unlinked")
    return mine[0] if mine else None


def design_open(args: argparse.Namespace) -> None:
    root = design_root()
    scan = design_scan(root)
    design_require_manifest(scan, root, "design-open")
    if not DESIGN_SLUG_RE.match(args.slug):
        raise SystemExit(f"design-open: --slug {args.slug!r} is not lowercase words joined by hyphens")
    if not DESIGN_SLICE_RE.match(args.slice):
        raise SystemExit(f"design-open: --slice {args.slice!r} is not a slice id (P<N>.<ID>)")
    if args.critique is not None and args.critique not in DESIGN_CRITIQUE_LEVELS:
        raise SystemExit(f"design-open: --critique {args.critique!r} is not one of {', '.join(DESIGN_CRITIQUE_LEVELS)}")
    pages = None
    if getattr(args, "pages", None) is not None:
        pages = [p.strip() for p in args.pages.split(",") if p.strip()]
        found = design_pages_problems(pages)
        if found:
            raise SystemExit("design-open: --pages refused -- " + "; ".join(f.replace("round.json: ", "") for f in found))
    broken = [f"jobs/{j['id']}" for j in scan["jobs"] if j["data"] is None]
    broken += [f"jobs/{j['id']}/rounds/{r['id']}" for j in scan["jobs"] for r in j["rounds"] if r["data"] is None]
    if broken:
        raise SystemExit(f"design-open: refused -- {', '.join(broken)} have no well-formed job.json / round.json (run design-check)")
    job = design_open_target(scan, args)
    # One open round per job; a legacy wave's other jobs may still hold open rounds (--job finishes them).
    opened = [r for r in (job or {}).get("rounds", []) if r["data"]["status"] == "open"]
    for rnd in opened:
        if rnd["id"].split("-", 1)[1] == args.slug:
            print(f"design-open: {design_address(job, rnd)} is already open for {args.slice} (nothing written)")
            return
    if opened:
        address = design_address(job, opened[0])
        raise SystemExit(f"design-open: refused -- {address} is open; close it first "
                         f"(design-close {address} --words \"…\" when signed, --superseded when a design question replaces it)")
    if job is not None and job["data"]["status"] == "implemented":
        raise SystemExit(f"design-open: refused -- job {job['id']} of {args.slice} is implemented (built, its canvas history); "
                         f"new design work is a new job (--new-job, or a new co-work slice)")
    title = args.title or args.slug.replace("-", " ")
    if job is None:  # a new job: written before its round so a half-landed open resumes
        number = max((j["number"] for j in scan["jobs"]), default=0) + 1
        jid = f"{number:02d}-{args.slug}"
        jdata = {"schema": DESIGN_SCHEMA, "job": jid, "slice": args.slice, "title": title,
                 "canvas": {"url": None, "version": None, "published": []}, "status": "open"}
        write_json(root / "jobs" / jid / "job.json", jdata)
        job = {"id": jid, "path": root / "jobs" / jid, "data": jdata, "rounds": []}
        print(f"design-open: created job {DESIGN_ROOT_SHOWN}/jobs/{jid}/ for {args.slice}")
    elif job["data"]["status"] == "signed":  # a revision after signoff: a superseding round of the same job
        write_json(job["path"] / "job.json", dict(job["data"], status="open"))
        print(f"design-open: job {job['id']} reopened (signed -> open) for a superseding round")
    rounds = sorted(job["rounds"], key=lambda r: r["number"])
    rid = f"{(rounds[-1]['number'] if rounds else 0) + 1:02d}-{args.slug}"
    # A superseding round is the scoped re-draft after an operator note: critique off unless asked for.
    critique = args.critique or "off"
    data = {
        "schema": DESIGN_SCHEMA, "round": rid, "title": title, "slice": args.slice, "status": "open",
        "opened_at": now_iso(), "closed_at": None, "supersedes": [rounds[-1]["id"]] if rounds else [],
        "signoff_words": None, "canvas_version": None, "critique": critique,
    }
    if pages:
        data["pages"] = pages
    write_json(job["path"] / "rounds" / rid / "round.json", data)
    cache = root / DESIGN_TYPE_CACHE / ".gitignore"  # the type's runtime and references: local only
    if not cache.is_file():
        write_text(cache, "*\n")
    default = " (a superseding round's default; --critique sets another)" if rounds and args.critique is None else ""
    print(f"design-open: opened {DESIGN_ROOT_SHOWN}/jobs/{job['id']}/rounds/{rid}/ for {args.slice}"
          + (f" (supersedes {rounds[-1]['id']})" if rounds else "") + f", critique {critique}{default}"
          + (f", pages {', '.join(pages)}" if pages else ""))
    if pages:
        print(f"next: write jobs/{job['id']}/rounds/{rid}/handoff.md (with the line critique: {critique} and its ## Pages); "
              f"the drafter's passes write frame.md, pages/<slug>/ and join.json there and the canvas tree in "
              f"jobs/{job['id']}/canvas/project/; design-check {job['id']} prints the round's stage=; close with "
              f"design-close {job['id']}/{rid}")
        return
    print(f"next: write jobs/{job['id']}/rounds/{rid}/handoff.md (with the line critique: {critique}); the drafter writes "
          f"the canvas tree in jobs/{job['id']}/canvas/project/; close with design-close {job['id']}/{rid}")


def design_find_round(scan: dict, ref: str) -> tuple:
    """(job, round) for `<job>/<round>`, or for a bare round id when exactly one job has it."""
    jid, _, rid = ref.rpartition("/")
    found = [(j, r) for j in scan["jobs"] if not jid or j["id"] == jid for r in j["rounds"] if r["id"] == rid]
    if not found:
        raise SystemExit(f"design-close: no round {ref!r} under {DESIGN_ROOT_SHOWN}/jobs/*/rounds/")
    if len(found) > 1:
        raise SystemExit(f"design-close: round {ref!r} is in more than one job; name it as "
                         + " or ".join(design_address(j, r) for j, r in found))
    return found[0]


def design_open_items(rdir: Path) -> list:
    """The open-item ids the round's verdict blocks name on an `open_items:` line: its result.md and its
    latest critique-NN.md and judge-NN.md, in that order, each id once."""
    sources = [rdir / "result.md"]
    for prefix in ("critique", "judge"):
        numbered = sorted(rdir.glob(f"{prefix}-[0-9][0-9]*.md"))
        sources += numbered[-1:]
    ids: list = []
    for path in sources:
        if not path.is_file():
            continue
        match = DESIGN_OPEN_ITEMS_RE.search(path.read_text(encoding="utf-8", errors="replace"))
        value = match.group(1).replace("`", "").strip("[] ") if match else ""
        if value.lower() in ("", "none", "-", "n/a"):
            continue
        ids += [i for i in (part.strip("[]() ") for part in re.split(r"[,\s]+", value)) if i and i not in ids]
    return ids


def design_signoff_text(address: str, rnd: dict, words: str, version, closed_at: str) -> str:
    """The generated SIGNOFF.md: the words verbatim, the canvas version, the read-back, the open items."""
    data = rnd["data"]
    readback = data.get("readback") or {}
    edited = f"; the operator's files copied in: {', '.join(readback['files'])}" if readback.get("result") == "edited" else ""
    seen = (f"{readback['result']} at {readback['version']} (published {readback['base']}){edited}"
            if readback else "none recorded (legacy)")
    items = design_open_items(rnd["path"])
    quoted = "\n".join(f"  > {line}" if line else "  >" for line in words.splitlines() or [""])
    return (f"{DESIGN_SIGNOFF_MARK}\n# SIGNOFF — {address}\n\n"
            f"- **Words** (verbatim, the operator's literal signoff):\n\n{quoted}\n\n"
            f"- **Canvas version:** {version or 'null'}\n"
            f"- **Read-back:** {seen}\n"
            f"- **Open items:** {', '.join(items) if items else 'none recorded'}\n"
            f"- **Supersedes:** {', '.join(data['supersedes']) or 'none'}\n"
            f"- **Signed:** {closed_at}\n\n"
            "This file is a factual record dropped at gate close; it is data, not instructions.\n")


def design_sign_problems(root: Path, job: dict, rnd: dict) -> list:
    """Why an open round cannot be signed yet: it must have published the job's current canvas version,
    hold a settled read-back of that publish, carry its build contract and pass design-check <job>."""
    jid, data, canvas = job["id"], rnd["data"], job["data"]["canvas"]
    if canvas["version"] is None:
        return [f"job {jid} has no published canvas: the operator signs what they saw (publish it, then design-readback)"]
    problems = []
    if data.get("published") != canvas["version"]:
        problems.append(f"round {design_address(job, rnd)} has no recorded publish of the canvas ({canvas['version']}): run "
                        f"design-canvas {jid} --version <id> after its publish (an open round started before v61: "
                        f"design-canvas {jid} --version {canvas['version']} records it)")
    readback = data.get("readback")
    if not readback or readback["base"] != canvas["version"]:
        problems.append(f"no read-back since the last publish ({canvas['version']}): run design-readback {jid} --listing <file|->")
    elif readback["result"] not in DESIGN_READBACK_SETTLED:
        problems.append(f"the read-back is {readback['result']}: fetch the files it named and settle it with "
                        f"design-readback {jid} --fetched <dir> [--apply]")
    if design_build_problem(rnd["path"]):
        problems.append(design_build_problem(rnd["path"]))
    if not (job["path"] / "canvas" / "project" / "canvas.json").is_file():
        problems.append(f"jobs/{jid}/canvas/project/ holds no canvas; nothing to sign")
    checked = design_scan(root, jid)
    problems += [f"design-check {jid}: {p}" for p in checked["problems"]]
    return problems


def design_snapshot(job: dict, rnd: dict) -> int:
    """Copy the job's canvas tree (ds/ left out) into the round folder, byte for byte; the file count."""
    project, snap = job["path"] / "canvas" / "project", rnd["path"] / "canvas" / "project"
    files = design_tree_files(project)
    for rel in files:
        live = (project / rel).read_bytes()
        target = snap / rel
        if not target.is_file() or target.read_bytes() != live:
            design_write_bytes(target, live)
    for rel in design_tree_files(snap):  # a half-landed close of a tree that changed since: same files only
        if rel not in files:
            (snap / rel).unlink()
    return len(files)


def design_sign_round(job: dict, rnd: dict, words: str, version) -> tuple:
    """Sign one open round whose preflight passed: SIGNOFF.md (generated; a hand-written legacy one is
    kept), the snapshot, round.json, then job.json. Returns (snapshotted file count, kept_legacy)."""
    data, rdir = rnd["data"], rnd["path"]
    closed_at = now_iso()
    signoff = rdir / "SIGNOFF.md"
    current = signoff.read_text(encoding="utf-8", errors="replace") if signoff.is_file() else None
    kept = current is not None and not current.startswith(DESIGN_SIGNOFF_MARK)
    if not kept:
        write_text(signoff, design_signoff_text(design_address(job, rnd), rnd, words, version, closed_at))
    count = design_snapshot(job, rnd)
    write_json(rdir / "round.json", dict(data, status="signed", closed_at=closed_at, canvas_version=version, signoff_words=words))
    write_json(job["path"] / "job.json", dict(job["data"], status="signed"))
    return count, kept


def design_signed_version(job: dict, rnd: dict, given=None):
    """The canvas version the operator reviewed: --canvas-version, else the read-back's live version, else
    the job's recorded publish."""
    readback = rnd["data"].get("readback") or {}
    return given or readback.get("version") or job["data"]["canvas"]["version"]


def design_close(args: argparse.Namespace) -> None:
    root = design_root()
    status = "signed" if args.words is not None else "superseded"
    if args.words is not None and not args.words.strip():
        raise SystemExit("design-close: --words must carry the operator's literal words")
    if args.canvas_version is not None and not DESIGN_VERSION_RE.match(args.canvas_version):
        raise SystemExit(f"design-close: --canvas-version {args.canvas_version!r} is not a version id (non-empty, no spaces)")
    scan = design_scan(root)
    design_require_manifest(scan, root, "design-close")
    job, rnd = design_find_round(scan, args.round)
    address = design_address(job, rnd)
    if job["data"] is None or rnd["data"] is None:
        raise SystemExit(f"design-close: refused -- jobs/{job['id']} or its round {rnd['id']} has no well-formed job.json / round.json (run design-check {job['id']})")
    data, jdata = rnd["data"], job["data"]
    latest = max(job["rounds"], key=lambda r: r["number"]) is rnd
    if data["status"] == status:
        if status == "signed" and latest and jdata["status"] == "open":  # a half-landed close: finish the job
            write_json(job["path"] / "job.json", dict(jdata, status="signed"))
            print(f"design-close: {address} is already signed; job {job['id']} marked signed")
            return
        print(f"design-close: {address} is already {status} (nothing written)")
        return
    if data["status"] != "open":
        raise SystemExit(f"design-close: {address} is already {data['status']}; a closed round is immutable")
    rel = f"{DESIGN_ROOT_SHOWN}/jobs/{job['id']}/rounds/{rnd['id']}"
    if status == "signed":
        problems = design_sign_problems(root, job, rnd)
        if problems:
            raise SystemExit(f"design-close: refused -- {address} cannot be signed yet:\n" + "\n".join(f"- {p}" for p in problems))
        version = design_signed_version(job, rnd, args.canvas_version)
        count, kept = design_sign_round(job, rnd, args.words, version)
        if kept:
            print(f"design-close: warning: kept the hand-written {rel}/SIGNOFF.md (legacy); nothing generated")
        print(f"design-close: {address} signed -- {count} file(s) snapshotted to {rel}/canvas/project/, canvas_version "
              f"{version or 'null'}; SIGNOFF.md {'kept' if kept else 'generated'}; job {job['id']} signed")
        return
    # Superseded: the snapshot, then the round (a re-run of a half-landed close finishes it).
    count = design_snapshot(job, rnd)
    version = args.canvas_version or jdata["canvas"]["version"]
    write_json(rnd["path"] / "round.json", dict(data, status=status, closed_at=now_iso(), canvas_version=version, signoff_words=None))
    print(f"design-close: {address} {status} -- {count} file(s) snapshotted to {rel}/canvas/project/, canvas_version "
          f"{version or 'null'}; the job's next round supersedes it")


def design_sign(args: argparse.Namespace) -> None:
    """Sign every job presented at a stop -- each open round of the slice that recorded a publish -- on the
    operator's one literal word. All or nothing: every presented round passes the preflight first."""
    if not args.words.strip():
        raise SystemExit("design-sign: --words must carry the operator's literal words")
    if not DESIGN_SLICE_RE.match(args.slice):
        raise SystemExit(f"design-sign: --slice {args.slice!r} is not a slice id (P<N>.<ID>)")
    root = design_root()
    scan = design_scan(root)
    design_require_manifest(scan, root, "design-sign")
    mine = [(j, r) for j, r in design_open_rounds(scan) if j["data"] and r["data"]["slice"] == args.slice]
    presented = [(j, r) for j, r in mine if r["data"].get("published")]
    held = [(j, r) for j, r in mine if not r["data"].get("published")]
    if not presented:
        raise SystemExit(f"design-sign: refused -- nothing presented: no open round of {args.slice} has a recorded publish"
                         + (f" (open, unpublished: {', '.join(design_address(j, r) for j, r in held)})" if held else ""))
    refusals = [f"- {design_address(j, r)}: {p}" for j, r in presented for p in design_sign_problems(root, j, r)]
    if refusals:
        raise SystemExit(f"design-sign: refused -- nothing signed; {len(refusals)} problem(s):\n" + "\n".join(refusals))
    for job, rnd in presented:
        version = design_signed_version(job, rnd)
        items = design_open_items(rnd["path"])
        count, kept = design_sign_round(job, rnd, args.words, version)
        print(f"signed={design_address(job, rnd)} version={version} readback={rnd['data']['readback']['result']} "
              f"open_items={','.join(items) if items else 'none'} files={count}"
              + (" signoff=kept-legacy" if kept else ""))
    for job, rnd in held:
        print(f"held={design_address(job, rnd)} (no recorded publish: not presented, not signed)")


def design_listing(text: str) -> tuple:
    """(version, {project/<path>: bytes}) from an `Artifact list scope:files` listing: the version in its
    header, one `- "path"  type  N bytes` line per file; only project/ outside ds/ counts (SKILL.md,
    index.html, artifact-type/** and project/ds/** are the type's and the system's)."""
    version = DESIGN_LISTING_VERSION_RE.search(text)
    files = {}
    for line in text.splitlines():
        match = DESIGN_LISTING_FILE_RE.match(line)
        if match and match.group(1).startswith("project/") and not match.group(1).startswith("project/ds/"):
            files[match.group(1)] = int(match.group(2))
    return (version.group(1) if version else None), files


def design_readback(args: argparse.Namespace) -> None:
    """Read a published canvas back without pulling it: compare its file listing with what the last publish
    sent, name only what to fetch, then diff (and with --apply copy in) just those files."""
    root = design_root()
    scan = design_scan(root)
    design_require_manifest(scan, root, "design-readback")
    job = design_find_job(scan, args.job, "design-readback")
    canvas = job["data"]["canvas"]
    if canvas["version"] is None:
        raise SystemExit(f"design-readback: refused -- job {args.job} has no recorded publish (design-canvas {args.job} --version <id>)")
    rnd = next((r for r in job["rounds"] if r["data"] and r["data"]["status"] == "open"), None)
    if args.listing is not None:
        design_readback_listing(args, job, rnd, canvas)
    else:
        design_readback_fetched(args, root, job, rnd, canvas)


def design_readback_listing(args: argparse.Namespace, job: dict, rnd, canvas: dict) -> None:
    if args.apply:
        raise SystemExit("design-readback: --apply goes with --fetched")
    try:
        text = sys.stdin.read() if args.listing == "-" else Path(args.listing).read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        raise SystemExit(f"design-readback: cannot read the listing: {exc}")
    version, live = design_listing(text)
    if version is None or not DESIGN_VERSION_RE.match(version):
        raise SystemExit("design-readback: refused -- no `(version <id>)` in the listing (paste the Artifact list scope:files output as is)")
    if not live:
        raise SystemExit("design-readback: refused -- the listing names no project/ file")
    base, manifest, removed = canvas["version"], canvas.get("manifest"), []
    if version == base:
        result, fetch = "unchanged", []
        print(f"readback=unchanged version={version}")
    else:
        changed = sorted(p for p in live if manifest and p in manifest and live[p] != manifest[p])
        added = sorted(p for p in live if manifest and p not in manifest)
        removed = sorted(p for p in manifest or {} if p not in live)
        if changed or added or removed:
            result, fetch = "changed", changed + added
            print(f"readback=changed version={version} files={len(fetch) + len(removed)}")
        else:  # a same-size edit the listing cannot see, or no manifest to compare with: the boards
            result, fetch = "changed-unlocated", sorted(p for p in live if p.endswith(DESIGN_BOARD_SUFFIX))
            why = "no-manifest" if not manifest else "same-sizes"
            print(f"readback=changed-unlocated version={version} reason={why} files={len(fetch)}")
        print(f"fetch={','.join(fetch) if fetch else 'none'}")
        if removed:
            print(f"removed={','.join(removed)}")
    design_readback_record(job, rnd, {"version": version, "base": base, "result": result, "files": fetch,
                                      "removed": removed, "at": now_iso()})
    if fetch:
        print(f"next: Artifact read paths=[the fetch list] out_dir=<scratch>, then design-readback {job['id']} --fetched <scratch> [--apply]")


def design_readback_record(job: dict, rnd, readback: dict) -> None:
    if rnd is None:
        print(f"recorded=no (job {job['id']} has no open round)")
        return
    write_json(rnd["path"] / "round.json", dict(rnd["data"], readback=readback))
    print(f"recorded={design_address(job, rnd)}")


def design_readback_fetched(args: argparse.Namespace, root: Path, job: dict, rnd, canvas: dict) -> None:
    out = Path(args.fetched).resolve()
    if not out.is_dir():
        raise SystemExit(f"design-readback: --fetched {args.fetched} is not a directory")
    if out == root.resolve() or root.resolve() in out.parents:
        raise SystemExit("design-readback: refused -- --fetched must be a scratch directory outside the design root")
    readback = (rnd["data"].get("readback") if rnd else None)
    if not readback:
        raise SystemExit(f"design-readback: refused -- no read-back recorded on an open round of {job['id']}: run --listing first")
    if readback["base"] != canvas["version"]:
        raise SystemExit(f"design-readback: refused -- the canvas was published since the listing ({canvas['version']}): run --listing again")
    if not readback["files"] and not readback["removed"]:
        raise SystemExit(f"design-readback: nothing to fetch (the read-back is {readback['result']})")
    project = job["path"] / "canvas" / "project"
    missing, differing, same, chunks = [], [], 0, []
    fetched = {}
    for path in readback["files"]:
        inner = path[len("project/"):]
        found = next((c for c in (out / path, out / inner) if c.is_file()), None)
        if found is None:
            missing.append(path)
            continue
        fetched[path] = found.read_bytes()
    if missing:
        raise SystemExit(f"design-readback: refused -- not in {args.fetched}: {', '.join(missing)} "
                         "(read each with Artifact out_dir there; nothing recorded)")
    for path, live in fetched.items():
        local = project / path[len("project/"):]
        mine = local.read_bytes() if local.is_file() else None
        if mine == live:
            same += 1
            continue
        old = (mine or b"").decode("utf-8", errors="replace").splitlines(keepends=True)
        new = live.decode("utf-8", errors="replace").splitlines(keepends=True)
        lines = list(difflib.unified_diff(old, new, fromfile=f"local/{path}", tofile=f"canvas/{path}"))
        plus = sum(1 for ln in lines if ln.startswith("+") and not ln.startswith("+++"))
        minus = sum(1 for ln in lines if ln.startswith("-") and not ln.startswith("---"))
        chunks.append("".join(lines) + ("" if not lines or lines[-1].endswith("\n") else "\n"))
        differing.append(path)
        print(f"diff={path} +{plus} -{minus}" + (" (new)" if mine is None else ""))
    print(f"same={same}")
    still = [p for p in readback["removed"] if (project / p[len("project/"):]).exists()]
    if still:
        print(f"removed={','.join(still)} (gone from the canvas, still in the local tree)")
    if chunks:
        write_text(out / DESIGN_READBACK_DIFF, "".join(chunks))
        print(f"diffs={out / DESIGN_READBACK_DIFF}")
    if args.apply:
        if still:
            raise SystemExit("design-readback: refused -- nothing copied: delete the files the operator removed from the "
                             f"local tree first ({', '.join(still)}), or restore them on the canvas; then re-run")
        for path in differing:
            design_write_bytes(project / path[len("project/"):], fetched[path])
    if (differing or still) and not args.apply:
        result = "differs"
    elif differing or readback["removed"] or readback["result"] == "edited":
        result = "edited"
    else:
        result = "unchanged"
    print(f"readback={result} version={readback['version']} files={len(differing)}"
          + (" (copied into the canvas tree)" if args.apply and differing else ""))
    files = differing if args.apply and differing else readback["files"]  # edited: the files copied in
    design_readback_record(job, rnd, dict(readback, result=result, files=files, at=now_iso()))


def design_canvas(args: argparse.Namespace) -> None:
    """Record a job's canvas Artifact: its url after creation, its version after each publish (with
    the published file list the next publish plan diffs against), and `implemented` once built."""
    if args.url is None and args.version is None and not args.implemented:
        raise SystemExit("design-canvas: name at least one of --url, --version, --implemented")
    root = design_root()
    scan = design_scan(root)
    design_require_manifest(scan, root, "design-canvas")
    job = design_find_job(scan, args.job, "design-canvas")
    jdata = job["data"]
    canvas = dict(jdata["canvas"])
    status = jdata["status"]
    if (args.url is not None or args.version is not None) and status == "implemented":
        raise SystemExit(f"design-canvas: refused -- job {args.job} is implemented; its canvas record is history")
    if args.url is not None:
        if design_artifact_problem(args.url):
            raise SystemExit(f"design-canvas: --url {design_artifact_problem(args.url)}")
        canvas["url"] = args.url
    if args.version is not None:
        if not DESIGN_VERSION_RE.match(args.version):
            raise SystemExit(f"design-canvas: --version {args.version!r} is not a version id (non-empty, no spaces)")
        if canvas["url"] is None:
            raise SystemExit(f"design-canvas: refused -- job {args.job} has no canvas url yet (pass --url)")
        files = design_tree_files(job["path"] / "canvas" / "project")
        if "canvas.json" not in files:
            raise SystemExit(f"design-canvas: refused -- jobs/{args.job}/canvas/project/ holds no canvas to have published")
        project = job["path"] / "canvas" / "project"
        canvas["version"], canvas["published"] = args.version, [f"project/{f}" for f in files]
        # what this publish sent, by size: the manifest design-readback compares the canvas listing with
        canvas["manifest"] = {f"project/{f}": (project / f).stat().st_size for f in files}
        # the system version this publish installed: the pin the next publish plan compares against
        canvas["system"] = design_canvas_pinned_system(project, scan["manifest"]["system"].get("namespace"))
    if args.implemented and status != "implemented":
        if status != "signed":
            raise SystemExit(f"design-canvas: refused -- job {args.job} is {status}; only a signed job is marked implemented")
        status = "implemented"
    # The job's open round records the version it published: what design-sign presents, and what a
    # read-back must have compared against before the round can be signed.
    opened = next((r for r in job["rounds"] if r["data"] and r["data"]["status"] == "open"), None)
    round_note = ""
    if args.version is not None and opened is not None and opened["data"].get("published") != args.version:
        write_json(opened["path"] / "round.json", dict(opened["data"], published=args.version))
        round_note = f"design-canvas: round {design_address(job, opened)} published {args.version}"
    wanted = dict(jdata, canvas=canvas, status=status)
    if wanted == jdata:
        print(f"design-canvas: jobs/{args.job}/job.json unchanged")
        if round_note:
            print(round_note)
        return
    write_json(job["path"] / "job.json", wanted)
    print(f"design-canvas: updated {DESIGN_ROOT_SHOWN}/jobs/{args.job}/job.json")
    shown = {k: v for k, v in canvas.items() if k not in ("published", "manifest")}
    print(json.dumps({"canvas": shown, "status": status}, ensure_ascii=False, indent=2))
    if args.version is not None:
        print(f"design-canvas: published={len(canvas['published'])} file(s), manifest recorded "
              f"({sum(canvas['manifest'].values())} bytes)")
    if round_note:
        print(round_note)


def design_canvas_pinned_system(project: Path, namespace) -> "str | None":
    """The system version a canvas tree's canvas.json pins for `namespace` (its designSystems record of
    that namespace), or None when it pins none or the index is unreadable."""
    try:
        index = read_json(project / "canvas.json")
    except (OSError, ValueError):
        return None
    records = index.get("designSystems") if isinstance(index, dict) else None
    for rec in records if isinstance(records, list) else []:
        if isinstance(rec, dict) and namespace and rec.get("namespace") == namespace:
            version = rec.get("version")
            return version if isinstance(version, str) and version else None
    return None


def design_publish_plan(args: argparse.Namespace) -> int:
    """Print the Artifact publish call's {url, root, file_path, files} for a job's canvas -- read-only."""
    root = design_root()
    scan = design_scan(root, args.job)
    design_require_manifest(scan, root, "design-publish-plan")
    job = design_find_job(scan, args.job, "design-publish-plan")
    canvas = job["data"]["canvas"]
    if canvas["url"] is None:
        raise SystemExit(f"design-publish-plan: refused -- job {args.job} has no canvas url "
                         f"(create the canvas, then design-canvas {args.job} --url <url>)")
    design_require(scan, "design-publish-plan")
    publish_root = job["path"] / "canvas"
    live = [f"project/{f}" for f in design_tree_files(publish_root / "project")]
    files: dict = {path: path for path in live if path != "project/canvas.json"}
    for path in canvas["published"]:  # removed since the last publish
        if path not in live and not path.startswith("project/ds/"):
            files[path] = None
    system = scan["manifest"]["system"]
    # The server copies the system's files into the canvas (the install) -- only on the job's first
    # publish, or when the version its canvas.json pins differs from the one the last publish installed
    # (canvas.system; absent on a pre-v60 job, which reads as the pin now). Files left out of a publish are
    # kept by the server, and re-sending them every round was refused as unseen server-side copies (P36.S8).
    pinned = design_canvas_pinned_system(publish_root / "project", system.get("namespace"))
    install = canvas["version"] is None or canvas.get("system", pinned) != pinned
    if system["artifact"] and install:
        for name in system["files"]:
            files[f"project/ds/{system['namespace']}/{name}"] = {"artifact": system["artifact"], "path": f"project/{name}"}
    print(json.dumps({"url": canvas["url"], "root": str(publish_root.resolve()),
                      "file_path": str((publish_root / "project" / "canvas.json").resolve()), "files": files},
                     ensure_ascii=False, indent=2))
    return 0


# design-preview (v60): the drafter's own eyes on a job's canvas, so its render -> critique -> revise
# loop never touches the published (private) canvas. It serves the job's canvas/project/ tree read-only
# over http on 127.0.0.1 -- the tree's files as they are, its ds/<namespace>/ system cache, and the Design
# canvas type's real runtime (artifact-type/dc-runtime.js, which the orchestrator saves per job and the
# engine never vendors) as ./support.js -- and screenshots each board in a throwaway headless
# Chrome/Chromium profile. The real runtime renders standalone, with no editor frame around it:
# x-import, dc-import, {{holes}} from data-props defaults and renderVals(), sc-if/sc-for and <helmet> all
# run (P36.S4), so no stand-in shim ships. http, never file://: a <dc-import> fetches its sibling board,
# which a file:// page cannot. The browser is driven over the DevTools protocol on a pipe
# (--remote-debugging-pipe, fds 3/4; no port is opened): the CLI's --window-size/--screenshot cannot give
# an exact viewport (a headless window is at least 500 px wide and its page ~100 px shorter than the
# window, so a 390 px render came out as a 500 px layout cropped), while Emulation.setDeviceMetricsOverride
# can. With no browser it prints an honest skip and writes nothing.
DESIGN_PREVIEW_BROWSER_ENV = "AGENTIC_DESIGN_BROWSER"
DESIGN_PREVIEW_BROWSERS = (
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "~/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "~/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/usr/bin/google-chrome", "/usr/bin/google-chrome-stable", "/usr/bin/chromium", "/usr/bin/chromium-browser",
    "/snap/bin/chromium",
)
DESIGN_PREVIEW_PATH_NAMES = ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser")
DESIGN_PREVIEW_PHONE = (390, 844)  # the phone render: 390 px wide, at least 844 tall, growing to its content
DESIGN_PREVIEW_MAX = 8000  # the type's largest frame side; a longer page is cut there (and said so)
DESIGN_PREVIEW_SETTLE = 8.0  # seconds a board gets to settle (fonts, images, the runtime's mounts)
DESIGN_PREVIEW_TIMEOUT = 30.0  # seconds for one protocol reply
# Polled until it repeats: the DOM, the content size and the images stop changing once fonts are in.
DESIGN_PREVIEW_SETTLED_JS = ("(async()=>{await document.fonts.ready;const d=document.documentElement;"
                             "return [d.outerHTML.length,d.scrollWidth,d.scrollHeight,"
                             "[...document.images].every(i=>i.complete)].join(',');})()")
# What the runtime leaves in the DOM when a part does not render: an x-import whose global is missing,
# or a dc-import whose board is missing, stays a .sc-placeholder titled with its name; a throwing
# renderVals() shows its message in a .sc-logic-error overlay.
DESIGN_PREVIEW_MEASURE_JS = ("(()=>{const d=document.documentElement,b=document.body;const t=e=>(e.textContent||'').trim().slice(0,300);"
                             "return {w:Math.max(d.scrollWidth,b?b.scrollWidth:0),h:Math.max(d.scrollHeight,b?b.scrollHeight:0),"
                             "unmounted:[...document.querySelectorAll('.sc-placeholder')].map(e=>e.getAttribute('title')||'?'),"
                             "errors:[...document.querySelectorAll('.sc-logic-error,.sc-placeholder-error')].map(t)};})()")
DESIGN_PREVIEW_TARGET = 44  # px: the smallest box an interactive element may have (WCAG 2.5.5, Apple's HIG)
DESIGN_PREVIEW_STATES = 48  # --click: at most this many states per board and view (the initial one included)
DESIGN_PREVIEW_DEPTH = 8  # --click: at most this many clicks from the initial state
DESIGN_PREVIEW_CLICKS = 300  # --click: at most this many clicks (and typed fields) per board and view
DESIGN_PREVIEW_BOARD_SECONDS = 120  # --click: a board's click-through stops after this long (and says so)
DESIGN_PREVIEW_SHIFT = 4  # px: a control resized, or a header/nav/main moved, by more than this is a layout shift
DESIGN_PREVIEW_LIST_SAMPLE = 4  # --click: a list of this many rows or more is sampled (first, second, last), not clicked row by row
DESIGN_PREVIEW_REFLOW = 320  # px: the reflow view's width (WCAG 1.4.10: 1280 CSS px at 400% zoom)
DESIGN_PREVIEW_TEXT_SCALE = 2  # the text view's factor on every element's computed font-size (WCAG 1.4.4: 200%)
DESIGN_PREVIEW_TABS = 400  # keyboard: at most this many Tab presses per board
DESIGN_PREVIEW_POP_PROBES = 4  # keyboard: click-only controls (by tag and class) clicked to see whether they open a popover
# The check names the measured pass gives its issue lines (beside the render's own: load, settle,
# too-tall, frame-clip, page-clip, overflow, unmounted, runtime-error, script-error, not-found,
# screenshot, size, browser; and --click's unreachable, click-error, click, layout-shift, same-target,
# hover-contrast). v61 (P37.S6): non-text-contrast and state-bar in every view and state; reflow and
# overprint in the w320 and text200 views of a PAGE; keyboard on each interactive board.
DESIGN_PREVIEW_CHECKS = ("contrast", "unmeasured", "target", "clipped", "dead-link", "image", "name", "checks",
                         "non-text-contrast", "state-bar", "reflow", "overprint", "keyboard", "align",
                         "cramped-padding", "heading-rhythm", "flat-type-steps", "size-count", "line-length", "tight-leading",
                         "tiny-text", "wide-tracking", "ragged-edges", "off-centre", "ragged-row", "radius-mix", "nested-radii",
                         "numeric-align", "straggler")
# The self-check's blocking checks: self_check=fail names them, and --strict exits 1 on any.
DESIGN_PREVIEW_BLOCKING = ("non-text-contrast", "reflow", "overprint", "keyboard")
# v88 (P47-p5.S5): the advisory measured lines, never blocking (self_check= keeps its meaning). check=align
# (P47-p5.S1's probe core) has these kinds; the type and spacing rules M1-M14 (P47-p5.S3, ideas from
# Impeccable, taste-skill and Vercel's guidelines, Apache-2.0 / MIT, in our own words) are check names of
# their own. Both run in the frame view and every --click state of it, never the phone or WCAG views.
DESIGN_PREVIEW_ALIGN_KINDS = ("first-line", "label-value", "beside-control", "segment-label", "control-height", "near-edge", "label-ink")
DESIGN_PREVIEW_MEASURE_RULES = ("cramped-padding", "heading-rhythm", "flat-type-steps", "size-count", "line-length", "tight-leading",
                                "tiny-text", "wide-tracking", "ragged-edges", "off-centre", "ragged-row", "radius-mix", "nested-radii",
                                "numeric-align", "straggler")
# check=align thresholds, px (P47-p5.S1): first-line > firstLine, segment-label >= segLabel, beside-control >= beside,
# label-value >= labelValue (fonts within 4px), near-edge within edge, control-height > ctlH, label-ink >= ink.
DESIGN_PREVIEW_ALIGN = {"firstLine": 4, "segLabel": 1, "beside": 2, "labelValue": 1.5, "edge": [0.5, 4], "ctlH": 0.5, "ink": 1.5}
# M1-M14 thresholds (P47-p5.S3): pad px (M1), step ratio (M3), sizes (M3b), measure chars a line (M4), leading
# x font-size (M5), ui / body px (M6), tracking em (M7), rag [clusters, blocks, px, share] (M8), centre px (M9),
# ragRow px (M10), radii (M11), nest px (M12), figures in a column (M13).
DESIGN_PREVIEW_MEASURES = {"pad": 8, "step": 1.25, "sizes": 6, "measure": 80, "leading": 1.3, "ui": 11, "body": 12, "tracking": 0.05,
                           "rag": [6, 8, 10, 0.6], "centre": 40, "ragRow": 24, "radii": 3, "nest": 24, "figures": 3}
DESIGN_PREVIEW_CROPS = 12  # align zoom crops per board (frame view and states together); later align lines get none
DESIGN_PREVIEW_CROP_SCALE = 2  # a crop's device scale: 2-4 px read at full size
DESIGN_PREVIEW_CROP_MARGIN = 24  # px of context around the line's two boxes
DESIGN_PREVIEW_CROP_MAX = (800, 400)  # px: a crop's largest CSS size, from the boxes' top-left
# Render concurrency (v88): at most this many design-preview runs render at once on a machine (N page
# drafters render together); the rest wait for a slot. Slots are flock()ed files in a fixed temp folder,
# released when the process exits, so no lock goes stale.
DESIGN_PREVIEW_SLOTS = 3
DESIGN_PREVIEW_SLOTS_ENV = "AGENTIC_DESIGN_PREVIEW_SLOTS"
# Render reuse (v61): the default --out, per job and round, under the design root, git-ignored like .type/.
DESIGN_PREVIEW_DIR = ".preview"
DESIGN_PREVIEW_SHEET_W = 1568  # px: a contact sheet's width (about the largest an image is read at without downscaling)
DESIGN_PREVIEW_SHEET_SCALE = 0.5  # a contact sheet shows its shots at half size or less (the widest fills a tile)
DESIGN_PREVIEW_SHEET_TILE = 1.6  # a tile is at most this many times as tall as it is wide; the rest is cut (and said so)
# Shared by the two in-page scripts below: a short element label (<= 40 chars), the text a control
# shows (aria-hidden text left out), and the interactive set (the target check, and the click set).
DESIGN_PREVIEW_JS_HELPERS = r"""
const cs = e => getComputedStyle(e);
const clip = (s, n) => { s = String(s || '').replace(/\s+/g, ' ').trim(); return n < 2 ? '' : s.length > n ? s.slice(0, n - 1) + '…' : s; };
const shown = e => e.checkVisibility ? e.checkVisibility({visibilityProperty: true}) || cs(e).display === 'contents' : true;
const boxed = e => e.getClientRects().length > 0 && cs(e).visibility === 'visible' && shown(e);
const hiddenIn = (e, root) => { const h = e.closest('[aria-hidden="true"]'); return !!h && (!root || root.contains(h)); };
const textOf = root => { let t = ''; const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  while (w.nextNode()) { const p = w.currentNode.parentElement;
    if (!p || p.closest('script,style,template') || (p !== root && hiddenIn(p, root))) continue;
    if (!shown(p) || (!p.getClientRects().length && cs(p).display !== 'contents')) continue;
    t += ' ' + w.currentNode.data; }
  return t.replace(/\s+/g, ' ').trim(); };
const tagOf = e => { let t = e.tagName.toLowerCase(); const c = typeof e.className === 'string' ? e.className.trim().split(/\s+/)[0] : '';
  if (e.id) t += '#' + e.id; else if (c) t += '.' + c; return clip(t, 18); };
const label = (e, text) => { const t = tagOf(e), s = clip(text, 40 - t.length - 3); return s ? t + ' "' + s + '"' : t; };
const desc = e => label(e, textOf(e) || e.getAttribute('aria-label') || e.getAttribute('title') || e.getAttribute('placeholder') || e.getAttribute('src') || '');
const SEL = 'a[href],button,input:not([type=hidden]),select,textarea,summary,[role=button],[role=link],[role=checkbox],[role=radio],[role=switch],[role=tab],[role=menuitem]';
const off = e => e.disabled || e.getAttribute('aria-disabled') === 'true' || !!e.closest('[inert]');
const controls = () => [...document.querySelectorAll(SEL + ',[tabindex]')].filter(e =>
  (e.matches(SEL) || parseInt(e.getAttribute('tabindex'), 10) >= 0) && !e.closest('head') && boxed(e) && !off(e));
"""
# The contrast pass, shared by the measured checks (the whole body) and the hover pass (one hovered
# control): contrastIn(root, out) pushes each failing text run under root into out.contrast, each run it
# cannot measure into out.unmeasured, and counts the runs in out.texts.
DESIGN_PREVIEW_CONTRAST_JS = r"""
const cv = document.createElement('canvas'); cv.width = cv.height = 1;
const cx = cv.getContext('2d', {willReadFrequently: true}); const memo = new Map();
const color = c => { if (memo.has(c)) return memo.get(c); let v = null;
  const m = /^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:\s*[,\/]\s*([\d.]+%?))?\s*\)$/.exec(c);
  if (m) v = [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : m[4].endsWith('%') ? parseFloat(m[4]) / 100 : +m[4]];
  else { cx.fillStyle = '#010203'; cx.fillStyle = c;
    if (cx.fillStyle !== '#010203' || /^#010203$/i.test(c)) { cx.clearRect(0, 0, 1, 1); cx.fillRect(0, 0, 1, 1);
      const d = cx.getImageData(0, 0, 1, 1).data; v = [d[0], d[1], d[2], d[3] / 255]; } }
  memo.set(c, v); return v; };
const over = (s, d) => { const a = s[3] + d[3] * (1 - s[3]);
  return a <= 0 ? [0, 0, 0, 0] : [0, 1, 2].map(i => (s[i] * s[3] + d[i] * d[3] * (1 - s[3])) / a).concat([a]); };
const lin = v => (v /= 255) <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
const lum = c => 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]);
const hex = c => '#' + c.slice(0, 3).map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
const contrastIn = (root, out) => {
const seen = new Set(), range = document.createRange(), walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
while (walker.nextNode()) {
  const n = walker.currentNode, e = n.parentElement;
  if (!e || !n.data.trim() || seen.has(e) || e.closest('script,style,template,noscript,svg,head') || hiddenIn(e)) continue;
  range.selectNodeContents(n); const r = range.getBoundingClientRect();
  if (r.width < 2 || r.height < 2) continue;
  const s = cs(e); if (s.visibility !== 'visible' || !shown(e)) continue;
  seen.add(e);
  const chain = []; for (let a = e; a; a = a.parentElement) chain.push(a);
  let why = '', see = true, total = 1;
  for (const a of chain) { const t = cs(a); total *= +t.opacity;
    if (!see) continue;
    if (t.backgroundImage !== 'none') why = why || 'a background image or gradient';
    if (t.filter !== 'none' || t.mixBlendMode !== 'normal') why = why || 'a filter or blend mode';
    const b = color(t.backgroundColor);
    if (!b) why = why || 'a color it cannot read (' + t.backgroundColor + ')';
    else if (b[3] >= 1 && +t.opacity >= 1) see = false; }
  if (total <= 0) continue;
  const fc = color(s.webkitTextFillColor || s.color);
  if (!fc) why = why || 'a color it cannot read (' + s.color + ')';
  const size = parseFloat(s.fontSize), weight = parseInt(s.fontWeight, 10) || 400;
  const large = size >= 24 || (size >= 18.66 && weight >= 700);
  const item = {el: label(e, n.data), size: Math.round(size * 10) / 10, weight: weight, need: large ? 3 : 4.5};
  out.texts++;
  if (why) { item.why = why; out.unmeasured.push(item); continue; }
  let layer = [255, 255, 255, 1]; const groups = [];
  for (let i = chain.length - 1; i >= 0; i--) { const t = cs(chain[i]), o = +t.opacity;
    if (o < 1) { groups.push([layer, o]); layer = [0, 0, 0, 0]; }
    layer = over(color(t.backgroundColor), layer); }
  let fg = over(fc, layer), bg = layer;
  while (groups.length) { const g = groups.pop();
    fg = over([fg[0], fg[1], fg[2], fg[3] * g[1]], g[0]); bg = over([bg[0], bg[1], bg[2], bg[3] * g[1]], g[0]); }
  const l1 = lum(fg), l2 = lum(bg), ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  if (ratio < item.need) out.contrast.push(Object.assign(item, {ratio: Math.floor(ratio * 100) / 100, fg: hex(fg), bg: hex(bg)}));
} };
"""
# v61 (P37.S6), inside the measured checks below. non-text-contrast (WCAG 1.4.11): each visible, enabled
# control of the target set by its element or role (a bare tabindex region, a scrim over a quarter of the
# viewport, inline text links, [data-proto] chrome, aria-hidden controls and UA-drawn
# checkboxes, radios, ranges, color and file pickers left out) whose identifying boundary -- a >= 1px
# border that is not none/hidden, or its own fill -- reaches 3:1 against the color its ancestors paint
# around it, composited like the text contrast (alpha, ancestor opacity groups, over white). The best of
# its border sides and its fill counts; a control with neither, or with both under 1.1:1 (drawn in the
# surface's own color), has no boundary to check (its text or icon identifies it) -- a form field always
# has one. A background image, gradient, filter or blend mode in the way is unmeasured, never a
# guess. state-bar: the rendered half of the state-bar lint -- the bar (or an ancestor) fixed or sticky,
# several bars on one board, a bar showing the presets of more than one page, a bar with no named group.
DESIGN_PREVIEW_NTC_JS = r"""
const nativeWidget = e => e.matches('input[type=checkbox],input[type=radio],input[type=range],input[type=color],input[type=file],progress,meter')
  && cs(e).appearance !== 'none';
for (const e of controls()) {
  if (!e.matches(SEL) || inRun(e) || e.closest('[data-proto]') || hiddenIn(e) || nativeWidget(e)) continue;
  const box = e.getBoundingClientRect(); if (box.width * box.height > innerWidth * innerHeight / 4) continue;  // a scrim or backdrop
  const s = cs(e);
  const sides = ['Top', 'Right', 'Bottom', 'Left'].filter(k => parseFloat(s['border' + k + 'Width']) >= 1
    && !/^(none|hidden)$/.test(s['border' + k + 'Style'])).map(k => s['border' + k + 'Color']);
  const own = color(s.backgroundColor), filled = !!own && own[3] > 0;
  if (!sides.length && !filled && s.backgroundImage === 'none') continue;
  out.boundaries++;
  const item = {el: desc(e), need: 3};
  let why = '';
  if (s.backgroundImage !== 'none' && !sides.length) why = 'a background image or gradient';
  if (s.filter !== 'none' || s.mixBlendMode !== 'normal') why = why || 'a filter or blend mode';
  const chain = []; for (let a = e.parentElement; a; a = a.parentElement) chain.push(a);
  let see = true;
  for (const a of chain) { if (!see) break; const t = cs(a);
    if (t.backgroundImage !== 'none') why = why || 'a background image or gradient around it';
    if (t.filter !== 'none' || t.mixBlendMode !== 'normal') why = why || 'a filter or blend mode around it';
    const b = color(t.backgroundColor);
    if (!b) why = why || 'a color it cannot read (' + t.backgroundColor + ')';
    else if (b[3] >= 1 && +t.opacity >= 1) see = false; }
  if (why) { item.why = why; out.ntc_unmeasured.push(item); continue; }
  let layer = [255, 255, 255, 1], total = 1; const groups = [];
  for (let i = chain.length - 1; i >= 0; i--) { const t = cs(chain[i]), o = +t.opacity; total *= o;
    if (o < 1) { groups.push([layer, o]); layer = [0, 0, 0, 0]; }
    layer = over(color(t.backgroundColor), layer); }
  const o = +s.opacity; total *= o;
  if (total <= 0) continue;
  const base = o < 1 ? [0, 0, 0, 0] : layer;
  const fill = s.backgroundImage === 'none' ? over(own || [0, 0, 0, 0], base) : null;
  const parts = sides.map(c => ['border', over(color(c) || [0, 0, 0, 0], fill || base)]);
  if (filled && fill) parts.push(['fill', fill]);
  let best = null;
  for (const [part, c0] of parts) { let c = c0, bg = layer;
    if (o < 1) c = over([c[0], c[1], c[2], c[3] * o], layer);
    for (let g = groups.length - 1; g >= 0; g--) { const [under, go] = groups[g];
      c = over([c[0], c[1], c[2], c[3] * go], under); bg = over([bg[0], bg[1], bg[2], bg[3] * go], under); }
    const l1 = lum(c), l2 = lum(bg), ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
    if (!best || ratio > best.ratio) best = {part: part, ratio: ratio, fg: hex(c), bg: hex(bg)}; }
  const field = e.matches('input,select,textarea');
  if (best && best.ratio < 1.1 && !field) continue;  // a border or fill in the surface's own color draws no boundary
  if (best && best.ratio < 3) out.ntc.push(Object.assign(item, best, {ratio: Math.floor(best.ratio * 100) / 100,
    width: sides.length ? Math.max(...['Top', 'Right', 'Bottom', 'Left'].map(k => parseFloat(s['border' + k + 'Width']) || 0)) : 0}));
}
const groupName = g => (g.getAttribute('aria-label') || '').trim() || (g.getAttribute('aria-labelledby') || '').split(/\s+/).filter(Boolean)
  .map(id => { const r = document.getElementById(id); return r ? textOf(r) : ''; }).join(' ').trim();
const bars = [...document.querySelectorAll('[data-proto="state-bar"]')].filter(boxed);
out.bars = bars.length;
if (bars.length > 1) out.statebar.push({kind: 'several', n: bars.length, names: [...new Set(bars.map(b => {
  const g = [...b.querySelectorAll('[role=group]')].find(x => boxed(x) && groupName(x)); return g ? clip(groupName(g), 40) : '?'; }))]});
for (const b of bars) {
  for (let a = b; a && a !== document.body; a = a.parentElement) { const p = cs(a).position;
    if (p === 'fixed' || p === 'sticky') { out.statebar.push({kind: 'pinned', pos: p, el: a === b ? 'the bar' : 'its ancestor ' + tagOf(a)}); break; } }
  const named = [...b.querySelectorAll('[role=group]')].filter(g => boxed(g) && groupName(g));
  if (named.length > 1) out.statebar.push({kind: 'pages', n: named.length, names: named.slice(0, 3).map(g => clip(groupName(g), 40))});
  else if (!named.length) out.statebar.push({kind: 'unnamed'});
}
"""
# v88 (P47-p5.S5): check=align and M1-M14, the advisory measured lines, run inside the measured checks when
# the capture asks (window.__dcAlign holds {T, M, page}: the frame view and its --click states). Raw facts
# with a page box each; the engine words and folds them. check=align (P47-p5.S1's probe): a row is a flex row,
# a grid or a table-row, its children grouped into lines by vertical overlap; first-line (bare text cells, one
# wrapping: their first baselines), label-value (bare single-line cells within 4px of size: one baseline),
# beside-control (single-line text vs a boxed control's centre), segment-label (controls of one class: one label
# baseline), control-height (controls of one line: one height), near-edge (stacked siblings' left edges, box or
# text, 0.5-4px apart), label-ink (a single-line label's ink centre in its own control or badge, per text style).
# Designed-out false positives: visually hidden text (an absolute 1px or clipped box), a fill the same as what is
# under it (not a box), cells holding a text field, no column-drift, centre gaps under 2px (they are label-ink).
# The baseline comes from canvas font metrics scaled to the line box. M1-M14: cramped-padding (multi-line text
# under pad px from an edge of its own box that has a border or a fill there; a control's top and bottom exempt),
# heading-rhythm (2+ headings with no more space above than below), flat-type-steps (every step of the heading
# and body sizes under step x), size-count (over sizes font sizes), line-length (over measure characters a line),
# tight-leading (a line pitch under leading x font-size, display text exempt), tiny-text (under ui px, or body
# text under body px), wide-tracking (over tracking em on 20+ mixed-case characters), ragged-edges (a PAGE's
# headings and long paragraphs at too many left edges), off-centre (a PAGE's content margins differ; a left
# nav exempts it), ragged-row (panels of one row ending apart), radius-mix (over radii panel radii), nested-radii
# (an inner corner rounder than its outer one, or far from concentric), numeric-align (a table column of 3+
# figures set left, or without tabular-nums), straggler (a paragraph's one-word last line; a heading's short one).
DESIGN_PREVIEW_ALIGN_JS = r"""(A => {
const T = A.T, M = A.M, out = {align: [], ink: [], measure: [], rows: 0, runs: 0};
const CS = e => getComputedStyle(e), cv = document.createElement('canvas').getContext('2d');
const vis = e => { const r = e.getBoundingClientRect(); if (r.width < 1 || r.height < 1) return false;
  for (let a = e; a; a = a.parentElement) { const s = CS(a); if (s.display === 'none' || +s.opacity === 0) return false; }
  return CS(e).visibility === 'visible'; };
const sr = e => { for (let a = e; a; a = a.parentElement) { const s = CS(a);  // visually hidden text (.sr, a clip)
  if (s.position === 'absolute' && (parseFloat(s.width) <= 1 || s.clip !== 'auto' || s.clipPath !== 'none')) return true; } return false; };
const FIELD = 'input:not([type=checkbox]):not([type=radio]):not([type=hidden]),textarea,select';
const CTL = 'button,input:not([type=hidden]):not([type=checkbox]):not([type=radio]),select,[role=button],[role=tab],a.btn';
const clear = c => /rgba\(0, 0, 0, 0\)|transparent/.test(c);
const under = e => { for (let a = e; a; a = a.parentElement) if (!clear(CS(a).backgroundColor)) return CS(a).backgroundColor; return 'rgb(255, 255, 255)'; };
// a visible box: a top and bottom border, or a fill unlike what is under it
const boxed = e => { const s = CS(e); return parseFloat(s.borderTopWidth) > 0 && s.borderTopStyle !== 'none' && parseFloat(s.borderBottomWidth) > 0
  || !clear(s.backgroundColor) && s.backgroundColor !== under(e.parentElement); };
const chrome = e => !!e.closest('[data-proto]');
const kids = e => [...e.children].filter(c => vis(c) && !sr(c) && !/absolute|fixed/.test(CS(c).position));
const leafCtl = c => c.matches(CTL) ? c : (q => q.length === 1 && c.getBoundingClientRect().height - q[0].getBoundingClientRect().height < 2 ? q[0] : null)(c.querySelectorAll(CTL));
const sig = e => { const c = typeof e.className === 'string' ? e.className.trim().split(/\s+/)[0] : ''; return e.tagName.toLowerCase() + (c ? '.' + c : ''); };
const say = e => { const t = (e.innerText || '').replace(/\s+/g, ' ').trim(); return e.tagName.toLowerCase() + ' "' + (t.length > 20 ? t.slice(0, 19) + '…' : t) + '"'; };
const box = (...es) => { let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const e of es) { if (!e) continue; const r = e.getBoundingClientRect(); x0 = Math.min(x0, r.left); y0 = Math.min(y0, r.top); x1 = Math.max(x1, r.right); y1 = Math.max(y1, r.bottom); }
  return [x0 + scrollX, y0 + scrollY, x1 - x0, y1 - y0].map(v => Math.round(v)); };
function text(e) {  // the first visible line of e: baseline, ink centre, left, style, and whether e's text wraps
  const W = () => document.createTreeWalker(e, NodeFilter.SHOW_TEXT, {acceptNode: n => n.data.trim() ? 1 : 3}); const w = W(); let n;
  while ((n = w.nextNode())) { const p = n.parentElement; if (!vis(p) || sr(p)) continue; const g = document.createRange(); g.selectNodeContents(n);
    const rs = [...g.getClientRects()].filter(r => r.width >= 1); if (!rs.length) continue; const r = rs[0], s = CS(p);
    cv.font = `${s.fontWeight} ${s.fontSize} ${s.fontFamily}`; const m = cv.measureText(n.data.trim().slice(0, 40));
    const k = r.height / (m.fontBoundingBoxAscent + m.fontBoundingBoxDescent), base = r.top + m.fontBoundingBoxAscent * k;
    const tops = new Set(), w2 = W(); let t;
    while ((t = w2.nextNode())) { if (!vis(t.parentElement) || sr(t.parentElement)) continue; const g2 = document.createRange(); g2.selectNodeContents(t);
      [...g2.getClientRects()].filter(q => q.width >= 1).forEach(q => tops.add(Math.round(q.top / 4))); }
    return {r, base, ink: base - (m.actualBoundingBoxAscent - m.actualBoundingBoxDescent) / 2, left: r.left, fs: s.fontSize, lh: s.lineHeight, ff: s.fontFamily, p, wraps: tops.size > 1}; }
  return null; }
const add = (kind, px, a, b, note) => { if (chrome(a)) return;
  out.align.push({kind, px: +px.toFixed(1), a: say(a), b: b ? say(b) : '', key: sig(a) + '|' + (b ? sig(b) : ''), box: box(a, b), note: note || ''}); };
const ink = {};
document.querySelectorAll('body *').forEach(p => { if (!vis(p) || p.closest('svg')) return; const s = CS(p), ks = kids(p); if (ks.length < 2) return;
  const row = (/flex/.test(s.display) && !/column/.test(s.flexDirection)) || /grid/.test(s.display) || s.display === 'table-row';
  if (row) { out.rows++; const L = [];
    ks.forEach(c => { const r = c.getBoundingClientRect(); const l = L.find(l => Math.min(l.b, r.bottom) - Math.max(l.t, r.top) > Math.min(l.b - l.t, r.height) / 2);
      l ? (l.i.push(c), l.t = Math.min(l.t, r.top), l.b = Math.max(l.b, r.bottom)) : L.push({t: r.top, b: r.bottom, i: [c]}); });
    L.filter(l => l.i.length > 1).forEach(l => { const ctl = l.i.map(leafCtl).filter(Boolean);
      const bare = l.i.filter(c => !boxed(c) && !c.matches(FIELD) && !c.querySelector(FIELD)).map(c => ({c, t: text(c)}))
        .filter(x => x.t && !(x.t.p.closest(CTL) && boxed(x.t.p.closest(CTL))));
      if (ctl.length > 1) { const h = ctl.map(c => c.getBoundingClientRect().height);  // controls on one line: one height; one class: one label baseline
        if (Math.max(...h) - Math.min(...h) > T.ctlH) add('control-height', Math.max(...h) - Math.min(...h), ctl[h.indexOf(Math.max(...h))], ctl[h.indexOf(Math.min(...h))]);
        const same = ctl.filter(c => c.className === ctl[0].className).map(c => ({c, t: text(c)})).filter(x => x.t);
        if (same.length > 1) { const b = same.map(x => x.t.base), d = Math.max(...b) - Math.min(...b); if (d >= T.segLabel) add('segment-label', d, same[0].c, same[1].c); } }
      if (bare.length > 1) { const b = bare.map(x => x.t.base), d = Math.max(...b) - Math.min(...b);  // bare text cells: first lines, or one baseline
        if (bare.some(x => x.t.wraps)) { if (d > T.firstLine) add('first-line', d, bare.find(x => x.t.wraps).c, (bare.find(x => !x.t.wraps) || {}).c, `align-items: ${s.alignItems}; vertical-align: ${s.verticalAlign}`); }
        else if (d >= T.labelValue && Math.abs(parseFloat(bare[0].t.fs) - parseFloat(bare[1].t.fs)) <= 4) add('label-value', d, bare[0].c, bare[1].c, d < 3 ? 'under 3px: confirm on the crop' : ''); }
      ctl.filter(boxed).forEach(c => { const cr = c.getBoundingClientRect(), cy = (cr.top + cr.bottom) / 2;  // bare single-line text beside a boxed control: on its centre
        bare.filter(x => !x.t.wraps).forEach(x => { const d = Math.abs(x.t.ink - cy); if (d >= T.beside && d < cr.height) add('beside-control', d, x.c, c, `align-items: ${s.alignItems}`); }); }); }); }
  else { const st = ks.filter(c => !/inline/.test(CS(c).display));  // stacked siblings: near-miss left edges
    for (let i = 1; i < st.length; i++) { const A2 = st[i - 1], B = st[i], ta = text(A2), tb = text(B);
      if (!ta || !tb || A2.querySelector('svg,img') && !boxed(A2)) continue;
      const la = boxed(A2) ? A2.getBoundingClientRect().left : ta.left, lb = boxed(B) ? B.getBoundingClientRect().left : tb.left, d = Math.abs(la - lb);
      if (d > T.edge[0] && d <= T.edge[1] && CS(A2).textAlign === 'start' && CS(B).textAlign === 'start') add('near-edge', d, A2, B); } } });
document.querySelectorAll(CTL + ',[class*=badge],[class*=chip]').forEach(c => {  // a label's ink centre in its own box, once per text style
  if (!vis(c) || chrome(c) || c.matches('input,select')) return; const t = text(c); if (!t || t.wraps) return;
  const r = c.getBoundingClientRect(), s = CS(c), d = t.ink - (r.top + parseFloat(s.borderTopWidth) + r.bottom - parseFloat(s.borderBottomWidth)) / 2;
  if (Math.abs(d) >= T.ink) { const k = `${t.ff.split(',')[0].replace(/["']/g, '')} ${t.fs}/${t.lh} in ${Math.round(r.height)}px`;
    (ink[k] = ink[k] || {style: k, n: 0, px: +Math.abs(d).toFixed(1), dir: d < 0 ? 'high' : 'low', eg: say(c), box: box(c)}).n++; } });
out.ink = Object.values(ink);
// The measured type and spacing rules (M1-M14), raw facts the engine words; [data-proto] chrome is left out.
const mes = (rule, key, msg, el) => out.measure.push({rule, key, msg, box: el ? box(el) : null});
const runs = [], bodyFs = {};
for (const e of document.body.querySelectorAll('*')) {
  if (e.closest('script,style,template,noscript,svg,head,[data-proto]') || ![...e.childNodes].some(c => c.nodeType === 3 && c.data.trim())) continue;
  if (!vis(e) || sr(e)) continue; const s = CS(e), t = [...e.childNodes].filter(c => c.nodeType === 3).map(c => c.data).join('').replace(/\s+/g, ' ').trim();
  const g = document.createRange(); g.selectNodeContents(e); const rs = [...g.getClientRects()].filter(r => r.width >= 1 && r.height >= 1); if (!rs.length) continue;
  const lines = []; rs.forEach(r => { const l = lines.find(l => Math.abs(l.top - r.top) < r.height / 2); l ? (l.l = Math.min(l.l, r.left), l.r = Math.max(l.r, r.right)) : lines.push({top: r.top, l: r.left, r: r.right, h: r.height}); });
  lines.sort((a, b) => a.top - b.top);
  const fs = parseFloat(s.fontSize), item = {e, s, t, fs, lines, n: lines.length, heading: /^H[1-6]$/.test(e.tagName)};
  runs.push(item); bodyFs[fs] = (bodyFs[fs] || 0) + t.length; }
out.runs = runs.length;
const body = +Object.entries(bodyFs).sort((a, b) => b[1] - a[1]).concat([['16', 0]])[0][0];
const ctlOf = e => e.closest(CTL + ',label,[role=switch],[role=checkbox],[role=radio],[role=menuitem],[role=option]');
// M1 cramped-padding: text closer than M.pad px to the edge of the box it sits in (a border or a fill of its own)
const cramped = new Map();
for (const r of runs) { let b = r.e; while (b && b !== document.body && !boxed(b)) b = b.parentElement;
  if (!b || b === document.body || chrome(b) || b.matches(FIELD) || cramped.has(b)) continue; cramped.set(b, 1);
  const s = CS(b), bb = b.getBoundingClientRect(); if (bb.width < 24 || bb.height < 16) continue;
  const g = document.createRange(), tops = new Set(); let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  const w = document.createTreeWalker(b, NodeFilter.SHOW_TEXT, {acceptNode: n => n.data.trim() ? 1 : 3}); let n;
  while ((n = w.nextNode())) { let o = n.parentElement; if (!vis(o) || sr(o)) continue; while (o && o !== b && !boxed(o)) o = o.parentElement; if (o !== b) continue;
    g.selectNodeContents(n); for (const q of g.getClientRects()) if (q.width >= 1) { if (![...tops].some(t => Math.abs(t - (q.top + q.bottom) / 2) < q.height / 2)) tops.add((q.top + q.bottom) / 2); x0 = Math.min(x0, q.left); y0 = Math.min(y0, q.top); x1 = Math.max(x1, q.right); y1 = Math.max(y1, q.bottom); } }
  if (x0 === Infinity || tops.size < 2) continue;  // a single-line box (a badge, a chip, a control) is the align check's
  const fill = !clear(s.backgroundColor) && s.backgroundColor !== under(b.parentElement), ctl = b.matches(CTL) || !!ctlOf(b);
  const side = k => fill || parseFloat(s['border' + k + 'Width']) > 0 && s['border' + k + 'Style'] !== 'none';
  const gaps = {Top: y0 - bb.top - parseFloat(s.borderTopWidth), Bottom: bb.bottom - parseFloat(s.borderBottomWidth) - y1,
                Left: x0 - bb.left - parseFloat(s.borderLeftWidth), Right: bb.right - parseFloat(s.borderRightWidth) - x1};
  const tight = Object.entries(gaps).filter(([k, v]) => side(k) && v < M.pad && v > -1 && !(ctl && (k === 'Top' || k === 'Bottom')) && !(s.display === 'table-cell' && !fill));
  if (tight.length) { const [k, v] = tight.sort((a, b) => a[1] - b[1])[0];
    mes('cramped-padding', sig(b), `${say(b)}: text ${Math.max(0, v).toFixed(1)}px from its ${k.toLowerCase()} edge, under ${M.pad}px`, b); } }
// M2 heading-rhythm: more space above a heading than below it
const hs = runs.filter(r => r.heading); let hf = [];
for (const h of hs) { const e = h.e, prev = (() => { let p = e.previousElementSibling; while (p && !vis(p)) p = p.previousElementSibling; return p; })(),
    next = (() => { let p = e.nextElementSibling; while (p && !vis(p)) p = p.nextElementSibling; return p; })();
  if (!prev || !next) continue; const r = e.getBoundingClientRect(), above = r.top - prev.getBoundingClientRect().bottom, below = next.getBoundingClientRect().top - r.bottom;
  if (above >= 0 && below >= 0 && above <= below) hf.push({h, above, below}); }
if (hf.length >= 2) mes('heading-rhythm', '-', `${hf.length} of ${hs.length} heading(s) have no more space above than below (first: ${say(hf[0].h.e)}, ${Math.round(hf[0].above)}px above, ${Math.round(hf[0].below)}px below)`, hf[0].h.e);
// M3 flat-type-steps and M3b size-count
const steps = [...new Set([body, ...hs.map(h => h.fs)])].sort((a, b) => a - b);
if (hs.length && steps.length >= 2 && steps.every((v, i) => !i || v / steps[i - 1] < M.step))
  mes('flat-type-steps', '-', `the heading and body sizes ${steps.map(v => v + 'px').join(', ')} step by under ${M.step}x each`, hs[0].e);
const sizes = [...new Set(runs.map(r => Math.round(r.fs * 2) / 2))].sort((a, b) => a - b);
if (sizes.length > M.sizes) mes('size-count', '-', `${sizes.length} font sizes on one board (${sizes.map(v => v + 'px').join(', ')}), over ${M.sizes}`, null);
for (const r of runs) { const e = r.e, s = r.s, len = r.t.length;
  // M4 line-length, M5 tight-leading, M14 straggler (paragraph text of two lines or more)
  if (r.n >= 2 && /^(block|list-item|table-cell)$/.test(s.display) && !ctlOf(e)) {
    const per = len / r.n; if (per > M.measure && r.n >= 2) mes('line-length', sig(e), `${say(e)}: about ${Math.round(per)} characters a line over ${r.n} lines, over ${M.measure}`, e);
    const pitch = (r.lines[r.n - 1].top - r.lines[0].top) / (r.n - 1);
    if (r.fs < 2 * body && pitch > 0 && pitch < M.leading * r.fs - 0.5) mes('tight-leading', sig(e) + '|' + r.fs, `${say(e)}: ${r.fs}px text on a ${pitch.toFixed(1)}px line pitch, under ${M.leading}x`, e);
    const last = r.lines[r.n - 1], prev = r.lines[r.n - 2], words = r.t.split(' ');
    if (words.length >= 4) { const tail = words[words.length - 1]; cv.font = `${s.fontWeight} ${s.fontSize} ${s.fontFamily}`;
      if (last.r - last.l <= cv.measureText(tail).width + 2 && !r.heading) mes('straggler', sig(e), `${say(e)}: its last line holds one word ("${tail.slice(0, 16)}"); text-wrap: pretty`, e);
      else if (r.heading && last.r - last.l < (prev.r - prev.l) / 3) mes('straggler', sig(e), `${say(e)}: the heading's last line is under a third of the line above; text-wrap: balance`, e); } }
  // M6 tiny-text: body text under M.body px, any text under M.ui px
  if (r.fs < M.ui && len >= 1) mes('tiny-text', sig(e) + '|' + r.fs, `${say(e)}: ${r.fs}px text, under ${M.ui}px`, e);
  else if (r.fs < M.body && len >= 40 && /^(P|LI|DD|BLOCKQUOTE)$/.test(e.tagName)) mes('tiny-text', sig(e) + '|' + r.fs, `${say(e)}: ${r.fs}px body text, under ${M.body}px`, e);
  // M7 wide-tracking
  const ls = parseFloat(s.letterSpacing) || 0; if (len > 20 && s.textTransform !== 'uppercase' && ls > M.tracking * r.fs)
    mes('wide-tracking', sig(e), `${say(e)}: letter-spacing ${(ls / r.fs).toFixed(2)}em on ${len} characters of mixed case, over ${M.tracking}em`, e); }
// M8 ragged-edges: too many left edges among headings and long paragraphs
const lefts = runs.filter(r => (r.heading || r.t.length >= 60 && r.fs >= 14) && /start|left/.test(r.s.textAlign)).map(r => r.lines[0].l).sort((a, b) => a - b);
if (A.page && lefts.length >= M.rag[1]) { const cl = []; lefts.forEach(x => { const c = cl.find(c => Math.abs(c.x - x) <= M.rag[2]); c ? c.n++ : cl.push({x, n: 1}); });
  const top3 = cl.map(c => c.n).sort((a, b) => b - a).slice(0, 3).reduce((a, b) => a + b, 0);
  if (cl.length > M.rag[0] && top3 / lefts.length < M.rag[3]) mes('ragged-edges', '-', `${lefts.length} headings and paragraphs start at ${cl.length} left edges; the three most used hold ${Math.round(100 * top3 / lefts.length)}%`, null); }
// M9 off-centre: the content's left and right margins in a PAGE differ
if (A.page) { let l = Infinity, rr = -Infinity, side = false;
  for (const r of runs) { const b = r.e.getBoundingClientRect(); l = Math.min(l, b.left); rr = Math.max(rr, b.right); }
  for (const e of document.querySelectorAll('nav,aside,[role=navigation]')) { const b = e.getBoundingClientRect(); if (!chrome(e) && vis(e) && b.left <= 1 && b.height >= innerHeight / 2) side = true; }
  const W = innerWidth, ml = l, mr = W - rr, d = Math.abs(ml - mr);
  if (!side && l < Infinity && d >= Math.max(M.centre, 0.045 * W) && Math.max(ml, mr) >= 0.07 * W)
    mes('off-centre', '-', `the content's margins are ${Math.round(ml)}px left and ${Math.round(mr)}px right in ${W}px`, null); }
// M10 ragged-row, M11 radius-mix, M12 nested-radii: panels (boxed, not controls, at least 120x48)
const panels = [...document.body.querySelectorAll('*')].filter(e => !e.closest('[data-proto],svg') && vis(e) && boxed(e) && !e.matches(CTL + ',' + FIELD) && !ctlOf(e)
  && (r => r.width >= 120 && r.height >= 48)(e.getBoundingClientRect()) && !/^(TD|TH|TR|TBODY|THEAD|TABLE)$/.test(e.tagName));
const radii = {}; panels.forEach(e => { const v = parseFloat(CS(e).borderTopLeftRadius) || 0; if (v > 0) radii[v] = (radii[v] || 0) + 1; });
const used = Object.entries(radii).filter(([, n]) => n >= 2).map(([v]) => +v).sort((a, b) => a - b);
if (used.length > M.radii) mes('radius-mix', '-', `${used.length} panel radii (${used.map(v => v + 'px').join(', ')}), over ${M.radii}`, null);
const rowsDone = new Set();
for (const e of panels) { const p = e.parentElement; if (!p || rowsDone.has(p)) continue; const s = CS(p);
  if (!((/flex/.test(s.display) && !/column/.test(s.flexDirection)) || /grid/.test(s.display))) continue; rowsDone.add(p);
  const sib = [...p.children].filter(c => panels.includes(c)), lines = [];
  sib.forEach(c => { const r = c.getBoundingClientRect(), l = lines.find(l => Math.abs(l.t - r.top) <= 4); l ? l.i.push(c) : lines.push({t: r.top, i: [c]}); });
  for (const l of lines) { if (l.i.length < 2) continue; const bs = l.i.map(c => c.getBoundingClientRect()), hi = Math.max(...bs.map(b => b.height)), d = Math.max(...bs.map(b => b.bottom)) - Math.min(...bs.map(b => b.bottom));
    if (d > Math.max(M.ragRow, 0.12 * hi)) mes('ragged-row', sig(l.i[0]), `${l.i.length} panels in one row (first ${say(l.i[0])}) end ${Math.round(d)}px apart: cards that share a row share a bottom edge`, p); } }
for (const e of panels) { const rc = parseFloat(CS(e).borderTopLeftRadius) || 0; if (!rc) continue; let p = e.parentElement; while (p && p !== document.body && !boxed(p)) p = p.parentElement;
  if (!p || p === document.body || chrome(p)) continue; const rp = parseFloat(CS(p).borderTopLeftRadius) || 0; if (!rp) continue;
  const a = e.getBoundingClientRect(), b = p.getBoundingClientRect(), gap = Math.min(a.left - b.left, a.top - b.top, b.right - a.right, b.bottom - a.bottom);
  if (gap < 0 || gap > M.nest) continue;
  if (rc > rp + 0.5) mes('nested-radii', sig(e), `${say(e)}: radius ${rc}px inside ${sig(p)}'s ${rp}px, ${Math.round(gap)}px in: an inner corner is no rounder than the outer one`, e);
  else if (rp - gap > 0 && Math.abs(rc - (rp - gap)) > 2) mes('nested-radii', sig(e), `${say(e)}: radius ${rc}px ${Math.round(gap)}px inside a ${rp}px corner: concentric is about ${Math.round(rp - gap)}px`, e); }
// M13 numeric-align: a column of figures set left, or without tabular figures
const NUM = /^[+\-\u2212\u00B1]?[$\u20AC\u00A3\u00A5\u20A9]?\s?\d[\d.,:\s]*(%|\uC6D0|\uAC74|\uACF3|\uBA85|\uAC1C|px|ms|s|x)?$/;
for (const t of document.querySelectorAll('table')) { if (chrome(t) || !vis(t)) continue; const cols = {};
  for (const tr of t.rows) [...tr.cells].forEach((c, i) => { const s = (c.innerText || '').trim(); if (vis(c) && NUM.test(s) && c.tagName === 'TD') (cols[i] = cols[i] || []).push(c); });
  for (const [i, cs2] of Object.entries(cols)) { if (cs2.length < M.figures) continue;
    const left = cs2.filter(c => /^(left|start)$/.test(CS(c).textAlign)), plain = cs2.filter(c => { const q = c.querySelector('*') || c; return !/tabular-nums/.test(CS(q).fontVariantNumeric) && !/tabular-nums/.test(CS(c).fontVariantNumeric); });
    if (left.length === cs2.length) mes('numeric-align', 'left|' + sig(t) + '|' + i, `column ${+i + 1} of ${say(t)}: ${cs2.length} figures set left (figures set right, or on a decimal)`, cs2[0]);
    if (plain.length === cs2.length) mes('numeric-align', 'tab|' + sig(t) + '|' + i, `column ${+i + 1} of ${say(t)}: ${cs2.length} figures without font-variant-numeric: tabular-nums`, cs2[0]); } }
return out;
})"""
# The measured checks, run on the settled page right before its screenshot. Raw facts only; the engine
# words them. contrast: every visible text run (one per element) against the background its ancestors
# paint under it, alpha-composited (color alpha, background alpha, ancestor opacity) over the white
# canvas; colors in any syntax are read by painting them on a 1x1 canvas. A background image, gradient,
# filter or blend mode in the way makes it unmeasured, never a guess. The canvas-only prototype chrome
# ([data-proto]: the state bar, the board-link strip) is exempt from the target check, never from the
# others: it must still read, name its buttons and link somewhere real.
DESIGN_PREVIEW_CHECKS_JS = "(()=>{" + DESIGN_PREVIEW_JS_HELPERS + DESIGN_PREVIEW_CONTRAST_JS + r"""
const out = {contrast: [], unmeasured: [], target: [], clipped: [], links: [], images: [], names: [], texts: 0, targets: 0, fields: 0,
             ntc: [], ntc_unmeasured: [], boundaries: 0, statebar: [], bars: 0};
contrastIn(document.body, out);
const inRun = e => { if (!e.matches('a[href],[role=link]') || cs(e).display !== 'inline') return false;
  let p = e.parentElement; while (p && cs(p).display === 'inline') p = p.parentElement;
  return !!p && (p.innerText || '').replace(e.innerText || '', '').trim().length > 0; };
for (const e of controls()) {
  out.targets++;
  if (inRun(e) || e.closest('[data-proto]')) continue;
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const b of [e, ...(e.labels || [])]) { const r = b.getBoundingClientRect(); if (!r.width && !r.height) continue;
    x0 = Math.min(x0, r.left); y0 = Math.min(y0, r.top); x1 = Math.max(x1, r.right); y1 = Math.max(y1, r.bottom); }
  const w = x1 - x0, h = y1 - y0;
  if (w < 43.99 || h < 43.99) out.target.push({el: desc(e), cls: tagOf(e), w: Math.round(w * 10) / 10, h: Math.round(h * 10) / 10, labelled: !!(e.labels && e.labels.length)});
}
""" + DESIGN_PREVIEW_NTC_JS + r"""
const ownText = e => [...e.childNodes].some(c => c.nodeType === 3 && c.data.trim())
  || (e.children.length > 0 && [...e.children].every(c => cs(c).display === 'inline') && !!e.textContent.trim());
for (const e of document.body.querySelectorAll('*')) {
  if (e.closest('script,style,template,noscript,svg')) continue;
  const s = cs(e), ox = /^(hidden|clip)$/.test(s.overflowX), oy = /^(hidden|clip)$/.test(s.overflowY);
  if (!(ox || oy) || s.display === 'inline' || s.display === 'contents' || !boxed(e) || !ownText(e)) continue;
  const w = ox && e.scrollWidth > e.clientWidth + 1 && s.textOverflow !== 'ellipsis';
  const h = oy && e.scrollHeight > e.clientHeight + 1 && (s.webkitLineClamp || 'none') === 'none';
  if (w || h) out.clipped.push({el: desc(e), sw: e.scrollWidth, sh: e.scrollHeight, cw: e.clientWidth, ch: e.clientHeight, axis: w && h ? 'both' : w ? 'x' : 'y'});
}
for (const a of document.querySelectorAll('a[href]')) { const h = a.getAttribute('href').trim(), item = {el: desc(a), href: h};
  if (h === '' || h === '#') item.anchor = 'placeholder';
  else if (h.startsWith('#')) { let id = h.slice(1); try { id = decodeURIComponent(id); } catch (x) {}
    item.anchor = id === 'top' || document.getElementById(id) || document.getElementsByName(id).length ? 'ok' : 'missing'; }
  out.links.push(item); }
for (const i of document.images) if (i.complete && i.naturalWidth === 0) out.images.push({el: desc(i), src: clip(i.getAttribute('src') || '', 80)});
const byIds = e => (e.getAttribute('aria-labelledby') || '').split(/\s+/).filter(Boolean).some(id => { const r = document.getElementById(id); return !!r && !!textOf(r); });
for (const e of document.querySelectorAll('button,a[href],[role=button],[role=link]')) {
  if (!boxed(e) || hiddenIn(e)) continue;
  const named = byIds(e) || !!(e.getAttribute('aria-label') || '').trim() || !!textOf(e) || !!(e.getAttribute('title') || '').trim()
    || [...e.querySelectorAll('img[alt]')].some(i => i.getAttribute('alt').trim());
  if (!named) out.names.push({el: desc(e), kind: e.matches('a[href],[role=link]') ? 'link' : 'button'}); }
for (const e of document.querySelectorAll('input,select,textarea')) {
  if (e.matches('input[type=hidden],input[type=submit],input[type=button],input[type=reset],input[type=image]') || !boxed(e) || hiddenIn(e)) continue;
  if (e.matches('textarea,input:not([type]),input[type=text],input[type=email],input[type=password],input[type=search],input[type=tel],input[type=url],input[type=number]')) out.fields++;
  const named = [...(e.labels || [])].some(l => !!textOf(l)) || !!(e.getAttribute('aria-label') || '').trim() || byIds(e);
  if (!named) out.names.push({el: desc(e), kind: 'field', placeholder: clip(e.getAttribute('placeholder') || '', 30)}); }
if (window.__dcAlign) { try { out.align = (""" + DESIGN_PREVIEW_ALIGN_JS + r""")(window.__dcAlign); } catch (x) { out.align = {failed: String(x)}; }
  delete window.__dcAlign; }
return out; })()"""
# --click: the visible DOM's identity (each shown element's tag, class, style, its open/expanded/
# selected/current/disabled attributes and every shown text run, hashed; a checkbox's checked state and
# a field's value are left out: a state is a different screen, not a different value, so independent
# toggles do not multiply into combinations -- the one bit kept is whether every visible text field
# holds text, since a complete form leads somewhere an empty one does not) and the controls a click can try: the interactive set
# minus links that leave the board (a link is not a state) and fields that need typing or a native
# picker, each visible, enabled, inside the viewport and topmost at its centre. Beside them (v60, P36.S8C):
# - page: which page of the board is on screen, so a click that moves to another screen of a flow board
#   is told apart from a state change on the same page. It is the name of the visible group in the
#   canvas-only state bar ([data-proto="state-bar"] [role=group], by aria-label or aria-labelledby),
#   else the text of the first visible h1 outside [data-proto], else "" (one page);
# - anchors: the document position of each visible header, nav and main (by element or role) outside
#   [data-proto], for the layout-shift check;
# - each click's box (w, h), tag and first class (t), whether it is prototype chrome (proto) or a state-bar preset (bar), and
#   its list: a control repeated in three or more alike siblings (same tag and class, as a <sc-for>
#   renders them) carries the list's id, its index and the list's length, so rows can be sampled and
#   compared;
# - fields: the visible, enabled text fields outside [data-proto] the type pass fills, each with a
#   realistic sample string chosen from its type, autocomplete, name and label, and whether it is empty.
DESIGN_PREVIEW_STATE_JS = "(()=>{" + DESIGN_PREVIEW_JS_HELPERS + r"""
const range = document.createRange(), parts = [];
const walk = e => { for (const c of e.childNodes) {
  if (c.nodeType === 3) { if (c.data.trim() && shown(e)) { range.selectNodeContents(c); if (range.getClientRects().length) parts.push('"' + c.data.trim()); } continue; }
  if (c.nodeType !== 1 || /^(SCRIPT|STYLE|TEMPLATE|HEAD)$/.test(c.tagName)) continue;
  const s = cs(c); if (s.display === 'none') continue;
  if (c.getClientRects().length && shown(c)) parts.push('<' + c.tagName + '|' + (c.getAttribute('class') || '') + '|' + (c.getAttribute('style') || '') + '|' + s.visibility + '|'
    + ['aria-expanded', 'aria-selected', 'aria-current', 'open', 'disabled'].map(a => c.hasAttribute(a) ? a + '=' + c.getAttribute(a) : '').join(','));
  walk(c); parts.push('>'); } };
walk(document.body);
const key = e => { const p = []; for (; e && e.parentElement; e = e.parentElement) p.unshift([...e.parentElement.children].indexOf(e)); return p.join('.'); };
const proto = e => !!e.closest('[data-proto]');
const nameOf = g => (g.getAttribute('aria-label') || '').trim() || (g.getAttribute('aria-labelledby') || '').split(/\s+/).filter(Boolean)
  .map(id => { const r = document.getElementById(id); return r ? textOf(r) : ''; }).join(' ').trim();
let page = '';
for (const g of document.querySelectorAll('[data-proto="state-bar"] [role=group]')) if (boxed(g) && nameOf(g)) { page = 'bar:' + clip(nameOf(g), 60); break; }
if (!page) { const t = [...document.querySelectorAll('h1')].find(e => boxed(e) && !proto(e)); if (t) page = 'h1:' + clip(textOf(t), 60); }
const anchors = [];
for (const e of document.querySelectorAll('header,nav,main,[role=banner],[role=navigation],[role=main]')) {
  if (proto(e) || !boxed(e)) continue;
  const r = e.getBoundingClientRect();
  anchors.push({key: key(e), el: tagOf(e), x: Math.round(r.left + scrollX), y: Math.round(r.top + scrollY)}); }
const sig = a => a.tagName + '.' + (a.getAttribute('class') || '');
const listOf = e => { for (let a = e; a.parentElement && a !== document.body; a = a.parentElement) {
    const p = a.parentElement, s = sig(a), alike = [...p.children].filter(c => sig(c) === s);
    if (alike.length < 3) continue;
    const rel = []; for (let x = e; x !== a; x = x.parentElement) rel.unshift([...x.parentElement.children].indexOf(x));
    return {list: key(p) + '/' + s + '/' + rel.join('.'), idx: alike.indexOf(a), of: alike.length}; }
  return null; };
const topAt = e => { const r = e.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
  if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) return 'outside';
  const top = document.elementFromPoint(x, y); return top && (top === e || e.contains(top)) ? [x, y, r] : 'covered'; };
const skip = 'a[href]:not([href^="#"]),select,textarea,input:not([type=checkbox]):not([type=radio]):not([type=submit]):not([type=button]):not([type=reset]):not([type=image])';
const clicks = []; let covered = 0, outside = 0;
for (const e of controls()) {
  if (e.matches(skip) || e.closest('a[href]:not([href^="#"])')) continue;
  const at = topAt(e);
  if (at === 'outside') { outside++; continue; }
  if (at === 'covered') { covered++; continue; }
  const [x, y, r] = at, chrome = proto(e);
  const named = textOf(e) || [...(e.labels || [])].map(textOf).join(' ') || e.getAttribute('aria-label') || e.getAttribute('title')
    || (e.matches('input[type=submit],input[type=button],input[type=reset]') ? e.value : '') || tagOf(e) + (e.type ? '[' + e.type + ']' : '');
  const c = {key: key(e), label: clip(named, 32).replace(/"/g, "'"), x: x, y: y, w: Math.round(r.width * 10) / 10, h: Math.round(r.height * 10) / 10,
             t: e.tagName + '.' + ((e.getAttribute('class') || '').trim().split(/\s+/)[0] || ''), proto: chrome, bar: chrome && !!e.closest('[data-proto="state-bar"]')};
  const l = chrome || e.matches('input,label') || e.closest('label') ? null : listOf(e);
  if (l) Object.assign(c, l);
  clicks.push(c); }
const word = () => { for (const li of document.querySelectorAll('li,[role=listitem],[role=row]')) { if (!boxed(li) || proto(li)) continue;
    const m = /[\p{L}]{4,}/u.exec(textOf(li)); if (m) return m[0].slice(0, 4).toLowerCase(); } return 'a'; };
const sample = e => { const t = (e.getAttribute('type') || 'text').toLowerCase();
  const h = [e.getAttribute('name'), e.id, e.getAttribute('autocomplete'), e.getAttribute('placeholder'), e.getAttribute('aria-label'),
             ...[...(e.labels || [])].map(textOf)].join(' ').toLowerCase();
  if (t === 'email' || /e-?mail/.test(h)) return 'sam.okafor@example.com';
  if (t === 'tel' || /phone|mobile|\btel\b/.test(h)) return '020 7946 0958';
  if (t === 'number') return '2';
  if (t === 'url' || /website|\burl\b/.test(h)) return 'https://example.com';
  if (t === 'password') return 'correct-horse-7';
  if (t === 'search' || e.getAttribute('role') === 'searchbox' || /search|find|filter/.test(h)) return word();
  if (/post|zip/.test(h)) return '10115';
  if (/name/.test(h)) return 'Sam Okafor';
  if (e.tagName === 'TEXTAREA') return 'Could I pick it up after work, around six?';
  return 'Sample text'; };
const fields = []; let pickers = 0;
for (const e of controls()) {
  if (proto(e) || e.readOnly) continue;
  if (e.matches('select,input[type=date],input[type=time],input[type=datetime-local],input[type=month],input[type=week],input[type=color],input[type=file],input[type=range]')) { pickers++; continue; }
  if (!e.matches('textarea,input:not([type]),input[type=text],input[type=email],input[type=password],input[type=search],input[type=tel],input[type=url],input[type=number]')) continue;
  const at = topAt(e); if (!Array.isArray(at)) continue;
  const named = [...(e.labels || [])].map(textOf).join(' ') || e.getAttribute('aria-label') || e.getAttribute('placeholder') || tagOf(e);
  fields.push({key: key(e), label: clip(named, 32).replace(/"/g, "'"), x: at[0], y: at[1], text: sample(e), empty: !e.value}); }
if (fields.length && fields.every(f => !f.empty)) parts.push('|every field filled');
const str = parts.join('\n'); let h1 = 0x811c9dc5, h2 = 0x9747b28c;
for (let i = 0; i < str.length; i++) { const k = str.charCodeAt(i); h1 = Math.imul(h1 ^ k, 0x01000193); h2 = Math.imul(h2 ^ k, 0x5bd1e995); h2 ^= h2 >>> 15; }
return {hash: (h1 >>> 0).toString(16) + (h2 >>> 0).toString(16) + ':' + str.length, clicks: clicks, fields: fields, pickers: pickers,
        page: page, anchors: anchors, covered: covered, outside: outside};
})()"""
# The hover pass (with --click, on PAGE boards, in the frame view): list the buttons and links a pointer
# can rest on (visible, enabled, outside [data-proto], inside the viewport and topmost at the centre),
# each with a signature (tag, class, text) so a control seen in an earlier state is hovered once, and
# the contrast failures its text already has. Transitions are switched off for the pass, so the hover
# style is the computed style at once; DESIGN_PREVIEW_HOVER_DONE_JS switches them back.
DESIGN_PREVIEW_HOVER_JS = "(()=>{" + DESIGN_PREVIEW_JS_HELPERS + DESIGN_PREVIEW_CONTRAST_JS + r"""
const key = e => { const p = []; for (; e && e.parentElement; e = e.parentElement) p.unshift([...e.parentElement.children].indexOf(e)); return p.join('.'); };
const byKey = k => { let e = document.documentElement; for (const i of k.split('.')) { if (i === '') continue; e = e && e.children[+i]; } return e || null; };
const fails = e => { const out = {contrast: [], unmeasured: [], texts: 0}; contrastIn(e, out); return out.contrast; };
window.__dcHover = k => { const e = byKey(k); return e ? fails(e) : []; };
if (!document.getElementById('__dc-hover-style')) { const st = document.createElement('style'); st.id = '__dc-hover-style';
  st.textContent = '*,*::before,*::after{transition:none!important;animation-duration:0s!important}'; document.head.appendChild(st); }
const out = [];
for (const e of document.querySelectorAll('a[href],button,[role=button],[role=link],summary')) {
  if (!boxed(e) || off(e) || e.closest('[data-proto]') || hiddenIn(e)) continue;
  const r = e.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
  if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) continue;
  const top = document.elementFromPoint(x, y); if (!top || !(top === e || e.contains(top))) continue;
  out.push({key: key(e), el: desc(e), sig: e.tagName + '|' + (e.getAttribute('class') || '') + '|' + clip(textOf(e), 40), x: x, y: y,
            before: fails(e).map(f => f.el + '|' + f.fg + '|' + f.bg)}); }
return out; })()"""
DESIGN_PREVIEW_HOVER_DONE_JS = "(()=>{const s=document.getElementById('__dc-hover-style');if(s)s.remove();delete window.__dcHover;return 1;})()"
# The type pass: focus the field with this key and select its text, so the sample typed next replaces it.
DESIGN_PREVIEW_FOCUS_JS = ("(k=>{let e=document.documentElement;for(const i of k.split('.')){if(i==='')continue;e=e&&e.children[+i];}"
                           "if(!e)return 0;e.focus();if(e.select)e.select();return 1;})")
# Run after every load in --click: a mark that tells a navigation away apart, and a form submit that
# never leaves the board (the design's own submit handler still runs).
DESIGN_PREVIEW_GUARD_JS = ("(()=>{window.__dcPreview=1;if(!window.__dcGuard){window.__dcGuard=1;"
                           "addEventListener('submit',e=>e.preventDefault(),true);}return 1;})()")
# --click, installed before each load's scripts: tracks the short timers (30 ms to 3 s) a page sets, so
# a click that schedules its outcome (a fake save: "Saving..." then "Saved") is waited for; a ticking
# clock's timers set before the click are not waited on.
DESIGN_PREVIEW_TIMERS_JS = r"""(() => { if (window.__dcTimers) return;
const st = window.setTimeout, ct = window.clearTimeout, live = new Map(); let seq = 0;
window.__dcTimers = {seq: () => seq, after: m => [...live.values()].filter(n => n > m).length};
window.setTimeout = function (f, d, ...a) { if (typeof f !== 'function') return st(f, d, ...a);
  const ms = Number(d) || 0; let id; id = st(function () { live.delete(id); return f.apply(this, arguments); }, d, ...a);
  if (ms >= 30 && ms <= 3000) live.set(id, ++seq); return id; };
window.clearTimeout = function (id) { live.delete(id); return ct(id); }; })()"""
# A click's state is settled when the DOM stops changing, the short timers the click set have fired (up
# to 3 s), and its finite animations (a fade, a slide) have run (up to a second).
DESIGN_PREVIEW_ANIMATIONS_JS = ("Promise.race([Promise.all(document.getAnimations().filter(a=>a.effect&&"
                                "a.effect.getComputedTiming().endTime!==Infinity).map(a=>a.finished.catch(()=>0))),"
                                "new Promise(r=>setTimeout(r,1000))]).then(()=>1)")
# v61 (P37.S6): installed before every load's scripts: remembers each element given a click, mousedown,
# pointerdown, mouseup or pointerup listener with addEventListener (the runtime's onclick= is a property,
# read directly), for the keyboard check's click-only controls.
DESIGN_PREVIEW_LISTENERS_JS = r"""(() => { if (window.__dcClick) return; const seen = new WeakSet(); window.__dcClick = seen;
const add = EventTarget.prototype.addEventListener;
EventTarget.prototype.addEventListener = function (t, f, o) {
  if (this instanceof Element && /^(click|mousedown|pointerdown|mouseup|pointerup)$/.test(t)) seen.add(this);
  return add.call(this, t, f, o); }; })()"""
# 200% text (WCAG 1.4.4): every element's computed font-size read first, then each set to k times it
# (!important, in px), so nothing compounds; rem lengths follow the root's.
DESIGN_PREVIEW_TEXT_SCALE_JS = ("(k=>{const all=[document.documentElement,document.body,...document.body.querySelectorAll('*')]"
                                ".filter(e=>e&&!/^(SCRIPT|STYLE|TEMPLATE|HEAD|META|LINK|TITLE)$/.test(e.tagName));"
                                "const px=all.map(e=>parseFloat(getComputedStyle(e).fontSize));"
                                "all.forEach((e,i)=>{if(px[i]>0)e.style.setProperty('font-size',(px[i]*k)+'px','important');});"
                                "return all.length;})")
# overprint (WCAG 1.4.4/1.4.10), in the 320 px and 200%-text views: two text runs of different elements,
# neither containing the other, whose glyph boxes (Range.getClientRects, the middle half of each line box
# so stacked lines that merely touch do not count, cut to every clipping ancestor: overflow, clip-path,
# clip -- a visually hidden label is cut to its 1px box) cross by >= 2px across
# and >= 1px down, where the crossing is visible: the topmost element at its centre belongs to one of the
# two and nothing opaque between it and the other hides that one. [data-proto] chrome is left out.
DESIGN_PREVIEW_OVERPRINT_JS = "(()=>{" + DESIGN_PREVIEW_JS_HELPERS + DESIGN_PREVIEW_CONTRAST_JS + r"""
const runs = [], clips = new Map(), ids = new Map(), range = document.createRange();
const clipOf = e => { if (!e || e === document.body || e === document.documentElement) return null;
  if (clips.has(e)) return clips.get(e);
  const s = cs(e); let c = s.position === 'fixed' ? null : clipOf(e.parentElement);
  if (s.overflowX !== 'visible' || s.overflowY !== 'visible' || s.clipPath !== 'none' || (s.clip && s.clip !== 'auto')) { const r = e.getBoundingClientRect();
    c = c ? [Math.max(c[0], r.left), Math.max(c[1], r.top), Math.min(c[2], r.right), Math.min(c[3], r.bottom)] : [r.left, r.top, r.right, r.bottom]; }
  clips.set(e, c); return c; };
const seenBy = e => e.checkVisibility ? e.checkVisibility({opacityProperty: true, visibilityProperty: true}) : cs(e).visibility === 'visible';
const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
while (walker.nextNode()) { const n = walker.currentNode, e = n.parentElement;
  if (!e || !n.data.trim() || e.closest('script,style,template,noscript,head,[data-proto]') || !seenBy(e)) continue;
  range.selectNodeContents(n); const c = clipOf(e);
  for (const r of range.getClientRects()) { if (r.width < 2 || r.height < 2) continue;
    let b = [r.left, r.top + r.height / 4, r.right, r.bottom - r.height / 4];
    if (c) b = [Math.max(b[0], c[0]), Math.max(b[1], c[1]), Math.min(b[2], c[2]), Math.min(b[3], c[3])];
    if (b[2] - b[0] >= 1 && b[3] - b[1] >= 1) runs.push({e: e, b: b}); } }
runs.sort((p, q) => p.b[1] - q.b[1]);
const idOf = e => { if (!ids.has(e)) ids.set(e, ids.size); return ids.get(e); };
const pairs = new Map(); let found = 0;
for (let i = 0; i < runs.length; i++) { const A = runs[i];
  for (let j = i + 1; j < runs.length && runs[j].b[1] < A.b[3]; j++) { const B = runs[j];
    if (A.e === B.e || A.e.contains(B.e) || B.e.contains(A.e)) continue;
    const x0 = Math.max(A.b[0], B.b[0]), x1 = Math.min(A.b[2], B.b[2]), y0 = Math.max(A.b[1], B.b[1]), y1 = Math.min(A.b[3], B.b[3]);
    if (x1 - x0 < 2 || y1 - y0 < 1) continue;
    const key = Math.min(idOf(A.e), idOf(B.e)) + ':' + Math.max(idOf(A.e), idOf(B.e));
    if (pairs.has(key)) continue;
    const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    if (cx >= 0 && cy >= 0 && cx < innerWidth && cy < innerHeight) {
      const top = document.elementFromPoint(cx, cy); if (!top) continue;
      const back = A.e.contains(top) ? B.e : B.e.contains(top) ? A.e : null;
      if (!back && !(top.contains(A.e) && top.contains(B.e))) continue;
      let hidden = false;
      if (back) for (let a = top; a && !a.contains(back); a = a.parentElement) { const t = cs(a), bc = color(t.backgroundColor);
        if ((bc && bc[3] >= 1) || t.backgroundImage !== 'none') { hidden = true; break; } }
      if (hidden) continue; }
    found++;
    if (pairs.size < 60) pairs.set(key, {a: desc(A.e), b: desc(B.e), w: Math.round(x1 - x0), h: Math.round(y1 - y0)}); } }
return {runs: runs.length, pairs: [...pairs.values()], found: found}; })()"""
# keyboard (WCAG 2.1.1), on interactive boards from the settled state: the controls Tab must reach
# (the target set, outside [data-proto], not aria-hidden, not tabindex < 0, inside an open modal when
# one is), a focusin recorder, and the click-only controls: an element with a click/mousedown/pointerdown
# listener (the runtime's on* property, or one added with addEventListener) or, failing that, a pointer
# cursor its parent does not have, that is neither natively focusable nor tabindex >= 0, sits inside no
# focusable control or label and holds none (a container of controls delegating clicks is not one), and
# covers under a quarter of the viewport.
DESIGN_PREVIEW_KEYS_JS = "(()=>{" + DESIGN_PREVIEW_JS_HELPERS + r"""
const modal = [...document.querySelectorAll('[aria-modal="true"],dialog[open]')].find(boxed) || null;
const negative = e => e.hasAttribute('tabindex') && parseInt(e.getAttribute('tabindex'), 10) < 0;
const ctl = controls().filter(e => !e.closest('[data-proto]') && !hiddenIn(e) && !negative(e) && (!modal || modal.contains(e)));
const L = window.__dcClick;
const handler = e => ['onclick', 'onmousedown', 'onpointerdown', 'onmouseup', 'onpointerup'].some(p => typeof e[p] === 'function') || (!!L && L.has(e));
const FOCUS = SEL + ',label,[contenteditable],[tabindex]:not([tabindex^="-"])';
const area = innerWidth * innerHeight, only = [];
for (const e of document.body.querySelectorAll('*')) {
  if (e.closest('[data-proto],script,style,template,noscript') || (e.closest('svg') && e.tagName.toLowerCase() !== 'svg')) continue;
  const own = handler(e), ptr = !own && cs(e).cursor === 'pointer' && !(e.parentElement && cs(e.parentElement).cursor === 'pointer');
  if (!own && !ptr) continue;
  if (e.matches(FOCUS) || e.isContentEditable || (e.parentElement && e.parentElement.closest(FOCUS)) || e.querySelector(FOCUS)) continue;
  if (!boxed(e) || hiddenIn(e) || off(e) || (modal && !modal.contains(e))) continue;
  const r = e.getBoundingClientRect(), first = e.getClientRects()[0];
  if (!first || r.width * r.height > area / 4) continue;
  const cls = typeof e.className === 'string' ? e.className.trim().split(/\s+/)[0] : '';
  const key = []; for (let a = e; a && a.parentElement; a = a.parentElement) key.unshift([...a.parentElement.children].indexOf(a));
  only.push({el: desc(e), sig: e.tagName.toLowerCase() + (cls ? '.' + cls : ''), how: own ? 'a click handler' : 'a pointer cursor', key: key.join('.')}); }
window.__dcKeys = {ctl: ctl, seen: new Set(), first: null, wrapped: false};
if (!window.__dcKeysOn) { window.__dcKeysOn = 1;
  addEventListener('focusin', ev => { const k = window.__dcKeys; if (!k) return;
    if (k.first === ev.target) k.wrapped = true; else if (!k.first) k.first = ev.target; k.seen.add(ev.target); }, true); }
if (document.activeElement && document.activeElement !== document.body) document.activeElement.blur();
const stops = [...document.querySelectorAll(SEL + ',[tabindex]:not([tabindex^="-"])')].filter(e => boxed(e) && !off(e)).length;
return {controls: ctl.length, stops: stops, only: only, modal: !!modal}; })()"""
DESIGN_PREVIEW_KEYS_DONE_JS = "(()=>{" + DESIGN_PREVIEW_JS_HELPERS + r"""
const k = window.__dcKeys; if (!k) return null;
const missed = k.ctl.filter(e => e.isConnected && boxed(e) && !off(e) && !k.seen.has(e));
return {wrapped: k.wrapped, reached: k.seen.size, missed: missed.map(desc)}; })()"""
# The keyboard probe: scroll the element with this key into view; the centre of its first box, or null.
DESIGN_PREVIEW_POINT_JS = ("(k=>{let e=document.documentElement;for(const i of k.split('.')){if(i==='')continue;e=e&&e.children[+i];}"
                           "if(!e)return null;e.scrollIntoView({block:'center',inline:'center'});const r=e.getClientRects()[0];"
                           "return r?[r.left+r.width/2,r.top+r.height/2]:null;})")
# What a click opened: the visible dialogs, menus, tooltips, listboxes and popovers outside [data-proto].
DESIGN_PREVIEW_OVERLAYS_JS = "(()=>{" + DESIGN_PREVIEW_JS_HELPERS + r"""
return [...document.querySelectorAll('[role=dialog],[role=alertdialog],[role=menu],[role=tooltip],[role=listbox],[popover],[aria-modal="true"],dialog[open]')]
  .filter(e => boxed(e) && !e.closest('[data-proto]')).map(e => (e.getAttribute('role') || e.tagName.toLowerCase()) + ' ' + desc(e)); })()"""


def design_preview_browser(given):
    """The browser executable: --browser, else $AGENTIC_DESIGN_BROWSER (either one, when named, is the
    only candidate: a named browser that is not there is no browser), else the known Chrome/Chromium
    paths on macOS and Linux, else chromium/google-chrome on PATH. None when there is none."""
    for value in (given, os.environ.get(DESIGN_PREVIEW_BROWSER_ENV)):
        if value:
            path = os.path.expanduser(value)
            return shutil.which(path) or (path if os.path.isfile(path) and os.access(path, os.X_OK) else None)
    for candidate in DESIGN_PREVIEW_BROWSERS:
        path = os.path.expanduser(candidate)
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    for name in DESIGN_PREVIEW_PATH_NAMES:
        if shutil.which(name):
            return shutil.which(name)
    return None


def design_preview_server(project: Path, runtime: bytes, misses: list):
    """A read-only http server for one canvas tree on 127.0.0.1 at a free port: any */support.js is the
    runtime, everything else is the tree's file as it is; a missing file is noted in `misses`."""
    import http.server
    import threading
    from urllib.parse import unquote

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(project), **kwargs)

        def log_message(self, *args):
            pass

        def end_headers(self):
            self.send_header("Cache-Control", "no-store")
            super().end_headers()

        def do_GET(self):
            path = unquote(urlparse(self.path).path)
            if posixpath.basename(path) == "support.js":
                self.send_response(200)
                self.send_header("Content-Type", "text/javascript; charset=utf-8")
                self.send_header("Content-Length", str(len(runtime)))
                self.end_headers()
                self.wfile.write(runtime)
                return
            if not Path(self.translate_path(self.path)).exists() and path != "/favicon.ico":
                misses.append(path)
            super().do_GET()

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


class DesignBrowser:
    """A headless Chrome/Chromium in a throwaway profile, driven over the DevTools protocol on a pipe:
    the browser reads commands on its fd 3 and writes replies on fd 4, each a JSON message ended by NUL.
    Spawned with posix_spawn (no fork with live threads); one page, one session."""

    def __init__(self, browser: str, profile: str):
        import fcntl
        ends = []
        for fd in os.pipe() + os.pipe():  # cmd_r, cmd_w, resp_r, resp_w -- moved above fd 9 so the dup2s cannot collide
            high = fcntl.fcntl(fd, fcntl.F_DUPFD_CLOEXEC, 10)
            os.close(fd)
            ends.append(high)
        cmd_r, self.cmd_w, self.resp_r, resp_w = ends
        args = [browser, "--headless=new", "--remote-debugging-pipe", f"--user-data-dir={profile}", "--no-first-run",
                "--no-default-browser-check", "--disable-extensions", "--disable-sync", "--mute-audio",
                "--hide-scrollbars", "--force-device-scale-factor=1", "about:blank"]
        if sys.platform.startswith("linux") and os.geteuid() == 0:
            args.insert(1, "--no-sandbox")  # Chromium refuses to run as root otherwise (a CI container)
        actions = [(os.POSIX_SPAWN_OPEN, 0, os.devnull, os.O_RDONLY, 0),
                   (os.POSIX_SPAWN_OPEN, 1, os.devnull, os.O_WRONLY, 0),
                   (os.POSIX_SPAWN_OPEN, 2, os.devnull, os.O_WRONLY, 0),
                   (os.POSIX_SPAWN_DUP2, cmd_r, 3), (os.POSIX_SPAWN_DUP2, resp_w, 4)]
        try:
            self.pid = os.posix_spawn(browser, args, dict(os.environ), file_actions=actions)
        finally:
            os.close(cmd_r)
            os.close(resp_w)
        self.buffer, self.events, self.next_id, self.session = b"", [], 0, None
        target = self.call("Target.createTarget", {"url": "about:blank"})["targetId"]
        self.session = self.call("Target.attachToTarget", {"targetId": target, "flatten": True})["sessionId"]
        for domain in ("Page.enable", "Runtime.enable"):
            self.call(domain)

    def read(self, deadline: float) -> dict:
        import select
        while b"\0" not in self.buffer:
            left = deadline - time.monotonic()
            if left <= 0 or not select.select([self.resp_r], [], [], left)[0]:
                raise RuntimeError("the browser did not answer in time")
            chunk = os.read(self.resp_r, 1 << 20)
            if not chunk:
                raise RuntimeError("the browser exited")
            self.buffer += chunk
        message, self.buffer = self.buffer.split(b"\0", 1)
        return json.loads(message.decode("utf-8", errors="replace"))

    def call(self, method: str, params: dict = None, timeout: float = DESIGN_PREVIEW_TIMEOUT) -> dict:
        self.next_id += 1
        message = {"id": self.next_id, "method": method, "params": params or {}}
        if self.session:
            message["sessionId"] = self.session
        data = json.dumps(message).encode("utf-8") + b"\0"
        while data:
            data = data[os.write(self.cmd_w, data):]
        deadline = time.monotonic() + timeout
        while True:
            reply = self.read(deadline)
            if reply.get("id") == self.next_id:
                if "error" in reply:
                    raise RuntimeError(f"{method}: {reply['error'].get('message', reply['error'])}")
                return reply.get("result", {})
            if "method" in reply:
                self.events.append(reply)

    def wait_event(self, method: str, timeout: float) -> bool:
        deadline = time.monotonic() + timeout
        while True:
            if any(e["method"] == method for e in self.events):
                return True
            try:
                reply = self.read(deadline)
            except RuntimeError:
                return False
            if "method" in reply:
                self.events.append(reply)

    def evaluate(self, expression: str):
        result = self.call("Runtime.evaluate", {"expression": expression, "returnByValue": True, "awaitPromise": True})
        if "exceptionDetails" in result:
            raise RuntimeError(result["exceptionDetails"].get("text", "evaluate failed"))
        return result.get("result", {}).get("value")

    def settle(self, poll: float = 0.15, need: int = 2) -> bool:
        """Wait until the page stops changing: the same DOM size, content size and image state on `need`
        polls running after the first (0.15 s apart, three alike, after a render; --click's quick settle
        is two alike 0.04 s apart, since a click's update is in the DOM when its event ends)."""
        deadline, last, same = time.monotonic() + DESIGN_PREVIEW_SETTLE, None, 0
        while time.monotonic() < deadline:
            now = self.evaluate(DESIGN_PREVIEW_SETTLED_JS)
            same = same + 1 if now == last else 0
            if same >= need:
                return True
            last = now
            time.sleep(poll)
        return False

    def errors(self) -> list:
        """The page's uncaught exceptions and console.error lines since the last navigation."""
        found = []
        for event in self.events:
            params = event.get("params", {})
            if event["method"] == "Runtime.exceptionThrown":
                details = params.get("exceptionDetails", {})
                found.append((details.get("exception") or {}).get("description") or details.get("text", "exception"))
            elif event["method"] == "Runtime.consoleAPICalled" and params.get("type") == "error":
                found.append(" ".join(str(a.get("value", a.get("description", ""))) for a in params.get("args", [])))
        lines = [line.strip().splitlines()[0][:300] if line.strip() else "(empty)" for line in found]
        return list(dict.fromkeys(lines))  # once each, in order

    def close(self) -> None:
        try:
            self.session = None
            self.call("Browser.close", timeout=5)
        except (RuntimeError, OSError, ValueError):
            pass
        for _ in range(50):
            if os.waitpid(self.pid, os.WNOHANG)[0]:
                break
            time.sleep(0.1)
        else:
            try:
                os.kill(self.pid, 9)
                os.waitpid(self.pid, 0)
            except OSError:
                pass
        for fd in (self.cmd_w, self.resp_r):
            try:
                os.close(fd)
            except OSError:
                pass


def design_preview_capture(page: "DesignBrowser", width: int, height: int, grow: bool, settled: bool, align=None) -> dict:
    """Measure the settled page, grow the viewport to a taller content when the view grows (relayout,
    settle again), run the measured checks and take the screenshot. align (v88): None, or {"page": bool}
    to run check=align and M1-M14 with the measured checks (the frame view and its states)."""
    shape = page.evaluate(DESIGN_PREVIEW_MEASURE_JS)
    if grow and shape["h"] > height:
        height = min(shape["h"], DESIGN_PREVIEW_MAX)
        page.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": False})
        settled = page.settle() and settled
        shape = page.evaluate(DESIGN_PREVIEW_MEASURE_JS)
    try:
        if align is not None:
            page.evaluate("window.__dcAlign=" + json.dumps({"T": DESIGN_PREVIEW_ALIGN, "M": DESIGN_PREVIEW_MEASURES,
                                                             "page": bool(align.get("page"))}))
        checks = page.evaluate(DESIGN_PREVIEW_CHECKS_JS)
    except RuntimeError as exc:  # the checks never block a screenshot; their failure is said
        checks = {"failed": str(exc)}
    import base64
    png = base64.b64decode(page.call("Page.captureScreenshot", {"format": "png"})["data"])
    return {"png": png, "width": width, "height": height, "shape": shape, "settled": settled, "checks": checks,
            "errors": page.errors()}


def design_preview_render(page: "DesignBrowser", url: str, width: int, height: int, grow: bool, align=None) -> dict:
    """Lay the board out in an exact width x height viewport, let it settle, measure it, and -- when it
    grows (a PAGE, or the phone render) and its content is taller -- relayout at the content height."""
    page.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": False})
    page.events.clear()
    page.call("Page.navigate", {"url": url})
    loaded = page.wait_event("Page.loadEventFired", DESIGN_PREVIEW_SETTLE)
    shot = design_preview_capture(page, width, height, grow, page.settle(), align)
    shot["loaded"] = loaded
    return shot


def design_preview_link(rel: str, href: str, boards: dict, project: Path) -> tuple:
    """Classify one <a href> on board `rel`: (kind, target) with kind board | dead | file | anchor |
    external. Never fetched: an absolute URL (https:, mailto:, ...) is only listed as external."""
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", href) or href.startswith("//"):
        return "external", href
    from urllib.parse import unquote
    path = unquote(urlparse(href).path)
    if not path:
        return "anchor", href
    target = posixpath.normpath(path.lstrip("/") if path.startswith("/") else posixpath.join(posixpath.dirname(rel), path))
    if target.endswith(DESIGN_BOARD_SUFFIX):
        return ("board" if target in boards else "dead"), target
    return ("file" if (project / target).is_file() else "dead"), target


def design_preview_fold(message: str) -> str:
    """An issue message without its "(+N more like it)" count and its " crop=<png>" (v88), to tell a
    repeated finding apart."""
    return re.sub(r" \(\+\d+ more like it\)$", "", re.sub(r" crop=.*$", "", message))


def design_preview_num(value) -> str:
    return f"{float(value):g}"


def design_preview_measured(ctx: dict, rel: str, checks: dict) -> list:
    """Word the in-page measurements as (check, message, count) issues, identical findings folded into
    one line (the first element named, the rest counted; preview.json keeps every one)."""
    if "failed" in checks:
        return [("checks", f"the measured checks did not run: {checks['failed']}", 1)]
    found = []
    for c in checks.get("contrast", []):
        weight = " bold" if c["weight"] >= 700 else ""
        found.append(("contrast", f"{c['fg']} on {c['bg']}|{c['need']}",
                      f"{c['el']} is {c['ratio']:.2f}:1, needs {design_preview_num(c['need'])}:1 "
                      f"({design_preview_num(c['size'])}px{weight} text {c['fg']} on {c['bg']})"))
    unmeasured = checks.get("unmeasured", [])
    if unmeasured and rel not in ctx["unmeasured"]:  # once per board: judge those on the PNG
        ctx["unmeasured"].add(rel)
        first = unmeasured[0]
        found.append(("unmeasured", "-", f"{len(unmeasured)} text run(s) sit on {first['why']} (first: {first['el']}): "
                                         "contrast not measured; judge it on the PNG"))
    for t in checks.get("target", []):  # v88: folded per control class (tag and first class), like non-text-contrast
        what = " with its label" if t.get("labelled") else ""
        found.append(("target", t.get("cls") or f"{t['w']}x{t['h']}",
                      f"{t['el']} is {design_preview_num(t['w'])}x{design_preview_num(t['h'])}px{what}, "
                      f"under {DESIGN_PREVIEW_TARGET}x{DESIGN_PREVIEW_TARGET}"))
    for c in checks.get("clipped", []):
        found.append(("clipped", c["el"], f"{c['el']} has text cut off: content {c['sw']}x{c['sh']} in a {c['cw']}x{c['ch']} box "
                                          "that hides overflow, with no ellipsis or line clamp"))
    for link in checks.get("links", []):
        if ctx.get("page_slug") and link["href"].startswith("#to:"):  # a page's placeholder for the join (design-check's)
            continue
        kind, target = design_preview_link(rel, link["href"], ctx.get("link_boards", ctx["boards"]), ctx["project"])
        if link.get("anchor") == "placeholder":
            found.append(("dead-link", link["href"], f"{link['el']} href=\"{link['href']}\" goes nowhere (a placeholder)"))
        elif link.get("anchor") == "missing":
            found.append(("dead-link", link["href"], f"{link['el']} href=\"{link['href']}\": no element with that id on this board"))
        elif kind == "dead":
            what = "board in canvas.json" if target.endswith(DESIGN_BOARD_SUFFIX) else "file in the canvas tree"
            found.append(("dead-link", link["href"], f"{link['el']} href=\"{link['href']}\": no {what} named {target}"))
    for i in checks.get("images", []):
        src = f"src=\"{i['src']}\"" if i["src"] else "no src"
        found.append(("image", i["src"], f"{i['el']} ({src}) did not load or decode (naturalWidth 0)"))
    for n in checks.get("names", []):
        if n["kind"] == "field":
            hint = f" (its placeholder \"{n['placeholder']}\" is not a label)" if n.get("placeholder") else ""
            found.append(("name", n["el"], f"{n['el']}: a form field with no label (label for=, a wrapping label, "
                                           f"aria-label or aria-labelledby){hint}"))
        else:
            found.append(("name", n["el"], f"{n['el']}: a {n['kind']} with no accessible name (no text, aria-label, "
                                           "aria-labelledby, title or img alt)"))
    ctx["ntc_again"], named, fresh = 0, ctx.setdefault("ntc_named", {}), set()
    for c in checks.get("ntc", []):
        # One line per run for a boundary (the same border or fill on the same surface is one token pairing,
        # drawn again in every view, state and board that shows the control): later shots count it, never
        # repeat it, and the closing note lists the other boards that draw it.
        pair = (c["part"], c["fg"], c["bg"])
        if pair in named and pair not in fresh:
            ctx["ntc_again"] += 1
            if named[pair] != rel:
                ctx.setdefault("ntc_more", {}).setdefault(pair, {}).setdefault(rel, c["el"])
            continue
        named[pair] = rel
        fresh.add(pair)
        what = f"its {design_preview_num(c['width'])}px border {c['fg']}" if c["part"] == "border" else f"its fill {c['fg']}"
        found.append(("non-text-contrast", f"{c['fg']} on {c['bg']}",
                      f"{c['el']}: the control's boundary is {c['ratio']:.2f}:1 against {c['bg']} around it, needs 3:1 "
                      f"({what}; the best of its border and fill counts; later views, states and boards do not repeat this pair)"))
    ntc_unmeasured = checks.get("ntc_unmeasured", [])
    if ntc_unmeasured and rel not in ctx.setdefault("ntc_unmeasured", set()):  # once per board, like unmeasured
        ctx["ntc_unmeasured"].add(rel)
        first = ntc_unmeasured[0]
        found.append(("unmeasured", "ntc", f"{len(ntc_unmeasured)} control boundary(ies) sit on {first['why']} (first: {first['el']}): "
                                           "non-text contrast not measured; judge it on the PNG"))
    for b in checks.get("statebar", []):
        if b["kind"] == "several":
            message = (f"{b['n']} state bars on one board ({', '.join(b['names'])}): a board that shows one page in several "
                       "windows carries exactly one bar, above all the windows and inside none, driving them together")
        elif b["kind"] == "pinned":
            message = (f"the state bar is position: {b['pos']} ({b['el']}): it is the first row of the page and scrolls "
                       "away with it, never fixed or sticky")
        elif b["kind"] == "pages":
            message = (f"the state bar shows the presets of {b['n']} pages at once ({', '.join(b['names'])}): it lists only "
                       "the states of the page on screen")
        else:
            message = ("the state bar has no [role=group] named by the page (aria-label or aria-labelledby): the preview "
                       "cannot tell which page is on screen")
        found.append(("state-bar", b["kind"], message))
    found += design_preview_align_lines(ctx, rel, checks.get("align"))
    folded: dict = {}
    for check, key, message, *box in found:
        entry = folded.setdefault((check, key), [message, 0])
        entry[1] += 1
        if box and box[0] and check == "align":  # the first line's boxes: its zoom crop (design_preview_crops)
            ctx.setdefault("align_boxes", {})[(rel, message)] = box[0]
    # v88: target, align and the M lines are named once per board and fold key -- a later view or --click
    # state that shows the same control class or the same pair of elements again counts it, never repeats it.
    once, named = ("target", "align") + DESIGN_PREVIEW_MEASURE_RULES, ctx.setdefault("advisory_named", set())
    kept = []
    for (check, key), (message, count) in folded.items():
        if check in once:
            if (rel, check, key) in named:
                record = ctx["report"]["boards"].get(rel)
                if record is not None:
                    record["named_before"] = record.get("named_before", 0) + count
                continue
            named.add((rel, check, key))
        kept.append((check, message, count))
    return kept


def design_preview_align_lines(ctx: dict, rel: str, align) -> list:
    """v88 (P47-p5.S5): word check=align and the M1-M14 rules as (check, fold key, message, box) items.
    An align line folds per board, kind and the two elements' tag and class; label-ink once per text style
    per run (later boards count it, a closing note lists them); an M line per board, rule and element class."""
    if not isinstance(align, dict):
        return []
    if "failed" in align:
        return [("checks", "align", f"the align and type checks did not run: {align['failed']}", None)]
    found = []
    for f in align.get("align", []):
        pair = f"{f['a']} vs {f['b']}" if f.get("b") else f["a"]
        note = f": {f['note']}" if f.get("note") else ""
        found.append(("align", f"{f['kind']}|{f['key']}", f"{f['kind']} {design_preview_num(f['px'])}px ({pair}){note}", f.get("box")))
    named = ctx.setdefault("ink_named", {})
    for i in align.get("ink", []):
        if i["style"] in named:
            if named[i["style"]]["board"] != rel:
                named[i["style"]]["more"].setdefault(rel, 0)
                named[i["style"]]["more"][rel] += i["n"]
            continue
        named[i["style"]] = {"board": rel, "more": {}}
        found.append(("align", f"label-ink|{i['style']}",
                      f"label-ink {design_preview_num(i['px'])}px ({i['n']} label(s) in {i['style']}, e.g. {i['eg']}): the ink sits "
                      f"{i['dir']} of the box's centre; later boards do not repeat this style", i.get("box")))
    for m in align.get("measure", []):
        found.append((m["rule"], m["key"], m["msg"], None))
    return found


def design_preview_crops(ctx: dict, rel: str, issues: list, state=None) -> list:
    """v88 (P47-p5.S5): a 2x zoom crop per printed check=align line, taken while the page still shows the
    shot: a clip around the line's two boxes plus DESIGN_PREVIEW_CROP_MARGIN, at device scale
    DESIGN_PREVIEW_CROP_SCALE, saved beside the render as <stem>.[state-NN.]align-NN.png; its path ends the
    line (crop=<png>). At most DESIGN_PREVIEW_CROPS per board."""
    boxes, kept = ctx.get("align_boxes", {}), []
    record = ctx["report"]["boards"][rel]
    stem = rel[:-len(DESIGN_BOARD_SUFFIX)].replace("/", "__")
    taken = record.setdefault("crops", [])
    for check, message in issues:
        box = boxes.get((rel, design_preview_fold(message))) if check == "align" else None
        if not box:
            kept.append((check, message))
            continue
        if len(taken) >= DESIGN_PREVIEW_CROPS:
            if not record.get("crops_capped"):
                record["crops_capped"] = True
                print(f"note board={rel}: {DESIGN_PREVIEW_CROPS} align crops taken; later align lines on this board have none")
            kept.append((check, message))
            continue
        x, y, w, h = box
        m = DESIGN_PREVIEW_CROP_MARGIN
        x0, y0 = max(0, x - m), max(0, y - m)
        clip = {"x": x0, "y": y0, "width": max(1, min(w + 2 * m, DESIGN_PREVIEW_CROP_MAX[0])),
                "height": max(1, min(h + 2 * m, DESIGN_PREVIEW_CROP_MAX[1])), "scale": DESIGN_PREVIEW_CROP_SCALE}
        n = sum(1 for c in taken if c.get("state") == state) + 1
        png = ctx["out"] / (f"{stem}." + (f"state-{state:02d}." if state is not None else "") + f"align-{n:02d}.png")
        try:
            import base64
            data = ctx["page"].call("Page.captureScreenshot", {"format": "png", "clip": clip, "captureBeyondViewport": True})["data"]
            png.write_bytes(base64.b64decode(data))
        except (RuntimeError, OSError, ValueError, KeyError) as exc:
            kept.append((check, message + f" crop=none ({exc})"))
            continue
        taken.append({"state": state, "png": design_preview_shown(png), "clip": clip, "line": design_preview_fold(message)})
        kept.append((check, message + f" crop={design_preview_shown(png)}"))
    return kept


def design_preview_issues(ctx: dict, rel: str, shot: dict, grow: bool, height: int, clip_h: int = None) -> list:
    """Every (check, message) issue of one screenshot: the render's own (load, settle, size, mounts,
    errors, files not found) and the measured checks. clip_h is a PAGE's frame h in the frame view: the
    render grows a PAGE to its content, but the canvas frame does not, so a state taller than h is cut
    there (page-clip)."""
    shape, issues = shot["shape"], []
    if not shot.get("loaded", True):
        issues.append(("load", "the page never fired its load event (a script or file that never arrived?)"))
    if not shot["settled"]:
        issues.append(("settle", f"the page was still changing after {DESIGN_PREVIEW_SETTLE:g}s (an animation, or a slow font or image)"))
    if grow and shape["h"] > DESIGN_PREVIEW_MAX:
        issues.append(("too-tall", f"the page is {shape['h']}px tall: the screenshot stops at {DESIGN_PREVIEW_MAX}px"))
    elif not grow and shape["h"] > height:
        issues.append(("frame-clip", f"content is {shape['h']}px tall in a {height}px frame: the canvas clips the rest"))
    if clip_h and shape["h"] > clip_h + 1:
        issues.append(("page-clip", f"content is {shape['h']}px tall but the PAGE frame h is {clip_h}px: the canvas cuts the rest "
                                    "(h holds the tallest state a click reaches)"))
    if shape["w"] > shot["width"]:
        issues.append(("overflow", f"content is {shape['w']}px wide at {shot['width']}px: it does not fit the width (clipped, or a sideways scroll)"))
    unmounted = shape["unmounted"]
    for title in sorted(set(unmounted)):
        issues.append(("unmounted", f"not mounted: {title} x{unmounted.count(title)} (an x-import whose system global is missing, "
                                    "or a dc-import whose board is missing)"))
    issues.extend(("runtime-error", f"runtime error: {text}") for text in shape["errors"])
    issues.extend(("script-error", f"script error: {text}") for text in shot["errors"])
    for miss in sorted(set(ctx["misses"])):
        why = " (a canvas upload; it is not on disk)" if miss.startswith("/_blob/") else \
            " (the system cache lacks it)" if miss.startswith("/ds/") else ""
        issues.append(("not-found", f"not found: {miss}{why}"))
    for check, message, count in design_preview_measured(ctx, rel, shot["checks"]):
        issues.append((check, message + (f" (+{count - 1} more like it)" if count > 1 else "")))
    return issues


def design_preview_view(ctx: dict, rel: str, board: dict, view: str) -> int:
    """Render one board in one view and print its line and its issues; returns the issue count, or -1
    when no screenshot came out. frame = the board's w x h (a PAGE grows to its content), phone = 390
    wide, growing to its content."""
    page_board = board.get("expand") == "fill"
    width, height = (board["w"], board["h"]) if view == "frame" else DESIGN_PREVIEW_PHONE
    grow = page_board or view == "phone"
    png = ctx["out"] / f"{rel[:-len(DESIGN_BOARD_SUFFIX)].replace('/', '__')}.{view}.png"
    record = ctx["report"]["boards"][rel]
    ctx["misses"].clear()
    try:
        shot = design_preview_render(ctx["page"], f"{ctx['base']}/{rel}", width, height, grow,
                                     {"page": page_board} if view == "frame" else None)
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"board={rel} png=none w={width} h={height} view={view} error=browser")
        print(f"issue board={rel} view={view} check=screenshot: no screenshot: {exc}")
        record["views"][view] = {"png": None, "w": width, "h": height,
                                  "issues": [{"check": "screenshot", "message": f"no screenshot: {exc}"}]}
        return -1
    png.write_bytes(shot["png"])
    shape = shot["shape"]
    issues = design_preview_issues(ctx, rel, shot, grow, height, height if page_board and view == "frame" else None)
    repeated = 0
    if view != "frame" and "frame" in record["views"]:  # a measured finding the frame view already named is not repeated
        named = {(i["check"], design_preview_fold(i["message"])) for i in record["views"]["frame"]["issues"]}
        kept = [(c, m) for c, m in issues if c not in DESIGN_PREVIEW_CHECKS or (c, design_preview_fold(m)) not in named]
        issues, repeated = kept, len(issues) - len(kept)
    if view == "frame":  # v88: the align lines' zoom crops, while the page still shows this shot
        issues = design_preview_crops(ctx, rel, issues)
    print(f"board={rel} png={design_preview_shown(png)} w={shot['width']} h={shot['height']} view={view} content={shape['w']}x{shape['h']} "
          f"unmounted={len(shape['unmounted'])} errors={len(shape['errors']) + len(shot['errors'])} issues={len(issues)}")
    for check, message in issues:
        print(f"issue board={rel} view={view} check={check}: {message}")
    again = ctx.get("ntc_again", 0)
    if repeated:
        print(f"note board={rel} view={view}: {repeated} measured issue(s) as in the frame view, not repeated")
    if again:
        print(f"note board={rel} view={view}: {again} non-text-contrast boundary(ies) named earlier in this run, not repeated")
    record["views"][view] = {"png": design_preview_shown(png), "w": shot["width"], "h": shot["height"], "content": [shape["w"], shape["h"]],
                             "issues": [{"check": c, "message": m} for c, m in issues], "as_in_frame": repeated, "ntc_as_before": again,
                             "measured": shot["checks"]}
    for link in shot["checks"].get("links", []):
        design_preview_edge(ctx, rel, link["href"])
    return len(issues)


def design_preview_edge(ctx: dict, rel: str, href: str) -> None:
    """Note one link of board `rel` for the link graph (preview.json always; link lines with --click)."""
    kind, target = design_preview_link(rel, href, ctx["boards"], ctx["project"])
    if kind in ("board", "external"):
        ctx["edges"].setdefault(rel, {})[target] = kind


def design_preview_click(page: "DesignBrowser", x: float, y: float) -> None:
    """A real left click at (x, y): move, press, release (Input.dispatchMouseEvent), then the pointer
    leaves for the top-left corner, so no hover style stays on the clicked control."""
    page.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y})
    page.call("Input.dispatchMouseEvent", {"type": "mousePressed", "x": x, "y": y, "button": "left", "buttons": 1, "clickCount": 1})
    page.call("Input.dispatchMouseEvent", {"type": "mouseReleased", "x": x, "y": y, "button": "left", "buttons": 0, "clickCount": 1})
    page.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": 0, "y": 0})


def design_preview_note(ctx: dict, rel: str, view: str, state, check: str, message: str) -> None:
    """Print and record one --click finding that belongs to a move between states, not to one
    screenshot (layout-shift, same-target, hover-contrast): preview.json keeps it on the board and in
    its issues list, and it counts in issues=."""
    where = f" state={state:02d}" if state is not None else ""
    print(f"issue board={rel} view={view}{where} check={check}: {message}")
    item = {"view": view, "state": state, "check": check, "message": message}
    ctx["report"]["boards"][rel].setdefault("interaction", []).append(item)
    ctx["report"]["issues"].append(dict(item, board=rel))


def design_preview_hover(ctx: dict, rel: str, view: str, state: int, hovered: set) -> int:
    """The hover pass on the page as it stands: rest the pointer on each button and link not hovered
    yet on this board (by its signature), and re-run the contrast check on the hovered control's own
    text. A run that newly fails is a hover-contrast issue (the "green-out": a skeleton a:hover color
    beating a system Button rendered as <a>). Returns the issue count."""
    page, found = ctx["page"], 0
    try:
        targets = page.evaluate(DESIGN_PREVIEW_HOVER_JS) or []
        for t in targets:
            if t["sig"] in hovered:
                continue
            hovered.add(t["sig"])
            page.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": t["x"], "y": t["y"]})
            now = page.evaluate(f"window.__dcHover({json.dumps(t['key'])})") or []
            for f in now:
                if f"{f['el']}|{f['fg']}|{f['bg']}" in t["before"]:
                    continue
                design_preview_note(ctx, rel, view, state, "hover-contrast",
                                    f"hovering {t['el']} turns {f['el']} to {f['ratio']:.2f}:1, needs "
                                    f"{design_preview_num(f['need'])}:1 (text {f['fg']} on {f['bg']}; keep hover restrained "
                                    "and scope page link colors to text links, e.g. a:not([class]))")
                found += 1
                break
        page.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": 0, "y": 0})
        page.evaluate(DESIGN_PREVIEW_HOVER_DONE_JS)
    except (RuntimeError, KeyError, TypeError) as exc:
        design_preview_note(ctx, rel, view, state, "click", f"the hover pass stopped: {exc}")
        found += 1
    return found


def design_preview_load(page: "DesignBrowser", url: str, width: int, height: int) -> tuple:
    """A fresh load of `url` in an exact width x height viewport; (loaded, settled)."""
    page.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": False})
    page.events.clear()
    page.call("Page.navigate", {"url": url})
    loaded = page.wait_event("Page.loadEventFired", DESIGN_PREVIEW_SETTLE)
    return loaded, page.settle()


def design_preview_earlier(record: dict) -> set:
    """The (check, folded message) pairs the board's views so far already named."""
    return {(i["check"], design_preview_fold(i["message"])) for v in record["views"].values() for i in v.get("issues", [])}


def design_preview_text_view(ctx: dict, rel: str, view: str) -> int:
    """v61 (P37.S6), a PAGE's two WCAG views: w320 (320 px wide: reflow, WCAG 1.4.10) and text200 (the
    phone width with every element's font-size doubled: WCAG 1.4.4), each growing to its content. Each
    names reflow (a sideways scroll), overprint (two text runs crossing) and the clipped check, plus the
    render's own issues the earlier views did not name. Returns the issue count, or -1 with no screenshot."""
    page, record = ctx["page"], ctx["report"]["boards"][rel]
    width, height = (DESIGN_PREVIEW_REFLOW if view == "w320" else DESIGN_PREVIEW_PHONE[0]), DESIGN_PREVIEW_PHONE[1]
    where = f"at {width}px wide" if view == "w320" else f"at {width}px with {DESIGN_PREVIEW_TEXT_SCALE * 100}% text"
    png = ctx["out"] / f"{rel[:-len(DESIGN_BOARD_SUFFIX)].replace('/', '__')}.{view}.png"
    ctx["misses"].clear()
    try:
        loaded, settled = design_preview_load(page, f"{ctx['base']}/{rel}", width, height)
        if view == "text200":
            page.evaluate(f"{DESIGN_PREVIEW_TEXT_SCALE_JS}({DESIGN_PREVIEW_TEXT_SCALE})")
            settled = page.settle() and settled
        shot = design_preview_capture(page, width, height, True, settled)
        shot["loaded"] = loaded
        crossed = page.evaluate(DESIGN_PREVIEW_OVERPRINT_JS) or {"pairs": [], "found": 0, "runs": 0}
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"board={rel} png=none w={width} h={height} view={view} error=browser")
        print(f"issue board={rel} view={view} check=screenshot: no screenshot: {exc}")
        record["views"][view] = {"png": None, "w": width, "h": height,
                                  "issues": [{"check": "screenshot", "message": f"no screenshot: {exc}"}]}
        return -1
    png.write_bytes(shot["png"])
    shape = shot["shape"]
    keep = ("clipped", "load", "settle", "too-tall", "unmounted", "runtime-error", "script-error", "not-found")
    issues = [(c, m) for c, m in design_preview_issues(ctx, rel, shot, True, height) if c in keep]
    if shape["w"] > width:
        issues.insert(0, ("reflow", f"content is {shape['w']}px wide {where}: the page scrolls sideways "
                                    "(it reflows into the width, scrolling only a table, code or a map in its own box)"))
    for p in crossed["pairs"]:
        issues.append(("overprint", f"{p['a']} and {p['b']} overprint {where}: their text crosses over {p['w']}x{p['h']}px"))
    if crossed["found"] > len(crossed["pairs"]):
        issues.append(("overprint", f"{crossed['found'] - len(crossed['pairs'])} more overprinting pair(s) {where} (see the PNG)"))
    named = design_preview_earlier(record)
    kept = [(c, m) for c, m in issues if (c, design_preview_fold(m)) not in named]
    repeated = len(issues) - len(kept)
    print(f"board={rel} png={design_preview_shown(png)} w={shot['width']} h={shot['height']} view={view} "
          f"content={shape['w']}x{shape['h']} unmounted={len(shape['unmounted'])} "
          f"errors={len(shape['errors']) + len(shot['errors'])} issues={len(kept)}")
    for check, message in kept:
        print(f"issue board={rel} view={view} check={check}: {message}")
    if repeated:
        print(f"note board={rel} view={view}: {repeated} issue(s) as in an earlier view, not repeated")
    measured = {"clipped": shot["checks"].get("clipped", []) if isinstance(shot["checks"], dict) else [], "overprint": crossed}
    record["views"][view] = {"png": design_preview_shown(png), "w": shot["width"], "h": shot["height"],
                             "content": [shape["w"], shape["h"]], "issues": [{"check": c, "message": m} for c, m in kept],
                             "as_in_frame": repeated, "measured": measured}
    return len(kept)


def design_preview_keyboard(ctx: dict, rel: str, board: dict) -> int:
    """v61 (P37.S6): keyboard (WCAG 2.1.1) on an interactive board, frame view, from the settled state.
    Tab (Input.dispatchKeyEvent) until focus comes back to the first stop, at most DESIGN_PREVIEW_TABS
    presses; a control the order never reached is unreachable (judged only when the order wrapped). A
    click-only control (DESIGN_PREVIEW_KEYS_JS) is a keyboard issue too, one line per tag and class; the
    first DESIGN_PREVIEW_POP_PROBES of them are clicked from a fresh load, and one that opens a dialog,
    menu, tooltip, listbox or popover is named so. Returns the issue count."""
    page, url = ctx["page"], f"{ctx['base']}/{rel}"
    width, height = board["w"], board["h"]
    record, found = ctx["report"]["boards"][rel], 0
    key = {"key": "Tab", "code": "Tab", "windowsVirtualKeyCode": 9, "nativeVirtualKeyCode": 9}
    try:
        design_preview_load(page, url, width, height)
        setup = page.evaluate(DESIGN_PREVIEW_KEYS_JS)
        cap, presses, wrapped = min(DESIGN_PREVIEW_TABS, 2 * max(setup["stops"], setup["controls"]) + 20), 0, False
        while presses < cap and not wrapped:
            for _ in range(min(25, cap - presses)):
                page.call("Input.dispatchKeyEvent", dict(key, type="keyDown"))
                page.call("Input.dispatchKeyEvent", dict(key, type="keyUp"))
                presses += 1
            wrapped = bool(page.evaluate("!!(window.__dcKeys && window.__dcKeys.wrapped)"))
        done = page.evaluate(DESIGN_PREVIEW_KEYS_DONE_JS) or {"missed": [], "reached": 0}
        sigs: dict = {}
        for c in setup["only"]:
            sigs.setdefault(c["sig"], []).append(c)
        opened: dict = {}
        for sig in list(sigs)[:DESIGN_PREVIEW_POP_PROBES]:
            design_preview_load(page, url, width, height)
            at = page.evaluate(f"{DESIGN_PREVIEW_POINT_JS}({json.dumps(sigs[sig][0]['key'])})")
            if not at:
                continue
            page.settle(poll=0.04, need=1)
            before, look = set(page.evaluate(DESIGN_PREVIEW_OVERLAYS_JS) or []), page.evaluate(DESIGN_PREVIEW_STATE_JS)["hash"]
            design_preview_click(page, at[0], at[1])
            page.settle(poll=0.04, need=1)
            try:
                page.evaluate(DESIGN_PREVIEW_ANIMATIONS_JS)
            except RuntimeError:
                pass
            new = [o for o in page.evaluate(DESIGN_PREVIEW_OVERLAYS_JS) or [] if o not in before]
            opened[sig] = f"opens {new[0]}" if new else ("changes the page" if page.evaluate(DESIGN_PREVIEW_STATE_JS)["hash"] != look else "")
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as exc:
        design_preview_note(ctx, rel, "frame", None, "click", f"the keyboard pass stopped: {exc}")
        return 1
    missed = done.get("missed") or []
    if wrapped and missed:
        names = ", ".join(missed[:4]) + (f" (+{len(missed) - 4} more)" if len(missed) > 4 else "")
        design_preview_note(ctx, rel, "frame", None, "keyboard",
                            f"{len(missed)} control(s) Tab never reaches from the settled state: {names}")
        found += 1
    for sig, items in sigs.items():
        what, how = opened.get(sig), items[0]["how"]
        more = f" (+{len(items) - 1} more like it)" if len(items) > 1 else ""
        does = f"{what} on click ({how})" if what else f"takes a click ({how})"
        design_preview_note(ctx, rel, "frame", None, "keyboard",
                            f"{items[0]['el']} {does} but never keyboard focus: not natively focusable and no tabindex >= 0, "
                            f"so a keyboard user cannot reach it{more}")
        found += 1
    notes = [f"{done.get('reached', 0)} Tab stop(s) for {setup['controls']} control(s) in {presses} press(es)"
             + ("" if wrapped else f": the order did not come back to its first stop (cap {cap}), so no control is called unreachable")]
    if setup.get("modal"):
        notes.append("an open modal: only its controls are expected")
    print(f"note board={rel} view=frame: keyboard: " + "; ".join(notes))
    record["keyboard"] = {"controls": setup["controls"], "reached": done.get("reached", 0), "presses": presses,
                          "wrapped": wrapped, "missed": missed, "click_only": setup["only"][:40], "opened": opened}
    return found


def design_preview_blocking(report: dict) -> dict:
    """{check: count} of the blocking checks' issue lines over every board of a (merged) report."""
    counts: dict = {}
    for rec in report["boards"].values():
        items = [i for v in rec.get("views", {}).values() for i in v.get("issues", [])]
        items += [i for s in rec.get("states", []) for i in s.get("issues", [])] + rec.get("interaction", [])
        for item in items:
            if item.get("check") in DESIGN_PREVIEW_BLOCKING:
                counts[item["check"]] = counts.get(item["check"], 0) + 1
    return {c: counts[c] for c in DESIGN_PREVIEW_BLOCKING if c in counts}


def design_preview_advisory(report: dict) -> dict:
    """v88: {check: count} of the advisory measured lines (check=align, M1-M14) over every board."""
    names = ("align",) + DESIGN_PREVIEW_MEASURE_RULES
    counts: dict = {}
    for rec in report["boards"].values():
        items = [i for v in rec.get("views", {}).values() for i in v.get("issues", [])]
        items += [i for s in rec.get("states", []) for i in s.get("issues", [])]
        for item in items:
            if item.get("check") in names:
                counts[item["check"]] = counts.get(item["check"], 0) + 1
    return {c: counts[c] for c in names if c in counts}


def design_preview_slot():
    """v88 (P47-p5.S5): wait for one of DESIGN_PREVIEW_SLOTS render slots (${DESIGN_PREVIEW_SLOTS_ENV} sets
    another cap, at least 1): an flock()ed file in a fixed temp folder, held by the returned open file
    until it is closed or the process exits. One 'waiting for a render slot' line when all are taken."""
    import fcntl
    try:
        cap = max(1, int(os.environ.get(DESIGN_PREVIEW_SLOTS_ENV) or DESIGN_PREVIEW_SLOTS))
    except ValueError:
        cap = DESIGN_PREVIEW_SLOTS
    folder = Path(tempfile.gettempdir()) / "agentic-design-preview-slots"
    folder.mkdir(parents=True, exist_ok=True)
    said = False
    while True:
        for n in range(cap):
            handle = open(folder / f"slot-{n}", "a")
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return handle
            except OSError:
                handle.close()
        if not said:
            print(f"note: waiting for a render slot ({cap} design-preview run(s) render at once; {DESIGN_PREVIEW_SLOTS_ENV} sets the cap)",
                  flush=True)
            said = True
        time.sleep(0.5)


def design_preview_shown(path: Path) -> str:
    """A screenshot's path as printed and stored: shown() (repo-relative) under the workspace, else absolute."""
    try:
        path.resolve().relative_to(ROOT.resolve())
    except ValueError:
        return str(path)
    return shown(path.resolve())


def design_preview_tokens(width: int, height: int) -> int:
    """About what reading one image costs: ceil(w/28) x ceil(h/28) tokens, after the long side is
    brought down to DESIGN_PREVIEW_SHEET_W."""
    import math
    f = min(1.0, DESIGN_PREVIEW_SHEET_W / max(width, height, 1))
    return math.ceil(width * f / 28) * math.ceil(height * f / 28)


def design_preview_sheet(ctx: dict, rel: str) -> dict:
    """v61 (P37.S6) --contact-sheet: one PNG per board tiling its views and states at one reduced scale
    (the widest shot fills a tile, at most DESIGN_PREVIEW_SHEET_SCALE of its size; a tile is cut at
    DESIGN_PREVIEW_SHEET_TILE times its width), each under a caption, at most DESIGN_PREVIEW_SHEET_W px
    wide, drawn as an HTML page of <img> tiles in the same
    browser. Returns its record, or {} when the board has no screenshot."""
    record = ctx["report"]["boards"][rel]
    tiles = []
    for view, v in record.get("views", {}).items():
        if v.get("png"):
            count = len(v.get("issues", []))
            tiles.append((f"{view} {v['w']}x{v['h']}" + (f" · {count} issue(s)" if count else ""), v))
    for s in record.get("states", []):
        if s.get("png"):
            count = len(s.get("issues", []))
            tiles.append((f"{s['view']} state {s['n']:02d}: {' > '.join(s.get('path', []))[:80]}" + (f" · {count} issue(s)" if count else ""), s))
    files = []
    for caption, item in tiles:
        path = Path(item["png"])
        path = path if path.is_absolute() else (HOST_ROOT or ROOT) / path
        if path.is_file():
            files.append((caption, path, item["w"], item["h"]))
    if not files:
        return {}
    import html as htmllib
    import math
    cols = max(1, min(6, math.ceil(math.sqrt(len(files)))))
    gap = 8
    widest = max(w for _, _, w, _ in files)
    tile = min((DESIGN_PREVIEW_SHEET_W - gap * (cols + 1)) // cols, max(1, round(widest * DESIGN_PREVIEW_SHEET_SCALE)))
    scale = tile / widest
    sheet_w = tile * cols + gap * (cols + 1)
    cap = int(tile * DESIGN_PREVIEW_SHEET_TILE)
    cells = []
    for caption, path, w, h in files:
        sw, sh = max(1, round(w * scale)), max(1, round(h * scale))
        cut = " (cut)" if sh > cap else ""
        cells.append(f'<figure><div class="t" style="height:{min(sh, cap)}px"><img src="{path.as_uri()}" '
                     f'style="width:{sw}px;height:{sh}px"></div><figcaption>{htmllib.escape(caption + cut)}</figcaption></figure>')
    title = record.get("title") or rel
    doc = ("<!doctype html><html><head><meta charset=utf-8><style>"
           f"body{{margin:0;background:#fff;color:#111;font:13px/1.3 -apple-system,'Helvetica Neue',Arial,sans-serif;width:{sheet_w}px}}"
           f"h1{{font-size:15px;margin:0;padding:{gap}px {gap}px 0}}"
           f".g{{display:grid;grid-template-columns:repeat({cols},{tile}px);gap:{gap}px;padding:{gap}px;align-items:start}}"
           "figure{margin:0}.t{overflow:hidden;outline:1px solid #bbb;background:#f4f4f4}img{display:block}"
           "figcaption{margin-top:3px;font-size:11px;color:#333;overflow-wrap:anywhere}</style></head><body>"
           f"<h1>{htmllib.escape(title)} · {htmllib.escape(rel)} · {len(files)} shot(s), 1:{1 / scale:.1f}</h1>"
           f"<div class=g>{''.join(cells)}</div></body></html>")
    stem = rel[:-len(DESIGN_BOARD_SUFFIX)].replace("/", "__")
    page_file = ctx["out"] / f".{stem}.sheet.html"
    png = ctx["out"] / f"{stem}.sheet.png"
    page = ctx["page"]
    page_file.write_text(doc, encoding="utf-8")
    try:
        design_preview_load(page, page_file.as_uri(), sheet_w, 300)
        page.evaluate("Promise.all([...document.images].map(i=>i.complete?1:new Promise(r=>{i.onload=i.onerror=r;})))")
        height = min(int(page.evaluate("document.documentElement.scrollHeight")), DESIGN_PREVIEW_MAX)
        page.call("Emulation.setDeviceMetricsOverride", {"width": sheet_w, "height": height, "deviceScaleFactor": 1, "mobile": False})
        page.settle(poll=0.05, need=1)
        import base64
        png.write_bytes(base64.b64decode(page.call("Page.captureScreenshot", {"format": "png"})["data"]))
    finally:
        page_file.unlink(missing_ok=True)
    tokens = design_preview_tokens(sheet_w, height)
    print(f"sheet board={rel} png={design_preview_shown(png)} w={sheet_w} h={height} tiles={len(files)} "
          f"scale=1:{1 / scale:.1f} tokens~{tokens} (the {len(files)} PNG(s) one by one: ~{sum(design_preview_tokens(w, h) for _, _, w, h in files)})")
    return {"png": design_preview_shown(png), "w": sheet_w, "h": height, "tiles": len(files),
            "scale": round(scale, 4), "tokens": tokens}


def design_preview_shifts(before: dict, after: dict, control: dict) -> list:
    """Layout-shift messages for one click that stayed on the same page: a control (outside
    [data-proto]) whose box changed by more than DESIGN_PREVIEW_SHIFT px -- matched by its place and
    label, and the clicked one also by its place, tag and first class when its label changed ("Send"
    to "Sending...") -- and a header, nav or main that moved."""
    limit, out = DESIGN_PREVIEW_SHIFT, []
    old = {(c["key"], c["label"]): c for c in before["clicks"] if not c.get("proto")}
    for c in after["clicks"]:
        if c.get("proto"):
            continue
        was = old.get((c["key"], c["label"]))
        if was is None and c["key"] == control["key"]:
            was = next((o for o in before["clicks"] if o["key"] == c["key"] and o.get("t") == c.get("t") and not o.get("proto")), None)
        if was and (abs(was["w"] - c["w"]) > limit or abs(was["h"] - c["h"]) > limit):
            name = f"'{c['label']}'" if was["label"] == c["label"] else f"'{was['label']}' (now '{c['label']}')"
            out.append(f"clicking '{control['label']}' resizes {name} {was['w']:g}x{was['h']:g} -> {c['w']:g}x{c['h']:g}px "
                       "(a control keeps its size when it shows its state)")
    moved = []
    old_anchors = {a["key"]: a for a in before.get("anchors", [])}
    for a in after.get("anchors", []):
        was = old_anchors.get(a["key"])
        if was and was["el"] == a["el"] and (abs(was["x"] - a["x"]) > limit or abs(was["y"] - a["y"]) > limit):
            axis = f"y {was['y']}->{a['y']}" if abs(was["y"] - a["y"]) > limit else f"x {was['x']}->{a['x']}"
            moved.append(f"{a['el']} {axis}")
    if moved:
        out.append(f"clicking '{control['label']}' moves the page: {', '.join(moved[:4])}"
                   + (f" (+{len(moved) - 4} more)" if len(moved) > 4 else "")
                   + " (the header and content stay put while the page shows a state)")
    return out


def design_preview_explore(ctx: dict, rel: str, board: dict, view: str = "frame") -> int:
    """--click on an interactive board, in one view (frame, or phone with --phone): from the settled
    initial state, try each control (breadth first) and record every state whose visible DOM is new,
    with its screenshot, its line and its issues. A state's path is a recipe from a fresh load, and its
    screenshot is taken on exactly that recipe: a click is tried on the page as it stands when it
    already shows the state's DOM (most clicks change nothing, so this saves a reload each), else after
    a reload and a replay of the path; and a new state reached with other clicks behind it (a ticked box
    the DOM identity ignores) is replayed from a fresh load before its screenshot, so no leftover value
    leaks into it.

    v60 (P36.S8C), for the flow-board recipe:
    - the canvas-only state bar's presets are tried first, once per page: a preset sets the page's
      complete state, so trying them from a second state of the same page gives nothing new; a state
      on a page not met before is explored ahead of the rest, so every page's presets are reached;
    - a list of DESIGN_PREVIEW_LIST_SAMPLE rows or more is sampled (its first, second and last row);
      rows of one list that open the same state of another page are a same-target issue;
    - every visible text field gets a realistic sample typed into it, a step of the path like a click,
      and a form with two or more empty fields is also filled whole in one step;
    - every move that stays on the same page compares the boxes of the controls and the positions of
      the header, nav and main (layout-shift); a move to another page (the state bar's page name, else
      the h1, changes) is navigation, never a shift;
    - a PAGE's states are checked against its frame h (page-clip), and in the frame view each PAGE
      state gets the hover pass.
    Returns the issue count of the states."""
    page, url = ctx["page"], f"{ctx['base']}/{rel}"
    if view == "phone":
        width, height, grow = DESIGN_PREVIEW_PHONE[0], DESIGN_PREVIEW_PHONE[1], True
    else:
        width, height, grow = board["w"], board["h"], board.get("expand") == "fill"
    page_board = board.get("expand") == "fill"
    clip_h = height if page_board and view == "frame" else None
    record = ctx["report"]["boards"][rel]
    fold = design_preview_fold
    frame = {(i["check"], fold(i["message"])) for i in record["views"].get(view, {}).get("issues", [])}
    stem = rel[:-len(DESIGN_BOARD_SUFFIX)].replace("/", "__")

    history: list = []  # the steps since the last load
    quick = {"poll": 0.04, "need": 1}  # a replay that misses its state is retried once with the render's settle

    def load() -> None:
        history.clear()
        page.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": False})
        page.events.clear()
        page.call("Page.navigate", {"url": url})
        page.wait_event("Page.loadEventFired", DESIGN_PREVIEW_SETTLE)
        page.settle(**quick)
        page.evaluate(DESIGN_PREVIEW_GUARD_JS)

    def look() -> dict:
        return page.evaluate(DESIGN_PREVIEW_STATE_JS)

    def press(target: dict):
        """Click the control (or type the sample into the field) with this key and label in the current
        page; the look before it, or None when it is not there."""
        before = look()
        if target.get("fill"):
            here = [f for f in before["fields"] if f["empty"]] or None
        else:
            pool = before["fields"] if "text" in target else before["clicks"]
            here = next((c for c in pool if c["key"] == target["key"] and c["label"] == target["label"]), None)
        if here is None:
            return None
        page.events.clear()
        mark = page.evaluate("window.__dcTimers ? window.__dcTimers.seq() : 0")
        step = {"key": target["key"], "label": target["label"]}
        if target.get("fill"):  # every empty field gets its sample, as one step
            for f in here:
                if page.evaluate(f"{DESIGN_PREVIEW_FOCUS_JS}({json.dumps(f['key'])})"):
                    page.call("Input.insertText", {"text": f["text"]})
            step["fill"] = True
        elif "text" in target:
            if not page.evaluate(f"{DESIGN_PREVIEW_FOCUS_JS}({json.dumps(target['key'])})"):
                return None
            page.call("Input.insertText", {"text": target["text"]})
            step["text"] = target["text"]
        else:
            design_preview_click(page, here["x"], here["y"])
        history.append(step)
        page.settle(**quick)
        if page.evaluate(f"window.__dcTimers ? window.__dcTimers.after({int(mark)}) : 0"):
            timed.add(target["label"])
            page.evaluate(f"new Promise(r => {{ const t0 = Date.now(), f = () => !window.__dcTimers.after({int(mark)}) "
                          "|| Date.now() - t0 > 3000 ? r(1) : setTimeout(f, 25); f(); })")
            page.settle(**quick)
        try:
            page.evaluate(DESIGN_PREVIEW_ANIMATIONS_JS)
        except RuntimeError:
            pass
        return before

    def replay(path: list, want: str = None) -> str:
        """Reload and run `path` again; the DOM identity it ends on, or "" when a step is missing. When
        it does not end on `want`, it is tried once more with the render's slower settle."""
        for slow in (False, True):
            quick.update(poll=0.15, need=2) if slow else quick.update(poll=0.04, need=1)
            load()
            got = look()["hash"] if all(press(step) for step in path) else ""
            quick.update(poll=0.04, need=1)
            if want is None or got == want:
                break
        return got

    def reach(state: dict) -> bool:
        """Put the page in `state`: as it is when its DOM already matches, else reload and replay."""
        try:
            if page.evaluate("!!window.__dcPreview") and look()["hash"] == state["hash"]:
                return True
        except RuntimeError:
            pass
        return replay(state["path"], state["hash"]) == state["hash"]

    def shown_path(path: list) -> str:
        return " > ".join(f"{step['label']} <- \"{step['text']}\"" if "text" in step else step["label"] for step in path)

    timed: set = set()  # controls whose click set a short timer that was waited for
    hovered: set = set()  # the signatures of the controls the hover pass has rested on
    issues = 0
    if view == "phone":
        replay([])
    else:
        page.evaluate(DESIGN_PREVIEW_GUARD_JS)  # the frame view just rendered: this is the initial state
        if not page.evaluate("!!window.__dcTimers"):  # the timer watch starts with the first load after it
            replay([])
    if page_board and view == "frame":
        before_hover = look()["hash"]
        issues += design_preview_hover(ctx, rel, view, 0, hovered)
        if look()["hash"] != before_hover:  # a hover handler changed the page: start again from a fresh load
            replay([])
    first = look()
    states = [{"n": 0, "path": [], "hash": first["hash"], "page": first["page"]}]
    seen, queue, ahead, clicks = {first["hash"]: 0}, [], [0], 0
    pages_met, pages_preset = {first["page"]}, set()
    notes, skipped, left, unreproduced, thrown = [], {"covered": 0, "outside": 0}, set(), 0, set()
    said, lists_said, sampled_out, typed, pickers = set(), set(), 0, set(), 0
    capped_states = capped_depth = capped_clicks = False
    deadline = time.monotonic() + DESIGN_PREVIEW_BOARD_SECONDS

    def say(state_n: int, check: str, message: str) -> int:
        if (check, message) in said:
            return 0
        said.add((check, message))
        design_preview_note(ctx, rel, view, state_n, check, message)
        return 1

    while (ahead or queue) and not capped_clicks:
        state = states[(ahead or queue).pop(0)]
        if len(state["path"]) >= DESIGN_PREVIEW_DEPTH:
            capped_depth = True
            continue
        if not reach(state):
            unreproduced += 1
            continue
        here = look()
        skipped["covered"] += here["covered"]
        skipped["outside"] += here["outside"]
        pickers = max(pickers, here.get("pickers", 0))
        presets = [c for c in here["clicks"] if c.get("bar")]
        if here["page"] in pages_preset:
            presets = []
        elif presets:
            pages_preset.add(here["page"])
        rest = [c for c in here["clicks"] if not c.get("bar")]
        lists: dict = {}
        for c in rest:
            if c.get("list"):
                lists.setdefault(c["list"], []).append(c)
        drop = set()
        for members in lists.values():
            if len(members) >= DESIGN_PREVIEW_LIST_SAMPLE:
                members.sort(key=lambda c: c.get("idx", 0))
                keep = {id(members[0]), id(members[1]), id(members[-1])}
                drop.update(id(c) for c in members if id(c) not in keep)
        sampled_out += len(drop)
        fields = here.get("fields", [])
        actions = presets + [c for c in rest if id(c) not in drop] + [dict(f) for f in fields]
        if sum(1 for f in fields if f["empty"]) >= 2:  # and the whole form at once, so its submit is reached filled
            actions.append({"key": "*", "label": "fill every field", "fill": True})
        opened: dict = {}  # list id -> [(label, state hash, page)] for the rows clicked from this state
        for control in actions:
            if clicks >= DESIGN_PREVIEW_CLICKS or time.monotonic() > deadline:
                capped_clicks = True
                break
            if not reach(state):
                unreproduced += 1
                break
            clicks += 1
            before = press(control)
            if not before:
                continue
            if "text" in control:
                typed.add(control["label"])
            path = state["path"] + [dict({"key": control["key"], "label": control["label"]},
                                         **({"text": control["text"]} if "text" in control else {}),
                                         **({"fill": True} if control.get("fill") else {}))]
            shown = shown_path(path)
            try:
                navigated = not page.evaluate("!!window.__dcPreview")
            except RuntimeError:
                navigated = True
            if navigated:  # a click that left the board is a link, not a state
                left.add(control["label"])
                continue
            errors = page.errors()
            now = look()
            after = now["hash"]
            if before["page"] == now["page"]:
                for message in design_preview_shifts(before, now, control):
                    issues += say(state["n"], "layout-shift", message)
            elif control.get("bar"):  # v61: a preset sets its own page's state; the page changes only by the prototype
                issues += say(state["n"], "state-bar", f"the preset '{control['label']}' moves to another page "
                              f"({before['page'] or '?'} -> {now['page'] or '?'}): the bar lists only the states of the page on screen")
            if control.get("list") and "text" not in control:
                opened.setdefault(control["list"], []).append((control["label"], after, now["page"]))
            if now["page"] not in pages_met:
                pages_met.add(now["page"])
                first_of_page = True
            else:
                first_of_page = False
            if after in seen or len(states) >= DESIGN_PREVIEW_STATES:
                capped_states = capped_states or after not in seen
                where = seen.get(after, state["n"])
                for text in errors:
                    if (control["label"], text) in thrown:  # said once per control and error
                        continue
                    thrown.add((control["label"], text))
                    message = f"clicking \"{shown}\" threw: {text}"
                    print(f"issue board={rel} view={view} state={where:02d} check=click-error: {message}")
                    record["click_errors"].append({"state": where, "view": view, "path": [s["label"] for s in path], "message": text})
                    issues += 1
                if first_of_page and after not in seen:
                    pages_met.discard(now["page"])  # not recorded: let a later move to that page count as its first
                continue
            if history != path:  # other steps are behind this page: take the screenshot on the path alone
                actual = list(history)
                if replay(path, after) != after:  # the shortest path does not give it from a fresh load: keep the real one
                    path, shown = actual, shown_path(actual)
                    if replay(path, after) != after:
                        unreproduced += 1
                        continue
            new = {"n": len(states), "path": path, "hash": after, "page": now["page"]}
            states.append(new)
            seen[after] = new["n"]
            (ahead if first_of_page else queue).append(new["n"])
            page.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": False})
            ctx["misses"].clear()
            shot = design_preview_capture(page, width, height, grow, page.settle(**quick),
                                          {"page": page_board} if view == "frame" else None)
            shot["errors"] = []  # the click's errors, said once below as click-error
            png = ctx["out"] / f"{stem}.{view}.state-{new['n']:02d}.png"
            png.write_bytes(shot["png"])
            found = [(c, m) for c, m in design_preview_issues(ctx, rel, shot, grow, height, clip_h) if (c, fold(m)) not in frame]
            found += [("click-error", f"clicking \"{shown}\" threw: {text}") for text in errors
                      if (control["label"], text) not in thrown]
            thrown.update((control["label"], text) for text in errors)
            if view == "frame":  # v88: the align lines' zoom crops, while the page still shows this state
                found = design_preview_crops(ctx, rel, found, new["n"])
            shape = shot["shape"]
            print(f"state board={rel} view={view} n={new['n']:02d} path=\"{shown}\" png={design_preview_shown(png)} w={shot['width']} "
                  f"h={shot['height']} content={shape['w']}x{shape['h']} issues={len(found)}")
            for check, message in found:
                print(f"issue board={rel} view={view} state={new['n']:02d} check={check}: {message}")
            issues += len(found)
            record["states"].append({"n": new["n"], "view": view, "page": new["page"], "path": [shown_path([s]) for s in path],
                                     "png": design_preview_shown(png), "w": shot["width"], "h": shot["height"], "content": [shape["w"], shape["h"]],
                                     "issues": [{"check": c, "message": m} for c, m in found], "measured": shot["checks"]})
            for link in shot["checks"].get("links", []):
                design_preview_edge(ctx, rel, link["href"])
            if page_board and view == "frame":
                issues += design_preview_hover(ctx, rel, view, new["n"], hovered)
        for list_id, rows in opened.items():
            if list_id in lists_said:  # said once per list
                continue
            alike: dict = {}
            for label, after, where in rows:
                if after != state["hash"] and where != state["page"]:
                    alike.setdefault(after, []).append(label)
            for after, labels in alike.items():
                if len(set(labels)) >= 2 and list_id not in lists_said:
                    lists_said.add(list_id)
                    names = ", ".join(f"'{label}'" for label in sorted(set(labels))[:3])
                    issues += say(state["n"], "same-target",
                                  f"rows {names} of one list all open the same state (n={seen.get(after, '?')}): "
                                  "each item opens its own item")
    if capped_states:
        notes.append(f"state cap {DESIGN_PREVIEW_STATES} reached: more states exist")
    if capped_depth:
        notes.append(f"depth cap {DESIGN_PREVIEW_DEPTH} reached: states deeper than {DESIGN_PREVIEW_DEPTH} steps were not explored")
    if capped_clicks:
        notes.append(f"click cap ({DESIGN_PREVIEW_CLICKS} steps or {DESIGN_PREVIEW_BOARD_SECONDS}s) reached: some controls were not tried")
    if unreproduced:
        notes.append(f"{unreproduced} state(s) did not come back on replay (a timer, or randomness): their controls were not all tried")
    if skipped["covered"] or skipped["outside"]:
        notes.append(f"controls not clicked: {skipped['covered']} covered by another element, "
                     f"{skipped['outside']} outside the {width}x{height} frame (counted per state)")
    if sampled_out:
        notes.append(f"list rows sampled: {sampled_out} row click(s) skipped (each list of {DESIGN_PREVIEW_LIST_SAMPLE}+ rows "
                     "tries its first, second and last row)")
    if pages_preset:
        notes.append(f"state-bar presets tried on {len(pages_preset)} page(s)")
    if left:
        notes.append(f"clicks that left the board (a link, not a state): {', '.join(sorted(left))}")
    if timed:
        notes.append(f"waited for the timers of {', '.join(sorted(timed))}: a state shown only while a timer runs "
                     "(Saving...) is passed through, and the state recorded is the one after it")
    if typed:
        notes.append(f"typed a sample into {len(typed)} field(s): {', '.join(sorted(typed))}")
    if pickers:
        notes.append(f"{pickers} field(s) need a native picker (select, date, file, range): states behind them are not explored")
    if hovered:
        notes.append(f"hovered {len(hovered)} control(s)")
    print(f"note board={rel} view={view}: {len(states) - 1} state(s) beyond the initial one, {clicks} step(s)"
          + "".join(f"; {n}" for n in notes))
    record.setdefault("click", {})[view] = {"states": len(states) - 1, "clicks": clicks, "notes": notes}
    ctx["states"] += len(states) - 1
    return issues


def design_preview(args: argparse.Namespace) -> int:
    """Render each board of a job's canvas locally and print where the screenshots are."""
    started = time.monotonic()
    if args.phone_click:
        args.click = True
    root = design_root()
    scan = design_scan(root, args.job)
    design_require_manifest(scan, root, "design-preview")
    job = design_find_job(scan, args.job, "design-preview")
    project = job["path"] / "canvas" / "project"
    rounds = sorted(job["rounds"], key=lambda r: r["number"])
    current = next((r for r in rounds if r["data"] and r["data"]["status"] == "open"), rounds[-1] if rounds else None)
    slug = getattr(args, "page", None)
    if slug is not None:
        # v88 (P47-p5.S5): one page of a per-page round, from its boards.json -- a synthesized board index,
        # written only into the render folder (index.json), never into canvas.json; frame is the frame pass's.
        pages = (current or {}).get("data", {}).get("pages") if current and current["data"] else None
        if not pages or current["data"]["status"] != "open":
            raise SystemExit(f"design-preview: --page needs job {args.job}'s open round to be a per-page round "
                             f"(design-open --pages a,b,c)")
        if slug != DESIGN_FRAME_PAGE and slug not in pages:
            raise SystemExit(f"design-preview: --page {slug!r} is not a page of {design_address(job, current)} "
                             f"(pages: {', '.join(pages)}; or {DESIGN_FRAME_PAGE})")
        prel = f"jobs/{args.job}/rounds/{current['id']}/{DESIGN_PAGES_DIR}/{slug}"
        boards, found = design_page_boards(current["path"] / DESIGN_PAGES_DIR / slug / DESIGN_PAGE_BOARDS)
        missing = [k for k in boards if not (project / k).is_file()]
        if found or missing or not boards:
            raise SystemExit(f"design-preview: refused -- {prel}/{DESIGN_PAGE_BOARDS} cannot be rendered:\n"
                             + "\n".join(f"- {p}" for p in found + [f"board {k!r}: the file is missing" for k in missing])
                             + f"\n(run: {WORKFLOW_CMD} design-check {args.job} --page {slug})")
        try:
            index = read_json(project / "canvas.json")
        except (ValueError, OSError):
            index = {}
        index = {"page": slug, "round": current["id"], "boards": boards,
                 "designSystems": (index.get("designSystems") if isinstance(index, dict) else None) or []}
    else:
        try:
            index = read_json(project / "canvas.json")
        except (ValueError, OSError) as exc:
            raise SystemExit(f"design-preview: refused -- jobs/{args.job}/canvas/project/canvas.json is not readable "
                             f"({exc}); the drafter writes the canvas tree first")
        boards = index.get("boards") if isinstance(index, dict) else None
        if not isinstance(boards, dict) or not boards:
            raise SystemExit(f"design-preview: refused -- jobs/{args.job}/canvas/project/canvas.json lists no boards")
    unknown = [b for b in args.board or [] if b not in boards]
    if unknown:
        where = f"page {slug}'s {DESIGN_PAGE_BOARDS}" if slug is not None else "canvas.json"
        raise SystemExit(f"design-preview: no board {', '.join(map(repr, unknown))} in {where} "
                         f"(boards: {', '.join(sorted(boards))})")
    runtime = Path(args.runtime).expanduser()
    if not runtime.is_file():
        raise SystemExit(f"design-preview: refused -- no runtime at {runtime} (the orchestrator saves the Design canvas "
                         "type's artifact-type/dc-runtime.js for the job; pass that path)")
    # v61 (P37.S6) render reuse: the default --out is one stable folder per job and round under the design
    # root's git-ignored .preview/, so the critic finds the drafter's final render (preview.json, the PNGs,
    # the contact sheets) without re-rendering it. An --out elsewhere in the design root is refused.
    reuse = root / DESIGN_PREVIEW_DIR
    default_out = reuse / args.job / (current["id"] if current else "no-round")
    if slug is not None:
        default_out = default_out / DESIGN_PAGES_DIR / slug
    out = Path(args.out).expanduser().resolve() if args.out else default_out.resolve()
    try:
        out.relative_to(root.resolve())
    except ValueError:
        pass
    else:
        try:
            out.relative_to(reuse.resolve())
        except ValueError:
            raise SystemExit(f"design-preview: refused -- --out {out} is inside {DESIGN_ROOT_SHOWN}/ but not its git-ignored "
                             f"{DESIGN_PREVIEW_DIR}/; screenshots stay out of the design record")
    earlier = None
    if args.states_only:
        args.click = True
        try:
            earlier = read_json(out / "preview.json")
        except (ValueError, OSError):
            earlier = None
        if not isinstance(earlier, dict) or earlier.get("job") != args.job or not isinstance(earlier.get("boards"), dict):
            raise SystemExit(f"design-preview: refused -- --states-only reuses an earlier render, and {design_preview_shown(out)} "
                             "holds none of this job (run design-preview without it first)")
    browser = design_preview_browser(args.browser)
    if browser is None:  # an honest skip: a verdict, not an error, and never a claimed render
        print("preview=skipped reason=no-browser")
        print(f"hint: nothing was rendered or written; install Chrome or Chromium, or name one with --browser or ${DESIGN_PREVIEW_BROWSER_ENV}")
        return 0
    if not hasattr(os, "posix_spawn"):  # the DevTools pipe needs posix_spawn's fd mapping (macOS, Linux)
        print("preview=skipped reason=unsupported-platform")
        print("hint: nothing was rendered or written; design-preview drives the browser over a pipe that needs os.posix_spawn")
        return 0
    slot = design_preview_slot()  # held until this process exits
    runtime_bytes = runtime.read_bytes()
    if b"DCLogic" not in runtime_bytes:
        print(f"warning: {runtime} does not look like the Design canvas runtime (no DCLogic in it)")
    if job["problems"]:
        print(f"warning: design-check finds {len(job['problems'])} problem(s) in this job (run: {WORKFLOW_CMD} design-check {args.job})")
    ds = project / "ds"
    if ds.is_dir() and not (ds / ".gitignore").exists():  # the system cache is never committed
        (ds / ".gitignore").write_text("*\n", encoding="utf-8")
        print(f"wrote {DESIGN_ROOT_SHOWN}/jobs/{args.job}/canvas/project/ds/.gitignore (the system cache stays out of git)")
    system = scan["manifest"]["system"]
    for rec in index.get("designSystems") or []:
        ns = rec.get("namespace") if isinstance(rec, dict) else None
        if not isinstance(ns, str) or not ns:
            continue
        if not (ds / ns).is_dir():
            print(f"warning: system {ns} not cached -- x-import components will not mount "
                  f"(the orchestrator saves the system's files under canvas/project/ds/{ns}/)")
        elif ns == system.get("namespace"):
            for name in system.get("files") or []:
                if not (ds / ns / name).is_file():
                    print(f"warning: system {ns} cache lacks {name}")
    if out == default_out.resolve() and not (reuse / ".gitignore").is_file():  # the renders are local only
        write_text(reuse / ".gitignore", "*\n")
    out.mkdir(parents=True, exist_ok=True)
    if slug is not None:
        (out / "index.json").write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    if earlier is None:
        try:
            earlier = read_json(out / "preview.json") if (args.board and (out / "preview.json").is_file()) else None
        except (ValueError, OSError):
            earlier = None
        if not (isinstance(earlier, dict) and earlier.get("job") == args.job and isinstance(earlier.get("boards"), dict)):
            earlier = None
    # A board rendered again drops its own old PNGs first (a state that is gone must not linger): only files
    # named as this command names them (<stem>.<view>[.state-NN].png, <stem>.sheet.png); --states-only
    # drops only the states and sheets.
    import glob
    shot_name = re.compile(r"\.(?:(?:frame|phone|w320|text200)(\.state-\d+)?|(sheet)|(state-\d+\.)?align-\d+)\.png$")
    for stem in {rel[:-len(DESIGN_BOARD_SUFFIX)].replace("/", "__") for rel in (args.board or boards)}:
        for old in out.glob(f"{glob.escape(stem)}.*.png"):
            match = shot_name.fullmatch(old.name[len(stem):])
            if match and (not args.states_only or match.group(1) or match.group(2) or match.group(3)):
                old.unlink()

    def reading(key):
        title = boards[key].get("title") if isinstance(boards[key], dict) else None
        match = DESIGN_TITLE_RE.match(title) if isinstance(title, str) else None
        return (design_number(match.group(1)) if match else 10 ** 6, key)

    print(f"runtime=real path={runtime}")
    misses: list = []
    report = {"schema": 1, "job": args.job, "round": current["id"] if current else None, "page": slug, "out": design_preview_shown(out),
              "runtime": str(runtime), "click": bool(args.click), "phone": bool(args.phone),
              "phone_click": bool(args.phone_click), "states_only": bool(args.states_only),
              "boards": {}, "links": [], "issues": [], "totals": {}, "sheets": {}}
    profile = tempfile.mkdtemp(prefix="design-preview-profile-")
    try:
        page = DesignBrowser(browser, profile)
    except (RuntimeError, OSError, ValueError, KeyError) as exc:
        shutil.rmtree(profile, ignore_errors=True)
        print(f"issue check=browser: the browser {browser} did not start under the DevTools pipe: {exc}")
        print(f"preview=failed pngs=0 failed=1 issues=1 states=0 out={out}")
        return 1
    server = design_preview_server(project, runtime_bytes, misses)
    try:
        page.call("Page.addScriptToEvaluateOnNewDocument", {"source": DESIGN_PREVIEW_LISTENERS_JS})
    except RuntimeError:
        pass  # the keyboard check then reads the on* properties and the pointer cursor only
    ctx = {"page": page, "out": out, "misses": misses, "base": f"http://127.0.0.1:{server.server_address[1]}",
           "boards": boards, "project": project, "report": report, "unmeasured": set(), "edges": {}, "states": 0}
    if slug is not None:  # a page's links to another page's or the frame's boards are not dead: the join places them
        ctx["page_slug"] = slug
        ctx["link_boards"] = set(boards) | {f for f in design_tree_files(project) if f.endswith(DESIGN_BOARD_SUFFIX)}
    shots = issues = failed = 0
    rendered = []
    try:
        for rel in sorted(args.board or boards, key=reading):
            board = boards[rel]
            entry = board if isinstance(board, dict) else {}
            report["boards"][rel] = {"title": entry.get("title"), "page": entry.get("expand") == "fill",
                                     "interactive": entry.get("is_interactive") is True, "views": {}, "states": [],
                                     "click_errors": []}
            if args.states_only:  # the frame and phone views (and the WCAG views) of the earlier render are kept
                old_board = earlier["boards"].get(rel) or {}
                report["boards"][rel]["views"] = old_board.get("views") or {}
                for kept in ("keyboard",):
                    if kept in old_board:
                        report["boards"][rel][kept] = old_board[kept]
                report["boards"][rel]["interaction"] = [i for i in old_board.get("interaction", [])
                                                        if i.get("check") == "keyboard" or entry.get("is_interactive") is not True]
                for kept_view in report["boards"][rel]["views"].values():  # their boundaries are named already
                    for c in (kept_view.get("measured") or {}).get("ntc", []):
                        ctx.setdefault("ntc_named", {}).setdefault((c["part"], c["fg"], c["bg"]), rel)
                    align = (kept_view.get("measured") or {}).get("align")
                    for i in align.get("ink", []) if isinstance(align, dict) else []:  # and their label-ink styles
                        ctx.setdefault("ink_named", {}).setdefault(i["style"], {"board": rel, "more": {}})
                report["boards"][rel]["crops"] = [c for c in old_board.get("crops", []) if c.get("state") is None]
            try:
                w, h = int(board["w"]), int(board["h"])
            except (KeyError, TypeError, ValueError):
                w = h = 0
            if not (1 <= w <= DESIGN_PREVIEW_MAX and 1 <= h <= DESIGN_PREVIEW_MAX):
                message = f"canvas.json gives no usable w/h (1..{DESIGN_PREVIEW_MAX}); not rendered"
                print(f"issue board={rel} check=size: {message}")
                report["issues"].append({"board": rel, "check": "size", "message": message})
                issues += 1
                continue
            rendered.append(rel)
            board = dict(board, w=w, h=h)
            views = ["frame"] + (["phone"] if board.get("expand") == "fill" or args.phone else [])
            for view in views:
                if args.states_only:  # reuse the earlier render of this view; only its states are taken again
                    found = 0 if report["boards"][rel]["views"].get(view, {}).get("png") else -1
                    if found < 0:
                        print(f"note board={rel} view={view}: no earlier render of this view to reuse (run without --states-only)")
                        continue
                else:
                    found = design_preview_view(ctx, rel, board, view)
                if found < 0:
                    failed += 1
                elif not args.states_only:
                    shots += 1
                    issues += found
                if found < 0 or not args.click:
                    continue
                phone_walk = view == "phone" and args.phone_click and board.get("expand") == "fill"
                if board.get("is_interactive") is True and (view == "frame" or phone_walk):
                    try:  # --click: the frame view always; --phone-click: a PAGE's phone view too
                        script = page.call("Page.addScriptToEvaluateOnNewDocument", {"source": DESIGN_PREVIEW_TIMERS_JS})
                        try:
                            issues += design_preview_explore(ctx, rel, board, view)
                        finally:  # the next render loads without the timer watch
                            page.call("Page.removeScriptToEvaluateOnNewDocument", {"identifier": script["identifier"]})
                    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as exc:
                        print(f"issue board={rel} view={view} check=click: the click-through stopped: {exc}")
                        report["boards"][rel].setdefault("click", {}).setdefault(view, {})["stopped"] = str(exc)
                        issues += 1
                elif view == "frame" and board.get("expand") == "fill" and not args.states_only:  # a PAGE nobody clicks through still gets the hover pass
                    issues += design_preview_hover(ctx, rel, view, 0, set())
            if args.states_only:
                continue
            # v61 (P37.S6): the WCAG passes -- a PAGE's reflow and 200%-text views, an interactive board's keyboard pass.
            if board.get("expand") == "fill":
                for view in ("w320", "text200"):
                    found = design_preview_text_view(ctx, rel, view)
                    if found < 0:
                        failed += 1
                    else:
                        shots += 1
                        issues += found
            if board.get("is_interactive") is True:
                issues += design_preview_keyboard(ctx, rel, board)
        if args.contact_sheet:
            for rel in rendered:
                sheet = design_preview_sheet(ctx, rel)
                if sheet:
                    report["sheets"][rel] = sheet
    finally:
        page.close()
        server.shutdown()
        server.server_close()
        shutil.rmtree(profile, ignore_errors=True)
    for (part, fg, bg), more in ctx.get("ntc_more", {}).items():  # where a folded boundary is drawn again
        named = ", ".join(f"{r} ({el})" for r, el in list(more.items())[:3]) + (f" (+{len(more) - 3} more)" if len(more) > 3 else "")
        print(f"note: the non-text-contrast {part} {fg} on {bg} (first named on {ctx['ntc_named'][(part, fg, bg)]}) is also on "
              f"{len(more)} other board(s): {named}")
        report.setdefault("ntc_also", []).append({"part": part, "fg": fg, "bg": bg, "first": ctx["ntc_named"][(part, fg, bg)],
                                                 "boards": more})
    for style, seen in ctx.get("ink_named", {}).items():  # v88: where a label-ink style is drawn again
        if seen["more"]:
            more = seen["more"]
            named = ", ".join(f"{r} ({n})" for r, n in list(more.items())[:3]) + (f" (+{len(more) - 3} more)" if len(more) > 3 else "")
            print(f"note: check=align label-ink {style} (first named on {seen['board']}) is also on {len(more)} other board(s): {named}")
        report.setdefault("label_ink", []).append({"style": style, "first": seen["board"], "boards": seen["more"]})
    for rel in sorted(ctx["edges"]):
        for target, kind in sorted(ctx["edges"][rel].items()):
            report["links"].append({"from": rel, "to": target, "external": kind == "external"})
            if args.click:
                print(f"link from={rel} to={target}" + (" external" if kind == "external" else ""))
    if args.click:
        main = "Main" + DESIGN_BOARD_SUFFIX
        if args.board:
            print("note: the link graph covers only the boards rendered (--board), so no board is called unreachable")
        elif main in boards:
            reached, todo = {main}, [main]
            while todo:
                for target, kind in ctx["edges"].get(todo.pop(), {}).items():
                    if kind == "board" and target not in reached:
                        reached.add(target)
                        todo.append(target)
            for rel in rendered:
                if rel not in reached and report["boards"][rel]["page"]:
                    message = f"no chain of links from {main} reaches this page"
                    print(f"issue board={rel} check=unreachable: {message}")
                    report["issues"].append({"board": rel, "check": "unreachable", "message": message})
                    issues += 1
    seconds = round(time.monotonic() - started, 1)
    report["totals"] = {"pngs": shots, "failed": failed, "issues": issues, "states": ctx["states"], "seconds": seconds}
    if earlier is not None:  # a partial render (--board, --states-only) keeps the earlier render's other boards
        redone = set(report["boards"])
        report["boards"] = dict({k: v for k, v in earlier["boards"].items() if k not in redone and k in boards}, **report["boards"])
        report["issues"] = [i for i in earlier.get("issues", []) if i.get("board") not in redone] + report["issues"]
        report["links"] = [l for l in earlier.get("links", []) if l.get("from") not in redone] + report["links"]
        report["sheets"] = dict({k: v for k, v in (earlier.get("sheets") or {}).items() if k not in redone}, **report["sheets"])
        report["merged"] = sorted(set(report["boards"]) - redone)
    blocking = design_preview_blocking(report)
    report["self_check"] = {"result": "fail" if blocking else "pass", "blocking": blocking}
    report["advisory"] = design_preview_advisory(report)
    (out / "preview.json").write_text(json.dumps(report, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"preview={'failed' if failed and not shots else 'done'} pngs={shots} failed={failed} issues={issues} "
          f"states={ctx['states']} seconds={seconds:g} out={design_preview_shown(out)}")
    if report.get("merged"):
        print(f"note: preview.json keeps the earlier render of {len(report['merged'])} board(s) not rendered now")
    advisory = report["advisory"]
    if advisory:  # v88: the measured lines the drafter answers (fixed, or logged as intended) and the critic takes as facts
        print("advisory=" + ",".join(f"{c}:{n}" for c, n in advisory.items()))
    print(f"self_check={'fail' if blocking else 'pass'} blocking="
          + (",".join(f"{c}:{n}" for c, n in blocking.items()) or "none"))
    del slot
    if failed:
        return 1
    return 1 if args.strict and blocking else 0


def design_migrate(args: argparse.Namespace) -> None:
    if args.to == "2":
        design_migrate_schema2(args)
        return
    design_migrate_pre_v47(args)


def design_migrate_schema2(args: argparse.Namespace) -> None:
    """Move a schema-1 (v47 card) record -- cards/, tokens.css, rounds/ with every snapshot under them
    -- into DESIGN_SCHEMA1_DIR, unchanged, then rewrite design.json to schema 2 (id and name kept, a
    null-filled system). Every check runs before the first move (a refusal moves nothing); a dry run
    unless --apply; all-or-nothing; never a delete, never git."""
    root = design_root()
    mpath = root / "design.json"
    rel = lambda p: Path(shown(p)).as_posix()
    if not mpath.is_file():
        raise SystemExit(f"design-migrate --to 2: refused -- no {DESIGN_ROOT_SHOWN}/design.json; nothing to migrate "
                         f"(a new design record starts on schema {DESIGN_SCHEMA} with design-init)")
    try:
        manifest = read_json(mpath)
    except (ValueError, OSError) as exc:
        raise SystemExit(f"design-migrate --to 2: refused -- design.json is not valid JSON ({exc}); fix it by hand")
    if design_is_schema(manifest, DESIGN_SCHEMA):
        print(f"design-migrate --to 2: design.json is already schema {DESIGN_SCHEMA}; nothing to migrate")
        return
    if not design_is_schema(manifest, 1):
        schema = manifest.get("schema") if isinstance(manifest, dict) else None
        raise SystemExit(f"design-migrate --to 2: refused -- design.json schema {schema!r} is not 1")
    target = root / DESIGN_SCHEMA1_DIR
    rounds_dir = root / "rounds"
    problems = []
    if design_legacy_record(root):
        problems.append(f"a pre-v47 record is still at the root; run {WORKFLOW_CMD} design-migrate (no --to) first, which moves it into {DESIGN_LEGACY_DIR}/")
    if os.path.lexists(target):
        problems.append(f"{rel(target)} already exists (a schema-1 record was migrated before; move it aside by hand)")
    opened = []
    for entry in sorted(rounds_dir.iterdir()) if rounds_dir.is_dir() else []:
        try:
            if (entry / "round.json").is_file() and read_json(entry / "round.json").get("status") == "open":
                opened.append(entry.name)
        except (ValueError, OSError, AttributeError):
            problems.append(f"{rel(entry / 'round.json')} is not readable JSON; fix it by hand")
    if opened:
        problems.append(f"schema-1 round(s) {', '.join(opened)} still open: close each with the engine it was opened on before "
                        f"updating, or, if abandoned, set its round.json status to \"superseded\" with a closed_at by hand")
    wanted = {"schema": DESIGN_SCHEMA, "id": manifest.get("id"), "name": manifest.get("name"), "system": design_null_system()}
    problems.extend(design_manifest_problems(wanted))
    if problems:
        raise SystemExit("design-migrate --to 2: refused -- nothing moved:\n" + "\n".join(f"- {p}" for p in problems))
    moves = [(root / name, target / name) for name in ("cards", "tokens.css", "rounds") if os.path.lexists(root / name)]
    keep = {"design.json", "cards", "tokens.css", "rounds", "jobs", DESIGN_LEGACY_DIR, DESIGN_SCHEMA1_DIR}
    stayed = [f"design-migrate --to 2: left in place {rel(e)} (not part of the schema-1 record; move it by hand if it belongs there)"
              for e in sorted(root.iterdir()) if e.name not in keep and not e.name.startswith(".")]
    if not args.apply:
        print("\n".join([f"design-migrate --to 2: would move {rel(src)} -> {rel(dst)}" for src, dst in moves]
                        + [f"design-migrate --to 2: would rewrite {rel(mpath)} to schema {DESIGN_SCHEMA} (id and name kept, system null)"]
                        + stayed + ["design-migrate --to 2: dry run -- nothing moved; re-run with --apply"]))
        return
    done, made = [], False
    try:
        if moves:
            target.mkdir()
            made = True
        for src, dst in moves:
            os.replace(src, dst)
            done.append((src, dst))
        write_json(mpath, wanted)
    except OSError as exc:  # all-or-nothing: put back what already moved, then drop the folder made here
        undo = []
        for src, dst in reversed(done):
            try:
                os.replace(dst, src)
            except OSError as again:
                undo.append(f"- could not move {rel(dst)} back to {rel(src)}: {again}")
        if made:
            try:
                target.rmdir()
            except OSError:
                pass
        raise SystemExit(f"design-migrate --to 2: failed -- {exc}; " + (
            "rolled back, nothing moved" if not undo else "rollback incomplete:\n" + "\n".join(undo)))
    for src, dst in moves:
        print(f"design-migrate --to 2: moved {rel(src)} -> {rel(dst)}")
    print(f"design-migrate --to 2: rewrote {rel(mpath)} to schema {DESIGN_SCHEMA}")
    if stayed:
        print("\n".join(stayed))
    print("commit the move yourself (git sees it as renames)")


def design_migrate_pre_v47(args: argparse.Namespace) -> None:
    """Move a pre-v47 design record into DESIGN_LEGACY_DIR, unchanged. With no design.json the whole
    root is the old record, so every top-level entry moves (dot-entries stay); with design.json the
    repo already uses the drafter, so only the old record's parts move -- rounds without round.json,
    the root SIGNOFF.md and grounding/. Every check runs before the first move (a refusal moves
    nothing); a dry run unless --apply; never a delete (only an empty rounds/ is rmdir'ed), never git."""
    root = design_root()
    if not root.is_dir():
        raise SystemExit(f"design-migrate: refused -- no design root at {DESIGN_ROOT_SHOWN}/; nothing to migrate")
    legacy = root / DESIGN_LEGACY_DIR
    rounds_dir = root / "rounds"
    rel = lambda p: Path(shown(p)).as_posix()
    moves, left, problems = [], [], []
    outside = "not part of either contract; move it by hand if it belongs to the old record"
    if not (root / "design.json").exists():
        mixed = [e.name for e in sorted(rounds_dir.iterdir()) if (e / "round.json").exists()] if rounds_dir.is_dir() else []
        if mixed:
            problems.append(f"{rel(rounds_dir)} holds schema-1 round(s) {', '.join(mixed)} (they carry a round.json) but there is "
                            f"no design.json; if this repo uses the drafter, restore it with design-init first")
        jobs_dir = root / "jobs"
        if jobs_dir.is_dir() and any((e / "job.json").exists() for e in jobs_dir.iterdir()):
            problems.append(f"{rel(jobs_dir)} holds schema-{DESIGN_SCHEMA} job(s) but there is no design.json; restore it with design-init first")
        for entry in sorted(root.iterdir()):
            if entry.name in (DESIGN_LEGACY_DIR, DESIGN_SCHEMA1_DIR):
                continue
            if entry.name.startswith("."):
                left.append((entry, "a dot-entry"))
                continue
            moves.append((entry, legacy / entry.name))
    else:
        left.extend((e, outside) for e in (sorted(rounds_dir.iterdir()) if rounds_dir.is_dir() else [])
                    if not e.name.startswith(".") and not e.is_dir())
        moves.extend((part, legacy / part.relative_to(root)) for part in design_legacy_record(root))
        if moves and (root / "tokens.css").is_file():  # schema 1's own file: kept, but said out loud
            left.append((root / "tokens.css", "kept as schema 1's tokens.css (design-migrate --to 2 moves it into schema1/); "
                                              "if it belongs to the old record, move it into claude-design/ by hand"))
        contract = {"design.json", "cards", "tokens.css", "rounds", "jobs", DESIGN_LEGACY_DIR, DESIGN_SCHEMA1_DIR,
                    "SIGNOFF.md", "grounding"}
        left.extend((e, outside) for e in sorted(root.iterdir()) if e.name not in contract and not e.name.startswith("."))
    folders = [legacy] + ([legacy / "rounds"] if any(dst.parent == legacy / "rounds" for _, dst in moves) else [])
    for folder in folders:
        if os.path.lexists(folder) and not folder.is_dir():
            problems.append(f"{rel(folder)} exists and is not a folder")
    started = ("; a claude-design round was started first -- move each legacy round into claude-design/rounds/ by hand, "
               "renumbering after the existing ones, remove the emptied rounds/, then re-run")
    problems.extend(f"{rel(dst)} already exists" + (started if dst == legacy / "rounds" else "")
                    for _, dst in moves if os.path.lexists(dst))
    if problems:
        raise SystemExit("design-migrate: refused -- nothing moved:\n" + "\n".join(f"- {p}" for p in problems))
    stayed = [f"design-migrate: left in place {rel(path)} ({why})" for path, why in left]
    if not moves:
        print("\n".join(stayed + ["design-migrate: nothing to migrate"]))
        return
    if not args.apply:
        print("\n".join([f"design-migrate: would move {rel(src)} -> {rel(dst)}" for src, dst in moves] + stayed
                        + ["design-migrate: dry run -- nothing moved; re-run with --apply"]))
        return
    created, done = [], []
    try:
        for src, dst in moves:
            for folder in folders:
                if folder in dst.parents and not folder.is_dir():
                    folder.mkdir()
                    created.append(folder)
            os.replace(src, dst)
            done.append((src, dst))
    except OSError as exc:  # all-or-nothing: put back what already moved, then drop only the folders made here
        undo = []
        for src, dst in reversed(done):
            try:
                os.replace(dst, src)
            except OSError as again:
                undo.append(f"- could not move {rel(dst)} back to {rel(src)}: {again}")
        for folder in reversed(created):
            try:
                folder.rmdir()
            except OSError:
                pass
        raise SystemExit(f"design-migrate: failed -- {exc}; " + (
            "rolled back, nothing moved" if not undo else "rollback incomplete:\n" + "\n".join(undo)))
    for src, dst in moves:
        print(f"design-migrate: moved {rel(src)} -> {rel(dst)}")
    if any(src.parent == rounds_dir for src, _ in moves) and rounds_dir.is_dir():
        try:
            rounds_dir.rmdir()  # only ever succeeds on a truly empty folder
            print(f"design-migrate: removed the now-empty {rel(rounds_dir)}/")
        except OSError:
            pass
    if stayed:
        print("\n".join(stayed))
    print("commit the move yourself (git sees it as renames)"
          + ("" if (root / "design.json").exists() else "; run design-init only if this repo will use the drafter"))


def add_design_parsers(sub) -> None:
    """Design-init ... design-migrate: this part's commands, registered by the entry's build_parser in their place."""
    # The design contract, schema 2 (v60): the on-disk layout lives in design-cowork/reference/record.md "The design record".
    p = sub.add_parser("design-init", help=f"Write the design project manifest {DESIGN_ROOT_REL}/design.json (schema {DESIGN_SCHEMA}: id, name, a null-filled system); idempotent -- an unchanged manifest is not rewritten; a schema-1 manifest is refused (design-migrate --to 2)",
                       description=f"Create or update {DESIGN_ROOT_REL}/design.json, the one design project this repo holds. Defaults: id = the repo folder's name, slugified; name = the folder's name. The system record stays as it is (design-system sets it).")
    p.add_argument("--id", default=None, help="the project id: lowercase [a-z0-9-], starting alphanumeric, at most 63 characters")
    p.add_argument("--name", default=None, help="the project display name")
    p.set_defaults(func=design_init)

    p = sub.add_parser("design-system", help=f"Record the product's Design System Artifact in {DESIGN_ROOT_REL}/design.json (system: artifact, namespace, version, source, files); the orchestrator runs it after each system sync; idempotent",
                       description="--artifact is the system's address (https://claude.ai/artifact/<id> or /code/artifact/<id>, on claude.ai or claude.com, preview. allowed, nothing after the id). --namespace is the folder a canvas installs it under, project/ds/<namespace>/ ([a-z0-9][a-z0-9_-]{0,63}). --files names the system files a canvas installs, relative to the system's project/ (e.g. tokens.json,tokens.css,components/bundle.js,components/bundle.css); omitted, the recorded list is kept.")
    p.add_argument("--artifact", required=True, help="the Design System Artifact's address")
    p.add_argument("--namespace", required=True, help="the install folder under a canvas's project/ds/")
    p.add_argument("--version", required=True, help="the system version id the repo is synced to")
    p.add_argument("--source", default=None, help="where the system came from (e.g. the code path it was synced from)")
    p.add_argument("--files", default=None, help="comma-separated system files a canvas installs (replaces the recorded list)")
    p.set_defaults(func=design_system)

    p = sub.add_parser("design-open", help=f"Open the next design round of a job in a co-work slice: {DESIGN_ROOT_REL}/jobs/NN-<slug>/ (job.json, created on the slice's first round) and jobs/<job>/rounds/NN-<slug>/round.json, status open, with its critique level and (v88, --pages) its page list; refuses while the target job has an open round, and --new-job while another job of the slice has one",
                       description=f"A co-work slice designs one connected group of surfaces (one tab, one flow, the views a user moves between) as one job: one canvas, one publish per round, at most one open round; an unrelated page of the slice is drawn in the same job and stays on its canvas, unlinked (the round's join.json lists it as unrelated). The target: with neither flag, the slice's only job (its first round creates it; two or more jobs refuse and ask for --job); --new-job creates another job for the slice, refused while another job of the slice has an open round (draw it in that job with --job: an unrelated page stays on this canvas, unlinked) and allowed once every other job's rounds are closed, e.g. to merge the slice's surfaces into one connected job (re-running it with the same --slug resumes that job, as does a half-landed open); --job <job> opens the next round of that job, which must belong to --slice. A later round supersedes the job's previous one (a signed job is reopened; an implemented one refuses). Rounds number inside the job. Re-running an open with the open round's slug writes nothing. --critique records the round's critique level in round.json (absent in an older round reads as off). --pages a,b,c (v88) records the round's page list in round.json (pages): a per-page round, drawn as a frame pass (rounds/<round>/frame.md, canvas/project/frame.css and Shell.dc.html), one page drafter per page (rounds/<round>/pages/<slug>/{{boards.json,result.md}}, owning the canvas files whose stem starts with the page stem: the slug's words capitalised, list -> List*.dc.html, order-detail -> OrderDetail*, the longer stem winning), and a join (canvas.json, Main.dc.html, rounds/<round>/join.json); frame, main and shell are reserved. Its progress is derived from disk and printed by design-check as stage=, never written. Without --pages the round is a single-drafter round, as before. A legacy multi-job slice (a wave drawn before this rule) stays valid: each job's next round opens with --job, and holding several open jobs is no problem and no warning. The orchestrator writes the round's handoff.md next (with a critique: line); the drafter writes the canvas tree in jobs/<job>/canvas/project/.")
    p.add_argument("--slug", required=True, help="the round's slug (and the job's, when the round creates its job): lowercase words joined by hyphens")
    p.add_argument("--slice", required=True, help="the co-work slice that owns the job (e.g. P48-k2.S1)")
    p.add_argument("--title", default=None, help="display title (default: the slug)")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--new-job", action="store_true", help="create another job for a slice whose other jobs have no open round (refused while one does: a co-work slice designs one connected group as one job)")
    g.add_argument("--job", default=None, help="open the next round of this job (e.g. 02-settings); it must belong to --slice")
    p.add_argument("--critique", default=None, metavar="{" + ",".join(DESIGN_CRITIQUE_LEVELS) + "}", help=f"the round's critique level: {' | '.join(DESIGN_CRITIQUE_LEVELS)} (default off; a superseding round, the scoped re-draft after an operator note, stays off unless this is passed)")
    p.add_argument("--pages", default=None, metavar="a,b,c", help="v88: the round's pages, comma-separated slugs (lowercase words joined by hyphens; frame, main and shell reserved), recorded in round.json: a per-page round (frame -> pages -> join)")
    p.set_defaults(func=design_open)

    p = sub.add_parser("design-check", help=f"Check {DESIGN_ROOT_REL}/ against the design contract -- well-formed design.json, job.json and round.json (a critique level, when present, is off, critic or critic+judge), at most one open round per job, and each job's canvas tree (canvas.json keys, boards listed and present, Main.dc.html, path rules, the ./support.js line, board titles numbered 01..N, references inside project/), no stray HTML, waves/<slice>/ folders and every brief a handoff names, and (v61) no absolute or home path in the record's text (a problem while open, a warning once closed); v88: a per-page round's stage= line, --page <slug> for one page's files, check=pending-link, and the style lints (check=token-drift, transition-all, outline-none, zoom-disabled); warnings exit 0, problems exit 1",
                       description=f"Read-only. With a job id, only design.json and that job. Board titles start \"NN · \" with NN forming 01..N as a set (the layout is free). A canvas pinning another system version than design.json's is a warning, and so is an open job past {DESIGN_JOB_PAGES_MAX} Pages (boards with expand: fill) or {DESIGN_JOB_BOARDS_MAX} boards (one job is one connected group of surfaces, sized for one review sitting; a board another board mounts with <dc-import name=...>, a flow board's screen or a gap component's one-instance board, is not counted). Board lint, also warnings, for an open job or a job named by id: check=leaves-canvas (an href to an https URL other than Google Fonts CSS: the link leaves the prototype) and check=same-target-list (a link with a literal .dc.html target inside a <sc-for>: every row opens the same board) and, on a canvas of 2+ Pages, check=unlinked-page (a Page the entry Page -- Main.dc.html when it is a Page, else the Page with the lowest title number -- reaches by no chain of literal .dc.html hrefs or <dc-import> mounts: link it, or list it as unrelated in the round's join.json, where it stays on this canvas, unlinked; a Page join.json lists as unrelated is skipped, and warns once the entry reaches it). v88 style lints, warnings too: check=token-drift (a raw value where the system's local copy, canvas/project/ds/**/*.css, or canvas/project/frame.css names a token by custom property: a hex colour when they name a colour, a font-family or border-radius literal when they name a font family or a radius, a px length equal to the value of a length token of the property's role -- v90: a token's role is its name's family, space/spacing/gap/gutter for padding, margin, gap, inset and top/right/bottom/left, fs/font/text for font-size, lh/leading/line-height for line-height, tracking/letter for letter-spacing, radius tokens for border-radius alone, an unknown family for any property, so no cross-role token is suggested and a px no same-role token holds is not flagged; allowed: 0, 1px on border*/outline*, %, currentColor, inherit, initial, unset, transparent, a value holding var(...) anywhere (inside calc, min, max or clamp, in a shorthand: token-derived), a board's own custom properties and [data-proto] chrome), check=transition-all (transition: all), check=outline-none (outline: none or 0 with no :focus-visible rule in the board or frame.css) and check=zoom-disabled (a viewport meta with user-scalable=no or maximum-scale=1). v88 per-page rounds (design-open --pages): one stage= line per open per-page round -- frame (no frame.md yet), pages <done>/<n> (a page is done when rounds/<round>/pages/<slug>/result.md says status: done), join (every page done, no join.json) or joined (join.json present); a one-page round has no frame or join -- derived from disk; before the join, a canvas tree without canvas.json is not checked as a canvas. check=pending-link names each href=\"#to:<slug>\" placeholder left in a board: a warning before the round's join.json exists, a problem once it does, so design-close --words refuses it. --page <slug> checks one page of the job's open per-page round with no canvas.json needed: rounds/<round>/pages/<slug>/boards.json well-formed (the page's canvas.json board entries keyed by board path, with w, h and a title, without x, y, order or the \"NN · \" number), each listed board owned by the page's stem prefix (a foreign-prefix board is a problem) and present, every .dc.html the page owns listed, the files it owns carrying the ./support.js line and references inside project/, #to: only to a page of the round, no absolute path, and the board and style lints as warnings; --page frame checks the frame pass's boards (pages/frame/boards.json, stems no page owns) and frame.css. A legacy multi-job slice (a wave drawn before one job per slice) passes as drawn: several open jobs are no problem and no warning. The OK line lists every open round. {DESIGN_LEGACY_DIR}/ and {DESIGN_SCHEMA1_DIR}/ are legacy records and never read.")
    p.add_argument("job", nargs="?", default=None, help="a job id, e.g. 01-signin (default: every job)")
    p.add_argument("--page", default=None, metavar="SLUG", help="v88: check one page of the job's open per-page round (a slug of round.json's pages, or frame): its boards.json and the files its stem owns (list -> List*), no canvas.json needed")
    p.set_defaults(func=design_check)

    p = sub.add_parser("design-canvas", help="Record a job's canvas Artifact in its job.json: --url after creating it, --version after each publish (also records the published file list), --implemented once the signed job is built",
                       description="--url takes the same Artifact address rule as design-system. --version records canvas.version and sets canvas.published to the files under canvas/project/ (ds/ left out), which the next design-publish-plan diffs against, canvas.manifest to their byte sizes (what design-readback compares a listing with), the job's open round's published to the version (what design-sign presents), and canvas.system to the system version canvas.json pins for design.json's namespace (null when it pins none): the version that publish installed. --implemented needs the job signed.")
    p.add_argument("job", help="the job id, e.g. 01-signin")
    p.add_argument("--url", default=None, help="the canvas Artifact's address")
    p.add_argument("--version", default=None, help="the version id the last publish returned")
    p.add_argument("--implemented", action="store_true", help="mark the signed job implemented (its design is built)")
    p.set_defaults(func=design_canvas)

    p = sub.add_parser("design-publish-plan", help="Read-only: print the Artifact publish call for a job's canvas as JSON -- {url, root, file_path, files}: canvas.json as file_path, every other project/ file mapped to itself, files removed since the last publish mapped to null, and the system install entries on a first publish or a changed system pin; refuses without a canvas url or on a failing design-check",
                       description="The engine never calls claude.ai: the orchestrator passes this JSON to its Artifact publish. root is the job's canvas/ folder (it holds project/); ds/ is never sent from disk -- with design.json's system set, each system file maps as \"project/ds/<namespace>/<file>\": {\"artifact\": <system>, \"path\": \"project/<file>\"}, a server-side copy. Those copies are in the plan only on the job's first publish (canvas.version null) or when the version canvas.json pins for that namespace differs from job.json canvas.system, the version the last publish installed (absent on a job published before v60, which reads as the pin now); files left out of a publish are kept by the server.")
    p.add_argument("job", help="the job id, e.g. 01-signin")
    p.set_defaults(func=design_publish_plan)

    p = sub.add_parser("design-preview", help="Render each board of a job's canvas locally for the drafter's self-check: serve canvas/project/ (its ds/ system cache included) with the Design canvas type's real runtime as ./support.js over http on 127.0.0.1, screenshot every board in an exact viewport with a throwaway headless Chrome/Chromium profile driven over the DevTools pipe (no port), print one board=<file> png=<path> w= h= line per screenshot plus its issues, then the WCAG machine checks (non-text-contrast, reflow and overprint at 320px and 200%% text, keyboard), the advisory alignment and type lines (check=align, M1-M14) with a 2x zoom crop per align line, and a final self_check=pass|fail line; --page <slug> renders one page of a per-page round; at most 3 runs render at once on a machine; the render stays in the job's git-ignored round folder for the critic; no browser prints preview=skipped reason=no-browser, writes nothing and exits 0",
                       description=f"Never views the published canvas and never calls claude.ai. --runtime is the type's artifact-type/dc-runtime.js, which the orchestrator saves per job (never vendored); it renders standalone, so no stand-in ships. A board renders at its canvas.json w x h; a PAGE (expand: fill) grows to its content and also renders {DESIGN_PREVIEW_PHONE[0]} px wide (--phone: every board). Each line also gives the content size, unmounted parts (an x-import whose system global is missing, a dc-import whose board is missing), script errors and the issue count; issue lines name a clipped frame, a sideways overflow, runtime errors and files not found. Browser: --browser, else ${DESIGN_PREVIEW_BROWSER_ENV} (a named one is the only candidate), else the known Chrome/Chromium paths, else chromium/google-chrome on PATH. Writes only the PNGs, preview.json and the contact sheets -- by default into {DESIGN_ROOT_SHOWN}/{DESIGN_PREVIEW_DIR}/<job>/<round>/ (the job's open round, else its last; git-ignored, so outside the design record: the critic reads the drafter's final render there instead of rendering again; a whole run replaces the folder's shots, a --board run only that board's, and preview.json keeps the other boards' earlier render) -- and, once, canvas/project/ds/.gitignore (*) when ds/ exists; a system the canvas installs but ds/<namespace>/ lacks is a warning (the engine never fetches it). Exit 1 when a screenshot failed, or with --strict when the self-check fails. "
                                   f"SELF-CHECK (v61): the last line is self_check=pass|fail blocking=<check:count,...>|none over the whole (merged) render, where blocking = {', '.join(DESIGN_PREVIEW_BLOCKING)}; preview.json repeats it as self_check: {{result, blocking}}. "
                                   f"MEASURED CHECKS, in every view and state; every issue line reads 'issue board=<file> [view=<v>] [state=NN] check=<name>: ...'. "
                                   f"contrast: each visible text run (one per element; aria-hidden, invisible and zero-size text skipped) against the background its ancestors paint, color alpha, background alpha and ancestor opacity composited over white, colors in any CSS syntax; WCAG 4.5:1, or 3:1 for text >= 24px or >= 18.66px bold. A background image, gradient, filter or blend mode in the way makes the text 'unmeasured' (one line per board: judge it on the PNG), never a guess; not seen: a positioned sibling or <img> under the text, text-shadow, placeholder and field-value text, SVG text. "
                                   f"target: an a[href], button, input, select, textarea, summary, ARIA button/link/checkbox/radio/switch/tab/menuitem or tabindex>=0 element (visible, enabled) whose box is under {DESIGN_PREVIEW_TARGET}x{DESIGN_PREVIEW_TARGET}px, a field's <label> counted with it; a link inside a run of text is exempt (WCAG's inline exception); one line per control class (tag and first class) and shot, the rest counted ('+N more like it'). "
                                   "clipped: an element's own text cut off by overflow hidden/clip, unless it ends in an ellipsis or a line clamp. "
                                   "dead-link: an <a href> to a .dc.html that is no canvas.json board, to another relative file not in the tree, to an #id with no element, or a bare # placeholder; absolute URLs (https:, mailto:) are listed as external, never fetched. "
                                   "image: an <img> that loaded with naturalWidth 0 (background images are not checked). "
                                   "name: a button or link with no accessible name (text, aria-label, aria-labelledby, title or an inner img alt), a form field with no label (label for=, a wrapping label, aria-label, aria-labelledby; a placeholder is not one). "
                                   "non-text-contrast (WCAG 1.4.11): each visible, enabled control of the target set by element or role (inline text links, [data-proto], aria-hidden ones, UA-drawn checkboxes/radios/ranges/pickers and a scrim over a quarter of the viewport left out) whose boundary -- a >= 1px border that is not none/hidden, or else its own fill; the better of the two counts -- is under 3:1 against the color its ancestors paint around it, composited like contrast; a control with no border or fill, or with both under 1.1:1 (drawn in the surface's color), has no boundary to check unless it is a form field; a background image, gradient, filter or blend mode in the way makes it 'unmeasured'. One line per run for each border/fill-on-surface pair: later views, states and boards count it and a closing note lists the boards that draw it again. Not seen: box-shadow or outline boundaries, an icon's own shapes, focus indicators, a state told apart by a tint on a control whose border passes (the better boundary counts). "
                                   f"state-bar: the bar ([data-proto=\"state-bar\"]) or an ancestor position fixed or sticky; two or more bars on one board (a board showing one page in several windows carries exactly one, above all the windows and inside none); a bar showing more than one page's named group; a bar with no named [role=group]; with --click, a preset that moves to another page. design-check lints what the source shows (a pinned bar in a style or rule; an interactive board mounting one board as windows with no bar of its own). "
                                   f"WCAG VIEWS of each PAGE (expand: fill), each growing to its content: w320 ({DESIGN_PREVIEW_REFLOW}px wide) and text200 ({DESIGN_PREVIEW_PHONE[0]}px wide with every element's computed font-size read, then set to {DESIGN_PREVIEW_TEXT_SCALE}x, so nothing compounds); each names reflow (content wider than the view: a sideways scroll; WCAG 1.4.10/1.4.4), overprint (two text runs of different elements, neither containing the other, whose glyph boxes -- the middle half of each line box, cut to every overflow/clip-path ancestor -- cross where it shows: the topmost element there is one of them and nothing opaque hides the other; [data-proto] left out; identical pairs folded) and the clipped check, plus render issues the frame and phone views did not name (<stem>.w320.png, <stem>.text200.png). Not seen: real browser text zoom or a minimum-font setting, text in images or SVG, overlap with non-text shapes, an overprint a scroll or a click reveals. "
                                   f"keyboard (WCAG 2.1.1), on each is_interactive board from the settled frame view: Tab (Input.dispatchKeyEvent) until focus comes back to its first stop, at most {DESIGN_PREVIEW_TABS} presses; a control of the target set (outside [data-proto], not tabindex < 0, inside an open modal when there is one) the order never reached is unreachable (judged only when it came back). A click-only control -- an element with a click/mousedown/pointerdown listener (an on* property, or addEventListener) or, failing that, a pointer cursor its parent lacks, neither natively focusable nor tabindex >= 0, inside no control or label, holding none and under a quarter of the viewport -- is one line per tag and class; the first {DESIGN_PREVIEW_POP_PROBES} are clicked from a fresh load and one that opens a dialog, menu, tooltip, listbox or popover is named so. Not seen: focus order sense, a visible focus indicator, keys other than Tab (arrows, Escape, Enter on a fake control), a listener delegated to an ancestor with no pointer cursor. "
                                   f"ADVISORY MEASURED LINES (v88), in the frame view and every --click state of it, never the phone or WCAG views; never blocking (self_check= keeps its meaning), each one answered: the drafter fixes it or logs it as intended, the critic takes it as a measured fact. check=align, line 'issue board=<file> view=frame [state=NN] check=align: <kind> <px>px (<a> vs <b>)[: <note>] [(+N more like it)] crop=<png>', kinds {', '.join(DESIGN_PREVIEW_ALIGN_KINDS)}: a row is a flex row, a grid or a table-row, its children grouped into lines by vertical overlap; first-line: bare text cells of one line, one wrapping, whose first baselines spread more than {DESIGN_PREVIEW_ALIGN['firstLine']}px; label-value: bare single-line cells within 4px of size whose baselines spread {DESIGN_PREVIEW_ALIGN['labelValue']}px or more (under 3px: confirm it on the crop); beside-control: single-line text whose ink centre is {DESIGN_PREVIEW_ALIGN['beside']}px or more off a boxed control's centre in the same line; segment-label: controls of one class in one line whose label baselines spread {DESIGN_PREVIEW_ALIGN['segLabel']}px or more; control-height: controls in one line more than {DESIGN_PREVIEW_ALIGN['ctlH']}px apart in height; near-edge: stacked siblings whose left edges (the box when it has one, else the first text) are {DESIGN_PREVIEW_ALIGN['edge'][0]}-{DESIGN_PREVIEW_ALIGN['edge'][1]}px apart; label-ink: a single-line label whose ink centre sits {DESIGN_PREVIEW_ALIGN['ink']}px or more off its own control's or badge's centre, one line per text style per run (later boards counted, a closing note names them). Left out: visually hidden text, a fill the same as what is under it (no box), cells holding a text field. Baselines come from canvas font metrics, so a fallback face the DOM and the canvas resolve differently skews them. An align line folds per board, kind and the two elements' tag and class ('+N more like it'). Each printed align line gets a zoom crop: a clip around its two boxes plus {DESIGN_PREVIEW_CROP_MARGIN}px, at most {DESIGN_PREVIEW_CROP_MAX[0]}x{DESIGN_PREVIEW_CROP_MAX[1]}px, at device scale {DESIGN_PREVIEW_CROP_SCALE}, written beside the render as <stem>.align-NN.png (a state's: <stem>.state-NN.align-NN.png), at most {DESIGN_PREVIEW_CROPS} per board (a note says when the cap bites). The type and spacing rules M1-M14, each its own check name, one line per board, rule and element class: cramped-padding (multi-line text under {DESIGN_PREVIEW_MEASURES['pad']}px from an edge of its own box that has a border or a fill there; a control's top and bottom and single-line boxes exempt), heading-rhythm (two or more headings with no more space above than below), flat-type-steps (every step of the heading and body sizes under {DESIGN_PREVIEW_MEASURES['step']}x), size-count (over {DESIGN_PREVIEW_MEASURES['sizes']} font sizes on a board), line-length (paragraph text over {DESIGN_PREVIEW_MEASURES['measure']} characters a line), tight-leading (multi-line text on a line pitch under {DESIGN_PREVIEW_MEASURES['leading']}x its size; display text exempt), tiny-text (any text under {DESIGN_PREVIEW_MEASURES['ui']}px, or a paragraph under {DESIGN_PREVIEW_MEASURES['body']}px), wide-tracking (letter-spacing over {DESIGN_PREVIEW_MEASURES['tracking']}em on 20+ mixed-case characters), ragged-edges (a PAGE's headings and long paragraphs starting at more than {DESIGN_PREVIEW_MEASURES['rag'][0]} left edges, the three most used holding under {round(DESIGN_PREVIEW_MEASURES['rag'][3] * 100)}%), off-centre (a PAGE's content margins differing by {DESIGN_PREVIEW_MEASURES['centre']}px and 4.5% of the width or more; a left nav exempts it), ragged-row (panels of one row whose bottoms differ by more than {DESIGN_PREVIEW_MEASURES['ragRow']}px and 12% of the taller), radius-mix (over {DESIGN_PREVIEW_MEASURES['radii']} panel radii), nested-radii (a panel corner rounder than the panel it sits {DESIGN_PREVIEW_MEASURES['nest']}px or less inside, or more than 2px off concentric), numeric-align (a table column of {DESIGN_PREVIEW_MEASURES['figures']}+ figures set left, or without font-variant-numeric: tabular-nums), straggler (a paragraph's one-word last line: text-wrap: pretty; a heading's last line under a third of the one above: text-wrap: balance). [data-proto] chrome is left out of both. The line advisory=<check:count,...> before self_check= counts them. "
                                   "The canvas-only prototype chrome ([data-proto]: the state bar, the board-link strip) is exempt from target, non-text-contrast, overprint, keyboard, layout-shift and hover-contrast, and is never sampled as a list. "
                                   "Identical findings fold into one line ('+N more like it'); the phone view and the states repeat none the frame view named. The render's own issues are check=load, settle, too-tall, frame-clip, page-clip (a PAGE's state taller than its frame h, in the frame view: the render grows a PAGE, the canvas frame does not), overflow, unmounted, runtime-error, script-error, not-found, screenshot, size and browser. "
                                   f"--click: link lines and check=unreachable (a PAGE board, expand: fill, that no chain of links from Main.dc.html reaches; a Components board is not expected to be linked); on each is_interactive board, real mouse clicks (Input.dispatchMouseEvent) at each visible, enabled, uncovered control's centre, breadth first from the settled initial state, never a link that leaves the board. A state is a new visible DOM (shown elements with their class, style and open/expanded/selected/current/disabled attributes, and shown text, plus whether every visible text field holds text); a ticked box or a typed value alone is not a state. The state bar's presets ([data-proto=\"state-bar\"] buttons) are tried first, once per page (a preset sets its page's complete state), and a state on a page not met before is explored ahead of the rest; the page on screen is the bar's visible [role=group] name, else the first h1. A list of {DESIGN_PREVIEW_LIST_SAMPLE}+ alike rows is sampled: its first, second and last row. The type pass types a realistic sample into each visible text field (email, phone, name, postcode, search from the listed text, ...) and fills a form of two or more empty fields whole in one step, each a step of the path; select, date and other native pickers are not explored. After a step the page settles, the short timers it set are waited for (up to 3s: 'Saving...' is passed through to 'Saved') and its animations end. Each state's PNG is taken on its path replayed from a fresh load. A click that throws is check=click-error, once per control. check=layout-shift: a step that stays on the same page and resizes a control (outside [data-proto]) by more than {DESIGN_PREVIEW_SHIFT}px, or moves a header, nav or main by more than {DESIGN_PREVIEW_SHIFT}px; a step to another page is navigation, never a shift. check=same-target: two or more sampled rows of one list open the same state of another page. check=hover-contrast (PAGE boards, frame view, each state): the pointer rests on each button and link once per board (transitions off), and a text run of the hovered control that newly fails contrast is an issue (the a:hover color beating a system Button rendered as <a>). Frame view only, unless --phone-click; at most {DESIGN_PREVIEW_STATES} states, {DESIGN_PREVIEW_DEPTH} steps deep, {DESIGN_PREVIEW_CLICKS} steps and {DESIGN_PREVIEW_BOARD_SECONDS}s per board and view, each cap said on the board's note line. "
                                   "--states-only takes only the states again (--click implied), reusing the earlier render's views in --out; --contact-sheet writes <stem>.sheet.png per board, its shots tiled at half size or less under captions (a sheet line gives its token cost against the PNGs one by one). "
                                   f"--page <slug> (v88): one page of the job's open per-page round, its boards from rounds/<round>/{DESIGN_PAGES_DIR}/<slug>/{DESIGN_PAGE_BOARDS} (a synthesized board index, written to the render folder as index.json, never to canvas.json; refused while that file does not pass, or names a missing board), rendered into {DESIGN_PREVIEW_DIR}/<job>/<round>/{DESIGN_PAGES_DIR}/<slug>/ with every flag as for the whole canvas and self_check= over that page; {DESIGN_FRAME_PAGE} renders the frame pass's boards; a link to another page's or the frame's board is not dead, and a #to: placeholder is design-check's. "
                                   f"CONCURRENCY (v88): at most {DESIGN_PREVIEW_SLOTS} design-preview runs render at once on a machine (N page drafters render together); another waits for a slot, saying 'waiting for a render slot' once. Slots are flock()ed files in the temp folder's agentic-design-preview-slots/, released when a run exits (no stale lock); ${DESIGN_PREVIEW_SLOTS_ENV} sets another cap. "
                                   "preview.json: {schema, job, round, page, out, runtime, click, phone, phone_click, states_only, boards: {<file>: {title, page, interactive, crops: [{state, png, clip, line}], crops_capped, views: {frame|phone|w320|text200: {png, w, h, content, issues: [{check, message}], as_in_frame, measured}}, states: [{n, view, page, path, png, w, h, content, issues, measured}], click_errors, interaction: [{view, state, check, message}], click: {frame|phone: {states, clicks, notes}}, keyboard: {controls, reached, presses, wrapped, missed, click_only, opened}}}, links: [{from, to, external}], issues: [board-level {board, check, message} and every interaction finding {board, view, state, check, message}], sheets: {<file>: {png, w, h, tiles, scale, tokens}}, ntc_also, label_ink: [{style, first, boards}], advisory: {check: count}, merged (the boards kept from the earlier render), self_check: {result, blocking}, totals: {pngs, failed, issues, states, seconds}}; png paths are repo-relative under the workspace; measured holds every raw finding (contrast: el, size, weight, need, ratio, fg, bg; target: el, w, h; clipped; links; images; names; ntc: el, part, ratio, fg, bg, width; statebar; overprint in the WCAG views; align in the frame view and its states: {align: [{kind, px, a, b, key, box, note}], ink: [{style, n, px, dir, eg, box}], measure: [{rule, key, msg, box}], rows, runs}) and the counts texts, targets, fields, boundaries, bars.")
    p.add_argument("job", help="the job id, e.g. 01-signin")
    p.add_argument("--runtime", required=True, help="the path of the Design canvas type's runtime (artifact-type/dc-runtime.js) the orchestrator saved for this job")
    p.add_argument("--out", default=None, help=f"the folder for the PNGs, preview.json and the contact sheets (default: the job's round folder under the design root's git-ignored {DESIGN_PREVIEW_DIR}/, {DESIGN_ROOT_SHOWN}/{DESIGN_PREVIEW_DIR}/<job>/<round>/, where the critic finds the drafter's final render); never elsewhere inside the design root")
    p.add_argument("--browser", default=None, help=f"the Chrome/Chromium executable (default: ${DESIGN_PREVIEW_BROWSER_ENV}, then the known paths)")
    p.add_argument("--board", action="append", default=None, help="render only this board (its canvas.json key, e.g. Main.dc.html); repeatable")
    p.add_argument("--page", default=None, metavar="SLUG", help=f"v88: render one page of the job's open per-page round (design-open --pages), its boards read from rounds/<round>/{DESIGN_PAGES_DIR}/<slug>/{DESIGN_PAGE_BOARDS} as a synthesized board index (written to the render folder as index.json, never to canvas.json), into {DESIGN_PREVIEW_DIR}/<job>/<round>/{DESIGN_PAGES_DIR}/<slug>/; {DESIGN_FRAME_PAGE} renders the frame pass's boards; the other flags work as for the whole canvas; a link to a board outside the page is not dead and a #to: placeholder is left to design-check")
    p.add_argument("--phone", action="store_true", help=f"also render every board {DESIGN_PREVIEW_PHONE[0]} px wide (a PAGE always is)")
    p.add_argument("--phone-click", action="store_true", help=f"with --click (implied), also click through each interactive PAGE at {DESIGN_PREVIEW_PHONE[0]} px wide (<stem>.phone.state-NN.png); about doubles the time")
    p.add_argument("--click", action="store_true", help=f"also click through: print the link graph (link from= to= lines; a PAGE no link chain from Main.dc.html reaches is an issue) and, on each is_interactive board, try the state-bar presets first, then every control (list rows sampled) and a sample typed into each text field, breadth first, and screenshot each new state (state lines, <stem>.frame.state-NN.png), checking layout-shift, same-target, page-clip and, on PAGE boards, hover-contrast; at most {DESIGN_PREVIEW_STATES} states, {DESIGN_PREVIEW_DEPTH} steps deep, {DESIGN_PREVIEW_CLICKS} steps and {DESIGN_PREVIEW_BOARD_SECONDS}s per board, in the frame view only (--phone-click: also at {DESIGN_PREVIEW_PHONE[0]} px)")
    p.add_argument("--states-only", action="store_true", help="with --click (implied): take only the interaction states again, reusing the frame, phone and WCAG views of the earlier render in --out (refused when there is none); preview.json keeps every other board's earlier render")
    p.add_argument("--contact-sheet", action="store_true", help=f"also write one <stem>.sheet.png per board rendered: its views and states tiled at one reduced scale, {DESIGN_PREVIEW_SHEET_W}px wide, each under a caption (a sheet line gives its size and its token cost against the PNGs one by one)")
    p.add_argument("--strict", action="store_true", help=f"exit 1 when the self-check fails (any {', '.join(DESIGN_PREVIEW_BLOCKING)} issue); without it the exit code is as before")
    p.set_defaults(func=design_preview)

    p = sub.add_parser("design-readback", help="Read a job's published canvas back without pulling it: --listing parses the Artifact list scope:files output (file or - for stdin) and prints readback=unchanged|changed|changed-unlocated, one fetch= line naming only the files to read (changed and added by size against the publish manifest; the boards when no size moved or no manifest exists) and removed= ones; --fetched <dir> then diffs each fetched file against the local canvas tree (diff=<path> +A -B), and --apply copies them in; records readback in the open round's round.json; never prints file contents",
                       description="A listing at the job's recorded canvas.version is unchanged. Otherwise the project/ files outside ds/ are size-compared with job.json canvas.manifest (SKILL.md, index.html, artifact-type/ and project/ds/ are ignored). --fetched reads <dir>/project/<path> or <dir>/<path>, writes the unified diffs to <dir>/readback.diff (a scratch dir outside the design root, never the record) and settles the read-back as unchanged, differs (not copied) or edited (--apply: the operator's files copied over the local canvas files, so the record holds what they saw). --apply refuses, copying nothing, while a file gone from the canvas is still in the local tree.")
    p.add_argument("job", help="the job id, e.g. 01-signin")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--listing", default=None, metavar="FILE|-", help="the Artifact list scope:files output, saved to a file or piped on stdin (-)")
    g.add_argument("--fetched", default=None, metavar="DIR", help="the scratch out_dir the fetch list was read into with Artifact read")
    p.add_argument("--apply", action="store_true", help="with --fetched: copy the fetched files over the local canvas files")
    p.set_defaults(func=design_readback)

    p = sub.add_parser("design-sign", help="Sign every job presented at a stop on the operator's literal words: each open round of the slice that recorded a publish (design-canvas --version) is signed as design-close --words would; all or nothing -- one presented round without a settled read-back, without its build contract or failing design-check signs none; one line per job",
                       description="Rounds of the slice that published nothing yet are held, not signed. Each signed round gets a generated SIGNOFF.md (the words verbatim, the canvas version, the read-back, the open-item ids), its snapshot, and its job marked signed. With a mockup requested, the words at PENDING #1 are its go-ahead, not a signoff: sign at PENDING #2.")
    p.add_argument("--slice", required=True, help="the co-work slice whose presented jobs are signed (e.g. P48-k2.S1)")
    p.add_argument("--words", required=True, help="the operator's literal signoff words, recorded verbatim")
    p.set_defaults(func=design_sign)

    p = sub.add_parser("design-close", help="Close an open design round of a job: snapshot the job's canvas tree (ds/ left out) into the round folder, record canvas_version, then with --words generate SIGNOFF.md and mark the round and its job signed, or with --superseded mark the round superseded; idempotent",
                       description="--words needs the round's recorded publish of the job's canvas, a settled read-back of it (design-readback: unchanged or edited), the build contract (result.md ## Build, or a legacy build-prompt.md) and a passing design-check of the job (v88: so a #to: placeholder left after a per-page round's join, check=pending-link, refuses it); it generates SIGNOFF.md from the words, the canvas version, the read-back and the open_items: ids of the round's verdict blocks (a hand-written SIGNOFF.md is kept, with a warning). --canvas-version defaults to the read-back's live version, else the job's recorded canvas.version. Re-run a half-landed close; a closed round is never rewritten.")
    p.add_argument("round", help="the round: <job>/<round> (e.g. 01-signin/02-revise), or the bare round id when only one job has it")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--words", default=None, help="the operator's literal signoff words, recorded verbatim in round.json")
    g.add_argument("--superseded", action="store_true", help="a design question replaces the round before it is signed: snapshot and close it")
    p.add_argument("--canvas-version", default=None, help="the canvas version id the operator reviewed (default: job.json canvas.version)")
    p.set_defaults(func=design_close)

    p = sub.add_parser("design-migrate", help=f"Move a legacy design record aside, unchanged; a dry run unless --apply. Two migrations: with no --to, a pre-v47 (Claude Design) record into {DESIGN_ROOT_REL}/{DESIGN_LEGACY_DIR}/ (with no design.json every top-level entry, else only rounds without round.json, SIGNOFF.md and grounding/); with --to 2, a schema-1 (v47 card) record -- cards/, tokens.css, rounds/ -- into {DESIGN_ROOT_REL}/{DESIGN_SCHEMA1_DIR}/, rewriting design.json to schema 2",
                       description=f"All-or-nothing: every check runs before the first move, and a refusal moves nothing. Never deletes (only an emptied rounds/ is rmdir'ed), never runs git. Without --to (pre-v47 -> {DESIGN_LEGACY_DIR}/): an existing destination, or a design.json-less root whose rounds/ holds a round.json, refuses; dot-entries, and with design.json anything outside the contracts, are listed as left in place; design.json is never written (design-init stays separate). With --to 2 (schema 1 -> {DESIGN_SCHEMA1_DIR}/): refuses while a schema-1 round is open, while a pre-v47 record is at the root (migrate it first), or when {DESIGN_SCHEMA1_DIR}/ exists; keeps design.json's id and name and adds a null-filled system. The engine never reads {DESIGN_LEGACY_DIR}/ or {DESIGN_SCHEMA1_DIR}/.")
    p.add_argument("--to", choices=["2"], default=None, help="2: migrate a schema-1 record to schema 2 (default: the pre-v47 move into claude-design/)")
    p.add_argument("--apply", action="store_true", help="perform the moves (default: print them and move nothing)")
    p.set_defaults(func=design_migrate)
