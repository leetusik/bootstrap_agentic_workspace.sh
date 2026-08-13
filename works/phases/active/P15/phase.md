# Phase P15: Drop Codex support

_Intent: see [intent.md](intent.md)._

## Objective

Remove all Codex-specific machinery, contract text, installer payload, tests, and documentation so the workspace ships Claude Code only, and give existing adopters a flagged upgrade path.

## Context

Upstream bootstrap repo. Everything Claude-facing stays; everything Codex-facing goes. The
removal is spread over six ordered slices because the build guard (`installer/build.py --check`,
enforced by `.githooks/pre-commit`) refuses any commit where the live tree and the committed
`bootstrap_agentic_workspace.sh` disagree — so the cut is shaped by "what must land in one
commit", not by "what is topically similar".

Verified against the tree at commit `c307eb9`. The survey in `intent.md` was re-checked file by
file during `P15.DECOMP`; corrections and additions are in *Findings & Notes* below.

## Decomposition

Six middle slices, strictly ordered. Every one is `--risk high` (`slice-executor-high`): each
writes real code or spans several files; nothing here is a one-line edit.

| Slice | Name | Why it is its own slice |
| --- | --- | --- |
| `P15.S1` | Strip Codex from the workflow engine and `executors.toml` | Pure engine change. The Codex files still exist on disk, so the build stays green; doing this first means later slices delete files nothing references. |
| `P15.S2` | Strip Codex from the installer and delete the Codex trees | **Atomic by necessity** — see *Constraints*. `installer/build.py` + `installer/main.py` + `installer/wrapper.sh` + `.githooks/pre-commit` + `rm -rf .agents/ .codex/` + `rm AGENTS.md` in one commit. |
| `P15.S3` | Strip Codex from the contract and Claude skill prose | `CLAUDE.md` plus the 10 `.claude/**` files that mention Codex or `AGENTS.md`. **Also owns two `installer/` constants** — see *Constraints* (the `CLAUDE_HDR` coupling). |
| `P15.S4` | Rewrite the retrofit smoke test Codex-free | `tests/retrofit_smoke.sh`. Must come after `S3`, because Test 0 asserts contract strings (`"Codex branch:"`, `"DesignSync"`, …) that `S3` deletes. Keeps the version pin at `30`. |
| `P15.S5` | Strip Codex from READMEs, guides, and shipped doc bodies | `README.md`, `README.en.md`, `docs/retrofit-guide.md`, `installer/README.md`, `installer/payloads/doc_bodies/{architecture,operations}.md`. Nothing else depends on it, so it sits late. |
| `P15.S6` | Ship the removal as workspace v31 with a CHANGELOG entry | Release metadata last, so the CHANGELOG describes the finished phase. Bumps `WORKSPACE_VERSION`, appends `## v31` with **Migration notes**, and moves the smoke test's version pin `30` → `31` in the same commit. |

Ordering rationale, in one line: **engine → installer+deletion → contract → tests → prose →
release**, so that every commit builds, validates, and (from `S4` onward) keeps the smoke test
green.

### What must stay atomic, and why

1. **`S2` — installer edits and the tree deletion are one commit.** `installer/build.py`
   currently (a) lists `.codex/config.toml` and both `.codex/agents/slice-executor-*.toml` in
   `FIXED_LIVE_FILES`, (b) globs `.agents/skills/*/SKILL.md` and `.agents/skills/*/agents/openai.yaml`
   as live payload, (c) hard-asserts `len(claude_skills) == len(codex_skills) == EXPECTED_SKILL_COUNT`
   and `claude_skills == codex_skills`, and (d) `collect_contract_body()` reads `AGENTS.md` and
   asserts its body is byte-equal to `CLAUDE.md`'s. Deleting any of those trees without fixing
   `build.py` in the same commit makes the build `die()` and the pre-commit hook reject the commit.
   `installer/main.py` re-derives `CODEX_SKILLS` from the generated `PAYLOADS` dict and raises at
   import time on the same parity guard, so it moves with `build.py`.
