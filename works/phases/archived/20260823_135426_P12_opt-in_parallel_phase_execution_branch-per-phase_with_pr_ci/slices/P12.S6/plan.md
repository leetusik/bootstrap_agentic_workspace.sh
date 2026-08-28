# P12.S6 — Skills + contract for parallel mode

_Auto-mode plan. Context: `phase.md` §Settled Decisions S1–S5 (all binding — command names, flags,
branch format `phase/P<N>-<slug>`, skill-guided `gh`, seed-once CI, the narrowed push deny),
§Constraints, §Doc Impact. The orchestrator pre-researched every documentation surface with a
read-only agent; the line references below come from that pass — re-verify before editing._

## Goal

Teach the agents what the engine already does. After S6, the contract and skills describe parallel
mode end to end: when to suggest it, how to opt in, how work runs in the worktree, how the branch
review defers consolidation, and the agent-run integration sequence (intent amendment 2). Docs
lag code today; this closes the gap. Everything here is machinery (contract, skills, agent files)
→ one installer rebuild at the end covers it.

## Deliverables

### 1. New skill: `parallel-phase` (the lifecycle reference)

`.claude/skills/parallel-phase/SKILL.md` + `.agents/skills/parallel-phase/SKILL.md` +
`.agents/skills/parallel-phase/agents/openai.yaml` (3 new files; skills auto-register in the
installer — folder + rebuild is all it takes, per phase.md's DECOMP correction).

- Frontmatter per convention: `name`, `description` ("Run a phase in parallel on its own branch and
  worktree, and integrate it back: PR, quiet-point gate, merge, deferred doc consolidation,
  teardown." — or similar), `allowed-tools` starting `Bash(python3 scripts/workflow.py:*)` plus
  broad `Bash`, `Read`, `Glob`, `Grep` (it runs git/gh), `disable-model-invocation: true`. The
  `.agents` twin drops the two Claude-only frontmatter keys; `openai.yaml` mirrors the description
  verbatim, `allow_implicit_invocation: false`.
- Body — the full lifecycle, quoting engine commands exactly (backticked, full
  `python3 scripts/workflow.py ...` form; placeholders `<P>`, `P<N>`):
  1. **When**: mirror the engine hints' wording (suggestion only, never a default) — `new-phase`
     hints when another phase is `in_progress`; `next` hints when a planned phase waits behind one.
  2. **Opt in**: `parallel-start <P>` — requires phase `planned`, clean tree, default stream; runs
     between `new-phase` and any `start-slice`; makes its one engine commit and cuts
     `phase/P<N>-<slug>` + a sibling worktree. Open a second session in the worktree (a teammate
     instead clones and checks out the branch — identical from there).
  3. **Work**: in the worktree, `/do-next-slice` / `/do-whole-phase` as normal — selection,
     `pending`, and dashboards are stream-scoped (S1); main's backlog stands still until merge;
     `parallel-status` shows every stream from anywhere.
  4. **Review on the branch**: run the review as usual with ONE difference — a parallel phase's
     passing review **stops before doc consolidation** (no `doc-new-version` on the branch): the
     "Doc impact" list in `phase.md` is verified but consolidation is deferred to main, post-merge.
     Record the verdict with `review-phase` as normal.
  5. **Integrate (agent-run, after the review passes)**: `parallel-gate <P>` locally (GATE OPEN
     required; CLOSED → stop and report — never merge past it) → push the branch (the permission
     prompt is the operator's approval; existing adopters must first remove any old blanket
     `Bash(git push:*)` deny, per the v24 migration note) → `gh pr create` (phase = the reviewable
     unit; PR body from `phase.md`; the passing review verdict is what PR approval maps to) → wait
     for CI (`gh pr checks --watch`; the `parallel-gate` job re-checks the quiet point
     server-side) → merge with a merge commit (`gh pr merge --merge`; slice history is worth
     keeping) → on main: pull, `parallel-merge-finish` (regenerates generated files; conflicts in
     them: take either side, rerun) → **serialized consolidation on main**: read the merged
     `phase.md` §Doc Impact, run `doc-new-version` + edit + `rebuild-docs` for each named doc (one
     phase at a time, never two in parallel) → `parallel-consolidated <P>` → `parallel-teardown
     <P>` → commit. If anything closes the gate mid-sequence, stop and report.

### 2. Contract: `CLAUDE.md` + `AGENTS.md` (strict mirror — byte-identical except L1/L3; apply every edit to both)

- **Commit convention (L97-101)** — the load-bearing carve-out: opting a phase into parallel
  execution *is* the operator's ask. `parallel-start` makes its own engine commit and cuts the
  branch; slice commits land on the phase branch; pushing the branch and opening/merging the PR
  are part of the documented `parallel-phase` integration flow (each push still passes the
  permission prompt). Outside that flow, the old sentence stands verbatim: no branching, never
  push without being asked.
- **Hard Rules** — extend the durable-doc bullet (L54) and the delegation bullet's consolidation
  half (L61): pass-only consolidation happens at the review **except for a parallel-mode phase,
  which defers it to the serialized post-merge step on main** (`parallel-merge-finish` →
  `doc-new-version` → `parallel-consolidated`). Extend the review/archive bullet (L67): archiving
  a parallel phase is blocked while `execution.consolidation` is `"pending"`. Add ONE new compact
  bullet for parallel mode itself (opt-in per phase; phase = the unit of parallelism, slices stay
  sequential; branch+worktree, never a clone; stream-scoped selection and `pending`; quiet-point
  merge gate; merge-safe generated files; suggestion hints are advisory).
- **Canonical State / Read Order (L32, L38)**: the `works/state.json` pointer is scoped to the
  current checkout's stream; cross-stream truth comes from `parallel-status`.
- **Workflow Commands list (L79-95)**: add the six `parallel-*` commands, one line each, matching
  the list's existing style.
- **Driving This Workspace (L15-17)**: add `parallel-phase` to both skill lists (it ships to
  Codex too).
- Keep the additions tight — this contract is a compact routing document; the lifecycle detail
  lives in the `parallel-phase` skill, not here.

### 3. Existing skills (body edits; descriptions unchanged → no openai.yaml churn)

- **`create-phase`** (.claude + .agents): at the routing/`new-phase` step, when the engine prints
  the parallel hint (another phase `in_progress`), surface it to the operator: offer
  `parallel-start <P>` now (before any decomposition/execution) and point at the `parallel-phase`
  skill. Suggestion only.
- **`do-next-slice`** (.claude + .agents) and **`do-whole-phase`** (.claude only): the pointer
  wording is now stream-scoped ("the current stream's active phase"); relay the engine's
  parallel-start hint when `next` prints it; the review-slice consolidation sentences gain the
  parallel deferral condition; the "never push" line gains the integration-flow carve-out
  (same wording as the contract).
- **`review-phase`** (.claude + .agents): L10/L24-25 consolidation claims and the L28-31
  verdict-then-branch sequence gain the parallel condition — on a parallel phase, a `pass` skips
  consolidation entirely (deferred post-merge; the checks about `docs/current` matching apply at
  consolidation time on main, not at the branch review) and the skill points at `parallel-phase`
  for the integration steps.
- **`archive-phase`** (.claude + .agents): the "done with a passing review" gate wording (L18,
  L32) also names the consolidation gate for parallel phases (engine already blocks it).
- **Executor agent files**: check `.claude/agents/slice-executor-high.md`,
  `.claude/agents/slice-executor-mid.md`, `.codex/agents/slice-executor-*.toml` for pass-only
  consolidation wording; where the review behavior is described, add the same parallel deferral
  carve-out. Do not touch the model/effort lines `sync-agents` manages.

### 4. Doc Impact additions (append to `phase.md`)

- Note for the REVIEW slice: `docs/current/decisions.md` currently records parallel fan-out as
  "rejected for now" (grep for it) — P12 supersedes that decision; the consolidation must rewrite
  it, not just append.
- One-line notes for whatever S6 itself changes in durable truth (likely `operations`: the
  parallel-phase skill + contract carve-outs).

### 5. Versioning

S5 already bumped `WORKSPACE_VERSION` to 24 with a v24 CHANGELOG entry this same unreleased
change set — **extend the v24 entry** (new skill + contract/skill updates) rather than bumping to
25. Record this as a settled decision.

## Validation (lean)

1. `python3 installer/build.py` + `--check` — pass (contract, skills, agent files are all
   embedded; the new skill must appear in the artifact — grep it).
2. `bash tests/retrofit_smoke.sh` — pass (fresh-install presence + live-vs-embedded diffs pick up
   the new skill automatically; fix assertions only if they hardcode skill counts/lists).
3. Mirror checks: `diff CLAUDE.md AGENTS.md` shows exactly the L1/L3 title lines; each edited
   skill's `.agents` twin differs from the `.claude` file only by the two frontmatter keys.
4. Consistency greps: every `parallel-*` mention uses the full quoted command form; no remaining
   unconditional "never push"/"consolidate at the review" sentence that contradicts the carve-outs
   (grep for `never push`, `doc-new-version`, `consolidat` across CLAUDE.md, AGENTS.md,
   `.claude/skills/`, `.agents/skills/`, `.claude/agents/`, `.codex/agents/`).
5. Real tree: `python3 scripts/workflow.py validate` + `next` unchanged.

## Boundaries

Executor: docs/machinery text only — **no `scripts/workflow.py` changes** (if prose reveals an
engine gap, note it in `result.md` for the review; do not patch code). No commits in the real
repo, no pushes, no status transitions, no `doc-new-version`, no other slice's `plan.md`. Write
`result.md`; append settled decisions (v24 extension; anything the executor had to decide in
wording) and Doc Impact notes to `phase.md`.
