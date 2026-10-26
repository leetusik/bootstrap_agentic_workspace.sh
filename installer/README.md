# installer/ — source for `bootstrap_agentic_workspace.sh`

The single-file distributable at the repo root — `bootstrap_agentic_workspace.sh` —
is a **build product**, assembled from this directory by `build.py`. It stays one
self-contained POSIX-sh file because consumers `curl … | sh` the raw root file and
`/update-workspace` clones + runs that same file. **Never hand-edit the root
artifact; edit the source here and rebuild.**

## The one workflow

To change anything the installer emits:

1. Edit the **source under `payload/`** (or the fresh-only payload — see below).
2. Run `python3 installer/build.py` to reassemble the root artifact.
3. Commit the rebuilt `bootstrap_agentic_workspace.sh` together with your edit.

That is the whole loop. There is no longer a second copy to mirror by hand — the
old double-maintenance (edit a skill *and* mirror it into a heredoc) is gone.

**Release rule (version + changelog).** When the edit ships a machinery change to
targets — anything an adopting repo receives via `curl … | sh` or `/update-workspace`
(a skill, agent def, `scripts/workflow.py`, the contract, settings, templates, …;
their sources are under `payload/`) —
bump `WORKSPACE_VERSION` in `installer/main.py` **and** add the matching
`## v<N> — <date>` entry to the root `CHANGELOG.md`, in the **same commit** as the
change and the rebuilt artifact. `/update-workspace` reads that changelog from the
upstream clone to tell adopters what a sync brings, so a version bump without a
changelog entry (or vice versa) leaves them blind. Repo-only edits that never reach a
target (this README, `tests/`, `LICENSE`, the root `CLAUDE.md`) do not need a bump.

`python3 installer/build.py --check` fails (non-zero) if the committed artifact has
drifted from source; it runs in `tests/retrofit_smoke.sh` (Test 7) so CI catches a
stale artifact. The tracked `.githooks/pre-commit` hook runs the same check whenever
staged files touch `installer/`, `payload/` or the artifact, blocking a commit that would ship a stale artifact —
register it once per clone: `git config core.hooksPath .githooks`.

## What lives where

- **`build.py`** — deterministic assembler. Reads `payload/` + `payloads/`,
  generates a payload manifest, splices it into `main.py`, wraps the result in the
  `wrapper.sh` heredoc, and writes the root artifact (preserving the executable
  bit). Determinism = sorted walks + sorted dict keys + `repr()` literals, no
  timestamps → same inputs produce a byte-identical artifact. Safety checks:
  `compile()` the assembled python body, `sh -n` the assembled artifact, assert no
  body line collides with the heredoc delimiter (`INSTALLER_PY`), assert the skill
  inventory is exactly `EXPECTED_SKILL_COUNT` (17) packages, and assert `payload/contract.md`
  still starts with `CLAUDE_HDR` before slicing the contract body off it.
  **It only `compile()`s the artifact — it never runs it**, so a change to what
  `main.py` reads out of `PAYLOADS` needs a real install into a temp dir to verify.
- **`wrapper.sh`** — the POSIX-sh wrapper (arg parsing, the cross-flag refusals, env
  export, and the usage text `--help` prints) ending in the
  `python3 - <<'INSTALLER_PY'` heredoc with a `#@@PYTHON_BODY@@` marker where the
  python driver is spliced.
- **`main.py`** — the python driver: config/env, layout resolution
  (`resolve_layout()`, see *Install modes and flags*), write engine, retrofit/update
  policies, the nested install, guards, docs seeding logic, finalizers, dispatch. It carries a
  `#@@GENERATED_PAYLOADS@@` marker where `build.py` splices the generated constants
  (`PAYLOADS`, `CONTRACT_BODY`, `DOC_BODIES`). The workspace bootstraps with **no
  phases** — the operator's first task is captured via the create-phase flow, so
  there is no phase scaffold to seed.
- **`payloads/`** — fresh-install-only seeds that have **no `payload/`
  counterpart** (so there is nothing to mirror):
  - `doc_bodies/<doc>.md` — the 11 initial `docs/current/*.md` bodies. Runtime
    tokens `__PROJECT_NAME__` / `__PROJECT_SUMMARY__` are substituted by `main.py`.

## Install modes and flags

The default layout is **nested** (since v50); the at-root layout is reached explicitly. One
function, `resolve_layout()` at the top of `main.py` (before `HOST, ROOT` are set), picks the
layout of a run, and the wrapper rejects contradictory flags first:

- **No flag: the private nested install.** `TARGET_DIR` is a git repo's root (the *host*); the
  engine and all state go to `<host>/workflow/`, a nested git repo, and the skills, agents,
  `settings.local.json` and `CLAUDE.local.md` go to the host untracked, hidden by the host's
  `.git/info/exclude`. A new or empty target is `git init`-ed as the host, with this workspace's own
  commit convention recorded as confirmed (trailers allowed), and that init is undone if a refusal
  comes before the first write. A non-empty non-git target (unless it is a folder of repos, next
  bullet), a new directory inside another repo's work tree, a bare install over an at-root workspace,
  and a bare install or `--update` on a nested install's own `workflow/` are refused with nothing written.
