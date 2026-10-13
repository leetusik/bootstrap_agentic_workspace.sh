# CLAUDE.md — developing bootstrap_agentic_workspace.sh

This repo **ships the agentic workspace**: the single-file installer `bootstrap_agentic_workspace.sh` and its sources. The workspace that plans and records the work on it is a **private nested install** in `workflow/` (git-excluded, its own repo). Drive it with `python3 workflow/scripts/workflow.py <command>`; its contract loads through `CLAUDE.local.md` (`@workflow/CLAUDE.workspace.md`). Commit workflow state with `git -C workflow …`, never in this repo.

## Layout

- `payload/`: the shipped sources, each at its **emit path with the first component undotted**: `payload/claude/{skills,agents,settings.json}`, `payload/scripts/workflow.py`, `payload/works/templates/`, `payload/executors.toml` (the adopter seed's source), `payload/github/workflows/workspace-ci.yml` (the adopter CI seed), `payload/gitattributes`, and `payload/contract.md` (the shipped `CLAUDE.md`). Never put a dotted name or a `CLAUDE.md` under `payload/`: Claude Code or GitHub would load it.
- `installer/`: `build.py`, `main.py`, `wrapper.sh`, `payloads/doc_bodies/`.
- `tests/retrofit_smoke.sh`: the release smoke suite.
- **`.claude/skills/`, `.claude/agents/`, `CLAUDE.local.md` and `workflow/` are installed, untracked copies. Never edit them**: an edit there shows no diff and is lost at the next `--update`. Edit `payload/`, rebuild, then refresh.

## Rules

- After editing `payload/**` or `installer/**`, run `python3 installer/build.py` and commit the rebuilt `bootstrap_agentic_workspace.sh` in the same commit. `.githooks/pre-commit` enforces `--check` (register once per clone: `git config core.hooksPath .githooks`).
- A release bumps `WORKSPACE_VERSION` in `installer/main.py` and adds the top `CHANGELOG.md` section, with its Migration notes line, in the same commit; the smoke suite checks they agree.
- Refresh this repo's own install with `sh bootstrap_agentic_workspace.sh --update .`, then commit the refresh in `git -C workflow`.
- Host commits follow the custom recorded with `nested-convention` (Conventional Commits, a component scope, **no phase or slice IDs**, `Co-Authored-By` allowed); the IDs live in the nested repo's commits.
- Run `bash tests/retrofit_smoke.sh` **alone** in its shell call, never chained.
- CI here is `.github/workflows/upstream-ci.yml` (build parity + smoke). The shipped adopter CI seed never runs in this repo.
