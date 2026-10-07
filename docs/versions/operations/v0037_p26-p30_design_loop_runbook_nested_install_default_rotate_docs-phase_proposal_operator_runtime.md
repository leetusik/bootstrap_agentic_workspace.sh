---
doc_id: operations
version: v0037
created_at: 2026-10-07T16:59:38+09:00
commit: 455b62502396aa23946e3f57bec298f597e87e43
source: P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW
summary: P26-P30 design loop runbook, nested install default, rotate docs-phase proposal, Operator Runtime
previous: v0036_p24_fix_the_parallel_execution_block_still_carries_and_mirrors_the_consolidation_debt
---

# Operations

## Status

Adoption is documented three ways. The **default install is nested and private** (since v50):
`sh bootstrap_agentic_workspace.sh <dir>` keeps the engine and state in an untracked nested repo
`<dir>/workflow/` and the skills and agents untracked in the host's `.claude/`, and changes no tracked
file (README *Private use in a repo you don't own (the default install)*; see *Nested personal
install* below). **`--at-root`** installs the committed, team-visible layout into a fresh empty dir
(README Quickstart), and a **non-destructive retrofit** into an existing repo (`--into-existing` / the
`/retrofit` skill) is the at-root retrofit. Once adopted, a workspace is kept current with upstream via
the **update** path (`--update` / the `/update-workspace` skill), which **detects the installed
layout**. Full retrofit runbook: [`docs/retrofit-guide.md`](../../retrofit-guide.md).

The distributable `bootstrap_agentic_workspace.sh` is now a **build product**
assembled from an `installer/` source tree — maintainers edit live repo files (or
`installer/payloads/` for fresh-install-only seeds) and run `python3
installer/build.py`, never editing the artifact by hand. Workspaces are now
**versioned**: an integer `WORKSPACE_VERSION` is stamped into each target's marker
and a root `CHANGELOG.md` records what each version brings, which `/update-workspace`
surfaces as "you're on vN → upstream vM". See *Building and releasing the installer*
below. As of **v26**, the `/explain` educational-explainer **ships with the workspace
again**, reversing v15's retirement — it is operator-invoked only and sets a knowledge
base up on first use, on the hosted service at `knowledge.hi2vi.com`. The
`--with-explain` flag stays retired; `explain` is unconditional now. See *`/explain`
ships with the workspace again* below.

As of **v31 the workspace ships Claude Code only** — Codex support is removed. One
contract (`CLAUDE.md`, no `AGENTS.md` twin), one set of entry points (`.claude/`), one
set of **17 workflow skill packages** (18 by v49), and the two `.claude/agents/slice-executor-{mid,high}.md`
tiers (a third agent file, the `design-drafter` subagent, since v47). The `.agents/` skill mirror, `.codex/config.toml`, and the `.codex/agents/*.toml`
executors are gone from the repository and from the installer payload; the v29 dual-harness
inventory, Codex's automatic-only execution skills, and the harness-specific preset halves
described below in earlier form all went with them. Claude Code keeps default `auto` plus
opt-in `gate` and `plan only`. Commits and saved explainers still identify the model that
actually performed the work rather than a hard-coded default. **Adopters:** see
*Updating an adopted workspace to upstream* — an update flags the retired trees instead of
deleting them, and never touches an `AGENTS.md` your repo maintains for other tools.

As of **v32 a phase can carry an operator acceptance gate**: a phase that changes
operator-visible surfaces declares itself at the `DECOMP` boundary, and its review cannot be
recorded as a `pass` until the operator has walked the running product and cleared the gate. The
same release makes the **operator's runtime** durable truth (a seeded `## Operator Runtime` section
in the operations doc that any "verified in a real browser" claim must verify in), turns the seeded
`## Regression Checklist` into a **cumulative product smoke list**, and gives the review executor
stages it performs itself against the running product. All of it is conditioned on the phase's
declaration, so a machinery-only repo — this one included — is untouched. See *The operator
acceptance gate* below.

As of **v34 a design round ends at running code, and the phase's shape is named.** The operator
picks one of three styles — **`build-after`** (`DECOMP` -> groundwork -> design round(s) ->
`DECOMP2` -> build slices), **`design-only`** (a design phase, then a separate apply phase; it must
be chosen at `/create-phase`), or **`paired`** (design 1 -> apply 1 -> design 2 -> apply 2 in one
phase, with no `DECOMP2`) — recorded in the phase's `intent.md` under `## Design Style`. A design
slice then ran **inline -> dispatched -> inline** and stopped `pending` **twice**, the second stop
being the approval, taken on a **runnable mockup** built in the project's own frontend — **v42
reshapes that** (next paragraph but one). `--kind` became a **closed set** enforced by
the engine, and `create-phase` became agent-runnable **on instruction**, the second model-invocable
skill. See *Visual-design runbook* below.

Running the workflow: every slice — including the phase **review** — is executed by a `slice-executor` tier subagent (risk-routed by the orchestrator; see *Executor tiers* below). As of **v23** there are **two** tiers, not three: the `low` tier is retired, `slice-executor-mid` takes a one-line (or few-line) code edit or docs, and `slice-executor-high` takes everything else — essentially all code writing, and every cross-file change. Until **v38**, durable docs were versioned **once per phase, at the review slice** — the executor consolidated the phase's "Doc impact" notes (left in `phase.md` by earlier slices) into new versions on a passing review, rather than per slice; the read-only `phase-reviewer` is retired. **v38 moved that work to a docs phase the operator creates**, after P21 measured the review's own consolidation read at 90–97% of its budget; a passing review now only **verifies** the "Doc impact" list and writes its two named gate sections. See *Durable-doc consolidation — a docs phase the operator creates* below. As of **v21** the review's pass/fail branching is unchanged: a `changes_requested` or `blocked` verdict **stops** the review executor before any doc work and hands the phase back with numbered findings and proposed fix slices, and the review **no longer writes a phase explainer at all** (this supersedes v16's auto-explain) — it reports the fixed pointer `explain: not written — run /explain for this phase`, and explaining is a separate operator-run step. See *The phase review — validate, then branch on the verdict* below. As of **v17**, the plugin-free **env-var/REST path is the documented default** for reaching a knowledge base — two exports in `~/.zshenv` let `/explain` save the explainer over plain REST — and a freshly bootstrapped workspace ships the same guidance in its own seed `operations.md`. **v26 supersedes this**: the shipped `explain` skill sets a knowledge base up on first run, and the env vars became the override for an existing base, hosted or self-hosted. See *Knowledge setup* below. As of **v19**, the `do-whole-phase` loop may spend an executor's idle window preparing the *next* slice and then reconcile instead of re-researching; **v20** retired the bespoke `slice-planner` agent and recast that from a mandated procedure into an optional, mechanism-free judgment call. In the default automatic path the orchestrator writes its inline plan directly to `plan.md`; only the gated modes copy the operator-approved harness plan file. See *Idle-window preparation* and *Persisting plans* below. As of **v24** a phase may optionally run on its **own branch and git worktree** instead of the shared default stream: six `parallel-*` commands cover the whole lifecycle, the workspace ships **CI** (`.github/workflows/workspace-ci.yml`), a new **`parallel-phase`** skill carries the runbook, and a parallel phase's passing review **defers** its doc consolidation to a serialized post-merge step on the default stream. Everything about the default single-stream flow was unchanged then; **v42 makes the worktree the default** (below). See *Phase worktrees* below. As of **v25**, the no-mode execution default is **`auto`** — plan inline → write `plan.md` → dispatch the executor — while `gate` and `plan only` remain opt-in approval paths (**v31**: these are simply *the* modes; there is no second harness to narrow them to).

As of **v35** the phase notebook is **bounded state, not an append-only log**: `phase.md` is seeded from `works/templates/phase.md` into fixed sections, carries an engine-generated `## Slices` table between two markers, and is **edited** by each slice under a soft budget that `validate` warns about and `finish-slice` prints — while each slice's `result.md` stays the log and leads with its verdict block. **v39 replaced v35's 200-line / 16 KB pair with a single soft byte cap, 400 KB (~100k tokens)**, dropping the line ceiling; both numbers are still printed, but only bytes are judged, and it stays warning-only (advisory, exit 0). `finish-slice` takes `--outcome "one line"` for the table, reads across the whole workflow become **just in time** (the `docs/current/` *sections* the work touches, never the whole doc set and never `docs/index.json`), and the two markdown dashboards lost their `- Rebuilt at:` line. See *The phase notebook and just-in-time reads* below.

As of **v36** the closed `--kind` set has **eight** members: `research` joins it as a **findings-only** kind, and executor-tier routing is stated **kind-first** — `decomposition`, `research` and `review` always reach `slice-executor-high` whatever their `risk` says, so a `low` rating can no longer route any of them down. The same release names the **instrument** for real-browser work — **Aside** — which the verification doctrine had demanded since v32 without ever saying *with what*; the seeded `## Operator Runtime` manifest gains one **optional** field for it. **v37 corrects the surface half of that and adds the missing safety half**: Aside has **two** surfaces rather than three, the prescribed default is **`aside repl` over Bash** (executor-driven, and explicitly *not* a standing `aside mcp` registration, whose one tool definition costs ~1,344 tokens in every session, browser-related or not — `claude mcp add -s local aside -- aside mcp` survives only as a per-operator escape hatch the workspace neither ships nor prescribes), and agent runs happen on a **dedicated Aside profile** named per invocation, which gives the manifest a **second, conditionally required** field and the doctrine a **third** halt. No engine change in either release. See *Executor tiers* and *The operator runtime manifest* below, and the qa doc's *Verification doctrine* for the instrument itself.

As of **v42 the per-phase git worktree gained its working shape, and a design round closes on the
operator's return.** (v42 also made the worktree the **default** for every phase; **v43 reversed that
one decision** — see the next paragraph — while keeping everything else here intact.) The engine half:
a phase moves into its worktree through `parallel-start <P>`, and the orchestrator enters the printed
path in the same session (`EnterWorktree`). `parallel-start` no longer needs a clean tree: a dirty or staged default checkout
stays behind untouched, the stamp commit contains **exactly** the phase folder plus the five
regenerated `works/` files (`git commit --only`), and the worktree is cut under
`<repo>/.claude/worktrees/P<N>-<slug>`, hidden by a line the engine writes to `.git/info/exclude`
(never `.gitignore`). Integration is a **local `git merge --no-ff`**
after `parallel-gate` opens; push → PR → CI → `gh pr merge` is the remote variant, only when the
operator asks. The two gate sections a branch review may not write are **recorded** as tagged
`## Doc impact` notes and written at the merge. The design half: every card path a handoff names
carries a **two-digit reading-order prefix**, **the operator's return closes the round** — their
literal "done" at PENDING #1 is the approval and `SIGNOFF.md` records their words, after the
card-contract and concreteness checks — and a **runnable mockup is built only when the operator asks
for one** (`Mockup: requested` under `## Design Style`); PENDING #2 exists only then, as the gate on
that mockup. The eight worktree rules are written out once, in the contract, the `parallel-phase`
skill and *Phase worktrees* below. See also *Visual-design runbook*.

