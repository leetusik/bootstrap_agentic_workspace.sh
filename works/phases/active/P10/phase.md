# Phase P10: Pipelined slice planning and verbatim plan capture

_Intent: see [intent.md](intent.md)._

## Objective

Overlap the next slice's planning research with the running executor in do-whole-phase, and persist operator-approved plans by copying the harness plan file instead of re-emitting it.

## Context

Two **independent** efficiency changes to the slice workflow, both pure *machinery prose* work in the upstream bootstrap repo (contract + skills + one new Claude agent file). Nothing here changes `scripts/workflow.py`, the workflow state model, the gate's position, `plan only`, `auto`'s safety halts, or the escalation ladder.

1. **Pipelined slice planning — `do-whole-phase` only.** Today the orchestrator idles for the whole executor run ("doing nothing else in the meantime", added in `d1767f9` to forbid inline synchronous execution), so the loop is strictly serial: plan N → dispatch N → idle → N returns → research + plan N+1 → gate → dispatch N+1. Research for N+1 does not depend on N finishing; only the final reconciliation does. Move the research into the idle window via a **read-only prefetch subagent**, then reconcile instead of re-researching. **The operator's approval gate does not move** — the operator still approves plan N+1 after seeing slice N's outcome.
2. **Verbatim plan capture by copy.** `do-next-slice` step 2 demands the approved plan be persisted "verbatim … not a paraphrase or summary". In Claude Code the harness already holds that exact plan on disk (`~/.claude/plans/<slug>.md`), so `cp` it instead of re-emitting it through `Write` — byte-exact, and it removes the only step where a paraphrase can creep in. `Write` stays the fallback where no plan file exists (Codex, `auto`).

Because it edits embedded machinery, every slice here carries the rebuild obligation: `python3 installer/build.py` with the rebuilt `bootstrap_agentic_workspace.sh` committed in the same commit (`.githooks/pre-commit` enforces `--check`).

## Decomposition

**Two middle slices**, one per intent item, executed serially. Rationale for the split: the two changes are independent in *substance* (one restructures the `do-whole-phase` loop and adds an agent; the other rewrites a persistence rule shared by both skills) but overlapping in *files* — both touch `CLAUDE.md`, `AGENTS.md`, and `.claude/skills/do-whole-phase/SKILL.md`. Splitting by intent item keeps each slice reviewable against one half of `intent.md`; running them serially (`S2 --depends-on S1`) avoids a rebase on the shared prose and keeps each rebuild artifact atomic.

Considered and rejected: giving `.claude/agents/slice-planner.md` its own slice. The agent file is meaningless without the loop rewrite that dispatches it, and shipping an unused agent in an intermediate commit would double the rebuild/version-bump overhead for no reviewability gain. Also rejected: merging S1 and S2 into one slice — they would then be validated as one blob against two unrelated intent items, and the `cp` change (mid-tier, mechanical-ish prose) would inherit S1's `high` risk unnecessarily.

- **P10.S1 — Pipelined prefetch in `do-whole-phase`** (`implementation`, risk `high`, order 1)
  - **New `.claude/agents/slice-planner.md`** per the design decision recorded below (read-only `Read, Glob, Grep`; model pinned in-file; returns a compact brief, never a plan and never a file dump), plus its **installer wiring — three edits, not one** (see Findings): `FIXED_LIVE_FILES` in `installer/build.py`, an explicit `write_text(...)` in `installer/main.py`, and `MANAGED_FILES` in `installer/main.py`.
  - **Rewrite the `do-whole-phase` per-slice loop** to: dispatch executor N → immediately dispatch the read-only prefetch for N+1 → on N's return, `finish-slice` / `validate` / commit unchanged → `EnterPlanMode` for N+1 and **reconcile, don't re-research** (start from the brief, then read only what N actually changed per `files_changed` plus the new `phase.md` notes) → `ExitPlanMode` → persist `plan.md` → dispatch N+1 → prefetch N+2.
  - **Carry every `intent.md` guardrail verbatim in substance:** prefetch is read-only (no repo writes, no `workflow.py` state commands, no commits, no second executor dispatch); **skip** it when the current slice is `DECOMP`, when the next is `REVIEW`, when the next is already `ready` (`[r]`), when the next slice's expected files sit inside slice N's declared blast radius, or when the phase or any slice is `pending`; **discard** the draft on any verdict other than `done`; **never block on it** — the executor's completion notification always wins, and if the brief has not arrived, drop it and plan normally; the draft lives in the **session scratchpad**, never in a slice folder (a slice owns exactly two context files, and a stale draft must never be readable as an approved plan).
  - **Per-slice sizing rule** from the operator's clarification: subagent-only prefetch for an easy/mechanical next slice; for a heavy/hard one the orchestrator may *also* research inline, so it forms its own view rather than trusting a digest for a decision-heavy plan.
  - **Mirror into `CLAUDE.md` + `AGENTS.md`** (bodies must stay byte-equal) and amend the "doing nothing else in the meantime" wording so the prefetch is a *stated exception scoped to `do-whole-phase`*, not a contradiction — the same sentence also governs `do-next-slice`, which gets **no** prefetch (non-goal), so the carve-out must name the skill.
  - **Rebuild** `bootstrap_agentic_workspace.sh` via `python3 installer/build.py`; the rebuilt artifact is part of the slice's changes.
  - **Risk `high`** because the new wording sits inside the paragraphs that carry the delegation rule, the approval gate, `auto`'s safety halts, and the escalation ladder — none of which may be weakened.

