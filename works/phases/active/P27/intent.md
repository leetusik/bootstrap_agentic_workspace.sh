# Intent — P27

- Captured at: 2026-09-30T02:45:51+09:00
- Origin: operator

## Original Input (verbatim)

> design deck done. btw, make the two choiceable. design deck or orginal claude design cowork. and look up design deck. if any change needed on this or the deck side, you name it

## Confirmed Intent (refined + clarified)

Make the design tool a per-phase choice between the P26 loop (repo design files + the `design-drafter`, viewed in design-deck) and the original Claude Design co-work loop that P26 removed. Shipped as workspace **v48**.

1. **The choice.** `/create-phase` asks it together with the style and mockup questions and records a `Design tool: drafter | claude-design` line under `## Design Style`; an absent line reads as `drafter`.
2. **`design-cowork` carries both loops.**
   - `drafter`: the P26 loop, unchanged, visible in design-deck.
   - `claude-design`: the original loop restored as it was before P26. That means Connect GitHub and the design-slice push, PENDING while the operator designs in Claude Design, the DesignSync read-back, the remote regroup, and the DesignSync mechanics and Never lines, all run on the main thread. `DesignSync` goes back into the skill's `allowed-tools`. **Nothing is copied into the repo:** cards stay in Claude Design, and design-deck shows nothing for these rounds (design-deck is separate from Claude Design rounds).
3. **Where the records live.** A `claude-design` round keeps the original record layout (`rounds/NN-slug/{handoff.md, output/{result.md, build-prompt.md}}`, `SIGNOFF.md`, `grounding/`) under `docs/reference/design/claude-design/`. `design-check`, the other `design-*` commands and design-deck skip that folder, so both loops can coexist in one repo across phases.
4. **Contract wording.** The design lines in `CLAUDE.md`, the co-work refusal and mockup clauses in both slice executors, the `do-next-slice` and `do-whole-phase` PENDING #1 wording, both READMEs and the retrofit guide name the partner for either tool. The smoke pins that assert the old loop's absence (`tests/retrofit_smoke.sh`) are relaxed so they check the choice instead.
5. **Legacy migration.** Repos with the pre-P26 layout (for example changple5, vocky, Mijual, arb_upbit_1, navercafecollector, changple_web) currently fail `design-check`. `design-open` refuses them, and `design-register` still accepts them. Give them a documented migration, or a command: move the legacy `rounds/`, `SIGNOFF.md` and `grounding/` into `docs/reference/design/claude-design/` unchanged, and run `design-init` only if the repo will later use the drafter.
6. **`design-register` hint.** On success it prints the design-deck URL, and notes that the deck only sees repos under its mounted projects folder (default `~/projects`).
7. **v48 + re-sync note.** Bump `WORKSPACE_VERSION` to 48 and add a CHANGELOG entry with a migration note. Say that downstream copies synced at v47 (design-deck among them) are missing P26.F1/F2: the drafter's `new visual direction` licence, `#` fragments, and the stricter `design-check` reference scan. Rebuild `bootstrap_agentic_workspace.sh`.

**Out of scope:** the design-deck repo's own changes: re-sync to v48, documenting `design-init` → `design-register` in the README, the "superseded by" label, the `feedback.md`/`SIGNOFF` visibility question, `~` expansion in the registry path. They go in a design-deck phase in that repo, only when the operator asks. Also out of scope: `design-check --root`, schema 2 (D29), and copying Claude Design cards to disk.

## Clarifications Resolved

- Q: Should Claude Design rounds be saved to the repo so design-deck can show them? — A: "design-deck is seperate thing from claude design rounds" → no copying; pure original loop.
- Q: Where is the design tool chosen? — A: Per phase at /create-phase.
- Q: Which extra fixes go into P27? — A: Legacy migration, v48 bump + re-sync note, register prints deck hint (not `design-check --root`).
- Q: Claude Design records under `docs/reference/design/claude-design/` in the original layout, skipped by `design-*` and the deck, with legacy repos migrated by moving their old records there? — A: confirmed ("go").

## Notes

- This is workspace machinery, not product visual design: no `## Design Style` section for this phase.
- The audit findings behind this phase are in this session's report. The original loop's text is recoverable from `git show 7ecd381^:.claude/skills/design-cowork/SKILL.md` (639 lines). P26's commits: 7ecd381, 48a20ee, 4eaabc8, f21129d, plus fixes b84eb1e and 22b3acb.
- Constraint carried by the `claude-design` mode: DesignSync needs a claude.ai login, fails under `ocx claude`, and cannot run in a subagent. That was the reason P26 removed it (CHANGELOG v47).
