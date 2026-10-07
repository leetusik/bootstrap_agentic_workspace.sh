# Deferred Jobs

> Generated dashboard. Do not put detailed deferred context here; edit each `works/deferred/<state>/<DID>/` folder instead.

## Summary

- Open: `30`
- Promoted: `0`
- Dropped: `11`

## Open

| ID | Status | Title | Source | Trigger | Path |
|---|---|---|---|---|---|
| `D12` | `deferred` | Validate the v37 Aside prescription against a real browsable product | P20.REVIEW | the first phase with a real browsable product needing a functional sweep or gated review | `works/deferred/open/D12` |
| `D13` | `deferred` | Decide whether the dedicated-profile rule binds the fallback browser as well as Aside | P20.REVIEW | before the first non-Aside workspace runs a fidelity or gated-review slice -- or whenever the Aside doctrine is next edited | `works/deferred/open/D13` |
| `D17` | `deferred` | Make the stale_docs= aggregate count say what it counts | P22.REVIEW | next time anyone touches stale_docs_line() or a docs phase runs | `works/deferred/open/D17` |
| `D18` | `deferred` | Slim the slice-executor bodies | P23.REVIEW | The next phase that edits either executor body for content, or when the operator next targets per-dispatch cost. | `works/deferred/open/D18` |
| `D19` | `deferred` | Match the contract's smoke pins with whitespace normalized | P23.REVIEW | The next time a contract pin breaks on a line wrap, or together with the never-rule floor pin list. | `works/deferred/open/D19` |
| `D20` | `deferred` | Pin the never-rule floor in smoke | P23.REVIEW | The next edit of CLAUDE.md, or when the whitespace-normalized contract pins land. | `works/deferred/open/D20` |
| `D21` | `deferred` | Correct two stale one-line descriptions (new-slice --help, executors.toml tier comment) | P23.REVIEW | The next edit of workflow.py's argparse help or of executors.toml, or the next docs phase. | `works/deferred/open/D21` |
| `D22` | `deferred` | A running phase stays planned: start-slice never moves it to in_progress | P23.REVIEW | Before the next parallel-start or parallel-gate on a real phase, or the next edit of start_slice / parallel_start_hint. | `works/deferred/open/D22` |
| `D23` | `deferred` | Fix the doc-new-version skill's --source P1.S1 example | P24.REVIEW | The next phase that edits the skill set or workflow.py help text, or together with D21 | `works/deferred/open/D23` |
| `D24` | `deferred` | Correct README drift outside the P21-P23 changes | P24.REVIEW | The next phase that edits either README, or the next docs phase | `works/deferred/open/D24` |
| `D25` | `deferred` | Split decisions.md's Decision Log and judge the other oversized doc sections | P24.REVIEW | The next docs phase whose confirmed scope includes restructuring, or the first slice that needs more than one Decision Log entry | `works/deferred/open/D25` |
| `D26` | `deferred` | Correct the phase_consolidation and phase_execution docstrings on the parallel consolidation field | P24.REVIEW | The next edit of phase_consolidation, parallel_start or set_phase_consolidation, or together with D22 | `works/deferred/open/D26` |
| `D28` | `deferred` | Re-evaluate Doop as a design-cowork option | P25.REVIEW | Doop reaches v1.0, publishes an image, or ships a non-interactive agent token | `works/deferred/open/D28` |
| `D29` | `deferred` | Design schema 2: more than one design project per repo | P26.REVIEW | The operator answers yes, or a repo needs a second design system | `works/deferred/open/D29` |
| `D3` | `deferred` | Make installer/build.py smoke-execute the assembled artifact | P15.REVIEW | Next time installer/build.py is touched, or the first time a broken artifact reaches a commit | `works/deferred/open/D3` |
| `D30` | `deferred` | Flag a design round left open, or review addresses left over, when a design phase ends | P26.REVIEW | The first design-bearing phase under v47, or its review | `works/deferred/open/D30` |
| `D31` | `deferred` | Bring docs/reference/design/ into a design phase's review boundary | P26.REVIEW | The first design-bearing phase review under v47 | `works/deferred/open/D31` |
| `D32` | `deferred` | Widen design-check's reference scan beyond src, href and url() | P26.REVIEW | A drafted card passes design-check but loads a resource through a form the scan does not read, or the dashboard build asks for a stricter check | `works/deferred/open/D32` |
| `D33` | `deferred` | Point design-drafter at the claude-design/ record as design memory | P27.REVIEW | The first drafter phase in a repo that holds a claude-design/ record, or the next edit to design-drafter.md | `works/deferred/open/D33` |
| `D34` | `deferred` | design-migrate: refuse or flag a round-number collision with an existing claude-design/rounds/ when design.json is present | P27.REVIEW | The next edit to design-migrate, or the first repo found with a design.json on a legacy root | `works/deferred/open/D34` |
| `D35` | `deferred` | Nested phase-scope measures from the merge-base after a rebase | P28.REVIEW | The first real ticket rebased before its PR | `works/deferred/open/D35` |
| `D36` | `deferred` | README caveats for the private install: git clean and working-tree tools | P28.REVIEW | The next README edit or an operator report | `works/deferred/open/D36` |
| `D37` | `deferred` | claude-design round push targets the host branch in a nested install | P28.REVIEW | The first design phase run in a nested install | `works/deferred/open/D37` |
| `D38` | `deferred` | Engine texts that skip a clash rename or the host prefix | P28.REVIEW | The next nested engine change | `works/deferred/open/D38` |
| `D39` | `deferred` | A private-install route for a host whose .gitignore refuses --nested | P28.REVIEW | The real company repo refuses the nested install | `works/deferred/open/D39` |
| `D40` | `deferred` | Nested validate/next re-checks the ignore guarantee after install | P28.REVIEW | The next nested engine change, or an operator report | `works/deferred/open/D40` |
| `D41` | `deferred` | Nested install wires a host's AGENTS.md and .agents/skills into Claude Code | operator | The next nested-installer change, or a second host that uses AGENTS.md | `works/deferred/open/D41` |
| `D5` | `deferred` | Confirm: ## Design Style is appended by create-phase only when visual, not scaffolded into every intent.md | P17.REVIEW | Before the first design-bearing phase runs under v34, or the next time works/templates/intent.md is edited. | `works/deferred/open/D5` |
| `D6` | `deferred` | Widen installer/main.py flag_stale_skills() ownership heuristic beyond the disable-model-invocation marker | P17.REVIEW | If a model-invocable skill is retired upstream, or when flag_stale_skills() is next touched. | `works/deferred/open/D6` |
| `D7` | `deferred` | Qualify review-phase gate stage 4 for a phase whose only surface is a throwaway mockup | P17.REVIEW | Before the first design-only or mockup-shipping phase reaches its review. | `works/deferred/open/D7` |

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
| `D14` | `dropped` | State a docs-phase cadence and tune CONSOLIDATION_DEBT_MIN_PHASES to it | resolved by P22 | `works/deferred/dropped/D14` |
| `D15` | `dropped` | Decide the phase-notebook budget's shape: bytes-only, raised, or excluding the generated block | resolved by P22 | `works/deferred/dropped/D15` |
| `D16` | `dropped` | Decide whether keep-tests-small grows teeth for changple5, and in what shape | resolved by P22 | `works/deferred/dropped/D16` |
| `D2` | `dropped` | slice-executor-mid has no co-work refusal clause | fixed in P16.S4 — slice-executor-mid now carries the co-work refusal clause | `works/deferred/dropped/D2` |
| `D27` | `dropped` | Adopt the chosen Claude Design replacement in design-cowork | superseded by P26 (operator chose an own-repo dashboard over repo design files + a design subagent) | `works/deferred/dropped/D27` |
| `D4` | `dropped` | Retrofit guide Troubleshooting omits the .gitattributes line-merge | fixed in P16.S6 — the retrofit guide's Troubleshooting row now lists the .gitattributes line-merge | `works/deferred/dropped/D4` |
| `D8` | `dropped` | Slim CLAUDE.md to <= 12 KB | resolved by P23: CLAUDE.md slimmed from 50,048 B to 12,259 B (<= 12 KB) with all 58 never-rules kept; shipped as workspace v44 | `works/deferred/dropped/D8` |
| `D9` | `dropped` | Decide whether the Aside fallback wording stands, or Aside becomes a hard requirement | Answered at P20/v37: the fallback stands unchanged -- the doctrine's demands bind, the instrument does not (intent.md part 4). CLAUDE.md's fallback sentence is byte-identical to v36; design-cowork's gained one generalizing clause only. | `works/deferred/dropped/D9` |