- **P10.S2 — Copy-based verbatim plan capture** (`implementation`, risk `medium`, order 2, `depends_on P10.S1`)
  - **Rewrite the persistence rule** in `do-next-slice` step 2 in **both** copies (`.claude/skills/`, `.agents/skills/`), keeping the bodies byte-identical apart from frontmatter: in Claude Code, copy the approved harness plan file into the slice's `plan.md` (byte-exact) **after confirming it is *this* slice's plan** and not a stale entry from an earlier plan-mode entry in the same session; copy **immediately after approval, before the next `EnterPlanMode`**; slice-local additions are **appended after** the copy, never a rewrite of the copied body. Fall back to `Write` where no plan file exists (Codex — no plan mode; `auto` — plan mode never entered).
  - **Apply the same rule at every other persistence site** (see Findings for the exact list): `do-whole-phase` default loop, its `auto` branch (fallback), its `plan only` branch, and `do-next-slice`'s own `plan only` branch.
  - **Mirror into `CLAUDE.md` + `AGENTS.md`**; rebuild the installer artifact.
  - `depends_on P10.S1` is **ordering only** (advisory in the engine) — both slices edit the same three prose files, so serial execution avoids a rebase.
  - **Risk `medium`**: the change is well-specified and local to one persistence rule, but it is prose surgery under a byte-equality constraint across four files, not a mechanical line swap. (In the default `flex` preset `mid` and `high` are both opus@`xhigh`, so this rating costs nothing in capability.)

`P10.REVIEW` (order 9999) already existed and was not touched. It validates both slices together and, on a pass, consolidates the phase's Doc-impact notes into new doc versions.

## Findings & Notes

### Decision (settled by `DECOMP`): how the prefetch subagent is defined

`intent.md` left this open. Decided as follows — **S1 inherits this; do not re-litigate it**:

- **A new `.claude/agents/slice-planner.md`**, shaped like the existing executor agent files:
  - `name: slice-planner`
  - `description:` states plainly that it does **read-only research for an upcoming slice** and returns a **compact brief — never a plan, never a file dump, never an implementation**.
  - `tools: Read, Glob, Grep` — **no `Edit`, no `Write`, no `Bash`, no `Agent`, no `WebSearch`/`WebFetch`**. The tool allowlist, not prose, is what makes the prefetch structurally read-only: with no `Bash` it cannot run `workflow.py` state commands, cannot commit, and cannot `git` anything; with no `Agent` it cannot dispatch a second executor. Web tools are omitted deliberately — the prefetch researches *this repo*, and network latency would fight the "never block on it" rule.
  - `model: sonnet`, `effort: xhigh` — matches the `flex` preset's `low` tier. A read-and-summarize brief does not need opus, and for a heavy/hard next slice the orchestrator supplements with its own inline research anyway (the operator's sizing clarification).
  - `permissionMode: bypassPermissions` — consistent with the three executor agent files. It grants nothing extra here (the agent has only `Read, Glob, Grep`, all already pre-approved in `.claude/settings.json`), but it prevents a background prefetch from silently hanging on a permission prompt, which would violate "never block on it".
