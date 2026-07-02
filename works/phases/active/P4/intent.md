# Intent — P4

- Captured at: 2026-07-02T11:30:25+09:00
- Origin: operator

## Original Input (verbatim)

> well, We should do below jobs you make comprehensive one phase that handles below:
>
> 1. when commiting, I think currently opus 4.8 fixed. it should be flexible across models. (now it's fable 5).
> 2. currently installler too fat. maybe refactor(split) it. and store in installer/ dir
> 3. for /update-workspace , I think it's good to dedicated md file. so that the other project can catch up the diff easily. and maybe versioning would also good for both (this repo) and other repo

## Confirmed Intent (refined + clarified)

One comprehensive phase covering three jobs:

**Job 1 — Model-flexible attribution and executor model.** Nothing should pin the workspace to a specific model. Git trailers are stamped by the harness with the real model (history says `Claude Opus 4.8 (1M context)` because Opus 4.8 did that work; the newest commit already says `Claude Fable 5`). The *active* pins to remove:

- `.claude/agents/slice-executor.md` and `.claude/agents/slice-executor-high.md` — `model: opus` → `model: inherit`, so the executor always runs the session's model (Fable 5 today, whatever's next tomorrow). The v0013 "keep `opus` alias, it auto-tracks the top model" decision predates the Fable/Mythos tier above Opus and is superseded — record that in the decisions doc at the phase review. Mirror the change in the installer heredoc that generates these files (`bootstrap_agentic_workspace.sh` ~line 2735).
- Commit Convention hardcodes the Codex trailer `GPT-5.5` — `CLAUDE.md:96`, `AGENTS.md:96`, installer ~line 1065; same pattern in the explain skill (`.claude/skills/explain/SKILL.md:116-117`, `.agents/skills/explain/SKILL.md` mirror, installer ~lines 620-621). Reword to "attribute to the model that actually did the work" with no hardcoded model names (GPT-5.5 becomes an example, not a rule).
- Prose "on `opus`" / "on `gpt-5.5`" references in `README.md` (~170, 246, 289), `CLAUDE.md`/`AGENTS.md` (~line 19), installer (~line 988) — update to model-neutral wording.

**Job 2 — Split the installer into `installer/`.** The installer is a single self-contained 3,025-line file: POSIX sh wrapper (lines 1–99) around one giant `python3 - <<'PY'` heredoc. All emitted files live as embedded string literals (`COMMAND_SKILLS` ~480 lines, `DOC_BODIES` ~440 lines, `WORKFLOW_PY` ~940 lines, plus contract, templates, agent defs, settings) — so every skill edit today requires a matching "mirror into bootstrap" heredoc edit (see commit `fde6f46`). Refactor:

- Source of truth = **live repo files**: the build reads this repo's real `.claude/skills/*`, `scripts/workflow.py`, agent defs, settings, templates, and contract, and embeds them into the distributable — killing the double-maintenance. Fresh-install-only seeds (doc bodies, initial phase scaffold) live as payloads under `installer/`.
- Hard constraint: other repos consume the installer via `curl … | sh` of the raw-GitHub single file, and `/update-workspace` clones and runs that same file — so a build script must assemble the **single-file `bootstrap_agentic_workspace.sh`, committed at repo root**, functionally unchanged for all three modes (fresh, `--into-existing`, `--update`).
- Add a sync check (extend `tests/retrofit_smoke.sh` or a new check) that fails when the committed artifact drifts from the source under `installer/`.

**Job 3 — CHANGELOG + workspace versioning for `/update-workspace`.** Today there is no changelog and no version constant; targets get only `works/.workspace-version.json` (`upstream_url`, `synced_commit`, `synced_at`) and "what changed" is a raw byte-wise file diff. Add:

- A root `CHANGELOG.md` with one entry per workspace version (integer versions v1, v2, …) describing what changed and any manual migration notes; seed it with an initial entry.
- A `WORKSPACE_VERSION` constant in the installer, stamped as `workspace_version` into the target's `works/.workspace-version.json` (both in this repo and in adopting repos).
- `/update-workspace` preview reports "you're on vN → upstream vM" and surfaces the changelog entries in between (read from the fresh upstream clone).

**Cross-job note for DECOMP:** the jobs collide inside the installer (job 1 edits heredoc text, job 2 dissolves the heredocs, job 3 adds version plumbing) — sequencing likely wants the split (job 2) first so jobs 1 and 3 land in modular files, but ordering is DECOMP's call.

## Clarifications Resolved

- Q: Should model flexibility cover attribution wording only, the executor `model: opus` pins only, or both? — A: operator was away at clarify; the recommended option **both** was auto-selected and ratified via plan approval.
- Q: After the split, is the installer's source of truth the live repo files or dedicated `installer/` payloads? — A: operator away; recommended **live repo files** (with `installer/`-local payloads only for fresh-install seeds) ratified via plan approval.
- Q: What versioning shape — integer versions + CHANGELOG.md, commit-keyed changelog, or semver? — A: operator away; recommended **root CHANGELOG.md + integer workspace versions** ratified via plan approval.

## Notes

- Deliverable of the creating session was phase creation only; decomposition and implementation happen when the operator executes P4.
- Directional decisions above were recommendations approved as part of the plan — DECOMP may adjust implementation detail but should surface any deviation from these directions to the operator.
