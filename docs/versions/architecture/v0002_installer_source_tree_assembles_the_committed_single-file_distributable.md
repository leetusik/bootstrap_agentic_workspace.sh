---
doc_id: architecture
version: v0002
created_at: 2026-07-02T13:51:53+09:00
source: P4.REVIEW
summary: installer/ source tree assembles the committed single-file distributable
previous: v0001_bootstrap
---

# Architecture

## Status

The workspace-cornerstone repo is self-hosting: it runs the workflow on itself and
ships its own machinery as a single-file installer. This document describes stable
system-level truth — most notably that the installer is a **build product**
assembled from an `installer/` source tree.

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
- `works/.workspace-version.json`: per-workspace marker — `upstream_url`, integer `workspace_version`, `synced_commit`, `synced_at`
- `scripts/workflow.py`: workflow and docs version manager
- `.claude/`, `.agents/`, `.codex/`: tool entry points (skills, subagents, config)
- `installer/`: source tree for the distributable (see below)
- `bootstrap_agentic_workspace.sh`: the **generated** single-file distributable (build product — never hand-edited)
- `CHANGELOG.md`: repo-only changelog, one `## v<N>` section per workspace version (not emitted to targets)

## Installer Source Tree

The single-file distributable at repo root is not written by hand — it is assembled
deterministically from `installer/`, with the live repo files as the source of truth
for emitted machinery (no more heredoc mirroring inside the artifact).

- `installer/build.py`: deterministic assembler (`--check` = drift guard). It reads
  `wrapper.sh` + `main.py`, embeds a generated payload manifest (`target-path →
  content`) built from the live repo files plus `payloads/`, and writes
  `../bootstrap_agentic_workspace.sh`.
- `installer/wrapper.sh`: the POSIX-sh wrapper that hosts the Python driver in a
  heredoc.
- `installer/main.py`: the Python driver — config/env, the write engine, retrofit +
  update policies, mode guards, docs/P1 seeding, finalizers, and dispatch. Holds the
  `WORKSPACE_VERSION` integer constant and `write_version_marker()`. Emitted skill
  sets are derived at runtime from the payload manifest (a skill is Claude-only when
  it has no `.agents/skills/<name>/` mirror), so adding/removing a skill needs no
  installer code change — just the live files + a rebuild.
- `installer/payloads/`: the only content with no live counterpart — fresh-install
  seeds (`doc_bodies/<doc>.md` ×11, `p1_seed/` phase+intent scaffolds).
- `installer/README.md`: the edit → build → commit loop and the release rule.

The build product is byte-identical across all three install modes (fresh /
`--into-existing` / `--update`); `installer/build.py --check` and
`tests/retrofit_smoke.sh` Test 7 fail on any drift between the committed artifact and
`installer/` source.

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