2. **`S3` — the `CLAUDE.md` header line and its two pinned copies are one commit.** *(New — the
   survey missed this.)* `CLAUDE.md` line 3 is `> Equivalent to \`AGENTS.md\`. If you change
   workflow rules, update both.` That exact string is pinned in two places:
   - `installer/build.py` `CLAUDE_HDR` (~L62), checked by `collect_contract_body()` with
     `die("CLAUDE.md header changed — update CLAUDE_HDR in build.py")`;
   - `installer/main.py` (~L477) `write_text("CLAUDE.md", f"# CLAUDE.md\n\n> Equivalent to ...")`.

   So `S3` must edit `CLAUDE.md`'s header line **and** `CLAUDE_HDR` **and** the `main.py` write
   literal together. After the change, `CLAUDE_HDR` becomes `"# CLAUDE.md\n\n"` and the extracted
   body still starts at `# Agent Contract`. (`AGENTS_HDR` and the byte-equality assertion are
   already gone by then — `S2` removed them.)
3. **`S6` — the version bump and the smoke test's pin are one commit.** `tests/retrofit_smoke.sh`
   (~L232) asserts `main_version == top_changelog == marker_version == 30`. Bumping
   `WORKSPACE_VERSION` without moving that literal turns the smoke test red; moving the literal
   first turns it red the other way. Ordering the release last and doing both together means the
   smoke test is green at the end of every slice from `S4` on.

### Deliberately not sliced

Per `intent.md`, the historical record is preserved: `works/phases/active/P13` and `P14`,
`docs/versions/**`, `works/events.jsonl`, and existing `CHANGELOG.md` sections are untouched.
`works/backlog.md` and `works/index.json` mention Codex only because P13/P14 are named after it —
they are generated files and regenerate as-is. `docs/current/*.md` is generated; new durable truth
lands as **new** doc versions at `P15.REVIEW` (see *Doc impact*).

## Findings & Notes

### Survey verification (against the tree at `c307eb9`)

The survey in `intent.md` is accurate. Confirmed exactly:

- `.agents/` = **34 files** (17 skills x `SKILL.md` + `agents/openai.yaml`); `.codex/` = **3 files**
  (`config.toml`, `agents/slice-executor-{mid,high}.toml`). `.claude/skills/` = 17, same names.
- `installer/build.py`: `EXPECTED_SKILL_COUNT = 17` (L41). `FIXED_LIVE_FILES` Codex entries are
  exactly three: `".codex/config.toml"` (L46), `".codex/agents/slice-executor-mid.toml"` (L50),
  `".codex/agents/slice-executor-high.toml"` (L51). `AGENTS_HDR` at L63. `.agents/` payload globs
  at L86-89. Parity block L90-117. `collect_contract_body()` L121-130.
- `installer/main.py`: `WORKSPACE_VERSION = 30` (L38); `CODEX_SKILLS` + `EXPECTED_SKILL_COUNT = 17`
  + guards L55-71; `MANAGED_DIRS` L80-81; `MANAGED_FILES` L85, L94; the `CODEX_SKILLS` loop
  L100-105; `_merge_contract` L231-255 and `_retrofit_handle` L266; `_is_machinery()` L286-289;
  update dispatch L351; contract writes L477-478; Codex payload writes L555-563 and L572;
  `OBSOLETE_MACHINERY` L597-606; `flag_obsolete_machinery()` L609-612; `flag_stale_skills()`
  L615-640; final banner L709-724.
- `scripts/workflow.py`: `CODEX_AGENTS` L41; `codex_model`/`codex_effort` in all four
  `EXECUTOR_PRESETS` tier dicts L53-58 (flat dicts of four keys each — edit each dict, do not
  delete a branch); `read_executors_toml()` L116-166 (the `(claude|codex)` alternations are at
  L144 and L148, error strings at L137, L157, L165); `executor_config()` L169-181 (the `codex_`
  prefixing at L175, the empty-model check at L178); `_patched_agent_toml()` L197-210 (exists only
  for `.codex/agents/*.toml`); `executor_agent_files()` L213-220 (4 entries → 2, drop L219);
  `sync_agents()` print at L244; `validate` warnings L748-760 (they are generic over
  `executor_agent_files()`, so they need no Codex-specific edit once L219 is gone — only the
  `_patched_agent_toml` branch at L756 does); the `parallel-start` next-step hint at L1133.
- `.githooks/pre-commit` L8 alternation, verbatim:
  `^(installer/|scripts/workflow\.py$|CLAUDE\.md$|AGENTS\.md$|executors\.toml$|\.claude/|\.agents/|\.codex/|\.github/|\.gitattributes$|works/templates/|bootstrap_agentic_workspace\.sh$)`
  → drop `AGENTS\.md$|`, `\.agents/|`, `\.codex/|`.
