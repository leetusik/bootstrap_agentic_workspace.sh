# Deferred Jobs

> Generated dashboard. Do not put detailed deferred context here; edit each `works/deferred/<state>/<DID>/` folder instead.

## Summary

- Open: `7`
- Promoted: `0`
- Dropped: `6`

## Open

| ID | Status | Title | Source | Trigger | Path |
|---|---|---|---|---|---|
| `D12` | `deferred` | Validate the v37 Aside prescription against a real browsable product | P20.REVIEW | the first phase with a real browsable product needing a functional sweep or gated review | `works/deferred/open/D12` |
| `D13` | `deferred` | Decide whether the dedicated-profile rule binds the fallback browser as well as Aside | P20.REVIEW | before the first non-Aside workspace runs a fidelity or gated-review slice -- or whenever the Aside doctrine is next edited | `works/deferred/open/D13` |
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
| `D10` | `dropped` | Install Aside and validate the MCP surface end to end against a real product | Split and closed at P20/v37: the install + surface-validation half was executed live 2026-09-01 (Aside CLI 1.26.810.1915, both transports round-tripped, MCP tool definition measured at 4,974 JSON chars) and the facts are recorded in intent.md and the v37 decision. The title names validating the MCP surface, which v37 stops prescribing, so the job is dropped rather than left open; its against-a-real-product half is re-filed as the next job. | `works/deferred/dropped/D10` |
| `D11` | `dropped` | Decide whether agent Aside runs are confined to a separate account, and write it into the doctrine | Answered and written into the doctrine at P20/v37: agent Aside runs happen on a dedicated profile via a per-invocation 'aside repl --account <id>', never 'aside account use'; the ## Operator Runtime manifest records the agent's account id in a conditionally required field; a manifest naming Aside without one, or a machine holding only the personal profile, is a third needs_operator halt. | `works/deferred/dropped/D11` |
| `D2` | `dropped` | slice-executor-mid has no co-work refusal clause | fixed in P16.S4 — slice-executor-mid now carries the co-work refusal clause | `works/deferred/dropped/D2` |
| `D4` | `dropped` | Retrofit guide Troubleshooting omits the .gitattributes line-merge | fixed in P16.S6 — the retrofit guide's Troubleshooting row now lists the .gitattributes line-merge | `works/deferred/dropped/D4` |
| `D9` | `dropped` | Decide whether the Aside fallback wording stands, or Aside becomes a hard requirement | Answered at P20/v37: the fallback stands unchanged -- the doctrine's demands bind, the instrument does not (intent.md part 4). CLAUDE.md's fallback sentence is byte-identical to v36; design-cowork's gained one generalizing clause only. | `works/deferred/dropped/D9` |
