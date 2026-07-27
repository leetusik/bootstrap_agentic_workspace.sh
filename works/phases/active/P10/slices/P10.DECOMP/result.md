# P10.DECOMP — result

Decomposed phase `P10` into **two** middle slices, settled the one design decision `intent.md` left open, and seeded `phase.md`. No implementation, no doc versions, no commits, no status transitions beyond the two `new-slice` calls.

## Slices created

| Slice | Name | Kind | Risk | Order | Depends on |
|---|---|---|---|---|---|
| `P10.S1` | Pipelined prefetch in do-whole-phase | `implementation` | `high` | 1 | — |
| `P10.S2` | Copy-based verbatim plan capture | `implementation` | `medium` | 2 | `P10.S1` |

Both are **bare folders** — each holds only `slice.json`. Neither `plan.md` was pre-filled (the orchestrator writes each at that slice's turn). `P10.REVIEW` (order 9999) was left untouched.

This is exactly the breakdown the plan recommended: one slice per intent item, kept separate because the operator asked for both and they are independent in substance; serial because they overlap in files (`CLAUDE.md`, `AGENTS.md`, `.claude/skills/do-whole-phase/SKILL.md`). Splitting the new agent file into its own slice was considered and rejected — rationale recorded in `phase.md` under *Decomposition*.

Tier consequence of the risk ratings: `S1` → `slice-executor-high`, `S2` → `slice-executor-mid` (in the default `flex` preset both are opus@`xhigh`, so `medium` costs no capability here — it signals reviewability, not a cheaper model).

## Design decision settled

**How the prefetch subagent is defined** (left open by `intent.md`, decided here so `P10.S1` inherits it):

A new `.claude/agents/slice-planner.md` — `tools: Read, Glob, Grep` only (no `Edit`/`Write`/`Bash`/`Agent`/web tools), `model: sonnet`, `effort: xhigh`, `permissionMode: bypassPermissions`, with a description that pins it to returning a **compact brief, never a plan and never a file dump**. **No** Codex counterpart (`do-whole-phase` is Claude-Code-only) and **no** `executors.toml`/`sync-agents` fourth tier — the model stays pinned in the agent file.

Accepted the orchestrator's steer without override. Full rationale and the two consequences it forces (the planner has no `Bash`, so the dispatch prompt must hand it every path it needs; and being outside `EXECUTOR_TIERS` means no config knob and no drift warning) are in `phase.md` → *Findings & Notes → Decision*.

## Deviation from the plan: one factual correction

The plan states a new agent file needs **one** installer edit (`FIXED_LIVE_FILES` in `installer/build.py`). Reading `installer/main.py` shows that is necessary but **not sufficient** — it would ship the file as dead payload. It needs **three**:

1. `installer/build.py` → `FIXED_LIVE_FILES` (lines 42-55) — embeds it into `PAYLOADS`. Skills are globbed from disk (`collect_live_payloads`, build.py:79-84); `.claude/agents/` is not.
2. `installer/main.py` → an explicit `write_text(".claude/agents/slice-planner.md", PAYLOADS[...])`. The existing agent write is a **loop over `("low", "mid", "high")`** (main.py:480-482) and will never emit a fourth file — so without this, install *and* update silently omit it.
3. `installer/main.py` → `MANAGED_FILES` (main.py:79, beside the three executor agents) — fresh-install conflict guard (main.py:365) and managed-file bookkeeping.

This is a correction to a premise, not a scope change: no installer file was edited here (that is `P10.S1`'s job, per this slice's non-goals). It is recorded in `phase.md` → *Findings* and *Constraints* so `S1` cannot miss it.

## Other findings recorded for the middle slices

Verified by inspection, all in `phase.md` → *Findings & Notes*:

- The two `do-next-slice` copies are byte-identical from `# do-next-slice` onward (`diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` → empty); they differ only in frontmatter, and their line numbers are offset by 2.
- The complete list of **plan-persistence sites** `S2` must cover (both `do-next-slice` copies' step 2 *and* their `plan only` branch; `do-whole-phase` lines 18/19/20; contract lines 19 and 59) — plus the gotcha that `CLAUDE.md:42` and `:57` say "verbatim" about `intent.md`, not plan capture, and must not be touched.
- The complete list of **"doing nothing else in the meantime"** sites, and which ones `S1` must *not* touch: the `do-next-slice` copies keep the sentence unchanged (no prefetch there — explicit non-goal), so the shared contract sentence must scope its exception to `do-whole-phase` by name.
- `do-whole-phase/SKILL.md:21` also says executors run "one at a time" — a concurrent prefetch needs a carve-out there too (one *executor* at a time; the read-only planner is not an executor).
- Version precedent: `WORKSPACE_VERSION = 17`; recommended (not mandated) that P10 ship as **one release** — `S1` bumps to 18 and opens `## v18` in `CHANGELOG.md`, `S2` appends to that same section.

## Follow-up not filed

Because `slice-planner.md` sits outside `EXECUTOR_TIERS = ("low", "mid", "high")` (`scripts/workflow.py:30`), operators get no `executors.toml` knob for its model and `validate` will not warn when `/update-workspace` resets it. That is the right trade for this phase, but it is a genuine follow-up. I did **not** run `defer-job` — a decomposition slice's only permitted workflow command is `new-slice` — so it is recorded in `phase.md` as a deferred-job candidate for the orchestrator to file.

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | **passed** — "Workflow validation passed." |
| `python3 scripts/workflow.py next` | **passed** — `current_slice=P10.DECOMP`, `next_slice=P10.S1` |
| `python3 installer/build.py --check` | **passed** — "OK: bootstrap_agentic_workspace.sh is in sync with installer/ source" (no-op, as expected: this slice shipped no machinery change) |
| `works/backlog.md` slice order | **passed** — lists `P10.DECOMP`, `P10.S1`, `P10.S2`, `P10.REVIEW` in order |

## Doc impact

None from this slice. `phase.md` now carries a `## Doc impact` section (empty, with the expected targets noted for planning: `operations.md` v0017 and `decisions.md` v0023 are the only `docs/current/*.md` mentioning the orchestrator or `do-whole-phase`). `S1` and `S2` append their real notes there; `P10.REVIEW` consolidates.
