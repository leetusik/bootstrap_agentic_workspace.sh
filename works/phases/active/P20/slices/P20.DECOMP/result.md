# Result — P20.DECOMP (decompose phase)

- **status:** done
- **summary:** Cut P20 into three bare middle slices on the seams of the change rather than the files — S1 surface truth (intent parts 1/2/5), S2 profile safety (part 3, confirming part 4), S3 release + consistency sweep — all `implementation / high`, chained S1 → S2 → S3, and recorded the breakdown, passage ownership, the smoke-test hazard and the deferred-job mechanics in `phase.md`.
- **files_changed:**
  - `works/phases/active/P20/slices/P20.S1/slice.json` (created, bare folder)
  - `works/phases/active/P20/slices/P20.S2/slice.json` (created, bare folder)
  - `works/phases/active/P20/slices/P20.S3/slice.json` (created, bare folder)
  - `works/phases/active/P20/phase.md` (edited: Decisions, Doc impact, Operator Questions, Notes for later slices, Now)
  - `works/phases/active/P20/slices/P20.DECOMP/result.md` (this file)
  - `works/index.json`, `works/backlog.md`, `works/state.json`, `works/events.jsonl`, `works/phases/active/P20/slices/P20.DECOMP/slice.json` (engine-written by `new-slice` / `rebuild`), `docs/index.json` (`last_rebuilt_at` timestamp only — no doc content changed)
- **validation:**
  - `python3 scripts/workflow.py new-slice --phase P20 --slice P20.S{1,2,3} …` — passed (three bare folders, `slice.json` only)
  - `python3 scripts/workflow.py rebuild` — passed
  - `python3 scripts/workflow.py validate` — passed ("Workflow validation passed.")
  - `python3 installer/build.py --check` — passed, untouched ("in sync with installer/ source")
  - `wc -l -c works/phases/active/P20/phase.md` → 77 lines / 13,322 bytes — inside the 200-line / 16 KB budget
  - `bash tests/retrofit_smoke.sh` — deliberately **not** run: this slice changed no machinery; it belongs to the middle slices and the review
- **deviations:** one, deliberate — the plan sketched a defensible two-slice cut (taxonomy+default / profile+release) and left the shape to me; I cut **three** and argue it in `phase.md` `## Decisions`. Everything else followed the plan.
- **doc_impact:** `- (nothing from P20.DECOMP itself) Expected carriers for the review to consolidate: qa.md (Verification doctrine / With what), decisions.md (the v36 Aside entry), operations.md (manifest field + migration note). (P20.DECOMP)`
- **operator_need:** none

---

## The inventory — verified against the tree, not assumed

`grep -rn -i aside` over the live tree (excluding `.git/`, `works/phases/archived/`, `docs/versions/`,
`works/events.jsonl`, `bootstrap_agentic_workspace.sh`) confirms the plan's inventory **exactly**, with
no missed live carrier. Every file the plan named carries what it said it carried, at the lines it said:

- `CLAUDE.md` line 76 — the whole Aside rule is one paragraph, as described.
- `.claude/agents/slice-executor-{mid,high}.md` lines 32, 33, 36 — verified **byte-identical between the
  two tiers** in all three passages (diffed the matched lines).
- `.claude/skills/design-cowork/SKILL.md` — ~278, ~420–427, ~429–433, ~435–439, ~500–502.
- `.claude/skills/review-phase/SKILL.md` line 43.
- `installer/payloads/doc_bodies/operations.md` line 28.
- `tests/retrofit_smoke.sh`, `installer/main.py` (`WORKSPACE_VERSION = 36`, line 38), `CHANGELOG.md`.
- `README.md` / `README.en.md` — confirmed: **no Aside mention at all**, so the plan's "verify before
  assuming" resolves to "no edit".

Additions and corrections the plan did not have:

1. **The smoke-test hazard is narrower than it looks, and that is good news.** All the v36 Aside
   assertions live in **one** python heredoc (Test 5), not scattered across the suite: design-cowork
   ~138–142, review-phase ~149–153, the ops seed field ~159–163, both agent bodies ~197–205 (inside the
   per-tier loop, so each string is asserted **twice**), `CLAUDE.md` ~255–259, plus the Test-5 summary
   line ~274. One block to keep in step, per slice.
