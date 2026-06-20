---
doc_id: decisions
version: v0008
created_at: 2026-06-20T20:58:25+09:00
source: operator-request
summary: do-whole-phase auto-advances into planning; the default pause is approval of the readied plan, not permission to plan
previous: v0007_clarify_do-whole-phase_loop_add_auto_waiver_drop_plan.md_template
---

# Decisions

## Status

Six decisions recorded: the phase archiving workflow, non-destructive retrofit into existing repos, capturing operator intent at intake, routing slice execution through a `slice-executor` subagent, engine-scaffolded phase `intent.md` with a `create-phase` intake skill, and clarifying the `do-whole-phase` loop with an `auto` waiver plus a template-free native `plan.md` (see Decision Log).

## Purpose

Use this doc as a lightweight ADR index: important choices, rejected alternatives, tradeoffs, and decision sources.

## Decision Log

### Clarify the `do-whole-phase` loop, add an `auto` waiver, and drop the `plan.md` template

- Date: 2026-06-20
- Status: accepted
- Context: `do-whole-phase`'s control flow read ambiguously — the per-slice "plan → approve → executor" loop and the approval-gate waiver were compressed into one dense bullet, and the waiver was only an example phrase ("run unattended") rather than a named opt-in. Separately, the orchestrator's plan step forced its plan-mode output into a fixed `plan.md` template (`Goal / Scope / Milestones / Validation`) plus per-slice `## Operator Input (verbatim)` / `## Operator Intent (refined)` headings — re-encoding the agent's native plan into a rigid form and duplicating, at the slice level, the verbatim-intent capture that `intent.md` already owns at the phase level.
- Decision:
  - **Name the default loop, and what it does *not* pause on.** `do-whole-phase` advances on its own: after each slice it automatically heads into planning the next — it never pauses for permission to *start* planning. The one pause is the operator approving the **readied plan** before the executor runs: **plan → operator approves the readied plan → executor**, repeated. (`do-next-slice` does the same for its single slice.)
  - **`auto` is the explicit waiver.** The operator invokes the skill with `auto` (e.g. `/do-whole-phase auto`; "run unattended" still counts) to skip that plan-approval pause and run plan → executor straight through. `auto` waives only the plan approval — the safety halts (`pending`, `needs_operator`, `blocked`, a failed/empty executor return) still STOP the loop. Applies to both skills.
  - **`plan.md` is the native plan, no template.** `create_slice` no longer scaffolds `plan.md` from a template (the `works/templates/plan.md` file is removed); the orchestrator writes its own free-form native plan into `plan.md` at the slice's turn, and the `slice-executor` reads it from disk as before. A fresh slice now has no `plan.md` until its turn — which tightens the existing "`DECOMP` creates bare folders, don't pre-fill `plan.md`" rule.
  - **Drop the slice-level verbatim headings.** The `## Operator Input (verbatim)` / `## Operator Intent (refined)` convention is removed; the native plan incorporates any operator note, and the operator's verbatim intent lives in the phase's `intent.md`. The refine → clarify → confirm step for an ambiguous slice note stays — its result lands in the native plan rather than a templated heading.
- Alternatives considered:
  - *Drop `plan.md` entirely and pass the plan in the executor's dispatch prompt* — rejected: the `slice-executor` runs isolated and reads its inputs from disk; keeping `plan.md` as the on-disk handoff preserves that pattern and the durable plan record.
  - *Keep the `plan.md` template* — rejected: it re-encoded the agent's native plan into a rigid form for no gain; the native plan is the plan.
  - *Make `auto` a persisted mode or engine flag* — rejected: it is a per-run operator choice, like the prior waiver; no engine change is needed.
- Consequences:
  - `workflow.py` `create_slice` scaffolds only `result.md`; `promote_deferred` tolerates an absent `plan.md`. `works/templates/plan.md` is deleted. The `do-next-slice` / `do-whole-phase` skill bodies (`.claude` ↔ `.agents`), `slice-executor.md`, and the contract (`CLAUDE.md` / `AGENTS.md`) are updated; every change is mirrored into the installer (`bootstrap_agentic_workspace.sh`). `validate` is unaffected — it never checked `plan.md`.
  - Amends the 2026-06-18 orchestrator/worker decision below: its "Plan mode by default … operator can waive it per run" sub-decision now names that waiver `auto`, and "writes `plan.md`" now means the free-form native plan rather than a templated fill.
