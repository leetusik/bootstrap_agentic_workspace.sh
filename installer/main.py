# -*- coding: utf-8 -*-
# Line 1 must stay this PEP 263 cookie, spelled utf-8. wrapper.sh feeds this program to python3 on
# stdin, and without a declared encoding CPython 3.9 rejects the whole program ("Non-UTF-8 code ...
# but no encoding declared") whenever a multibyte character in one of the long embedded payload
# lines straddles its ~1 KB read-chunk boundary. The cookie turns that per-chunk check off (P27.F3).
from __future__ import annotations

import copy
import difflib
import hashlib
import json
import os
import re
import shlex
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
# stale / kept: (path, reason) pairs; notes / intents: lines (the update report, print_update_report)
UPDATE_SUMMARY = {"updated": [], "added": [], "merged": [], "preserved": [], "unchanged": [],
                  "stale": [], "kept": [], "notes": [], "intents": []}
# --to-multi-repo <repo> (P40.S10, OQ4): turn the per-repo nested install at <repo>/workflow/ into a
# multi-repo host at <repo>'s parent folder. Every refusal comes first (convert_prepare); then the parent
# is git init-ed (+ its empty commit), <repo>/workflow moves up a level, and the plain --update runs at
# the parent -- this very program from here on, with TARGET the parent and UPDATE set -- seeding the
# registry with the conversion's convention rule and `converted_from` (nested_plan); convert_finish maps
# the anchors, cleans the old repo's side and prints the closing block. No worktree code, no nested commit.
CONVERT = os.environ.get("TO_MULTI_REPO") == "1"
CONVERT_REPO = None
if CONVERT:
    CONVERT_REPO = TARGET.resolve()
    TARGET = CONVERT_REPO.parent
    UPDATE = True
UPSTREAM_URL = "https://github.com/leetusik/bootstrap_agentic_workspace.sh"
# Integer workspace version. Bumped (with a matching CHANGELOG.md entry) whenever a
# machinery change ships to targets. Rides inside this built artifact, so adopting
# repos — which have no installer/ — still get it stamped into their marker below.
WORKSPACE_VERSION = 84
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
_CONVERT_UNDO = None     # --to-multi-repo: (where the nested repo moved to, where it came from) until the first write
# The commit convention recorded for a host this installer just `git init`ed: it has no history to
# infer from and is the operator's own repo, so it takes this workspace's own Commit Convention.
NESTED_INIT_CONVENTION = {"inferred": None, "confirmed": True,
                          "text": "type(scope): summary -- imperative, no trailing period",
                          "coauthor_trailers": "allowed"}
# Multi-repo host (P40): a folder that tracks nothing and holds product repos at depth 1. The marker's
# optional `repos` registry (scripts/workflow.py: nested_repos(), NESTED_REPO_KEYS) is what makes an
# install multi-repo; every branch below is gated on a non-empty registry, so a single-repo nested or
# at-root install runs exactly the code it always did. The installer seeds the registry (a fresh install
# into a repos-only folder, or an --update on a host that tracks nothing and has no `repos` key) and
# renders it (the exclude lines, the CLAUDE.local.md block); the engine's `nested-repos` edits it after.
# The installer never contains worktree code. The conversion (--to-multi-repo, S10) shares these names:
# _child_repo_dirs, _seed_repos, _inferred_convention, _registry_entries, _multi_repo_local_block.
REPOS_HOST = False          # this run git init-ed a repos-only target: the host is a multi-repo host
REPOS_HOST_NAMES = []       # ... and the depth-1 repo dirs it found there (the registry nested_plan seeds)
HOST_FIRST_COMMIT = "chore: start the host history"   # the empty commit new-phase / parallel-start base on (OQ2)
HOST_COMMIT_ERROR = None    # why that commit was not made (git has no identity, usually); None when it was
REPO_NAME_RE = re.compile(r"[A-Za-z0-9._-]+")   # == scripts/workflow.py NESTED_REPO_NAME


