# Plan — P28.S3 Text, `/update-workspace`, docs and release v49 (implementation / low)

## Goal

Finish the nested personal install for the operator, then ship it as **v49**:
- the texts the operator reads;
- the skills that must behave differently at a nested host;
- the READMEs and the retrofit guide;
- the release.

S1 (engine) and S2 (installer) are landed; their contracts are pinned in `phase.md` `## Decisions` (Engine contract, Nested installer).

Read first:
- `phase.md`: `## Decisions`, plus every note tagged `for P28.S3` (three from S1/DECOMP, three from S2);
- `intent.md` (the per-ticket flow the operator asked for).

**At-root output stays unchanged** except the version stamp and the new docs.

## 1. Installer texts (`installer/main.py`)

- **`_nested_local_block()`**, the managed block in the host's `CLAUDE.local.md`. Polish it into a short, scannable rule set:
  1. what this is (a private install that is never committed and invisible to the team);
  2. the import line;
  3. **start Claude at the host root**;
  4. **two commits per slice**:
     - product code goes to the host on the operator's ticket branch, in the convention `python3 workflow/scripts/workflow.py nested-convention` prints, with Claude co-author trailers only when it says `allowed`;
     - `works/` state goes to `workflow/` in the workspace's Commit Convention;
  5. if `next` shows `host_commit_convention=UNCONFIRMED`, confirm it with the operator before the first product commit;
  6. no parallel worktrees;
  7. a PR's title, body and commits carry no phase or slice IDs, workflow paths or workspace files;
  8. never stage `workflow/`, `CLAUDE.local.md` or our `.claude/` files into the host;
  9. the rename note when a clash renamed something.

  **Keep both S2 constraints:**
  - the `@workflow/CLAUDE.workspace.md` line stands on its own, outside backticks and fences;
  - renames are phrased "skill `X` is `/Y`", never `/X`.
