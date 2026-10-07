# -*- coding: utf-8 -*-
# Line 1 must stay this PEP 263 cookie, spelled utf-8. wrapper.sh feeds this program to python3 on
# stdin, and without a declared encoding CPython 3.9 rejects the whole program ("Non-UTF-8 code ...
# but no encoding declared") whenever a multibyte character in one of the long embedded payload
# lines straddles its ~1 KB read-chunk boundary. The cookie turns that per-chunk check off (P27.F3).
from __future__ import annotations

import difflib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

if sys.version_info < (3, 8):
    sys.exit(f"Error: python3 >= 3.8 required, found {sys.version.split()[0]}")

TARGET = Path(os.environ["TARGET_DIR"]).expanduser()
PROJECT_NAME = os.environ["PROJECT_NAME"]
PROJECT_SUMMARY = os.environ["PROJECT_SUMMARY"]
FORCE_EMPTY_OK = os.environ.get("FORCE_EMPTY_OK") == "1"
# Retrofit: non-destructively add the workspace to an EXISTING repo. Gated
# strictly behind --into-existing; the fresh-install path is unchanged.
RETROFIT = os.environ.get("INTO_EXISTING") == "1"
INSTALL_DOCS = True  # recomputed in the guards for retrofit (skip if target already has docs/)
RETROFIT_SUMMARY = {"created": [], "skipped": [], "merged": []}
# Update: refresh an already-installed workspace's machinery to THIS version,
# preserving the downstream's own work (everything under works/ except templates)
# and all of docs/. Gated behind --update; mutually exclusive with --into-existing.
# --dry-run previews the change-list and writes nothing.
UPDATE = os.environ.get("UPDATE") == "1"
DRY_RUN = os.environ.get("DRY_RUN") == "1"
UPDATE_DOCS = True  # recomputed in the guards for update (skip docs rebuild if no docs subsystem)
UPDATE_SUMMARY = {"updated": [], "added": [], "merged": [], "preserved": [], "unchanged": [], "stale": []}
UPSTREAM_URL = "https://github.com/leetusik/bootstrap_agentic_workspace.sh"
# Integer workspace version. Bumped (with a matching CHANGELOG.md entry) whenever a
# machinery change ships to targets. Rides inside this built artifact, so adopting
# repos — which have no installer/ — still get it stamped into their marker below.
WORKSPACE_VERSION = 51
ROOT = TARGET.resolve()
# Nested personal install (P28; the default layout since P29): TARGET is a HOST git repo -- one the
# operator may not own, or a new/empty dir this run `git init`s. The engine and all workflow state go
# to the nested git repo <host>/workflow (ROOT, so every ROOT-relative write below lands there);
# skills and agents go to the host's .claude/ as untracked files, beside .claude/settings.local.json
# and CLAUDE.local.md, all hidden by the host's info/exclude. Nothing tracked in the host changes.
# Every nested branch is gated on NESTED, so the at-root installs (--at-root, --into-existing, and
# --update of an at-root workspace) are byte-for-byte unchanged. resolve_layout() decides NESTED.
NESTED_DIR = "workflow"
NESTED_MARKER = ".agentic-nested.json"   # == scripts/workflow.py NESTED_MARKER (the engine owns its schema)
EXPLICIT_NESTED = os.environ.get("NESTED") == "1"   # --nested: accepted, redundant (must match on --update)
AT_ROOT_FLAG = os.environ.get("AT_ROOT") == "1"     # --at-root: the committed, team-visible layout
# A fresh nested install into a new or empty, non-git target runs `git init` there (P29). Until the
# first write, a refusal undoes that init (_nested_undo_init); from the first write on it is kept.
HOST_INITED = False
_HOST_INIT_UNDO = None   # (the .git this run created, [dirs this run created, deepest first]) or None
# The commit convention recorded for a host this installer just `git init`ed: it has no history to
# infer from and is the operator's own repo, so it takes this workspace's own Commit Convention.
NESTED_INIT_CONVENTION = {"inferred": None, "confirmed": True,
                          "text": "type(scope): summary -- imperative, no trailing period",
                          "coauthor_trailers": "allowed"}


def _nested_undo_init() -> None:
    """Remove what this run's `git init` of a new or empty host created -- its .git, then each
    directory it created if it is empty again -- and nothing else. A no-op once writing started."""
    global _HOST_INIT_UNDO
    undo, _HOST_INIT_UNDO = _HOST_INIT_UNDO, None
    if not undo:
        return
    git_dir, created = undo
    shutil.rmtree(git_dir, ignore_errors=True)
    for d in created:
        try:
            d.rmdir()
        except OSError:
            pass


def _nested_refuse(*lines: str) -> None:
    _nested_undo_init()   # every pre-write refusal leaves an initialised host as it found it
    for i, line in enumerate(lines):
        print(("Error: " if i == 0 else "") + line, file=sys.stderr)
    sys.exit(1)


def _at_root_workspace_in(t: Path) -> bool:
    """An at-root agentic workspace lives at `t`: the engine plus works/ state (the --update guard's test)."""
    works_present = (t / "works/state.json").exists() or any((t / "works/phases/active").glob("*/phase.json"))
    return (t / "scripts/workflow.py").exists() and works_present


def resolve_layout() -> bool:
    """True for the nested layout (P29: the default), False for at-root. --into-existing and
    --at-root are at-root. --update detects the installed layout at the target: the nested marker
    (workflow/.agentic-nested.json) or an at-root workspace (scripts/workflow.py + works/); both is
    ambiguous unless a flag picks one, a flag that contradicts the one found refuses, and neither
    falls to at-root, whose "no agentic workspace found here" error then fires. Anything else -- a
    fresh install, with or without --nested -- is nested. Refuses (exit 1, nothing written)."""
    if RETROFIT:
        return False
    t = ROOT
    if os.path.lexists(t / NESTED_MARKER) and (UPDATE or not AT_ROOT_FLAG):
        # The target is a nested install's own workflow/: refreshing it at-root would write
        # CLAUDE.md and .claude/ into workflow/, and a fresh install would nest a second one inside.
        _nested_refuse(f"{t} is the {NESTED_DIR}/ directory of a nested install (it holds {NESTED_MARKER}): "
                       f"run the installer on the host repo's root, {t.parent}, instead (nothing written).")
    if not UPDATE:
        return not AT_ROOT_FLAG
    marker = t / NESTED_DIR / NESTED_MARKER
    nested_here, root_here = os.path.lexists(marker), _at_root_workspace_in(t)
    if nested_here and root_here:
        if EXPLICIT_NESTED or AT_ROOT_FLAG:
            return EXPLICIT_NESTED
        _nested_refuse(f"{t} holds both a nested install ({marker}) and an at-root workspace ({t / 'scripts/workflow.py'} "
                       "plus works/): the layout to update is ambiguous.",
                       "Re-run with --update --nested or --update --at-root to say which one to refresh (nothing written).")
    if nested_here:
        if AT_ROOT_FLAG:
            _nested_refuse(f"--at-root given, but {t} holds a nested install ({NESTED_DIR}/{NESTED_MARKER}); drop the flag.")
        return True
    if root_here and EXPLICIT_NESTED:
        _nested_refuse(f"--nested given, but {t} holds an at-root workspace (scripts/workflow.py plus works/); drop the flag.")
    return False


NESTED = resolve_layout()
HOST = None
if NESTED:
    HOST, ROOT = ROOT, ROOT / NESTED_DIR
NESTED_CONTRACT = "CLAUDE.workspace.md"  # never CLAUDE.md under workflow/: Claude Code would auto-load a second copy
NESTED_RENAME_PREFIX = "wf-"
NESTED_LOCAL_BEGIN, NESTED_LOCAL_END = "<!-- BEGIN agentic-workspace (nested) -->", "<!-- END agentic-workspace (nested) -->"
NESTED_EXCLUDE_BEGIN, NESTED_EXCLUDE_END = "# BEGIN agentic-workspace (nested)", "# END agentic-workspace (nested)"
# Each of our skill dirs also gets this as its own .gitignore (P28.F1): the deepest .gitignore wins,
# so it hides the dir's files (itself included) even where a host .gitignore re-includes
# .claude/skills/** -- which info/exclude, ranked below every .gitignore, cannot override.
NESTED_SKILL_GITIGNORE = "*\n"
SHOWN_PREFIX = f"{NESTED_DIR}/" if NESTED else ""   # change-list paths as typed from the host root

DOC_TYPES = ["product", "experience", "architecture", "frontend", "backend", "data", "api", "operations", "security", "qa", "decisions"]

# Common, harmless files a brand-new repo often already contains. Their presence
# does NOT count as "non-empty" for the safety guard (the GitHub "create repo
# with README" case should just work).
EMPTY_OK_ALLOWLIST = {
    ".git", ".github", ".gitignore", ".gitattributes", ".gitkeep",
    ".editorconfig", ".vscode", ".idea", ".DS_Store",
    "README.md", "README", "README.rst", "README.txt",
    "LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING", "NOTICE",
}

#@@GENERATED_PAYLOADS@@

# The skill inventory is derived independently from the embedded payload manifest.
# The build enforces the release invariant: 18 skill packages.
CLAUDE_SKILLS = sorted({k.split("/")[2] for k in PAYLOADS if k.startswith(".claude/skills/") and k.endswith("/SKILL.md")})
EXPECTED_SKILL_COUNT = 18
if len(CLAUDE_SKILLS) != EXPECTED_SKILL_COUNT:
    raise RuntimeError(
        f"embedded skill inventory must contain {EXPECTED_SKILL_COUNT} skill packages "
        f"(found {len(CLAUDE_SKILLS)})"
    )

MANAGED_DIRS = [
    "docs", "docs/current", "docs/versions",
    *[f"docs/versions/{doc_id}" for doc_id in DOC_TYPES],
    "works", "works/phases", "works/phases/active", "works/phases/archived",
    "works/deferred", "works/deferred/open", "works/deferred/promoted", "works/deferred/dropped",
    "works/templates", "scripts",
    ".claude", ".claude/skills", ".claude/agents",
]

MANAGED_FILES = [
    "CLAUDE.md",
    "docs/README.md", "docs/index.json",
    *[f"docs/current/{doc_id}.md" for doc_id in DOC_TYPES],
    *[f"docs/versions/{doc_id}/v0001_bootstrap.md" for doc_id in DOC_TYPES],
    "works/state.json", "works/index.json", "works/backlog.md", "works/deferred.md", "works/events.jsonl",
    *[f"works/templates/{n}" for n in ("deferred_brief.md", "intent.md", "phase.md")],
    "scripts/workflow.py",
    ".claude/agents/slice-executor-mid.md", ".claude/agents/slice-executor-high.md", ".claude/agents/design-drafter.md",
    ".claude/settings.json",
    "executors.toml",
]
for name in CLAUDE_SKILLS:
    MANAGED_DIRS.append(f".claude/skills/{name}")
    MANAGED_FILES.append(f".claude/skills/{name}/SKILL.md")
