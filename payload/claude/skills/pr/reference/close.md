# The close: one ordered checklist

Closing a phase is written here and nowhere else. The orchestrator runs it, never an executor. In order:

1. **Open the drafts** when the review would pass, read each PR's CI, add screenshots for a changed user surface.
2. **At `accept`** (or the operator's `close` for a waived gate's draft, or a `pr_open=` hint saying the close is due; a close cut off resumes at its first unfinished step): A, re-read only if the PR changed, before the pass is recorded; B, Ready and the landing, after it.
3. **A worktree phase:** integrate.
4. **Clean up** what the phase started, and its merged head branches.
5. **One `validate` and one workflow commit.**

Accepting a phase stacked on an unmerged base defers its close until that base merges (`stack.md`).

## Open the drafts, when the review passes

The review would pass and every body passes `pr-check`. With no stop and no word, per recorded branch, bottom-up in a stack or series (`split.md`):

1. `git push -u origin <b>`, never `--force`.
2. `gh pr create --draft --base <base> --head <b> --title "<title>" --body-file <body>`. `<base>` exactly as `pr_branch=` prints it (a branch name, never `origin/…`); the title an imperative "what" in the repo's convention, with no phase or slice IDs. A refusal: `open.md`.
3. A details file: `gh pr comment <n> --body-file <details>`, point the body's details link at that comment's URL, re-run `pr-check`, then `gh pr edit <n> --body-file <body>`.
4. `python3 scripts/workflow.py pr-record <P> [--repo <name>] --branch <b> --url <url>`; a cross-repo series also updates the wave index in its first PR.
5. **Read the CI:** `gh pr checks <n>` (exit 8: pending). Red (`fail` or `cancel`) becomes a fix round **before the gate opens**, never after the accept: `review-phase <P> --verdict changes_requested --note "operator-reported: CI red: <checks>"`, fix slices, `reopen.md`'s update step. Pending: open the gate and wait with `gh pr checks <n> --watch --fail-fast` while the operator walks; read it again before B. No checks: say "no CI checks".
6. **Record the draft's state** for A: one line per PR in `topics/pr-draft.md` (`-<repo>` likewise), `<url> <headRefOid> <updatedAt> <comment count>`, from `gh pr view <n> --json headRefOid,updatedAt,comments --jq '[.headRefOid,.updatedAt,(.comments|length)]|@tsv'`.

**Screenshots**, only for a phase that changed a user surface, before that branch's push:

- capture each changed surface with `playwright-cli` (`screenshot --filename=<dir>/<surface>-after.png`, a before where it helps) outside every repo;
- push them to the repo's orphan **`pr-assets`** branch, one folder per PR named by its head branch (`/` as `-`), from a throwaway worktree, so no image enters the product tree: `git fetch origin pr-assets`; then `git worktree add -B pr-assets <tmp> origin/pr-assets`, or `git worktree add --orphan -b pr-assets <tmp>` when the fetch found none; copy the images into `<tmp>/<folder>/`; `git -C <tmp> add <folder>`; `git -C <tmp> commit -m "docs: screenshots for <b>"`; `git -C <tmp> push origin pr-assets` (never `--force`); note `git -C <tmp> rev-parse HEAD` as `<sha>`; `git worktree remove <tmp>`;
- link each as `![<surface>, after](../blob/<sha>/<folder>/<file>.png?raw=true)`: GitHub's form for a repo file in that repo's PR, pinned to the commit; it renders for viewers with read access, private repos included.

Then the walkthrough lines (each URL, what to read on GitHub, the CI state) open `accept-gate <P> --open`'s walkthrough, or are a waived gate's pass report.

**An open failure** (no `gh`, auth, the network, a refused push): the `REVIEW` slice `pending --stop-kind operator-action --on-words "<what fixing it resumes>"`, and STOP. Never `--force`, never the pass without the URL (the engine refuses it). **A draft already open** (a fix round): `reopen.md`'s update step, never a second `gh pr create`.

## At `accept`

**Pass recorded or not.** A waived gate's pass was recorded when its drafts opened, a legacy phase's at once, and a pre-v93 phase closes from its `pr_open=` hint: those reach the close `done`. On a required gate, A runs after `accept-gate <P> --clear` and before `review-phase <P> --verdict pass`; B runs after the pass.

- **Not `done`:** a change request is `review-phase <P> --verdict changes_requested --note "operator-reported: <what>"`; the gate resets and the fix round runs on the same branch.
- **`done`:** a change request, the operator's or the team's, always goes through `reopen-phase` (`reopen.md`); never `review-phase`, which the engine refuses.

### A. Re-read, only if the PR changed

