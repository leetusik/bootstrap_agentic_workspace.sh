---
doc_id: decisions
version: v0003
created_at: 2026-06-10T14:09:08+09:00
source: P3.S1
summary: Support non-destructive retrofit into existing repos via --into-existing (extend installer, additive merges)
previous: v0002_archiving_workflow_manual_archiving_first-class_archive-phase_rotate-backlog
---

# Decisions

## Status

Two decisions recorded: the phase archiving workflow and non-destructive retrofit into existing repos (see Decision Log).

## Purpose

Use this doc as a lightweight ADR index: important choices, rejected alternatives, tradeoffs, and decision sources.

## Decision Log

### Support non-destructive retrofit into an existing repo via `--into-existing`

- Date: 2026-06-10
- Status: accepted
- Context: The installer only scaffolded into an empty directory — it hard-aborts when any managed file exists and refuses non-empty targets without `--force-empty-ok`, and `write_text` overwrites unconditionally. There was no supported, documented way to adopt the workspace into a repo that already has code, a README, `scripts/`, `docs/`, or git history, and no safe story for collisions with existing files.
- Decision:
  - **Extend the installer** with a flag-gated `--into-existing` retrofit mode rather than shipping a separate script or a skill-only staging dance. The fresh-install (no-flag) path stays byte-for-byte unchanged.
  - Retrofit is **non-destructive** and runs in **two passes**: a PLAN pass classifies every managed path with no writes and aborts up front on an unresolvable collision (so the tool never half-installs), then an APPLY pass writes by tier.
  - **Four-tier collision policy:** (1) *skip-if-exists* for pure content; (2) *install the `docs/` and `works/` subsystems only if wholly absent* (gate on `docs/index.json` / `works/state.json`) and gate the installer's final `rebuild`/`validate` to only-installed subsystems — because `rebuild` itself unconditionally overwrites generated files, so skip-on-write alone is insufficient; (3) *additive, idempotent merge* for `.claude/settings.json` (union permissions) and `CLAUDE.md`/`AGENTS.md` (a marked workspace section plus a `*.workspace.md` sidecar holding the full contract); (4) *hard abort* on a pre-existing `scripts/workflow.py`, since the whole runtime shells out to it.
  - **Seed P1 from project state** using only the existing `--phase-name`/`--phase-objective` flags (no `workflow.py` change); the `/retrofit` skill synthesizes them from the README/manifest/language/latest commit. P1 stays `DECOMP`+`REVIEW`-only.
  - Deliver a `retrofit` **skill** (mirrored in `.claude/skills` and `.agents/skills`, explicit-invocation only) that orchestrates preflight → installer → contract reconciliation → `validate` → report, and a committed, non-installed smoke test (`tests/retrofit_smoke.sh`).
- Alternatives considered:
  - *Skill/guide-only staging without changing the installer* — rejected: more fragile and harder to verify deterministically than a flag the installer owns.
  - *Uniform skip-if-exists for every file* — rejected: unsafe, because the installer's final `rebuild` re-overwrites generated `docs/current/*` and `works/*`; non-destructiveness is a property of write **and** rebuild together.
  - *Strict zero-touch (only ever create new files; sidecars + manual merge for everything)* — rejected in favor of additive idempotent merges for `.claude/settings.json` and the contract, for a usable out-of-box result; merges are additive-only and re-runnable with no duplication.
  - *Add an `edit-phase`/`rename-phase` command to reseed P1* — rejected: unnecessary; the existing seed flags suffice and avoid touching `workflow.py` (and its dual-apply surface).
- Consequences:
  - The installer gains a clearly flag-gated retrofit branch; the fresh path is untouched and still validated by a regression check.
  - Retrofit-only artifacts (`CLAUDE.workspace.md`, `AGENTS.workspace.md`) are deliberately **not** added to `MANAGED_FILES` (or the fresh-install guard would false-trip); the new `retrofit` skill's files **are** added so fresh installs ship it.
  - Dual-apply surface: the new skill (live files + `COMMAND_SKILLS`) and, if touched, the contract (live `CLAUDE.md`/`AGENTS.md` + the embedded `WORKFLOW_DOC`); `workflow.py` is intentionally left unchanged. A committed smoke test asserts the live↔embedded copies stay in sync.
- Source: P3 (slices P3.S1 guide+docs, P3.S2 installer mode, P3.S3 skill, P3.S4 verification)

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
