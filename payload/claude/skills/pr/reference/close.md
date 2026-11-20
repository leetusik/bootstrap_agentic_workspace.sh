# The close

The orchestrator runs it, never an executor: the drafts open when the review would pass, and at the operator's `accept` the engine's `close <P>` walks the rest in its fixed order.

## Open the drafts, when the review passes

The review would pass and every body passes `pr check`. With no stop and no word, per recorded branch, bottom-up in a stack or series (`split.md`):

1. `git push -u origin <b>`, never `--force`.
2. `gh pr create --draft --base <base> --head <b> --title "<title>" --body-file <body>`. `<base>` exactly as `pr_branch=` prints it (a branch name, never `origin/…`); the title an imperative "what" in the repo's convention, with no phase or slice IDs. A refusal: `open.md`.
3. A details file: `gh pr comment <n> --body-file <details>`, point the body's details link at that comment's URL, re-run `pr check`, then `gh pr edit <n> --body-file <body>`.
4. `python3 scripts/workflow.py pr record <P> [--repo <name>] --branch <b> --url <url>`: it also records the draft's head, `updatedAt` and comment count, what `close` compares the PR against. A cross-repo series also updates the wave index in its first PR.
5. **Read the CI:** `gh pr checks <n>` (exit 8: pending). Red (`fail` or `cancel`) becomes a fix round **before the gate opens**, never after the accept: `review <P> --verdict changes_requested --note "operator-reported: CI red: <checks>"`, fix slices, `reopen.md`'s update step. Pending: open the gate and wait with `gh pr checks <n> --watch --fail-fast` while the operator walks. No checks: say "no CI checks".

**Screenshots**, only for a phase that changed a user surface, before that branch's push:

- capture each changed surface with `playwright-cli` (`screenshot --filename=<dir>/<surface>-after.png`, a before where it helps) outside every repo;
- push them to the repo's orphan **`pr-assets`** branch, one folder per PR named by its head branch (`/` as `-`), from a throwaway worktree, so no image enters the product tree: `git fetch origin pr-assets`; then `git worktree add -B pr-assets <tmp> origin/pr-assets`, or `git worktree add --orphan -b pr-assets <tmp>` when the fetch found none; copy the images into `<tmp>/<folder>/`; `git -C <tmp> add <folder>`; `git -C <tmp> commit -m "docs: screenshots for <b>"`; `git -C <tmp> push origin pr-assets` (never `--force`); note `git -C <tmp> rev-parse HEAD` as `<sha>`; `git worktree remove <tmp>`;
- link each as `![<surface>, after](../blob/<sha>/<folder>/<file>.png?raw=true)`: GitHub's form for a repo file in that repo's PR, pinned to the commit; it renders for viewers with read access, private repos included.

Then the walkthrough lines (each URL, what to read on GitHub, the CI state) open `gate <P> open`'s walkthrough, or are a waived gate's pass report.

**An open failure** (no `gh`, auth, the network, a refused push): the `REVIEW` slice `pending --stop-kind operator-action --on-words "<what fixing it resumes>"`, and STOP. Never `--force`. **A draft already open** (a fix round): `reopen.md`'s update step, never a second `gh pr create`.

## At `accept`: run `close`

**Pass recorded or not.** On a required gate, clear it with the operator's literal words first: `gate <P> clear --words "<their words>"`; `close` then records the pass after its re-read. A waived gate's pass was recorded when its drafts opened, a legacy phase's at once: `close` needs that pass. The operator's `close` for a waived gate's draft, or a `pr_open=` hint saying the close is due, starts here too.

- **Not `done`:** a change request is `review <P> --verdict changes_requested --note "operator-reported: <what>"`; the gate resets and the fix round runs on the same branch.
- **`done`:** a change request, the operator's or the team's, always goes through `phase reopen` (`reopen.md`); never `review`, which the engine refuses.

Then `python3 scripts/workflow.py close <P>`, again after each stop until it prints `close=done`. It prints one `step=<name> state=…` line per step and `stop=<name> do=<what>`. It reads the PRs (`gh pr view`, `gh pr checks`) and records what it read, and it runs the engine's own steps itself: the pass, `worktree merge-finish`, `worktree teardown`, `check`. It never pushes, merges, flips a PR Ready or writes to GitHub. Those are yours, on the `accept`, at its stops:

