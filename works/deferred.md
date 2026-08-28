# Deferred Jobs

> Generated dashboard. Do not put detailed deferred context here; edit each `works/deferred/<state>/<DID>/` folder instead.

## Summary

- Open: `1`
- Promoted: `0`
- Dropped: `3`
- Rebuilt at: `2026-08-29T03:42:14+09:00`

## Open

| ID | Status | Title | Source | Trigger | Path |
|---|---|---|---|---|---|
| `D3` | `deferred` | Make installer/build.py smoke-execute the assembled artifact | P15.REVIEW | Next time installer/build.py is touched, or the first time a broken artifact reaches a commit | `works/deferred/open/D3` |

## Promoted

| ID | Status | Title | Promoted To | Path |
|---|---|---|---|---|
| - | - | - | - | - |

## Dropped

| ID | Status | Title | Reason | Path |
|---|---|---|---|---|
| `D1` | `dropped` | Make /explain portable so public users can use it | Resolved by P7.S1: embedded /explain retired; portability shipped for real by the knowledge repo's Claude Code plugin (/knowledge:explain) | `works/deferred/dropped/D1` |
| `D2` | `dropped` | slice-executor-mid has no co-work refusal clause | fixed in P16.S4 — slice-executor-mid now carries the co-work refusal clause | `works/deferred/dropped/D2` |
| `D4` | `dropped` | Retrofit guide Troubleshooting omits the .gitattributes line-merge | fixed in P16.S6 — the retrofit guide's Troubleshooting row now lists the .gitattributes line-merge | `works/deferred/dropped/D4` |
