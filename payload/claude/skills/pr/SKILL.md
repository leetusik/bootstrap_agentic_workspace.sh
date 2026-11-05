---
name: pr
description: "Write, check and open a phase's pull requests under PR rule v1: one body per recorded branch, measured by pr-check, opened as drafts when the review passes."
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch --show-current), Bash(git branch --list:*), Bash(git rev-parse:*), Bash(git check-attr:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh api repos/*/community/profile), Bash(python3 scripts/workflow.py next), Bash(python3 scripts/workflow.py pr-check:*), Bash(python3 scripts/workflow.py pr-rules-decide), Read, Write, Edit, Glob, Grep
disable-model-invocation: true
---

# pr

A phase that changes product files ships as **one branch per repo it changed, one draft PR each**. This skill is the one procedure for writing, checking and opening those PRs. It is explicit-invocation only, like every workflow command-skill: the operator types `/pr`, and the review and the orchestrator read `.claude/skills/pr/SKILL.md` by path and follow it. Three callers use it:

- **the phase review's body step**, which writes and checks a body for each recorded branch, then hands back;
- **the orchestrator when the review passes**, which opens the drafts (*Open the drafts*), before the acceptance gate opens or the pass is recorded;
- **the operator by hand** (`/pr`), for a change made outside a phase: steps 2, 3, 5 and 6 below, with the body in a scratch file, checked with no phase by `python3 scripts/workflow.py pr-check --body <file> [--base <branch>] [--branch <b>]`. It measures the checked-out branch (or `--branch`) against `--base`, else the repo's default branch, and checks that body; there is no details file.

Nothing here is pre-allowed to write to a remote. `git push`, `gh pr create`, `gh pr comment`, `gh pr edit` and `gh pr ready` each reach the harness's permission prompt. The authority to open the drafts is the operator's run of the phase: no separate word is asked for. Recording (`pr-branch`, `pr-record`, `pr-rules-decide --rule`) is the orchestrator's, never an executor's.

## Write and check (the review's body step)

1. **Find the branches.** `python3 scripts/workflow.py next` prints one `pr_branch=<repo|host|root>:<b> base=<base> url=<url|none>` line per recorded branch; the phase's `phase.json` `pr` block holds the same. Write **one body per recorded branch**. A branch is recorded only in a repo the phase changed: there is no un-record command, so never record one speculatively.
2. **Read the team rules live**, read-only, every time (they are never cached):
   - PR templates: `.github/pull_request_template.md`, the `.github/PULL_REQUEST_TEMPLATE/` forms, and the root and `docs/` copies;
   - `CONTRIBUTING*` lines about PRs and review; `CODEOWNERS`;
   - tracked `AGENTS.md` and `CLAUDE.md` lines about PRs;
   - tracked agent skills about PRs: `.agents/skills/*/SKILL.md` and `.claude/skills/*/SKILL.md` whose name or description is about pull requests (a team's `create-pull-request`, say);
   - `gh api repos/<owner>/<repo>/community/profile`, when `gh` is authenticated;
   - the decided conflicts: `python3 scripts/workflow.py pr-rules-decide`, bare.

   **Precedence:** the team wins where it speaks (headings, title format, language, trailers, merge method); ours fills the gaps (the budgets, `## Review`, size, draft-first, the series line). A conflict nobody has decided goes into the "decided as drawn" list of the gate's walkthrough (or the pass report); the operator's answer is recorded afterwards with `pr-rules-decide --rule … --choice team|ours`.
3. **Write the body** to the phase's `topics/pr-body.md` (`works/phases/active/<P>/topics/`), or `topics/pr-body-<repo>.md` on a multi-repo host. Depth this review alone needs goes to `topics/pr-details.md` (`-<repo>` likewise), posted as one comment when the draft opens. Follow `reference/body.md`: the skeleton, the budgets, the visual rule and the prose rules. Write from the final diff, the commits, the issue and the phase's recorded decisions, never from the slice log.
4. **Check it.** `python3 scripts/workflow.py pr-check <P> [--repo <name>] [--branch <b>]`. Rewrite and re-run until it prints `pr_check=pass`. Only `warn` lines the body itself causes (a `leak_warn=`, a `review_heading=`) or the size (`size_flag=`, step 5), each justified in your hand-back, may end the loop at `pr_check=warn`; `body=missing` never ends it, since a missing body is never a pass. A fail is a budget, a leak or a heading line: shorten, move depth to the details file, or fix the heading. Never pad, abbreviate or game the counts.
5. **Size over the flag** (`size_status=flag`, over 1,000 counted lines): offer a split by `reference/split.md`, or a **named exception** (a first-of-feature drop, a fixture set, bulk tests) stated in `## Review` with its reason. Size never splits the phase itself.
6. **Hand back**, per branch: the body path (and details path), the `pr-check` lines, the size, the series line if any, the `<!-- screenshot -->` spots the operator must fill on GitHub, and the undecided team-rule conflicts for the gate's (or the pass report's) "decided as drawn" list.

## Open the drafts, when the review passes

The review's verdict would pass and the reader's one revision is done: open the drafts now, with no stop and no word. For each recorded branch, **bottom-up** in a stack or series (`reference/split.md`):

1. `git push -u origin <b>`, never `--force`.
2. `gh pr create --draft --base <base> --head <b> --title "<title>" --body-file <body>`. `<base>` is the recorded base exactly as `pr_branch=` prints it: a branch name (`main`, `feat/x-1`), passed as-is, never prefixed with `origin/`. The title is an imperative "what" in the repo's title convention, with no phase or slice IDs. **If GitHub refuses the draft** (drafts in private repos need a paid plan; the error names draft pull requests), retry **once** without `--draft`, request no reviewers, and say so in the report: in a solo repo that is the same preview.
3. When a details file exists: `gh pr comment <n> --body-file <details>`, take the comment's URL from its output, point the body's details link at it, re-run `pr-check` on the edited body, then `gh pr edit <n> --body-file <body>`.
4. `python3 scripts/workflow.py pr-record <P> [--repo <name>] --branch <b> --url <url>`
5. In a cross-repo series, update the wave index in the series' first PR (`gh pr edit` on its body, after `pr-check`).

Then print the walkthrough lines: each PR's URL, and what to read on GitHub (the first screen, the Review asks, the diagram's render, any screenshot spot to fill while previewing the draft). On a required gate they open the walkthrough passed to `accept-gate <P> --open`, and the operator's `accept` after reading the draft clears the gate; on a waived gate they are the pass report.

**An open failure** (no `gh`, no auth, the network, a refused push): set the `REVIEW` slice `pending --stop-kind operator-action --on-words "<what fixing it resumes>"` and STOP. Never retry with `--force`, and never record the pass without the URL (the engine refuses it).

**A draft already open** (a fix round after failures the operator reported on GitHub): at the next would-pass, push the fix commits (`git push`, never `--force`) and replace the body (`gh pr edit <n> --body-file <body>`, after `pr-check`). Never a second `gh pr create`.

## Ready, reviewers, merging

- **Ready is the operator's call.** In a draft, names are plain text, never `@`, so opening it notifies nobody. When the operator says a PR is ready, **print** (never run unasked) `gh pr ready <n>` and one `gh pr edit <n> --add-reviewer <login>` line per name in `## Review`.
- **Never merge a team repo's PR.** The workflow binds only the operator's own PRs and never tells a team when to merge; each repo merges by its own custom. A repo that lands locally (a `--no-ff` merge plus its release step, as its `CLAUDE.md` says) opens the draft for the read only: never use GitHub's merge button there.
- **Review replies** stay at most five lines and link the fixing commit; a longer answer becomes a body edit or a repo doc.
