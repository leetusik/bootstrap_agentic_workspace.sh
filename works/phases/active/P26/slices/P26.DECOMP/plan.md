# Plan — P26.DECOMP (decomposition)

## Context

P26 replaces the Claude Design loop in `design-cowork` with **design files kept in each product repo**, which a separately built web dashboard will read. A **dedicated design subagent** does the drafting. Read `works/phases/active/P26/intent.md` in full. It holds:
- the operator's verbatim request;
- the five deliverables: the on-disk contract, the design subagent, the `design-cowork` rewrite with Claude Design kept only as an optional bundle import, the hard-rule reword, and the register hook;
- the fixed governance;
- no interim viewer;
- the dashboard facts the contract must fit: served from the Mac over Tailscale, reads the registered repos from disk, desktop only.

Inputs the executor should use (by path, not re-derived):
- `works/phases/active/P25/slices/P25.S2/result.md`: §3.1 is the frames-board prototype (`@dsCard` line-1 marker carrying the round address and viewport, `NN-slug.html` cards, `check` / `regroup` semantics, per-card notes), §4.1 is the loop mapping, §5 is where `frontend-design` fits, §7 is the adoption change list.
- `works/phases/active/P25/slices/P25.S1/result.md` §1: requirements R1–R12 (R1–R8 must).
- The prototype script `board.py` in the P25 scratch dir `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/1aa717b3-0250-45dc-9d55-868a00349f51/scratchpad/board/` (reference only; it may vanish).

## Machinery footprint (from read-only exploration)

- **Engine** (`scripts/workflow.py`): no design-specific logic. `co-work` is only a member of `SLICE_KINDS` (L38–54). `executor_agent_files()` is hard-coded to the two slice-executor files (L244–283).
- **Doctrine**:
  - `CLAUDE.md` L13, 15, 49, 52, 60;
  - `design-cowork/SKILL.md` (48 KB). About 18 KB is loop mechanics: §The loop, §The handoff, §The card set, §The design record, §Read back, §Closing the round, §Mechanics, and part of §Never. About 29 KB is governance: styles, the mockup gate, RESPECT THE DESIGN, Verifying;
  - `do-whole-phase` L21–28 and `do-next-slice` (the co-work steps);
  - `create-phase` L19–57;
  - `review-phase` L41–50;
  - both executor bodies L15, 33, 60 ("no `DesignSync`").
- **Shipping** a new agent file touches five places: `installer/build.py` `FIXED_LIVE_FILES`; `installer/main.py` `MANAGED_FILES` and the emit loop (L540–543) and the banner (L688–689); and the smoke `DUAL_FIXED` list (L940). Skills ship as `*/SKILL.md` only, so any contract text must live inside a `SKILL.md` or the engine's own help.
- **Smoke** (`tests/retrofit_smoke.sh`): about 70 design pins, many tied to mechanics phrases (`@dsCard`, "DesignSync is main-thread only", "Connect GitHub").
- **Release**: currently v46. A version bump plus a CHANGELOG entry with `Migration notes`, then `installer/build.py`, all in one commit.

## The cut: four middle slices, then REVIEW

| Slice | Kind / risk | Why this rating |
|---|---|---|
| `P26.S1` define the on-disk design contract and its engine commands | implementation / **high** | **open design + wide blast radius**: the contract is the interface between two repos, and the layout, round history and registry format are all undecided |
| `P26.S2` add the design subagent and ship it | implementation / low | the approach is pinned by S1 and P25 §7; it is five known shipping edits plus an agent body |
| `P26.S3` rewrite `design-cowork` around the files | implementation / **high** | **core invariant**: a 48 KB doctrine rewrite that must drop no governance line, and the retired mechanics are pinned across the smoke suite |
| `P26.S4` sweep the contract and orchestrator skills, ship v47 | implementation / low | a pinned text sweep plus the release steps |

