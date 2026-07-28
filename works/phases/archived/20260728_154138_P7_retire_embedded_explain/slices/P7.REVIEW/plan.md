# Plan — P7.REVIEW: phase review of "Retire embedded /explain"

Orchestrator plan (do-whole-phase, auto mode). Executor: `slice-executor-high`.

Read first: `works/phases/active/P7/phase.md` (objective, findings, constraints, **Doc impact** list), `works/phases/active/P7/intent.md` (confirmed operator intent), the two slice results (`slices/P7.DECOMP/result.md`, `slices/P7.S1/result.md`), and `AGENTS.md`.

## Job

Validate the whole phase's work together, review it against the objective / intent / workspace contract, and — only on a passing review — consolidate the phase's Doc impact notes into new durable doc versions. Return a `review_verdict`.

## 1. Phase-wide validation (run all; report output)

- `python3 installer/build.py --check` → must pass (rebuilt artifact in sync with `installer/` source).
- `sh tests/retrofit_smoke.sh` → full suite green, including the rewritten Test 8 (`--with-explain` rejected as unknown option) and the kept "default install omits explain" regressions.
- `python3 scripts/workflow.py validate` → passes.
- Leftover-reference sweep: `grep -rn "with-explain\|WITH_EXPLAIN\|OPTIONAL_SKILLS" .` and `grep -rni "skills/explain" .` — expected survivors ONLY: CHANGELOG history + the new v15 entry, `docs/versions/**` + `docs/index.json` + `docs/current/` history (pre-consolidation), `works/**`, and the two plan-mandated smoke-test blocks (the kept regressions + new Test 8). Zero hits in `installer/`, `.claude/`, `.agents/`, `README*`, and the rebuilt `bootstrap_agentic_workspace.sh`.
- Consistency spot-checks: `WORKSPACE_VERSION = 15` in `installer/main.py` and embedded in the rebuilt artifact; CHANGELOG's top entry is `## v15 — 2026-07-21` with a Migration notes line and the verified plugin pointer (`/plugin marketplace add leetusik/knowledge`, `/plugin install knowledge@knowledge`, `/knowledge:setup`, `/knowledge:explain`); README.en.md skill counts match the real `.claude/skills/*/` count and its plugin pointer matches the same commands.

## 2. Review dimensions

- **Objective met:** every piece of the phase objective (phase.md) shipped — skill copies gone, `--with-explain` path gone, KB wiring gone, users pointed at the plugin, installer rebuilt, D1 resolved (check `works/deferred/dropped/D1/` exists and open deferred count is 0).
- **Intent honored:** intent.md's gate was verified before work started; the plugin pointer used is the verified one (never invented); "leave current state as is till knowledge done" was respected (work started only after the knowledge P7 pass).
- **Contract kept:** docs untouched by S1 (no `doc-new-version` ran before this slice); same-commit rebuild rule held (the S1 commit `31c78d9` contains both machinery edits and the rebuilt artifact); historical CHANGELOG entries and `docs/versions/` byte-untouched; root `README.md` untouched.
- Did each slice meet its plan? Are deviations explained in `result.md`? (S1 recorded one: the smoke test legitimately retains `--with-explain` strings to test the rejection — the plan's sweep bullet was over-broad, the deviation is correct.)

## 3. On a PASSING review only — consolidate docs

Consolidate the phase.md **Doc impact** list into new doc versions (you are the review slice — `doc-new-version` is allowed here, and ONLY here):

- `python3 scripts/workflow.py doc-new-version --doc operations --summary "<one line: embedded explain retired — no longer ships, --with-explain removed, workspace v15; install the knowledge plugin (/plugin marketplace add leetusik/knowledge → /plugin install knowledge@knowledge; /knowledge:setup, /knowledge:explain)>" --source P7.REVIEW` — body: what changed operationally, the `--update` behavior for old installs (never auto-deleted; `.agents` copy flagged stale, `.claude` copy left untouched; remove both manually), and the plugin pointer. Supersedes the truth of operations v0010/v0011.
- `python3 scripts/workflow.py doc-new-version --doc decisions --summary "<one line: embedded /explain retired in favor of the knowledge repo's Claude Code plugin; manual migration, stale-flag asymmetry accepted>" --source P7.REVIEW` — body: the decision, rationale (plugin makes explain portable for real — resolves D1 by deletion; single distribution point in the knowledge repo), and the accepted `--update` asymmetry.

Write only docs — never source, never works state beyond your own `result.md` + phase.md notes. Do not hand-edit `docs/current/` (generated). Verify `python3 scripts/workflow.py validate` still passes after versioning.

If the review does NOT pass: consolidate nothing; list the concrete problems and proposed fix slices instead.

## Done means

`result.md` written (validation outputs, review findings per dimension, docs consolidated or why not); a short review note appended to phase.md's Findings & Notes; structured verdict returned including `review_verdict: pass | changes_requested | blocked` with a one-line note, plus any proposed fix slices on `changes_requested`. You never commit and never transition slice/phase status — the orchestrator records the verdict via `review-phase`.
