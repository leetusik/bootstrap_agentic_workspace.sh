# CLAUDE.md — developing bootstrap_agentic_workspace.sh

This repo **ships the agentic workspace**: the single-file installer `bootstrap_agentic_workspace.sh` and its sources. The workspace that plans and records the work on it is a **private nested install** in `workflow/` (git-excluded, its own repo). Drive it with `python3 workflow/scripts/workflow.py <command>`; its contract loads through `CLAUDE.local.md` (`@workflow/CLAUDE.workspace.md`). Commit workflow state with `git -C workflow …`, never in this repo.

## Layout

- `payload/`: the shipped sources, each at its **emit path with the first component undotted**: `payload/claude/{skills,agents,settings.json}`, `payload/scripts/workflow.py`, `payload/works/templates/`, `payload/executors.toml` (the adopter seed's source), `payload/github/workflows/workspace-ci.yml` (the adopter CI seed), `payload/gitattributes`, and `payload/contract.md` (the shipped `CLAUDE.md`). Never put a dotted name or a `CLAUDE.md` under `payload/`: Claude Code or GitHub would load it.
- `installer/`: `build.py`, `main.py`, `wrapper.sh`, `payloads/doc_bodies/`.
- `tests/retrofit_smoke.sh`: the release smoke suite.
- `changelog.d/`: pending release notes, one fragment per branch (its `README.md` gives the format). Only `--release` turns them into a version.
- **`.claude/skills/`, `.claude/agents/`, `CLAUDE.local.md` and `workflow/` are installed, untracked copies. Never edit them**: an edit there shows no diff and is lost at the next `--update`. Edit `payload/`, rebuild, then refresh.

## Rules

- After editing `payload/**` or `installer/**`, run `python3 installer/build.py` and commit the rebuilt `bootstrap_agentic_workspace.sh` in the same commit. `.githooks/pre-commit` enforces `--check` (register once per clone: `git config core.hooksPath .githooks`, which also arms the release guards below).
- **The version is stamped as work lands on `main`, never on a branch.** A branch or slice never touches `WORKSPACE_VERSION` or `CHANGELOG.md`'s numbered sections; it writes its notes in `changelog.d/<slug>.md` (line 1 `# <one-line summary>`, then the bullets, including a `**Migration notes.**` line; format in `changelog.d/README.md`). So two parallel branches never renumber each other.
- **Landing a branch on `main`:** `git merge --no-ff --no-commit <branch>` → `python3 installer/build.py --release` → `git add -A CHANGELOG.md installer/main.py bootstrap_agentic_workspace.sh changelog.d` → `git commit -m "build(release): workspace v<M> — <summary>"` (`--release` prints `released=v<M>` and the subject). It stamps `M = N + 1` into a `## v<M> — <date>` section holding every pending fragment (by file name), sets `WORKSPACE_VERSION = M`, deletes the fragments and rebuilds the artifact, which also settles an artifact merge conflict. It refuses off `main`, with no fragment, with a fragment missing its summary or Migration notes line, and when `WORKSPACE_VERSION` is not the top `## v<N>`. A release made on `main` directly: write the fragment, run `--release`, commit the same way.
- **Guards against a forgotten stamp:** on `main`, `.githooks/pre-commit` and `.githooks/pre-merge-commit` (git's automatic merge commits) refuse a commit that holds a fragment, and CI fails a push to `main` that carries one. Never hand-edit `WORKSPACE_VERSION` or add a numbered CHANGELOG section. The smoke suite still checks that the version, the top CHANGELOG section and a fresh install's marker agree.
- Refresh this repo's own install with `sh bootstrap_agentic_workspace.sh --update .`, then commit the refresh in `git -C workflow`.
- Host commits follow the custom recorded with `nested-convention` (Conventional Commits, a component scope, **no phase or slice IDs**, `Co-Authored-By` allowed); the IDs live in the nested repo's commits.
- Run `bash tests/retrofit_smoke.sh` **alone** in its shell call, never chained.
- CI here is `.github/workflows/upstream-ci.yml` (build parity + smoke). The shipped adopter CI seed never runs in this repo.
