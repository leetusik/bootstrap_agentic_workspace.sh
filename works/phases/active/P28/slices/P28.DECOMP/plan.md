# Plan — P28.DECOMP (decomposition)

## Context

P28 adds a **nested personal install**. One engineer runs this workspace privately inside a host (company) repo they don't own, and the team sees nothing: no branch, no tracked-file change and no PR diff.

- **Layout:** the engine and its state live in a nested git repo at `<host>/workflow`, hidden by the host's `.git/info/exclude`.
- **Wiring:** skills and agents go into the host's tracked `.claude/` as **untracked** files. Clashing names are prefixed at install.
- **Settings and contract:** permissions go in `settings.local.json`, and the contract pointer in `CLAUDE.local.md`.
- **Commits:** each slice makes two commits — product code to the host in the host's convention (asked once), state to `/workflow`.
- **Review:** `phase-scope` reads the product diff from the host repo.
- **Parallel worktrees:** off.
- **Updates:** `--update` covers nested installs.
- **Acceptance:** the gate waits for a run in the real company repo.

Read `works/phases/active/P28/intent.md` in full: the verbatim request, the confirmed intent, five clarifications, and the notes.

## Machinery footprint (read-only exploration, this session)

**Installer (`installer/main.py`, `wrapper.sh`)**
- One root is used for everything: `ROOT = TARGET.resolve()` (main.py:44). Every write goes through `write_text` (363–375) to `ROOT/path`.
- **Nested mode needs two roots:**
  - **engine root** `<host>/workflow`: `scripts/`, `works/`, `docs/`, templates, the contract, `executors.toml`, `.workspace-version.json`;
  - **host root** `<host>`: `.claude/skills|agents`, `settings.local.json`, `CLAUDE.local.md`, `.git/info/exclude`.
- **Writes that must not happen in nested mode:**
  - `emit_policy_files()` (175–191, called unconditionally at 559) writes `.github/workflows/workspace-ci.yml` and line-merges `.gitattributes`. Skip it, or point it at the nested repo.
  - `_merge_settings_json` (196–216) targets `.claude/settings.json`.
  - `_merge_contract` (219–243) edits `CLAUDE.md` and writes a sidecar.
- **Guards that assume one root:** the fresh-install "empty target" guard (435–453) must check `<host>/workflow`, not the host. The `--update` detection (388–405) is file-based, with no mode marker.
- **No git calls:** the installer runs no git command and changes no git config today. A nested install must `git init` the nested repo (a new, deliberate exception) and append to the host's `info/exclude`.
- **Adding the flag:** `wrapper.sh` parses flags at 50–65, validates at 68–70 and exports env at 78–84. Add `--nested` and `export NESTED` there.
- **The `/update-workspace` skill** runs `sh … . --update` from cwd and `scripts/workflow.py sync-agents`. Both assume cwd is the workspace root.
- **`flag_stale_skills`** (603–621) would report prefixed copies as stale.

**Engine (`scripts/workflow.py`)**
- **Root and paths:**
  - `ROOT` (L16) is already `<host>/workflow` when the engine sits at `workflow/scripts/`.
  - `CLAUDE_AGENTS = ROOT/.claude/agents` (L102) is wrong in nested mode: `sync-agents`, `executor-mode` and the validate drift check (L267–293, L1343–1352) must use the host's `.claude/agents`, plus any renamed agent names.
- **`phase-scope` (L2622–2735):**
  - Today the base is the **nested** commit that added `phase.json` (`_phase_creation_commit` L2549), and the head is the nested review-pass commit (L2608–2619). Neither SHA exists in the host repo.
  - **The engine needs host anchors:** record the host's `HEAD` in `phase.json` at `new-phase`, and again at review pass. Then diff and status the host with `_git(cwd=HOST)` (L2576, L2592), with a pathspec that excludes `workflow/`.
  - The existing `_repo_prefix` and `--relative` support (L1854, L2576) handles a subdirectory of one repo, never a second repo.
- **Parallel commands:** `parallel-start` (L1941), `-gate` (L2093), `-merge-finish` (L2186), `-consolidated` (L2233), `-teardown` (L2045) and `-status` (L2389) must refuse in nested mode. The `next` hint (L2475) must be silenced.
- **Printed paths:** they are ROOT-relative (`slice_path=` L2794, L1498, L1529, …). With cwd = host they need the `workflow/` prefix.
- **Design registry identity** uses `ROOT` and `ROOT.name` (L3457, L3617, L3648), which would come out as "workflow". It should use the host.
- **`rev-parse HEAD` at L450** (doc provenance) should record the host's HEAD.

