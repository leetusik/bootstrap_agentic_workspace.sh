---
name: update-workspace
description: Update the current repo's agentic-workspace machinery to the latest upstream cornerstone, preserving your phases, slices, and docs.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash
disable-model-invocation: true
---

# update-workspace

Bring this repo's workspace machinery to the latest upstream version, keeping your work (first adoption is `/retrofit`). The update overwrites the engine, agents, skills and `works/templates/`, merges settings additively (removing only hooks the workspace retired and moving an `autoCompactWindow` still at a value it shipped, each on a `removed:` / `changed:` line), refreshes the contract, and keeps the rest of `works/` and all of `docs/`. The installer detects the layout itself: at root, **nested** (`workflow/.agentic-nested.json`: run from the host root; it merges `.claude/settings.local.json`, refreshes `workflow/CLAUDE.workspace.md` and the `CLAUDE.local.md` block, and touches no tracked host file), or a multi-repo host.

1. **Preflight.** `git rev-parse --is-inside-work-tree`; a dirty tree (`git status --porcelain`; nested: `git -C workflow status --porcelain`) is reported, with committing first recommended. **Linked** (`next` prints `store=cloud`): hi2vi holds `works/` and `docs/`, so check only the update's paths, `git -C workflow status --porcelain -- . ':(exclude)works' ':(exclude)docs'` and `git -C workflow status --porcelain -- works/templates works/.workspace-version.json`. No `works/state.json` and `scripts/workflow.py`: STOP, use `/retrofit`. Read `works/.workspace-version.json`'s `workspace_version` (**N**; absent: pre-versioning).
2. **Fetch.** `tmp="$(mktemp -d)"`, `git clone --depth 1 https://github.com/leetusik/bootstrap_agentic_workspace.sh.git "$tmp"`, `ref="$(git -C "$tmp" rev-parse HEAD)"`. The top `## v<M>` of `$tmp/CHANGELOG.md` is the upstream version **M**.
3. **Preview.** Report `vN → vM` and print every `## v` entry newer than N, **Migration notes** included (N == M: any diff is unreleased drift). Then `sh "$tmp/bootstrap_agentic_workspace.sh" . --update --dry-run` and show its whole report: files updated or added, settings merged, the `removed:` / `changed:` lines, `stale (ours, unchanged — remove these files)`, `yours, kept`, and any `intents naming a retired mechanism`.
4. **STOP for the operator's approval.**
5. **Apply.** `SYNCED_COMMIT="$ref" sh "$tmp/bootstrap_agentic_workspace.sh" . --update` (the same command for every layout).
6. **Verify.** `python3 scripts/workflow.py sync-agents` (re-applies `executors.toml`'s overrides), then `next`, then `npm install -g @playwright/cli@0.1.25` (the agent's browser; the settings allow it). Run `executor-route` and show every `override=` line; drop one only on the operator's yes (delete its `[claude.<row>]` table, `sync-agents` again). **Act on each Migration notes line** the preview printed, in order. A `[codex.*]` table is refused (Codex support was removed in workspace v31): delete it.
7. **Team PR rules** (per registered repo on a multi-repo host): read them live by `.claude/skills/pr/SKILL.md`'s *Write and check* step 2 and the decided ones (`pr rules`, bare); show the undecided conflicts by the stop rules (`.claude/skills/do-whole-phase/SKILL.md` § Stops). The team wins where it speaks; ask only whether the operator wants ours on a point, and record only what they decide: `pr rules --rule "<what>" --choice team|ours [--note "<why>"] [--repo <name>]`.
8. **Clean up.** Remove only the files listed stale, each by path (`rmdir` a directory only once it is empty); `yours, kept` stay; each `intents naming a retired mechanism` line goes to the operator (never edit an `intent.md`). List what you removed and every `removed:` / `changed:` line; show `git status` (nested: `git -C workflow status`, and the host's, which must be unchanged).
9. **Commit**, unasked, by the `commit` skill: `chore: update agentic workspace to v<M>`; a clean tree stages all (`git add -A`), a dirty one only the paths the report and your removals name. Nested: `git -C workflow add -A && git -C workflow commit -m "chore: update agentic workspace to v<M> (nested)"`; the host gets no commit. **Linked:** never the whole nested repo: `git -C workflow add -A -- . ':(exclude)works' ':(exclude)docs' && git -C workflow add -A -- works/templates works/.workspace-version.json`, then the same commit. Never push. Then `rm -rf "$tmp"`.

## A multi-repo host

Updated as above from the host folder; `--update` never writes inside a repo. Show the operator, and act only on their word:

- the first `--update` of a hand-made host seeds its registry; an inferred convention stays UNCONFIRMED until `repo convention --confirm --repo <name> --text "<conventions>" --trailers allowed|forbidden`;
- a repo the registry lacks prints `repo add <path>`; `repo map-anchors <repo>` runs only if it names the right repo;
- a repo tracking `AGENTS.md` needs **Project instructions** `claude-md-and-agents-md` in the operator's user settings (pass it on);
- an unstamped-worktree warning clears with `worktree add-repo <P> --repo <name>=<branch> --adopt` from inside the set; never run `worktree teardown` with an engine lacking `worktree add-repo`.

**`--to-multi-repo <repo>`** turns a per-repo nested install into a multi-repo host at the repo's parent, only on the operator's word: update and commit the install first; preview with `sh "$tmp/bootstrap_agentic_workspace.sh" --to-multi-repo <repo> --dry-run` (every step, or every refusal, writing nothing) and STOP for approval; run it without `--dry-run`; then follow its closing block (the nested commit, the conventions to confirm, `sync-agents`, the rollback with real paths) and start Claude Code at the parent. If it halts after the move, follow its shorter rollback, fix, and re-run `--to-multi-repo`, never a plain `--update` at the parent.
