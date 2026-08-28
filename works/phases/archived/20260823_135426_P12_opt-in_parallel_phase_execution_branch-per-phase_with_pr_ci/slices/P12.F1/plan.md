# P12.F1 — Guard `doc-new-version` against a parallel stream

_Auto-mode plan for the review's must-fix finding 1 (see `works/phases/active/P12/slices/
P12.REVIEW/result.md`). Context: `phase.md` §Settled Decisions (S1 helpers are binding), the
review's traced corruption path: `new_doc_version` (`scripts/workflow.py:~300`) never checks the
stream while `parallel_consolidated` (`:~1294`) hard-refuses the identical condition; two branches
allocating the same `vNNNN` collide silently (`dest.exists()` compares the full slug path,
`docs/index.json` is hand-merged, `validate_docs` has no version-id uniqueness check)._

## Goal

Make the deferred-consolidation guarantee engine-enforced, exactly as the review prescribed:
`doc-new-version` refuses to run on a parallel stream, mirroring the existing guard in
`parallel_consolidated`. Fold in the reviewer's optional hardening: `validate_docs` gains a
duplicate-`vNNNN` check so any historical collision fails loudly instead of silently dropping a
version from `docs/current`.

## Implementation (`scripts/workflow.py` only, + installer rebuild)

1. **The guard** — in `new_doc_version`, immediately after the `doc_id in DOC_TYPES` check and
   before any allocation or file write, mirror the sibling guard:
   ```python
   stream = current_stream(all_active_phases())
   if stream:
       raise SystemExit(f"this checkout is on parallel stream {stream}; doc consolidation runs on the default stream — defer it to post-merge (parallel-merge-finish, then doc-new-version, then parallel-consolidated)")
   ```
   Match `parallel_consolidated`'s actual wording style (read it first). Note `current_stream`
   only shells to git when a stamped parallel phase exists (S1), so default workspaces keep
   byte-identical behavior — the guard is unreachable for them by construction.
2. **The hardening** — in `validate_docs`, per doc: collect the `v(\d+)` prefix of every version
   id in `docs/index.json` and append an error on any duplicate number (message naming the doc,
   the number, and both full ids). Pure additional check; valid workspaces are unaffected.

No other behavior changes. Do not touch the `parallel-*` commands, the skills, or the contract —
the prose already states the rule; this makes the engine agree with it.

## Validation (lean)

1. Temp-repo smoke (scratchpad; commits confined to the temp repo): with a parallel phase
   checked out on its branch, `doc-new-version` refuses with the stream message; on the default
   stream of the same repo it succeeds as before; hand-craft a duplicate-`vNNNN` index fixture and
   assert `validate` errors on it (and passes once fixed).
2. Real tree: `python3 scripts/workflow.py validate` + `next` unchanged; one rebuild-diff
   byte-identity pass (guard adds nothing on the default path).
3. `python3 -m py_compile scripts/workflow.py`; `python3 installer/build.py` then `--check`
   (rebuilt `bootstrap_agentic_workspace.sh` included in this slice's changes).
4. `python3 <scratchpad>/smoke_s3.py` regression once (doc/consolidation paths adjacent).

## Boundaries

Executor: never commit the real repo, never push, no status transitions, no `doc-new-version`
runs against the real tree (the smoke exercises it only inside the temp repo), no other slice's
`plan.md`. Write `result.md`; append a one-line `operations` (or `decisions`) Doc Impact note to
`phase.md` §Doc Impact — the engine now enforces the deferral — so the re-review consolidates it
with the rest.
