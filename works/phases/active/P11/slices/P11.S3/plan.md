# P11.S3 — Take auto-explain out of the review; stop on a non-passing verdict

## Context

Two changes the operator added mid-phase (`intent.md` item 3, with their verbatim request):

1. **Auto-explain leaves the review's default behaviour.** P8 made the review produce the phase
   explainer; explaining now becomes a separate operation the operator runs. The review still
   **reports a pointer** so explainers do not silently stop happening.
2. **A non-passing review stops and hands back.** Review and doc consolidation stay in the same
   executor — that is fine — but the moment the verdict is not `pass`, the executor stops before
   the pass-only work and returns findings plus proposed fix slices to the main thread, which
   decides. Today the rules say "on `changes_requested` / `blocked`, version nothing", which reads
   as *skip a step and carry on*; it must read as *stop and report*.

**The critical distinction, and the thing most likely to be got wrong:** "stop" means do not proceed
to the **pass-only work**. It does **not** mean abort at the first failing check. The executor still
completes validation and judgment so the orchestrator receives the complete picture — otherwise
every review cycle surfaces one finding at a time.

Note this partly **reverses P8**. That is deliberate, and the doc consolidation at `REVIEW` must
record the reversal plainly rather than dropping the earlier decision quietly.

Dispatch: **`slice-executor-high`** (`risk: high` — contract surgery across the review path, the
same class of work as `P11.S1`).

## Work

### 1. Remove auto-explain from the review path

Live machinery mentions (verified — `works/`, `docs/`, and `CHANGELOG.md` history are **not** to be
touched):

| File | What is there |
|---|---|
| `.claude/skills/review-phase/SKILL.md` **and** `.agents/skills/review-phase/SKILL.md` | `:30` — the entire auto-explain paragraph (skill location search, change mode, outcome lines, the KB-repo commit exception) |
| `.claude/skills/do-next-slice/SKILL.md` **and** `.agents/skills/do-next-slice/SKILL.md` | `:33` — the review paragraph's "and produces the phase explainer via the installed knowledge-plugin explain skill (auto-explain — …)" clause |
| `.claude/skills/do-whole-phase/SKILL.md` | `:32` — the same clause in the review bullet |
| `CLAUDE.md` **and** `AGENTS.md` | `:19` and `:61` — both carry an "auto-explain" clause |
| `.claude/agents/slice-executor-high.md` **and** `.codex/agents/slice-executor-high.toml` | `:32` review-slice duties; `:42` the **KB-repo `git` commit carve-out**; `:66` the `explain` return field |

Replace, don't just delete:

- **The review's report keeps one pointer line** — `explain: not written — run /explain for this
  phase` (or equivalent). Keep the `explain` field in the executor's structured return with that
  fixed meaning, so the orchestrator surfaces it without doing any work.
- **Delete the KB-repo commit carve-out entirely** (`slice-executor-high` `:42`). It existed solely
  for the explainer's offline fallback; with auto-explain gone, the executor has no business
  running `git` anywhere. The plain "never commit or push" rule stands with no exception.
- **`WebSearch` / `WebFetch` stay** on `slice-executor-high` (operator's call — a reviewer sometimes
  needs to check an external fact). Do not touch the `tools:` line.

### 2. Make a non-passing verdict stop the executor

State this wherever the review's flow is described — `review-phase/SKILL.md` (both copies), the
review paragraphs in `do-next-slice` (both copies) and `do-whole-phase`, the review-slice section of
both `slice-executor-high` files, and the contract bullets:

- Complete **validation and judgment first** — all of the phase's slices, against the objective,
  `intent.md`, and the docs. The verdict is formed from the whole picture.
- If the verdict is **`pass`**: consolidate the docs as today, then return.
- If it is **`changes_requested` or `blocked`**: **stop there.** Do not consolidate docs, do not do
  any other pass-only work. Return the verdict with the numbered findings and proposed fix slices
  (`<P>.F<n>`, one-line scope each) to the orchestrator, which decides what happens next — create
  fix slices, or take the decision to the operator. Replace the current "version nothing" phrasing,
  which reads as *skip a step and continue*.
- The orchestrator side is unchanged in behaviour but should read consistently: it records the
  verdict with `review-phase`, then acts on it.

Keep the two `review-phase` copies byte-identical apart from frontmatter, likewise the two
`do-next-slice` copies, and keep the `CLAUDE.md` / `AGENTS.md` bodies byte-equal.

### 3. Release plumbing

v20 is already released and committed, so this is a **new version**:

- `installer/main.py` → `WORKSPACE_VERSION = 20` → `21`.
- `CHANGELOG.md` → a new `## v21 — 2026-07-28` section. Say plainly that this reverses P8's
  auto-explain-at-review behaviour, that explaining is now a separate operator-run step, and that a
  non-passing review now stops instead of skipping ahead. **Migration notes:** nothing to delete or
  configure — the review simply stops writing explainers; run `/explain` when you want one.
