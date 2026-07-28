# P10.DECOMP — decompose "Pipelined slice planning and verbatim plan capture"

## Context

Phase `P10` is created but not decomposed: only `P10.DECOMP` and `P10.REVIEW` exist. The
operator's confirmed intent (`works/phases/active/P10/intent.md`) asks for two independent
efficiency changes to the slice workflow:

1. **Pipelined slice planning** — in `do-whole-phase` only, move the *research* for slice N+1
   into the idle window while executor N runs (read-only prefetch, discarded on any non-`done`
   verdict), then reconcile instead of re-researching before the operator's gate. The gate itself
   does not move.
2. **Verbatim plan capture by copy** — after the operator approves a plan in Claude Code, copy
   the harness plan file (`~/.claude/plans/<slug>.md`) into the slice's `plan.md` instead of
   re-emitting it through `Write`. Fall back to `Write` where no plan file exists (Codex, `auto`).

This is machinery work in the upstream bootstrap repo: it edits the contract and the skills, so it
carries the rebuild obligation (`python3 installer/build.py`, committed in the same commit;
`.githooks/pre-commit` enforces `--check`).

This slice does **only** the decomposition: create the phase's middle slices as bare folders and
record the breakdown, findings, and the one open design decision in `phase.md`. No implementation,
no pre-filled `plan.md` for any slice, no doc versions.

## What the executor must do

Dispatch: `slice-executor-high` (decomposition always).

### 1. Read before deciding

- `works/phases/active/P10/intent.md` — the confirmed intent, guardrails, non-goals, and the
  "Machinery-change obligations" note. It is the source of truth for scope.
- `CLAUDE.md` (identical body in `AGENTS.md`) — the *Driving This Workspace* paragraph and the
  Hard Rules bullets that describe the orchestrator/executor split, the "doing nothing else in the
  meantime" rule, `plan.md` ownership, and `ready` / `plan only`.
- `.claude/skills/do-whole-phase/SKILL.md` — the loop that gains the prefetch step (Claude Code
  only; there is no `.agents/skills/do-whole-phase`).
- `.claude/skills/do-next-slice/SKILL.md` and `.agents/skills/do-next-slice/SKILL.md` — step 2
  holds the "verbatim … not a paraphrase" rule that the `cp` change rewrites. **Verified: the two
  bodies are byte-identical apart from frontmatter** (Claude adds `allowed-tools` +
  `disable-model-invocation`; Codex has a bare `name`/`description` block plus
  `agents/openai.yaml`). Keep them so.
- `.claude/agents/slice-executor-high.md` — the reference shape for a Claude agent file
  (frontmatter: `name`, `description`, `tools`, `model`, `effort`, `permissionMode`).
- `installer/build.py` — `FIXED_LIVE_FILES` (lines 42–55) lists the non-skill files shipped
  verbatim; skills and `.claude/agents/*` are otherwise picked up only via that list
  (`collect_live_payloads` globs skills from disk, but **not** `.claude/agents/`). A new agent file
  must be added to `FIXED_LIVE_FILES` or it will not ship. `collect_contract_body` hard-fails when
  the `CLAUDE.md` / `AGENTS.md` bodies differ.

### 2. Settle the one open design decision, and record it

`intent.md` leaves this for `DECOMP`: **how the prefetch subagent is defined.** Decide it now and
write the decision plus its rationale into `phase.md` under *Findings & Notes*, so the
implementation slice inherits it rather than re-litigating it.

Recommended (the orchestrator's steer — override only with a recorded reason):

- A new read-only `.claude/agents/slice-planner.md`: `tools: Read, Glob, Grep` (no `Edit`, no
  `Write`, no `Bash`, no `Agent`), model pinned in the agent file, description making clear it
  returns a **compact brief, never a plan and never a file dump**.
- Register it in `installer/build.py` `FIXED_LIVE_FILES`.
- **No Codex counterpart** — `do-whole-phase` is Claude Code only.
- **No `executors.toml` / `sync-agents` tier support** in this phase (the sync code enumerates the
  three `slice-executor-{low,mid,high}` tiers at `scripts/workflow.py:201-202` and `validate`
  warns on drift for exactly those files; adding a fourth tier is a bigger change than the phase
  needs). If the executor disagrees, it may instead record a deferred job — it must not silently
  widen scope.

### 3. Create the middle slices

Recommended breakdown — **two** implementation slices, in this order. The executor may adjust
(e.g. split the agent file into its own slice) if it records why in `phase.md`, but it must keep
the two intent items in separate slices: they are independent, and the operator asked for both.

- **`P10.S1` — Pipelined prefetch in `do-whole-phase`** (`--kind implementation`, `--risk high`,
  `--order 1`)
  - New `.claude/agents/slice-planner.md` (per the decision above) + `FIXED_LIVE_FILES`
    registration.
  - Rewrite the `do-whole-phase` per-slice loop to: dispatch executor N → immediately dispatch the
    read-only prefetch for N+1 → on N's return, `finish-slice` / `validate` / commit unchanged →
    `EnterPlanMode` for N+1 and **reconcile, don't re-research** (start from the brief, then read
    only what N actually changed per `files_changed` and the new `phase.md` notes) → `ExitPlanMode`
    → persist `plan.md` → dispatch N+1 → prefetch N+2.
  - Carry every guardrail from `intent.md` verbatim in substance: prefetch is read-only (no repo
    writes, no `workflow.py` state commands, no commits, no second executor dispatch); **skip**
    when the current slice is `DECOMP`, when the next is `REVIEW`, when the next is already
    `ready`, when the next slice's files sit inside slice N's blast radius, or when anything is
    `pending`; **discard** on any non-`done` verdict; **never block on it** — the executor's
    completion notification always wins; the draft lives in the session scratchpad, never in a
    slice folder.
  - Per-slice sizing rule from the operator's clarification: subagent-only prefetch for an
    easy/mechanical next slice; for a heavy/hard one the orchestrator may *also* research inline.
  - Mirror the rule change into `CLAUDE.md` **and** `AGENTS.md` (bodies must stay byte-equal), and
    amend the "doing nothing else in the meantime" wording so the prefetch is a stated exception
    rather than a contradiction. Non-goal: no prefetch in `do-next-slice`.
  - Rebuild: `python3 installer/build.py`; the rebuilt `bootstrap_agentic_workspace.sh` is part of
    the slice's changes.
  - `risk: high` because the wording must not weaken the delegation, gate, `auto`-safety-halt, or
    escalation rules it sits next to.

