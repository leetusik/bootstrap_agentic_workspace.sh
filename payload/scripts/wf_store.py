"""The engine's store: where the state is, paths, ids, events, phases, slices, the notebook, `next`, review, the
acceptance gate, check and archive. It imports no other engine module: the names its SEAMS list are
bound by the entry (workflow.py) before any command runs."""
from __future__ import annotations

import json
import os
import re
import secrets
import shutil
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


# The names this module calls in a module above it. It never imports that module: the entry (workflow.py) binds
# each name here before any command runs.
SEAMS = {
    "wf_git": (
        '_find_phase_dir', '_freeze_host_review_base', '_freeze_repo_anchors', '_parallel_verdict_pair',
        '_phase_repo_path', '_pr_label', '_pr_next_lines', '_pr_open_entries', '_pr_registry_names',
        '_repo_anchor_problems', '_repo_current_branch', '_pr_draft_advice', '_unstamped_set_warning',
        'explain_unit_lines', 'merge_ready_line', 'nested_next_lines', 'nested_repo_checks', 'new_pr_block',
        'parallel_start_hint', 'pr_block_problems', 'pr_open_lines', 'pr_rules_validate', 'pr_stack_lines',
    ),
    "wf_agenda": (
        'agenda_index', 'agenda_links', 'agenda_read_all', 'agenda_require_item', 'rebuild_agenda_dashboard',
        'rebuild_deferred_dashboard', 'validate_agenda',
    ),
    "wf_adapter": (
        '_patched_agent_md', 'executor_agent_files', 'resolve_routes', 'resume_card',
    ),
    "wf_cloud": (
        'cloud_commits_waiting_line', 'cloud_link_file', 'cloud_store_line', 'COMMITTED_AT',
    ),
}

# Where the state is. The engine's modules sit flat beside its entry, ENGINE. ROOT is the workspace this run reads
# and writes, found once, in order: (1) the engine's own parent when it sits inside a workspace (its parent holds
# works/: every installed copy, nested or at root); (2) the folder WORKFLOW_ROOT names (its workflow/ when that is a
# nested host); (3) the first folder up from the current directory that holds workflow/.agentic-nested.json (a
# nested host: its workflow/) or works/phases/ (an at-root workspace). None of them: one line, exit 2. So an engine
# outside any workspace (a plugin's folder) never writes into its own folder.
ENGINE = Path(__file__).resolve().parent / "workflow.py"
NO_WORKSPACE = "no workspace found from {cwd}; run from inside one or set WORKFLOW_ROOT"


def _walk_to_state(start: Path):
    """(state, folder) for the first folder from `start` up that holds `workflow/.agentic-nested.json` (nested,
    checked first at each level: the state is its `workflow/`) or `works/phases/` (at root: the folder), or None."""
    for d in (start, *start.parents):
        if (d / "workflow" / ".agentic-nested.json").is_file():  # == NESTED_MARKER
            return d / "workflow", d
        if (d / "works" / "phases").is_dir():
            return d, d
    return None


def find_root() -> Path:
    own = ENGINE.parent.parent
    if (own / "works").is_dir():
        return own
    named = os.environ.get("WORKFLOW_ROOT", "").strip()
    if named:
        folder = Path(named).expanduser().resolve()
        return folder / "workflow" if (folder / "workflow" / ".agentic-nested.json").is_file() else folder
    cwd = Path.cwd().resolve()
    found = _walk_to_state(cwd)
    if found is None:
        print(NO_WORKSPACE.format(cwd=cwd), file=sys.stderr)
        raise SystemExit(2)
    return found[0]


ROOT = find_root()
# Nested personal install (P28). The marker `.agentic-nested.json` beside `scripts/` says the engine and all
# workflow state live in a nested repo (`<host>/workflow`, ROOT) inside a host repo the operator does
# not own (HOST_ROOT): product code, git history for phase scope, and `.claude/agents` are the
# host's, while works/, docs/, executors.toml and the templates stay under ROOT. EVERY nested
# branch below is gated on that marker: with no `.agentic-nested.json`, NESTED is None, HOST_ROOT is None and
# behaviour and output are byte-for-byte the at-root engine's. A marker that exists but is malformed
# is never read as at-root mode -- `validate` reports it as an error and every other command refuses
# (see `main`). The installer writes the marker; this file owns its schema (NESTED_* below).
NESTED_MARKER = ".agentic-nested.json"
NESTED_SCHEMA = 1
NESTED_KEYS = ("schema", "host_root", "commit_convention", "renames")
NESTED_CONVENTION_KEYS = ("inferred", "confirmed", "text", "coauthor_trailers")
NESTED_TRAILERS = ("allowed", "forbidden", "unknown")
NESTED_RENAME_KINDS = ("skills", "agents")
# Optional, but strict when present: the installer's record of which host-side skill directories
# and agent files are the workspace's own (so `--update --nested` never mistakes them for a clash),
# (P40) `repos`, the multi-repo host's registry of its product repos, and (P51) `pr_rules`, the operator's
# decided team-rule conflicts for PRs (`load_pr_rules`; validate checks it as an error, never a marker problem,
# so a malformed record never stops the other commands).
NESTED_OPTIONAL_KEYS = ("installed", "repos", "pr_rules")
# P40: one registry entry per product repo of a multi-repo host (a host that tracks nothing and
# holds its repos at depth 1). The install is multi-repo iff `repos` is a non-empty list
# (`nested_repos()`); without it every code path is the single-repo nested one, byte-for-byte.
# `commit_convention` is the top-level four-key object or null (= inherit the host-level one);
# `rules` lists the repo's own rules files (AGENTS.md, CLAUDE.md, .agents/skills/*/SKILL.md), repo-relative.
NESTED_REPO_KEYS = ("name", "path", "default_branch", "commit_convention", "rules")
NESTED_REPO_NAME = re.compile(r"[A-Za-z0-9._-]+")
# P40.S10: `converted_from`, which the installer's `--to-multi-repo <repo>` appends to: one entry per
# per-repo nested install converted into this multi-repo host, `{"repo", "old_nested", "at"}` (strings:
# the repo's name, its old `<repo>/workflow`, the date). A known field, but lenient: nothing in the
# engine reads it (the installer renders its CLAUDE.local.md line), so a malformed value is a validate
# WARNING, never an error that would stop every command.
NESTED_NOTE_KEYS = ("converted_from",)
NESTED_CONVERTED_KEYS = ("repo", "old_nested", "at")
# P35: a nested phase worktree is a pair, and its host half needs a branch the operator names.
NESTED_HOST_BRANCH_REQUIRED = (
    "worktree start in a nested install needs --host-branch <name>: the host repo's branch for this phase's product commits, "
    "named by the host's own convention for branches (see repo convention), with no workspace phase/slice IDs in it; "
    "an existing branch is reused when no host worktree has it checked out (an explain phase may omit it: v86 cuts its host worktree "
    "detached, since an explain makes no host commit) -- nothing was written")
# v86 (§9.4): a worktree SET's repos ride beside a host BRANCH; only an explain phase's lone pair may be detached.
NESTED_SET_NEEDS_HOST_BRANCH = (
    "--repo and --repo-base need --host-branch <name>: a worktree set's host half is a branch the operator names; only an explain "
    "phase's plain pair may omit it (a detached host worktree, no host branch) -- nothing was written")
# phase.json `host_anchors` (nested only): the host HEAD at phase new and at the passing review --
# phase scope's range in the host repo, whose commits the nested repo never sees. `review_base`
# (P40, optional) is written at the passing review only when the base rule resolved something other
# than `created` (a rebased branch); absent means `created`, so older phase.json files stay valid.
HOST_ANCHOR_KEYS = ("created", "review_pass", "review_base")
# phase.json `repo_anchors.<name>` (multi-repo host only, P40): each registered repo's HEAD and branch
# at phase new, and both ends of its range frozen at the passing review. Exactly these four keys.
REPO_ANCHOR_KEYS = ("created", "branch", "review_pass", "review_base")


def nested_marker_problems(data) -> list:
    """Every way a parsed `.agentic-nested.json` breaks schema 1 -- empty when it is well-formed.

        {"schema": 1,
         "host_root": "..",                       # relative to the engine root; the host repo's root
         "commit_convention": {"inferred": "<text>" | null, "confirmed": false,
                               "text": "<text>" | null, "coauthor_trailers": "allowed" | "forbidden" | "unknown"},
         "renames": {"skills": {"<original>": "<installed>"}, "agents": {"<original>": "<installed>"}},
         "installed": {"skills": ["<installed>", ...], "agents": ["<installed>", ...]},  # optional
         "repos": [{"name": "<name>", "path": "<host-relative dir>", "default_branch": "<branch>" | null,
                    "commit_convention": {<the four keys above>} | null, "rules": ["<repo-relative path>", ...]}]}  # optional

    A confirmed convention carries its text and a decided trailer rule; an installed name is a bare
    file/directory name. `installed` (written by the installer) lists the host-side skill directories
    and agent files that are the workspace's own; when present it has exactly those two lists of
    distinct bare names, and every renamed name appears in it. `repos` (P40, the multi-repo registry)
    is a list of objects with exactly NESTED_REPO_KEYS: a unique name, a unique normalized host-relative
    path that is neither the nested workspace nor under `.claude/` and stays under the host, and a
    `commit_convention` checked by the same rules as the top-level one (or null). Other unknown
    top-level keys are not problems (`validate` warns about them)."""
    if not isinstance(data, dict):
        return [f"{NESTED_MARKER} is not a JSON object"]
    problems = []
    missing = [k for k in NESTED_KEYS if k not in data]
    if missing:
        problems.append(f"missing field(s) {', '.join(missing)}")
    if "schema" in data and (data["schema"] is True or data["schema"] != NESTED_SCHEMA):
        problems.append(f"schema {data['schema']!r} is not {NESTED_SCHEMA}")
    if "host_root" in data:
        raw = data["host_root"]
        if not (isinstance(raw, str) and raw.strip()) or os.path.isabs(raw):
            problems.append(f"host_root {raw!r} must be a non-empty path relative to the engine root (normally \"..\")")
        else:
            host = (ROOT / raw).resolve()
            if not host.is_dir():
                problems.append(f"host_root {raw!r} resolves to {host}, which is not a directory")
            elif host == ROOT or host not in ROOT.parents:
                problems.append(f"host_root {raw!r} resolves to {host}, which does not contain the engine root {ROOT}")
    if "commit_convention" in data:
        problems.extend(_convention_problems(data["commit_convention"], "commit_convention"))
    if "renames" in data:
        renames = data["renames"]
        if not isinstance(renames, dict):
            problems.append("renames is not an object")
        else:
            for kind in NESTED_RENAME_KINDS:
                table = renames.get(kind)
                if not isinstance(table, dict):
                    problems.append(f"renames.{kind} must be an object mapping an original name to its installed name")
                    continue
                for original, installed in table.items():
                    if not (original and _bare_installed_name(installed)):
                        problems.append(f"renames.{kind}: {original!r} -> {installed!r} is not a bare installed name")
    if "installed" in data:
        inst = data["installed"]
        if not isinstance(inst, dict) or sorted(inst) != sorted(NESTED_RENAME_KINDS):
            problems.append(f"installed must be an object with exactly {' and '.join(NESTED_RENAME_KINDS)} (lists of installed names)")
        else:
            for kind in NESTED_RENAME_KINDS:
                names = inst[kind]
                if not isinstance(names, list):
                    problems.append(f"installed.{kind} must be a list of installed names")
                    continue
                bad = [n for n in names if not _bare_installed_name(n)]
                if bad:
                    problems.append(f"installed.{kind}: {', '.join(repr(n) for n in bad)} is not a bare installed name")
                elif len(set(names)) != len(names):
                    problems.append(f"installed.{kind} lists a name twice")
                table = data.get("renames", {}).get(kind) if isinstance(data.get("renames"), dict) else None
                if isinstance(table, dict) and not bad:
                    missing = sorted(v for v in table.values() if isinstance(v, str) and v not in names)
                    if missing:
                        problems.append(f"installed.{kind} does not list the renamed {', '.join(missing)}")
    if "repos" in data:
        problems.extend(_repos_problems(data["repos"], data.get("host_root")))
    return problems


def _converted_from_problems(raw) -> list:
    """Every way the marker's `converted_from` (P40.S10) breaks its shape: a list of objects with exactly
    the three string keys of NESTED_CONVERTED_KEYS. `validate` prints each one as a warning."""
    if not isinstance(raw, list):
        return [f"converted_from must be a list of objects with {', '.join(NESTED_CONVERTED_KEYS)} (strings)"]
    problems = []
    for i, entry in enumerate(raw):
        label = f"converted_from[{i}]"
        if not isinstance(entry, dict):
            problems.append(f"{label} is not an object")
            continue
        missing = [k for k in NESTED_CONVERTED_KEYS if k not in entry]
        unknown = sorted(str(k) for k in entry if k not in NESTED_CONVERTED_KEYS)
        if missing:
            problems.append(f"{label}: missing field(s) {', '.join(missing)}")
        if unknown:
            problems.append(f"{label}: unknown field(s) {', '.join(unknown)} (an entry has exactly {', '.join(NESTED_CONVERTED_KEYS)})")
        for key in NESTED_CONVERTED_KEYS:
            if key in entry and not (isinstance(entry[key], str) and entry[key].strip()):
                problems.append(f"{label}.{key} must be a non-empty string")
    return problems


def _convention_problems(conv, label: str) -> list:
    """Every way a `commit_convention` object breaks schema 1, each problem prefixed with `label`:
    the top-level one (`commit_convention`) and each registry entry's (`repos[<i>].commit_convention`)."""
    if not isinstance(conv, dict):
        return [f"{label} is not an object"]
    problems = []
    gone = [k for k in NESTED_CONVENTION_KEYS if k not in conv]
    if gone:
        problems.append(f"{label}: missing field(s) {', '.join(gone)}")
    for key in ("inferred", "text"):
        if key in conv and conv[key] is not None and not isinstance(conv[key], str):
            problems.append(f"{label}.{key} must be a string or null")
    if "confirmed" in conv and not isinstance(conv["confirmed"], bool):
        problems.append(f"{label}.confirmed must be true or false")
    if "coauthor_trailers" in conv and conv["coauthor_trailers"] not in NESTED_TRAILERS:
        problems.append(f"{label}.coauthor_trailers {conv['coauthor_trailers']!r} is not one of {', '.join(NESTED_TRAILERS)}")
    if conv.get("confirmed") is True:
        if not (isinstance(conv.get("text"), str) and conv["text"].strip()):
            problems.append(f"{label}: a confirmed convention records its text")
        if conv.get("coauthor_trailers") not in ("allowed", "forbidden"):
            problems.append(f"{label}: a confirmed convention records coauthor_trailers allowed or forbidden")
    return problems


def _repos_problems(repos, host_root) -> list:
    """Every way the marker's `repos` registry (P40) breaks its shape. `host_root` is the marker's own
    value: the nested-dir and stays-under-the-host rules read it, and are skipped when it is unusable
    (that is already a host_root problem). Structural only: whether each path is a git work tree
    root, hidden from the host and clean of workspace files is `validate`'s (`nested_repo_checks`)."""
    if not isinstance(repos, list):
        return [f"repos must be a list of objects with exactly {', '.join(NESTED_REPO_KEYS)}"]
    host = nested_dir = None
    if isinstance(host_root, str) and host_root.strip() and not os.path.isabs(host_root):
        candidate = (ROOT / host_root).resolve()
        if candidate.is_dir() and candidate != ROOT and candidate in ROOT.parents:
            host, nested_dir = candidate, Path(os.path.relpath(ROOT, candidate)).as_posix()
    problems, names, paths = [], set(), set()
    for i, repo in enumerate(repos):
        label = f"repos[{i}]"
        if not isinstance(repo, dict):
            problems.append(f"{label} is not an object")
            continue
        missing = [k for k in NESTED_REPO_KEYS if k not in repo]
        unknown = sorted(k for k in repo if k not in NESTED_REPO_KEYS)
        if missing:
            problems.append(f"{label}: missing field(s) {', '.join(missing)}")
        if unknown:
            problems.append(f"{label}: unknown field(s) {', '.join(unknown)} (a repo entry has exactly {', '.join(NESTED_REPO_KEYS)})")
        if "name" in repo:
            name = repo["name"]
            if not (isinstance(name, str) and NESTED_REPO_NAME.fullmatch(name)):
                problems.append(f"{label}.name {name!r} must match [A-Za-z0-9._-]+")
            elif name in names:
                problems.append(f"{label}.name {name!r} is listed twice")
            else:
                names.add(name)
        if "path" in repo:
            raw = repo["path"]
            bad = _repo_path_problem(raw, host, nested_dir)
            if bad:
                problems.append(f"{label}.path {raw!r} {bad}")
            elif raw in paths:
                problems.append(f"{label}.path {raw!r} is listed twice")
            else:
                paths.add(raw)
        branch = repo.get("default_branch")
        if branch is not None and not (isinstance(branch, str) and branch.strip() and branch == branch.strip()):
            problems.append(f"{label}.default_branch must be a branch name or null")
        if repo.get("commit_convention") is not None:
            problems.extend(_convention_problems(repo["commit_convention"], f"{label}.commit_convention"))
        if "rules" in repo and not (isinstance(repo["rules"], list) and all(isinstance(r, str) and r.strip() for r in repo["rules"])):
            problems.append(f"{label}.rules must be a list of repo-relative paths")
    return problems


def _repo_path_problem(raw, host, nested_dir):
    """Why a registry `path` is unusable, or None. A path is host-relative and normalized (no `.`,
    `..` or empty segment, no trailing `/`), never the nested workspace or a dir around it, never
    under `.claude/`, and -- when the host is known -- still under the host once symlinks resolve."""
    if not (isinstance(raw, str) and raw.strip()) or raw != raw.strip():
        return "must be a non-empty path relative to the host root"
    if os.path.isabs(raw) or "\\" in raw:
        return "must be relative to the host root, not absolute"
    parts = raw.split("/")
    if any(part in ("", ".", "..") for part in parts):
        return "must be a normalized path under the host root (no '.', '..' or empty segment, no trailing '/')"
    if parts[0] == ".claude":
        return "is under .claude/, which holds the workspace's own files"
    if nested_dir is not None:
        if raw == nested_dir or raw.startswith(nested_dir + "/"):
            return "is the nested workspace"
        if nested_dir.startswith(raw + "/"):
            return "contains the nested workspace"
    if host is not None:
        resolved = (host / raw).resolve()
        if host not in resolved.parents:
            return f"resolves to {resolved}, outside the host {host}"
    return None


def _bare_installed_name(name) -> bool:
    """A skill directory or agent file stem as installed in the host: one plain path segment."""
    return (isinstance(name, str) and bool(name.strip()) and name == name.strip()
            and "/" not in name and "\\" not in name and not name.startswith("."))


def _load_nested() -> tuple:
    """(marker, problems): (None, []) when ROOT holds no `.agentic-nested.json` -- at-root mode, the only
    case that touches nothing. A marker that cannot be read or parsed comes back as `{}` with its
    problem, so it still counts as nested (never silently at-root)."""
    path = ROOT / NESTED_MARKER
    if not os.path.lexists(path):
        return None, []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return {}, [f"cannot be read as JSON ({exc})"]
    return (data if isinstance(data, dict) else {}), nested_marker_problems(data)


NESTED, NESTED_PROBLEMS = _load_nested()
HOST_ROOT = None
if NESTED is not None and isinstance(NESTED.get("host_root"), str) and NESTED["host_root"].strip() and not os.path.isabs(NESTED["host_root"]):
    HOST_ROOT = (ROOT / NESTED["host_root"]).resolve()
# The command prefix every printed hint uses: WORKFLOW_CMD from the environment when set (a plugin names its own);
# for an engine outside the workspace, its own path from the host root (the workspace root at root); else from
# the host root when nested (cwd = <host>), from the workspace root otherwise -- so at root it is exactly the
# literal the hints always printed. A nested marker too broken to name its host gets the absolute path, right
# from any cwd.
if os.environ.get("WORKFLOW_CMD", "").strip():
    WORKFLOW_CMD = os.environ["WORKFLOW_CMD"].strip()
elif ENGINE.parent.parent != ROOT:
    WORKFLOW_CMD = f"python3 {Path(os.path.relpath(ENGINE, HOST_ROOT or ROOT)).as_posix()}"
elif HOST_ROOT is not None:
    WORKFLOW_CMD = f"python3 {Path(os.path.relpath(ROOT, HOST_ROOT)).as_posix()}/scripts/workflow.py"
elif NESTED is not None:
    WORKFLOW_CMD = f"python3 {ROOT / 'scripts' / 'workflow.py'}"
else:
    WORKFLOW_CMD = "python3 scripts/workflow.py"
# Appended to every printed `worktree start <P>` hint: a nested install's start needs the host branch
# (P35), which the operator names; at root it is empty, so the hints print exactly as before.
NESTED_HOST_BRANCH_ARG = " --host-branch <name>" if NESTED is not None else ""


def shown(path: Path) -> str:
    """A path as the operator's shell must type it: relative to the host root when nested (so
    `workflow/works/...` resolves from a session started at the host), else today's ROOT-relative
    string. OUTPUT ONLY -- a path persisted into index.json, slice.json, phase.json or events.jsonl
    stays ROOT-relative, because the state it points into lives in the nested repo."""
    if HOST_ROOT is not None:
        return os.path.relpath(path, HOST_ROOT)
    if NESTED is not None:  # a marker too broken to name its host: absolute, right from any cwd
        return str(path)
    return str(path.relative_to(ROOT))


def shown_rel(rel: str) -> str:
    """`shown` for a ROOT-relative string read back from stored state (an index or phase path):
    host-relative when nested, and at root the stored string itself, untouched."""
    return shown(ROOT / rel) if HOST_ROOT is not None else rel


WORKS = ROOT / "works"
ACTIVE = WORKS / "phases" / "active"
ARCHIVED = WORKS / "phases" / "archived"
DEFERRED_OPEN = WORKS / "deferred" / "open"
DEFERRED_PROMOTED = WORKS / "deferred" / "promoted"
DEFERRED_DROPPED = WORKS / "deferred" / "dropped"
# The agenda (P66): one folder per item, `works/agenda/<AID>/agenda.json`, rewritten in place on every
# change and never moved -- a status is a field, not a folder (unlike deferred jobs).
AGENDA = WORKS / "agenda"
PHASE_STATUSES = {"planned", "in_progress", "in_review", "pending", "blocked", "done"}
SLICE_STATUSES = {"todo", "ready", "in_progress", "in_review", "changes_requested", "pending", "blocked", "done"}
# The typed pending record (v61): every operator stop says what kind it is and what the operator's words on
# return will do. Stored on the slice as `pending: {kind, on_words, since}` while it is `pending`, and
# cleared whenever it leaves `pending`. A closed set; `other` is the escape hatch.
SLICE_STOP_KINDS = {
    "wave": "a design-round stop (the slice's canvas is published; the operator reviews it)",
    "mockup": "the mockup gate (the operator walks the requested mockup)",
    "decision": "a question only the operator answers (DECOMP's design style, a needs_operator)",
    "operator-action": "the operator must run or provide something",
    "limit": "a usage limit with no reset time",
    "other": "anything else",
}
DEFERRED_STATUSES = {"deferred", "ready", "promoted", "done", "dropped"}
# An agenda item's STORED status. In progress is never stored: it is derived (an Open item with a linked
# phase not done), so a listing shows five statuses. AGENDA_SHOWN is the one table of their signed words.
AGENDA_STATUSES = {"open", "deferred", "solved", "dropped"}
AGENDA_SHOWN = {"open": "Open", "in_progress": "In progress", "deferred": "Deferred", "solved": "Solved",
                "dropped": "Dropped"}
# agenda.json's keys, in the order every write gives them (any other key is kept, after these).
AGENDA_KEYS = ("id", "title", "note", "status", "order", "created_at", "changed_at", "outcome", "reason")
AGENDA_TITLE_MAX = 200
AGENDA_TITLE_REFUSAL = "Enter a title of 1–200 characters."  # the signed design's field error, word for word
REVIEW_VERDICTS = {"pass", "changes_requested", "blocked"}
# Ids (readable ids, after v83): an id the operator can say. New phase and deferred ids are the next
# NUMBER plus a two-symbol random tail -- `P46-k2`, `D92-x4`, slices `P46-k2.S1` -- the number one more than the highest
# numbered id of that kind the workspace can see (old `P45` and tailed `P45-m9` alike, archived included),
# the tail drawn with `secrets` from v73's alphabet (Crockford base32 in lowercase without the look-alikes
# `i l o u`) and holding at least one letter, so `P46-12` never reads as a range. Two branches that each
# make the next id draw the same number but (923 times in 924) different tails; a same-number same-tail
# pair surfaces as a git add/add conflict on the phase folder at merge, never a silent mix (no engine
# guard). Older ids are never renamed: v72's `P<n>` / `D<n>` and v73's minted `P-<token>` / `D-<token>`
# (4 symbols) stay valid beside the new shape. These patterns are the ONE predicate every reader of a
# stored id uses (a digit after `P` means numbered, with or without a tail; a dash after `P` means a v73
# token), and `id_sort_key` the one order a listing uses (numbered ids by number, then v73 tokens by
# creation). Slice ids keep their per-phase suffixes: `P46-k2.S1`, `P-7kq2.S1`, `P12.S1`.
ID_TOKEN_ALPHABET = "0123456789abcdefghjkmnpqrstvwxyz"
ID_TOKEN_LENGTH = 4  # a v73 token: guards only an explicit `--phase P-7kq2` / `--id D-m3xa` now
ID_TOKEN_PATTERN = "[0-9a-hjkmnp-tv-z]{4}"
ID_TAIL_LENGTH = 2
ID_TAIL_LETTERS = "abcdefghjkmnpqrstvwxyz"
# Two alphabet symbols, at least one a letter (never all digits): 32^2 - 10^2 = 924 tails per number.
ID_TAIL_PATTERN = "(?:[a-hjkmnp-tv-z][0-9a-hjkmnp-tv-z]|[0-9][a-hjkmnp-tv-z])"
ID_MODE_WORDS = frozenset({"gate", "plan"})  # `auto` and `only` cannot be drawn: u, o and l are not in the alphabet
PHASE_ID_PATTERN = rf"P(?:[0-9]+(?:-{ID_TAIL_PATTERN})?|-{ID_TOKEN_PATTERN})"
DEFERRED_ID_PATTERN = rf"D(?:[0-9]+(?:-{ID_TAIL_PATTERN})?|-{ID_TOKEN_PATTERN})"
# An agenda item's id is always a number and a tail (`A7-m3`): it was born after v83, so no untailed `A7`
# and no v73 `A-<token>` shape exists for it. Its numbers are a sequence of their own.
AGENDA_ID_PATTERN = rf"A[0-9]+-{ID_TAIL_PATTERN}"
# A numbered id, tailed or not, any prefix: group 1 the number, group 2 the tail (None when untailed).
NUMBERED_ID_RE = re.compile(rf"[PDA]([0-9]+)(?:-({ID_TAIL_PATTERN}))?")
SLICE_SUFFIX_PATTERN = "[A-Z][A-Z0-9]*"
PHASE_ID_RE = re.compile(PHASE_ID_PATTERN)
DEFERRED_ID_RE = re.compile(DEFERRED_ID_PATTERN)
AGENDA_ID_RE = re.compile(AGENDA_ID_PATTERN)
SLICE_ID_RE = re.compile(rf"({PHASE_ID_PATTERN})\.({SLICE_SUFFIX_PATTERN})")
# An archive folder is `<yyyymmdd>_<hhmmss>_<phase id>_<slug>` (`_archive_one`); the slug is lowercase.
ARCHIVE_FOLDER_ID_RE = re.compile(rf"_({PHASE_ID_PATTERN})_")
# The slice kinds (workspace v34). `kind` routes real behavior -- `co-work` in particular means
# orchestrator-inline (the round's lifecycle and the operator's words stay on the main thread), so a
# typo like `cowork` reads as ordinary work. `slice new` makes an unknown kind with one advice: line
# (it routes on the high row, the safe direction), `validate()` warns of it, and `promote-deferred`
# still refuses one before it mints a phase. `--risk` is not checked either: unrecognized values route
# high. A kind routes before `risk` is read (`slice_route`): decomposition, review and co-work to the high
# row, research (findings-only: no product code) to the research row, never the mid row.
SLICE_KINDS = {"implementation", "review", "decomposition", "research", "fix", "docs", "qa", "co-work"}
# Phase-notebook budget (v35; an index since v61): phase.md is read and written ONE SECTION at a
# time (`section`), so it is an index of what the next slice needs, not a store. Long
# material -- a contract, a signed-design summary -- lives in `topics/<slug>.md` beside it,
# linked by one line. 40 KB is a soft cap: still a WARNING, never an error, because a hard cap
# invites truncating exactly the notes that matter; the warning names the biggest sections
# so the fix is a move to `topics/` or to the slice's `result.md`, never a deletion.
PHASE_MD_BUDGET = 40 * 1024
# Notebook entries: a section's entries are what `section --entry` reads and writes
# and what `--to-topic` moves (`notebook_entries` is the one parser). An entry over
# LONG_ENTRY_BYTES (or one with nested list lines) is long: the move's candidate. A moved entry
# leaves one pointer line whose gist is a verbatim excerpt of at most GIST_MAX characters; a gist
# with fewer than GIST_PLAIN_MIN characters of plain text once markdown, links and the label are
# stripped is a bare link, which says nothing where the decision was, so the move refuses it.
LONG_ENTRY_BYTES = 512
GIST_MAX = 160
GIST_PLAIN_MIN = 24
# Per-section budgets (bytes), warning-only like PHASE_MD_BUDGET, which still judges the total. A
# section not named here gets SECTION_BUDGET_DEFAULT; None = no budget of its own (Slices is
# generated; Doc impact is only in notebooks from before its retirement), though both still count to the total.
# `notebook_report` is the one reader: the index, slice finish, validate and next all print from it.
SECTION_BUDGETS = {"decisions": 12288, "operator questions": 8192, "notes for later slices": 6144,
                   "now": 2048, "objective": 2048, "slices": None, "doc impact": None}
