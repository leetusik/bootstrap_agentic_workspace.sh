# Plan — P4.S1 (Split installer into installer/ with build + drift check)

Orchestrator's native plan. Slice kind: `implementation`, risk `high`. Executor: `slice-executor` (xhigh). Read `phase.md` (installer map + findings) and `intent.md` Job 2 first.

## Goal

Dissolve the 3,025-line self-contained `bootstrap_agentic_workspace.sh` into an `installer/` source tree + build step that emits the **single-file distributable at repo root, committed, functionally unchanged** for all three modes (fresh, `--into-existing`, `--update`). Kill the double-maintenance: after this slice, editing a live skill/agent/contract file + rebuilding is the whole workflow — no heredoc mirroring.

**This slice is a pure refactor: the emitted target-repo content must not change.** Wording/model/version changes belong to S2/S3.

## Hard constraints

- Consumers `curl … | sh` the raw root file and `/update-workspace` clones + runs that same file — the distributable stays **one self-contained POSIX-sh file at repo root** with the same name, flags, env contract (`SYNCED_COMMIT`, `--dry-run`, `--into-existing`, `--update`, `--force-empty-ok`, `--name`, ...), and behavior.
- Build must be **deterministic**: same inputs → byte-identical artifact (sorted directory walks, no timestamps/randomness in the artifact).
- Build runs with stock python3 (it is already the installer's hard dependency); no new dependencies.

## Design (approved direction — adjust details with rationale in result.md)

**Source of truth = live repo files, embedded as finished files.** The live `.claude/skills/*/SKILL.md`, `.agents/skills/*/SKILL.md` + `agents/openai.yaml`, `.claude/agents/*.md`, `.codex/agents/*.toml`, `.codex/config.toml`, `.claude/settings.json`, `scripts/workflow.py`, `works/templates/*.md`, `docs/README.md`, and the contract (`CLAUDE.md` == `AGENTS.md` — build asserts byte-equality and embeds once) are already the exact bytes the installer emits (verified in phase.md findings). So the build embeds finished file contents keyed by target path, and the emit code writes literals — the per-file builder functions (`claude_skill`, `codex_skill`, `codex_openai_yaml`, `claude_subagent_md`, `codex_subagent_toml`) and the `COMMAND_SKILLS`/`WORKFLOW_DOC`/`WORKFLOW_PY` heredocs disappear. Derive `MANAGED_DIRS`/`MANAGED_FILES` and the stale-skill lists from that manifest instead of hand-maintained literals where practical.

Per-skill metadata the emit loop still needs (`claude_only` for do-whole-phase, Codex mirror presence) can be derived from which mirrors exist on disk — `.agents/skills/<name>/` missing ⇒ Claude-only. Runtime interpolation (PROJECT_NAME etc. in the P1 seed and doc frontmatter) stays code in the driver, not payload text.

**Layout (suggested):**

```
installer/
  README.md          # how the split works: edit live files → build → commit artifact
  build.py           # assembles + writes ../bootstrap_agentic_workspace.sh; --check mode
  wrapper.sh         # POSIX sh wrapper source (current lines 1–99) with a marker where the python body goes
  main.py            # the python driver: config/env, write engine, retrofit/update policies,
                     # guards, docs+P1 seeding logic, finalizers, dispatch — with a marker
                     # where the generated payload manifest goes
  payloads/
    doc_bodies/<doc>.md   # the 11 fresh-only DOC_BODIES
    p1_seed/...           # fresh-only P1 scaffold text (phase.md / intent.md bodies etc.)
```

**build.py:** reads `wrapper.sh` + `main.py`, generates the payload manifest (e.g. a dict `target-path → content` built with `json.dumps`-safe literals from the live files + `installer/payloads/`), splices it at the marker, wraps the assembled python in the sh heredoc, writes the root artifact (preserve executable bit). Safety: assert no payload line collides with the heredoc delimiter (pick a distinctive one), `sh -n` the wrapper part, `compile()` the python body, assert CLAUDE.md == AGENTS.md. `--check`: build to a temp path, `cmp` against the committed root artifact, non-zero on drift.

**Drift check in tests:** add one small block to `tests/retrofit_smoke.sh` (keep-tests-small rule — a few lines, not a new suite): `python3 installer/build.py --check`. Existing block 6 (live-vs-fresh diff) plus this closes the loop: live files ↔ artifact ↔ fresh-install output.

## Validation (run all; record outcomes in result.md)

1. `python3 installer/build.py` twice → the two outputs are byte-identical (determinism), and the committed root artifact is the rebuilt one.
2. `python3 installer/build.py --check` → green against the committed artifact.
3. `bash tests/retrofit_smoke.sh` → all blocks green, including the new drift block.
4. **Functional equivalence, fresh mode:** `git show HEAD:bootstrap_agentic_workspace.sh > <tmp>/old.sh`; fresh-install old.sh and the new artifact into two temp dirs (same `--name`/`--summary`/`--phase-name`/`--phase-objective`); `diff -r` the trees excluding only timestamp-bearing files (`works/state.json`, `works/index.json`, `works/events.jsonl`, `works/.workspace-version.json`, `*/phase.json`, `*/slice.json`, `docs/index.json`, `docs/versions/*` frontmatter dates — byte-compare everything else, and structurally sanity-check the excluded ones).
5. **Functional equivalence, update mode:** fresh-install with old.sh into a temp git repo, then run the NEW artifact `--update --dry-run` on it → change-list reports **zero updated machinery files** (content identical ⇒ no diffs); then a real `--update` succeeds and `python3 scripts/workflow.py validate` passes there.
6. `python3 scripts/workflow.py validate` in this repo.

## Wrap-up

- `result.md`: what moved where, build/check usage, validation command outcomes, any deviations from this design.
- `phase.md` appends: cross-slice note for S2/S3 — "to change emitted content: edit the live file (or `installer/payloads/` for fresh-only seeds), run `python3 installer/build.py`, commit the rebuilt artifact"; plus Doc impact lines (operations: installer build/release procedure; architecture: installer/ source tree + committed distributable shape).
- Never commit; never transition state. The orchestrator commits after `finish-slice`.
