# P10.REVIEW — phase review — result

**Verdict: `pass`.** Both intent items shipped, every non-goal held, and a fresh end-to-end install
probe confirms the payload is live rather than dead. Two consolidated doc versions were created
(`operations` v0018, `decisions` v0024) and the phase explainer was saved. Three recommendations
are recorded below for follow-up — none of them blocks the phase.

## 1. Validation (all slices together, real outcomes)

| Check | Command | Outcome |
|---|---|---|
| Workflow state | `python3 scripts/workflow.py validate` | **PASS** — `Workflow validation passed.` (re-run clean after doc consolidation) |
| Artifact in sync | `python3 installer/build.py --check` | **PASS** — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| Tier config unaffected | `python3 scripts/workflow.py sync-agents --check` | **PASS** — exit 0, `agent files in sync with executors.toml/defaults`, `mode economy (default), 0 override(s)`. `slice-planner` is outside `EXECUTOR_TIERS`, so it is neither synced nor flagged |
| Contract byte-equality | `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | **PASS** — empty |
| `do-next-slice` copies equal | `diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` | **PASS** — empty |
| One release, not two | `grep -c 'WORKSPACE_VERSION = 19' bootstrap_agentic_workspace.sh` → `1`; `grep -c '^## v20' CHANGELOG.md` → `0` | **PASS** |

### End-to-end install probe (the check that catches dead payload)

Fresh install into an unused scratch dir:
`sh bootstrap_agentic_workspace.sh <scratchpad>/probe-review --name probe-review` — completed
cleanly (`rebuilt workflow and docs`, `Workflow validation passed.`). Verified **inside the probe**:

| Probe assertion | Result |
|---|---|
| `.claude/agents/slice-planner.md` exists, byte-identical to source | **PASS** — `diff` empty; 5,485 bytes beside the three executor tiers |
| `.claude/settings.json` contains `Bash(cp:*)` | **PASS** — line 5 of `permissions.allow` |
| Prefetch present in `do-whole-phase/SKILL.md` | **PASS** — `slice-planner` ×3, `Prefetch the next slice` ×1 |
| Prefetch **absent** from both `do-next-slice` copies | **PASS** — `slice-planner` ×0 and `prefetch` ×0 in `.claude/skills/` *and* `.agents/skills/` |
| Copy rule at all four rule sites | **PASS** — `harness plan file`: `do-next-slice` (Claude) ×1, `do-next-slice` (Codex) ×1, `do-whole-phase` ×3, `CLAUDE.md` ×2, `AGENTS.md` ×2 |
| Version stamp | **PASS** — `works/.workspace-version.json` → `"workspace_version": 19` |

Probe dir: `/private/tmp/claude-502/.../scratchpad/probe-review`.

## 2. Review against the objective and `intent.md`

**Intent item 1 (pipelined planning) — delivered.** `do-whole-phase/SKILL.md` gained the dispatch
carve-outs plus a `Prefetch the next slice's research` bullet with all five skip conditions, the
blast-radius definition, per-slice sizing, never-block, discard-on-non-`done`, scratchpad-only, the
reconcile-don't-re-research step, and mode coverage. `.claude/agents/slice-planner.md` ships with
`tools: Read, Glob, Grep` and is written by the installer at fresh install (three-edit wiring
verified by the probe, not by grep).

**Intent item 2 (copy-based plan capture) — delivered.** Every persistence site now copies: both
`do-next-slice` copies (default + `plan only`, same paragraph), `do-whole-phase`'s default loop and
`plan only`, and both contract clauses; `auto` explicitly stays on `Write` with the reason stated.
The confirm-before-copy guard, the "before the next `EnterPlanMode`" timing, and the append-after
rule are all present at the primary sites. `CLAUDE.md:42`/`:57` (the operator-intent "verbatim"
references) were correctly left alone.

**Invariants confirmed intact** by reading the amended paragraphs end-to-end:

- The approval gate has not moved — `CLAUDE.md`'s "the single gate is the operator's approval of
  each **readied plan** before the executor runs" is untouched, and the prefetch bullet restates
  it ("**the operator's approval gate does not move**").
- `auto`'s four safety halts, the escalation ladder (incl. max-2 and never-past-high), `plan only`
  / `ready` semantics, the delegation rule, and "each slice owns exactly two context files" are all
  present and unweakened. S1's two additive strengthenings (no repo writes / no workflow-state
  moves while an executor runs; inline supplementary research is read-only too) read as deliberate
  tightening, not drift.