- `executors.toml`: preset docs L10-21, commented `[codex.*]` block L43-49.
- `installer/wrapper.sh`: usage heredoc L21 ("Claude Code and OpenAI Codex"), L23-24 (AGENTS.md /
  CLAUDE.md equivalence), L26 (`.agents/skills/`). There are no per-tool installer flags, so there
  is nothing to gate — only text to remove.
- `.gitattributes`, `.github/workflows/workspace-ci.yml`, `.claude/settings.json`, and
  `works/templates/*` contain **no** Codex or `AGENTS.md` references. Nothing to do there.

### New findings the survey did not have

1. **`CLAUDE_HDR` / `main.py` contract-write coupling** — see *What must stay atomic* item 2.
   This is the one place where a "prose-only" edit breaks the build.
2. **The release needs a version bump, and the smoke test pins it.**
   `tests/retrofit_smoke.sh` L222-234 asserts
   `main_version == top_changelog == marker_version == 30`. `installer/main.py` documents
   `WORKSPACE_VERSION` as "bumped (with a matching `CHANGELOG.md` entry) whenever a machinery
   change ships to targets" — and the whole `OBSOLETE_MACHINERY` flagging story only reaches
   adopters through an update, so **v31 + a `## v31` CHANGELOG section with Migration notes is
   required**, not optional. This is an *append* to `CHANGELOG.md`, which is consistent with
   `intent.md`'s "append-only history stays as it is". Hence `P15.S6`.
   Optional simplification for `S4`/`S6` to consider: the three-way equality already catches a
   partial bump, so the trailing `== 30` literal could be dropped instead of maintained. Either
   choice is fine; just do not leave the two disagreeing.
3. **`flag_obsolete_machinery()` really does only check `is_file()`** (`installer/main.py` L611,
   confirmed). Adding `.agents` and `.codex` as **directory** entries to `OBSOLETE_MACHINERY`
   silently no-ops unless that becomes `.exists()` (or `is_file() or is_dir()`). `AGENTS.md` is a
   file and works either way.
4. **Two existing `OBSOLETE_MACHINERY` entries become redundant**: `.codex/agents/slice-executor.toml`
   (L599) and `.codex/agents/slice-executor-low.toml` (L605) are subsumed by a `.codex` directory
   entry and would double-report. `S2` should collapse them.
5. **`AGENTS.workspace.md` is a stranded artifact for retrofitted adopters.** `_merge_contract()`
   writes `CLAUDE.workspace.md` *and* `AGENTS.workspace.md`, and the update path refreshes whichever
   sidecar exists. Once the installer stops handling `AGENTS.md`, an already-retrofitted repo keeps
   a stale `AGENTS.workspace.md` that is never refreshed and never flagged. `S2` should decide:
   add `AGENTS.workspace.md` to `OBSOLETE_MACHINERY` too, or accept the strand and say so. Also
   note the pointer block at L241 names `` `.claude/`/`.agents/` `` and must lose `.agents/`.
6. **`flag_stale_skills()` is per-tool by design** (`disable-model-invocation: true` for Claude,
   `agents/openai.yaml` for Codex). Dropping the `.agents/skills` half is straightforward; keep the
   Claude marker logic exactly as is. With `.agents` flagged wholesale via `OBSOLETE_MACHINERY`,
   nothing is lost.
7. **CI runs the smoke test on every push** (`.github/workflows/workspace-ci.yml` step
   "retrofit smoke (upstream only)"). The pre-commit hook does **not**. So a red smoke test blocks
   nothing locally but does turn CI red on push — which is exactly why `S4` and `S6` are ordered to
   leave it green.
8. **`tests/retrofit_smoke.sh` Test 1 creates its own `AGENTS.md`** in the sample repo (L116) and
   pins the modified-file list to `.claude/settings.json,.gitattributes,AGENTS.md,CLAUDE.md,`
   (L135). After removal, the installer no longer touches it, so the list becomes
   `.claude/settings.json,.gitattributes,CLAUDE.md,`. Keeping the sample `AGENTS.md` and asserting
   it is left **byte-identical** is a better regression than deleting it: `AGENTS.md` is a
   cross-tool convention other tools still use, and this workspace must not clobber a repo's own.
   `S4`'s call, but recommended.
