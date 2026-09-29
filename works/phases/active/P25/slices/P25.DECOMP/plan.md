# Plan — P25.DECOMP (decomposition)

## Context

P25 is a **research** phase: it returns a ranked top 3 of replacements for Claude Design as the tool behind the `design-cowork` skill, with trade-offs and a recommendation on whether Claude Design stays as an optional path. Adopting the chosen option is **out of scope** (a later phase the operator creates), so the phase changes no machinery and needs no `DECOMP2`: the findings end in a report, not in build slices. Read `works/phases/active/P25/intent.md` in full. It holds the five ranking criteria, the fixed governance vs the replaceable loop, and two orchestrator readings the research must **verify, not assume**.

## The cut: two research slices, no DECOMP2

1. **`P25.S1` baseline and screened longlist** (`research / high`, order 1)
   - Verify the two readings in `intent.md`, and say what was checked and how:
     (a) whether `DesignSync` / Claude Design works under `ocx claude`, from ocx config, docs, how the tool is provided and whether it needs a claude.ai login, or a live probe if one is cheap and uses no operator account;
     (b) how Anthropic intends Claude Design to be used (native flow, handoff bundle), compared with ours.
   - Map what the replaceable loop actually needs from a tool (`design-cowork` SKILL.md §The loop, §The handoff / §The card set, §The design record, §Read back, §Closing the round, §The mockup), so each candidate is judged against real requirements and not against Claude Design's feature list.
   - Build a longlist of candidates across categories. Examples to consider, not prescribe: self-hostable canvases (Penpot and its MCP, tldraw, Excalidraw), component/story galleries (Storybook, Ladle), a repo-native static frames board the agent writes and the operator views locally, and anything else the survey turns up.
   - Screen every candidate against the 5 criteria with a pass / fail / unclear table, and pick a shortlist of about 4–6.
2. **`P25.S2` evaluate the shortlist and rank the top 3** (`research / high`, order 2, depends on S1)
   - Evaluate the shortlist in depth, with a cheap hands-on probe where it is possible (scratch dir outside the repo, no repo installs, no accounts).
   - Rank the top 3 with trade-offs per criterion. For each option, sketch how the replaceable loop (handoff → operator view → read-back → signoff/regroup, design memory) would map onto it, with the fixed governance untouched.
   - State where `frontend-design` would be needed, if anywhere.
   - Recommend whether Claude Design stays as an optional path.
   - The full report lives in S2's `result.md`. The ranked summary lives in `phase.md`.

**Why two slices and not one:** S1's verification and screening decide what S2 evaluates in depth, and splitting keeps each executor's context bounded. **Why no DECOMP2:** nothing after the research needs cutting inside this phase.

## What the executor does

1. Read `intent.md`, `phase.md`, and `CLAUDE.md`'s research-kind and DECOMP2 rules.
2. Create the two bare slices (no `plan.md`):
   - `python3 scripts/workflow.py new-slice --phase P25 --slice P25.S1 --name "verify the baseline and screen a replacement longlist" --kind research --risk high --order 1`
   - `python3 scripts/workflow.py new-slice --phase P25 --slice P25.S2 --name "evaluate the shortlist and rank the top 3" --kind research --risk high --order 2 --depends-on P25.S1`
3. Edit `phase.md`:
   - `## Decisions`: the two-slice cut and why there is no DECOMP2; adoption is out of scope.
   - `## Notes for later slices`, tagged **(from P25.DECOMP, for P25.S1)** / **(…, for P25.S2)**:
     - the 5 criteria are the ranking rubric;
     - the two readings to verify;
     - the fixed/replaceable split;
     - no machinery edits, no product code, no account creation, probes only in scratch outside the repo;
     - name the evidence behind each claim (doc URL, command run, or "not verified" plus the reasoning);
     - S2 owns the ranking and the Claude Design recommendation.
   - `## Doc impact`: `- (none — P25 is findings-only; adoption is a later operator-created phase)`.
   - Rewrite `## Now` as the handoff to S1.
4. `python3 scripts/workflow.py rebuild`, then `validate`.
5. Write `result.md`, verdict block first. Include your read on the acceptance gate.

## Boundaries

- Bare folders only. No `accept-gate`, no commits, no status transitions beyond `new-slice`.
- No research in this slice. The candidate examples above are handed to S1 as seeds only.

## Acceptance gate (orchestrator, after finish-slice)

**`--waive`**, with the note: "research-only: findings are a ranked report the operator reads; no operator-visible product or machinery change; adoption is a later operator-created phase". Nothing runnable changes, so a gated review would have nothing to open. The operator reads the ranked top 3 at the end of the phase, when the loop reports it.

## Verification

- `validate` exits 0.
- `next` points at `P25.S1`.
- The S1 and S2 folders each hold only `slice.json`.
- `phase.md`'s `## Slices` table lists DECOMP, S1, S2 and REVIEW.
