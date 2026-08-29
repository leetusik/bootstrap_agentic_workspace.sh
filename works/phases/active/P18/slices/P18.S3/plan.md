# Plan — P18.S3: executor agents + orchestrator skills — just-in-time reads and the notebook edit protocol

## Goal

Make the agents and skills *state* the protocol S1/S2 shipped: what each role reads (just-in-time), how `result.md` is shaped (verdict block first), how `phase.md` is edited (bounded state, rewritten under budget, around the generated block), and how the review cross-checks the two. Prose only — no engine changes. Read `phase.md` first: its `## Decisions` and the `## Notes for later slices` tagged **for S3** are the shipped facts you describe; `intent.md` parts 2 and 4 are the confirmed spec.

**The one hard invariant:** `.claude/agents/slice-executor-mid.md` and `slice-executor-high.md` stay byte-identical below their frontmatter (`diff <(tail -n +9 mid) <(tail -n +9 high)` empty), and `python3 scripts/workflow.py sync-agents --check` reports no drift afterwards. Edit one, copy the body to the other.

## The protocol to write (same words everywhere it is restated)

- **Executor reads, in order:** `plan.md` (the spec) → `phase.md` (the bounded notebook: `## Slices` table, Decisions, Doc impact, Operator Questions, Notes for later slices, Now) → `intent.md` **only when unsure what was asked** → `phase.json` (gate block, as today) → the `docs/current/` **sections** the plan names — never the whole doc set, never `docs/index.json` → `CLAUDE.md` (as today). Review slice adds: every completed slice's `slice.json` + `result.md`, `## Regression Checklist` / `## Operator Runtime` on a gated phase (as today).
- **`result.md`:** free-form, from scratch, **verdict block first** (the same block the executor returns — it is the durable form of the ephemeral verdict), then validation commands and outcomes, deviations, and the detail: findings prose, dead ends, command output. It is the per-slice **log**; the phase notebook is never a second copy of it.
- **`phase.md` edit (step 4):** *edit*, under `PHASE_MD_BUDGET` (200 lines / 16 KB — `finish-slice` prints the size, `validate` warns): update `## Decisions` (replace a superseded line, never stack versions); append to `## Doc impact` and `## Operator Questions` (never delete there); remove the `## Notes for later slices` entries your slice consumed and add yours, tagged `(from <slice>)`; rewrite `## Now` (≤ 15 lines: done / next / open). **Never edit inside the `<!-- slices:begin -->` … `<!-- slices:end -->` block** — `rebuild` regenerates it (so `next`, `new-slice`, `finish-slice` all refresh it); the Outcome cell comes from `finish-slice --outcome`, the Result cell links `result.md` when it exists. Compression is restorable: the pre-edit notebook is in git and the detail is in `result.md`.
- **Review cross-check:** because the notebook is rewritten, the review reads `phase.md` **and** every `result.md`, and checks that no decision recorded in a `result.md` was dropped from `## Decisions` and no operator question was left unrouted; a dropped decision is a finding. The review reads `result.md` files **head-first** (verdict block) for validation commands, whole where needed.
- **Orchestrator (drivers):** after each slice re-read `phase.md` and the returned verdict; read `result.md` head-first, whole only on a non-`done` verdict; **drop the per-slice re-read of `works/backlog.md`** (`next` prints the pointer). At session start read `CLAUDE.md`, `next`, the phase's `phase.md` (+ `intent.md` when present) and the selected slice folder; `docs/current/` sections only as the work needs them.
- **`finish-slice` in the drivers:** `finish-slice <id> --outcome "one line"` — the orchestrator supplies the outcome from the verdict's `summary`.

## Files

1. `.claude/agents/slice-executor-high.md` then `-mid.md` (body copy): `## Inputs` list (lines ~19-26) → the read order above; *Do* step 3 (`result.md`, verdict first, log not notebook); step 4 (the edit protocol, the generated block, the budget); the review bullet in step 1 gains the cross-check; `## Never` gains "edit inside the generated `## Slices` block". Keep every existing gate/mockup/parallel sentence intact — this slice narrows nothing there.
2. `.claude/skills/do-next-slice/SKILL.md`: line ~10 (read list), ~22-23 (`phase.md` as planning context — fine, keep), ~27 (verdict + `result.md` head-first), the `finish-slice` mention → `--outcome`.
3. `.claude/skills/do-whole-phase/SKILL.md`: line ~10 (read list), **~17** (drop `works/backlog.md`; re-read `phase.md` + verdict), ~33 (reconcile against `result.md` head + new notebook), ~36 (`finish-slice --outcome`).
4. `.claude/skills/review-phase/SKILL.md`: inputs ~19-21 (docs sections not `docs/current/*.md` + `docs/index.json`; drop `works/backlog.md`), the questions list ~28-32 gains the cross-check bullet, ~29 "from its `plan.md` / `result.md`" → "from the verdict block at the head of its `result.md`".
5. `.claude/skills/create-phase/SKILL.md` ~15: "Read `docs/current/*.md` and `works/backlog.md` for context if useful" → the `docs/current/` sections relevant to the request, and `python3 scripts/workflow.py next` for the pointer.
6. `.claude/skills/design-cowork/SKILL.md`: one added sentence near line ~119 (build inventory) / ~235 (landed spec): these live in `phase.md` and **count against the notebook budget** — keep them to the inventory and the spec pointers, detail in the round's record.
7. `.claude/skills/parallel-phase/SKILL.md`: line ~150 `## Doc Impact` → `## Doc impact`; near ~146-148 / ~175 add one line: `phase.md` is **not** a generated file — a merge conflict *inside* its `## Slices` marker block is resolved by re-running `rebuild`, the rest of the notebook is merged by hand like any prose.
8. Consistency sweep before returning: `grep -rn "Findings & Notes\|Open Questions\|works/backlog.md\|docs/current/\*.md\|Doc Impact" .claude/` — every remaining hit must be intentional (historical wording in `explain`/`retrofit` skills that describes old workspaces may stay; say so in `result.md`).
9. `python3 installer/build.py` (agents and skills are embedded) → `--check` green.

## Validate

- `diff <(tail -n +9 .claude/agents/slice-executor-mid.md) <(tail -n +9 .claude/agents/slice-executor-high.md)` — empty
- `python3 scripts/workflow.py sync-agents --check` — no drift
- `python3 scripts/workflow.py validate` — clean
- `python3 installer/build.py --check` — pass
- `bash tests/retrofit_smoke.sh` — all PASS (137 baseline; some asserts pin skill wording — if one pins wording this slice deliberately supersedes, replace it with an assert on the new invariant, never delete it)
- the grep sweep in step 8, with its residue explained

## result.md and phase.md

Verdict block first. In `phase.md`: consume the S3 notes, append the `## Doc impact` line (`operations.md`: the read order + notebook edit protocol as the runbook now states it), rewrite `## Now` for S4 — and since the notebook is at ~13 KB of 16, **prune anything S4 no longer needs** (the DECOMP-era rationale that has since become a Decision, for instance) as the first live use of the rule you are writing.