- The prefetch is **`do-whole-phase`-only** and read-only **by tool allowlist**, not by prose —
  confirmed both in source and in the probe (0 mentions in either `do-next-slice` copy).
- **No fourth tier**: `EXECUTOR_TIERS` is still `("low","mid","high")` and `sync-agents` enumerates
  three. **No Codex counterpart**: `.codex/agents/` holds exactly the three executor tomls.
- Swept for missed persistence sites (`grep` across `.claude/skills`, `.agents/skills`,
  `.claude/agents`, `.codex/agents`, `README.en.md`) — none found.

**One coherent release.** The `## v19` section reads as one release: four prefetch bullets, two
copy bullets, and a single Migration-notes paragraph covering both. The Migration notes do read as
a correction rather than a contradiction — they now enumerate the `do-next-slice` change directly
instead of repeating S1's "untouched" claim. One residual looseness noted under Recommendations.

## 3. The three items the slices referred to this review

1. **S2's terser `plan only` bullet in `do-whole-phase/SKILL.md` — accepted as-is, no fix slice.**
   The bullet is not a bare cross-reference: it names the mechanism inline ("persist the plan by
   **copying the harness plan file** to that slice's own `plan.md`") and defers only the
   confirm/immediacy/append detail with "— the same confirm-then-copy rule as the default loop
   above". The referent is a *backward* reference two bullets up in the same file, and the full
   rule is also spelled out in `do-next-slice`'s own `plan only` branch. An agent following the
   skill cold gets the action, the object, and an unambiguous pointer. Re-spelling a fourth
   multi-clause sentence in one file would add drift surface, not clarity. Judged sufficient.
2. **Stale READMEs — recommendation, not a fix slice here.** Confirmed both: `README.en.md:170-175`
   still says "the three risk-routed `slice-executor` tier subagents" while enumerating what
   `.claude/` ships, and now under-counts `.claude/agents/`; `README.md`'s Korean tier table
   (~lines 152-155) still lists `slice-executor-mid` as Opus, stale since `b26d622`/v18 (actual:
   sonnet). Neither is embedded machinery, neither was in either slice's scope, and a review slice
   writes only docs — so nothing was edited. **Recommended as one small follow-up covering both
   files together** (fixing only the English one would leave the pair inconsistent). A follow-up
   rather than a `P10.F1`: the staleness is user-facing prose, predates this phase in the Korean
   case, and reopening a validated phase for it buys nothing.
3. **`effort: xhigh` on `slice-planner` — sanity-checked, kept, flagged as worth lowering.** The
   value is pinned in-file and deliberately independent of the presets, so the stale DECOMP
   rationale ("matches the `flex` preset's low tier" — untrue since `b26d622`) is a stale
   *justification*, not a defect. But on the merits it now points the wrong way: `xhigh` maximises
   latency for an agent that lives under "a late brief is dropped", and the current default preset
   is `economy` (low tier = sonnet@`medium`). **Recommend lowering to `medium` or `high`** —
   one line in `.claude/agents/slice-planner.md` plus a rebuild. Not changed here (a review writes
   no source), and not a blocker: an over-thorough brief is dropped, never wrong.

## 4. For the orchestrator to file after the phase (executors cannot run `defer-job`)

- **`slice-planner` sits outside `EXECUTOR_TIERS`.** Consequences: (a) no `executors.toml` knob for
  its model/effort, and (b) `validate` emits no drift warning when `/update-workspace` resets it to
  the upstream default. Deliberate for this phase (a fourth tier is a wider engine change), but a
  genuine follow-up — worth a `defer-job`, ideally bundled with recommendation 3 above.
- **README refresh** (recommendation 2) — a second candidate `defer-job` or a small follow-up phase.

## 5. Doc versions created

Two, consolidating the four "Doc impact" notes in `phase.md`:

- **`docs/versions/operations/v0018_…_workspace_v19.md`** — new sections *Pipelined slice planning —
  the `slice-planner` prefetch (since v19)* (the agent and why the allowlist is the enforcement
  mechanism, its exclusion from `executors.toml`/`sync-agents` and what that costs, dispatch-by-path,
  the five skip conditions + blast radius, never-block / discard / scratchpad-only, per-slice sizing,
  the unmoved gate, the accepted trade-offs) and *Persisting the approved plan by copy (since v19)*
  (the confirm-before-copy guard as load-bearing, timing, append-after, the `Write` fallback, every
  covered site, and the `Bash(cp:*)` merge on `--update`). Also: the `--update` write policy now
  notes `.claude/agents/` arrives whole, and *Building and releasing the installer* gained the
  **three-edit rule for a new agent file** with the "verify with a real install probe, not a grep"
  warning.
- **`docs/versions/decisions/v0024_…_workspace_v19.md`** — two new Decision Log entries at the top:
  *Pipeline the next slice's research into the executor's idle window via a read-only
  `slice-planner` subagent (P10)* and *Persist the operator-approved plan by copying the harness
  plan file instead of retyping it (P10)*, each with context, decision, alternatives considered
  (incl. the rejected fourth tier, the rejected Codex counterpart, and copy-without-the-guard), and
  consequences with the accepted trade-offs. The `Bash(cp:*)` rationale is recorded explicitly:
  it grants nothing beyond the already-allowed `Write` tool.

`python3 scripts/workflow.py rebuild-docs` then `validate` — both clean; `installer/build.py --check`
still OK after the doc work (docs are not embedded machinery).

### One correction made while carrying content forward (declared)

The `operations.md` **Executor tiers** table and the **Environment Variables** table still described
the pre-`b26d622` defaults (`haiku` low tier, uniform `xhigh` efforts) — stale since v18, which
landed as a direct commit outside any phase and never got a doc version. Since a new version is the
whole doc and is signed as current, carrying a knowingly-false table forward was not acceptable;
both tables were corrected to the two shipped presets (`economy` default: sonnet@`medium` /
sonnet@`high` / opus@`high`; `flex`: sonnet@`high` / sonnet@`xhigh` / opus@`xhigh`; Codex identical
in both) and a `mode` row was added. This is a doc-only factual correction outside P10's own scope,
recorded here so it is not mistaken for phase content.

## 6. Auto-explain

**`explain: saved /Users/sugang/projects/personal/knowledge/docs/bootstrap_agentic_workspace.sh/2026-07-28-pipelined-planning-and-copy-based-plan-capture-p10.html`**
(local fallback; verdict-neutral, and it was `pass` on its own merits regardless).

- Skill located at `~/.claude/skills/explain/SKILL.md` (no project copy, no plugin install) and
  followed as written, in change mode with P10 as the change-ref.
- KB probe: `KB_STATUS=configured` via the legacy convention —
  `KB_ROOT=~/projects/personal/knowledge`, `KB_API_BASE_URL=http://localhost:8766`, no token,
  `KB_LOCAL_FALLBACK=yes`. (Note: `KB_API_BASE_URL`/`KB_API_TOKEN` were **not** set in this
  environment, so the v17 env-var/REST default did not apply.)
- Research section: **included** — three sources opened and cited (IdleSpec idle-time speculative
  planning on arXiv; Zylos Research on side-effect-free speculative execution and discarding
  mispredictions; Anthropic Engineering on Claude Code's read-only tool allowlist and least
  privilege). The explainer's *Best practices & next steps* records where P10 aligns with
  prevailing practice, where it deliberately diverges (no runtime conflict detection; depth-1
  speculation; `bypassPermissions` composed with a 3-tool allowlist), and four next steps.
- API save: **unreachable** — `curl` exit 7 (`Failed to connect to localhost port 8766`), so the
  skill's step-6 local fallback ran: the HTML was written with the `<!--kb …-->` comment
  frontmatter, the Recent bullet was inserted after the `<!-- explain:recent -->` marker in
  `docs/index.md`, and the KB repo was committed (`cfcb409`) under the **scoped KB-repo-only**
  carve-out — `git -C ~/projects/personal/knowledge`, no push, nothing committed in this
  workspace's repo. A later `POST /api/reindex` (or `docker compose up -d` in the KB) reconciles
  the DB.

## 7. Deviations from `plan.md`

1. **The `rm -rf` pre-clean of the probe dir was denied by the settings deny-rule**, as it should
   be. Used a plain `mkdir -p` into the (unused) `probe-review` path instead; the install ran
   against a genuinely empty directory, so the probe's meaning is unchanged.
2. **One doc correction beyond P10's scope** — the stale executor-tier tables in `operations.md`,
   declared in full in §5 above.

Otherwise none. No source, skill, contract, or README file was edited; no commits in this repo; no
status transitions.

## Return

- `review_verdict`: **`pass`**
- `doc_versions`: `operations/v0018_…`, `decisions/v0024_…`
- `explain`: `saved /Users/sugang/projects/personal/knowledge/docs/bootstrap_agentic_workspace.sh/2026-07-28-pipelined-planning-and-copy-based-plan-capture-p10.html`
