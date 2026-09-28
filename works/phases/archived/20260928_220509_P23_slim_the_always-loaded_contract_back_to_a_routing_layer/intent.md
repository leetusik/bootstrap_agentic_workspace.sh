# Intent — P23

- Captured at: 2026-09-28T03:26:50+09:00
- Origin: operator

## Original Input (verbatim)

> good. /commit and /create-phase for the task.

(Sent mid-turn, verbatim: "and maybe autocompact to 500k explicit would be helpful." Clarification answers, verbatim option picks: scope = "Aim for ≤ 12 KB (Recommended)"; autocompact = "Set 500k on this machine (Recommended)".)

"The task" is the `/doctor` finding (2026-09-28, checks 3 and 4) that the operator's "good" accepted: `CLAUDE.md` is 49,646 chars (~12.4k est. tokens). That is over Claude Code 2.1.283's per-file instruction warning floor (`max(40,000, 5% of the context window)` chars, so 40k on a 200K window), and the file loads into every session and every slice-executor dispatch.

## Confirmed Intent (refined + clarified)

Slim `CLAUDE.md` from 49,646 chars toward D8's ≤ 12 KB target, so it works again as the compact routing contract its own first line says it is. No load-bearing rule may be lost in the process.

1. **Research first.** Before cutting anything, map each rule to the reader who needs it. That reader is the orchestrator (main thread), the executor (`slice-executor-*`), or the skill that already owns the operation. What's known so far: `do-whole-phase`, `do-next-slice`, `create-phase`, `review-phase`, `parallel-phase` and `design-cowork` each restate large parts of the Hard Rules. The two executor files are 27.5k chars each. Executors can't invoke skills, and every dispatch loads `CLAUDE.md` (164 of 164 executor transcripts checked).
2. **Cut what the code already says.** `## Workflow Commands` (`CLAUDE.md:90-116`, ~4.6k chars) restates `workflow.py --help`. Four of its bullets carry smoke-pinned phrases (`--kind` closed set, `finish-slice --outcome`, `phase-scope`), and those pins get re-homed rather than lost.
3. **Move skill-owned detail to the file that owns it.** Candidates: worktrees (`:78`, 4.4k chars) → `parallel-phase`; design (`:79`, 3.8k) and Aside (`:76`, 3.3k) → `design-cowork`; acceptance gate and review boundary (`:74`, `:77`, ~4k) → `review-phase`. Anything an executor needs goes to the executor files, or stays in the contract, never into a skill.
4. **Keep every "never" rule in the contract.** Each moved bullet leaves its prohibition core behind: never push, never patch `docs/versions/`, never hand-edit generated files, confirmation gates, operator-only commands, the dedicated-browser-profile rule, and the like.
5. **Ship it as a workspace release.** Re-point the `tests/retrofit_smoke.sh` pins (60 exact phrases, 49 of them in Hard Rules) to wherever each rule lands. Rebuild with `installer/build.py` in the same commit, bump `WORKSPACE_VERSION`, and add a CHANGELOG entry. Adopters get it through `/update-workspace`.

**Scope boundary:** machinery and doctrine in this repo only. Adopting repos are read as evidence and are never edited from here. The executor files may take on moved rules, but must not grow by more than the contract shrinks, because both load on every dispatch. Pays D8, which was filed by P18 and whose reason P21.REVIEW refreshed.

## Clarifications Resolved

- Q: Target scope: D8's ≤ 12 KB, or just under the 40k-char warning floor? — A: **≤ 12 KB**, in one editorial pass, with a research slice first. D8 closes with the phase.
- Q: Where does the explicit 500k auto-compact window go? — A: **This machine only, not the phase.** Done 2026-09-28: `~/.claude/settings.json` `autoCompactWindow` 450000 → 500000, which covers subscription sessions. ocx already had `claudeCode.autoCompactWindow = 500000` (last modified 02:29 KST) and injects it as `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, which overrides the setting, starting with the next `ocx claude` launch. The ocx session running at creation time still carries 829,800, ocx's default. Nothing ships to adopters.

## Notes

- Source material: `works/deferred/open/D8/deferred.json`; P21's contract-size measurement (`works/phases/active/P21/slices/P21.S1/result.md` §6, the size table at `:478-488`: contract + executor file ≈ 16.3k tokens per dispatch, up 5x in two months; P21.REVIEW routed OQ2 to D8). The binary constants behind the warning are in 2.1.283's `VGe()`: `wEn = 40000`, `bEn = 0.05`, and `DFe = 200000` as the fallback window.
- Size budget to beat: `CLAUDE.md` 49,646 chars (Hard Rules 32,090; Driving 6,781; Workflow Commands 4,611; Canonical State 2,397; Commit Convention 1,781).
- Pin map: `tests/retrofit_smoke.sh:370-423` asserts 60 phrases. By section: Hard Rules 49, Workflow Commands 4, Canonical State 3, Driving 2, Read Order 2. The densest lines are `:76` (Aside, 11 pins), `:79` (design, 8), `:59` and `:78` (5 each).
- Retrofit (`installer/main.py` `_merge_contract`): when an adopter already has its own `CLAUDE.md`, the full contract goes to a `CLAUDE.workspace.md` sidecar, and only a marked pointer block (`<!-- BEGIN agentic-workspace -->`) is appended to their file. A shorter contract therefore shrinks the sidecar and leaves the pointer alone. Smoke Tests 1–2 cover this (non-destructive and idempotent).
- This is not a docs phase. P21/P22 `consolidation_owed` stays open, and this phase adds its own `## Doc impact` notes (architecture/operations sections that describe the contract).
- Workspace version: v43 is the latest release (v44 was reverted in `c7f5dbb`), so this phase opens v44.
