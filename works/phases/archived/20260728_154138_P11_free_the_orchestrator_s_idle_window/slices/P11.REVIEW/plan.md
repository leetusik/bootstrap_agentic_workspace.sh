# P11.REVIEW — phase review

## Context

All four middle slices are landed and committed:

| Slice | Commit | What shipped |
|---|---|---|
| `P11.S1` | `87b0912` | Deleted `.claude/agents/slice-planner.md` + all four installer touchpoints; the `do-whole-phase` prefetch became an **optional** idle-window practice; mirrored byte-equally into both contracts. **v20** |
| `P11.S2` | `fb91424` | Two README tier corrections (`slice-executor-mid` is sonnet; `high` is the catch-all) |
| `P11.S3` | `15102bb` | Auto-explain removed from the whole review path (nine live machinery files) and replaced by a fixed pointer; the KB-repo `git` carve-out deleted; a non-passing verdict now **stops before doc consolidation** and hands back. **v21** |
| `P11.S4` | `fc63153` | Corrected the three `README.en.md` passages S3 falsified |

**This review is the first to run under its own new rules** — no explainer, and a stop-and-hand-back
on anything short of a `pass`. Follow them as written in `.claude/skills/review-phase/SKILL.md`, not
from memory of how reviews used to work.

Dispatch: **`slice-executor-high`** (review always). It writes **only docs** — never source, never
skills, never the contract, never the READMEs. Anything needing a fix is `changes_requested` with
proposed fix slices, not an edit.

## 1. Validate all four slices together

Form the verdict from the complete picture — run everything, then judge. Report real outcomes:

- `python3 scripts/workflow.py validate`; `python3 installer/build.py --check`;
  `python3 scripts/workflow.py sync-agents --check`.
- `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` — empty.
- Paired skill copies byte-identical below frontmatter: `review-phase` and `do-next-slice`.
- `grep -c 'WORKSPACE_VERSION = 21' bootstrap_agentic_workspace.sh` → 1; `CHANGELOG.md` has `## v21`
  **and** still `## v20`.
- **No live `slice-planner` reference** — `grep -rn 'slice-planner'` excluding `.git/`, `works/`,
  `docs/`: only `installer/main.py`'s `OBSOLETE_MACHINERY` entry, its mirror in the artifact, and the
  historical `## v19`/`## v20` CHANGELOG sections.
- **No live auto-explain reference** — `grep -rn 'auto-explain\|auto-save'` over the same scope
  returns nothing. Note `docs/` is excluded because fixing it is this slice's own job.
- **Fresh end-to-end install probe** into an unused dir (`<scratchpad>/probe-p11-review2`). In the
  *probe*: `workspace_version: 21`; `.claude/agents/` holds exactly the three `slice-executor-*`
  files; `grep -rl 'slice-planner\|auto-explain\|auto-save'` returns nothing — **including the seeded
  `docs/versions/operations/v0001_bootstrap.md`**, which S3 had to fix separately because it said
  "auto-save" rather than "auto-explain"; the stop-on-non-pass wording present in both `review-phase`
  copies; the probe's own `validate` passes.
- **README consistency** — `README.en.md` and `README.md` agree with each other and with v21: no
  claim that a review writes an explainer, tier facts matching the `economy` default.

## 2. Review against the objective, `intent.md`, and the results

`intent.md` has **three** items (item 3 was added mid-phase; its verbatim request is recorded there).
Judge each:

- **Item 1 — the idle-window rule reads as a permission.** Read the `do-whole-phase` bullet and the
  contract's Hard Rules bullet cold: would an orchestrator take them as *"you may, and here is how to
  judge it"* or as *"do this, unless…"*? The operator's standard: *"I just want to give a free to the
  orchestrator… it's an option not mandatory."*
- **Item 2 — the READMEs** are accurate after S2 and S4.
- **Item 3 — the review's own contract.** Auto-explain is gone from every live path and replaced by
  the pointer; the KB-repo commit carve-out is gone so "never commit" holds in every git root;
  `WebSearch`/`WebFetch` deliberately remain. And the fail-fast wording carries the distinction that
  matters: **stop** applies to the pass-only work, *not* to the review — validation and judgment
  always complete first.
