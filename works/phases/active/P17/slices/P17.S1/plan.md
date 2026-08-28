# Plan — P17.S1

Rewrite `.claude/skills/design-cowork/SKILL.md` (334 lines) so it specifies **three named
styles**, the **runnable mockup**, and **one operator gate per design round**. This file is the
phase's specification — S2 copies its decisions into six other files, so wording precision here
is the deliverable, not prose polish.

## Read first, in this order

1. `works/phases/active/P17/intent.md` — **the specification.** §1 (three styles), §2 (the loop
   diagram and the mockup contract), the eight resolved clarifications, and the Notes, which
   carry the verbatim replacement wording for the re-cut `Never` bans.
2. `works/phases/active/P17/phase.md` — `## Findings & Notes` from `DECOMP`. It found **two
   things `intent.md` missed**; both are in scope for this slice and are called out below.
3. `.claude/skills/design-cowork/SKILL.md` — the file you are rewriting, in full.

## Scope: this one file only

Edit **only** `.claude/skills/design-cowork/SKILL.md`. Do not touch `CLAUDE.md`, the drivers,
the executor agents, `scripts/workflow.py`, the installer, or any doc under `docs/` — S2 and S3
own those, and the dependency order exists so they copy from a finished spec. Do not bump
`WORKSPACE_VERSION` and do not run `installer/build.py`.

## The edits

**`## The loop` (L16-36).** Replace the diagram with intent §2's shape — three commits and two
`pending` windows, the middle span dispatched:

```
handoff.md → push → PENDING #1 [the operator designs in Claude Design; NOT an approval]
  → read back [DesignSync, ORCHESTRATOR] → concreteness check → land the design AS-IS
  → build the mockup [DISPATCHED, slice-executor-high]
  → PENDING #2 [THE GATE: the operator opens the running mockup]
  → SIGNOFF → regroup [retire the round's address] → implement [a separate slice]
```

Update the "Two commits per design slice" sentence (L35-36) to three, naming what each carries.
Say plainly why PENDING #1 is not an approval: the operator confirms the design inside the
Claude Design session, and that session ending *is* the confirmation.

**`## Shape` (L38-74).** Replace the two-shape bullets with the three named styles —
`build-after`, `design-only`, `paired` — each with its slice shape and when to choose it. Keep
every existing rule that still holds: `--kind co-work --risk high`, never `low`; how many rounds
is decided at `DECOMP`; the build inventory; `DECOMP2` cutting backing/backend first; expect the
read-back to re-shape the phase; fractional orders; the design-fidelity fix slice.

Three things to get exactly right:
- **`design-only` must be chosen at `create-phase`** — the `DECOMP` executor cannot run
  `new-phase`. That constraint is unchanged and is why the choice has a deadline.
- **`paired` has no `DECOMP2`.** `DECOMP` cuts the design/apply pairs as **bare folders**; the
  apply-slice count equals the round count, which `DECOMP` already knows from the build
  inventory. Each apply slice's `plan.md` is written at its turn from the round that just
  landed. State explicitly that **creating a bare folder is not pre-planning**, so the
  pre-planning ban holds unchanged — an executor will otherwise read `paired` as a licence.
- **The agent suggests, the operator confirms.** Asked at `create-phase` by default; `DECOMP`
  asks it instead (stopping `pending`) when the phase was created before its visual nature was
  clear. The confirmed style lives in the phase's `intent.md` under `## Design Style`.

**New `## The mockup — the design in the project's own language`**, after `## Read back, then
land it`. Everything in intent §2's mockup contract:
- A **throwaway route** in the project's own router, namespaced and addressed by round; the exact
  path follows the project's conventions. Record the path in the round's record **and** in
  `phase.md`.
- The project's **real stack, components and tokens**, under RESPECT THE DESIGN — every designed
  element and state present.
- **Stubbed data, no backing work.** It proves **look and states, not wiring.** Non-functional
  controls are acceptable **and must be named as such in the gate walkthrough**. State the bound
  and why it exists: without it the mockup slice grows into the apply slice it precedes.
- **Exempt from the full functional sweep** — that sweep belongs to apply/fidelity slices. Say so
  here, in `## Verifying`, or both, so the two are never confused.
- Verified in the `## Operator Runtime` runtime and access path; absent or `UNFILLED` →
  `needs_operator` → `pending`.
- **Dispatched to `slice-executor-high`**, with the executor given no DesignSync — so
  `build-prompt.md` completeness is what makes it buildable, exactly as for the implement slice.
