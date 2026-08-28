# P12.S6 — Skills + contract for parallel mode (result)

Docs-and-machinery slice: the engine built in S1–S5 is now described to the agents end to end. No
`scripts/workflow.py` change (per the plan's boundary); one installer rebuild covers everything.

## What landed

### 1. New skill `parallel-phase` (the lifecycle reference)

- `.claude/skills/parallel-phase/SKILL.md` — frontmatter per convention (`name`, `description`,
  `allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash`,
  `disable-model-invocation: true` — explicit invocation only, like every other command skill;
  `design-cowork` stays the only model-invocable one).
- `.agents/skills/parallel-phase/SKILL.md` — generated from the Claude file by dropping exactly the
  two Claude-only frontmatter keys (verified by `diff`).
- `.agents/skills/parallel-phase/agents/openai.yaml` — description mirrored verbatim,
  `allow_implicit_invocation: false`.

Body sections, quoting every engine command in full `python3 scripts/workflow.py ...` form:
**1. When** (the two advisory hints, suggestion never a default) · **2. Opt in** (`parallel-start <P>`
with its guard list, the one fixed-message engine commit and why the stamp must exist on both
branches, the worktree vs. a teammate's plain clone) · **3. Work** (stream-scoped selection,
`pending` halting only its own stream, dashboards still listing everything, `parallel-status`,
generated files regenerated-not-merged) · **4. Review on the branch** (the single difference: a
passing review verifies the "Doc impact" list and defers consolidation; the `docs/current` check
moves to consolidation time on main) · **5. Integrate** (the 10-step agent-run sequence:
`parallel-gate` → push → `gh pr create` → `gh pr checks --watch` → `gh pr merge --merge` → pull +
`parallel-merge-finish` → serialized `doc-new-version`/`rebuild-docs` on the default stream →
`parallel-consolidated <P>` → `parallel-teardown <P>` → commit) · **Guardrails**.

Skills auto-register in the installer (`build.py` discovers skill payloads from disk, `main.py`
derives `CLAUDE_SKILLS`/`CODEX_SKILLS` from the manifest), so the folders plus a rebuild were all it
took — confirmed by a fresh install from the rebuilt artifact (below).

### 2. Contract — `CLAUDE.md` + `AGENTS.md` (strict mirror)

`AGENTS.md` is regenerated from `CLAUDE.md` with only the two header lines swapped, so the pair stays
byte-identical elsewhere. Changes:

- **Commit convention** — the carve-out: opting a phase into parallel mode **is** the operator's ask
  (engine stamp commit, phase branch, slice commits on the branch, pushing to open/merge the PR; each
  push still passes the permission prompt; adopters must delete any old blanket `Bash(git push:*)`
  deny). Outside that flow the previous sentences stand verbatim.
- **Hard Rules** — durable-doc bullet and the delegation bullet's consolidation half gained the
  parallel deferral; the review/archive bullet gained the `execution.consolidation: "pending"` archive
  block; **one new compact bullet** covers parallel mode itself (opt-in per phase, phase = unit of
  parallelism, branch + worktree or a plain clone, stream-scoped selection/`pending`, regenerate-not-
  merge, the quiet-point gate, advisory hints) and points at the skill for the lifecycle.
- **Driving This Workspace** — `/parallel-phase` in the Claude list, `(parallel-phase included)` on the
  Codex line; the "only on a passing verdict" consolidation sentence gained the parallel condition.
- **Read Order / Canonical State** — the `works/state.json` pointer is documented as stream-scoped
  (with the `"stream"` key) and cross-stream truth comes from `parallel-status`; the generated
  dashboards are marked regenerate-not-merge.
- **Workflow Commands** — the six `parallel-*` commands, one line each in the list's existing style;
  the `doc-new-version` line notes the parallel-mode timing.

### 3. Existing skills and executor agents

- `create-phase` (both twins) — new sub-step 4 under "Make a phase": relay `new-phase`'s parallel
  hint, note that **now is the only moment to opt in** (`parallel-start` requires status `planned`),
  run it if the operator agrees, point at `parallel-phase`. No frontmatter change needed — its
  `allowed-tools` already permit `python3 scripts/workflow.py ...`.
- `do-next-slice` (both twins) / `do-whole-phase` (Claude only) — pointer wording is stream-scoped;
  the engine's `parallel-start` hint is relayed; the review-slice consolidation sentences carry the
  parallel deferral; the `never push` lines carry the integration-flow carve-out; a parallel `pass`
  now names the integration sequence.
- `review-phase` (both twins) — a new paragraph stating that parallel mode changes exactly one thing
  (the consolidation); the two check bullets and the `pass` branch carry the condition (verify the
  "Doc impact" list, report `doc_versions: none — deferred to post-merge consolidation (parallel
  mode)`, `docs/current` parity checked at consolidation time on main); the closing paragraph notes a
  parallel `pass` opens the integration.
- `archive-phase` (both twins) — both gate sentences name the consolidation gate.
- All four executor agent files (`.claude/agents/slice-executor-{mid,high}.md`,
  `.codex/agents/slice-executor-{mid,high}.toml`) — step 5's review bullet gained the parallel
  exception, step 1's review bullet (high tier) and the "review consolidates the docs" sentences
  gained the qualifier. **Model/effort lines untouched** — `sync-agents --check` reports in sync, and
  the Claude/Codex bodies remain byte-identical per tier.

### 4. Versioning

`WORKSPACE_VERSION` stays **24**; the v24 CHANGELOG entry gained two bullets (the new skill; the
contract + skill + agent carve-outs). No bump to 25 — S5's v24 is the same unreleased change set.

## Validation

| Command | Outcome |
|---|---|
| `python3 installer/build.py` | pass — rebuilt `bootstrap_agentic_workspace.sh` (381996 → current) |
| `python3 installer/build.py --check` | pass — artifact in sync with `installer/` source |
| `grep -c "parallel-phase" bootstrap_agentic_workspace.sh` | 14 hits; all three new payload keys present (`.claude/skills/parallel-phase/SKILL.md`, `.agents/.../SKILL.md`, `.agents/.../agents/openai.yaml`) |
| fresh install from the artifact into a temp dir | pass — both skill folders + `openai.yaml` land; installed `SKILL.md` byte-identical to the live file |
| `bash tests/retrofit_smoke.sh` | pass — ALL RETROFIT SMOKE TESTS PASSED (no assertion hardcodes a skill list/count) |
| `diff CLAUDE.md AGENTS.md` | exactly the L1/L3 title lines |
| `diff .claude/skills/<s>/SKILL.md .agents/skills/<s>/SKILL.md` for `create-phase`, `review-phase`, `archive-phase`, `do-next-slice`, `parallel-phase` | each differs by exactly the two frontmatter keys |
| Claude vs. Codex agent-body diff (`mid`, `high`) | identical bodies |
| `python3 scripts/workflow.py sync-agents --check` | pass — agent files in sync with `executors.toml` |
| quoting grep (every `parallel-*` mention inside a code span/fence) | clean — the only hit is a false positive from a backtick span wrapped across two CHANGELOG lines |
| `grep -rn "never push"` across contract/skills/agents | remaining hits are the two carve-out sentences plus the `commit` skill's already-conditional "unless explicitly asked" |
| `grep -rn "consolidat"` across contract/skills/agents | no unconditional review-time-consolidation sentence left |
| `python3 scripts/workflow.py validate` | pass |
| `python3 scripts/workflow.py next` | unchanged — `current_phase=P12`, `current_slice=P12.S6`, `next_slice=P12.S7` |

## Deviations from `plan.md`

- **Two extra qualifier edits beyond the plan's enumerated list**, both required by the plan's own
  consistency grep (no unconditional consolidation sentence left): the "only on a passing verdict"
  sentence in *Driving This Workspace* and the `doc-new-version` line in the command list; plus the
  "so the review consolidates them" / "consolidates the docs" sentences in the four executor agent
  files (the plan only named their review-behavior paragraph).
- **`create-phase` got its relay as a sub-step of "Make a phase" (4), not at step 5's report**, because
  the hint is printed by `new-phase` and the opt-in must happen while the phase is still `planned` —
  step 5 is a STOP-and-report step.
- The `commit` skill was left alone: its "Never push … unless explicitly asked" is already conditional.

## Engine gaps noted (not patched — `scripts/workflow.py` was out of scope)

1. **The deferral is prose-enforced only.** Nothing stops `doc-new-version` from running inside a
   parallel worktree — the branch review is told not to, but the engine would happily allocate a
   `vNNNN` there and collide with the default stream later. `parallel-consolidated` and (softly)
   `parallel-merge-finish` already check `current_stream()`; `doc-new-version` could refuse (or warn)
   on a parallel stream the same way. Cheap, and it would make the one genuinely collision-prone
   command fail loudly instead of silently.
2. **`parallel-merge-finish` only warns** when run from a parallel worktree while
   `parallel-consolidated` hard-refuses — deliberate per S3, but worth a second look at review time
   for consistency.

Both are recorded here rather than fixed; the review can decide whether either deserves a fix slice.
