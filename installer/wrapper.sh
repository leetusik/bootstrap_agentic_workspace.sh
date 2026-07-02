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
  --into-existing             Non-destructively retrofit into an existing repo (see docs/retrofit-guide.md)
  --update                    Update an already-installed workspace's machinery to this version
  --dry-run                   With --update, preview the change-list without writing anything
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
- Each slice owns slice.json plus plan.md (the orchestrator's free-form native plan, written at the slice's turn) and result.md (written at slice end).
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
into_existing=0
update=0
dry_run=0

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
    --into-existing) into_existing=1; shift ;;
    --update) update=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --) shift; while [ $# -gt 0 ]; do [ -z "$target_dir" ] || die "only one TARGET_DIR may be provided"; target_dir=$1; shift; done ;;
    -*) die "unknown option $1" ;;
    *) [ -z "$target_dir" ] || die "only one TARGET_DIR may be provided"; target_dir=$1; shift ;;
  esac
done

[ -n "$target_dir" ] || target_dir=.
[ -e "$target_dir" ] && [ ! -d "$target_dir" ] && die "target exists but is not a directory: $target_dir"
[ "$update" = 1 ] && [ "$into_existing" = 1 ] && die "--update and --into-existing are mutually exclusive"
[ "$dry_run" = 1 ] && [ "$update" = 0 ] && die "--dry-run is only valid with --update"

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
export INTO_EXISTING="$into_existing"
export UPDATE="$update"
export DRY_RUN="$dry_run"

python3 - <<'INSTALLER_PY'
#@@PYTHON_BODY@@
INSTALLER_PY
