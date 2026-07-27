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
  - **Risk `medium`**: the change is well-specified and local to one persistence rule, but it is prose surgery under a byte-equality constraint across four files, not a mechanical line swap. (_Rationale aside corrected by `P10.S1`: the original text claimed `mid` and `high` were both opus@`xhigh` in the default preset, so the rating "cost nothing". Commit `b26d622` re-cut the presets — `economy` is now the default at sonnet@`medium` / sonnet@`high` / opus@`high`, so `mid` is genuinely a step below `high`. The `medium` rating still stands on its merits; it is simply not free any more._)

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

- **`operations.md`** — the `do-whole-phase` loop is no longer strictly serial: as of workspace **v19** the orchestrator dispatches a read-only `slice-planner` prefetch for slice N+1 right after dispatching executor N, then plans N+1 by reconciling that brief instead of re-researching. Document the new agent (`Read, Glob, Grep` only, sonnet pinned in-file, outside `executors.toml`/`sync-agents`), the five skip conditions + blast radius, never-block / discard-on-non-`done` / scratchpad-only, the per-slice sizing rule, and that this is `do-whole-phase`-only (not `do-next-slice`, not `plan only`) with the operator's approval gate unmoved. (Source: `P10.S1`.)
- **`decisions.md`** — new decision (P10, v19): *pipeline the next slice's research into the executor's idle window via a read-only prefetch subagent*. Record the alternatives weighed (orchestrator-inline research only vs. a delegated read-only agent; a fourth `executors.toml` tier vs. a model pinned in-file), why the tool allowlist — not prose — is the enforcement mechanism, the accepted trade-offs (discarded prefetch tokens; the prefetch reads a tree the executor is mutating, with blast-radius skipping as a mitigation rather than a guarantee), and the guardrails that keep the delegation rule, the approval gate, `auto`'s safety halts, and the escalation ladder untouched. (Source: `P10.S1`.)
- **`operations.md`** — as of workspace **v19**, the orchestrator no longer retypes an approved plan through `Write`: in Claude Code it `cp`s the harness plan file the harness named for that planning session into the slice's `plan.md`, after confirming its opening lines match the just-approved plan (guards against the harness's one-plan-file-per-session reuse), and does so immediately, before the next `EnterPlanMode` overwrites it. Slice-local additions (an `## Escalation` section, for example) are appended after the copy, never a rewrite. `Write` remains the fallback wherever no plan file exists (Codex — no plan mode; `auto` — plan mode never entered). Covers every persistence site: `do-next-slice`'s default and `plan only` branches (both copies), and `do-whole-phase`'s default loop and `plan only` branch. Document the confirm-before-copy guard as load-bearing, not decorative. (Source: `P10.S2`.)
- **`decisions.md`** — new decision (P10, v19): *persist the operator-approved plan by copying the harness's own plan file instead of re-emitting it through `Write`*. Record the alternative considered and rejected (keep `Write`, i.e. status quo — rejected because retyping a document the harness already holds is the one step where a paraphrase or silent truncation can creep in), the load-bearing guard this decision depends on (confirm the plan file's opening lines match the just-approved plan before copying, because the harness reuses one plan file per session and a skipped step can leave a stale entry), why `Write` stays as the explicit fallback (Codex has no plan mode; `auto` never enters it, so no harness file exists to copy in either case), and the new `.claude/settings.json` `Bash(cp:*)` allowlist entry this decision required (grants nothing beyond the already-allowed `Write` tool; added purely to avoid a permission prompt right after the approval gate). (Source: `P10.S2`.)

### Cross-slice notes from `P10.S1` (pipelined prefetch — shipped)