- Source: operator-request (direct implementation; not run through a phase)

### Engine-scaffold phase `intent.md` and add a `create-phase` intake skill

- Date: 2026-06-19
- Status: accepted
- Context: The 2026-06-15 intent decision deliberately kept `intent.md` **convention-driven** — the agent was to write it by hand and `workflow.py` was left unchanged. In practice that left a gap: `new-phase` never created `intent.md` and never linked it from `phase.md`, so only the installer-seeded **P1** ever had one. Every phase created later via `new-phase` (P2+) had no `intent.md` at all — so the read-side wiring already shipped in `slice-executor` / `do-next-slice` / `do-whole-phase` ("consult `intent.md` when unsure") had nothing to read. There was also no single entry point for phase creation — unlike deferred work, which has a `defer-job` skill — so the refine → clarify → confirm intake lived only as prose and was easy to skip.
- Decision:
  - **Engine scaffolds `intent.md`.** `new-phase` now writes `intent.md` from `works/templates/intent.md` (filling `__PHASE_ID__` / `__CAPTURED_AT__` / `__ORIGIN__`), adds the `_Intent: see [intent.md](intent.md)._` link near the top of `phase.md`, and records `intent_md` in `phase.json` `paths` — the same scaffold-then-fill split already used for `plan.md` / `result.md`. The agent fills the content; the engine guarantees the file and link exist.
  - **Add a `/create-phase` skill** (mirrored in `.claude/skills` and `.agents/skills`, explicit-invocation only) as the canonical intake: **refine → clarify → confirm**, then create one or more phases (or route to `defer-job` when the operator wants the work parked), fill each `intent.md`, and **stop** before decomposition.
  - **Soft validation, not a gate.** `validate` emits a non-failing warning when an active phase lacks `intent.md`; it never fails the run, so archived or odd-path phases are not broken.
- Alternatives considered:
  - *Keep it convention-only (status quo)* — rejected: it is exactly what left P2+ with no `intent.md`; making the engine scaffold it (a few lines, mirroring `plan.md`/`result.md`) is the reliable fix.
  - *Make phase creation a subagent instead of a skill* — rejected: intent capture is interactive (clarify by **asking** the operator), and subagents run isolated and cannot pause to ask; the operator-facing intake belongs on the main thread, like the other command-skills.
  - *Build deferred-job handling into the new skill* — rejected: `defer-job` already exists; the intake skill recognizes "park for later" and routes to it rather than duplicating the logic.
  - *Hard validation gate (fail when `intent.md` is missing)* — rejected: too strict; a soft warning surfaces the gap without breaking `validate` on history.
- Consequences:
  - `workflow.py` `new_phase()` scaffolds `intent.md`, links `phase.md`, and adds `paths.intent_md`; `validate()` gains the soft warning. New managed files: `.claude/skills/create-phase/SKILL.md`, `.agents/skills/create-phase/SKILL.md`, `.agents/skills/create-phase/agents/openai.yaml`. The contract (`CLAUDE.md`/`AGENTS.md`) documents the skill and the scaffold; `works/templates/intent.md` switches its header fields to `__KEY__` placeholders. Every change is mirrored into the installer (`bootstrap_agentic_workspace.sh`: embedded `WORKFLOW_PY` `new_phase`/`validate`, the intent template, the skill-write blocks, the managed-files manifest) and `.claude` ↔ `.agents` kept in parity.
  - No executor/read-side change was needed — `slice-executor`, `do-next-slice`, and `do-whole-phase` already consult `intent.md`; the scaffold simply makes it reliably present for them.
  - Supersedes the "convention-driven, not a new flag" sub-decision and the "no `workflow.py` engine change" consequence of the 2026-06-15 intent decision (see *Superseded Decisions*).
- Source: operator-request (direct implementation; not run through a phase)

### Route slice execution through a `slice-executor` subagent (orchestrator/worker split)

