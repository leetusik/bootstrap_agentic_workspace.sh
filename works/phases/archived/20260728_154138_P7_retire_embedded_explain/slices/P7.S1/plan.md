# Plan — P7.S1: Remove explain from the distribution

Orchestrator plan (do-whole-phase, auto mode — operator opted in for this run). Executor: `slice-executor-mid`.

Read `works/phases/active/P7/phase.md` first — its **Findings & Notes** section carries the verified, line-exact removal footprint, the decided `--update` behavior, and the verified knowledge-plugin install pointer. This plan sequences that work; phase.md is the detail source. Phase intent: `works/phases/active/P7/intent.md`.

## Job

Remove the explain feature from the bootstrap distribution in one coherent change (the orchestrator commits it as one commit): skill copies, installer wiring, smoke-test rewrite, README.en.md, CHANGELOG v15, `WORKSPACE_VERSION` 15, and the installer rebuild. Point users at the knowledge repo's plugin.

## Steps (order matters — edits before rebuild)

1. **Delete the skill copies** (whole dirs): `.claude/skills/explain/`, `.agents/skills/explain/`.
2. **`installer/wrapper.sh`** — remove the four explain bits: usage line (~16), `with_explain=0` init (~52), `--with-explain` case arm (~65), `export WITH_EXPLAIN` (~90). The generic `-*) die "unknown option $1"` arm then rejects the flag.
3. **`installer/main.py`** — remove the whole optional-skill block (lines ~60–68: `WITH_EXPLAIN` env read, `--update` keep-refresh special case, `OPTIONAL_SKILLS`, `_excluded` filtering); `CLAUDE_SKILLS`/`CODEX_SKILLS` stay as the sorted lists derived from `PAYLOADS`. Bump `WORKSPACE_VERSION` (line ~38) 14 → **15**. Do **not** touch `flag_stale_skills` or `OBSOLETE_MACHINERY` (phase.md explains why they're already correct).
4. **`tests/retrofit_smoke.sh`** — keep the "default install omits explain" assertions (~173–174) as permanent regressions. Replace the whole Test 8 block (~209–222, `--with-explain` install + dual-apply diff loop) with a compact assertion that `--with-explain` is now an **unknown option**: run the built installer with `--with-explain`, expect non-zero exit and the unknown-option error. Keep the surrounding tests and numbering coherent; match the file's existing ok/bad style.
5. **`README.en.md`** — remove the `--with-explain` flag-table row (~162), the optional-explain prose (~171–172), the explain skills-table row (~273), and the "explain is the one exception" prose (~287–289). **Recount the skill counts from the repo state after deletion** (e.g. "14 core Agent Skills", "15 Agent Skills" at ~253) — count `.claude/skills/*/` dirs, don't blindly decrement. Where the removal leaves a natural place to say so (the skills section), add a short pointer: the explainer feature now lives in the knowledge repo's Claude Code plugin — see step 6 for the exact commands; keep it to a sentence or two, matching the README's voice.
6. **`CHANGELOG.md`** — add a new top entry `## v15 — 2026-07-21`, matching the house style of v14's entry (bold-lead bullets). Content: embedded `/explain` and `--with-explain` are retired; the feature lives on as the knowledge repo's Claude Code plugin — verified pointer (do not invent another):

       /plugin marketplace add leetusik/knowledge
       /plugin install knowledge@knowledge

   then `/knowledge:setup` once, `/knowledge:explain <topic>` to use (note the namespace change from bare `/explain`). **Migration notes:** existing installs are never auto-deleted — on `--update`, `.agents/skills/explain` is flagged stale ("remove manually?") while `.claude/skills/explain` is left untouched (no marker → treated operator-owned); remove both copies manually and install the plugin. Historical entries stay byte-untouched.
7. **Rebuild:** `python3 installer/build.py` — regenerates `bootstrap_agentic_workspace.sh` (drops embedded explain payloads + wrapper flag). Then `python3 installer/build.py --check` must pass.

## Validation (run all; report results in result.md)

- `python3 installer/build.py --check` → OK.
- `sh tests/retrofit_smoke.sh` → all tests pass (including the rewritten Test 8 and the kept 173–174 regressions).
- `python3 scripts/workflow.py validate` → passes.
- Leftover-reference sweep: `grep -rn "with-explain\|WITH_EXPLAIN\|OPTIONAL_SKILLS" .` and `grep -rni "skills/explain" .` — expected survivors ONLY: CHANGELOG historical entries (v1/v2-era lines), `docs/versions/` + `docs/index.json` history, `works/` (phase folders, archived), and this phase's own files. Zero hits in `installer/`, `.claude/`, `.agents/`, `tests/`, `README*`, and the rebuilt `bootstrap_agentic_workspace.sh`. Report any surprise hit.

## Hard constraints

- Same-commit rebuild rule: your edits + the rebuilt `bootstrap_agentic_workspace.sh` are staged together by the orchestrator in ONE commit; your job is to leave the worktree in that exact state with `--check` passing. Never hand-edit `bootstrap_agentic_workspace.sh`.
- Do NOT run `doc-new-version` (REVIEW consolidates). Append one-line **Doc impact** notes to `phase.md`'s "Doc impact" list (operations: explain no longer ships, `--with-explain` retired, plugin pointer; decisions: embedded explain retired in favor of the knowledge plugin).
- Do NOT run deferred commands — the orchestrator drops D1 after you return.
- Do NOT touch `docs/current/`, `docs/versions/`, historical CHANGELOG entries, root `README.md` (its only "explains" is the contract tagline), or anything under `works/` beyond `phase.md` notes and your own `result.md`.
- Never commit; never transition slice/phase status.

## Done means

Worktree holds the complete removal with all validation green; `result.md` written (free-form: what changed, validation output, any deviations); `phase.md` Doc impact lines + a short cross-slice note appended; structured verdict returned (`done | needs_operator | blocked | escalate` + summary + files changed + validation results).
