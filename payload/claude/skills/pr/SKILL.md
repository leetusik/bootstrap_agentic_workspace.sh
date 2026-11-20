---
name: pr
description: "Write, check, open and close a phase's pull requests under PR rule v1: one body per recorded branch, measured by pr check, opened as drafts when the review passes, closed on the operator's accept."
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch --show-current), Bash(git branch --list:*), Bash(git rev-parse:*), Bash(git check-attr:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh pr checks:*), Bash(gh api repos/*/community/profile), Bash(python3 scripts/workflow.py next), Bash(python3 scripts/workflow.py pr check:*), Bash(python3 scripts/workflow.py pr rules), Bash(python3 scripts/workflow.py pr team), Read, Write, Edit, Glob, Grep
disable-model-invocation: true
---

# pr

A phase that changes product files ships as **one branch per repo it changed, one draft PR each**. This skill writes and checks the bodies; `reference/close.md` is **the close**: the drafts opening when the review passes, then the engine's `close <P>` at the operator's accept, step by step to the last commit. Callers read this file by path:

- the review's executor: *Write and check* below, then it hands back;
- the orchestrator: `reference/close.md`, from the review's would-pass to the phase's end;
- the operator by hand (`/pr`), for a change made outside a phase: steps 2, 3, 5 and 6 below, the body in a scratch file, checked by `python3 scripts/workflow.py pr check --body <file> [--base <branch>] [--branch <b>] [--limit <n>]`.

**The operator's run of the phase is the word for the draft's push**; Ready and the merge wait for their `accept`, and waiving the PR (`pr record <P> --waive --note "why"`) is the only opt-out. No remote write is pre-allowed here: `git push` and `gh pr create|comment|edit|ready|merge` reach the permission prompt, bar the close's deletion of a merged head branch, which the shipped settings allow. Recording (`pr branch`, `pr record`, `pr sync`, `pr team --record`, `pr rules --rule`) is the orchestrator's.

## Write and check (the review's body step)

1. **Find the branches.** `next` prints `pr_branch=<repo|host|root>:<b> base=<base> url=<url|none>` per recorded branch. Write one body per branch.
2. **Read the team rules live**, every time: PR templates (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`, the root and `docs/` copies), `CONTRIBUTING*` and `CODEOWNERS`, tracked `AGENTS.md` / `CLAUDE.md` lines and agent skills about PRs (`.agents/skills/*/SKILL.md`, `.claude/skills/*/SKILL.md`), `gh api repos/<owner>/<repo>/community/profile`, and the decided conflicts (`pr rules`, bare). **The team wins where it speaks** (headings, title, language, trailers, merge method, a size limit); ours fills the gaps (the budgets, `## Review`, draft-first, the series line). An undecided conflict goes on the "decided as drawn" list; the operator's answer is recorded with `pr rules --rule … --choice team|ours`.
3. **Write the body** to `topics/pr-body.md` (`-<repo>` on a multi-repo host), depth to `topics/pr-details.md`, from the walkthrough as it ran, the final diff and the phase's decisions, by `reference/body.md`.
4. **Check it.** `python3 scripts/workflow.py pr check <P> [--repo <name>] [--branch <b>] [--limit <n>]` until `pr_check=pass`. Only a `warn` the body causes (`leak_warn=`, `review_heading=`) or `size_over=`, each justified, may end at `warn`; `body=missing` never does. Never pad, abbreviate or game the counts.
5. **Size.** `size_status=info`: nothing to do. `over` the team's limit: a split (`reference/split.md`) or a named exception stated in `## Review`, listed as "decided as drawn". Size never splits the phase.
6. **Hand back** per branch: the paths, the `pr check` lines, the size, and the undecided team-rule conflicts.

## Ready, merging, stacks, reopening

- **Ready runs at the close**, on the operator's `accept` (or `close`), never before. A draft's names are plain text, never `@`.
- **If GitHub refuses the draft** (a private repo on a free plan), never retry it as a plain PR, which notifies people: stop for the operator's `plain` or `waive` (`reference/open.md`).
- **Never merge a team repo's PR.** A solo repo merges by its own custom; one that lands locally never uses GitHub's merge button.
- The `pr-reader` runs only when the operator asks, or for a team repo with PR rules (`adapter.py route --reader`); `pr check` checks every body.
- **A phase stacked on an open PR:** `reference/stack.md`. **Changes after the phase is done**: `reference/reopen.md`.
- **Review replies** stay at most five lines and link the fixing commit.