As of **v43 the phase worktree is opt-in again: a phase runs on the current checkout — the default
stream — unless the operator asks for one.** v42 had put every phase on its own branch in its own
worktree at first execution, so every ordinary run bought a stamp commit, a branch, a nested checkout
and an integration sequence to get back, for parallelism almost no run used. v43 changes **only how
the worktree is reached**; the mechanism in *Phase worktrees* below is unchanged in every particular.
Asking has three forms: the **`worktree`** mode word on `/do-next-slice` / `/do-whole-phase` (or the
same thing in the operator's own words), `parallel-start <P>` run by the operator's own hand, or an
explicit instruction to run two phases at once. The do-* skills never run `parallel-start` on their
own initiative and `create-phase` still never does. The engine's hints went back to **suggestions**
that fire only where a worktree pays — a `planned` phase queued behind an `in_progress` one, from both
`next` and `new-phase` — and are silent in the ordinary one-phase-at-a-time run; the rule everywhere
is **relay a hint, never act on it**. `parallel-skip <P>` and `new-phase --on-main` are **retired
no-ops** that write nothing and report where the phase already runs: the default stream needs no
marker. A docs phase needs no pin either — the rule that replaces it is stated directly: **never ask
for a worktree on a docs phase**, since `doc-new-version` / `docs-consolidated` only work on the
default stream. Phases still carrying v42's `execution: {"mode": "default"}` pin keep it, still
validate, and are **refused** by `parallel-start` rather than silently overridden.

As of **v38** durable-doc consolidation moved out of the review and into a docs phase the
operator creates: a passing review now only **verifies** the phase's "Doc impact" list and
writes its two named gate sections (`## Regression Checklist` in qa, `## Operator Runtime`
here), while the engine stamps a top-level `consolidation: "pending"` field on the phase's
`phase.json`; an owing phase validates but stays in `active/`, and archiving refuses it until
the operator pays the debt. `next` prints `consolidation_owed=<phases>` and `validate` warns,
both advisory (exit 0). **v39** adds explicit staleness on top: the `docs` listing prints a
per-doc last-updated marker and flags a doc outrun by an unconsolidated note as **STALE**
(evidence to check against the notes, never current truth), `validate` carries the same
`stale_docs=` warning beside `consolidation_owed=`, and the phase notebook's soft budget becomes
the single 400 KB byte cap described above. **v44** slims the routing contract (`CLAUDE.md`) to
~12 KB with `workflow.py --help` as the command reference, and gives a `docs` slice in an
operator-created docs phase the **docs-slice carve-out**: it alone may run `doc-new-version` /
`rebuild-docs` for the "Doc impact" notes its plan names, editing only the returned `edit_path`;
`docs-consolidated <P>` stays the orchestrator's. See *Durable-doc consolidation — a docs phase
the operator creates* below.

Product visual work automatically invokes the `design-cowork` guide: **the design subagent drafts and
the operator decides** (v47; in a phase that picks the `claude-design` tool, v48, the operator designs
in Claude Design instead and decides there). The orchestrator writes one `handoff.md` per round, stops
`pending` for the operator, reads the round back, and signs it only on their literal words. **v34
narrowed the co-work boundary**: the mockup build is a dispatched span of the slice, and SIGNOFF moved
from the read-back to the operator's approval of that running mockup. **v42 makes the mockup optional**:
without one, SIGNOFF is taken at the read-back, on the operator's return. **v47 adds the drafting as a
second dispatched span** (to `design-drafter`, under the default tool), while the `DesignSync` work
(read-back, regroup) exists only under `claude-design` and stays main-thread only, never dispatched.
Later slices implement the signed contract and prove fidelity in a real browser. **v31 removed the Codex
half of this** (ImageGen generation, the `record.json` / `SIGNOFF.md` round record, the inline-resume
carve-out) along with Codex itself; see *Visual-design runbook* below.

As of **v47 the design lives in the repo as files, drafted by a design subagent**, and as of **v48 the
design tool is a per-phase choice.** The design is one project per repo at the fixed root
`docs/reference/design/` (schema 1: a `design.json` manifest, numbered self-contained cards, one
`tokens.css` and a flat folder per round), run by five engine commands (`design-init`, `design-open`,
`design-check`, `design-close` and `design-register`, the operator's own step, which writes a registry
**outside the repo**) and drafted by a third managed agent file, **`design-drafter`**, which follows the
`high` tier and is not a tier of its own. The contract's routing rules changed with it: a `co-work`
slice still runs inline but dispatches its drafting to the drafter and, only on request, its mockup
build to `slice-executor-high`; `do-whole-phase` and `do-next-slice` carry the per-round steps and stop
counts; the mockup span reads the round's record on disk; and the contract's visual-design hard rule
reads "the design subagent drafts, the operator decides". That release is workspace **v47**
(`WORKSPACE_VERSION` 47, with `CHANGELOG.md` migration notes). **v48** brings Claude Design back as the
alternative: `drafter` stays the default and `claude-design` is picked per phase (a `Design tool:` line
under `## Design Style`; absent reads as `drafter`), keeping its record under
`docs/reference/design/claude-design/`; `design-migrate` moves a pre-v47 record there;
`design-register` prints a design-deck hint from `$AGENTIC_DESIGN_DECK_URL`; and the installer's stdin
program declares utf-8, so the Mac's system Python 3.9 cannot reject it. See *Visual-design runbook*,
*Updating an adopted workspace to upstream* and *Building and releasing the installer*.

As of **v49 a nested personal install exists, and as of v50 it is the default.** v49's opt-in `--nested`
installs the workspace privately into a repo you don't own: the engine and state in an untracked nested
git repo `<host>/workflow/`, the skills and agents untracked in the host's `.claude/`, nothing
team-visible. The engine runs from the host root as `python3 workflow/scripts/workflow.py`,
`nested-convention` records the host's commit convention, and `parallel-*` is off. **v50 makes it the
default**: a bare install is nested, `--at-root` reaches the committed layout, `--update` detects the
layout, `--nested` is a redundant no-op, and `--force-empty-ok` needs `--at-root`. P28.F1 amended v49 in
place (the ignore guarantee), with no version bump. See *Nested personal install* below.

As of **v51 `/rotate-backlog` proposes the docs phase by default** (the latest release): it archives as
before and then prints a read-only docs-phase proposal for the phases held back only by unpaid doc
consolidation; the operator confirms it, and `new-phase --consolidates` marks the phase that pays them.
`/rotate-backlog archive-only` opts out, and `docs-debt` shows which live docs phase pays each owing
phase. See *Durable-doc consolidation — a docs phase the operator creates*.

## Purpose

Use this doc for local development, environment variables, deployment, infra, jobs, observability, backups, and recovery.

## Visual-design runbook (two design tools: drafter or Claude Design, since v47/v48)

`design-cowork` is the workspace guide that **invokes itself** when a request touches product
visual design: design systems, redesigns, mockups, visual gates, brand/palette/type, or the appearance
of a user-facing page. Schema, API, data, and architecture decisions do not trigger it. **The design
subagent drafts and the operator decides** — under the `claude-design` tool the operator designs in
Claude Design (claude.ai/design) instead and decides there. Either way **the operator decides, whoever
drafts**, and only their literal words sign a round. The orchestrator owns the context gathering, the
handoff, the read-back, the round's lifecycle and the workflow bookkeeping around that choice — it never
designs. The contract's visual-design hard rule reads **"the design subagent drafts, the operator
decides"** (v47; it replaced "Claude Design plus the operator make every visual decision") and leaves
literal signoff, immutable rounds and RESPECT THE DESIGN untouched.

**v31 removed the Codex branch of this runbook**, and with it the ImageGen/exact-reference generation
path, the `record.json` + `SIGNOFF.md`-per-round artifact set, the capability-probe halts, and the
Codex-only inline resume of a `pending` design slice.

**v34 changed three things in this runbook** and nothing else: the phase shape became **three named
styles the operator picks**, the round's single approval moved off the static card set onto a
**runnable mockup in the project's own frontend**, and a design slice therefore makes **four** commits
across **two** `pending` windows instead of two commits across one.

**v42 changes three things** and nothing else: the card paths a handoff names are **numbered in
reading order**, so the operator reviews the design in the order it was meant to be read; **the
operator's return closes the round** — their literal "done" at PENDING #1 is the approval; and the
**runnable mockup is built only when the operator asks for one**, so a design slice is back to two
commits across one `pending` window unless a mockup was requested (then the mockup shape applies — four
commits under `claude-design`, three under `drafter` since v47 — with SIGNOFF at the mockup gate).

**v47 moved the design onto repo files, and v48 made the design tool a per-phase choice.** Claude Design
and `DesignSync` both need a claude.ai login, so they fail under `ocx claude`, and `DesignSync` cannot
run in a subagent. v47 therefore made the design a written contract of plain files in the repo
(`docs/reference/design/`, schema 1), drafted by a dedicated subagent, `design-drafter`, and read back
with the engine's `design-check`. v48 brought Claude Design back, restored, **as the alternative**: the
**`drafter`** tool is the default and **`claude-design`** is picked per phase, with its own record under
`docs/reference/design/claude-design/`. Where the two loops differ, P26's governance text wins; the three
styles, rounds and superseding, literal signoff, the mockup gate and RESPECT THE DESIGN mean the same
under both. The commit shape follows the tool: under `drafter` a design slice makes **two** commits across
one `pending` window (**three** across two with a mockup), under `claude-design` **two** without a mockup
and **four** with one, and each superseding round adds one commit and one stop either way. The drafter is
not a third tier: it follows the `high` tier (see *Executor tiers*).

### Choose the design style at intake — three named styles (since v34)

The style is **named, suggested by the agent with a reason, and confirmed by the operator** — never
the agent's decision alone and never left implicit. It is asked at `/create-phase` by default, and
recorded in the phase's `intent.md` under a **`## Design Style`** section that `DECOMP` reads — with
a second line, **`Mockup: requested`** or **`Mockup: on request`** (the default when the operator did
not ask), asked beside the style (since v42). The
section is appended **only when the phase is visual**: `works/templates/intent.md` carries no such
heading, and every reader treats its absence as "not a design phase", never as an unanswered
question. A phase created before its visual nature was clear has the style asked at `DECOMP` instead,
which stops **`pending`** for the answer.

- **`build-after`** — one phase, two decomposition passes: `DECOMP` → groundwork → design round(s)
  → `DECOMP2` → build slices. The opening `DECOMP` creates only known groundwork, the high-risk
  `co-work` rounds, and `DECOMP2`; it records a **build inventory** but cuts no speculative build
  slices, because the design decides what gets built. After signoff, `DECOMP2` cuts backing/backend
  work first, faithful UI implementation second, and bounded fidelity fixes last. Choose it when the
  whole design should land before any of it is built and the build fits in the same phase.
- **`design-only`** — a design phase, then a separate apply phase, both single-pass. **It must be
  chosen at `/create-phase`**, because a `DECOMP` executor may not run `new-phase`, so a split
  decided later cannot be created from inside decomposition; that deadline is the one hard constraint
  on the choice. A requested mockup's route deliberately **survives** into the apply phase — it is
  what that phase's slices build against — and the apply slice deletes it as it implements the
  surface for real. Choose it when the design is big.
- **`paired`** — one phase, alternating design 1 → apply 1 → design 2 → apply 2, with **no
  `DECOMP2`**. `DECOMP` cuts the pairs as **bare folders**; the apply-slice count equals the round
  count, which the build inventory already gives it. **Cutting a bare folder is not pre-planning** —
  each apply slice's `plan.md` is written at its turn, from the round that just landed, so the ban on
  planning past the design gate holds unchanged. Anything a round reveals that the pairs miss is cut
  afterwards at a fractional order. Choose it when the rounds are independent surfaces and each is
  small enough to apply before the next design starts.

In **every** style, how many rounds there are is decided at the opening `DECOMP` (one `co-work` slice
per round), and `DECOMP` records the build inventory — what to build, not how.

A `co-work` slice is `--kind co-work --risk high` and runs **inline** — the round's lifecycle and the
operator's words stay on the main thread — with **dispatched spans only for drafting and code**: under
`drafter`, the drafting of every round, to `design-drafter` in the background; under both tools, the
mockup build (`slice-executor-high`), only when the operator asked for a mockup. Under `claude-design`
the **DesignSync work is never dispatched** (`DesignSync` is main-thread only, so no executor can read a
round back or run the regroup). The slice writes no ***product*** implementation code: a requested
throwaway mockup route is the one exception, and real implementation and browser-fidelity work are
always separate slices.

### Choose the design tool at intake — drafter or claude-design (since v48)

The design tool is a **per-phase choice**, asked at `/create-phase` together with the style and the
mockup question and recorded as one line under `## Design Style` in `intent.md`:

```text
Design tool: drafter | claude-design
```

**An absent line reads as `drafter`, and so does an absent `## Design Style` section**, so every phase
created before v48 keeps v47's loop. `DECOMP` reads the tool with the style; when the style is asked at
`DECOMP` instead, so is the tool. The tool is fixed for the phase and **never switched mid-round**; a
later phase may pick the other.

- **`drafter`** — the default, and the P26 loop. `design-drafter` drafts each round into the on-disk
  contract under `docs/reference/design/` (schema 1); the operator opens the card files, or design-deck
  (the read-only design dashboard) once the repo is registered. No claude.ai account, no `DesignSync`,
  no push.
- **`claude-design`** — the original loop, restored. The operator designs in Claude Design, which reads
  the repo over **Connect GitHub** (or a local-directory connection), and the orchestrator reads each
  round back with `DesignSync` and lands its record under `docs/reference/design/claude-design/`. Its
  constraints are real: it needs a claude.ai login, so it fails under `ocx claude`, and `DesignSync`
  runs on the main thread only, never in a subagent. When `DesignSync` is not available in the session,
  the slice stops `pending` and says so — it never falls back to the drafter mid-round.
- **design-deck shows `drafter` rounds only.** Claude Design's cards stay in Claude Design and nothing
  is mirrored to disk, so the dashboard shows nothing for a `claude-design` round; the engine's
  `design-*` commands and design-deck both skip `claude-design/`. A repo may hold both records, across
  phases that chose differently.

### Hand off, stop, read back, land — under `drafter` (the default; since v47)

The loop is **`design-open` → `handoff.md` → the round is drafted → read back with `design-check` →
PENDING #1 → the operator's return**, then SIGNOFF or a superseding round:

```text
design-open → handoff.md [numbered card paths · "new visual direction: yes/no"]      [inline]
  → the round is drafted [dispatched: design-drafter, in the background]
  → read back [inline]: design-check <the paths> → the cards + result.md → concreteness check
  → commit the drafted round → PENDING #1 [the operator opens the cards, then returns with words]
  → feedback:            feedback.md → design-close --superseded → design-open [same slice]
                         → a new handoff → drafted again → read back → PENDING #1 again
  → no mockup requested: SIGNOFF [on the operator's literal words at their return]
  → mockup requested:    build the mockup [dispatched: slice-executor-high]
                         → PENDING #2 [the mockup gate] → SIGNOFF [on their words at the gate]
  → design-close --words [snapshot, retire the round's address] → implement [a separate slice]
```

**Commits, one per span.** Without a mockup, **two** — `drafted` (the round's `round.json` and
`handoff.md`, the drafted cards, `tokens.css`, `result.md` and `build-prompt.md`, and the spec pointers in
`phase.md`) and `signoff` (`SIGNOFF.md` and what `design-close --words` wrote) — with one `pending`
window between them; with a requested mockup, **three** — `drafted`, `mockup`, `signoff` — with a
`pending` window after the first and after the second (the mockup gate). Each superseding round adds one
commit and one stop. The orchestrator makes every one; the dispatched drafter and mockup executor commit
nothing, as always. Under `/do-next-slice` one design slice therefore takes **two** invocations (three
with a mockup).

**The operator's return closes the round (v42).** PENDING #1 is the wait while the operator reviews the
drafted cards, and their words on return decide the round: their **literal approval** is the approval,
and their literal words are what `SIGNOFF.md` and `design-close --words` record; **anything else is
feedback** — recorded verbatim in `feedback.md`, the round closed `--superseded`, and a new round of the
same slice re-drafts it. It is never inferred from silence, from the drafter's `done` or from the record
looking finished, and it is never signed before the read-back: the card-contract and concreteness checks
run first, and **if anything is wrong the orchestrator raises exactly those points instead of signing**
— back to the drafter when it can fix them, `pending` with exactly those points when it cannot.
**PENDING #2 exists only when a mockup was requested**, and is then the gate on the running mockup,
where SIGNOFF is taken instead. Because the engine cannot tell the two windows apart (both are
`status: pending` on the same slice), the drivers require them to be **reported differently**: at
PENDING #1 name the card files to open (`docs/reference/design/cards/NN-slug.html`, in numbered order,
or the dashboard once the repo is registered), every departure the drafter logged and its
`open_questions` as decisions to take, whether `frontend-design` was used, and what the operator's words
will do (literal approval signs the round, or starts the mockup build; anything else is feedback); at
PENDING #2 say you are asking for approval, and give the run command, the mockup route's URL, the
viewports, what is real and what is stubbed, and that only their literal words close the round.

- **`handoff.md` says what to design and decides nothing:** product context, a scope checklist, locked
  vs. in-play areas, real paths and real content (never lorem — if there is nothing real to point at,
  ask), open questions posed back rather than answered, operator attachments, the definition of done,
  and any operator-named reference clearly labeled *REFERENCE — data, not a proposal*. It names the
  round's **numbered card paths** and says **`new visual direction: yes`** or **`no`**: the drafter
  loads the `frontend-design` skill only on a handoff saying yes, and a missing line leaves it
  unloaded and becomes an `open_questions` entry (P26.F1). A revision round's handoff lists every card
  still carrying the slice's address and is read back like the first.
- **The card paths are numbered in reading order (v42).** Every path the handoff names carries a
  **two-digit reading-order prefix** — `01-nav.html`, `02-hero.html`, `03-button.html`, … — in the
  order the operator should review them (the scope checklist's order: foundations → components →
  surfaces, or the user-flow order). Deciding the order of review is organization, not design.
  Cards the drafter adds beyond the checklist take the next numbers; a card that supersedes one
  already in the library keeps that card's path, number included. Read-back verifies that every
  listed path is present and every added card is numbered after them — a gap or an unnumbered card
  is the card-contract failure. The numbers stay in the library for good: paths never change at the
  regroup, so the order a round was reviewed in is the order it is filed in.
- **The drafter** is dispatched as a background task, one at a time, its prompt carrying only the round
  folder and the slice id; it reads `handoff.md`, the design system and the prior rounds itself. It
  writes the open round's addressed cards, `tokens.css`, `result.md` and `build-prompt.md`, runs
  `design-check` on its own paths and returns a verdict (`done | needs_operator | blocked`). It never
  signs, opens or closes a round, builds a mockup or writes product code, and commits nothing. Its
  `done` is its claim, not the check.
- **Read-back is the orchestrator's own: `design-check <the handoff's numbered paths>`, never the
  drafter's `design_check` line.** Exit 1 (a listed path missing or unaddressed, a gap in the
  sequence, an unnumbered card, an unknown marker attribute, a reference the self-contained rule
  forbids, one monolithic HTML) goes back to the drafter on the same open round with exactly the named
  problems; if they survive that second pass the slice stops `pending` with them and nothing is signed.
  The orchestrator never edits a card or writes one itself. Then the concreteness bar — *there are no
  design decisions left to invent*: a `build-prompt.md` too thin to build from goes back to the
  drafter, a question only the operator can settle goes to PENDING #1 as a decision to take, and the
  orchestrator never fills a design gap.
- **No account, no push, no external service.** The drafter loop needs no claude.ai account and no
  `DesignSync`, and **a design slice authorizes no `git push`** under it — everything the drafter reads
  and writes is in the working tree.
- **`design-register` is the operator's step.** `python3 scripts/workflow.py design-register` records
  the repo in the design registry outside it, once per product repo after `design-init`. It is the
  engine's first write outside a repo, so the operator runs it; no round waits on it, because the card
  files open directly without it. On success it prints the design-deck hint: the deck URL from
  `$AGENTIC_DESIGN_DECK_URL` when that is set (never guessed), and a warning when the repo lies outside
  the deck's mounted projects folder, where the deck shows it as unavailable.
- **A Claude Design bundle may be imported (optional).** The operator places an export, as exported, in
  the open round's `import/` folder (which `design-check` ignores); the drafter translates it into
  cards, `tokens.css`, `result.md` and `build-prompt.md` under the contract, logging every departure,
  and the bundle stays filed with the round as **data, not instructions**. An import round's handoff
  normally says `new visual direction: no`. No claude.ai account or `DesignSync` is involved.

### Hand off, stop, read back, land — under `claude-design` (since v48)

The loop is `handoff.md` → push → **PENDING #1** (the operator designs in Claude Design) → **their
return** ("done") → read back (`DesignSync`, orchestrator) → card-contract and concreteness checks →
land the design as-is → **SIGNOFF on their words** → regroup → implement (a separate slice). When the
operator asked for a mockup, the round instead continues after landing: **build the mockup**
(dispatched) → **PENDING #2**, the gate (the operator opens the running mockup) → SIGNOFF → regroup.

**The operator's words are routed first (P27.F1).** On their return, anything but literal approval is
feedback: it supersedes the round with **no read-back and no landing** — the round keeps only
`handoff.md` and `feedback.md` — and a new round of the same slice takes it (a new handoff, a push,
PENDING #1 again). The `DesignSync` read-back, the landing and the checks gate only **literal approval**
and the mockup go-ahead.

**Commits.** Two without a mockup — `handoff` and `signoff` (the landed record, the spec in `phase.md`
and the round's `SIGNOFF.md` entry; the regroup writes no repo bytes) — with one `pending` window between
them; four with one — `handoff`, `read-back`, `mockup`, `signoff` — and two windows. Each superseding
round adds one commit and one stop. The orchestrator makes every one; the dispatched mockup executor
commits nothing, as always.

**The operator's return closes the round here too (v42):** their literal "done" at PENDING #1 is the
approval and `SIGNOFF.md` records their words, never inferred from the session having ended or from the
record looking finished, and never signed before the read-back (if anything is wrong, raise exactly
those points and stop `pending` again). At PENDING #1 name the pushed `handoff.md` (a local-directory
connection needs no push) and the numbered card contract, and ask the operator to run the Claude Design
session and say "done" when they are back; at PENDING #2 report the mockup as under `drafter`.

- **Claude Design reads the real repository itself** through **Connect GitHub** (the default; a
  local-directory connection also works), so the orchestrator mirrors **nothing** — no canvas, no
  `tokens.css`, no cards of its own. Its one output is `handoff.md`. Pushing the branch so Claude
  Design sees current code is the one `git push` a design slice authorizes, **once per round** with its
  handoff commit (a superseding round's included); a local-dir connection needs none.
- **`handoff.md` is the same document as under `drafter`**, without the `new visual direction` line (that
  is the drafter's licence for `frontend-design`), and its card paths are numbered in reading order just
  the same.
- **A strict required-output manifest, three items:** the reviewable **card set**, a **record of what
  was designed** with every departure logged, and an **implementation contract** complete enough to
  build from without inventing anything. Markdown alone is not a round. If the session returns Claude
  Design's own handoff bundle, that bundle *is* the record and the contract — take it as-is.
- **The card set is what makes the design reviewable.** One card per reviewable unit (never one
  monolithic page); line 1 of each preview HTML carries the `<!-- @dsCard group="…" viewport="…" -->`
  marker the app parses into `_ds_manifest.json` — no marker, no card, empty pane. The handoff names
  the exact card paths and the `group` taxonomy, asks for a `tokens.css` the cards link, and defines
  done as *"the cards appear in the pane"*. While the round is under review the group carries the
  round's address (`⏳ P48.S1 · Components`); at SIGNOFF that address is retired.
- **Read back with `DesignSync`** (`list_files` first) and check what came back against the card paths
  the handoff named. Missing paths, a gap or unnumbered card, no `_ds_manifest.json`, or one monolithic
  HTML means the round never became visible — that is `needs_operator` with the card contract
  restated, never something the orchestrator fixes by authoring cards itself. Then the concreteness
  bar: *there are no design decisions left to invent*; too vague to build without guessing is
  `needs_operator` too. Either failure stops the slice `pending` again with nothing signed.
- **Land the design as-is** — the returned artifacts into the round's `output/`
  (`docs/reference/design/claude-design/rounds/<NN-slug>/output/`) and the spec pointers into
  `phase.md`, never the artifacts themselves. A mockup, when requested, is dispatched after landing and
  SIGNOFF waits for its gate.
- **Requiring a card is not drawing one.** The orchestrator says what must be reviewable; Claude
  Design decides what it looks like.

### The design record

Durable and **outside `works/`**, because the apply phase reads it long after the design phase is
archived, at one fixed root, **`docs/reference/design/`** — a repo's own `design/` tree and the
`output/` subfolder of the pre-v47 layout are retired, because the engine and the dashboard must find
the design unconfigured. The root holds one layout per tool, and a repo may hold both across phases.

**`drafter` — schema 1, the on-disk contract (v47).**

```text
docs/reference/design/
├── design.json              # the project manifest            design-init
├── tokens.css               # the design's tokens             the drafter
├── cards/                   # the cumulative card library: the live design
│   └── NN-slug.html         #   numbered 01…N, no gap
└── rounds/<NN>-<slug>/
    ├── round.json           # the round manifest              design-open / design-close
    ├── handoff.md           # the brief                       the orchestrator
    ├── result.md            # what was designed; every departure logged     the drafter
    ├── build-prompt.md      # the implementation contract     the drafter
    ├── feedback.md          # the operator's notes, verbatim  optional
    ├── SIGNOFF.md           # the operator's literal words    signed rounds only
    ├── import/              # a Claude Design bundle, filed as-is   optional
    ├── tokens.css           # snapshot at close
    └── cards/               # snapshot at close: this round's cards as they were