- Date: 2026-06-18
- Status: accepted
- Context: `do-next-slice` and `do-whole-phase` previously planned and implemented each slice inline on the main thread, so a slice's full implementation — its file reads, edits, and validation churn — accumulated in the same context that also owns workflow state, commits, and operator dialogue. As phases grow this erodes context hygiene and blurs "decide/verify" from "do". The workspace already passes cross-slice context through a file (`phase.md`), not conversation memory, so a subagent boundary behaves like the session boundary the system already survives — making an orchestrator/worker split low-risk and natural. The payoff is context hygiene plus per-slice checkpoints, not parallelism.
- Decision:
  - **Split the two execution skills into an orchestrator and a worker.** The **orchestrator** (main thread) plans each slice, writes `plan.md`, dispatches the worker, verifies the result, runs `validate`, transitions workflow state, commits, and talks to the operator. The **`slice-executor`** subagent implements exactly one already-planned slice in an isolated context: it reads `plan.md` / `phase.md` / `slice.json` / docs / code, implements, runs validation, writes `result.md`, appends cross-slice notes to `phase.md`, and returns a structured verdict (`status` = `done` | `needs_operator` | `blocked`, plus `summary` / `files_changed` / `validation` / `deviations` / `doc_versions`). One procedure, two entry points: `do-next-slice` runs it once; `do-whole-phase` loops it sequentially.
  - **Verify, don't trust.** The orchestrator re-runs `validate` and the executor's critical checks before `finish-slice` and commit; a failed or empty return means the slice is not done — do not finish, do not commit.
  - **Slice-kind routing.** Only implementation and `fix` slices are delegated. Decomposition stays in the orchestrator (it designs the breakdown and creates workflow state); review stays with the `phase-reviewer` subagent. In Codex (no subagents) the executor's procedure is followed inline via a shared-body host conditional.
  - **Plan mode by default.** The orchestrator does each slice's planning in plan-mode style first (read-only research, clarifying questions, present the plan for operator approval — the existing slice-level refine → clarify → confirm), then exits to write `plan.md` and dispatch. This makes `do-whole-phase` pause at each slice's plan gate by default; the operator can waive it per run.
  - **Full-permission executor.** `slice-executor.md` uses the `opus` model, `effort: max`, and `permissionMode: bypassPermissions` (autonomous, no prompts). The guardrails are the orchestrator's verify-before-commit gate plus the executor's hard Never-list (no commit/push, no workflow state-transition commands, no starting/decomposing another slice).
- Alternatives considered:
  - *Keep implementing inline on the main thread* — rejected: loses the context-hygiene and per-slice-checkpoint payoff; the file-based cross-slice channel makes the subagent boundary cheap, so there is little reason not to take it.
  - *Parallel fan-out across slices (worktree isolation)* — rejected for now: slices build on each other through `phase.md` and the shared tree with a commit at each boundary, so execution is sequential; parallelism is out of scope unless a decomposition explicitly marks slices independent.
  - *Gate the plan-mode approval only on `do-next-slice` and let `do-whole-phase` run unattended* — rejected as the default: the point of the gate is to ask per slice, so both gate by default, with a per-run waiver.
  - *Keep all durable-doc writes in the orchestrator* — rejected: the executor owns `doc-new-version` for its slice (append-only, never patches old versions, coupled to the code change) and reports the versions; the orchestrator confirms via `validate`, avoiding a round-trip.
  - *Pin the executor to a fixed model id; name the dispatch tool `Task`* — corrected during implementation: the executor uses the forward-compatible `opus` model alias, and the skills allow the dispatch tool by its real name **`Agent`** — a skill cannot spawn a subagent unless `Agent` is in its `allowed-tools` (this also formalizes the previously-implicit `phase-reviewer` dispatch).