**Text (contract, skills, agents, settings)**
- **Engine command:** 120 lines say `python3 scripts/workflow.py`. That includes the `allowed-tools` frontmatter of 16 of the 18 skills and the settings allowlist `Bash(python3 scripts/workflow.py:*)`.
- **Other paths:** `works/` appears on 37 lines, `docs/current` on 21 and `docs/versions` on 4.
- **No indirection exists.** `build.py` copies skills and agents verbatim, and the only placeholders are `__PROJECT_NAME__`/`__PROJECT_SUMMARY__`, used in doc bodies only.
- **Commit instructions:** do-next-slice L35, do-whole-phase L46, review-phase L64, parallel-phase L249, and the Commit Convention (CLAUDE.md L63–65). The executors already forbid commits "in any other git root" (L55).
- **Name cross-references:**
  - slash and skill-name references (`/create-phase`, "the `design-cowork` skill", …);
  - `subagent_type: design-drafter` (design-cowork L930);
  - agent filenames built in code (`executor_agent_files` L267–276; MANAGED_FILES main.py L84–87).
- **Renaming hazard:** many skill names are also engine subcommands (`review-phase`, `archive-phase`, `doc-new-version`, …), so a blind rename corrupts the engine command lines. `commit` is the likeliest clash with a host's own skills.

**Tests:** `tests/retrofit_smoke.sh` holds Tests 0–13 with `ok`/`bad`/`newtmp` helpers. A nested test fits as **Test 14** before the summary (L1489), shaped like Test 1, in roughly 50–80 lines.

## Design direction (DECOMP pins this in `## Decisions`; slices may refine it, never reverse it silently)

1. **A nested-mode marker, `workflow/nested.json`**, written by the installer and read by the engine. It records:
   - `host_root` (relative, `..`);
   - the host commit convention (`inferred`, then `confirmed: true|false`) and `coauthor_trailers: allowed|forbidden|unknown`;
   - the skill/agent **rename map** produced by clash detection.

   Its absence means today's at-root mode, **byte-for-byte unchanged in behaviour**.
2. **Paths are rewritten once, at install time,** in the installed copies of the contract, skills, agents and the `settings.local.json` allowlist:
   - `python3 scripts/workflow.py` → `python3 workflow/scripts/workflow.py`;
   - workspace paths (`works/`, `docs/current/`, `docs/versions/`, `docs/index.json`) get the `workflow/` prefix.

   The rewrite is an exact-token substitution with a **post-check**: no unprefixed engine command may remain. The upstream source files stay root-relative. The engine prints host-relative paths when nested.
3. **Name clashes:** a renamed skill or agent is rewritten only in its slash references, skill-name references and `subagent_type`/filename uses, **never** in `workflow.py <subcommand>` lines. The engine resolves agent filenames through the map.
4. **The nested deltas live in one place:** the installed `CLAUDE.local.md`. It is generated, imports the rewritten contract (`@workflow/CLAUDE.md`, if verified), and states the nested rules:
   - two commits per slice, the product commit in the host's recorded convention, and the trailer rule;
   - no parallel;
   - PRs carry no phase IDs or workflow paths.

   The skills' own text stays mode-neutral apart from the path rewrite.
5. **"Ask once" happens after install.** The installer runs non-interactively (`curl | sh`). It **infers** the convention from the host's `git log` and `CONTRIBUTING*` and writes it with `confirmed: false`. A new engine command (e.g. `nested-convention --confirm …`) records the operator's confirmation. Until then, the orchestrator asks before the first product commit.
6. **Updates:** `--update --nested` refreshes the machinery under `workflow/` and re-renders the host-side files with the same guarantees. `/update-workspace` learns to detect a nested install, for example `workflow/nested.json` existing under cwd.

**To verify inside DECOMP, before cutting** (the executor has WebSearch and WebFetch): is `CLAUDE.local.md` still supported by current Claude Code (it was deprecated in some versions)? Does it honour `@imports`? Do subagents load it? Are `.claude/agents` loaded from the project root? Record the answers in `## Decisions`, with the fallback chosen if one fails (e.g. a repo-scoped note in `~/.claude/CLAUDE.md` that imports `workflow/CLAUDE.md`). **If the findings leave item 4 open, cut a `research` slice plus `P28.DECOMP2`** instead of guessing.

## The cut: three middle slices, then REVIEW

| Slice | Kind / risk | Why this rating |
|---|---|---|
| `P28.S1` Engine: nested awareness | implementation / **high** | **core invariant**: a new persisted `phase.json` field (the host anchors) and the review boundary. Also **wide blast radius**: root and path handling feed every command |
| `P28.S2` Installer `--nested`: zero-footprint install, rewrite, clash map, update | implementation / **high** | **core invariant**: the whole point is "no tracked host file changes", and a wrong write silently leaks into the team's repo. Also **open design**: the token-exact rewrite and the rename map |
| `P28.S3` Text, `/update-workspace`, docs and release v49 | implementation / low | the nested pointer text, a skill sweep that follows S1/S2's final shape, READMEs, CHANGELOG and the version bump (same shape as P27.S3) |

