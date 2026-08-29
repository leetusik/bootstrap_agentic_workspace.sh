# Plan — P19.DECOMP (decompose phase)

Cut this phase into slices, record the breakdown in `phase.md`, and stop. You create **bare
folders** with `new-slice` and never pre-fill another slice's `plan.md`.

## Read first

- `works/phases/active/P19/intent.md` — the confirmed intent, in full. It is unusually detailed for
  a decomposition input: read the Notes section too, it carries three constraints that bind you.
- `works/phases/active/P19/phase.md` — the notebook you will write.
- `CLAUDE.md` — the contract you are amending.

## The hard constraint: exactly two middle slices

The operator capped this phase at **4 slices total**. `P19.DECOMP` and `P19.REVIEW` exist, so you
create **exactly two**. This is not a target to approximate — it is the operator's budget. If you
believe the work genuinely cannot be done in two, do not silently create three: record the reason in
`phase.md` under `## Operator Questions` and return `needs_operator`.

A consequence worth stating: **this phase gets no `DECOMP2` of its own**, even though it is the
phase inventing the pattern. The cap forbids it.

## What is being changed

Two independent changes, shipping together as workspace **v36**.

**1. The `research` slice kind.** `SLICE_KINDS` in `scripts/workflow.py:38` is a closed set; add
`research`. The kind's semantics, all confirmed by the operator:

- findings-only — a research slice writes no product code;
- **always `slice-executor-high`**, like `decomposition` and `review`; `risk` does not route it;
- its findings land in **`phase.md`**, because the executor's context dies with the slice and the
  notebook is what the next slice reads. `result.md` keeps the log as always;
- **a `DECOMP2` slice normally follows it.** This generalizes the second decomposition pass:
  `DECOMP2` today exists only inside the `build-after` design style, and after this phase it is also
  the ordinary answer to "we had to learn something before we could cut the rest."

That last point is the one with real reach — it changes what `DECOMP2` *is* in the contract, in
`IDs and Status`, and in both executor agent files, not just what `--kind` accepts.

