# Result — P4.S2 (Model-flexible attribution sweep)

Status: done. All edits landed in live files; distributable rebuilt from source.

## Changes made (live files)

1. **Executor model pins** — `.claude/agents/slice-executor.md:5` and
   `.claude/agents/slice-executor-high.md:5`: `model: opus` → `model: inherit`.
   `effort:` lines untouched.
2. **Commit Convention** — `CLAUDE.md:96` and `AGENTS.md:96` (identical, byte-equal
   contract body): rule is now "**Attribute each commit to the model that actually
   did the work.**" Kept "Claude Code adds its own `Co-Authored-By: Claude …`
   trailer automatically (naming whichever model ran the session)"; the Codex
   `GPT-5.5` trailer is now an example ("in another tool, add a `Co-Authored-By`
   trailer naming the model that ran — e.g. in Codex, `…GPT-5.5…`"); the
   carry-over prohibition generalized to "Never attribute a commit to a model that
   didn't do the work (e.g. don't carry over another tool's trailer)".
3. **explain skill trailer** — `.claude/skills/explain/SKILL.md` and
   `.agents/skills/explain/SKILL.md` (both mirrors, identical): trailer text now
   reads "your own tool's standard Co-Authored-By trailer — naming the model that
   actually did the work — … (e.g. in Codex, `…GPT-5.5…`)".
4. **Prose model-neutral** — `CLAUDE.md`/`AGENTS.md` lines ~16/19/61: Claude side →
   "running the session's model via `model: inherit`" / "`model: inherit`"; Codex
   side → "on its configured model" (+ `.codex/agents/*.toml` at line 16).
   `README.md` ~170/246/289: same treatment; tree comment at 289 → "(Codex, its
   configured model)".
5. **`.codex/config.toml`** lines 8-9: left as-is — the comment accurately
   describes the Codex-specific tomls (which genuinely pin `gpt-5.5`), not a
   workspace-wide claim.
6. **Rebuild** — `python3 installer/build.py` → wrote
   `bootstrap_agentic_workspace.sh` (209306 bytes) from `installer/` source; every
   edit above is picked up (agent defs, contract, explain skill).

CHANGELOG/version work deliberately untouched (S3's job).

## Validation

- `python3 installer/build.py` → wrote artifact (209306 bytes). PASS
- `python3 installer/build.py --check` → "OK: … in sync with installer/ source". PASS
- `bash tests/retrofit_smoke.sh` → ALL RETROFIT SMOKE TESTS PASSED (all 7 blocks
  green; includes executor effort split base xhigh / -high high, dual-apply of
  both agent defs + CLAUDE.md/AGENTS.md, and Test 7 drift check). PASS
- Grep sweep over `.claude/ .agents/ .codex/ CLAUDE.md AGENTS.md README.md scripts/
  installer/ tests/`: no `model: opus` remains; no "on `opus`" prose remains; every
  `gpt-5.5`/`GPT-5.5` occurrence is one of — the Codex toml pin
  (`.codex/agents/*.toml:3`), the `.codex/config.toml` comment describing those
  tomls, or an explicit example inside rule text (Commit Convention + explain
  skill, both mirrors). PASS
- `python3 scripts/workflow.py validate` → "Workflow validation passed." PASS

## Deviations from Plan

None. `.codex/config.toml:8-9` left unchanged per plan step 4 (accurate
description of the Codex-specific tomls, not a workspace-wide claim).

## Doc Impact

Updated the S2 "anticipated" line in `phase.md` to confirmed: `decisions` doc —
v0013 "`opus` alias auto-tracks the top model" is superseded (a Fable/Mythos tier
now sits above Opus); executor defs are `model: inherit`; commit attribution is
rule-based ("attribute to the model that actually did the work"), with model names
appearing only as examples. To be consolidated into a new `decisions` version at
P4.REVIEW.

## Files Changed

- `.claude/agents/slice-executor.md`
- `.claude/agents/slice-executor-high.md`
- `CLAUDE.md`
- `AGENTS.md`
- `.claude/skills/explain/SKILL.md`
- `.agents/skills/explain/SKILL.md`
- `README.md`
- `bootstrap_agentic_workspace.sh` (rebuilt from source)
