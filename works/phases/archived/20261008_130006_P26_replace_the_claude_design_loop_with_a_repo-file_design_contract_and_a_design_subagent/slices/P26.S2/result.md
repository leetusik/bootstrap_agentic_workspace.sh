status: done
tier: mid
summary: Added the design subagent `.claude/agents/design-drafter.md`, tracking the high tier through a third entry in `executor_agent_files()` (no new tier), and shipped it through the five places; smoke 195 PASS, build --check, sync-agents --check and validate pass.
files_changed:
- .claude/agents/design-drafter.md (new)
- scripts/workflow.py (`DESIGN_DRAFTER_FOLLOWS`, `executor_agent_files()` third entry and docstring)
- executors.toml (seed comment: the drafter follows `[claude.high]`)
- installer/build.py (`FIXED_LIVE_FILES`)
- installer/main.py (`MANAGED_FILES`, the agent emit loop, the banner's agents line)
- installer/README.md (shipped-files list)
- tests/retrofit_smoke.sh (`DUAL_FIXED` + two probes)
- bootstrap_agentic_workspace.sh (rebuilt)
- works/phases/active/P26/phase.md, works/phases/active/P26/slices/P26.S2/result.md
validation:
- `python3 installer/build.py` passed (wrote the artifact)
- `bash tests/retrofit_smoke.sh` (own foreground call, 600 s timeout): ALL RETROFIT SMOKE TESTS PASSED, 195 PASS / 0 FAIL (192 before: +1 fresh-install probe, +1 economy probe, +1 dual-apply for the new file)
- `python3 installer/build.py --check` OK (re-run after the smoke)
- `python3 scripts/workflow.py sync-agents --check` reports "agent files in sync"
- `python3 scripts/workflow.py validate` passed (only the pre-existing oversized-doc-sections warning)
deviations: none
doc_impact:
- architecture.md: the third managed agent file, design-drafter, shipped like the executors and kept on the high tier by `sync-agents`; not a tier (P26.S2)
- operations.md: Executor tiers section and the `.claude/agents/` list gain the drafter, which follows `[claude.high]` (P26.S2)
- qa.md: smoke baseline 195 PASS (P26.S2)

## What was done

1. **The agent file.** `.claude/agents/design-drafter.md`: `name: design-drafter`, `tools: Read, Edit, Write, Glob, Grep, Bash, Skill`, `model: opus` / `effort: xhigh` (what `sync-agents` writes for high in the seeded flex mode), `permissionMode: bypassPermissions` copied from the executors. The `description:` has no `: `. The body is in the executors' voice and covers the eight pinned points:
   - role (one round, background dispatch, no commits or state transitions, "the design subagent drafts, the operator decides");
   - inputs (round folder and slice id from the dispatch prompt; `handoff.md`, `design.json`, `tokens.css`, existing cards, prior rounds' `SIGNOFF.md` / `feedback.md` / `result.md`; `import/` read as data);
   - writes (numbered card paths with the line-1 `@dsCard` marker carrying `⏳ <slice> · <Group>`, self-contained cards with only `../tokens.css` relative, `tokens.css` when the system changes, `result.md` with every departure, `build-prompt.md`);
   - grounding and RESPECT THE DESIGN for signed rounds;
   - `frontend-design` via `Skill` only on new-direction rounds (first round, redesign, new brand or surface family), never on rounds that extend a system;
   - the "Never" list (no `SIGNOFF.md`, no `design-open` / `design-close` / `design-register`, no edits to `round.json`, `design.json`, `handoff.md`, `feedback.md`, closed rounds or anything outside `docs/reference/design/`, no commits, no mockup, no `DesignSync` or web);
   - `design-check <the handoff's paths>` before returning, `done` only on exit 0, with an optional throwaway headless screenshot (never the operator's profile; Aside only with the agent account id from `## Operator Runtime`);
   - the structured verdict (`status`, `round`, `cards_written`, `tokens_changed`, `frontend_design`, `departures`, `design_check`, `open_questions`, plus `blocker`).
2. **Model source: the high tier, via `sync-agents`.** `scripts/workflow.py` gained `DESIGN_DRAFTER_FOLLOWS = "high"` and `executor_agent_files()` now returns three entries (the two `slice-executor-{tier}` files, plus label `design-drafter` mapped to `config["high"]`'s model and effort); the docstring is updated. `EXECUTOR_TIERS`, `executors.toml` tables and the presets are untouched.
   - **Third file handling, checked:** `executor_agent_drift()`, `sync_agents()` (`--check` and write), the `executor-mode` status line and `validate`'s advisory warning all call `executor_agent_files()`, so they cover the third file with no other change. I proved it by temporarily setting the drafter's `model:` to `sonnet`: `sync-agents --check` exited 1 naming `.claude/agents/design-drafter.md`, `validate` warned, `executor-mode` printed "agent files: out of sync: .claude/agents/design-drafter.md". I restored the file byte-identically and re-checked in sync. The unused first tuple field ("tier") is not read by any caller.
   - The `executors.toml` seed comment now says the drafter is not a tier and follows `[claude.high]`. The installer embeds the live `executors.toml`, so nothing else changed there.
3. **Shipping, all five places:** `installer/build.py` `FIXED_LIVE_FILES`; `installer/main.py` `MANAGED_FILES`, the agent emit loop (one extra `write_text` for the drafter) and the banner's agents line (now names the design subagent; the "Visual design" line is untouched, S4's); smoke `DUAL_FIXED`. I also updated `installer/README.md`'s shipped-files list (one line), which the plan did not list. `grep` over the smoke suite found no pin on the banner text or the agent set beyond the sites already covered, so no existing pin needed changing.
4. **Smoke, two probes plus the dual-apply line.**
   - Test 5, fresh install: the drafter file exists, `tools:` includes `Skill`, and `tools:` has no `DesignSync`.
   - Test 5, after `executor-mode economy`: the drafter's `model:` and `effort:` equal `slice-executor-high`'s, and the effort is `high`.
   - Test 6: `.claude/agents/design-drafter.md` in `DUAL_FIXED` (the cross-check against `FIXED_LIVE_FILES` requires it).

## Notes

- The plan's note that `--update` resets agent files to upstream defaults also applies to the drafter; I left this for S4's CHANGELOG migration line (a note in `phase.md` for S4).
- The `Skill` tool grep in the smoke uses `grep -Eq '^tools: (.*, )?Skill(,.*)?$'` rather than `\b`, since BSD grep on macOS does not reliably support `\b`.
- Phase notebook: `## Decisions` gained the design-subagent entry and the footprint bullets were brought current; `## Doc impact` gained three lines; both S2 notes were consumed and replaced by a dispatch note for S3 and a migration note for S4; `## Now` was rewritten. Nothing was left in `## Operator Questions` by this slice.
- Nothing was committed and no status was changed.
