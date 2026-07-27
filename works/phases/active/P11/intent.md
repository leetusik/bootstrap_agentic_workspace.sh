# Intent — P11

- Captured at: 2026-07-28T03:39:33+09:00
- Origin: operator

## Original Input (verbatim)

> well, drop slice-planner it's we generated agent right? we'll use plain claude code behaviour and it seems launching explore agent if needed. and for readme, fix the readme. both.

> yeah, but dispatching explore while meantime planning is not forced. orchestrator can choose to research by it self, or awaiting for the slice to end(no pre plan), and stuff. I just want to give a free to the orchestrator. and tell it you can plan also while awaiting. it's an option not mandatory. the goal is to make efficient, and high quality work.

## Confirmed Intent (refined + clarified)

Two changes, both landing on top of P10 (workspace v19).

**1. Drop the bespoke `slice-planner` agent and recast the prefetch as an option, not a procedure.**

`P10.S1` shipped `.claude/agents/slice-planner.md` — a workspace-generated agent — and a
`do-whole-phase` rule that reads as a mandated sequence: dispatch executor N, then *immediately*
dispatch the planner for N+1. The operator wants plain Claude Code behaviour instead (the built-in
`Explore` agent is available when a delegated read-only search is the right tool), and, more
importantly, wants the rule to stop prescribing a mechanism at all.

- **Delete the agent** and all three installer touchpoints (`FIXED_LIVE_FILES` in
  `installer/build.py`; the explicit `write_text` and the `MANAGED_FILES` entry in
  `installer/main.py`). This also removes the cause of the known `EXECUTOR_TIERS` gap — no
  `executors.toml` knob, no `validate` drift warning — so that follow-up dissolves rather than
  needing a fix.
- **Rewrite the rule as a permission.** An executor's run is idle time on the main thread, and the
  orchestrator **may** use it to prepare the next slice — by dispatching a read-only research
  subagent (the built-in `Explore`), by reading files inline itself, by thinking the slice through,
  or by simply waiting. Nothing is mandatory and no mechanism is named as required. The rule's job
  is to *permit and encourage* the use of that window, explain when it pays off and when it does
  not, and leave the choice to the orchestrator's judgment per slice. The goal is efficient,
  high-quality work — not a procedure to follow.
- **Keep the invariants that protect the loop** (they constrain whatever the orchestrator chooses,
  not which choice it makes): the preparation is read-only; it never blocks — the executor's
  completion notification always wins; drafts are discarded on any verdict other than `done`; a
  draft lives in the session scratchpad and never becomes, or is read as, an approved plan; no
  second executor is dispatched; the operator's approval gate does not move.
- **Demote the five skip conditions** (`DECOMP`, `REVIEW`, already-`ready`, `pending`,
  blast-radius overlap) from hard rules to guidance — "cases where preparing ahead is usually
  pointless or unsafe" — so the orchestrator reads them as judgment input rather than a checklist.
- **Say the enforcement change honestly in the docs.** `decisions.md` v0024 claims the prefetch is
  read-only *by tool allowlist, not prose*. With the bespoke agent gone that is no longer true —
  `Explore` has `Bash`, and inline research is bounded only by the orchestrator's own discipline.
  The new doc version must state the weakened guarantee plainly rather than carry the old claim
  forward.

**2. Fix both READMEs.** Repair the known stale sections — `README.en.md` (the `.claude/agents/`
inventory, which P10 changed and this phase changes again) and `README.md`'s Korean executor-tier
table (still lists `slice-executor-mid` as Opus; stale since `b26d622` re-cut the presets) — plus
whatever the `slice-planner` removal makes inaccurate. Targeted repair of known-stale content, not
a full end-to-end accuracy audit of both files.

Ships as one release (workspace **v20**) with the usual rebuild obligation.

## Clarifications Resolved

- Q: Dropping `slice-planner` — what replaces it in the `do-whole-phase` prefetch? — A: the
  built-in `Explore` agent, keeping the pipelining; and (operator's follow-up) not as a required
  mechanism — "dispatching explore while meantime planning is not forced… I just want to give a
  free to the orchestrator… it's an option not mandatory."
- Q: How much of the READMEs should the fix cover? — A: fix the known stale bits, not a full
  accuracy pass.
- Q: If the prefetch becomes optional, do P10's five hard skip conditions stay mandatory? — A: no —
  split them: keep as hard rules only what protects correctness (never block, discard on
  non-`done`, a draft is never an approved plan, read-only, no second executor), and demote the
  five skip conditions to guidance.

## Notes

- Builds directly on P10 (`85b5d98` → `dcc62ce`), which shipped the prefetch and the copy-based
  plan capture as workspace v19. P10's copy-based plan capture is **out of scope** here and stays
  exactly as it is.
- Two follow-ups the P10 review left for the operator are folded into this phase: the README
  refresh (item 2) and the `slice-planner`-outside-`EXECUTOR_TIERS` gap (dissolved by item 1). The
  third — lowering `slice-planner`'s `effort` — is moot once the agent is deleted.
- Machinery-change obligations apply to every slice here: mirror rule changes in `CLAUDE.md` **and**
  `AGENTS.md` (`installer/build.py` asserts the bodies are byte-equal); keep the two
  `do-next-slice` copies byte-identical apart from frontmatter; rebuild
  `bootstrap_agentic_workspace.sh` via `python3 installer/build.py` and commit it in the same
  commit (`.githooks/pre-commit` enforces `--check`).
- Doc consolidation at `REVIEW` will need new `operations.md` (v0018 → next) and `decisions.md`
  (v0024 → next) versions; the decisions version supersedes P10's enforcement claim rather than
  adding to it.
