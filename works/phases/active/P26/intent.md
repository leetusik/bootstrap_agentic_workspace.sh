# Intent — P26

- Captured at: 2026-09-29T21:07:58+09:00
- Origin: operator

## Original Input (verbatim)

> ocx claude session works just like this one just not logged in. I did full do-whole-phase cycle before. And Here is my thought:
> ---
> 1. even w/o of chat surface. I still prefer web based dashboard and viewer. divided by project(like claude design system). so that I can walk my designs later.
> 2. so, maybe selfhost would be one of option. which service? I can't tell. but we can also build light weight product our own. it would fit to our workflow perfectly. and free customize
> 3. dedicated design subagent will do. for now, consider only claude code integeration

(Given after reading P25's ranked report — 1. repo-native frames board, 2. Storybook + addon-mcp, 3. self-hosted Penpot — and the orchestrator's recommendation; then `/create-phase`.)

## Confirmed Intent (refined + clarified)

Replace the Claude Design loop in `design-cowork` with **design files kept in each product repo**, read by **our own lightweight web dashboard** (built separately, in its own repo), and have a **dedicated design subagent** do the drafting. This phase is the **workspace-machinery half**:

1. **The on-disk design contract** — the layout a product repo uses for its design: projects, rounds (signed and superseded kept, so the operator can walk past designs later), numbered cards, tokens and decisions, all as files in git. This is the one interface the dashboard reads; the dashboard only reads and displays it.
2. **A dedicated design subagent** (a `.claude/agents/` executor) that drafts rounds into that contract, using Anthropic's `frontend-design` plugin only where it helps. Background-dispatchable — nothing main-thread only.
3. **Rewrite `design-cowork` around the files**: retire the `DesignSync` read-back and the SIGNOFF card-group regroup; keep Claude Design only as an **optional import** of a handoff bundle the operator exports from it.
4. **Reword the `CLAUDE.md` hard rule** "never invent visual decisions in an executor" to **"the design subagent drafts, the operator decides"** — signoff stays literal.
5. **A "register this repo" hook** that registers a product repo with the dashboard (the dashboard runs on the operator's Mac and reads the repos from disk).

**Fixed (unchanged):** the three styles (`build-after` / `design-only` / `paired`), rounds, literal signoff, the mockup gate, RESPECT THE DESIGN.

**Scope limits:** Claude Code integration only. **No interim viewer** in this phase — until the dashboard lands, the operator opens card files directly, and no design round is expected before then. The dashboard product itself is **out of scope** (its own repo, bootstrapped with this workspace, a later effort).

**Dashboard facts the contract and hook must fit** (decided now, built elsewhere): a web dashboard grouped by project with a rounds history; served from the operator's Mac on its **Tailscale** IP, reading registered repos straight from disk; **no mobile access** — Tailscale ACLs admit only desktop/laptop devices, and the app also refuses mobile user agents.

## Clarifications Resolved

- Q: Does `ocx claude` break the workflow? — A: "ocx claude session works just like this one just not logged in. I did full do-whole-phase cycle before." Only claude.ai-login features (Claude Design, `DesignSync`) fail there; no ocx live check is owed for anything else.
- Q: Where does the design truth live? — A: In each product repo (files in git; the dashboard only reads them).
- Q: Where does the dashboard run? — A: "tailscale based. no mobile handling required(prohibit mobile access)"; served from this Mac (reads repos from disk); mobile blocked by Tailscale ACLs + an in-app check.
- Q: Where does the dashboard's code live? — A: Its own repo; the bootstrap ships only the contract, the design subagent and the register hook.
- Q: Reword the hard rule to "the design subagent drafts, the operator decides"? — A: Yes, reword it.
- Q: How does the operator view a round before the dashboard ships? — A: Nothing — open card files directly.
- Q: Confirm P26's name and objective? — A: Yes, create P26.

## Notes

- Source: P25 (`works/phases/active/P25/`) — its S2 `result.md` §3 (setup gotchas, the frames-board prototype) and §7 (adoption notes) are inputs; D27 is superseded by this phase.
- This phase changes workspace machinery, not product visual design: no `## Design Style` section.
- Upstream bootstrap repo: machinery edits require `python3 installer/build.py` and the rebuilt installer in the same commit.
- Related open deferred jobs to check at `DECOMP`: D5, D7, D12, D13 (named by P25's review).