**S1 — engine.**
- Load `nested.json` and expose `HOST_ROOT` (`None` when absent).
- Record host anchors in `phase.json` at `new-phase` and at review pass. `phase-scope` diffs and statuses the host with those anchors and excludes `workflow/`.
- The `parallel-*` commands refuse with a clear line; the `next` hint stays silent.
- `CLAUDE_AGENTS` and agent filenames follow the host and the rename map.
- Printed paths become host-relative when nested; doc provenance and design-registry identity use the host.
- Add the `nested-convention` command (show / `--confirm`).
- **At-root behaviour unchanged.**
- **Probes:** small, core only:
  - a nested fixture where phase-scope lists only host product files;
  - a refusal of a parallel command;
  - at-root phase-scope unchanged.

**S2 — installer.**
- `--nested` in `wrapper.sh` (exclusive with `--into-existing`; combinable with `--update`). The two roots in `main.py`.
- Into `workflow/`: `git init` when absent, plus the engine, state, rewritten contract, docs and templates.
- Into `<host>/.claude/`: skills and agents, untracked. On a clash, prefix and record the rename in `nested.json`.
- Into `<host>`:
  - `settings.local.json`, merged additively if present;
  - the generated `CLAUDE.local.md`;
  - `info/exclude` entries, appended idempotently.
- **Never:** CI, `.gitattributes`, host `docs/`, `settings.json`, `CLAUDE.md` or git config.
- Infer the host commit convention.
- `--update --nested`.
- **Smoke Test 14:** a host fixture with a tracked `.claude/settings.json`, `CLAUDE.md`, `.gitattributes`, `.github/` and a deliberately clashing `commit` skill. Assert:
  - host `git status --porcelain` is empty and host HEAD and config are unchanged;
  - `workflow/.git` exists;
  - the rename is recorded and no unprefixed `python3 scripts/workflow.py` remains in the host `.claude/`;
  - a rerun is idempotent;
  - `--update --nested` keeps all of the above.

  Then do a live run against a scratch host repo.

**S3 — sweep and v49.**
- The `CLAUDE.local.md` template text.
- `/update-workspace` and `/retrofit` handle nested installs (and say it is the private route).
- The `commit` skill notes the two-repo split when nested.
- Both READMEs and the retrofit guide gain a "private use in a repo you don't own" section with the per-ticket flow:
  1. branch off `origin/main`;
  2. `/create-phase`;
  3. `/do-whole-phase`;
  4. `/review-phase`;
  5. a PR with no workflow traces.
- **Release:** `WORKSPACE_VERSION` 49, a `## v49` CHANGELOG entry, then `python3 installer/build.py` and `--check`.
- **Doc impact** notes for architecture, operations, decisions and qa. **No `doc-new-version`.**

**Upstream rule for every slice:** a slice that edits an embedded file (`scripts/workflow.py`, `.claude/*`, `works/templates/*`, `CLAUDE.md`, `installer/*`) runs `python3 installer/build.py`, and `--check` must pass. Only S3 bumps the version. **Tests:** only the core probes named above (per the contract's test rule).

## What the DECOMP executor does

1. Read `intent.md`, `phase.md`, and `CLAUDE.md`'s DECOMP and risk rules.
2. Do the Claude Code verification above. If it opens the design, cut `P28.R1` (`--kind research --risk high`) plus `P28.DECOMP2` instead of S1–S3 and stop.
3. Otherwise create the three bare slices with `new-slice`:
   - `--kind implementation` and the risks in the table;
   - `--order 1`–`3`;
   - `--depends-on` chaining S1 → S2 → S3;
   - no `plan.md`.
4. Edit `phase.md` (bounded, under budget):
   - **`## Decisions`:**
     - the cut and its rating triggers;
     - the compact footprint with line refs;
     - design items 1–6, plus the Claude Code verification answers;
     - "upstream source stays root-relative";
     - "at-root mode byte-for-byte unchanged";
     - "the acceptance gate waits for the real company repo".
   - **`## Notes for later slices`**, tagged by slice:
     - S1: the phase-scope anchors and `CLAUDE_AGENTS`;
     - S2: the policy-file skip, the guards, the rewrite post-check, and the subcommand-vs-skill-name hazard;
     - S3: the update-workspace cwd assumptions and the release duty;
     - all slices: the build.py rule.
   - **`## Now`.**
5. Write `result.md` (verdict block first) and return.

**Acceptance gate (orchestrator, after `finish-slice P28.DECOMP`):** `accept-gate P28 --require`, because the install and the per-ticket flow are operator-visible. Per `intent.md`, the walkthrough is run by the operator **in the real company repo**, so the gate stays open until then.

## Verification

- `python3 scripts/workflow.py validate` passes after DECOMP.
- `phase.md`'s `## Slices` shows S1–S3 (or R1 and DECOMP2) with the stated kinds and risks.
- No middle slice has a `plan.md`.