SECTION_BUDGET_DEFAULT = 6144
SECTION_REMEDIES = {"operator questions": "collapse answered entries with --resolve OQ<n> --pointer <ref>",
                    "now": "rewrite it shorter with --replace"}
# Paged reads: a section or topic block over PAGE_BYTES prints one page at a time, whole entries
# only. Bytes are at least characters, so a page plus its header stays under the Bash tool's
# 30,000-character output limit and is never printed cut off.
PAGE_BYTES = 24 * 1024
# Execution streams (workspace v24; opt-in again since v43). A phase.json MAY carry an
# optional `execution` block. `mode: "parallel"` = the phase runs on its own branch +
# worktree, stamped by `worktree start` -- which a phase gets ONLY when the operator asks
# for it. No block = the phase runs on the default stream, which is where every phase runs
# unless asked otherwise; that is the v43 default and it needs no marker.
# `mode: "default"` = a LEGACY pin written by v42's (since retired) skip command and `phase new --on-main`,
# when the worktree was the default and staying on main needed saying. Nothing new is ever stamped with it -- but `phase_execution` still returns
# None for it, so a pinned phase IS a default-stream phase everywhere, and `worktree start`
# still refuses one rather than silently overriding an old deliberate pin.
# See `phase_execution` / `phase_pinned`.
EXECUTION_MODES = {"parallel"}
PINNED_MODE = "default"
# The default worktree home. Nested under the repo so Claude Code's EnterWorktree can enter it
# from anywhere (it accepts `.claude/worktrees/` paths even from inside another worktree), and
# excluded through the repo's own info/exclude so the default checkout never sees it.
WORKTREES_DIR = ".claude/worktrees"
# What the stamp commit carries besides the phase folder: the generated works/ files that
# `rebuild_index_and_state` rewrites, plus the event log. Nothing else on the tree enters it.
STAMP_WORKS_FILES = ("works/state.json", "works/index.json", "works/backlog.md", "works/deferred.md", "works/agenda.md",
                     "works/events.jsonl")
# A default-stream phase in any of these states means main is mid-flight, so a phase
# branch may not be merged into it yet (the quiet-point gate, `worktree gate`).
BUSY_PHASE_STATUSES = ("in_progress", "in_review", "pending", "blocked")
# The quiet point's checked exemption (v86, §9.2): a branch whose diff since its merge-base with the
# default side touches only its own phase folder, the STAMP_WORKS_FILES, or paths ADDED under one of
# these folders (a deferred job filed, or an agenda item added, on the branch: a new minted-id folder
# cannot conflict) cannot collide with in-flight default-stream work, so `worktree gate` drops the
# busy-default-stream reason for it.
# The agenda across streams (P66): item folders are real truth, merged by git; a phase worktree may add,
# change or delete items like any checkout. Only an ADDED item is exempt here: a changed or deleted existing
# item keeps the busy reason and the gate names its path. At the merge the same item changed on both sides
# (or changed on one, deleted on the other) is an ordinary git conflict in its agenda.json, resolved by taking
# one side; two Open items left with one `order` are tolerated (the listing breaks the tie by id, and the next
# agenda-move renumbers). Links are written only into this stream's own phases (`agenda_phase_elsewhere`):
# this checkout's copy of another stream's phase.json is frozen at the stamp, and rewriting it would collide
# with that stream's own writes; agenda-delete leaves such a link (validate then warns of it, dangling).
GATE_EXEMPT_ADDED_PREFIXES = ("works/deferred/open/", "works/agenda/")
# An explain phase's publishable unit (`- unit:` in intent.md's `## Explain`); absent reads `book`,
# the only unit before v86.
EXPLAIN_UNITS = ("document", "book", "chapter")
EXPLAIN_UNIT_DEFAULT = "book"
# Regenerated from works/phases/** by `worktree merge-finish`; never merged by hand (see .gitattributes).
# docs/current/*.md are plain files agents edit, so they are not among them.
GENERATED_FILES = ("works/state.json", "works/index.json", "works/backlog.md", "works/deferred.md", "works/agenda.md")
# The executor agent files Claude Code loads: the host's `.claude/agents` when nested (Claude Code
# finds agents walking up from the session's cwd, the host root), the workspace's otherwise.
# executors.toml and .env stay at ROOT either way.


def _main_host_checkout(host: Path) -> Path:
    """Nested only (P35): the MAIN host checkout, even when HOST_ROOT is a host worktree. The main
    checkout is the parent of the host's common git dir when that dir is a plain `.git`; anything
    else (no git, a submodule's `.git/modules/<name>`, a separate GIT_DIR) falls back to `host`."""
    try:
        proc = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                              cwd=str(host), capture_output=True, text=True, timeout=10)
    except Exception:  # noqa: BLE001 - git is optional; the host's own folder is the honest fallback
        return host
    common = Path(proc.stdout.strip()) if proc.returncode == 0 and proc.stdout.strip() else None
    if common is None or common.name != ".git":
        return host
    return common.parent


# Nested only: the main host checkout (P35), resolved once. HOST_ROOT itself on the default stream;
# inside a parallel set HOST_ROOT is the host worktree and this is still the main checkout. Its
# `.claude/agents` is where Claude Code reads the agents from (a phase worktree pair has no `.claude/`
# of its own, so `<host-wt>/.claude/agents` never exists), and the multi-repo registry's paths
# resolve against it (`nested_repo_path`, P40), never against HOST_ROOT.
MAIN_HOST = _main_host_checkout(HOST_ROOT) if HOST_ROOT is not None else None
CLAUDE_AGENTS = MAIN_HOST / ".claude" / "agents" if MAIN_HOST is not None else (HOST_ROOT or ROOT) / ".claude" / "agents"


def nested_repos() -> list:
    """P40: the multi-repo registry -- the marker's `repos` entries; `[]` when the key is absent or
    empty, at root, or when the marker is malformed (every command but validate refuses then). The
    install is multi-repo iff this is non-empty, and EVERY multi-repo branch is gated on it, so a
    single-repo nested or at-root install runs exactly today's code."""
    if NESTED is None or NESTED_PROBLEMS:
        return []
    repos = NESTED.get("repos")
    return list(repos) if isinstance(repos, list) else []


def nested_repo_path(repo: dict) -> Path:
    """P40: where a registry entry lives -- under the MAIN host checkout, never HOST_ROOT. Inside a
    parallel set HOST_ROOT is the host worktree, where a repo with no worktree in that set is simply
    absent; reading the registry there must not report it missing (S2 §17). The set side
    (`HOST_ROOT / path`, a repo's worktree in the set) belongs to the parallel commands."""
    return (MAIN_HOST or HOST_ROOT) / repo["path"]


def _git_work_tree_root(path: Path) -> bool:
    """True when `path` is the root of its own git work tree. `git -C` on a plain directory walks up
    and answers for the enclosing repo (the host), so `--show-toplevel` must be `path` itself."""
    if not path.is_dir():
        return False
    try:
        proc = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=str(path), capture_output=True, text=True, timeout=10)
    except Exception:  # noqa: BLE001 - no git: nothing is a work tree root
        return False
    top = proc.stdout.strip()
    return proc.returncode == 0 and bool(top) and Path(top).resolve() == path.resolve()


def now_iso() -> str:
    """The engine's one stamp: local time to the second with its offset (`2026-11-17T15:40:24+09:00`). A zone
    whose offset is not whole minutes (a POSIX TZ such as `XXX-09:00:30`) would write `+09:00:30`, outside the
    agenda's stamp form (AGENDA_STAMP_FORM), so the same instant is written in UTC (`+00:00`) instead."""
    now = datetime.now().astimezone().replace(microsecond=0)
    offset = now.utcoffset()
    if offset is not None and offset.total_seconds() % 60:
        now = now.astimezone(timezone.utc)
    return now.isoformat()


def timestamp() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def slugify(value: str, fallback: str = "item") -> str:
    slug = re.sub(r"[^a-zA-Z0-9._-]+", "_", value.strip().lower()).strip("_")
    return slug or fallback


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


# Cloud mode's agenda inbox applier runs each web change as its agenda command in-process; while it does, every
# file the command is about to write (write_text, append_event) has its prior bytes noted here first, so a command
# that crashes midway can be undone to the tree it found. None, the default, outside that one call: nothing noted.
_CLOUD_UNDO = None


def _cloud_undo_note(path: Path) -> None:
    if _CLOUD_UNDO is None:
        return
    key = str(path)
    if key not in _CLOUD_UNDO:
        try:
            _CLOUD_UNDO[key] = path.read_bytes() if path.is_file() else None
        except OSError:
            _CLOUD_UNDO[key] = False  # unreadable: never restored blind (the undo's rescan names what is left)