9. **Smoke-test blocks that carry Codex expectations** (verified line ranges): Test 0 L38-106
   (rewrite wholesale — the `AGENTS.md`/`CLAUDE.md` body-equality assertion at L91-93 and the
   `"Codex branch:"` requirement at L95 both go); L135; L165-177; L236-255 (incl. the fresh-install
   inventory, the Codex tier-model greps, and the `.codex/agents/slice-executor-low.toml` retirement
   checks); L261-283 (economy/flex mode matrices — drop the `gpt-5.6-*` greps, keep the
   `[claude.low]`-rejected and unknown/duplicate/misplaced-mode checks); L288-303 (the `--update`
   staleness block, which is entirely Codex-skill-based and needs replacing with a Claude-skill
   equivalent); L330-336; L346 (`find .claude/skills .agents/skills`); L351-357 (the byte-for-byte
   drift manifest — drop the three `.codex` paths and `AGENTS.md`); L380.
10. **`docs/retrofit-guide.md`, `installer/README.md`, `README*.md`, and `tests/` are NOT embedded**
    in the artifact (only `installer/payloads/doc_bodies/*.md` and the `FIXED_LIVE_FILES` /
    skill-glob set are). Confirmed against `build.py`. So `S4` needs no rebuild; `S5` does, because
    of the two doc bodies.

### Doc impact

_(One line per durable-truth change; `P15.REVIEW` consolidates these into new doc versions —
never patch `docs/current/*.md` or an existing version.)_

- `architecture` — the tool-entry-point and contract lines change: `.agents/` and `.codex/` are
  gone, and `CLAUDE.md` is the single routing contract (no `AGENTS.md` twin).
  (`docs/current/architecture.md` L23, L35; latest version `v0003`.)
- `operations` — the whole dual-harness operating story goes: the 17+17 skill inventory, Codex's
  automatic-only `do-next-slice`/`do-whole-phase`, the `.codex/agents/slice-executor-*.toml`
  dispatch, the Codex `workspace-write` network caveat for `/explain`, and the Codex halves of the
  executor preset matrices. (`docs/current/operations.md`, 44 Codex mentions; latest `v0025`.)
- `decisions` — record the new accepted decision "drop Codex support; ship Claude Code only" with
  its rationale (dual-harness parity tax) and its migration mechanism (`OBSOLETE_MACHINERY`
  flagging, workspace v31). **Append a new decision; do not rewrite the 33 historical entries** —
  P13/P14 remain accepted history that this decision supersedes. (latest `v0033`.)
- No other `docs/current/*.md` mentions Codex (`product`, `experience`, `frontend`, `backend`,
  `data`, `api`, `security`, `qa` are all clean).

## Constraints

- **Every slice must end with all three of these passing**, because the orchestrator commits at
  each slice boundary and `.githooks/pre-commit` runs the build check:
  - `python3 installer/build.py`
  - `python3 installer/build.py --check`
  - `python3 scripts/workflow.py validate`
- **Any slice touching an embedded machinery file must run `python3 installer/build.py` and leave
  the regenerated `bootstrap_agentic_workspace.sh` for the orchestrator to stage in the same
  commit.** Embedded = `scripts/workflow.py`, `.claude/**` (skills, agents, `settings.json`),
  `CLAUDE.md`, `executors.toml`, `works/templates/**`, `.github/workflows/workspace-ci.yml`,
  `.gitattributes`, `installer/{main,wrapper}.py|sh`, and `installer/payloads/doc_bodies/*.md`.
  **Not embedded**: `README*.md`, `docs/retrofit-guide.md`, `installer/README.md`, `tests/**`,
  `CHANGELOG.md`, `.githooks/**`. So `S1`, `S2`, `S3`, `S5`, `S6` rebuild; `S4` does not.
- From `S4` onward, `bash tests/retrofit_smoke.sh` should also pass; treat it as `S4`'s and `S6`'s
  closing gate. (It is slow — it builds and installs into several temp dirs.)
- Never patch `docs/versions/**` or hand-edit `docs/current/*.md`; durable truth is versioned once,
  at `P15.REVIEW`.
- Leave `works/phases/active/P13`, `P14`, `works/events.jsonl`, and the existing `CHANGELOG.md`
  sections alone.

## Open Questions

- **`AGENTS.workspace.md` for already-retrofitted adopters** (finding 5): flag it as obsolete too,
  or accept the strand? `S2` should decide and record the choice here. Not a blocker — either
  answer is defensible; it just must be deliberate.
- **Whether to keep the literal `== 30`/`== 31` release pin in the smoke test** (finding 2). `S4`
  and `S6` between them must not leave the pin and `WORKSPACE_VERSION` disagreeing.
- Nothing else was left unresolved read-only.