- **The third `needs_operator` condition:** if building the mockup proves the record wrong,
  internally inconsistent, or too thin to build without inventing, the executor returns
  `needs_operator` and the orchestrator raises it. Never fill the gap.
- **Throwaway lifecycle:** whichever slice later implements the surface for real deletes the
  route; under `design-only` it deliberately survives into the apply phase; the review checks no
  orphaned design routes remain.
- **The gate walkthrough** the orchestrator gives the operator: the URL, the run command, the
  viewports, what is real versus stubbed, and what is deliberately not wired.
- **Rejection splits** the way the skill already splits findings — a departure from the record is
  fixed in-slice; a design question starts a new immutable superseding round.
- **Consequence:** a phase shipping a mockup changes operator-visible surfaces, so its gate is
  `accept-gate <P> --require`. **A design-only phase can no longer be waived.**
- Worth stating: the concreteness check stops being a judgment call — the mockup either builds
  from `build-prompt.md` without inventing, or it does not.

**`## Read back, then land it` (L164-195).** The read-back now **ends at step 3, landing the
record**. SIGNOFF (step 4) and the regroup (step 5) move to **after the mockup gate** — keep both
procedures verbatim, including the regroup's byte-identical-after-line-1 invariant and its
idempotence; only their position and their "only after the operator has approved" precondition
change, the latter now pointing at the mockup approval. Steps 1 and 2 (`list_files` card check,
concreteness bar) are unchanged.

**`## Mechanics` (L199-201).** Narrow "The design slice is NOT dispatched" to: the **DesignSync
work** is never dispatched — read-back and regroup stay on the main thread because no executor
has the tool — and the **mockup build is the one dispatched span** inside the slice. The slice is
inline → dispatched → inline.

**`## Never` (L313-334) — four bullets change. Narrow each; delete none.** `DECOMP` found the
third and fourth, which `intent.md` does not name:
1. *"Author mockups, palettes, type scales, or cards **yourself**"* → the mockup ban narrows to
   authoring one **before the round has come back**. The mockup **transcribes** an approved
   design; inventing one is designing. Palettes, type scales, cards, "proposals" and
   options-to-pick-from stay banned unchanged.
2. *"Write implementation code in a design slice"* → *"write **product** implementation code"* —
   the mockup is the exception: dispatched, stubbed, throwaway.
3. *"Delegate a DesignSync call, or **dispatch the design slice**."* (L322) — this bans exactly
   what §2 now requires. Narrow it to the DesignSync work alone. It is the same amendment as
   `## Mechanics`, stated a second time; both must agree.
4. *"Pre-plan past the design gate — **`DECOMP2`** and everything after it…"* (L333-334) — names
   `DECOMP2` specifically, which reads as self-contradictory under `paired`, a style with no
   `DECOMP2`. **Generalize the wording; do not weaken the ban.**

**`## Verifying`** — qualify the functional sweep so it is unmistakably an apply/fidelity duty,
not a mockup duty. Leave the rest (two yardsticks, Operator Runtime, regression checklist,
evidence, the gap channel) intact.

## Bar

- **Narrow, never delete.** Every ban that changes gets tighter and more precise, not looser. A
  reader must still find the line the skill exists to hold: the agent does not decide what
  things look like.
- Keep the file's voice and density. It is terse, bolded, and argumentative on purpose.
- Preserve everything the change does not touch — the handoff contract, the card set and
  `@dsCard` marker, the design record tree, the two sanctioned DesignSync writes, RESPECT THE
  DESIGN, the gap channel, `## Operator Questions`.
- Update the frontmatter `description` if the three styles or the mockup make it inaccurate.
  **Do not add `disable-model-invocation`** — this skill is deliberately model-invocable.
- No line-number references to other files in the prose; they drift.

## Validation

- `python3 scripts/workflow.py validate` passes.
- Re-read the finished file end to end and confirm no section still states a superseded rule —
  in particular that `## Mechanics` and `## Never` bullet 3 agree on what is and is not
  dispatched, and that nothing still implies SIGNOFF happens at the read-back.
- `grep -n "DECOMP2" .claude/skills/design-cowork/SKILL.md` — every remaining hit must be correct
  under all three styles.

## Notes

- Append a one-line **Doc impact** note to `phase.md` — the `## Visual-design runbook` in
  `docs/current/operations.md` (L70-198) now understates the process. Do **not** run
  `doc-new-version`; the review consolidates.
- Anything you find that contradicts `intent.md`: raise it in your verdict rather than designing
  around it. `DECOMP` did exactly that and it improved the phase.
