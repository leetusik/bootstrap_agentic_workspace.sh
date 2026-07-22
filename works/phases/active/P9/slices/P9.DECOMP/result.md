# Result — P9.DECOMP (decompose phase P9)

## What I decided

Split P9 into **two middle `implementation` slices**, validating and adopting the plan's recommended shape. I spot-checked the plan's survey against the actual files before committing to it.

| Slice | Name | Kind | Risk | Order | depends_on |
|---|---|---|---|---|---|
| `P9.S1` | Installer/product knowledge-setup wiring | implementation | medium | 1 | — |
| `P9.S2` | Repo docs alignment: env-var/REST knowledge default | implementation | medium | 2 | P9.S1 |

Both created as **bare folders** (only `slice.json`) — no `plan.md` pre-filled, per contract. Existing bookends: `P9.DECOMP` (order 0), `P9.REVIEW` (order 9999).

## Why this shape

- **Two slices, not one**: S1 and S2 touch different file classes with different commit/validation profiles. S1 edits embedded machinery under `installer/`, which forces a same-commit `python3 installer/build.py` rebuild of `bootstrap_agentic_workspace.sh` plus a `WORKSPACE_VERSION` bump and CHANGELOG entry. S2 edits only `README.en.md` (a human-facing repo doc, **not** machinery → no rebuild) plus `phase.md` Doc-impact notes. Separating them keeps the machinery rebuild atomic and lets REVIEW validate each cleanly.
- **Two slices, not three**: S1's two edits (seed `operations.md` body + fresh-install stdout line) are the same "what a fresh workspace receives" concern and share the single rebuild/version-bump/CHANGELOG obligation. Splitting them would force two version bumps for one logical change, so they stay together.
- **Both `medium`, neither `low`**: `low` is reserved for fully mechanical plans. S1 writes a substantive setup narrative (env-var exports, the Codex `network_access` tradeoff, plugin-vs-default framing) on top of a build-machinery edit; S2 reframes a README callout's emphasis and authors Doc-impact wording. Both are prose/framing judgment, so `medium` (→ `slice-executor-mid`) is the honest floor. Neither reaches `high`: no engine-logic design, and the intent is well-specified. (The orchestrator may still bump one tier up if a plan turns out heavier; it can never bump down, so I did not floor these at `low`.)
- **S2 depends_on S1** (advisory): S1 lands the canonical knowledge-setup text in the seed doc first; S2 mirrors that wording in `README.en.md` and the Doc-impact notes for consistency.

## Validation of the plan's assumptions (spot-checks)

- `installer/payloads/doc_bodies/operations.md` — confirmed a generic template with **zero** knowledge mentions (Status/Purpose/Env-Vars table/Deployment/…). This is where S1's knowledge-setup section goes.
- `installer/main.py` fresh-install stdout block — confirmed the final `else:` (~lines 623–633) lists contracts/skills/executor-tiers/docs but has **no KB line**. `WORKSPACE_VERSION = 16` at line 38 (S1 → 17).
- `README.en.md` knowledge callout (~lines 274–279) — confirmed it still **leads with the plugin-install path** (`/plugin marketplace add leetusik/knowledge …`). S2 reframes to env-var/REST-first, plugin as alternative.
- `CHANGELOG.md` exists at repo root — S1 adds an entry with the version bump.
- No engine/machinery *logic* change is needed: the resolver / REST save / skill-detection / Codex-sandbox degradation already exist externally and are described in machinery. This phase is docs + fresh-workspace onboarding only.

## What later slices should know

- **Do not version docs in a middle slice.** S2 appends Doc-impact notes to `phase.md` (for `operations.md` v0016 and `decisions.md` v0022); REVIEW consolidates them into new versions on a pass.
- **S1 machinery obligations are non-optional**: `python3 installer/build.py` rebuild in the same commit (pre-commit hook runs `--check`), `WORKSPACE_VERSION` 16→17, CHANGELOG entry. The executor runs `build.py` (a build step, allowed); the orchestrator owns the commit.
- **Consume, don't implement the SaaS contract**: describe org-level keys (P18) and returned doc URLs (P19) as consumed from the knowledge repo — never implement SaaS-side behavior here.
- Full breakdown, rationale, findings, constraints, and the Doc-impact placeholder are seeded in `works/phases/active/P9/phase.md`.

## Validation run

- `python3 scripts/workflow.py validate` → passed (see verdict).

## Deviations from plan.md

None. Adopted the plan's recommended two-slice shape; set S2's risk to `medium` (the plan left it to my judgment as `low`-or-`medium`) because the README reframing and Doc-impact authoring are not fully mechanical.
