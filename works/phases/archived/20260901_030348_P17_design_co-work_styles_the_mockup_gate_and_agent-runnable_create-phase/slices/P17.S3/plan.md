# Plan — P17.S3

Release the phase's work as **workspace v34**: bump the version, write the CHANGELOG entry,
rebuild the artifact. This is the last slice before the review, and its deliverable is what
adopting repos actually read to understand what a sync brings.

## Read first

- `works/phases/active/P17/phase.md` — the whole notebook, especially `### From P17.S1` and the
  S2 notes. The changelog entry is written **from what actually landed**, not from `intent.md`.
- `works/phases/active/P17/slices/P17.S1/result.md` and `.../P17.S2/result.md` — the deviations
  sections in particular; two of them are things adopters need to know about.
- `installer/README.md` L18-30 — the release rule.
- `CHANGELOG.md` — read the **v33 and v32 entries in full** before writing. They set the voice:
  lead with *why this release exists*, state the mechanism, then a **Migration notes** line.
  Entries are dense, argumentative, and written for someone deciding whether to sync.

## The three edits

1. **`installer/main.py:38`** — `WORKSPACE_VERSION = 33` → `34`. That line only.
2. **`CHANGELOG.md`** — a new `## v34 — 2026-08-29` section directly above `## v33`.
3. **`python3 installer/build.py`**, then `--check`, and stage the rebuilt
   `bootstrap_agentic_workspace.sh`. It will pick up the bumped version.

## What the changelog entry must carry

Written for an adopter deciding whether to sync — what changed, why, and what they must do.

**Why this release exists.** A design round ended at the **cards**: the operator approved a
static review surface in the Claude Design pane, and `build-prompt.md`'s completeness was a human
judgment call that nothing tested. The skill's own closing line admitted the gap — *signing the
cards is not accepting the product*. And the phase shape was an implicit binary chosen by an agent
reading a soft "big design → two phases" hint.

**What changed, in four parts:**

- **Three named styles**, chosen by the operator with the agent suggesting: `build-after` (the
  existing `DECOMP` → design → `DECOMP2` two-pass), `design-only` (a design phase, then a separate
  apply phase), and **`paired`** (new — design 1 → apply 1 → design 2 → apply 2 inside one phase,
  with **no `DECOMP2`**; its apply slices are cut as bare folders, and cutting a bare folder is not
  pre-planning). `design-only` must still be chosen at `create-phase`, because the `DECOMP`
  executor cannot run `new-phase`.
- **A runnable mockup, and one gate per round.** After the read-back, a **dispatched** span builds
  the design as a throwaway route in the project's own frontend stack, and the operator opens and
  clicks it. **Only the second `pending` window is an approval** — the Claude Design session ending
  is itself the design confirmation — so **SIGNOFF moves to the mockup gate**. The mockup is
  stubbed and does no backing work: it proves look and states, not wiring, and is therefore
  **exempt from the full functional sweep**. Four commits per design slice, not two. A phase
  shipping a mockup takes `accept-gate --require`, so **a design-only phase can no longer be
  waived**. The concreteness check stops being a judgment call — the mockup either builds from
  `build-prompt.md` without inventing, or it does not.
- **`--kind` is a closed set.** It was free-form since the beginning, so `--kind cowork` silently
  created a slice that read as ordinary implementation and got dispatched to an executor with no
  DesignSync. Hard error at `new-slice` and `promote-deferred`; **warning only in `validate()`**,
  so a repo carrying an invented kind survives the update. Note the deliberate asymmetry with
  `--risk`, which stays unvalidated and routes unrecognized values to `high` — so nobody "fixes" it
  later for symmetry.
- **`create-phase` is agent-runnable on instruction.** It loses
  `disable-model-invocation: true` and becomes a second, **narrower** exception than
  `design-cowork`: callable when an approved plan or a direct instruction calls for a phase, never
  fired on its own initiative. **Its step-3 operator-confirmation gate does not move** — invocation
  is not the gate, confirmation is.

**Migration notes.** Work out the real answer rather than copying v33's; check each claim:
- Fresh installs and installer-owned `CLAUDE.md`: nothing to do.
- A **retrofitted** repo keeps its own `CLAUDE.md` and gets the new contract text in the
  `CLAUDE.workspace.md` sidecar to fold in by hand.
- **Existing slices with a kind outside the set** (`docs`, `qa` are in it; anything invented is
  not) now produce a `validate` **warning**, not an error, and the exit code is unchanged.
- **An in-flight design phase** started under the old shape: state plainly what happens — its
  design slice ended at the cards with SIGNOFF at the read-back, and there is no mockup. Say
  whether it needs anything (it does not; the new shape applies to rounds started from here on,
  the same way v33 scoped itself).
- `--update` does not touch `docs/`, so the `## Visual-design runbook` in an adopter's
  `operations.md` keeps the old two-shape text until they re-version it themselves.

## Scope

- **Only** `installer/main.py` (the version line), `CHANGELOG.md`, and the rebuilt
  `bootstrap_agentic_workspace.sh`. Do not edit the skills, the contract, the engine, the agents,
  or the tests — S1 and S2 own those and their work is committed.
- If you find something wrong in their work, **raise it in your verdict**; do not fix it here. A
  `fix` slice is the phase's mechanism for that, and the review will catch it too.
- Do not run `doc-new-version` — the review consolidates. The `## Visual-design runbook` in
  `docs/current/operations.md` is already on the phase's Doc impact list.

## Validation

- `python3 installer/build.py --check` passes.
- `python3 scripts/workflow.py validate` passes.
- `bash tests/retrofit_smoke.sh` passes — it asserts installer behaviour and will exercise the
  bumped version.
- `grep -n "WORKSPACE_VERSION = 34" installer/main.py bootstrap_agentic_workspace.sh` — the bump
  reached the artifact, confirming the rebuild ran after the edit and not before.
- Re-read the finished changelog entry as an adopter who has never seen this phase: does it say
  what changed, why it changed, and what they must do?
