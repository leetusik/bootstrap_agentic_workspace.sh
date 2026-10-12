- status: done
- tier: mid
- summary: Rewrote the `rotate-backlog` skill to the one-shot chain (branches on the engine's first-line `rotate=` decision), made the minimal edits to `create-phase`, `archive-phase`, `do-whole-phase`, `do-next-slice`, `review-phase`, `CLAUDE.md` (l.13/15/19/53) and the `README.en.md` row, and shipped workspace v54 (version, CHANGELOG with Migration notes, installer rebuilt).
- files_changed: .claude/skills/rotate-backlog/SKILL.md, .claude/skills/create-phase/SKILL.md, .claude/skills/archive-phase/SKILL.md, .claude/skills/do-whole-phase/SKILL.md, .claude/skills/do-next-slice/SKILL.md, .claude/skills/review-phase/SKILL.md, CLAUDE.md, README.en.md, installer/main.py, CHANGELOG.md, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P33/phase.md, works/phases/active/P33/slices/P33.S2/result.md
- validation:
  - `python3 installer/build.py` then `python3 installer/build.py --check` -> pass (OK: in sync)
  - `bash tests/retrofit_smoke.sh` (sole command in its call) -> ALL PASSED, 247 PASS / 0 FAIL by the baseline (the run printed no FAIL line; Test 5 release-version agreement and the Test 6 dual-apply of every skill and `CLAUDE.md` pass)
  - `python3 scripts/workflow.py validate` -> "Workflow validation passed", warnings only the expected three (`consolidation_owed=P33`, `stale_docs=architecture, decisions, operations, qa`, `oversized_doc_sections=8`)
  - frontmatter: PyYAML is not installed, so checked by eye: the rotate-backlog `description` is double-quoted and has no inner double quote; the other five skills' frontmatter is untouched
  - read-through of the new skill against *Engine (landed in P33.S1)*: all five branches named; lines the skill reads (`rotate=refused stream=`, `docs_phase_elsewhere=`, `midflight=`, `stopped_before=`, `docs_phase_order=`, `docs_phase_covered=`, `docs_debt_waiting=`, `docs_phase_proposal=`, `phase=`, `name=`, `objective=`, `create:`, `scope:`, `docs_phase=none`) all match the engine's printed forms; stdout is read before the exit code
- deviations: none. Two judgment calls inside the plan's intent: the `archive-phase` skill's third sentence (the "one more gate" paragraph) also got a one-clause change to stay consistent with the rotated flow; the `create-phase` l.11 addition is a two-sentence exception appended after "Invocation is not the gate; confirmation is."
- doc_impact: two lines appended to `## Doc impact` (operations.md v54 release note, chain paragraph and pre-v51 migration line; decisions.md skill half of the decision superseding v0043), both tagged `(P33.S2)`

## Details

### Skill and text edits
- `rotate-backlog/SKILL.md`: full rewrite. Frontmatter: `argument-hint: "[archive-only] [gate]"`, `allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash, Agent`, still `disable-model-invocation: true`. Body: one paragraph, a Procedure (archive-only, then the engine run and the five `rotate=` branches; `create` shows the proposal, runs the `create:` line as printed, fills `intent.md` per the docs-phase route, commits and continues as `resume`; `resume` commits any `docs_phase_order=` write, runs the docs phase per `do-whole-phase` in `auto` (`gate` restores the approval loop), and after `done` runs the engine once more: `rotate=archive` sweeps and commits, anything else is relayed and STOPs), and a Rules section.
- `create-phase`: l.11 exception for the `/rotate-backlog` docs-phase route (the invocation is the confirmation, for this route only); the docs-phase route's opening paragraph no longer says it archives first and then asks once.
- `archive-phase`: rotate paragraph (debt first, docs phase created and run, archive last; `--archive-only` is the plain sweep) and the "one more gate" clause.
- `do-whole-phase` (l.53, one sentence), `do-next-slice` (l.45, one sentence), `review-phase` (l.85, one clause): archiving is `/rotate-backlog`'s (or `archive-all` / `archive-phase <P>`).
- `CLAUDE.md`: l.13 exception, l.15 carve-out, l.19 one-invocation exception, l.53 archiving line, exactly as the plan states.
- `README.en.md` l.454 row rewritten. `README.md` (Korean) has no `rotate-backlog` row, left untouched.

### v54
- `installer/main.py` l.44: `WORKSPACE_VERSION = 54` (was 52; P32's v53 slots between at merge).
- `CHANGELOG.md`: `## v54 — 2026-10-12` above `## v52`, with Migration notes (nothing to run; a v51–v53 docs phase sits behind planned work until the first `/rotate-backlog`; `archive-only` unchanged; `/update-workspace` overwrites the skill).
- Every place the number `v54` appears: `installer/main.py` (`WORKSPACE_VERSION = 54`), `CHANGELOG.md` (the `## v54` heading, and `pre-v54` in the `archive-only` bullet), `scripts/workflow.py` l.3562 and l.3699 (S1's two `# v54 (P33)` comments), `tests/retrofit_smoke.sh` l.888 (S1's block comment), the rebuilt `bootstrap_agentic_workspace.sh` (embeds the above; regenerate rather than edit), and `phase.md` prose. No `(v54)` tag was added to any skill or to `CLAUDE.md`.

### Notes
- No writing engine command was run in this worktree; `validate` is the only engine command, and the smoke test ran alone in its call. `works/` generated files were already modified before the slice started (the orchestrator's `start-slice`).
- Not done by design: no `doc-new-version`, no commit, no state transition, no engine logic change.
- The review should rewrite the `qa.md` `## Regression Checklist` rotate line (~l.347), which is now false (already in the `for P33.REVIEW` note).
