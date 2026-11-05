---
name: pr
description: "Write, check, open and close a phase's pull requests under PR rule v1: one body per recorded branch, measured by pr-check, opened as drafts when the review passes, closed on the operator's accept."
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch --show-current), Bash(git branch --list:*), Bash(git rev-parse:*), Bash(git check-attr:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh pr checks:*), Bash(gh api repos/*/community/profile), Bash(python3 scripts/workflow.py next), Bash(python3 scripts/workflow.py pr-check:*), Bash(python3 scripts/workflow.py pr-rules-decide), Bash(python3 scripts/workflow.py pr-team), Read, Write, Edit, Glob, Grep
disable-model-invocation: true
---

# pr

A phase that changes product files ships as **one branch per repo it changed, one draft PR each**. This skill is the one procedure for writing, checking, opening and closing those PRs. It is explicit-invocation only: the operator types `/pr`, and the review and the orchestrator read `.claude/skills/pr/SKILL.md` by path and follow it. Four callers use it:

- **the phase review's body step**, which writes and checks a body for each recorded branch, then hands back;
- **the orchestrator when the review passes**, which opens the drafts (*Open the drafts*), before the acceptance gate opens or the pass is recorded;
- **the orchestrator on the operator's `accept` or `close`**, which runs the close;
- **the operator by hand** (`/pr`), for a change made outside a phase: steps 2, 3, 5 and 6 below, with the body in a scratch file, checked with no phase by `python3 scripts/workflow.py pr-check --body <file> [--base <branch>] [--branch <b>] [--limit <n>]`. It measures the checked-out branch (or `--branch`) against `--base`, else the default branch; no details file.

Nothing here is pre-allowed to write to a remote. `git push`, `gh pr create`, `comment`, `edit`, `ready` and `merge` each reach the harness's permission prompt. **Drafts open automatically** when the review passes: the operator's run of the phase is the authority, and the only opt-out is waiving the phase's PR (`pr-record <P> --waive --note "why"`). Recording (`pr-branch`, `pr-record`, `pr-sync`, `pr-team --record`, `pr-rules-decide --rule`) is the orchestrator's, never an executor's.

## Write and check (the review's body step)

1. **Find the branches.** `python3 scripts/workflow.py next` prints one `pr_branch=<repo|host|root>:<b> base=<base> url=<url|none>` line per recorded branch; the phase's `phase.json` `pr` block holds the same. Write **one body per recorded branch**. A branch is recorded only in a repo the phase changed: there is no un-record command, so never record one speculatively.
2. **Read the team rules live**, read-only, every time (they are never cached):
   - PR templates: `.github/pull_request_template.md`, the `.github/PULL_REQUEST_TEMPLATE/` forms, and the root and `docs/` copies;
   - `CONTRIBUTING*` lines about PRs and review; `CODEOWNERS`;
   - tracked `AGENTS.md` and `CLAUDE.md` lines about PRs;
   - tracked agent skills about PRs: `.agents/skills/*/SKILL.md` and `.claude/skills/*/SKILL.md` whose name or description is about pull requests (a team's `create-pull-request`, say);
   - `gh api repos/<owner>/<repo>/community/profile`, when `gh` is authenticated;
   - the decided conflicts: `python3 scripts/workflow.py pr-rules-decide`, bare.

   **Precedence:** the team wins where it speaks (headings, title format, language, trailers, merge method, a size limit: note its line; none stated, no limit); ours fills the gaps (the budgets, `## Review`, draft-first, the series line). A conflict nobody has decided goes into the "decided as drawn" list of the gate's walkthrough (or the pass report); the operator's answer is recorded afterwards with `pr-rules-decide --rule … --choice team|ours`.
3. **Write the body** to the phase's `topics/pr-body.md` (`works/phases/active/<P>/topics/`), or `topics/pr-body-<repo>.md` on a multi-repo host. Depth this review alone needs goes to `topics/pr-details.md` (`-<repo>` likewise), posted as one comment when the draft opens. Follow `reference/body.md`: the skeleton, the budgets, the visual rule and the prose rules. Write from the final diff, the commits, the issue and the phase's decisions, never the slice log.
4. **Check it.** `python3 scripts/workflow.py pr-check <P> [--repo <name>] [--branch <b>] [--limit <n>]` (`--limit`: a team limit, step 2). Rewrite and re-run until `pr_check=pass`. Only `warn` lines the body itself causes (a `leak_warn=`, a `review_heading=`) or `size_over=` (step 5), each justified in your hand-back, may end the loop at `pr_check=warn`; `body=missing` never does. A fail is a budget, a leak or a heading line: shorten, move depth to the details file, or fix the heading. Never pad, abbreviate or game the counts.
5. **Size.** `size_status=info` (no team limit): nothing to do. `over` the team's limit: a split (`reference/split.md`) or a **named exception** (a first-of-feature drop, a fixture set, bulk tests) stated in `## Review` with its reason, listed under "decided as drawn". Size never splits the phase.
6. **Hand back**, per branch: the body path (and details path), the `pr-check` lines, the size, the series line if any, the `<!-- screenshot -->` spots the operator must fill on GitHub, and the undecided team-rule conflicts for the gate's (or the pass report's) "decided as drawn" list.

## Open the drafts, when the review passes

The review's verdict would pass and the reader's one revision is done: open the drafts now, with no stop and no word. For each recorded branch, **bottom-up** in a stack or series (`reference/split.md`):

1. `git push -u origin <b>`, never `--force`.
2. `gh pr create --draft --base <base> --head <b> --title "<title>" --body-file <body>`. `<base>` is the recorded base exactly as `pr_branch=` prints it: a branch name (`main`, `feat/x-1`), passed as-is, never prefixed with `origin/`. The title is an imperative "what" in the repo's title convention, with no phase or slice IDs. **If GitHub refuses the draft** (a private repo on a free plan), never retry it as a plain PR, which notifies people: stop for the operator's `plain` or `waive` (`reference/open.md`).
3. When a details file exists: `gh pr comment <n> --body-file <details>`, take the comment's URL from its output, point the body's details link at it, re-run `pr-check` on the edited body, then `gh pr edit <n> --body-file <body>`.
4. `python3 scripts/workflow.py pr-record <P> [--repo <name>] --branch <b> --url <url>`
5. In a cross-repo series, update the wave index in the series' first PR (`gh pr edit` on its body, after `pr-check`).

Then print the walkthrough lines: each PR's URL, and what to read on GitHub (the first screen, the Review asks, the diagram's render, any screenshot spot to fill while previewing the draft). On a required gate they open the walkthrough passed to `accept-gate <P> --open`, and the operator's `accept` after reading the draft clears the gate; on a waived gate they are the pass report.

**An open failure** (no `gh`, no auth, the network, a refused push; an adopter's blanket `Bash(git push:*)` deny refuses it outright: deleting the deny restores the prompt): set the `REVIEW` slice `pending --stop-kind operator-action --on-words "<what fixing it resumes>"` and STOP. Never retry with `--force`, and never record the pass without the URL (the engine refuses it).

**A draft already open** (a fix round on it): `reference/reopen.md`'s update step. Never a second `gh pr create`.

## Ready, merging, stacks, reopening

- **Ready runs at the close** (`reference/close.md`), on the operator's `accept` or `close`, never before. A draft's names are plain text, never `@`: it notifies nobody.
- **Never merge a team repo's PR**; the close leaves it Ready and prints the reviewer lines. A solo repo merges by its own custom: in a repo that lands locally, never GitHub's merge button.
- **A phase stacked on an open PR** (`pr_stack=`): `reference/stack.md`. **Team changes after the phase is done**: `reference/reopen.md`.
- **Review replies** stay at most five lines and link the fixing commit.