def write_text(path: Path, text: str, executable: bool = False) -> None:
    if _CLOUD_UNDO is not None:
        _cloud_undo_note(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".tmp_", suffix=path.name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        if executable:
            os.chmod(tmp, os.stat(tmp).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def write_json(path: Path, data: object) -> None:
    write_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def write_json_stamped(path: Path, data: dict, key: str, stamp: str) -> dict:
    """Write a generated JSON file whose `key` stamps when it was built, unless nothing but that
    stamp would change: then write nothing and keep the old stamp. So a read (`next`,
    a plain `rebuild`) leaves these tracked files, and the tree, unchanged; the stamp moves only
    with a real change (v74). Returns `data` holding the stamp that is on disk."""
    try:
        old = read_json(path)
    except (OSError, ValueError):
        old = None
    if isinstance(old, dict) and key in old and {k: v for k, v in old.items() if k != key} == {k: v for k, v in data.items() if k != key}:
        data[key] = old[key]
        return data
    data[key] = stamp
    write_json(path, data)
    return data


# The event log: `append_event` is its one writer, `all_events()` its one reader (works/events.jsonl).
def append_event(event_type: str, **payload: object) -> None:
    event = {"ts": now_iso(), "type": event_type, **payload}
    path = WORKS / "events.jsonl"
    if _CLOUD_UNDO is not None:
        _cloud_undo_note(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")


def _read_events(path: Path) -> tuple:
    """(events, skipped) of one JSONL event file: a line that is not JSON counts as skipped, a JSON value that
    is not an object is dropped silently (dispatch-summary's long-standing reading)."""
    events, skipped = [], 0
    if not path.exists():
        return events, skipped
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            skipped += 1
            continue
        if isinstance(obj, dict):
            events.append(obj)
    return events, skipped


def all_events(counts=None) -> list:
    """The whole event log, works/events.jsonl in file order. `counts["skipped"]` gets the number of
    unreadable lines."""
    events, skipped = _read_events(WORKS / "events.jsonl")
    if counts is not None:
        counts["skipped"] = skipped
    return events


def _meter_ts(value) -> "float | None":
    """An ISO-8601 timestamp (transcripts write `...Z`, events `+09:00`) as epoch seconds, else None."""
    if not isinstance(value, str) or not value:
        return None
    try:
        return datetime.fromisoformat(value[:-1] + "+00:00" if value.endswith("Z") else value).timestamp()
    except ValueError:
        return None


def head_commit() -> str:
    """The current HEAD sha, or "" where git cannot answer -- the provenance half of a doc's
    last-updated marker.

    Best effort and NEVER fatal: the engine has to keep working in a tarball copy, a fresh
    unpushed install or any checkout without git, so every failure (missing binary, not a repo,
    an empty repo with no commit yet, a timeout) records nothing instead of raising. Honest
    semantics: this is the commit the version was *created at* -- the version file itself lands
    in a later commit -- so the sha is provenance, while `created_at` and `source` are the
    staleness keys a reader actually judges by.

    Nested install: the HOST's HEAD -- the product state the doc describes -- never the nested
    repo's, which only holds workflow state. The same helper stamps a nested phase's host anchors.
    """
    try:
        proc = subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(HOST_ROOT or ROOT), capture_output=True, text=True, timeout=10)
    except Exception:  # noqa: BLE001 - git is optional; a doc version must still be writable without it
        return ""
    sha = proc.stdout.strip()
    return sha if proc.returncode == 0 and re.fullmatch(r"[0-9a-f]{7,40}", sha) else ""


def h2_sections(text: str) -> list:
    """`(heading, bytes)` for every `## ` section of a markdown document, biggest-unit-first order.

    A section runs from its heading to the next `## `, so deeper headings count as its body -- that
    is the unit a reader actually reads. Fenced blocks are skipped (a `## ` inside a shell example
    is a comment, not a heading), and the size is bytes, because bytes are what the reader pays.
    """
    lines = text.split("\n")
    fenced, starts = False, []
    for i, line in enumerate(lines):
        if line.startswith("```") or line.startswith("~~~"):
            fenced = not fenced
        elif not fenced and line.startswith("## "):
            starts.append(i)
    out = []
    for j, i in enumerate(starts):
        end = starts[j + 1] if j + 1 < len(starts) else len(lines)
        out.append((lines[i].strip(), len("\n".join(lines[i:end]).encode("utf-8"))))
    return out


def _created_sort_stamp(created_at) -> str:
    """A `created_at` as a string that sorts by time across machines in different zones (UTC), or
    the value as written when it is not an ISO time; "" when absent."""
    if not created_at:
        return ""
    try:
        return datetime.fromisoformat(str(created_at)).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    except (TypeError, ValueError):
        return str(created_at)


def id_sort_key(value, created_at=None) -> tuple:
    """The ONE order of phase and deferred ids in a listing: numbered ids first, tailed or not, by number
    and then tail -- `(0, n, tail or "")`, so `P46` before `P46-k2` before `P46-x4` and an all-numeric
    list sorts exactly as v72 sorted it -- then v73's minted tokens, by creation time and then token --
    `(1, created_at, token)`; an id of neither shape sorts last, as written. Deterministic: a numbered
    id reads no record. Phases still SELECT by `order`; this key lists them, and breaks a tie in `order`."""
    text = str(value)
    numeric = NUMBERED_ID_RE.fullmatch(text)
    if numeric:
        return (0, int(numeric.group(1)), numeric.group(2) or "")
    token = re.fullmatch(rf"[PD]-({ID_TOKEN_PATTERN})", text)
    if token:
        return (1, _created_sort_stamp(created_at), token.group(1))
    return (2, "", text)


def sort_phase_ids(ids, phases=None) -> list:
    """`ids` in `id_sort_key` order, a token's `created_at` read from `phases` (default: the active
    phases, read only when a token is listed); an id no record names sorts as if it had none."""
    ids = list(ids)
    if phases is None:
        phases = all_active_phases() if any(id_sort_key(pid)[0] == 1 for pid in ids) else []
    created = {p.get("id"): p.get("created_at") for p in phases if isinstance(p, dict)}
    return sorted(ids, key=lambda pid: id_sort_key(pid, created.get(pid)))


def phase_dirs() -> list:
    """The active phase folders in selection order: by `order`, a tie broken by `id_sort_key` (two
    branches that each created a phase give both the same next order; the merge must still select
    the same phase on every machine, never in directory-listing order)."""
    if not ACTIVE.exists():
        return []
    found = []
    for p in ACTIVE.iterdir():
        if p.is_dir() and (p / "phase.json").exists():
            data = read_json(p / "phase.json")
            found.append(((data.get("order", 999999), id_sort_key(data.get("id", p.name), data.get("created_at"))), p))
    return [p for _key, p in sorted(found, key=lambda item: item[0])]


def slice_dirs(phase_dir: Path) -> list:
    slices = phase_dir / "slices"
    if not slices.exists():
        return []
    return sorted([p for p in slices.iterdir() if p.is_dir() and (p / "slice.json").exists()], key=lambda p: read_json(p / "slice.json").get("order", 999999))


def all_active_phases() -> list:
    phases = []
    for pdir in phase_dirs():
        data = read_json(pdir / "phase.json")
        data["path"] = str(pdir.relative_to(ROOT))
        data["slices"] = []
        for sdir in slice_dirs(pdir):
            sdata = read_json(sdir / "slice.json")
            sdata["path"] = str(sdir.relative_to(ROOT))
            data["slices"].append(sdata)
        phases.append(data)
    return phases


def deferred_jobs() -> dict:
    groups = {"open": [], "promoted": [], "dropped": []}
    for label, base in [("open", DEFERRED_OPEN), ("promoted", DEFERRED_PROMOTED), ("dropped", DEFERRED_DROPPED)]:
        if not base.exists():
            continue
        for ddir in sorted([p for p in base.iterdir() if p.is_dir()]):
            djson = ddir / "deferred.json"
            if not djson.exists():
                continue
            data = read_json(djson)
            data["path"] = str(ddir.relative_to(ROOT))
            groups[label].append(data)
        # In id order (D2 before D10 before D10-x4, then v73's minted D- tokens by creation), not folder-name order.
        groups[label].sort(key=lambda d: id_sort_key(Path(d["path"]).name, d.get("created_at")))
    return groups


def clean_cell(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, dict):
        if "slice_id" in value:
            value = value.get("slice_id") or value
        elif "id" in value:
            value = value.get("id") or value
        else:
            value = json.dumps(value, ensure_ascii=False)
    return str(value).replace("|", "\\|").replace("\n", " ")


def status_box(status: object) -> str:
    """Dashboard checkbox glyph: done -> x, pending (waiting on operator) -> ~, ready (plan approved) -> r, else blank."""
    return "x" if status == "done" else "~" if status == "pending" else "r" if status == "ready" else " "


def phase_execution(data) -> dict:
    """The phase's parallel-execution block, or None when it belongs to the default stream.

    Shape (all fields optional in the file, absence of the whole block = today's behavior):

        "execution": {
          "mode": "parallel",              # "parallel" = own stream; "default" (pinned, v42) and anything else = default stream
          "branch": "phase/P13-some-slug", # required when parallel; the stream key
          "worktree": "/path or null"      # informational (null on a plain clone)
        }

    An older install's `consolidation` key in the block (the retired doc debt) is ignored.

    A nested install (P35) adds the host half of the worktree pair: `host_worktree`, `host_branch`,
    `host_base`, `host_base_sha`, `host_branch_created` and `base_branch`; there `worktree` is the
    NESTED worktree (`<host_worktree>/workflow`). See `_nested_execution_problems`.

    Read the block only through this helper so every caller agrees on what "parallel" means.
    """
    if not isinstance(data, dict):
        return None
    execution = data.get("execution")
    if not isinstance(execution, dict) or execution.get("mode") not in EXECUTION_MODES:
        return None
    return execution


def phase_in_flight(data) -> bool:
    """True when a phase is stamped for its own worktree and is still running there (P35.S7, closes D57).

    It has a parallel execution block (`phase_execution`) AND either still holds a worktree
    (`execution.worktree` is not null: running, or merged but not yet torn down) or has not reached
    `done`. A stamped phase that is `done` with its worktree torn down is history: it is not in
    flight, so `## Streams` and `next`'s `parallel_phases_elsewhere` skip it. Accepts a phase record
    or a `works/index.json` entry; both carry `status` and `execution`.
    """
    execution = phase_execution(data)
    if not execution:
        return False
    return execution.get("worktree") is not None or data.get("status") != "done"


NESTED_EXECUTION_HOST_KEYS = ("host_worktree", "host_branch", "host_base", "host_base_sha", "host_branch_created")
HOST_DETACHED = object()  # v86: the ## Streams Host branch cell of a detached host worktree (never a branch name)


def _host_branch_cell(execution: dict):
    """The Host branch cell's value: the stamped branch, `HOST_DETACHED` for an explain phase's detached
    host worktree (`host_branch` stamped null beside the other host keys, v86), else None (`-`)."""
    if execution.get("host_branch"):
        return execution["host_branch"]
    if "host_branch" in execution and "host_worktree" in execution:
        return HOST_DETACHED
    return None


def _nested_execution_problems(phase_id: str, execution: dict) -> list:
    """`validate`'s checks on the host half of a parallel execution block (P35), [] when sound.

    A nested `worktree start` stamps five host keys -- `host_worktree` (the host worktree; null once
    torn down), `host_branch`, `host_base` (the ref as resolved), `host_base_sha`, `host_branch_created`
    -- plus `base_branch` (the nested repo's branch at start). The five appear together, and only in a
    nested install; `base_branch` comes with them there, and is otherwise only type-checked (a root
    stamp of it is additive). `worktree` is the nested worktree: `<host_worktree>/<workflow>` while
    both are set. A block without any of them (every at-root block, and a legacy one) is untouched.
    v86 (§9.4): `host_branch` may be null -- a DETACHED host worktree (an explain phase's) -- and then
    `host_branch_created` must be false and the block carries no `repos` (a set needs a host branch)."""
    problems = []
    present = [k for k in NESTED_EXECUTION_HOST_KEYS if k in execution]
    if "base_branch" in execution:
        value = execution.get("base_branch")
        if value is not None and not (isinstance(value, str) and value.strip()):
            problems.append(f"phase {phase_id} has invalid execution.base_branch {value!r}; expected the nested repo's branch name or null")
    if not present:
        return problems
    if NESTED is None:
        problems.append(f"phase {phase_id} has nested-only execution keys ({', '.join(present)}) in an at-root install; they are written only by a nested worktree start")
        return problems
    missing = [k for k in (*NESTED_EXECUTION_HOST_KEYS, "base_branch") if k not in execution]
    if missing:
        problems.append(f"phase {phase_id} has a partial nested execution block: missing {', '.join(missing)} (worktree start writes all six together)")
    for key in ("host_branch", "host_base"):
        value = execution.get(key)
        if key == "host_branch" and value is None:
            continue  # v86: a detached host worktree; its consistency is checked below
        if key in execution and not (isinstance(value, str) and value.strip()):
            problems.append(f"phase {phase_id} has invalid execution.{key} {value!r}"
                            + ("; expected a non-empty string, or null for a detached host worktree" if key == "host_branch" else "; expected a non-empty string"))
    if "host_branch" in execution and execution.get("host_branch") is None:
        if execution.get("host_branch_created") is not False:
            problems.append(f"phase {phase_id} has execution.host_branch null (a detached host worktree) but host_branch_created "
                            f"{execution.get('host_branch_created')!r}; a detached host worktree creates no branch, so it must be false")
        if "repos" in execution:
            problems.append(f"phase {phase_id} has execution.host_branch null (a detached host worktree) with execution.repos; "
                            f"a worktree set needs a host branch (worktree start --host-branch)")
    sha = execution.get("host_base_sha")
    if "host_base_sha" in execution and not (isinstance(sha, str) and re.fullmatch(r"[0-9a-f]{7,64}", sha)):
        problems.append(f"phase {phase_id} has invalid execution.host_base_sha {sha!r}; expected a host commit sha")
    created = execution.get("host_branch_created")
    if "host_branch_created" in execution and not isinstance(created, bool):
        problems.append(f"phase {phase_id} has invalid execution.host_branch_created {created!r}; expected true or false")
    host_wt = execution.get("host_worktree")
    if host_wt is not None and not isinstance(host_wt, str):
        problems.append(f"phase {phase_id} has invalid execution.host_worktree {host_wt!r}; expected a path string or null")
    worktree = execution.get("worktree")
    if isinstance(host_wt, str) and isinstance(worktree, str) and HOST_ROOT is not None:
        expected = os.path.normpath(os.path.join(host_wt, os.path.relpath(ROOT, HOST_ROOT)))
        if os.path.normpath(worktree) != expected:
            problems.append(f"phase {phase_id} has execution.worktree {worktree!r}, but the nested worktree of host_worktree {host_wt!r} is {expected!r}")
    return problems


SET_REPO_KEYS = ("worktree", "branch", "base", "base_sha", "branch_created")


def _nested_execution_repo_problems(phase_id: str, execution: dict, errors: list, warnings: list) -> None:
    """`validate`'s checks on a worktree set's repo half (P40.S6, S2 §18): `execution.repos.<name> =
    {worktree, branch, base, base_sha, branch_created}`, written by `worktree start --repo` on a
    multi-repo host only. Called only when the key is present, so every single-repo and at-root block
    reads exactly as before. A stamped name the registry no longer lists is a warning (history stays
    readable); everything else is an error. Registry paths come from the marker, never the disk."""
    repos = execution.get("repos")
    if NESTED is None:
        errors.append(f"phase {phase_id} has execution.repos in an at-root install; it is written only by worktree start --repo on a multi-repo host")
        return
    if not NESTED_PROBLEMS and not nested_repos():
        errors.append(f"phase {phase_id} has execution.repos in a single-repo nested install; it is written only by worktree start --repo on a multi-repo host")
        return
    if not isinstance(repos, dict):
        errors.append(f"phase {phase_id} has a non-object execution.repos {repos!r}; expected {{<repo name>: {{{', '.join(SET_REPO_KEYS)}}}}}")
        return
    registry = {r.get("name"): r for r in nested_repos() if isinstance(r, dict)}
    host_wt = execution.get("host_worktree")
    for name, value in repos.items():
        label = f"phase {phase_id} execution.repos.{name}"
        if not isinstance(value, dict):
            errors.append(f"{label} is {value!r}; expected an object with {', '.join(SET_REPO_KEYS)}")
            continue
        missing = [k for k in SET_REPO_KEYS if k not in value]
        if missing:
            errors.append(f"{label} is missing {', '.join(missing)} (worktree start writes all five together)")
        for key in ("branch", "base"):
            v = value.get(key)
            if key in value and not (isinstance(v, str) and v.strip()):
                errors.append(f"{label}.{key} is {v!r}; expected a non-empty string")
        sha = value.get("base_sha")
        if "base_sha" in value and not (isinstance(sha, str) and re.fullmatch(r"[0-9a-f]{7,64}", sha)):
            errors.append(f"{label}.base_sha is {sha!r}; expected a commit sha in {name}")
        created = value.get("branch_created")
        if "branch_created" in value and not isinstance(created, bool):
            errors.append(f"{label}.branch_created is {created!r}; expected true or false")
        wt = value.get("worktree")
        if wt is not None and not isinstance(wt, str):
            errors.append(f"{label}.worktree is {wt!r}; expected a path string or null")
        elif isinstance(wt, str) and host_wt is None:
            errors.append(f"{label}.worktree is {wt!r} while execution.host_worktree is null; a repo worktree lives inside the host worktree (null it once torn down)")
        if name not in registry:
            if registry:
                warnings.append(f"{label}: no registered repo is named {name} -- kept as history (re-register it with: {WORKFLOW_CMD} repo add <path> --name {name})")
            continue
        if isinstance(wt, str) and isinstance(host_wt, str):
            expected = os.path.normpath(os.path.join(host_wt, registry[name]["path"]))
            if os.path.normpath(wt) != expected:
                errors.append(f"{label}.worktree is {wt!r}, but {name}'s worktree in host_worktree {host_wt!r} is {expected!r} (its registry path)")


def phase_pinned(data) -> bool:
    """True when the phase carries v42's legacy pin (`execution.mode == "default"`).

    Since v43 the default stream is the default, so nothing writes this block any more
    (`phase new --on-main` is a no-op). It is still honoured where it
    exists: `worktree start` refuses a pinned phase rather than overriding a deliberate pin,
    and the hints skip it. Everything else treats it exactly like a phase with no block,
    because `phase_execution` returns None for it."""
    execution = data.get("execution") if isinstance(data, dict) else None
    return isinstance(execution, dict) and execution.get("mode") == PINNED_MODE


def archived_phase_ids() -> set:
    """Every phase id archived/ holds, from each folder's `archive_manifest.json` `phase_id`, its
    `phase.json` `id` and the `_<id>_` in the folder name (`_archive_one` writes all three): an archived
    id is spent. An unreadable entry gives what still reads, never an error."""
    ids = set()
    for adir in (ARCHIVED.iterdir() if ARCHIVED.is_dir() else []):
        if not adir.is_dir():
            continue
        for name, key in (("archive_manifest.json", "phase_id"), ("phase.json", "id")):
            try:
                value = read_json(adir / name).get(key) if (adir / name).is_file() else None
            except Exception:  # noqa: BLE001 - an unreadable archive entry is skipped, never fatal
                value = None
            if isinstance(value, str) and value:
                ids.add(value)
        match = ARCHIVE_FOLDER_ID_RE.search(adir.name)
        if match:
            ids.add(match.group(1))
    return ids


def deferred_folder_ids() -> set:
    """Every deferred id with a folder in open/, promoted/ or dropped/ (the folder name is the id)."""
    return {d.name for base in (DEFERRED_OPEN, DEFERRED_PROMOTED, DEFERRED_DROPPED) if base.is_dir()
            for d in base.iterdir() if d.is_dir()}


def _id_token(value):
    """The lowercase token of a v73 `P-`/`D-` id, any case, or None for any other shape (a numbered id,
    tailed or not, has no token)."""
    match = re.fullmatch(r"[PDpd]-([0-9A-Za-z]+)", str(value))
    return match.group(1).lower() if match else None


def visible_phase_ids() -> set:
    """Every phase id this workspace can see: each active folder's name and its `phase.json` id, and every
    archived id (`archived_phase_ids`: an archived id is spent)."""
    ids = set(archived_phase_ids())
    for pdir in (ACTIVE.iterdir() if ACTIVE.is_dir() else []):
        if pdir.is_dir():
            ids.add(pdir.name)
            try:
                ids.add(str(read_json(pdir / "phase.json").get("id", "")))
            except Exception:  # noqa: BLE001 - an unreadable phase.json still has its folder name
                pass
    ids.discard("")
    return ids


def agenda_folder_ids() -> set:
    """Every agenda item id with a folder under works/agenda/ (the folder name is the id)."""
    return {d.name for d in AGENDA.iterdir() if d.is_dir()} if AGENDA.is_dir() else set()


def visible_ids(prefix: str) -> set:
    """The ids of one kind this workspace can see: phases (`P`, `visible_phase_ids`), deferred jobs (`D`,
    every folder in open/, promoted/ and dropped/) or agenda items (`A`, every folder under works/agenda/)."""
    if prefix == "P":
        return visible_phase_ids()
    return agenda_folder_ids() if prefix == "A" else deferred_folder_ids()


def visible_id_tokens() -> set:
    """The v73 tokens of every phase and deferred id this workspace can see -- ONE pool for both kinds.
    It now guards only an explicit v73-shape id (`--phase P-7kq2`, `--id D-m3xa`): the mint draws no token."""
    return {tok for tok in (_id_token(i) for i in visible_phase_ids() | deferred_folder_ids()) if tok}


def id_token_refusal(token: str, taken=None):
    """Why `token` cannot be an explicit v73-shape id's token, or None: all digits (it would read as a
    number), a mode word (`gate`, `plan`), a `p`/`d` and three digits (typed bare it would read as the old
    `P123` / `D123`), or a token some visible phase or deferred id already has."""
    token = token.lower()
    if token.isdigit():
        return f"its token {token} is all digits, which reads as a number"
    if token in ID_MODE_WORDS:
        return f"its token {token} is a mode word"
    if re.fullmatch(r"[pd][0-9]{3}", token):
        return f"its token {token}, typed bare, would read as the old id {token.upper()}"
    if token in (visible_id_tokens() if taken is None else taken):
        return f"its token {token} is already the token of a phase or deferred id this workspace holds (one pool for both kinds)"
    return None


def id_number(value):
    """`(n, tail)` of a numbered id of either prefix (`P46` -> `(46, None)`, `D92-x4` -> `(92, "x4")`), or
    None for any other shape (a v73 token, an odd name)."""
    match = NUMBERED_ID_RE.fullmatch(str(value))
    return (int(match.group(1)), match.group(2)) if match else None


def next_id_number(prefix: str, visible=None) -> int:
    """1 + the highest number of every visible numbered id of this kind, untailed (`P45`) and tailed
    (`P45-m9`) alike (`visible_ids`: phases active and archived, deferred jobs open, promoted and dropped);
    v73 tokens carry no number and are ignored. An empty workspace gives 1."""
    numbers = [id_number(i)[0] for i in (visible_ids(prefix) if visible is None else visible)
               if str(i).startswith(prefix) and id_number(i)]
    return max(numbers, default=0) + 1


def draw_id_tail() -> str:
    """Two symbols of `ID_TOKEN_ALPHABET`, drawn with `secrets` until one is a letter (never all digits)."""
    while True:
        tail = "".join(secrets.choice(ID_TOKEN_ALPHABET) for _ in range(ID_TAIL_LENGTH))
        if any(c in ID_TAIL_LETTERS for c in tail):
            return tail


def mint_id(prefix: str) -> str:
    """A new `<prefix><n>-<tail>` id (prefix `P`, `D` or `A`): `next_id_number` and a tail re-drawn while the
    full id is visible. Nothing else allocates a phase, deferred or agenda id. Two branches that each mint draw
    the same number; the tail keeps them apart, and a same-tail pair (1 in 924) is a git add/add conflict at
    merge. An agenda number is spent by nothing: a deleted item's folder is gone, so its number may be drawn
    again, with a new tail (delete the highest item and the next mint reuses its number). No tombstone is
    kept; the `agenda_deleted` event in works/events.jsonl is the record of the old id."""
    visible = visible_ids(prefix)
    number = next_id_number(prefix, visible)
    for _ in range(10000):
        candidate = f"{prefix}{number}-{draw_id_tail()}"
        if candidate not in visible:
            return candidate
    raise SystemExit(f"could not mint a free {prefix}{number}- id: every tail is taken")


def mint_phase_id() -> str:
    """`P<n>-<tail>`: `phase new` without `--phase`, `promote-deferred --create-phase` without `--phase`, and
    phase rotate's docs-phase proposal. It supersedes v73's `P-<token>`, which no one could say."""
    return mint_id("P")


# Brief names: what an operator may TYPE for an id, and the one place it becomes the id as stored. A
# numbered id is typed by its number: `46`, `p46`, `P46` name `P46-k2` while it is the only phase numbered
# 46 (an exact stored `P46` always wins), and `46-k2`, `p46-K2` name it always -- the tail is needed only when
# two branches each made a P46. v73's minted ids keep their brief forms: `7kq2`, `P-7kq2`, `p-7KQ2` are
# `P-7kq2` (a token needs a letter, is never a mode word, and keeps its dash once the prefix is written:
# `P7kq2` names nothing; `46k2` is the token `P-46k2`, never a tailed id). A deferred job likewise (`92`,
# `d92-X4`, `m3xa`, `D-m3xa`). Two contexts, both in `normalize_id_args`, the ONE choke point after argparse:
# CREATING an id (`phase new --phase`, `defer-job --id`) reads the form statically (`brief_id`: `46` is `P46`);
# REFERENCING one (every other argument) looks a number up among the stored ids (`resolve_id_ref`).
ID_ARG_KINDS = {"P": "phase", "D": "deferred job", "A": "agenda item"}
PHASE_ARG_HELP = ("the phase, in any brief form: 46 or P46 (numbered; type the tail, 46-k2, only when two phases share"
                  " the number), 7kq2 or P-7kq2 (a v73 id), any case")
ID_ARG_EXAMPLES = {"P": ("P46-k2", "46", "P12", "P-7kq2", "7kq2"), "D": ("D92-x4", "92", "D12", "D-m3xa", "m3xa"),
                   "A": ("A7-m3", "7")}  # an agenda id has no old or minted-token shape


def brief_id(prefix: str, raw) -> "str | None":
    """The id `raw` names read STATICALLY (prefix `P` for a phase, `D` for a deferred job), or None when it is
    no brief form: the optional `P`/`p` and digits (`P46`; leading zeros dropped),
    the same plus a dash and a valid tail (`P46-k2`, the tail lowercased), or the optional `P-`/`p-` and four
    v73 token symbols with a letter and no mode word (`P-7kq2`). A number is not looked up here."""
    text = str(raw).strip()
    number = re.fullmatch(rf"{prefix}?([0-9]+)", text, re.I)
    if number:
        return f"{prefix}{int(number.group(1))}"
    tailed = re.fullmatch(rf"{prefix}?([0-9]+)-([0-9A-Za-z]{{{ID_TAIL_LENGTH}}})", text, re.I)
    if tailed and re.fullmatch(ID_TAIL_PATTERN, tailed.group(2).lower()):
        return f"{prefix}{int(tailed.group(1))}-{tailed.group(2).lower()}"
    if prefix == "A":  # an agenda id has no v73 token shape: `7kq2` and `A-7kq2` name no agenda item
        return None
    token = re.fullmatch(rf"(?:{prefix}-)?({ID_TOKEN_PATTERN})", text, re.I)
    if token and not token.group(1).isdigit() and token.group(1).lower() not in ID_MODE_WORDS:
        return f"{prefix}-{token.group(1).lower()}"
    return None


def id_arg_refusal(prefix: str, raw) -> str:
    """Why `raw` is not a phase (`P`) or deferred job (`D`) id, with the three shapes that are; an agenda item
    (`A`) has one shape, a number and a tail."""
    text = str(raw).strip()
    if prefix == "A":
        tailed, number = ID_ARG_EXAMPLES["A"]
        return (f"{raw!r} is not an agenda item id: write {number} or {tailed} (the tail typed only when two"
                f" share the number)")
    tailed, number, old, minted, bare = ID_ARG_EXAMPLES[prefix]
    msg = (f"{raw!r} is not a {ID_ARG_KINDS[prefix]} id: write {number} or {tailed} (numbered, the tail typed only when"
           f" two share the number), {old} (an old numbered id), or {bare} or {minted} (a minted v73 id)")
    lone = re.fullmatch(rf"{prefix}({ID_TOKEN_PATTERN})", text, re.I)
    if lone:
        msg += f"; a minted id keeps its dash: {prefix}-{lone.group(1).lower()} (or just {lone.group(1).lower()})"
    return msg


def lookup_id_number(prefix: str, number: int, stored=None) -> tuple:
    """`(id, tailed)` for the number `number` of this kind: an exact stored `P46` wins (`(P46, [])`); else the
    stored `P46-<tail>` ids -- exactly one gives `(it, [it])`, none `(None, [])`, several `(None, [them, sorted])`.
    `stored` defaults to `visible_ids(prefix)`; an active `P46` folder answers without reading the rest."""
    exact = f"{prefix}{number}"
    if stored is None:
        if prefix == "P" and (ACTIVE / exact).is_dir():
            return exact, []
        stored = visible_ids(prefix)
    if exact in stored:
        return exact, []
    tailed = sorted((i for i in stored if str(i).startswith(prefix) and (id_number(i) or (None, None))[0] == number
                     and id_number(i)[1]), key=id_sort_key)
    return (tailed[0] if len(tailed) == 1 else None), tailed


def id_number_refusal(prefix: str, raw, number: int, tailed: list) -> str:
    """Why the number `raw` names no single id: no stored id has it, or several tailed ids share it."""
    kind = ID_ARG_KINDS[prefix]
    if tailed:
        return (f"{str(raw).strip()!r} names {len(tailed)} {kind}s numbered {number}: {', '.join(tailed)} -- type the tail"
                f" (e.g. {tailed[0]} or {tailed[0][1:]})")
    if prefix == "A":  # an agenda id is never untailed
        return f"{str(raw).strip()!r} names no {kind}: none is {prefix}{number}-<tail> in the agenda"
    where = "active or archived" if prefix == "P" else "open, promoted or dropped"
    return f"{str(raw).strip()!r} names no {kind}: none is {prefix}{number} or {prefix}{number}-<tail>, {where}"


def _stored_id_named(prefix: str, text: str) -> bool:
    """True when an id of a shape `brief_id` does not know is held exactly as typed (an old install's folder is
    never made unreachable): an active or archived phase, a deferred job, or an agenda item."""
    if not re.fullmatch(r"[A-Za-z0-9._-]+", text) or text in (".", ".."):
        return False
    if prefix == "D":
        return text in deferred_folder_ids()
    if prefix == "A":
        return text in agenda_folder_ids()
    return (ACTIVE / text).is_dir() or text in archived_phase_ids()


def resolve_id_arg(prefix: str, raw) -> str:
    """A phase (`P`), deferred job (`D`) or agenda item (`A`) id as typed when CREATING one -> the id as stored,
    read statically (`46` is `P46`); SystemExit with the shapes when it is no id. An id already in a stored
    shape (`PHASE_ID_RE` / `DEFERRED_ID_RE` / `AGENDA_ID_RE`) is returned untouched."""
    text = str(raw).strip()
    if {"P": PHASE_ID_RE, "D": DEFERRED_ID_RE, "A": AGENDA_ID_RE}[prefix].fullmatch(text):
        return text
    stored = brief_id(prefix, text)
    if stored is not None:
        return stored
    if _stored_id_named(prefix, text):
        return text
    raise SystemExit(id_arg_refusal(prefix, raw))


def resolve_id_ref(prefix: str, raw, stored=None) -> str:
    """A phase (`P`) or deferred job (`D`) id as typed when REFERENCING one -> the stored id: a bare number
    (`46`, `p46`, `P46`) is looked up (`lookup_id_number`: an exact `P46` wins, else the one `P46-<tail>`), and
    refused when it names none or several (the several listed); every other form reads as `resolve_id_arg`."""
    number = re.fullmatch(rf"{prefix}?([0-9]+)", str(raw).strip(), re.I)
    if number:
        found, tailed = lookup_id_number(prefix, int(number.group(1)), stored)
        if found is None:
            raise SystemExit(id_number_refusal(prefix, raw, int(number.group(1)), tailed))
        return found
    return resolve_id_arg(prefix, raw)


def _resolve_slice_arg(raw: str) -> str:
    """A slice id typed as `<brief phase>.<suffix>` -> its stored phase part (`46.S1` -> `P46-k2.S1`, `p-7KQ2.S1`
    -> `P-7kq2.S1`). A bare suffix (`S1`), a full id, a phase part that is no brief form, and a number that names
    no phase pass untouched (the command reports it); a number several phases share is refused."""
    head, dot, suffix = raw.partition(".")
    if not dot or not head or PHASE_ID_RE.fullmatch(head) and not re.fullmatch(r"P[0-9]+", head):
        return raw
    number = re.fullmatch(r"[Pp]?([0-9]+)", head)
    if number:
        found, tailed = lookup_id_number("P", int(number.group(1)))
        if found is None and len(tailed) > 1:
            raise SystemExit(id_number_refusal("P", head, int(number.group(1)), tailed))
        return f"{found}.{suffix}" if found else raw
    stored = brief_id("P", head)
    return f"{stored}.{suffix}" if stored else raw


def normalize_id_args(args: argparse.Namespace) -> None:
    """The ONE choke point for an id typed on a command line, run once after argparse (in a linked checkout,
    once after the begin step's pull, so an id reads the tree hi2vi holds: `cloud_boundary`): every `phase` /
    `--phase` argument is a phase id, every `deferred_id` and `defer-job --id` a deferred job's, and the `slice` attribute (positional `slice` and `--slice`) a
    slice whose phase part may be brief (`46.S1`). CREATING an id (`phase new --phase`, `defer-job --id`) reads
    it statically; `promote-deferred --create-phase --phase` references an existing phase when the number names
    one and otherwise creates statically; every other argument REFERENCES a stored id (`resolve_id_ref`). `--depends-on` stays full-form.
    A command then only ever sees the stored shape."""
    cmd = getattr(args, "cmd", None)
    phase = getattr(args, "phase", None)
    if isinstance(phase, str):
        if cmd == "phase new":
            args.phase = resolve_id_arg("P", phase)
        elif cmd == "promote-deferred" and getattr(args, "create_phase", False):
            number = re.fullmatch(r"[Pp]?([0-9]+)", phase.strip())
            found, tailed = lookup_id_number("P", int(number.group(1))) if number else (None, [])
            if len(tailed) > 1 and found is None:
                raise SystemExit(id_number_refusal("P", phase, int(number.group(1)), tailed))
            args.phase = found or resolve_id_arg("P", phase)
        else:
            args.phase = resolve_id_ref("P", phase)
    deferred = getattr(args, "deferred_id", None)
    if isinstance(deferred, str):
        args.deferred_id = resolve_id_ref("D", deferred)
    if cmd == "defer-job" and isinstance(getattr(args, "id", None), str) and args.id:
        args.id = resolve_id_arg("D", args.id)
    # The agenda (P66): `agenda_ids` (every item command's positional ids, a list) and agenda-move's
    # `--before`/`--after` REFERENCE stored items, in the order typed, so a bulk call is refused at its first bad
    # id; `agenda-add --id` CREATES one, read statically (`13-N1` is `A13-n1`) and checked by agenda_add.
    agenda_ids = getattr(args, "agenda_ids", None)
    if isinstance(agenda_ids, list):
        args.agenda_ids = [resolve_id_ref("A", raw) for raw in agenda_ids]
    for attr in ("before_id", "after_id"):
        if cmd == "agenda-move" and isinstance(getattr(args, attr, None), str):
            setattr(args, attr, resolve_id_ref("A", getattr(args, attr)))
    if cmd == "agenda-add" and isinstance(getattr(args, "id", None), str):
        args.id_typed = args.id
        args.id = brief_id("A", args.id) or args.id.strip()
    # `phase new --agenda` / `defer-job --agenda` REFERENCE an item (S2 links); the command then refuses an id of
    # a stored shape that names no item (`A99-zz`), before anything is written.
    if cmd in ("phase new", "defer-job") and isinstance(getattr(args, "agenda", None), str):
        args.agenda = resolve_id_ref("A", args.agenda)
    slice_arg = getattr(args, "slice", None)
    if isinstance(slice_arg, str):
        args.slice = _resolve_slice_arg(slice_arg.strip())
    if cmd == "mark-committed" and isinstance(getattr(args, "mark_slices", None), list):
        args.mark_slices = [_resolve_slice_arg(s.strip()) for s in args.mark_slices]


def new_acceptance() -> dict:
    """A fresh, undeclared operator acceptance gate. Five fields, no more."""
    return {"required": None, "walkthrough": None, "requested_at": None, "cleared_at": None, "note": None}


def phase_acceptance(data) -> dict:
    """The phase's operator acceptance gate, or None when the phase carries none (legacy).

    Fields: `required` (null undeclared, true operator-visible, false waived), `walkthrough` and `requested_at`
    (`gate <P> open`), `cleared_at` and `words` (`gate <P> clear --words`: the operator's literal words; a clear
    from before v102 has none and still reads as cleared), `note` (the clear's note or the waive reason). No block
    is legacy: `review --verdict pass` is allowed with one advisory line. Read the block only through here.
    """
    if not isinstance(data, dict):
        return None
    acceptance = data.get("acceptance")
    if not isinstance(acceptance, dict):
        return None
    required = acceptance.get("required")
    if not (required is None or isinstance(required, bool)):
        return None
    return acceptance


def acceptance_gate_is_open(data) -> bool:
    """True when the phase is waiting on the operator to walk the running product."""
    acceptance = phase_acceptance(data)
    return bool(acceptance and acceptance.get("required") is True
                and acceptance.get("requested_at") and not acceptance.get("cleared_at"))


def git_current_branch() -> str:
    """The checkout's current branch name, or None (detached HEAD, no git, not a repo).

    `symbolic-ref` first because it is right on a branch that has no commit yet (where
    `rev-parse --abbrev-ref HEAD` fails); `rev-parse` as the fallback. Any failure is
    silent: a workspace without git, or outside a repo, must keep working unchanged.
    """
    for cmd in (["git", "symbolic-ref", "--short", "-q", "HEAD"], ["git", "rev-parse", "--abbrev-ref", "HEAD"]):
        try:
            proc = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, timeout=10)
        except Exception:  # noqa: BLE001 - git is optional; fall back to the default stream
            return None
        if proc.returncode != 0:
            continue
        branch = proc.stdout.strip()
        if not branch or branch == "HEAD":  # empty, or detached HEAD
            return None
        return branch
    return None


def current_stream(phases: list) -> str:
    """The parallel stream this checkout is in, or None for the default stream.

    Stream membership is the current git branch matched against the phases' stamped
    `execution.branch` -- which works identically in a `git worktree` and in a plain
    clone on another machine, and needs no marker file. Git is consulted only when at
    least one active phase is actually opted in, so an untouched workspace never shells out.
    In a nested install (P35) the key is the NESTED repo's branch -- `git_current_branch()` reads
    ROOT, the repo that owns the state -- never the host's, whose branch names follow the host's
    custom and carry no workspace IDs.
    """
    branches = set()
    for phase in phases:
        execution = phase_execution(phase)
        if execution and execution.get("branch"):
            branches.add(execution["branch"])
    if not branches:
        return None
    branch = git_current_branch()
    return branch if branch in branches else None


def stream_phases(phases: list, stream) -> list:
    """The phases the current stream may select from.

    Default stream (`stream` is None): every phase except the ones running in their own worktree (a pinned phase has no branch and stays here).
    Parallel stream: only the phase stamped with that branch. Selection, and therefore the
    `works/state.json` pointer and the `pending` halt, is scoped to one stream this way;
    the dashboards still list every active phase folder.
    """
    scoped = []
    for phase in phases:
        execution = phase_execution(phase)
        if stream is None:
            if execution is None:
                scoped.append(phase)
        elif execution and execution.get("branch") == stream:
            scoped.append(phase)
    return scoped


def selectable_slices(phase: dict, slices=None) -> list:
    """The open slices the pointer may select, by order: every not-`done` slice."""
    slices = phase.get("slices", []) if slices is None else slices
    return [s for s in slices if s.get("status") != "done"]


def resolve_current(phases: list) -> tuple:
    for phase in phases:
        if phase.get("status") == "done":
            continue
        current_phase = phase["id"]
        if phase.get("status") in ("blocked", "pending"):
            return current_phase, None, None
        open_slices = selectable_slices(phase)
        if open_slices:
            return current_phase, open_slices[0]["id"], open_slices[1]["id"] if len(open_slices) > 1 else None
        return current_phase, None, None
    return None, None, None


def operator_wait_target(phases: list, current_phase, current_slice):
    """The phase or slice id awaiting operator co-work (status `pending`), else None.
    `pending` means the operator must validate or run something; selection halts
    until it is cleared back to `in_progress`. Distinct from `blocked`."""
    for phase in phases:
        if phase["id"] != current_phase:
            continue
        if phase.get("status") == "pending":
            return phase["id"]
        cur = next((s for s in phase["slices"] if s["id"] == current_slice), None)
        if cur and cur.get("status") == "pending":
            return current_slice
        return wave_wait_target(phase)  # P42: a declared phase's pending slice anywhere by order; None otherwise
    return None


# The ready set (P42): several slices of one phase in flight at once. A slice created with `--depends-on <id>`
# (repeatable) or `--depends-on none` is DECLARED: its slice.json carries `"depends_declared": true` beside
# `depends_on`, and that list binds -- each id names a slice of the same phase ordered strictly before it, so
# `order` stays a topological order and the plain pointer (the first open slice) always has its dependencies
# done. Every other slice is UNDECLARED (every pre-v71 slice, an advisory pre-v71 list included) and, like the
# barrier kinds, runs alone. Stateless: recomputed from disk on every call, it writes nothing,
# and a phase with no declared slice prints, stores and halts exactly as before (the plain pointer above).
# A barrier is never a wave slice (P42.F1): while one is in_progress it holds the phase alone, nothing is
# ready, and -- unless wave slices also run -- no wave line prints, so a declared phase then reads exactly as
# an undeclared one in the same state (at an open acceptance gate the running REVIEW is the gate's, not a
# returned wave slice to finish). slice start warns, never refuses, at a start the ready set would not make.
DEPENDS_DECLARED = "depends_declared"
BARRIER_KINDS = ("decomposition", "review", "co-work")
STOP_STATUSES = ("pending", "blocked")
DEPENDS_ON_HELP = ("a slice of this phase ordered before this one (repeat the flag for several), or `none`; either form "
                   "DECLARES the slice: its dependencies bind, and /do-whole-phase may run it beside other declared slices "
                   "once they are done. Refused (nothing written) for an id of another phase, one not ordered strictly "
                   "before this slice, or `none` beside an id. Without the flag the slice is undeclared and runs alone")


def slice_declared(s) -> bool:
    return isinstance(s, dict) and s.get(DEPENDS_DECLARED) is True


def phase_declared(phase) -> bool:
    """True when any slice of the phase, done ones included, was created with --depends-on."""
    return isinstance(phase, dict) and any(slice_declared(s) for s in phase.get("slices", []))


def slice_barrier(s: dict) -> bool:
    """A barrier runs alone: a decomposition, review or co-work slice, and every undeclared slice
    (nobody stated its file set, so nothing can be shown disjoint from it)."""
    return s.get("kind") in BARRIER_KINDS or not slice_declared(s)


def _order_of(s: dict):
    order = s.get("order", 999999)
    return order if isinstance(order, (int, float)) else 999999


def ready_set(phase: dict) -> dict:
    """`{ready, running, stops, barrier}` of one phase: lists of slices by order, and `barrier` the first
    barrier `in_progress` (else None). `running` is the wave: the non-barrier slices `in_progress`; a barrier
    never joins it, it holds the phase alone. `stops` are the open slices `pending` or `blocked`; any stop, a
    barrier in progress, or the phase itself `pending`/`blocked`, leaves `ready` empty. Else a walk over the
    open slices admits a barrier only as the first open slice with nothing running, ends at the first barrier
    either way, and admits a declared slice that is todo/ready with every dependency `done`. So an undeclared
    phase's ready set is its first open slice when that can start: the pointer."""
    slices = phase.get("slices", [])
    done = {s.get("id") for s in slices if s.get("status") == "done"}
    open_slices = [s for s in slices if s.get("status") != "done"]
    in_progress = [s for s in open_slices if s.get("status") == "in_progress"]
    out = {"ready": [], "running": [s for s in in_progress if not slice_barrier(s)],
           "barrier": next((s for s in in_progress if slice_barrier(s)), None),
           "stops": [s for s in open_slices if s.get("status") in STOP_STATUSES]}
    if out["stops"] or out["barrier"] is not None or phase.get("status") in STOP_STATUSES + ("done",):
        return out
    for i, s in enumerate(open_slices):
        startable = s.get("status") in ("todo", "ready")
        if slice_barrier(s):
            if i == 0 and startable and not out["running"]:
                out["ready"].append(s)
            break
        if startable and all(dep in done for dep in s.get("depends_on") or []):
            out["ready"].append(s)
    return out


def wave_wait_target(phase: dict):
    """operator_wait_target's widening: the id of a declared phase's first `pending` slice, else None."""
    stop = next((s for s in phase.get("slices", []) if s.get("status") == "pending"), None) if phase_declared(phase) else None
    return stop["id"] if stop else None


def _slice_ids(slices) -> str:
    return ",".join(s["id"] for s in slices) or "none"


def _wave_stops(phase: dict, wave: dict) -> list:
    stops = [f"{s['id']} ({s.get('status')})" for s in wave["stops"]]
    return ([f"phase {phase['id']} ({phase.get('status')})"] if phase.get("status") in STOP_STATUSES else []) + stops


def wave_held(wave: dict) -> bool:
    """True while a barrier runs alone (no wave slice beside it): a single-slice run that the plain pointer's
    lines carry, so the phase prints no wave line and reads as an undeclared phase does (P42.F1)."""
    return wave["barrier"] is not None and not wave["running"]


def wave_lines(phase) -> list:
    """`next` lines for a declared phase: `ready_slices=` and `running_slices=`. Empty for an
    undeclared phase (or None), so those outputs stay byte-identical there, and while a barrier holds the phase."""
    if not phase_declared(phase):
        return []
    wave = ready_set(phase)
    if wave_held(wave):
        return []
    stops = _wave_stops(phase, wave)
    ready = f"ready_slices={_slice_ids(wave['ready'])}"
    running = f"running_slices={_slice_ids(wave['running'])}"
    if stops:
        ready += f" -- stopped by {', '.join(stops)}: nothing new starts while a stop is on disk"
        if wave["running"]:
            running += " -- already running beside the stop: wait for each, then finish and commit it"
    return [ready, running]


def _active_phase(phase_id):
    """One active phase as all_active_phases() reads it, its slices in order; None when there is none."""
    pdir = ACTIVE / phase_id if isinstance(phase_id, str) and phase_id else None
    if pdir is None or not (pdir / "phase.json").is_file():
        return None
    data = read_json(pdir / "phase.json")
    data["slices"] = [read_json(sdir / "slice.json") for sdir in slice_dirs(pdir)]
    return data


def start_warning(slice_id: str):
    """slice start's one `warning:` line in a declared phase (OQ3, P42.F1), for a start the ready set would not
    make: a declared slice with a dependency not yet `done`, or a barrier while another slice of the phase is
    `in_progress`. None otherwise, and always None in an undeclared phase. It warns, never refuses."""
    try:
        phase = _active_phase(slice_id.split(".", 1)[0]) if isinstance(slice_id, str) else None
    except (OSError, ValueError, TypeError):  # an unreadable slice.json: the start goes on as before, unwarned
        return None
    if not phase_declared(phase):
        return None
    by_id = {s.get("id"): s for s in phase["slices"]}
    me = by_id.get(slice_id)
    if me is None:
        return None
    reasons = []
    if slice_declared(me):
        deps = [f"{dep} ({by_id[dep].get('status')})" if dep in by_id else f"{dep} (missing)"
                for dep in me.get("depends_on") or [] if (by_id.get(dep) or {}).get("status") != "done"]
        if deps:
            reasons.append(f"depends on {', '.join(deps)}, not done yet")
    if slice_barrier(me):
        beside = [s["id"] for s in phase["slices"] if s.get("status") == "in_progress" and s.get("id") != slice_id]
        if beside:
            reasons.append(f"is a barrier that runs alone, but {', '.join(beside)} {'is' if len(beside) == 1 else 'are'} in_progress")
    if not reasons:
        return None
    return f"warning: {slice_id} {', and '.join(reasons)} -- the ready set would not start it; started anyway (slice start warns, never refuses)"


def parse_depends_on(values):
    """`--depends-on` values -> the declared ids (`[]` for `none`), or None when the flag is absent: an
    undeclared slice, created exactly as before. Refuses an empty value and `none` beside an id."""
    if values is None:
        return None
    raw = [v.strip() for v in values]
    ids = list(dict.fromkeys(v for v in raw if v.lower() != "none"))
    if "" in ids:
        raise SystemExit("--depends-on needs a slice id or none; refused, nothing was written")
    if ids and any(v.lower() == "none" for v in raw):
        raise SystemExit(f"--depends-on none declares no dependency and never stands beside a slice id (got: {', '.join(raw)}); refused, nothing was written")
    return ids


def declared_dependencies(phase_id: str, slice_id: str, order, values):
    """parse_depends_on, then rule 2 at creation: each id names an existing slice of the same phase, other
    than this one, ordered strictly before `order`. Refuses (SystemExit, nothing written) otherwise."""
    ids = parse_depends_on(values)
    if not ids:
        return ids
    siblings = {s.get("id"): s for s in (read_json(d / "slice.json") for d in slice_dirs(ACTIVE / phase_id))}
    for dep in ids:
        if dep == slice_id:
            problem = "a slice cannot depend on itself"
        elif dep.split(".", 1)[0] != phase_id:
            problem = f"not a slice of phase {phase_id}; a declared dependency names a slice of the same phase"
        elif dep not in siblings:
            problem = f"phase {phase_id} has no such slice; create it first, ordered before {slice_id}"
        elif not _order_of(siblings[dep]) < order:
            problem = (f"it is ordered at {siblings[dep].get('order')}, not before {slice_id} at {order}; a declared dependency "
                       "comes strictly earlier by --order, so order stays a topological order")
        else:
            continue
        raise SystemExit(f"--depends-on {dep}: {problem}; refused, nothing was written")
    return ids


def declared_slice_lines(kind: str, deps) -> list:
    """slice new / promote-deferred's lines for a declared slice (none for an undeclared one)."""
    if deps is None:
        return []
    lines = [f"depends_on={','.join(deps)} (declared: binding; /do-whole-phase starts it once these are done)" if deps else
             "depends_on=none (declared: no dependency; /do-whole-phase may start it beside other ready slices)"]
    if kind in BARRIER_KINDS:
        lines.append(f"note: kind {kind} is a barrier that runs alone, so this declaration has no effect (validate warns)")
    return lines


def declaration_checks(phase: dict, s: dict, errors: list, warnings: list) -> None:
    """validate's checks of one slice's declaration. Silent for a slice with no marker key at all (every
    undeclared slice), so an undeclared workspace's validate output is unchanged."""
    if DEPENDS_DECLARED not in s:
        return
    if s.get(DEPENDS_DECLARED) is not True:
        errors.append(f"slice {s['id']} has invalid {DEPENDS_DECLARED} {s.get(DEPENDS_DECLARED)!r}; expected true "
                      "(written by slice new or promote-deferred --depends-on) or no key at all")
        return
    if s.get("kind") in BARRIER_KINDS:
        warnings.append(f"slice {s['id']} declares its dependencies, but kind {s.get('kind')} is a barrier that runs alone: "
                        f"the declaration has no effect -- drop {DEPENDS_DECLARED} from its slice.json")
    orders = {x.get("id"): x for x in phase.get("slices", [])}
    for dep in s.get("depends_on") or []:
        if dep in orders and not _order_of(orders[dep]) < _order_of(s):
            errors.append(f"declared dependency of {s['id']} (order {s.get('order')}) on {dep} (order {orders[dep].get('order')}) "
                          "is not ordered before it; a declared dependency comes strictly earlier by order, so order stays a "
                          "topological order -- reorder one of them")
        elif dep not in orders and isinstance(dep, str) and re.fullmatch(rf"{PHASE_ID_PATTERN}\..+", dep) and dep.split(".", 1)[0] != phase["id"]:
            errors.append(f"declared dependency of {s['id']} on {dep} crosses phases; a declared dependency names a slice "
                          f"of the same phase ({phase['id']})")


# Declaration at the cut (v77; advice since the thin engine). A decomposition should leave every open middle
# slice of its phase DECLARED, so slice finish on a decomposition prints one advice: line per undeclared one,
# which runs alone. The engine, not the decomposition's prose, determines what may run together
# (parallel_plan). An explain phase
# (`## Explain` in intent.md) is exempt: its chapters stay undeclared by design, as fix slices do. slice deps
# declares a slice that was cut without the flag.
def explain_phase(pdir: Path) -> bool:
    """True when the phase's intent.md carries the `## Explain` section (the explain route's only marker)."""
    intent = pdir / "intent.md"
    return intent.is_file() and any(line.strip() == "## Explain" for line in intent.read_text(encoding="utf-8").split("\n"))


def explain_unit(pdir: Path):
    """An explain phase's publishable unit: the `- unit:` value in intent.md's `## Explain` section
    (`document` | `book` | `chapter`, lower-cased, as written: `validate` reports an unknown one), or
    `book` when the field is absent -- every explain phase before v86 is a book. None for a phase that
    is not an explain phase. `next` prints it so the orchestrator picks its reference branch."""
    if not explain_phase(pdir):
        return None
    inside = False
    for line in (pdir / "intent.md").read_text(encoding="utf-8").split("\n"):
        text = line.strip()
        if text.startswith("## "):
            if inside:
                break
            inside = text == "## Explain"
            continue
        if inside:
            m = re.match(r"[-*]\s+unit\s*:\s*(.*)$", text, re.IGNORECASE)
            if m:
                value = m.group(1).strip().strip("`").strip()
                return value.split()[0].lower() if value else EXPLAIN_UNIT_DEFAULT
    return EXPLAIN_UNIT_DEFAULT


def undeclared_middle_slices(phase: dict) -> list:
    """The open (not `done`) slices of a phase that are neither a barrier kind, a fix nor declared, by order: a
    fix slice is cut after a review, outside any decomposition's reach, and stays undeclared unless its set is known."""
    return [s for s in phase.get("slices", []) if s.get("status") != "done" and s.get("kind") not in BARRIER_KINDS + ("fix",)
            and not slice_declared(s)]


def parallel_plan(phase: dict) -> list:
    """The rounds the open slices run in, as the ready set would start them if every round finished together:
    a list of slice lists, by order. A barrier is a round of its own; declared slices whose dependencies are
    all done (or in an earlier round) share a round; an undeclared slice runs alone, like a barrier. Pure:
    it reads the slice records and writes nothing."""
    done = {s.get("id") for s in phase.get("slices", []) if s.get("status") == "done"}
    pending = [s for s in phase.get("slices", []) if s.get("status") != "done"]
    rounds = []
    while pending:
        batch = []
        for i, s in enumerate(pending):
            if slice_barrier(s):
                if i == 0:
                    batch = [s]
                break
            if all(dep in done for dep in s.get("depends_on") or []):
                batch.append(s)
        if not batch:  # unreachable while order stays topological (validate errors otherwise); never loop
            batch = [pending[0]]
        rounds.append(batch)
        done |= {s.get("id") for s in batch}
        pending = [s for s in pending if s not in batch]
    return rounds


def parallel_plan_lines(phase: dict) -> list:
    """`parallel_plan=` and `parallel_rounds=` lines for a phase's open slices (none when nothing is open)."""
    rounds = parallel_plan(phase)
    if not rounds:
        return []
    short = lambda s: str(s.get("id", "")).split(".", 1)[-1]
    shown_rounds = " -> ".join(" + ".join(short(s) for s in batch) for batch in rounds)
    together = sum(len(batch) for batch in rounds if len(batch) > 1)
    total = sum(len(batch) for batch in rounds)
    widest = max(len(batch) for batch in rounds)
    if together:
        summary = f"{len(rounds)} rounds for {total} open slices; {together} run beside another (widest round: {widest})"
    else:
        summary = f"{len(rounds)} rounds for {total} open slices; a chain: no two slices run together"
    return [f"parallel_plan={phase.get('id')}: {shown_rounds}", f"parallel_rounds={summary}"]


SLICES_BEGIN = "<!-- slices:begin -->"
SLICES_END = "<!-- slices:end -->"
# WORKFLOW_CMD is the literal `python3 scripts/workflow.py` at root (so this line stays byte-identical to
# works/templates/phase.md); a nested install's template is installed with the host-relative prefix, so
# its regenerated line carries the same one.
SLICES_GUIDANCE = f"_Generated by `{WORKFLOW_CMD} check` from each slice's `slice.json`; never hand-edit this block._"


def render_slices_block(pdir: Path, phase: dict) -> str:
    """The body of the generated `## Slices` table: one row per slice, in `order`.

    This is the ONLY generated region of a phase notebook -- everything around it is the
    executors' bounded, hand-written state doc, which is why phase.md is deliberately not
    in GENERATED_FILES.
    """
    lines = [SLICES_GUIDANCE, "", "| Slice | Name | Kind / risk | Status | Outcome | Result |", "|---|---|---|---|---|---|"]
    rows = []
    for s in phase.get("slices", []):
        sid = s.get("id", "")
        has_result = (pdir / "slices" / str(sid) / "result.md").exists()
        result = f"[result.md](slices/{clean_cell(sid)}/result.md)" if has_result else "\u2014"
        outcome = clean_cell(s.get("outcome")) or "\u2014"
        rows.append(
            f"| `{clean_cell(sid)}` | {clean_cell(s.get('name', ''))} | "
            f"`{clean_cell(s.get('kind', ''))} / {clean_cell(s.get('risk', ''))}` | "
            f"`{clean_cell(s.get('status', ''))}` | {outcome} | {result} |"
        )
    return "\n".join(lines + rows)


def refresh_phase_md_slices(pdir: Path, phase: dict) -> None:
    """Splice the generated slice table between the two markers of an active phase's notebook.

    A marker counts only when it is alone on its line: notebooks that merely *quote* the
    literals in prose (a plan or a decomposition table describing this very block) must not
    be spliced. No markers -> return untouched, so legacy phases and adopters who deleted
    the block stay a silent no-op, never a migration. Writes only when the spliced text
    actually differs, so plain `next`/`rebuild` calls do not dirty every notebook in the tree.
    """
    path = pdir / "phase.md"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    start = next((i for i, ln in enumerate(lines) if ln.strip() == SLICES_BEGIN), None)
    end = next((i for i in range(start + 1, len(lines)) if lines[i].strip() == SLICES_END), None) if start is not None else None
    if start is None or end is None:
        return
    updated = "\n".join(lines[:start + 1] + render_slices_block(pdir, phase).split("\n") + lines[end:])
    if updated != text:
        write_text(path, updated)


def phase_md_size(pdir: Path) -> tuple:
    """(lines, bytes) of a phase notebook; (0, 0) when absent.

    Both numbers are reported, but only the byte count is judged against
    PHASE_MD_BUDGET (v39). Shared by `validate` (warning) and `slice finish` (size print)
    so the two can never disagree about what "over budget" means.
    """
    path = pdir / "phase.md"
    if not path.exists():
        return (0, 0)
    text = path.read_text(encoding="utf-8")
    return (len(text.splitlines()), len(text.encode("utf-8")))


def notebook_sections_hint(pdir: Path, limit: int = 3) -> str:
    """`biggest sections: ## A 12345 B, ...; move long material to topics/<slug>.md` for a notebook
    that is over budget, or "" when it cannot be read. Shared by `validate` and `slice finish`."""
    path = pdir / "phase.md"
    if not path.exists():
        return ""
    sections = sorted(h2_sections(path.read_text(encoding="utf-8")), key=lambda item: -item[1])[:limit]
    if not sections:
        return ""
    named = ", ".join(f"{heading} {size} B" for heading, size in sections)
    return f"biggest sections: {named}; move long material (contracts, signed-design summaries) to topics/<slug>.md, linked by one line, or to the slice's result.md"


def h2_spans(lines: list) -> list:
    """`(heading text, first line, end line)` for every `## ` section of a split notebook; the same
    fence-aware boundaries as `h2_sections`, in line numbers so a section can be spliced in place."""
    fenced, starts = False, []
    for i, line in enumerate(lines):
        if line.startswith("```") or line.startswith("~~~"):
            fenced = not fenced
        elif not fenced and line.startswith("## "):
            starts.append(i)
    return [(lines[i][3:].strip(), i, starts[j + 1] if j + 1 < len(starts) else len(lines)) for j, i in enumerate(starts)]


PHASE_SECTION_APPEND_ONLY = {"doc impact": "--append", "operator questions": "--append (or --resolve OQ<n> --pointer <ref>)"}
OQ_ENTRY = re.compile(r"^- \*\*OQ(\d+)\b")
OQ_PARTS = re.compile(r"^- \*\*OQ\d+[^*]*\*\*:?\s*(.*)$")

# Notebook entries. An entry is a column-0 list item of a section: ENTRY_MARKER, then its
# continuation and nested lines. `notebook_entries` is the ONE parser; every entry read and write,
# the move, the budget report and paging go through it. A pointer line is what a move leaves in an
# entry's place: one line, `<marker><gist> → [topics/<slug>.md](topics/<slug>.md) § <block>`.
ENTRY_MARKER = re.compile(r"(?:[-*+]|[0-9]+[.)]) ")
ENTRY_DEEP_HEADING = re.compile(r"#{3,}(?:\s|$)")
ENTRY_OQ = re.compile(r"\*\*OQ([0-9]+)\b")
ENTRY_KEY_PART = re.compile(r"([0-9]+)(?:\s*-\s*([0-9]+))?|OQ([0-9]+)", re.I)
TOPIC_SLUG_RE = re.compile(r"[a-z0-9][a-z0-9-]{0,63}")
POINTER_LINE = re.compile(r"(?:[-*+]|[0-9]+[.)]) .* → \[topics/([a-z0-9][a-z0-9-]{0,63})\.md\]\(topics/\1\.md\) § (\S.*)")
GIST_SENTENCE_END = re.compile(r"[.!?][*_`)\]\"'”’]*(?=\s|$)")
TOPIC_INTRO = ("_Entries moved here from phase.md by `section --to-topic`, byte for byte, one `## ` block each; "
               "the pointer line left in each one's place names its block._")
# The sections a move refuses, and why (every other section moves: Decisions, Notes for later slices,
# Objective and any custom section).
PHASE_SECTION_UNMOVABLE = {
    "slices": "it is generated from each slice.json by `check`",
    "doc impact": "it is append-only (a retired section, kept readable in older notebooks)",
    "operator questions": "it is append-only, and the review routes its entries where they are: collapse an answered one with --resolve OQ<n> --pointer <ref>",
    "now": "it is the handoff the next dispatch reads first: rewrite it shorter with --replace",
}


def notebook_entries(lines: list, first: int, end: int) -> list:
    """The entries of one notebook section, in document order: the one parser behind every
    entry read and write, the move, the budget report and paging. `lines[first:end]` is the section's
    body; for a section `(heading, i, e)` from `h2_spans`, pass `i + 1, e`.

    An entry starts at a column-0 line, outside a fence, that begins with a list marker (`- `, `* `,
    `+ `, `<digits>. `, `<digits>) `). It runs to the next such line, the next column-0 `###`-or-deeper
    heading, an unindented paragraph after a blank line, or the section's end. Its continuation and
    indented (nested) lines belong to it; its trailing blank lines are separators, not part of it. A
    line whose stripped form starts with ``` or ~~~ toggles a fence, and nothing inside a fence starts
    or ends an entry. Lines outside every entry (the italic guidance line, prose, `###` headings, table
    rows) are never touched by an entry operation.

    Each entry is a dict: `pos` (1-based), `start` and `end` (line indices, `end` exclusive and before
    the trailing blank lines), `sep_end` (the end of those blank lines, never past `end` of the
    section), `marker` (`- `, `9. `, ...), `label` (`9.`, `OQ3` or ""), `oq` (the n of a `**OQ<n>`
    lead, else None), `bytes` (UTF-8 bytes of its lines joined by newlines), `nested` (an indented
    line that starts with a list marker), `pointer` (a one-line pointer, POINTER_LINE), `long` (over
    LONG_ENTRY_BYTES or nested; a pointer is never long) and `lead` (its first line after the marker).
    """
    spans, fenced, current, prev_blank = [], False, None, False
    for k in range(first, end):
        line = lines[k]
        stripped = line.strip()
        fence = stripped.startswith("```") or stripped.startswith("~~~")
        if fenced:
            fenced = not fence
            if current is not None:
                current[1] = k + 1
            prev_blank = False
            continue
        if not stripped:
            prev_blank = True
            continue
        column0 = not line[0].isspace()
        if column0 and ENTRY_MARKER.match(line):
            current = [k, k + 1, False]
            spans.append(current)
        elif column0 and (prev_blank or ENTRY_DEEP_HEADING.match(line)):
            current = None
        elif current is not None and not column0 and ENTRY_MARKER.match(line.lstrip()):
            current[2] = True
        if current is not None:
            current[1] = k + 1
        fenced = fence
        prev_blank = False
    out = []
    for pos, (start, stop, nested) in enumerate(spans, 1):
        sep = stop
        while sep < end and not lines[sep].strip():
            sep += 1
        marker = ENTRY_MARKER.match(lines[start]).group(0)
        lead = lines[start][len(marker):]
        oq = ENTRY_OQ.match(lead)
        size = len("\n".join(lines[start:stop]).encode("utf-8"))
        pointer = stop - start == 1 and POINTER_LINE.fullmatch(lines[start].rstrip()) is not None
        label = marker.strip() if marker[0].isdigit() else (f"OQ{int(oq.group(1))}" if oq else "")
        out.append({"pos": pos, "start": start, "end": stop, "sep_end": sep, "marker": marker, "label": label,
                    "oq": int(oq.group(1)) if oq else None, "bytes": size, "nested": nested, "pointer": pointer,
                    "long": not pointer and (nested or size > LONG_ENTRY_BYTES), "lead": lead})
    return out


def entry_ranges(positions) -> str:
    """`1-8,10` for positions 1..8 and 10: a set of entry positions in the form `--entry` takes."""
    runs = []
    for pos in sorted(set(positions)):
        if runs and pos == runs[-1][1] + 1:
            runs[-1][1] = pos
        else:
            runs.append([pos, pos])
    return ",".join(str(a) if a == b else f"{a}-{b}" for a, b in runs)


def section_topic_slug(heading: str) -> str:
    """The topic slug a suggested move uses for a section: `Notes for later slices` -> `notes-for-later-slices`."""
    slug = re.sub(r"[^a-z0-9]+", "-", heading.lower()).strip("-")[:64].strip("-")
    return slug if slug and slug != "breakdown" else "notes"


def notebook_report(phase: str, text: str) -> dict:
    """The one budget report of a notebook (design §4), read by the index, slice finish, validate and
    next. Returns data:

    `{"phase", "lines", "bytes", "budget": PHASE_MD_BUDGET, "over", "sections": [...], "moves": [...],
      "flagged": [...]}`; each section is `{"heading", "bytes", "budget" (None = none of its own),
    "over", "movable", "long": [the long entries' dicts from notebook_entries], "move" (the suggested
    `section <P> "<Section>" --to-topic <slug> --entry <ranges>` or None), "remedy" (the fix for
    an over-budget section a move cannot shrink, or None)}`. Long entries are named only in movable
    sections (not PHASE_SECTION_UNMOVABLE); `moves` lists every section's move command; `flagged` the
    sections over their budget or holding long entries. Section bytes are `h2_sections`' bytes."""
    lines = text.split("\n")
    sections = []
    for heading, i, e in h2_spans(lines):
        key = heading.lower()
        size = len("\n".join(lines[i:e]).encode("utf-8"))
        budget = SECTION_BUDGETS.get(key, SECTION_BUDGET_DEFAULT)
        movable = key not in PHASE_SECTION_UNMOVABLE
        long_entries = [x for x in notebook_entries(lines, i + 1, e) if x["long"]] if movable else []
        move = (f'section {phase} "{heading}" --to-topic {section_topic_slug(heading)} '
                f'--entry {entry_ranges(x["pos"] for x in long_entries)}') if long_entries else None
        over = budget is not None and size > budget
        remedy = SECTION_REMEDIES.get(key) if over and not move else None
        sections.append({"heading": heading, "bytes": size, "budget": budget, "over": over, "movable": movable,
                         "long": long_entries, "move": move, "remedy": remedy})
    total = len(text.encode("utf-8"))
    return {"phase": phase, "lines": len(text.splitlines()), "bytes": total, "budget": PHASE_MD_BUDGET,
            "over": total > PHASE_MD_BUDGET, "sections": sections,
            "moves": [s["move"] for s in sections if s["move"]],
            "flagged": [s for s in sections if s["over"] or s["long"]]}


def notebook_section_line(section: dict, limit: int = 8) -> str:
    """One line for a flagged section of `notebook_report`: its size against its budget, up to `limit`
    long-entry labels (a label, else the position) with `+N more`, and its move command or remedy."""
    parts = []
    if section["over"]:
        parts.append(f"{section['bytes']} B, over its {section['budget']} B budget")
    else:
        parts.append(f"{section['bytes']} B")
    if section["long"]:
        names = [x["label"] or str(x["pos"]) for x in section["long"]]
        more = f" +{len(names) - limit} more" if len(names) > limit else ""
        parts.append(f"long entries: {', '.join(names[:limit])}{more}")
    if section["move"]:
        parts.append(f"move: {section['move']}")
    elif section["remedy"]:
        parts.append(section["remedy"])
    return f"## {section['heading']}: " + "; ".join(parts)


# The required step (design §6): when a phase that is not done has a notebook over PHASE_MD_BUDGET,
# `next`, `slice start` and the resume card tell the main thread to move long entries to
# topics before the next dispatch. `notebook_step` is the one function they print from; it is silent
# (None) under budget, for a done phase and for a phase with no notebook, so those outputs never change.
NOTEBOOK_STEP_MOVES = 3


def notebook_step(phase_id) -> dict:
    """The over-budget step of one phase, or None. `{"phase", "bytes", "form": "moves" | "advisory",
    "lines": [...]}`: moves when a movable long entry exists (`notebook_over_budget=` and at most
    NOTEBOOK_STEP_MOVES `notebook_move=` lines), advisory when nothing can move (`notebook_over_budget=`
    naming what remains, no move line). Read-only: it never writes and never blocks anything."""
    if not phase_id:
        return None
    pdir = ACTIVE / phase_id
    notebook = pdir / "phase.md"
    if not notebook.is_file():
        return None
    try:
        if read_json(pdir / "phase.json").get("status") == "done":
            return None
    except (OSError, ValueError):
        return None
    text = notebook.read_text(encoding="utf-8")
    if len(text.encode("utf-8")) <= PHASE_MD_BUDGET:
        return None
    report = notebook_report(phase_id, text)
    head = f"notebook_over_budget={phase_id} ({report['bytes']} of {PHASE_MD_BUDGET} B) -- "
    moves = report["moves"]
    if moves:
        more = (f" (+{len(moves) - NOTEBOOK_STEP_MOVES} more moves: `section {phase_id}` lists them)"
                if len(moves) > NOTEBOOK_STEP_MOVES else "")
        lines = [head + "advice: move long entries to topics before the next dispatch (gists stay, nothing is lost)" + more]
        lines.extend(f"notebook_move={m}" for m in moves[:NOTEBOOK_STEP_MOVES])
        return {"phase": phase_id, "bytes": report["bytes"], "form": "moves", "lines": lines}
    remains = []
    for s in report["sections"]:
        if s["heading"].lower() == "slices":
            remains.append(f"{s['heading']} {s['bytes']} B generated")
        elif s["over"]:
            remains.append(f"{s['heading']} {s['bytes']} B: {s['remedy'] or 'no long entry left to move'}")
    if not remains:  # nothing over its own budget: name the biggest section
        big = max(report["sections"], key=lambda s: s["bytes"], default=None)
        if big:
            remains.append(f"{big['heading']} {big['bytes']} B")
    lines = [head + f"advisory: nothing left to move ({'; '.join(remains)})"]
    return {"phase": phase_id, "bytes": report["bytes"], "form": "advisory", "lines": lines}


def notebook_step_lines(phase_id) -> list:
    """`notebook_step`'s lines, or [] when it is silent."""
    step = notebook_step(phase_id)
    return step["lines"] if step else []


def dangling_pointers(pdir: Path) -> list:
    """The pointer lines of a phase notebook whose topic file or `§ <block>` does not exist, as
    `(section, entry position, topics/<slug>.md, block)`: each one is a lost decision."""
    path = pdir / "phase.md"
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8").split("\n")
    topics, out = {}, []
    for heading, i, e in h2_spans(lines):
        for x in notebook_entries(lines, i + 1, e):
            if not x["pointer"]:
                continue
            m = POINTER_LINE.fullmatch(lines[x["start"]].rstrip())
            slug, block = m.group(1), m.group(2).strip()
            if slug not in topics:
                topic = pdir / "topics" / f"{slug}.md"
                topics[slug] = ({h.lower() for h, _, _ in h2_spans(topic.read_text(encoding="utf-8").split("\n"))}
                                if topic.is_file() else None)
            if topics[slug] is None or block.lower() not in topics[slug]:
                out.append((heading, x["pos"], f"topics/{slug}.md", block if topics[slug] is not None else None))
    return out


def paged_units(lines: list, first: int, end: int) -> list:
    """The page units of a block `lines[first:end]` (its heading at `first`, trailing blanks already
    dropped): the heading with the lines before the first entry, then each entry with its trailing
    separators, and each non-entry line after an entry on its own. `(start, stop, entry pos or None)`."""
    entries = notebook_entries(lines, first + 1, end)
    units, cur = [], first
    for x in entries:
        if not units:
            units.append((first, x["start"], None))
        else:
            units += [(k, k + 1, None) for k in range(cur, x["start"])]
        stop = min(x["sep_end"], end)
        units.append((x["start"], stop, x["pos"]))
        cur = stop
    if not entries:
        return [(first, end, None)]
    units += [(k, k + 1, None) for k in range(cur, end)]
    return units


def paged_print(lines: list, first: int, end: int, title: str, next_cmd: str, page) -> None:
    """Print a section or topic block `lines[first:end]` (trailing blanks dropped), paged (design §5).
    Without `page`, a block at or under PAGE_BYTES prints whole and unchanged; over it, page 1. A page
    packs whole units (an entry is never split; a unit bigger than a page gets its own) and opens with
    `<!-- page i of n · <title> · entries a–b of m · next: <next_cmd> --page i+1 -->` (`last page` on
    the last). Drop the header lines, concatenate the pages, and the result is the plain print."""
    while end > first + 1 and not lines[end - 1].strip():
        end -= 1
    plain = "\n".join(lines[first:end])
    if page is None and len(plain.encode("utf-8")) <= PAGE_BYTES:
        print(plain)
        return
    pages, size = [], 0
    for unit in paged_units(lines, first, end):
        ubytes = len("\n".join(lines[unit[0]:unit[1]]).encode("utf-8")) + 1
        if pages and size + ubytes <= PAGE_BYTES:
            pages[-1].append(unit)
            size += ubytes
        else:
            pages.append([unit])
            size = ubytes
    n, want = len(pages), page or 1
    if want < 1 or want > n:
        raise SystemExit(f"{title} has {n} page{'' if n == 1 else 's'}, so --page {want} names none")
    total = len(notebook_entries(lines, first + 1, end))
    chosen = pages[want - 1]
    pos = [u[2] for u in chosen if u[2] is not None]
    span = f"entries {pos[0]}–{pos[-1]} of {total}" if pos else f"entries none of {total}"
    tail = f"next: {next_cmd} --page {want + 1}" if want < n else "last page"
    print(f"<!-- page {want} of {n} · {title} · {span} · {tail} -->")
    print("\n".join(lines[chosen[0][0]:chosen[-1][1]]))


def resolve_entry_key(entries: list, key: str, section: str, phase: str, several: bool = False) -> list:
    """The entries `--entry K` names, in document order; SystemExit naming why when it names none or,
    unless `several`, more than one. K is a position (1-based), `OQ<n>`, or, with `several`, ranges and
    comma lists of those (`1-8,10`); any other text is a case-insensitive piece of an entry's first
    line and must match exactly one entry."""
    text = (key or "").strip()
    listing = f'section {phase} "{section}" --list'
    if not text:
        raise SystemExit(f"--entry needs a key: a position, OQ<n> or a piece of the entry's first line (see {listing})")
    parts = [part.strip() for part in text.split(",")]
    matched = [ENTRY_KEY_PART.fullmatch(part) for part in parts]
    if all(matched):
        if not several and (len(parts) > 1 or matched[0].group(2)):
            raise SystemExit(f"--entry {text} names several entries; here it takes one (ranges and lists go with --to-topic only)")
        chosen = {}
        for m in matched:
            if m.group(3):
                n = int(m.group(3))
                hits = [x for x in entries if x["oq"] == n]
                if len(hits) != 1:
                    have = ", ".join(f"OQ{x['oq']} ({x['pos']})" for x in entries if x["oq"] is not None) or "none"
                    raise SystemExit(f"{'no' if not hits else 'more than one'} entry OQ{n} in {section}; its OQ entries: {have}")
            else:
                a, b = int(m.group(1)), int(m.group(2) or m.group(1))
                if a < 1 or a > b or b > len(entries):
                    raise SystemExit(f"{section} has {len(entries)} entr{'y' if len(entries) == 1 else 'ies'}, so {m.group(0)} names none (see {listing})")
                hits = entries[a - 1:b]
            for x in hits:
                chosen[x["pos"]] = x
        return [chosen[pos] for pos in sorted(chosen)]
    wanted = text.lower()
    hits = [x for x in entries if wanted in (x["marker"] + x["lead"]).lower()]
    if len(hits) == 1:
        return hits
    if not hits:
        raise SystemExit(f"no entry of {section} has {text!r} in its first line (see {listing})")
    named = "; ".join(f"{x['pos']}: {x['lead'][:60]}" for x in hits)
    raise SystemExit(f"{text!r} matches {len(hits)} entries of {section}, so it names none; use a position -- {named}")


def _markdown_closers(text: str) -> str:
    """What closes the markdown `text` leaves open: a backtick for an open code span, then `**` for
    open bold; "" when nothing is open."""
    code = bold = False
    k = 0
    while k < len(text):
        if text[k] == "`":
            code = not code
        elif not code and text.startswith("**", k):
            bold = not bold
            k += 1
        k += 1
    return ("`" if code else "") + ("**" if bold else "")


def entry_gist(entry_lines: list) -> str:
    """The derived gist of an entry: a verbatim excerpt, never a summary. The entry's text is flattened
    (its marker and its continuation lines' markers dropped, whitespace collapsed) and kept whole up to
    GIST_MAX characters. Longer, it is cut at the last sentence end (`.` `!` `?` with any closing `**`,
    backtick, bracket or quote; never `:`) between characters 40 and GIST_MAX, else at the last word
    boundary that leaves room for ` …`. Markdown is kept, and a cut never leaves a `**` or a backtick
    open: the markers it would leave open are closed at the cut, inside GIST_MAX."""
    words = []
    for line in entry_lines:
        stripped = line.strip()
        marker = ENTRY_MARKER.match(stripped)
        words.append(stripped[marker.end():] if marker else stripped)
    flat = re.sub(r"\s+", " ", " ".join(words)).strip()
    if len(flat) <= GIST_MAX:
        return flat
    best = None
    for m in GIST_SENTENCE_END.finditer(flat):
        if m.end() > GIST_MAX:
            break
        if m.end() >= 40 and m.end() + len(_markdown_closers(flat[:m.end()])) <= GIST_MAX:
            best = m.end()
    if best is not None:
        return flat[:best] + _markdown_closers(flat[:best])
    for cut in range(GIST_MAX - 2, 0, -1):
        if flat[cut] == " " and cut + len(_markdown_closers(flat[:cut])) + 2 <= GIST_MAX:
            return flat[:cut] + _markdown_closers(flat[:cut]) + " \u2026"
    kept = flat[:GIST_MAX - 5]  # no word boundary at all: one long token (a URL, a path)
    return kept + _markdown_closers(kept) + " \u2026"


def gist_plain_chars(gist: str, entry: dict) -> int:
    """The characters of plain text a gist keeps once its links (whole, bare URLs too), its markdown and
    the entry's own label are stripped: under GIST_PLAIN_MIN, the gist is a bare link."""
    text = re.sub(r"!?\[[^\]]*\]\([^)]*\)", " ", gist)
    text = re.sub(r"<?https?://\S+", " ", text)
    if entry.get("oq") is not None:
        text = re.sub(rf"\bOQ{entry['oq']}\b", " ", text)
    text = re.sub(r"[*_`~#>\[\]…]", "", text)
    return len(re.sub(r"\s+", " ", text).strip())


def entry_block_label(entry: dict) -> str:
    """The label of a moved entry's topic block: its own number, its OQ<n>, else its position."""
    if entry["marker"][0].isdigit():
        return entry["marker"].strip()[:-1]
    if entry["oq"] is not None:
        return f"OQ{entry['oq']}"
    return str(entry["pos"])


def _topic_blocks_missing(text: str, blocks: list) -> list:
    """The names of `blocks` (`(name, entry lines)`) that `text` does not hold as a `## <name>` line, a
    blank line, then those lines byte for byte: the move's check, run before it touches phase.md."""
    lines = text.split("\n")
    found = {}
    for heading, i, e in h2_spans(lines):
        if lines[i] == f"## {heading}":
            found.setdefault(heading, (i, e))
    missing = []
    for name, body in blocks:
        if name not in found:
            missing.append(name)
            continue
        i, e = found[name]
        got, want = lines[i + 1:e], [""] + list(body)
        while got and not got[-1].strip():
            got.pop()
        while len(want) > 1 and not want[-1].strip():
            want.pop()
        if got != want:
            missing.append(name)
    return missing


def _phase_section_body(args: argparse.Namespace) -> str:
    """The text for --replace / --append: `--file`, else stdin."""
    if args.file:
        try:
            body = Path(args.file).read_text(encoding="utf-8")
        except OSError as exc:
            raise SystemExit(f"cannot read --file {args.file}: {exc}")
    else:
        body = sys.stdin.read()
    return body


def _clean_section_body(body: str, heading: str) -> list:
    """The body as lines. A `## ` heading line inside it is refused (it would split the section),
    except the section's own heading as a first line, which is dropped."""
    lines = body.strip("\n").split("\n") if body.strip() else []
    if lines and lines[0].strip().lower() == f"## {heading}".lower():
        lines = lines[1:]
        while lines and not lines[0].strip():
            lines = lines[1:]
    if not lines:
        raise SystemExit("empty text: nothing to write")
    if h2_spans(lines):
        raise SystemExit("the text contains a `## ` heading line, which would split the section; use deeper headings (### ) or write the other section with its own call")
    return lines


def _phase_section_flags(args: argparse.Namespace, mode) -> None:
    """Refuse the flag combinations `section` has no meaning for, naming the right form."""
    if args.topic is not None and (mode or args.list or args.entry is not None or args.gist is not None or args.dry_run):
        raise SystemExit("--topic reads a topic file: give it a block name or nothing (a topic is written by --to-topic, or directly)")
    if args.list and (mode or args.entry is not None):
        raise SystemExit("--list is a read: it takes a section name, no --entry and no write flag")
    if (args.gist is not None or args.dry_run) and mode != "--to-topic":
        raise SystemExit(f"{'--gist' if args.gist is not None else '--dry-run'} works with --to-topic only")
    if args.entry is not None and mode == "--append":
        raise SystemExit("--append adds at the section's end and takes no --entry (to change one entry: --entry K --replace)")
    if args.entry is not None and mode == "--resolve":
        raise SystemExit("--resolve names its entry itself (--resolve OQ<n> --pointer <ref>) and takes no --entry")
    if args.page is not None:
        if mode:
            raise SystemExit(f"--page is a read: it takes no {mode}")
        if args.list or args.entry is not None:
            raise SystemExit(f"--page pages a whole section or topic block; it takes no {'--list' if args.list else '--entry'}")
        if args.page < 1:
            raise SystemExit(f"--page counts from 1, got {args.page}")
    if mode == "--remove" and args.entry is None:
        raise SystemExit("--remove needs --entry K: it deletes one entry, never a section")


def _phase_topic_read(args: argparse.Namespace, pdir: Path, name: str) -> None:
    """`section <P> [<block>] --topic <slug>`: the topic's index (its `## ` blocks with bytes, then
    the total), or one block, heading included, paged like a section (`paged_print`)."""
    slug = args.topic.strip()
    if not TOPIC_SLUG_RE.fullmatch(slug):
        raise SystemExit(f"--topic takes a slug [a-z0-9][a-z0-9-]{{0,63}} (the file topics/<slug>.md), got {args.topic!r}")
    topic = pdir / "topics" / f"{slug}.md"
    if not topic.is_file():
        have = sorted(p.stem for p in (pdir / "topics").glob("*.md")) if (pdir / "topics").is_dir() else []
        raise SystemExit(f"phase {args.phase} has no topics/{slug}.md; its topics: {', '.join(have) or 'none'}")
    text = topic.read_text(encoding="utf-8")
    if not name:
        if args.page is not None:
            raise SystemExit("--page pages one block: give the block name (the index is never paged)")
        for heading, size in h2_sections(text):
            print(f"{size:>8}  {heading}")
        print(f"{len(text.encode('utf-8')):>8}  total")
        return
    lines = text.split("\n")
    spans = h2_spans(lines)
    for heading, i, e in spans:
        if heading.lower() == name.lower():
            paged_print(lines, i, e, heading, f'section {args.phase} "{heading}" --topic {slug}', args.page)
            return
    blocks = ", ".join(f"`{h}`" for h, _, _ in spans) or "none"
    print(f"unknown block: {name!r} in topics/{slug}.md; its blocks are {blocks}", file=sys.stderr)
    raise SystemExit(1)


def _phase_section_entry_write(args: argparse.Namespace, path: Path, text: str, lines: list, heading: str, i: int, e: int) -> None:
    """`--entry K --replace` swaps exactly that entry's lines; `--entry K --remove` deletes it with its
    trailing separator (the last entry of a section takes the blank lines before it instead, so the
    section still ends with its blank line). Every other byte of the file stays identical."""
    key = heading.lower()
    flag = "--replace" if args.replace else "--remove"
    if key == "slices":
        raise SystemExit("`Slices` is generated from each slice.json by `check`; never write it")
    advice = None
    if key in PHASE_SECTION_APPEND_ONLY:
        advice = f"advice: {heading} is append-only by custom ({PHASE_SECTION_APPEND_ONLY[key]}), and --entry {flag} wrote it anyway"
    elif args.remove and key == "decisions":
        advice = "advice: Decisions keeps every decision by custom: a superseded one is replaced in place (--entry K --replace)"
    entries = notebook_entries(lines, i + 1, e)
    entry = resolve_entry_key(entries, args.entry, heading, args.phase)[0]
    old_size = len("\n".join(lines[entry["start"]:entry["end"]]).encode("utf-8"))
    if args.replace:
        new = _clean_section_body(_phase_section_body(args), heading)
        while new and not new[-1].strip():
            new.pop()
        if not ENTRY_MARKER.match(new[0]):
            new[0] = entry["marker"] + new[0].lstrip()  # text without a marker takes the old entry's marker
        parsed = notebook_entries(new, 0, len(new))
        if len(parsed) > 1:
            raise SystemExit(f"the text holds {len(parsed)} entries; --entry K --replace writes exactly one (add the others with --append)")
        if not parsed or parsed[0]["start"] != 0 or parsed[0]["end"] != len(new):
            raise SystemExit("the text is not one entry: a `###` heading or an unindented paragraph after a blank line would stand outside it; indent its continuation lines, or write the rest with --append")
        lines[entry["start"]:entry["end"]] = new
        after = notebook_entries(lines, i + 1, e + len(new) - (entry["end"] - entry["start"]))
        if len(after) != len(entries) or (after[entry["pos"] - 1]["start"], after[entry["pos"] - 1]["end"]) != (entry["start"], entry["start"] + len(new)):
            raise SystemExit("the text would change the entries around it (a fence it opens and never closes?); nothing written")
        verb, new_size = "replaced", len("\n".join(new).encode("utf-8"))
    else:
        if entry["sep_end"] < e:
            del lines[entry["start"]:entry["sep_end"]]
        else:
            first = entry["start"]
            while first > i + 1 and not lines[first - 1].strip():
                first -= 1
            del lines[first:entry["end"]]
        verb, new_size = "removed", 0
    updated = "\n".join(lines)
    if updated != text:
        write_text(path, updated)
    print(f"{verb}={heading} entry={entry['pos']} bytes={old_size}->{new_size} phase_md={len(updated.encode('utf-8'))}")
    if advice:
        print(advice)


def _phase_section_move(args: argparse.Namespace, pdir: Path, archived: bool, path: Path, lines: list, heading: str, i: int, e: int) -> None:
    """`--to-topic <slug> [--entry K] [--gist TEXT] [--dry-run]`: move entries to `topics/<slug>.md`,
    losslessly. Each entry is appended as a `## <Section> <label>` block holding its lines byte for
    byte, the topic is re-read and every block verified, and only then is phase.md rewritten, each
    entry replaced by one pointer line carrying a verbatim gist. A failure between the two writes
    leaves a duplicate, never a loss. Every refusal is named and nothing is written."""
    key = heading.lower()
    slug = args.to_topic.strip()
    if archived and not args.dry_run:
        raise SystemExit(f"phase {args.phase} is archived; its notebook is read-only (--dry-run still reads it)")
    if key in PHASE_SECTION_UNMOVABLE:
        raise SystemExit(f"`{heading}` cannot move to a topic: {PHASE_SECTION_UNMOVABLE[key]}")
    if not TOPIC_SLUG_RE.fullmatch(slug):
        raise SystemExit(f"--to-topic takes a slug [a-z0-9][a-z0-9-]{{0,63}} (the file is topics/<slug>.md), got {args.to_topic!r}")
    if slug == "breakdown":
        raise SystemExit("the slug `breakdown` is refused: each decomposition pass rewrites topics/breakdown.md whole, so entries moved there would be lost; pick another slug")
    entries = notebook_entries(lines, i + 1, e)
    if not entries:
        raise SystemExit(f"`{heading}` has no entries to move (an entry is a column-0 list item: `- `, `* `, `+ `, `1. `, `1) `)")
    reasons, skipped = [], []
    if args.entry is not None:
        chosen = resolve_entry_key(entries, args.entry, heading, args.phase, several=True)
        reasons += [f"entry {x['pos']} is already a pointer line: nothing to move" for x in chosen if x["pointer"]]
    else:  # the whole section: entries already moved stay as they are
        chosen = [x for x in entries if not x["pointer"]]
        skipped = [x["pos"] for x in entries if x["pointer"]]
        if not chosen:
            raise SystemExit(f"every entry of `{heading}` is already a pointer line: nothing to move")
    given = args.gist.strip() if args.gist is not None else None
    if given is not None and len(chosen) != 1:
        reasons.append(f"--gist gives one entry's gist, but this move takes {len(chosen)} entries: move that entry alone (--entry K --gist TEXT), or let the gists derive")
    if given is not None and ("\n" in given or not given):
        reasons.append("--gist must be one non-empty line")
    plans = []
    for x in chosen:
        if x["pointer"]:
            continue
        body = lines[x["start"]:x["end"]]
        gist = given if given is not None else entry_gist(body)
        plain = gist_plain_chars(gist, x)
        if plain < GIST_PLAIN_MIN:
            reasons.append(f"entry {x['pos']}: {'the given' if given is not None else 'its derived'} gist {gist!r} keeps {plain} characters of plain text once markdown, links and the label are stripped, under the {GIST_PLAIN_MIN}-character floor (a bare link): give it a gist that says what the entry holds (--entry {x['pos']} --gist TEXT)")
        plans.append((x, body, gist))
    if reasons:
        for reason in reasons:
            print(f"refused: {reason}", file=sys.stderr)
        raise SystemExit(f"--to-topic refused, nothing written ({len(reasons)} reason{'' if len(reasons) == 1 else 's'} above)")
    rel = f"topics/{slug}.md"
    topic = pdir / "topics" / f"{slug}.md"
    old_topic = topic.read_text(encoding="utf-8") if topic.is_file() else ""
    if old_topic.strip():
        base = old_topic if old_topic.endswith("\n") else old_topic + "\n"
    else:
        base = f"# {args.phase} — {slug}\n\n{TOPIC_INTRO}\n"
    taken = {h.lower() for h, _, _ in h2_spans(base.split("\n"))}
    blocks, added, pointers = [], [], []
    for x, body, gist in plans:
        label = f"{heading} {entry_block_label(x)}"
        name, n = label, 2
        while name.lower() in taken:
            name, n = f"{label} ({n})", n + 1
        taken.add(name.lower())
        blocks.append((name, body))
        added.append(f"\n## {name}\n\n" + "\n".join(body) + "\n")
        pointers.append(f"{x['marker']}{gist} → [{rel}]({rel}) § {name}")
    new_topic = base + "".join(added)
    new_lines = list(lines)
    for (x, _, _), pointer in reversed(list(zip(plans, pointers))):
        new_lines[x["start"]:x["end"]] = [pointer]
    end = e - sum(x["end"] - x["start"] - 1 for x, _, _ in plans)
    after = notebook_entries(new_lines, i + 1, end)
    if (_topic_blocks_missing(new_topic, blocks) or len(after) != len(entries)
            or any(not after[x["pos"] - 1]["pointer"] for x, _, _ in plans)):
        raise SystemExit(f"--to-topic refused, nothing written: the blocks would not read back from {rel} byte for byte, "
                         f"or a pointer line would not parse as one (an unclosed fence in the topic or the entry?)")
    updated = "\n".join(new_lines)
    keys = entry_ranges(x["pos"] for x, _, _ in plans)
    old_size = len("\n".join(lines[i:e]).encode("utf-8"))
    new_size = len("\n".join(new_lines[i:end]).encode("utf-8"))
    tail = f"to={rel} bytes={old_size}->{new_size} phase_md={len(updated.encode('utf-8'))}"
    note = f"skipped={entry_ranges(skipped)} (already pointer lines)" if skipped else ""
    if args.dry_run:
        for pointer in pointers:
            print(pointer)
        print(f"would_move={heading} entries={keys} {tail} saved={old_size - new_size} (dry run: nothing written)")
        if note:
            print(note)
        return
    write_text(topic, new_topic)
    missing = _topic_blocks_missing(topic.read_text(encoding="utf-8"), blocks)
    if missing:
        raise SystemExit(f"{rel} does not hold {', '.join(missing)} byte for byte after the write; phase.md is unchanged, "
                         f"so nothing is lost (check the topic for a partial copy)")
    write_text(path, updated)
    print(f"moved={heading} entries={keys} {tail}")
    if note:
        print(note)


def phase_section(args: argparse.Namespace) -> None:
    """Read or write ONE `## ` section of a phase's phase.md (v61), or one entry of it: the
    notebook is an index, so a reader prints a section or an entry and a writer replaces, appends,
    removes or moves one, never the whole file.

    No name prints the index (a line per heading with its bytes, then the total). `--replace`
    keeps the heading and every other byte of the file; the generated `Slices` section refuses it,
    and the two append-only sections take it with one advice: line. `--append` / `--replace` on a
    heading the notebook lacks creates it before `## Now`. `--resolve OQ<n> --pointer <ref>`
    collapses one Operator Questions entry to a single resolved line (entries are never deleted).
    `--list` lists a section's entries (`notebook_entries`); `--entry K` prints one, and with
    `--replace` / `--remove` writes only it. `--to-topic <slug>` moves entries verbatim into
    `topics/<slug>.md`, leaving one pointer line each; `--topic <slug>` reads that file.
    A write happens only when the text changes; an archived phase is read-only.
    """
    pdir, archived = _find_phase_dir(args.phase)
    name = " ".join(args.name).strip().lstrip("#").strip() if args.name else ""
    modes = [flag for flag, on in (("--replace", args.replace), ("--append", args.append), ("--resolve", bool(args.resolve)),
                                   ("--remove", args.remove), ("--to-topic", args.to_topic is not None)) if on]
    if len(modes) > 1:
        raise SystemExit(f"choose one of {', '.join(modes)}")
    _phase_section_flags(args, modes[0] if modes else None)
    if args.topic is not None:
        _phase_topic_read(args, pdir, name)
        return
    path = pdir / "phase.md"
    if not path.exists():
        raise SystemExit(f"phase {args.phase} has no phase.md")
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    spans = h2_spans(lines)
    headings = ", ".join(f"`{h}`" for h, _, _ in spans)
    advice = None

    def find(wanted: str):
        for heading, i, e in spans:
            if heading.lower() == wanted.lower():
                return heading, i, e
        print(f"unknown section: {wanted!r}; the headings are {headings}", file=sys.stderr)
        raise SystemExit(1)

    if not modes:
        if not name:
            if args.page is not None:
                raise SystemExit(f"--page needs a section name (the index is never paged); the headings are {headings}")
            if args.list or args.entry is not None:
                raise SystemExit(f"{'--list' if args.list else '--entry'} needs a section name; the headings are {headings}")
            report = notebook_report(args.phase, text)
            if not report["flagged"]:  # nothing over or long: the index exactly as before
                for sec in report["sections"]:
                    print(f"{sec['bytes']:>8}  {sec['heading']}")
            else:  # bytes, budget and flags per section, the heading still last
                for sec in report["sections"]:
                    flags = ",".join(f for f, on in (("over", sec["over"]), (f"long:{len(sec['long'])}", sec["long"])) if on) or "-"
                    budget = sec["budget"] if sec["budget"] is not None else "-"
                    print(f"{sec['bytes']:>8}  {budget:>6}  {flags:<12} {sec['heading']}")
            over = " \u2014 OVER BUDGET" if report["over"] else ""
            print(f"{report['bytes']:>8}  total (budget {PHASE_MD_BUDGET}){over}")
            for sec in report["flagged"]:
                if sec["move"]:
                    print(f"move: {sec['move']}")
                elif sec["remedy"]:
                    print(f"fix ## {sec['heading']}: {sec['remedy']}")
            return
        heading, i, e = find(name)
        if args.list:
            entries = notebook_entries(lines, i + 1, e)
            if not entries:
                print(f"`{heading}` has no entries", file=sys.stderr)
            for x in entries:
                flags = ",".join(f for f, on in (("long", x["long"]), ("nested", x["nested"]), ("pointer", x["pointer"])) if on) or "-"
                lead = x["lead"] if len(x["lead"]) <= 80 else x["lead"][:80] + "…"
                print(f"{x['pos']:>4}  {x['label'] or '-':<5} {x['bytes']:>7} B  {flags:<18} {lead}")
            return
        if args.entry is not None:
            entry = resolve_entry_key(notebook_entries(lines, i + 1, e), args.entry, heading, args.phase)[0]
            print("\n".join(lines[entry["start"]:entry["end"]]))
            return
        paged_print(lines, i, e, heading, f'section {args.phase} "{heading}"', args.page)
        return
    if args.to_topic is not None:
        if not name:
            raise SystemExit(f"--to-topic needs a section name; the headings are {headings}")
        heading, i, e = find(name)
        _phase_section_move(args, pdir, archived, path, lines, heading, i, e)
        return
    if archived:
        raise SystemExit(f"phase {args.phase} is archived; its notebook is read-only")
    if args.entry is not None:
        if not name:
            raise SystemExit(f"--entry needs a section name; the headings are {headings}")
        heading, i, e = find(name)
        _phase_section_entry_write(args, path, text, lines, heading, i, e)
        return
    if args.resolve:
        if name and name.lower() != "operator questions":
            raise SystemExit("--resolve works on `Operator Questions` only; omit the section name")
        if not args.pointer:
            raise SystemExit("--resolve needs --pointer <ref> (where the answer landed: a Decisions line, a deferred job, a slice)")
        heading, i, e = find("Operator Questions")
        want = re.fullmatch(r"OQ(\d+)", args.resolve.strip(), re.I)
        if not want:
            raise SystemExit(f"--resolve takes OQ<n>, got {args.resolve!r}")
        n = want.group(1)
        entry = None
        for k in range(i + 1, e):
            m = OQ_ENTRY.match(lines[k])
            if m and m.group(1) == n:
                entry = k
                break
        if entry is None:
            have = ", ".join(f"OQ{OQ_ENTRY.match(ln).group(1)}" for ln in lines[i + 1:e] if OQ_ENTRY.match(ln)) or "none"
            raise SystemExit(f"no Operator Questions entry OQ{n}; entries: {have}")
        if re.match(r"^- \*\*OQ\d+\*\* \(resolved", lines[entry]):
            raise SystemExit(f"OQ{n} is already resolved")
        end = entry + 1
        while end < e and not lines[end].startswith("- "):
            end += 1
        block = lines[entry:end]
        while len(block) > 1 and not block[-1].strip():  # blank separators stay where they were
            block.pop()
            end -= 1
        parts = OQ_PARTS.match(block[0])
        question = (parts.group(1).strip() if parts else "")
        if not question:
            question = next((ln.strip() for ln in block[1:] if ln.strip()), "")
        if len(question) > 160:
            question = question[:157].rstrip() + "..."
        lines[entry:end] = [f"- **OQ{n}** (resolved \u2192 {args.pointer}): {question}"]
        updated, label = "\n".join(lines), f"OQ{n}"
        old_size = len("\n".join(block).encode("utf-8"))
        new_size = len(lines[entry].encode("utf-8"))
    else:
        if not name:
            raise SystemExit(f"{modes[0]} needs a section name; the headings are {headings}")
        created = not any(h.lower() == name.lower() for h, _, _ in spans)
        body = _clean_section_body(_phase_section_body(args), name)
        if created:  # any heading: a new one goes at the end, before ## Now
            now = next((s for h, s, _ in spans if h.lower() == "now"), None)
            at = now if now is not None else len(lines) - 1 if lines and lines[-1] == "" else len(lines)
            lines[at:at] = ([""] if at and lines[at - 1].strip() else []) + [f"## {name}", ""]
            spans = h2_spans(lines)
        heading, i, e = find(name)
        key = heading.lower()
        if key == "slices":
            raise SystemExit("`Slices` is generated from each slice.json by `check`; never write it")
        if args.replace and key in PHASE_SECTION_APPEND_ONLY:
            advice = f"advice: {heading} is append-only by custom; --resolve collapses an answered entry"
        old_section = [] if created else lines[i:e]
        if created or args.replace:
            new_section = [lines[i], ""] + body + [""]
        else:
            new_section = list(old_section)
            while new_section and not new_section[-1].strip():
                new_section.pop()
            new_section += body + [""]
        lines[i:e] = new_section
        updated, label = "\n".join(lines), heading
        old_size = len("\n".join(old_section).encode("utf-8"))
        new_size = len("\n".join(new_section).encode("utf-8"))
    if updated != text:
        write_text(path, updated)
    verb = "replaced" if args.replace else "appended" if args.append else "resolved"
    print(f"{verb}={label} bytes={old_size}->{new_size} phase_md={len(updated.encode('utf-8'))}")
    if advice:
        print(advice)


def rebuild_index_and_state() -> None:
    phases = all_active_phases()
    # Selection (pointer + operator halt) is scoped to this checkout's stream; the
    # dashboards below still list every active phase, parallel ones included.
    stream = current_stream(phases)
    selectable = stream_phases(phases, stream)
    current_phase, current_slice, next_slice = resolve_current(selectable)
    waiting_on = operator_wait_target(selectable, current_phase, current_slice)
    deferred = deferred_jobs()
    agenda_links_now = agenda_links()  # read once per rebuild: every item's phases and jobs
    agenda_counts, agenda_rows = agenda_index(agenda_read_all()[0], agenda_links_now)  # lenient: one bad item never stops it
    rebuilt_at = now_iso()
    index = {
        "active_phases": [
            {
                "id": p["id"], "name": p["name"], "objective": p["objective"], "status": p["status"],
                "order": p.get("order"), "path": p["path"],
                "review_status": p.get("review", {}).get("status"),
                "current_slice": next((s["id"] for s in selectable_slices(p)), None),
                "slice_count": len(p["slices"]),
                "done_slice_count": sum(1 for s in p["slices"] if s.get("status") == "done"),
                **({"execution": phase_execution(p)} if phase_execution(p) else {}),
                **({"pinned": True} if phase_pinned(p) else {}),
            } for p in phases
        ],
        "deferred_open_count": len(deferred.get("open", [])),
        "deferred_promoted_count": len(deferred.get("promoted", [])),
        "deferred_dropped_count": len(deferred.get("dropped", [])),
        "agenda_counts": agenda_counts,
        "agenda": agenda_rows,
        "last_rebuilt_at": rebuilt_at,
    }
    write_json_stamped(WORKS / "index.json", index, "last_rebuilt_at", rebuilt_at)
    mode = "waiting" if waiting_on else ("phase" if current_phase else "idle")
    state = {"current_phase": current_phase, "current_slice": current_slice, "next_slice": next_slice, "waiting_on_operator": waiting_on, "mode": mode}
    if stream:  # only ever present in a parallel-phase checkout
        state["stream"] = stream
    write_json_stamped(WORKS / "state.json", state, "updated_at", rebuilt_at)
    rebuild_backlog(phases, state, index)
    rebuild_deferred_dashboard(deferred)
    rebuild_agenda_dashboard(agenda_counts, agenda_rows, agenda_links_now)
    for p in phases:  # only the marker-delimited ## Slices block; archived phases are never touched
        refresh_phase_md_slices(ROOT / p["path"], p)
    if stream:  # a parallel stream's state just changed: the default checkout's dashboards follow it live
        refresh_default_checkout()


DEFAULT_REFRESH_ENV = "AGENTIC_WORKSPACE_REFRESHING_DEFAULT"


def _default_checkout_root():
    """The workspace root in this repo's main checkout when this checkout is one of its linked
    worktrees, else None (the main checkout itself, no git, or a common dir that is not a plain
    `.git`, as in `_main_host_checkout_agents`)."""
    try:
        proc = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                              cwd=str(ROOT), capture_output=True, text=True, timeout=10)
    except Exception:  # noqa: BLE001 - best effort: no refresh is the honest fallback
        return None
    common = Path(proc.stdout.strip()) if proc.returncode == 0 and proc.stdout.strip() else None
    if common is None or common.name != ".git":
        return None
    root = (common.parent / _repo_prefix()).resolve()
    return None if root == ROOT.resolve() else root