1. `python3 scripts/workflow.py pr-sync <P>`. `state=merged`: nothing to land; record the pass if not `done`, then steps 4–5. `state=closed`: stop and report. A failure writes nothing: an `operator-action` stop naming its line.
2. One call, `gh pr view <n> --json headRefOid,updatedAt,comments`, against `topics/pr-draft.md`. All three unchanged: on to B.
3. Changed, read `title,body,commits,reviews` too:
   - **an edited title or body:** the operator's version is the record; write it into the body file and run `pr-check`; a problem stops (`--stop-kind decision`); never overwrite their words;
   - **new commits:** `git fetch origin`, `git merge --ff-only origin/<b>` (a non-fast-forward stops), `pr-check`, and the CI read again;
   - **comments and reviews:** skip the workspace's own (`## Details for this PR`); judge by content, never by author. **A change request is not an accept:** stop and route it as above; a question does not stop the close.

### B. Ready and land (after the pass)

1. `gh pr ready <n>`.
2. **Solo or team:** `python3 scripts/workflow.py pr-team [--repo <name>]`. Recorded: use it. Unrecorded: the walkthrough's "decided as drawn" detection line is what the accept signed; record it, `pr-team --record solo|team [--repo <name>] --evidence "…"`. Nothing signed, or `detected=unknown`: ask (`--stop-kind decision`).
3. **Team:** leave it for the team's merge; print, never run, `gh pr edit <n> --add-reviewer <login>` per `## Review` name.
4. **Solo, CI green:** every check `pass` or `skipping`, or none reported. `fail` or `cancel`: stop; the phase is `done`, so on the operator's word `reopen-phase <P> --note "operator-reported: CI red: <checks>"` (`reopen.md`).
5. **Land by the repo's custom.** A stated custom (its `CLAUDE.md`, `AGENTS.md` or `CONTRIBUTING`) wins: a repo that lands locally merges with its release step and pushes the default branch, never GitHub's merge button. No stated custom: `gh pr merge <n>` with the repo's only allowed method (`gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed`), else `--merge`. Never `--delete-branch`, `--admin` or a force-push. **When the head's CI was green, run no pre-push local smoke and no post-landing `gh run watch`:** the landing adds only the release stamp, which the repo's build check covers.
6. `pr-sync <P>`; report each URL and its state.

**A change asked for after Ready**: on the operator's word, `reopen-phase <P> --note "operator-reported: <what>"` (or `"team-reported: <what>"`) by `reopen.md`; never `review-phase`, never a second PR. A stack closes bottom-up.

## A worktree phase: integrate (after the pass)

1. `python3 scripts/workflow.py parallel-gate <P>` from the worktree. `GATE CLOSED`: STOP and report; never merge past a closed gate.
2. `ExitWorktree` with `action: "keep"`.
3. In the main checkout (nested: `git -C workflow …`): `git pull --ff-only` only when an upstream exists. Something staged, or an uncommitted file the merge touches: commit your own workflow state (`works/`) first; anything else, STOP and ask. Never unstage or discard.
4. `git merge --no-ff phase/P<N>-<slug> -m "merge(P<N>): <name>"`. A conflict in a generated file: take either side (step 5 regenerates); `phase.md` prose is merged by hand.
5. `python3 scripts/workflow.py parallel-merge-finish`.
6. The sections the branch review's `result.md` holds under `## Gate sections (written at merge)`: edit only that section of `docs/current/<qa|operations>.md`. None: skip.
7. `python3 scripts/workflow.py parallel-teardown <P>`, with `--discard-ignored` straight away in a nested install whose worktrees hold caches (`node_modules`, `.venv`, build output, an explain's `pages/`); at root `git worktree remove` drops them itself. Each repo's product branch stays for its PR (B lands it).

## Clean up before the phase finishes

Only what this phase started, identified by the names and ports its slices recorded in their results; never another project's, never the operator's.

- **Processes:** stop the session's own background tasks; for each recorded port, `lsof -ti tcp:<port>` and `kill <pid>` when the pid is the phase's server.
- **Containers:** `docker rm -fv <name>` (with its anonymous volumes); a named volume the phase created, `docker volume rm <name>`. Never a prune.
- **Merged head branches:** once `pr-sync` reads the PR merged and `gh pr list --base <b> --state open` lists none, `git branch -d <b>` and `git push origin --delete <b>` (nested: `git -C <repo> …`); a checkout still on `<b>` (a remote merge; a local landing already left it) switches to the default branch first. Never `-D`. `pr-assets` stays: the bodies' images live there.

The shipped settings allow exactly these commands in their plain form, so at root no prompt stops the cleanup. A nested host's `git -C <repo> branch -d` and `git -C <repo> push origin --delete` each ask once per repo: no shipped rule matches them, since a `*` before the subcommand would approve any git option there (Claude Code warns at startup on such a rule). Report what was stopped and removed.

## One validate, one commit

At the end, one `python3 scripts/workflow.py validate` and one workflow commit holding the close's records (the `commit` skill; a linked checkout skips it). Chain bookkeeping that needs no reading in between into one call (`pr-sync <P> && python3 scripts/workflow.py validate`): each call costs a turn of a large context.