**2. Aside as the prescribed real-browser verification instrument.** Make **Aside** — a local-first
Chromium AI browser (https://aside.com) whose developer surface is a **CLI**, an **MCP server**, and
a Playwright-like **REPL** (`page`, tabs, locators, screenshots, downloads, JS;
https://docs.aside.com/help/developers) — the workspace's instrument for real-browser verification,
**replacing** scripted Playwright-style automation. It covers the `design-cowork` functional sweep,
fidelity slices, and the review's own product walk on a gated phase.

The existing qa doctrine (`docs/current/qa.md`, *Verification doctrine*, since v32) is the argument
for this and already implies it: it exists because thirty slices with a **scripted** fidelity slice
at the end of each passed while the product owner then found eleven user-visible failures, and its
demands — "type into it and wait", "watch a timer tick for a real interval", the browser defaults
the record never drew — are agentic browsing, not assertion scripts. You are naming the instrument
that doctrine was already asking for.

**The `## Operator Runtime` rule does not move.** Aside drives the runtime and access path recorded
in the operations doc; it never substitutes a runtime of its own, and an absent or `UNFILLED`
manifest still stops the slice `pending`.

## The open question you must resolve or route

**Aside is not installed here, and no one has established which surface an executor should reach it
by** (CLI, MCP, or REPL), whether it can run headless in an executor's environment at all, or what
an adopting workspace that does not have it should do — the fallback path matters, because a
workspace that cannot install Aside must still be able to verify.

This is exactly a `research`-slice question, and the phase can eat its own dogfood — but the
two-slice cap means a research slice spends half the budget and lands **no** implementation of
change 2. Decide deliberately and record the reasoning in `## Decisions`. Both shapes are legitimate:

- **A: split by change.** Slice 1 = the `research` kind end to end; slice 2 = the Aside change,
  doing its own investigation inline as part of its work. Fits the cap, ships both changes.
- **B: dogfood.** Slice 1 = the `research` kind; slice 2 = `--kind research` on Aside integration,
  proving the new kind — but then change 2 ships only as findings, and the operator's stated
  objective ("make Aside the prescribed instrument") does not land this phase.

**A is the shape that satisfies the objective**; B trades the objective for a demonstration. Choose,
say why, and if you pick anything that leaves part of the objective unshipped, put it on
`## Operator Questions` rather than deciding it silently.

If investigation shows Aside cannot be reached from an executor at all, that is a finding, not a
failure — the change becomes "prescribe Aside, document the surface, state the fallback", and the
slice that carries it should be scoped that way.

## Blast radius, so you can scope the slices honestly

The kind list and the verification prose are duplicated across the machinery. `grep` before you
scope; at minimum these carry one or both changes:

`scripts/workflow.py` (`SLICE_KINDS`, and the two `--kind` help strings at ~2154 and ~2236) ·
`CLAUDE.md` (the `--kind` closed set under *Workflow Commands*, the `DECOMP2` sentences under
*Hard Rules* and *IDs and Status*, the runtime-manifest rule) · `.claude/agents/slice-executor-high.md`
and `slice-executor-mid.md` · `.claude/skills/do-whole-phase/SKILL.md` · `.claude/skills/do-next-slice/SKILL.md` ·
`.claude/skills/design-cowork/SKILL.md` (*Verifying*) · `.claude/skills/review-phase/SKILL.md` ·
`.claude/skills/create-phase/SKILL.md` · `tests/retrofit_smoke.sh` · `CHANGELOG.md` (a `## v36`
section) · `installer/payloads/doc_bodies/qa.md` and `operations.md` (the **seed** bodies a fresh
workspace gets — distinct from this repo's own `docs/`, and not generated).

**Durable docs**: `docs/current/*.md` are generated snapshots — no slice may hand-edit them, and no
slice runs `doc-new-version`. Changes to durable truth become one-line `## Doc impact` notes in
`phase.md`; `P19.REVIEW` consolidates them. The seed bodies under `installer/payloads/` are ordinary
source files and *are* edited directly.

**Upstream bootstrap repo**: every slice that edits embedded machinery (`scripts/workflow.py`,
`.claude/*`, `works/templates/*`, `CLAUDE.md`) must run `python3 installer/build.py` and leave the
rebuilt `bootstrap_agentic_workspace.sh` in the tree; `--check` is enforced by the pre-commit hook,
and I commit it with the slice.

## Risk ratings

`--risk` picks the executor tier and is the phase's cost lever. Both middle slices here edit multiple
files and write real logic and contract prose: rate them **`high`**. `low` is for a one-line edit or
docs only, and neither slice is that.

## Do

1. Read `intent.md` and `phase.md` in full.
2. Investigate enough to scope honestly — the greps above, and whatever you need to judge the Aside
   question. You may use `WebSearch`/`WebFetch` for Aside's developer surface.
3. Create **exactly two** middle slices with
   `python3 scripts/workflow.py new-slice --phase P19 --slice P19.S<n> --name "..." --kind <kind> --risk high`,
   as bare folders. Order them so the `research`-kind change lands before anything that depends on
   the kind existing.
4. Write `phase.md`: the breakdown and why you cut it that way under `## Decisions`; the Aside-surface
   findings and the blast-radius facts the next slices need under `## Notes for later slices`, tagged
   `**(from P19.DECOMP, for P19.S<n>)**`; anything only the operator can settle under
   `## Operator Questions`; a `## Now` of ≤ 15 lines last. Do not touch the generated `## Slices`
   block. Keep the whole file under the 200-line / 16 KB budget.
5. Write `result.md`, verdict block first.
6. Do **not** create `P19.DECOMP2`, do not pre-fill any slice's `plan.md`, do not implement anything,
   do not run `accept-gate` (that is mine, at this boundary), do not commit.

## Return

A structured verdict. `needs_operator` if the two-slice cap cannot hold or the Aside question needs
an operator decision before the phase can be scoped.
