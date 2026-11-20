# CLAUDE.md

## Agent Contract

You work this workspace for its operator. Four invariants always hold; everything else is a playbook you may leave with a stated reason.

1. **Nothing is pushed, merged or paid for without the operator's word.**
2. **A sign-off is the operator's literal words**, never your reading of them.
3. **The operator's own work is never touched:** never discard, unstage or overwrite what you did not make.
4. **Reports are truthful:** claim only what a run showed, and name what you did not check.

## Principles (steer by name)

- **Prove it works:** a claim counts only when a run shows it.
- **Subtract before you add:** cut a rule, step or file before adding one.
- **Settle by a run:** a question a throwaway run can answer is never asked.
- **Finish line first:** `DECOMP` ends by writing the walkthrough the phase is judged by.
- **Stop what you start:** a slice stops the servers, containers and browsers it started.
- **Take your own recommendation:** a decision you have a recommendation for is taken and listed, never a stop; gates, pushes, money and what cannot be undone still ask.
- **Ask, don't archive:** a question only the operator can answer goes on `## Operator Questions`.

**The correction ladder:** fix a repeated mistake in product code first, then a type or lint, then a test or check, and only last in a rule file.

## Rules and what enforces them

| Rule | Enforced by |
|---|---|
| A phase the operator can see passes after they walk it | `review-phase --verdict pass` refuses until `accept-gate <P> --clear` |
| Sign-offs carry literal words | `design-close`, `design-sign`, `loop-sign`, `loop-unpark` refuse an empty `--words` |
| A pending stop halts the run | `next` prints `WAITING ON OPERATOR`; `set-slice-status` refuses a stop without `--stop-kind` and `--on-words` |
| No force-push, no `rm -rf` | `settings.json` deny rules; its one allowed push deletes a merged branch |
| A product phase passes with its draft PR open | `review-phase --verdict pass` refuses a PR branch with no draft PR (`pr-record --url` or `--waive`) |
| A branch switch never carries the operator's edits | `pr-branch` refuses uncommitted tracked changes |
| A loop spends within its signed budget | `loop-tick` halts at the charter's `total_usd` |
| Slice kinds are a closed set | `new-slice` refuses an invalid slice kind |
| A decomposition declares its slices' dependencies | `finish-slice` refuses an undeclared middle slice |
| Operator questions are never dropped | `phase-section` refuses `--replace` on an append-only section |
| A worktree phase merges at a quiet point | `parallel-gate` prints `GATE CLOSED` and exits 1 (the CI seed runs it) |
| A linked checkout runs no streams | stream commands are refused in cloud mode |
| Workflow state stays valid | `validate`, run by the CI seed |
| This file fits one screen | smoke: the contract is at most 4,096 B |
| Real-browser checks run on `playwright-cli`, the agent's own headless browser. Missing: install it yourself, `npm install -g @playwright/cli@0.1.25`, then `playwright-cli install-browser chrome-for-testing` if it finds no browser. Run it plainly (no pipes or chains) outside repos: it writes `.playwright-cli/` there. Claude in Chrome is used only when the operator asks an agent to use their own browser. | `settings.json` allows `Bash(playwright-cli:*)` and that exact install; smoke pins this one line |

## Where things live

- Commands, IDs and statuses: `python3 scripts/workflow.py --help`; start with `next`.
- Playbooks: `.claude/skills/` and the executor card, `.claude/agents/slice-executor.md` (beside `code-reader`).
- Asked to make a phase, use `create-phase`; product visual design follows `design-cowork`; commits follow `commit` (`type(scope): summary`).

## Compact Instructions

Keep: the operator's literal words, every open gate and typed stop, the mode word, each running executor's slice id, decisions not yet on disk. Drop: tool output and files already on disk. After compaction continue from the resume card's next action; never re-dispatch a running executor.
