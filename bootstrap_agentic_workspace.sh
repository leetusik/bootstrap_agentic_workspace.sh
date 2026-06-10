#!/bin/sh
set -eu

usage() {
  cat <<'USAGE'
Usage:
  bootstrap_agentic_workspace.sh [TARGET_DIR] [options]

Options:
  --name NAME                 Optional project name override
  --summary TEXT              Optional one-sentence summary override
  --phase-name NAME           Optional initial P1 phase name override
  --phase-objective TEXT      Optional initial P1 phase objective override
  --force-empty-ok            Allow bootstrapping into a repo with extra non-managed files
  -h, --help                  Show this help

TARGET_DIR defaults to the current directory.

This bootstrap creates a compact, scalable agentic workspace tuned for BOTH
Claude Code and OpenAI Codex:

- AGENTS.md / CLAUDE.md are equivalent compact routing contracts (the reliable
  cross-tool fallback both agents read).
- Operations ship as Agent Skills in BOTH .claude/skills/ (Claude Code: /slash +
  auto-invocation) and .agents/skills/ (Codex: $skill / implicit), so the same
  command works natively in either tool.
- works/backlog.md and works/deferred.md are generated dashboards, never the
  task database. Canonical state is JSON in the phase/slice/deferred folders.
- Each slice owns slice.json plus plan.md (filled at slice start) and result.md (written at slice end).
- Deferred jobs are one folder per job and never affect next-slice selection
  until promoted.
- Phase review is recorded (review-phase) and gates archiving.
- Docs are versioned fullstack categories: agents create
  docs/versions/<doc>/vNNNN_*.md and regenerate docs/current/*.md.

Requires python3 (>= 3.8). Safe to re-run only into a fresh workspace.
USAGE
}

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }
need_value() { [ $# -ge 2 ] || die "$1 requires a value"; [ -n "$2" ] || die "$1 requires a non-empty value"; }

target_dir=
project_name=
project_summary=
phase_name=
phase_objective=
force_empty_ok=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --name) need_value "$1" "${2-}"; project_name=$2; shift 2 ;;
    --name=*) project_name=${1#--name=}; [ -n "$project_name" ] || die "--name requires a non-empty value"; shift ;;
    --summary) need_value "$1" "${2-}"; project_summary=$2; shift 2 ;;
    --summary=*) project_summary=${1#--summary=}; [ -n "$project_summary" ] || die "--summary requires a non-empty value"; shift ;;
    --phase-name) need_value "$1" "${2-}"; phase_name=$2; shift 2 ;;
    --phase-name=*) phase_name=${1#--phase-name=}; [ -n "$phase_name" ] || die "--phase-name requires a non-empty value"; shift ;;
    --phase-objective) need_value "$1" "${2-}"; phase_objective=$2; shift 2 ;;
    --phase-objective=*) phase_objective=${1#--phase-objective=}; [ -n "$phase_objective" ] || die "--phase-objective requires a non-empty value"; shift ;;
    --force-empty-ok) force_empty_ok=1; shift ;;
    --) shift; while [ $# -gt 0 ]; do [ -z "$target_dir" ] || die "only one TARGET_DIR may be provided"; target_dir=$1; shift; done ;;
    -*) die "unknown option $1" ;;
    *) [ -z "$target_dir" ] || die "only one TARGET_DIR may be provided"; target_dir=$1; shift ;;
  esac
done

[ -n "$target_dir" ] || target_dir=.
[ -e "$target_dir" ] && [ ! -d "$target_dir" ] && die "target exists but is not a directory: $target_dir"

# Fixed non-interactive defaults. The first real task should replace this bootstrap intake context.
[ -n "$project_name" ] || project_name="New Project"
[ -n "$project_summary" ] || project_summary="Fresh agentic workspace. Replace this summary during the first real task."
[ -n "$phase_name" ] || phase_name="Bootstrap Intake"
[ -n "$phase_objective" ] || phase_objective="Capture the first real task, create versioned durable docs, and replace this placeholder phase with concrete work."

command -v python3 >/dev/null 2>&1 || die "python3 is required for this bootstrap"

export TARGET_DIR="$target_dir"
export PROJECT_NAME="$project_name"
export PROJECT_SUMMARY="$project_summary"
export PHASE_NAME="$phase_name"
export PHASE_OBJECTIVE="$phase_objective"
export FORCE_EMPTY_OK="$force_empty_ok"

python3 - <<'PY'
from __future__ import annotations

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

# Each operation ships as one Agent Skill, mirrored into Claude Code (.claude/skills)
# and Codex (.agents/skills). Fields:
#   name, desc          : skill identity (description drives implicit matching)
#   tools               : Claude Code allowed-tools line (tight scope = fewer prompts)
#   body                : the procedure (shared by both tools)
# All workflow command-skills are explicit-invocation only (operator actions),
# so neither agent fires them on a whim: disable-model-invocation (Claude) and
# allow_implicit_invocation=false (Codex).
COMMAND_SKILLS = [
    {
        "name": "do-next-slice",
        "desc": "Continue the active phase by completing exactly one slice, then stop.",
        "tools": "Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash",
        "body": """Run `python3 scripts/workflow.py next`, then read `AGENTS.md` (or `CLAUDE.md`), `docs/current/*.md` as needed, `docs/index.json`, `works/state.json`, `works/backlog.md`, the selected slice folder, and the phase's `phase.md` (the phase notebook — accumulated decomposition, findings, and cross-slice notes).

Work exactly one slice:

1. If the selected slice is `todo`, run `python3 scripts/workflow.py start-slice <slice_id>`.
2. Fill this slice's own `plan.md` before implementing — Goal, Scope, Milestones, and Validation are required, not optional; pull relevant context from `phase.md`. If the operator passed any note or extra instructions with the command, record it verbatim in `plan.md` under a `## Operator Input (verbatim)` heading. Never pre-fill another slice's `plan.md`.
3. Implement the slice.
4. For durable doc changes, run `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source <slice_id>`, edit only the returned `edit_path`, then run `python3 scripts/workflow.py rebuild-docs`.
5. Record validation commands, created doc versions, and outcome in `result.md`, and append any durable cross-slice notes (decisions, findings, gotchas) to the phase's `phase.md` so later slices can build on them.
6. Mark the slice done with `python3 scripts/workflow.py finish-slice <slice_id>` only when complete.
7. Run `python3 scripts/workflow.py validate`.
8. Commit by default: group the slice's pending changes into focused `type(scope): summary` commit(s) following the Commit Convention. Branch first if on `main`; never push.

When the selected slice is a decomposition (`kind: decomposition`), step 3 ("implement") means decomposing the phase, not writing code:

- Create the middle slices with `python3 scripts/workflow.py new-slice --phase <P> --slice <P>.S<n> --name "..."` (add `--kind`, `--risk`, `--order`, `--depends-on` as needed). Create the slices **only** — do not pre-fill their `plan.md`; each slice fills its own when it runs.
- Record the slice breakdown (what each slice covers and why) plus any research or findings in the phase's `phase.md`, so later slices share that context.

When the selected slice is a phase review (`kind: review`), step 3 ("implement") means running the review, not writing code:

- Invoke the read-only `phase-reviewer` subagent for the phase; record its verdict and the review outcome in `result.md` (the machine verdict is also persisted to `phase.json` by `review-phase`). (In Codex, follow the `review-phase` skill checklist instead.)
- Record the verdict: `python3 scripts/workflow.py review-phase <P> --verdict pass|changes_requested|blocked --reviewer phase-reviewer --note "..."`.
- On `pass`: run `finish-slice <slice_id>`. A passing review marks the phase `done` but it **stays in `active/`** — archiving is a separate, manual step, so do **not** archive now. Archive later when you choose: `archive-all` once every active phase is done, `rotate-backlog` to archive just the done phases while others continue, or `archive-phase <P>` for one phase.
- On `changes_requested`: create fix slices (`python3 scripts/workflow.py new-slice --phase <P> --slice <P>.F<n> --name "..." --kind fix`) and leave the review slice open for re-review; do not finish or archive.
- On `blocked`: record the blocker; do not finish or archive.

Stop after one slice. Do not advance to the next slice in the same turn.
""",
    },
    {
        "name": "do-whole-phase",
        "desc": "Finish the active phase end-to-end, including the review and any fix slices.",
        "tools": "Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash",
        "body": """Read `AGENTS.md` and the phase's `phase.md`, run `python3 scripts/workflow.py next`, then finish every remaining slice in the current phase only.

Rules:

- Re-read `works/state.json`, `works/backlog.md`, and the phase's `phase.md` after each slice.
- For each slice, fill its **own** `plan.md` before implementing (pull context from `phase.md`); if the operator passed a note with the command, record it verbatim under a `## Operator Input (verbatim)` heading in that slice's `plan.md`. Never pre-fill another slice's `plan.md`.
- When the slice is a decomposition (`kind: decomposition`), create the middle slices with `new-slice` (folders only — do not pre-fill their `plan.md`) and record the breakdown, findings, and notes in `phase.md`.
- When a slice finishes, write its `result.md` and append durable cross-slice notes to `phase.md` so later slices can build on them.
- Use `doc-new-version` for durable doc changes; never patch old doc versions or `docs/current/*.md` directly.
- Commit at every clean slice boundary by default, following the Commit Convention (branch first if on `main`; never push).
- When you reach the phase review slice, run the review:
  - In Claude Code, invoke the `phase-reviewer` subagent (read-only) and take its verdict.
  - In Codex, follow the `review-phase` skill checklist yourself.
- Record the verdict: `python3 scripts/workflow.py review-phase <P> --verdict pass|changes_requested|blocked --reviewer <name> --note "..."`.
- If the verdict is `changes_requested`, create concrete fix slices with `python3 scripts/workflow.py new-slice --phase <P> --slice <P.Fn> --name "..." --kind fix`, complete them, then re-review.
- Only a `pass` verdict marks the phase `done` (review-phase does this for you).
- A passing review leaves the phase `done` in `active/`; do **not** archive it here. Archiving is a separate manual step — later, use `archive-all` once every active phase is done, `rotate-backlog` to archive just the done phases while others continue, or `archive-phase <P>` for one phase.
- Do not continue into the next phase.
""",
    },
    {
        "name": "review-phase",
        "desc": "Review a completed phase against its objective and record a pass / changes_requested / blocked verdict.",
        "tools": "Bash(python3 scripts/workflow.py:*), Read, Glob, Grep, Bash",
        "body": """Review the target phase read-only, then record the verdict. Do not implement fixes here; that is done by fix slices.

Read:

- `AGENTS.md` (or `CLAUDE.md`)
- `docs/current/*.md` relevant to the phase, and `docs/index.json`
- `works/state.json`, `works/backlog.md`
- the phase folder under `works/phases/active/<P>/` and each completed slice's `slice.json` + `result.md`

Check:

- Did the phase objective actually ship?
- Did each slice meet its brief and plan? Are deviations explained in `result.md`?
- When product, architecture, or API truth changed, were new doc versions created (not in-place edits)?
- Do `docs/current/*.md` match the latest versions in `docs/index.json`? (`python3 scripts/workflow.py validate` checks this.)
- Were validation commands recorded?
- Are any issues serious enough to require fix slices?

Record exactly one verdict:

```sh
python3 scripts/workflow.py review-phase <P> --verdict pass --reviewer phase-reviewer --note "short justification"
# or
python3 scripts/workflow.py review-phase <P> --verdict changes_requested --reviewer phase-reviewer --note "numbered issues + proposed fix slices like P1.F1"
# or
python3 scripts/workflow.py review-phase <P> --verdict blocked --reviewer phase-reviewer --note "the blocker and needed input"
```

`pass` also marks the phase `done` — it stays in `active/`; archiving is a separate, manual step (`archive-all`, `rotate-backlog`, or `archive-phase`). `changes_requested` returns it to `in_progress`. `blocked` sets it `blocked`.
""",
    },
    {
        "name": "doc-new-version",
        "desc": "Create a new versioned durable doc instead of patching current docs.",
        "tools": "Bash(python3 scripts/workflow.py:*), Read, Edit",
        "body": """Run `python3 scripts/workflow.py doc-new-version $ARGUMENTS` (for example `--doc product --summary "..." --source P1.S1`).

Then edit only the returned `edit_path` under `docs/versions/<doc>/`, and run:

```sh
python3 scripts/workflow.py rebuild-docs
python3 scripts/workflow.py validate
```

Never manually edit `docs/current/*.md` or any existing file under `docs/versions/`.
""",
    },
    {
        "name": "deferred",
        "desc": "Rebuild and show the deferred jobs dashboard.",
        "tools": "Bash(python3 scripts/workflow.py:*)",
        "body": """Run `python3 scripts/workflow.py deferred`. Then read `works/deferred.md` if you need the human-readable dashboard.
""",
    },
    {
        "name": "defer-job",
        "desc": "Park work as a deferred job folder, outside active backlog selection.",
        "tools": "Bash(python3 scripts/workflow.py:*)",
        "body": """Run `python3 scripts/workflow.py defer-job $ARGUMENTS` (for example `--title "..." --reason "..." --trigger "..." --source P1.S1`).

Deferred jobs are stored under `works/deferred/open/<DID>/` and never affect next-slice selection until promoted.
""",
    },
    {
        "name": "promote-deferred",
        "desc": "Promote a deferred job into an active phase or slice.",
        "tools": "Bash(python3 scripts/workflow.py:*)",
        "body": """Run `python3 scripts/workflow.py promote-deferred $ARGUMENTS` (for example `D1 --phase P1 --slice P1.S2 --name "..."`; add `--create-phase --phase-name "..." --phase-objective "..."` to start a new phase).

This moves the job from `works/deferred/open/` to `works/deferred/promoted/`, creates a slice folder, and carries the deferred context into the slice brief.
""",
    },
    {
        "name": "archive-phase",
        "desc": "Archive review-passed phases: archive-all (full sweep), rotate-backlog (partial), or archive-phase (single).",
        "tools": "Bash(python3 scripts/workflow.py:*)",
        "body": """Archiving is **manual and explicit** — never automatic. A passing review marks a phase `done` but leaves it in `active/`; you archive when you choose. Archive whole phases only, never individual slices. Three first-class options:

**Archive everything — end-of-batch sweep.** When every active phase is done (the last review slice across all phases is complete), sweep them all to archived at once:

```sh
python3 scripts/workflow.py archive-all
```

`archive-all` refuses unless every active phase is `done` with a passing review.

**Rotate the done phases — partial sweep.** When only some phases are done, archive exactly those and leave the in-progress ones active:

```sh
python3 scripts/workflow.py rotate-backlog
```

**Archive one phase.** Archive a single review-passed phase by id:

```sh
python3 scripts/workflow.py archive-phase <P>
```

All three gate on the same rule: a phase must be `done` with a passing review to archive. Use `--force` (on `archive-all`/`archive-phase`) only for exceptional cleanup of an unfinished phase.
""",
    },
    {
        "name": "rotate-backlog",
        "desc": "Archive every currently-done phase and leave in-progress phases active (partial archive-all).",
        "tools": "Bash(python3 scripts/workflow.py:*)",
        "body": """Archive every phase that is **currently done** (all slices complete with a passing review) and leave in-progress phases active, then rebuild the dashboards:

```sh
python3 scripts/workflow.py rotate-backlog
```

This is the **partial** rotation `archive-all` cannot do: `archive-all` refuses unless *every* active phase is done, while `rotate-backlog` sweeps just the done phases and leaves the rest. Use it when several phases are active and only some have passed review.

Archives whole phases only; unfinished, blocked, or unreviewed phases are left untouched. There is no `--force` — to archive an unfinished phase, use `archive-phase <P> --force`.
""",
    },
    {
        "name": "rebuild-workflow",
        "desc": "Rebuild generated workflow dashboards, indexes, and docs snapshots, then validate.",
        "tools": "Bash(python3 scripts/workflow.py:*)",
        "body": """Run:

```sh
python3 scripts/workflow.py rebuild
python3 scripts/workflow.py validate
```
""",
    },
    {
        "name": "commit",
        "desc": "Group pending changes by topic into focused conventional commits.",
        "tools": "Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git reset:*), Bash(git commit:*)",
        "body": """Inspect pending changes, group them by logical topic, and create one focused commit per group using `type(scope): summary` (imperative, no trailing period).

Never push, force-push, use `git add -A`, or skip hooks unless explicitly asked.
""",
    },
]

MANAGED_DIRS = [
    "docs", "docs/current", "docs/versions",
    *[f"docs/versions/{doc_id}" for doc_id in DOC_TYPES],
    "works", "works/phases", "works/phases/active", "works/phases/archived",
    "works/deferred", "works/deferred/open", "works/deferred/promoted", "works/deferred/dropped",
    "works/templates", "scripts",
    ".claude", ".claude/skills", ".claude/agents",
    ".agents", ".agents/skills",
    ".codex",
]

MANAGED_FILES = [
    "AGENTS.md", "CLAUDE.md",
    "docs/README.md", "docs/index.json",
    *[f"docs/current/{doc_id}.md" for doc_id in DOC_TYPES],
    *[f"docs/versions/{doc_id}/v0001_bootstrap.md" for doc_id in DOC_TYPES],
    "works/state.json", "works/index.json", "works/backlog.md", "works/deferred.md", "works/events.jsonl",
    "works/phases/active/P1/phase.json", "works/phases/active/P1/phase.md",
    *[f"works/phases/active/P1/slices/P1.DECOMP/{n}" for n in ("slice.json", "plan.md", "result.md")],
    *[f"works/phases/active/P1/slices/P1.REVIEW/{n}" for n in ("slice.json", "plan.md", "result.md")],
    *[f"works/templates/{n}" for n in ("plan.md", "result.md", "deferred_brief.md")],
    "scripts/workflow.py",
    ".claude/agents/phase-reviewer.md", ".claude/settings.json",
    ".codex/config.toml",
]
for s in COMMAND_SKILLS:
    name = s["name"]
    MANAGED_DIRS.extend([f".claude/skills/{name}", f".agents/skills/{name}", f".agents/skills/{name}/agents"])
    MANAGED_FILES.extend([
        f".claude/skills/{name}/SKILL.md",
        f".agents/skills/{name}/SKILL.md",
        f".agents/skills/{name}/agents/openai.yaml",
    ])


def now_iso() -> str:
    return datetime.now().astimezone().replace(microsecond=0).isoformat()


def slugify(value: str, fallback: str = "item") -> str:
    slug = re.sub(r"[^a-zA-Z0-9._-]+", "_", value.strip().lower()).strip("_")
    return slug or fallback


def write_text(path, text: str, executable: bool = False) -> None:
    p = ROOT / path
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


def write_json(path, data) -> None:
    write_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


# ---- Guards -----------------------------------------------------------------
ROOT.mkdir(parents=True, exist_ok=True)
for rel in MANAGED_DIRS:
    p = ROOT / rel
    if p.exists() and not p.is_dir():
        sys.exit(f"Error: managed directory path exists but is not a directory: {rel}")

conflicts = [rel for rel in MANAGED_FILES if (ROOT / rel).exists()]
if conflicts:
    print("Error: target already contains managed workflow files:", file=sys.stderr)
    for rel in conflicts:
        print(f"  - {rel}", file=sys.stderr)
    print("Refusing to overwrite. Use this bootstrap only for a fresh agentic workspace.", file=sys.stderr)
    sys.exit(1)

if not FORCE_EMPTY_OK:
    extra = sorted(p.name for p in ROOT.iterdir() if p.name not in EMPTY_OK_ALLOWLIST)
    if extra:
        print("Error: target is not empty (beyond common repo metadata).", file=sys.stderr)
        print("Unexpected entries:", file=sys.stderr)
        for name in extra:
            print(f"  - {name}", file=sys.stderr)
        print("Re-run with --force-empty-ok if these are intentional and no managed files conflict.", file=sys.stderr)
        sys.exit(1)

for rel in MANAGED_DIRS:
    (ROOT / rel).mkdir(parents=True, exist_ok=True)

created_at = now_iso()

# ---- Routing contract (CLAUDE.md / AGENTS.md) -------------------------------
WORKFLOW_DOC = """## Agent Contract

This file is a compact routing contract. Operational detail lives in `scripts/workflow.py`, the Agent Skills under `.claude/skills/` and `.agents/skills/`, and the active slice folder.

Core rule: **Backlog routes. Slice folder explains. Result summarizes. Docs are versioned durable truth.**

## Driving This Workspace

Everything runs through one manager: `python3 scripts/workflow.py <command>`. The same operations are also packaged as Agent Skills so they work natively in either tool:

- **Claude Code:** slash commands like `/do-next-slice`, `/do-whole-phase`, `/review-phase` (from `.claude/skills/`), plus the read-only `phase-reviewer` subagent. `.claude/settings.json` pre-approves the workflow script so it runs without prompts.
- **Codex:** the same skills under `.agents/skills/` via `$skill` or `/skills`. Codex reads this file as `AGENTS.md`.
- **Any agent / CI:** call `python3 scripts/workflow.py ...` directly. This always works, even where skills are unavailable.

Workflow command-skills are explicit-invocation only; agents should not fire them autonomously.

**Making a phase ≠ executing it.** When the operator asks you to make, create, suggest, or plan a phase, the job is to run `new-phase` — which creates only `P<N>.DECOMP` and `P<N>.REVIEW` — and then STOP and report. Do **not** decompose the phase into middle slices, do **not** write slice plans, and do **not** implement any code. Decomposition is the `DECOMP` slice's own job and happens later, when the operator executes the phase (`/do-next-slice`, `/do-whole-phase`) or explicitly tells you to. Creating several phases at once is fine; decomposing or executing any of them is a separate, explicit step.

## Read Order

1. `docs/current/*.md` for the fullstack doc set
2. `docs/index.json`
3. `works/state.json`, `works/backlog.md`, and `works/deferred.md`
4. The active phase folder and active slice folder only

Do not read every historical slice or old doc version by default. Archived phases and old doc versions are history.

## Canonical State

- Current pointer: `works/state.json`
- Generated dashboards/index: `works/backlog.md`, `works/deferred.md`, `works/index.json`
- Phase state: `works/phases/active/<phase_id>/phase.json`
- Phase notebook: `works/phases/active/<phase_id>/phase.md` — objective plus the accumulating decomposition, findings, and cross-slice notes; the shared context across a phase's slices
- Slice state: `works/phases/active/<phase_id>/slices/<slice_id>/slice.json`
- Slice context: `plan.md` (filled at slice start, incl. verbatim operator notes) and `result.md` (written at slice end), beside `slice.json`
- Deferred state: `works/deferred/open/<DID>/deferred.json`
- Doc index: `docs/index.json`; latest docs: `docs/current/*.md` generated from `docs/versions/<doc>/vNNNN_*.md`

## Hard Rules

- Keep `works/backlog.md` and `works/deferred.md` lean: IDs, names, statuses, pointers, paths only. Detail goes in the folders.
- Never patch old files under `docs/versions/`; create a new version with `doc-new-version`.
- Treat `docs/current/*.md` as generated snapshots; never hand-edit them.
- New phases start with only `P<N>.DECOMP` and `P<N>.REVIEW`. Decomposition (the `DECOMP` slice) creates the middle slices **only** — bare folders — and records the slice breakdown, findings, and notes in `phase.md`; it does **not** pre-fill the new slices' `plan.md`.
- "Make/create/suggest a phase" = run `new-phase` (creates `DECOMP` + `REVIEW` only), then stop — do not decompose, write slice plans, or implement until the operator executes the phase or says to. See *Driving This Workspace*.
- Each slice owns exactly two context files: `plan.md` (the slice fills its **own** plan when it runs, before implementing; record any operator note passed with `do-next-slice`/`do-whole-phase` verbatim under `## Operator Input (verbatim)`) and `result.md` (write when done). A slice never pre-fills another slice's `plan.md`. There are no per-slice brief or review files.
- `phase.md` is the phase notebook: the `DECOMP` slice seeds it (breakdown, findings, notes), and every slice reads it for accumulated context at start and appends durable cross-slice notes back to it when it finishes — so later slices build on what earlier ones learned.
- Slice selection is by `order`; `depends_on` is advisory and only checked for existence by `validate`.
- Deferred jobs never affect next-slice selection until promoted.
- Record the phase review with `review-phase`. A passing review marks a phase `done` but does **not** archive it — the phase stays in `active/`. Archiving is a separate, manual step: `archive-all` once every active phase is done (the last review slice complete), `rotate-backlog` to archive just the done phases while others continue, or `archive-phase <P>` for a single review-passed phase. Archive whole phases only, never individual slices.

## IDs and Status

- Phase IDs: `P1`, `P2`, ... with status `planned | in_progress | in_review | blocked | done`
- Slice IDs: `P1.DECOMP`, `P1.S1`, `P1.F1`, `P1.REVIEW`, ... with status `todo | in_progress | in_review | changes_requested | blocked | done`
- Deferred IDs: `D1`, `D2`, ... with status `deferred | ready | promoted | done | dropped`
- Doc versions: `v0001_bootstrap.md`, `v0002_<slug>.md`, ...
- Phase review verdicts: `pass | changes_requested | blocked`

## Workflow Commands

Use `python3 scripts/workflow.py <command>`:

- `next` — show current/next active slice
- `new-phase --phase P2 --name "..." --objective "..."`
- `new-slice --phase P1 --slice P1.S1 --name "..."` (`--kind`, `--risk`, `--order`, `--depends-on`)
- `start-slice P1.S1` / `finish-slice P1.S1` / `set-slice-status P1.S1 <status>`
- `set-phase-status P1 <status>`
- `review-phase P1 --verdict pass|changes_requested|blocked [--reviewer NAME] [--note "..."]`
- `doc-new-version --doc frontend --summary "..." --source P1.S1` / `docs` / `rebuild-docs`
- `deferred` / `defer-job --title "..." --reason "..." --trigger "..." --source P1.S1`
- `promote-deferred D1 --phase P1 --slice P1.S2 --name "..."` / `drop-deferred D1 --reason "..."`
- `archive-all` (batch-archive every active phase once all are done) / `rotate-backlog` (archive just the done phases, leave the rest) / `archive-phase P1` (archive a single review-passed phase)
- `rebuild` / `validate`

## Commit Convention

Use `type(scope): summary`, imperative voice, no trailing period. Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `revert`.

By default, commit after each completed slice — at the end of `do-next-slice`, and at every clean slice boundary inside `do-whole-phase`. Outside the slice workflow, commit only when asked. Branch first if on `main`. Never push without being asked.
"""
write_text("CLAUDE.md", f"# CLAUDE.md\n\n> Equivalent to `AGENTS.md`. If you change workflow rules, update both.\n\n{WORKFLOW_DOC}")
write_text("AGENTS.md", f"# AGENTS.md\n\n> Equivalent to `CLAUDE.md`. If you change workflow rules, update both.\n\n{WORKFLOW_DOC}")

# ---- Versioned docs ---------------------------------------------------------
DOC_BODIES = {
    "product": f"""# Product

## Status

{PROJECT_NAME} is newly bootstrapped. Treat product scope, terminology, and public promises as draft until validated through the workflow.

## Summary

{PROJECT_SUMMARY}

## Target Users

- <primary user or customer>
- <secondary user or operator>

## Problem

- <problem this project solves>
- <current pain or workflow gap>

## Goals

- <goal>
- <goal>
- <goal>

## Non-Goals for Now

- <explicitly out-of-scope item>
- <explicitly out-of-scope item>

## Product Direction

Keep durable product truth here. Update by creating a new version under `docs/versions/product/`, not by patching old versions.

## Terminology

- `phase`: grouped unit of work under `works/phases/active/` or `works/phases/archived/`
- `slice`: concrete unit of work inside a phase
- `deferred job`: parked work under `works/deferred/` that does not affect active selection until promoted
""",
    "experience": """# Experience

## Status

No user experience map is finalized yet.

## Purpose

Use this doc for product-facing flow truth: routes, journeys, UX states, copy tone, and user-visible behavior.

## Route / Screen Map

- <route or screen>: <purpose>

## Core User Journeys

### Journey Name

- Entry:
- Steps:
- Success state:
- Failure / recovery state:

## UX States

- Empty states:
- Loading states:
- Error states:
- Permission states:

## Copy and Tone

- <principle>

## Open Questions

-
""",
    "architecture": f"""# Architecture

## Status

{PROJECT_NAME} is newly bootstrapped. This document should describe stable system-level truth as the app takes shape.

## Current Repo Shape

- `CLAUDE.md` / `AGENTS.md`: equivalent compact routing contracts
- `docs/current/`: generated latest doc snapshots
- `docs/versions/`: immutable durable doc versions by category
- `docs/index.json`: latest-version map
- `works/state.json`: current/next pointer
- `works/index.json`: generated machine index
- `works/backlog.md`: generated human dashboard
- `works/phases/active/`: active phase folders
- `works/phases/archived/`: archived phase folders
- `works/deferred/`: deferred job folders
- `scripts/workflow.py`: workflow and docs version manager
- `.claude/`, `.agents/`, `.codex/`: tool entry points (skills, subagents, config)

## System Shape

- <frontend runtime>
- <backend runtime>
- <database / persistence>
- <background workers / queues>
- <external integrations>

## Boundaries

- Frontend boundary:
- Backend boundary:
- Data boundary:
- External service boundary:

## Cross-Cutting Constraints

- <constraint>

## Open Questions

-
""",
    "frontend": """# Frontend

## Status

No frontend implementation truth is finalized yet.

## Purpose

Use this doc for browser/client structure and conventions.

## Stack

- Framework:
- Styling:
- Component system:
- State management:
- Data fetching:

## Routes and Layouts

- <route>: <layout and responsibility>

## Component Conventions

- <convention>

## Forms and Validation

- <pattern>

## Client Auth / Session Behavior

- <pattern>

## Accessibility / Responsive Rules

- <rule>

## Open Questions

-
""",
    "backend": """# Backend

## Status

No backend implementation truth is finalized yet.

## Purpose

Use this doc for server-side module layout, domain boundaries, jobs, auth, errors, and logging.

## Stack

- Language/runtime:
- Framework:
- Package manager:
- Server entrypoint:

## Module / Service Layout

- <module>: <responsibility>

## Domain Boundaries

- <domain>: <owned behavior>

## Auth and Session Logic

- <pattern>

## Background Jobs / Workers

- <job>: <trigger and behavior>

## Error Handling and Logging

- <pattern>

## Open Questions

-
""",
    "data": """# Data

## Status

No data model is finalized yet.

## Purpose

Use this doc for database schema truth, entities, migrations, indexes, storage, retention, and seed/test data.

## Storage

- Primary DB:
- Cache:
- Object/file storage:

## Entities

### Entity Name

- Purpose:
- Key fields:
- Relationships:
- Indexes:

## Migrations

- Tooling:
- Rules:

## Retention / Deletion

- <policy>

## Seed and Test Data

- <approach>

## Open Questions

-
""",
    "api": """# API

## Status

No public-facing contracts are finalized yet. Add contracts here when they are implemented or explicitly accepted.

## Documentation Rules

- Only document a contract as stable when it is implemented or explicitly accepted.
- Mark experimental surfaces as draft.
- Record breaking changes once external consumers exist.
- Keep public contract changes synchronized with product, experience, frontend, backend, data, and security docs when boundaries change.
- Update this doc by creating a new version under `docs/versions/api/`, not by patching old versions.

## Contract Template

### Surface Name

- Status:
- Consumers:
- Purpose:
- Method / transport:
- Path / topic / event:
- Inputs:
- Outputs:
- Errors:
- Auth or permissions:
- Notes:

## Contracts

- None yet.
""",
    "operations": """# Operations

## Status

No operations truth is finalized yet.

## Purpose

Use this doc for local development, environment variables, deployment, infra, jobs, observability, backups, and recovery.

## Local Development

- Install:
- Run:
- Test:
- Build:

## Environment Variables

| Name | Required | Purpose | Notes |
|---|---|---|---|
| <NAME> | yes/no | <purpose> | <notes> |

## Deployment

- Target:
- Process:
- Rollback:

## Scheduled Jobs / Workers

- <job>: <schedule/trigger>

## Observability

- Logs:
- Metrics:
- Alerts:

## Backup / Restore

- <policy>

## Open Questions

-
""",
    "security": """# Security

## Status

No security model is finalized yet.

## Purpose

Use this doc for auth, authorization, secrets, customer data boundaries, rate limits, abuse cases, and sensitive operations.

## Auth Model

- Identity:
- Session:
- Token/cookie behavior:

## Authorization Rules

- <resource>: <who can do what>

## Secret Handling

- <rule>

## Customer Data Boundaries

- <rule>

## Rate Limits / Abuse Cases

- <case>: <mitigation>

## Security Checklist

- [ ] No secrets committed
- [ ] Auth rules documented
- [ ] Sensitive data paths documented

## Open Questions

-
""",
    "qa": """# QA

## Status

No QA strategy is finalized yet.

## Purpose

Use this doc for test commands, acceptance criteria style, manual QA missions, browser QA flows, regression checks, and known fragile areas.

## Test Commands

- Unit:
- Integration:
- E2E:
- Lint/typecheck:

## Acceptance Criteria Style

- <rule>

## Manual QA Missions

### Mission Name

- Route / entry:
- What a real user would try:
- What would feel wrong:
- Evidence to collect:

## Regression Checklist

- [ ] <check>

## Known Fragile Areas

- <area>

## Open Questions

-
""",
    "decisions": """# Decisions

## Status

No major decisions are recorded yet.

## Purpose

Use this doc as a lightweight ADR index: important choices, rejected alternatives, tradeoffs, and decision sources.

## Decision Log

### Decision Title

- Date:
- Status: proposed | accepted | superseded
- Context:
- Decision:
- Alternatives considered:
- Consequences:
- Source:

## Superseded Decisions

- None yet.
""",
}


def doc_frontmatter(doc_id: str, version: str, source: str, summary: str, previous=None) -> str:
    previous_line = f"previous: {previous}\n" if previous else "previous: null\n"
    return f"---\ndoc_id: {doc_id}\nversion: {version}\ncreated_at: {created_at}\nsource: {source}\nsummary: {summary}\n{previous_line}---\n\n"


index_docs = {}
for doc_id in DOC_TYPES:
    version_id = "v0001_bootstrap"
    rel = f"docs/versions/{doc_id}/{version_id}.md"
    summary = f"Initial {doc_id} doc"
    content = doc_frontmatter(doc_id, "v0001", "bootstrap", summary) + DOC_BODIES[doc_id]
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

- Read latest docs from `docs/current/*.md`.
- Create updates with `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source <phase-or-slice>`.
- Edit only the newly created version file under `docs/versions/<doc>/`.
- Run `python3 scripts/workflow.py rebuild-docs` after editing the new version.
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
write_text("works/templates/plan.md", """# Plan

- Phase ID: __PHASE_ID__
- Slice ID: __SLICE_ID__
- Slice: __SLICE_NAME__
- Created at: __CREATED_AT__

## Goal

## Scope

## Milestones

1.
2.
3.

## Validation

-

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

-
""")
write_text("works/templates/result.md", """# Result

- Phase ID: __PHASE_ID__
- Slice ID: __SLICE_ID__
- Slice: __SLICE_NAME__
- Review status: pending
- Next action:

## Outcome

## Deviations from Plan

## Validation Run

-

## Files Changed

-

## Doc Versions Created

-

## Roadmap Updates

-

## Retrospective

-
""")
write_text("works/templates/deferred_brief.md", """# Deferred: __DEFERRED_ID__ __TITLE__

## Context

## Why Deferred

## Trigger to Promote

## Notes

""")

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
write_text(f"{p1_path}/phase.md", f"""# Phase P1: {PHASE_NAME}

## Objective

{PHASE_OBJECTIVE}

## Context

Initial bootstrap phase. Use `P1.DECOMP` to create concrete implementation slices before coding starts.

## Decomposition

_Slice breakdown and rationale — filled by the `P1.DECOMP` slice._

## Findings & Notes

_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._

## Constraints

- Keep `works/backlog.md` lean.
- Store detailed slice context inside each slice folder.
- Create new doc versions for durable doc changes.
- Record the review with `review-phase`; phases stay in `active/` after passing and are archived manually later (`archive-all`, `rotate-backlog`, or `archive-phase`).

## Open Questions

-
""")


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
    for tmpl_name in ("plan.md", "result.md"):
        text = (ROOT / "works/templates" / tmpl_name).read_text(encoding="utf-8")
        for k, v in replacements.items():
            text = text.replace(k, v)
        write_text(f"{folder}/{tmpl_name}", text)


new_slice_files("P1", "P1.DECOMP", "decompose phase", "decomposition", "todo", 0, "low", {"type": "bootstrap", "id": None})
new_slice_files("P1", "P1.REVIEW", "phase review", "review", "todo", 9999, "medium", {"type": "bootstrap", "id": None})
write_text("works/events.jsonl", json.dumps({"ts": created_at, "type": "bootstrap", "project": PROJECT_NAME, "phase": "P1"}, ensure_ascii=False) + "\n")

# ---- Workflow engine (scripts/workflow.py) ----------------------------------
WORKFLOW_PY = r'''#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import stat
import sys
import tempfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKS = ROOT / "works"
DOCS = ROOT / "docs"
ACTIVE = WORKS / "phases" / "active"
ARCHIVED = WORKS / "phases" / "archived"
DEFERRED_OPEN = WORKS / "deferred" / "open"
DEFERRED_PROMOTED = WORKS / "deferred" / "promoted"
DEFERRED_DROPPED = WORKS / "deferred" / "dropped"
DOC_TYPES = {"product", "experience", "architecture", "frontend", "backend", "data", "api", "operations", "security", "qa", "decisions"}
PHASE_STATUSES = {"planned", "in_progress", "in_review", "blocked", "done"}
SLICE_STATUSES = {"todo", "in_progress", "in_review", "changes_requested", "blocked", "done"}
DEFERRED_STATUSES = {"deferred", "ready", "promoted", "done", "dropped"}
REVIEW_VERDICTS = {"pass", "changes_requested", "blocked"}


def now_iso() -> str:
    return datetime.now().astimezone().replace(microsecond=0).isoformat()


def timestamp() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def slugify(value: str, fallback: str = "item") -> str:
    slug = re.sub(r"[^a-zA-Z0-9._-]+", "_", value.strip().lower()).strip("_")
    return slug or fallback


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_text(path: Path, text: str, executable: bool = False) -> None:
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


def append_event(event_type: str, **payload: object) -> None:
    event = {"ts": now_iso(), "type": event_type, **payload}
    WORKS.mkdir(parents=True, exist_ok=True)
    with (WORKS / "events.jsonl").open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")


def strip_frontmatter(text: str) -> str:
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return text[end + len("\n---\n"):].lstrip("\n")
    return text


def doc_index() -> dict:
    return read_json(DOCS / "index.json")


def write_doc_index(index: dict) -> None:
    index["last_rebuilt_at"] = now_iso()
    write_json(DOCS / "index.json", index)


def rebuild_docs() -> None:
    index = doc_index()
    for doc_id, info in index.get("docs", {}).items():
        latest = next((v for v in info.get("versions", []) if v["id"] == info.get("latest")), None)
        if not latest:
            raise SystemExit(f"latest version missing in docs/index.json for {doc_id}")
        src = ROOT / latest["path"]
        if not src.exists():
            raise SystemExit(f"latest doc file missing: {latest['path']}")
        write_text(ROOT / info["current_path"], src.read_text(encoding="utf-8"))
    write_doc_index(index)


def next_doc_version_id(doc_id: str, index: dict) -> tuple:
    nums = []
    for v in index["docs"][doc_id].get("versions", []):
        m = re.match(r"v(\d+)", v["id"])
        if m:
            nums.append(int(m.group(1)))
    num = max(nums, default=0) + 1
    return f"v{num:04d}", num


def new_doc_version(args: argparse.Namespace) -> None:
    doc_id = args.doc
    if doc_id not in DOC_TYPES:
        raise SystemExit(f"doc must be one of: {', '.join(sorted(DOC_TYPES))}")
    index = doc_index()
    info = index["docs"][doc_id]
    latest_id = info["latest"]
    latest = next(v for v in info["versions"] if v["id"] == latest_id)
    base_body = strip_frontmatter((ROOT / latest["path"]).read_text(encoding="utf-8"))
    version_prefix, _ = next_doc_version_id(doc_id, index)
    version_id = f"{version_prefix}_{slugify(args.summary, 'update')}"
    rel = f"docs/versions/{doc_id}/{version_id}.md"
    dest = ROOT / rel
    if dest.exists():
        raise SystemExit(f"doc version already exists: {rel}")
    frontmatter = (
        f"---\n"
        f"doc_id: {doc_id}\n"
        f"version: {version_prefix}\n"
        f"created_at: {now_iso()}\n"
        f"source: {args.source}\n"
        f"summary: {args.summary}\n"
        f"previous: {latest_id}\n"
        f"---\n\n"
    )
    write_text(dest, frontmatter + base_body)
    info["latest"] = version_id
    info["versions"].append({
        "id": version_id, "path": rel, "created_at": now_iso(),
        "source": args.source, "summary": args.summary, "previous": latest_id,
    })
    write_doc_index(index)
    rebuild_docs()
    append_event("doc_version_created", doc=doc_id, version=version_id, source=args.source)
    print(f"created doc version {doc_id}/{version_id}")
    print(f"edit_path={rel}")
    print("after editing, run: python3 scripts/workflow.py rebuild-docs")


def cmd_docs(args: argparse.Namespace) -> None:
    index = doc_index()
    for doc_id in sorted(index["docs"]):
        info = index["docs"][doc_id]
        latest = next(v for v in info["versions"] if v["id"] == info["latest"])
        print(f"{doc_id}: latest={info['latest']} current={info['current_path']} latest_path={latest['path']}")


def validate_docs(errors: list) -> None:
    if not (DOCS / "index.json").exists():
        errors.append("missing docs/index.json")
        return
    index = doc_index()
    for doc_id in DOC_TYPES:
        info = index.get("docs", {}).get(doc_id)
        if not info:
            errors.append(f"missing doc index entry: {doc_id}")
            continue
        latest = next((v for v in info.get("versions", []) if v.get("id") == info.get("latest")), None)
        if not latest:
            errors.append(f"missing latest doc version entry: {doc_id}")
            continue
        latest_path = ROOT / latest["path"]
        current_path = ROOT / info["current_path"]
        if not latest_path.exists():
            errors.append(f"missing latest doc file: {latest['path']}")
        if not current_path.exists():
            errors.append(f"missing current doc file: {info['current_path']}")
        if latest_path.exists() and current_path.exists() and latest_path.read_text(encoding="utf-8") != current_path.read_text(encoding="utf-8"):
            errors.append(f"current doc is stale; run rebuild-docs: {doc_id}")


def phase_dirs() -> list:
    if not ACTIVE.exists():
        return []
    return sorted([p for p in ACTIVE.iterdir() if p.is_dir() and (p / "phase.json").exists()], key=lambda p: read_json(p / "phase.json").get("order", 999999))


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


def rebuild_deferred_dashboard(groups=None, rebuilt_at=None) -> None:
    groups = groups or deferred_jobs()
    rebuilt_at = rebuilt_at or now_iso()
    open_count = len(groups.get("open", []))
    promoted_count = len(groups.get("promoted", []))
    dropped_count = len(groups.get("dropped", []))
    lines = [
        "# Deferred Jobs", "", "> Generated dashboard. Do not put detailed deferred context here; edit each `works/deferred/<state>/<DID>/` folder instead.", "",
        "## Summary", "",
        f"- Open: `{open_count}`", f"- Promoted: `{promoted_count}`", f"- Dropped: `{dropped_count}`", f"- Rebuilt at: `{rebuilt_at}`", "",
        "## Open", "", "| ID | Status | Title | Source | Trigger | Path |", "|---|---|---|---|---|---|",
    ]
    if not groups.get("open"):
        lines.append("| - | - | - | - | - | - |")
    for d in groups.get("open", []):
        lines.append(f"| `{clean_cell(d.get('id'))}` | `{clean_cell(d.get('status'))}` | {clean_cell(d.get('title'))} | {clean_cell(d.get('source'))} | {clean_cell(d.get('trigger'))} | `{clean_cell(d.get('path'))}` |")
    lines.extend(["", "## Promoted", "", "| ID | Status | Title | Promoted To | Path |", "|---|---|---|---|---|"])
    if not groups.get("promoted"):
        lines.append("| - | - | - | - | - |")
    for d in groups.get("promoted", []):
        lines.append(f"| `{clean_cell(d.get('id'))}` | `{clean_cell(d.get('status'))}` | {clean_cell(d.get('title'))} | `{clean_cell(d.get('promoted_to'))}` | `{clean_cell(d.get('path'))}` |")
    lines.extend(["", "## Dropped", "", "| ID | Status | Title | Reason | Path |", "|---|---|---|---|---|"])
    if not groups.get("dropped"):
        lines.append("| - | - | - | - | - |")
    for d in groups.get("dropped", []):
        lines.append(f"| `{clean_cell(d.get('id'))}` | `{clean_cell(d.get('status'))}` | {clean_cell(d.get('title'))} | {clean_cell(d.get('dropped_reason'))} | `{clean_cell(d.get('path'))}` |")
    lines.append("")
    write_text(WORKS / "deferred.md", "\n".join(lines))


def resolve_current(phases: list) -> tuple:
    for phase in phases:
        if phase.get("status") == "done":
            continue
        current_phase = phase["id"]
        if phase.get("status") == "blocked":
            return current_phase, None, None
        open_slices = [s for s in phase["slices"] if s.get("status") != "done"]
        if open_slices:
            return current_phase, open_slices[0]["id"], open_slices[1]["id"] if len(open_slices) > 1 else None
        return current_phase, None, None
    return None, None, None


def rebuild_index_and_state() -> None:
    phases = all_active_phases()
    current_phase, current_slice, next_slice = resolve_current(phases)
    deferred = deferred_jobs()
    rebuilt_at = now_iso()
    index = {
        "active_phases": [
            {
                "id": p["id"], "name": p["name"], "objective": p["objective"], "status": p["status"],
                "order": p.get("order"), "path": p["path"],
                "review_status": p.get("review", {}).get("status"),
                "current_slice": next((s["id"] for s in p["slices"] if s.get("status") != "done"), None),
                "slice_count": len(p["slices"]),
                "done_slice_count": sum(1 for s in p["slices"] if s.get("status") == "done"),
            } for p in phases
        ],
        "deferred_open_count": len(deferred.get("open", [])),
        "deferred_promoted_count": len(deferred.get("promoted", [])),
        "deferred_dropped_count": len(deferred.get("dropped", [])),
        "last_rebuilt_at": rebuilt_at,
    }
    write_json(WORKS / "index.json", index)
    state = {"current_phase": current_phase, "current_slice": current_slice, "next_slice": next_slice, "mode": "phase" if current_phase else "idle", "updated_at": rebuilt_at}
    write_json(WORKS / "state.json", state)
    rebuild_backlog(phases, state, index)
    rebuild_deferred_dashboard(deferred, rebuilt_at)


def rebuild_backlog(phases: list, state: dict, index: dict) -> None:
    lines = [
        "# Backlog", "", "> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.", "",
        "## Pointer", "",
        f"- Current phase: `{state.get('current_phase') or 'none'}`",
        f"- Current slice: `{state.get('current_slice') or 'none'}`",
        f"- Next slice: `{state.get('next_slice') or 'none'}`",
        f"- Open deferred jobs: `{index.get('deferred_open_count', 0)}`",
        f"- Rebuilt at: `{index.get('last_rebuilt_at')}`", "",
        "## Active Phases", "", "| Phase | Status | Review | Objective | Current Slice | Path |", "|---|---|---|---|---|---|",
    ]
    if not phases:
        lines.append("| - | - | - | - | - | - |")
    for p in phases:
        current = next((s["id"] for s in p["slices"] if s.get("status") != "done"), "none")
        objective = clean_cell(p.get("objective", ""))
        review = clean_cell(p.get("review", {}).get("status"))
        lines.append(f"| `{p['id']}` | `{p['status']}` | `{review}` | {objective} | `{current}` | `{p['path']}` |")
    for p in phases:
        lines.extend(["", f"## Phase {p['id']}: {p['name']}", "", "| Slice | Status | Name | Kind | Path |", "|---|---|---|---|---|"])
        for s in p["slices"]:
            checkbox = "x" if s.get("status") == "done" else " "
            name = clean_cell(s.get("name", ""))
            lines.append(f"| [{checkbox}] `{s['id']}` | `{s['status']}` | {name} | `{clean_cell(s.get('kind', ''))}` | `{s['path']}` |")
    lines.append("")
    write_text(WORKS / "backlog.md", "\n".join(lines))


def validate() -> int:
    errors: list = []
    phases = all_active_phases()
    seen_phases, seen_slices = set(), set()
    all_slice_ids = {s["id"] for p in phases for s in p["slices"]}
    for p in phases:
        if p["id"] in seen_phases:
            errors.append(f"duplicate phase id: {p['id']}")
        seen_phases.add(p["id"])
        if p["status"] not in PHASE_STATUSES:
            errors.append(f"invalid phase status {p['id']}: {p['status']}")
        review_status = p.get("review", {}).get("status")
        if p["status"] == "done" and review_status != "pass":
            errors.append(f"phase {p['id']} is done but review status is {review_status!r}; record a passing review with review-phase")
        for s in p["slices"]:
            if s["id"] in seen_slices:
                errors.append(f"duplicate slice id: {s['id']}")
            seen_slices.add(s["id"])
            if s["phase_id"] != p["id"]:
                errors.append(f"slice phase mismatch: {s['id']} says {s['phase_id']}, folder phase is {p['id']}")
            if s["status"] not in SLICE_STATUSES:
                errors.append(f"invalid slice status {s['id']}: {s['status']}")
            for dep in s.get("depends_on", []):
                if dep not in all_slice_ids:
                    errors.append(f"missing dependency for {s['id']}: {dep}")
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
                errors.append(f"missing deferred.json: {ddir.relative_to(ROOT)}")
                continue
            data = read_json(djson)
            if data.get("status") not in DEFERRED_STATUSES:
                errors.append(f"invalid deferred status {data.get('id')}: {data.get('status')}")
            if data.get("status") not in allowed:
                errors.append(f"deferred job in wrong folder: {data.get('id')} status {data.get('status')} under {base.relative_to(ROOT)}")
    validate_docs(errors)
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


def create_slice(phase_id: str, slice_id: str, name: str, kind: str, order: int, risk: str, source: dict, depends_on=None) -> Path:
    require_phase(phase_id)
    if not slice_id.startswith(f"{phase_id}."):
        raise SystemExit(f"slice id must start with {phase_id}.")
    sdir = ACTIVE / phase_id / "slices" / slice_id
    if sdir.exists():
        raise SystemExit(f"slice already exists: {slice_id}")
    created = now_iso()
    data = {
        "id": slice_id, "phase_id": phase_id, "name": name, "kind": kind, "status": "todo", "order": order,
        "depends_on": depends_on or [], "created_at": created, "started_at": None, "completed_at": None, "risk": risk, "source": source,
        "paths": {"plan": "plan.md", "result": "result.md"},
        "validation": {"required": [], "last_run": None, "last_status": "pending"},
        "archive": {"archived": False, "archived_at": None, "archive_path": None},
    }
    write_json(sdir / "slice.json", data)
    common = {"PHASE_ID": phase_id, "SLICE_ID": slice_id, "SLICE_NAME": name, "CREATED_AT": created}
    for name_in in ("plan.md", "result.md"):
        write_text(sdir / name_in, render_template(load_template(name_in), **common))
    return sdir


def new_phase(args: argparse.Namespace) -> None:
    phase_id = args.phase
    if not re.fullmatch(r"P[0-9]+", phase_id):
        raise SystemExit("phase must look like P1, P2, P3")
    pdir = ACTIVE / phase_id
    if pdir.exists():
        raise SystemExit(f"phase already exists: {phase_id}")
    order = args.order if args.order is not None else max([read_json(p / "phase.json").get("order", 0) for p in phase_dirs()], default=0) + 1
    phase_data = {
        "id": phase_id, "name": args.name, "objective": args.objective, "status": "planned", "order": order,
        "created_at": now_iso(), "started_at": None, "completed_at": None,
        "review": {"status": "pending", "reviewed_at": None, "reviewer": None, "note": None},
        "paths": {"phase_md": "phase.md", "slices_dir": "slices"},
        "archive": {"archived": False, "archived_at": None, "archive_path": None},
    }
    write_json(pdir / "phase.json", phase_data)
    write_text(pdir / "phase.md", f"# Phase {phase_id}: {args.name}\n\n## Objective\n\n{args.objective}\n\n## Context\n\n## Decomposition\n\n_Slice breakdown and rationale — filled by the `{phase_id}.DECOMP` slice._\n\n## Findings & Notes\n\n_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._\n\n## Constraints\n\n## Open Questions\n\n-\n")
    create_slice(phase_id, f"{phase_id}.DECOMP", "decompose phase", "decomposition", 0, "low", source={"type": "new_phase", "id": phase_id})
    create_slice(phase_id, f"{phase_id}.REVIEW", "phase review", "review", 9999, "medium", source={"type": "new_phase", "id": phase_id})
    append_event("phase_created", phase=phase_id)
    rebuild_index_and_state()
    print(f"created phase {phase_id}: {pdir.relative_to(ROOT)}")


def _auto_order(pdir: Path, explicit) -> int:
    if explicit is not None:
        return explicit
    orders = [read_json(s / "slice.json").get("order", 0) for s in slice_dirs(pdir) if read_json(s / "slice.json").get("kind") != "review"]
    return max(orders, default=0) + 10


def new_slice(args: argparse.Namespace) -> None:
    pdir = require_phase(args.phase)
    order = _auto_order(pdir, args.order)
    sdir = create_slice(args.phase, args.slice, args.name, args.kind, order, args.risk, source={"type": "manual", "id": None}, depends_on=args.depends_on or [])
    append_event("slice_created", phase=args.phase, slice=args.slice)
    rebuild_index_and_state()
    print(f"created slice {args.slice}: {sdir.relative_to(ROOT)}")


def set_slice_status(slice_id: str, status: str) -> None:
    if status not in SLICE_STATUSES:
        raise SystemExit(f"invalid slice status: {status}")
    sdir = require_slice(slice_id)
    data = read_json(sdir / "slice.json")
    old = data.get("status")
    data["status"] = status
    if status == "in_progress" and not data.get("started_at"):
        data["started_at"] = now_iso()
    if status == "done":
        data["completed_at"] = now_iso()
    write_json(sdir / "slice.json", data)
    append_event("slice_status_changed", slice=slice_id, old_status=old, new_status=status)
    rebuild_index_and_state()


def start_slice(args: argparse.Namespace) -> None:
    set_slice_status(args.slice, "in_progress")
    print(f"started {args.slice}")


def finish_slice(args: argparse.Namespace) -> None:
    set_slice_status(args.slice, "done")
    print(f"finished {args.slice}")


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


def review_phase(args: argparse.Namespace) -> None:
    if args.verdict not in REVIEW_VERDICTS:
        raise SystemExit(f"verdict must be one of: {', '.join(sorted(REVIEW_VERDICTS))}")
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    data["review"] = {"status": args.verdict, "reviewed_at": now_iso(), "reviewer": args.reviewer, "note": args.note}
    # Verdict drives phase status so the lifecycle stays consistent.
    status_map = {"pass": "done", "changes_requested": "in_progress", "blocked": "blocked"}
    new_status = status_map[args.verdict]
    if new_status == "done":
        data["completed_at"] = now_iso()
    data["status"] = new_status
    write_json(pdir / "phase.json", data)
    append_event("phase_reviewed", phase=args.phase, verdict=args.verdict, reviewer=args.reviewer)
    rebuild_index_and_state()
    print(f"phase {args.phase} review: {args.verdict} (status -> {new_status})")
    if args.verdict == "changes_requested":
        print("create fix slices, e.g.: python3 scripts/workflow.py new-slice --phase {0} --slice {0}.F1 --name \"...\" --kind fix".format(args.phase))
    elif args.verdict == "pass":
        print(f"phase {args.phase} is done and stays in active/. Do NOT archive a single phase now.")
        print("Archive all phases together with `archive-all` only once every active phase is done (the last review slice is complete).")


def cmd_next(args: argparse.Namespace) -> None:
    rebuild_index_and_state()
    state = read_json(WORKS / "state.json")
    current_slice = state.get("current_slice")
    if not current_slice:
        if state.get("current_phase"):
            print(f"current_phase={state['current_phase']}")
            print("no open slice in the current phase; review/archive it or create a new phase")
        else:
            print("no active slice; create a phase or promote deferred work")
        return
    sdir = require_slice(current_slice)
    print(f"current_phase={current_slice.split('.', 1)[0]}")
    print(f"current_slice={current_slice}")
    print(f"slice_path={sdir.relative_to(ROOT)}")
    print(f"next_slice={state.get('next_slice') or 'none'}")


def cmd_deferred(args: argparse.Namespace) -> None:
    rebuild_index_and_state()
    groups = deferred_jobs()
    print(f"open={len(groups.get('open', []))}")
    print(f"promoted={len(groups.get('promoted', []))}")
    print(f"dropped={len(groups.get('dropped', []))}")
    print("dashboard=works/deferred.md")


def next_deferred_id() -> str:
    max_n = 0
    for base in (DEFERRED_OPEN, DEFERRED_PROMOTED, DEFERRED_DROPPED):
        if not base.exists():
            continue
        for p in base.iterdir():
            m = re.fullmatch(r"D(\d+)", p.name)
            if m:
                max_n = max(max_n, int(m.group(1)))
    return f"D{max_n + 1}"


def defer_job(args: argparse.Namespace) -> None:
    did = args.id or next_deferred_id()
    ddir = DEFERRED_OPEN / did
    if ddir.exists():
        raise SystemExit(f"deferred job already exists: {did}")
    created = now_iso()
    data = {"id": did, "title": args.title, "status": "deferred", "source": args.source, "reason": args.reason, "trigger": args.trigger, "created_at": created, "promoted_to": None, "dropped_reason": None}
    write_json(ddir / "deferred.json", data)
    text = load_template("deferred_brief.md").replace("__DEFERRED_ID__", did).replace("__TITLE__", args.title)
    text = text.replace("## Why Deferred\n", f"## Why Deferred\n\n{args.reason}\n")
    text = text.replace("## Trigger to Promote\n", f"## Trigger to Promote\n\n{args.trigger}\n")
    write_text(ddir / "brief.md", text)
    append_event("deferred_created", deferred=did, source=args.source)
    rebuild_index_and_state()
    print(f"created deferred job {did}: {ddir.relative_to(ROOT)}")


def promote_deferred(args: argparse.Namespace) -> None:
    did = args.deferred_id
    ddir = DEFERRED_OPEN / did
    if not (ddir / "deferred.json").exists():
        raise SystemExit(f"open deferred job not found: {did}")
    data = read_json(ddir / "deferred.json")
    if not (ACTIVE / args.phase / "phase.json").exists():
        if not args.create_phase:
            raise SystemExit(f"phase does not exist: {args.phase}. Use --create-phase to create it.")
        ns = argparse.Namespace(phase=args.phase, name=args.phase_name or data["title"], objective=args.phase_objective or data["title"], order=None)
        new_phase(ns)
    pdir = require_phase(args.phase)
    order = _auto_order(pdir, args.order)
    sdir = create_slice(args.phase, args.slice, args.name or data["title"], args.kind, order, args.risk, source={"type": "deferred", "id": did, "path": str(ddir.relative_to(ROOT))}, depends_on=args.depends_on or [])
    with (sdir / "plan.md").open("a", encoding="utf-8") as f:
        f.write("\n---\n\n## Promoted Deferred Context\n\n")
        f.write((ddir / "brief.md").read_text(encoding="utf-8"))
    data["status"] = "promoted"
    data["promoted_to"] = {"phase_id": args.phase, "slice_id": args.slice, "path": str(sdir.relative_to(ROOT))}
    write_json(ddir / "deferred.json", data)
    target = DEFERRED_PROMOTED / did
    if target.exists():
        raise SystemExit(f"promoted destination already exists: {target.relative_to(ROOT)}")
    shutil.move(str(ddir), str(target))
    append_event("deferred_promoted", deferred=did, phase=args.phase, slice=args.slice)
    rebuild_index_and_state()
    print(f"promoted {did} -> {args.slice}: {sdir.relative_to(ROOT)}")


def drop_deferred(args: argparse.Namespace) -> None:
    did = args.deferred_id
    ddir = DEFERRED_OPEN / did
    if not (ddir / "deferred.json").exists():
        raise SystemExit(f"open deferred job not found: {did}")
    data = read_json(ddir / "deferred.json")
    data["status"] = "dropped"
    data["dropped_reason"] = args.reason
    write_json(ddir / "deferred.json", data)
    target = DEFERRED_DROPPED / did
    if target.exists():
        raise SystemExit(f"dropped destination already exists: {target.relative_to(ROOT)}")
    shutil.move(str(ddir), str(target))
    append_event("deferred_dropped", deferred=did, reason=args.reason)
    rebuild_index_and_state()
    print(f"dropped {did}: {target.relative_to(ROOT)}")


def _phase_blockers(pdir: Path) -> list:
    """Reasons a phase is not cleanly archivable; empty list means ready."""
    phase = read_json(pdir / "phase.json")
    slices = [read_json(s / "slice.json") for s in slice_dirs(pdir)]
    reasons = []
    not_done = [s["id"] for s in slices if s.get("status") != "done"]
    if not_done:
        reasons.append(f"unfinished slices: {', '.join(not_done)}")
    review_status = phase.get("review", {}).get("status")
    if review_status != "pass":
        reasons.append(f"review is {review_status!r}, not pass")
    return reasons


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


def archive_phase(args: argparse.Namespace) -> None:
    # First-class single-phase archive: archive one review-passed phase on request.
    # Useful when only some phases are done. For the partial sweep of every done
    # phase use rotate-backlog; for the end-of-batch sweep of everything use
    # archive-all. --force is for exceptional cleanup of an unfinished phase only.
    pdir = require_phase(args.phase)
    if not args.force:
        reasons = _phase_blockers(pdir)
        if reasons:
            raise SystemExit(f"phase {args.phase} is not archivable ({'; '.join(reasons)}). Finish/review it, or use --force for exceptional cleanup.")
    dest = _archive_one(pdir, forced=args.force)
    rebuild_index_and_state()
    print(f"archived phase {args.phase}: {dest.relative_to(ROOT)}")


def archive_all(args: argparse.Namespace) -> None:
    # Batch-archive every active phase at once. Gated so archiving only happens
    # once the last review slice across all active phases is done.
    pdirs = phase_dirs()
    if not pdirs:
        print("no active phases to archive")
        return
    if not args.force:
        blockers = []
        for pdir in pdirs:
            reasons = _phase_blockers(pdir)
            if reasons:
                blockers.append(f"{read_json(pdir / 'phase.json')['id']}: {'; '.join(reasons)}")
        if blockers:
            print("not archiving: every active phase must be done (the last review slice complete) before a batch archive.")
            for b in blockers:
                print(f"- {b}")
            raise SystemExit("Finish the open phases first, or use --force for exceptional cleanup.")
    archived = []
    for pdir in pdirs:
        phase_id = read_json(pdir / "phase.json")["id"]
        dest = _archive_one(pdir, forced=args.force)
        archived.append((phase_id, dest))
    rebuild_index_and_state()
    print(f"archived {len(archived)} phase(s):")
    for phase_id, dest in archived:
        print(f"- {phase_id}: {dest.relative_to(ROOT)}")


def rotate_backlog(args: argparse.Namespace) -> None:
    # Partial rotation: archive every phase that is cleanly archivable right now
    # (all slices done with a passing review) and leave the rest active, then
    # rebuild the dashboards. This is the partial sweep archive-all cannot do,
    # since archive-all refuses unless EVERY active phase is done.
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
        print(f"- {phase_id}: {dest.relative_to(ROOT)}")
    if blocked:
        print(f"left {len(blocked)} phase(s) active: {', '.join(p for p, _ in blocked)}")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Manage the agentic workflow state.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("rebuild", help="Rebuild workflow dashboards/index/state and docs snapshots")
    p.set_defaults(func=lambda args: (rebuild_docs(), rebuild_index_and_state(), print("rebuilt workflow and docs")))

    p = sub.add_parser("rebuild-docs", help="Regenerate docs/current/*.md from docs/index.json latest versions")
    p.set_defaults(func=lambda args: (rebuild_docs(), print("rebuilt docs/current from latest versions")))

    p = sub.add_parser("docs", help="Print latest doc versions")
    p.set_defaults(func=cmd_docs)

    p = sub.add_parser("doc-new-version", help="Create a new durable doc version from the latest version")
    p.add_argument("--doc", required=True, choices=sorted(DOC_TYPES))
    p.add_argument("--summary", required=True)
    p.add_argument("--source", required=True)
    p.set_defaults(func=new_doc_version)

    p = sub.add_parser("validate", help="Validate workflow and docs structure")
    p.set_defaults(func=lambda args: sys.exit(validate()))

    p = sub.add_parser("next", help="Print the current phase/slice selection")
    p.set_defaults(func=cmd_next)

    p = sub.add_parser("deferred", help="Rebuild and print deferred jobs dashboard summary")
    p.set_defaults(func=cmd_deferred)

    p = sub.add_parser("new-phase", help="Create a new phase with DECOMP and REVIEW slices")
    p.add_argument("--phase", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--objective", required=True)
    p.add_argument("--order", type=int)
    p.set_defaults(func=new_phase)

    p = sub.add_parser("new-slice", help="Create a new slice folder with slice.json + markdown files")
    p.add_argument("--phase", required=True)
    p.add_argument("--slice", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--kind", default="implementation")
    p.add_argument("--risk", default="medium")
    p.add_argument("--order", type=int)
    p.add_argument("--depends-on", action="append")
    p.set_defaults(func=new_slice)

    p = sub.add_parser("start-slice", help="Mark a slice in_progress")
    p.add_argument("slice")
    p.set_defaults(func=start_slice)

    p = sub.add_parser("finish-slice", help="Mark a slice done")
    p.add_argument("slice")
    p.set_defaults(func=finish_slice)

    p = sub.add_parser("set-slice-status", help="Set any valid slice status")
    p.add_argument("slice")
    p.add_argument("status")
    p.set_defaults(func=lambda args: (set_slice_status(args.slice, args.status), print(f"slice {args.slice}: {args.status}")))

    p = sub.add_parser("set-phase-status", help="Set any valid phase status")
    p.add_argument("phase")
    p.add_argument("status")
    p.set_defaults(func=set_phase_status)

    p = sub.add_parser("review-phase", help="Record a phase review verdict (pass/changes_requested/blocked)")
    p.add_argument("phase")
    p.add_argument("--verdict", required=True, choices=sorted(REVIEW_VERDICTS))
    p.add_argument("--reviewer", default=None)
    p.add_argument("--note", default=None)
    p.set_defaults(func=review_phase)

    p = sub.add_parser("defer-job", help="Create a deferred job folder")
    p.add_argument("--id")
    p.add_argument("--title", required=True)
    p.add_argument("--reason", required=True)
    p.add_argument("--trigger", required=True)
    p.add_argument("--source", required=True)
    p.set_defaults(func=defer_job)

    p = sub.add_parser("promote-deferred", help="Promote an open deferred job into an active slice")
    p.add_argument("deferred_id")
    p.add_argument("--phase", required=True)
    p.add_argument("--slice", required=True)
    p.add_argument("--name")
    p.add_argument("--kind", default="implementation")
    p.add_argument("--risk", default="medium")
    p.add_argument("--order", type=int)
    p.add_argument("--depends-on", action="append")
    p.add_argument("--create-phase", action="store_true")
    p.add_argument("--phase-name")
    p.add_argument("--phase-objective")
    p.set_defaults(func=promote_deferred)

    p = sub.add_parser("drop-deferred", help="Drop an open deferred job")
    p.add_argument("deferred_id")
    p.add_argument("--reason", required=True)
    p.set_defaults(func=drop_deferred)

    p = sub.add_parser("archive-phase", help="Archive a single review-passed phase (first-class; use when only some phases are done)")
    p.add_argument("phase")
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=archive_phase)

    p = sub.add_parser("archive-all", help="Batch-archive ALL active phases at once; only when every phase is done (last review slice complete)")
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=archive_all)

    p = sub.add_parser("rotate-backlog", help="Archive every currently-done phase and leave in-progress phases active, then rebuild (partial archive-all)")
    p.set_defaults(func=rotate_backlog)

    args = parser.parse_args(argv)
    result = args.func(args)
    if isinstance(result, tuple):
        return 0
    return 0 if result is None else int(result or 0)


if __name__ == "__main__":
    raise SystemExit(main())
'''
write_text("scripts/workflow.py", WORKFLOW_PY, executable=True)

# ---- Agent surfaces: skills for both tools ----------------------------------
def claude_skill(name: str, desc: str, tools: str, body: str) -> str:
    return (
        "---\n"
        f"name: {name}\n"
        f"description: {desc}\n"
        f"allowed-tools: {tools}\n"
        "disable-model-invocation: true\n"
        "---\n\n"
        f"# {name}\n\n{body}"
    )


def codex_skill(name: str, desc: str, body: str) -> str:
    return (
        "---\n"
        f"name: {name}\n"
        f"description: {desc}\n"
        "---\n\n"
        f"# {name}\n\n{body}"
    )


def codex_openai_yaml(name: str, desc: str) -> str:
    return (
        "interface:\n"
        f"  display_name: \"{name}\"\n"
        f"  short_description: \"{desc}\"\n"
        f"  default_prompt: \"Use the {name} skill.\"\n"
        "policy:\n"
        "  allow_implicit_invocation: false\n"
    )


for s in COMMAND_SKILLS:
    write_text(f".claude/skills/{s['name']}/SKILL.md", claude_skill(s["name"], s["desc"], s["tools"], s["body"]))
    write_text(f".agents/skills/{s['name']}/SKILL.md", codex_skill(s["name"], s["desc"], s["body"]))
    write_text(f".agents/skills/{s['name']}/agents/openai.yaml", codex_openai_yaml(s["name"], s["desc"]))

# Claude Code subagent: read-only reviewer that reuses the review-phase checklist.
write_text(".claude/agents/phase-reviewer.md", """---
name: phase-reviewer
description: Reviews a completed phase against objective, slices, docs, validation, and workflow integrity. Read-only.
tools: Read, Glob, Grep, Bash
model: inherit
---

You are the phase reviewer for this agentic workspace, running in an isolated read-only context.

Follow the checklist in the `review-phase` skill (`.claude/skills/review-phase/SKILL.md`). Read the phase folder under `works/phases/active/<phase_id>/`, the completed slices' `slice.json` and `result.md`, the relevant `docs/current/*.md`, and `docs/index.json`. You may run `python3 scripts/workflow.py validate` to check docs/state integrity.

Do not edit files. Return exactly one verdict to the parent agent, with a short justification:

- `pass`
- `changes_requested` — with numbered issues and proposed fix slices such as `P1.F1`
- `blocked` — with the blocker and needed input

The parent agent records the verdict with `python3 scripts/workflow.py review-phase <P> --verdict <verdict> --reviewer phase-reviewer --note "..."`.
""")

# ---- Claude Code project settings: pre-approve the workflow manager ----------
write_json(".claude/settings.json", {
    "permissions": {
        "allow": [
            "Bash(python3 scripts/workflow.py:*)",
            "Read",
            "Edit",
            "Write",
            "Glob",
            "Grep",
        ],
        "deny": [
            "Bash(git push:*)",
            "Bash(rm -rf:*)",
        ],
    },
})

# ---- Codex project config (documentation + safe defaults) -------------------
write_text(".codex/config.toml", """# Project-scoped Codex notes for this agentic workspace.
#
# Codex reads instructions from AGENTS.md and discovers repo skills under
# .agents/skills/ automatically. The primary Codex config lives in your user
# home (~/.codex/config.toml); keep machine/account settings there.
#
# Recommended user-level settings to pair with this workspace:
#
#   # Treat this repo root as the project root.
#   project_root_markers = [".git"]
#
#   # Optional: a read-only phase-review subagent. See the schema at
#   # https://developers.openai.com/codex/subagents
#   # Until then, the `review-phase` skill provides the same checklist and
#   # records the verdict via: python3 scripts/workflow.py review-phase ...

project_root_markers = [".git"]
""")

# ---- Generate dashboards/state from the source of truth, then self-check ----
def run_workflow(*workflow_args: str) -> None:
    subprocess.run([sys.executable, str(ROOT / "scripts" / "workflow.py"), *workflow_args], cwd=str(ROOT), check=True)


run_workflow("rebuild")
run_workflow("validate")

print(f"Bootstrapped cross-tool agentic workspace at {TARGET}")
print("Contracts: CLAUDE.md and AGENTS.md (equivalent)")
print("Claude Code: skills in .claude/skills/ (e.g. /do-next-slice), subagent .claude/agents/phase-reviewer.md, settings .claude/settings.json")
print("Codex: skills in .agents/skills/ (e.g. $do-next-slice), instructions AGENTS.md")
print("Any agent / CI: python3 scripts/workflow.py <command>")
print("Canonical state: phase.json / slice.json / deferred.json; generated: works/backlog.md, works/deferred.md")
print("Versioned docs: docs/versions/<doc>/vNNNN_*.md with generated docs/current/*.md")
print(f"Created initial phase: P1 - {PHASE_NAME}")
print("Next: python3 scripts/workflow.py next   (or /do-next-slice in Claude Code)")
PY
