# P11.S3 — Result

Auto-explain is out of the review path, and a non-passing verdict now **stops** the review executor
before the pass-only work instead of skipping a step and carrying on. Ships as workspace **v21**.

## What changed

### 1. Auto-explain removed from the review path

| File | Change |
|---|---|
| `.claude/skills/review-phase/SKILL.md`, `.agents/skills/review-phase/SKILL.md` | The whole auto-explain paragraph (skill location search, change mode, KB probe, offline fallback, outcome lines, KB-repo commit exception) is **replaced** by one paragraph: the review writes no explainer, explaining is an operator-run `/explain`, and the review's only obligation is the pointer line. |
| `.claude/skills/do-next-slice/SKILL.md`, `.agents/skills/do-next-slice/SKILL.md` | The review paragraph's auto-explain clause replaced with the pointer + the stop rule. |
| `.claude/skills/do-whole-phase/SKILL.md` | Same, in the review bullet. |
| `CLAUDE.md` / `AGENTS.md` (`:19`, `:61`) | Both auto-explain clauses replaced; both bullets now also carry the stop rule. |
| `.claude/agents/slice-executor-high.md`, `.codex/agents/slice-executor-high.toml` | `:32`/`:29` review duties rewritten; `:42`/`:39` **KB-repo `git` carve-out deleted**; `:66`/`:63` `explain` return field is now the fixed pointer. |

The pointer, verbatim and identical everywhere: `explain: not written — run /explain for this phase`.
It is reported on **every** verdict — it costs the executor no work, so it does not conflict with the
stop rule.

**KB-repo commit carve-out deleted, not narrowed.** The "Never commit" bullet in both
`slice-executor-high` files now reads with **no exception anywhere** — not in this repo, not in any
other git root, on any slice kind — with read-only `git status` / `git diff` explicitly still fine
(the bright line is about *writing*, and executors do inspect the tree). `WebSearch` / `WebFetch`
stay on the Claude `tools:` line, untouched, per the operator's call. `slice-executor-low` / `-mid`
never carried the carve-out, so nothing changed there.

### 2. A non-passing verdict stops the executor

Stated in all six surfaces (both `review-phase` copies, both `do-next-slice` copies,
`do-whole-phase`, both `slice-executor-high` files, and both contract bullets). The wording is built
around the distinction the plan flagged as most likely to be got wrong:

- **First**, complete validation and judgment across every slice — "never abort at the first failing
  check, or the orchestrator learns one finding per review cycle instead of all of them at once".
- **Then** branch: `pass` → consolidate docs → return. `changes_requested` / `blocked` → "stop here
  and hand back", doing no doc consolidation and **no other pass-only step**, returning the verdict
  with numbered findings and proposed fix slices (`<P>.F<n>`) for the orchestrator to decide on.
- The old phrasing ("version nothing — fixes land first…") is gone, replaced by an explicit "this is
  a full stop, not a skipped step you carry on past".

Review and doc consolidation remain in the **same** executor; only the branch changed. The
orchestrator side is unchanged in behaviour (`review-phase` records the verdict, then it acts).

### 3. Release plumbing

- `installer/main.py`: `WORKSPACE_VERSION = 20 → 21`.
- `CHANGELOG.md`: a new `## v21 — 2026-07-28` section that says plainly this **reverses v16's
  auto-explain**, that explaining is now operator-run, that the KB-repo commit carve-out is deleted,
  and that a non-passing review stops rather than skipping ahead — including the "stop is scoped to
  the pass-only work, not to the review itself" clarification. **Migration notes: nothing to delete
  or configure**; the review just stops writing explainers, run `/explain` when you want one.
- `python3 installer/build.py` run; the rebuilt `bootstrap_agentic_workspace.sh` (295,953 bytes) is
  left in the working tree, `--check` in sync.

## Deviation from `plan.md` (one, deliberate — `REVIEW` should ratify)