- **No flag, into a folder of repos: the multi-repo host.** A target that is not a git repo and
  holds only git repos at depth 1 (a single repo counts; the harmless files a new target may hold,
  such as `.DS_Store` or a README, are ignored) is installed as a host that tracks nothing and
  carries several product repos. The installer `git init`s the folder and makes its one empty
  commit, `chore: start the host history` (the base `new-phase` and `parallel-start` need),
  writes a `/<repo>/` line per repo inside the managed `info/exclude` block, and seeds the
  registry, an optional `repos` list in `workflow/.agentic-nested.json` (name, path, default
  branch, rules files and convention per repo, each repo's convention inferred from its own history
  and unconfirmed; the host-level convention, the rules for every repo, starts unconfirmed with
  nothing inferred). `CLAUDE.local.md` gets the multi-repo block. It writes nothing into any repo.
  When git has no identity, the init is kept, no commit is made and the run still exits 0: it
  prints `git config --global user.name`/`user.email` and then `git -C <host> commit --allow-empty
  -m "chore: start the host history"` for you to run. A refusal before the first write undoes the
  init and its commit. When a registered repo tracks an `AGENTS.md`, one line says to set Project
  instructions to `claude-md-and-agents-md` in `~/.claude/settings.json`, because Claude Code
  reads no `AGENTS.md` while a `CLAUDE.local.md` sits at the working directory.
- **`--at-root`**: the committed, team-visible layout into a fresh directory (`CLAUDE.md`,
  `.claude/`, `scripts/`, `works/`, `docs/` at its root). Its behaviour and output are the v49
  default, unchanged. `--force-empty-ok` is accepted only with `--at-root` or `--into-existing`
  (on `--update` too).
- **`--into-existing`**: the at-root retrofit (`--at-root` with it is allowed and redundant).
- **`--update [--dry-run]`**: detects the installed layout at the target, the nested marker
  `workflow/.agentic-nested.json` versus an at-root workspace (`scripts/workflow.py` plus
  `works/`), and refreshes it in that layout. Both found is ambiguous and refuses unless
  `--nested` or `--at-root` picks one; a flag that contradicts the layout found refuses. On a
  host that tracks nothing and has no registry yet, the first `--update` seeds one from the depth-1
  repos; once `repos` exists, `--update` only prints (a drift line per unregistered child repo,
  `nested-repos --add <path>`, and a `nested-repos --map-anchors <repo>` note) and never
  re-detects.
