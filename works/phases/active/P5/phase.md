# Phase P5: Optional /explain install (--with-explain)

_Intent: see [intent.md](intent.md)._

## Objective

Make the /explain skill opt-in at install: default off, included only via a new --with-explain flag. It stays live in the repo and embedded in the built artifact; gating happens at install time in installer/main.py, keeping the derived skill inventories, conflict guard, dir creation, and stale-skill flagging consistent from one filter point. --update preserves an already-installed copy (never drops or flags it). Bump WORKSPACE_VERSION and add a CHANGELOG entry per the release rule, then rebuild the root artifact.

## Context

## Decomposition

_Slice breakdown and rationale — filled by the `P5.DECOMP` slice._

## Findings & Notes

_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._

## Constraints

## Open Questions

-