def refresh_default_checkout() -> None:
    """Rerun the default checkout's OWN engine `check` from a parallel stream (workspace v67), so
    its `works/backlog.md` follows this phase whether or not anything runs there. Its rebuild reads
    this phase from this worktree's files (`streams_section`); the files it rewrites are generated
    and stay uncommitted there. Best effort and silent: a missing engine, a failure or a timeout
    never blocks this stream, and the env guard stops a refresh from refreshing again."""
    if os.environ.get(DEFAULT_REFRESH_ENV):
        return
    root = _default_checkout_root()
    engine = root / "scripts" / "workflow.py" if root is not None else None
    if engine is None or not engine.is_file():
        return
    try:
        subprocess.run([sys.executable, str(engine), "check"], cwd=str(root), capture_output=True, text=True,
                       timeout=60, env={**os.environ, DEFAULT_REFRESH_ENV: "1"})
    except Exception:  # noqa: BLE001 - never block the stream on the default checkout's dashboards
        pass


def _phase_at_worktree(worktree: str, phase_id: str):
    """`(phase data, slices)` of one phase as its worktree's files hold them right now (uncommitted
    progress included), or None when the worktree or its phase folder cannot be read."""
    pdir = Path(worktree) / _repo_prefix() / "works" / "phases" / "active" / phase_id
    try:
        data = json.loads((pdir / "phase.json").read_text(encoding="utf-8"))
        slices = [json.loads((s / "slice.json").read_text(encoding="utf-8"))
                  for s in (sorted((pdir / "slices").iterdir()) if (pdir / "slices").is_dir() else [])
                  if (s / "slice.json").is_file()]
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict) or not all(isinstance(s, dict) for s in slices):
        return None
    slices.sort(key=lambda d: d.get("order", 999999))
    return data, slices