- **`reread`:** the PR changed since its draft (or has no recorded draft state). Read what it names. **An edited title or body:** the operator's version is the record; write it into the body file and run `pr check`; a problem stops (`--stop-kind decision`); never overwrite their words. **New commits:** `git fetch origin`, `git merge --ff-only origin/<b>` (a non-fast-forward stops), `pr check`. **Comments and reviews:** skip the workspace's own (`## Details for this PR`); judge by content, never by author. **A change request is not an accept:** stop and route it as above; a question does not stop the close. Nothing stops: re-record the draft with the `pr record … --url` it prints. A closed PR: report it.
- **`ready`:** `gh pr ready <n>`.
- **`ci`:** red: the phase is `done`, so on the operator's word `phase reopen <P> --note "operator-reported: CI red: <checks>"` (`reopen.md`). Pending: the watch it prints.
- **`land`:** unrecorded solo or team: the walkthrough's "decided as drawn" detection line is what the accept signed; record it, `pr team --record solo|team [--repo <name>] --evidence "…"`; nothing signed, or `detected=unknown`: ask (`--stop-kind decision`). **Never merge a team repo's PR:** print, never run, `gh pr edit <n> --add-reviewer <login>` per `## Review` name. **Solo:** land by the repo's custom. A stated custom (its `CLAUDE.md`, `AGENTS.md` or `CONTRIBUTING`) wins: a repo that lands locally merges with its release step and pushes the default branch, never GitHub's merge button. No stated custom: `gh pr merge <n>` with the repo's only allowed method (`gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed`), else `--merge`. Never `--delete-branch`, `--admin` or a force-push. **When the head's CI was green, run no pre-push local smoke and no post-landing `gh run watch`:** the landing adds only the release stamp, which the repo's build check covers.
- **`merge`** (a worktree phase): its `commit-pass` step has already committed the pass on the branch (only the phase folder and the generated `works/` files; nothing else of yours). From the worktree, `worktree gate <P>` (advice, exit 0; `GATE CLOSED reason=…`: STOP, never merge past it); `ExitWorktree` with `action: "keep"`; in the main checkout (nested: `git -C workflow …`) `git pull --ff-only` only when an upstream exists; something staged, or an uncommitted file the merge touches: commit your own workflow state (`works/`) first, anything else STOP and ask, never unstage or discard; the `git merge --no-ff` it prints (a generated file's conflict: take either side; `phase.md` prose by hand). The branch review's `## Gate sections (written at merge)`: edit only that section of `docs/current/<qa|operations>.md`. Then `close <P>` there.
- **`teardown`:** what it lists are caches (`node_modules`, `.venv`, build output, an explain's `pages/`): `worktree teardown <P> --discard-ignored`. Each repo's product branch stays for its PR.
- **`commit`:** clean up (below), then one workflow commit holding the close's records (the `commit` skill; a linked checkout skips it).

**A change asked for after Ready**: on the operator's word, `phase reopen <P> --note "operator-reported: <what>"` (or `"team-reported: <what>"`) by `reopen.md`; never `review`, never a second PR. A stack closes bottom-up; accepting a phase stacked on an unmerged base defers its close until that base merges (`stack.md`).

## Clean up before the commit

Only what this phase started, identified by the names and ports its slices recorded in their results; never another project's, never the operator's.

- **Processes:** stop the session's own background tasks; for each recorded port, `lsof -ti tcp:<port>` and `kill <pid>` when the pid is the phase's server.
- **Containers:** `docker rm -fv <name>` (with its anonymous volumes); a named volume the phase created, `docker volume rm <name>`. Never a prune.
- **Merged head branches:** once the PR reads merged and `gh pr list --base <b> --state open` lists none, `git branch -d <b>` and `git push origin --delete <b>` (nested: `git -C <repo> …`); a checkout still on `<b>` switches to the default branch first. Never `-D`. `pr-assets` stays: the bodies' images live there.

The shipped settings allow exactly these commands in their plain form; a nested host's `git -C <repo> branch -d` and `git -C <repo> push origin --delete` each ask once per repo. Report what was stopped and removed.
