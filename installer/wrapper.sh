#!/bin/sh
set -eu

usage() {
  cat <<'USAGE'
Usage:
  bootstrap_agentic_workspace.sh [TARGET_DIR] [options]

By default the install is private and nested: TARGET_DIR is a git repo's root
(a new or empty dir is git init-ed as that host repo). The engine and its state
go to <target>/workflow/, a nested git repo; skills, agents,
.claude/settings.local.json and CLAUDE.local.md go to the host untracked, all
hidden by the host's .git/info/exclude, so no tracked file changes.

Options:
  --name NAME                 Optional project name override
  --summary TEXT              Optional one-sentence summary override
  --at-root                   Install the committed, team-visible layout instead, into a
                              fresh dir (CLAUDE.md, .claude/, scripts/, works/, docs/ at its root)
  --force-empty-ok            With --at-root: allow a target with extra non-managed files
  --into-existing             At-root retrofit into an existing repo, non-destructively
                              (see docs/retrofit-guide.md)
  --update                    Update an installed workspace's machinery to this version; the
                              layout (nested or at-root) is detected from what is installed
  --dry-run                   With --update, preview the change-list without writing anything
  --nested                    Accepted and redundant: the nested layout is the default
  -h, --help                  Show this help

TARGET_DIR defaults to the current directory.

This bootstrap creates a compact, scalable agentic workspace tuned for
Claude Code:

- CLAUDE.md is the compact routing contract every agent reads (nested:
  workflow/CLAUDE.workspace.md, imported by the host's CLAUDE.local.md).
- Operations ship as Agent Skills in .claude/skills/ (Claude Code: /slash +
  auto-invocation).
- works/backlog.md and works/deferred.md are generated dashboards, never the
  task database. Canonical state is JSON in the phase/slice/deferred folders.
- Each slice owns slice.json plus plan.md (the orchestrator's free-form native plan, written at the slice's turn) and result.md (written at slice end).
- Deferred jobs are one folder per job and never affect next-slice selection
  until promoted.
- Phase review is recorded (review-phase) and gates archiving.
- Docs are versioned fullstack categories: agents create
  docs/versions/<doc>/vNNNN_*.md and regenerate docs/current/*.md.

Requires python3 (>= 3.8), and git for the default nested install. A fresh
install never overwrites an installed workspace: refresh one with --update.
USAGE
}

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }
need_value() { [ $# -ge 2 ] || die "$1 requires a value"; [ -n "$2" ] || die "$1 requires a non-empty value"; }

target_dir=
project_name=
project_summary=
force_empty_ok=0
into_existing=0
update=0
dry_run=0
nested=0
at_root=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --name) need_value "$1" "${2-}"; project_name=$2; shift 2 ;;
    --name=*) project_name=${1#--name=}; [ -n "$project_name" ] || die "--name requires a non-empty value"; shift ;;
    --summary) need_value "$1" "${2-}"; project_summary=$2; shift 2 ;;
    --summary=*) project_summary=${1#--summary=}; [ -n "$project_summary" ] || die "--summary requires a non-empty value"; shift ;;
    --force-empty-ok) force_empty_ok=1; shift ;;
    --into-existing) into_existing=1; shift ;;
    --update) update=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --nested) nested=1; shift ;;
    --at-root) at_root=1; shift ;;
    --) shift; while [ $# -gt 0 ]; do [ -z "$target_dir" ] || die "only one TARGET_DIR may be provided"; target_dir=$1; shift; done ;;
    -*) die "unknown option $1" ;;
    *) [ -z "$target_dir" ] || die "only one TARGET_DIR may be provided"; target_dir=$1; shift ;;
  esac
done

[ -n "$target_dir" ] || target_dir=.
[ -e "$target_dir" ] && [ ! -d "$target_dir" ] && die "target exists but is not a directory: $target_dir"
[ "$update" = 1 ] && [ "$into_existing" = 1 ] && die "--update and --into-existing are mutually exclusive"
[ "$dry_run" = 1 ] && [ "$update" = 0 ] && die "--dry-run is only valid with --update"
[ "$at_root" = 1 ] && [ "$nested" = 1 ] && die "--at-root and --nested are mutually exclusive"
[ "$nested" = 1 ] && [ "$into_existing" = 1 ] && die "--nested and --into-existing are mutually exclusive (--nested installs into a host repo without changing any tracked file)"
[ "$force_empty_ok" = 1 ] && [ "$at_root" = 0 ] && [ "$into_existing" = 0 ] && die "--force-empty-ok applies to the at-root install; add --at-root"

# Fixed non-interactive defaults.
[ -n "$project_name" ] || project_name="New Project"
[ -n "$project_summary" ] || project_summary="Fresh agentic workspace. Replace this summary during the first real task."

command -v python3 >/dev/null 2>&1 || die "python3 is required for this bootstrap"

export TARGET_DIR="$target_dir"
export PROJECT_NAME="$project_name"
export PROJECT_SUMMARY="$project_summary"
export FORCE_EMPTY_OK="$force_empty_ok"
export INTO_EXISTING="$into_existing"
export UPDATE="$update"
export DRY_RUN="$dry_run"
export NESTED="$nested"
export AT_ROOT="$at_root"

python3 - <<'INSTALLER_PY'
#@@PYTHON_BODY@@
INSTALLER_PY