def _phase_progress(phase_like: dict, slices: list) -> tuple:
    """`(current slice id or "none", "n/m")` for one phase as read from some source."""
    slices = slices or []
    cur = next((x.get("id") for x in slices if x.get("status") != "done"), None)
    return (cur or "none", f"{sum(1 for x in slices if x.get('status') == 'done')}/{len(slices)}")


def streams_section(phases: list, state: dict, live=None) -> list:
    """The `## Streams` table for `works/backlog.md` (P35.S7): the default stream plus every stamped
    phase still in flight, each read live from where its slices actually advance.

    A parallel phase's slice progress lives on its own branch, so this checkout's copy of it stands
    still until the merge. Each phase read from elsewhere lands in `live` (phase id -> (phase data,
    slices, where it was read)), so `rebuild_backlog` renders its `## Active Phases` row and its
    slice table from the same read. Rows: this checkout's own stream first
    when it is a parallel one (from its working tree), then the `default` row (this checkout's
    pointer on the default stream; on a parallel stream the base branch's pointer, from
    `execution.base_branch`, else the local copy), then one row per other in-flight phase, read
    from its worktree's files while that worktree is on disk (workspace v67: uncommitted progress
    included), then its branch, then `origin/<branch>`, else the local copy -- labelled so. Git is touched
    only when a stamped phase is in flight (the same gate as `current_stream`); with none, this is
    a single working-tree default row and no git call is made. The Host branch column is nested only.
    """
    nested = NESTED is not None
    stream = state.get("stream")
    own = next((p for p in phases if stream and (phase_execution(p) or {}).get("branch") == stream), None)
    others = [p for p in phases if phase_in_flight(p) and p is not own]
    use_git = bool((own or others) and _git_available())
    rows = []

    base_dir = str(HOST_ROOT or ROOT)

    def where(worktree):  # the default homes sit under the checkout's root: print them relative to it, keeping the tracked file free of home paths
        if worktree and os.path.isabs(worktree) and os.path.commonpath([base_dir, worktree]) == base_dir:
            return os.path.relpath(worktree, base_dir)
        return worktree

    def add(stream_cell, phase_id, status, cur, done, host, worktree, source):
        worktree = where(worktree)
        cells = [f"`{clean_cell(stream_cell)}`", f"`{clean_cell(phase_id)}`" if phase_id else "-", clean_cell(status) or "-",
                 f"`{clean_cell(cur)}`" if cur else "-", done or "-"]
        if nested:
            cells.append("detached" if host is HOST_DETACHED else f"`{clean_cell(host)}`" if host else "-")
        cells += [f"`{clean_cell(worktree)}`" if worktree else "-", clean_cell(source)]
        rows.append("| " + " | ".join(cells) + " |")

    if own is not None:
        execution = phase_execution(own)
        cur, done = _phase_progress(own, own["slices"])
        short = _parallel_verdict_pair(own["id"], own.get("status"), (own.get("review") or {}).get("status"), own["slices"],
                                       None, False, True)[0]
        add(stream, own["id"], short, cur, done, _host_branch_cell(execution), execution.get("worktree"), "working tree")

    # The default row.
    if own is None:
        pid, cur_slice = state.get("current_phase"), state.get("current_slice")
        phase = next((p for p in phases if p["id"] == pid), None)
        if phase is None:
            add("default", None, "idle", None, None, None, None, "working tree")
        else:
            _, done = _phase_progress(phase, phase["slices"])
            add("default", pid, phase.get("status"), cur_slice or "none", done, None, None, "working tree")
    else:
        base = (phase_execution(own) or {}).get("base_branch")
        plist, source = None, "local copy"
        if base and use_git:
            plist = _phases_at_ref(base)
            if plist is not None:
                source = f"branch {base}"
        sel = stream_phases(plist if plist is not None else phases, None)
        target = next((q for q in sel if q.get("status") != "done"), None)
        if target is None:
            add("default", None, "idle", None, None, None, None, source)
        else:
            if plist is not None:
                target["slices"] = _slices_at_ref(base, target["id"]) or []
                if live is not None:
                    live[target["id"]] = (target, target["slices"], f"branch `{clean_cell(base)}`")
            cur_slice = resolve_current([target])[1]
            _, done = _phase_progress(target, target["slices"])
            add("default", target["id"], target.get("status"), cur_slice or "none", done, None, None, source)

    for p in others:
        execution = phase_execution(p)
        branch = execution.get("branch")
        data, slices, source = p, p["slices"], "local copy"
        branch_gone, merged = False, None
        on_disk = _phase_at_worktree(execution["worktree"], p["id"]) if use_git and isinstance(execution.get("worktree"), str) else None
        if on_disk is not None:
            (data, slices), source = on_disk, "worktree"
            if live is not None:
                live[p["id"]] = (data, slices, f"its worktree `{clean_cell(where(execution['worktree']))}`")
        if use_git and branch:
            for candidate in ((branch, f"origin/{branch}") if on_disk is None else ()):
                found = _phase_json_at_ref(candidate, p["id"])
                if found is not None:
                    data, slices, source = found, _slices_at_ref(candidate, p["id"]) or [], f"branch {candidate}"
                    if live is not None:
                        live[p["id"]] = (data, slices, f"branch `{clean_cell(candidate)}`")
                    break
            branch_gone = not _branch_exists(branch)
            if not branch_gone:
                merged = _git(["merge-base", "--is-ancestor", branch, "HEAD"], check=False).returncode == 0
        short = _parallel_verdict_pair(p["id"], data.get("status"), (data.get("review") or {}).get("status"), slices,
                                       merged, branch_gone, False)[0]
        cur, done = _phase_progress(data, slices)
        add(branch or "-", p["id"], short, cur, done, _host_branch_cell(execution), execution.get("worktree"), source)

    head = ["Stream", "Phase", "Status", "Current slice", "Done"] + (["Host branch"] if nested else []) + ["Worktree", "Source"]
    return ["## Streams", "", "| " + " | ".join(head) + " |", "|" + "---|" * len(head)] + rows + [""]


