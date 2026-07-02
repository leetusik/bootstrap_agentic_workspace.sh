# Plan — P4.DECOMP (decompose phase P4)

Orchestrator's native plan. Slice kind: `decomposition`. Executor: `slice-executor` (xhigh).

## Goal

Create P4's middle slices with `new-slice` (bare folders only — never pre-fill their `plan.md`), and seed `phase.md` with the decomposition rationale and the durable research findings below so later slices build on them. The phase intent is confirmed in `../../intent.md` — three jobs: (1) model-flexible attribution, (2) installer split into `installer/`, (3) CHANGELOG + integer workspace versioning. Approved sequencing: **split first**, so jobs 1 and 3 land in modular files.

## Proposed breakdown (operator-approved guidance — finalize it, and record in phase.md any deviation and why)

1. `P4.S1` — "Split installer into installer/ with build + drift check" — `--kind implementation --risk high --order 2`
   Dissolve the 3,025-line self-contained `bootstrap_agentic_workspace.sh` into an `installer/` source tree + build step that emits the identical-behavior single-file distributable at repo root (committed). Source of truth = live repo files (`.claude/skills/*`, `.agents/skills/*`, `scripts/workflow.py`, `.claude/agents/*.md`, `.codex/agents/*.toml`, `works/templates/*`, `.claude/settings.json`, contract text) + `installer/`-local payloads for fresh-install-only seeds (the 11 `DOC_BODIES`, P1-seed text). Build must be deterministic (byte-stable across runs). Drift check fails when the committed artifact ≠ rebuilt-from-source. All three modes (fresh, `--into-existing`, `--update`) functionally unchanged — consumers `curl … | sh` the raw root file.

2. `P4.S2` — "Model-flexible attribution sweep" — `--kind implementation --risk low --order 3 --depends-on P4.S1`
   `model: opus` → `model: inherit` in `.claude/agents/slice-executor{,-high}.md`; de-hardcode `GPT-5.5` from the Commit Convention (`CLAUDE.md:96`/`AGENTS.md:96`) and the explain skill (`.claude/skills/explain/SKILL.md:116-117`, `.agents/skills/explain/SKILL.md:114-115`) — model names become examples, the rule becomes "attribute to the model that actually did the work"; make "on `opus`" / "on `gpt-5.5`" prose model-neutral (`CLAUDE.md`/`AGENTS.md` 16/19/61, `README.md` 170/246/289). Codex toml keeps its explicit `model = "gpt-5.5"` (intent scopes it out; Codex needs an explicit model). Rebuild distributable via S1's build. Doc impact: decisions (v0013 "opus alias auto-tracks top model" rationale superseded by the Fable/Mythos tier above Opus).

3. `P4.S3` — "CHANGELOG + integer workspace versioning in /update-workspace" — `--kind implementation --risk medium --order 4 --depends-on P4.S1`
   Root `CHANGELOG.md` seeded (v1 = this first versioned release; earlier history noted as pre-versioning). `WORKSPACE_VERSION` integer constant in the installer source, stamped as `workspace_version` into `works/.workspace-version.json` by `write_version_marker()` (update this repo's marker too). `/update-workspace` skill (both mirrors): report "you're on vN → upstream vM" + the CHANGELOG entries in between (read from the fresh upstream clone), alongside the existing `--dry-run` change-list; local `workspace_version` absent → treat as pre-versioning.

Keep `P4.REVIEW` last (already exists). Risk tags are deliberate — they select executor effort (`low` → high, else xhigh).

## Durable findings to seed into phase.md (from orchestrator research, verified today)

- **Installer map** (`bootstrap_agentic_workspace.sh`, 3,025 lines): sh wrapper 1–99; python heredoc 100–3025. `COMMAND_SKILLS` 164–646 (15 skills; `do-whole-phase` is `claude_only`); managed-files manifest 648–682; write engine + retrofit/update policies 686–886; mode guards 890–972; `WORKFLOW_DOC` 974–1066 (emitted verbatim → `CLAUDE.md` + `AGENTS.md`); `DOC_BODIES` 1071–1512 (fresh-only); templates 1568–1631; P1 seed 1634–1721 (fresh-only); `WORKFLOW_PY` 1724–2663 (→ `scripts/workflow.py`); builders + emit 2667–2857 (`model: opus` stamped at 2735; Codex toml `gpt-5.5` at 2852/2856); settings + codex config 2860–2903; finalizers 2905–3025 (`write_version_marker` 2909–2918 writes `works/.workspace-version.json`: `upstream_url`, `synced_commit` [env `SYNCED_COMMIT` or "bootstrap"], `synced_at`; nothing programmatic reads it).
- **Payloads are byte-identical to live repo files** (sampled: `.claude/agents/slice-executor.md`, `.claude/skills/do-next-slice/SKILL.md`) — self-hosting repo in sync, so building from live files is safe.
- **Repo-only files the installer never emits**: the installer itself, `README.md`, `LICENSE`, `.gitignore`, `tests/`.
- **Model-pin inventory (live repo)**: pins `.claude/agents/slice-executor.md:5`, `slice-executor-high.md:5` (`opus`), `.codex/agents/slice-executor{,-high}.toml:3` (`gpt-5.5`); trailers `CLAUDE.md:96`, `AGENTS.md:96`, explain SKILL.md both mirrors; prose CLAUDE/AGENTS 16/19/61, README 170/246/289, `.codex/config.toml:8-9`. `tests/retrofit_smoke.sh` greps `effort:` lines, not `model:` — S2's model change won't break it; effort or filename changes would.
- **`tests/retrofit_smoke.sh`** (164 lines, 6 blocks): retrofit non-destructiveness, idempotent re-run, foreign-workflow abort, docs-gating, fresh-install regression, live-vs-fresh drift diff. `--update` mode is currently untested. Uses `mktemp -d` + `trap cleanup EXIT`; requires git + python3.
- **`/update-workspace` mirrors** differ only in 2 frontmatter lines (`.claude` copy has `allowed-tools` + `disable-model-invocation`); body identical. Preview = installer's own `--update --dry-run` change-list; apply passes `SYNCED_COMMIT="$ref"`; never auto-commits.
- No `CHANGELOG.md`, no version constant, no build/packaging script exists anywhere today.

## Execution notes

- Run `new-slice` for each middle slice exactly as specified above (adjust only with recorded rationale).
- Seed `phase.md`: Decomposition section (breakdown + what each slice covers and why, incl. the split-first sequencing rationale), Findings & Notes (the durable findings above), and start the running "Doc impact" list (empty is fine — S2/S3/REVIEW will append).
- Do not pre-fill any middle slice's `plan.md`; do not touch source code on this slice.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `python3 scripts/workflow.py next` shows `P4.S1` as the next slice after this one finishes (selection is by order; DECOMP order < S1).

## Result

Write `result.md` beside this plan: slices created (IDs, kinds, risks, orders), validation output, any deviations.