- **`P10.S2` — Copy-based verbatim plan capture** (`--kind implementation`, `--risk medium`,
  `--order 2`, `--depends-on P10.S1`)
  - Rewrite `do-next-slice` step 2's persistence rule in **both** copies
    (`.claude/skills/`, `.agents/skills/`), keeping the bodies byte-identical apart from
    frontmatter: in Claude Code, copy the approved harness plan file into the slice's `plan.md`
    (byte-exact) after confirming it is *this* slice's plan and not a stale entry from an earlier
    plan-mode entry in the same session; copy immediately after approval, before the next
    `EnterPlanMode`; slice-local additions are appended after the copy, never a rewrite of the
    copied body. Fall back to `Write` where no plan file exists (Codex, `auto`).
  - Apply the same rule in `.claude/skills/do-whole-phase/SKILL.md` (it persists a plan per slice)
    and in the `plan only` path, which also writes an approved plan.
  - Mirror into `CLAUDE.md` + `AGENTS.md`; rebuild the installer.
  - `--depends-on P10.S1` only to fix the order — both edit the same three prose files, so serial
    execution avoids a rebase.

`P10.REVIEW` already exists; do not create it, and do not touch its `order`.

### 4. Seed `phase.md`

Fill *Context*, *Decomposition*, *Findings & Notes*, and *Constraints* with:

- The slice breakdown above (what each slice covers and why) — enough that each slice's own
  planning starts from shared context.
- The prefetch-subagent decision from step 2, with rationale.
- The machinery constraints that both slices inherit: `CLAUDE.md` / `AGENTS.md` bodies must stay
  byte-equal (`installer/build.py` fails otherwise); the two `do-next-slice` copies stay
  byte-identical apart from frontmatter; every machinery edit requires
  `python3 installer/build.py` with the rebuilt artifact committed in the same commit, and
  `--check` must pass.
- Findings worth carrying: `.claude/agents/*` ships only via `FIXED_LIVE_FILES` (skills are
  globbed, agents are not); `do-whole-phase` has no Codex counterpart; `sync-agents` and
  `validate` know only the three executor tiers.
- Anything in *Open Questions* that this slice resolved should be struck or answered there.

Do **not** pre-fill `P10.S1/plan.md` or `P10.S2/plan.md` — each slice's plan is written by the
orchestrator at that slice's turn.

### 5. Write `result.md`, and stop

Free-form: which slices were created with what `kind`/`risk`/`order`, the design decision taken,
and anything the next planner should know. No commits, no status transitions beyond the `new-slice`
calls this slice is allowed to make. Append durable cross-slice notes to `phase.md` (step 4 covers
this).

## Validation for this slice

- `python3 scripts/workflow.py validate` — clean.
- `python3 scripts/workflow.py next` — shows `P10.S1` as the next slice.
- `python3 installer/build.py --check` — still passes (this slice changes no shipped machinery, so
  it must be a no-op; if it fails, that is a pre-existing problem to report, not to fix here).
- `works/backlog.md` lists `P10.DECOMP`, `P10.S1`, `P10.S2`, `P10.REVIEW` in order.

## Explicit non-goals for this slice

- No edits to `CLAUDE.md`, `AGENTS.md`, any `SKILL.md`, `installer/build.py`, or
  `bootstrap_agentic_workspace.sh`.
- No new agent file yet — `P10.S1` creates it.
- No `doc-new-version` (durable docs are consolidated at `P10.REVIEW`); durable-truth changes are
  recorded as one-line "Doc impact" notes in `phase.md` by the slices that make them.
- No commits (the orchestrator commits).
