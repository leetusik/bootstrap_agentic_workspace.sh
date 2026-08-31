# Intent — P19

- Captured at: 2026-08-29T16:18:53+09:00
- Origin: operator

## Original Input (verbatim)

> well then we gonna make a research kind of slice too.
> ---
> 1. make research slice. a decomp2 slice follows usually.
> 2. make qa run with the "aside"
> --
> /create-phase for the task. limit the slice num 4. include decomp and review.

Preceding operator message in the same exchange, relaying another agent and setting the
context this request answers:

> from changple5 agent: "Since research is no longer a valid slice kind, I'll cut the research
> slices as --kind qa instead. I'll wait for the Explore brief before writing the plan. · summarized"..

## Confirmed Intent (refined + clarified)

Two independent changes to slice-kind semantics, shipped together as workspace **v36**.

**1. A `research` slice kind.** Add `research` to the closed `SLICE_KINDS` set in
`scripts/workflow.py` (it currently holds `implementation`, `review`, `decomposition`, `fix`,
`docs`, `qa`, `co-work`). Its shape:

- **Findings-only.** A research slice writes no product code. Its product is what was learned.
- **Always `slice-executor-high`**, like `decomposition` and `review` — `risk` does not route this
  kind. Research decides what gets cut next, so a weak read is expensive.
- **Findings land in `phase.md`.** The executor's context dies with the slice, so the notebook is
  what survives; `result.md` keeps the log (dead ends, commands, the detail) as always.
- **A `DECOMP2` slice normally follows it**, re-cutting the remaining work from what was learned.
  This **generalizes the second decomposition pass**: `DECOMP2` exists today only inside the
  `build-after` design style, and after this phase it is also the ordinary answer to "we had to
  learn something before we could cut the rest."

This partly reverses the position taken earlier in the same conversation (that investigation
belongs inside `DECOMP` or the orchestrator's planning step, and that a research slice pays a
dispatch cycle to hand back a lossy summary). The operator overruled it. The one part of that
argument that survives as a requirement, not an objection, is the notebook rule above: research is
only worth a slice if `DECOMP2` can genuinely re-cut from what lands in `phase.md`.

The immediate trigger: an agent, told `research` was not a valid kind, planned to cut its research
slices as `--kind qa` — a slice that reads as one thing and is another, the exact failure P17 closed
the enum to prevent. Making the kind real is the fix.

**2. `qa` runs with Aside.** Make **Aside** — the local-first Chromium AI browser
(https://aside.com, YC F25), whose developer surface is a **CLI**, an **MCP server**, and a
Playwright-like **REPL** (`page`, tabs, locators, screenshots, downloads, JS) — the workspace's
prescribed instrument for real-browser verification, **in place of scripted Playwright-style
automation**. It covers the functional sweep specified in `design-cowork`'s *Verifying* section, the
fidelity slices, and the review's own walk of the running product on a gated phase.

This is the instrument the existing qa doctrine (`docs/current/qa.md`, *Verification doctrine*,
since v32) was already asking for and could not name: that doctrine exists because two build phases
and thirty slices with a **scripted** real-browser fidelity slice at the end of each both passed,
and the product owner then found eleven user-visible failures. Its demands — "type into it and
wait", "watch a timer tick for a real interval", catching "the browser defaults the record never
drew" — are agentic browsing, not assertion scripts.

**The operator-runtime rule is untouched.** Aside drives the runtime and access path recorded in
`## Operator Runtime` (the operations doc); it never substitutes a runtime of its own. An absent or
`UNFILLED` manifest still stops the slice `pending` exactly as it does today.

## Clarifications Resolved

- Q: "Make qa run with the 'aside'" — what does *aside* mean here? — A: "you fucking find yourself
  its substitue of playwirght or some shit." Resolved by web research: **Aside** (https://aside.com),
  a local-first Chromium AI browser from a Y Combinator F25 startup, with a CLI, MCP server, and
  browser-automation REPL for developers (https://docs.aside.com/help/developers,
  https://aside.com/blog/developers). Confirmed by the operator.
- Q: How should a `research` slice route to an executor tier? — A: **Always high.** Like
  decomposition and review; `risk` does not route this kind.
- Q (assumption, confirmed): Does Aside **replace** the scripted approach as the default instrument,
  or join it as one option among several? — A: Replace.
- Q (assumption, confirmed): Is `research` a kind, not a tier bypass — still a dispatched executor
  writing `result.md` and editing the notebook? — A: Yes.

## Notes

- **Slice budget: 4 total, set by the operator** — `P19.DECOMP`, **two** middle slices, `P19.REVIEW`.
  Which two is `DECOMP`'s call. Note this phase carries no `DECOMP2` of its own; the cap forbids it.
- **Aside is not installed in this workspace**, and which surface an executor should reach it by
  (CLI / MCP / REPL) is unknown. That is precisely a `research`-slice question, so this phase can eat
  its own dogfood — but the 4-slice cap means `DECOMP` must decide whether it can afford to.
- **Upstream bootstrap repo.** Both changes touch embedded machinery (`scripts/workflow.py`,
  `.claude/*`, docs), so every slice that edits one must run `python3 installer/build.py` and commit
  the rebuilt `bootstrap_agentic_workspace.sh` in the same commit; `--check` is enforced by the
  pre-commit hook.
- **Version:** ships as workspace **v36** (v35 is current). `CHANGELOG.md` needs its entry.
- **Not a visual-design phase** — no `## Design Style` section, deliberately.
