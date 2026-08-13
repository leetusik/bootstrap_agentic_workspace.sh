# Plan — P15.DECOMP (decompose phase)

## Goal

Cut `P15` into middle slices and seed `phase.md`. Create **bare slice folders only** via
`new-slice` — never pre-fill another slice's `plan.md` — and record the breakdown, findings,
and cross-slice notes in `phase.md`.

This is **not** a product-visual-design phase, so it decomposes in a **single pass**. Do not
create a `co-work` slice and do not create a `P15.DECOMP2`.

## Read first

- `works/phases/active/P15/intent.md` — the confirmed intent, the three resolved
  clarifications, and a **survey of the Codex surface area** captured at phase creation
  (commit `c307eb9`). The survey is context, not a breakdown, and its line numbers are
  approximate. **Re-verify every claim against the current tree before you rely on it.**
- `CLAUDE.md` — the workspace contract, especially the upstream-repo rebuild rule.
- `docs/current/architecture.md` and `docs/current/operations.md` for how the installer and
  the executor tiers are documented today.

## The hard constraint that shapes the cut

The orchestrator commits at every slice boundary, and the tracked `.githooks/pre-commit` hook
runs `python3 installer/build.py --check` whenever `installer/`, `scripts/workflow.py`,
`CLAUDE.md`, `AGENTS.md`, `executors.toml`, `.claude/`, `.agents/`, `.codex/`, `.github/`,
`.gitattributes`, `works/templates/`, or the artifact is staged.

So: **every slice must leave the tree in a state where `python3 installer/build.py` succeeds,
`python3 installer/build.py --check` passes, and `python3 scripts/workflow.py validate`
passes.** That is the real boundary constraint, and it forces some changes to be atomic:

- `installer/build.py` currently reads `.agents/skills/*/SKILL.md`, `.agents/skills/*/agents/openai.yaml`,
  `.codex/config.toml`, and `.codex/agents/*.toml` as live payload, hard-asserts a 17↔17
  Claude/Codex skill inventory, and asserts `CLAUDE.md` and `AGENTS.md` have byte-equal bodies.
  **Deleting `.agents/`, `.codex/`, or `AGENTS.md` in a slice that does not also fix
  `build.py` will break the build and block the commit.** Those must land together.
- `installer/main.py` writes those same payloads; its `PAYLOADS` dict is generated from
  `build.py`, so the two move together.
- Any slice touching an embedded machinery file must finish by running
  `python3 installer/build.py` and staging the regenerated `bootstrap_agentic_workspace.sh`
  in the same commit. Embedded files include `scripts/workflow.py`, `.claude/**`, `CLAUDE.md`,
  `works/templates/**`, and `installer/payloads/doc_bodies/*.md` — but **not** `README*.md`,
  `docs/retrofit-guide.md`, `installer/README.md`, or `tests/`.

Verify the current `FIXED_LIVE_FILES` list and the pre-commit path list yourself rather than
trusting this summary.

## Suggested shape (a starting point — improve it if the tree disagrees)

Roughly five middle slices, ordered so each commit is self-consistent:

1. **Engine.** `scripts/workflow.py` + `executors.toml`: drop `CODEX_AGENTS`, the
   `codex_model` / `codex_effort` keys from all four `EXECUTOR_PRESETS` tier dicts (each
   preset entry is one flat dict carrying four keys, so this is an edit to each dict, not a
   branch deletion), the `(claude|codex)` alternations and error strings in
   `read_executors_toml()`, the `codex_` field prefixing in `executor_config()`,
   `_patched_agent_toml()`, the Codex entries in `executor_agent_files()` (4 → 2), the
   `sync_agents()` printing, the `validate` warnings, and the Codex next-step hint; plus the
   `[codex.*]` block and preset docs in `executors.toml`. The Codex files still exist on
   disk at this point, so the build still succeeds.
