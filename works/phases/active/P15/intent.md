# Intent — P15

- Captured at: 2026-08-14T05:10:12+09:00
- Origin: operator

## Original Input (verbatim)

> drop codex stuff entirely from this repo. maybe you should make a phase for this task.

## Confirmed Intent (refined + clarified)

Remove OpenAI Codex support from this upstream bootstrap workspace completely, so it ships
Claude Code only and the dual-harness parity tax disappears.

In scope:

- Delete the Codex-only trees outright: `.agents/` (17 mirrored skills, each with an
  `agents/openai.yaml`) and `.codex/` (`config.toml` plus the two `slice-executor-*.toml`
  executor agents).
- Delete `AGENTS.md` entirely. `CLAUDE.md` becomes the single agent contract; the
  `AGENTS_HDR` constant, the `CLAUDE.md == AGENTS.md` byte-equality assertion in
  `installer/build.py`, and the dual contract write in `installer/main.py` all go with it.
  It is *not* kept as a thin pointer, even though `AGENTS.md` is a broader cross-tool
  convention — the operator chose full deletion.
- Strip Codex from the load-bearing machinery: `scripts/workflow.py` (executor presets,
  `read_executors_toml` / `executor_config` / `sync-agents` / `validate`), `installer/build.py`
  (payload globs and the 17-to-17 parity assertions), `installer/main.py` (managed dirs and
  files, machinery classification, payload writes, stale-skill flagging, final banner),
  `executors.toml`, `installer/wrapper.sh`, and `.githooks/pre-commit`.
- Strip Codex from the tests: `tests/retrofit_smoke.sh` (Test 0 is ~90% Codex assertions;
  the retrofit, fresh-install, mode-matrix, `--update`, and drift-manifest blocks all carry
  Codex expectations too).
- Strip Codex from the prose: `CLAUDE.md` itself, `README.md`, `README.en.md`,
  `docs/retrofit-guide.md`, `installer/README.md`, the shipped doc bodies under
  `installer/payloads/doc_bodies/`, and the handful of Codex mentions inside
  `.claude/skills/{design-cowork,explain,update-workspace}/SKILL.md` and the
  `AGENTS.md` co-mentions across `.claude/skills/*` and `.claude/agents/slice-executor-*.md`.
- Give existing adopters a flagged upgrade path: add `.agents/`, `.codex/`, and `AGENTS.md`
  to `OBSOLETE_MACHINERY` in `installer/main.py` so a `--update` run tells the operator to
  remove them. `--update` never deletes; flagging is the mechanism that already exists for
  retiring shipped machinery.
- Regenerate `bootstrap_agentic_workspace.sh` via `python3 installer/build.py` in the same
  commit as any embedded-machinery edit, per the contract's upstream-repo rule.

Out of scope — the historical record is preserved, not purged:

- `works/phases/active/P13` ("Codex workflow parity") and `P14` ("Codex visual-design cowork
  replacement") stay as they are; they are completed work, not machinery.
- `docs/versions/**` is never patched (hard rule). New durable truth is recorded as new doc
  versions at `P15.REVIEW`, and `docs/current/*.md` regenerates from those.
- `works/events.jsonl` and `CHANGELOG.md` are append-only history and stay as they are.

This is a single phase covering machinery, installer, tests, docs/READMEs, and the
regenerated artifact.

## Clarifications Resolved

- Q: `AGENTS.md` is currently a byte-identical twin of `CLAUDE.md` (asserted by `build.py`),
  and it is also the generic cross-tool convention (Cursor, Amp, Copilot read it) — not only
  Codex. Delete it entirely, keep it as a thin pointer to `CLAUDE.md`, or keep the full
  mirror minus Codex content? — A: Delete it entirely.
- Q: The working tree carried an uncommitted P14 follow-up (pinning the Codex `design-cowork`
  branch to verified GPT Image 2) — all Codex work this phase will delete. Commit it first,
  discard it, or let the P15 removal absorb it? — A: Commit it first, then remove. Landed as
  `c307eb9 feat(p14): pin codex visual cowork to verified gpt image 2` before P15 was created,
  so the work exists in history and the removal diff is honest.
- Q: Existing adopters have `.agents/`, `.codex/`, and `AGENTS.md` on disk. Flag them via the
  existing `OBSOLETE_MACHINERY` mechanism on `--update`, or just stop shipping them silently?
  — A: Flag as obsolete on `--update`.

## Notes

- Stated assumption, not asked: the historical record above is preserved. If decomposition
  disagrees, raise it rather than silently purging.
- Survey done at phase-creation time, as raw material for `P15.DECOMP` — this is context,
  **not** a slice breakdown. Line numbers were accurate at commit `c307eb9`; re-verify.
  - Delete outright: `.agents/` (34 files), `.codex/` (3 files), `AGENTS.md`.
  - `scripts/workflow.py`: `CODEX_AGENTS` (~L41); `codex_model`/`codex_effort` keys in all
    four `EXECUTOR_PRESETS` tier dicts (~L51-60) — note every preset entry is one flat dict
    carrying four keys, so this is an edit to each dict, not a branch deletion;
    the `(claude|codex)` regex alternations and error strings in `read_executors_toml()`
    (~L116-166); the `codex_` field prefixing in `executor_config()` (~L168-182);
    `_patched_agent_toml()` (~L196-210, exists only for `.codex/agents/*.toml`);
    `executor_agent_files()` 4 entries to 2 (~L214-221); `sync_agents()` printing (~L223-250);
    the `validate` warnings over those files (~L753, L758); the next-step hint (~L1133).
  - `installer/build.py`: Codex entries in `FIXED_LIVE_FILES` (~L47, L50-51); `AGENTS_HDR`
    (~L62-63); the `.agents/` payload globs (~L86-88); the whole parity-assertion block
    including `EXPECTED_SKILL_COUNT = 17` (~L90-117); the `CLAUDE.md == AGENTS.md` assertion
    in `collect_contract_body()` (~L121-130).
  - `installer/main.py`: `CODEX_SKILLS` and its parity guards (~L57-71); `MANAGED_DIRS` /
    `MANAGED_FILES` (~L79-105); retrofit contract sidecar handling (~L232-266);
    `_is_machinery()` (~L273-289); update dispatch (~L340-351); contract write (~L476-478);
    Codex payload writes (~L553-572); `OBSOLETE_MACHINERY` additions (~L597-606);
    `flag_stale_skills()`'s per-tool marker branch (~L615-640); the final print block
    (~L709-724).
  - Gotcha: `flag_obsolete_machinery()` (~L609-612) checks only `is_file()`. Flagging the
    `.agents/` and `.codex/` **directories** requires extending that check, or the new
    entries will silently never fire.
  - `executors.toml`: the preset documentation (~L11-15) and the commented `[codex.*]`
    block (~L43-48).
  - `tests/retrofit_smoke.sh`: Test 0 rewritten wholesale (~L38-106), plus the pinned
    modified-file list (~L135), the Codex-installed assertions (~L165-175), the fresh-install
    inventory and tier models (~L236-255), the economy/flex mode matrices (~L263-279), the
    `--update` staleness assertions (~L288-303), the byte-for-byte drift manifest
    (~L346-357), and the rejected-install check (~L380).
  - `.githooks/pre-commit` (~L8): drop `\.agents/|\.codex/` from the staged-path alternation.
  - `installer/wrapper.sh`: the `usage()` heredoc (~L21, L25-26). There are no per-tool
    installer flags today — dual-tool install is unconditional, so nothing to gate, only
    to remove.
  - Contract and prose: `CLAUDE.md` (~L3, 16, 21, 23, 25, 27, 65, 68, the "Narrow Codex
    design exception" at ~L70, ~L71, the entire "**Codex branch:**" half of the design rule
    at ~L75, and the `<noreply@openai.com>` attribution sentence at ~L114);
    `.claude/skills/design-cowork/SKILL.md` (~L200-201);
    `.claude/skills/explain/SKILL.md` (~L156, L460-461);
    `.claude/skills/update-workspace/SKILL.md` (~L12); `AGENTS.md` co-mentions across
    `.claude/skills/*` and `.claude/agents/slice-executor-{mid,high}.md`;
    `README.md` (18 hits, incl. the tier table with GPT-5.6 columns ~L165-168);
    `README.en.md` (32 hits, incl. the project-structure tree ~L391-413);
    `docs/retrofit-guide.md` (16 hits, incl. the 17+17 inventory ~L146-157);
    `installer/README.md` (~L44, L66-96);
    `installer/payloads/doc_bodies/architecture.md` (~L20) and `operations.md` (~L27, L40-48).
- Every slice touching embedded machinery must finish with `python3 installer/build.py` and
  commit the regenerated `bootstrap_agentic_workspace.sh` in the same commit;
  `python3 installer/build.py --check` must pass (the tracked pre-commit hook enforces it).
- Review-time verification should include a Codex-free `tests/retrofit_smoke.sh` run, a fresh
  install into a temp dir, and an `--update` against a pre-P15 workspace showing `.agents/`,
  `.codex/`, and `AGENTS.md` flagged stale.
