# Result — P17.S1

Rewrote `.claude/skills/design-cowork/SKILL.md` (334 → 480 lines) into the phase's specification:
three named styles, the runnable mockup, one operator gate per design round. One file touched, as
scoped — no contract, driver, agent, engine, installer or `docs/` change, no `WORKSPACE_VERSION`
bump, no `installer/build.py` run, no `doc-new-version`.

## What changed, section by section

| Section | Change |
| --- | --- |
| frontmatter `description` | now names the mockup the operator approves; `disable-model-invocation` still absent, deliberately |
| intro | the loop line gains "put it in front of the operator as running code"; *The line* gains the transcription-vs-invention sentence |
| `## The loop` | intent §2's diagram (two `pending` windows, the middle span dispatched); a paragraph on why PENDING #1 is not an approval; commits **two → four**, one per span, each named |
| `## Shape` → `## Shape — three styles` | `build-after` / `design-only` / `paired`, each with its slice shape and a "choose it when"; a *Choosing* block (agent suggests, operator confirms, `create-phase` by default, `DECOMP` asks late and stops `pending`, recorded under `## Design Style` in `intent.md`); a *True in every style* block carrying the surviving rules (round count at `DECOMP`, build inventory, `S<n>` numbering, read-back re-shaping, fractional orders, the fidelity-fix slice) |
| `## The handoff` | the implementation contract is now what the **mockup** is built from, as well as what the apply slices size from |
| `## The card set` | pointer retargeted to *Closing the round*, step 5 |
| `## The design record` | `build-prompt.md` completeness now covers the mockup build **and** the implement slice — both dispatched with no DesignSync |
| `## Read back, then land it` | ends at step 3 (land AS-IS) plus a **Stop there** paragraph; steps 1-2 untouched |
| **new** `## The mockup — the design in the project's own language` | the whole of intent §2's contract: throwaway namespaced route recorded in the record and `phase.md`; real stack/components/tokens under RESPECT THE DESIGN; stubbed data with the bound argued; sweep exemption; Operator Runtime verification with the `needs_operator` fallback; dispatched to `slice-executor-high` with no DesignSync; the third `needs_operator` condition; PENDING #2 and the walkthrough contents; rejection split; throwaway lifecycle and the review's orphaned-route check; `accept-gate --require` (design-only can no longer be waived); the concreteness check made mechanical |
| **new** `## Closing the round — SIGNOFF, then regroup` | steps 4 and 5 verbatim, renumbered nowhere, preconditioned on the mockup approval; the byte-identical-after-line-1 invariant and the idempotence note intact |
| `## Mechanics` | first bullet narrowed: the **DesignSync work** is never dispatched, the mockup build is the one dispatched span, the slice runs inline → dispatched → inline; write-case 2 pointer retargeted |
| `## Verifying` | the acceptance-gate sentence now covers any phase shipping a mockup; the functional sweep re-headed as an apply/fidelity duty on real wiring with the mockup explicitly exempt; the closing "signing the cards" sentence widened to cover the stubbed mockup |
| `## Never` | four bullets narrowed (see below), one added, one scope-qualified; nothing deleted |

## The `Never` block — narrowed, never deleted

1. *Author mockups … yourself* → **author a mockup before the round has come back**; palette, type
   scale, cards, "proposals", "round 1", options-to-pick-from stay banned outright, and the
   transcription-vs-inventing sentence is inside the bullet.
2. *Write implementation code in a design slice* → **product** implementation code, with the mockup
   named as the one exception on its own terms (dispatched, stubbed, throwaway, deleted later).
3. *Delegate a DesignSync call, or dispatch the design slice* → **dispatch the read-back or the
   regroup**, with a parenthetical stating the mockup build *is* dispatched. Agrees word-for-word in
   substance with the amended `## Mechanics` bullet.
4. *Pre-plan past the design gate — `DECOMP2` and everything after it* → generalized to **everything
   downstream of a round**, then instantiated per style (`DECOMP2`'s build slices / the paired apply
   slice / the apply phase), plus "cutting a bare slice folder is not planning; writing its `plan.md`
   ahead of the round it depends on is."

Added: *Treat PENDING #1 as an approval, or sign a round off on the landed record alone.*
Qualified (not weakened): *Verify only against the record…* now says the manifest runtime is
mandatory everywhere including the mockup, and the functional sweep on every slice shipping real
wiring — otherwise it would contradict the mockup's sweep exemption.

## Validation

| Command | Outcome |
| --- | --- |
| `python3 scripts/workflow.py validate` | **passed** ("Workflow validation passed.") |
| `grep -n "DECOMP2" .claude/skills/design-cowork/SKILL.md` | 7 hits, all correct under all three styles: 3 inside the `build-after` block, 1 in `paired`'s explicit "no `DECOMP2`", 2 style-qualified in *True in every style*, 1 style-qualified in `## Never` |
| `grep -in "dispatch"` + read-through | `## Mechanics` and `## Never` bullet 3 agree: DesignSync work never dispatched, mockup build is the one dispatched span |
| `grep -n "SIGNOFF"` + read-through | no site still places SIGNOFF at the read-back; `## Read back, then land it` ends at step 3 and points forward |
| `grep -in "two commit\|two passes\|two phases"` | zero hits — no superseded shape wording left |
| `awk 'length > 100'` | new lines stay inside the file's existing ~100-105 col wrap; the only outliers are pre-existing |
| full end-to-end re-read | done in five passes; the fixes it produced (paragraph re-wraps, the "signing the cards" sentence, the `Never` sweep qualifier) are in the table above |
| `git diff --stat` | `.claude/skills/design-cowork/SKILL.md` only (`works/*` deltas are the orchestrator's `start-slice`) |

No browser verification: machinery-only slice, and this repo has no `## Operator Runtime` section
because it has no product to browse (`P17.DECOMP` recorded the same).

## Deviations from `plan.md`

**One, and it is a plan-vs-intent conflict I am raising rather than designing around.** The plan says
to update "Two commits per design slice" **to three**. Intent §2's diagram has **four** `→ commit`
markers (handoff, read-back, mockup, signoff), and four is what the new loop actually forces: SIGNOFF
can no longer ride the read-back commit because the mockup build and PENDING #2 now sit between them.
Writing three would have left the file internally inconsistent with the diagram directly above it, so
I followed `intent.md` and wrote four, naming what each carries. **S2 must copy four, not three.**

Everything else follows the plan as written. Judgment calls worth knowing about are in `phase.md`
under `### From P17.S1` — section renames S2's grep sweep needs, the one added `Never` bullet, and
the one bullet I scope-qualified to keep it from contradicting the mockup's sweep exemption.
