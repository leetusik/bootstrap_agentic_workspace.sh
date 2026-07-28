# Intent — P10

- Captured at: 2026-07-25T00:43:31+09:00
- Origin: operator

## Original Input (verbatim)

> Well, Currently our process of do-whole-phase is basically like
> 1. plan for the slice, dispatch
> 2. wait till the executor ends
> 3. after executor ends, plan for the next slice.
>
> right? but why don't we prepare the plan while awaiting, and then after executor done, gives a little adjustment, and then go.
>
> btw, since we store a plan in two place, the later slice plan store can be done with cp.

## Confirmed Intent (refined + clarified)

Two independent efficiency changes to the slice workflow.

**1. Pipelined slice planning (`do-whole-phase` only).** The orchestrator currently idles for the whole executor run — `CLAUDE.md` and the `do-*` skills say it waits for the completion notification "doing nothing else in the meantime" (added in `d1767f9` to forbid inline synchronous execution). The loop is therefore strictly serial: plan N → dispatch N → idle → N returns → research + plan N+1 → gate → dispatch N+1. Research for slice N+1 does not depend on slice N being finished; only the final reconciliation does. Move that research into the idle window: dispatch executor N, immediately prefetch read-only research for N+1, and when N returns do a cheap delta-reconciliation instead of a full research pass before the gate.

**The operator's approval gate does not move.** The operator still approves plan N+1 *after* seeing slice N's outcome (`result.md`, verdict, updated `phase.md`). Only the research shifts off the critical path.

Per-slice loop becomes: gate (or `auto`) → `plan.md` → dispatch executor N → **immediately prefetch N+1** → executor N returns → `finish-slice` / `validate` / commit (unchanged) → `EnterPlanMode` for N+1 and *reconcile, don't re-research* (start from the prefetch brief, then read only what slice N actually changed per `files_changed` and the new `phase.md` notes) → `ExitPlanMode` for approval → persist `plan.md` → dispatch N+1 → prefetch N+2.

Guardrails: the prefetch is read-only — no repo writes, no `workflow.py` state commands, no commits, no second executor dispatch. **Skip it entirely** when the current slice is `DECOMP` (middle slices do not exist yet), when the next slice is `REVIEW` (never pre-planned by contract), when the next slice is already `ready` (`[r]`, an approved `plan.md` exists), when the next slice's expected files sit inside slice N's declared blast radius (torn reads — prefetch only what lies outside it), or when the phase or any slice is `pending`. **Discard the draft** on any verdict other than `done`. **Never block on it** — the executor's completion notification always wins; if the brief has not arrived, drop it and plan normally. The draft lives in the session scratchpad, never in a slice folder (that would collide with the "each slice owns exactly two context files" rule and risk a stale draft being read as an approved plan).

**2. Persist the approved plan by copy, not by re-typing.** `do-next-slice` step 2 requires writing the operator-approved plan "verbatim … not a paraphrase or summary" into the slice's `plan.md`. In Claude Code the harness already holds that exact plan on disk — the plan-mode message names a plan file under `~/.claude/plans/`. Copy it into the slice folder instead of re-emitting it through `Write`: byte-exact, and it removes the only step where a paraphrase can silently creep in. Guard first by confirming the file is *this* slice's plan (not a stale entry from an earlier plan-mode entry in the same session), and copy immediately after approval, before the next `EnterPlanMode`. Fall back to `Write` where no plan file exists — Codex (no plan mode) and `auto` mode (plan mode never entered). Slice-local additions are appended after the copy, never a rewrite of the copied body.

**Non-goals.** No prefetch in `do-next-slice` — it stops after one slice, so a tail prefetch would speculate on work the operator may never run; it gets the `cp` change only. No change to the gate's position, to `plan only`, to `auto`'s safety halts, or to the escalation ladder.

## Clarifications Resolved

- Q: How should this be delivered — a new phase, or direct edits in the planning session? — A: A new phase (`P10`).
- Q: Which parts of the proposal should be in scope? — A: Both — pipelined planning *and* the `cp` plan capture.
- Q: Who does the speculative research during the executor's run — the orchestrator inline, or a delegated read-only subagent? — A: "it depends on slice. if the slice heavy and hard, may orchestrator decide to do both. if its easy, maybe go only subagent research." The orchestrator sizes the next slice (its `slice.json` `kind`/`risk` plus the `DECOMP` breakdown) and decides per slice: subagent research only for an easy/mechanical slice; for a heavy/hard one the orchestrator may research inline *in addition to* the subagent, so it forms its own view rather than trusting a digest for a decision-heavy plan. Either way the subagent is read-only and returns a compact brief — never a plan, never a file dump.

## Notes

- Prior planning artifact for this phase: `~/.claude/plans/well-currently-our-process-ancient-rain.md` (approved by the operator 2026-07-25).
- Open for `DECOMP` to settle: how to define the prefetch subagent. Recommended a new read-only `.claude/agents/slice-planner.md` (`Read, Glob, Grep`; no `Edit`/`Write`/`Agent`) added to `FIXED_LIVE_FILES` in `installer/build.py`, with **no Codex counterpart** since `do-whole-phase` is Claude-Code-only. Whether it also needs `executors.toml` + `sync-agents` tier support is `DECOMP`'s call; the simplest version pins a model in the agent file.
- Trade-offs to carry into the phase: prefetch tokens are sometimes discarded (any non-`done` verdict, or a blast-radius collision); a concurrent prefetch reads a tree the executor is mutating, and the blast-radius skip rule is a mitigation rather than a guarantee; `auto` mode gets the cleanest benefit, while manual mode's saving lands on the operator's side of the gate.
- Machinery-change obligations: mirror every rule change in `CLAUDE.md` **and** `AGENTS.md` (`installer/build.py` asserts the bodies are byte-equal); keep the two `do-next-slice` copies byte-identical apart from frontmatter; rebuild `bootstrap_agentic_workspace.sh` via `python3 installer/build.py` and commit it in the same commit (`.githooks/pre-commit` enforces `--check`).
