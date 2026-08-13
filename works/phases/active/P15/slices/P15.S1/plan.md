# Plan — P15.S1: Strip Codex from the workflow engine and `executors.toml`

## Scope

Two files only: `scripts/workflow.py` and `executors.toml`. Nothing else — the Codex trees,
the installer, the contract, the tests, and the docs all belong to later slices.

The Codex files still exist on disk after this slice. That is deliberate: the engine simply
stops referencing them, so the build stays green and `P15.S2` deletes files nothing points at.

Read `works/phases/active/P15/phase.md` first — the *Findings & Notes* section has the verified
line numbers, and *Constraints* has the build rule. Line numbers were verified at `c307eb9`;
re-check before editing.

## `scripts/workflow.py`

1. **`CODEX_AGENTS`** (~L41) — delete the constant.
2. **`EXECUTOR_PRESETS`** (~L51-60) — remove the `codex_model` and `codex_effort` keys from all
   four tier dicts. Each preset entry is one flat dict of four keys; this is an edit to each
   dict, not a branch deletion. The surviving `flex` values stay `sonnet@xhigh` / `opus@xhigh`
   and `economy` stays `sonnet@high` / `opus@high`. Update the comment above
   `DEFAULT_EXECUTOR_MODE` — its last sentence ("Both harnesses have preset-specific values.")
   and the `[claude.<tier>] / [codex.<tier>]` mention both go.
3. **`read_executors_toml()`** (~L116-166):
   - Keep the `[claude.<tier>]` section syntax. Existing adopters have `executors.toml` files
     using it, and renaming the table would break them for no gain.
   - Drop `codex` from the `(claude|codex)` alternations at ~L144 and ~L148, and from the
     error strings at ~L137, ~L157, ~L165 and the docstring.
   - **Add a dedicated error for a `[codex.*]` section**, mirroring the existing retired-tier
     handling right below it. An adopter upgrading with a `[codex.mid]` block in their file
     would otherwise fall through to the generic `cannot parse` error, which tells them
     nothing. Give them the real reason and the fix — something like:
     `executors.toml line {n}: Codex support was removed in workspace v31 — this workspace
     ships Claude Code only, so drop this section`.
     Match the tier regex loosely (any tier name after `codex.`) so a `[codex.low]` also lands
     on this message rather than the retired-tier one.
   - The `values` dict is keyed `(harness, tier, key)`. With one harness left, simplify it to
     `(tier, key)` and update `executor_config()` accordingly — but only if it stays clearly
     readable; a mechanical `harness == "claude"` leftover is worse than either extreme.
4. **`executor_config()`** (~L169-181) — drop the `field = key if harness == "claude" else
   f"codex_{key}"` prefixing (~L175) and reduce the empty-model check (~L178) to the single
   `model` field with a `[claude.{tier}] model` label.
5. **`_patched_agent_toml()`** (~L197-210) — delete it entirely. It exists only to patch
   `.codex/agents/*.toml`.
6. **`executor_agent_files()`** (~L213-220) — drop the `.codex` entry (~L219), leaving two.
   With only `.md` files left, the `kind` element of the tuple is dead weight: drop it and
   have both call sites use `_patched_agent_md` directly. That also removes the
   `if kind == "md" else _patched_agent_toml(...)` branches in `sync_agents()` and in
   `validate` (~L756). Update the docstring ("the 4 tier agent files" → 2).
7. **`sync_agents()`** (~L244) — the per-tier print currently reads
   `f"{tier:<5} claude={cfg['model']} @ {...}  codex={cfg['codex_model']} @ {...}"`. With one
   harness the `claude=` label is noise; print `f"{tier:<5} {cfg['model']} @ {effort or
   '(no effort line)'}"`. **This changes `sync-agents` output** — record it in `phase.md` so
   `P15.S4` aligns the smoke test's mode-matrix assertions.
8. **`validate`** (~L748-760) — the warning loop is generic over `executor_agent_files()`, so
   it needs no Codex-specific edit beyond unpacking the shortened tuple and dropping the
   `_patched_agent_toml` branch. Leave the advisory-only behaviour (warn, never error) intact.
9. **The `parallel-start` next-step hint** (~L1133) — drop `($do-whole-phase in Codex)`, leaving
   the Claude Code invocation only. Re-read the surrounding print block; the phrasing should
   still read naturally as one sentence.

Then grep the whole file for `codex`, `Codex`, `AGENTS.md`, and `.agents` case-insensitively
and confirm zero hits remain.

## `executors.toml`

- Rewrite the preset documentation (~L10-21): the `mode` bullet loses its Codex rows, so
  `economy` reads `sonnet@high / opus@high` and `flex` reads `sonnet@xhigh / opus@xhigh`, and
  the per-tier bullet names `[claude.<tier>]` only.
- Delete the commented `[codex.*]` block (~L43-49) and the blank line before it.
- Leave `mode = "flex"` as-is, and leave the `[claude.*]` commented examples as-is.
- The header comment mentioning "a named preset for both harnesses" needs its "both harnesses"
  wording fixed too.

## Constraints

- Do **not** touch `.agents/`, `.codex/`, `AGENTS.md`, `CLAUDE.md`, `installer/**`, `tests/**`,
  `README*`, or `docs/**`. Later slices own all of those.
- Both files are embedded in the installer artifact, so **finish by running
  `python3 installer/build.py`** and leave the regenerated `bootstrap_agentic_workspace.sh` in
  the working tree for the orchestrator to commit.
- Do not commit. Do not transition slice or phase status. Do not run `doc-new-version` — append
  a one-line "Doc impact" note to `phase.md` if you change durable truth.
- `tests/retrofit_smoke.sh` is expected to fail after this slice (it still asserts the Codex
  tier models). That is fine and planned — `P15.S4` rewrites it. Do not "fix" it here.

## Validation

- `python3 scripts/workflow.py validate` — passes, and its warning output is unchanged
  (no missing/drifted executor agent files).
- `python3 scripts/workflow.py sync-agents --check` — reports the two Claude agent files in
  sync. Also run bare `sync-agents` and confirm it rewrites nothing and prints the two tiers.
- `python3 scripts/workflow.py next` — still works (smoke-tests the CLI end to end).
- Feed a temporary `executors.toml` containing a `[codex.mid]` section to `sync-agents` and
  confirm the new error message fires; restore the real file afterwards.
- `python3 installer/build.py` then `python3 installer/build.py --check` — both pass.
- `grep -rin 'codex' scripts/workflow.py executors.toml` — no hits.

## Notes for `phase.md`

Record: the `sync-agents` output format change (for `P15.S4`), the decision to keep the
`[claude.<tier>]` table name, the new `[codex.*]` rejection message and its wording, and
whether you simplified the `values` key tuple.