- **`--to-multi-repo REPO [--dry-run]`**: converts the per-repo nested install at `REPO/workflow/`
  into a multi-repo host at `REPO`'s parent folder. It takes the repo and no target, and does not
  combine with `--update`, `--at-root`, `--into-existing`, `--nested`, `--force-empty-ok`, `--name`
  or `--summary`. `--dry-run` prints every step, or every refusal, and writes nothing. Every
  refusal comes before the first write: no per-repo nested install (an at-root workspace, or a
  marker that already holds `repos`), an install not at this installer's version, an in-flight
  worktree pair, a dirty nested repo or a failing `validate`, a parent that is inside a work tree,
  tracks files, holds a `workflow/`, a managed `CLAUDE.local.md` block or a non-repo entry, or whose
  ignore rules would show a host file to git, and a repo that tracks a workspace file. Then it
  `git init`s the parent with the one empty commit (a parent that is already a repo tracking
  nothing keeps its history), moves `REPO/workflow` to the parent, runs the plain `--update` there,
  moves the old repo's convention into the registry as that repo's (every other repo inferred and
  unconfirmed, the host-level convention unconfirmed), records `converted_from` in the marker,
  runs `nested-repos --map-anchors REPO` so each phase's `host_anchors` become
  `repo_anchors.REPO`, and cleans the old repo: only workspace files byte-identical to what this
  installer writes are deleted, edited ones stay and are listed, and its leftover worktrees are
  listed, never deleted. The closing block names the nested commit to make
  (`chore(works): convert to a multi-repo host`), the conventions to confirm and the rollback
  (revert that commit, `mv` the nested repo back, `--update REPO` after copying aside the skills
  listed as yours, then remove the host's own files). A stop between the move and the cleanup
  prints the shorter rollback and says to re-run `--to-multi-repo`, never to run a plain
  `--update` at the parent.
- **`--nested`**: accepted and redundant (on `--update` it must match the layout found).

Nothing migrates an at-root install: `--to-multi-repo` converts a *per-repo nested* install, never
an at-root one. This upstream repo was itself converted to the nested layout by hand, once, on
2026-10-13 (no at-root-to-nested migration command ships): its sources live under
`payload/` and its workspace in the git-excluded `workflow/`. `tests/retrofit_smoke.sh` passes
`--at-root` wherever a test expects the at-root layout.

## Source of truth = `payload/`

`build.py` embeds these shipped sources **verbatim**, so editing them and rebuilding is all
that is needed. Each source sits under `payload/` at its **emit path** (where the installer
writes it) with the first path component undotted (`build.py`'s `src_rel()`), and the
contract is `payload/contract.md`. No source sits at a path Claude Code or GitHub would load
in this repo (`.claude/`, `.github/`, `CLAUDE.md`), because this repo is driven by a nested
install whose copies own `.claude/`; never add a dotted name or a `CLAUDE.md` under `payload/`.
Below, each entry is the source, then the emit path where it differs:

- `payload/scripts/workflow.py`
- `payload/claude/skills/<name>/**` → `.claude/skills/<name>/…` (skills are discovered from disk by their
  `SKILL.md`; the build asserts the release inventory is exactly 17 packages — `EXPECTED_SKILL_COUNT` in
  both `build.py` and `main.py`, so adding or removing a skill means moving both). A skill ships as its
  **whole directory**: `SKILL.md` plus every other file under it (dotfiles and `__pycache__` excepted),
  written on fresh install, retrofit, `--update` and the nested install (rewritten and renamed with
  its skill) like any machinery.
  - **Cores and references (v61).** `design-cowork`, `do-whole-phase` and `do-next-slice` are a core
    `SKILL.md` of **≤ 8,192 bytes** plus `reference/<topic>.md` files the core names, each with the
    moment to read it; the smoke suite asserts the cap, that every named reference exists, and that no
    reference is orphaned.
  - **Shared references have one source.** `SHARED_SKILL_FILES` in `build.py` maps each copy to its
    source; the build emits a byte-identical copy, so every installed skill directory is
    self-contained. Today: `do-whole-phase/reference/dispatch.md` (the route table: resolve → pin →
    dispatch → record → Explore) is copied to `do-next-slice/reference/dispatch.md`. Edit the source
    only; a copy that also exists under `payload/` is a build error.
  - **Retired reference files.** `--update` reports a file in one of our skill directories that the
    payload does not ship as **"yours, kept"**, unless `RETIRED_FILES` in `main.py` holds the hash of
    its unchanged text, and then it is flagged stale (by content, file by file, never a directory).
    Both only report; nothing is deleted. When a release stops shipping a file, add its hash to
    that table.
  `/explain` is not shipped; it comes from the knowledge plugin as `/knowledge:explain` (see the
  Knowledge block in [README.en.md](../README.en.md)). The updater never creates, edits, removes or
  reports a path with an `explain` component, and `RETIRED_FILES` never lists one.
- `payload/claude/agents/slice-executor.md`, `payload/claude/agents/design-drafter.md`,
  `payload/claude/agents/design-critic.md`, `payload/claude/agents/Explore.md` → `.claude/agents/…` (the design subagent and the design critic; `sync-agents` keeps each on its own row, `design` and `critic`)
- `payload/executors.toml` → `executors.toml` (seed-once executor-route config — created if absent,
  never overwritten on update; every row commented out at its engine default)
- `payload/claude/settings.json` → `.claude/settings.json` (the project `autoCompactWindow` ships at 500000; Claude Code also compacts an idle session by itself, on by default, and `idleCompaction: false` in your user settings turns that off; a 200k-context model compacts at its own limit, since the window is capped at the model's context. No compaction hook and no `idleCompaction` key ships; the `SessionStart` `compact` hook only prints the resume card)
- `payload/works/templates/{deferred_brief,intent,phase}.md` → `works/templates/…`
- `payload/github/workflows/workspace-ci.yml` → `.github/workflows/workspace-ci.yml` (**seed-once** repo policy file — created when
  absent, never overwritten, on install/retrofit/update alike; one workflow
  that runs `validate` on every push and PR, plus a `parallel-gate` job on `phase/*` pull
  requests; this repo's own CI is `.github/workflows/upstream-ci.yml`)
- `payload/gitattributes` → `.gitattributes` (**line-merged** repo policy file — the
  `works/events.jsonl merge=union` rule is appended when missing and existing content
  is never rewritten; skipping a repo's existing `.gitattributes` would silently drop
  the union rule)
- `payload/contract.md`, the shipped `CLAUDE.md` contract body (the `# CLAUDE.md\n\n` header stripped, embedded once as
  `CONTRACT_BODY`; the header literal is pinned as `CLAUDE_HDR` in `build.py` **and** in the
  `main.py` write — change the contract's first line and both must move with it)

Both policy files are emitted by `emit_policy_files()` in `main.py` rather than through
the normal `write_text` dispatch, so their policy is defined once and applies to fresh
installs, `--into-existing` retrofits and `--update` alike. They are deliberately **not**
in `MANAGED_FILES`: a repo that already has CI or attribute rules must not fail the
fresh-install conflict guard.

Interpolation that depends on install-time values (project name, doc frontmatter
dates) stays as code in `main.py`; the payloads carry only static text plus the
`__…__` sentinels above.