**Two extra live-machinery surfaces were fixed: the bootstrap banner and the seeded `operations.md`
doc body.** The plan's verified table was built from `grep 'auto-explain'`; these two say
"auto-**save** … on a passing review" instead, so the grep missed them. Both are embedded machinery
(not `docs/`, not README), and both would have told every freshly bootstrapped workspace exactly the
thing this slice removes:

- `installer/main.py:633` — the bootstrap's closing knowledge line, now: "export `KB_API_BASE_URL` +
  `KB_API_TOKEN` in `~/.zshenv` so `/explain` can save phase explainers to your KB (an operator-run
  step; the phase review writes none)".
- `installer/payloads/doc_bodies/operations.md` — the `## Knowledge (phase explainers)` section
  seeded as every new workspace's `docs/versions/operations/v0001_bootstrap.md`, now opening with
  "Explaining is an **operator-run step, separate from the phase review**… The review itself writes
  no explainer — it only reports the pointer". The KB setup steps, the Codex network caveat, and the
  plugin alternative are unchanged.

The fresh-install probe was what surfaced them (the banner prints on every bootstrap). A CHANGELOG
bullet records the correction. This stays inside the plan's intent ("live machinery is clean") and
touches nothing the plan's non-goals protect.

## Not done, on purpose — `README.en.md` is now stale (proposed `P11.F1`)

The plan's non-goals say "No README edits", so the README was left alone — but three passages in
`README.en.md` now claim the review produces the explainer and are **false as of this slice**:

- `:48` — "…consolidates its doc versions, and — with the knowledge plugin installed — files a phase
  explainer into your KB."
- `:274-281` — the Knowledge callout: "A passing phase review can auto-save an interactive HTML
  phase explainer…" and "with the env vars set a passing review auto-saves the explainer via plain
  REST".
- `:295-301` — the tier paragraph: "…and, on a pass, producing the phase explainer via the knowledge
  plugin's explain skill — gracefully skipped when the plugin/KB is absent."

`README.md` (Korean) makes **no** explainer claim (grep-verified), so this is one file, three spots.
Recommend `REVIEW` raise it as a fix slice (`P11.F1`, `risk: low` — three named replacements,
no rebuild since the READMEs are not in `FIXED_LIVE_FILES`) or hand it to the operator as a
follow-up. Not a defect in this slice's work; a scope boundary the plan drew.

## Validation — every row of the plan's table, real outcomes

| # | Check | Outcome |
|---|---|---|
| 1 | `grep -rl 'auto-explain'` over `*.md`/`*.toml`/`*.py`, excluding `works/`, `docs/`, `CHANGELOG.md`, the artifact | **PASS** — no hits. (`CHANGELOG.md` keeps two historical v16 mentions plus the new v21 line describing the reversal; `docs/` v16–v19 versions are history for `REVIEW` to supersede.) |
| 2 | `grep -n 'explain' .claude/agents/slice-executor-high.md` | **PASS** — exactly 2 hits: the review-slice duty line and the `explain` return field, both pointer-style. `grep KB_ROOT` → none in either high file. |
| 3 | `grep -n 'WebSearch' .claude/agents/slice-executor-high.md` | **PASS** — still on line 4 (`tools: Read, Edit, Write, Glob, Grep, Bash, WebSearch, WebFetch`). The Codex `.toml` has no tools line (never had one). |
| 4 | `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | **PASS** — empty. (Mirrored by regenerating `AGENTS.md` as its own 4-line header + `CLAUDE.md`'s body, so byte-equality is structural, not eyeballed.) |
| 5 | `review-phase` copies identical below frontmatter (`tail -n +7` vs `tail -n +5`); same for `do-next-slice` | **PASS** — both diffs empty. |
| 6 | `python3 installer/build.py` then `--check` | **PASS** — "wrote bootstrap_agentic_workspace.sh (295953 bytes)", then "OK: … in sync with installer/ source". |
| 7 | `grep -c 'WORKSPACE_VERSION = 21' bootstrap_agentic_workspace.sh`; CHANGELOG has one `## v21` and still one `## v20` | **PASS** — `1`, `1`, `1`. |
| 8 | `python3 scripts/workflow.py validate`; `sync-agents --check` | **PASS** — "Workflow validation passed."; "agent files in sync with executors.toml/defaults" (mode economy, 0 overrides). |
| 9 | Fresh install probe | **PASS** — see below. |
| 10 | Read-through: nothing adjacent weakened | **PASS** — see below. |

