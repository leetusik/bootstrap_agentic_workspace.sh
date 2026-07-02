# Plan — P4.REVIEW (phase review)

Orchestrator's native plan. Slice kind: `review`. Executor: `slice-executor` (xhigh). Never edit source code on this slice; docs + `result.md` + `phase.md` only.

## Goal

Review phase P4 as a whole against its objective, `intent.md`, and the docs; validate all completed slices together; on a `pass`, consolidate the phase's "Doc impact" notes (see `phase.md`) into new durable-doc versions. Return a `review_verdict`.

## Inputs

Every completed slice's `plan.md` + `result.md` (`P4.DECOMP`, `P4.S1`, `P4.S2`, `P4.S3`), `phase.md` (decomposition, cross-slice notes, Doc impact list), `intent.md` (three jobs + hard constraints + resolved clarifications), `docs/current/*.md`, `docs/index.json`.

## Validate all slices together (re-runnable checks; the one-time old-vs-new equivalence proofs in S1's result stand as recorded evidence — do not re-derive them against the now-changed HEAD)

1. `python3 installer/build.py` twice → byte-identical outputs; `python3 installer/build.py --check` green (committed artifact in sync).
2. `bash tests/retrofit_smoke.sh` → all blocks green (covers retrofit ×4, fresh regression incl. `workspace_version` marker assert, live-vs-fresh drift, build drift).
3. Grep sweep over live machinery (`.claude/`, `.agents/`, `.codex/`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `scripts/`, `installer/`, `tests/`): no `model: opus`; no "on `opus`" / "on `gpt-5.5`" prose; `GPT-5.5` appears only as example-in-rule text or the scoped-out Codex toml pin (+ its config comment).
4. End-to-end current-artifact check: fresh-install the committed artifact into a temp git repo → marker carries `"workspace_version": 1`; `--update --dry-run` from that same artifact over it → 0 machinery changes; target `python3 scripts/workflow.py validate` passes.
5. `CHANGELOG.md` exists at root with a `## v1` entry and is absent from the built artifact (repo-only); both `/update-workspace` mirrors' bodies byte-identical.
6. `python3 scripts/workflow.py validate` in this repo.

## Judge

- Intent Job 1: executor defs `model: inherit`; attribution rule-first with models as examples; prose model-neutral; Codex toml pin intentionally kept.
- Intent Job 2: single committed distributable at root, `curl … | sh` contract intact, all three modes functionally unchanged, live-files source of truth, drift check wired into tests.
- Intent Job 3: integer versioning stamped into the marker, seeded CHANGELOG, version-aware `/update-workspace` preview, release rule documented.
- Each slice's `result.md` consistent with its `plan.md`; deviations reasoned; workflow hard rules honored (no per-slice doc versions, tests kept small).

## On `pass` only — consolidate docs (one new version per affected doc, `--source P4.REVIEW`)

Per the Doc impact list in `phase.md` — expected three:
- `decisions`: installer split to `installer/` source tree + committed build product with drift guard (source of truth = live repo files); executor `model: inherit` + rule-based commit attribution, **superseding v0013's "`opus` alias auto-tracks the top model" rationale** (Fable/Mythos tier now sits above Opus); integer workspace versioning + root CHANGELOG policy (bump + entry in the same commit as a machinery release).
- `operations`: the installer is a build product — edit live files / `installer/payloads/`, `python3 installer/build.py`, commit the rebuilt artifact; drift guards (`build.py --check`, smoke Test 7); release rule; version-aware update flow (vN → vM preview reading upstream's CHANGELOG from the clone; pre-versioning fallback).
- `architecture`: repo shape — `installer/` source tree (`build.py`, `wrapper.sh`, `main.py`, `payloads/`) assembling the single committed distributable; payload manifest derived from live files; CHANGELOG repo-only.

Procedure per doc: `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source P4.REVIEW`, edit only the returned `edit_path` (follow the doc's existing structure; for `decisions` add new entries and mark the superseded v0013 rationale as superseded — never rewrite history), then `python3 scripts/workflow.py rebuild-docs` once at the end. Never hand-edit `docs/current/*` or old versions.

## Verdict + wrap-up

- `review_verdict`: `pass` | `changes_requested` (numbered issues + proposed `P4.Fn` fix slices) | `blocked`.
- `result.md`: validation outcomes, judgement per intent job, doc versions created (IDs), verdict + rationale.
- `phase.md`: append the review note (and mark the Doc impact items consolidated).
- Never commit; never transition state — the orchestrator records the verdict via `review-phase`.