2. **Installer + tree deletion (atomic).** `installer/build.py`, `installer/main.py`,
   `installer/wrapper.sh`, `.githooks/pre-commit`, and the deletion of `.agents/`, `.codex/`,
   and `AGENTS.md`. Includes adding `.agents`, `.codex`, and `AGENTS.md` to
   `OBSOLETE_MACHINERY` — **and note the gotcha**: `flag_obsolete_machinery()` currently
   checks only `is_file()`, so directory entries will silently never fire unless that check
   is extended. Also reworks `flag_stale_skills()`, whose "is it ours" marker is per-tool.
3. **Contract + Claude skills prose.** `CLAUDE.md` (the Codex routing bullet, the
   orchestrator/executor paragraph, the tier table, the "Narrow Codex design exception", the
   whole "**Codex branch:**" half of the design rule, the `<noreply@openai.com>` attribution
   sentence, and the `AGENTS.md` equivalence header) plus the Codex and `AGENTS.md` mentions
   inside `.claude/skills/*/SKILL.md` and `.claude/agents/slice-executor-{mid,high}.md`.
   Note that `CLAUDE.md`'s own opening line declares `AGENTS.md` its equivalent — that goes.
4. **Tests.** `tests/retrofit_smoke.sh` — Test 0 is roughly 90% Codex assertions and needs
   rewriting rather than trimming; the retrofit, fresh-install, mode-matrix, `--update`, and
   drift-manifest blocks all carry Codex expectations too.
5. **Docs and READMEs.** `README.md` (Korean), `README.en.md`, `docs/retrofit-guide.md`,
   `installer/README.md`, and `installer/payloads/doc_bodies/{architecture,operations}.md`.

Merge, split, or reorder these if verification shows a better cut — this is a suggestion, not
a mandate. What is **not** negotiable is that each slice ends buildable and validating.

## Risk ratings (this is the phase's main cost lever)

Every slice above writes real code or spans more than one file, so rate them **`--risk high`**.
Reserve `low` for a genuinely one-line or few-line edit; nothing in this survey qualifies.

## Out of scope — do not create slices for these

The historical record is preserved, per the operator's confirmed intent:

- `works/phases/active/P13` and `P14` (the Codex phases) stay untouched.
- `docs/versions/**` is never patched — hard rule. New durable truth is recorded as **new**
  doc versions at `P15.REVIEW`, and `docs/current/*.md` regenerates from those.
- `works/events.jsonl` and `CHANGELOG.md` are append-only history and stay as they are.

## What to write into `phase.md`

- **Decomposition:** the slice list with IDs, names, one-line rationale each, the ordering
  constraint above, and which changes must stay atomic and why.
- **Findings & Notes:** what your verification of the survey confirmed, corrected, or newly
  found — especially anything the survey got wrong, any additional coupling site, and the
  `flag_obsolete_machinery()` `is_file()` gotcha if it still holds. Also record the exact
  current `EXPECTED_SKILL_COUNT`, the `FIXED_LIVE_FILES` Codex entries, and the pre-commit
  path alternation, so later slices do not have to re-derive them.
- **Constraints:** the build/validate-per-slice rule and the artifact-regeneration rule.
- **Open Questions:** anything you could not resolve read-only.

## Boundaries

- Create slices with `python3 scripts/workflow.py new-slice --phase P15 --slice P15.S<n>
  --name "..." --kind implementation --risk high` (add `--order` only if you need a
  non-default position). Bare folders — **write no `plan.md` for any of them**.
- Do not implement anything. Do not delete a single Codex file in this slice.
- Do not commit and do not transition slice or phase status — the orchestrator does both.
- Do not run `doc-new-version`; if you find durable truth that will change, append a one-line
  "Doc impact" note to `phase.md` for `P15.REVIEW` to consolidate.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `python3 installer/build.py --check` still passes (you changed no machinery).
- Every created slice has a `slice.json` and **no** `plan.md`.