2. **A version assertion the plan did not name.** `tests/retrofit_smoke.sh` ~line 395 asserts a
   *three-way equality* — installer `WORKSPACE_VERSION` == top `## v<N>` CHANGELOG heading == the fresh
   install's `works/.workspace-version.json` marker. That makes the version bump and the changelog
   section literally inseparable and confirms the plan's "one slice, the last one" rule with a test
   behind it. Recorded in `phase.md` `## Decisions` for S3.
3. **The qa doc's long-form doctrine has no seed twin.** `installer/payloads/doc_bodies/qa.md` carries
   no Aside prose at all (only `## Regression Checklist`), so the long-form *With what — the instrument*
   argument exists in exactly two live places: `.claude/skills/design-cowork/SKILL.md` (machinery, a
   middle slice edits it) and `docs/current/qa.md` (a generated snapshot, the review consolidates it).
   No middle slice needs to touch a qa seed body.
4. **Cross-phase coupling.** `works/phases/active/P21/intent.md` says P21 "should coordinate its
   workspace version number with P20's at review time". P20 claims **v37**; noted for S3/REVIEW.

## The cut, and the alternative I rejected

Three middle slices, `implementation / high`, `--order` 1/2/3, `depends_on` chained:

| Slice | Seam | Intent parts |
|---|---|---|
| `P20.S1` | what the instrument is and how it is driven | 1, 2, 5 |
| `P20.S2` | whose browser it may drive | 3 (confirms 4) |
| `P20.S3` | release + consistency sweep | — |

The rejected alternative was the plan's own sketch: two slices, profile safety riding with the release
(P19's shape — one doctrine slice, then a doctrine+release slice). I rejected it on one specific ground.
P19's two changes touched *different* passages; P20's rewrite passes over **the same five passages
twice** — the CLAUDE.md rule, agent lines 32/33/36, the design-cowork instrument block, review-phase
stage 2, and the ops seed field. When the same prose is rewritten twice in a phase, the failure mode is
drift between the two passes (and between the two agent bodies), and the only thing that catches it is a
sweep over a *settled* tree: the full smoke run, `sync-agents --check`, and a grep for surviving v36
wording. A slice cannot perform that sweep from inside its own edit, and a slice that also owns the
changelog would be writing the release note for prose it is still changing. S3 is small in edits
(`installer/main.py`, `CHANGELOG.md`, the rebuild) and large in verification, which is exactly the shape
that pays here. Its `--risk` is `high` regardless — it edits machinery and rebuilds the installer, and
the plan's rule is explicit that nothing here is a `low` slice.

Ownership between S1 and S2 is assigned by **change type, not by file**: S1 makes every *surface-wording*
rewrite everywhere (including the seed manifest's `aside mcp` → repl-over-Bash phrasing), S2 makes every
*profile* addition in those same files. The alternative — giving S2 the whole seed file — would leave the
seed naming the retired MCP surface at S1's commit boundary. Recorded in `phase.md` `## Notes for later
slices`; that note is why S2 will not rewrite what S1 just wrote.

## The three deferred jobs — mechanics decided, execution left to the review

The engine has no half-close (`drop-deferred` is the only closing transition, `deferred.json` has no
partial state), so the exact reasons and the one re-file are written out in `phase.md` `## Decisions`.
The shape: **D9 drop** (answered — fallback stands), **D11 drop** (answered *and written into the
doctrine*), **D10 drop + re-file the narrowed half** as a new job (next free id is **D12**). D10 is the
only judgment call, and it goes to drop-and-re-file rather than leave-open because its title names
validating **the MCP surface** — the very surface v37 stops prescribing — so leaving it open would leave
an actively misleading job on the deferred dashboard. Filing and dropping are the orchestrator's actions
at the review; no middle slice touches them.

## What this slice did not do

No doctrine prose, no product code, no `plan.md` pre-filled for S1/S2/S3 (all three folders hold only
`slice.json`), no `docs/current/*` edit, no `doc-new-version`, no `accept-gate`, no status transition, no
commit, and nothing touched under `works/phases/archived/**` or `docs/versions/**`. On the gate: the
decomposition turned up **nothing operator-visible** — this repo ships no browsable product and the
phase's whole effect is machinery prose, a seed doc body, smoke assertions and a version bump — so the
evidence supports the orchestrator's intended `--waive`.