if NESTED:
    # Under workflow/ there is no .claude/ (its skills would load on demand as duplicates) and no
    # CLAUDE.md (the contract is CLAUDE.workspace.md); the host-side files are written separately.
    MANAGED_DIRS = [d for d in MANAGED_DIRS if not d.startswith(".claude")]
    MANAGED_FILES = [f for f in MANAGED_FILES if not f.startswith(".claude") and f != "CLAUDE.md"]



def now_iso() -> str:
    return datetime.now().astimezone().replace(microsecond=0).isoformat()


def slugify(value: str, fallback: str = "item") -> str:
    slug = re.sub(r"[^a-zA-Z0-9._-]+", "_", value.strip().lower()).strip("_")
    return slug or fallback


def _atomic_write(p, text: str, executable: bool = False) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    # Atomic write: temp file in the same dir, then replace.
    fd, tmp = tempfile.mkstemp(dir=str(p.parent), prefix=".tmp_", suffix=p.name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        if executable:
            mode = os.stat(tmp).st_mode
            os.chmod(tmp, mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        os.replace(tmp, str(p))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


# ---- Repo-level policy files (CI workflow, .gitattributes) ------------------
# Neither file is machinery that may be overwritten: a target repo may already have
# its own CI or its own attribute rules, and both are legal fresh-install
# destinations (.github and .gitattributes are in EMPTY_OK_ALLOWLIST). So both ship
# through one policy, applied identically on fresh install, retrofit and --update
# (they are emitted by emit_policy_files() below, not through write_text):
#   .github/workflows/workspace-ci.yml -- SEED-ONCE: created when absent, never
#     overwritten (executors.toml precedent; adopters customize their own CI).
#   .gitattributes -- LINE-MERGE: the `works/events.jsonl merge=union` rule is
#     appended when missing and existing content is left untouched. Skipping the
#     file outright (the plain retrofit policy) would silently drop the union rule
#     on any repo that already has a .gitattributes, which is exactly where a
#     phase-branch merge would then conflict.
CI_WORKFLOW_PATH = ".github/workflows/workspace-ci.yml"
GITATTRIBUTES_PATH = ".gitattributes"
GITATTRIBUTES_MERGE_LINE = "works/events.jsonl merge=union"
GITATTRIBUTES_APPEND_NOTE = (
    "\n# Added by the agentic workspace: works/events.jsonl is an append-only log, so\n"
    "# both sides of a merge are always wanted (`union` is a built-in git merge driver\n"
    "# and needs no per-clone config). The generated files (works/state.json,\n"
    "# works/index.json, works/backlog.md, works/deferred.md, docs/current/*.md) get no\n"
    "# merge driver on purpose -- resolve a conflict there by taking either side and\n"
    "# re-running: python3 scripts/workflow.py parallel-merge-finish\n"
)


def _gitattributes_action() -> str:
    """What applying our merge rules would do: 'create' | 'merge' | 'unchanged'."""
    p = ROOT / GITATTRIBUTES_PATH
    if not p.is_file():
        return "create"
    try:
        existing = p.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return "unchanged"  # unreadable/binary -- never touch it
    if any(ln.strip() == GITATTRIBUTES_MERGE_LINE for ln in existing.splitlines()):
        return "unchanged"
    return "merge"


def _apply_gitattributes(text: str, action: str) -> None:
    p = ROOT / GITATTRIBUTES_PATH
    if action == "create":
        _atomic_write(p, text)
        return
    existing = p.read_text(encoding="utf-8")
    sep = "" if (not existing or existing.endswith("\n")) else "\n"
    _atomic_write(p, existing + sep + GITATTRIBUTES_APPEND_NOTE + GITATTRIBUTES_MERGE_LINE + "\n")


def emit_policy_files() -> None:
    """Emit the CI workflow (seed-once) and .gitattributes (line-merge) under every
    install mode, recording the outcome in whichever summary the mode reports."""
    ci_exists = (ROOT / CI_WORKFLOW_PATH).exists()
    ga_action = _gitattributes_action()
    if not DRY_RUN:
        if not ci_exists:
            _atomic_write(ROOT / CI_WORKFLOW_PATH, PAYLOADS[CI_WORKFLOW_PATH])
        if ga_action != "unchanged":
            _apply_gitattributes(PAYLOADS[GITATTRIBUTES_PATH], ga_action)
    if UPDATE:
        UPDATE_SUMMARY["preserved" if ci_exists else "added"].append(CI_WORKFLOW_PATH)
        UPDATE_SUMMARY[{"create": "added", "merge": "merged", "unchanged": "unchanged"}[ga_action]].append(GITATTRIBUTES_PATH)
    elif RETROFIT:
        RETROFIT_SUMMARY["skipped" if ci_exists else "created"].append(CI_WORKFLOW_PATH)
        RETROFIT_SUMMARY[{"create": "created", "merge": "merged", "unchanged": "skipped"}[ga_action]].append(GITATTRIBUTES_PATH)


# ---- Retrofit (--into-existing) write policy --------------------------------
# In retrofit mode the workspace is added non-destructively: an existing file is
# never overwritten. A small, known set is additively, idempotently merged.
def _merge_settings_json(text: str) -> None:
    """Union our permission entries into an existing .claude/settings.json,
    preserving every key the target already has. Idempotent."""
    p = ROOT / ".claude/settings.json"
    ours = json.loads(text)
    try:
        theirs = json.loads(p.read_text(encoding="utf-8"))
        if not isinstance(theirs, dict):
            raise ValueError("settings.json is not a JSON object")
    except Exception:
        # Never clobber an unparseable file — drop a sidecar instead.
        _atomic_write(ROOT / ".claude/settings.workspace.json", text)
        RETROFIT_SUMMARY["skipped"].append(".claude/settings.json (unparseable; wrote .claude/settings.workspace.json)")
        return
    perms = theirs.setdefault("permissions", {})
    for key in ("allow", "deny"):
        current = perms.get(key) or []
        additions = (ours.get("permissions") or {}).get(key) or []
        perms[key] = list(current) + [x for x in additions if x not in current]
    _atomic_write(p, json.dumps(theirs, ensure_ascii=False, indent=2) + "\n")
    RETROFIT_SUMMARY["merged"].append(".claude/settings.json")


def _merge_contract(path: str, full_text: str) -> None:
    """Keep the target's existing CLAUDE.md; write the full workspace contract to a
    *.workspace.md sidecar and append a marked, idempotent pointer block
    (re-running replaces just the marked block, never duplicates)."""
    p = ROOT / path
    sidecar = path[:-3] + ".workspace.md"  # CLAUDE.md -> CLAUDE.workspace.md
    _atomic_write(ROOT / sidecar, full_text)
    begin, end = "<!-- BEGIN agentic-workspace -->", "<!-- END agentic-workspace -->"
    block = (
        f"{begin}\n"
        f"> This repo uses the agentic workspace (`scripts/workflow.py` + skills under `.claude/`).\n"
        f"> Full operating contract: [`{sidecar}`]({sidecar}) — reconcile it with this file's own rules as needed.\n"
        f"{end}"
    )
    existing = p.read_text(encoding="utf-8")
    if begin in existing and end in existing:
        i = existing.index(begin)
        j = existing.index(end) + len(end)
        new = existing[:i] + block + existing[j:]
    else:
        sep = "" if existing.endswith("\n") else "\n"
        new = existing + sep + "\n" + block + "\n"
    _atomic_write(p, new)
    RETROFIT_SUMMARY["merged"].append(path)
    RETROFIT_SUMMARY["created"].append(sidecar)


def _retrofit_handle(path: str, text: str) -> bool:
    """Return True if retrofit policy fully handled this write (kept theirs or
    merged); False to proceed with a normal create."""
    if not (ROOT / path).exists():
        return False  # absent -> create normally
    if path == ".claude/settings.json":
        _merge_settings_json(text)
        return True
    if path == "CLAUDE.md":
        _merge_contract(path, text)
        return True
    RETROFIT_SUMMARY["skipped"].append(path)  # keep theirs
    return True


# ---- Update (--update) write policy -----------------------------------------
# Refresh machinery in place while preserving the downstream's own work and docs:
#   OVERWRITE (machinery, upstream-owned): scripts/workflow.py, the .claude
#     subagents, every skill, works/templates/*.
#   MERGE (additive): .claude/settings.json.
#   CONTRACT (sidecar-aware): CLAUDE.md.
#   SEED-ONCE: executors.toml (operator tier config — created if absent, never
#     overwritten).
#   PRESERVE (never touch): everything under works/ except templates, and all of
#     docs/ (the append-only version chain plus generated snapshots).
# The repo-level policy files (.github/workflows/workspace-ci.yml seed-once,
# .gitattributes line-merged) bypass this dispatch entirely — see emit_policy_files().
# In --dry-run nothing is written; changes are only recorded for the report.
def _is_machinery(path: str) -> bool:
    if path == "scripts/workflow.py":
        return True
    if NESTED and path == NESTED_CONTRACT:
        return True  # the nested install's contract (rewritten) is machinery, refreshed like the skills
    return path.startswith((".claude/agents/", ".claude/skills/", "works/templates/"))


def _difflines(old: str, new: str):
    """(added, removed) line counts between two texts, via difflib opcodes."""
    a, b = old.splitlines(), new.splitlines()
    added = removed = 0
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b).get_opcodes():
        if tag in ("replace", "delete"):
            removed += i2 - i1
        if tag in ("replace", "insert"):
            added += j2 - j1
    return added, removed


def _record_change(path: str, text: str) -> bool:
    """Record whether `text` changes the file at `path`; return True if it does."""
    target = ROOT / path
    if target.is_file():
        old = target.read_text(encoding="utf-8")
        if old == text:
            UPDATE_SUMMARY["unchanged"].append(path)
            return False
        added, removed = _difflines(old, text)
        UPDATE_SUMMARY["updated"].append((path, added, removed))
        return True
    UPDATE_SUMMARY["added"].append(path)
    return True


def _update_write(path: str, text: str, executable: bool) -> None:
    if _record_change(path, text) and not DRY_RUN:
        _atomic_write(ROOT / path, text, executable)


def _update_handle(path: str, text: str, executable: bool) -> None:
    # Preserve all downstream work and docs.
    if path.startswith("works/") and not path.startswith("works/templates/"):
        UPDATE_SUMMARY["preserved"].append(path)
        return
    if path.startswith("docs/") and path != "docs/README.md":
        UPDATE_SUMMARY["preserved"].append(path)
        return
    if path == "docs/README.md":
        # Machinery doc, but only refresh where the docs subsystem exists.
        if UPDATE_DOCS:
            _update_write(path, text, executable)
        else:
            UPDATE_SUMMARY["preserved"].append(path)
        return
    # Additive merge: never clobber the operator's settings.
    if path == ".claude/settings.json":
        if (ROOT / path).exists():
            UPDATE_SUMMARY["merged"].append(path)
            if not DRY_RUN:
                _merge_settings_json(text)
        else:
            _update_write(path, text, executable)
        return
    # Contract: a retrofitted repo keeps its own CLAUDE.md and we refresh the
    # workspace sidecar; a fresh-installed repo's contract IS machinery, so
    # overwrite it in place (operator previews via --dry-run).
    if path == "CLAUDE.md":
        sidecar = path[:-3] + ".workspace.md"
        if (ROOT / sidecar).exists():
            _record_change(sidecar, text)
            if not DRY_RUN:
                _merge_contract(path, text)
        else:
            _update_write(path, text, executable)
        return
    # Seed-once: executors.toml is the operator's tier config — create it when
    # absent (a pre-v9 workspace) and never overwrite an existing one.
    if path == "executors.toml":
        if (ROOT / path).exists():
            UPDATE_SUMMARY["preserved"].append(path)
        else:
            _update_write(path, text, executable)
        return
    if _is_machinery(path):
        _update_write(path, text, executable)
        return
    # Any other managed file is content/state — preserve.
    UPDATE_SUMMARY["preserved"].append(path)


def write_text(path, text: str, executable: bool = False) -> None:
    if UPDATE:
        _update_handle(path, text, executable)
        return
    if RETROFIT:
        if not INSTALL_DOCS and (path == "docs" or path.startswith("docs/")):
            return  # target already has a docs/ system — don't scaffold ours
        if _retrofit_handle(path, text):
            return
    _atomic_write(ROOT / path, text, executable)
    if RETROFIT:
        RETROFIT_SUMMARY["created"].append(path)


def write_json(path, data) -> None:
    write_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


# ---- Nested personal install (the default layout): rewrite, clash map, host-side plan ---------
# Everything here runs only when NESTED. The host-side files (skills, agents, settings.local.json,
# CLAUDE.local.md, the info/exclude block) and the rewritten engine-side texts (the contract as
# workflow/CLAUDE.workspace.md, works/templates/*) are rendered IN MEMORY by nested_plan() and
# post-checked before anything is written; nested_apply() writes them after the engine side.
# Before any write, nested_plan() also asks git whether every host-side target WILL be ignored
# (a host .gitignore negation outranks info/exclude); after the writes, nested_verify_clean()
# asserts the host's git status lists none of them.
NESTED_AGENTS = ["slice-executor-mid", "slice-executor-high", "design-drafter"]
NESTED_KINDS = ("skills", "agents")
# The engine's subcommands, read from the embedded engine: a hyphenated skill name that is not one
# of them only ever names the skill, so its plain backticked form is renamed too.
_ENGINE_SUBCOMMANDS = set(re.findall(r'add_parser\(\s*"([a-z][a-z0-9-]*)"', PAYLOADS["scripts/workflow.py"]))
NESTED_SKILL_ONLY = {n for n in CLAUDE_SKILLS if "-" in n and n not in _ENGINE_SUBCOMMANDS}
# Token-bounded: never preceded by a word character, `.`, `/` or `-`, so `workflow/works/`, a URL,
# `<repo>/scripts/...` and words such as `networks/` are left alone (and a second pass is a no-op).
NESTED_ENGINE_RE = re.compile(r"(?<![\w./-])scripts/workflow\.py(?![\w-])")
NESTED_PATH_RE = re.compile(
    r"(?<![\w./-])(?:works/|docs/(?:current|versions|reference)(?![\w-])|docs/index\.json(?![\w-]|\.\w)"
    r"|docs/README\.md(?![\w-]|\.\w)|executors\.toml(?![\w-]|\.\w)|\.env(?![\w-]|\.\w))")
# The contract named as `CLAUDE.md`: after "read"/"see", inside "contract (" / "contract — ", or as a
# bare list item. Every other `CLAUDE.md` stays: in a host repo that is the team's own contract (the
# executors' "repo-specific safety rule" pointer) or the retrofit/update texts about that file.
NESTED_CONTRACT_REF_RE = re.compile(
    r"(?:(?<=\bread )|(?<=\bRead )|(?<=\bsee )|(?<=\bSee )|(?<=contract \()|(?<=contract — )|(?<=^- ))`CLAUDE\.md`", re.M)
# A `workflow.py ...` command, up to its closing backtick or the end of the line: renames never touch it.
NESTED_PROTECT_RE = re.compile(r"(workflow\.py[^`\n]*)")


def nested_rewrite(text: str, renames: dict) -> str:
    """Rewrite one SOURCE payload text for a nested install. Applied to the upstream payload only,
    never to an installed copy, so a rerun or --update cannot double-prefix (and a second pass would
    change nothing anyway: every prefixed token is preceded by `/`).

    1. Engine paths: `scripts/workflow.py` -> `workflow/scripts/workflow.py` -- so `python3
       scripts/workflow.py`, the skills' allowed-tools and the settings allowlist too.
    2. Workspace paths -> under `workflow/`: works/, docs/current, docs/versions, docs/reference,
       docs/index.json, docs/README.md, executors.toml, .env.
    3. The contract named as `CLAUDE.md` (NESTED_CONTRACT_REF_RE) -> `workflow/CLAUDE.workspace.md`.
    4. Renames (`renames` = {"skills": {X: Y}, "agents": {X: Y}}), never inside a `workflow.py ...`
       command: a skill in `/X`, `.claude/skills/X/`, "`X` skill" (bold too), its own `name:`
       frontmatter and -- a hyphenated skill-only name -- `X` in backticks; an agent wherever its
       (always hyphenated, never a subcommand) name appears as a token: `name:`, `subagent_type: X`,
       `.claude/agents/X.md`, prose."""
    text = NESTED_ENGINE_RE.sub(f"{NESTED_DIR}/scripts/workflow.py", text)
    text = NESTED_PATH_RE.sub(lambda m: f"{NESTED_DIR}/{m.group(0)}", text)
    text = NESTED_CONTRACT_REF_RE.sub(f"`{NESTED_DIR}/{NESTED_CONTRACT}`", text)
    skills, agents = renames.get("skills") or {}, renames.get("agents") or {}
    if not (skills or agents):
        return text
    parts = NESTED_PROTECT_RE.split(text)  # odd indices are the protected workflow.py commands
    for i in range(0, len(parts), 2):
        part = parts[i]
        for x, y in skills.items():
            e = re.escape(x)
            part = re.sub(r"(?<![\w./-])/" + e + r"(?![\w-])", f"/{y}", part)
            part = re.sub(r"(?<![\w-])\.claude/skills/" + e + r"(?=/)", f".claude/skills/{y}", part)
            bare = r"`" + e + r"`" if x in NESTED_SKILL_ONLY else r"`" + e + r"`(?=\**\s+skill\b)"
            part = re.sub(bare, f"`{y}`", part)
        for x, y in agents.items():
            part = re.sub(r"(?<![\w-])" + re.escape(x) + r"(?![\w-])", y, part)
        parts[i] = part
    text = "".join(parts)
    if skills and text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end > 0:
            head = re.sub(r"(?m)^name: (\S+)$", lambda m: "name: " + skills.get(m.group(1), m.group(1)), text[:end])
            text = head + text[end:]
    return text


def _host_git(*args: str):
    """(returncode, stdout) of git run in the host repo -- read-only queries only."""
    proc = subprocess.run(["git", "-C", str(HOST), *args], capture_output=True)
    return proc.returncode, proc.stdout.decode("utf-8", errors="replace")


def _work_tree_top(path: Path):
    """The root of the git work tree `path` is inside, or None when it is in none."""
    proc = subprocess.run(["git", "-C", str(path), "rev-parse", "--is-inside-work-tree", "--show-toplevel"], capture_output=True)
    lines = proc.stdout.decode("utf-8", errors="replace").splitlines()
    if proc.returncode != 0 or len(lines) < 2 or lines[0].strip() != "true" or not lines[1].strip():
        return None
    return Path(lines[1].strip()).resolve()


def _host_empty_or_absent() -> bool:
    """HOST is absent, or a directory with no entry outside EMPTY_OK_ALLOWLIST and no .git."""
    if not os.path.lexists(HOST):
        return True
    return (HOST.is_dir() and not os.path.lexists(HOST / ".git")
            and not any(e.name not in EMPTY_OK_ALLOWLIST for e in HOST.iterdir()))


def _nested_refuse_inside(top) -> None:
    """HOST sits below the root of the work tree `top`: today's refusal, naming --at-root too."""
    _nested_refuse(f"the nested install goes at a git repo's root, and {HOST} is inside the work tree of {top}: "
                   f"re-run with {top} as TARGET_DIR, or install the committed at-root layout with --at-root.",
                   *([f"To make {HOST} a repo of its own instead, run git init there first (then re-run)."] if _host_empty_or_absent() else []))


def nested_init_host() -> None:
    """A fresh nested install into a target that is absent, or a directory that is empty in the
    EMPTY_OK_ALLOWLIST sense and in no git work tree: `mkdir -p` + `git init -q` it as the host
    (P29), recording what to undo should a refusal come before the first write. Any other target
    is left to nested_preflight's checks; an absent one inside a work tree refuses as a directory
    there would."""
    global HOST_INITED, _HOST_INIT_UNDO
    created = []
    if os.path.lexists(HOST):
        if not _host_empty_or_absent() or _work_tree_top(HOST) is not None:
            return
    else:
        anc = HOST
        while not os.path.lexists(anc):
            created.append(anc)   # deepest first: the undo order
            anc = anc.parent
        if not anc.is_dir():
            _nested_refuse(f"cannot create {HOST}: {anc} exists and is not a directory.")
        top = _work_tree_top(anc)
        if top is not None:
            _nested_refuse_inside(top)
    try:
        HOST.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        _nested_refuse(f"cannot create {HOST} ({exc}); nothing written.")
    _HOST_INIT_UNDO = (HOST / ".git", created)
    HOST_INITED = True
    proc = subprocess.run(["git", "init", "-q", str(HOST)], capture_output=True)
    if proc.returncode != 0:
        _nested_refuse(f"git init in {HOST} failed (exit {proc.returncode}: {proc.stderr.decode('utf-8', 'replace').strip()}); nothing written.")


def nested_preflight() -> None:
    """Refuse (exit 1, nothing written) unless HOST is the root of a git work tree whose workflow/ is
    ours to use -- a fresh install first `git init`s a new or empty host (nested_init_host) -- and,
    on a fresh install, unless the target holds no at-root workspace already. A fresh install over an
    existing nested install is an idempotent exit 0."""
    if not UPDATE and _at_root_workspace_in(HOST):
        _nested_refuse(f"{HOST} already holds an at-root agentic workspace: use --update to refresh it "
                       "(a fresh install would put a second, nested one beside it).")
    if shutil.which("git") is None:
        _nested_refuse("the default (nested) install needs git on PATH (the host is a git repo, and workflow/ becomes a nested one): "
                       + ("install git, then re-run." if UPDATE else "install git, or use --at-root."))
    if os.path.lexists(HOST) and not HOST.is_dir():
        _nested_refuse(f"{TARGET} exists and is not a directory.")
    if not UPDATE:
        nested_init_host()
    top = _work_tree_top(HOST)
    if top is None:
        if UPDATE:
            _nested_refuse(f"a nested install's host must be the root of a git work tree, and {HOST} is not inside one (nothing written).")
        if os.path.lexists(HOST / ".git"):
            _nested_refuse(f"{HOST}/.git exists, but git does not read {HOST} as a work tree: repair the repo (then re-run), "
                           "or install the committed at-root layout with --at-root")
        _nested_refuse(f"{HOST} is not a git repo and is not empty: run git init there first (then re-run), "
                       "or install the committed at-root layout with --at-root")
    if top != HOST:
        if UPDATE:
            _nested_refuse(f"a nested install's host must be the root of a git work tree, and {HOST} is inside the work tree of {top} (nothing written).")
        _nested_refuse_inside(top)
    rc, out = _host_git("ls-files", "--", NESTED_DIR)
    if out.strip():
        _nested_refuse(f"the host repo tracks a path named {NESTED_DIR}: a nested install needs <host>/{NESTED_DIR}/ for itself (nothing written).")
    if UPDATE:
        if not ((ROOT / NESTED_MARKER).is_file() and (ROOT / "scripts/workflow.py").is_file()):
            _nested_refuse(f"the nested install here is incomplete (an update needs {NESTED_DIR}/{NESTED_MARKER} and {NESTED_DIR}/scripts/workflow.py).",
                           f"Restore them from the nested repo's own history (git -C {NESTED_DIR} status), then re-run (nothing written).")
        return
    if os.path.lexists(ROOT / NESTED_MARKER):
        print(f"This host already has a nested agentic workspace ({NESTED_DIR}/{NESTED_MARKER}): already installed -- use --update to refresh it.")
        sys.exit(0)
    if os.path.lexists(ROOT) and not ROOT.is_dir():
        _nested_refuse(f"<host>/{NESTED_DIR} exists and is not a directory; a nested install needs it absent or empty.")
    if ROOT.is_dir():
        extra = sorted(e.name for e in ROOT.iterdir() if e.name != ".git")
        if extra:
            _nested_refuse(f"<host>/{NESTED_DIR}/ is not empty ({', '.join(extra[:5])}{', ...' if len(extra) > 5 else ''}); "
                           "a nested install needs it absent or empty (an existing .git is fine).")


def _frontmatter_name(path: Path):
    """The `name:` in a markdown file's leading frontmatter, or None."""
    try:
        head = path.read_text(encoding="utf-8", errors="replace")[:4096]
    except OSError:
        return None
    if not head.startswith("---"):
        return None
    end = head.find("\n---", 3)
    m = re.search(r"(?m)^name:[ \t]*['\"]?([^'\"\n]*?)['\"]?[ \t]*$", head[:end] if end > 0 else head)
    return (m.group(1).strip() or None) if m else None


def _host_taken(kind: str, ours: set) -> dict:
    """{name: where} for every name the HOST's own skills or agents use -- the directory or file
    name and the `name:` frontmatter (Claude Code keys on `name:`) -- skipping the workspace's own
    installed copies (`ours`). For skills, `.claude/commands/` counts too: a skill of the same
    name would shadow the team's command."""
    taken = {}
    base = HOST / ".claude" / kind
    for entry in (sorted(base.iterdir()) if base.is_dir() else []):
        stem = entry.name[:-3] if kind == "agents" and entry.name.endswith(".md") else entry.name
        if stem in ours:
            continue
        names = [stem]
        frontmatter = entry / "SKILL.md" if kind == "skills" else entry
        if frontmatter.is_file():
            names.append(_frontmatter_name(frontmatter))
        for name in names:
            if name:
                taken.setdefault(name, f".claude/{kind}/{entry.name}")
    commands = HOST / ".claude" / "commands"
    if kind == "skills" and commands.is_dir():
        for f in sorted(commands.rglob("*.md")):
            taken.setdefault(f.stem, f.relative_to(HOST).as_posix())
    return taken


def nested_infer_convention():
    """The host's commit convention, inferred non-interactively from its recent history and any
    CONTRIBUTING file -- one line for the operator to confirm (`nested-convention --confirm`), or
    None when the host has neither."""
    rc, out = _host_git("log", "-n", "50", "--no-merges", "--format=%s")
    subjects = [s.strip() for s in out.splitlines() if s.strip()] if rc == 0 else []
    rc, bodies = _host_git("log", "-n", "50", "--no-merges", "--format=%B%x00")
    trailers = sum(1 for b in bodies.split("\x00") if re.search(r"(?im)^co-authored-by:", b)) if rc == 0 else 0
    mentions = []
    for f in sorted(HOST.glob("CONTRIBUTING*")) + sorted((HOST / ".github").glob("CONTRIBUTING*")):
        try:
            head = f.read_bytes()[:4096].decode("utf-8", errors="replace") if f.is_file() else ""
        except OSError:
            continue
        for line in head.splitlines():
            s = re.sub(r"^[\s>*#-]+", "", line).strip()
            if s and "commit" in s.lower() and s[:140] not in mentions:
                mentions.append(s[:140])
    mentions = mentions[:3]

    def eg(s: str) -> str:
        return s if len(s) <= 72 else s[:69] + "..."

    n, parts = len(subjects), []
    if n:
        cc = [s for s in subjects if re.match(r"\w+(\([^)]*\))?!?: ", s)]
        ticket = [s for s in subjects if re.match(r"\[?[A-Z][A-Z0-9]+-\d+", s)]
        if len(cc) >= 0.6 * n:
            parts.append(f'Conventional Commits "type(scope): summary" ({len(cc)}/{n} recent subjects, e.g. "{eg(cc[0])}")')
        elif len(ticket) >= 0.6 * n:
            parts.append(f'ticket-prefixed "ABC-123 summary" ({len(ticket)}/{n} recent subjects, e.g. "{eg(ticket[0])}")')
        else:
            parts.append(f'free-form subjects, no dominant pattern ({n} recent, e.g. "{eg(subjects[0])}")')
    elif mentions:
        parts.append("no commits yet")
    else:
        return None
    if mentions:
        parts.append("CONTRIBUTING mentions: " + " / ".join(mentions))
    if n:
        parts.append(f"Co-Authored-By trailers in {trailers}/{n} recent commits")
    return "; ".join(parts)


def _nested_unignored(check_paths: list, exclude_entries: list) -> list:
    """[(target, reason)] for each host path in `check_paths` that git would NOT ignore once our
    exclude block is in place -- decided before any write (P28.F1). The block goes into a temporary
    core.excludesFile, which ranks below the host's .gitignore files and its current info/exclude,
    and matches every target: so the answer is "ignored" unless a .gitignore (or an operator line
    already in info/exclude) decides otherwise, which is exactly what can override the block once
    it is in info/exclude (it has no negations). The one approximation errs safe: an operator's own
    info/exclude negation of a target refuses even where our block would come after it. A target
    that does not exist yet is matched as a file, so `workflow/` is checked as a directory that
    must exist: it is created empty for the check and removed again if it was absent. Refuses
    (exit 1, nothing written) when the check itself cannot run."""
    fd, tmp = tempfile.mkstemp(prefix="agentic-nested-", suffix=".exclude")
    made_root = False
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write("\n".join(exclude_entries) + "\n")
        if NESTED_DIR in check_paths and not os.path.lexists(ROOT):
            ROOT.mkdir()
            made_root = True
        proc = subprocess.run(["git", "-C", str(HOST), "-c", f"core.excludesFile={tmp}", "check-ignore", "-v", "-z",
                               "--no-index", "--non-matching", "--stdin"],
                              input="".join(p + "\0" for p in check_paths).encode("utf-8"), capture_output=True)
    finally:
        if made_root:
            try:
                ROOT.rmdir()
            except OSError:
                pass
        os.unlink(tmp)
    if proc.returncode not in (0, 1):
        _nested_refuse("cannot check that the host's git will ignore the install's files "
                       f"(git check-ignore exit {proc.returncode}: {proc.stderr.decode('utf-8', 'replace').strip()}); nothing written.")
    fields = proc.stdout.decode("utf-8", errors="replace").split("\0")
    decided = {fields[i + 3]: fields[i:i + 3] for i in range(0, len(fields) - 3, 4)}
    unignored = []
    for path in check_paths:
        shown = f"{path}/" if path == NESTED_DIR else path
        source, line, pattern = decided.get(path, ["", "", ""])
        if path not in decided:
            unignored.append((shown, "git check-ignore gave no answer for it"))
        elif not pattern:
            unignored.append((shown, "no ignore pattern matches it"))
        elif pattern.startswith("!"):
            unignored.append((shown, f"re-included by {source}:{line}:{pattern}"))
    return unignored


def nested_verify_clean(plan: dict) -> None:
    """After every write (P28.F1, belt and braces behind the preflight): the host's git status lists
    none of the install's paths, or the install exits 1 naming them."""
    # GIT_OPTIONAL_LOCKS=0: status must not refresh the host's index (an env var, so an older git ignores it).
    proc = subprocess.run(["git", "-C", str(HOST), "--literal-pathspecs", "status", "--porcelain", "--untracked-files=all",
                           "--", *plan["status_paths"]], capture_output=True, env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    rc, out = proc.returncode, proc.stdout.decode("utf-8", errors="replace")
    if rc == 0 and not out.strip():
        plan["verified_clean"] = True
        return
    _nested_refuse("the nested install is written, but the host's git can see these paths, so `git add` could stage them:",
                   *([f"  {ln}" for ln in out.splitlines()[:20] if ln.strip()] or [f"  (git status failed with exit {rc})"]),
                   "Next: stage nothing in the host. `git check-ignore -v --no-index <path>` names the rule that re-includes each "
                   "path; move the listed paths out of the repo before your next `git add`, and report this.")


def _with_block(existing: str, begin: str, end: str, block: list) -> str:
    """`existing` with exactly one managed block (the `begin` ... `end` lines): earlier copies
    removed, the new one in the first copy's place, else appended after the operator's own text,
    which is kept. A stray or unterminated marker is an error (ValueError), never a guess."""
    lines, out, first, i = existing.splitlines(), [], None, 0
    while i < len(lines):
        if lines[i].strip() == begin:
            j = next((k for k in range(i + 1, len(lines)) if lines[k].strip() == end), None)
            if j is None:
                raise ValueError(f"an unterminated {begin!r} line")
            first = len(out) if first is None else first
            i = j + 1
            continue
        if lines[i].strip() == end:
            raise ValueError(f"a stray {end!r} line")
        out.append(lines[i])
        i += 1
    if first is None:
        out = out + ([""] if out and out[-1].strip() else []) + block
    else:
        out = out[:first] + block + out[first:]
    return "\n".join(out) + "\n"


def _nested_local_block(renames: dict) -> list:
    """The managed CLAUDE.local.md block: what this is, the contract import (on its own line,
    outside any code span or fence, or Claude Code will not expand it) and the nested rules."""
    cmd = f"python3 {NESTED_DIR}/scripts/workflow.py"
    lines = [
        NESTED_LOCAL_BEGIN,
        f"This is a private install of the agentic workspace. It is never committed to this repo and the team cannot see it: `{NESTED_DIR}/` (its own git repo), this file and the workspace's own `.claude/` files are hidden by this clone's `.git/info/exclude`.",
        "",
        f"@{NESTED_DIR}/{NESTED_CONTRACT}",
        "",
        "Nested-install rules (they win over the contract above where the two differ):",
        f"- Start Claude Code at this repo's root, never inside `{NESTED_DIR}/`. Run the engine from here: `{cmd} <command>`.",
        "- Two commits per slice, in two repos:",
        f"  - product code goes to this repo, on the operator's ticket branch, in the host's commit convention, which `{cmd} nested-convention` prints. Add Claude `Co-Authored-By` trailers only when it says `allowed`;",
        f"  - workflow state goes to the nested repo (`git -C {NESTED_DIR} ...`) in the contract's Commit Convention.",
        f"- If `next` shows `host_commit_convention=UNCONFIRMED`, confirm the convention with the operator before the first product commit, then record it: `{cmd} nested-convention --confirm --text \"<convention>\" --trailers allowed|forbidden`.",
        "- No parallel worktrees: the `parallel-*` commands refuse in a nested install.",
        f"- A pull request's title, body and commits (and every product commit) carry no phase or slice IDs, no `{NESTED_DIR}/` paths and no workspace files.",
        f"- Never stage `{NESTED_DIR}/`, `CLAUDE.local.md`, `.claude/settings.local.json` or the workspace's skills and agents into this repo (the exclude block lists them).",
    ]
    pairs = [f"skill `{x}` is `/{y}`" for x, y in sorted((renames.get("skills") or {}).items())]
    pairs += [f"agent `{x}` is `{y}`" for x, y in sorted((renames.get("agents") or {}).items())]
    if pairs:
        lines.append("- Renamed at install, so this repo's own skills and agents stay untouched: " + "; ".join(pairs) + ".")
    lines.append(NESTED_LOCAL_END)
    return lines


def _docs_readme() -> str:
    return f"""# Docs

Durable docs are versioned. Do not patch old versions.

## Categories

{chr(10).join(f"- `docs/current/{doc_id}.md`" for doc_id in DOC_TYPES)}

## Rules

Doc updates happen in a **docs phase the operator creates** — never per slice. A slice that changes durable truth appends a one-line note to its phase's `## Doc impact` list instead; `python3 scripts/workflow.py docs-debt` prints what is owed, and the docs phase runs the commands below over those notes.

- Read latest docs from `docs/current/*.md`.
- The agent creates updates with `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source <phase-or-slice>`.
- Edit only the newly created version file under `docs/versions/<doc>/`.
- The agent runs `python3 scripts/workflow.py rebuild-docs` after editing the new version.
- `docs/current/*.md` is generated from the latest version and should not be manually edited.
- When a phase's notes are all consolidated: `python3 scripts/workflow.py docs-consolidated <P>` (that is also what unblocks archiving it).

## Update Triggers

- `product`: goals, users, scope, terminology, business direction
- `experience`: routes, journeys, UI behavior, copy, UX states
- `architecture`: system boundaries, components, runtime, integrations
- `frontend`: routing, components, state, data fetching, browser auth
- `backend`: server modules, services, jobs, auth/session, logging/errors
- `data`: schema, migrations, entities, indexes, storage, retention
- `api`: REST/RPC/webhook/event contracts and error shapes
- `operations`: env, deployment, local commands, jobs, monitoring, backups
- `security`: permissions, secrets, customer data boundaries, abuse controls
- `qa`: test commands, QA missions, regression checklist, acceptance style
- `decisions`: meaningful choices, tradeoffs, rejected alternatives
"""


def nested_plan() -> dict:
    """Render and check everything the nested install writes, IN MEMORY, before any write: the
    clash map (merged into the existing marker on --update), the rewritten host-side skills and
    agents (each skill dir with its own `*` .gitignore), the engine-side contract and templates,
    settings.local.json, CLAUDE.local.md, the info/exclude block and the marker. Refuses (exit 1,
    nothing written) on an unresolvable clash, a tracked target, a target the host's .gitignore
    would keep visible (the ignore preflight), an unmergeable settings.local.json / CLAUDE.local.md /
    exclude file, or a failed post-check."""
    old = {}
    if UPDATE:
        try:
            old = json.loads((ROOT / NESTED_MARKER).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            _nested_refuse(f"{NESTED_DIR}/{NESTED_MARKER} cannot be read as JSON ({exc}); fix it, then re-run (nothing written).")
        if not isinstance(old, dict):
            _nested_refuse(f"{NESTED_DIR}/{NESTED_MARKER} is not a JSON object; fix it, then re-run (nothing written).")
    raw_renames = old.get("renames") if isinstance(old.get("renames"), dict) else {}
    raw_installed = old.get("installed") if isinstance(old.get("installed"), dict) else {}
    shipped = {"skills": CLAUDE_SKILLS, "agents": NESTED_AGENTS}
    renames, installed, stale = {k: {} for k in NESTED_KINDS}, {k: [] for k in NESTED_KINDS}, []
    for kind in NESTED_KINDS:
        table = raw_renames.get(kind) if isinstance(raw_renames.get(kind), dict) else {}
        old_renames = {x: y for x, y in table.items() if isinstance(y, str) and y}
        listed = raw_installed.get(kind) if isinstance(raw_installed.get(kind), list) else []
        prev = [n for n in listed if isinstance(n, str) and n]
        taken = _host_taken(kind, set(prev))
        for x in shipped[kind]:
            if x in old_renames:            # --update keeps every existing rename
                y = old_renames[x]
            elif x in prev:                 # ... and every name it installed unrenamed
                y = x
            else:                           # a newly shipped name (or a fresh install): clash check
                y = x
                if x in taken:
                    y = NESTED_RENAME_PREFIX + x
                    if y in taken:
                        _nested_refuse(f"cannot install the workspace's {kind[:-1]} {x}: the host's {taken[x]} takes {x!r} and its {taken[y]} takes {y!r} (nothing written).")
            if y != x:
                renames[kind][x] = y
            installed[kind].append(y)
        # The workspace's own copies that this version no longer ships stay recognised (and
        # excluded) while they exist; they are reported as stale, never deleted.
        for name in prev:
            rel = f".claude/skills/{name}" if kind == "skills" else f".claude/agents/{name}.md"
            if name not in installed[kind] and os.path.lexists(HOST / rel):
                installed[kind].append(name)
                stale.append(rel)

    files = {}
    for x in CLAUDE_SKILLS:
        files[f".claude/skills/{renames['skills'].get(x, x)}/SKILL.md"] = nested_rewrite(PAYLOADS[f".claude/skills/{x}/SKILL.md"], renames)
    for x in NESTED_AGENTS:
        files[f".claude/agents/{renames['agents'].get(x, x)}.md"] = nested_rewrite(PAYLOADS[f".claude/agents/{x}.md"], renames)
    engine_side = {NESTED_CONTRACT: nested_rewrite(f"# CLAUDE.md\n\n{CONTRACT_BODY}", renames)}
    for name in ("deferred_brief.md", "intent.md", "phase.md"):
        engine_side[f"works/templates/{name}"] = nested_rewrite(PAYLOADS[f"works/templates/{name}"], renames)
    # Agents at the host root read both of these, and their comments and text name the engine and
    # workspace paths. Rendered whenever written: executors.toml is seed-once (an existing one is
    # never overwritten), and docs/README.md is machinery whose refresh must not undo the rewrite.
    engine_side["executors.toml"] = nested_rewrite(PAYLOADS["executors.toml"], renames)
    engine_side["docs/README.md"] = nested_rewrite(_docs_readme(), renames)
    settings_ours = nested_rewrite(PAYLOADS[".claude/settings.json"], renames)
    local_block = _nested_local_block(renames)

    # Post-check: nothing the rewrite should have caught is left. Our own texts only -- never the
    # operator's part of CLAUDE.local.md or settings.local.json.
    problems = []
    checked = {**files, **{f"{NESTED_DIR}/{k}": v for k, v in engine_side.items()},
               "CLAUDE.local.md (managed block)": "\n".join(local_block), ".claude/settings.local.json (ours)": settings_ours}
    for label, text in sorted(checked.items()):
        if "python3 scripts/workflow.py" in text or NESTED_ENGINE_RE.search(text):
            problems.append(f"{label}: an unprefixed scripts/workflow.py")
        m = NESTED_PATH_RE.search(text)
        if m:
            problems.append(f"{label}: an unprefixed workspace path {m.group(0)!r}")
        free = "".join(NESTED_PROTECT_RE.split(text)[0::2])
        for x in renames["skills"]:
            if re.search(r"(?<![\w./-])/" + re.escape(x) + r"(?![\w-])", free):
                problems.append(f"{label}: the renamed skill still appears as /{x}")
        for x in renames["agents"]:
            if re.search(r"subagent_type:\s*" + re.escape(x) + r"(?![\w-])", text):
                problems.append(f"{label}: the renamed agent still appears as subagent_type: {x}")
    if problems:
        _nested_refuse("the nested rewrite left unprefixed or un-renamed references; nothing was written:", *[f"  - {p}" for p in problems[:12]])

    # Tracked-target refusal: info/exclude cannot hide a tracked file, so writing one would leak.
    targets = sorted({f".claude/skills/{n}" for n in installed["skills"]} | {f".claude/agents/{n}.md" for n in installed["agents"]}
                     | {"CLAUDE.local.md", ".claude/settings.local.json"})
    rc, out = _host_git("--literal-pathspecs", "ls-files", "--", *targets)
    tracked = [ln for ln in out.splitlines() if ln.strip()]
    if rc != 0 or tracked:
        _nested_refuse("the host repo tracks a file the nested install would write, and info/exclude cannot hide a tracked file "
                       "(nothing written):", *([f"  - {t}" for t in tracked[:10]] or [f"  (git ls-files failed with exit {rc})"]))

    # Ignore preflight (P28.F1): a .gitignore ranks above info/exclude, so a host negation such as
    # `!.claude/skills/**`, `!CLAUDE*.md` or an allowlist (`*` / `!*/` / `!*.md`) re-includes what
    # our block hides. Every skill dir we own (absent or a real directory) gets its own .gitignore
    # of `*`, the deepest pattern list for every path inside it, so its files are ignored by
    # construction: that file is MODELLED here, not written first. Every other target -- the agent
    # files, CLAUDE.local.md, settings.local.json, workflow/ as a directory, and an odd skill entry
    # that is not a directory -- is asked of git, and one that would stay visible refuses the
    # install, on --update too, before anything is written.
    exclude_entries = [f"/{NESTED_DIR}/", "/CLAUDE.local.md", "/.claude/settings.local.json"]
    exclude_entries += [f"/.claude/skills/{n}/" for n in sorted(installed["skills"])]
    exclude_entries += [f"/.claude/agents/{n}.md" for n in sorted(installed["agents"])]
    def _real_dir_or_absent(p: Path) -> bool:
        return not os.path.lexists(p) or (p.is_dir() and not p.is_symlink())
    self_hiding = [n for n in sorted(installed["skills"]) if _real_dir_or_absent(HOST / ".claude" / "skills" / n)]
    skill_ignores = {f".claude/skills/{n}/.gitignore": NESTED_SKILL_GITIGNORE for n in self_hiding}
    skill_targets = [f".claude/skills/{n}" for n in sorted(installed["skills"])]
    other_targets = [f".claude/agents/{n}.md" for n in sorted(installed["agents"])] + ["CLAUDE.local.md", ".claude/settings.local.json", NESTED_DIR]
    check_paths = [t for t in skill_targets if t.rsplit("/", 1)[1] not in self_hiding] + other_targets
    unignored = _nested_unignored(check_paths, exclude_entries)
    if unignored:
        _nested_refuse("the host's ignore rules would leave files of the nested install visible to git, so it cannot stay private (nothing written):",
                       *[f"  - {target}: {why}" for target, why in unignored],
                       "Why: a .gitignore in the host re-includes these paths, and .git/info/exclude, where this install hides its files, "
                       "ranks below every .gitignore and cannot override it.")

    settings_path = HOST / ".claude" / "settings.local.json"
    settings_text = settings_ours
    if os.path.lexists(settings_path):
        try:
            existing = settings_path.read_text(encoding="utf-8")
            theirs = json.loads(existing)
            if not isinstance(theirs, dict) or not isinstance(theirs.get("permissions", {}), dict):
                raise ValueError("not a JSON object with an object `permissions`")
            merged = json.loads(existing)
            perms = merged.setdefault("permissions", {})
            for key in ("allow", "deny"):
                current = perms.get(key) or []
                if not isinstance(current, list):
                    raise ValueError(f"permissions.{key} is not a list")
                perms[key] = list(current) + [x for x in json.loads(settings_ours)["permissions"].get(key, []) if x not in current]
        except (OSError, ValueError) as exc:
            _nested_refuse(f".claude/settings.local.json exists but cannot be merged ({exc}); fix or move it, then re-run (nothing written).")
        settings_text = existing if merged == theirs else json.dumps(merged, ensure_ascii=False, indent=2) + "\n"

    rc, out = _host_git("rev-parse", "--git-path", "info/exclude")
    if rc != 0 or not out.strip():
        _nested_refuse("cannot locate the host repo's info/exclude (git rev-parse --git-path info/exclude failed); nothing written.")
    exclude_path = Path(out.strip()) if os.path.isabs(out.strip()) else HOST / out.strip()
    local_path = HOST / "CLAUDE.local.md"
    try:
        local_text = _with_block(local_path.read_text(encoding="utf-8") if local_path.is_file() else "",
                                 NESTED_LOCAL_BEGIN, NESTED_LOCAL_END, local_block)
    except (OSError, ValueError) as exc:
        _nested_refuse(f"CLAUDE.local.md cannot take the managed block ({exc}); fix it, then re-run (nothing written).")
    try:
        exclude_text = _with_block(exclude_path.read_text(encoding="utf-8") if exclude_path.is_file() else "",
                                   NESTED_EXCLUDE_BEGIN, NESTED_EXCLUDE_END, [NESTED_EXCLUDE_BEGIN, *exclude_entries, NESTED_EXCLUDE_END])
    except (OSError, ValueError) as exc:
        _nested_refuse(f"{exclude_path} cannot take the managed block ({exc}); fix it, then re-run (nothing written).")

    # The marker, to the engine's schema 1 (+ `installed`). --update merges: a confirmed convention
    # and the existing renames are kept; an unconfirmed convention is re-inferred. A host this run
    # `git init`ed (P29) has no history to infer from and is the operator's own: it starts confirmed
    # on this workspace's own Commit Convention (NESTED_INIT_CONVENTION).
    old_conv = old.get("commit_convention") if isinstance(old.get("commit_convention"), dict) else {}
    if HOST_INITED:
        conv = dict(NESTED_INIT_CONVENTION)
    elif old_conv.get("confirmed") is True:
        conv = old_conv
    else:
        conv = {"inferred": nested_infer_convention(), "confirmed": False, "text": None, "coauthor_trailers": "unknown"}
    marker = dict(old)
    marker.update({"schema": 1, "host_root": "..", "commit_convention": conv, "renames": renames,
                   "installed": {k: sorted(installed[k]) for k in NESTED_KINDS}})
    home_skills = Path(os.path.expanduser("~")) / ".claude" / "skills"
    try:
        exclude_label = exclude_path.resolve().relative_to(HOST).as_posix()
    except ValueError:
        exclude_label = str(exclude_path)
    return {
        "renames": renames, "installed": installed, "stale": stale, "convention": conv,
        "shadowed": [n for n in installed["skills"] if os.path.lexists(home_skills / n)],
        "engine_side": engine_side,
        # Sorted, so each skill dir's .gitignore is written before its SKILL.md.
        "host_writes": [(HOST / rel, text, rel) for rel, text in sorted({**files, **skill_ignores}.items())]
                       + [(settings_path, settings_text, ".claude/settings.local.json"), (local_path, local_text, "CLAUDE.local.md"),
                          (exclude_path, exclude_text, exclude_label)],
        "marker_text": json.dumps(marker, ensure_ascii=False, indent=2) + "\n",
        "exclude_label": exclude_label,
        # nested_verify_clean() asks git status about exactly these after the writes.
        "status_paths": skill_targets + other_targets,
        "verified_clean": False,
    }


HOST_SUMMARY = {"updated": [], "added": [], "unchanged": []}


def nested_apply(plan: dict) -> None:
    """Write the host side and the marker (--dry-run: only record what would change). A file that
    already existed (the operator's CLAUDE.local.md, settings.local.json, info/exclude) keeps its mode."""
    for path, text, label in plan["host_writes"]:
        try:
            old = path.read_text(encoding="utf-8") if path.is_file() else None
        except (OSError, UnicodeDecodeError):
            old = ""
        if old == text:
            HOST_SUMMARY["unchanged"].append(label)
            continue
        HOST_SUMMARY["added" if old is None else "updated"].append(label)
        if not DRY_RUN:
            mode = stat.S_IMODE(path.stat().st_mode) if old is not None else None
            _atomic_write(path, text)
            if mode is not None:
                os.chmod(path, mode)
    if not DRY_RUN:
        _atomic_write(ROOT / NESTED_MARKER, plan["marker_text"])


def _nested_renames_line(plan: dict) -> str:
    pairs = [f"/{x} -> /{y}" for x, y in sorted(plan["renames"]["skills"].items())]
    pairs += [f"agent {x} -> {y}" for x, y in sorted(plan["renames"]["agents"].items())]
    return ("renamed to leave the host's own alone: " + ", ".join(pairs)) if pairs else "no name clashes with the host's own skills, commands or agents"


def print_nested_banner(plan: dict) -> None:
    cmd = f"python3 {NESTED_DIR}/scripts/workflow.py"
    if DRY_RUN or UPDATE:
        print(f"{'DRY RUN (--update --dry-run)' if DRY_RUN else 'Update complete (--update)'} at {HOST} (nested, detected)"
              f"{' -- nothing written.' if DRY_RUN else ''}")
        print(f"  engine side ({NESTED_DIR}/):")
        print_change_list()
        print(f"  host side (untracked, hidden by {plan['exclude_label']}): updated {len(HOST_SUMMARY['updated'])}, "
              f"added {len(HOST_SUMMARY['added'])}, unchanged {len(HOST_SUMMARY['unchanged'])}")
        for label in HOST_SUMMARY["updated"]:
            print(f"    ~ {label}")
        for label in HOST_SUMMARY["added"]:
            print(f"    + {label}")
        if plan["verified_clean"]:
            print("  verified: the host's git status lists none of the workspace's files")
        else:
            print("  checked: git will ignore every host-side file once written")
    else:
        print(f"Installed the agentic workspace privately into the host repo at {HOST}")
        if HOST_INITED:
            print("  host: a new git repo -- the installer ran git init there, and it has no commits yet")
        print(f"  engine + state: {NESTED_DIR}/ (a nested git repo; the contract is {NESTED_DIR}/{NESTED_CONTRACT})")
        print(f"  Claude Code: {len(plan['installed']['skills'])} skills in .claude/skills/ (each dir hides itself with a .gitignore of *), "
              f"{len(NESTED_AGENTS)} agents in .claude/agents/, .claude/settings.local.json, and CLAUDE.local.md importing the contract -- all untracked")
        if plan["verified_clean"]:
            print(f"  hidden by {plan['exclude_label']}, verified: the host's git status stays clean (no tracked file, CI, .gitattributes or docs/ touched)")
    print(f"  {_nested_renames_line(plan)}")
    for name in plan["shadowed"]:
        print(f"  warning: your personal skill ~/.claude/skills/{name} shadows the workspace's /{name} in this repo (rename or remove one)")
    conv = plan["convention"]
    if HOST_INITED:
        print(f"  host commit convention: confirmed for the new repo -- this workspace's own ({conv.get('text')}), coauthor_trailers={conv.get('coauthor_trailers')}")
    elif conv.get("confirmed") is True:
        print(f"  host commit convention: confirmed (coauthor_trailers={conv.get('coauthor_trailers')})")
    else:
        print(f"  host commit convention: UNCONFIRMED (inferred: {conv.get('inferred') or 'nothing -- the host has no history yet'})")
    if DRY_RUN:
        print("Re-run without --dry-run to apply.")
        return
    if HOST_INITED:
        print("The installer made no git commits: the host has no commits yet, and the workspace's files in it stay untracked.")
    else:
        print("The installer made no git commits, and nothing tracked in the host changed.")
    print(f"Next (start Claude Code at the host root, {HOST} -- never inside {NESTED_DIR}/):")
    if UPDATE:
        print(f"  1. Review and commit the refresh in the nested repo: git -C {NESTED_DIR} status, then git -C {NESTED_DIR} add -A && git -C {NESTED_DIR} commit -m \"chore: update agentic workspace (nested)\"")
        print(f"  2. Re-apply your executor tiers: {cmd} sync-agents")
    else:
        print(f"  1. First commit in the nested repo: git -C {NESTED_DIR} add -A && git -C {NESTED_DIR} commit -m \"chore: install agentic workspace (nested)\"")
        print(f"  2. Start Claude Code at the host root and accept the trust dialog on the first run, then: /{plan['renames']['skills'].get('create-phase', 'create-phase')} for the first phase ({cmd} next shows the state)")
    if conv.get("confirmed") is not True:
        print(f"  3. Confirm the commit convention before the first product commit: {cmd} nested-convention (then --confirm --text \"<convention>\" --trailers allowed|forbidden)")
    elif HOST_INITED:
        print(f"  The new repo's commit convention is recorded; {cmd} nested-convention shows it (--confirm --text \"...\" --trailers allowed|forbidden changes it).")
    else:
        print(f"  The host's commit convention is recorded; {cmd} nested-convention shows it.")
    if not HOST_INITED:
        print(f"  Any remote for {NESTED_DIR}/ stays inside your company's org: its phase and slice files describe the company's code.")


# ---- Guards -----------------------------------------------------------------
NESTED_PLAN = None
if NESTED:
    # Before anything is written, workflow/ included: the host checks (a fresh install into a new or
    # empty target `git init`s it first), then the whole host-side render with its post-check, the
    # tracked-target refusal and the ignore preflight. A refusal or a crash up to here undoes that init.
    try:
        nested_preflight()
        NESTED_PLAN = nested_plan()
    except BaseException:
        _nested_undo_init()
        raise
    _HOST_INIT_UNDO = None   # the first write is next: from here on the initialised host is kept
ROOT.mkdir(parents=True, exist_ok=True)
for rel in MANAGED_DIRS:
    p = ROOT / rel
    if p.exists() and not p.is_dir():
        sys.exit(f"Error: managed directory path exists but is not a directory: {rel}")

if UPDATE:
    # Require an already-installed workspace; refuse on a bare or foreign repo.
    works_present = (ROOT / "works/state.json").exists() or any(
        (ROOT / "works/phases/active").glob("*/phase.json")
    )
    if not NESTED and not ((ROOT / "scripts/workflow.py").exists() and works_present):
        print("Error: no agentic workspace found here to update.", file=sys.stderr)
        print("A new install is just: sh bootstrap_agentic_workspace.sh <dir> (the private nested layout, the default), "
              "or --at-root / --into-existing for the committed at-root layout.", file=sys.stderr)
        sys.exit(1)
    # Rebuild docs only when THIS repo uses the workspace's OWN docs system —
    # index.json plus our versioned doc-type dirs. A repo adopted over its own
    # (foreign or absent) docs/ never received ours, so running our docs rebuild
    # there would crash or corrupt; skip it and rebuild only the works side.
    UPDATE_DOCS = (
        (ROOT / "docs/index.json").exists()
        and (ROOT / "docs/versions").is_dir()
        and any((ROOT / "docs/versions" / d).is_dir() for d in DOC_TYPES)
    )
elif RETROFIT:
    # PLAN pass: classify before writing anything, and abort up front on a
    # load-bearing collision so a retrofit can never half-install.
    # Idempotent: a repo that already has the workspace is a clean no-op. Check
    # this BEFORE the workflow.py guard so re-running --into-existing (which sees
    # the workflow.py we installed) exits cleanly instead of aborting.
    works_present = (ROOT / "works/state.json").exists() or any(
        (ROOT / "works/phases/active").glob("*/phase.json")
    )
    if works_present:
        print("This repo already contains an agentic workspace (works/ present) — nothing to retrofit.")
        print("Drive it directly with python3 scripts/workflow.py.")
        sys.exit(0)
    # A foreign scripts/workflow.py would break the runtime — abort before writing.
    if (ROOT / "scripts/workflow.py").exists():
        print("Error: target already has scripts/workflow.py.", file=sys.stderr)
        print("The workspace runtime shells out to it, so it cannot be installed over a", file=sys.stderr)
        print("foreign copy. Rename/relocate the existing file, or adopt the workspace", file=sys.stderr)
        print("manually (see docs/retrofit-guide.md), then re-run.", file=sys.stderr)
        sys.exit(1)
    # Install the docs versioning subsystem only when the target has no docs
    # system of its own; otherwise leave docs/ untouched and skip its rebuild.
    docs_present = (
        (ROOT / "docs/index.json").exists()
        or ((ROOT / "docs/current").is_dir() and any((ROOT / "docs/current").glob("*.md")))
        or ((ROOT / "docs/versions").is_dir() and any((ROOT / "docs/versions").iterdir()))
    )
    INSTALL_DOCS = not docs_present
else:
    conflicts = [rel for rel in MANAGED_FILES if (ROOT / rel).exists()]
    if conflicts:
        print("Error: target already contains managed workflow files:", file=sys.stderr)
        for rel in conflicts:
            print(f"  - {rel}", file=sys.stderr)
        print("Refusing to overwrite. Use this bootstrap only for a fresh agentic workspace.", file=sys.stderr)
        print("To add the workspace to an existing repo, re-run with --into-existing.", file=sys.stderr)
        sys.exit(1)

    if not FORCE_EMPTY_OK:
        extra = sorted(p.name for p in ROOT.iterdir() if p.name not in EMPTY_OK_ALLOWLIST)
        if extra:
            print("Error: target is not empty (beyond common repo metadata).", file=sys.stderr)
            print("Unexpected entries:", file=sys.stderr)
            for name in extra:
                print(f"  - {name}", file=sys.stderr)
            print("Re-run with --force-empty-ok if these are intentional and no managed files conflict.", file=sys.stderr)
            print("Or use --into-existing to non-destructively retrofit into an existing repo.", file=sys.stderr)
            sys.exit(1)

for rel in MANAGED_DIRS:
    if DRY_RUN:
        continue  # dry-run writes nothing, not even directories
    if ((RETROFIT and not INSTALL_DOCS) or (UPDATE and not UPDATE_DOCS)) and (rel == "docs" or rel.startswith("docs/")):
        continue  # don't scaffold a docs/ tree the target opted out of
    (ROOT / rel).mkdir(parents=True, exist_ok=True)

if NESTED and not UPDATE and not DRY_RUN and not (ROOT / ".git").exists():
    # The nested repo that versions the workflow state. The installer never commits; the banner
    # names the operator's first commit there.
    subprocess.run(["git", "init", "-q"], cwd=str(ROOT), check=True)

created_at = now_iso()

# ---- Routing contract (CLAUDE.md) -------------------------------------------
if NESTED:
    # workflow/CLAUDE.workspace.md, rewritten; CLAUDE.local.md at the host root imports it.
    write_text(NESTED_CONTRACT, NESTED_PLAN["engine_side"][NESTED_CONTRACT])
else:
    write_text("CLAUDE.md", f"# CLAUDE.md\n\n{CONTRACT_BODY}")

# ---- Versioned docs ---------------------------------------------------------


def doc_frontmatter(doc_id: str, version: str, source: str, summary: str, previous=None) -> str:
    previous_line = f"previous: {previous}\n" if previous else "previous: null\n"
    return f"---\ndoc_id: {doc_id}\nversion: {version}\ncreated_at: {created_at}\nsource: {source}\nsummary: {summary}\n{previous_line}---\n\n"


index_docs = {}
for doc_id in DOC_TYPES:
    version_id = "v0001_bootstrap"
    rel = f"docs/versions/{doc_id}/{version_id}.md"
    summary = f"Initial {doc_id} doc"
    body = DOC_BODIES[doc_id].replace("__PROJECT_NAME__", PROJECT_NAME).replace("__PROJECT_SUMMARY__", PROJECT_SUMMARY)
    content = doc_frontmatter(doc_id, "v0001", "bootstrap", summary) + body
    write_text(rel, content)
    write_text(f"docs/current/{doc_id}.md", content)
    index_docs[doc_id] = {
        "latest": version_id,
        "current_path": f"docs/current/{doc_id}.md",
        "versions": [{"id": version_id, "path": rel, "created_at": created_at, "source": "bootstrap", "summary": summary, "previous": None}],
    }
write_json("docs/index.json", {"docs": index_docs, "last_rebuilt_at": created_at})
# Nested: rewritten (agents at the host root read it), like the contract and the templates.
write_text("docs/README.md", NESTED_PLAN["engine_side"]["docs/README.md"] if NESTED else _docs_readme())

# ---- Templates --------------------------------------------------------------
# No plan.md or result.md template: the orchestrator writes its free-form native plan
# into plan.md at the slice's turn, and the executor writes a free-form result.md at
# slice end. Scaffolded seeds: the phase notebook, the phase intent, and the deferred brief.
# Nested: rewritten, because agents at the host root read the phase files made from them.
_TEMPLATES = NESTED_PLAN["engine_side"] if NESTED else PAYLOADS
write_text("works/templates/deferred_brief.md", _TEMPLATES["works/templates/deferred_brief.md"])
write_text("works/templates/intent.md", _TEMPLATES["works/templates/intent.md"])
write_text("works/templates/phase.md", _TEMPLATES["works/templates/phase.md"])

# ---- Works state: starts with NO phases --------------------------------------
# The workspace intentionally bootstraps empty: the operator's first real task is
# captured via the create-phase intake flow (create-phase → new-phase), never a
# pre-seeded placeholder phase.
write_text("works/events.jsonl", json.dumps({"ts": created_at, "type": "bootstrap", "project": PROJECT_NAME}, ensure_ascii=False) + "\n")

# ---- Workflow engine (scripts/workflow.py) ----------------------------------
write_text("scripts/workflow.py", PAYLOADS["scripts/workflow.py"], executable=True)

# ---- Agent surfaces: Claude Code skills -------------------------------------
# (Nested: none under workflow/ -- the host-side copies are written by nested_apply below.)
for name in ([] if NESTED else CLAUDE_SKILLS):
    write_text(f".claude/skills/{name}/SKILL.md", PAYLOADS[f".claude/skills/{name}/SKILL.md"])

# Subagents: full-permission workers that implement one already-planned slice, in two
# capability tiers picked by the slice's risk (embedded verbatim from the live repo), plus
# the design subagent that drafts one design round (it follows the high tier's model).
if not NESTED:
    for tier in ("mid", "high"):
        write_text(f".claude/agents/slice-executor-{tier}.md", PAYLOADS[f".claude/agents/slice-executor-{tier}.md"])
    write_text(".claude/agents/design-drafter.md", PAYLOADS[".claude/agents/design-drafter.md"])

# ---- Executor-tier config (seeded once — commented defaults; operator-owned) ----
write_text("executors.toml", NESTED_PLAN["engine_side"]["executors.toml"] if NESTED else PAYLOADS["executors.toml"])

# ---- Claude Code project settings: pre-approve the workflow manager ----------
# (Nested: the host's settings.json is never touched; nested_apply writes settings.local.json.)
if not NESTED:
    write_text(".claude/settings.json", PAYLOADS[".claude/settings.json"])

# ---- Repo-level policy files: CI workflow (seed-once) + .gitattributes (merge) ----
# Never in a nested install: no CI file and no .gitattributes anywhere, host or workflow/.
if not NESTED:
    emit_policy_files()

# ---- Nested install: the host side and the marker (rendered and checked up front) ----
if NESTED:
    nested_apply(NESTED_PLAN)

# ---- Generate dashboards/state from the source of truth, then self-check ----
def run_workflow(*workflow_args: str) -> None:
    # Nested: from the host root, the way every nested session runs it (python3 workflow/scripts/workflow.py).
    subprocess.run([sys.executable, str(ROOT / "scripts" / "workflow.py"), *workflow_args], cwd=str(HOST or ROOT), check=True)


def write_version_marker() -> None:
    """Record provenance: which upstream commit this workspace is synced to.
    Informational only (the diff itself is always file-based); kept out of
    MANAGED_FILES so it never trips the fresh-install conflict guard."""
    marker = {
        "upstream_url": UPSTREAM_URL,
        "workspace_version": WORKSPACE_VERSION,
        "synced_commit": os.environ.get("SYNCED_COMMIT") or "bootstrap",
        "synced_at": now_iso(),
    }
    _atomic_write(ROOT / "works/.workspace-version.json", json.dumps(marker, ensure_ascii=False, indent=2) + "\n")


# Machinery files and directories older workspace versions shipped that this version
# has retired. --update never deletes; flag them so the operator removes them manually.
OBSOLETE_MACHINERY = [
    ".claude/agents/slice-executor.md",   # replaced by slice-executor-{low,mid,high}.md in v7
    ".env.example",                       # tier config moved to executors.toml(.example) in v8
    "executors.toml.example",             # example dropped in v9 — executors.toml itself is seeded
    "works/templates/result.md",          # template dropped in v10 — result.md is free-form, written by the executor
    ".claude/agents/slice-planner.md",    # retired in v20 — idle-window research uses plain Claude Code behaviour (Explore or inline)
    ".claude/agents/slice-executor-low.md",   # low tier retired in v23 — routing is two-tier (mid/high)
    ".agents",                            # Codex support dropped in v31 — the mirrored Codex skill tree
    ".codex",                             # Codex support dropped in v31 — Codex config + executor agents
    "AGENTS.md",                          # Codex support dropped in v31 — CLAUDE.md is the single contract
    "AGENTS.workspace.md",                # Codex support dropped in v31 — retrofit sidecar, no longer refreshed
]


def flag_obsolete_machinery() -> None:
    # .exists(), not .is_file(): OBSOLETE_MACHINERY carries retired directories
    # (.agents, .codex) as well as files.
    for rel in OBSOLETE_MACHINERY:
        if (ROOT / rel).exists():
            UPDATE_SUMMARY["stale"].append(f"{SHOWN_PREFIX}{rel}")


def flag_stale_skills() -> None:
    """Surface workspace-managed skill dirs that this version no longer ships, so
    the operator can remove them. A dir is "ours" only by our marker (a shipped
    SKILL.md sets `disable-model-invocation: true`) — so the operator's own skills
    are not mislabeled. Never deletes.

    Nested: the host's .claude/skills holds the TEAM's skills, so a marker heuristic could mislabel
    them; only the workspace's own copies (the marker's `installed` record) that this version no
    longer ships are stale -- nested_plan() lists them, and our installed or renamed names never are."""
    if NESTED:
        UPDATE_SUMMARY["stale"].extend(NESTED_PLAN["stale"])
        return
    expected = set(CLAUDE_SKILLS)
    base = ".claude/skills"
    d = ROOT / base
    if not d.is_dir():
        return
    for sub in sorted(d.iterdir()):
        if not sub.is_dir() or sub.name in expected:
            continue
        try:
            head = (sub / "SKILL.md").read_text(encoding="utf-8")[:400]
        except OSError:
            continue
        if "disable-model-invocation: true" in head:
            UPDATE_SUMMARY["stale"].append(f"{base}/{sub.name}")


def print_change_list() -> None:
    upd, add, mrg = UPDATE_SUMMARY["updated"], UPDATE_SUMMARY["added"], UPDATE_SUMMARY["merged"]
    print(f"  machinery updated: {len(upd)} file(s)")
    for path, added, removed in upd:
        print(f"    ~ {SHOWN_PREFIX}{path}  (+{added}/-{removed})")
    if add:
        print(f"  added: {len(add)} file(s)")
        for path in add:
            print(f"    + {SHOWN_PREFIX}{path}")
    if mrg:
        print(f"  merged (additive): {', '.join(SHOWN_PREFIX + m for m in mrg)}")
    print(f"  preserved (your work + docs, untouched): {len(UPDATE_SUMMARY['preserved'])} file(s)")
    print(f"  unchanged: {len(UPDATE_SUMMARY['unchanged'])} file(s)")
    if UPDATE_SUMMARY["stale"]:
        print(f"  stale workspace skills/machinery dropped upstream (remove manually?): {', '.join(UPDATE_SUMMARY['stale'])}")


if UPDATE:
    flag_stale_skills()
    flag_obsolete_machinery()

if DRY_RUN:
    pass  # previewed only — no rebuild/validate, no marker
elif UPDATE:
    if UPDATE_DOCS:
        run_workflow("rebuild")
        run_workflow("validate")
    else:
        # No docs subsystem here (retrofitted repo) — the docs rebuild would crash.
        run_workflow("next")
    write_version_marker()
elif RETROFIT and not INSTALL_DOCS:
    # The target owns docs/ — rebuild only the works side; do not run our docs
    # rebuild/validate against a foreign doc system.
    run_workflow("next")
    write_version_marker()
else:
    run_workflow("rebuild")
    run_workflow("validate")
    write_version_marker()

if NESTED:
    if not DRY_RUN:
        nested_verify_clean(NESTED_PLAN)
    print_nested_banner(NESTED_PLAN)
elif DRY_RUN:
    print(f"DRY RUN (--update --dry-run) at {TARGET} — nothing written.")
    print_change_list()
    print("Re-run without --dry-run to apply.")
elif UPDATE:
    print(f"Update complete (--update) at {TARGET}")
    print_change_list()
    if not UPDATE_DOCS:
        print("  note: no docs subsystem here; skipped docs rebuild (ran 'next' only)")
    print(f"  provenance recorded: works/.workspace-version.json (synced_commit {os.environ.get('SYNCED_COMMIT') or 'bootstrap'})")
    print("The installer made no git changes. Review the diff (git status); commit once the operator approves.")
    print("Next: python3 scripts/workflow.py sync-agents  # re-apply your preserved executors.toml")
    print("Then: python3 scripts/workflow.py next")
elif RETROFIT:
    created, skipped, merged = (RETROFIT_SUMMARY["created"], RETROFIT_SUMMARY["skipped"], RETROFIT_SUMMARY["merged"])
    print(f"Retrofit complete (--into-existing) at {TARGET}")
    print(f"  created: {len(created)} new file(s)")
    print(f"  skipped (kept yours): {len(skipped)} file(s)")
    if merged:
        print(f"  merged (additive): {', '.join(merged)}")
    print(f"  docs subsystem: {'installed' if INSTALL_DOCS else 'skipped (target already has a docs/ system)'}")
    print("  works subsystem: installed (no phases yet — the first phase is created by the operator)")
    if not INSTALL_DOCS:
        print("  note: docs versioning not installed; skipped docs rebuild/validate")
    print("The installer made no git changes. Review the diff (git status); commit the adoption once the operator approves.")
    print("If CLAUDE.md already existed, reconcile the CLAUDE.workspace.md sidecar; add __pycache__/ to .gitignore.")
    print("Next: python3 scripts/workflow.py validate, then create the first phase (/create-phase in Claude Code)")
else:
    print(f"Bootstrapped agentic workspace at {TARGET}")
    print("Contract: CLAUDE.md")
    print("Claude Code: 18 skills in .claude/skills/ (e.g. /do-next-slice), subagent tiers .claude/agents/slice-executor-{mid,high}.md, design subagent .claude/agents/design-drafter.md, settings .claude/settings.json")
    print("Visual design: design-cowork fires automatically; per phase the operator picks the tool — drafter (default: the design-drafter subagent drafts each round as plain files under docs/reference/design/: numbered cards, tokens, round records) or claude-design (they design in Claude Design; records under docs/reference/design/claude-design/) — and decides: picks a style (build-after / design-only / paired) and signs on the cards, or on a runnable mockup they ask for, before separate implementation and browser fidelity; python3 scripts/workflow.py design-register lists a drafter repo for a design dashboard")
    print("Executor tiers are risk-routed (mid is the default, real code included; high for decomposition, research, review, named triggers and retries); economy is the no-mode fallback, while this seed selects flex in executors.toml; switch it with python3 scripts/workflow.py executor-mode <economy|flex>, or tune it and run sync-agents")
    print("Any agent / CI: python3 scripts/workflow.py <command>")
    print("CI: .github/workflows/workspace-ci.yml runs validate on every push/PR (seeded once — yours to edit); .gitattributes carries the merge rules for machine-written files")
    print("Canonical state: phase.json / slice.json / deferred.json; generated: works/backlog.md, works/deferred.md")
    print("Versioned docs: docs/versions/<doc>/vNNNN_*.md with generated docs/current/*.md")
    print("Knowledge: /explain writes an interactive explainer for a phase or topic to your knowledge base (an operator-run step; the phase review writes none). First run sets up a hosted KB for you — it asks first. Already have one? export KB_API_BASE_URL + KB_API_TOKEN — see docs/current/operations.md")
    print("No phases yet — the workspace starts empty on purpose.")
    print("Next: create the first phase with /create-phase (Claude Code) or python3 scripts/workflow.py new-phase ...")
