# Deferred Jobs

> Generated dashboard. Do not put detailed deferred context here; edit each `works/deferred/<state>/<DID>/` folder instead.

## Summary

- Open: `5`
- Promoted: `0`
- Dropped: `3`
- Rebuilt at: `2026-08-29T11:19:38+09:00`

## Open

| ID | Status | Title | Source | Trigger | Path |
|---|---|---|---|---|---|
| `D3` | `deferred` | Make installer/build.py smoke-execute the assembled artifact | P15.REVIEW | Next time installer/build.py is touched, or the first time a broken artifact reaches a commit | `works/deferred/open/D3` |
| `D5` | `deferred` | Confirm: ## Design Style is appended by create-phase only when visual, not scaffolded into every intent.md | P17.REVIEW | Before the first design-bearing phase runs under v34, or the next time works/templates/intent.md is edited. | `works/deferred/open/D5` |
| `D6` | `deferred` | Widen installer/main.py flag_stale_skills() ownership heuristic beyond the disable-model-invocation marker | P17.REVIEW | If a model-invocable skill is retired upstream, or when flag_stale_skills() is next touched. | `works/deferred/open/D6` |
| `D7` | `deferred` | Qualify review-phase gate stage 4 for a phase whose only surface is a throwaway mockup | P17.REVIEW | Before the first design-only or mockup-shipping phase reaches its review. | `works/deferred/open/D7` |
| `D8` | `deferred` | Slim CLAUDE.md to <= 12 KB | P18 | After P18 lands and the just-in-time Read Order is settled; a dedicated editorial phase, not folded into other work. | `works/deferred/open/D8` |

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