- **`print_nested_banner()`**, fresh and update:
  - replace the placeholder first-commit message with a real one, e.g. `git -C workflow add -A && git -C workflow commit -m "chore: install agentic workspace (nested)"`;
  - say to start Claude at the host root and accept the trust dialog on the first run (S2's live-run finding);
  - point to `nested-convention`;
  - "any remote for `workflow/` stays inside your company's org".
- **Rewrite coverage (S2 left this to S3):** add the seed `workflow/executors.toml` and `workflow/docs/README.md` to the nested rewrite and its post-check. Agents running at the host root read both, and their comments say `python3 scripts/workflow.py`.
  - Apply the rewrite only when writing **fresh** in nested mode.
  - `--update` never overwrites `executors.toml` (seed-once), so leave an existing one alone.
  - At-root writes stay byte-identical.
- **Engine messages naming skills unrenamed** (e.g. validate's "via the create-phase skill" in a clash case): leave them, and note it in the README caveats. That is cheaper and safer than threading the rename map through the engine's prose.

## 2. Skills (upstream source stays root-relative; S2's rewrite prefixes the installed copies)

- **`/update-workspace`** gets a nested branch:
  - in preflight, `workflow/.agentic-nested.json` under cwd means a nested install;
  - then the dry-run is `sh "$tmp/bootstrap_agentic_workspace.sh" . --update --nested --dry-run`, and the apply is `SYNCED_COMMIT="$ref" sh … . --update --nested`;
  - then `sync-agents` and `next` run as usual (the rewrite prefixes them);
  - the version marker is the installed copy's `works/.workspace-version.json` (prefixed by the rewrite);
  - say that a plain `--update` at a nested host refuses and points here.

  Write the source text so the rewrite produces correct paths. Literal `workflow/` prefixes written in source must not end up double-prefixed: verify by rendering a nested install in scratch and reading the installed `update-workspace/SKILL.md`.
- **`/retrofit`:** one short paragraph. It is the team-visible adoption route. For a private install in a repo you don't own, use `sh <path>/bootstrap_agentic_workspace.sh <host-root> --nested` instead (`--nested --into-existing` is refused). Point to the README section.
- **`commit`:** one short paragraph. In a nested install (`workflow/.agentic-nested.json` exists), host and `workflow/` are two repos:
  - commit product changes in the host with the convention `nested-convention` prints and its trailer rule;
  - commit state changes with `git -C workflow` in this workspace's convention;
  - never stage workflow files into the host.

  Keep the skill flat. `EXPECTED_SKILL_COUNT` stays 18.
- **Do not edit `CLAUDE.md`**: the nested rules live in the `CLAUDE.local.md` block (decision item 4).

## 3. READMEs and the retrofit guide

Add a section, **"Private use in a repo you don't own (`--nested`)"**, to `README.en.md` (English) and `README.md` (Korean; write natural Korean matching that file's tone), plus a short pointer subsection in `docs/retrofit-guide.md`. Also add `--nested` to README.en.md's `### Options` list. The section covers:
- **When to use it:** a company or team repo where the team does not use the workspace; strictly private; zero footprint.
- **Install:** `sh bootstrap_agentic_workspace.sh <host-root> --nested`. Then list what it writes and where:
  - `workflow/` (a nested git repo);
  - untracked `.claude/` skills and agents;
  - `settings.local.json`;
  - the `CLAUDE.local.md` block;
  - the `info/exclude` block.

  Then what it never touches, and the `wf-` rename on a clash.
- **First run:**
  - start Claude at the host root and accept the trust dialog;
  - make the first `workflow/` commit;
  - confirm the commit convention with `nested-convention`.
- **The per-ticket flow, start to PR:**
  1. `git switch -c <branch> origin/main`, the team's way;
  2. `/create-phase`;
  3. `/do-whole-phase`, with two commits per slice;
  4. `/review-phase`, whose `phase-scope` reads the host diff;
  5. push and open a PR with no workflow traces;
  6. review comments become fix slices.
- **Updating:** `/update-workspace` or `sh … <host-root> --update --nested`.
- **Caveats:**
  - parallel worktrees are off, and host worktrees lack the untracked files;
  - a company managed policy may disable `bypassPermissions`, which our agents use;
  - engine messages may name a renamed skill by its original name;
  - keep any `workflow/` remote inside the company's org;
  - check the company's AI-tool policy.

## 4. Release v49

- `WORKSPACE_VERSION = 49` in `installer/main.py`.
- A `## v49 — 2026-10-07` entry at the top of `CHANGELOG.md`, in the house style of v48:
  - the nested install, the engine's nested mode, the `--nested`/`--update --nested` flags, the marker, `nested-convention`, `phase-scope` host anchors, parallel off;
  - the skill changes (`update-workspace`, `retrofit`, `commit`).
  - **Migration notes:** none required for at-root workspaces; nested mode is opt-in. `/update-workspace` picks up the nested branch automatically.
- Run `python3 installer/build.py`, then `python3 installer/build.py --check`.

## Validation

- `bash tests/retrofit_smoke.sh`, as the only command in its own foreground Bash call. It must pass. Adjust any pin that names v48 only if the suite requires it; add no new tests (text is verified by reading).
- `python3 scripts/workflow.py validate` passes.
- **Live render check** in the session scratchpad:
  - make a fake host (git init, one tracked `CLAUDE.md`, one conventional commit) and install `--nested`;
  - read the installed `CLAUDE.local.md`, `update-workspace/SKILL.md`, `commit/SKILL.md`, `workflow/executors.toml` and `workflow/docs/README.md`: correct prefixes, no `workflow/workflow/`;
  - host `git status --porcelain` is empty.

## Hand-off

- **`phase.md`:**
  - consume the S3 notes;
  - add `## Doc impact` lines: operations (the nested runbook: install, first run, per-ticket flow, update); decisions (the P28 decisions: nested mode, marker, rewrite, gate waived); README/guide are repo docs, not durable docs, so note them only if they change a durable truth;
  - leave a REVIEW note listing what to walk on a fake host (the fresh install; one end-to-end ticket of create-phase → a product commit plus a state commit → phase-scope; `--update --nested`; host status clean throughout);
  - rewrite `## Now`.
- **`result.md`:** verdict block first.
