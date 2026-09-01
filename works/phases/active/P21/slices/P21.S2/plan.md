# Plan — P21.S2 (defer doc consolidation out of the review + the gate carve-out; R1+R2)

## Context

Read first, in this order: `works/phases/active/P21/phase.md` whole (the `## Decisions` from S1/DECOMP2 and the notes tagged for you are binding), `slices/P21.S1/result.md` **§11** (the remedy analysis: what a passing review still records, where `## Doc impact` notes live between phases, the five parallel-mode pieces to generalise, the file-by-file blast-radius table, the two couplings) and **§2.6/§11d** where you need the numbers. Then the current machinery you are changing: the parallel-mode pieces in `scripts/workflow.py` (`execution.consolidation`, `parallel-merge-finish`, `parallel-consolidated`, `_phase_blockers`, the stream refusal in `new_doc_version`), and the doctrine sites in `CLAUDE.md`, `.claude/agents/slice-executor-{mid,high}.md`, and `.claude/skills/{review-phase,do-next-slice,do-whole-phase,parallel-phase}/SKILL.md`.

This is the operator-confirmed remedy (see `intent.md`): retire per-review durable-doc consolidation in favour of operator-created docs phases, by **generalising the parallel-mode deferred path that has shipped since v24** — not by inventing new machinery. R2 rides inside this slice deliberately: the review keeps a **narrow named write to exactly two sections** — `## Regression Checklist` (qa doc) and `## Operator Runtime` (operations doc) — and defers everything else. Shipping R1 without R2 silently stops the smoke list being appended.

## What to change

**Machinery (`scripts/workflow.py`):**
1. Every phase, not just parallel ones, carries consolidation state: on a passing review with non-empty `## Doc impact`, the phase owes consolidation (`pending`) until the debt is paid; empty-impact phases owe nothing. Lift/generalise the `execution.consolidation` shape per §11c — keep it backward-compatible: adopter repos and this repo hold many phase.json files without the new shape, and `validate`/`rebuild`/archiving must treat them as legacy (no error, no owed debt).
2. The review path stops creating doc versions; `doc-new-version` remains the consolidation instrument, now run from a docs phase (or post-merge in parallel mode, unchanged). Relax the stream refusal in `new_doc_version` only as far as §11 says is needed.
3. Generalise the `parallel-merge-finish` debt listing so the "phases owing docs" list is producible outside parallel mode (S3 will surface it in `next`/`validate`; do not build S3's surfacing here, but leave the state queryable). Generalise `parallel-consolidated` (or add its general twin) so the operator can mark any phase's debt paid; keep the existing parallel commands working verbatim.
4. `_phase_blockers`: a phase owing consolidation is held out of archiving, exactly as parallel mode does today.

**Doctrine (`CLAUDE.md`, both agent files, the four skills):** rewrite the "durable docs are versioned once per phase, at the review slice" rule and its echoes — the review now *verifies* the `## Doc impact` list and writes only the two named gate sections; consolidation happens in operator-created docs phases via `doc-new-version`; parallel mode's deferred path becomes the universal path rather than an exception. §11's blast-radius table names the sites (4 per agent file). Keep edits surgical — this notebook's OQ2 is about contract growth, so replace sentences rather than adding paragraphs; aim for a net contract size no larger than today's.

**Self-hosting wrinkle (binding, from the DECOMP2 note):** the moment this lands, `P21.REVIEW` itself follows the new rule. State that explicitly in `phase.md` (a `## Decisions` line) and leave P21's own state consistent with the new shape.

**Workspace version:** this is a doctrine-bearing machinery change; follow the convention P20 used to ship v37 (find how v37 was recorded — likely in CLAUDE.md/templates) and bump to v38, coordinating the number as the phase notes require. If versioning turns out to live only in docs consolidated at review time, note that in `result.md` and leave it for the review-time step instead — do not invent a new versioning site.

**Installer:** after all machinery edits, run `python3 installer/build.py` and confirm `python3 installer/build.py --check` passes, leaving the rebuilt `bootstrap_agentic_workspace.sh` in the tree (the orchestrator commits everything together).

## Validation

- `python3 scripts/workflow.py validate` and `rebuild` clean on this live repo (its mixed legacy/new phase.json population is itself the backward-compat test).
- Exercise the state-mutating flows in a **scratch copy** of the repo (copy to the session scratchpad, run there): a phase with doc-impact notes passing review → owes debt → blocked from archiving → marked consolidated → archivable; a legacy phase (no new shape) archivable as before; the parallel commands unchanged.
- `python3 installer/build.py --check` passes.
- Keep any test files you add terse per the keep-tests-small rule; prefer the scratch-copy smoke flow over a suite.

## phase.md duties

Append one `## Doc impact` line per durable doc whose truth changed (workflow doc, operations/qa if touched, etc. — one short line each; the notebook rides near its ceiling). Record the self-hosting decision. Consume your notes, rewrite `## Now` for S3. Under budget, headroom for the outcome line.

## Boundaries

- No commits, no status transitions, no accept-gate, no doc-new-version runs (the new rule applies to you too — doc impact lines only).
- Do not build S3's `next`/`validate` surfacing or S4's entry point; leave clean seams for them.
- Adopter repos: untouched, unread except if you need to double-check a §11 claim.
