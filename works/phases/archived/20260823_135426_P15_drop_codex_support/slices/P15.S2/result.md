# Result — P15.S2: Strip Codex from the installer and delete the Codex trees

**Status: done.** The atomic cut landed as one coherent change set: `installer/build.py`,
`installer/main.py`, `installer/wrapper.sh`, `.githooks/pre-commit`, the deletion of `.agents/`
(34 files), `.codex/` (3 files) and `AGENTS.md`, and the regenerated
`bootstrap_agentic_workspace.sh`. Deletions are staged via `git rm -r`; everything else is
unstaged for the orchestrator. **No commit was made.**

## What changed

### `installer/build.py`

- `FIXED_LIVE_FILES`: dropped `.codex/config.toml` and both `.codex/agents/slice-executor-*.toml`.
- Dropped both `.agents/skills` payload globs (`*/SKILL.md`, `*/agents/openai.yaml`).
- Parity block: removed the `codex_skills` comprehension, the two-arm length check, the
  `claude_skills != codex_skills` die, and the `missing_metadata` block. **`EXPECTED_SKILL_COUNT`
  survives as a Claude-only assert** (`expected 17 Claude skills; found N`) — a real guard against a
  truncated payload, kept per plan.
- Deleted `AGENTS_HDR`.
- `collect_contract_body()` is now three lines: read `CLAUDE.md`, check `CLAUDE_HDR`, return the
  body. The `AGENTS.md` read, the `AGENTS_HDR` check and the body-equality check are gone;
  **the `CLAUDE_HDR` check is kept verbatim** — `P15.S3` owns that literal.
- Module docstring rewritten (no longer names `.agents/skills/*`, the `.codex` subagents,
  `.codex/config.toml`, or "the `CLAUDE.md == AGENTS.md` contract body"); it now says the
  contract body is embedded header-stripped, and adds `executors.toml` which the old list omitted.

### `installer/main.py`

- Deleted `CODEX_SKILLS` and both import-time parity guards (the 17↔17 `RuntimeError` and the
  `missing_codex_metadata` `RuntimeError`). The Claude-side count assert is kept, matching
  `build.py`.
- `MANAGED_DIRS`: dropped `.agents`, `.agents/skills`, `.codex`, `.codex/agents`, and the
  per-skill `.agents/skills/<n>{,/agents}` extend loop.
- `MANAGED_FILES`: dropped `"AGENTS.md"`, `.codex/config.toml`, both
  `.codex/agents/slice-executor-*.toml`, and the per-skill `.agents` entries.
- `_merge_contract()`: docstring is CLAUDE-only; the pointer block now reads
  ``skills under `.claude/` `` (was `` `.claude/`/`.agents/` ``).
- `_retrofit_handle()`: `if path in ("CLAUDE.md", "AGENTS.md")` → `if path == "CLAUDE.md"`.
- Update dispatch: same narrowing, plus the comment block above it (`CONTRACT (sidecar-aware):
  CLAUDE.md`, and the OVERWRITE list lost `.codex/config.toml`).
- `_is_machinery()`: now `path == "scripts/workflow.py"` plus a prefix check over
  `.claude/agents/`, `.claude/skills/`, `works/templates/`.
- Deleted `write_text("AGENTS.md", …)`; the section header is now `Routing contract (CLAUDE.md)`.
- Fresh-install writes: deleted the `CODEX_SKILLS` skill/yaml loop, the
  `.codex/agents/slice-executor-*.toml` write inside the shared tier loop, and the
  `.codex/config.toml` write with its section comment.
- **`OBSOLETE_MACHINERY`** — final list (4 added, 2 collapsed):
  `.claude/agents/slice-executor.md`, `.env.example`, `executors.toml.example`,
  `works/templates/result.md`, `.claude/agents/slice-planner.md`,
  `.claude/agents/slice-executor-low.md`, **`.agents`**, **`.codex`**, **`AGENTS.md`**,
  **`AGENTS.workspace.md`** — the four new entries each commented
  `# Codex support dropped in v31 — …`. Removed `.codex/agents/slice-executor.toml` and
  `.codex/agents/slice-executor-low.toml`, now subsumed by the `.codex` directory entry
  (they would have double-reported).
- **`flag_obsolete_machinery()`: `is_file()` → `.exists()`**, with a comment saying why. Without
  this the two new directory entries would silently never fire and the whole migration promise
  would be dead code.