- **The version bump landed on 19, not 18 — `P10.S2` must NOT bump again, only append to `## v19`.** The DECOMP finding recorded `WORKSPACE_VERSION = 17`, but commit `b26d622` (executor-tier preset re-cut, landed after DECOMP) already shipped **v18** with its own committed CHANGELOG section and Migration notes. Folding P10 into a released section would have retro-fitted it, so S1 opened `## v19 — 2026-07-28`. The "P10 = one release" recommendation is intact, just at 19.
- **The three-edit installer rule is confirmed by experiment, and there is a fourth thing worth knowing:** `--update` needs no change at all. `installer/main.py::_is_machinery()` matches the `.claude/agents/` prefix, so a new agent file is classed machinery and shows up as `added: 1 file(s)` on `--update` for adopting workspaces. Verified by deleting the file from a fresh probe install and re-running `--update --dry-run` and `--update`.
- **`sync-agents` ignores `slice-planner` cleanly.** `scripts/workflow.py` enumerates `EXECUTOR_TIERS = ("low", "mid", "high")` only, so `sync-agents --check` stays green (exit 0) and the new agent is neither synced nor drift-warned — exactly the known follow-up already recorded above (no `executors.toml` knob; `/update-workspace` silently resets it). Still a candidate deferred job after the phase.
- **`effort: xhigh` on `slice-planner` is the plan's fixed value, kept as-is — but its DECOMP rationale is now stale.** "Matches the `flex` preset's low tier" was true before `b26d622`; `flex`'s low tier is now sonnet@`high` and `economy`'s is sonnet@`medium`. The value is pinned in-file and deliberately independent of the presets, so this is a stale rationale, not a defect. If `REVIEW` (or the operator) wants a cheaper/faster prefetch, `effort` is a one-line change in `.claude/agents/slice-planner.md` + rebuild.
- **Where the prose landed, so `P10.S2` can edit around it without a conflict:** `.claude/skills/do-whole-phase/SKILL.md` gained 8 lines — one new bullet plus 7 sub-bullets — inserted *after* the "Delegated slices" dispatch bullet and *before* the decomposition bullet. The `plan only` bullet (S2's third persistence site) and the `auto` bullet are textually unchanged, as are both `do-next-slice` copies (`git diff --stat` over them is empty). The contract gained one Hard Rules bullet placed between the "Every slice … is executed by a dispatched `slice-executor` tier" bullet and the "Slice selection is by `order`" bullet.
- **Two additive strengthenings inside the carve-out sentences** (recorded so `REVIEW` reads them as deliberate, not drift): the dispatch bullet now also forbids repo writes and workflow-state moves while an executor runs, and the sizing sub-bullet states that the orchestrator's *optional inline* research is read-only too. Without them, "doing nothing else … except the prefetch" could be misread as licence for arbitrary concurrent work.
- **The exact `slice-planner` dispatch-prompt shape** the orchestrator should use is written out in `slices/P10.S1/result.md` (§ *Dispatch-prompt shape*). It matters because the agent has no `Bash`: everything — slice id/folder, phase folder, the specific questions, and the blast-radius exclusions — must be handed over as paths. Note that `phase.md` itself is always partly inside the running slice's blast radius (every executor appends to its tail), so it is readable-but-stale by construction.
- **READMEs deliberately untouched (flagged for `REVIEW`, not fixed here).** `README.en.md:170-175` enumerates what a bootstrapped workspace ships ("plus the three risk-routed `slice-executor` tier subagents…") and now under-counts the `.claude/agents/` inventory; `README.md`'s Korean tier table (lines 153-155) is separately stale since `b26d622` (it still says `slice-executor-mid` = Opus). Neither file is embedded machinery or in this slice's plan scope, and editing only the English one would have left the pair inconsistent. Best handled as one small follow-up covering both READMEs — the review's call.
- **Validation reality check:** the end-to-end install probe is the check that catches dead payload — greps alone would have passed even with the `write_text` call missing. The probe (into the session scratchpad) installed cleanly, wrote `.claude/agents/slice-planner.md` byte-identical to source, stamped `workspace_version: 19`, and showed `slice-planner` 3× in the probe's `do-whole-phase/SKILL.md`, 2× in each contract, and **0×** in `do-next-slice/SKILL.md`.

### Cross-slice notes from `P10.S2` (copy-based verbatim plan capture — shipped)

- **All four rule sites landed, plus the settings allowlist and the CHANGELOG append.** Both
  `do-next-slice` copies (default + `plan only` branches, same paragraph), all three
  `do-whole-phase` persistence sites (default loop, `auto`'s explicit `Write`-stays clause, `plan
  only`), and both contract clauses (`CLAUDE.md`/`AGENTS.md` — the *Driving This Workspace*
  sentence and the "each slice owns exactly two context files" Hard Rules bullet) now describe
  copy-not-retype. `CLAUDE.md:42`/`:57` (the operator-intent "verbatim" references) were
  deliberately left alone, as `DECOMP`'s finding flagged.
- **`.claude/settings.json` needed no installer wiring beyond the rebuild** — it was already in
  `FIXED_LIVE_FILES`, had an explicit `write_text` call, and `installer/main.py::_merge_settings_json`
  already unions permission entries into an existing file on `--update`, so the new `Bash(cp:*)`
  entry propagates to adopting workspaces automatically. Confirmed via the install probe (probe's
  `.claude/settings.json` contains the entry) rather than by running an update probe (S1 already
  established the update path works for `.claude/*` payload changes; this slice's change is
  additive to an existing merged file, a lower-risk path than S1's brand-new file).
- **`WORKSPACE_VERSION` stayed at 19** — appended three bullets and extended the Migration notes
  paragraph in the `## v19` section S1 opened; no new section, no bump. The Migration notes now
  correct S1's claim that `do-next-slice` is "untouched" (true only for the prefetch change; this
  slice is the one that touches it) and add the `.claude/settings.json` merge note.
- **One judgment call left for `REVIEW` to weigh:** the `do-whole-phase` `plan only` bullet says
  "the same confirm-then-copy rule as the default loop above" rather than re-spelling the full
  multi-clause rule a third time in one file (the default-loop bullet directly above it, and
  `do-next-slice`'s own `plan only` branch in a different file, both spell it out in full). This
  keeps the bullet from padding out the already-large prefetch block just below it, but trades off
  a same-file forward reference instead of full self-containment. See `result.md` deviations.
- **Read-through confirmed nothing adjacent weakened:** the approval gate's position, `auto`'s
  safety halts, the escalation ladder, `plan only` / `ready` semantics, and S1's `slice-planner`
  prefetch bullet are all textually intact — this slice's edits are additive/substitutive within
  the persistence clauses only.

## Open Questions

- ~~How is the prefetch subagent defined (new agent file? tier config? Codex counterpart?)~~ — **resolved by `DECOMP`**: a new read-only `.claude/agents/slice-planner.md` (`Read, Glob, Grep`; `sonnet`@`xhigh` pinned in-file; `bypassPermissions`), wired through all three installer touchpoints, with **no** Codex counterpart and **no** `executors.toml`/`sync-agents` tier support. See *Findings & Notes → Decision*.
- Open for `P10.S1` planning (implementation detail, not a blocker): the exact wording of the blast-radius skip test — how the orchestrator declares slice N's blast radius (from `plan.md`'s scope section) and compares it against the next slice's expected files. `intent.md` fixes the *rule*; the phrasing is S1's call.