def _nested_undo_init() -> None:
    """Remove what this run's `git init` of a new or empty host created -- its .git, then each
    directory it created if it is empty again -- and nothing else. A no-op once writing started.
    --to-multi-repo: the nested repo it moved goes back first (os.rename, as it came)."""
    global _HOST_INIT_UNDO, _CONVERT_UNDO
    moved, _CONVERT_UNDO = _CONVERT_UNDO, None
    if moved:
        try:
            os.rename(moved[0], moved[1])
            print(f"(--to-multi-repo undone: {moved[0]} moved back to {moved[1]}"
                  + (f", and the {moved[0].parent / '.git'} this run made removed)" if _HOST_INIT_UNDO else ")"), file=sys.stderr)
        except OSError as exc:
            _HOST_INIT_UNDO = None   # keep the host's .git: the nested repo is still under it
            print(f"Error: --to-multi-repo could not move {moved[0]} back ({exc}); move it by hand: "
                  f"mv {shlex.quote(str(moved[0]))} {shlex.quote(str(moved[1]))}", file=sys.stderr)
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
    fresh install, with or without --nested -- is nested. Refuses (exit 1, nothing written).
    --to-multi-repo is nested by definition: its own refusals (convert_prepare) judge the target."""
    if CONVERT:
        return True
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

DOC_TYPES = ["product", "architecture", "operations", "qa", "decisions"]

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
# Each skill ships as a directory: its SKILL.md (the core) plus any reference files, every one of
# them an emit path in PAYLOADS (the build fans the do-* shared references out into both skills).
SKILL_FILES = {name: sorted(k for k in PAYLOADS if k.startswith(f".claude/skills/{name}/")) for name in CLAUDE_SKILLS}

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
    ".claude/agents/slice-executor.md", ".claude/agents/design-drafter.md",
    ".claude/agents/design-critic.md", ".claude/agents/Explore.md",
    ".claude/settings.json",
    "executors.toml",
]
for name in CLAUDE_SKILLS:
    MANAGED_DIRS.append(f".claude/skills/{name}")
    MANAGED_FILES.extend(SKILL_FILES[name])
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


def _nested_engine_cmd(text: str) -> str:
    """In a nested install, spell the engine command as the host-root path. Only the
    command changes: the works/... names in the comment are relative to workflow/ (the
    file's own directory), so nested_rewrite must not be used here."""
    return NESTED_ENGINE_RE.sub(f"{NESTED_DIR}/scripts/workflow.py", text) if NESTED else text


def _apply_gitattributes(text: str, action: str) -> None:
    p = ROOT / GITATTRIBUTES_PATH
    if action == "create":
        _atomic_write(p, _nested_engine_cmd(text))
        return
    existing = p.read_text(encoding="utf-8")
    sep = "" if (not existing or existing.endswith("\n")) else "\n"
    _atomic_write(p, existing + sep + _nested_engine_cmd(GITATTRIBUTES_APPEND_NOTE) + GITATTRIBUTES_MERGE_LINE + "\n")


def emit_policy_files(ci: bool = True) -> None:
    """Emit the CI workflow (seed-once) and .gitattributes (line-merge) under every
    install mode, recording the outcome in whichever summary the mode reports.
    ci=False (a nested install, where ROOT is workflow/) emits the .gitattributes alone:
    the nested repo needs the union rule for events.jsonl when a phase branch merges,
    but the CI file is the host's business and is never written there."""
    ci_exists = (ROOT / CI_WORKFLOW_PATH).exists()
    ga_action = _gitattributes_action()
    if not DRY_RUN:
        if ci and not ci_exists:
            _atomic_write(ROOT / CI_WORKFLOW_PATH, PAYLOADS[CI_WORKFLOW_PATH])
        if ga_action != "unchanged":
            _apply_gitattributes(PAYLOADS[GITATTRIBUTES_PATH], ga_action)
    if UPDATE:
        if ci:
            UPDATE_SUMMARY["preserved" if ci_exists else "added"].append(CI_WORKFLOW_PATH)
        UPDATE_SUMMARY[{"create": "added", "merge": "merged", "unchanged": "unchanged"}[ga_action]].append(GITATTRIBUTES_PATH)
    elif RETROFIT:
        if ci:
            RETROFIT_SUMMARY["skipped" if ci_exists else "created"].append(CI_WORKFLOW_PATH)
        RETROFIT_SUMMARY[{"create": "created", "merge": "merged", "unchanged": "skipped"}[ga_action]].append(GITATTRIBUTES_PATH)


# ---- Retrofit (--into-existing) write policy --------------------------------
# In retrofit mode the workspace is added non-destructively: an existing file is
# never overwritten. A small, known set is additively, idempotently merged.
# Mechanisms an earlier version shipped and a later one retired (v61). `--update` scans the intent.md of
# every active phase that is not done for `pattern` and prints one line per hit, asking the agent to
# re-confirm that intent with the operator; it rewrites nothing. `hook` (optional) is a substring of
# the `command` of the settings hook handler that shipped the mechanism: `--update` removes exactly
# those handlers (RETIRED_HOOK_COMMANDS, derived below).
RETIRED_MECHANISMS = [
    {"name": "compact-gate", "retired": 61, "hook": "workflow.py compact-gate",
     "pattern": r"\bcompact-gate\b|PreCompact[ -](?:boundary[ -])?gate|boundary[- ]gated compaction",
     "replacement": "pure compaction and the resume card, compact-resume / next --card"},
    {"name": "claude-design", "retired": 60, "pattern": r"\bclaude-design\b|\bDesignSync\b",
     "replacement": "the drafter design tool and Design canvas Artifacts"},
    {"name": "design-deck", "retired": 60, "pattern": r"\bdesign-deck\b|\bdesign-register\b",
     "replacement": "Design canvas Artifacts in the Claude app"},
    {"name": "build-prompt.md", "retired": 61, "pattern": r"\bbuild-prompt\.md\b",
     "replacement": "the round's result.md ## Build"},
    {"name": "record-dispatch --tokens", "retired": 61,
     "pattern": r"record-dispatch[^\n]*?--(?:tokens|tool-uses|duration-ms)\b",
     "replacement": "spans metered from transcripts by dispatch-summary"},
]
# Settings we shipped and later retired or changed (v61). `--update` (and every other path through
# _merge_settings_dict) removes exactly our retired hook handlers -- matched by command -- and moves a window
# still at a value we shipped to today's; it reports both through SETTINGS_CHANGES.
RETIRED_HOOK_COMMANDS = {m["hook"]: f"retired in v{m['retired']}" for m in RETIRED_MECHANISMS if m.get("hook")}
SHIPPED_COMPACT_WINDOWS = {300000, 450000}  # 300000: v56 and v61-v65; 450000: v66-v81; today's value is 500000 (v57-v60, again since v82)
SETTINGS_CHANGES = {"removed": [], "changed": []}


def _merge_settings_dict(theirs: dict, ours: dict, label: str = None) -> dict:
    """Merge of our settings payload into a parsed target. Returns a new dict (`theirs` is not
    mutated); every key we do not own is untouched.
    - permissions.allow/deny: union, the adopter's entries first.
    - hooks: first, our retired handlers (RETIRED_HOOK_COMMANDS: a `command` containing
      `workflow.py compact-gate`) are removed, and a group or event key they leave empty is
      pruned -- nothing else is, an adopter's own handler on the same event included. Then, for
      each event and matcher group in `ours`, append our handler to the target's group with the
      same `matcher` (creating the event list / group when absent) unless a handler with the same
      `command` already exists anywhere under that event. Never removes, reorders or rewrites an
      adopter's entries.
    - autoCompactWindow (v56; 500000 since v82, as in v57-v60): copied from `ours` when the target has no
      such key; a value equal to one we shipped (SHIPPED_COMPACT_WINDOWS: 300000, v56 and v61-v65;
      450000, v66-v81) moves to ours; any other value the adopter chose is kept.
    With `label` (the file's shown path), each removal and change is recorded in SETTINGS_CHANGES.
    Idempotent. Raises ValueError on a malformed target shape (a non-object
    `permissions`/`hooks`, a non-list `allow`/`deny`/event/`hooks`, a non-object
    group) so callers can sidecar / refuse instead of clobbering."""
    merged = copy.deepcopy(theirs)
    removed, changed = [], []
    hooks_in = merged.get("hooks")
    if isinstance(hooks_in, dict):
        for event in list(hooks_in):
            groups = hooks_in[event]
            if not isinstance(groups, list):
                continue  # a malformed shape is reported below, never repaired here
            kept_groups = []
            for g in groups:
                inner = g.get("hooks") if isinstance(g, dict) else None
                if not isinstance(inner, list):
                    kept_groups.append(g)
                    continue
                keep = []
                for h in inner:
                    cmd = h.get("command") if isinstance(h, dict) else None
                    retired = next((k for k in RETIRED_HOOK_COMMANDS if isinstance(cmd, str) and k in cmd), None)
                    if retired:
                        removed.append(f"hooks.{event} {retired.split()[-1]} ({RETIRED_HOOK_COMMANDS[retired]})")
                    else:
                        keep.append(h)
                if len(keep) == len(inner):
                    kept_groups.append(g)
                elif keep:
                    kept_groups.append(dict(g, hooks=keep))
                # else: a group our removal emptied is pruned
            if kept_groups:
                hooks_in[event] = kept_groups
            elif groups:  # an event key our removal emptied is pruned
                del hooks_in[event]
        if removed and not hooks_in:
            del merged["hooks"]
    perms = merged.setdefault("permissions", {})
    if not isinstance(perms, dict):
        raise ValueError("`permissions` is not an object")
    for key in ("allow", "deny"):
        current = perms.get(key) or []
        if not isinstance(current, list):
            raise ValueError(f"permissions.{key} is not a list")
        additions = (ours.get("permissions") or {}).get(key) or []
        perms[key] = list(current) + [x for x in additions if x not in current]
    our_hooks = ours.get("hooks") or {}
    if our_hooks:
        hooks = merged.setdefault("hooks", {})
        if not isinstance(hooks, dict):
            raise ValueError("`hooks` is not an object")
        for event, our_groups in our_hooks.items():
            groups = hooks.setdefault(event, [])
            if not isinstance(groups, list) or not all(isinstance(g, dict) for g in groups):
                raise ValueError(f"hooks.{event} is not a list of objects")
            for g in groups:
                if not isinstance(g.get("hooks", []), list) or not all(isinstance(h, dict) for h in g.get("hooks", [])):
                    raise ValueError(f"hooks.{event}[].hooks is not a list of objects")
            have = {h.get("command") for g in groups for h in g.get("hooks", [])}
            for og in our_groups:
                for oh in og.get("hooks", []):
                    if oh.get("command") in have:
                        continue
                    target = next((g for g in groups if g.get("matcher") == og.get("matcher")), None)
                    if target is None:
                        target = {k: v for k, v in og.items() if k != "hooks"}
                        target["hooks"] = []
                        groups.append(target)
                    target.setdefault("hooks", []).append(copy.deepcopy(oh))
                    have.add(oh.get("command"))
    if "autoCompactWindow" in ours:
        current = merged.get("autoCompactWindow")
        if "autoCompactWindow" not in merged:
            merged["autoCompactWindow"] = ours["autoCompactWindow"]
        elif current in SHIPPED_COMPACT_WINDOWS and current != ours["autoCompactWindow"]:
            merged["autoCompactWindow"] = ours["autoCompactWindow"]
            changed.append(f"autoCompactWindow {current} -> {ours['autoCompactWindow']} "
                           f"(today's default; set it back if you chose {current})")
    if label:
        for key, lines in (("removed", removed), ("changed", changed)):
            for line in (f"{label} {x}" for x in lines):
                if line not in SETTINGS_CHANGES[key]:  # one line per change, however many handlers it took
                    SETTINGS_CHANGES[key].append(line)
    return merged


def _merge_settings_json(text: str, write: bool = True) -> None:
    """Merge our settings payload (permissions union + hooks, our retired hooks removed + autoCompactWindow)
    into an existing .claude/settings.json, preserving every key the target already has. Idempotent.
    write=False (--update --dry-run) only records the removed/changed lines for the report."""
    p = ROOT / ".claude/settings.json"
    ours = json.loads(text)
    try:
        theirs = json.loads(p.read_text(encoding="utf-8"))
        if not isinstance(theirs, dict):
            raise ValueError("settings.json is not a JSON object")
        merged = _merge_settings_dict(theirs, ours, label=".claude/settings.json")
    except Exception:
        if not write:
            return
        # Never clobber an unparseable / malformed file — drop a sidecar instead.
        _atomic_write(ROOT / ".claude/settings.workspace.json", text)
        RETROFIT_SUMMARY["skipped"].append(".claude/settings.json (unparseable; wrote .claude/settings.workspace.json)")
        return
    if not write:
        return
    _atomic_write(p, json.dumps(merged, ensure_ascii=False, indent=2) + "\n")
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
#   SEED-ONCE: executors.toml (operator route config — created if absent, never
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
            _merge_settings_json(text, write=not DRY_RUN)
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
    # Seed-once: executors.toml is the operator's route config — create it when
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
NESTED_AGENTS = ["slice-executor", "design-drafter", "design-critic", "Explore"]
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


def _git_in(path: Path, *args: str):
    """(returncode, stdout) of git run in `path` -- read-only queries only."""
    proc = subprocess.run(["git", "-C", str(path), *args], capture_output=True)
    return proc.returncode, proc.stdout.decode("utf-8", errors="replace")


def _host_git(*args: str):
    """(returncode, stdout) of git run in the host repo -- read-only queries only."""
    return _git_in(HOST, *args)


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


def _is_repo_dir(path: Path) -> bool:
    """`path` is a real directory (not a symlink) that is the root of its own git work tree: it has a
    `.git` (a directory, or the file of a worktree or submodule) and git agrees it is a work tree root."""
    if path.is_symlink() or not path.is_dir() or not os.path.lexists(path / ".git"):
        return False
    top = _work_tree_top(path)
    return top is not None and top == path.resolve()


def _registrable_name(name: str) -> bool:
    """A dir name the registry can take as a repo's name and path: [A-Za-z0-9._-]+, and neither the
    nested workspace's dir nor `.claude/` (the engine refuses both as a registry path)."""
    return bool(REPO_NAME_RE.fullmatch(name)) and name not in (NESTED_DIR, ".claude")


def _child_repo_dirs(base: Path) -> list:
    """Sorted names of `base`'s depth-1 directories that are git work tree roots, the nested
    workspace's own dir and `.claude/` aside. Detection only: it registers nothing."""
    try:
        entries = sorted(base.iterdir(), key=lambda e: e.name)
    except OSError:
        return []
    return [e.name for e in entries if e.name not in (NESTED_DIR, ".claude") and _is_repo_dir(e)]


def _repos_only_target():
    """The depth-1 repo names (sorted) when HOST is a repos-only target (S1 §12 step 1), else None: not
    inside any git work tree and not a repo itself; every depth-1 entry outside EMPTY_OK_ALLOWLIST is a
    git repo whose name the registry can take; at least one such repo. Anything else keeps today's refusal."""
    if not HOST.is_dir() or os.path.lexists(HOST / ".git") or _work_tree_top(HOST) is not None:
        return None
    names = []
    for entry in sorted(HOST.iterdir(), key=lambda e: e.name):
        if entry.name in EMPTY_OK_ALLOWLIST:
            continue
        if not (_registrable_name(entry.name) and _is_repo_dir(entry)):
            return None
        names.append(entry.name)
    return names or None


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
    there would.

    P40: a non-git target that holds only product repos (_repos_only_target) is initialised the same
    way, with its undo, and then gets the empty commit `chore: start the host history` -- the one
    commit the installer ever makes (_host_first_commit); it becomes a multi-repo host (REPOS_HOST)."""
    global HOST_INITED, REPOS_HOST, REPOS_HOST_NAMES, _HOST_INIT_UNDO
    created = []
    repos_only = None
    if os.path.lexists(HOST):
        if _host_empty_or_absent():
            if _work_tree_top(HOST) is not None:
                return
        else:
            repos_only = _repos_only_target()
            if repos_only is None:
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
    if repos_only is not None:
        REPOS_HOST, REPOS_HOST_NAMES = True, repos_only
        _host_first_commit()


def _host_first_commit() -> None:
    """The host's one commit, empty: new-phase stamps host_anchors.created from it and parallel-start
    takes its base from it. A refusal later in this run removes the whole .git with it (the undo). When
    git will not make it (no identity, usually), the init is kept, HOST_COMMIT_ERROR says why and the
    banner prints the commands; the install goes on as a hand-initialised host's would."""
    global HOST_COMMIT_ERROR
    try:
        proc = subprocess.run(["git", "-C", str(HOST), "commit", "--allow-empty", "-q", "-m", HOST_FIRST_COMMIT],
                              capture_output=True, stdin=subprocess.DEVNULL, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        HOST_COMMIT_ERROR = str(exc) or type(exc).__name__
        return
    if proc.returncode != 0:
        lines = [ln.strip() for ln in proc.stderr.decode("utf-8", errors="replace").splitlines() if ln.strip()]
        HOST_COMMIT_ERROR = lines[0] if lines else f"git commit exited {proc.returncode}"


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


def nested_infer_convention(base: Path = None):
    """The host's commit convention, inferred non-interactively from its recent history and any
    CONTRIBUTING file -- one line for the operator to confirm (`nested-convention --confirm`), or
    None when the host has neither. `base` (P40) infers from another repo instead: each registered
    repo of a multi-repo host, on its own history."""
    base = HOST if base is None else base
    rc, out = _git_in(base, "log", "-n", "50", "--no-merges", "--format=%s")
    subjects = [s.strip() for s in out.splitlines() if s.strip()] if rc == 0 else []
    rc, bodies = _git_in(base, "log", "-n", "50", "--no-merges", "--format=%B%x00")
    trailers = sum(1 for b in bodies.split("\x00") if re.search(r"(?im)^co-authored-by:", b)) if rc == 0 else 0
    mentions = []
    for f in sorted(base.glob("CONTRIBUTING*")) + sorted((base / ".github").glob("CONTRIBUTING*")):
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


REPO_RULE_NAMES = ("AGENTS.md", "CLAUDE.md")   # == scripts/workflow.py NESTED_REPO_RULE_NAMES


def _inferred_convention(repo_path: Path) -> dict:
    """An UNCONFIRMED convention for one repo: inferred from that repo's own history and CONTRIBUTING
    file (the host-level rule of nested_plan, applied per repo -- S1 §5)."""
    return {"inferred": nested_infer_convention(repo_path), "confirmed": False, "text": None, "coauthor_trailers": "unknown"}


def _repo_origin_head(path: Path):
    """The branch a repo's `origin/HEAD` points at (`main`, `dev`, ...), or None. Same reading as the
    engine's `_repo_origin_head`, which `nested-repos --add` seeds `default_branch` from."""
    rc, out = _git_in(path, "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD")
    target = out.strip() if rc == 0 else ""
    return target.split("/", 1)[1] if target.startswith("origin/") and len(target) > len("origin/") else None


def _detect_repo_rules(path: Path) -> list:
    """A repo's own rules files, repo-relative and sorted: every tracked `AGENTS.md` / `CLAUDE.md` at
    any depth, plus `.agents/skills/*/SKILL.md`. The same detection as the engine's `_detect_repo_rules`
    (`nested-repos --detect-rules`): tracked files only, so build output and ignored copies never count."""
    rc, out = _git_in(path, "ls-files", "-z")
    if rc != 0:
        return []
    found = []
    for f in out.split("\0"):
        parts = f.split("/") if f else []
        if parts and (parts[-1] in REPO_RULE_NAMES or (len(parts) == 4 and parts[:2] == [".agents", "skills"] and parts[3] == "SKILL.md")):
            found.append(f)
    return sorted(found)


def _seed_repos(names: list, convention_for) -> list:
    """Registry entries for the depth-1 repos `names` of HOST, in the engine's key order: name and path
    are the dir name, default_branch the repo's origin/HEAD target (else null), rules detected.
    `convention_for(name, path)` returns the entry's commit_convention: a four-key object or None (inherit)."""
    return [{"name": n, "path": n, "default_branch": _repo_origin_head(HOST / n),
             "commit_convention": convention_for(n, HOST / n), "rules": _detect_repo_rules(HOST / n)} for n in names]


def _clean_repo_path(raw) -> bool:
    """A registry path the installer will act on (an exclude line, a block line, a git call): host-relative
    and normalized, never the nested dir or under `.claude/`. The engine's `validate` judges the rest."""
    if not (isinstance(raw, str) and raw.strip() and raw == raw.strip()) or os.path.isabs(raw) or "\\" in raw:
        return False
    parts = raw.split("/")
    return not any(p in ("", ".", "..") for p in parts) and parts[0] not in (NESTED_DIR, ".claude")


def _registry_entries(raw) -> list:
    """The entries of a marker's `repos` the installer can use: dicts with a usable name and path. Others
    are skipped here (never rewritten, never dropped from the marker): the engine's `validate` reports them."""
    if not isinstance(raw, list):
        return []
    return [r for r in raw if isinstance(r, dict) and isinstance(r.get("name"), str) and _clean_repo_path(r.get("path"))]


def _reinfer_unconfirmed(raw: list) -> list:
    """A later --update: a repo whose own convention is unconfirmed is re-inferred, as the host-level one
    is on a single-repo host; a confirmed or null (inherit) one is kept. Entries are copied, never mutated."""
    out = []
    for r in raw:
        conv = r.get("commit_convention") if isinstance(r, dict) else None
        if isinstance(conv, dict) and conv.get("confirmed") is not True and _clean_repo_path(r.get("path")) and _is_repo_dir(HOST / r["path"]):
            r = {**r, "commit_convention": _inferred_convention(HOST / r["path"])}
        out.append(r)
    return out


def _repo_unconfirmed(repos: list, host_conv: dict) -> list:
    """Names of the registered repos whose effective convention is UNCONFIRMED: its own is not confirmed,
    or it has none (null = inherit) and the host-level one is not confirmed -- the engine's reading."""
    out = []
    for r in repos:
        conv = r.get("commit_convention")
        if (conv.get("confirmed") is True) if isinstance(conv, dict) else (host_conv.get("confirmed") is True):
            continue
        out.append(r["name"])
    return out


def _tracked_workspace_files(repo_path: Path, installed: dict) -> list:
    """Workspace paths a repo tracks (`workflow`, `CLAUDE.local.md`, `.claude/settings.local.json`, an
    installed skill dir or agent file): the engine's validate row, an error once the repo is registered."""
    paths = [NESTED_DIR, "CLAUDE.local.md", ".claude/settings.local.json"]
    paths += [f".claude/skills/{n}" for n in installed.get("skills") or []] + [f".claude/agents/{n}.md" for n in installed.get("agents") or []]
    rc, out = _git_in(repo_path, "ls-files", "-z", "--", *paths)
    files = [f for f in out.split("\0") if f] if rc == 0 else []
    return [w for w in paths if any(f == w or f.startswith(w + "/") for f in files)]


def _is_commit(path: Path, sha: str) -> bool:
    proc = subprocess.run(["git", "-C", str(path), "cat-file", "-e", f"{sha}^{{commit}}"], capture_output=True)
    return proc.returncode == 0


def _registry_drift_notes(repos: list) -> list:
    """One line per depth-1 child repo the registry does not list. The installer never re-detects once
    `repos` exists (S1 §3): the engine's `nested-repos --add` owns the list."""
    registered = {r["path"] for r in repos}
    cmd = f"python3 {NESTED_DIR}/scripts/workflow.py"
    notes = []
    for child in _child_repo_dirs(HOST):
        if child not in registered:
            quoted = shlex.quote(child)
            hint = f"{cmd} nested-repos --add {quoted}" if _registrable_name(child) else f"{cmd} nested-repos --add {quoted} --name <name>"
            notes.append(f"{child}/ is a git repo the registry does not list (--update never re-detects): {hint}")
    return notes


def _anchor_map_notes(repos: list) -> list:
    """S2 §25: phases whose `host_anchors` shas are no commit of the host but are commits of exactly one
    registered repo (glide: the migrated P1-P33 shas) get one note per repo naming `nested-repos
    --map-anchors <repo>`. --update maps nothing itself: the engine owns phase.json, and its command
    skips a phase in flight on its own branch."""
    seen, counts = {}, {}

    def commit_of(path: Path, sha: str) -> bool:
        key = (str(path), sha)
        if key not in seen:
            seen[key] = _is_commit(path, sha)
        return seen[key]
    for state in ("active", "archived"):
        for pj in sorted((ROOT / "works" / "phases" / state).glob("*/phase.json")):
            try:
                data = json.loads(pj.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            anchors = data.get("host_anchors") if isinstance(data, dict) else None
            if not isinstance(anchors, dict):
                continue
            shas = [anchors.get(k) for k in ("created", "review_pass", "review_base")]
            shas = [s for s in shas if isinstance(s, str) and re.fullmatch(r"[0-9a-fA-F]{7,64}", s)]
            if not shas or any(commit_of(HOST, s) for s in shas):
                continue
            owners = [r["name"] for r in repos if all(commit_of(HOST / r["path"], s) for s in shas)]
            if len(owners) == 1:
                counts[owners[0]] = counts.get(owners[0], 0) + 1
    cmd = f"python3 {NESTED_DIR}/scripts/workflow.py"
    return [f"{n} phase(s) hold host_anchors shas that are no commit of the host but are commits of {name}: run {cmd} nested-repos --map-anchors {name}"
            for name, n in sorted(counts.items())]


def _nested_unignored(check_paths: list, exclude_entries: list, dir_paths=()) -> list:
    """[(target, reason)] for each host path in `check_paths` that git would NOT ignore once our
    exclude block is in place -- decided before any write (P28.F1). The block goes into a temporary
    core.excludesFile, which ranks below the host's .gitignore files and its current info/exclude,
    and matches every target: so the answer is "ignored" unless a .gitignore (or an operator line
    already in info/exclude) decides otherwise, which is exactly what can override the block once
    it is in info/exclude (it has no negations). The one approximation errs safe: an operator's own
    info/exclude negation of a target refuses even where our block would come after it. A target
    that does not exist yet is matched as a file, so `workflow/` is checked as a directory that
    must exist: it is created empty for the check and removed again if it was absent. `dir_paths`
    (P40: a multi-repo host's registered repos) are directories the exclude block hides as `/<path>/`;
    they are shown with the trailing slash. Refuses (exit 1, nothing written) when the check itself
    cannot run."""
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
        shown = f"{path}/" if path == NESTED_DIR or path in dir_paths else path
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


def _renames_line(renames: dict):
    """The block's renames line ("Renamed at install, ..."), or None when nothing was renamed."""
    pairs = [f"skill `{x}` is `/{y}`" for x, y in sorted((renames.get("skills") or {}).items())]
    pairs += [f"agent `{x}` is `{y}`" for x, y in sorted((renames.get("agents") or {}).items())]
    if pairs:
        return "- Renamed at install, so this repo's own skills and agents stay untouched: " + "; ".join(pairs) + "."
    return None


def _multi_repo_local_block(renames: dict, repos: list, converted=()) -> list:
    """The managed CLAUDE.local.md block of a multi-repo host (P40; S1 §6 with S2 §21's parallel line):
    the single-repo block's shape, with one line per registered repo (path, default branch, rules files),
    "this repo" meaning the repo the change lives in, one commit per repo a slice changed, and a parallel
    line naming `--repo` and `parallel-add-repo`. Emitted only when `repos` is non-empty; the renames
    line is appended exactly as the single-repo block does. `converted` (the marker's `converted_from`,
    S10) adds one line per converted per-repo install after the repo list; without it the block is S9's."""
    cmd = f"python3 {NESTED_DIR}/scripts/workflow.py"
    repo_lines = []
    for r in repos:
        rules = [x for x in r.get("rules") or [] if isinstance(x, str) and x]
        facts = [f"default branch `{r['default_branch']}`"] if isinstance(r.get("default_branch"), str) and r["default_branch"] else []
        facts += ["rules: " + ", ".join(f"`{x}`" for x in rules)] if rules else []
        repo_lines.append(f"  - `{r['path']}/`" + (f" ({'; '.join(facts)})" if facts else ""))
    for c in converted:
        if isinstance(c, dict) and all(isinstance(c.get(k), str) and c[k].strip() for k in ("repo", "at")):
            repo_lines.append(f"- Records from before {c['at']} name product paths relative to `{c['repo']}/`.")
    lines = [
        NESTED_LOCAL_BEGIN,
        f"This is a private install of the agentic workspace at a host folder that tracks nothing and holds several product repos. It is never committed anywhere and the team cannot see it: `{NESTED_DIR}/` (its own git repo), this file and the workspace's own `.claude/` files are hidden by the host's `.git/info/exclude`.",
        "",
        f"@{NESTED_DIR}/{NESTED_CONTRACT}",
        "",
        "Nested-install rules for a multi-repo host (they win over the contract above where the two differ):",
        f"- Start Claude Code at this host folder, never inside `{NESTED_DIR}/` or a repo. Run the engine from here: `{cmd} <command>`.",
        f"- The product repos (`{cmd} nested-repos` lists them, with each repo's rules files):",
        *repo_lines,
        "- \"This repo\" in any rule means the repo the change lives in. Before changing a repo, read its rules files; they win over this block for that repo.",
        "- Commits per slice: one in each repo the slice changed, plus one for the workflow state:",
        f"  - product code goes to its own repo with `git -C <repo> ...`, on the operator's branch there, in that repo's conventions for commits, branches and pull requests, which `{cmd} nested-convention --repo <name>` prints. Add Claude `Co-Authored-By` trailers only when it says `allowed`. The host folder itself never gets a commit;",
        f"  - workflow state goes to the nested repo (`git -C {NESTED_DIR} ...`) in the contract's Commit Convention.",
        f"- If `next` shows `host_commit_convention=UNCONFIRMED` or an UNCONFIRMED repo in `repo_conventions=`, confirm those conventions with the operator before that repo's first product commit, then record them: `{cmd} nested-convention --confirm [--repo <name>] --text \"<conventions>\" --trailers allowed|forbidden` (no `--repo`: the rules for every repo).",
        f"- **Parallel phases, only on the operator's word:** `{cmd} parallel-start <P> --host-branch <name> [--host-base <ref>] [--repo <name>=<branch> ...] [--repo-base <name>=<ref> ...]` cuts a set: a host worktree under `.claude/worktrees/`, the nested worktree at its `{NESTED_DIR}/`, and one worktree per named repo at its `<repo>/`; add a repo mid-phase from inside the set with `parallel-add-repo <P> --repo <name>=<branch>`. Propose each branch name from that repo's recorded custom (`nested-convention --repo <name>`) and let the operator confirm it. Each repo's side follows its own custom; the engine never fetches, pushes, opens a PR or merges into any repo's default branch.",
        f"- A pull request's title, body and commits (and every product commit, in every repo) carry no phase or slice IDs, no `{NESTED_DIR}/` paths and no workspace files.",
        f"- Never stage `{NESTED_DIR}/`, `CLAUDE.local.md`, `.claude/settings.local.json` or the workspace's skills and agents into any repo or the host (the exclude block lists them).",
    ]
    renames_line = _renames_line(renames)
    if renames_line:
        lines.append(renames_line)
    lines.append(NESTED_LOCAL_END)
    return lines


def _nested_local_block(renames: dict, repos=(), converted=()) -> list:
    """The managed CLAUDE.local.md block: what this is, the contract import (on its own line,
    outside any code span or fence, or Claude Code will not expand it) and the nested rules.
    A multi-repo host (a non-empty registry, P40) gets _multi_repo_local_block instead."""
    if repos:
        return _multi_repo_local_block(renames, repos, converted)
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
        f"  - product code goes to this repo, on the operator's ticket branch, in the host's conventions for commits, branches and pull requests, which `{cmd} nested-convention` prints. Add Claude `Co-Authored-By` trailers only when it says `allowed`;",
        f"  - workflow state goes to the nested repo (`git -C {NESTED_DIR} ...`) in the contract's Commit Convention.",
        f"- If `next` shows `host_commit_convention=UNCONFIRMED`, confirm the host's conventions (commits, branches and pull requests) with the operator before the first product commit, then record them: `{cmd} nested-convention --confirm --text \"<conventions>\" --trailers allowed|forbidden`.",
        f"- **Parallel phases, only on the operator's word:** `{cmd} parallel-start <P> --host-branch <name> [--host-base <ref>]` cuts a pair: a host worktree under `.claude/worktrees/` on the host branch, with the nested worktree at its `{NESTED_DIR}/`. Propose the branch name from the host's recorded custom and let the operator confirm it. The host side follows that custom; the engine never pushes, opens a PR or merges into the host's default branch.",
        f"- A pull request's title, body and commits (and every product commit) carry no phase or slice IDs, no `{NESTED_DIR}/` paths and no workspace files.",
        f"- Never stage `{NESTED_DIR}/`, `CLAUDE.local.md`, `.claude/settings.local.json` or the workspace's skills and agents into this repo (the exclude block lists them).",
    ]
    renames_line = _renames_line(renames)
    if renames_line:
        lines.append(renames_line)
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

- `product`: goals, users, scope, terminology, business direction, and the user journeys and UX rules the code cannot show
- `architecture`: system boundaries, components, runtime, integrations, and what the code cannot say about its modules, data, API contracts and security model (invariants, ownership, retention, outside contracts, trust boundaries)
- `operations`: env, deployment, local commands, jobs, monitoring, backups, and how the operator runs and views the product
- `qa`: test commands, QA missions, regression checklist, acceptance style
- `decisions`: meaningful choices, tradeoffs, rejected alternatives

These docs are read by agents, which can read the code: write what the code cannot say, and point at the code for the rest. An install made before v79 may also hold `experience`, `frontend`, `backend`, `data`, `api` and `security`: they are retired, kept readable and never versioned again, and their changes go to `product` (experience) or `architecture` (the rest).
"""


def _is_explain_path(rel: str) -> bool:
    """A repo-relative path with a component named `explain`: the knowledge plugin owns it (v65), so no
    install path creates, writes, removes, flags or reports it."""
    return "explain" in rel.split("/")


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
    prior_renames = {k: {} for k in NESTED_KINDS}  # the marker's whole table, retired names included
    retained_renames = {k: {} for k in NESTED_KINDS}  # renames of retired copies still on disk
    for kind in NESTED_KINDS:
        table = raw_renames.get(kind) if isinstance(raw_renames.get(kind), dict) else {}
        old_renames = {x: y for x, y in table.items() if isinstance(y, str) and y}
        prior_renames[kind] = old_renames
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
        # excluded) while they exist; flag_retired_files() classifies their files by content, never deletes them.
        # Their renames stay in the marker with them (never in the rewrite), so a later --update still maps
        # a renamed copy back to its canonical path.
        original = {y: x for x, y in old_renames.items()}
        for name in prev:
            rel = f".claude/skills/{name}" if kind == "skills" else f".claude/agents/{name}.md"
            if name not in installed[kind] and os.path.lexists(HOST / rel):
                installed[kind].append(name)
                if name in original and original[name] not in shipped[kind]:
                    retained_renames[kind][original[name]] = name
                if not _is_explain_path(rel):
                    stale.append(rel)

    files = {}
    for x in CLAUDE_SKILLS:
        for rel in SKILL_FILES[x]:  # the core and its reference files, into the (renamed) skill dir
            inner = rel[len(f".claude/skills/{x}/"):]
            files[f".claude/skills/{renames['skills'].get(x, x)}/{inner}"] = nested_rewrite(PAYLOADS[rel], renames)
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

    # Multi-repo host (P40). The registry is the marker's `repos`. Seeded when this run git init-ed a
    # repos-only folder (each repo takes its own convention, inferred from its own history, UNCONFIRMED), or
    # when --update finds no `repos` key on a host that tracks nothing and holds a depth-1 child repo
    # (under a confirmed host-level convention every repo inherits it: null; else inferred per repo). Once
    # it exists the installer never re-detects: it re-infers each repo's own unconfirmed convention and
    # reports drift (_registry_drift_notes). A single-repo host gets [] here, and so none of this.
    old_conv = old.get("commit_convention") if isinstance(old.get("commit_convention"), dict) else {}
    repos, repos_seeded = [], False
    if REPOS_HOST:
        repos, repos_seeded = _seed_repos(REPOS_HOST_NAMES, lambda n, p: _inferred_convention(p)), True
    elif UPDATE and "repos" not in old:
        rc, out = _host_git("ls-files", "-z")
        names = [n for n in _child_repo_dirs(HOST) if _registrable_name(n)] if rc == 0 and not out.strip("\0") else []
        if names and CONVERT:
            # --to-multi-repo (S10): the old repo keeps the old marker's convention, verbatim; every other repo
            # gets its own inferred, unconfirmed one -- the old repo's rules are never copied up to bind the others.
            repos, repos_seeded = _seed_repos(names, lambda n, p: copy.deepcopy(old_conv) if n == CONVERT_REPO.name else _inferred_convention(p)), True
        elif names:
            inherit = old_conv.get("confirmed") is True
            repos, repos_seeded = _seed_repos(names, lambda n, p: None if inherit else _inferred_convention(p)), True
    elif UPDATE and isinstance(old.get("repos"), list):
        repos = _reinfer_unconfirmed(old["repos"])
    usable = _registry_entries(repos)
    if repos_seeded:
        # The engine's validate rejects a registered repo that tracks a workspace file; refuse before writing.
        tracking = [(r["name"], _tracked_workspace_files(HOST / r["path"], installed)) for r in usable]
        tracking = [(n, w) for n, w in tracking if w]
        if tracking:
            _nested_refuse("a repo this install would register tracks a file the workspace owns, which the engine's validate rejects (nothing written):",
                           *[f"  - {n}/ tracks {', '.join(w)}: untrack them (git -C {n} rm -r --cached -- {' '.join(w)}), then re-run" for n, w in tracking])
    # --to-multi-repo (S10) appends one `converted_from` entry; the multi-repo block prints one line per entry.
    converted = list(old.get("converted_from")) if isinstance(old.get("converted_from"), list) else []
    if CONVERT:
        converted.append({"repo": CONVERT_REPO.name, "old_nested": f"{CONVERT_REPO.name}/{NESTED_DIR}",
                          "at": datetime.now().astimezone().date().isoformat()})
    local_block = _nested_local_block(renames, usable, converted)

    # Post-check: nothing the rewrite should have caught is left. Our own texts only -- never the
    # operator's part of CLAUDE.local.md or settings.local.json, nor a registered repo's own paths (a
    # stand-in repo line takes their place in the multi-repo block).
    problems = []
    stand_in = [{"name": "repo", "path": "repo", "default_branch": None, "rules": []}] if usable else []
    checked = {**files, **{f"{NESTED_DIR}/{k}": v for k, v in engine_side.items()},
               "CLAUDE.local.md (managed block)": "\n".join(_nested_local_block(renames, stand_in)), ".claude/settings.local.json (ours)": settings_ours}
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
    exclude_entries = [f"/{NESTED_DIR}/", "/CLAUDE.local.md", "/.claude/settings.local.json", "/.claude/worktrees/"]
    exclude_entries += [f"/.claude/skills/{n}/" for n in sorted(installed["skills"])]
    exclude_entries += [f"/.claude/agents/{n}.md" for n in sorted(installed["agents"])]
    # A multi-repo host's registered repos: one `/<path>/` line each, generated from the registry so
    # --update follows `nested-repos --add/--remove`. Only a repo that exists is preflighted and verified
    # (validate reports a missing one).
    exclude_entries += [f"/{r['path']}/" for r in usable]
    repo_dirs = [r["path"] for r in usable if (HOST / r["path"]).is_dir()]
    def _real_dir_or_absent(p: Path) -> bool:
        return not os.path.lexists(p) or (p.is_dir() and not p.is_symlink())
    self_hiding = [n for n in sorted(installed["skills"]) if _real_dir_or_absent(HOST / ".claude" / "skills" / n)]
    skill_ignores = {f".claude/skills/{n}/.gitignore": NESTED_SKILL_GITIGNORE for n in self_hiding
                     if not _is_explain_path(f".claude/skills/{n}")}
    skill_targets = [f".claude/skills/{n}" for n in sorted(installed["skills"])]
    other_targets = [f".claude/agents/{n}.md" for n in sorted(installed["agents"])] + ["CLAUDE.local.md", ".claude/settings.local.json", NESTED_DIR]
    check_paths = [t for t in skill_targets if t.rsplit("/", 1)[1] not in self_hiding] + other_targets + repo_dirs
    unignored = _nested_unignored(check_paths, exclude_entries, repo_dirs)
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
            merged = _merge_settings_dict(theirs, json.loads(settings_ours), label=".claude/settings.local.json")
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
    # on this workspace's own Commit Convention (NESTED_INIT_CONVENTION). A multi-repo host's top-level
    # convention is "the rules for every repo": confirmed it is kept; unconfirmed it starts empty
    # (inferred: null), never inferred from the host's own empty history and never the workspace's own.
    if usable and CONVERT:
        # --to-multi-repo: the old convention moved to its repo above; the rules for every repo start empty.
        conv = {"inferred": None, "confirmed": False, "text": None, "coauthor_trailers": "unknown"}
    elif usable:
        conv = old_conv if old_conv.get("confirmed") is True else {"inferred": None, "confirmed": False, "text": None, "coauthor_trailers": "unknown"}
    elif HOST_INITED:
        conv = dict(NESTED_INIT_CONVENTION)
    elif old_conv.get("confirmed") is True:
        conv = old_conv
    else:
        conv = {"inferred": nested_infer_convention(), "confirmed": False, "text": None, "coauthor_trailers": "unknown"}
    marker = dict(old)
    marker.update({"schema": 1, "host_root": "..", "commit_convention": conv,
                   "renames": {k: {**retained_renames[k], **renames[k]} for k in NESTED_KINDS},
                   "installed": {k: sorted(installed[k]) for k in NESTED_KINDS}})
    if repos_seeded or (UPDATE and isinstance(old.get("repos"), list)):
        marker["repos"] = repos
    if CONVERT:
        marker["converted_from"] = converted
    # Notes for the update report: drift (a depth-1 child repo the registry lacks) and the anchors to map
    # (--to-multi-repo maps them itself, right after this --update: convert_finish).
    if UPDATE and usable:
        UPDATE_SUMMARY["notes"].extend(_registry_drift_notes(usable) + ([] if CONVERT else _anchor_map_notes(usable)))
    # OQ1: Claude Code reads no AGENTS.md while a CLAUDE.local.md sits at the working directory, which every
    # nested install writes. The installer writes nothing into any repo; the banner prints one hint line when
    # a registered repo's rules, or a single-repo host's tracked files, include an AGENTS.md.
    if usable:
        agents_md = [r["name"] for r in usable if any(isinstance(x, str) and x.rsplit("/", 1)[-1] == "AGENTS.md" for x in r.get("rules") or [])]
    else:
        rc, out = _host_git("ls-files", "-z")
        agents_md = ["this repo"] if rc == 0 and any(f.rsplit("/", 1)[-1] == "AGENTS.md" for f in out.split("\0") if f) else []
    home_skills = Path(os.path.expanduser("~")) / ".claude" / "skills"
    try:
        exclude_label = exclude_path.resolve().relative_to(HOST).as_posix()
    except ValueError:
        exclude_label = str(exclude_path)
    return {
        "renames": renames, "installed": installed, "stale": stale, "convention": conv, "prior_renames": prior_renames,
        "shadowed": [n for n in installed["skills"] if os.path.lexists(home_skills / n) and not _is_explain_path(n)],
        "engine_side": engine_side,
        # Sorted, so each skill dir's .gitignore is written before its SKILL.md.
        "host_writes": [(HOST / rel, text, rel) for rel, text in sorted({**files, **skill_ignores}.items())]
                       + [(settings_path, settings_text, ".claude/settings.local.json"), (local_path, local_text, "CLAUDE.local.md"),
                          (exclude_path, exclude_text, exclude_label)],
        "marker_text": json.dumps(marker, ensure_ascii=False, indent=2) + "\n",
        "exclude_label": exclude_label,
        # nested_verify_clean() asks git status about exactly these after the writes.
        "status_paths": skill_targets + other_targets + repo_dirs,
        "verified_clean": False,
        # P40: the usable registry (empty on a single-repo host), whether this run seeded it, and the
        # AGENTS.md carriers the banner's hint names.
        "repos": usable, "repos_seeded": repos_seeded, "agents_md": agents_md,
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
        print_update_report()
        if plan["verified_clean"]:
            print("  verified: the host's git status lists none of the workspace's files")
        else:
            print("  checked: git will ignore every host-side file once written")
    else:
        print(f"Installed the agentic workspace privately into the host repo at {HOST}")
        if REPOS_HOST:
            print("  host: a new git repo over the repos in this folder -- the installer ran git init there"
                  + (f" and made its one commit, the empty \"{HOST_FIRST_COMMIT}\"" if HOST_COMMIT_ERROR is None
                     else " but could not make its first commit (see below)"))
        elif HOST_INITED:
            print("  host: a new git repo -- the installer ran git init there, and it has no commits yet")
        print(f"  engine + state: {NESTED_DIR}/ (a nested git repo; the contract is {NESTED_DIR}/{NESTED_CONTRACT})")
        print(f"  Claude Code: {len(plan['installed']['skills'])} skills in .claude/skills/ (each dir hides itself with a .gitignore of *), "
              f"{len(NESTED_AGENTS)} agents in .claude/agents/, .claude/settings.local.json, and CLAUDE.local.md importing the contract -- all untracked")
        if plan["verified_clean"]:
            print(f"  hidden by {plan['exclude_label']}, verified: the host's git status stays clean (no tracked file, CI, .gitattributes or docs/ touched)")
        print_update_report()
    print(f"  {_nested_renames_line(plan)}")
    for name in plan["shadowed"]:
        print(f"  warning: your personal skill ~/.claude/skills/{name} shadows the workspace's /{name} in this repo (rename or remove one)")
    conv = plan["convention"]
    repos = plan["repos"]
    if repos:
        # P40: a multi-repo host's top-level convention is the rules for every repo; each repo has its own.
        if conv.get("confirmed") is True:
            print(f"  host commit convention (the rules for every repo): confirmed (coauthor_trailers={conv.get('coauthor_trailers')})")
        else:
            print("  host commit convention (the rules for every repo): UNCONFIRMED (inferred: nothing -- a multi-repo host has no commits of its own to infer from)")
        print(f"  repos: {len(repos)} ({', '.join(r['name'] for r in repos)}) -- "
              + (f"{'would be seeded' if DRY_RUN else 'seeded'} into {NESTED_DIR}/{NESTED_MARKER} from the repos in this folder"
                 if plan["repos_seeded"] else f"the registry in {NESTED_DIR}/{NESTED_MARKER} ({cmd} nested-repos lists it)")
              + f"; each is hidden by a /<path>/ line in {plan['exclude_label']}")
        unconfirmed = _repo_unconfirmed(repos, conv)
        if unconfirmed:
            print(f"  repo conventions: UNCONFIRMED for {', '.join(unconfirmed)} -- confirm each before its first product commit: "
                  f"{cmd} nested-convention --confirm --repo <name> --text \"<conventions>\" --trailers allowed|forbidden")
    elif HOST_INITED:
        print(f"  host commit convention: confirmed for the new repo -- this workspace's own ({conv.get('text')}), coauthor_trailers={conv.get('coauthor_trailers')}")
    elif conv.get("confirmed") is True:
        print(f"  host commit convention: confirmed (coauthor_trailers={conv.get('coauthor_trailers')})")
    else:
        print(f"  host commit convention: UNCONFIRMED (inferred: {conv.get('inferred') or 'nothing -- the host has no history yet'})")
    if plan["agents_md"]:
        # OQ1 / S1 §13: the installer writes nothing into any repo; the operator sets this once, in the user settings.
        who = "this repo's AGENTS.md" if not repos else "the AGENTS.md of " + ", ".join(plan["agents_md"])
        print("  AGENTS.md: Claude Code reads no AGENTS.md while a CLAUDE.local.md sits at the working directory, and this install writes one -- "
              f"to load {who}, set Project instructions to claude-md-and-agents-md in ~/.claude/settings.json (/config shows it; Claude Code 2.1.277+)")
    if DRY_RUN:
        print("Re-run without --dry-run to apply.")
        return
    if CONVERT:
        return   # --to-multi-repo: convert_finish prints the rest, and its own Next
    if REPOS_HOST and HOST_COMMIT_ERROR is None:
        print(f"The installer made one git commit, the empty \"{HOST_FIRST_COMMIT}\" in the host (new-phase and parallel-start base on it); "
              "the workspace's files stay untracked and nothing in any repo changed.")
    elif REPOS_HOST:
        print("The installer made no git commits and changed nothing in any repo. The host has no commit yet, and new-phase needs one first "
              f"(git said: {HOST_COMMIT_ERROR}). Give git an identity (globally, so the nested repo's first commit works too), then make it:")
        print("    git config --global user.name \"<your name>\" && git config --global user.email \"<you@example.com>\"")
        print(f"    git -C {shlex.quote(str(HOST))} commit --allow-empty -m \"{HOST_FIRST_COMMIT}\"")
    elif HOST_INITED:
        print("The installer made no git commits: the host has no commits yet, and the workspace's files in it stay untracked.")
    else:
        print("The installer made no git commits, and nothing tracked in the host changed.")
    print(f"Next (start Claude Code at the host root, {HOST} -- never inside {NESTED_DIR}/):")
    if UPDATE:
        print(f"  1. Commit the refresh in the nested repo (/update-workspace does this itself): git -C {NESTED_DIR} status, then git -C {NESTED_DIR} add -A && git -C {NESTED_DIR} commit -m \"chore: update agentic workspace to v{WORKSPACE_VERSION} (nested)\"")
        print(f"  2. Re-apply your executors.toml route overrides: {cmd} sync-agents; {cmd} executor-route prints an override= line for each row it pins")
    else:
        print(f"  1. First commit in the nested repo: git -C {NESTED_DIR} add -A && git -C {NESTED_DIR} commit -m \"chore: install agentic workspace (nested)\"")
        print(f"  2. Start Claude Code at the host root and accept the trust dialog on the first run, then: /{plan['renames']['skills'].get('create-phase', 'create-phase')} for the first phase ({cmd} next shows the state)")
    if repos:
        if conv.get("confirmed") is not True:
            print(f"  3. Confirm the conventions that bind every repo before the first product commit: {cmd} nested-convention (then --confirm --text \"<conventions>\" --trailers allowed|forbidden; add --repo <name> for one repo's own)")
        else:
            print(f"  The host-level conventions (the rules for every repo) are recorded; {cmd} nested-convention shows them, and each repo's with --repo <name>.")
    elif conv.get("confirmed") is not True:
        print(f"  3. Confirm the host's conventions (commits, branches and pull requests) before the first product commit: {cmd} nested-convention (then --confirm --text \"<conventions>\" --trailers allowed|forbidden)")
    elif HOST_INITED:
        print(f"  The new repo's conventions are recorded; {cmd} nested-convention shows them (--confirm --text \"...\" --trailers allowed|forbidden changes it).")
    else:
        print(f"  The host's conventions (commits, branches, pull requests) are recorded; {cmd} nested-convention shows them.")
    if not HOST_INITED or REPOS_HOST:
        print(f"  Any remote for {NESTED_DIR}/ stays inside your company's org: its phase and slice files describe the company's code.")


# ---- The update report (v61): what --update removed, changed and flags, in one place ----------
# Every file an earlier version shipped and this one no longer does: emit path -> (the last version that
# shipped it, the sha256 of each text that version wrote there). Ownership is by CONTENT, never by path
# or directory: a present file whose hash matches is ours and unchanged, flagged stale (remove it); any
# other file at a retired path, or under a retired directory, is the adopter's, reported "yours, kept".
# An unmodified copy from an even older version therefore reads as kept: conservative on purpose.
# A path with an `explain` component is never listed here, touched or reported (_is_explain_path):
# the knowledge plugin owns it, and a .claude/skills/explain/ copy stays until its owner deletes it.
# Generated once (P37.S8) by a throwaway script over this repo's git history: every committed
# bootstrap_agentic_workspace.sh's embedded PAYLOADS (what the installer wrote, not the repo's own tree),
# taking the text at the last commit that shipped the path (the trailing comment). AGENTS.md and
# AGENTS.workspace.md are v30's "# AGENTS.md" header + CONTRACT_BODY, as v30's main.py wrote both; the
# second executor-mode hash is v52's nested_rewrite (no renames) of the same text. The Kiro sidecar
# (.kiro/, added and reverted inside v44) never shipped and is absent.
# When a later version drops a shipped file (a skill's reference file too), add it here the same way:
# the hash of its last shipped text, plus its nested_rewrite with no renames for a .claude/ file.
# The v65 executor pair (slice-executor-mid/-high, merged into slice-executor in v66) is hashed with its
# frontmatter `model:` / `effort:` lines dropped (RETIRED_ROUTE_LINES): sync-agents owns those two lines
# and an adopter's overrides live in executors.toml, so a copy that differs only there is still ours.
RETIRED_FILES = {
    '.agents/skills/archive-phase/SKILL.md': (30, ('f748d9ae055255eee2eef5c16b59d86219755331bdda66a9938fb5ae80d82013',)),  # 4ee5c22
    '.agents/skills/archive-phase/agents/openai.yaml': (30, ('8a5fe61f92bfbc624864afb5907edb8b918017f99f38fab0bc7235ad09a0d2c3',)),  # 4ee5c22
    '.agents/skills/commit/SKILL.md': (30, ('cebbc9317542e76102be4b5e9a439033f008acb817e1f4daba069e117763774b',)),  # 4ee5c22
    '.agents/skills/commit/agents/openai.yaml': (30, ('f4447ffb0661c6e85e1ad8af155ab4df50c74acc7ddf47d592408b86548c6e2f',)),  # 4ee5c22
    '.agents/skills/create-phase/SKILL.md': (30, ('8e9ab6847b743474ff9875ac6b6e12becda8ddeefbf62b25b571b989986fcc07',)),  # 4ee5c22
    '.agents/skills/create-phase/agents/openai.yaml': (30, ('177306729676315872e49b4d15ffe73cc2568728a2c59b8a66db783176f6460d',)),  # 4ee5c22
    '.agents/skills/defer-job/SKILL.md': (30, ('a13cd7220828fd312b878459f47e7c10d0d0195b8879375479773a469978bfd7',)),  # 4ee5c22
    '.agents/skills/defer-job/agents/openai.yaml': (30, ('46b101bb9e58272aeb33e1a93b56e075b92e36b50f281a6c2260e392f88ce8db',)),  # 4ee5c22
    '.agents/skills/deferred/SKILL.md': (30, ('e3d01f70bc9bb167d0bbd1d74005151fd8c823dbbd450696105339802f67882f',)),  # 4ee5c22
    '.agents/skills/deferred/agents/openai.yaml': (30, ('c1aefcc49a339628ed743c1ac4f1167b6cbf50eb94e5a55b2f9bd4e79c25f239',)),  # 4ee5c22
    '.agents/skills/design-cowork/SKILL.md': (30, ('f19cb3f2fb07307152eec95cab45c6dff29be5dc3e2508de4a34d423166785f9',)),  # 4ee5c22
    '.agents/skills/design-cowork/agents/openai.yaml': (30, ('33ebbf01cf515f4e89699a63cbf4e6d7494a4ac022c2e46d945894d7ec13c534',)),  # 4ee5c22
    '.agents/skills/do-next-slice/SKILL.md': (30, ('84f97c72c58bad82944d0369785d3486cb330eec37ec238b8e052a6f5de05c6b',)),  # 4ee5c22
    '.agents/skills/do-next-slice/agents/openai.yaml': (30, ('aeff0d7fc86ede761042ea3837cfdde1fe6accf656395c446c6e0ebf84d8123a',)),  # 4ee5c22
    '.agents/skills/do-whole-phase/SKILL.md': (30, ('e6aec0c715791ab0bbb47d8f2f124ac064df861f6f21669a572b49b93e17ef03',)),  # 4ee5c22
    '.agents/skills/do-whole-phase/agents/openai.yaml': (30, ('482b7e274c36509c5edbf1395d470a8603038ada6be8e241465868f24d4d2774',)),  # 4ee5c22
    '.agents/skills/doc-new-version/SKILL.md': (30, ('8c066ef299e02e8d72851c3f198a82015dd3f0f13874427f0c418236def92099',)),  # 4ee5c22
    '.agents/skills/doc-new-version/agents/openai.yaml': (30, ('f081a68aa674117ea0c0e97e1557f6d002c09de7bc267fefef214d52a817e53c',)),  # 4ee5c22
    '.agents/skills/parallel-phase/SKILL.md': (30, ('03f41c6bc927bba5d875e8d7c5c47ab1fee8b3937c388e97e9168cac4fd334b7',)),  # 4ee5c22
    '.agents/skills/parallel-phase/agents/openai.yaml': (30, ('5606a3232f932e9ffa41e4e58bd8457962237c38aa4b9439922effe2b3768b2e',)),  # 4ee5c22
    '.agents/skills/promote-deferred/SKILL.md': (30, ('a314fc511656a451e2f408c0383e0f3ec52482bc3ecf6c8aedfb25c083fba520',)),  # 4ee5c22
    '.agents/skills/promote-deferred/agents/openai.yaml': (30, ('3567035e19a67ccf89415387d9c48fba44a384ab2ef068c9cf594a83d291bc55',)),  # 4ee5c22
    '.agents/skills/rebuild-workflow/SKILL.md': (30, ('a2730a21fa5ba34c95b826b325a0e24430c095732c1378d9ced9a7fb62c9cf74',)),  # 4ee5c22
    '.agents/skills/rebuild-workflow/agents/openai.yaml': (30, ('2185bbae7136a4e77b38aea2c6b061e49fda6a264f724d28fe929b2630a78faf',)),  # 4ee5c22
    '.agents/skills/retrofit/SKILL.md': (30, ('66cc4658acd9bf8149e2f415ce7a1f82956f37c6fd9cf7bf9fee47ca8741ef72',)),  # 4ee5c22
    '.agents/skills/retrofit/agents/openai.yaml': (30, ('18b5537ef7a138221575dad2d8d19e5a3698351d38c25ff5708e19e27e01e962',)),  # 4ee5c22
    '.agents/skills/review-phase/SKILL.md': (30, ('d9e26409b18aecf1d8c99f116b2d9498b371351b738006bb4f49faa7ca0e4b32',)),  # 4ee5c22
    '.agents/skills/review-phase/agents/openai.yaml': (30, ('ec764186a6f0380290058bba59e4d431434a1ca8d8bc143705b7c99329bb3fde',)),  # 4ee5c22
    '.agents/skills/rotate-backlog/SKILL.md': (30, ('5d1433b879b7861c9b4d150541543b5bf594a7537e4939d569efccdaaa21d538',)),  # 4ee5c22
    '.agents/skills/rotate-backlog/agents/openai.yaml': (30, ('6d0256fe50e14bebef26818397323412ab68cbe7cacc4599af1bca1a7582e2c3',)),  # 4ee5c22
    '.agents/skills/update-workspace/SKILL.md': (30, ('4f25b084dbfd896148f240ea3c663af40848a35041ba7aaed92d7abb8a6be30e',)),  # 4ee5c22
    '.agents/skills/update-workspace/agents/openai.yaml': (30, ('0631c41fd8e1ec98331777d3e078d1ef4fdc1ec6c6cbf07cffcf73e1e1101206',)),  # 4ee5c22
    '.claude/agents/explain-critic.md': (80, ('9884de281812c30718d8a96a8210c9057020b8c109cd42fd00b057bd6495ff14', '855f34a90ded840a0402d8c1bfc04e188272faabea48327840cf008f6b85b693', 'f82cbdcb86cf9d37356ed6378ccbc5f3b3a83b2ccd90233eba647496bb98cf65', '7a59c619824460c8532da58fb25943bafd23c3a78b4259977567e779d3a84aff', '2c66e29d087b3ce4990323c9ce3c6d290a7bd38334f9760ef253c15ede6deb58', '118e9d3b8478b14f237e0216631cfa213c11e0cb12184bdc0fd6a110d60acd53')),  # 9b64bcb (v75-v80), 8fa6476 (v66-v74), d0759a4 (v65)
    '.claude/agents/slice-executor-high.md': (65, ('7a76f8dbe6d10b50333d34b2008fb576dd48f3720f9e2ba67847f4d5eed41f36', '0eafa7ed541f7d21f075878686179c186ac3cbacec96a7fb562d53279964ac4d')),  # d0759a4, route lines dropped
    '.claude/agents/slice-executor-low.md': (22, ('3d798df8b1170cf3aff4bbf10fbe83e6f7d8a8721a990a8d74333b7c08c731df',)),  # 097041d
    '.claude/agents/slice-executor-mid.md': (65, ('3c74ce9945cae627de3588f3ea01533cb8990a48e0b12d813af61d0ba04ded8a', 'faaa25e5cdc62e625d3720030f24e94388ec1cbeb5e80de6deafc39820f2654b')),  # d0759a4, route lines dropped
    '.claude/agents/slice-planner.md': (19, ('7c8fa4c4824f276ec5e79292826dfb58a41ed4078682175faae2e119d36c51d6',)),  # c94f6e4
    '.claude/skills/executor-mode/SKILL.md': (52, ('382fe9e6644c15c46d49ab0b481c8cec0b6722f20816d3fca48a60ba61826d43', 'cef5b8fbf576e83fd6048ceb652e05ddcd7cbcded6a4168efb5c834f32c16970')),  # 7c874c3
    '.codex/agents/slice-executor-high.toml': (30, ('217fcafcd0449db43fd1e25b4a0a13cc918ee2ab46d4980a8544b098ed31ec2d',)),  # 4ee5c22
    '.codex/agents/slice-executor-low.toml': (22, ('57e24a3b80eaa8a1991b82aeb29b6447735453c08ede535cc353a86a2b78bc35',)),  # 097041d
    '.codex/agents/slice-executor-mid.toml': (30, ('1cd71cc675b96957f227c797ae7fd75b1ae8172eef3823ba890150545e7642b0',)),  # 4ee5c22
    '.codex/agents/slice-executor.toml': (6, ('bd800dc30642e149b54bcf7b04af954b3e19d8d9517371c84e4fb53618fadd1e',)),  # 057ec31
    '.codex/config.toml': (30, ('789bf89992ed3a26c23fa7476e497f45682a8b76f50de6b626add3638fc94fc5',)),  # 4ee5c22
    '.env.example': (7, ('d93203bd09384e1a44ffcd868c80966f0b8de96536bcf95e768b369b1d757750',)),  # 3104b74
    'AGENTS.md': (30, ('7ef0f82ad8d51f08cdcd750735fd0849344b5cb739f341f77c704fcf6e5033e6',)),  # 4ee5c22
    'AGENTS.workspace.md': (30, ('7ef0f82ad8d51f08cdcd750735fd0849344b5cb739f341f77c704fcf6e5033e6',)),  # 4ee5c22
    'executors.toml.example': (8, ('dad1620e97404eb7d1d9f29d796a05347c3b655e567c74a9e26ac6814e923261',)),  # 8a3c8c2
    'works/templates/result.md': (9, ('3938ceaf78a7392d62ca5a7e88ee51e132d56f30adafb06afb002361639e1dc9',)),  # 06561c4
}
# The retired paths hashed with their frontmatter model:/effort: lines dropped (_drop_route_lines).
RETIRED_ROUTE_LINES = {".claude/agents/slice-executor-high.md", ".claude/agents/slice-executor-mid.md"}
# Retired directories, walked file by file and never flagged whole. A retired skill's directory (a
# .claude/skills/<name>/ path above whose skill this version no longer ships) is walked the same way.
RETIRED_DIRS = (".agents", ".codex")


def _drop_route_lines(text: str) -> str:
    """An agent file's text without its frontmatter `model:` / `effort:` lines, the two sync-agents writes."""
    end = text.find("\n---\n", 4) if text.startswith("---\n") else -1
    if end == -1:
        return text
    head = [line for line in text[4:end].split("\n") if not line.startswith(("model:", "effort:"))]
    return "---\n" + "\n".join(head) + text[end:]


def _unrename(text: str, renames: dict) -> str:
    """Undo nested_rewrite's renames ({kind: {X: Y}}) in an installed text: every Y token back to X.
    Exact for our own texts, which never carry a `wf-` name of their own."""
    for table in renames.values():
        for x, y in table.items():
            text = re.sub(r"(?<![\w-])" + re.escape(y) + r"(?![\w-])", x, text)
    return text


def _retired_entry(key: str, renames: dict = None):
    """(stale reason, kept reason, hashes, normalizer or None) for a RETIRED_FILES path, else None.
    The normalizer maps a file's text to the text its hash is taken over: a RETIRED_ROUTE_LINES path
    drops its model:/effort: lines, and a nested copy installed under renames has them undone."""
    if key not in RETIRED_FILES:
        return None
    version, hashes = RETIRED_FILES[key]
    route_lines = key in RETIRED_ROUTE_LINES
    if not (route_lines or renames):
        return (f"unchanged since v{version}", f"differs from what v{version} shipped", hashes, None)

    def norm(text: str) -> str:
        text = _unrename(text, renames) if renames else text
        return _drop_route_lines(text) if route_lines else text
    aside = " (its model/effort lines aside)" if route_lines else ""
    return (f"unchanged since v{version}{aside}", f"differs from what v{version} shipped{aside}", hashes, norm)


# ---- --to-multi-repo <repo> (P40.S10): a per-repo nested install -> a multi-repo host at its parent ----
# convert_prepare() runs at the guards, before anything is written: every refusal (S2 §23, each naming its
# fix), then the plan for the old repo's side (which of its workspace files are ours and unchanged, what its
# settings.local.json, CLAUDE.local.md and info/exclude become, its leftover worktrees) and, with --dry-run,
# the full step list and exit 0. A real run then does steps 1-2 -- git init the parent (+ its empty commit),
# move the nested repo up a level -- which _nested_undo_init reverses should the --update's own planning
# still refuse. Step 3 is the plain --update at the parent (the rest of this program; nested_plan seeds the
# registry with the conversion's convention rule and appends `converted_from`, step 4). convert_finish()
# then maps the anchors with the freshly updated engine, cleans the old repo's side, lists its leftover
# worktrees and prints the closing block. Deletes only the workspace's own unchanged files, never touches a
# .claude/worktrees/ dir, runs no teardown and makes no nested commit.
CONVERT_COMMIT = "chore(works): convert to a multi-repo host"
CONVERT_PLAN = None
CONVENTION_KEYS = ("inferred", "confirmed", "text", "coauthor_trailers")   # == scripts/workflow.py NESTED_CONVENTION_KEYS


def _git_ro(path: Path, *args: str):
    """(returncode, stdout) of a read-only git query that must not even refresh the index (git status)."""
    proc = subprocess.run(["git", "-C", str(path), *args], capture_output=True, env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    return proc.returncode, proc.stdout.decode("utf-8", errors="replace")


def _read_text_or_none(p: Path):
    try:
        return p.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def _worktree_entries(repo: Path) -> list:
    """`git worktree list --porcelain` of `repo`, its main working tree first: [{path, branch, prunable}]."""
    rc, out = _git_in(repo, "worktree", "list", "--porcelain")
    entries = []
    for line in out.splitlines() if rc == 0 else []:
        if line.startswith("worktree "):
            entries.append({"path": line[len("worktree "):], "branch": None, "prunable": False})
        elif entries and line.startswith("branch "):
            entries[-1]["branch"] = line[len("branch "):].replace("refs/heads/", "", 1)
        elif entries and line.startswith("prunable"):
            entries[-1]["prunable"] = True
    return entries


def _without_block(text: str, begin: str, end: str):
    """(`text` without our managed block, the block's inner lines), or (text, None) when it holds none.
    Blank lines left at the end go with it (the separator _with_block put before an appended block). A
    stray or unterminated marker raises ValueError, as _with_block does: such a file is left as it is."""
    lines, out, inner, found, i = text.splitlines(), [], [], False, 0
    while i < len(lines):
        if lines[i].strip() == begin:
            j = next((k for k in range(i + 1, len(lines)) if lines[k].strip() == end), None)
            if j is None:
                raise ValueError(f"an unterminated {begin!r} line")
            inner += lines[i + 1:j]
            found, i = True, j + 1
            continue
        if lines[i].strip() == end:
            raise ValueError(f"a stray {end!r} line")
        out.append(lines[i])
        i += 1
    if not found:
        return text, None
    while out and not out[-1].strip():
        out.pop()
    return ("\n".join(out) + "\n") if out else "", inner


def _without_our_settings(theirs: dict, ours: dict) -> dict:
    """`theirs` (a settings.local.json) minus exactly the workspace's own entries: our permissions.allow /
    deny entries, our hook handlers (matched by command, a retired one too) and an autoCompactWindow at a
    value we shipped. A list, group, event or object the removal empties goes with it; every other key and
    entry stays as it is. `theirs` is not mutated."""
    out = copy.deepcopy(theirs)
    perms = out.get("permissions")
    if isinstance(perms, dict):
        for key in ("allow", "deny"):
            ours_k = (ours.get("permissions") or {}).get(key) or []
            cur = perms.get(key)
            if isinstance(cur, list) and any(x in ours_k for x in cur):
                kept = [x for x in cur if x not in ours_k]
                if kept:
                    perms[key] = kept
                else:
                    del perms[key]
        if not perms:
            del out["permissions"]
    our_cmds = {h.get("command") for groups in (ours.get("hooks") or {}).values() for g in groups for h in g.get("hooks", [])}
    hooks = out.get("hooks")
    if isinstance(hooks, dict):
        for event in list(hooks):
            groups = hooks[event]
            if not isinstance(groups, list):
                continue
            kept_groups = []
            for g in groups:
                inner = g.get("hooks") if isinstance(g, dict) else None
                if not isinstance(inner, list):
                    kept_groups.append(g)
                    continue
                keep = [h for h in inner if not (isinstance(h, dict) and isinstance(h.get("command"), str)
                                                 and (h["command"] in our_cmds or any(k in h["command"] for k in RETIRED_HOOK_COMMANDS)))]
                if len(keep) == len(inner):
                    kept_groups.append(g)
                elif keep:
                    kept_groups.append(dict(g, hooks=keep))
            if kept_groups:
                hooks[event] = kept_groups
            else:
                del hooks[event]
        if not hooks:
            del out["hooks"]
    window = out.get("autoCompactWindow")
    if isinstance(window, int) and not isinstance(window, bool) and (window in SHIPPED_COMPACT_WINDOWS or window == ours.get("autoCompactWindow")):
        del out["autoCompactWindow"]
    return out


def _same_as_retired(p: Path, entry) -> bool:
    """A RETIRED_FILES entry (_retired_entry) holds the hash of `p`'s text: ours, unchanged."""
    if entry is None or p.is_symlink() or not p.is_file():
        return False
    try:
        data = p.read_bytes()
        if entry[3] is not None:
            data = entry[3](data.decode("utf-8")).encode("utf-8")
    except (OSError, UnicodeDecodeError):
        return False
    return hashlib.sha256(data).hexdigest() in entry[2]


def _convert_classify(repo: Path, renames: dict, installed: dict) -> dict:
    """Step 6a, planned up front: the old repo's skill dirs and agent files its marker's `installed` lists,
    classified file by file as flag_retired_files does -- ours and unchanged (deleted) or yours (kept). Ours
    is this version's text under the install's renames (an agent's model:/effort: lines aside: sync-agents
    writes them) or, for a file this version does not ship, a text RETIRED_FILES knows. A skill dir's
    self-hiding .gitignore is ours only while every file beside it is; a directory goes once it is empty."""
    original = {k: {y: x for x, y in renames[k].items()} for k in NESTED_KINDS}
    undo = renames if any(renames.values()) else None
    hide = hashlib.sha256(NESTED_SKILL_GITIGNORE.encode("utf-8")).hexdigest()
    delete, kept, dirs, gone, shown = [], [], [], set(), []
    for name in installed.get("skills") or []:
        rel = f".claude/skills/{name}"
        d = repo / rel
        if _is_explain_path(rel) or not os.path.lexists(d):
            continue
        if d.is_symlink() or not d.is_dir():
            kept.append((rel, "not a directory the workspace wrote"))
            continue
        x = original["skills"].get(name, name)
        expected = {r[len(f".claude/skills/{x}/"):]: nested_rewrite(PAYLOADS[r], renames) for r in SKILL_FILES.get(x, [])}
        found = []
        for top, subdirs, files in os.walk(d):
            found += [Path(top) / n for n in subdirs if (Path(top) / n).is_symlink()] + [Path(top) / n for n in files]
        all_ours, guard, mine = True, None, []
        for f in sorted(found):
            inner = f.relative_to(d).as_posix()
            if inner == ".gitignore":
                guard = f
                continue
            if inner in expected:
                same = not f.is_symlink() and _read_text_or_none(f) == expected[inner]
                why = f"differs from what v{WORKSPACE_VERSION} installs"
            else:
                entry = _retired_entry(f".claude/skills/{x}/{inner}", undo)
                same = _same_as_retired(f, entry)
                why = entry[1] if entry else "not a file the workspace shipped"
            if same:
                mine.append(f)
            else:
                kept.append((f"{rel}/{inner}", why))
                all_ours = False
        if guard is not None:
            try:
                guard_ours = not guard.is_symlink() and hashlib.sha256(guard.read_bytes()).hexdigest() == hide
            except OSError:
                guard_ours = False
            if all_ours and guard_ours:
                mine.append(guard)
            else:
                kept.append((f"{rel}/.gitignore", "it hides the files kept beside it" if guard_ours else "differs from the .gitignore the workspace wrote"))
                all_ours = False
        delete += mine
        dirs.append(d)
        if all_ours:
            gone.add(rel)
            shown.append(f"{rel}/")
        else:
            shown += [f.relative_to(repo).as_posix() for f in mine]
    for name in installed.get("agents") or []:
        rel = f".claude/agents/{name}.md"
        p = repo / rel
        if _is_explain_path(rel) or not os.path.lexists(p):
            continue
        x = original["agents"].get(name, name)
        if x in NESTED_AGENTS:
            text = _read_text_or_none(p) if p.is_file() and not p.is_symlink() else None
            same = text is not None and _drop_route_lines(text) == _drop_route_lines(nested_rewrite(PAYLOADS[f".claude/agents/{x}.md"], renames))
            why = f"differs from what v{WORKSPACE_VERSION} installs (its model/effort lines aside)"
        else:
            entry = _retired_entry(f".claude/agents/{x}.md", undo)
            same = _same_as_retired(p, entry)
            why = entry[1] if entry else "not a file the workspace shipped"
        if same:
            delete.append(p)
            gone.add(rel)
            shown.append(rel)
        else:
            kept.append((rel, why))
    return {"delete": delete, "dirs": dirs, "kept": kept, "gone": gone, "shown": shown}


def _convert_plan_files(repo: Path, renames: dict, gone: set, leftovers: list) -> dict:
    """Steps 6b-6d, planned up front: {key: (path, action, new text or None, why)} for the old repo's
    settings.local.json, CLAUDE.local.md and info/exclude; action is delete | rewrite | keep | none."""
    plan = {}
    p = repo / ".claude" / "settings.local.json"
    if not os.path.lexists(p):
        plan["settings"] = (p, "none", None, "absent")
    else:
        try:
            theirs = json.loads(p.read_text(encoding="utf-8"))
            if not isinstance(theirs, dict):
                raise ValueError("not a JSON object")
        except (OSError, ValueError) as exc:
            plan["settings"] = (p, "keep", None, f"cannot be read as JSON ({exc}): left exactly as it is")
        else:
            stripped = _without_our_settings(theirs, json.loads(nested_rewrite(PAYLOADS[".claude/settings.json"], renames)))
            if not stripped:
                plan["settings"] = (p, "delete", None, "deleted: it held only the workspace's entries")
            elif stripped == theirs:
                plan["settings"] = (p, "keep", None, "holds none of the workspace's entries: left as it is")
            else:
                plan["settings"] = (p, "rewrite", json.dumps(stripped, ensure_ascii=False, indent=2) + "\n",
                                    f"the workspace's entries removed, yours kept ({', '.join(sorted(stripped))})")
    p = repo / "CLAUDE.local.md"
    text = _read_text_or_none(p) if p.is_file() and not p.is_symlink() else None
    if text is None:
        plan["local"] = (p, "none", None, "absent") if not os.path.lexists(p) else (p, "keep", None, "not a text file: left as it is")
    else:
        try:
            rest, inner = _without_block(text, NESTED_LOCAL_BEGIN, NESTED_LOCAL_END)
        except ValueError as exc:
            plan["local"] = (p, "keep", None, f"its managed block cannot be read ({exc}): left exactly as it is")
        else:
            if inner is None:
                plan["local"] = (p, "keep", None, "holds no managed block: left as it is")
            elif not rest.strip():
                plan["local"] = (p, "delete", None, "deleted: it held only the managed block")
            else:
                plan["local"] = (p, "rewrite", rest, "the managed block removed, your own lines kept")
    gone = set(gone) | {NESTED_DIR}
    if plan["settings"][1] == "delete":
        gone.add(".claude/settings.local.json")
    if plan["local"][1] == "delete":
        gone.add("CLAUDE.local.md")
    rc, out = _git_in(repo, "rev-parse", "--git-path", "info/exclude")
    p = Path(out.strip()) if rc == 0 and out.strip() else repo / ".git" / "info" / "exclude"
    p = p if p.is_absolute() else repo / p
    text = _read_text_or_none(p) if p.is_file() else None
    if text is None:
        plan["exclude"] = (p, "none", None, "absent")
        return plan
    try:
        rest, inner = _without_block(text, NESTED_EXCLUDE_BEGIN, NESTED_EXCLUDE_END)
    except ValueError as exc:
        plan["exclude"] = (p, "keep", None, f"its managed block cannot be read ({exc}): left exactly as it is")
        return plan
    if inner is None:
        plan["exclude"] = (p, "none", None, "holds no managed block")
    elif leftovers:
        # Never the worktrees line while leftover worktrees exist; the whole block stays, since it also hides
        # the workspace files a leftover host worktree carries (its CLAUDE.local.md copy, its workflow/).
        plan["exclude"] = (p, "keep", None, "the managed block kept whole while the leftover worktrees below exist (it hides "
                                             ".claude/worktrees/ and the workspace files they hold): remove it by hand once they are gone")
    else:
        # What the block hid and is still there (yours, kept) stays hidden: the block keeps exactly those lines.
        left = [ln.strip() for ln in inner if ln.strip()]
        left = [ln for ln in left if ln.strip("/") != ".claude/worktrees" and ln.strip("/") not in gone
                and os.path.lexists(repo / ln.strip("/"))]
        if left:
            plan["exclude"] = (p, "rewrite", _with_block(text, NESTED_EXCLUDE_BEGIN, NESTED_EXCLUDE_END, [NESTED_EXCLUDE_BEGIN, *left, NESTED_EXCLUDE_END]),
                               f"the managed block now hides only what is left of yours ({' '.join(left)})")
        else:
            plan["exclude"] = (p, "rewrite", rest, "the managed block removed")
    return plan


def _convert_leftovers(repo: Path) -> list:
    """Step 7, read up front: the old repo's worktrees besides its main checkout, and every entry under its
    .claude/worktrees/ that is not one of them. Listed, never deleted."""
    lines, seen = [], set()
    for e in _worktree_entries(repo)[1:]:
        seen.add(os.path.realpath(e["path"]))
        lines.append(f"{e['path']} ({'branch ' + e['branch'] if e['branch'] else 'detached'}"
                     + (", prunable: its directory is gone)" if e["prunable"] else ")"))
    wt = repo / ".claude" / "worktrees"
    if wt.is_dir() and not wt.is_symlink():
        for d in sorted(wt.iterdir(), key=lambda e: e.name):
            if os.path.realpath(d) not in seen:
                lines.append(f"{d} (under .claude/worktrees/, not a registered worktree)")
    return lines


def _convert_phases(nested: Path, repo: Path) -> list:
    """The dry run's step 5: (phase label, whether --map-anchors maps it) for each phase with host_anchors shas."""
    out = []
    for state in ("active", "archived"):
        for pj in sorted((nested / "works" / "phases" / state).glob("*/phase.json")):
            try:
                data = json.loads(pj.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            anchors = data.get("host_anchors") if isinstance(data, dict) else None
            shas = [anchors.get(k) for k in ("created", "review_pass", "review_base")] if isinstance(anchors, dict) else []
            shas = [s for s in shas if isinstance(s, str) and s]
            if shas:
                out.append((f"{data.get('id', pj.parent.name)}{' (archived)' if state == 'archived' else ''}",
                            all(_is_commit(repo, s) for s in shas)))
    return out


def _convert_unignored(parent: Path, exclude, names: list, old: dict) -> list:
    """nested_plan's ignore preflight, asked BEFORE the git init and the move, so its refusal is one more
    pre-write refusal: a throwaway repo in the system temp dir models the parent after the init (its
    .gitignore copied, and the info/exclude it has now when it is a repo already), with workflow/ and each
    repo to register as directories; the same targets and exclude entries as nested_plan's are asked of
    _nested_unignored there. Every other ignore source is refused as a stray before this runs (.claude/,
    CLAUDE.local.md and any other non-repo entry) or does not exist yet. [(target, reason)]."""
    global HOST, ROOT
    raw_renames = old.get("renames") if isinstance(old.get("renames"), dict) else {}
    named = {}
    for kind, shipped in (("skills", CLAUDE_SKILLS), ("agents", NESTED_AGENTS)):
        table = raw_renames.get(kind) if isinstance(raw_renames.get(kind), dict) else {}
        named[kind] = [table[x] if isinstance(table.get(x), str) and table.get(x) else x for x in shipped]
    exclude_entries = [f"/{NESTED_DIR}/", "/CLAUDE.local.md", "/.claude/settings.local.json", "/.claude/worktrees/"]
    exclude_entries += [f"/.claude/skills/{n}/" for n in sorted(named["skills"])]
    exclude_entries += [f"/.claude/agents/{n}.md" for n in sorted(named["agents"])]
    exclude_entries += [f"/{n}/" for n in names]
    # The parent has no .claude/ (a stray, refused), so every skill dir is absent and hides itself (nested_plan's self_hiding).
    check_paths = [f".claude/agents/{n}.md" for n in sorted(named["agents"])] + ["CLAUDE.local.md", ".claude/settings.local.json", NESTED_DIR] + list(names)
    model = Path(tempfile.mkdtemp(prefix="agentic-convert-"))
    saved = (HOST, ROOT)
    try:
        if subprocess.run(["git", "init", "-q", str(model)], capture_output=True).returncode != 0:
            return [("(the check)", "git init of a throwaway repo in the system temp dir failed, so the parent's ignore rules cannot be checked")]
        ignore = parent / ".gitignore"
        if ignore.is_file():
            shutil.copyfile(ignore, model / ".gitignore")
        if exclude is not None and exclude.is_file():
            (model / ".git" / "info").mkdir(parents=True, exist_ok=True)   # an init template may lack info/
            shutil.copyfile(exclude, model / ".git" / "info" / "exclude")
        for n in names:
            (model / n).mkdir()
        HOST, ROOT = model, model / NESTED_DIR
        return _nested_unignored(check_paths, exclude_entries, list(names))
    except OSError as exc:
        return [("(the check)", f"the throwaway model of the parent could not be built ({exc})")]
    finally:
        HOST, ROOT = saved
        shutil.rmtree(model, ignore_errors=True)


def convert_prepare() -> None:
    """--to-multi-repo: every refusal and the plan, nothing written; --dry-run prints the step list and exits
    0. A real run then git-inits the parent (+ the empty commit) and moves the nested repo up a level."""
    global CONVERT_PLAN, _HOST_INIT_UNDO, _CONVERT_UNDO
    repo, parent = CONVERT_REPO, HOST
    nested, target = repo / NESTED_DIR, parent / NESTED_DIR
    q = lambda p: shlex.quote(str(p))   # noqa: E731
    engine = f"python3 {NESTED_DIR}/scripts/workflow.py"

    def refuse(*problems: str) -> None:
        _nested_refuse(f"--to-multi-repo {repo}: refused, nothing written:", *[f"  - {p}" for p in problems])

    # Stage 1: is there a per-repo nested install to convert (each check needs the one before it).
    if shutil.which("git") is None:
        refuse("the conversion needs git on PATH: install git, then re-run.")
    if not _is_repo_dir(repo):
        refuse(f"{repo} is not the root of a git repo: name the repo whose per-repo nested install is <repo>/{NESTED_DIR}/.")
    if _at_root_workspace_in(repo):
        refuse(f"{repo} holds an at-root workspace (scripts/workflow.py plus works/, committed in the repo): only a private "
               "per-repo nested install converts; an at-root workspace has no conversion path.")
    marker_path = nested / NESTED_MARKER
    if not marker_path.is_file() or not (nested / "scripts" / "workflow.py").is_file():
        refuse(f"{repo} has no per-repo nested install ({NESTED_DIR}/{NESTED_MARKER} and {NESTED_DIR}/scripts/workflow.py): nothing to "
               "convert. A fresh install into a folder that holds only repos makes a multi-repo host.")
    try:
        old = json.loads(marker_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        old = None
        refuse(f"{NESTED_DIR}/{NESTED_MARKER} cannot be read as JSON ({exc}): fix it (cd {q(repo)} && {engine} validate), then re-run.")
    if not isinstance(old, dict):
        refuse(f"{NESTED_DIR}/{NESTED_MARKER} is not a JSON object: fix it (cd {q(repo)} && {engine} validate), then re-run.")
    if "repos" in old:
        refuse(f"{nested} already belongs to a multi-repo host (its marker holds a repos registry): nothing to convert.")
    conv = old.get("commit_convention")
    if not (isinstance(conv, dict) and sorted(conv) == sorted(CONVENTION_KEYS)):
        refuse("the marker's commit_convention is not the four-key object the old repo's convention moves as: fix it "
               f"(cd {q(repo)} && {engine} validate names the problem), then re-run.")
    try:
        version = json.loads((nested / "works" / ".workspace-version.json").read_text(encoding="utf-8")).get("workspace_version")
    except (OSError, ValueError, AttributeError):
        version = None
    raw_installed = old.get("installed")
    if not (isinstance(raw_installed, dict) and all(isinstance(raw_installed.get(k), list) for k in NESTED_KINDS)):
        refuse(f"the marker's `installed` (the skill and agent copies this install wrote) is missing or malformed, so the cleanup cannot "
               f"tell the workspace's files from yours: refresh the install (sh bootstrap_agentic_workspace.sh --update {q(repo)}, then "
               f"commit it in {q(nested)}), then re-run.")
    if version != WORKSPACE_VERSION:
        refuse(f"{nested} is at {'workspace v' + str(version) if isinstance(version, int) else 'an unknown workspace version'} and this "
               f"installer is v{WORKSPACE_VERSION}: refresh it first, so the cleanup can tell the workspace's unchanged files from "
               f"yours (sh bootstrap_agentic_workspace.sh --update {q(repo)}, then git -C {q(nested)} add -A && git -C {q(nested)} "
               f"commit -m \"chore: update agentic workspace to v{WORKSPACE_VERSION} (nested)\"); then re-run.")
    if not _is_repo_dir(nested):
        refuse(f"{nested} is not a git repo of its own: its history is the conversion's backup and rollback; give it one "
               f"(git -C {q(nested)} init, then add -A and commit), then re-run.")

    # Stage 2: everything else, collected, so one run names every fix.
    problems = []
    for pj in sorted((nested / "works" / "phases" / "active").glob("*/phase.json")):
        try:
            data = json.loads(pj.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        ex = data.get("execution") if isinstance(data, dict) else None
        if isinstance(ex, dict) and (ex.get("worktree") or ex.get("host_worktree")):
            pid = data.get("id", pj.parent.name)
            problems.append(f"{pid} is in flight in a worktree pair ({ex.get('host_worktree') or ex.get('worktree')}), which the move would "
                            f"orphan: finish and tear it down first (cd {q(repo)} && {engine} parallel-teardown {pid}), then re-run.")
    linked = _worktree_entries(nested)[1:]
    if linked:
        problems.append(f"the nested repo has linked worktrees the move would orphan ({', '.join(e['path'] for e in linked)}): finish and "
                        f"remove them (git -C {q(nested)} worktree remove <path>; worktree prune for one whose directory is gone), then re-run.")
    rc, out = _git_ro(nested, "status", "--porcelain")
    if rc != 0 or out.strip():
        problems.append(f"the nested repo {nested} has uncommitted changes{'' if rc == 0 else ' (git status failed)'}: commit them first "
                        f"(git -C {q(nested)} add -A && git -C {q(nested)} commit -m \"<summary>\"), so the conversion is one commit away "
                        "from its rollback; then re-run.")
    # The --update at the parent ends in the engine's validate; a failure there would stop the conversion after
    # the move. validate only reads, so ask the install's own engine now.
    proc = subprocess.run([sys.executable, str(nested / "scripts" / "workflow.py"), "validate"], cwd=str(repo),
                          capture_output=True, stdin=subprocess.DEVNULL)
    if proc.returncode != 0:
        said = [ln.strip().lstrip("- ") for ln in (proc.stdout + proc.stderr).decode("utf-8", errors="replace").splitlines()
                if ln.strip() and not ln.startswith("Workflow validation failed")]
        problems.append(f"the install's validate fails ({'; '.join(said[:4]) + ('; ...' if len(said) > 4 else '') or 'exit ' + str(proc.returncode)}): "
                        f"fix it first (cd {q(repo)} && {engine} validate), commit the fix in the nested repo, then re-run.")
    top = _work_tree_top(parent)
    parent_git, exclude = None, None
    if top is not None and top != parent.resolve():
        problems.append(f"the parent {parent} is inside the work tree of {top}: a multi-repo host is a folder of its own, outside every "
                        "repo; move the repos into such a folder, then re-run.")
    elif top is not None:
        rc, out = _git_in(parent, "ls-files", "-z")
        if rc != 0 or out.strip("\0"):
            problems.append(f"the parent {parent} is a git repo that tracks files: a multi-repo host tracks nothing; untrack them (or move "
                            "the repos into a folder of their own), then re-run.")
        parent_git = "history" if _git_in(parent, "rev-parse", "-q", "--verify", "HEAD")[0] == 0 else "empty"
        rc, out = _git_in(parent, "rev-parse", "--git-path", "info/exclude")
        exclude = Path(out.strip()) if rc == 0 and out.strip() else None
        exclude = exclude if exclude is None or exclude.is_absolute() else parent / exclude
        try:
            _with_block(exclude.read_text(encoding="utf-8") if exclude is not None and exclude.is_file() else "",
                        NESTED_EXCLUDE_BEGIN, NESTED_EXCLUDE_END, [])
        except (OSError, ValueError) as exc:
            problems.append(f"{exclude} cannot take the managed block ({exc}): fix it, then re-run.")
    elif os.path.lexists(parent / ".git"):
        problems.append(f"{parent}/.git exists, but git does not read {parent} as a work tree: repair or remove it, then re-run.")
    if os.path.lexists(target):
        problems.append(f"{target} already exists: a host has room for one nested workspace, at {NESTED_DIR}/; move it away, then re-run.")
    local_parent = parent / "CLAUDE.local.md"
    local_block = local_parent.is_file() and any(ln.strip() == NESTED_LOCAL_BEGIN for ln in (_read_text_or_none(local_parent) or "").splitlines())
    if local_block:
        problems.append(f"{local_parent} holds a nested install's managed block: the parent is no fresh host; remove the block (or the "
                        "file), then re-run.")
    strays, unnamed = [], []
    for e in sorted(parent.iterdir(), key=lambda e: e.name):
        if e.name in EMPTY_OK_ALLOWLIST or e.name in (NESTED_DIR, repo.name) or (local_block and e.name == "CLAUDE.local.md"):
            continue
        if _is_repo_dir(e):
            if not _registrable_name(e.name):
                unnamed.append(f"{e.name}/")
        else:
            strays.append(e.name + ("/" if e.is_dir() and not e.is_symlink() else ""))
    if strays:
        problems.append(f"{parent} holds entries that are not product repos ({', '.join(strays)}): a multi-repo host holds only repos at "
                        "depth 1 (plus files such as .DS_Store, README.md or .gitignore); move them out, then re-run.")
    if unnamed:
        problems.append(f"{', '.join(unnamed)} {'is a git repo whose folder name' if len(unnamed) == 1 else 'are git repos whose folder names'} "
                        "the registry cannot take ([A-Za-z0-9._-]+, not workflow or .claude): rename the folder, then re-run.")
    if not _registrable_name(repo.name):
        problems.append(f"the old repo's folder name {repo.name!r} cannot be a registry name ([A-Za-z0-9._-]+, not workflow or .claude): "
                        "rename the folder, then re-run.")
    installed = {k: [n for n in raw_installed[k] if isinstance(n, str) and n] for k in NESTED_KINDS}
    names = sorted({n for n in _child_repo_dirs(parent) if _registrable_name(n)} | ({repo.name} if _registrable_name(repo.name) else set()))
    for n in names:
        tracked = _tracked_workspace_files(parent / n, installed)
        if tracked:
            problems.append(f"{n}/ tracks {', '.join(tracked)}, which the workspace owns (the engine's validate rejects a registered repo "
                            f"that does): untrack {'it' if len(tracked) == 1 else 'them'} (git -C {q(parent / n)} rm -r --cached -- "
                            f"{' '.join(tracked)}), then re-run.")
    # The --update's ignore preflight, asked now: its refusal would otherwise come after the init and the move.
    # Its model needs a parent that is (or will be) a work tree root of its own and holds no stray entry.
    if not strays and (top is None or top == parent.resolve()) and (top is not None or not os.path.lexists(parent / ".git")):
        unignored = _convert_unignored(parent, exclude, names, old)
        if unignored:
            problems.append("the parent's ignore rules would leave files of the host install visible to git, so it cannot stay "
                            f"private ({'; '.join(f'{t}: {why}' for t, why in unignored)}): a .gitignore (or an info/exclude line) "
                            f"in {parent} re-includes them, and .git/info/exclude, where the install hides its files, ranks below "
                            "every .gitignore; fix it, then re-run.")
    if problems:
        refuse(*problems)

    # The plan for the old repo's side (read-only); then the dry run, or steps 1-2.
    raw_renames = old.get("renames") if isinstance(old.get("renames"), dict) else {}
    renames = {k: ({x: y for x, y in raw_renames[k].items() if isinstance(y, str) and y} if isinstance(raw_renames.get(k), dict) else {})
               for k in NESTED_KINDS}
    leftovers = _convert_leftovers(repo)
    classified = _convert_classify(repo, renames, installed)
    CONVERT_PLAN = {"repo": repo, "parent": parent, "name": repo.name, "nested": nested, "target": target, "names": names,
                    "convention": copy.deepcopy(conv), "parent_git": parent_git, "inited": False, "leftovers": leftovers,
                    "classified": classified, "files": _convert_plan_files(repo, renames, classified["gone"], leftovers),
                    "writing": False, "finished": False}
    if DRY_RUN:
        _convert_print_dry_run(renames, _convert_phases(nested, repo))
        sys.exit(0)
    if parent_git is None:
        _HOST_INIT_UNDO = (parent / ".git", [])
        CONVERT_PLAN["inited"] = True
        proc = subprocess.run(["git", "init", "-q", str(parent)], capture_output=True)
        if proc.returncode != 0:
            refuse(f"git init in {parent} failed (exit {proc.returncode}: {proc.stderr.decode('utf-8', 'replace').strip()}).")
        _host_first_commit()
    try:
        os.rename(nested, target)
    except OSError as exc:
        refuse(f"cannot move {nested} to {target} ({exc}): the repos must be on one filesystem with their parent; then re-run.")
    _CONVERT_UNDO = (target, nested)


def _convert_shown(p: Path) -> str:
    plan = CONVERT_PLAN
    try:
        return f"{plan['name']}/{p.relative_to(plan['repo']).as_posix()}"
    except ValueError:
        return str(p)


def _convert_cleanup_lines(past: bool) -> list:
    """Step 6 in words: what goes and what stays on the old repo's side."""
    plan = CONVERT_PLAN
    name, c = plan["name"], plan["classified"]
    lines = []
    if c["shown"]:
        lines.append(f"{'deleted' if past else 'delete'} the workspace's own copies, unchanged ({len(c['delete'])} file(s)):")
        lines += [f"  - {name}/{rel}" for rel in c["shown"]]
    if c["kept"]:
        lines.append(f"yours, kept ({len(c['kept'])}):")
        lines += [f"  - {name}/{rel}  ({why})" for rel, why in c["kept"]]
    for key in ("settings", "local", "exclude"):
        p, action, _, why = plan["files"][key]
        if action != "none" or key == "exclude":
            lines.append(f"{_convert_shown(p)}: {why}")
    return lines


def _convert_print_dry_run(renames: dict, phases: list) -> None:
    plan = CONVERT_PLAN
    repo, parent, name, nested, target, conv = plan["repo"], plan["parent"], plan["name"], plan["nested"], plan["target"], plan["convention"]
    others = [n for n in plan["names"] if n != name]
    print(f"DRY RUN (--to-multi-repo --dry-run): convert {repo}'s per-repo nested install into a multi-repo host at {parent} -- nothing written.")
    if plan["parent_git"] is None:
        print(f"  1. git init {parent}, then its one commit, the empty \"{HOST_FIRST_COMMIT}\" (with no git identity: the init, and the commands to make it)")
    else:
        print(f"  1. {parent} is already a git repo that tracks nothing: its history is kept, no commit made"
              + ("" if plan["parent_git"] == "history" else " (it has none yet: the closing block prints the one to make)"))
    print(f"  2. move {nested} -> {target} (the nested repo, with its history and branches)")
    print(f"  3. the plain --update at {parent} (what a separate --update there would write):")
    for s in sorted(renames["skills"].get(x, x) for x in CLAUDE_SKILLS):
        print(f"       + {parent}/.claude/skills/{s}/ (with its self-hiding .gitignore)")
    for a in sorted(renames["agents"].get(x, x) for x in NESTED_AGENTS):
        print(f"       + {parent}/.claude/agents/{a}.md")
    print(f"       + {parent}/.claude/settings.local.json")
    print(f"       + {parent}/CLAUDE.local.md (the multi-repo block, with: Records from before <today> name product paths relative to `{name}/`.)")
    print(f"       ~ {parent}/.git/info/exclude (the managed block, with {' '.join('/' + n + '/' for n in plan['names'])})")
    print(f"       ~ {target}/: the machinery every --update refreshes, then rebuild and validate")
    print(f"       ~ {target}/{NESTED_MARKER}: repos {', '.join(plan['names'])}; {name} keeps the old convention verbatim "
          f"({'confirmed' if conv.get('confirmed') is True else 'UNCONFIRMED'}, coauthor_trailers={conv.get('coauthor_trailers')})"
          + (f"; {', '.join(others)} {'gets its' if len(others) == 1 else 'each get their'} own, inferred and UNCONFIRMED" if others else "")
          + "; the host-level convention (the rules for every repo) UNCONFIRMED, nothing inferred")
    print(f"  4. converted_from in {target}/{NESTED_MARKER}: {{\"repo\": \"{name}\", \"old_nested\": \"{name}/{NESTED_DIR}\", \"at\": \"<today>\"}}")
    print(f"  5. map the anchors: python3 {NESTED_DIR}/scripts/workflow.py nested-repos --map-anchors {name} (writes phase.json files only)")
    for label, maps in phases:
        print(f"       {label}: " + (f"host_anchors -> repo_anchors.{name}" if maps else f"skipped: its host_anchors are not commits of {name}"))
    if not phases:
        print("       no phase holds host_anchors shas: nothing to map")
    print(f"  6. clean {repo} (only the workspace's own, unchanged files go; nothing of yours is deleted):")
    for line in _convert_cleanup_lines(past=False):
        print(f"       {line}")
    print(f"  7. leftover worktrees of {repo}, listed and never deleted:" + ("" if plan["leftovers"] else " none"))
    for line in plan["leftovers"]:
        print(f"       - {line}")
    print(f"  8. the closing block: the nested commit to make (\"{CONVERT_COMMIT}\"), the conventions to confirm, the rollback")
    print("Re-run without --dry-run to apply.")


def _convert_rollback_lines(halted: bool = False) -> list:
    """The rollback, as commands: after the nested commit (revert, mv back, --update the old repo), or, for a
    run that stopped before cleaning the old repo (`halted`), the uncommitted reset and the mv alone."""
    plan = CONVERT_PLAN
    q = lambda p: shlex.quote(str(p))   # noqa: E731
    target, parent = plan["target"], plan["parent"]
    # clean -f without -d: the files the run added go, and the empty directories the install keeps stay.
    reset = f"git -C {q(target)} reset -q --hard && git -C {q(target)} clean -qf"
    if halted:
        lines = [f"  {reset}", f"  mv {q(target)} {q(plan['nested'])}"]
    else:
        lines = [f"  git -C {q(target)} revert --no-edit \"$(git -C {q(target)} log -1 --format=%H -F --grep='{CONVERT_COMMIT}')\"",
                 f"  (before that commit is made, instead: {reset})",
                 f"  mv {q(target)} {q(plan['nested'])}",
                 f"  sh bootstrap_agentic_workspace.sh --update {q(plan['repo'])}"]
        if any(rel.startswith(".claude/") for rel, _ in plan["classified"]["kept"]):
            lines.append(f"  (that --update rewrites {plan['name']}'s installed skills and agents, as every --update does: copy aside the ones listed as yours first)")
    lines.append(f"  then the host's own files are yours to delete: rm -rf {q(parent / '.claude/skills')} {q(parent / '.claude/agents')} && "
                 f"rm -f {q(parent / '.claude/settings.local.json')} {q(parent / 'CLAUDE.local.md')} && rmdir {q(parent / '.claude')}"
                 + (f", and the .git this conversion made: rm -rf {q(parent / '.git')}" if plan["inited"] else ""))
    return lines


def _convert_halted() -> None:
    """atexit, once writing started: a run that stops before convert_finish ends says where it stopped and how
    to roll back (the old repo is not cleaned yet, so the mv back restores it). Never a plain --update at the
    parent: its registry rule is not the conversion's."""
    plan = CONVERT_PLAN
    if not plan or not plan["writing"] or plan["finished"]:
        return
    print(f"Error: --to-multi-repo stopped after the move, before the old repo was cleaned ({plan['nested']} is now {plan['target']}; "
          f"nothing in {plan['repo']} was deleted). Roll back, fix what is said above, then re-run --to-multi-repo:", file=sys.stderr)
    for line in _convert_rollback_lines(halted=True):
        print(line, file=sys.stderr)


def convert_start_writing() -> None:
    """At the guards, past every refusal: the first write is next. Steps 1-2 as done, before the --update's report."""
    import atexit
    plan = CONVERT_PLAN
    plan["writing"] = True
    atexit.register(_convert_halted)
    print(f"Converting {plan['repo']}'s per-repo nested install into a multi-repo host at {plan['parent']} (--to-multi-repo)")
    if plan["inited"] and HOST_COMMIT_ERROR is None:
        print(f"  1. host: git init {plan['parent']}, and its one commit, the empty \"{HOST_FIRST_COMMIT}\"")
    elif plan["inited"]:
        print(f"  1. host: git init {plan['parent']}; git could not make its first commit ({HOST_COMMIT_ERROR}): the commands are in Next")
    else:
        print(f"  1. host: {plan['parent']} was already a git repo that tracks nothing: its history kept, no commit made")
    print(f"  2. moved {plan['nested']} -> {plan['target']} (the nested repo, with its history and branches)")
    print(f"  3. the plain --update at {plan['parent']}:", flush=True)   # before the engine's own output (rebuild, validate)


def _convert_apply_cleanup() -> list:
    """Step 6: the workspace's own unchanged files, then our settings entries, then the CLAUDE.local.md
    block, then the exclude block -- in that order, so nothing turns visible on the way. Only empty
    directories go. Never raises: a failure is collected, and the rest still runs."""
    plan = CONVERT_PLAN
    repo, c, errors = plan["repo"], plan["classified"], []
    for f in c["delete"]:
        try:
            os.unlink(f)
        except OSError as exc:
            errors.append(f"could not delete {f} ({exc})")
    for d in c["dirs"]:
        subdirs = sorted((p for p in d.rglob("*") if p.is_dir() and not p.is_symlink()), key=lambda p: len(p.parts), reverse=True)
        for sub in subdirs + [d]:
            try:
                sub.rmdir()   # an empty directory only: one that still holds anything stays
            except OSError:
                pass
    for key in ("settings", "local", "exclude"):
        p, action, text, _ = plan["files"][key]
        try:
            if action == "delete":
                os.unlink(p)
            elif action == "rewrite":
                mode = stat.S_IMODE(p.stat().st_mode)
                _atomic_write(p, text)
                os.chmod(p, mode)
        except OSError as exc:
            errors.append(f"could not {'delete' if action == 'delete' else 'rewrite'} {p} ({exc})")
        if key == "settings":
            for d in (repo / ".claude" / "skills", repo / ".claude" / "agents", repo / ".claude"):
                try:
                    d.rmdir()
                except OSError:
                    pass
    return errors


def convert_finish() -> None:
    """Steps 4-8, after the plain --update at the parent: report converted_from, map the anchors with the
    freshly updated engine, clean the old repo's side, list its leftover worktrees, print the closing block."""
    plan = CONVERT_PLAN
    repo, parent, name, target = plan["repo"], plan["parent"], plan["name"], plan["target"]
    engine = f"python3 {NESTED_DIR}/scripts/workflow.py"
    q = lambda p: shlex.quote(str(p))   # noqa: E731
    failed = []
    try:
        marker = json.loads((ROOT / NESTED_MARKER).read_text(encoding="utf-8"))
        entry = marker["converted_from"][-1]
        print(f"  4. converted_from: {json.dumps(entry, ensure_ascii=False)} ({NESTED_DIR}/{NESTED_MARKER}; CLAUDE.local.md now says "
              f"records from before {entry['at']} name product paths relative to {name}/)")
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        marker = {}
        failed.append(f"converted_from could not be read back from {ROOT / NESTED_MARKER} ({exc})")
    print(f"  5. anchors: {engine} nested-repos --map-anchors {name}")
    proc = subprocess.run([sys.executable, str(ROOT / "scripts" / "workflow.py"), "nested-repos", "--map-anchors", name],
                          cwd=str(HOST), capture_output=True, stdin=subprocess.DEVNULL)
    for line in (proc.stdout + proc.stderr).decode("utf-8", errors="replace").splitlines():
        print(f"       {line}")
    if proc.returncode != 0:
        failed.append(f"the anchor mapping exited {proc.returncode} (nothing was rolled back): fix what it says, then re-run it: "
                      f"cd {q(parent)} && {engine} nested-repos --map-anchors {name}")
    print(f"  6. cleaned {repo} (only the workspace's own, unchanged files went; nothing of yours was deleted):")
    for line in _convert_cleanup_lines(past=True):
        print(f"       {line}")
    errors = _convert_apply_cleanup()
    for e in errors:
        print(f"       error: {e}")
    if errors:
        failed.append(f"{len(errors)} cleanup step(s) in {repo} failed (above): finish them by hand")
    print(f"  7. leftover worktrees of {repo}, listed and never deleted:" + ("" if plan["leftovers"] else " none"))
    for line in plan["leftovers"]:
        print(f"       - {line}")
    if plan["leftovers"]:
        print(f"       they are yours: integrate or remove each (git -C {q(repo)} worktree remove <path>), then {name}'s exclude block by hand")
    if plan["files"]["local"][1] == "rewrite":
        print(f"  note: {name}/CLAUDE.local.md keeps your own lines; a session started at {parent} reads {parent}/CLAUDE.local.md: "
              "move what still applies there, above its managed block")
    print(f"Next (from {parent}: start Claude Code there from now on, never inside {NESTED_DIR}/ or a repo):")
    step = 1
    if (plan["inited"] and HOST_COMMIT_ERROR is not None) or plan["parent_git"] == "empty":
        print(f"  {step}. Give the host its first commit, which new-phase and parallel-start base on"
              + (" (git has no identity: set one globally first, so the nested commit below works too):" if HOST_COMMIT_ERROR else ":"))
        if HOST_COMMIT_ERROR:
            print("       git config --global user.name \"<your name>\" && git config --global user.email \"<you@example.com>\"")
        print(f"       git -C {q(parent)} commit --allow-empty -m \"{HOST_FIRST_COMMIT}\"")
        step += 1
    print(f"  {step}. Commit the conversion in the nested repo: git -C {q(target)} add -A && git -C {q(target)} commit -m \"{CONVERT_COMMIT}\"")
    step += 1
    print(f"  {step}. Confirm the conventions that bind every repo (UNCONFIRMED, nothing inferred) before the first product commit: "
          f"{engine} nested-convention (then --confirm --text \"<conventions>\" --trailers allowed|forbidden); each repo's own:")
    for r in marker.get("repos") or [] if isinstance(marker.get("repos"), list) else []:
        rc = r.get("commit_convention") if isinstance(r, dict) else None
        if isinstance(rc, dict) and rc.get("confirmed") is True:
            print(f"       {r.get('name')}: confirmed, moved from the old install (coauthor_trailers={rc.get('coauthor_trailers')}); "
                  f"{engine} nested-convention --repo {r.get('name')} shows it")
        elif isinstance(rc, dict):
            print(f"       {r.get('name')}: UNCONFIRMED -- {engine} nested-convention --confirm --repo {r.get('name')} --text \"<conventions>\" "
                  "--trailers allowed|forbidden")
    step += 1
    print(f"  {step}. Re-apply your executors.toml route overrides to the new agent files: {engine} sync-agents")
    print("Rollback (the nested repo's history is the backup; the installer deletes none of this):")
    for line in _convert_rollback_lines():
        print(line)
    plan["finished"] = True
    if failed:
        print("Error: --to-multi-repo did not finish:", file=sys.stderr)
        for f in failed:
            print(f"  - {f}", file=sys.stderr)
        sys.exit(1)
    print(f"Converted: {parent} is a multi-repo host over {', '.join(r.get('name', '?') for r in marker.get('repos') or [] if isinstance(r, dict))}.")


# ---- Guards -----------------------------------------------------------------
NESTED_PLAN = None
if NESTED:
    # Before anything is written, workflow/ included: the host checks (a fresh install into a new or
    # empty target `git init`s it first), then the whole host-side render with its post-check, the
    # tracked-target refusal and the ignore preflight. A refusal or a crash up to here undoes that init.
    try:
        if CONVERT:
            convert_prepare()   # --to-multi-repo: its own refusals and --dry-run first, then git init + the move
        nested_preflight()
        NESTED_PLAN = nested_plan()
    except BaseException:
        _nested_undo_init()
        raise
    _HOST_INIT_UNDO = None   # the first write is next: from here on the initialised host is kept
    if CONVERT:
        _CONVERT_UNDO = None   # ... and the moved nested repo stays moved
        convert_start_writing()
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
    for rel in SKILL_FILES[name]:  # the core SKILL.md and its reference files
        write_text(rel, PAYLOADS[rel])

# Subagents: the one full-permission slice executor that carries out one already-planned slice,
# its route's model and effort passed per dispatch (embedded verbatim from the live repo), plus
# the design subagent that drafts one design round (its own design row, [claude.design]), the design
# critic that judges a drafted round (the critic row; the judge row runs it in judge mode) and the
# read-only Explore lookup agent (the explore row).
if not NESTED:
    write_text(".claude/agents/slice-executor.md", PAYLOADS[".claude/agents/slice-executor.md"])
    write_text(".claude/agents/design-drafter.md", PAYLOADS[".claude/agents/design-drafter.md"])
    write_text(".claude/agents/design-critic.md", PAYLOADS[".claude/agents/design-critic.md"])
    write_text(".claude/agents/Explore.md", PAYLOADS[".claude/agents/Explore.md"])

# ---- Executor route config (seeded once — commented defaults; operator-owned) ----
write_text("executors.toml", NESTED_PLAN["engine_side"]["executors.toml"] if NESTED else PAYLOADS["executors.toml"])

# ---- Claude Code project settings: pre-approve the workflow manager ----------
# (Nested: the host's settings.json is never touched; nested_apply writes settings.local.json.)
if not NESTED:
    write_text(".claude/settings.json", PAYLOADS[".claude/settings.json"])

# ---- Repo-level policy files: CI workflow (seed-once) + .gitattributes (merge) ----
# A nested install writes only workflow/.gitattributes (the union rule for works/events.jsonl, which a
# phase-branch merge needs in the nested repo); no CI file anywhere, and nothing in the host repo.
emit_policy_files(ci=not NESTED)

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


def _classify(p: Path, shown: str, entry, unknown: str) -> bool:
    """Record one present file as stale (ours, unchanged) or kept (yours). True when stale. An
    `explain` path is never recorded."""
    if _is_explain_path(shown):
        return False
    digest = None
    if entry and not p.is_symlink():
        try:
            data = p.read_bytes()
            norm = entry[3] if len(entry) > 3 else None
            if norm is not None:
                data = norm(data.decode("utf-8")).encode("utf-8")
            digest = hashlib.sha256(data).hexdigest()
        except (OSError, UnicodeDecodeError):
            pass
    if entry and digest in entry[2]:
        UPDATE_SUMMARY["stale"].append((shown, entry[0]))
        return True
    UPDATE_SUMMARY["kept"].append((shown, entry[1] if entry else unknown))
    return False


def _walk_retired_dir(base: Path, rel: str, entry_of, guard=None) -> None:
    """Classify every file under one retired directory (symlinks are listed, never followed); note the
    directory removable once its files are gone when every one of them is stale. `guard` (nested) is
    the directory's self-hiding .gitignore as (path, entry), classified last: ours only while every
    other file beside it is stale too, since it hides them."""
    d = base / rel
    if not d.is_dir() or d.is_symlink():
        return
    found = []
    for top, dirs, files in os.walk(d):
        found += [Path(top) / n for n in dirs if (Path(top) / n).is_symlink()] + [Path(top) / n for n in files]
    all_stale, guarded = bool(found), None
    for f in sorted(found):
        inner = f.relative_to(base).as_posix()
        if guard and inner == guard[0]:
            guarded = f
            continue
        all_stale = _classify(f, inner, entry_of(inner), "not a file the workspace shipped") and all_stale
    if guarded is not None:
        if all_stale:
            all_stale = _classify(guarded, guard[0], guard[1], "")
        elif not _is_explain_path(guard[0]):
            UPDATE_SUMMARY["kept"].append((guard[0], "it hides the files kept beside it"))
    if all_stale:
        UPDATE_SUMMARY["notes"].append(f"{rel}/ holds only stale files: remove the emptied directory once they are gone")


def flag_retired_files() -> None:
    """At-root: classify each present file at a retired path and every file under a retired directory,
    by content (RETIRED_FILES). Never deletes, and never flags a directory.

    Nested: no nested install ever had these paths; the workspace's own copies its marker recorded and
    this version no longer ships (nested_plan()'s `stale`: skill directories and agent files) are
    classified file by file the same way, a skill directory's self-hiding .gitignore counting as ours
    while it still holds what we wrote."""
    if NESTED:
        hide = ("ours: the directory's self-hiding .gitignore", "differs from the .gitignore the workspace wrote",
                (hashlib.sha256(NESTED_SKILL_GITIGNORE.encode("utf-8")).hexdigest(),))
        # The marker's renames rewrote every installed text, so a retired agent is looked up by its
        # canonical path (a renamed copy maps back) and hashed with the renames undone.
        prior = NESTED_PLAN["prior_renames"]
        undo = prior if any(prior.values()) else None
        canonical = {f".claude/agents/{y}.md": f".claude/agents/{x}.md" for x, y in prior["agents"].items()}
        for rel in NESTED_PLAN["stale"]:
            if rel.startswith(".claude/agents/"):
                if os.path.lexists(HOST / rel):
                    _classify(HOST / rel, rel, _retired_entry(canonical.get(rel, rel), undo), "not a file the workspace shipped")
            else:
                _walk_retired_dir(HOST, rel, _retired_entry, guard=(f"{rel}/.gitignore", hide))
        return
    dirs = list(RETIRED_DIRS) + sorted({"/".join(k.split("/")[:3]) for k in RETIRED_FILES
                                        if k.startswith(".claude/skills/") and k.split("/")[2] not in CLAUDE_SKILLS})
    for rel in dirs:
        _walk_retired_dir(ROOT, rel, _retired_entry)
    for key in sorted(RETIRED_FILES):
        p = ROOT / key
        if not any(key.startswith(d + "/") for d in dirs) and os.path.lexists(p) and not p.is_dir():
            _classify(p, key, _retired_entry(key), "")


def flag_skill_dir_files() -> None:
    """Per file, never per directory: in each of our installed skill directories, a file the payload
    does not ship is stale when RETIRED_FILES holds its unchanged text, and otherwise the operator's own."""
    renames = NESTED_PLAN["renames"]["skills"] if NESTED else {}
    base = HOST if NESTED else ROOT
    for name in CLAUDE_SKILLS:
        installed = renames.get(name, name)
        d = base / ".claude" / "skills" / installed
        if not d.is_dir() or d.is_symlink():
            continue
        shipped = {rel[len(f".claude/skills/{name}/"):] for rel in SKILL_FILES[name]}
        if NESTED:
            shipped.add(".gitignore")  # the self-hiding file nested_plan() writes into each dir
        for f in sorted(p for p in d.rglob("*") if p.is_file()):
            inner = f.relative_to(d).as_posix()
            if inner not in shipped:
                _classify(f, f".claude/skills/{installed}/{inner}", _retired_entry(f".claude/skills/{name}/{inner}"),
                          "not shipped by this version")


def flag_retired_intents() -> None:
    """Read-only: each active phase that is not done whose intent.md names a retired mechanism
    (RETIRED_MECHANISMS) gets one line, for the agent to re-confirm that intent with the operator."""
    phases = []
    for pj in (ROOT / "works/phases/active").glob("*/phase.json"):
        try:
            d = json.loads(pj.read_text(encoding="utf-8"))
            text = (pj.parent / "intent.md").read_text(encoding="utf-8")
        except (OSError, ValueError):
            continue
        archive = d.get("archive") if isinstance(d, dict) else None
        if not isinstance(d, dict) or d.get("status") == "done" or (isinstance(archive, dict) and archive.get("archived")):
            continue
        pid = str(d.get("id") or pj.parent.name)
        num = re.fullmatch(r"P(\d+)", pid)
        phases.append(((0, int(num.group(1)), "") if num else (1, 0, pid), pid, text))
    for _, pid, text in sorted(phases, key=lambda t: t[0]):
        for mech in RETIRED_MECHANISMS:
            if re.search(mech["pattern"], text):
                UPDATE_SUMMARY["intents"].append(f"{pid} intent.md names {mech['name']} (retired v{mech['retired']}: "
                                                 f"{mech['replacement']}) — re-confirm with the operator")


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
    if not NESTED:  # nested: print_nested_banner prints the report under the host side, where its paths live
        print_update_report()


def print_update_report() -> None:
    """The one update report (v61), printed by --update, --update --dry-run, the nested banner's host
    side and the retrofit summary: the settings entries the run removed and the values it changed, the
    files it flags stale (ours, unchanged: remove these files), the files it leaves as yours, and the
    active intents naming a retired mechanism. Every path on its own line; no list is ever truncated."""
    for line in SETTINGS_CHANGES["removed"]:
        print(f"  removed: {line}")
    for line in SETTINGS_CHANGES["changed"]:
        print(f"  changed: {line}")
    for key, title in (("stale", "stale (ours, unchanged — remove these files)"), ("kept", "yours, kept")):
        if UPDATE_SUMMARY[key]:
            print(f"  {title}: {len(UPDATE_SUMMARY[key])}")
            for path, why in UPDATE_SUMMARY[key]:
                print(f"    - {path}  ({why})")
    for note in UPDATE_SUMMARY["notes"]:
        print(f"  note: {note}")
    if UPDATE_SUMMARY["intents"]:
        print(f"  intents naming a retired mechanism: {len(UPDATE_SUMMARY['intents'])}")
        for line in UPDATE_SUMMARY["intents"]:
            print(f"    - {line}")


if UPDATE:
    flag_retired_files()
    flag_skill_dir_files()
    flag_retired_intents()

if DRY_RUN:
    pass  # previewed only — no rebuild/validate, no marker
elif UPDATE:
    # The marker first: the rebuild renders its version into backlog.md.
    write_version_marker()
    if UPDATE_DOCS:
        run_workflow("rebuild")
        run_workflow("validate")
    else:
        # No docs subsystem here (retrofitted repo) — the docs rebuild would crash.
        run_workflow("next")
elif RETROFIT and not INSTALL_DOCS:
    # The target owns docs/ — rebuild only the works side; do not run our docs
    # rebuild/validate against a foreign doc system.
    write_version_marker()
    run_workflow("next")
else:
    write_version_marker()
    run_workflow("rebuild")
    run_workflow("validate")

if NESTED:
    if not DRY_RUN:
        nested_verify_clean(NESTED_PLAN)
    print_nested_banner(NESTED_PLAN)
    if CONVERT:
        convert_finish()
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
    print("      python3 scripts/workflow.py executor-route  # an override= line for each row it pins against the defaults")
    print("Then: python3 scripts/workflow.py next")
elif RETROFIT:
    created, skipped, merged = (RETROFIT_SUMMARY["created"], RETROFIT_SUMMARY["skipped"], RETROFIT_SUMMARY["merged"])
    print(f"Retrofit complete (--into-existing) at {TARGET}")
    print(f"  created: {len(created)} new file(s)")
    print(f"  skipped (kept yours): {len(skipped)} file(s)")
    if merged:
        print(f"  merged (additive): {', '.join(merged)}")
    print_update_report()
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
    print("Claude Code: 18 skills in .claude/skills/ (e.g. /do-next-slice), slice executor .claude/agents/slice-executor.md, design subagent .claude/agents/design-drafter.md, design critic .claude/agents/design-critic.md, read-only lookup agent .claude/agents/Explore.md, settings .claude/settings.json")
    print("Visual design: design-cowork fires automatically; the design-drafter subagent drafts each design job as a working canvas under docs/reference/design/jobs/ (clickable Pages, a board per component), the design-critic judges it when the job's critique is on, the orchestrator publishes each job to its own Design canvas Artifact in the Claude app, and the operator decides: picks a style (build-after / design-only / paired) and signs each job in their own words, or on an in-product mockup they ask for, before separate implementation and browser fidelity")
    print("One executor, routed per dispatch by kind, then risk, then attempt (mid is the default row, real code included; high for decomposition, research, review, named triggers and retries), through one route table whose rows set each dispatch's model and effort; python3 scripts/workflow.py executor-route shows it (and executor-route <slice> the decision for one slice); override a row in executors.toml, then run sync-agents")
    print("Any agent / CI: python3 scripts/workflow.py <command>")
    print("CI: .github/workflows/workspace-ci.yml runs validate on every push/PR (seeded once — yours to edit); .gitattributes carries the merge rules for machine-written files")
    print("Canonical state: phase.json / slice.json / deferred.json; generated: works/backlog.md, works/deferred.md")
    print("Versioned docs: docs/versions/<doc>/v<yyMMddHHmm>_*.md (a new version is named by its UTC minute; v0001_bootstrap.md is the first) with generated docs/current/*.md")
    print("Knowledge: /explain is the knowledge plugin's, not this workspace's (plugin 0.6.0+): /plugin marketplace add leetusik/knowledge, then /plugin install knowledge@knowledge; run /knowledge:setup once, then /knowledge:explain P<N> for one chapter")
    print("  a book (researched, outlined, signed, critic-checked, published private) is an explain phase: ask /create-phase — see docs/current/operations.md")
    print("No phases yet — the workspace starts empty on purpose.")
    print("Next: create the first phase with /create-phase (Claude Code) or python3 scripts/workflow.py new-phase ...")
