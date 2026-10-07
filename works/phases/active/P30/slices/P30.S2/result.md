# Result — P30.S2 (Skills, texts and release v51)

- status: done
- tier: mid
- summary: Rewrote the `rotate-backlog` skill into the propose, confirm once, create-and-fill-`intent.md`, STOP flow with an `archive-only` opt-out. The create-phase docs-phase route now passes `--consolidates` and names rotate as its entry point, and the archive-phase skill and the README skill row describe the new default. Released v51 (CHANGELOG, `WORKSPACE_VERSION = 51`, installer rebuilt). Smoke is unchanged at 239 PASS / 0 FAIL.
- files_changed: .claude/skills/rotate-backlog/SKILL.md, .claude/skills/create-phase/SKILL.md, .claude/skills/archive-phase/SKILL.md, README.en.md, CHANGELOG.md, installer/main.py, bootstrap_agentic_workspace.sh (rebuilt by installer/build.py), works/phases/active/P30/phase.md, works/phases/active/P30/slices/P30.S2/result.md
- validation:
  - `python3 scripts/workflow.py validate`: PASS (only the pre-existing consolidation/stale/oversized warnings)
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: PASS (in sync), re-run after the last skill wording edit
  - `bash tests/retrofit_smoke.sh`, alone in its own foreground Bash call, output to a file and counted afterwards: 239 PASS / 0 FAIL, rc 0 (baseline 239, no new tests). I ran it twice: once after the main edits and once more after the last one-bullet wording change to the rotate skill plus the installer rebuild; both gave 239/0. The first run's count was taken from a second run because the suite prints no summary count.
  - frontmatter of the three edited skills read back by eye (no PyYAML here): the new `description` is double-quoted with no inner quotes and `argument-hint` is quoted
  - no real `rotate-backlog` was run in this repo
- deviations:
  - The plan said to set `WORKSPACE_VERSION = 51` in `scripts/workflow.py`. The constant lives in `installer/main.py` (v50 changed it there), so I bumped it there. The smoke test pins no literal version (three-way equality of the installer, the top CHANGELOG heading and the fresh marker), so no test edit was needed.
  - I added `argument-hint: "[archive-only]"` to the rotate skill's frontmatter. The plan did not list it. It mirrors `executor-mode` and changes no behaviour.
  - The rotate skill never says "worktree" (the plan said never to mention one); its Rules bullet says the docs phase stays on the default stream and that a parallel-run hint from `new-phase` is relayed, not acted on. I wrote a first draft that named a worktree and removed it before the final build.
- doc_impact: two lines appended to phase.md `## Doc impact` (operations; decisions), tagged `(P30.S2)`. No `doc-new-version`.

## What changed

- **`.claude/skills/rotate-backlog/SKILL.md` (D7).**
  - Frontmatter: `name` and `disable-model-invocation: true` kept; `description` rewritten (quoted); `allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write`; new `argument-hint`.
  - Body: a six-step Procedure.
    - Run `rotate-backlog` (with `--archive-only` and a stop when the args carry `archive-only`).
    - Relay what was archived and what was left active.
    - Read the ending: `docs_phase=none` stops; `docs_phase_covered=` names the live docs phase; a `docs_phase_proposal=` block is presented. One run can print covered lines and a proposal.
    - Propose and ask once, with the `docs-debt` scope summarised. The operator may edit the name or objective or narrow the phase list, and a phase left out keeps owing.
    - On the explicit yes, run the printed `create:` line, or the same shape with the edited text and a narrowed `--consolidates`. Fill `intent.md` as the `create-phase` docs-phase route says (that skill stays the source of truth, so the steps are listed but not duplicated in full).
    - Stop and report the phase id and `intent.md` path, with `/do-whole-phase` to execute it. Never decompose.
  - The contrast with `archive-all` and `archive-phase --force` is kept in the opening paragraph, along with "no `--force`".
  - Rules: the confirmation gate is create-phase's, unchanged (typing `/rotate-backlog` is not the confirmation); the docs phase stays on the default stream; other blockers are never proposed; no `new-phase` before the yes and no `archive-*`/`--force` on the operator's behalf.
- **`.claude/skills/create-phase/SKILL.md` (D8).** Two edits inside *The docs-phase route*. The opening names `/rotate-backlog` as the default entry point that proposes the route and runs the same confirm-then-create sequence. Step 4 now says to create the phase with `--consolidates <the confirmed phases>`: it is what marks a docs phase, so rotate and `docs-debt` see the debt as being paid, it refuses for an id that is not an active phase owing consolidation, and a phase left out keeps owing. No text that Test 0 pins was touched (the smoke run proves it).
- **`.claude/skills/archive-phase/SKILL.md` (D9).** The rotate paragraph says rotate then proposes the docs phase (read-only, the `/rotate-backlog` skill asks once) and names `rotate-backlog --archive-only` beside the command. The gate sentence now reads "`rotate-backlog` leaves it active **and proposes the docs phase that pays it**".
- **`README.en.md`.** The one skill-table row for `rotate-backlog` gains a clause: it then proposes the docs phase that pays the held-back debt (one confirmation; `archive-only` skips it). `README.md` (Korean) names no `rotate-backlog`, so it is untouched.
- **Left alone because still true:** the `rotate-backlog` mentions in `do-next-slice`, `do-whole-phase`, `review-phase`, `parallel-phase` and both executor agent files ("archive just the done phases", "leaves it active", the forbidden-commands list). `do-next-slice` also says "do not create the docs phase on your own initiative", which still holds because the creation is the operator's yes inside `/rotate-backlog`. `CLAUDE.md` has no rotate line that became false.
- **Release (D10).** `CHANGELOG.md` gets `## v51 — 2026-10-07` above v50: the default proposal, `archive-only`, no duplicate/no phase for other blockers, `new-phase --consolidates`, the `docs-debt` `paid by:` line, the `validate` shape check, the skill/doc changes, and a Migration notes line (none required; a pre-v51 docs phase is not seen as covering, so decline a proposal for debt it already pays). `installer/main.py` `WORKSPACE_VERSION` 50 to 51. `installer/build.py` rebuilt `bootstrap_agentic_workspace.sh` (the built file carries `WORKSPACE_VERSION = 51`), `--check` passes. The smoke release-version test (three-way equality) and the "every section has a Migration notes line" test both pass.

## Notebook edits (phase.md)

- `## Decisions`: a `Final (S2)` clause on D7 and on D10 (replacing nothing, adding the final facts).
- `## Doc impact`: two `(P30.S2)` lines, operations and decisions.
- `## Notes for later slices`: the S1 to S2 note consumed; a `(from P30.S2, for P30.REVIEW)` note added; the DECOMP to REVIEW note kept.
- `## Now`: rewritten to point at `P30.REVIEW`. No operator questions raised.

## Dead ends and notes

- The skill flow is text and cannot be run as an operator session from a slice. I checked it by reading it against S1's recorded real proposal output (`docs_phase=none`, `docs_phase_covered=<PX> (pays …)`, the `docs_phase_proposal=` block with `create:` and `scope:`), which the S1 smoke block already exercises through `eval` of the `create:` line.
- Nothing was committed and no state was transitioned.
