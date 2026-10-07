# Plan — P25.S2 (research): evaluate the shortlist and rank the top 3

## Context

This is the deliverable slice of P25 (see `intent.md`). S1 landed the following, and none of it needs to be re-derived:
- both readings verified;
- requirements R1–R12 (musts R1–R8);
- a 17-row screening table;
- a four-option shortlist in `phase.md` `## Decisions`: repo-native frames board, Storybook + `@storybook/addon-mcp`, self-hosted Penpot + MCP, self-hosted Doop.

Every `phase.md` note tagged `for P25.S2` is binding. That covers the rubric C1–C5, fixed vs replaceable, hard limits, the evidence rule, the per-candidate open unknowns, the Claude Design inputs, and the MCP-cost-under-ocx note. Read them first, and `slices/P25.S1/result.md` §1 (requirements) plus the shortlist rows of its screening table.

## The local-account boundary (orchestrator's ruling, answering S1's note)

**Cleared, narrowly.** A throwaway **local** user on a **scratch self-hosted** Penpot or Doop instance is not a vendor account and involves none of the operator's identities, so it may be created, subject to these conditions:
- Docker is available here (`docker info` succeeds). Run each instance from a compose file in the scratch dir: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/1aa717b3-0250-45dc-9d55-868a00349f51/scratchpad/`, never in the repo.
- Bind to `127.0.0.1` only, and use a throwaway email/password.
- **Tear down** afterwards with `docker compose down -v`, and remove the pulled images if they are large. Record in `result.md` that teardown happened.
- **Time-box it:** if an image pull or bring-up is heavy or fails after a reasonable attempt, stop and judge that candidate from docs and source, and say so. A probe is evidence, not an obligation.
- Any browser used to drive a probe is a **throwaway profile** created in scratch (e.g. a headless Chromium via `npx playwright` in scratch, or Aside only with an agent account id if one is recorded). Never the operator's signed-in profile.
- Still forbidden: SaaS or vendor accounts, the operator's accounts, installs into the repo, and any machinery edit.

## Work

1. **Resolve the open unknowns per candidate.** Probe where it is cheap, otherwise reason from docs and source, and cite the evidence for each claim. The decisive questions:
   - **Frames board:** prototype a minimal board in scratch. Use 3–4 numbered HTML cards across two groups, plus a generated index with grouping, numbered order, viewport frames and a round address. Confirm that an executor can read it back visually (screenshot via a scratch headless browser) and textually (the files). Settle how operator feedback returns without inline comments. Settle when `frontend-design` would be needed.
   - **Storybook:** does a regroup (the `title` change) break R7 or story URLs in a way that matters? How do you draft surfaces that don't exist in code yet? What about non-React support? Which addon-mcp toolsets actually work? What is the install footprint in a product repo? A scratch `npx storybook init` probe is allowed if it is cheap.
   - **Penpot:** C3 is decisive. Can a background executor drive it while the operator views the same file, given the MCP plugin's live-tab requirement? Also: the export path into the repo record (R5), how R2 and R7 map onto boards and pages, vector vs HTML/CSS fidelity, and infra weight.
   - **Doop:** does a background subagent reuse the MCP connection? Is there any design-system or token memory (C5)? What is the export path? How mature is it (commits, releases, issues)?
2. **Rank the top 3.** Give a per-criterion trade-off table: C1–C5, plus the R-musts, setup cost, ongoing maintenance, and the cost of MCP schemas inlined under ocx. Give a short rationale per rank, and say why the fourth candidate dropped out.
3. **Map the loop for each of the top 3**, with the fixed governance untouched:
   - `handoff.md` → what the agent drafts, and where;
   - the operator's view surface;
   - the executor read-back;
   - the SIGNOFF regroup;
   - where the persistent design memory lives (system, prior rounds, decisions).

   Name which of today's pieces survive or change: `handoff.md`, the numbered card contract, the `DesignSync` read-back, the regroup. Say where `frontend-design` is needed, if anywhere.
4. **Claude Design recommendation.** Should it stay as an optional path, and in what form? Consider: a main-thread-only, paid-plan, opt-in path with `/design-login` under ocx, or retirement. Weigh the "outside `DesignSync`'s stated purpose" fragility. Be explicit about what stays unverified.
5. **Adoption notes.** List what the later adoption phase would have to change in the machinery: skill sections, executor `tools:` allowlists (`mcp__<server>`), and the `## Operator Runtime` fields. Keep it to one short list, and do not make those changes.

## Where findings land

- **`result.md`**, verdict block first. It is the full report the operator reads, so write it for the operator:
  1. a one-screen executive summary (the ranked top 3 + the Claude Design recommendation);
  2. then the evidence: probes run with commands and outcomes, the trade-off table, loop mappings, and adoption notes.
- **`phase.md`**, edited under budget:
  - `## Decisions`: the ranked top-3 summary and the Claude Design recommendation, compact;
  - `## Notes for later slices`: consume the S2 notes; leave anything the review must check;
  - `## Operator Questions`: only genuine choices the operator must make when picking. E.g. a trade-off where the ranking hinges on a preference only they hold. Keep it to few or none;
  - `## Now`: rewrite it as the handoff to `P25.REVIEW`;
  - `## Doc impact`: nothing.

## Boundaries

- No edits outside `phase.md` and this slice's `result.md`.
- Scratch only for probes.
- Tear down every container, and do not leave a local server running.

## Validation

- `python3 scripts/workflow.py validate` exits 0.
- `git status --short` shows only `works/` changes.
- `docker ps` shows no container this slice started.