**S1 — contract + engine.**
- **The contract is written into `design-cowork/SKILL.md` as one new section** (it replaces §The design record). It covers:
  - the design root in a product repo (`docs/reference/design/`, today's record home);
  - projects ("divided by project": the dashboard lists projects across registered repos; S1 decides whether a repo may hold more than one);
  - the cumulative card library, with numbered stable paths and the line-1 `@dsCard` marker carrying group, round address and viewport, so today's card contract carries over;
  - tokens / the system;
  - rounds, each holding `handoff.md`, `feedback.md`, `SIGNOFF.md` and `build-prompt.md`, with signed and superseded rounds kept and addressable, so the operator can **walk past designs later**. S1 decides snapshot vs git-ref;
  - the registry format.
- **Engine commands in `workflow.py`** (names are S1's call; prototype semantics from P25 §3.1):
  - `check`: numbered and contiguous, no monolith, markers valid;
  - `regroup`: line 1 only, byte-identical below, idempotent;
  - `register`: writes this repo into a registry **outside** the repo on the Mac, at an env-overridable path. The dashboard reads it later. `register` is the "register this repo" hook.
- **Tests:** smoke probes only for the core invariants (regroup byte-identical and idempotent, `check` catching a gap), kept small.
- **Scope limits:** no viewer, and no `board.html`.

**S2 — design subagent.**
- **Agent file:** `.claude/agents/design-drafter.md` (name final at S2). It drafts a round's cards into the S1 contract from `handoff.md`, grounded in the existing tokens and library. It is background-dispatchable. Its `tools:` include `Skill`, so it can load `frontend-design` only on rounds that set a new visual direction (P25 §5). It never signs and never decides.
- **Model:** say how it gets its model — tracking the high tier through `sync-agents`, or a fixed alias — and record why.
- **Shipping:** wire the five shipping places.

**S3 — `design-cowork` rewrite.**
- **Replace the loop mechanics:**
  - handoff → dispatched drafter → **PENDING** (the operator opens the card files directly) → the operator's literal signoff → `regroup`;
  - read-back becomes `check`, file reads, and optional screenshots;
  - drop `DesignSync` from `allowed-tools` and from §Mechanics / §Never;
  - add a short **"import a Claude Design bundle"** subsection (optional path, main-thread, the operator exports).
- **Keep every governance section's meaning unchanged:**
  - the styles;
  - rounds and superseding;
  - literal signoff;
  - the mockup gate (a mockup still means a dispatched build and a second PENDING);
  - RESPECT THE DESIGN;
  - Verifying.
- **Leave out of scope:** D7 and D13 stay deferred. Do not rewrite the Aside fallback paragraph.
- **Smoke:** update the design pins to match, retiring the dead phrases as `gone` pins.

**S4 — contract/orchestrator sweep + v47.**
- **`CLAUDE.md`:**
  - the co-work exception becomes "the drafting span is dispatched to the design subagent; signoff stays on the main thread";
  - the hard rule becomes **"the design subagent drafts, the operator decides"** (literal signoff);
  - drop "Claude Design" as the sole design partner.
- **Skills and executors:**
  - `do-whole-phase` / `do-next-slice`: the co-work steps;
  - `create-phase`: the mockup question's "return from Claude Design" wording;
  - `review-phase`: the mockup lines as needed;
  - both executor bodies: L15/33/60;
  - the installer banner.
- **Release:** smoke pins; `WORKSPACE_VERSION` 47 plus a `## v47` CHANGELOG entry whose **migration notes** cover adopters with in-flight Claude Design rounds and existing `_ds_manifest` records; then `python3 installer/build.py` (`--check` must pass).
- **Doc impact:** a `## Doc impact` note for operations (the Visual-design runbook), decisions, qa and architecture. **No `doc-new-version`.**

Why S3 and S4 are separate: S3 is one large file where losing governance is the risk. S4 is a wide but shallow sweep that must match S3's final wording, so it runs after.

## What the DECOMP executor does

1. Read `intent.md`, `phase.md`, and `CLAUDE.md`'s DECOMP/risk rules.
2. Create the four bare slices with `new-slice`, `--kind implementation`, and risks as in the table:
   - `--order 1`–`4`;
   - `--depends-on` chaining S1 → S2 → S3 → S4;
   - no `plan.md`.
3. Edit `phase.md`:
   - **`## Decisions`:** the cut and the rating triggers; the machinery footprint above (compact, with line refs); the governance-vs-mechanics split of `design-cowork`; "no interim viewer"; D7/D13 out of scope.
   - **`## Notes for later slices`** (tagged): for S1, the open contract questions listed above plus the P25 inputs; for S2, the five shipping places and the `sync-agents` hard-coding; for S3, the section map and "keep governance meaning"; for S4, the CLAUDE.md lines, the release rule and the migration-notes duty; for every slice, the upstream rule (`installer/build.py` rebuilt in the same commit whenever an embedded file changes, `--check` passing).
   - **`## Now`:** the handoff to S1.
4. `rebuild`, then `validate`.
5. Write `result.md` with the verdict block first, including your read on the gate.

**Boundaries:** bare folders only; no `accept-gate`, no commits, no machinery edits in this slice.

## Acceptance gate (orchestrator, after `finish-slice`)

**`--waive`**, with the note: "workspace machinery only: no running product surface; the design contract is reported to the operator at the end of the phase for their dashboard build". This repo has no `## Operator Runtime` section, and nothing here is browser-verifiable; earlier machinery phases (P21–P24) waived for the same reason. At phase end I report the S1 contract summary to you, because the dashboard repo builds against it.

## Verification

- `validate` exits 0.
- `next` points at `P26.S1`.
- The four new folders hold only `slice.json`.
- The `## Slices` table lists DECOMP, S1–S4 and REVIEW with the ratings above.
