from __future__ import annotations

import difflib
import json
import os
import re
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
PHASE_NAME = os.environ["PHASE_NAME"]
PHASE_OBJECTIVE = os.environ["PHASE_OBJECTIVE"]
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
WORKSPACE_VERSION = 1
ROOT = TARGET.resolve()

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

# Skill inventory derived from the embedded payload manifest: a skill is Claude-only
# (e.g. do-whole-phase) when it has no Codex mirror under .agents/skills/.
CLAUDE_SKILLS = sorted({k.split("/")[2] for k in PAYLOADS if k.startswith(".claude/skills/") and k.endswith("/SKILL.md")})
CODEX_SKILLS = sorted({k.split("/")[2] for k in PAYLOADS if k.startswith(".agents/skills/") and k.endswith("/SKILL.md")})

MANAGED_DIRS = [
    "docs", "docs/current", "docs/versions",
    *[f"docs/versions/{doc_id}" for doc_id in DOC_TYPES],
    "works", "works/phases", "works/phases/active", "works/phases/archived",
    "works/deferred", "works/deferred/open", "works/deferred/promoted", "works/deferred/dropped",
    "works/templates", "scripts",
    ".claude", ".claude/skills", ".claude/agents",
    ".agents", ".agents/skills",
    ".codex", ".codex/agents",
]

