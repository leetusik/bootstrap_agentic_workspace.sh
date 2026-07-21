# Intent — P5

- Captured at: 2026-07-02T14:17:59+09:00
- Origin: operator

## Original Input (verbatim)

> since the /explain feature linked in only my mac, make the feature optional when install. and defer able it public users also can use the feature.

## Confirmed Intent (refined + clarified)

The `/explain` skill is coupled to the operator's personal Mac only: it reads/writes a knowledge
base at `~/projects/personal/knowledge`, commits into that repo, and points at a viewer on
`localhost:8765` (docker + mkdocs). Shipped to anyone else it is dead weight or breaks.

This phase covers **only the first half** of the request:

- **Make `/explain` optional at install.** It must no longer be installed by default. A new opt-in
  installer flag `--with-explain` includes it (for the operator, who has the KB). The skill stays
  live in this repo and embedded in the built artifact — it is gated at **install time** in
  `installer/main.py`, not removed from the source. `--update` never drops or flags an
  already-installed `explain`. Because default install behavior changes and reaches adopters via
  `/update-workspace`, bump `WORKSPACE_VERSION` and add a `CHANGELOG.md` entry in the same commit,
  then rebuild the root artifact.

The **second half** — "public users also can use the feature" — is intentionally **deferred**, not
built here (see the deferred job created alongside this phase: parameterize the KB path / viewer so
any adopter can use `/explain`). The operator's own words ("defer able it") route that to a
deferred job, promoted later when we actually ship `/explain` publicly.

## Clarifications Resolved

- Q: Should `/explain` be opt-in (default off, `--with-explain`) or opt-out (default on,
  `--no-explain`)? — A: Operator was away at ask-time; proceeded with the recommended **opt-in /
  default-off** (the natural meaning of "optional" for a Mac-coupled feature) and the operator then
  approved the plan carrying that choice. Revisit if the operator prefers opt-out.
- Q: Create the phase only, or create and execute it this session? — A: Same — proceeded with the
  recommended **create + execute now** (per-slice work still delegated to the executor), approved
  via the plan.

## Notes

- Split confirmed by exploration: no absolute `/Users/sugang` paths; all Mac coupling funnels
  through `~/projects/personal/knowledge` + `localhost:8765` (docker/mkdocs).
- Build-product constraint: `installer/build.py` embeds every on-disk skill into the artifact, so
  the opt-out must be install-time gating in `installer/main.py`; the root
  `bootstrap_agentic_workspace.sh` is regenerated, never hand-edited.
