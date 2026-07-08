# Phase P7: Retire embedded /explain

_Intent: see [intent.md](intent.md)._

## Objective

Remove the explain feature from the bootstrap distribution — embedded skill copies (.claude/skills/explain, .agents/skills/explain), the --with-explain installer path, and KB API wiring — and point users at the knowledge repo's Claude Code plugin instead. Gated: starts only after the knowledge repo's P7 (Claude Code plugin) review passes; leave everything as-is until then. Rebuild the installer (python3 installer/build.py) as part of the work; likely resolves deferred D1 (hardcoded KB path/ports) by deletion.

## Context

## Decomposition

_Slice breakdown and rationale — filled by the `P7.DECOMP` slice._

## Findings & Notes

_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._

## Constraints

## Open Questions

-
