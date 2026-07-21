# P8.REVIEW plan — phase review (auto mode)

Review the whole of phase P8 "Auto-explain at phase review" against its objective, `intent.md`, the slices' `result.md`, and the docs — then decide a `review_verdict`. This review runs on the **new** machinery P8.S1 just landed (commit `9a015a0`), so on a pass it consolidates docs **and dogfoods the auto-explain step for the first time**.

## Scope

Completed slices: `P8.DECOMP` (decomposition, commit `d24edaa`) and `P8.S1` (the atomic machinery change, commit `9a015a0`). Phase change-ref for the explainer: these two commits / the phase's diff.

## Validate all slices together

Re-run every slice's validation:

- `python3 installer/build.py --check` (artifact in sync)
- `python3 scripts/workflow.py sync-agents --check` (tools: edit must not trip drift)
- `bash tests/retrofit_smoke.sh` (installer regression)
- `python3 scripts/workflow.py validate` (state integrity)
- Mirror checks: `diff <(tail -n +4 CLAUDE.md) <(tail -n +4 AGENTS.md)` empty; `.claude`/`.agents` bodies of `review-phase` and `do-next-slice` SKILL.md identical (frontmatter-only diff); high-executor `.md`/`.toml` bodies identical (toml closing `"""` aside)
- Spot greps: auto-explain wording present in the 11 edited machinery files and embedded in the rebuilt artifact; `WORKSPACE_VERSION = 16` in `installer/main.py` + artifact; mid/low agent files and the Codex high toml carry **no** `WebSearch`

## Judge

- Objective shipped? (review = validate + consolidate docs + explain; graceful skip; Codex mirrors; contract; installer rebuilt same-commit)
- Each slice met its plan; deviations explained in `result.md`? (S1 reported none)
- The five settled decisions in `phase.md` implemented faithfully (pass-gated, verdict-neutral, ordered detection, WebSearch/WebFetch Claude-high only, scoped KB-repo commit carve-out)?
- Contract/mirror hygiene: CLAUDE.md/AGENTS.md body-identical with own headers; no historical CHANGELOG edits; `docs/current` untouched by slices.

## On a pass — in this order

1. **Consolidate docs** from the two CONFIRMED Doc-impact notes in `phase.md`: `python3 scripts/workflow.py doc-new-version --doc operations --summary "..." --source P8.REVIEW` and `--doc decisions ...`; edit only each returned `edit_path`; then `python3 scripts/workflow.py rebuild-docs` and re-run `python3 scripts/workflow.py validate`.
2. **Auto-explain the phase** per the new checklist in `.claude/skills/review-phase/SKILL.md` (your own updated instructions): locate the installed explain skill (user-level `~/.claude/skills/explain/SKILL.md` exists on this machine), follow it in **change mode with phase P8 as the change-ref**. The skill's steps govern (KB probe → research gate → API save → fallback). This machine resolves the KB via the legacy convention (`~/projects/personal/knowledge`); the API path (201) makes no local git — only the API-unreachable fallback may commit, and **only** in the KB repo, never here, never push. Best-effort: any failure → report and move on; the outcome NEVER changes the verdict.
3. Report the `explain:` outcome line in `result.md` and the verdict block's `explain` field.

On `changes_requested`/`blocked`: no doc versions, no explainer — numbered issues + proposed fix slices (P8.F1, …) instead.

## Deliverables

`result.md` (validation table, judgment, doc versions, explain outcome), durable notes appended to `phase.md`, and the structured verdict block (`review_verdict` + `doc_versions` + `explain`). Never edit source; never commit; never transition status — the orchestrator records the verdict via `review-phase`.
