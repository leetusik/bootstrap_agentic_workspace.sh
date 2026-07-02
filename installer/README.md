# installer/ — source for `bootstrap_agentic_workspace.sh`

The single-file distributable at the repo root — `bootstrap_agentic_workspace.sh` —
is a **build product**, assembled from this directory by `build.py`. It stays one
self-contained POSIX-sh file because consumers `curl … | sh` the raw root file and
`/update-workspace` clones + runs that same file. **Never hand-edit the root
artifact; edit the source here and rebuild.**

## The one workflow

To change anything the installer emits:

1. Edit the **live repo file** (or the fresh-only payload — see below).
2. Run `python3 installer/build.py` to reassemble the root artifact.
3. Commit the rebuilt `bootstrap_agentic_workspace.sh` together with your edit.

That is the whole loop. There is no longer a second copy to mirror by hand — the
old double-maintenance (edit a skill *and* mirror it into a heredoc) is gone.

**Release rule (version + changelog).** When the edit ships a machinery change to
targets — anything an adopting repo receives via `curl … | sh` or `/update-workspace`
(a skill, agent def, `scripts/workflow.py`, the contract, settings, templates, …) —
bump `WORKSPACE_VERSION` in `installer/main.py` **and** add the matching
`## v<N> — <date>` entry to the root `CHANGELOG.md`, in the **same commit** as the
change and the rebuilt artifact. `/update-workspace` reads that changelog from the
upstream clone to tell adopters what a sync brings, so a version bump without a
changelog entry (or vice versa) leaves them blind. Repo-only edits that never reach a
target (this README, `tests/`, `LICENSE`) do not need a bump.

`python3 installer/build.py --check` fails (non-zero) if the committed artifact has
drifted from source; it runs in `tests/retrofit_smoke.sh` (Test 7) so CI catches a
stale artifact.

## What lives where

- **`build.py`** — deterministic assembler. Reads the live files + `payloads/`,
  generates a payload manifest, splices it into `main.py`, wraps the result in the
  `wrapper.sh` heredoc, and writes the root artifact (preserving the executable
  bit). Determinism = sorted walks + sorted dict keys + `repr()` literals, no
  timestamps → same inputs produce a byte-identical artifact. Safety checks:
  `compile()` the python body, `sh -n` the assembled artifact, assert
  `CLAUDE.md` == `AGENTS.md` (contract body), assert no line collides with the
  heredoc delimiter.
- **`wrapper.sh`** — the POSIX-sh wrapper (arg parsing, env export) ending in the
  `python3 - <<'INSTALLER_PY'` heredoc with a `#@@PYTHON_BODY@@` marker where the
  python driver is spliced.
- **`main.py`** — the python driver: config/env, write engine, retrofit/update
  policies, guards, docs + P1 seeding logic, finalizers, dispatch. It carries a
  `#@@GENERATED_PAYLOADS@@` marker where `build.py` splices the generated constants
  (`PAYLOADS`, `CONTRACT_BODY`, `DOC_BODIES`, `P1_PHASE_MD`, `P1_INTENT_MD`).
- **`payloads/`** — fresh-install-only seeds that have **no live counterpart** in
  the repo (so there is nothing to mirror):
  - `doc_bodies/<doc>.md` — the 11 initial `docs/current/*.md` bodies. Runtime
    tokens `__PROJECT_NAME__` / `__PROJECT_SUMMARY__` are substituted by `main.py`.
  - `p1_seed/phase.md`, `p1_seed/intent.md` — the initial P1 phase scaffold.
    Tokens `__PHASE_NAME__` / `__PHASE_OBJECTIVE__` / `__CREATED_AT__` /
    `__INTENT_ORIGIN__` / `__INTENT_ORIGINAL__` are substituted by `main.py`.

## Source of truth = live repo files

`build.py` embeds these live files **verbatim** (target path == repo-relative
path), so editing them and rebuilding is all that is needed:

- `scripts/workflow.py`
- `.claude/skills/*/SKILL.md`, `.agents/skills/*/SKILL.md`,
  `.agents/skills/*/agents/openai.yaml` (skills are discovered from disk — a skill
  is Claude-only, e.g. `do-whole-phase`, when it has no `.agents/skills/` mirror)
- `.claude/agents/slice-executor{,-high}.md`, `.codex/agents/slice-executor{,-high}.toml`
- `.claude/settings.json`, `.codex/config.toml`
- `works/templates/{result,deferred_brief,intent}.md`
- the `CLAUDE.md` == `AGENTS.md` contract body (asserted byte-equal, embedded once)

Interpolation that depends on install-time values (project name, phase name, doc
frontmatter dates, the P1 scaffold) stays as code in `main.py`; the payloads carry
only static text plus the `__…__` sentinels above.