### Row 9 — fresh install probe (real run)

Probe root: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/e928efe8-a4ce-400f-8417-b9be6cb5ed57/scratchpad/probe-p11-s3`
(`ws/` = first bootstrap, which exposed the two banner/doc-body misses; `ws2/` = the final v21 tree,
the one to inspect).

- `works/.workspace-version.json` → `"workspace_version": 21` ✅
- `grep -rl 'auto-explain' ws2/` → **nothing** ✅; `grep -rn 'auto-save'` → **nothing** ✅
- "stop here and hand back" present in **both** probe `review-phase` copies (`.claude` :31,
  `.agents` :29) ✅
- pointer line `not written — run /explain for this phase` present in the probe's
  `.claude`/`.agents` `review-phase` (×1 each), both `slice-executor-high` files (×2 each), and
  `CLAUDE.md` / `AGENTS.md` (×2 each) ✅
- bootstrap banner printed the corrected knowledge line ✅
- `python3 ws2/scripts/workflow.py validate` → "Workflow validation passed." ✅

### Row 10 — read-through

Grep-confirmed intact after the edits, in `CLAUDE.md`/`AGENTS.md` and the two loop skills: the
delegation rule ("as a background task"), the approval gate ("plan → operator approves the readied
plan → executor"), `auto` strictly opt-in with its safety halts, the escalation ladder ("at most 2
escalations per slice"), `plan only` / `ready`, P10's copy-based plan capture ("copying the harness
plan file"), and P11.S1's optional idle-window rule ("you *may* use that window"). `git diff --stat`
shows the change confined to the six machinery files, the two contracts, the two installer files,
`CHANGELOG.md`, and the rebuilt artifact — no collateral edits.

## Wording judgements for `REVIEW` to weigh

1. **Where the "not the first failing check" clause lives.** It is stated in the executor contract
   (both high files) and the `review-phase` checklist as an instruction to the reviewer, and echoed
   in the orchestrator-facing skills as an expectation ("it completes validation and judgment first,
   so you receive the whole picture in one cycle"). Duplicated on purpose: the executor may read only
   its agent file plus the checklist, and this is exactly the sentence a fresh reviewer must not
   miss.
2. **"Stop" is phrased as a branch, not an abort.** Each surface says complete validation/judgment →
   *then* branch, and the stop bullet names what is skipped ("doc consolidation … and no other
   pass-only step") rather than saying "stop the review". "This is a full stop, not a skipped step
   you carry on past" is the sentence carrying the replaced "version nothing" semantics.
3. **The pointer is verdict-independent.** Saying "identical on every verdict" avoids a reader
   inferring the pointer is itself pass-only work that the stop rule suppresses.
4. **The commit bullet gained a read-only clause.** Deleting the carve-out left "no exception
   anywhere", which could be over-read as banning `git status`/`git diff` too. The parenthetical
   keeps the bright line about *writes*. Flagging it because it is the one place I added text the
   plan did not ask for inside a safety invariant.
5. **`README.en.md` staleness** — see the section above; `REVIEW`'s call.

## Housekeeping

No commits, no status transitions, no `doc-new-version`, no edits under `docs/`. Two Doc-impact
lines appended to `phase.md` (`operations.md`, `decisions.md`) plus cross-slice notes.
