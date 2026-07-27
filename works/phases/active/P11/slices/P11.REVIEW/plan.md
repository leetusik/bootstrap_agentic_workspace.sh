# P11.REVIEW — phase review

## Context

Both middle slices are landed and committed:

- **`P11.S1`** (`87b0912`) — deleted `.claude/agents/slice-planner.md`, applied all four installer
  edits (three removals plus the `OBSOLETE_MACHINERY` entry that tells v19 workspaces to remove the
  file by hand), rewrote the `do-whole-phase` rule from a mandated procedure into an **optional**
  use of the executor's idle window, mirrored it byte-equally into `CLAUDE.md`/`AGENTS.md`, and
  shipped workspace **v20**.
- **`P11.S2`** (`fb91424`) — three verbatim string fixes across both READMEs: `slice-executor-mid`
  is sonnet under the shipped `economy` default, the false "mid is the default" claim is gone, and
  `high` is named as the catch-all. No rebuild, no bump, no CHANGELOG entry (READMEs are not
  embedded machinery).

This slice validates the phase as a whole against `intent.md`, decides a verdict, and — **only on a
pass** — consolidates the two "Doc impact" notes into new doc versions and produces the phase
explainer.

Dispatch: **`slice-executor-high`** (review always). It writes **only docs** — never source, never
skills, never the contract, never the READMEs. Anything needing a fix is `changes_requested` with
proposed fix slices, not an edit.

## 1. Validate all of the phase's slices together

Run and report real outcomes:

- `python3 scripts/workflow.py validate` — state integrity; also catches a stale `docs/current`.
- `python3 installer/build.py --check` — artifact in sync with `installer/` source.
- `python3 scripts/workflow.py sync-agents --check` — exit 0 against the `economy` default.
- `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` — empty.
- `diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` — empty, and `git diff --stat` over both paths across the phase shows them untouched.
- **Live `slice-planner` references.** `grep -rn 'slice-planner'` excluding `.git/`, `works/`, and
  `docs/`. The only surviving hits should be `installer/main.py`'s `OBSOLETE_MACHINERY` entry, its
  mirror inside `bootstrap_agentic_workspace.sh`, and the historical `## v19` / `## v20` CHANGELOG
  sections. Anything else is a live reference that should not exist. (`docs/` is excluded because
  fixing it is this slice's own job, below.)
- **Fresh end-to-end install probe** into an unused scratch dir (`<scratchpad>/probe-p11-review`):
  in the *probe*, `.claude/agents/` holds exactly the three `slice-executor-*` files;
  `works/.workspace-version.json` shows `workspace_version: 20`; `grep -rl 'slice-planner'` over the
  probe returns nothing; the optional-practice wording (including `Explore`) is present in
  `do-whole-phase/SKILL.md` and the "Idle-window preparation" bullet in both contracts. If it
  genuinely cannot run, say so explicitly rather than skipping silently.

## 2. Review against the objective, `intent.md`, and the results

Read `intent.md`, `phase.md`, and both `result.md` files, then judge:

- **Did the rule actually become a permission?** This is the heart of the phase, and it is a
  judgement about tone as much as content. Read the new `do-whole-phase` bullet and the contract's
  Hard Rules bullet cold and ask whether an orchestrator would read them as *"you may, and here is
  how to judge it"* or as *"do this, unless…"*. The operator's words: *"I just want to give a free
  to the orchestrator… it's an option not mandatory."*
- **Did the hard invariants survive the relaxation?** read-only; no second executor; never block;
  discard on any non-`done` verdict; scratchpad-only and advisory; the approval gate unmoved. And
  confirm the neighbours are intact: the delegation rule, `auto`'s safety halts, the escalation
  ladder, `plan only` / `ready`, "each slice owns exactly two context files", and P10's copy-based
  plan capture (explicitly out of scope this phase).
- **Is the removal complete and honest?** All four installer edits present; `OBSOLETE_MACHINERY`
  actually reachable on `--update`; no orphaned mention of a deleted agent in live machinery.
- **Do the two READMEs now agree** with each other and with `executors.toml`'s documented `economy`
  default?

**One item `P11.S1` referred to this review.** Its `result.md` records a deviation against the
*plan's expectation*, not the work: the plan asserted `grep -c 'slice-planner'
bootstrap_agentic_workspace.sh` should be `0`, which contradicted the same plan's requirement to add
an `OBSOLETE_MACHINERY` entry — the artifact embeds `installer/main.py`, so the retirement line
necessarily rides in it. The real count is 1. Confirm that reading, and that the check's *intent*
(no payload mentions the agent) holds via the probe.

Also record in `result.md`, for the orchestrator to file afterwards: whether any deferred job is
still worth opening. The P10-era `slice-planner`-outside-`EXECUTOR_TIERS` follow-up should now be
**dissolved** by the deletion — say so explicitly if you agree, so it is not carried forward as an
open item.

## 3. On a pass — consolidate the docs

Only on `pass`, via `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..."
--source P11.REVIEW`, then write the new version body. Never patch `docs/current/*.md` or an old
version. A new version is the whole doc carried forward, not a diff.

- **`operations.md`** (v0018 → next) — recast the v19 section *Pipelined slice planning — the
  `slice-planner` prefetch* as the v20 optional idle-window practice: no prescribed mechanism
  (`Explore`, inline reading, thinking, or waiting), the surviving invariants, the five conditions
  as guidance rather than gates, and the agent's removal with its `OBSOLETE_MACHINERY` migration
  note. The v19 mentions at roughly `:33`, `:81`, `:356` need the same treatment — the phase note
  flags them; verify against the actual current file rather than trusting the line numbers.
- **`decisions.md`** (v0024 → next) — this is a decisions log, so **supersede rather than erase**:
  keep P10's decision as history, mark it superseded by P11, and record the new decision — drop the
  bespoke agent for plain harness behaviour and make the practice optional. State the weakened
  guarantee plainly: v19's read-only property came from a `Read, Glob, Grep` allowlist; `Explore`
  has `Bash` and inline research is bounded only by the orchestrator's discipline, so read-only is
  now a rule to follow, not a structure that enforces itself. Record what was bought in exchange (no
  fourth managed agent surface, no agent outside `EXECUTOR_TIERS`, no pinned model drifting from the
  presets, and a rule that reads as a permission).

Then confirm `python3 scripts/workflow.py validate` is still clean.

## 4. On a pass — auto-explain (best-effort, verdict-neutral)

Produce the phase explainer via the installed knowledge-plugin explain skill, exactly as
`.claude/skills/review-phase/SKILL.md` specifies.

**Changed since the last review:** the knowledge base is now wired to production —
`~/.config/knowledge-kb/config.json` points `api.base_url` at `https://knowledge.hi2vi.com` with a
valid token (verified: `GET /api/documents` → 200). So expect a real **201** from the API, not the
offline file fallback P10 took. Per the skill, on an HTTP error you **must not** fall back to a file
write: report `failed (<status>)`. Report the outcome as `saved <url>` / `skipped (<reason>)` /
`failed (<reason>)`. **It never changes the verdict.**

## 5. Report

Write `works/phases/active/P11/slices/P11.REVIEW/result.md`: the validation table with real
outcomes, the verdict and its reasoning, how the referred item was decided, the doc versions
created, and the auto-explain outcome. Append any durable notes to `phase.md`.

Return `review_verdict` (`pass` | `changes_requested` | `blocked`), `doc_versions`, and `explain`.
On `changes_requested`, propose numbered fix slices (`P11.F1`, …) with a one-line scope each. You
never commit and never transition slice/phase status — the orchestrator records the verdict with
`review-phase`.