- **Consequence S1 must honour:** with no `Bash`, the planner cannot run `python3 scripts/workflow.py next` and cannot read `git` state. The orchestrator's dispatch prompt must therefore hand it everything it needs by path — the next slice's id and folder, the phase folder (`phase.md`, `intent.md`), and the blast-radius exclusions — and the planner reads `slice.json` files directly from disk.
- **No Codex counterpart.** `do-whole-phase` is Claude Code only (there is no `.agents/skills/do-whole-phase/`), so no `.codex/agents/slice-planner.toml` is created. `installer/main.py` derives its skill inventory from the payload keys (`CLAUDE_SKILLS` / `CODEX_SKILLS`, main.py:57-58) and already handles Claude-only skills, so nothing special is needed there.
- **No `executors.toml` / `sync-agents` tier support in this phase** — the model stays pinned in the agent file. `scripts/workflow.py` enumerates exactly three tiers (`EXECUTOR_TIERS = ("low", "mid", "high")`, line 30; used by `executor_agent_files()` ~line 196 and the advisory drift warning in `validate` ~lines 588-598); adding a fourth is a wider change than this phase needs, and the phase's value does not depend on it.
  - **Known follow-up (candidate for a deferred job, not for this phase):** because `slice-planner.md` is outside `EXECUTOR_TIERS`, (a) operators get no `executors.toml` knob for its model, and (b) `validate` will not warn when `/update-workspace` resets it to the upstream default. Worth filing after the phase; `DECOMP` deliberately did not run `defer-job` (outside a decomposition slice's allowed commands).

### Verified findings (carry into both slices)

- **Shipping a new `.claude/agents/*.md` takes THREE edits, not one.** The `DECOMP` plan mentioned only `FIXED_LIVE_FILES`; reading `installer/main.py` shows that is necessary but **not sufficient**:
  1. `installer/build.py` → `FIXED_LIVE_FILES` (lines 42-55) — embeds the file into `PAYLOADS`. Skills are globbed from disk (`collect_live_payloads`, build.py:79-84); `.claude/agents/` is **not** globbed.
  2. `installer/main.py` → an explicit `write_text(".claude/agents/slice-planner.md", PAYLOADS[".claude/agents/slice-planner.md"])`. The existing agent write is a loop over `("low", "mid", "high")` (main.py:480-482) and will **never** emit a fourth file. Without this, the payload ships but is never written — install and update both silently omit it.
  3. `installer/main.py` → `MANAGED_FILES` (main.py:79, beside the three executor agents) — the fresh-install conflict guard (main.py:365) and the managed-file bookkeeping.
- **`do-whole-phase` has no Codex mirror** (`ls .agents/skills` confirms): the prefetch change lands in the Claude skill and the shared contract only.
- **The two `do-next-slice` copies are byte-identical from `# do-next-slice` onward** — verified with `diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` (empty). They differ only in frontmatter: Claude adds `allowed-tools` + `disable-model-invocation`; Codex has a bare `name`/`description` block and a sibling `agents/openai.yaml`. Keep them so — and note the line numbers are offset by 2 (step 2 is Claude line 19 / Codex line 17; step 3 is Claude line 20 / Codex line 18).
- **Exact sites the `cp` rule (S2) must cover** — every place an approved plan is persisted:
  - `.claude/skills/do-next-slice/SKILL.md:19` (= `.agents/…:17`), step 2: `write the **operator-approved plan verbatim** to this slice's own plan.md — … not a paraphrase or summary` — the primary site.
  - the **`plan only`** branch inside that same step-2 paragraph ("write the approved plan verbatim to the slice's `plan.md`").
  - `.claude/skills/do-whole-phase/SKILL.md:18` (default loop: "write the approved **native plan** to that slice's **own** `plan.md`"), `:19` (`auto` — the `Write` fallback, since plan mode is never entered), `:20` (`plan only`: "write the approved plan verbatim").
  - `CLAUDE.md` / `AGENTS.md:19` ("writes its **native plan** to `plan.md`") and the Hard Rules bullet at line 59.
  - **Gotcha:** `CLAUDE.md:42` and `:57` also say "verbatim", but about the operator's **original request in `intent.md`** — unrelated to plan capture. Do not touch them.
- **Exact sites the "doing nothing else in the meantime" carve-out (S1) must and must not touch:** the sentence appears in `CLAUDE.md`/`AGENTS.md:19`, `.claude/skills/do-whole-phase/SKILL.md:21`, **and** `.claude/skills/do-next-slice/SKILL.md:20` / `.agents/skills/do-next-slice/SKILL.md:18`. Prefetch is a `do-whole-phase`-only behaviour (explicit non-goal for `do-next-slice`), so the `do-next-slice` copies keep the sentence **unchanged** and the contract's shared sentence must scope its exception by name.
- **`do-whole-phase/SKILL.md:21` also says executors run "one at a time: wait for it to return before dispatching the next."** The prefetch is a *concurrent* dispatch, so this sentence needs a carve-out too — the constraint is one *executor* at a time; the read-only planner is not an executor and does not count against it.
- **Version/CHANGELOG precedent:** `WORKSPACE_VERSION = 17` (`installer/main.py:38`); `CHANGELOG.md` has one `## v<N>` section per version, newest first, and recent machinery phases bumped once each (v16 = the auto-explain phase, v17 = the knowledge-default phase). **Recommendation for S1/S2 planning:** treat P10 as **one release** — S1 bumps 17 → 18 and opens a `## v18` CHANGELOG section; S2 appends its bullets to that same section without a second bump. `WORKSPACE_VERSION` marks what an adopting workspace syncs to, and mid-phase commits are not separately released. (Recommendation, not a mandate — the hard rule requires only the rebuild.)
- `.claude/settings.json` already pre-approves `Read`, `Edit`, `Write`, `Glob`, `Grep` and `Bash(python3 scripts/workflow.py:*)`, and denies `git push` / `rm -rf` — the planner agent's three tools need no settings change.
- Slice ordering is clean: `P10.DECOMP` order 0, `P10.S1` order 1, `P10.S2` order 2, `P10.REVIEW` order 9999.

## Constraints

- **Contract bodies must stay byte-equal.** `installer/build.py::collect_contract_body` hard-fails the build when `CLAUDE.md` and `AGENTS.md` differ below their headers. Every rule change goes into **both**, identically.
- **The two `do-next-slice` copies stay byte-identical apart from frontmatter** (`.claude/skills/` vs `.agents/skills/`).
- **Rebuild obligation (both slices).** Any edit to embedded machinery (`scripts/workflow.py`, `.claude/*`, `.agents/*`, `.codex/*`, `works/templates/*`, the contract) requires `python3 installer/build.py` with the rebuilt `bootstrap_agentic_workspace.sh` committed in the same commit; `python3 installer/build.py --check` must pass (enforced by `.githooks/pre-commit`).
- **A new agent file needs all three installer edits** (build.py `FIXED_LIVE_FILES` + main.py `write_text` + main.py `MANAGED_FILES`) or it ships as dead payload. Verify after rebuild that the artifact actually contains the new path.
- **Do not weaken the rules the new wording sits beside**: the delegation rule (every slice is executed by a dispatched executor), the operator approval gate and its position, `auto`'s safety halts (`pending` / `needs_operator` / `blocked` / failed `high` return), the escalation ladder, `plan only` / `ready`, and "each slice owns exactly two context files".
- **Non-goals (from `intent.md`):** no prefetch in `do-next-slice`; no change to the gate's position, to `plan only`, to `auto`'s safety halts, or to the escalation ladder; no `executors.toml` / `sync-agents` fourth tier; no Codex counterpart for the planner agent.
- **Prefetch is read-only and never authoritative**: its brief is input to the orchestrator's own plan, never an approved plan, and it is discarded on any non-`done` verdict or blast-radius collision. Accepted trade-off (recorded in `intent.md`): some prefetch tokens are spent and thrown away, and the prefetch reads a tree the executor is mutating — the blast-radius skip rule is a mitigation, not a guarantee.
- **Durable docs version only at `P10.REVIEW`**: S1 and S2 append Doc-impact notes below; they never run `doc-new-version` and never hand-edit `docs/current/*.md`.

## Doc impact

_Running list of durable-truth changes; `P10.REVIEW` consolidates these into new doc versions. Middle slices append here — no `doc-new-version` before REVIEW._

_(Expected targets, for planning only — the slices record the real notes: `operations.md` (currently v0017) and `decisions.md` (currently v0023) are the two docs that carry the orchestrator/executor loop and its decisions; `grep` shows they are the only `docs/current/*.md` mentioning the orchestrator or `do-whole-phase`.)_

- _(none yet — S1/S2 append here)_

## Open Questions

- ~~How is the prefetch subagent defined (new agent file? tier config? Codex counterpart?)~~ — **resolved by `DECOMP`**: a new read-only `.claude/agents/slice-planner.md` (`Read, Glob, Grep`; `sonnet`@`xhigh` pinned in-file; `bypassPermissions`), wired through all three installer touchpoints, with **no** Codex counterpart and **no** `executors.toml`/`sync-agents` tier support. See *Findings & Notes → Decision*.
- Open for `P10.S1` planning (implementation detail, not a blocker): the exact wording of the blast-radius skip test — how the orchestrator declares slice N's blast radius (from `plan.md`'s scope section) and compares it against the next slice's expected files. `intent.md` fixes the *rule*; the phrasing is S1's call.