- `flag_stale_skills()`: dropped the `.agents/skills` half and the `agents/openai.yaml` ownership
  marker; the Claude `disable-model-invocation: true` marker logic is byte-for-byte unchanged, just
  de-looped. Docstring rewritten (it was per-tool prose).
- Banners: retrofit banner now says "If CLAUDE.md already existed, reconcile the
  CLAUDE.workspace.md sidecar" and drops `$create-phase in Codex`. Fresh banner: "Bootstrapped
  agentic workspace" (was "cross-tool"), "Contract: CLAUDE.md" (was "Contracts: CLAUDE.md and
  AGENTS.md (equivalent)"), the whole Codex skills line deleted, the design line keeps only the
  Claude Design + DesignSync half, and the final "Next:" line drops `$create-phase (Codex)`.

### `installer/wrapper.sh`

`usage()` heredoc only: "tuned for BOTH Claude Code and OpenAI Codex" → "tuned for Claude Code";
the `AGENTS.md / CLAUDE.md are equivalent … cross-tool fallback` bullet → "CLAUDE.md is the compact
routing contract every agent reads"; the dual-skill bullet → `.claude/skills/` only. No flag
handling touched (there are no per-tool flags).

### `.githooks/pre-commit`

Dropped `AGENTS\.md$|`, `\.agents/|`, `\.codex/|` from the L8 alternation. Verified below that this
does not affect the S2 commit itself.

### Deletions

`git rm -r .agents .codex AGENTS.md` → **38 paths staged as `D`** (34 + 3 + 1), matching the
inventory in `phase.md`. Nothing left on disk.

## Validation

Every command below was actually run; the artifact was executed for real, not just built.

| # | Command | Outcome |
| --- | --- | --- |
| 1 | `python3 installer/build.py` | **pass** — `wrote bootstrap_agentic_workspace.sh (325505 bytes)` |
| 2 | `python3 installer/build.py --check` | **pass** — `OK: … in sync with installer/ source` |
| 3 | `python3 scripts/workflow.py validate` (this repo) | **pass** — `Workflow validation passed.` |
| 4 | Fresh install: `bash bootstrap_agentic_workspace.sh <tmp>/fresh --name x --summary y` | **pass**, exit 0 |
| 5 | Fresh-install inventory check | **pass** — see below |
| 6 | `python3 scripts/workflow.py validate` in the fresh workspace | **pass** |
| 7 | `python3 scripts/workflow.py sync-agents --check` in the fresh workspace | **pass** — `agent files in sync with executors.toml/defaults` |
| 8 | Retrofit into a dir seeded with its own `CLAUDE.md` **and** `AGENTS.md` (`--into-existing`) | **pass**, exit 0 |
| 9 | `diff` of the seeded `AGENTS.md` before/after retrofit | **pass** — byte-identical |
| 10 | `--update` against a pre-S2 workspace carrying `.agents/`, `.codex/`, `AGENTS.md`, `AGENTS.workspace.md` | **pass** — all four flagged, nothing deleted |
| 11 | Codex-residue grep over the four files | **pass with a documented reinterpretation** — see *Deviations* |
| 12 | Narrowed pre-commit regex vs. this slice's staged path set | **pass** — still fires |

### 4-7 — the gate the build cannot provide

The plan's central hazard is that `build.py` only `compile()`s the assembled body (~L171), so
`main.py`'s import-time guards never run at build time. Running the artifact is what proves the
cut. It ran clean:

```
rebuilt workflow and docs
Workflow validation passed.
Bootstrapped agentic workspace at …/fresh
Contract: CLAUDE.md
Claude Code: 17 skills in .claude/skills/ (e.g. /do-next-slice), subagent tiers …
```

No `RuntimeError: embedded skill inventory …`, no `KeyError`. Resulting workspace:
`.claude/skills` = **17**, `.claude/agents/` = exactly `slice-executor-{mid,high}.md`, `CLAUDE.md`
present; **no** `.agents/`, `.codex/`, `AGENTS.md`, or `AGENTS.workspace.md`. Top level is exactly
`.claude .gitattributes .github CLAUDE.md docs executors.toml scripts works`.

`sync-agents --check` printed the S1 format (`mid   sonnet @ xhigh` / `high  opus @ xhigh`) and
exited 0 — the S1 engine change and the S2 installer change compose correctly in a *freshly
installed* workspace, which is the combination neither slice could verify alone.

### 8-9 — retrofit leaves a repo's own `AGENTS.md` alone

