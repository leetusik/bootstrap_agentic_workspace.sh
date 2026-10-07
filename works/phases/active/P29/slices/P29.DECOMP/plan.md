# Plan — P29.DECOMP (decomposition)

## Context

P29 makes the v49 **nested personal install** the installer's **default layout everywhere**. The operator's intent, confirmed and recorded verbatim in `works/phases/active/P29/intent.md` (read it in full first):

- `sh bootstrap_agentic_workspace.sh <dir>` installs nested.
- A fresh or empty dir gets `git init` as its host.
- At-root is reached only with `--at-root`, or with `--into-existing`, which implies it.
- `--nested` stays a harmless no-op.
- `--update` detects the layout from the marker, so `/update-workspace` needs no `--nested`.
- Existing at-root installs keep updating at-root, with no migration.
- Ships as **v50**.

**The mechanism already exists (P28):** the `NESTED` branch in `installer/main.py` (`nested_preflight` ~L494, `nested_plan` ~L760, and the guards ~L1030), the engine's marker handling, and the smoke Tests 14+. **This phase changes routing, not the install itself:** it decides which mode runs, it handles the one new case (a host with no git yet), and it updates the texts.

Read `works/phases/active/P28/phase.md` `## Decisions` (the nested engine contract and installer), because P29 builds on it.

## Footprint (read-only exploration, this session)

- **`installer/wrapper.sh`** — flag parsing at the `while` loop, cross-flag checks after it, and the env exports. It needs `--at-root` and a new export, `AT_ROOT`.
  - Current conflicts: `--nested` with `--into-existing`; `--nested` with `--force-empty-ok`.
  - The usage text describes `--nested` as an opt-in.
- **`installer/main.py`**
  - `NESTED = os.environ.get("NESTED") == "1"` (~L52) is computed at import, before `HOST, ROOT = ROOT, ROOT/"workflow"`. Mode resolution has to move to that point.
  - `nested_preflight` refuses a target that is not the root of a git work tree. That refusal is where the new `git init` case goes.
  - The `--update` guard (~L1038) refuses a plain `--update` on a nested host. That refusal becomes auto-detection.
  - The fresh guard (~L1083) is today's at-root path, and it stays byte-for-byte the same behind `--at-root`.
  - Convention inference: `_host_git("log", …)` (~L569). It must not fail on an unborn HEAD.
- **Engine `scripts/workflow.py`** — already handles a host with no commit (`head_commit()` returns `""`, so `host_anchors.created` is null and `phase-scope` diffs from the empty tree). **No engine change is expected.** S1 confirms this live, and touches the engine only if something actually breaks.
- **`tests/retrofit_smoke.sh`** — there are 22 `sh "$BOOT"` calls. 11 of them are plain fresh installs that expect at-root: each gets `--at-root`. There are also the P28 nested tests. Under the CLAUDE.md test rule, add only a few core probes.
- **Texts:**
  - `README.md`, `README.en.md`, `docs/retrofit-guide.md` (the `--nested` section; and the line ~303 staging command, which needs `--at-root`), `installer/README.md`, `CHANGELOG.md`.
  - Skills: `.claude/skills/update-workspace/SKILL.md` (its `(nested)` command variants collapse into one), `retrofit/SKILL.md` (its pointer to `--nested`), and `commit/SKILL.md` if needed.
  - `WORKSPACE_VERSION` 49 → 50.

## The cut

Order **S1 → S2**, with `depends_on` chained, then `P29.REVIEW`. No research slice is needed: every open point is pinned below.

- **`P29.S1` Installer: nested by default** — implementation / **high**.
  - *Trigger — core invariant:* the mode routing every install and every `--update` goes through. A mis-detected update writes the wrong layout into a live workspace. A missed guard installs nested on top of an at-root workspace.
  - *Scope:* `wrapper.sh`, `installer/main.py`, the smoke suite edits and probes, then a rebuild with `python3 installer/build.py`, whose `--check` must pass.
- **`P29.S2` Texts, `/update-workspace` and release v50** — implementation / low. Same shape as P28.S3:
  - both READMEs, the retrofit guide, `installer/README.md` and the skills;
  - the CHANGELOG v50 entry with migration notes;
  - `WORKSPACE_VERSION = 50`, then a rebuild.

**Acceptance gate:** `accept-gate P29 --require`. The installer's default behaviour is an operator-visible surface. The walkthrough consists of a few scratch-directory commands for the operator: a bare install into a new dir, a bare install into an existing git repo, a bare `--update` on each layout, and `--at-root`.

## Decisions S1 must hold (record these in phase.md `## Decisions`)