- **Invariants and neighbours intact:** read-only preparation, no second executor, never block,
  discard on non-`done`, scratchpad-only, the approval gate unmoved; the delegation rule, `auto`'s
  safety halts, the escalation ladder, `plan only` / `ready`, "each slice owns exactly two context
  files", and P10's copy-based plan capture (out of scope this phase).

**Items referred to this review:**

1. **`P11.S3`'s deviation** — it fixed two surfaces my plan's `grep 'auto-explain'` table missed
   because they say "auto-**save**": `installer/main.py`'s install banner and
   `installer/payloads/doc_bodies/operations.md` (seeded as every new workspace's `operations`
   v0001). Confirm both fixes are correct and complete — this is the one place a miss would ship a
   false claim to every future workspace.
2. **`P11.S1`'s deviation** — the plan's `grep -c 'slice-planner' <artifact>` = 0 expectation was
   self-contradictory (the artifact embeds `installer/main.py`, so the `OBSOLETE_MACHINERY` line
   rides in it). Real count is 1; confirm the intent holds via the probe.
3. **Two P10-era follow-ups should now be closed, not carried forward** — the README refresh (done by
   S2 + S4) and the `slice-planner`-outside-`EXECUTOR_TIERS` gap (dissolved by deletion). Say so
   explicitly if you agree, so nothing lingers as an open item.

## 3. On a pass — consolidate the docs

Only on `pass`. `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source
P11.REVIEW`, edit only the returned `edit_path`, then `rebuild-docs`. Never patch `docs/current/*.md`
or an old version; a new version is the whole doc carried forward, not a diff.

`phase.md` carries **four** Doc-impact notes — two from S1, two from S3 — consolidating into **two**
versions, each covering both:

- **`operations.md`** (v0018 → next): the idle-window practice is optional and mechanism-free with
  the bespoke agent retired (recast the v19 `slice-planner` section and its other v19 mentions); the
  review no longer writes the explainer (superseding the v16 auto-explain description **and** the
  `## Knowledge (phase explainers)` "a passing review auto-saves" framing — explaining is operator-run
  `/explain`, the review reports a pointer); a non-passing verdict stops before doc consolidation and
  hands back; the KB-repo commit carve-out is gone. Verify against the actual current file rather than
  trusting the line numbers in the notes.
- **`decisions.md`** (v0024 → next): **supersede, don't erase.** Keep P10's and P8's decisions as
  history and mark what each is superseded by. Record P11's two decisions — (a) drop the bespoke agent
  for plain harness behaviour and make the practice optional, stating plainly that read-only is now a
  rule to follow rather than a tool-allowlist guarantee; (b) reverse P8's auto-explain-at-review, with
  its reasoning, the pointer that replaces it, and the carve-out removal — while `WebSearch`/`WebFetch`
  stay by the operator's call.

Then confirm `python3 scripts/workflow.py validate` is still clean (it catches a stale
`docs/current`).

## 4. No explainer

Per v21, the review writes **no** phase explainer: locate no explain skill, run no KB probe, no
fallback, no commit anywhere. Report the single pointer line — `explain: not written — run /explain
for this phase` — in `result.md` and in the structured return, identical on every verdict.

## 5. Report

Write `works/phases/active/P11/slices/P11.REVIEW/result.md`: the validation table with real
outcomes, the verdict and its reasoning, each referred item and how it was decided, the doc versions
created, and the pointer line. Append any durable notes to `phase.md`.

Return `review_verdict` (`pass` | `changes_requested` | `blocked`), `doc_versions`, and the
`explain` pointer. On `changes_requested`, propose numbered fix slices (`P11.F1`, …) with a one-line
scope each and **stop before any doc work**. You never commit and never transition slice/phase
status — the orchestrator records the verdict with `review-phase`.