def installed_workspace_version():
    """The installer's marker version (`works/.workspace-version.json`), or None when missing, unreadable or not an int."""
    try:
        version = read_json(WORKS / ".workspace-version.json").get("workspace_version")
    except (OSError, ValueError, AttributeError):
        return None
    return version if isinstance(version, int) and not isinstance(version, bool) else None


def rebuild_backlog(phases: list, state: dict, index: dict) -> None:
    lines = [
        "# Backlog", "", "> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.",
        "> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.", "",
        "## Pointer", "",
        f"- Current phase: `{state.get('current_phase') or 'none'}`",
        f"- Current slice: `{state.get('current_slice') or 'none'}`",
        f"- Next slice: `{state.get('next_slice') or 'none'}`",
        f"- Waiting on operator: `{state.get('waiting_on_operator') or 'none'}`",
    ]
    if state.get("stream"):  # only in a parallel-phase checkout; absent on the default stream
        lines.append(f"- Stream: `{clean_cell(state['stream'])}` (parallel phase checkout; the pointer above is scoped to it)")
    live = {}  # phase id -> (phase data, slices, where) for every phase streams_section read from elsewhere
    version = installed_workspace_version()
    lines += [
        f"- Open deferred jobs: `{index.get('deferred_open_count', 0)}`",
        f"- Open agenda items: `{sum((index.get('agenda_counts') or {}).get(key, 0) for key in ('open', 'in_progress'))}`",
        f"- Workspace version: `{'unknown' if version is None else f'v{version}'}`", "",
        *streams_section(phases, state, live),
        "## Active Phases", "", "| Phase | Status | Review | Name | Current Slice | Path |", "|---|---|---|---|---|---|",
    ]
    if not phases:
        lines.append("| - | - | - | - | - | - |")
    for p in phases:
        data, slices, _ = live.get(p["id"], (p, p["slices"], None))
        current = next((s["id"] for s in selectable_slices(data, slices)), "none")
        name = clean_cell(p.get("name", ""))
        review = clean_cell((data.get("review") or {}).get("status"))
        current_cell = f"`{current}`"
        execution = phase_execution(p)
        if execution:  # runs on its own branch; read from it when git could reach it, else this checkout's copy
            current_cell += f" · parallel: `{clean_cell(execution.get('branch'))}`"
        elif phase_pinned(p):  # v42's legacy pin; since v43 the default stream needs no marker
            current_cell += " · pinned: default stream"
        lines.append(f"| [{status_box(data.get('status'))}] `{p['id']}` | `{data.get('status')}` | `{review}` | {name} | {current_cell} | `{p['path']}` |")
    for p in phases:
        data, slices, read_from = live.get(p["id"], (p, p["slices"], None))
        lines.extend(["", f"## Phase {p['id']}: {p['name']}", ""])
        if read_from:  # its slices advance elsewhere: show them as that worktree or branch records them
            lines.extend([f"_Read live from {read_from}, where this phase advances._", ""])
        lines.extend(["| Slice | Status | Name | Kind | Path |", "|---|---|---|---|---|"])
        rows = []
        for s in slices:
            checkbox = status_box(s.get("status"))
            name = clean_cell(s.get("name", ""))
            path = s.get("path") or f"{p['path']}/slices/{s['id']}"  # slice.json read at a ref carries no path
            rows.append(f"| [{checkbox}] `{s['id']}` | `{s['status']}` | {name} | `{clean_cell(s.get('kind', ''))}` | `{path}` |")
        lines.extend(rows)
    lines.append("")
    write_text(WORKS / "backlog.md", "\n".join(lines))


def validate() -> int:
    errors: list = []
    warnings: list = []
    phases = all_active_phases()
    seen_phases, seen_slices = set(), set()
    seen_branches: dict = {}
    all_slice_ids = {s["id"] for p in phases for s in p["slices"]}
    archived_ids = archived_phase_ids()
    for p in phases:
        if p["id"] in seen_phases:
            errors.append(f"duplicate phase id: {p['id']}")
        seen_phases.add(p["id"])
        # Ids: all three shapes are valid and nothing is renamed, so these two only WARN -- an adopter's
        # history must keep validating. Creation is the hard gate (phase new refuses either case).
        if not PHASE_ID_RE.fullmatch(str(p["id"])):
            warnings.append(f"phase id {p['id']!r} has an unknown shape; expected P<n>-<tail> (P46-k2), P<n> (P12) or a minted P-<token> (P-7kq2) -- nothing renames it")
        if p["id"] in archived_ids:
            warnings.append(f"active phase {p['id']} has the same id as an archived phase; an archived id is spent, so lookups by id "
                            "(phase scope, the meter, events.jsonl) mix the two -- new phases are minted (phase new without --phase)")
        if p["status"] not in PHASE_STATUSES:
            errors.append(f"invalid phase status {p['id']}: {p['status']}")
        review_status = p.get("review", {}).get("status")
        if p["status"] == "done" and review_status != "pass":
            errors.append(f"phase {p['id']} is done but review status is {review_status!r}; record a passing review with review")
        if p["status"] == "done":
            unfinished = [s["id"] for s in p["slices"] if s.get("status") != "done"]
            if unfinished:
                errors.append(f"phase {p['id']} is done but has unfinished slices: {', '.join(unfinished)}; a passing review closes the REVIEW slice")
        # A retired doc-consolidation field (`consolidation`, `consolidates`, `execution.consolidation`) from an
        # older install is ignored, never refused.
        # Optional parallel-execution block. Absent = default stream = nothing to check.
        if "execution" in p:
            execution = p.get("execution")
            if not isinstance(execution, dict):
                errors.append(f"phase {p['id']} has a non-object execution block: {execution!r}")
            else:
                mode = execution.get("mode")
                if mode not in EXECUTION_MODES and mode != PINNED_MODE:
                    errors.append(f"phase {p['id']} has invalid execution.mode {mode!r}; expected one of {sorted(EXECUTION_MODES | {PINNED_MODE})}")
                elif mode == PINNED_MODE:
                    pass  # v42's legacy pin to the default stream: no branch, no worktree, nothing else to check
                else:
                    branch = execution.get("branch")
                    if not isinstance(branch, str) or not branch.strip():
                        errors.append(f"phase {p['id']} is parallel but has no execution.branch; the branch name is the stream key")
                    elif branch in seen_branches:
                        errors.append(f"duplicate execution.branch {branch!r}: {seen_branches[branch]} and {p['id']}")
                    else:
                        seen_branches[branch] = p["id"]
                    worktree = execution.get("worktree")
                    if worktree is not None and not isinstance(worktree, str):
                        errors.append(f"phase {p['id']} has invalid execution.worktree {worktree!r}; expected a path string or null")
                    errors.extend(_nested_execution_problems(p["id"], execution))
                    if "repos" in execution:  # P40.S6: a worktree set's repo half (multi-repo only)
                        _nested_execution_repo_problems(p["id"], execution, errors, warnings)
                    unstamped = _unstamped_set_warning(p["id"], execution)  # P40.S8: nested only, a live host worktree only
                    if unstamped:
                        warnings.append(unstamped)
        # Optional operator acceptance gate. Absent = legacy phase = nothing to check and
        # NO warning: nagging every pre-v32 phase on every run would clutter the dashboards.
        if "acceptance" in p:
            acceptance = p.get("acceptance")
            if not isinstance(acceptance, dict):
                errors.append(f"phase {p['id']} has a non-object acceptance block: {acceptance!r}")
            else:
                required = acceptance.get("required")
                if not (required is None or isinstance(required, bool)):
                    errors.append(f"phase {p['id']} has invalid acceptance.required {required!r}; expected true (operator-visible), false (waived) or null (undeclared)")
                for field in ("walkthrough", "note", "requested_at", "cleared_at", "words"):
                    value = acceptance.get(field)
                    if value is not None and not isinstance(value, str):
                        errors.append(f"phase {p['id']} has invalid acceptance.{field} {value!r}; expected a string or null")
                if p["status"] == "done" and required is True and not acceptance.get("cleared_at"):
                    errors.append(f"phase {p['id']} is done but its operator acceptance gate was never cleared; the operator must walk the running product (gate {p['id']} open, then clear --words)")
        # Optional host anchors (P28): written only by a nested install's phase new / passing review.
        # Absent = an at-root or pre-nested phase = nothing to check.
        if "host_anchors" in p:
            anchors = p.get("host_anchors")
            if not isinstance(anchors, dict):
                errors.append(f"phase {p['id']} has a non-object host_anchors block: {anchors!r}")
            else:
                for key, value in anchors.items():
                    if key not in HOST_ANCHOR_KEYS:
                        errors.append(f"phase {p['id']} has unknown host_anchors.{key}; expected only {', '.join(HOST_ANCHOR_KEYS)}")
                    elif value is not None and not (isinstance(value, str) and re.fullmatch(r"[0-9a-f]{7,64}", value)):
                        errors.append(f"phase {p['id']} has invalid host_anchors.{key} {value!r}; expected a host commit sha or null")
        if "repo_anchors" in p and nested_repos():
            _repo_anchor_problems(p, errors, warnings)
        # P51: the PR block. Absent = a phase from before P51 = nothing to check, and no warning.
        if "pr" in p:
            errors.extend(f"phase {p['id']} {problem}" for problem in pr_block_problems(p["pr"], _pr_registry_names()))
        if not (ACTIVE / p["id"] / "intent.md").exists():
            warnings.append(f"phase {p['id']} has no intent.md (expected {p['id']}/intent.md); capture operator intent via the create-phase skill")
        unit = explain_unit(ACTIVE / p["id"])
        if unit is not None and unit not in EXPLAIN_UNITS:
            errors.append(f"phase {p['id']} has an unknown explain unit {unit!r} in intent.md's ## Explain; expected one of "
                          f"{', '.join(EXPLAIN_UNITS)} (an absent unit reads {EXPLAIN_UNIT_DEFAULT})")
        # Bounded notebook (v35). Warnings only: `validate` prints them and still exits 0.
        # A `done` phase is skipped for the budget: its notebook is closed history waiting
        # to be archived, so "rewrite it under budget" is advice nobody can act on -- the
        # check must bite while the phase is still running (that includes `in_review`).
        notebook = ACTIVE / p["id"] / "phase.md"
        lines_n, bytes_n = phase_md_size(notebook.parent)
        if p["status"] != "done" and bytes_n > PHASE_MD_BUDGET:
            warnings.append(f"phase {p['id']}: phase.md is {lines_n} lines / {bytes_n} bytes, over the notebook budget of {PHASE_MD_BUDGET} bytes; {notebook_sections_hint(notebook.parent)}")
        if p["status"] != "done" and notebook.exists():  # per section (design §4): over its budget, or long entries
            for section in notebook_report(p["id"], notebook.read_text(encoding="utf-8"))["flagged"]:
                warnings.append(f"phase {p['id']}: phase.md {notebook_section_line(section)}")
        for heading, pos, rel, block in dangling_pointers(notebook.parent):  # every active phase: a lost decision
            what = f"has no block `{block}`" if block is not None else "does not exist"
            warnings.append(f"phase {p['id']}: phase.md ## {heading} entry {pos} points at {rel}, which {what}: the moved entry is lost (restore the topic from git, or rewrite the pointer)")
        for s in p["slices"]:
            if s["id"] in seen_slices:
                errors.append(f"duplicate slice id: {s['id']}")
            seen_slices.add(s["id"])
            if s["phase_id"] != p["id"]:
                errors.append(f"slice phase mismatch: {s['id']} says {s['phase_id']}, folder phase is {p['id']}")
            if s["status"] not in SLICE_STATUSES:
                errors.append(f"invalid slice status {s['id']}: {s['status']}")
            # Warning, never an error: creation is the hard gate (see SLICE_KINDS), and
            # history an adopting repo cannot change must not break its validate.
            if s.get("kind") not in SLICE_KINDS:
                warnings.append(f"slice {s['id']} has unknown kind {s.get('kind')!r}; expected one of {sorted(SLICE_KINDS)} -- edit slice.json to one of them")
            if s["status"] == "ready" and not (ROOT / s["path"] / "plan.md").exists():
                errors.append(f"slice {s['id']} is ready but has no plan.md; ready asserts an operator-approved plan exists")
            if "pending" in s:  # the typed pending record (v61): {kind, on_words, since}, only while pending
                record = s.get("pending")
                if s["status"] != "pending":
                    errors.append(f"slice {s['id']} is {s['status']} but carries a pending record; slice status clears it when a slice leaves pending -- remove the key")
                elif not isinstance(record, dict) or set(record) != {"kind", "on_words", "since"}:
                    errors.append(f"slice {s['id']} has a malformed pending record {record!r}; expected {{kind, on_words, since}} (slice status {s['id']} pending --stop-kind ... --on-words ...)")
                else:
                    if record.get("kind") not in SLICE_STOP_KINDS:
                        errors.append(f"slice {s['id']} has unknown pending kind {record.get('kind')!r}; expected one of {list(SLICE_STOP_KINDS)}")
                    if not isinstance(record.get("on_words"), str) or not record["on_words"].strip():
                        errors.append(f"slice {s['id']}'s pending record has no on_words (what the operator's words will do)")
                    if not isinstance(record.get("since"), str) or not record["since"].strip():
                        errors.append(f"slice {s['id']}'s pending record has no since timestamp")
            for dep in s.get("depends_on", []):
                if dep not in all_slice_ids:
                    errors.append(f"missing dependency for {s['id']}: {dep}")
            declaration_checks(p, s, errors, warnings)  # P42: declared slices only; silent without the marker
    state = read_json(WORKS / "state.json") if (WORKS / "state.json").exists() else {}
    if state.get("current_phase") and state["current_phase"] not in seen_phases:
        errors.append(f"state current_phase does not exist: {state['current_phase']}")
    if state.get("current_slice") and state["current_slice"] not in seen_slices:
        errors.append(f"state current_slice does not exist: {state['current_slice']}")
    for base, allowed in [(DEFERRED_OPEN, {"deferred", "ready"}), (DEFERRED_PROMOTED, {"promoted", "done"}), (DEFERRED_DROPPED, {"dropped"})]:
        if not base.exists():
            continue
        for ddir in base.iterdir():
            if not ddir.is_dir():
                continue
            djson = ddir / "deferred.json"
            if not djson.exists():
                errors.append(f"missing deferred.json: {shown(ddir)}")
                continue
            data = read_json(djson)
            if not DEFERRED_ID_RE.fullmatch(ddir.name):
                warnings.append(f"deferred id {ddir.name!r} has an unknown shape; expected D<n>-<tail> (D92-x4), D<n> (D12) or a minted D-<token> (D-m3xa) -- nothing renames it")
            if data.get("status") not in DEFERRED_STATUSES:
                errors.append(f"invalid deferred status {data.get('id')}: {data.get('status')}")
            if data.get("status") not in allowed:
                errors.append(f"deferred job in wrong folder: {data.get('id')} status {data.get('status')} under {shown(base)}")
    validate_agenda(errors, warnings)
    # Agent-file drift is advisory only: warn (never error, never crash) when the six managed agent
    # files disagree with the route table (executors.toml/defaults), so a foreign or partial
    # workspace still validates. Skipped when a broken nested marker names no host: the agent files
    # live there, not under ROOT.
    try:
        for _label, path, model, effort in ([] if NESTED is not None and HOST_ROOT is None else executor_agent_files(resolve_routes())):
            if not path.exists():
                warnings.append(f"missing executor agent file: {shown(path)} (run: {WORKFLOW_CMD} sync-agents)")
                continue
            current = path.read_text(encoding="utf-8")
            desired = _patched_agent_md(current, model, effort)
            if desired != current:
                warnings.append(f"executor agent file out of sync with executors.toml/defaults: {shown(path)} (run: {WORKFLOW_CMD} sync-agents)")
    except (SystemExit, Exception) as exc:  # noqa: BLE001 - advisory check must not fail validate
        warnings.append(f"executor agent config check failed: {exc}")
    # Nested personal install (P28): a malformed marker is an ERROR, so a broken nested install is
    # never mistaken for at-root mode; the host must be a git work tree (phase scope and the
    # product commits read it). Silent at root -- no marker, nothing checked.
    if NESTED is not None:
        marker = shown(ROOT / NESTED_MARKER)
        errors.extend(f"{marker}: {problem}" for problem in NESTED_PROBLEMS)
        unknown = sorted(set(NESTED) - set(NESTED_KEYS) - set(NESTED_OPTIONAL_KEYS) - set(NESTED_NOTE_KEYS))
        if unknown:
            warnings.append(f"{marker}: unknown field(s) {', '.join(unknown)} (schema {NESTED_SCHEMA} reads only {', '.join(NESTED_KEYS + NESTED_OPTIONAL_KEYS)})")
        if "converted_from" in NESTED:
            warnings.extend(f"{marker}: {problem} (the --to-multi-repo record; only the CLAUDE.local.md line reads it)"
                            for problem in _converted_from_problems(NESTED["converted_from"]))
        if HOST_ROOT is not None and HOST_ROOT.is_dir():
            try:
                proc = subprocess.run(["git", "rev-parse", "--is-inside-work-tree"], cwd=str(HOST_ROOT), capture_output=True, text=True, timeout=10)
            except Exception:  # noqa: BLE001 - no git binary: say so, never fail on it
                warnings.append(f"git is not available, so the nested install's host {HOST_ROOT} cannot be confirmed as a git work tree")
            else:
                if proc.returncode != 0 or proc.stdout.strip() != "true":
                    errors.append(f"nested install: the host {HOST_ROOT} is not a git work tree (phase scope and the host product commits need one)")
        if nested_repos() and HOST_ROOT is not None and HOST_ROOT.is_dir():
            nested_repo_checks(errors, warnings)
    pr_rules_validate(errors)  # P51: the marker's pr_rules key, or at root works/pr-rules.json, where present
    for w in warnings:
        print(f"warning: {w}")
    if errors:
        print("Workflow validation failed:")
        for e in errors:
            print(f"- {e}")
        return 1
    print("Workflow validation passed.")
    return 0


