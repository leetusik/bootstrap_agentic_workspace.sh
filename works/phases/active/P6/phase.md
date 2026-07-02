# Phase P6: Wire /explain to the KB document API

_Intent: see [intent.md](intent.md)._

## Objective

Replace /explain steps 5–7 (manual file write, Recent bullet, KB git commit) with one POST to the KB document API at localhost:8766 — the API-owned write path — keeping today's manual flow only as a transport-failure fallback and handling HTTP errors per the API contract; steps 1–4 and 8 unchanged. Edit both live skill copies (byte-consistent apart from the sanctioned frontmatter difference), rebuild the distributable with installer/build.py (--check passing), bump WORKSPACE_VERSION 2→3 + CHANGELOG v3 per the release rule, and finish with the operator-authorized sync of the updated skill to ~/.claude/skills/explain/SKILL.md. D1 stays deferred — KB path and ports stay hardcoded.

## Context

## Decomposition

_Slice breakdown and rationale — filled by the `P6.DECOMP` slice._

## Findings & Notes

_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._

## Constraints

## Open Questions

-