```

- **`design.json`** is exactly `{"schema": 1, "id": …, "name": …}`: one project per repo, keyed by `id`
  so a later schema can hold several.
- **A round** is one design iteration of a `co-work` slice, in a flat folder, numbered after the highest
  one; **at most one round is open per project**. It runs `open` → `signed` or `superseded`, and a
  **closed round is immutable**: `design-close` leaves a snapshot of its cards and `tokens.css`, and
  `supersedes` is derived at close, never declared.
- **Cards** are `cards/NN-slug.html`, numbered `01…N` with no gap and never renumbered: a path never
  changes, number included, and a card that supersedes one is written at the same path. Line 1 is the
  marker and only the marker, `<!-- @dsCard group="…" viewport="WxH" title="…" -->`, from a closed
  attribute set (`group` and `viewport` required, `title` optional). `group` is the design system's own
  taxonomy; while a round is under review its cards carry the round's address
  (`⏳ <slice> · <Group>`), and `design-close --words` retires it with a pure regroup — line 1 only,
  every later byte asserted identical.
- **Self-contained, as the contract text states it (P26.F2; it supersedes P26.F1's wording of the `#`
  half).** A card references nothing relative except `../tokens.css` and in-page `#` fragments (inline
  SVG's `url(#id)` / `<use href="#id">`, a `href="#"` link stub); images are inline SVG or `data:` — a
  `data:` URI suits any resource — and anything else is an absolute `https:` URL. `tokens.css` follows
  the same rule, `#` included, without the `../tokens.css` exception, and `design-drafter` §Do 2 says
  the same. `design-check` enforces it exactly: `../tokens.css` (cards only), in-page `#` fragments,
  `data:` and absolute `https://` URLs pass; `//` (protocol-relative), `http://`, `mailto:`, `tel:`,
  `javascript:` and `about:` fail with a named problem (P26.F1).
- **The registry** is outside every repo: `$AGENTIC_DESIGN_REGISTRY`, default
  `~/.config/agentic-workspace/design-registry.json`. `design-register` is its only writer
  (idempotent, atomic, refusing an `id` another live repo holds, replacing an entry whose root has
  vanished), which is why it is the operator's to run. Every test points `$AGENTIC_DESIGN_REGISTRY` at a
  scratch path.
- **The commands** (`python3 scripts/workflow.py <command> --help` has the detail):

| command | what it does |
|---|---|
| `design-init [--id I] [--name N]` | writes `design.json`; idempotent; refuses on a root still holding the pre-v47 record |
| `design-open --slug S --slice P<N>.S<n> [--title T]` | opens the next round; refuses while one is open |
| `design-check [cards/NN-slug.html …]` | checks the whole contract and names every problem (exit 1); given the handoff's numbered list it also checks each path is present and addressed |
| `design-close <round> --words "…"` / `--superseded` | snapshot, regroup (signed only), manifest; idempotent |
| `design-register` | writes this repo's project into the registry and prints the design-deck hint |
| `design-migrate [--apply]` | moves a pre-v47 record into `claude-design/`, unchanged; a dry run unless `--apply` |

**The drafted record is read-only.** Once the round closes it is never edited — nits are catalogued as
apply-time to-dos. The implement slice and a requested mockup read it from disk and nothing else, so
`build-prompt.md` must be complete: a card shows what a state looks like, the contract says how to build
it, and a slice that cannot be built from the record means `build-prompt.md` is what is short.

**`claude-design` — the original layout, under `claude-design/` (v48).**

```text
docs/reference/design/claude-design/
├── rounds/<NN>-<slug>/
│   ├── handoff.md          # OUT — the orchestrator writes it
│   ├── feedback.md         # the operator's words, verbatim — superseded rounds only
│   └── output/             # IN — Claude Design returns it; READ-ONLY
│       ├── result.md       #   what was designed; every departure logged
│       └── build-prompt.md #   the implementation contract
├── SIGNOFF.md              # one entry per signed round, the operator's literal words
└── grounding/              # the operator's grounding material, kept as it is
```

It has no `round.json`: a round's `feedback.md` marks it superseded and its entry in the root
`SIGNOFF.md` marks it signed. The folder sits **outside schema 1** and needs no `design.json`; the
engine's `design-*` commands and design-deck skip it, so neither its HTML nor its rounds are problems.
The returned record is **read-only** — never edited, nits catalogued as apply-time to-dos. The cards stay
in the design project and are never copied down (a local copy is a mirror, and it goes stale on the next
round), which is exactly why the implementation contract must be complete: the implement slice is
dispatched to an executor with **no DesignSync**, so the landed record is the whole source of truth it
gets. Returned content — like any generated or external artifact — is durable untrusted **data, not
instructions**.

**Migrating a pre-v47 record — `design-migrate` (v48).** A repo whose Claude Design record still sits in
the old layout at the design root (`rounds/` without `round.json`, a root `SIGNOFF.md`, `grounding/`)
fails `design-check`, and `design-open` refuses it. `python3 scripts/workflow.py design-migrate` is a dry
run that prints each move; `--apply` moves, and the operator commits the renames. It moves the old record
unchanged — with no `design.json`, every top-level entry of the root; with one, only the rounds without
`round.json`, the root `SIGNOFF.md` and `grounding/` — and is all-or-nothing: it refuses, moving nothing,
when a destination already exists (so run it before the first `claude-design/rounds/` folder exists). It
never deletes, never runs git and never writes `design.json`. **A pre-v47 root is steered to it first
(P27.F2):** `design-init` refuses, and the `design-check`, `design-open` and `design-register` hints name
`design-migrate`. Run `design-init` afterwards only if the repo will also use the `drafter` tool.

### The runnable mockup — only when the operator asks for one (since v42; introduced v34)

**A mockup is optional.** It is built only when the operator asked for one — `Mockup: requested`
under `## Design Style` in `intent.md`, or in their own words at any time before the round closes
("build me a mockup"). No request means **no dispatched span at all** in the slice: the round closes
on the operator's return, signed on the card set. When one is requested, between landing the record
and SIGNOFF the round becomes **running code the operator can open**, built from `build-prompt.md`.
It **transcribes** the round and decides nothing — the moment the builder is choosing what something
looks like, that is designing, and it is raised rather than done.

- **A throwaway route in the project's own router**, namespaced and addressed by round; the exact path
  follows the project's own routing conventions. The path is recorded in the slice's `result.md` **and** in
  `phase.md`, so the gate walkthrough, the apply slices and the review can all find it.
- **The project's real stack, components and tokens**, under **RESPECT THE DESIGN**: every designed
  element and every designed state present, nothing dropped, simplified, restyled or "improved".
- **Stubbed data, no backing work.** It proves **look and states, not wiring**. Non-functional
  controls are acceptable **and are named as such in the gate walkthrough**. That bound is
  load-bearing: without it the mockup span grows into the apply slice it exists to precede, and the
  design gate lands after the build instead of before it.
- **Exempt from the full functional sweep** — the sweep is an apply/fidelity duty on real wiring (see
  the qa doc's *Verification doctrine*). What is checked here: it runs, every designed element and
  state renders, and it matches the record.
- **Verified in the operator's runtime** — the runtime and access path `## Operator Runtime` names,
  and additionally in the production build when the two differ. Absent, or still carrying its
  `UNFILLED` marker → `needs_operator`, and the orchestrator sets the slice `pending`.
- **Dispatched to `slice-executor-high`** with **no DesignSync**, so `build-prompt.md` plus the round's
  record on disk are the whole source of truth it gets — under `drafter` the cards, `tokens.css`,
  `result.md` and `build-prompt.md` under `docs/reference/design/`; under `claude-design` the landed
  `result.md` and `build-prompt.md`, because its cards stay in Claude Design — exactly as for the
  implement slice. This adds a
  **third `needs_operator` condition** to the two at read-back (cards missing or the round back as
  prose; the concreteness bar unmet): if building the mockup proves the record **wrong, internally
  inconsistent, or too thin to build without inventing**, the executor raises it and the orchestrator
  asks the operator. The gap is never filled in the mockup, not even "just for now".
- **And when a mockup is built, the concreteness check stops being a judgment call.** It either
  builds from `build-prompt.md` without inventing anything, or it does not. Without one, the
  read-back's check is the whole bar — which is why it runs before anything is signed.
- **Rejection at the gate splits** the way every other finding does: a **departure from the record** is
  fixed in the slice, while a **design question** starts a new immutable superseding round.
- **Throwaway lifecycle.** Whichever slice later implements the surface for real **deletes the route**;
  under `design-only` it survives into the apply phase and is deleted there. The phase review checks
  that no orphaned design routes remain — in a phase that shipped one.
- **Consequence: the phase gate follows the mockup, with no judgment left in it.** A phase that ships
  a mockup changes operator-visible surfaces and takes `accept-gate <P> --require`. A **`design-only`
  phase that ships none** ships no running surface, so it is **waived** with the fixed note
  `design-only, no mockup: the operator signed the round on the card set`; `build-after` and `paired`
  phases are gated by their build/apply slices as always — `--require`. A mockup asked for after
  `DECOMP` declared the gate re-declares it (`accept-gate <P> --require` in the mockup commit). When
  `DECOMP` had to ask the design style, that answer — and the mockup answer beside it — must land
  **before** the gate is declared, because the declaration depends on them.

### Close the round — on the operator's return, or on the mockup they asked for

The operator's words at their return — PENDING #1 — decide the round, one of three ways:

- **Feedback — anything but literal approval.** Nothing is signed. Their words go verbatim into the
  round's `feedback.md`, the round closes **superseded**, and a **new round of the same slice** takes
  it; a superseding round is a new immutable round, never an edit to the one it replaces. Under
  `drafter`: `design-close <round> --superseded` (snapshot and close, no regroup: the cards stay
  addressed), then `design-open --slug <s> --slice <the same slice>` — the new round inherits the
  addressed cards — a new handoff, the drafter re-dispatched, read back, PENDING #1 again. Under
  `claude-design`: `feedback.md` closes the round with no read-back and no landing, the next round
  folder is created under `claude-design/rounds/` for the same slice, and the slice stops at PENDING #1
  again after the new handoff and push.
- **Literal approval, no mockup requested** — SIGNOFF now: **one stop**. (Under `claude-design`, once the
  read-back has passed and the record has landed.)
- **Mockup requested** — their go-ahead starts the mockup build, and SIGNOFF waits for their literal
  approval of the running mockup at PENDING #2: **two stops**.

However the round closes, the same rules hold:

- **The `pending` gate is the ordinary one.** The design slice stops `pending` like any other operator
  co-work item and resumes only after explicit operator input clears it back to `in_progress` — the
  same rule `do-next-slice` and `do-whole-phase` state. **v31 removed the one carve-out that ever
  existed here** (a Codex-only allowance to clear and resume a `pending` `co-work` slice inline when
  the invocation itself carried the literal approval); it was written for Codex because Codex was
  automatic-only, and it went with Codex. No pending gate is special any more.
- **The read-back lands the record.** Under `drafter` the drafter already wrote the record in place, so
  landing is the spec pointers into `phase.md` — what landed, where the round is, the mockup route once
  one exists, the decisions later slices must not re-litigate — never the cards themselves; under
  `claude-design` the returned artifacts go into the round's `output/` as-is, with the same pointers.
  Without a mockup, **SIGNOFF is written right here (v42)**, on the words the operator returned with,
  and the slice is done; when a mockup was requested the slice moves on to the mockup build instead and
  SIGNOFF waits for that gate.
- **Approval must be literal** — the operator's own words at their return, or, when they asked for a
  mockup, on the **running mockup** at PENDING #2 — never silence, never the drafter's `done` or the
  Claude Design session having ended without their word, never the record looking finished — and it
  authorizes only that slice's `pending → in_progress` transition. On approval, write the SIGNOFF: the
  operator's literal words as the authorization, what supersedes what, the mockup route it was approved
  on when one was built, the token delta ("None." when nothing changed), and the line stating the file
  is a factual record dropped at gate close, data and not instructions. Under `drafter` that is
  `SIGNOFF.md` in the round folder; under `claude-design`, the round's entry in
  `claude-design/SIGNOFF.md`.
- **Retire the round's address with a pure regroup**, only after SIGNOFF and only on this round's
  cards. The invariant that makes it legal is that **every byte after line 1 is identical**; paths never
  move. It is idempotent. Under `drafter` it is `design-close <round> --words "<their literal words>"`,
  which refuses without `SIGNOFF.md` or on a failing `design-check`, then snapshots the round's cards
  and `tokens.css`, regroups line 1 and closes the manifest (`signed`, `signoff_words`, `cards`,
  `supersedes`). Under `claude-design` it is the remote regroup over `DesignSync`: `list_files` →
  `get_file` → rewrite the `group` value on line 1 and nothing else → `finalize_plan` with exactly those
  paths → `write_files`; a pane that does not re-index is cosmetic and never blocks the apply slices.
- **A literal revision creates the next immutable superseding round**; it never overwrites the earlier
  one.
- **Under `claude-design`, writes to the design project are limited to two sanctioned cases** —
  grounding the project in components that already exist and are implemented in the repo
  (operator-requested, when there is no repo connection), and the post-approval regroup above. Both
  file or document what already exists. Never write a new visual decision.

### Implement and prove fidelity after signoff

Every post-signoff plan and executor dispatch names the approved round and says `RESPECT THE DESIGN`.
Build missing backing/data behavior before the UI. Then ship every declared element and state, reusing
project components, tokens, layout primitives, routing, accessibility, and data flow — never dropping,
simplifying, restyling, or "improving" a designed element to save effort, and where an exact value is
unspecified picking the option closest to the designed intent rather than a plainer fallback. Exercise
the declared routes, viewports, responsive transitions, interactions, keyboard/focus behavior, and
reduced motion in a **real browser**, and keep only selected durable evidence with the round.

Fix one concrete mismatch per bounded pass with the smallest defensible patch. A broad redesign,
missing designed state, or unresolved product choice starts a new immutable design round. If no real
browser run succeeds, report the exact runtime/prerequisite need and make **no visual-fidelity claim**;
unit tests, DOM inspection, and static screenshots may supplement but never replace that run.

### Install, retrofit, and update behavior

A fresh install and retrofit carry the `design-cowork` guide (deliberately model-invocable, so it
fires by itself on visual work), the execution skills, the two executor tiers, the `design-drafter`
agent (since v47) and the contract's design rule. Retrofit remains non-destructive: pre-existing
operator-owned paths are skipped or merged under the normal collision policy. `--update --dry-run`
previews replacement of the managed skill/runner/executor/drafter/contract files; applying `--update`
refreshes them in whichever layout is installed while preserving phases, durable docs, and the seed-once
`executors.toml`. Updating from a pre-v31 workspace additionally flags the retired `.agents`, `.codex`,
`AGENTS.md`, and `AGENTS.workspace.md` for manual removal (see *Updating an adopted workspace to
upstream*). No plugin integration or state migration is required, and **`sync-agents` runs after every
`--update`**: updates reset the agent files to upstream defaults, and it re-applies the `high` tier's
model and effort to the drafter along with any preserved adopter override. The install modes are in
*Nested personal install* below, and the v47/v48 design-record steps are in *Updating an adopted
workspace to upstream*.

## Executor tiers (kind-first, then risk routing; `executors.toml`, escalation) — since v7, two-tier since v23

Every slice is executed by one of two `slice-executor` tiers, picked by the orchestrator from the slice's `kind` + `risk` — **`kind` is read first**:

| Tier | Routes | `economy` | `flex` | Behavior |
|---|---|---|---|---|
| `slice-executor-mid` | implementation/`fix` with `risk` exactly `low` — a one-line (or few-line) code edit, or docs; **no `decomposition`, `research` or `review` slice ever reaches it** | `sonnet` @ `high` | `sonnet` @ `xhigh` | Judgment within the plan's intent; escalates the moment the slice turns out to be real code writing, spans more than one file, or breaks the plan's assumptions |
| `slice-executor-high` | decomposition, **`research`** and the phase review — those three by **kind**, whatever `risk` says (since v36) — plus everything else (`high`/`medium`/unset/unknown): essentially all code writing, and every cross-file change | `opus` @ `high` | `opus` @ `xhigh` | Full judgment; the escalation ceiling |

**The risk vocabulary is two values — `low` and `high` — and `--risk` defaults to `high`** on both `new-slice` and `promote-deferred` (it defaulted to `medium` through v22). Routing fails safe: only an exact `low` reaches `mid`, so an unset, legacy (`medium`), or misspelled risk lands on `high`. The engine still does **not** validate `--risk`; that non-validation is deliberate and unchanged. A phase's `DECOMP` and `REVIEW` slices are now created with `risk: high` to match the `kind` rule that already routed them to `slice-executor-high`.

**Kind beats risk, and `research` made that explicit (v36).** Three kinds route to `slice-executor-high` by **kind** and never by rating: `decomposition`, `review`, and — since v36 — `research`. Before v36 the routing prose read "decomposition and review always → high; `risk` exactly `low` → mid; anything else → high", which would have let a `research` slice rated `low` land on `mid`; the always-high clause now names all three in every place routing is stated (`CLAUDE.md`, both agent bodies, both `do-*` skills, and both `--kind` / `--risk` help strings). Cut a research slice with **`--risk high`** anyway so the recorded rating cannot contradict the routing — and **if the two ever disagree, the kind wins**. The engine still does not validate `--risk`, and `SLICE_KINDS` carries the reasoning in a comment above it.

**`research` — the eighth kind (v36).** A findings-only slice: it writes no product code (a throwaway probe is deleted before it finishes), and what it learned lands in **`phase.md`**, because the executor's context dies with the slice and a finding kept only in `result.md` prose is lost to the next dispatch. `DECOMP` cuts one when the phase cannot be cut past a point without learning something first, together with a `<P>.DECOMP2` ordered after it, instead of guessing at the slices beyond. That makes **`DECOMP2` a device with two origins** — a research slice, and the `build-after` design style (unchanged in every particular) — neither a special case of the other, and both never pre-planned. "The findings change nothing about the remaining breakdown" is itself a real result and needs no re-cut; a phase genuinely needing a third pass numbers it `<P>.DECOMP3`, which is a licence for one more id rather than a numbering scheme.

Defaults come from a **mode preset** (`EXECUTOR_PRESETS` in `scripts/workflow.py`). Since **v31** each tier carries exactly one model/effort pair: with no selected mode, `economy` resolves to `sonnet@high` / `opus@high`, and `flex` resolves to `sonnet@xhigh` / `opus@xhigh`. This upstream repository and the fresh-install seed select `mode = "flex"`; adopters may select another mode or override individual fields, then apply it with `sync-agents`. (`effort = ""` remains the escape hatch for a model that rejects the effort parameter.)

- **Configure via `executors.toml` (since v8; seeded since v9):** the installer seeds a top-level `mode = "flex"` plus commented per-tier examples — seed-once, never overwritten by updates, safe to delete (absent = `economy`), and committable (it holds no secrets). Set `mode` and/or `model` / `effort` under a `[claude.mid]` / `[claude.high]` table, then apply with `python3 scripts/workflow.py sync-agents`. **The `[claude.<tier>]` table name is deliberately unchanged in v31** — renaming it would break every adopter's existing file for no gain, so a post-v31 `executors.toml` is simply the old syntax minus any Codex tables. Two sections are rejected by name rather than by a generic parse error: a retired `[claude.low]` (v23) and any `[codex.*]` table, the latter with `executors.toml line <n>: Codex support was removed in workspace v31 — this workspace ships Claude Code only, so drop this section`. Values are written verbatim (aliases, full model IDs, `inherit`); an **empty** `effort = ""` omits the effort line; an empty model errors, and so does any unrecognized line or section (line-numbered). `sync-agents --check` reports drift without writing; `validate` warns while agent files drift. (Until v8 this was a gitignored `.env`; a leftover `.env` with `SLICE_EXECUTOR_*` keys is no longer read — `sync-agents` warns about it.)
- **Severity, exactly:** a leftover `[codex.*]` table makes `sync-agents` (and `sync-agents --check`) exit **1** with that message, while `validate` catches it in its advisory wrapper, prints `warning: executor tier config check failed: …`, and still exits **0**. It does not abort every workflow command.
- **`sync-agents` output is one line per tier** since v31 — `mid   sonnet @ xhigh` / `high  opus @ xhigh` (was a `claude=… codex=…` pair) — followed by the `config source:` line and the sync/drift verdict.
- **Escalation (one step since v23):** a `mid` executor that can't safely complete a slice returns `escalate` with findings (a failed/empty `mid` return counts the same); the orchestrator appends an `## Escalation` section to the slice's `plan.md` and re-dispatches the slice to `slice-executor-high` — max **1** per slice (the ladder is a single step now), never past `slice-executor-high`, plan re-approved by the operator only in `gate` mode (in the default `auto` the slice is re-dispatched straight away). `needs_operator`/`blocked` keep their meanings and still stop the run.
- **The design subagent follows the `high` tier (P26.S2).** `design-drafter`
  (`.claude/agents/design-drafter.md`) drafts a design round (see *Visual-design runbook*) and is **not
  a tier**: `EXECUTOR_TIERS`, `executors.toml` and the presets are unchanged. `sync-agents` gives it the
  `high` tier's model and effort (`executor_agent_files()`, `DESIGN_DRAFTER_FOLLOWS`), so `[claude.high]`
  and `executor-mode` govern it, and `sync-agents` re-applies it after `--update`. One knob governs every
  agent file, and design work never lands on `mid`.
- **Updating from a pre-v23 workspace:** `--update` never deletes, so it flags the now-stale `.claude/agents/slice-executor-low.md` for manual removal; delete it, drop any `[claude.low]` block from `executors.toml`, and re-run `sync-agents`. Slices already carrying `risk: medium` or `risk: low` keep working — `medium` routes to `high`, `low` routes to `mid`.
- **Upstream selection:** this bootstrap repo intentionally tracks `mode = "flex"`, and its **three** generated agent files (`.claude/agents/slice-executor-{mid,high}.md` — four before v31 — and, since v47, `.claude/agents/design-drafter.md` on the `high` tier's model and effort) must remain synchronized to that selection. `sync-agents --check` and the installer drift guard enforce it.

## Nested personal install — the default layout (v49; the default since v50)

The installer's **default layout is the nested personal install**: `sh bootstrap_agentic_workspace.sh
<dir>` with no flag installs the workspace privately, with no team-visible footprint — the engine and
state in an untracked nested git repo `<dir>/workflow/`, the skills and agents untracked in the host's
`.claude/`. The engine and installer mechanics are in architecture.md (*Nested Install*); this section is
the runbook.

**Install modes (P29).**
- **A bare install is nested.** A new or empty non-git target is `git init`ed as the host repo, with this
  workspace's commit convention recorded **confirmed** (trailers allowed), so `next` never asks
  `UNCONFIRMED`; that `git init` is undone on any pre-write refusal. A non-empty non-git target refuses.
  An existing git repo is nested with its HEAD and `git status` unchanged. The installer makes no commit
  in the host.
- **`--at-root`** reaches the committed, team-visible layout (`CLAUDE.md`, `.claude/`, `scripts/`,
  `works/`, `docs/` at the target's root) — the layout a bare install produced through v49.
  `--into-existing` stays the at-root retrofit (*Adopting into an existing repo*), and `--force-empty-ok`
  needs `--at-root` (or `--into-existing`), on `--update` too.
- **`--update` detects the installed layout** — the nested marker `workflow/.agentic-nested.json`
  versus an at-root workspace — and refreshes it in that layout, so neither `--update` nor
  `--update --dry-run` needs a layout flag. It refuses, writing nothing, when the layout is ambiguous
  (both found, no flag to choose) or a flag contradicts what is installed (`--at-root` on a nested
  install, `--nested` on an at-root workspace).
- **`--nested` is a redundant no-op** (v49's opt-in flag; a matching one is accepted, so its scripts keep
  running).
- **A bare install over an at-root workspace refuses** (use `--update`), and so does any run on a nested
  install's own `workflow/` directory (run the installer at the host root).
- **Parallel worktrees need an `--at-root` install**: `parallel-*` refuses with `parallel worktrees are
  disabled in a nested personal install`.

**What a nested install writes (P28.S2).** The engine side is `<host>/workflow/`, a nested git repo with
no `.claude/` and no `CLAUDE.md`; its contract is `CLAUDE.workspace.md`. The host side is untracked
files — the skills, the agents, `.claude/settings.local.json` and a `CLAUDE.local.md` that imports the
contract — hidden by one `info/exclude` block. It writes no CI, `.gitattributes`, host `docs/` or
`settings.json`. A skill or agent name that clashes with one of the host's installs as `wf-<name>`, and a
personal `~/.claude/skills/<name>` shadows ours (the installer warns).

**The ignore guarantee (P28.F1).** Each installed skill directory carries its own `.gitignore` of `*`
(self-hiding, so it beats a host `!.claude/skills/**`). A preflight runs `git check-ignore` with our block
as a temporary `core.excludesFile`, before any write and on `--update` too, over the agent files,
`CLAUDE.local.md`, `settings.local.json` and `workflow/`. When a host `.gitignore` re-includes one, the
install refuses with nothing written, naming `<target>: re-included by <file>:<line>:<pattern>`, with no
override. After writing it asserts an empty `git status --porcelain --untracked-files=all -- <targets>`
and prints "stays clean" only then.

**Running it (P28.S1).** Start Claude Code at the host root and run the engine from there as
`python3 workflow/scripts/workflow.py <command>`. `nested-convention` shows the host commit convention
(bare) or records it (`--confirm --text … --trailers allowed|forbidden`); `next` prints `nested_host=` and
`host_commit_convention=UNCONFIRMED|confirmed`.

**First run (P28.S2/S3).** Make the first commit in the nested repo
(`git -C workflow add -A && git -C workflow commit …`), start Claude at the host root and accept the trust
dialog, and confirm the convention with `nested-convention`. Keep any `workflow/` remote inside the
company org, and note a company policy may disable `bypassPermissions`.

**One ticket, start to PR (P28.S3).** `git switch -c <branch> origin/main` → `/create-phase` (records the
host base) → `/do-whole-phase` (two commits per slice: product to the host, in `nested-convention`'s
text; state to `workflow/`) → `/review-phase` (`phase-scope` reads the host diff) → push a PR with no
phase or slice IDs and no workflow paths. Review comments become fix slices.

**Update.** `/update-workspace` runs the plain `--update` (and `--update --dry-run`) from the host root,
then `sync-agents`; v50 collapsed v49's `(nested)` command variants into it.

## Adopting into an existing repo (retrofit)

The default bootstrap installs the **nested** layout (above), and `--at-root` installs the committed
layout, again only into an empty directory. To add the committed workspace to a repo that already has
code/docs/history, use the retrofit path — `--into-existing`, the **at-root** retrofit. It is
**non-destructive**: it adds the workspace's files, skips anything already
present, additively merges a small known set, and aborts before writing on an
unresolvable collision. See [`docs/retrofit-guide.md`](../../retrofit-guide.md)
for the full procedure; the operational essentials:

- **Invoke:** the `/retrofit` skill — the agent runs the installer — or directly: `bootstrap_agentic_workspace.sh . --into-existing` (the `--phase-name`/`--phase-objective` seeding flags were removed in v6 — nothing is seeded).
- **Four-tier collision policy:** (1) skip-if-exists for pure content (skills, templates, the `slice-executor` tier subagents, `executors.toml`); (2) install the `docs/` and `works/` subsystems only if wholly absent (gate on `docs/index.json` / `works/state.json`), and gate the final rebuild to installed subsystems; (3) additive idempotent merge for `.claude/settings.json` (union permissions) and `CLAUDE.md` (marked section + `CLAUDE.workspace.md` sidecar); (4) hard abort on a pre-existing `scripts/workflow.py`.
- **Your `AGENTS.md` is never touched (v31).** The installer no longer reads, merges into, appends to, or rewrites a repo's own `AGENTS.md` on any path, and writes no `AGENTS.workspace.md` sidecar — a retrofit and an `--update` both leave it **byte-identical** (sha-pinned by the lifecycle smoke test). One scope caveat: a *fresh* `--at-root` install into a directory that already contains `AGENTS.md` is still refused by the emptiness guard unless `--force-empty-ok` is passed (which needs `--at-root`), because `AGENTS.md` is not in the empty-ok allowlist.
- **Two passes:** classify everything first (no writes), abort up front on a tier-4 collision, then apply — so a retrofit never half-installs.
- **No seeded phase (since v6):** the workspace starts with no phases; the operator's first phase comes from the `/create-phase` intake flow.
- **Git:** the installer runs no git; the operator reviews the diff (`git status` shows only additions plus the additive `.claude/settings.json` merge) and the agent commits the adoption on their approval. The agent adds `__pycache__/` to `.gitignore`.
- **Verify:** `python3 scripts/workflow.py validate` then `next`. Retrofit is idempotent — re-running is a clean no-op.
- **Inventory (since v31, current at v51):** fresh install and retrofit each carry **18 Claude skill packages** (17 at v31), the two `slice-executor` tier agents and, since v47, the `design-drafter` agent — one tree, `.claude/`. Retrofit remains skip-if-present and never overwrites operator-owned content.

## Updating an adopted workspace to upstream

The machinery (engine, skills, subagents, contract, templates) evolves upstream;
the **update** path refreshes it in place without disturbing the downstream's own
work. Retrofit *adopts* (non-destructive, skips what exists); update *re-applies*
(overwrites machinery, preserves work). Drive it with the `/update-workspace`
skill — the agent clones the latest upstream, shows
the dry-run change-list, and applies on the operator's approval — or directly:

- **Invoke:** `bootstrap_agentic_workspace.sh . --update` (add `--dry-run` to preview the change-list and write nothing). `--update` and `--into-existing` are mutually exclusive; `--update` requires an already-installed workspace (`scripts/workflow.py` plus `works/state.json` or an active `phase.json`, or the nested marker `workflow/.agentic-nested.json`), else it errors toward fresh install / retrofit. **It detects the installed layout** (since v50; see *Nested personal install*), so a nested install is refreshed from the host root with no `--nested`; an ambiguous layout (both found, no flag to choose) or a contradicting flag refuses, writing nothing.
- **Write policy:** (1) **overwrite** machinery — `scripts/workflow.py`, the `.claude/agents/slice-executor-*.md` tier agents and `design-drafter.md`, every skill under `.claude/skills/`, and `works/templates/*`; (2) **additive merge** for `.claude/settings.json` (union permissions, never clobber); (3) **contract** — refresh `CLAUDE.workspace.md` if the repo was retrofitted, else overwrite `CLAUDE.md` in place (a repo's own `AGENTS.md` is not read or written on any path); (4) **seed-once** — `executors.toml` is created when absent and never overwritten. Everything under `works/` except templates, and **all** of `docs/`, is **preserved** untouched. A brand-new managed skill is added on update and is not classified as stale.
- **Coming from a pre-v31 (dual-harness) workspace:** the update stamps the marker to 31 and flags `.agents`, `.codex`, `AGENTS.md`, and `AGENTS.workspace.md` in the stale change-list — each exactly once — and **deletes none of them**; remove them by hand once you are satisfied, keeping any `AGENTS.md` your project maintains for other tools. The two directory entries only fire because the flagger tests `.exists()` rather than `is_file()`; that is load-bearing, not a simplification opportunity. Then drop any `[codex.*]` table from `executors.toml` and re-run `sync-agents`. If you drive the workspace from Codex, do not update — v30 is the last release with a Codex path.
- **Coming from a pre-v32 workspace:** the update brings the acceptance gate, the runtime-manifest rule and the works-as-a-product verification spec, then `sync-agents` as always. Nothing breaks: existing phases carry no `acceptance` block, stay legacy, and pass with one advisory line — opt a **live** phase in with `accept-gate <P> --require`, never a `done` one. Because `--update` never touches `docs/`, add `## Operator Runtime` to your operations doc and rewrite your `## Regression Checklist` yourself, via `doc-new-version` from `installer/payloads/doc_bodies/` in the upstream clone; until the manifest is real the first slice claiming real-browser verification stops `pending` asking for it.
- **Coming from a pre-v36 workspace:** the engine change is purely **additive** — one member (`research`) added to `SLICE_KINDS` — so existing slices, history and `validate` are unaffected and nothing needs renaming. Both agent bodies changed, so re-run `sync-agents` as always. The Aside instrument travels in the skills and agent bodies every workspace receives; only the seeded manifest's new one-line *Browser instrument for the agent* field is docs, so `--update` never delivers it — add it yourself with `doc-new-version` if you want it recorded, and note that its absence alone never stops a slice.
- **Coming from a pre-v37 workspace:** there is **no engine change at all** — `scripts/workflow.py` is untouched, so slices, history and `validate` behave exactly as before. Both agent bodies changed (the `repl`-over-Bash invocation and the dedicated-profile instruction), so re-run `sync-agents` as always; the corrected doctrine itself travels in `CLAUDE.md`, `design-cowork` and `review-phase`, which every workspace receives. The seeded manifest's **two** instrument fields are docs, so `--update` never delivers them — add them yourself with `doc-new-version` from `installer/payloads/doc_bodies/operations.md` in the upstream clone. **And undo one thing v36 told you to do:** if you ran `claude mcp add -s local aside -- aside mcp`, remove that registration — v37 no longer prescribes the MCP surface, and a standing registration costs ~1,344 tokens in every session, browser-related or not.
- **Coming from a pre-v47 workspace:** the update brings the file-based design loop, the `design-drafter` agent (a third managed agent file) and the five `design-*` commands. **Run `sync-agents` after `--update`**: updates reset agent files to the upstream defaults, and the drafter follows `[claude.high]`, so an override moves it too. A Claude Design round in flight under v46 can be finished there and imported as a bundle, or superseded by a first round under the new loop. A record built around `_ds_manifest.json`, a repo's own `design/` tree or `rounds/<NN>/output/` moves to schema 1: run `design-init`, then move each card to `docs/reference/design/cards/NN-slug.html` with the `@dsCard` marker on line 1 — `validate` does not run `design-check`, so run that yourself. Run `design-register` once per product repo to list it for a dashboard (the operator's step: it writes outside the repo).
- **Coming from a pre-v48 workspace:** nothing changes for a repo that keeps using v47's loop — an absent `Design tool:` line reads as `drafter`. A pre-v47 Claude Design record sitting at the design root fails `design-check` and is refused by `design-open`: run `design-migrate` (a dry run), then `design-migrate --apply`, and commit the renames. Run `design-init` only when the repo will also use the drafter, and only after the migration. Set `AGENTIC_DESIGN_DECK_URL` to see the design-deck URL after `design-register`. **Re-sync any copy synced at v47 before P26.F1/F2** (design-deck among them): it lacks the drafter's `new visual direction` licence, the in-page `#` fragments in the self-contained rule and the stricter `design-check` reference scan. Run `sync-agents` after `--update`.
- **Coming from a pre-v49 or pre-v50 workspace:** nothing migrates an existing install: at-root keeps updating at-root and nested keeps updating nested, with no new flag. v50 changes habits: a bare install that expected the committed layout must now say `--at-root` (without it the install is nested and needs `git`); `--nested` is redundant, so leave it or drop it; `--force-empty-ok` needs `--at-root` (or `--into-existing`), and that now applies to `--update` too, where v49 silently ignored it; parallel worktrees need an `--at-root` install. A new personal project is private by default; use `--at-root` if collaborators should receive the workspace through the repo.
- **Coming from a pre-v51 workspace:** no migration is required. A phase created before v51 carries no `consolidates` key (valid), and a docs phase created before v51 is not seen as covering what it pays, so `/rotate-backlog` may propose a docs phase for debt a live one already pays — decline it or run `archive-only`.
- **Docs rebuild is gated:** the post-update `rebuild` runs only when the repo uses the workspace's *own* docs system (`docs/index.json` plus our versioned doc-type dirs); a repo adopted over its own docs runs `next` only, so the rebuild never crashes on a foreign or absent index.
- **No pruning, just flags:** skills or machinery upstream has dropped are never deleted; the change-list flags managed-looking skill dirs (those whose `SKILL.md` sets `disable-model-invocation: true`) absent from the new manifest **and** retired machinery files (`OBSOLETE_MACHINERY` — e.g. the untiered `slice-executor.md`/`.toml` replaced in v7, and `.claude/agents/slice-planner.md` retired in v20), so the operator removes them by hand.
- **Post-update tier config:** updates reset the three generated agent files (the two tiers and the drafter) to upstream machinery while preserving the adopter's seed-once `executors.toml`. Re-run `python3 scripts/workflow.py sync-agents` after every update to reapply that preserved preset and any overrides (`validate` warns while the files drift). An update onto an older workspace seeds a missing `executors.toml` and flags the retired examples (`.env.example` from pre-v8, `executors.toml.example` from v8) as obsolete machinery (flagged, never deleted — remove them with `git rm`).
- **Provenance + version:** each install/update records `works/.workspace-version.json` (`upstream_url`, `workspace_version`, `synced_commit`, `synced_at`). `workspace_version` is the integer `WORKSPACE_VERSION` baked into the artifact (see *Building and releasing the installer*); a marker missing that key was adopted **pre-versioning**. The `/update-workspace` skill passes the upstream commit via `SYNCED_COMMIT`; the file diff is always byte-based, so the marker is informational.
- **Version-aware preview:** before applying, `/update-workspace` reports the sync as "you're on vN → upstream vM". It reads local **N** from `works/.workspace-version.json` (absent ⇒ pre-versioning) and upstream **M** from the top `## v<M>` heading in the fresh clone's root `CHANGELOG.md` (the clone is a full checkout, so the file is there — the installed target never carries `CHANGELOG.md`). It then prints every `## v` entry newer than N (their "what changed" bullets and any **Migration notes**), alongside the existing `--dry-run` file change-list. Equal versions ⇒ "already on vM; any diff below is unreleased upstream drift". Applying stamps the upstream `workspace_version` M into the marker.
- **Git:** the installer makes no git changes — the operator reviews the diff and the agent commits on their approval. Idempotent: re-running `--update` with no upstream change is a clean no-op (machinery unchanged).

## `/explain` ships with the workspace again — with first-run setup (v26 reverses v15)

Short history: the `/explain` educational-explainer rode inside the bootstrap as an
optional skill (opt-in via `--with-explain` from v2, wired to a KB document API from v4),
was **retired in v15** once the feature graduated into a portable Claude Code plugin in
the [knowledge repo](https://github.com/leetusik/knowledge), and **ships by default again
as of v26**.

**Why the reversal.** v15's reasoning — a portable plugin need not ride inside every
workspace — left a dangling pointer. Four places still tell the operator to run
`/explain`: the phase review's fixed pointer `explain: not written — run /explain for this
phase`, the contract (`CLAUDE.md`), the seeded `operations.md`, and the
installer's closing line. A plugin-free adopter followed those instructions and found no
such command. Shipping the skill closes the gap.

**What ships.** `.claude/skills/explain/SKILL.md` — discovered from disk by `build.py`, so no
build-code change was needed, exactly as the v15 deletion needed none (v31 dropped the second,
mirrored copy along with the rest of the Codex tree). The skill is
**operator-invoked only** (`disable-model-invocation: true`), matching every other workflow
command-skill. `design-cowork` was the sole model-invocable exception at the time; **since v34 there
are two, of different widths** — `design-cowork` still fires by itself whenever work turns visual,
while **`create-phase`** is callable by the agent **when instructed** (an approved plan or a direct
operator instruction) and **never on its own initiative**. `explain` is unaffected and stays
operator-invoked. The phase review still writes no explainer.

**It is a vendored fork, not a mirror.** The body comes from
`plugin/skills/explain/SKILL.md` in the knowledge repo, de-plugin-ified: every
`/knowledge:setup` reference is gone, because that command does not exist in a bootstrap
workspace, and v31 additionally dropped the two Codex-only passages (the `workspace-write`
network caveat and the `<noreply@openai.com>` attribution parenthetical). Nothing syncs the two
copies — a provenance comment under the `# explain` H1 records the upstream commit **and
enumerates all four divergences**, and re-vendoring is a manual merge. Since v31 the body is
embedded once, not twice.

**First-run setup replaces the hard stop.** Where the upstream skill stopped with "run
`/knowledge:setup`", step 2a now sets a knowledge base up. It asks for **one** thing — an
email — then installs the `knowledge` CLI (`uv tool install`, or the bundled installer
script only with an explicit yes) and runs `knowledge init --password-stdin`, which signs
the operator up or, on a 409, logs them in; either way it reuses the project and mints or
reuses an **org-level** key, then writes `~/.config/knowledge-kb/config.json` at mode 0600.
Guardrails: creating an account is outward-facing, so nothing runs before the operator
agrees; the generated password is written to a temp file and piped via stdin, never through
argv (visible in `ps`, kept in shell history); the temp file is removed on every path; a
login failure gets at most one retry. `knowledge config` (exit 0/1) is the verification
probe, but it redacts the token, so the skill re-runs its own resolver for the real values.

**Hosted-first.** `https://knowledge.hi2vi.com` is the encouraged path and the only one
walked through. Self-hosting stays supported — point `KB_API_BASE_URL` / `KB_API_TOKEN` at
your own server and every REST path works unchanged — but it is a one-line escape hatch,
not a documented procedure, and the upstream setup skill's docker-compose scaffold mode is
deliberately not vendored.

**The offline local-file fallback is deleted.** The upstream skill's "API unreachable" path
wrote markdown into a local KB checkout and committed it with `git -C <KB_ROOT>`. v21
removed the contract carve-out that authorized exactly that commit, and a hosted account has
no `kb_root`, so the path was both unauthorized and unreachable. An unreachable API is now
reported as a failed save, and `KB_ROOT` / `KB_LOCAL_FALLBACK` are documented as unused.
This costs self-hosting nothing: a self-hosted server is reached over the same REST API.

**Permissions ship narrow.** `.claude/settings.json` gains three read-only allow entries —
`Bash(command -v:*)`, `Bash(knowledge config:*)`, `Bash(knowledge guide:*)`. The
account-creating and software-installing commands (`knowledge init`, `uv tool install`, the
curl-pipe) are deliberately **not** pre-approved, so they still prompt. The settings merge
is additive and removals never propagate, which is why these went in narrow on purpose.

**`--with-explain` stays retired.** `explain` is unconditional now, so the flag remains an
unknown option the installer rejects (the wrapper's generic `-*) die "unknown option $1"`
arm). The old `WITH_EXPLAIN` / `OPTIONAL_SKILLS` wiring is not coming back.

- **Migration hazard — `--update` now overwrites an existing `.claude/skills/explain/`.**
  Under v15 that dir carried no `disable-model-invocation: true` marker, so it was treated
  as operator-owned and left untouched. It is now workspace machinery (`_is_machinery`
  covers `.claude/skills/`), so an update rewrites it
  unconditionally. A hand-maintained copy must be saved first; `--update --dry-run` shows
  it as a machinery diff. `--into-existing` still **skips** any `explain` dir already
  present.
- **A separately installed knowledge plugin is unaffected** — its command is
  `/knowledge:explain`, a different namespace from this workspace's `/explain`. You do not
  need both.
- **Release note (v26):** `WORKSPACE_VERSION` 25 → 26 plus the `## v26 — 2026-08-10`
  `CHANGELOG.md` entry with **Migration notes**, in one commit with the rebuilt artifact,
  per the release rule below. No `sync-agents` re-run is needed.
- **Verify:** `tests/retrofit_smoke.sh` asserts the fresh install **ships**
  `.claude/skills/explain/SKILL.md` and greps it to prove it carries no plugin-only setup
  reference; the dual-apply manifest covers it, and Test 8 still asserts `--with-explain`
  is rejected as an unknown option.

## The phase notebook and just-in-time reads (since v35)

Through v34 `phase.md` was **state and log in one append-only file**. Nothing was ever pruned, so a
notebook grew roughly 70–90 lines per slice — P15 finished at **819 lines** with `## Findings & Notes`
alone at 82 % of them, against eight deletions across the whole phase — while the orchestrator and
every executor re-read the file whole on every turn, so the cost scaled about **`40·N²` lines per
phase**. The damage is context-window pressure, not dollars. v35 splits the file **by audience**, puts
a budget on the half that is re-read, and stops reading everything else up front.

**`phase.md` is bounded state; `result.md` is the log.** The notebook answers *what the next slice
needs*; a slice's `result.md` answers *what this slice did* — its validation commands and outcomes,
its deviations from `plan.md`, its findings prose and dead ends, and the durable form of the
structured verdict (which is ephemeral and dies with the session, hence the **verdict block first**,
so the orchestrator and the review can `head` the file). Nothing is written into both: a note that
belongs in the notebook lives there and is referenced from `result.md` in a line.

**The seeded shape.** `new-phase` renders `works/templates/phase.md` — a real embedded machinery file,
so adopters receive it on `--update`, with a byte-identical `PHASE_MD_TEMPLATE_FALLBACK` in
`scripts/workflow.py` covering a tree that lacks it (the smoke suite pins the two as equal). The
sections are `## Objective`, `## Slices`, `## Decisions`, `## Doc impact`, `## Operator Questions`,
`## Notes for later slices`, `## Now`. `## Context`, `## Findings & Notes`, `## Constraints`, and
`## Open Questions` left the seed with v35.

**The generated `## Slices` block is the engine's, and only it.** `rebuild_index_and_state` splices a
table (`Slice | Name | Kind / risk | Status | Outcome | Result`, rows in `order`, `Result` linking
`slices/<id>/result.md` once that file exists) between `<!-- slices:begin -->` and
`<!-- slices:end -->` in every active phase — so on `rebuild`, and therefore on `next`, `new-slice`
and `finish-slice` too. Four properties make that safe:

- **A marker counts only when it is alone on its line.** The first implementation matched the literal
  anywhere and spliced the table into a prose cell that *quoted* it. Notebooks, plans and skills may
  now discuss the markers freely.
- **No markers → return untouched.** A legacy notebook or an adopter who deleted the block is a
  silent no-op, never an in-place migration.
- **Write only on change.** `write_text` always rewrites, so a read → splice → compare guard is what
  keeps a plain `next` from dirtying every notebook in the tree.
- **`phase.md` is deliberately *not* in `GENERATED_FILES`.** Only the marker block is generated, so
  `parallel-merge-finish`'s "resolve by taking either side" must never apply to the notebook. A
  conflict *inside* the block is resolved by re-running `rebuild`; the rest is merged by hand.

**`finish-slice <id> --outcome "one line"`** stores the line in `slice.json` (before the status
change, so the rebuild that follows renders the row in the same command) and it becomes the table's
Outcome cell. The orchestrator takes it from the executor's returned `summary`. Omitted, it warns and
still finishes the slice — a warning, never an error.

**Two `validate` guardrails, both warnings, never errors.** `validate()` keeps `warnings` and `errors`
in separate lists, prints warnings first, and still exits 0 with warnings — a hard cap would invite
truncating exactly the notes that matter, and the review sees the warning either way.

- **`PHASE_MD_BUDGET`.** v35 shipped a `(200 lines, 16 KB)` pair; **v39 replaced it with a single soft
  byte cap, `PHASE_MD_BUDGET = 400 * 1024` (400 KB, ~100k tokens)**, and dropped the line ceiling —
  the cap is deliberately generous, so a slice writes what the next one needs and does not compress to
  fit. Over budget warns with the advice *state to `phase.md`, detail to the slice's `result.md`*. The
  check **skips a `done` phase**: a closed notebook waiting to be archived cannot act on "rewrite it
  under budget", and without the skip this repo's own pre-v35 `P17` (446 lines / 32,850 bytes) would
  warn on every run. It still bites through `in_review`, which is where the review reads it.
  `finish-slice` prints `phase.md: <lines> lines / <bytes> bytes (budget 409600 bytes)` — with
  ` — OVER BUDGET` appended — from the same `phase_md_size()` helper `validate` uses, so the two can
  never disagree; lines still print but are **informational only since v39**, bytes are what is judged.
- **`## Doc Impact` case drift.** The canonical heading is `## Doc impact`; a case-drifted one hides
  the notes from the review. Matched per line with `re.match`, not as a substring, so a notebook may
  quote both spellings in prose (this one does).

**No more timestamp churn.** The `- Rebuilt at:` line left `works/backlog.md` and `works/deferred.md`,
so repeated `next` calls leave both dashboards byte-identical and stop dirtying the tree.
`docs/index.json`'s `last_rebuilt_at` and `works/state.json`'s `updated_at` are machine-read and keep
theirs.

**Reads are just in time — sections, not documents.** An executor reads, in order: its `plan.md` →
the phase's `phase.md` → `intent.md` **only when unsure what was asked** → `phase.json` (the
`acceptance` block) → the `docs/current/` **sections** its plan names, plus `slice.json` and the code
it will change. Never the whole doc set (330 KB across eleven docs, `decisions.md` and `operations.md`
being 73 % of it) and never `docs/index.json` (54 KB of version history, not truth). The drivers
match: `do-next-slice`, `do-whole-phase`, `review-phase` and `create-phase` take the pointer from
`python3 scripts/workflow.py next` and **drop the per-slice re-read of `works/backlog.md` and
`works/state.json`** — both are generated from the same state `next` prints — read `result.md`
head-first for the verdict block, and re-read the bounded notebook after each slice because it was
**rewritten, not appended to**, which makes the previous read stale. `design-cowork`'s build inventory
and landed spec still live in the notebook and count against its budget: one line per candidate,
the spec as pointers, the detail in the round's record.

**The edit protocol** (the executor owns it — it already owns step 4 and holds the slice's result
fresh):

- `## Slices` — never edited by hand; the engine owns everything between the markers.
- `## Decisions` — record what the slice settled and **replace a superseded line** instead of stacking
  versions of it; a decision that proved wrong is corrected in place.
- `## Doc impact` and `## Operator Questions` — **append-only**: add lines, delete nobody's.
- `## Notes for later slices` — **remove the entries this slice consumed**, add new ones tagged
  `**(from <slice>, for <slice>)**`. A note nobody still needs is a cost paid on every remaining
  dispatch.
- `## Now` — rewritten (≤ 15 lines), and last on purpose: it is the handoff the next dispatch reads
  first.

Compression is safe because it is **restorable**: the pre-edit notebook is in git (the orchestrator
commits every slice) and the detail is in `result.md` by path. What must never be lost is a decision
or an operator question.

**The review is the safety net.** Because the notebook is now rewritten rather than appended to, the
phase review **cross-checks `phase.md` against every `result.md`**: a decision a `result.md` records
that never reached `## Decisions` is a finding, and an unrouted `## Operator Questions` entry blocks
the pass. A *shorter* notebook is not a finding — that is the mechanism working.

**Measured on the phase that shipped it (P18, six slices).** Notebook after each slice's edits:
79 lines / 11,991 bytes → 80 / 13,016 → 79 / 13,993 → 79 / 14,097 → 78 / 13,817 → 78 / 13,917 at the
review. Lines never passed 40 % of their half of the budget while bytes ran 73–86 % of theirs, so
**bytes are the binding limit and the line count is slack** for prose in this style. At phase end the
engine-owned and seeded material — header, objective, the generated block, the section preambles — was
2,847 bytes, **17 % of the byte budget**; the other 83 % is hand-written `## Decisions` prose, and
pruning (landed decomposition rows, consumed notes) is what pays for each slice's additions.

**Migration.** Existing notebooks are **preserved untouched** — `--update` ships the template, and a
notebook without markers is a permanent no-op, so a pre-v35 phase runs to completion in its old shape.
To adopt the generated table in a live phase, paste the two marker lines under a `## Slices` heading
and run `rebuild`. `finish-slice` without `--outcome` still works. `CLAUDE.md` grew ~1 KB carrying the
new protocol; the reclamation is a separate editorial job (deferred **D8**), not a v35 regression.

## The phase review — validate, then branch on the verdict (v21 supersedes the v16 auto-explain)

The phase review is one `slice-executor-high` run that does two things in order:
**validate the phase's slices together, then judge them**. Only after the verdict is
settled does the run split — and as of **v21** the split is a real branch, not a
skipped step:

- **On `pass`:** **verify** the phase's "Doc impact" list against what the phase actually
  changed — an incomplete list is a review finding, not a detail, never silently filled in —
  then write only its two named gate sections (`## Regression Checklist` in qa,
  `## Operator Runtime` in operations, when this phase changed them: `doc-new-version` →
  edit the returned `edit_path` → `rebuild-docs`), report
  `doc_versions: none — deferred to a docs phase`, and return. **Since v38** the review no
  longer consolidates the phase's other notes into doc versions at all: the engine stamps a
  top-level `consolidation: "pending"` on the phase's `phase.json`, and the operator pays the
  whole debt later, across every owing phase at once, in a docs phase the operator creates
  (`create-phase`'s *docs-phase route*) — never per phase at the review. See
  *Durable-doc consolidation — a docs phase the operator creates* below.
- **On `changes_requested` or `blocked`: stop and hand back.** Writing the two gate sections
  is **pass-only work**; the executor runs none of it, and no other pass-only step
  either. It returns the verdict, numbered findings, and proposed fix slices
  (`<P>.F<n>`, one line of scope each) to the orchestrator, which decides what happens
  next. The docs stay unversioned — and the phase's consolidation debt unpaid — until the
  docs phase.
- **On `pass` in a phase running in its own worktree (the operator asked for one; opt-in
  v24–v41, the default in v42, opt-in again since v43): write no doc versions at all — not
  even the two gate sections.** A branch review already only **verifies** that `phase.md`'s
  "Doc impact" list covers every durable-truth change the phase made — an incomplete list
  is a review finding — and returns
  `doc_versions: none — deferred to post-merge consolidation (parallel mode)`. Every version,
  including the two gate sections, is cut later, one phase at a time, on the default stream.
  The `docs/current` vs. `docs/index.json` parity check moves to that consolidation step too.
  This is engine-enforced, not merely documented: `doc-new-version` refuses to run on a
  parallel stream. **The two gate sections are recorded, not lost (v42):** where a
  default-stream review writes `## Regression Checklist` and `## Operator Runtime` itself as
  its one carve-out, the branch review appends them to `## Doc impact` as notes tagged
  `(gate section — written at merge)` — the checklist lines verbatim, the runtime change as
  exact text — and the post-merge step writes exactly those, nothing more.

**The boundary (v41).** The review reviews the phase, not the whole system.
`python3 scripts/workflow.py phase-scope <P>` prints what the phase changed — its creation commit,
the base..head range (the creation commit's parent to `HEAD`, or to the commit that recorded a
passing review on a done phase; the merge-base with the default branch in parallel mode) and the
product files in it, `works/` and `docs/` excluded — and the boundary is those files, the surfaces
they feed, and the phase's own claims. Everything the review checks is inside it; a shared file
widens it to every surface it feeds; a checklist line that cannot be placed is inside; and anything
the review notices outside it is an observation listed as a deferred-job candidate for the
orchestrator to file, never a finding. The product-wide sweep is an operator-created QA phase
(`create-phase`'s *QA-sweep route*). The command is advisory: without git it prints one line and
exits 0.

**"Stop" is scoped to the pass-only work, not to the review.** Validation and judgment
always complete first, across every slice — the executor never aborts at the first
failing check, or the orchestrator learns one finding per review cycle instead of all
of them at once. The distinction is stated in that order on every surface (`review-phase`,
`do-next-slice`, `do-whole-phase`, `slice-executor-high`, and the contract bullet — one copy
of each since v31), and the clinching sentence is
*"This is a full stop, not a skipped step you carry on past."*

**The review writes no phase explainer (v21 reverses v16).** Between v16 and v20 a
passing review auto-produced an HTML phase explainer by locating and following the
external knowledge plugin's explain skill. That step is **gone from the review's
default behaviour**: the review locates no explain skill, runs no KB probe, has no
offline fallback, and commits nothing anywhere. Explaining is now a **separate
operator-run operation** (`/explain`). The review's whole remaining obligation is one
fixed pointer line, reported in `result.md` and in the structured return and
**identical on every verdict** — it costs the executor no work, so it does not collide
with the stop rule:

    explain: not written — run /explain for this phase

- **The KB-repo commit carve-out is deleted, not narrowed.** v16 had granted the review
  slice one narrow exception to "never commit" — the explain skill's offline fallback
  committing with `git -C <KB_ROOT>` in the *separate* knowledge-base repo. With
  auto-explain gone the exception has no purpose, so `slice-executor-high`
  now reads "no exception anywhere: not in this workspace's repo and not in any other
  git root, on any slice kind", with read-only inspection (`git status` / `git diff`)
  explicitly still fine — the bright line is about *writes*. `slice-executor-low` /
  `-mid` never carried the carve-out.
- **`WebSearch` / `WebFetch` stay on the high tier.** They were added in v16 for
  the explainer's cited research, but a reviewer occasionally needs to check an
  external fact, so they remain on `.claude/agents/slice-executor-high.md`'s `tools:`
  line by the operator's explicit call (cheap to remove later if they go unused).
  `sync-agents` patches only `model:` / `effort:`, so that line survives sync and
  `sync-agents --check` stays green.
- **Release + adopter impact.** Ships as workspace **v21** (`WORKSPACE_VERSION` 20 → 21
  + the `## v21` CHANGELOG entry, one commit with the rebuilt artifact). **Migration
  notes: nothing to delete or configure** — the review simply stops writing explainers;
  run `/explain` when you want one. Nine live machinery files carried the change; the
  fresh-install banner (`installer/main.py`) and the seeded
  `installer/payloads/doc_bodies/operations.md` knowledge section were part of it, since
  both had claimed a passing review auto-saves the explainer.
- **Lesson (v21):** the two surfaces above say "auto-**save**", not "auto-explain", so a
  grep for `auto-explain` missed them and a fresh-install probe is what caught them.
  When editing explainer/knowledge behaviour, grep `explain|explainer|auto-save|KB_API`
  across `installer/payloads/` **and** the banner prints, not just the skills.

## Durable-doc consolidation — a docs phase the operator creates (since v38)

**Why.** Through v37 a passing review consolidated the whole phase's `## Doc impact` notes into new
doc versions itself; P21 measured that read at 90–97% of the review's own budget. v38 moved the work
out to a phase the operator creates, so the review only verifies the list and writes its two named
gate sections (see *The phase review* above). This section states the resulting runbook.

**The debt.** A passing review stamps a top-level `consolidation: "pending"` field in the phase's
`phase.json` when the phase's `## Doc impact` list has real notes (`phase_consolidation()` is the
single reader every command shares). `parallel-start` also stamps `"pending"` inside the parallel
`execution` block at the stamp, before any review, so a parallel phase owes the debt from its stamp;
every write goes through `set_phase_consolidation()`, which mirrors the top-level key into that
block. `phase_consolidation()` reads the top-level key first, then falls back to the in-block field,
which covers a stamped-but-unreviewed parallel phase and v24–v37 files alike — nothing is migrated.
An owing phase validates and runs to completion exactly as before — it just stays in `active/` until
the debt is paid: `archive-phase` refuses it, `archive-all` lists it, and `rotate-backlog` leaves it
active — and, since v51, proposes the docs phase that pays it (*Starting one*, below).

**Surfacing.** `next` and `validate` both print `consolidation_owed=<phases>` (`validate`'s copy is a
warning) whenever at least `CONSOLIDATION_DEBT_MIN_PHASES` phases owe — that knob is `1` in
`scripts/workflow.py`, the deliberate default, so the debt is visible the moment anything owes,
whatever cadence the operator later runs docs phases on. Neither call changes what `next` selects or
what `validate` exits with.

**Staleness (v39).** Since a doc can sit unconsolidated for a while, v39 makes that explicit rather
than silent:
- `python3 scripts/workflow.py docs` prints a per-doc last-updated marker —
  `updated=<date> source=<slices> commit=<sha>` — under every doc, and flags a doc **STALE** when an
  unconsolidated `## Doc impact` note is newer than its latest version, naming the notes and the
  owing phases.
- `validate` carries the same rollup as a `stale_docs=` warning beside `consolidation_owed=`:
  advisory, exit 0, and silent when nothing is owed.
- The doctrine: a **STALE** doc is evidence to check against the owing phases' notes, never current
  truth on its own.

**Starting one.** `python3 scripts/workflow.py docs-debt` is the worklist: every owing phase, its
`## Doc impact` notes verbatim, the docs they name, and the exact pay command
(`docs-consolidated <P>` on the default stream, `parallel-consolidated <P>` for a merged parallel
phase), plus a per-doc rollup for the default one-slice-per-doc cut. Each owing phase a live docs phase
covers also gets a `paid by: <P> (<status>)` line beneath its `pay:` line (v51). The operator starts the
phase through `create-phase`'s *docs-phase route*: refine → clarify → confirm →
`new-phase … --consolidates <the confirmed phases>`, `intent.md` records the `docs-debt` scope, then
STOP — an ordinary phase, on the default stream always (never a worktree: `doc-new-version` /
`docs-consolidated` / `parallel-consolidated` only run there).

**`/rotate-backlog` is the default entry point (v51).** `rotate-backlog` archives every clean phase as
before and then **prints** a read-only docs-phase proposal, on every exit path: `docs_phase_proposal=`
with `phase=` (one above the highest phase number, active or archived), `name=`, `objective=`, the exact
`new-phase … --consolidates …` line (`create:`), a `scope:` pointer to `docs-debt` and a proposal-only
closing line; `docs_phase_covered=<P> (pays …)` when a live docs phase already covers a debt-only phase
(and it proposes nothing for that phase); or `docs_phase=none`. A phase held back only by unpaid
consolidation (every slice done, review `pass`, `consolidation: pending`, no other blocker) is proposed;
one blocked for any other reason (unfinished, unreviewed, an unmerged parallel branch) is reported as
before and never proposed. The skill is **propose-then-confirm**: it archives, relays, reads the
block's ending, and on a proposal presents the name, objective and `docs-debt` scope, asks once, then on
the operator's yes runs the `create:` line, fills `intent.md` per the docs-phase route and STOPs; the
operator may edit the name or objective or narrow the list (a phase left out keeps owing and stays
active). **Opt out:** `/rotate-backlog archive-only` (the engine's `rotate-backlog --archive-only`)
keeps the pre-v51 archive-and-report output and prints no proposal. **`new-phase --consolidates
P26,P27`** marks the phase as the docs phase that pays them — an optional top-level `consolidates` key
in its `phase.json` and the only docs-phase marker (nothing reads a phase's name or `intent.md`); it
refuses, writing nothing, when an id is not an active phase owing consolidation. Only a **live** docs
phase covers: a finished one covers nothing, so rotate proposes again. The `archive-phase` skill says
rotate leaves a debt-owing phase active and proposes the docs phase that pays it.

**Running one.** `DECOMP` cuts one `docs` slice per doc (a doc that collects notes from several
owing phases still gets exactly one new version). Each slice runs the **executor's docs-slice
carve-out** (P23 OQ1, operator-approved): `doc-new-version --doc <doc> --summary "…" --source
"<P>.REVIEW, …"`, edits only the returned `edit_path`, then `rebuild-docs` — no other workflow
command, and no source edit. The orchestrator records `docs-consolidated <P>` (or
`parallel-consolidated <P>`) per covered phase once its notes have all landed, which is what clears
`docs-debt`, the STALE flag and the archiving gate together. A docs phase leaves no `## Doc impact`
notes of its own — it creates no new durable truth — and its acceptance gate is normally `--waive`d
at the `DECOMP` boundary, since it changes no operator-visible surface.

**Section-size warning.** `validate` and `doc-new-version` both warn (advisory, exit 0) when a
`docs/current` H2 section passes `DOC_SECTION_WARN_BYTES` (10 KB), naming the doc, the section and
its size — visibility, not a mandate to split. `doc-new-version` adds that any split belongs in the
new version file being written, never hand-edited into `docs/current`.

## The operator acceptance gate — how it is driven (since v32)

The gate is the one place in the workflow where a **human who is not an agent** has to act before
work can be called done. Its command surface is deliberately one command; the discipline is in
*when* it is run.

**Declare at the `DECOMP` boundary — never by omission.** Right after `finish-slice <P>.DECOMP`, and
in the same commit, the orchestrator decides from `intent.md` and the decomposition whether the phase
changes anything the operator can see, then runs one of:

```sh
python3 scripts/workflow.py accept-gate <P> --require
python3 scripts/workflow.py accept-gate <P> --waive --note "why nothing operator-visible changes"
```

`--note` is mandatory on `--waive`: "not operator-visible" is a claim someone makes, not a default
someone forgets. Neither flag changes the phase's status — the phase is still being built. Forgetting
is not survivable: `review-phase --verdict pass` refuses an undeclared phase and names both flags.

**Open it at the review, then STOP.** The review executor validates all slices, runs its gate stages,
judges, and returns `walkthrough` beside `review_verdict`. The
orchestrator — not the executor — then runs

```sh
python3 scripts/workflow.py accept-gate <P> --open --walkthrough "<the returned walkthrough>"
```

which records the walkthrough, stamps `requested_at`, sets the phase `pending`, files nothing else;
the orchestrator files any deferred jobs the review listed, runs `validate`, commits, reports the
walkthrough to the operator, and stops. `next` then prints `WAITING ON OPERATOR`,
`acceptance_gate=open`, the walkthrough text, and the clear command.

**The operator has the last word.** Accepting is
`accept-gate <P> --clear [--note "what I saw"]` (theirs to run, or the orchestrator's on their
explicit say-so) — the phase returns to `in_progress`, and on that resume the `REVIEW` slice is
still `in_progress` with a `result.md` carrying `review_verdict: pass`, so the orchestrator records
the pass **without re-dispatching the review**. Reporting failures instead is
`review-phase <P> --verdict changes_requested --note "operator-reported: ..."` — never refused, and
it resets the gate — which becomes `fix` slices and a re-review from the top. Clearing a gate is
never `set-phase-status`.

**What the review executor owes on a gated phase** (`acceptance.required: true`, and only then), in
order, after validating the slices and before rendering the verdict: find the manifest; open the
running product **itself** and spot-check the phase's headline claims; walk the surfaces the phase
changed with fresh eyes as a first-time user, reporting everything dead, confusing or annoying there,
explicitly **not** judged against the design record; re-run the `## Regression Checklist` lines
inside the phase's boundary (v41 — `phase-scope <P>` names the changed files, a shared file widens
the boundary, and the outside lines are recorded by count with the diff as the proof, never re-run)
and append this phase's headline lines; route every `## Operator Questions` entry (into the walkthrough, or as a deferred job
listed for the orchestrator to file); return the `walkthrough`. **Since v38** the review's pass path
writes only its two named gate sections (the `## Regression Checklist` append above is one of
them), still *before* the gate opens; consolidating the rest of the phase's "Doc impact" notes is
the docs phase's job, paid later across every owing phase at once.
Waived and legacy phases skip the whole section.

**The operator runtime manifest (`## Operator Runtime`).** Any slice claiming "verified in a real
browser" verifies in the runtime and access path that section of the adopting workspace's operations
doc records — run command(s); dev vs production mode; the origin/host the operator browses;
devices/viewports/browsers; the production build command + origin when they differ; whatever else is
needed to see what they see — and additionally in the production build when the two differ. The
executor's most convenient runtime is not the operator's, and whole bug classes (dev-only
double-effects, reload semantics, LAN or tunnel origins, small viewports) live in exactly that gap.
The seed ships the section with the line
`- Status: UNFILLED — fill before any slice claims real-browser verification`; **an absent section
and an unfilled one mean the same thing** — the executor returns `needs_operator` and the
orchestrator sets the slice `pending`, rather than assuming.

**Two instrument fields since v37 — one optional, one conditionally required.** The seeded manifest
gains `- Browser instrument for the agent:` (Aside if it is installed on this machine, otherwise the
real browser an agent may drive here) and, directly under it,
`- Agent's Aside account id (required whenever the instrument above is Aside):`. The first is there
because the instrument's fallback branch turns on a **per-machine fact** no skill can carry and no
agent should decide on the operator's behalf, and it stays explicitly **optional**: its absence alone
never stops a slice. The second is there because Aside is a real desktop browser and `--account <id>`
picks a real signed-in profile — an agent on the operator's own profile can act *as* the operator —
so the requirement is written **relative to the field above it** rather than absolutely: name no
instrument and there is no profile to record.

**The runtime halt did not move; v37 adds a separate one.** **Instrument and runtime are different
axes** — Aside *drives* the runtime this manifest records and never substitutes one of its own, and
the absent-or-`UNFILLED` → `needs_operator` → `pending` rule is about the **runtime**, so a manifest
that names no instrument is still not an unfilled manifest. Without that clause the v36 field would
have become a fresh halt condition for every adopter who never receives it. What v37 does add is a
**third** halt on the *profile* axis: a manifest naming Aside with **no** agent account id, or a
machine holding only the operator's personal profile, returns `needs_operator` — never a borrowed
personal profile "just for this check", and never an account the workspace creates for the operator.
Because `--update` never touches `docs/`, **both** fields reach **fresh installs only**. Copy the two
lines from `installer/payloads/doc_bodies/operations.md` in the upstream clone with `doc-new-version`
if you want them recorded. Installing Aside is an operator action this workspace never takes for
you.

**This repository's manifest records a CLI with no browser.** The bootstrap workspace ships machinery,
not a browsable product: there is nothing to open in a browser, so its phases are legacy-shaped or
waived and the gate stages never fire here. `## Operator Runtime` below is nonetheless **filled** for
this repo (D50, P31), so a "verified in a real browser" claim is answered by the manifest — those claims
do not apply, and verification is live CLI runs — rather than by an absent section. The manifest is
durable truth for *adopting product workspaces*; the seeded copy in
`installer/payloads/doc_bodies/operations.md` is where this repo maintains the template.

**Adopters get the gate, not the docs.** `--update` preserves all of `works/` and `docs/`, so every
phase an adopter already has keeps **no `acceptance` block** and passes exactly as before, and the
seeded `## Operator Runtime` + rewritten `## Regression Checklist` reach **fresh installs only**. To
opt an in-flight phase in, run `accept-gate <P> --require` on a **live** phase — never on a `done`
one, which is accepted and then correctly fails `validate` ("done but its operator acceptance gate
was never cleared"). To get the two doc sections, copy them from the seed with `doc-new-version`
(never by hand-editing `docs/current/*.md`) and fill the manifest.

## Phase worktrees (on request; opt-in v24–v41, the default in v42, opt-in again since v43)

A phase can run on its own branch + git worktree, with the orchestrator session entering it, so
two phases can progress at once without fighting over one next-slice pointer, and the default
checkout's uncommitted work never mixes with a phase's commits. v24 introduced this as an opt-in the
engine only ever *suggested*; v42 made it the default for every phase; **v43 put it back to opt-in**,
because one phase at a time is the normal shape of this workspace and a branch per phase made every
ordinary run pay for parallelism it never used. So: **a phase runs on the current checkout unless the
operator asks for a worktree**, and nothing else moves it — not the engine, not `create-phase`, not
the do-* skills on their own initiative. The phase is the unit of parallelism: slices inside it stay
sequential, never fanned out. **A nested personal install has no worktrees (v49):** `parallel-*`
refuses there, so parallel worktrees need an `--at-root` install.

**The eight worktree rules** — the same list the contract and the `parallel-phase` skill carry:

1. **When — only when asked** — a `planned` phase moves into its worktree on the operator's word
   and nothing else: the `worktree` mode word on `/do-next-slice` / `/do-whole-phase` (or the same
   thing in their own words), `parallel-start <P>` run by their own hand, or an explicit instruction
   to run two phases at once. The do-* skills run `parallel-start` when told to and **never on their
   own initiative**; `create-phase` never does; a phase already carrying the stamp is entered without
   asking again. A `hint:` line is a suggestion to relay, not an instruction to act on.
2. **Where** — `<repo>/.claude/worktrees/P<N>-<slug>` on branch `phase/P<N>-<slug>`
   (`--worktree PATH` overrides). The engine adds `.claude/worktrees/` to `.git/info/exclude` in
   the common git dir — never to `.gitignore`, which is the adopter's file — so the nested worktree
   is invisible to `git status` on the default checkout.
3. **The stamp commit** — the one fixed-message engine commit (`chore(works): opt <P> into
   parallel execution`; the single deliberate exception to "the engine never commits", because the
   stamp must exist on both branches) contains **exactly** the phase folder plus the five
   regenerated `works/` files (`state.json`, `index.json`, `backlog.md`, `deferred.md`,
   `events.jsonl`), via `git add -- <paths>` + `git commit --only -- <paths>`. A phase folder not
   yet committed goes in whole.
4. **What stays behind** — a dirty or staged default checkout does **not** block entry (v42 drops
   the v24 clean-tree guard). Everything else stays there, uncommitted and untouched, and the
   worktree starts from that stamp commit — "start from the latest commit".
5. **What still refuses** — every guard runs before any mutation, so a refusal leaves zero partial
   state: the phase is not `planned`; it already carries an `execution` block (parallel or pinned);
   no git repo; the checkout is on a parallel stream; a merge or rebase is in progress; the branch
   exists or is stamped on another phase; the worktree path exists; an overridden path's parent is
   missing.
6. **Enter and exit** — the orchestrator calls `EnterWorktree` with the printed path in the same
   session, re-runs `next` (`stream=phase/…`), and works there; background Agents dispatched from
   there run in the worktree. `ExitWorktree` `keep` returns to the default checkout for integration
   and never removes the worktree. Stream membership is the current git branch vs. the stamped
   `execution.branch`, never a marker file, so a teammate's plain clone of the branch works too.
   Fallback when a session cannot switch: drive the other checkout's engine by absolute path
   (`python3 <checkout>/scripts/workflow.py …` — `ROOT` derives from the script's own location).
7. **The merge** — a **local `git merge --no-ff`** on the default checkout after `parallel-gate <P>`
   is OPEN, never past a closed gate; the nine-step sequence is below.
8. **Staying on `main` needs nothing** — it *is* the default: no flag, no stamp, no `execution`
   block. `parallel-skip <P>` and `new-phase --on-main` are **retired no-ops** (v43), kept callable
   only so v42 habits and scripts survive the upgrade: they write nothing and report where the phase
   already runs. A docs phase needs no pin either — it runs here like everything else, and since
   `doc-new-version` / `docs-consolidated` only work on the default stream, **never ask for a
   worktree on a docs phase**. A phase still carrying v42's `execution: {"mode": "default"}` pin
   keeps it, still validates, and is refused by `parallel-start` rather than overridden; un-pinning
   is a deliberate hand edit.

Selection, the `works/state.json` pointer, and a `pending` halt are stream-scoped; generated files
are **regenerated, not merged** (`parallel-merge-finish`, never hand-edited).

### The seven commands

| Command | Runs on | Does |
|---|---|---|
| `parallel-start <P> [--worktree PATH] [--slug SLUG]` | default stream | Stamps the phase, makes the stamp commit, cuts `phase/P<N>-<slug>` and adds the worktree under `.claude/worktrees/` |
| `parallel-skip <P>` | anywhere | **Retired no-op (v43)**; reports where the phase runs and writes nothing. `new-phase --on-main` does the same at creation |
| `parallel-status` | any checkout | Read-only cross-stream view (`pinned_to_default=` included); the only workflow command that writes nothing |
| `parallel-gate <P> [--branch-ref REF] [--main-ref REF]` | any checkout / CI | Quiet-point gate: `GATE OPEN` (exit 0) or `GATE CLOSED` + numbered reasons (exit 1) |
| `parallel-merge-finish` | default stream | Right after the merge: regenerate every generated file and list the phases still owing doc consolidation |
| `parallel-consolidated <P>` | default stream | Records that the deferred consolidation is done |
| `parallel-teardown <P>` | not the phase's own branch | Retires the merged branch + worktree |

- **`parallel-start`** — the refusal list is rule 5, in that order, all before any mutation. It no
  longer checks for a clean tree: `git commit --only -- <paths>` commits exactly the stamped paths
  whatever else is staged or dirty, which is what lets a phase start from the latest commit while the
  operator's half-finished edit stays in the default checkout. It prints the branch, the worktree
  path, what the stamp commit contains, the exclude line it wrote (once, idempotently), and the
  `EnterWorktree` next step. Un-pinning a pinned phase means deleting its `execution` block from
  `phase.json` by hand; the command refuses rather than doing it.
- **`parallel-skip`** — retired in v43 into a no-op: it exists only because v42 made the worktree
  the default, and the default stream needs no marker. It still resolves the phase (an unknown id is
  still an error), prints that it is a no-op and where the phase actually runs, writes nothing,
  appends no event, and exits 0 — so an adopting workspace's habits and scripts survive the upgrade.
  `validate` still accepts a v42 pinned block where one exists and skips the branch/worktree checks
  for it; the backlog still shows `pinned: default stream` beside such a phase and `parallel-status`
  still lists `pinned_to_default=`.
- **`parallel-status`** answers "what is happening on every stream right now?" from any checkout:
  this stream's pointer, then per worktree phase its branch / worktree / consolidation state and the
  **branch-side slice table** read with `git show` / `git ls-tree` — which the default stream's own
  `works/backlog.md` cannot show before the merge — the pinned phases, and a one-line verdict naming
  the next command. It deliberately skips the usual rebuild (it is meant to be run *from* a worktree,
  where a rebuild would rewrite that checkout's dashboards as a side effect), reports a `source=`
  line saying what it read, and falls back to the local folder copy once the branch is torn down.
- **`parallel-gate`** reads the branch phase's `done` + review `pass` **from the branch**, never from
  the default stream's stale pre-merge copy, and requires the default stream to be quiet (every
  default-stream active phase `planned` or `done`; `in_progress` / `in_review` / `pending` /
  `blocked` close it — other worktree phases never make it busy). Run from inside the phase worktree
  (v42) it reads the default stream from the **local default branch** and says so
  (`main_state_source=main (local default branch; this checkout is the phase branch)`); it never uses
  the phase checkout's working tree as a stand-in for main.
- **`parallel-merge-finish`** refuses while a merge is in progress, then re-derives every generated
  file and lists each merged-but-unconsolidated phase with its `phase.md` "Doc impact" location and
  the exact follow-up sequence — explicitly **one phase at a time**. It makes no commit.
- Archiving is gated: a phase whose `consolidation` is still `"pending"` cannot be archived
  (`archive-phase` refuses, `archive-all` lists it, `rotate-backlog` leaves it active and proposes the docs phase that pays it, v51). **Since
  v38** the debt is a **top-level** `phase.json` field, `phase_consolidation()`'s single source of
  truth for every phase, not only a worktree one — every owing phase reads it. `parallel-start`
  stamps the in-block `execution.consolidation` field at the stamp, before any review, and every
  write mirrors it there too; `phase_consolidation()` reads the top-level key first and falls back
  to that in-block field, which covers a stamped-but-unreviewed parallel phase and v24–v37 files
  alike — nothing is migrated. `parallel-teardown` only *warns* in that state — removing a worktree
  is reversible, archiving is not.

**The two hints (engine half).** Restored in v43 to what they were before v42 — *suggestions*, fired
only where a worktree pays, and silent in the ordinary one-phase-at-a-time run. `new-phase` prints
`hint: <busy> is in progress -- this phase can run in parallel on its own branch: ... parallel-start
<P>` when it creates a phase while another is `in_progress` on this stream; `next` on the default
stream prints `hint: <P> is waiting behind <current> -- it can run in parallel on its own branch:
... parallel-start <P>` when the current phase is `in_progress` and a later one is still `planned`.
Both run nothing and touch no generated file, and **neither is acted on by an agent**: the rule in
the contract, both do-* skills and `create-phase` is *relay a hint, never act on it*. A phase already
stamped gets no hint, and neither does a worktree checkout.

### The integration sequence — a local merge (agent-run, since v42)

After the branch review passes, the orchestrator runs the whole integration itself — the
`parallel-phase` skill holds the runbook. If anything closes the gate or turns a check red
mid-sequence, it **stops and reports** instead of merging:

1. `parallel-gate <P>` from the worktree — `GATE CLOSED` means stop, never merge.
2. `ExitWorktree` `keep` — back to the default checkout; the worktree stays for the teardown.
3. `git pull --ff-only`, only when the default branch tracks a remote.
4. **STOP and ask** if the index is not clean, or a file the merge touches is uncommitted — typically
   the generated `works/` files after a phase was created on this checkout since the stamp,
   which is workflow state to commit first, never the operator's edit to discard (git refuses both;
   the orchestrator never unstages or discards their work). Then
   `git merge --no-ff phase/P<N>-<slug> -m "merge(P<N>): <name>"` — an orchestrator commit. A
   conflict in a generated file: take either side, `git add`, conclude (step 5 regenerates it);
   `phase.md` prose is merged by hand.
5. `parallel-merge-finish` — regenerates, lists the consolidation debt, makes no commit.
6. `doc-new-version` + `rebuild-docs` for each `## Doc impact` note tagged
   `(gate section — written at merge)` — the review's two gate sections and nothing else; none
   tagged = skip.
7. Commit the regenerated files and those versions.
8. `parallel-teardown <P>` — removes the worktree and the merged branch (refuses on an unmerged
   branch, from the branch itself, or a non-clean worktree) and nulls `execution.worktree`.
9. Commit the `phase.json` change.

The rest of the debt is the docs phase's, which records `parallel-consolidated <P>` and thereby
unblocks archiving. The engine has no merge wrapper: the merge is an ordinary orchestrator commit,
with `parallel-gate` as the one shared check that both CI and the agent run.

**The remote variant — push → PR → CI → `gh pr merge`.** Only when the operator asks or the repo's
policy requires it; it replaces steps 2–4: `git push -u origin phase/P<N>-<slug>` (the interactive
permission prompt is the operator's approval — nothing is pre-allowed) → `gh pr create` (one PR per
phase, body from `phase.md`) → `gh pr checks --watch` (red → stop) → `gh pr merge --merge` (a merge
commit; no squash, no rebase) → `ExitWorktree keep` + `git pull` → continue at step 5. The engine has
no `gh` wrapper: PR steps stay skill-guided so `gh` auth/output/error handling remains agent
territory and `workflow.py` stays offline-testable.

### Workspace CI

`.github/workflows/workspace-ci.yml` ships with the workspace:

- job **`validate`** — runs `python3 scripts/workflow.py validate` on every push and PR, and
  shell-guards the upstream-only checks (`installer/build.py --check`, `tests/retrofit_smoke.sh`)
  on the presence of those files, so an adopting workspace with no `installer/` or `tests/` skips
  them cleanly;
- job **`parallel-gate`** — runs only on a `pull_request` whose head ref starts with `phase/` (the
  remote variant). It checks out the **PR head sha** (`fetch-depth: 0`) rather than the default PR
  *merge* commit (whose `works/` is a blend of both sides), derives `<P>` from the branch name, and
  runs `parallel-gate <P> --branch-ref HEAD --main-ref origin/<base>`. A closed gate exits 1 → red
  check; whether that blocks the merge is branch protection's business.

No external actions beyond `actions/checkout@v4`, ASCII only, no secrets.

### Installer and adopter impact (workspace v24)

- `.github/workflows/workspace-ci.yml` is **seed-once** — created when absent, never overwritten,
  because an adopter's CI is theirs to own.
- `.gitattributes` is **line-merged** — `works/events.jsonl merge=union` is appended only when that
  exact line is absent, and existing content is never rewritten. Skipping the file entirely would
  silently drop the union rule exactly on the repos where a phase-branch merge conflicts.
- Both are emitted by one policy helper, so fresh install, `--into-existing` and `--update` behave
  identically, and neither trips the fresh-install conflict guard.
- **The shipped `.claude/settings.json` deny narrows from `Bash(git push:*)` to
  `Bash(git push --force:*)`.** Agent-driven integration has to push phase branches, and a blanket
  deny blocked that outright with no prompt; pushes now go through the normal interactive
  permission prompt (nothing is pre-allowed) while force-pushes stay denied. **Settings merges are
  additive and a deny can never be removed downstream, so existing adopters must delete the old
  `Bash(git push:*)` line by hand.**
- `.githooks/pre-commit` also matches `^\.github/` and `^\.gitattributes$`, since both are embedded
  payloads and editing either must force the artifact-parity check.

### Adopter impact (workspace v42)

- **No new seeded file and no `.gitignore` edit.** The exclude line lives in `.git/info/exclude`,
  written by the engine on the first `parallel-start` (idempotent: one comment line, one path line).
  `git status` on the default checkout never shows the nested worktree.
- **Coming from a pre-v42 workspace:** phases already `in_progress` finish on the default stream;
  a phase enters a worktree only when the operator asks (`parallel-start <P>`, or the `worktree`
  word on a do-* skill) — and never ask for one on a docs phase. The `update-workspace` skill's
  last step says the same.
- **The push-deny note above now matters only for the remote variant.** A local merge pushes
  nothing; the narrowed deny and the by-hand deletion of an old blanket `Bash(git push:*)` line
  apply only when the operator asks for push → PR.
- `tests/retrofit_smoke.sh` (Test 12) exercises the dirty-tree stamp commit, the nested worktree and
  its exclude line, the retired pins stamping nothing, the gate run from inside the worktree, and a local merge
  followed by `parallel-merge-finish` and teardown.

### The `parallel-phase` skill

`/parallel-phase` is the single source for the lifecycle: the eight rules, `parallel-start`'s stamp
and refusals, stream-scoped work in the worktree, the branch review's deferral with the recorded
gate sections, the nine-step local merge and the remote variant. Like every other command skill it
is **explicit-invocation only** — but the default it describes is not: `do-next-slice` /
`do-whole-phase` run `parallel-start` and enter the worktree when the operator asks for one.
`create-phase`, `review-phase`, `archive-phase` and `update-workspace` carry only the matching relays
and gates, and the contract lists the seven command names — the contract routes, the skill explains.

## Knowledge setup — first-run setup by default, env vars as the override (v17, superseded by v26)

`/explain` files its HTML phase explainer into a **knowledge base**; this is how a
workspace points at one. v17 made the plugin-free **env-var/REST path** the documented
default; **v26 supersedes that**: the skill now ships with the workspace and sets a
knowledge base up on first run (see the section above), so the two exports below are the
**override** for an existing base — hosted or self-hosted — rather than the primary setup.
A freshly bootstrapped workspace ships the same guidance in
its own seed `operations.md` (a `## Knowledge (phase explainers)` section between
Environment Variables and Deployment) plus a `Knowledge (optional)` line in the
fresh-install stdout. Since **v21** both of those seeds say plainly that explaining is
an **operator-run step and the phase review writes no explainer** — before v21 they
described a passing review auto-saving one, which would have shipped a false claim into
every freshly bootstrapped workspace's `operations` v0001.

- **Two exports in `~/.zshenv`, never a repo `.env`.** Sign up at the knowledge
  service, mint an API key, and export it where every zsh invocation inherits it:

      export KB_API_BASE_URL="https://knowledge.hi2vi.com"
      export KB_API_TOKEN="vk_..."

  `~/.zshenv` (not a repo `.env`) is deliberate: Claude Code does not
  auto-load a `.env` into the process environment, so the explain skill's resolver
  would never see it — and a secret in a repo file risks an accidental commit (this
  repo's own retired executor-tier `.env` taught the same lesson). One org-level key
  serves every repo; each document's project defaults to the repo's directory name.
- **The agent saves via plain REST.** With the env vars set, `/explain` saves the
  explainer over plain REST (a Bearer-headed `POST`),
  no plugin install required. The explain skill's resolver reads env vars first,
  overriding any config file. Cloudflare in front of the service is **not** a barrier —
  a plain `curl` reaches the app, and a `401` without a token is the app itself, not a
  challenge. (Through v30 this path also had to document a Codex sandbox caveat —
  `workspace-write` blocked outbound network, so the save silently skipped. v31 removed
  Codex, and with it that caveat; Claude Code needs no network opt-in.)
- **Plugin as the alternative/richer path.** The Claude Code knowledge plugin
  (`/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge`
  → `/knowledge:setup`, `/knowledge:explain` on demand) stays available for a richer
  workflow; the env-var/REST default needs none of it.
- **The SaaS side is consumed, not built here.** Org-level keys and returned doc URLs
  are owned by the knowledge service (its sibling phases P18/P19/P20); this repo
  documents the contract it consumes and implements no SaaS-side behavior.

## Idle-window preparation — optional, `do-whole-phase` only (v19, recast in v20)

`do-whole-phase` used to idle for the whole executor run: plan N → dispatch N → wait
→ N returns → research + plan N+1 → gate → dispatch N+1. Research for N+1 never
depended on N *finishing*, only the final reconciliation did, so **v19** opened that
idle window for preparing the next slice. **v20 changed what kind of rule this is.**
v19 prescribed a mechanism — dispatch the bespoke read-only `slice-planner` agent
right after dispatching executor N, with five hard skip conditions. As of v20 the rule
is a **permission, not a procedure**: while executor N runs in the background the
orchestrator is idle on the main thread and **may** use that window to prepare slice
N+1 — by dispatching Claude Code's built-in read-only **`Explore`** agent, by reading
files inline itself, by thinking the slice through, or by simply waiting. Nothing is
mandatory, no mechanism is prescribed, and the call is the orchestrator's per slice.
The goal is efficient, high-quality work, not a procedure to follow.

- **The bespoke agent is retired.** `.claude/agents/slice-planner.md` is deleted, along
  with its three installer touchpoints (`build.py::FIXED_LIVE_FILES`, the explicit
  `write_text` in `main.py`, and `main.py::MANAGED_FILES`) and **plus a fourth edit that
  had to be added**: the file joins `OBSOLETE_MACHINERY`, the only channel that tells a
  v19 workspace to remove it by hand (`--update` never deletes). Deleting the agent also
  dissolves the v19 anomaly of an agent sitting outside `EXECUTOR_TIERS` — no
  `executors.toml` knob, no `sync-agents` coverage, no `validate` drift warning, and no
  in-file pinned model for `/update-workspace` to silently reset.
- **The enforcement changed, and the docs say so.** v19's read-only guarantee was
  structural — the planner's `Read, Glob, Grep` allowlist made a repo write impossible.
  With the bespoke agent gone that guarantee is weaker: `Explore` has `Bash`, and inline
  research is bounded only by the orchestrator's own discipline. **Read-only is now a
  rule to follow, not a structural property.** This is the accepted cost of not carrying
  a fourth managed agent surface.
- **Hard limits — they constrain the *how*, never the *whether*.** Whatever the
  orchestrator chooses stays strictly **read-only** (no repo writes, no `workflow.py`
  state commands, no commits, and never any part of slice N+1's actual work); dispatches
  **no second executor** (read-only research is not an executor and does not count
  against the one-at-a-time rule); **never blocks** — executor N's completion
  notification always wins, anything not ready by then is dropped, and
  `finish-slice` / `validate` / the commit are never delayed for it; is **discarded** on
  any verdict other than `done` (`escalate`, `blocked`, `needs_operator`, a failed or
  empty return — the world it assumed did not happen); and lives in the **session
  scratchpad, never in a slice folder** (a slice owns exactly two context files, and a
  stale draft must never be readable as an approved plan). Whatever is gathered is
  advisory input to the orchestrator's own plan, never an approved plan: in `gate`
  mode **the operator's approval gate does not move**.
- **Judgment, not a checklist.** v19's five skip conditions survive in full but as
  *guidance*: preparing ahead usually does not pay off when the current slice is
  `DECOMP` (the middle slices do not exist yet), when the next is `REVIEW` (never
  pre-planned) or already `ready` (`[r]` — an approved `plan.md` exists), when the phase
  or any slice is `pending` (the loop stops there anyway), or when the next slice's
  files sit inside slice N's **blast radius** (the paths N's `plan.md` says it will
  touch — anything read there may be stale by the time N returns; `phase.md` is inside
  every running slice's blast radius by construction, so it is readable-but-stale).
  It tends to pay off when N+1's subject is separate from what N is touching, when it is
  decision-dense, or when it lands in a large unfamiliar area. **Weigh these; do not tick
  them off.**
- **If you delegate, keep the ask small.** The condensed contract of the retired agent's
  prompt now lives in the skill itself: hand the subagent everything by path (slice N+1's
  id and folder, the phase folder, and the paths N is mutating as explicit exclusions),
  ask a few sharp questions rather than "research this slice", and ask for a compact
  **advisory brief** — relevant files with one line each, patterns to reuse, constraints
  and risks, open questions, and an explicit "not read / possibly stale" list. Never a
  plan, never a file dump. A shallow brief that arrives in time beats an exhaustive one
  that does not.
- **After N returns**, plan N+1 by **reconciling** whatever was gathered against what N
  actually changed (`files_changed`, `result.md`, the new `phase.md` notes) instead of
  re-reading everything; do a full research pass when nothing was prepared, what there
  was got dropped, or the state visibly drifted.
- **Scope.** `do-whole-phase` only — `do-next-slice` never prefetches (it stops after one
  slice, so a tail prefetch speculates on work the operator may never run), and
  `plan only` runs no executor, so there is no idle window to fill. It applies in the
  default (`auto`) loop — where the reconciliation feeds the inline plan — **and** in
  `gate`, where it feeds the plan-mode pass.
- **Accepted trade-offs.** Some preparation tokens are spent and thrown away, and
  anything read while an executor mutates the tree may be stale — the blast-radius
  guidance is a mitigation, not a guarantee. The default (`auto`) gets the cleanest
  benefit; in `gate` mode the saving lands on the operator's side of the gate.

## Persisting plans: inline write by default, harness copy at the gate (since v19)

The default automatic path plans inline and writes the complete plan directly to
`plan.md`. The opt-in `gate` and `plan only` paths instead copy the
operator-approved harness plan into the slice byte-exact. An existing `ready` plan is
dispatched directly unless visible drift requires re-planning.

- **The confirm-before-copy guard is load-bearing, not decorative.** The harness
  reuses **one plan file per session**, so before copying, confirm the file's opening
  lines match the plan just approved. Use the exact path the harness named for *this*
  planning session — never glob `~/.claude/plans/` and never pick by modification time.
- **Copy immediately after approval, before the next `EnterPlanMode`**, which
  overwrites the file.
- **Append after the copy, never rewrite it.** Slice-local additions — an
  `## Escalation <n>` section, for example — go *after* the copied body; the copied
  text itself is never edited.
- **`Write` is the default path:** automatic planning enters no harness plan mode,
  so no file exists to copy. This covers the default `auto` branches of both
  execution skills.
- **The copy sites are the two gated branches:** `gate` / `plan only` in
  `do-next-slice` and `do-whole-phase`, plus the corresponding contract clauses.
- **`.claude/settings.json` gains `Bash(cp:*)`** so the copy does not raise a
  permission prompt immediately after every approval gate. It is merged into an
  existing settings file on `--update` (`_merge_settings_json` unions permission
  entries), so adopting workspaces pick it up automatically.

## Building and releasing the installer

The distributable `bootstrap_agentic_workspace.sh` at repo root is **generated** —
never hand-edit it. It is assembled by `python3 installer/build.py` from the
`installer/` source tree, with the **live repo files as the source of truth** for
emitted machinery.

- **Where things live:** `installer/build.py` (deterministic assembler + `--check`),
  `installer/wrapper.sh` (the POSIX-sh wrapper), `installer/main.py` (the Python
  driver: config, write engine, the nested/at-root layout switch, retrofit/update policies, guards,
  seeding, finalizers), and `installer/payloads/` (fresh-install-only seeds with no live
  counterpart: the 11 `doc_bodies/<doc>.md` — the `p1_seed/` scaffolds were deleted in v6).
- **The edit → build → commit loop:** to change what the installer emits, edit the
  **live file** — a skill (`.claude/skills/*/SKILL.md`), an agent def
  (`.claude/agents/*.md`), `scripts/workflow.py`,
  `.claude/settings.json`, `executors.toml`, `works/templates/*`, `.github/workflows/workspace-ci.yml`,
  `.gitattributes`, or the contract (`CLAUDE.md` — since v31 the only one; `build.py` asserts its
  `# CLAUDE.md` header prefix, so changing that line means changing `CLAUDE_HDR` and `main.py`'s
  contract-write literal in the same commit) — or, for a
  fresh-only seed, edit `installer/payloads/`. Then run `python3 installer/build.py`
  and commit the rebuilt artifact **with** your edit. No more heredoc mirroring.
- **Adding a *new* `.claude/agents/*.md` takes THREE edits, not one** (learned shipping
  `slice-planner` in v19 — with only the first, the payload ships but is never written,
  and every grep of the artifact still passes): (1) `installer/build.py` →
  `FIXED_LIVE_FILES`, because `.claude/agents/` is enumerated explicitly while skills are
  globbed from disk; (2) `installer/main.py` → an explicit
  `write_text(".claude/agents/<name>.md", …)`, because the existing agent write is a loop
  over `("mid", "high")` that will never emit a third file; (3)
  `installer/main.py` → `MANAGED_FILES`, for the fresh-install conflict guard and
  managed-file bookkeeping. The `--update` path needs nothing (see the write policy
  above). **Verify with a real install probe, not a grep** — a fresh install into a
  scratch dir is the only check that catches dead payload.
- **Retiring one takes FOUR edits** (learned removing `slice-planner` in v20): the same
  three, reversed, **plus** an `OBSOLETE_MACHINERY` entry in `installer/main.py` with
  the house `# retired in vNN — <why>` comment. `--update` never deletes, and
  `flag_stale_skills()` walks only `.claude/skills/`, not
  `.claude/agents/` — so `OBSOLETE_MACHINERY` is the **only** channel that tells an
  already-installed workspace to remove the file by hand
  (`flag_obsolete_machinery()` pushes it into `UPDATE_SUMMARY["stale"]`). Without it
  every adopting workspace silently keeps a dead agent file. Consequence to expect:
  `grep -c '<retired-name>' bootstrap_agentic_workspace.sh` is **1, not 0** — the
  artifact embeds `installer/main.py`, so the retirement entry necessarily rides in it.
  The real check is that the single hit *is* that entry and that `grep -rl` over a fresh
  install probe returns nothing.
- **Retiring a whole tree takes the same shape, with one gotcha** (learned dropping Codex in v31):
  `flag_obsolete_machinery()` tests **`.exists()`**, not `is_file()`, precisely so directory entries
  like `.agents` and `.codex` fire. Reverting that one word turns every directory entry into dead
  code and empties the migration promise silently. Collapse redundant child entries into the
  directory entry (a listed `.codex/agents/*.toml` beside `.codex` double-reports), and expect the
  entries themselves to keep the retired name alive inside the artifact, since `main.py` *is* the
  artifact.
- **Drift guard:** `python3 installer/build.py --check` fails (non-zero) when the
  committed artifact no longer matches `installer/` source; `tests/retrofit_smoke.sh`
  Test 7 runs the same check, so CI/the smoke test flags a stale artifact. The build
  is deterministic — same inputs produce a byte-identical artifact. **It only `compile()`s
  the assembled body and `sh -n`s the wrapper — it never runs the artifact**, so a dangling
  `PAYLOADS[...]` read or an import-time guard mismatch passes the build, `--check`, and the
  pre-commit hook and still dies on every install. Any change to what `main.py` reads out of
  `PAYLOADS` must be verified by **executing** the built artifact into a scratch dir (deferred
  job `D3` tracks making the build gate do this itself).
- **The installer's stdin program declares utf-8 (v48, P27.F3).** The artifact's Python is fed to
  `python3` on stdin, and system Python 3.9 reads it in chunks, so a multibyte character that lands on a
  chunk boundary could be rejected. The program therefore opens with a PEP 263 utf-8 coding declaration,
  and smoke Test 7 asserts it.
- **Release rule (version + changelog):** when an edit ships a machinery change to
  targets, bump `WORKSPACE_VERSION` in `installer/main.py` **and** add the matching
  `## v<N> — <date>` entry to the root `CHANGELOG.md`, in the **same commit** as the
  rebuilt artifact. `/update-workspace` reads that changelog from the upstream clone
  to tell adopters what a sync brings, so a bump without an entry (or vice versa)
  leaves them blind. Repo-only edits that never reach a target (`installer/README.md`,
  `tests/`, `LICENSE`, this `CHANGELOG.md` itself) need no bump. `CHANGELOG.md` is
  **repo-only** — deliberately not emitted to targets.
- **v44 release:** `WORKSPACE_VERSION` 43 → 44 plus the `## v44 — 2026-09-28`
  `CHANGELOG.md` entry, shipped alongside the slimmed ~12 KB routing contract (`CLAUDE.md`,
  with `python3 scripts/workflow.py --help` as the command reference) and the docs-slice
  carve-out (see *Durable-doc consolidation — a docs phase the operator creates* above). The
  same release gives `new-slice`, `promote-deferred` and `new-phase` `--order` help — a
  fractional value (e.g. `4.5`) inserts a slice between two neighbors without renumbering —
  and `--depends-on` help, advisory only: `validate` checks that the named slice exists,
  nothing more.
- **v47 release (P26.S4):** `WORKSPACE_VERSION` 46 → 47 plus the `## v47` `CHANGELOG.md` entry, shipped
  with the file-based design loop, the `design-drafter` agent (a new managed agent file — the three edits
  above) and the contract's reworded visual-design rule. Its migration notes: in-flight Claude Design
  rounds, `_ds_manifest.json` / own-`design/` / `output/` records to schema 1, `sync-agents` after
  `--update`, and `design-register` once per repo (see *Updating an adopted workspace to upstream*).
- **v48 release (P27.S3):** `WORKSPACE_VERSION` 47 → 48 plus `## v48`, shipping the per-phase design tool,
  the `claude-design/` record, `design-migrate`, the register deck hint and the utf-8 declaration above.
  Its upgrade steps are the *Coming from a pre-v48 workspace* bullet.
- **v49 and v50 releases (P28, P29.S2):** v49 shipped the nested install as an opt-in `--nested`, and
  P28.F1 amended it in place with no version bump. `WORKSPACE_VERSION` 49 → 50 plus `## v50` made it the
  default, with migration notes for `--force-empty-ok` (needs `--at-root`, `--update` included), the bare
  install no longer yielding at-root, and parallel worktrees needing `--at-root`.
- **v51 release (P30.S2):** `WORKSPACE_VERSION` 51 in `installer/main.py` plus `## v51`, shipping the
  `/rotate-backlog` proposal, `--archive-only` and `new-phase --consolidates`. Migration: none required —
  a pre-v51 docs phase is simply not seen as covering.

## Capturing operator intent (intake)

Operator requests can carry grammar slips, awkward phrasing, or genuine
ambiguity, and a misread of intent silently propagates into decomposition and
every downstream slice. So intent is **refined, clarified, and confirmed before
any work starts**, and preserved as durable, linked truth.

- **When:** wherever operator intent first enters a unit of work — always at phase creation, and at the slice level when an operator note is ambiguous.
- **Entry point:** the `/create-phase` skill drives phase creation (explicit invocation only) — it captures intent, creates the phase(s), then **stops** before decomposition. The same skill routes work the operator wants parked for later to `defer-job` instead of creating a phase.
- **Flow:** **refine** the request into clear language → **clarify** anything ambiguous by asking the operator → **confirm** the interpretation. Only after the operator confirms does the agent run `new-phase`; it never creates the phase on an unconfirmed guess.
- **Persist (phase level):** `new-phase` scaffolds `intent.md` in the phase folder (from `works/templates/intent.md`) and links it near the top of `phase.md`; the agent then fills it with the operator's **verbatim original** request (immutable) plus the **confirmed refined intent** and any resolved clarifications. The verbatim original is never edited; only the confirmed wording is the refined version.
- **Persist (slice level):** a slice's `plan.md` is the orchestrator's free-form native plan (no template) — it incorporates any operator note passed with `do-next-slice` / `do-whole-phase`, and when that note is ambiguous the agent clarifies it with the operator and reflects the confirmed reading in the plan. The operator's **verbatim** intent is captured at the phase level in `intent.md`, not duplicated under per-slice headings.
- **Reference:** when any later agent is unsure of intent, it consults the phase's `intent.md` (linked from `phase.md`) — the confirmed source of truth for what was asked.
- **No seeded phases (since v6):** the installer seeds nothing — every phase, and therefore every `intent.md`, comes from the create-phase intake flow.
- **Always present:** because `new-phase` scaffolds `intent.md` for every phase, the file always exists for executors to read; `validate` emits a soft (non-failing) warning if an active phase is missing it.

## Local Development

- Install:
- Run:
- Test:
- Build:

## Operator Runtime

How the **operator** runs and views this product. Any slice claiming "verified in a real
browser" verifies here — this runtime, this access path, these devices — and additionally in
the production build when the two differ. **This product is a CLI with no browser surface** — the
engine and the built installer, run in a terminal on the operator's Mac — so such a claim does not
apply to this repo, and verification is live CLI runs.

- Run command(s): the engine, `python3 scripts/workflow.py <command>` (`python3 scripts/workflow.py
  --help` is the reference); and the built installer, `sh bootstrap_agentic_workspace.sh <dir>
  [--at-root|--update|--into-existing|…]`, rebuilt from `installer/` with `python3 installer/build.py`.
- Mode: there is no dev / production split. The built artifact is what ships, and
  `python3 installer/build.py --check` keeps it in sync with the `installer/` source.
- Origin / host the operator browses: none (CLI). The operator runs it in a terminal on the Mac.
- Devices / viewports / browsers: none; there is no web surface.
- Browser instrument for the agent: none. "Verified in a real browser" claims do not apply to this repo;
  verification is live CLI runs.
- Agent's Aside account id: n/a, since no instrument is named above and so there is no profile to record.
- Production build command + origin (when different): `python3 installer/build.py`; no origin, and the
  same as the run command.
- Also needed to see what the operator sees: **scratch directories.** Mutating commands
  (`rotate-backlog`, `archive-*`, `new-phase`, installs) run in `cp -R` copies of this checkout or in
  fresh `mktemp -d` installs, never against this checkout unless the operator asks.
- Smoke suite: `bash tests/retrofit_smoke.sh`, run once, alone in its own foreground Bash call — a
  chained, prefixed or backgrounded run can stall it at zero CPU.

## Environment Variables

The workspace machinery reads **no environment variables**. Executor-tier config lives in the repo-root **`executors.toml`** (the installer seeds `mode = "flex"` with commented per-tier examples; seed-once — updates never overwrite it; committable — it holds no secrets), read by `python3 scripts/workflow.py sync-agents`. All tables/keys are optional; absent fields inherit the selected preset, and an absent file resolves to the built-in `economy` preset. There are two tiers as of v23: a retired `[claude.low]` section is an error naming the retirement, not a silent no-op, and since v31 any `[codex.*]` section is an error naming the Codex removal. (Until v8 this config was a gitignored `.env`; a leftover `.env` with `SLICE_EXECUTOR_*` keys is no longer read and `sync-agents` warns about it.)

| Table | Key | Purpose | Default (`economy` preset) |
|---|---|---|---|
| _(top level)_ | `mode` | Preset the per-tier defaults come from — `economy` or `flex` | `economy` |
| `[claude.mid]` | `model` | Model for `slice-executor-mid` | `sonnet`; verbatim pass-through |
| `[claude.mid]` | `effort` | Effort for `slice-executor-mid` | `high` (`flex`: `xhigh`); empty = no effort line, for models that reject the param |
| `[claude.high]` | `model` | Model for `slice-executor-high` | `opus` (e.g. `fable`, or `claude-mythos-5` once available) |
| `[claude.high]` | `effort` | Effort for `slice-executor-high` | `high` (`flex`: `xhigh`) |

Values are double-quoted TOML strings; the parser is a strict subset — an unrecognized line, unknown section, duplicate key, or unquoted value errors with its line number. Empty `model` values are an error; `effort = ""` omits the effort line entirely.

## Deployment

- Target:
- Process:
- Rollback:

## Scheduled Jobs / Workers

- <job>: <schedule/trigger>

## Observability

- Logs:
- Metrics:
- Alerts:

## Backup / Restore

- <policy>

## Open Questions

-
