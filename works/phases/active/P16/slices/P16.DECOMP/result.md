# Result — P16.DECOMP (decompose phase)

## What I did

Cut `P16` into **six middle slices**, created as bare folders (`slice.json` only — no `plan.md`
pre-filled anywhere), and seeded `phase.md` with the breakdown, the binding cross-slice design
decisions, the tree findings, and the deferred-job calls.

Single decomposition pass, as `plan.md` specified: this phase edits the *text* of `design-cowork`
and the machinery around it and designs no product's look, so there is **no `co-work` slice and no
`P16.DECOMP2`**.

## Slices created

| Slice | Kind | Risk | Order | Depends on |
|---|---|---|---|---|
| `P16.S1` — Acceptance-gate engine: phase.json block + accept-gate commands | implementation | high | 10 | — |
| `P16.S2` — Seed the operator runtime manifest and the cumulative product smoke list | implementation | high | 20 | — |
| `P16.S3` — Contract + review/loop skills: gate, manifest, catalogue routing, review independence | implementation | high | 30 | S1, S2 |
| `P16.S4` — Executor prompts: manifest runtime, review independence, catalogue routing, co-work refusal (D2) | implementation | high | 40 | S3 |
| `P16.S5` — design-cowork: works-as-a-product verification and the gap channel | implementation | high | 50 | S2, S3 |
| `P16.S6` — Ship workspace v32: version, CHANGELOG, adopter prose, Test 0 invariants | implementation | high | 60 | S1–S5 |

Ordering rationale: the engine lands first so the prose slices can name real commands; the seeded
doc bodies land next so the prose can cite a real heading; the three prose surfaces follow; the
release closes. Scope-per-slice is in `phase.md` § *Decomposition*.

**All six are `high`.** Each touches more than one file and each must rebuild the distributable, so
none meets the `mid` bar ("a one-line/few-line code edit, or docs"). `S2` was the closest call and
is argued in `phase.md`; `S3` is deliberately kept whole so the contract and the review procedure
cannot disagree.

## Decisions settled here (recorded in `phase.md`, binding on S1–S6)

The plan asked for the shared vocabulary to be fixed at decomposition so the slices cannot diverge.
Settled: the `acceptance` block name and its five fields on `phase.json`; the single orchestrator-only
`accept-gate` command with `--require` / `--waive` / `--open --walkthrough` / `--clear` / bare-show;
what `review-phase --verdict pass` refuses (undeclared, or required-but-uncleared) and what it never
refuses (`changes_requested`, `blocked`); the `changes_requested` gate reset; the legacy default
(absence of the block = legacy = pass allowed, no `validate` warning); the manifest heading
`## Operator Runtime` in the `operations` doc body with an explicit unfilled marker; reuse of the
existing `## Regression Checklist` in `qa` as the cumulative smoke list (no new file, no new
template); catalogue routing as procedure plus a `## Operator Questions` running list in `phase.md`;
the review's new stages and the one new return field `walkthrough`; and the conditioning switch that
makes every F1/F3/F6 duty depend on the phase's declaration.

## Deferred jobs

- **D2** — folded into `P16.S4` (its trigger is exactly that slice's file set). Recommended closing
  move for the orchestrator, after S4 lands:
  `python3 scripts/workflow.py drop-deferred D2 --reason "fixed in P16.S4 — slice-executor-mid now carries the co-work refusal clause"`.
  Not run here: decomposition may run no state-transition command other than `new-slice`.
- **D4** — its trigger fires in `S6` (which edits `docs/retrofit-guide.md`); folding it in is the
  orchestrator's call, and it is unrelated to P16's objective.
- **D3** — does not fire: `installer/build.py` needs no edit (skills and doc bodies are discovered
  by glob).

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | **passed** — "Workflow validation passed." (exit 0, no warnings) |
| `python3 installer/build.py --check` | **passed** — "OK: bootstrap_agentic_workspace.sh is in sync with installer/ source" (exit 0) |

No embedded machinery file was changed by this slice, so the artifact is untouched and stays in
sync.

## Deviations from `plan.md`

None to the instructions. Relative to the plan's *suggested shape*, the six slices are kept as
suggested in count and subject; the refinements are all recorded in `phase.md`:

- `S2` reuses `qa.md`'s existing `## Regression Checklist` rather than adding a template or a new
  file (the plan invited this comparison and it is the leaner answer).
- `S6`, not each prose slice, owns all `tests/retrofit_smoke.sh` Test 0 additions, so the assertions
  are authored once against the final wording.
- `S4`'s scope is widened beyond D2: `slice-executor-mid.md` lags `-high.md` in several other
  respects found while reading (the `DECOMP2` language, the review's complete-validation rule, the
  pass-only stop, the `explain:` pointer, the broader no-commit wording).
- `S3` picks up one sentence in `.claude/skills/parallel-phase/SKILL.md` (covered by the plan's "any
  other skill that names the review or `pending`").

## Doc impact

None — this slice created slice folders and wrote the phase notebook. The *Doc impact* and
*Operator questions* running lists are seeded empty in `phase.md` for the later slices.