- Consequences:
  - New managed file `.claude/agents/slice-executor.md` (added to `MANAGED_FILES`); the `do-next-slice` and `do-whole-phase` skill bodies are rewritten and gain `Agent` in `allowed-tools`. The contract (`CLAUDE.md` / `AGENTS.md`) documents the orchestrator/executor model in *Driving This Workspace* and a Hard Rule. Every change was applied in the installer first, then mirrored to the materialized snapshot (`.claude` ↔ `.agents`), with byte-parity verified by re-generating from the installer; `tests/retrofit_smoke.sh` passes and no real slice was executed.
  - Codex has no subagents, so it gets no `slice-executor.md` file and executes the same procedure inline through the shared skill body's host conditional.
  - No `workflow.py` engine change: delegation is a skill/contract convention, not a machine-enforced invariant. The structured verdict is a reporting convention the orchestrator acts on (`needs_operator` → set the slice `pending` and stop; `blocked` → record and stop).
- Source: operator-request (direct implementation; not run through a phase)

### Capture operator intent at intake — refine, clarify, confirm, persist to `intent.md`

- Date: 2026-06-15
- Status: accepted
- Context: Operator requests enter the workspace as free natural language that can carry grammar slips, awkward phrasing, or genuine ambiguity. The previous flow distilled that raw text straight into a phase `--objective` (or a slice's `## Operator Input (verbatim)` note) with no refinement, no clarification, and no confirmation — so a misread of intent propagated silently into decomposition and every downstream slice, and there was no durable, authoritative record of what the operator actually asked in their own words.
- Decision:
  - **Add an intake step** at the first point intent enters a unit of work: the agent **refines** the request into clear language, **clarifies** ambiguity by asking the operator, and **confirms** the interpretation before acting. The agent does not run `new-phase` until the operator confirms.
  - **Persist both** the operator's **verbatim original** (immutable) and the **confirmed refined intent** (plus resolved clarifications) to a dedicated **`intent.md`** in the phase folder, **linked near the top of `phase.md`**. Later agents consult it whenever they are unsure of intent — it is the confirmed source of truth.
  - **Convention-driven, not a new flag.** The agent writes `intent.md` and the `phase.md` link by convention (mirroring the existing `## Operator Input (verbatim)` mechanism); `workflow.py` / `new-phase` are left unchanged. Intent applies at the **phase level always** and the **slice level when needed** — an ambiguous slice note is paired with a `## Operator Intent (refined)` section in that slice's `plan.md`.
- Alternatives considered:
  - *Store intent as a `## Intent` section inside `phase.md`* — rejected: mixes the immutable verbatim original with the evolving notebook; a separate `intent.md` keeps the original word-for-word and is the literal "store it somewhere and link from `phase.md`".
  - *Make it first-class via a `new-phase --original-input` flag (write `intent.md` + a `phase.json` field)* — rejected for now: heavier and doubles the `workflow.py` dual-apply surface; the convention path matches how operator input is already captured and keeps the engine unchanged.
  - *Phase level only* — rejected: slice-level operator notes can be just as ambiguous, so refinement is allowed there too (recorded in `plan.md`), but only when it adds value.
- Consequences:
  - The behavior lives in the **contract** (`CLAUDE.md`/`AGENTS.md`) and the `do-next-slice` / `do-whole-phase` / `retrofit` **skills**, plus a new `works/templates/intent.md`. Every change is applied in both the live files and their embedded copies inside `bootstrap_agentic_workspace.sh`, and across `.claude/skills` ↔ `.agents/skills`.
  - The installer seeds P1 with a placeholder `intent.md` (Origin `bootstrap-placeholder`, or `synthesized-from-repo` on retrofit) so every phase has the file and link uniformly; the `/retrofit` skill enriches it from project state.
  - No `workflow.py` engine change, so no new validation gate — `intent.md` presence is a contract expectation, not a machine-enforced invariant.
- Source: operator-request (direct implementation; not run through a phase)

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

- The 2026-06-15 *Capture operator intent at intake* decision's "convention-driven, not a new flag" sub-decision and its "no `workflow.py` engine change" consequence are **superseded** by the 2026-06-19 *Engine-scaffold phase `intent.md`* decision above: `new-phase` now scaffolds `intent.md` and links it from `phase.md`, with a soft `validate` warning. The intake flow itself (refine → clarify → confirm; verbatim original + confirmed refined intent; linked from `phase.md`) is unchanged — only its enforcement moved from pure convention to an engine-backed scaffold filled by the `/create-phase` skill.