def require_phase(phase_id: str) -> Path:
    p = ACTIVE / phase_id
    if not (p / "phase.json").exists():
        raise SystemExit(f"phase not found: {phase_id}")
    return p


def require_slice(slice_id: str) -> Path:
    phase_id = slice_id.split(".", 1)[0]
    s = ACTIVE / phase_id / "slices" / slice_id
    if not (s / "slice.json").exists():
        raise SystemExit(f"slice not found: {slice_id}")
    return s


def load_template(name: str) -> str:
    return (WORKS / "templates" / name).read_text(encoding="utf-8")


def render_template(text: str, **values: str) -> str:
    for k, v in values.items():
        text = text.replace(f"__{k.upper()}__", v)
    return text


# Byte-identical to works/templates/phase.md, which is the live seed. The copy exists so
# `phase new` still works on a tree that predates the template (an adopter yet to update);
# tests/retrofit_smoke.sh asserts the two stay identical.
PHASE_MD_TEMPLATE_FALLBACK = """# Phase __PHASE_ID__: __NAME__

_Intent: see [intent.md](intent.md)._

## Objective

__OBJECTIVE__

## Slices

<!-- slices:begin -->
_Generated by `python3 scripts/workflow.py check` from each slice's `slice.json`; never hand-edit this block._
<!-- slices:end -->

## Decisions

_Durable cross-slice decisions, one gist line each. Replace a superseded line (`--entry K --replace`); never stack versions. Long detail goes to `topics/<slug>.md` behind its gist line (`--to-topic` moves one); a breakdown lives in `topics/breakdown.md`._

## Operator Questions

_Questions only the operator can answer, one entry each: `- **OQ<n> (<slice>):** <question>`. Append only (`section <P> "Operator Questions" --append`); an answered entry collapses with `section <P> --resolve OQ<n> --pointer <ref>`, never deleted. Every entry is routed at the review — folded into the acceptance walkthrough, filed with `defer-job`, or resolved. An unrouted entry is a review finding._

## Notes for later slices

_Gotchas and constraints the next slices need, each tagged `**(from <slice>, for <slice>)**`. A slice that consumes a note removes it (`--entry K --remove`); the detail stays in that slice's `result.md`. This file is an index read and written only through `section <P>`, never whole; keep it under 40 KB._

## Now

_≤ 15 lines, rewritten by every slice at its end: what is done, what the next slice must know, what is open. Last on purpose._
"""


def phase_md_template() -> str:
    """The phase-notebook seed: the shipped template when present, else the embedded copy."""
    try:
        return load_template("phase.md")
    except OSError:
        return PHASE_MD_TEMPLATE_FALLBACK


def require_slice_kind(kind: str) -> str:
    """promote-deferred's refusal of an unknown slice kind, at its very top: its --create-phase branch creates
    the phase BEFORE the slice, so a bad kind is caught before anything is written. `slice new` advises instead."""
    if kind not in SLICE_KINDS:
        raise SystemExit(f"invalid slice kind: {kind}; expected one of {sorted(SLICE_KINDS)}")
    return kind


def create_slice(phase_id: str, slice_id: str, name: str, kind: str, order, risk: str, source: dict, depends_on=None, declared=False) -> Path:
    require_phase(phase_id)
    if not slice_id.startswith(f"{phase_id}."):
        raise SystemExit(f"slice id must start with {phase_id}.")
    sdir = ACTIVE / phase_id / "slices" / slice_id
    if sdir.exists():
        raise SystemExit(f"slice already exists: {slice_id}")
    created = now_iso()
    data = {
        "id": slice_id, "phase_id": phase_id, "name": name, "kind": kind, "status": "todo", "order": order,
        "depends_on": depends_on or [], **({DEPENDS_DECLARED: True} if declared else {}), "created_at": created, "started_at": None, "completed_at": None, "risk": risk, "source": source,
        "paths": {"plan": "plan.md", "result": "result.md"},
        "outcome": None,  # one line, set by `slice finish --outcome`; rendered in the phase's ## Slices table
        "validation": {"required": [], "last_run": None, "last_status": "pending"},
        "archive": {"archived": False, "archived_at": None, "archive_path": None},
    }
    write_json(sdir / "slice.json", data)
    # Neither context file is scaffolded: the orchestrator writes its free-form native
    # plan to plan.md at the slice's turn, and the executor writes its free-form
    # result.md at slice end — a fresh slice folder holds only slice.json.
    return sdir


def _with_host_anchors(data: dict, anchors: dict) -> dict:
    """`data` with `anchors` merged into its `host_anchors` block, the block placed right after
    `acceptance` (or appended) when it is new, so phase.json keeps reading naturally."""
    current = data.get("host_anchors")
    merged = dict(current) if isinstance(current, dict) else {}
    merged.update(anchors)
    if "host_anchors" in data:
        data["host_anchors"] = merged
        return data
    ordered = {}
    for key, value in data.items():
        ordered[key] = value
        if key == "acceptance":
            ordered["host_anchors"] = merged
    ordered.setdefault("host_anchors", merged)
    data.clear()
    data.update(ordered)
    return data


def _with_repo_anchors(data: dict, entries: dict) -> dict:
    """`data` with `entries` ({repo name: anchor entry}) merged into its `repo_anchors` block (P40,
    multi-repo only), the block placed right after `host_anchors` (else `acceptance`, else appended)
    when it is new -- `_with_host_anchors`' ordering idiom."""
    current = data.get("repo_anchors")
    merged = dict(current) if isinstance(current, dict) else {}
    merged.update(entries)
    if "repo_anchors" in data:
        data["repo_anchors"] = merged
        return data
    after = "host_anchors" if "host_anchors" in data else "acceptance"
    ordered = {}
    for key, value in data.items():
        ordered[key] = value
        if key == after:
            ordered["repo_anchors"] = merged
    ordered.setdefault("repo_anchors", merged)
    data.clear()
    data.update(ordered)
    return data


def explicit_phase_id(phase_id: str) -> str:
    """An explicit `phase new --phase` id, checked before anything is written: any of the three shapes
    (`P46-k2` with a valid tail -- its number need not be the next one --, an old `P12`, or a v73 `P-` token),
    never one that exists active or archived (an archived id is spent), and a v73 token only as v73's mint
    would have drawn it (`id_token_refusal`). SystemExit otherwise."""
    if not PHASE_ID_RE.fullmatch(phase_id):
        raise SystemExit(f"phase must look like P46-k2 (a number and a two-symbol tail with a letter), P12 or P-7kq2"
                         f" (got {phase_id!r}); omit --phase and the engine mints one")
    if (ACTIVE / phase_id).exists():
        raise SystemExit(f"phase already exists: {phase_id}")
    if phase_id in archived_phase_ids():
        raise SystemExit(f"phase already exists (archived): {phase_id}; an archived id is spent -- omit --phase and the engine mints one")
    token = _id_token(phase_id)
    reason = id_token_refusal(token) if token else None
    if reason:
        raise SystemExit(f"phase id {phase_id} refused: {reason}; omit --phase and the engine mints one")
    return phase_id


def new_phase(args: argparse.Namespace) -> None:
    agenda = getattr(args, "agenda", None)
    if agenda is not None:
        agenda_require_item(agenda)  # P66: refused before an id is minted or anything is written
    raw = getattr(args, "phase", None)
    phase_id = mint_phase_id() if raw is None else explicit_phase_id(raw)
    pdir = ACTIVE / phase_id
    order = _clean_order(args.order) if args.order is not None else max([read_json(p / "phase.json").get("order", 0) for p in phase_dirs()], default=0) + 1
    phase_data = {
        "id": phase_id, "name": args.name, "objective": args.objective, "status": "planned", "order": order,
        "created_at": now_iso(), "started_at": None, "completed_at": None,
        "review": {"status": "pending", "reviewed_at": None, "reviewer": None, "note": None},
        "acceptance": new_acceptance(),
        "pr": new_pr_block(),  # P51: the phase's PR branches (pr branch / pr record); the pass guard reads it
        "paths": {"phase_md": "phase.md", "intent_md": "intent.md", "slices_dir": "slices"},
        "archive": {"archived": False, "archived_at": None, "archive_path": None},
    }
    if NESTED is not None:
        # The nested repo never sees the host's commits, so phase scope's base is the host HEAD now
        # (null while the host has no commit). At root this key is never written.
        phase_data = _with_host_anchors(phase_data, {"created": head_commit() or None})
    repo_stamp_lines = []
    repos = nested_repos()
    if repos:
        # P40 multi-repo: each registered repo's own range starts at its HEAD now (null while it has
        # no commit); `branch` lets phase scope note a repo later switched to another branch.
        stamped = {}
        for repo in repos:
            rpath, why = _phase_repo_path(repo, phase_data)
            if rpath is None:
                repo_stamp_lines.append(f"repo_anchors: {repo['name']} not stamped ({why}) -- phase scope reports it 'no anchor'")
                continue
            head = _rev_parse("HEAD", cwd=rpath)
            stamped[repo["name"]] = {"created": head, "branch": _repo_current_branch(rpath), "review_pass": None, "review_base": None}
        if stamped:
            phase_data = _with_repo_anchors(phase_data, stamped)
            repo_stamp_lines.insert(0, "repo_anchors=" + ", ".join(
                f"{n}@{(e['created'] or 'none')[:7]} ({e['branch'] or 'detached'})" for n, e in stamped.items()) + " -- phase scope's base per repo")
    if agenda is not None:
        phase_data["agenda"] = agenda  # P66 D4: present only while linked
    write_json(pdir / "phase.json", phase_data)
    # Seed the notebook from the template: fixed sections plus an empty generated ## Slices
    # block, which the rebuild at the end of this function fills immediately.
    write_text(pdir / "phase.md", render_template(phase_md_template(), PHASE_ID=phase_id, NAME=args.name, OBJECTIVE=args.objective))
    write_text(pdir / "intent.md", render_template(load_template("intent.md"), PHASE_ID=phase_id, CAPTURED_AT=now_iso(), ORIGIN="operator"))
    create_slice(phase_id, f"{phase_id}.DECOMP", "decompose phase", "decomposition", 0, "high", source={"type": "new_phase", "id": phase_id})
    create_slice(phase_id, f"{phase_id}.REVIEW", "phase review", "review", 9999, "high", source={"type": "new_phase", "id": phase_id})
    append_event("phase_created", phase=phase_id, **({"agenda": agenda} if agenda is not None else {}))
    rebuild_index_and_state()
    print(f"created phase {phase_id}: {shown(pdir)}")
    if agenda is not None:
        print(f"linked {phase_id} to {agenda}")
    for line in repo_stamp_lines:
        print(line)
    # v43: a phase runs on this stream unless the operator asks for a worktree, so creation
    # stamps nothing and says nothing -- except where a worktree would actually buy something.
    if getattr(args, "on_main", False):
        print(f"note: --on-main is a no-op since v43 -- the default stream IS the default, so {phase_id} already runs here; nothing was stamped")
    # Proactive opt-in suggestion: a phase created while another one is mid-flight is the
    # first of the two moments a worktree becomes relevant. Suggestion only, never a default.
    # In a nested install (P35) the command also names the host branch the operator must choose.
    busy = next((p for p in all_active_phases() if p["id"] != phase_id and p.get("status") == "in_progress" and phase_execution(p) is None), None)
    if busy:
        print(f"hint: {busy['id']} is in progress -- this phase can run in parallel on its own branch: {WORKFLOW_CMD} worktree start {phase_id}{NESTED_HOST_BRANCH_ARG}")


def _clean_order(value):
    """Normalize an explicit order: whole numbers stay ints, fractions stay floats so a
    slice/phase can be inserted between two neighbors (e.g. --order 4.5 sorts between 4 and 5)."""
    return int(value) if float(value).is_integer() else float(value)


def _auto_order(pdir: Path, explicit):
    if explicit is not None:
        return _clean_order(explicit)
    orders = [read_json(s / "slice.json").get("order", 0) for s in slice_dirs(pdir) if read_json(s / "slice.json").get("kind") != "review"]
    return max(orders, default=0) + 10


def new_slice(args: argparse.Namespace) -> None:
    pdir = require_phase(args.phase)
    args.slice = full_slice_id(args.phase, args.slice)  # v73: a bare suffix (S1) names a slice of --phase
    order = _auto_order(pdir, args.order)
    deps = declared_dependencies(args.phase, args.slice, order, args.depends_on)  # None: undeclared, as before
    sdir = create_slice(args.phase, args.slice, args.name, args.kind, order, args.risk, source={"type": "manual", "id": None}, depends_on=deps or [], declared=deps is not None)
    append_event("slice_created", phase=args.phase, slice=args.slice)
    rebuild_index_and_state()
    print(f"created slice {args.slice}: {shown(sdir)}")
    if args.kind not in SLICE_KINDS:
        print(f"advice: kind {args.kind} is not one of {', '.join(sorted(SLICE_KINDS))}; it routes on the high row")
    for line in declared_slice_lines(args.kind, deps):
        print(line)


def set_slice_deps(args: argparse.Namespace) -> None:
    """Declare an existing slice (v77): write its `depends_on` and the declared marker, under the same rules
    as `slice new --depends-on`. Refused for a barrier kind (it runs alone) and a `done` slice (no effect)."""
    sdir = require_slice(args.slice)
    data = read_json(sdir / "slice.json")
    phase_id = sdir.parents[1].name
    if data.get("kind") in BARRIER_KINDS:
        raise SystemExit(f"slice deps {args.slice}: kind {data.get('kind')} is a barrier that runs alone; refused, nothing was written")
    if data.get("status") == "done":
        raise SystemExit(f"slice deps {args.slice}: the slice is done, so a declaration has no effect; refused, nothing was written")
    deps = declared_dependencies(phase_id, args.slice, _order_of(data), args.depends_on)
    if data.get(DEPENDS_DECLARED) is True and (data.get("depends_on") or []) == deps:
        print(f"unchanged {args.slice}")
    else:
        data["depends_on"], data[DEPENDS_DECLARED] = deps, True
        write_json(sdir / "slice.json", data)
        append_event("slice_declared", slice=args.slice, depends_on=deps)
        rebuild_index_and_state()
        print(f"declared {args.slice}")
    for line in declared_slice_lines(data.get("kind"), deps):
        print(line)


def cmd_parallel_plan(args: argparse.Namespace) -> None:
    """`phase rounds`: what the engine lets run together in a phase (v77): its open slices in rounds, the
    undeclared middle slices (each runs alone), and, for an explain phase, that it stays sequential.
    Read-only: the decomposition runs it before it returns, and slice finish prints the same plan."""
    pdir = require_phase(args.phase)
    phase = _active_phase(pdir.name) or {}
    lines = parallel_plan_lines(phase)
    if not lines:
        print(f"parallel_plan={pdir.name}: no open slice")
        return
    for line in lines:
        print(line)
    if explain_phase(pdir):
        print("note: an explain phase's chapters stay undeclared and run one at a time")
        return
    loose = undeclared_middle_slices(phase)
    if loose:
        print(f"undeclared={', '.join(str(s.get('id')) for s in loose)} (advice: each runs alone until it is declared: "
              f"{WORKFLOW_CMD} slice deps <slice> --depends-on <id>|none)")


def _set_slice_status(sdir: Path, status: str, pending=None) -> str:
    """Write the status; `pending` (a {kind, on_words, since} record) is stored only with status `pending`.
    Leaving `pending` clears the record; a bare `pending` keeps one only when the slice was already pending."""
    data = read_json(sdir / "slice.json")
    old = data.get("status")
    data["status"] = status
    if status == "pending" and pending is not None:
        data["pending"] = pending
    elif status != "pending" or old != "pending":
        data.pop("pending", None)
    if status == "in_progress" and not data.get("started_at"):
        data["started_at"] = now_iso()
    if status == "done":
        data["completed_at"] = now_iso()
    else:  # a linked checkout's commit record (COMMITTED_AT) holds only while the slice stays done
        data.pop(COMMITTED_AT, None)
    write_json(sdir / "slice.json", data)
    return old


def set_slice_status(slice_id: str, status: str, pending=None) -> None:
    if status not in SLICE_STATUSES:
        raise SystemExit(f"invalid slice status: {status}")
    sdir = require_slice(slice_id)
    old = _set_slice_status(sdir, status, pending)
    extra = {"stop_kind": pending["kind"]} if pending else {}
    append_event("slice_status_changed", slice=slice_id, old_status=old, new_status=status, **extra)
    rebuild_index_and_state()


def cmd_set_slice_status(args: argparse.Namespace) -> None:
    """slice status: a `pending` stop is typed with --stop-kind and --on-words, both, and only with `pending`;
    a `pending` without them is refused, nothing written (the invariant: a pending stop halts the run)."""
    stop_kind, on_words = getattr(args, "stop_kind", None), getattr(args, "on_words", None)
    on_words = _one_line(on_words) if on_words is not None else None
    pending = None
    if args.status != "pending":
        if stop_kind or on_words is not None:
            raise SystemExit(f"slice status: --stop-kind/--on-words type a pending stop; refused with status {args.status!r}")
    else:
        if not stop_kind or not on_words:
            raise SystemExit(f"slice status {args.slice} pending: refused, nothing written -- a pending stop needs both "
                             f"--stop-kind <{'|'.join(SLICE_STOP_KINDS)}> and --on-words \"<what the operator's words will do>\"")
        pending = {"kind": stop_kind, "on_words": on_words, "since": now_iso()}
    set_slice_status(args.slice, args.status, pending)
    print(f"slice {args.slice}: {args.status}" + (f" (stop_kind={stop_kind})" if pending else ""))


def start_slice(args: argparse.Namespace) -> None:
    warning = start_warning(args.slice)  # P42.F1: declared phases only; read before the start changes the state
    set_slice_status(args.slice, "in_progress")
    print(f"started {args.slice}")
    if warning:
        print(warning)
    step = notebook_step(args.slice.split(".", 1)[0])  # §6: a warning, never a refusal
    if step:
        todo = ("advice: run the notebook_move lines `next` prints before dispatching" if step["form"] == "moves"
                else "advisory: nothing left to move (`next` names what remains)")
        print(f"warning: notebook {step['phase']} is over budget ({step['bytes']} of {PHASE_MD_BUDGET} B) -- {todo}")


def finish_slice(args: argparse.Namespace) -> None:
    sdir = require_slice(args.slice)
    pdir = sdir.parents[1]  # .../<phase>/slices/<slice> -> <phase>
    decomposition = read_json(sdir / "slice.json").get("kind") == "decomposition"
    loose = []
    if decomposition and not explain_phase(pdir):  # v77: the cut decides parallelism; an undeclared slice runs alone
        loose = undeclared_middle_slices(_active_phase(pdir.name) or {})
    outcome = (getattr(args, "outcome", None) or "").strip()
    if outcome:  # stored before the status change, so the rebuild it triggers renders the row
        data = read_json(sdir / "slice.json")
        data["outcome"] = outcome
        write_json(sdir / "slice.json", data)
    set_slice_status(args.slice, "done")
    if not outcome:  # a warning, never an error: the slice is still finished
        print(f"warning: no --outcome recorded for {args.slice}; the ## Slices row will be blank")
    print(f"finished {args.slice}")
    if decomposition:  # v77: the engine's determination of what runs together, for the orchestrator to relay
        for line in parallel_plan_lines(_active_phase(pdir.name) or {}):
            print(line)
    for s in loose:
        print(f"advice: {s.get('id')} is a middle slice left undeclared, so it runs alone: "
              f"{WORKFLOW_CMD} slice deps {s.get('id')} --depends-on <an earlier slice of this phase>|none")
    lines_n, bytes_n = phase_md_size(sdir.parents[1])  # .../<phase>/slices/<slice> -> <phase>
    if lines_n or bytes_n:  # the notebook is where the next slice reads its state; keep it in view
        over = " \u2014 OVER BUDGET" if bytes_n > PHASE_MD_BUDGET else ""  # bytes judge; lines are informational
        print(f"phase.md: {lines_n} lines / {bytes_n} bytes (budget {PHASE_MD_BUDGET} bytes){over}")
        if bytes_n > PHASE_MD_BUDGET:
            print(f"  {notebook_sections_hint(sdir.parents[1])}")
        report = notebook_report(pdir.name, (pdir / "phase.md").read_text(encoding="utf-8"))
        for section in report["flagged"]:  # a section over its own budget or holding long entries
            print(f"  {notebook_section_line(section)}")


def _set_phase_status(pdir: Path, status: str) -> str:
    data = read_json(pdir / "phase.json")
    old = data.get("status")
    data["status"] = status
    if status == "in_progress" and not data.get("started_at"):
        data["started_at"] = now_iso()
    if status == "done":
        data["completed_at"] = now_iso()
    write_json(pdir / "phase.json", data)
    return old


def set_phase_status(args: argparse.Namespace) -> None:
    if args.status not in PHASE_STATUSES:
        raise SystemExit(f"invalid phase status: {args.status}")
    pdir = require_phase(args.phase)
    old = _set_phase_status(pdir, args.status)
    append_event("phase_status_changed", phase=args.phase, old_status=old, new_status=args.status)
    rebuild_index_and_state()
    print(f"phase {args.phase}: {old} -> {args.status}")


def _require_acceptance_cleared(phase_id: str, data: dict) -> None:
    """Refuse a passing review while the operator acceptance gate is undeclared or uncleared.

    Called before `review_phase` writes anything. Only `pass` is ever refused: an operator's
    failure report must stay recordable as `changes_requested` (or `blocked`).
    """
    acceptance = phase_acceptance(data)
    if acceptance is None:
        if "acceptance" in data:
            print(f"acceptance: phase {phase_id} has a malformed gate block -- treated as legacy (run: {WORKFLOW_CMD} check --no-rebuild)")
        else:
            print("acceptance: legacy phase (no gate block) -- pass recorded without an operator acceptance gate")
        return
    required = acceptance.get("required")
    if required is None:
        raise SystemExit(
            f"phase {phase_id} has not declared whether the operator must accept it; a pass cannot be recorded yet:\n"
            f"  {WORKFLOW_CMD} gate {phase_id} require                     (operator-visible: the operator walks the running product)\n"
            f"  {WORKFLOW_CMD} gate {phase_id} waive --note \"why\"          (nothing the operator can see)")
    if required is True and not acceptance.get("cleared_at"):
        raise SystemExit(
            f"phase {phase_id} requires operator acceptance and the gate is not cleared; show the operator the running product first:\n"
            f"  {WORKFLOW_CMD} gate {phase_id} open --walkthrough \"...\"    (orchestrator, after the review executor's validation and judgment)\n"
            f"  {WORKFLOW_CMD} gate {phase_id} clear --words \"<the operator's words>\"   (after the operator walks it)")


def review_phase(args: argparse.Namespace) -> None:
    if args.verdict not in REVIEW_VERDICTS:
        raise SystemExit(f"verdict must be one of: {', '.join(sorted(REVIEW_VERDICTS))}")
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    # Gate check first, before anything is written: a refused pass must leave no trace.
    if args.verdict == "pass":
        _require_acceptance_cleared(args.phase, data)
        _pr_draft_advice(args.phase, data)  # advice only (v102): a pass with no draft PR prints advice: pr_draft=due
    if args.verdict == "changes_requested" and data.get("status") == "done" and _pr_open_entries(data):
        # P52: a done phase with an open PR reopens through phase reopen (any change request, the team's or the
        # operator's), which also cuts a nested install's worktree on the PR branch; recorded here it would reopen
        # with no worktree. A done phase with no open PR is unchanged.
        open_prs = ", ".join(f"{_pr_label(e)} ({e.get('state') or 'unsynced'})" for e in _pr_open_entries(data))
        raise SystemExit(f"review {args.phase} --verdict changes_requested: refused -- {args.phase} is done and its PR is still open "
                         f"({open_prs}); a change request (the team's or the operator's) reopens it on the PR branch: "
                         f"{WORKFLOW_CMD} phase reopen {args.phase} --note \"team-reported: <what>\" (or \"operator-reported: <what>\"; "
                         f"pr sync {args.phase} first) -- nothing was written")
    # The fix passes this review cycle has asked for: one per `changes_requested`. A pass ends the cycle and
    # clears the count; a reopen is itself a change request, so `_reopen_apply` starts its cycle at one.
    earlier = (data.get("review") or {}).get("fix_passes")
    fix_passes = 0 if args.verdict == "pass" else (
        (earlier if type(earlier) is int and earlier > 0 else 0) + (args.verdict == "changes_requested"))
    data["review"] = {"status": args.verdict, "reviewed_at": now_iso(), "reviewer": args.reviewer, "note": args.note}
    if fix_passes:
        data["review"]["fix_passes"] = fix_passes
    if args.verdict == "changes_requested":
        acceptance = phase_acceptance(data)
        if acceptance is not None:
            # The phase is about to change again, so the gate re-opens for the re-review.
            # `required` and the operator's note survive; the walked script does not.
            acceptance.update({"walkthrough": None, "requested_at": None, "cleared_at": None})
            acceptance.pop("words", None)
    # Verdict drives phase status so the lifecycle stays consistent.
    status_map = {"pass": "done", "changes_requested": "in_progress", "blocked": "blocked"}
    new_status = status_map[args.verdict]
    if new_status == "done":
        data["completed_at"] = now_iso()
    data["status"] = new_status
    if args.verdict == "pass" and NESTED is not None:
        # The end of the phase's host range: phase scope reads base..review_pass in the host.
        _with_host_anchors(data, {"review_pass": head_commit() or None})
        _freeze_host_review_base(data)
        if nested_repos():
            _freeze_repo_anchors(data)
    write_json(pdir / "phase.json", data)
    # Drive the phase's REVIEW slice from the same verdict so the phase and its
    # review slice never diverge (a pass no longer leaves REVIEW stuck in_progress).
    _drive_review_slices(pdir, args.verdict)
    append_event("phase_reviewed", phase=args.phase, verdict=args.verdict, reviewer=args.reviewer)
    rebuild_index_and_state()
    print(f"phase {args.phase} review: {args.verdict} (status -> {new_status})")
    if args.verdict == "changes_requested":
        if fix_passes <= 1:
            print(f"create fix slices, e.g.: {WORKFLOW_CMD} slice new --phase {args.phase} --slice {args.phase}.F1 --name \"...\" --kind fix")
        else:
            print(f"fix_passes={fix_passes}: the one fix pass already ran -- a further fix needs the operator's word (this verdict, when it "
                  f"records their own report); without it cut no fix slice and stop: {WORKFLOW_CMD} slice status "
                  f"{args.phase}.REVIEW pending --stop-kind decision --on-words \"...\"")
    elif args.verdict == "pass":
        print(f"phase {args.phase} is done and stays in active/. Do NOT archive a single phase now.")
        print("Archive done phases later, whole phases only: `phase rotate` (archives every done phase), or `phase archive --all` once every active phase is done.")


def _drive_review_slices(pdir: Path, verdict: str) -> list:
    """Set the phase's REVIEW slice(s) from a phase verdict (`review`, and `phase reopen`'s
    changes_requested), so the phase and its review slice never diverge. Returns `[(slice id, old status)]`."""
    slice_verdict = {"pass": "done", "changes_requested": "changes_requested", "blocked": "blocked"}[verdict]
    driven = []
    for sdir in slice_dirs(pdir):
        sdata = read_json(sdir / "slice.json")
        if sdata.get("kind") == "review":
            old = _set_slice_status(sdir, slice_verdict)
            if slice_verdict == "done" and cloud_link_file().exists():
                # a REVIEW changes no product file, so its only commit is the workflow state's, which a linked
                # checkout never makes: its commit record is written with the verdict
                closed = read_json(sdir / "slice.json")
                closed[COMMITTED_AT] = now_iso()
                write_json(sdir / "slice.json", closed)
            append_event("slice_status_changed", slice=sdata["id"], old_status=old, new_status=slice_verdict)
            driven.append((sdata["id"], old))
    return driven


def _ensure_acceptance(data: dict) -> dict:
    """The phase's acceptance block, created on demand -- this is how an adopter opts a legacy
    phase in. Inserted right after `review` so phase.json keeps reading naturally; a malformed
    block is replaced by a fresh one."""
    acceptance = phase_acceptance(data)
    if acceptance is not None:
        return acceptance
    acceptance = new_acceptance()
    ordered = {}
    for key, value in data.items():
        if key == "acceptance":
            continue
        ordered[key] = value
        if key == "review":
            ordered["acceptance"] = acceptance
    ordered.setdefault("acceptance", acceptance)
    data.clear()
    data.update(ordered)
    return acceptance


