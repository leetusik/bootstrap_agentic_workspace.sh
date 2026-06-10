# Result

- Phase ID: P3
- Slice ID: P3.S1
- Slice: retrofit guide and durable docs
- Review status: pending
- Next action: execute P3.S2 (installer --into-existing mode), implementing the policy this guide specifies

## Outcome

Shipped the human-facing retrofit deliverable and recorded durable truth:

- **`docs/retrofit-guide.md`** (new) — the full adoption runbook: when to
  retrofit, prerequisites, the two recommended paths (`/retrofit` skill and
  `--into-existing`), the **four-tier collision policy** in plain terms, seeding
  P1 from project state, post-install steps (reconcile contract, gitignore
  `__pycache__`, commit), verification, idempotency, a **manual fallback**
  (staging copy) so the guide is useful even before S2 lands, and a
  troubleshooting table. This doc is the written spec S2 implements and S4 checks.
- **`README.md`** — new Quickstart subsection "Already have a project? Retrofit
  it" with the `--into-existing` example and a guide link, plus a pointer added
  to the Safety note.
- **`operations` v0002** — adoption/retrofit procedure as durable operations
  truth (pointer-style; links the guide).
- **`decisions` v0003** — the decision to support non-destructive retrofit via
  `--into-existing` (extend the installer; additive merges; four-tier policy;
  seed-from-state; reject uniform skip-if-exists and zero-touch).

## Deviations from Plan

None. Guide-first ordering as planned. The guide intentionally references
`--into-existing` and the `/retrofit` skill, which S2/S3 deliver — it is the spec
for those slices; the manual fallback keeps the guide standalone in the meantime.

## Validation Run

- `python3 scripts/workflow.py rebuild-docs` → regenerated current snapshots.
- `python3 scripts/workflow.py validate` → "Workflow validation passed."
- Spot-checked `docs/current/operations.md` (v0002) and `docs/current/decisions.md`
  (v0003) reflect the edits.

## Files Changed

- `docs/retrofit-guide.md` (new)
- `README.md` (Quickstart subsection + Safety pointer)
- `docs/versions/operations/v0002_*.md` (new), `docs/versions/decisions/v0003_*.md` (new)
- `docs/index.json`, `docs/current/operations.md`, `docs/current/decisions.md` (generated)

## Doc Versions Created

- `operations` → v0002 (adoption/retrofit procedure)
- `decisions` → v0003 (support non-destructive retrofit)

## Roadmap Updates

- None to the slice set. Next: P3.S2.

## Retrospective

- Writing the guide first forced the exact collision policy (the four tiers, the
  rebuild-gating, the sidecar/marker contract handling) to be pinned as prose
  before any code — S2 now implements against a concrete spec, and the README +
  durable docs already point users at it.
