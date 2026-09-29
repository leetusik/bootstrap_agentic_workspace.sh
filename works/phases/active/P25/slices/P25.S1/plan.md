# Plan — P25.S1 (research): verify the baseline and screen a replacement longlist

## Context

P25 ranks replacements for Claude Design behind `design-cowork` (see `intent.md`). This slice is findings-only and produces the evidence `P25.S2` ranks from. Every note in `phase.md` tagged `for P25.S1` (and `for P25.S1 and P25.S2`) is binding: the 5-criteria rubric, fixed governance vs the replaceable loop, the hard limits and the evidence rule. Read them first.

## Work

1. **Loop requirements.** Read `.claude/skills/design-cowork/SKILL.md`, only the sections the notes name (§The loop, §The handoff / §The card set, §The design record, §Read back, §The mockup, §Closing the round, §Mechanics). Distil a short requirements list: what the loop needs from a design tool (an input the agent can write, frames/cards the operator can view, a read-back the agent can do, a record that persists across rounds, signoff/regroup mechanics). Mark each item *must* or *nice*. It is the yardstick for step 4.
2. **Reading (a): ocx + `DesignSync`.** Establish how `DesignSync` / Claude Design reaches a Claude Code session: harness-provided tool vs MCP, claude.ai OAuth login vs API key. Establish what `ocx claude` changes: the opencodex proxy at `127.0.0.1:10100` to a Kiro provider, and a nested `claude -p` under ocx reports "Not logged in" (operator memory). Useful sources: `ocx --help` / `ocx claude --help` and ocx config (read-only; **never** change ocx config), Claude Code / Claude Design public docs (WebSearch/WebFetch), and the repo's own records (`grep -rn DesignSync docs/current .claude`). Report a verdict: *verified*, *strongly indicated* or *unverified*, with the evidence. A live probe only if it is cheap and uses no operator account.
3. **Reading (b): Claude Design's intended usage.** From Anthropic's public docs and announcements: the native flow (design in Claude Design → handoff bundle / export → Claude Code builds), how design systems / projects persist, and what `DesignSync` is meant for. Contrast with our loop (repo `handoff.md` in → `DesignSync` read-back → numbered cards → card-group rewrite at signoff). State where ours diverges, citing sources.
4. **Longlist and screen.** Survey widely: self-hostable design canvases (Penpot + MCP, tldraw, Excalidraw, …), code-first component/story galleries (Storybook, Ladle, Histoire, …), repo-native static frames boards (agent-written HTML frames, viewed locally or via Aside), open-source AI design tools and MCP servers, and anything else the survey turns up. Aim for about 10–15 candidates. Screen each against the 5 criteria (pass / fail / unclear, one-line reason, one source) and against the *must* requirements from step 1. Where one cheap probe settles an *unclear* (an MCP's install docs, a `--help`, a scratch `npx` run outside the repo), do it and keep it short. Then pick a **shortlist of 4–6** with a line on why each made it and why each notable near-miss did not.

## Where findings land

- **`result.md`** (verdict block first): the requirements list, both readings with evidence, the full screening table with sources, and the shortlist rationale.
- **`phase.md`** (edit under budget, don't just append):
  - `## Decisions`: two lines on the verified readings, and the shortlist in one compact block.
  - `## Notes for later slices`: consume the S1-only notes; add anything tagged `for P25.S2` (open unknowns per shortlisted candidate, probes worth running).
  - `## Operator Questions`: only if something genuinely needs the operator's choice. Don't invent questions.
  - `## Now`: rewrite it as the handoff to S2, and correct the stale "gate undeclared" line: the gate is now **waived** by the orchestrator.
  - `## Doc impact`: nothing, the phase is findings-only.

## Boundaries

- No edits outside `phase.md` and this slice's `result.md`.
- Scratch probes go under `/private/tmp/claude-502/…/scratchpad` or `$TMPDIR`, never in the repo.
- No account creation and no operator-signed-in browser profile.
- No ranking of the top 3 and no Claude Design recommendation. Those belong to S2.

## Validation

- `python3 scripts/workflow.py validate` exits 0.
- `git status --short` shows only `works/phases/active/P25/` (plus any generated `works/` files).