- `python3 installer/build.py`, leaving the rebuilt artifact in the tree.

### 4. Doc-impact notes (append to `phase.md`, no `doc-new-version`)

- **`operations.md`** — the review no longer produces the explainer (with the pointer it reports
  instead), and a non-passing review stops before doc consolidation and hands back to the
  orchestrator. Note that this supersedes the auto-explain description added at v16.
- **`decisions.md`** — a new decision that **reverses P8's** auto-explain-at-review: why (the review
  executor was carrying an authoring-plus-research job at its most context-loaded moment, and
  explaining is a different job from reviewing), what replaces it (an operator-run `/explain`, with
  the review reporting a pointer), and the consequence that the executor's KB-repo commit carve-out
  is gone. Plus the fail-fast rule and why "stop" is scoped to the pass-only work.

## Validation

| Check | Expectation |
|---|---|
| `grep -rn 'auto-explain' --include='*.md' --include='*.toml' .` excluding `works/`, `docs/`, `CHANGELOG.md`, `bootstrap_agentic_workspace.sh` | **no hits** — live machinery is clean |
| `grep -n 'explain' .claude/agents/slice-executor-high.md` | only the pointer-style `explain` return field; **no** KB-repo `git` carve-out |
| `grep -n 'WebSearch' .claude/agents/slice-executor-high.md` | still present — deliberately retained |
| `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | empty |
| `review-phase` copies byte-identical below frontmatter; same for `do-next-slice` | both diffs empty |
| `python3 installer/build.py` then `--check` | rebuild succeeds; in sync |
| `grep -c 'WORKSPACE_VERSION = 21' bootstrap_agentic_workspace.sh` | 1; `CHANGELOG.md` has one `## v21` and still has `## v20` |
| `python3 scripts/workflow.py validate` and `sync-agents --check` | both pass |
| **Fresh install probe** into `<scratchpad>/probe-p11-s3` | `workspace_version: 21`; `grep -rl 'auto-explain'` over the probe returns nothing; the stop-on-non-pass wording present in the probe's `review-phase/SKILL.md` (both copies) |
| Read-through | Confirm nothing adjacent weakened: the delegation rule, the approval gate, `auto`'s safety halts, the escalation ladder, `plan only` / `ready`, P10's copy-based plan capture, and P11.S1's optional idle-window rule |

## Record

`result.md` — what changed, the validation table with real outcomes, and any wording judgement
`REVIEW` should weigh. Append cross-slice notes and the two Doc-impact lines to `phase.md`. No
`doc-new-version`, no edits under `docs/`, no commits, no status transitions.

## Non-goals

- No change to the `explain` skill itself, to the knowledge-base config, or to how `/explain` works
  when run manually — this only stops the *review* from invoking it.
- No splitting of review and docs into separate executors (the operator explicitly kept them
  together); no change to the executor tiers, `executors.toml`, or `sync-agents`.
- No README edits, no `scripts/workflow.py` change, no edits under `docs/`.
- No re-litigating P11.S1's idle-window rule or P10's copy-based plan capture.