1. **Mode resolution, one function at the top of `main.py`**, before `HOST, ROOT` are set. The wrapper exports `AT_ROOT`, and `NESTED` is set only by explicit `--nested`.
   - `--into-existing` or `--at-root` → at-root.
   - `--update` → **detect**:
     - `<target>/workflow/.agentic-nested.json` present → nested.
     - At-root workspace present (`scripts/workflow.py` + `works/`) → at-root.
     - Both present → refuse as ambiguous, and name both.
     - Neither → today's "no agentic workspace found" error.
     - An explicit `--nested` or `--at-root` that **contradicts** the detected layout refuses with one line. One that matches is a no-op. This keeps v49's `/update-workspace` text (`--update --nested`) working.
   - Otherwise (fresh install) → **nested**.
2. **Wrapper conflicts:**
   - `--at-root` with `--nested` → refuse.
   - `--nested` with `--into-existing` → refuse (unchanged).
   - `--force-empty-ok` without `--at-root` (or `--into-existing`, unchanged) → refuse with "applies to the at-root install; add --at-root". It never silently switches the layout.
3. **Fresh nested install into a target that is not a git repo:**
   - Target absent, or empty in the `EMPTY_OK_ALLOWLIST` sense → `mkdir -p` + `git init -q` the target as the host, then the normal nested install.
   - Non-empty and not a git repo → refuse with nothing written, and hint `git init` it yourself, or `--at-root`.
   - Target inside a git work tree but not its root → today's refusal, unchanged. Its hint also mentions `--at-root`.
4. **The guard against a layout already in place:** a bare fresh install into a target that already holds an **at-root** workspace (`scripts/workflow.py` + `works/`) must **not** install nested on top of it. It refuses with "already installed at-root — use --update" and writes nothing. A target already holding a nested install keeps v49's idempotent exit 0, but its hint now says plain `--update`.
5. **The convention for a host the installer just initialised** — the operator's own new project, with no history to infer from:
   - Write `commit_convention` already confirmed: `text` = this workspace's Commit Convention (`type(scope): summary`, imperative, no trailing period), `coauthor_trailers: allowed`, `inferred: null`. So `next` does not nag about `UNCONFIRMED` on a repo the operator owns.
   - An existing host keeps v49's infer-and-ask path.
   - Convention inference must survive an unborn HEAD, where `git log` fails, by treating it as no history.
6. **At-root stays byte-for-byte unchanged** behind `--at-root` (P28 invariant (a) carried over): the same writes, guards and output apart from the flag name in hints. The upstream repo itself stays at-root. Nothing in `installer/build.py` changes role.
7. **No migration.** Nothing converts an at-root install. `--update` on an at-root workspace behaves exactly as today.
8. **Tests (core only):**
   - Add `--at-root` to the 11 plain fresh `sh "$BOOT"` calls.
   - Add one new smoke test with these probes:
     - (a) a bare install into a new dir leaves `git init` at the host, plus nested `workflow/` and the marker with a confirmed convention, and host `git status --porcelain` stays empty;
     - (b) a bare install into an existing git repo is nested;
     - (c) a bare `--update` refreshes a nested install with no `--nested`, and `--update --nested` still works;
     - (d) a bare `--update` on an at-root install stays at-root;
     - (e) a bare install over an at-root workspace refuses, writing nothing;
     - (f) contradictory flags (`--update --at-root` on nested, `--at-root --nested`, `--force-empty-ok` without `--at-root`) refuse.
   - Run the suite **once, alone in its own foreground Bash call**, and report the count against the current baseline.
9. **Doc impact (S1 and S2 each leave a one-line note):** the install modes and defaults in operations (`## Operator Runtime` is unaffected) and in the architecture installer section. No `doc-new-version` in this phase.

## What this DECOMP executor does

1. Create the two middle slices as **bare folders** (never pre-filling their `plan.md`), with names, kinds and risks as above, `depends_on` chained S1 → S2, ordered before `P29.REVIEW`:
   - `python3 scripts/workflow.py new-slice --phase P29 --slice P29.S1 --name "Installer: nested by default" --kind implementation --risk high`
   - `python3 scripts/workflow.py new-slice --phase P29 --slice P29.S2 --name "Texts, /update-workspace and release v50" --kind implementation --risk low`
   - Use the engine's `--help` for the dependency and order flags.
2. Edit `phase.md` under budget:
   - `## Decisions`: the cut with its risk triggers, then decisions 1–9 above, compact.
   - `## Notes for later slices`: S2 rewrites the texts from S1's final flag shape. The retrofit-guide staging command needs `--at-root`. The CHANGELOG v50 migration notes cover: `--nested` is now a no-op, plain `--update` detects the layout, `--force-empty-ok` needs `--at-root`, and existing installs are unaffected.
   - `## Now`: point at S1.
3. Write `result.md` with the verdict block first.
4. Run `python3 scripts/workflow.py validate`.

It does not commit or transition state, and it does not run `accept-gate`. The orchestrator runs `accept-gate P29 --require` in the DECOMP commit.

## Verification

- `python3 scripts/workflow.py validate` passes.
- `next` points at `P29.S1`.
- `phase.md` `## Slices` lists S1, S2 and REVIEW.
- The S1 and S2 folders hold only `slice.json`.
