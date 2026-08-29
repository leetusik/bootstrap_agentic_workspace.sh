# Result — P19.DECOMP (decompose phase)

- **status:** done
- **summary:** Cut P19 into exactly the two middle slices the operator's 4-slice cap allows —
  `P19.S1` (the `research` kind + generalizing `DECOMP2`) and `P19.S2` (Aside as the prescribed
  real-browser verification instrument, shipping v36) — both `implementation / high`, created as
  bare folders. Resolved the plan's open question in favour of **shape A** and did the Aside
  investigation here, handing the findings down through the notebook.
- **files_changed:**
  - `works/phases/active/P19/slices/P19.S1/slice.json` (created via `new-slice`)
  - `works/phases/active/P19/slices/P19.S2/slice.json` (created via `new-slice`)
  - `works/phases/active/P19/phase.md`
  - `works/phases/active/P19/slices/P19.DECOMP/result.md`
  - engine-regenerated: `works/backlog.md`, `works/index.json`, `works/state.json`, `works/events.jsonl`
- **validation:**
  - `python3 scripts/workflow.py validate` — PASS ("Workflow validation passed.")
  - `bash tests/retrofit_smoke.sh` — PASS ("ALL RETROFIT SMOKE TESTS PASSED")
  - `python3 installer/build.py --check` — PASS (no machinery edited, so nothing to rebuild)
  - `wc -l/-c works/phases/active/P19/phase.md` — 140 lines / 10.8 KB, under the 200-line / 16 KB budget
- **deviations:** none
- **doc_impact:** none — decomposition changed no durable truth. The two middle slices will append
  their own `## Doc impact` notes for `P19.REVIEW` to consolidate.

---

## The two-slice cap held

`P19.DECOMP` + `P19.REVIEW` already existed, so exactly two were created:

| Slice | Kind / risk | Order | Depends on |
|---|---|---|---|
| `P19.S1` — add the research slice kind and generalize DECOMP2 | `implementation / high` | 1 | — |
| `P19.S2` — prescribe Aside as the real-browser verification instrument; ship v36 | `implementation / high` | 2 | `P19.S1` |

No `plan.md` was pre-filled and no `P19.DECOMP2` was created (the cap forbids it — recorded in
`phase.md` under `## Decisions` so the review does not read the absence as an omission).

The breakdown, the risk reasoning, the file-by-file blast radius and the Aside findings are in
`works/phases/active/P19/phase.md` (`## Decisions`, `## Notes for later slices`) — not restated here.

## The open question: shape A, decided

The plan offered **A** (split by change) or **B** (dogfood — a `--kind research` slice on Aside).
Chose **A**, because B spends half a 4-slice budget proving the new kind and ships change 2 as
findings only, leaving the operator's stated objective ("make Aside the prescribed instrument")
unlanded this phase.

The dogfood is not actually forfeited: the Aside investigation was done *here*, and its findings were
handed to `P19.S2` through `## Notes for later slices` — which is precisely the mechanism the
`research` kind institutes (findings survive in `phase.md`, not in a dead executor context). The phase
demonstrates the handoff without buying a slice for it.

## Aside investigation (the scoping evidence)

Sources: `https://docs.aside.com/help/developers`, `https://aside.com/blog/developers`,
`https://docs.aside.com/help/subscription`, `https://aside.com/download`, YC company page.

**Reachable, in principle — three surfaces, all documented.** Install
`curl -fsSL https://releases.aside.com/install.sh | bash`. CLI (`aside "<task>"`, `aside --session`,
`aside exec -m <model>`, `aside account list|status|use`); MCP server (`aside mcp`, configured
`{"mcpServers":{"aside":{"command":"aside","args":["mcp"]}}}`); REPL
(`aside repl "const p = await openTab('https://example.com')"` — Playwright-like `page`, tabs,
locators, screenshots, downloads, JS, plus the same page snapshots and stable element refs the browser
agent itself acts on). The docs' own routing: CLI for a check inside a dev workflow, MCP when a coding
agent needs evidence from private pages, REPL for deterministic inspection.

**Not reachable *here*, and that is a finding rather than a failure** (the plan anticipated it):

- no `aside` on `PATH`, no `/Applications/Aside.app`, no `.mcp.json` in the repo;
- installing it is an outward-facing, operator-only action (a macOS `.dmg` download plus an account);
- **macOS-only** desktop app; **headless operation is undocumented**; free tier is 500 credits/month.

So `P19.S2` is scoped as the plan's third shape — **prescribe Aside, document the surface, state the
fallback** — not as a live integration, and it must not claim a verified browser run. Recommending
**MCP as the surface to prescribe for an executor** (its tools arrive as native tools in a dispatched
session, which the CLI and REPL do not), with CLI/REPL as the Bash-reachable fallbacks. This repo is
workspace machinery with no product UI, so nothing regresses from the absence of a live run.

The two consequences only the operator can settle — whether the Linux/CI/no-install fallback wording
is acceptable, and whether a follow-up job should be filed to install Aside and validate the MCP
surface end to end — are on `phase.md`'s `## Operator Questions` for `P19.REVIEW` to route.

## Scoping method

Greps over `scripts/workflow.py`, `CLAUDE.md`, `.claude/agents/*`, `.claude/skills/*`,
`tests/retrofit_smoke.sh`, `installer/payloads/doc_bodies/*`, `CHANGELOG.md` and `installer/main.py`
confirmed the plan's blast-radius list and added three facts worth having, all recorded as notes:
the two agent-tier bodies are byte-identical below the frontmatter and `retrofit_smoke.sh` asserts it;
the `plan only` "stop before an unlanded dependency" rule in both `do-*` skills gains a fourth face
(a `DECOMP2` following a research slice); and the **seed** `installer/payloads/doc_bodies/qa.md`
carries no verification-doctrine section at all today, so adding an Aside line there is a deliberate
judgement call rather than an edit to an existing paragraph.

`WORKSPACE_VERSION` lives at `installer/main.py:38` (currently `35`); the bump to 36 and the single
`CHANGELOG.md` `## v36` section covering both changes were assigned to `P19.S2`, the last middle
slice, so the entry is written once with both halves landed.

## Dead ends

`https://docs.aside.com/llms.txt` returned only an index, and the developers page (both HTML and
`.md`) never states headless support, platform matrix, or whether the desktop app must be running for
the CLI/MCP/REPL to work. Those remain genuinely unknown and are recorded as such — `P19.S2` should
write the prescription without asserting them.
