# Plan — P4.S2 (Model-flexible attribution sweep)

Orchestrator's native plan. Slice kind: `implementation`, risk `low`. Executor: `slice-executor-high`. Read `phase.md` first — especially the S1 cross-slice note ("How to change what the installer emits"): edit **live files**, then `python3 installer/build.py`, drift check green. No heredoc mirroring exists anymore.

## Goal

Nothing in the workspace pins a specific model (intent Job 1). Executor defs inherit the session's model; attribution and prose describe a rule ("attribute to the model that actually did the work"), with model names only as examples. The Codex tomls keep their explicit `model = "gpt-5.5"` — intent scopes them out (Codex needs an explicit model).

## Changes (all in live files; exact wording is yours — keep it terse and rule-first)

1. **Executor model pins** — `.claude/agents/slice-executor.md:5` and `.claude/agents/slice-executor-high.md:5`: `model: opus` → `model: inherit` (Claude Code supports `inherit` = run the session's model). Do not touch `effort:` lines (`tests/retrofit_smoke.sh` block 5 greps them).
2. **Commit Convention** — `CLAUDE.md` line ~96 and `AGENTS.md` identically (build asserts the contract bodies stay byte-equal): the rule becomes "attribute each commit to the model that actually did the work"; keep "Claude Code adds its own trailer automatically"; the Codex `GPT-5.5` trailer becomes an **example** of the rule (e.g. "in Codex, add a `Co-Authored-By` trailer naming the model that ran — e.g. `Co-Authored-By: GPT-5.5 <noreply@openai.com>`"), and "never carry over another tool's trailer" generalizes to "never attribute a commit to a model that didn't do the work".
3. **explain skill trailer text** — `.claude/skills/explain/SKILL.md` ~116-117 and `.agents/skills/explain/SKILL.md` ~114-115: same example-not-rule treatment.
4. **Prose model mentions → model-neutral**:
   - `CLAUDE.md`/`AGENTS.md` lines ~16, ~19, ~61: "(on `gpt-5.5`)" / "on `opus`" → e.g. "running the session's model (`model: inherit`)" for Claude and "on its configured model (`.codex/agents/*.toml`)" for Codex.
   - `README.md` ~170, ~246, ~289: same treatment (289 is the tree-diagram comment).
   - `.codex/config.toml` comment lines 8-9: still accurate (the toml genuinely pins `gpt-5.5`) — reword only if it reads as a workspace-wide claim; otherwise leave.
5. **Rebuild** — `python3 installer/build.py`; the rebuilt `bootstrap_agentic_workspace.sh` picks up every edit above (contract, agent defs, explain skill). CHANGELOG/version work is S3's — don't touch.
6. **Doc impact** — update the anticipated S2 line in `phase.md` to confirmed: `decisions` — v0013 "`opus` alias auto-tracks the top model" superseded (Fable/Mythos tier now sits above Opus); executor defs are `model: inherit`; attribution is rule-based, models named only as examples.

## Validation

1. `python3 installer/build.py --check` → green (after rebuild).
2. `bash tests/retrofit_smoke.sh` → all 7 blocks green.
3. Grep sweep over live machinery (`.claude/`, `.agents/`, `.codex/`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `scripts/`, `installer/`, `tests/`): no `model: opus` remains; every `GPT-5.5`/`gpt-5.5` occurrence is either the Codex toml pin, the `.codex/config.toml` comment describing it, or an explicit example inside rule text; no "on `opus`" prose remains. (`works/` and `docs/` are history/generated — out of scope.)
4. `python3 scripts/workflow.py validate`.

## Wrap-up

`result.md` with validation outcomes + final wording chosen; `phase.md` gets the confirmed Doc-impact line (step 6) and any cross-slice note S3 needs. Never commit; never transition state.
