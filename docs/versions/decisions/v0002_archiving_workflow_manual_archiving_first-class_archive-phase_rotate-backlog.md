---
doc_id: decisions
version: v0002
created_at: 2026-06-10T13:04:06+09:00
source: P2.S4
summary: Archiving workflow: manual archiving, first-class archive-phase, rotate-backlog
previous: v0001_bootstrap
---

# Decisions

## Status

One decision recorded: the phase archiving workflow (see Decision Log).

## Purpose

Use this doc as a lightweight ADR index: important choices, rejected alternatives, tradeoffs, and decision sources.

## Decision Log

### Phase archiving is manual and explicit, with three first-class operations

- Date: 2026-06-10
- Status: accepted
- Context: A passing phase review marks a phase `done` but should not move it out of `active/`. Operators need control over when phases leave the active set, and the original single-phase archive was framed only as an exceptional "escape hatch", leaving no supported way to archive *some* done phases while others are still in flight.
- Decision:
  - Archiving is **manual and user-requested only**, never automatic. A passing review only marks a phase `done` and leaves it in `active/`.
  - `archive-all` stays the default end-state sweep: archive every active phase at once, allowed only when **every** active phase is done (the last review slice complete).
  - `archive-phase <P>` is promoted from an exceptional escape hatch to a **first-class** single-phase archive (still gated on a passing review; `--force` only for exceptional cleanup of an unfinished phase).
  - A new **`rotate-backlog`** operation archives every phase that is currently done and leaves in-progress phases active, then rebuilds the dashboards — the partial rotation `archive-all` cannot do (it requires all phases done). Shipped as a `workflow.py` command and a skill mirrored into `.claude/skills` and `.agents/skills`.
- Alternatives considered:
  - *Auto-archive a phase when its review passes* — rejected: removes operator control and makes the active set churn mid-work; the operator explicitly wants archiving to be a deliberate step.
  - *Keep single-phase archiving as an escape hatch only* — rejected: with many phases and only some done, partial archiving is a normal need, not an exception.
  - *Add a `--dry-run`/`--force` to `rotate-backlog`* — deferred: by construction it only touches cleanly-archivable phases, so neither is needed yet; revisit if a preview is requested.
- Consequences:
  - Three archive entry points with one shared gate (`_phase_blockers`: all slices done + review `pass`): `archive-all` (full sweep), `rotate-backlog` (partial sweep), `archive-phase` (single). `rotate-backlog` reuses the existing archive helpers; no forked logic.
  - Every rule/skill/tooling change is applied in both the live repo files and their embedded copies inside `bootstrap_agentic_workspace.sh`, and `CLAUDE.md` is kept in sync with `AGENTS.md` (both generated from the same embedded contract).
- Source: P2 (slices P2.S1 engine, P2.S2 skills, P2.S3 contract, P2.S4 this record)

## Superseded Decisions

- None yet.
