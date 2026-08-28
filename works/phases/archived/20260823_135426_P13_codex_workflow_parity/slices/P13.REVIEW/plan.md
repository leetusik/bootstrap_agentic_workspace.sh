# P13.REVIEW — Review Codex workflow parity

Independently review all P13 work against `intent.md`, the confirmed non-visual boundary, every completed slice plan/result, the current durable docs, and the live v29 tree. Complete validation and judgment across the entire phase before deciding the verdict. Never edit source or test machinery on this review slice.

## Scope and evidence

1. Read P13 `intent.md`, `phase.md`, `phase.json`, all completed `slice.json` / `plan.md` / `result.md` files (`DECOMP`, S1, S2, F1, S3, S4, S5), `docs/index.json`, current operations/decisions docs, and relevant commits/diffs.
2. Judge the final tree, not intermediate superseded wording. Specifically verify:
   - both tools ship 17 complete skill packages; every Codex package has explicit-only metadata except the deliberate model-invocable visual guide;
   - Codex `do-next-slice` and `do-whole-phase` are independent automatic-only bodies that reject `gate`, `plan only`, and unknown modes before mutation, preserve `ready` compatibility, stay sequential, and implement the complete state/review/fix loop;
   - Claude retains its existing automatic default plus opt-in `gate` / `plan only`, with obsolete Codex fallbacks removed;
   - final executor matrices are economy Claude Sonnet/Opus@high + Codex Luna/Terra@high; flex Claude Sonnet/Opus@xhigh + Codex Terra/Sol@high; this repo and fresh v29 seed select flex; routing/escalation and post-update resync are correct;
   - actual executing-model attribution is used, with no live hard-coded GPT-5.5 default/example;
   - fresh install, retrofit, and update inventory/managed/stale/seed-once behavior match the release notes;
   - `AGENTS.md` / `CLAUDE.md` bodies are equivalent and P14-owned visual skill bodies were not changed by P13.
3. Audit the phase's operations/decisions doc-impact notes for completeness. No other durable doc area should be required unless the review finds an actual omitted truth.

## Validation

Re-run the unique superset of all slice validation, collecting all findings before branching:

- `bash -n tests/retrofit_smoke.sh`
- `python3 -m py_compile scripts/workflow.py installer/build.py installer/main.py`
- `python3 scripts/workflow.py sync-agents --check`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh`
- `python3 scripts/workflow.py validate`
- targeted semantic/inventory/search assertions equivalent to the durable S5 checks (automatic-only rejection ordering, forbidden Claude mechanics in Codex bodies, `ready` path, 17+17 inventory/metadata, contract parity, executor matrices, v29/changelog/marker, update/no-stale/resync, live-versus-embedded parity)
- `git diff --check`

Historical changelog entries, immutable doc versions, and the pre-review generated `docs/current` may retain superseded GPT-5.5/Claude-only claims; classify those as history rather than live machinery. P14's visual `design-cowork` surface is out of scope except for verifying P13 did not alter it.

## Verdict branch

- On `changes_requested` or `blocked`: finish validation and judgment first, then stop before all pass-only work. Write numbered findings and proposed fix slices in `result.md` and return them; create no doc versions and edit no source.
- On `pass` (this is not a parallel phase): consolidate exactly the complete doc-impact set into new immutable versions:
  1. `python3 scripts/workflow.py doc-new-version --doc operations --summary "Codex first-class automatic workflow parity, executor presets, and v29 installation lifecycle" --source P13.REVIEW`
  2. edit only its returned `edit_path` so the latest operations doc accurately consolidates P13's final state and supersedes old Codex/Claude-only and executor-default claims;
  3. `python3 scripts/workflow.py doc-new-version --doc decisions --summary "Codex automatic-only workflow parity with project executor presets and complete skill inventory" --source P13.REVIEW`
  4. edit only its returned `edit_path` with one clear accepted decision plus necessary supersession notes for old GPT-5.5/Claude-only whole-phase and identical-preset claims;
  5. run `python3 scripts/workflow.py rebuild-docs`, then `python3 scripts/workflow.py validate` and confirm `docs/current` matches `docs/index.json`.

Write a free-form `result.md` with the full judgment, validation, doc versions or findings, and the fixed line `explain: not written — run /explain for this phase`. Append only concise review conclusions to `phase.md`. Return structured `status: done` plus `review_verdict`; do not run `review-phase`, commit, or any other state transition—the orchestrator owns those actions.