def _print_acceptance(phase_id: str, acceptance) -> None:
    print(f"phase={phase_id}")
    if acceptance is None:
        print("acceptance=none (legacy phase: no gate block, so review --verdict pass is allowed)")
        print(f"declare one with: {WORKFLOW_CMD} gate {phase_id} require | waive --note \"why\"")
        return
    for key in ("required", "requested_at", "cleared_at", "words", "note"):
        value = acceptance.get(key)
        print(f"{key}={json.dumps(value) if key == 'required' else (value or 'none')}")
    walkthrough = acceptance.get("walkthrough")
    if walkthrough:
        print("walkthrough:")
        print(walkthrough)
    else:
        print("walkthrough=none")


def cmd_gate(args: argparse.Namespace) -> None:
    """`gate <P> [require|waive|open|clear]`: declare, open, clear or show (bare) a phase's operator acceptance gate.
    `clear` needs --words, the operator's literal words, recorded beside cleared_at (a sign-off is their words).
    Orchestrator/operator command: executors never run it; an open gate STOPS the run until the operator walks it."""
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    action = args.action
    if args.walkthrough is not None and action != "open":
        raise SystemExit(f"--walkthrough belongs to open: {WORKFLOW_CMD} gate {args.phase} open --walkthrough \"...\"")
    if args.words is not None and action != "clear":
        raise SystemExit(f"--words belongs to clear: {WORKFLOW_CMD} gate {args.phase} clear --words \"<the operator's words>\"")
    if action is None:
        _print_acceptance(args.phase, phase_acceptance(data))  # show only: writes nothing
        return
    acceptance = phase_acceptance(data)
    message = None
    words = (args.words or "").strip()
    if action == "require":
        acceptance = _ensure_acceptance(data)
        acceptance["required"] = True
        event = "acceptance_required"
        message = f"phase {args.phase}: operator acceptance REQUIRED -- review --verdict pass refuses until the gate is opened and cleared"
    elif action == "waive":
        if not args.note:
            raise SystemExit(f"gate {args.phase} waive requires --note \"why this phase changes nothing the operator can see\"")
        acceptance = _ensure_acceptance(data)
        acceptance["required"] = False
        acceptance["note"] = args.note
        event = "acceptance_waived"
        message = f"phase {args.phase}: operator acceptance WAIVED -- {args.note}"
    elif action == "open":
        if acceptance is None or acceptance.get("required") is not True:
            raise SystemExit(
                f"phase {args.phase} has not declared that the operator must accept it; declare it first:\n"
                f"  {WORKFLOW_CMD} gate {args.phase} require")
        if not (args.walkthrough or "").strip():
            raise SystemExit(f"gate {args.phase} open requires --walkthrough \"the concrete script: URLs to open, actions to try, in the operator runtime\"")
        acceptance["walkthrough"] = args.walkthrough
        acceptance["requested_at"] = now_iso()
        acceptance["cleared_at"] = None
        event = "acceptance_opened"
    else:  # clear: the operator's literal words, or nothing is written
        if not words:
            raise SystemExit(f"gate {args.phase} clear: refused -- --words \"<the operator's literal words>\" is required: a sign-off is "
                             f"their words, never a reading of them -- nothing was written")
        if acceptance is None or not acceptance.get("requested_at"):
            raise SystemExit(
                f"phase {args.phase} has no open acceptance gate (requested_at is unset); nothing to clear:\n"
                f"  {WORKFLOW_CMD} gate {args.phase} open --walkthrough \"...\"")
        acceptance["cleared_at"] = now_iso()
        acceptance["words"] = words
        if args.note:
            acceptance["note"] = args.note
        event = "acceptance_cleared"
    write_json(pdir / "phase.json", data)
    # Opening/clearing rides the existing `pending` halt -- no second halt state.
    if action in ("open", "clear"):
        status = "pending" if action == "open" else "in_progress"
        old = _set_phase_status(pdir, status)
        append_event("phase_status_changed", phase=args.phase, old_status=old, new_status=status)
    append_event(event, phase=args.phase, **({"words": words} if action == "clear" else {}))
    rebuild_index_and_state()
    if action == "open":
        print(f"phase {args.phase}: acceptance gate OPEN -- phase is pending [~]; do not start, finish, or advance past it")
        print("WALKTHROUGH (the operator runs this against the running product):")
        print(args.walkthrough)
        print(f"Then clear it with the operator's literal words: {WORKFLOW_CMD} gate {args.phase} clear --words \"...\" [--note \"what they reported\"]")
    elif action == "clear":
        print(f"phase {args.phase}: acceptance gate CLEARED with the operator's words -- phase is in_progress again; "
              f"the close records the pass: {WORKFLOW_CMD} close {args.phase}")
    else:
        print(message)


def _git(cmd: list, cwd=None, check: bool = True):
    """Run a git command in the workspace root. With `check`, a failure raises SystemExit
    carrying git's own message, so every parallel-mode guard fails loudly and in one style."""
    try:
        proc = subprocess.run(["git", *cmd], cwd=str(cwd or ROOT), capture_output=True, text=True)
    except FileNotFoundError:
        raise SystemExit("git is not available; parallel execution needs git")
    if check and proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip() or f"exit {proc.returncode}"
        raise SystemExit(f"git {' '.join(cmd)} failed: {detail}")
    return proc


def _require_git_repo() -> None:
    proc = _git(["rev-parse", "--is-inside-work-tree"], check=False)
    if proc.returncode != 0 or proc.stdout.strip() != "true":
        raise SystemExit("not inside a git work tree; parallel execution needs a git repo")


def _branch_exists(branch: str) -> bool:
    return _git(["rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"], check=False).returncode == 0


def _git_available(cwd=None) -> bool:
    """True when this workspace (or `cwd`: a nested install's host) sits inside a usable git work
    tree. Never raises: a workspace without git (or outside a repo) must keep working exactly as before."""
    try:
        proc = subprocess.run(["git", "rev-parse", "--is-inside-work-tree"], cwd=str(cwd or ROOT), capture_output=True, text=True)
    except Exception:  # noqa: BLE001 - git is optional
        return False
    return proc.returncode == 0 and proc.stdout.strip() == "true"


def _git_dir(common: bool = False, cwd=None) -> Path:
    """This checkout's git dir (per-worktree state: HEAD, index, MERGE_HEAD, rebase-*) or, with
    `common`, the dir every worktree shares (refs, info/exclude). Absolute either way: git prints
    `.git` relative to the cwd in the main checkout and an absolute path from a linked worktree,
    and joining onto the cwd (ROOT, or `cwd`: a nested install's host) is right in both cases."""
    flag = "--git-common-dir" if common else "--git-dir"
    base = Path(cwd) if cwd is not None else ROOT
    return (base / _git(["rev-parse", flag], cwd=cwd).stdout.strip()).resolve()


def _git_operation_in_progress(cwd=None):
    """'merge' / 'rebase' while this checkout is mid-operation, else None. `git commit -- <paths>`
    refuses a partial commit during either, so the stamp commit needs a plain HEAD. With `cwd` (a
    nested install's host, P35) a cherry-pick or a bisect counts too: the host is never touched
    mid-operation, and its branch and worktree are cut only from a plain HEAD."""
    gd = _git_dir(cwd=cwd)
    if (gd / "MERGE_HEAD").exists():
        return "merge"
    if (gd / "rebase-merge").exists() or (gd / "rebase-apply").exists():
        return "rebase"
    if cwd is not None:
        if (gd / "CHERRY_PICK_HEAD").exists():
            return "cherry-pick"
        if (gd / "BISECT_LOG").exists():
            return "bisect"
    return None


def _ensure_worktrees_excluded(cwd=None) -> None:
    """Put `.claude/worktrees/` in the common `info/exclude` once, so a nested phase worktree never
    shows as untracked (or gets swept into `git add -A` as an embedded repo) in any checkout of this
    repo. Never `.gitignore`: that file is the adopter's, tracked, and theirs to edit.

    With `cwd` (a nested install's host, P35) the line goes into the HOST's common exclude, anchored
    as `/.claude/worktrees/` like the installer's managed block, and either form counts as present."""
    exclude = _git_dir(common=True, cwd=cwd) / "info" / "exclude"
    line = f"{WORKTREES_DIR}/" if cwd is None else f"/{WORKTREES_DIR}/"
    present = {line} if cwd is None else {line, f"{WORKTREES_DIR}/"}
    existing = exclude.read_text(encoding="utf-8") if exclude.exists() else ""
    if present & {l.strip() for l in existing.splitlines()}:
        return
    sep = "" if not existing or existing.endswith("\n") else "\n"
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.write_text(f"{existing}{sep}# agentic workspace: per-phase git worktrees cut by worktree start\n{line}\n", encoding="utf-8")


_REPO_PREFIX = None


def _repo_prefix() -> str:
    """The workspace root's path inside the git repo ('' at the repo root).

    `git show <ref>:<path>` and `git cat-file <ref>:<path>` read the path from the tree's root, so every
    cross-ref read below prefixes the workspace-relative path with this. `git ls-tree` reads its path
    relative to the working directory (the workspace root, where `_git` runs), so a prefixed path goes
    only through `_ls_tree`, which reads from the repo's top. A pathspec (`git log/diff/status -- <path>`)
    is working-directory-relative too: give it the workspace-relative path, never a prefixed one."""
    global _REPO_PREFIX
    if _REPO_PREFIX is None:
        _REPO_PREFIX = _git(["rev-parse", "--show-prefix"], check=False).stdout.strip()
    return _REPO_PREFIX


def _ls_tree(ref: str, rel: str):
    """`git ls-tree --name-only` of the workspace-relative folder `rel` (ending in `/`) at `ref`, read from the
    repo's top: `--full-tree` makes git take the prefixed path from the top, not from the working directory,
    so a workspace installed in a subfolder of its repo lists its own folder, not `<prefix><prefix><rel>`
    (P66 F9). The printed names are full repo paths (`--full-tree` implies `--full-name`); at the repo root,
    and in a nested install (whose `workflow/` is its own repo), they are what a plain `ls-tree` printed."""
    return _git(["ls-tree", "--full-tree", "--name-only", ref, f"{_repo_prefix()}{rel}"], check=False)


def _json_at_ref(ref: str, rel: str):
    """A workspace-relative JSON file as recorded at a git ref, or None when unreadable."""
    proc = _git(["show", f"{ref}:{_repo_prefix()}{rel}"], check=False)
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout)
    except ValueError:
        return None


def _phase_json_at_ref(ref: str, phase_id: str):
    return _json_at_ref(ref, f"works/phases/active/{phase_id}/phase.json")


def _phases_at_ref(ref: str):
    """Every active phase.json as recorded at a git ref (ordered), or None if the ref is unreadable.

    Lets the gate read another stream's state (main, `origin/main`, a phase branch)
    without switching checkouts -- pre-merge, main's copy of a phase branch's state is stale.
    """
    proc = _ls_tree(ref, "works/phases/active/")
    if proc.returncode != 0:
        return None
    prefix = _repo_prefix()
    phases = []
    for line in proc.stdout.splitlines():
        entry = line.strip().rstrip("/")  # a full repo path
        if not entry:
            continue
        raw = _git(["show", f"{ref}:{entry}/phase.json"], check=False)
        if raw.returncode != 0:
            continue
        try:
            data = json.loads(raw.stdout)
        except ValueError:
            continue
        data.setdefault("path", entry[len(prefix):] if prefix and entry.startswith(prefix) else entry)  # workspace-relative, as all_active_phases
        phases.append(data)
    phases.sort(key=lambda d: (d.get("order", 999999), id_sort_key(d.get("id", ""), d.get("created_at"))))  # phase_dirs' order
    return phases


def _slices_at_ref(ref: str, phase_id: str):
    """Every slice.json of one phase as recorded at a git ref (ordered), or None if unreadable.

    The cross-stream half of `_phases_at_ref`: a phase branch's slice progress exists only on
    that branch until the merge, so reading it needs the tree at the ref, not the checkout.
    """
    proc = _ls_tree(ref, f"works/phases/active/{phase_id}/slices/")
    if proc.returncode != 0:
        return None
    slices = []
    for line in proc.stdout.splitlines():
        entry = line.strip().rstrip("/")  # a full repo path
        if not entry:
            continue
        raw = _git(["show", f"{ref}:{entry}/slice.json"], check=False)
        if raw.returncode != 0:
            continue
        try:
            data = json.loads(raw.stdout)
        except ValueError:
            continue
        slices.append(data)
    slices.sort(key=lambda d: d.get("order", 999999))
    return slices


def _worktree_entries(cwd=None) -> list:
    """`[(path, ref-or-None)]` for every worktree git registers in the repo at `cwd` (ROOT by default),
    from `git worktree list --porcelain`; `ref` is `refs/heads/<name>`, or None when detached/bare."""
    return _parse_worktree_list(_git(["worktree", "list", "--porcelain"], cwd=cwd).stdout)


def _parse_worktree_list(text: str) -> list:
    """`git worktree list --porcelain` output -> `[(path, ref-or-None)]` (see `_worktree_entries`)."""
    entries, path, ref = [], None, None
    for line in text.splitlines() + [""]:
        if line.startswith("worktree "):
            path, ref = line[len("worktree "):], None
        elif line.startswith("branch "):
            ref = line[len("branch "):]
        elif not line.strip() and path is not None:
            entries.append((path, ref))
            path, ref = None, None
    return entries


def _rev_parse(ref: str, cwd=None):
    proc = _git(["rev-parse", "-q", "--verify", f"{ref}^{{commit}}"], cwd=cwd, check=False)
    return proc.stdout.strip() if proc.returncode == 0 and proc.stdout.strip() else None


def _one_line(text) -> str:
    """A stored free-text value collapsed onto one printable line."""
    return " ".join(str(text).split())


def cmd_next(args: argparse.Namespace) -> None:
    """Print this checkout's pointer. When the current phase is not done and its notebook is over
    PHASE_MD_BUDGET, `notebook_over_budget=` (and up to 3 `notebook_move=` commands, the required form;
    none, the advisory form) follows the pointer and wave lines, and in the WAITING block precedes its
    `After the operator approves` line: run the moves before the next dispatch. Silent under budget."""
    rebuild_index_and_state()
    if getattr(args, "card", False):  # the resume card alone: what compact-resume prints after a compaction
        print(resume_card())
        return
    state = read_json(WORKS / "state.json")
    # Nested install: name the host, and hold the first product commit until the operator has
    # confirmed the host's commit convention. Printed before every return below; silent at root.
    for line in nested_next_lines():
        print(line)
    if cloud_link_file().exists():  # cloud mode: hi2vi's revisions are the history, so no workflow-repo commit
        print(cloud_store_line())
        print(cloud_commits_waiting_line())  # the waiting-commit record git gives in local mode
    # Stream context. Both lines are silent on the default stream with no parallel
    # phases, so an untouched workspace sees exactly the output it saw before.
    stream = state.get("stream")
    if stream:
        print(f"stream={stream} (parallel phase checkout; the pointer below is scoped to this phase)")
    index = read_json(WORKS / "index.json")
    elsewhere = [
        f"{p['id']}:{p['execution'].get('branch')}"
        for p in index.get("active_phases", [])
        if phase_in_flight(p) and p["execution"].get("branch") != stream
    ]
    if elsewhere:
        print(f"parallel_phases_elsewhere={', '.join(elsewhere)} (not in this stream; each runs from its own branch)")
    ready = merge_ready_line(stream, index.get("active_phases", []))
    if ready:
        print(ready)
    try:  # P52: every done phase's open PR, before every return below; read from the record, never the network
        for line in pr_open_lines(index):
            print(line)
    except Exception as exc:  # noqa: BLE001 - the pointer must print whatever a phase's pr block holds
        print(f"pr_open=unreadable error={_one_line(str(exc)) or type(exc).__name__}")
    try:  # P52: a stacked PR whose lower PR merged, vanished or moved; local refs only, never the network
        for line in pr_stack_lines(index):
            print(line)
    except Exception as exc:  # noqa: BLE001 - the pointer must print whatever a phase's pr block holds
        print(f"pr_stack=unreadable error={_one_line(str(exc)) or type(exc).__name__}")
    waiting = state.get("waiting_on_operator")
    if waiting:
        kind = "slice" if "." in waiting else "phase"
        clear = f"slice status {waiting} in_progress" if kind == "slice" else f"phase status {waiting} in_progress"
        # An open acceptance gate is the same `pending` halt with a concrete script attached:
        # print the walkthrough, and clear through gate clear so cleared_at and the words get stamped.
        gate = None
        if kind == "phase" and (ACTIVE / waiting / "phase.json").exists():
            pdata = read_json(ACTIVE / waiting / "phase.json")
            if acceptance_gate_is_open(pdata):
                gate = phase_acceptance(pdata)
                clear = f"gate {waiting} clear --words \"<the operator's words>\""
        print(f"current_phase={state.get('current_phase')}")
        for line in explain_unit_lines(state.get("current_phase")):
            print(line)
        for line in _pr_next_lines(state.get("current_phase")):  # P51: silent for a phase without a pr block
            print(line)
        print(f"waiting_on_operator={waiting}")
        print(f"WAITING ON OPERATOR: {kind} {waiting} is pending [~] -- operator co-work needed (validation or an operator-run action).")
        if kind == "slice":
            try:
                record = read_json(require_slice(waiting) / "slice.json").get("pending")
            except (OSError, ValueError, SystemExit):
                record = None
            if isinstance(record, dict):
                print(f"stop_kind={record.get('kind')}")
                print(f"on_words={_one_line(record.get('on_words') or '')}")
            else:
                print("stop_kind=untyped (set it with --stop-kind/--on-words)")
        print("Do not start, finish, or advance past it. Report what you need, then wait for the operator.")
        for line in wave_lines(_active_phase(state.get("current_phase"))):  # P42: declared phases only
            print(line)
        if gate:
            print(f"acceptance_gate=open (requested_at={gate.get('requested_at')}) -- the operator must walk the running product before this phase's review can pass.")
            print("WALKTHROUGH:")
            print(gate.get("walkthrough") or "(none recorded)")
        for line in notebook_step_lines(waiting.split(".", 1)[0]):  # §6: a notebook write, not an advance
            print(line)
        print(f"After the operator approves, clear it: {WORKFLOW_CMD} {clear}")
        if gate:
            print("Add --note \"...\" to record what the operator reported.")
        return
    current_slice = state.get("current_slice")
    if not current_slice:
        if state.get("current_phase"):
            print(f"current_phase={state['current_phase']}")
            for line in explain_unit_lines(state["current_phase"]):
                print(line)
            for line in _pr_next_lines(state["current_phase"]):
                print(line)
            print("no open slice in the current phase; review/archive it or create a new phase")
        else:
            print("no active slice; create a phase or promote deferred work")
        return
    sdir = require_slice(current_slice)
    print(f"current_phase={current_slice.split('.', 1)[0]}")
    for line in explain_unit_lines(current_slice.split(".", 1)[0]):
        print(line)
    for line in _pr_next_lines(current_slice.split(".", 1)[0]):
        print(line)
    print(f"current_slice={current_slice}")
    print(f"slice_path={shown(sdir)}")
    print(f"next_slice={state.get('next_slice') or 'none'}")
    for line in wave_lines(_active_phase(state.get("current_phase"))):  # P42: declared phases only
        print(line)
    for line in notebook_step_lines(current_slice.split(".", 1)[0]):  # §6: silent under budget
        print(line)
    hint = parallel_start_hint(state, index)
    if hint:
        print(hint)
RESUME_CARD_FIELD = 160    # a free-text field (a span description, the operator's words) is cut to this


def _card_cut(text, limit: int = RESUME_CARD_FIELD) -> str:
    text = _one_line(text or "")
    return text if len(text) <= limit else text[: limit - 3].rstrip() + "..."


def full_slice_id(phase_id: str, raw: str) -> str:
    """`--slice` as stored: a bare suffix (`S1`, `F2`) is prefixed with its phase id (`P46-k2.S1`), so a
    slice of a phase the same command mints can be named before its id is known; a full id stays as is."""
    return f"{phase_id}.{raw}" if re.fullmatch(SLICE_SUFFIX_PATTERN, raw) else raw


ONE_LINE_USAGE_COMMANDS = set()  # filled by _one_line_usage_errors as main() registers each agenda parser


def _one_line_usage_errors(parser: argparse.ArgumentParser) -> None:
    """A usage error on this subcommand prints one line (`<prog> <command>: error: <message>`, exit 2), never
    the usage block: the agenda's refusals are each exactly one line, the web's "Change refused" text. Two
    paths raise one: an error inside the subparser (a missing argument, a bad value) calls this parser's
    `error`, replaced here; an unknown option or an extra positional is left over and raised by the top-level
    parser's `parse_args`, so the command is recorded in ONE_LINE_USAGE_COMMANDS and main() gives the
    top-level parser the same one-line `error` for a run of that command only."""
    ONE_LINE_USAGE_COMMANDS.add(parser.prog.rsplit(" ", 1)[-1])
    parser.error = lambda message: parser.exit(2, f"{parser.prog}: error: {message}\n")


def _phase_blocker_kinds(pdir: Path) -> list:
    """Reasons a phase is not cleanly archivable, typed: `[(kind, text)]`, kind one of "slices",
    "review" or "pr" (P52: a recorded PR not yet merged). Empty list means ready. `_phase_blockers` is this list's text.
    A retired `consolidation` field from an older install never holds a phase."""
    phase = read_json(pdir / "phase.json")
    slices = [read_json(s / "slice.json") for s in slice_dirs(pdir)]
    reasons = []
    not_done = [s["id"] for s in slices if s.get("status") != "done"]
    if not_done:
        reasons.append(("slices", f"unfinished slices: {', '.join(not_done)}"))
    review_status = phase.get("review", {}).get("status")
    if review_status != "pass":
        reasons.append(("review", f"review is {review_status!r}, not pass"))
    # A recorded, unwaived PR GitHub has not merged (as pr sync last read it): phase rotate's sweep leaves the
    # phase active (its pr_open= line stays in next); phase archive <P> archives it with advice.
    for entry in _pr_open_entries(phase):
        reasons.append(("pr", f"PR {_pr_label(entry)} is {entry.get('state') or 'unsynced'}, not merged (pr sync {phase['id']} reads it)"))
    return reasons


def _phase_blockers(pdir: Path) -> list:
    """Reasons a phase is not cleanly archivable; empty list means ready."""
    return [text for _, text in _phase_blocker_kinds(pdir)]


def _parallel_branch_merged(execution: dict, git_ok: bool = None) -> bool:
    """True when a parallel phase's branch is merged into HEAD. No branch, a deleted branch (merged
    and torn down) and a workspace without git all count as merged; otherwise the branch must be an
    ancestor of HEAD. The one test `worktree merge-finish` and `phase rotate` share."""
    git_ok = _git_available() if git_ok is None else git_ok
    branch = execution.get("branch")
    if git_ok and branch and _branch_exists(branch):
        return _git(["merge-base", "--is-ancestor", branch, "HEAD"], check=False).returncode == 0
    return True


def _archive_one(pdir: Path, forced: bool) -> Path:
    """Move a single phase folder to archived/, writing its manifest. No rebuild."""
    phase = read_json(pdir / "phase.json")
    phase_id = phase["id"]
    slices = [read_json(s / "slice.json") for s in slice_dirs(pdir)]
    review_status = phase.get("review", {}).get("status")
    base_name = f"{timestamp()}_{phase_id}_{slugify(phase.get('name', phase_id))}"
    archive_name = base_name
    suffix = 1
    while (ARCHIVED / archive_name).exists():
        suffix += 1
        archive_name = f"{base_name}_{suffix}"
    dest = ARCHIVED / archive_name
    manifest = {
        "phase_id": phase_id, "archived_at": now_iso(),
        "archive_reason": "forced" if forced else "phase_review_passed",
        "review_verdict": review_status,
        "source_path": str(pdir.relative_to(ROOT)), "archive_path": str(dest.relative_to(ROOT)),
        "slices": [s["id"] for s in slices],
    }
    write_json(pdir / "archive_manifest.json", manifest)
    shutil.move(str(pdir), str(dest))
    append_event("phase_archived", phase=phase_id, archive_path=str(dest.relative_to(ROOT)))
    return dest


def cmd_phase_archive(args: argparse.Namespace) -> None:
    """`phase archive <P>`: one review-passed phase. `--all`: every active phase, only once every one is done
    (`phase rotate` is the partial sweep). `--force` is for exceptional cleanup of an unfinished phase only."""
    if bool(args.all_phases) == bool(args.phase):
        raise SystemExit("phase archive: name one phase, or --all for every active phase")
    pdirs = phase_dirs() if args.all_phases else [require_phase(args.phase)]
    if not pdirs:
        print("no active phases to archive")
        return
    held = [(pdir, _phase_blocker_kinds(pdir)) for pdir in pdirs] if not args.force else []
    advice = [f"advice: {read_json(pdir / 'phase.json')['id']}: {text}; archived anyway, so next no longer lists it"
              for pdir, kinds in held for kind, text in kinds if kind == "pr"]
    blockers = [(pdir, [text for kind, text in kinds if kind != "pr"]) for pdir, kinds in held]
    blockers = [(pdir, reasons) for pdir, reasons in blockers if reasons]
    if blockers and not args.all_phases:
        raise SystemExit(f"phase {args.phase} is not archivable ({'; '.join(blockers[0][1])}). Finish/review it, or use --force for exceptional cleanup.")
    if blockers:
        print("not archiving: every active phase must be done (the last review slice complete) before a batch archive.")
        for pdir, reasons in blockers:
            print(f"- {read_json(pdir / 'phase.json')['id']}: {'; '.join(reasons)}")
        raise SystemExit("Finish the open phases first, or use --force for exceptional cleanup.")
    archived = [(read_json(pdir / "phase.json")["id"], _archive_one(pdir, forced=args.force)) for pdir in pdirs]
    rebuild_index_and_state()
    for line in advice:
        print(line)
    if not args.all_phases:
        print(f"archived phase {args.phase}: {shown(archived[0][1])}")
        return
    print(f"archived {len(archived)} phase(s):")
    for phase_id, dest in archived:
        print(f"- {phase_id}: {shown(dest)}")


def cmd_check(args: argparse.Namespace) -> None:
    """`check`: rebuild the generated files, then validate (exit 1 on an invalid record); `--no-rebuild`
    validates only. A malformed nested marker is never rebuilt on: check validates and lists it."""
    if not args.no_rebuild and not (NESTED is not None and NESTED_PROBLEMS):
        rebuild_index_and_state()
        print("rebuilt workflow")
    sys.exit(validate())


def _rotate_sweep() -> None:
    """The archive sweep: archive every phase that is cleanly archivable right now (every slice done,
    review `pass`, no unmerged PR) and leave the rest active, then rebuild. Whole phases, never
    forced, phase archive's manifest -- the partial sweep phase archive --all cannot do, since phase archive --all
    refuses unless EVERY active phase is done. Its output is `--archive-only`'s, verbatim."""
    pdirs = phase_dirs()
    if not pdirs:
        print("no active phases to rotate")
        return
    ready, blocked = [], []
    for pdir in pdirs:
        phase_id = read_json(pdir / "phase.json")["id"]
        (blocked if _phase_blockers(pdir) else ready).append((phase_id, pdir))
    if not ready:
        rebuild_index_and_state()
        print(f"no done phases to rotate; {len(blocked)} phase(s) still active: {', '.join(p for p, _ in blocked)}")
        return
    archived = []
    for phase_id, pdir in ready:
        dest = _archive_one(pdir, forced=False)
        archived.append((phase_id, dest))
    rebuild_index_and_state()
    print(f"rotated {len(archived)} done phase(s) to archived:")
    for phase_id, dest in archived:
        print(f"- {phase_id}: {shown(dest)}")
    if blocked:
        print(f"left {len(blocked)} phase(s) active: {', '.join(p for p, _ in blocked)}")


def rotate_backlog(args: argparse.Namespace) -> None:
    """The step of /rotate-backlog: `rotate=refused` on a parallel stream (writes nothing, exits non-zero),
    else `rotate=archive` and the sweep (`_rotate_sweep`). `--archive-only` is the sweep alone, with no
    rotate= line."""
    if getattr(args, "archive_only", False):
        _rotate_sweep()
        return
    stream = current_stream(all_active_phases())
    if stream is not None:
        print(f"rotate=refused stream={stream}")
        raise SystemExit("phase rotate wrote nothing: archiving runs on the default stream only -- run it from the main checkout, not this phase's worktree")
    print("rotate=archive")
    _rotate_sweep()