MANAGED_FILES = [
    "AGENTS.md", "CLAUDE.md",
    "docs/README.md", "docs/index.json",
    *[f"docs/current/{doc_id}.md" for doc_id in DOC_TYPES],
    *[f"docs/versions/{doc_id}/v0001_bootstrap.md" for doc_id in DOC_TYPES],
    "works/state.json", "works/index.json", "works/backlog.md", "works/deferred.md", "works/events.jsonl",
    "works/phases/active/P1/phase.json", "works/phases/active/P1/phase.md", "works/phases/active/P1/intent.md",
    *[f"works/phases/active/P1/slices/P1.DECOMP/{n}" for n in ("slice.json", "result.md")],
    *[f"works/phases/active/P1/slices/P1.REVIEW/{n}" for n in ("slice.json", "result.md")],
    *[f"works/templates/{n}" for n in ("result.md", "deferred_brief.md", "intent.md")],
    "scripts/workflow.py",
    ".claude/agents/slice-executor.md", ".claude/agents/slice-executor-high.md", ".claude/settings.json",
    ".codex/config.toml", ".codex/agents/slice-executor.toml", ".codex/agents/slice-executor-high.toml",
]
for name in CLAUDE_SKILLS:
    MANAGED_DIRS.append(f".claude/skills/{name}")
    MANAGED_FILES.append(f".claude/skills/{name}/SKILL.md")
    if name not in CODEX_SKILLS:
        continue
    MANAGED_DIRS.extend([f".agents/skills/{name}", f".agents/skills/{name}/agents"])
    MANAGED_FILES.extend([
        f".agents/skills/{name}/SKILL.md",
        f".agents/skills/{name}/agents/openai.yaml",
    ])



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
    """Keep the target's existing CLAUDE.md/AGENTS.md; write the full workspace
    contract to a *.workspace.md sidecar and append a marked, idempotent pointer
    block (re-running replaces just the marked block, never duplicates)."""
    p = ROOT / path
    sidecar = path[:-3] + ".workspace.md"  # CLAUDE.md -> CLAUDE.workspace.md
    _atomic_write(ROOT / sidecar, full_text)
    begin, end = "<!-- BEGIN agentic-workspace -->", "<!-- END agentic-workspace -->"
    block = (
        f"{begin}\n"
        f"> This repo uses the agentic workspace (`scripts/workflow.py` + skills under `.claude/`/`.agents/`).\n"
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
    if path in ("CLAUDE.md", "AGENTS.md"):
        _merge_contract(path, text)
        return True
    RETROFIT_SUMMARY["skipped"].append(path)  # keep theirs
    return True


# ---- Update (--update) write policy -----------------------------------------
# Refresh machinery in place while preserving the downstream's own work and docs:
#   OVERWRITE (machinery, upstream-owned): scripts/workflow.py, the .claude
#     subagents, every skill, .codex/config.toml, works/templates/*.
#   MERGE (additive): .claude/settings.json.
#   CONTRACT (sidecar-aware): CLAUDE.md / AGENTS.md.
#   PRESERVE (never touch): everything under works/ except templates, and all of
#     docs/ (the append-only version chain plus generated snapshots).
# In --dry-run nothing is written; changes are only recorded for the report.
def _is_machinery(path: str) -> bool:
    if path in ("scripts/workflow.py", ".codex/config.toml"):
        return True
    return path.startswith((".claude/agents/", ".codex/agents/", ".claude/skills/", ".agents/skills/", "works/templates/"))


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
    # Contract: a retrofitted repo keeps its own CLAUDE.md/AGENTS.md and we
    # refresh the workspace sidecar; a fresh-installed repo's contract IS
    # machinery, so overwrite it in place (operator previews via --dry-run).
    if path in ("CLAUDE.md", "AGENTS.md"):
        sidecar = path[:-3] + ".workspace.md"
        if (ROOT / sidecar).exists():
            _record_change(sidecar, text)
            if not DRY_RUN:
                _merge_contract(path, text)
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


# ---- Guards -----------------------------------------------------------------
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
    if not ((ROOT / "scripts/workflow.py").exists() and works_present):
        print("Error: no agentic workspace found here to update.", file=sys.stderr)
        print("Install fresh into an empty dir, or adopt an existing repo with --into-existing.", file=sys.stderr)
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

created_at = now_iso()

# ---- Routing contract (CLAUDE.md / AGENTS.md) -------------------------------
write_text("CLAUDE.md", f"# CLAUDE.md\n\n> Equivalent to `AGENTS.md`. If you change workflow rules, update both.\n\n{CONTRACT_BODY}")
write_text("AGENTS.md", f"# AGENTS.md\n\n> Equivalent to `CLAUDE.md`. If you change workflow rules, update both.\n\n{CONTRACT_BODY}")

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
write_text("docs/README.md", f"""# Docs

Durable docs are versioned. Do not patch old versions.

## Categories

{chr(10).join(f"- `docs/current/{doc_id}.md`" for doc_id in DOC_TYPES)}

## Rules

Doc updates are the agent's job, normally as part of a slice — the operator asks; the agent runs the commands.

- Read latest docs from `docs/current/*.md`.
- The agent creates updates with `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source <phase-or-slice>`.
- Edit only the newly created version file under `docs/versions/<doc>/`.
- The agent runs `python3 scripts/workflow.py rebuild-docs` after editing the new version.
- `docs/current/*.md` is generated from the latest version and should not be manually edited.

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
""")

# ---- Templates --------------------------------------------------------------
# No plan.md template: the orchestrator writes its own free-form native plan into
# each slice's plan.md at the slice's turn. Only result.md (and intent.md) are scaffolded.
write_text("works/templates/result.md", PAYLOADS["works/templates/result.md"])
write_text("works/templates/deferred_brief.md", PAYLOADS["works/templates/deferred_brief.md"])
write_text("works/templates/intent.md", PAYLOADS["works/templates/intent.md"])

# ---- Initial phase P1 -------------------------------------------------------
p1_path = "works/phases/active/P1"
phase_json = {
    "id": "P1", "name": PHASE_NAME, "objective": PHASE_OBJECTIVE, "status": "planned", "order": 1,
    "created_at": created_at, "started_at": None, "completed_at": None,
    "review": {"status": "pending", "reviewed_at": None, "reviewer": None, "note": None},
    "paths": {"phase_md": "phase.md", "slices_dir": "slices"},
    "archive": {"archived": False, "archived_at": None, "archive_path": None},
}
write_json(f"{p1_path}/phase.json", phase_json)
write_text(f"{p1_path}/phase.md", P1_PHASE_MD.replace("__PHASE_NAME__", PHASE_NAME).replace("__PHASE_OBJECTIVE__", PHASE_OBJECTIVE))
intent_origin = "synthesized-from-repo" if RETROFIT else "bootstrap-placeholder"
intent_original = "(Synthesized by the adopting agent from the repo's README, manifest, and git history — not a verbatim operator request.)" if RETROFIT else "(Bootstrap placeholder — no operator request captured yet.)"
write_text(f"{p1_path}/intent.md", P1_INTENT_MD.replace("__CREATED_AT__", created_at).replace("__INTENT_ORIGIN__", intent_origin).replace("__INTENT_ORIGINAL__", intent_original).replace("__PHASE_OBJECTIVE__", PHASE_OBJECTIVE))


def new_slice_files(phase_id: str, slice_id: str, name: str, kind: str, status: str, order: int, risk: str, source: dict) -> None:
    folder = f"works/phases/active/{phase_id}/slices/{slice_id}"
    slice_data = {
        "id": slice_id, "phase_id": phase_id, "name": name, "kind": kind, "status": status, "order": order,
        "depends_on": [], "created_at": created_at, "started_at": None, "completed_at": None, "risk": risk, "source": source,
        "paths": {"plan": "plan.md", "result": "result.md"},
        "validation": {"required": [], "last_run": None, "last_status": "pending"},
        "archive": {"archived": False, "archived_at": None, "archive_path": None},
    }
    write_json(f"{folder}/slice.json", slice_data)
    replacements = {"__PHASE_ID__": phase_id, "__SLICE_ID__": slice_id, "__SLICE_NAME__": name, "__CREATED_AT__": created_at}
    # Only result.md is scaffolded; plan.md has no template (the orchestrator writes its
    # free-form native plan there at the slice's turn), matching create_slice in workflow.py.
    for tmpl_name in ("result.md",):
        text = (ROOT / "works/templates" / tmpl_name).read_text(encoding="utf-8")
        for k, v in replacements.items():
            text = text.replace(k, v)
        write_text(f"{folder}/{tmpl_name}", text)


new_slice_files("P1", "P1.DECOMP", "decompose phase", "decomposition", "todo", 0, "low", {"type": "bootstrap", "id": None})
new_slice_files("P1", "P1.REVIEW", "phase review", "review", "todo", 9999, "medium", {"type": "bootstrap", "id": None})
write_text("works/events.jsonl", json.dumps({"ts": created_at, "type": "bootstrap", "project": PROJECT_NAME, "phase": "P1"}, ensure_ascii=False) + "\n")

# ---- Workflow engine (scripts/workflow.py) ----------------------------------
write_text("scripts/workflow.py", PAYLOADS["scripts/workflow.py"], executable=True)

# ---- Agent surfaces: skills for both tools ----------------------------------
for name in CLAUDE_SKILLS:
    write_text(f".claude/skills/{name}/SKILL.md", PAYLOADS[f".claude/skills/{name}/SKILL.md"])
    if name not in CODEX_SKILLS:
        continue  # Claude-only skill (e.g. do-whole-phase) — no Codex mirror
    write_text(f".agents/skills/{name}/SKILL.md", PAYLOADS[f".agents/skills/{name}/SKILL.md"])
    write_text(f".agents/skills/{name}/agents/openai.yaml", PAYLOADS[f".agents/skills/{name}/agents/openai.yaml"])

# Subagents: full-permission workers that implement one already-planned slice (embedded verbatim from the live repo).
write_text(".claude/agents/slice-executor.md", PAYLOADS[".claude/agents/slice-executor.md"])
write_text(".claude/agents/slice-executor-high.md", PAYLOADS[".claude/agents/slice-executor-high.md"])
write_text(".codex/agents/slice-executor.toml", PAYLOADS[".codex/agents/slice-executor.toml"])
write_text(".codex/agents/slice-executor-high.toml", PAYLOADS[".codex/agents/slice-executor-high.toml"])

# ---- Claude Code project settings: pre-approve the workflow manager ----------
write_text(".claude/settings.json", PAYLOADS[".claude/settings.json"])

# ---- Codex project config (documentation + safe defaults) -------------------
write_text(".codex/config.toml", PAYLOADS[".codex/config.toml"])

# ---- Generate dashboards/state from the source of truth, then self-check ----
def run_workflow(*workflow_args: str) -> None:
    subprocess.run([sys.executable, str(ROOT / "scripts" / "workflow.py"), *workflow_args], cwd=str(ROOT), check=True)


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


def flag_stale_skills() -> None:
    """Surface workspace-managed skill dirs that this version no longer ships, so
    the operator can remove them. A dir is "ours" only by a tool-specific marker
    (Claude SKILL.md sets `disable-model-invocation: true`; a Codex skill carries an
    `agents/openai.yaml`) — so the operator's own skills are not mislabeled. The
    expected set is per-tool: Codex excludes `claude_only` skills (e.g. do-whole-phase),
    so a workspace updated to this version flags its now-stale Codex copy. Never deletes."""
    claude_expected = set(CLAUDE_SKILLS)
    codex_expected = set(CODEX_SKILLS)
    for base, expected in ((".claude/skills", claude_expected), (".agents/skills", codex_expected)):
        d = ROOT / base
        if not d.is_dir():
            continue
        for sub in sorted(d.iterdir()):
            if not sub.is_dir() or sub.name in expected:
                continue
            if base == ".claude/skills":
                try:
                    head = (sub / "SKILL.md").read_text(encoding="utf-8")[:400]
                except OSError:
                    continue
                ours = "disable-model-invocation: true" in head
            else:
                ours = (sub / "agents" / "openai.yaml").is_file()
            if ours:
                UPDATE_SUMMARY["stale"].append(f"{base}/{sub.name}")


def print_change_list() -> None:
    upd, add, mrg = UPDATE_SUMMARY["updated"], UPDATE_SUMMARY["added"], UPDATE_SUMMARY["merged"]
    print(f"  machinery updated: {len(upd)} file(s)")
    for path, added, removed in upd:
        print(f"    ~ {path}  (+{added}/-{removed})")
    if add:
        print(f"  added: {len(add)} file(s)")
        for path in add:
            print(f"    + {path}")
    if mrg:
        print(f"  merged (additive): {', '.join(mrg)}")
    print(f"  preserved (your work + docs, untouched): {len(UPDATE_SUMMARY['preserved'])} file(s)")
    print(f"  unchanged: {len(UPDATE_SUMMARY['unchanged'])} file(s)")
    if UPDATE_SUMMARY["stale"]:
        print(f"  stale workspace skills dropped upstream (remove manually?): {', '.join(UPDATE_SUMMARY['stale'])}")


if UPDATE:
    flag_stale_skills()

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

if DRY_RUN:
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
    print("Next: python3 scripts/workflow.py next")
elif RETROFIT:
    created, skipped, merged = (RETROFIT_SUMMARY["created"], RETROFIT_SUMMARY["skipped"], RETROFIT_SUMMARY["merged"])
    print(f"Retrofit complete (--into-existing) at {TARGET}")
    print(f"  created: {len(created)} new file(s)")
    print(f"  skipped (kept yours): {len(skipped)} file(s)")
    if merged:
        print(f"  merged (additive): {', '.join(merged)}")
    print(f"  docs subsystem: {'installed' if INSTALL_DOCS else 'skipped (target already has a docs/ system)'}")
    print(f"  works subsystem: installed; seeded phase P1 - {PHASE_NAME}")
    if not INSTALL_DOCS:
        print("  note: docs versioning not installed; skipped docs rebuild/validate")
    print("The installer made no git changes. Review the diff (git status); commit the adoption once the operator approves.")
    print("If CLAUDE.md/AGENTS.md already existed, reconcile the *.workspace.md sidecar(s); add __pycache__/ to .gitignore.")
    print("Next: python3 scripts/workflow.py validate && python3 scripts/workflow.py next")
else:
    print(f"Bootstrapped cross-tool agentic workspace at {TARGET}")
    print("Contracts: CLAUDE.md and AGENTS.md (equivalent)")
    print("Claude Code: skills in .claude/skills/ (e.g. /do-next-slice), subagent .claude/agents/slice-executor.md, settings .claude/settings.json")
    print("Codex: skills in .agents/skills/ (e.g. $do-next-slice), subagent .codex/agents/slice-executor.toml, instructions AGENTS.md")
    print("Any agent / CI: python3 scripts/workflow.py <command>")
    print("Canonical state: phase.json / slice.json / deferred.json; generated: works/backlog.md, works/deferred.md")
    print("Versioned docs: docs/versions/<doc>/vNNNN_*.md with generated docs/current/*.md")
    print(f"Created initial phase: P1 - {PHASE_NAME}")
    print("Next: python3 scripts/workflow.py next   (or /do-next-slice in Claude Code)")
