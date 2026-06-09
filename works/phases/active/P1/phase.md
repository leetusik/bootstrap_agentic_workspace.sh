# Phase P1: User-Facing README & Onboarding Guide

## Objective

Create a user-friendly root README.md that makes this workspace approachable to newcomers. It should: (1) explain what the project is and the problem it solves; (2) show how to bootstrap a workspace by running bootstrap_agentic_workspace.sh, with prerequisites and what gets created; (3) cover how to get started and use it day-to-day — the phase/slice workflow, scripts/workflow.py, and the Claude Code / Codex skills; (4) explain how to contribute; (5) include a FEATURED, opinionated 'how to work with coding agents' methodology section sharing the operator's approach; and (6) add a 'Related / inspired by' see-also section linking similar projects such as oh-my-claude-code, oh-my-zsh-style frameworks, and Claude Code skills/plugins. Keep docs/current/*.md and CLAUDE.md as the source of truth and link to them rather than duplicating.

## Context

First real task for this workspace, replacing the bootstrap placeholder. Use `P1.DECOMP` to break the README into concrete implementation slices before writing.

## Decomposition

Two implementation slices (recorded by `P1.DECOMP`):

- **P1.S1 — Core README** (order 10): overview & problem solved; quickstart/bootstrap (`bootstrap_agentic_workspace.sh`, prereq `python3 >= 3.8`, flags `--name`/`--summary`/`--phase-name`/`--phase-objective`/`--force-empty-ok`, what gets created); day-to-day usage (phase/slice model, `scripts/workflow.py`, the 10 cross-tool Agent Skills, read order); contributing; project-structure tree. Links CLAUDE.md/AGENTS.md/docs as source of truth.
- **P1.S2 — Methodology & related projects** (order 20, depends_on P1.S1): the FEATURED, agent-authored "How to work with coding agents" methodology; the "Related / inspired by" see-also section (shortlist below); a one-line positioning lead-in.

Order: P1.DECOMP (0) → P1.S1 (10) → P1.S2 (20) → P1.REVIEW (9999).

## Findings & Notes

**Decisions (operator):** research the ecosystem before decomposing; two slices; methodology fully agent-authored from the repo's design + best practices; related section = see-also links + a light positioning lead-in. Decomposition records findings/notes here in `phase.md`; each slice fills its own `plan.md` when it runs and appends notes back here.

**Verified related-projects shortlist (deep research — for P1.S2):**

- Workflow / spec-driven: GitHub Spec Kit — https://github.com/github/spec-kit
- Cross-tool skills: wshobson/agents — https://github.com/wshobson/agents
- oh-my-X lineage: oh-my-claudecode — https://github.com/Yeachan-Heo/oh-my-claudecode · claude-forge — https://github.com/sangrokjung/claude-forge · oh-my-openagent — https://github.com/code-yeongyu/oh-my-opencode · oh-my-customcode — https://github.com/baekenough/oh-my-customcode · oh-my-zsh — https://github.com/ohmyzsh/ohmyzsh
- Subagent/config kits: VoltAgent/awesome-claude-code-subagents — https://github.com/VoltAgent/awesome-claude-code-subagents · dotclaude — https://github.com/poshan0126/dotclaude · centminmod/my-claude-code-setup — https://github.com/centminmod/my-claude-code-setup

**Positioning:** four traits (persisted phase/slice/deferred state machine; versioned durable docs; parallel cross-tool `.claude/skills` + `.agents/skills`; single bootstrap script) appear separately across the surveyed projects but are bundled in none.

**Caveats (heed when writing P1.S2):** star counts are a 2026-06-09/10 snapshot — cite cautiously or omit; use the new name "oh-my-openagent" (oh-my-opencode URL redirects); do NOT repeat refuted claims (OMC isn't a persisted phase/slice system; oh-my-customcode isn't genuinely cross-tool — name lineage only; don't cite exact bundle inventories for dotclaude/centminmod); "closest/distinct" are editorial positioning, not verified facts.

## Cross-Slice Notes

**From P1.S1 (Core README) → for P1.S2.** The root `README.md` core is written; structure is locked.
P1.S2 only needs to insert two sections and two TOC entries:

- **Insertion anchor for the two sections:** the HTML comment
  `<!-- P1.S2 inserts "How I work with coding agents" + "Related / inspired by" here -->`, which sits
  between the "Project structure" section and the "Contributing" section. Replace that comment with
  the two sections (methodology first, then related).
- **Use these exact headings** so the TOC anchors resolve:
  `## ⭐ How I work with coding agents` and `## Related / inspired by`.
- **Add two TOC entries** between the `Project structure` and `Contributing` lines in the Contents
  list:
  `- [How I work with coding agents](#-how-i-work-with-coding-agents)` (leading hyphen in the anchor
  is correct — GitHub drops the ⭐ but keeps the space) and
  `- [Related / inspired by](#related--inspired-by)` (double hyphen from " / ").
- **Methodology:** first-person operator voice, ~5–7 punchy principles (each 2–3 sentences), link to
  `CLAUDE.md` for mechanics. Seed principles are in `slices/P1.S1`'s sibling plan / the approved
  workflow plan.
- **Related:** omit star counts; use the name **oh-my-openagent**; group the links; label the
  positioning lead-in as editorial; do **not** repeat the refuted claims noted above.
- README facts already verified by P1.S1: bootstrap flags match `--help`; `origin/HEAD` is `main`
  (raw `curl` URL is valid); all internal relative links resolve. P1.S2 should keep new links valid.

## Constraints

- Keep `works/backlog.md` lean.
- Store detailed slice context inside each slice folder.
- Create new doc versions for durable doc changes.
- Record the review with `review-phase`; phases stay in `active/` after passing and are archived together with `archive-all` once every active phase is done.

## Open Questions

-