Seeded target: its own `CLAUDE.md`, its own `AGENTS.md`, and `src/app.py`. Result: exit 0,
`merged (additive): CLAUDE.md`, 52 files created. The seeded `AGENTS.md` diffs **byte-identical**,
and **no `AGENTS.workspace.md` sidecar was created**. `CLAUDE.md` gained the pointer block, which
now reads:

```
> This repo uses the agentic workspace (`scripts/workflow.py` + skills under `.claude/`).
```

Pre-S2 this same run would have read `AGENTS.md`, written `AGENTS.workspace.md`, and appended a
pointer block to `AGENTS.md`. The installer is now strictly less invasive.

### 10 — the adopter migration path

Setup per the plan: fresh-installed `<tmp>/old` with the **committed** pre-S2 artifact
(`git show HEAD:bootstrap_agentic_workspace.sh`), then hand-seeded an `AGENTS.workspace.md` to
simulate a retrofitted adopter's strand, then `--update` with the new artifact. Output:

```
  stale workspace skills/machinery dropped upstream (remove manually?): .agents, .codex, AGENTS.md, AGENTS.workspace.md
```

All four flagged, each exactly once (no double-report from the collapsed `.codex/agents/*` entries).
Nothing deleted: the Codex file count is **37 before and 37 after**, both `AGENTS.md` and
`AGENTS.workspace.md` still present, and `AGENTS.md`'s md5 is unchanged
(`ad6306c1698bba5340b95374e6dcdc8b`) — so the update path no longer rewrites it either.
`python3 scripts/workflow.py validate` in the updated workspace passes.

### 12 — the hook narrowing is inert for this commit

Confirmed by running this slice's path set through the new alternation: `installer/build.py`,
`installer/main.py`, `installer/wrapper.sh` and `bootstrap_agentic_workspace.sh` all still match,
so the hook fires and `build.py --check` runs on the S2 commit exactly as before. (A hypothetical
deletions-only commit would no longer fire — harmless, since with no installer or artifact change
there is no drift to detect.)

## Deviations from `plan.md`

**One, and it is a gate-wording conflict rather than a scope change.**

The plan's last validation bullet asks for `grep -rni 'codex\|\.agents\|AGENTS'` over the four
files with **no hits**. That is unsatisfiable alongside the plan's own body, which mandates
keeping some of those very strings. Seven hits survive, all required:

- `installer/build.py:59` `CLAUDE_HDR` and `installer/main.py:460` the `write_text("CLAUDE.md", …)`
  literal — both contain `` `AGENTS.md` `` inside the header string. Plan §1 says explicitly
  "**Keep the `CLAUDE_HDR` check**; `P15.S3` changes that literal, not this slice", and `phase.md`
  *What must stay atomic* item 2 assigns both to `S3` as one atomic pair. Removing either here
  would break the `S3` coupling and fail the build.
- `installer/main.py:579-582` the four new `OBSOLETE_MACHINERY` entries and their
  `# Codex support dropped in v31` comments, plus the `.agents, .codex` mention in the
  `flag_obsolete_machinery()` comment at L588 — these *are* the migration deliverable the plan
  mandates in §2.

Interpreted gate: **no Codex hits beyond (a) the `S3`-owned header literal and (b) the deliberate
`OBSOLETE_MACHINERY` migration entries.** Verified clean under that reading. After `S3` changes the
header literal, the only surviving hits in these files will be the `OBSOLETE_MACHINERY` block.

Nothing else deviated. `tests/`, `CLAUDE.md`, `.claude/**`, `README*`, `docs/**`,
`installer/README.md`, `installer/payloads/**`, `WORKSPACE_VERSION` (left at 30) and `CHANGELOG.md`
were not touched. `tests/retrofit_smoke.sh` is expected red and was **not** run as a gate, per plan.

## Doc impact

Two lines appended to the running "Doc impact" list in `phase.md` (`architecture` and
`operations`). No `doc-new-version` was run — `P15.REVIEW` consolidates.

## Notes recorded in `phase.md`

Under a new *From `P15.S2`* heading: the precise fresh-install guard narrowing (with the surprise
that the emptiness guard still catches the plain case), the "repo's own `AGENTS.md` is now
untouched" behaviour plus the `S4` test recommendation, the settled `AGENTS.workspace.md` decision,
the final `OBSOLETE_MACHINERY` list and the `.exists()` fix, an exact `S3` scope correction
(11 `.claude/**` files, not 10), and — under *Open Questions* — the `build.py`-only-`compile()`s
hazard flagged as a candidate deferred job.
