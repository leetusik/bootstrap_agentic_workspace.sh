# Result — P34.DECOMP

- status: done
- tier: high
- model: opus
- effort: high
- summary: Cut P34 into four sequential slices (S1 engine compact-gate/compact-resume, high for the fail-open core invariant; S2 settings + installer hooks merge, S3 Compact Instructions + skill reorder + doc notes, S4 release v55, all low) and pinned the phase's design in phase.md's Decisions, including two corrections to the plan: the hook command form (the nested rewrite skips a `/`-prefixed engine path) and blocking only by stdout JSON with a trailing `|| true`.
- files_changed: works/phases/active/P34/phase.md; works/phases/active/P34/slices/P34.S1..S4/slice.json (new-slice); works/phases/active/P34/slices/P34.DECOMP/result.md
- validation: `python3 scripts/workflow.py validate` — passed (pre-existing warnings only: P32/P33 doc debt, stale docs, oversized doc sections); new slice folders hold `slice.json` only; `rebuild` regenerated `## Slices`; phase.md 13,903 B (far under budget)
- deviations: (1) hook command form `cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py <cmd> || true` instead of `python3 "$CLAUDE_PROJECT_DIR/scripts/workflow.py" <cmd>`; (2) `compact-gate` blocks only via stdout JSON at exit 0, never exit 2; (3) `in_review` slice status pinned as blocking. Reasons below.
- doc_impact: none (the decomposition changes no durable truth; S3 records the phase's notes)

## What was done

Created with `new-slice` (bare folders, no `plan.md`):

| Slice | kind / risk | order | depends_on | trigger |
|---|---|---|---|---|
| P34.S1 Engine: compact-gate and compact-resume | implementation / high | 1 | — | core invariant (the veto must never fail closed or fail a request) |
| P34.S2 Ship the hooks: settings, installer hooks merge, smoke | implementation / low | 2 | P34.S1 | — (rule pinned, smoke-asserted) |
| P34.S3 Texts: Compact Instructions, skill reorder, doc notes | implementation / low | 3 | P34.S2 | — |
| P34.S4 Release v55 | implementation / low | 4 | P34.S3 | — |

`phase.md`: `## Breakdown (P34.DECOMP)` added; `## Decisions` (13 lines), `## Operator Questions` (the `/autocompact 300k` question), `## Notes for later slices` (5 tagged notes), `## Now` written. No research slice, no design slice, no DECOMP2 — reasons in the Breakdown.

## Verifications made against the tree

- `installer/main.py:44` `WORKSPACE_VERSION = 54` → P34 ships v55.
- `wc -c`: `CLAUDE.md` 12,588; `do-whole-phase/SKILL.md` 42,793; `do-next-slice/SKILL.md` 36,067.
- `_merge_settings_json` (l.301–321) unions only `permissions.allow/deny`, as the plan said.
- **`NESTED_ENGINE_RE = (?<![\w./-])scripts/workflow\.py(?![\w-])`** (`installer/main.py:504`): a command `python3 "$CLAUDE_PROJECT_DIR/scripts/workflow.py"` would **not** be rewritten for the nested layout (the path is preceded by `/`). The plan's "follows the layout for free" was wrong for that form; `cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py …` puts the path after a space, so it is rewritten to `workflow/scripts/workflow.py`, and the cd makes the cwd the host root. Recorded as a Decision; S2 asserts it in the smoke test.
- An argparse error (e.g. a stale engine without `compact-gate`) exits **2**, which Claude Code reads as a block → fail-closed. Hence block-by-JSON-at-exit-0 only, plus `|| true` on the command. Recorded as a Decision.
- `resolve_current` (l.1511): a `pending`/`blocked` phase returns no current slice, so the acceptance gate allows compaction; otherwise the first non-done slice. `in_review` is never set on a slice by the engine (`review_phase` l.2199 drives the REVIEW slice straight to done/changes_requested/blocked); only `set-slice-status` can set it → pinned as blocking (unfinished work; the cap bounds it).
- Probe in a throwaway `cp -R` copy (`scratchpad/probe1`, tree reset with `git checkout -- . && git clean -fd works/`, no commit): `python3 scripts/workflow.py next` on a clean tree leaves exactly ` M works/index.json` and ` M works/state.json` — the dashboard exclusion is necessary and sufficient for `next`.
- Live transcript model ids (`~/.claude/projects/<slug>/<session>.jsonl`): `claude-fable-5-1` on the main thread, no `[1m]` marker → the 1M test must go by model family. Noted for S1.

## Not done (by plan)

No engine/settings/installer/skill/contract/test/doc edits, no middle-slice `plan.md`, no `accept-gate`, no commit. The orchestrator declares `accept-gate P34 --require` after `finish-slice`.
