- status: done
- tier: mid
- summary: Cut architecture v0010 folding the 9 P26-P30 notes. Added four sections (Nested Install, Design Record and Design Subagent, Docs Phase Marker and the Rotate Proposal) and merged the rest into Status, Current Repo Shape, Installer Source Tree and Execution Streams. Every superseded statement was replaced.
- version: `docs/versions/architecture/v0010_p26-p30_design_contract_and_drafter_design_tool_choice_nested_install_default_rotate_docs-phase_proposal.md` (previous v0009; `docs/current/architecture.md` rebuilt)
- validation:
  - `python3 scripts/workflow.py docs-debt` (read in full; 9 architecture lines, matching *Cut*): pass
  - `python3 scripts/workflow.py doc-new-version --doc architecture --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "P26-P30 design contract and drafter, design tool choice, nested install default, rotate docs-phase proposal"`: pass, no warning
  - `python3 scripts/workflow.py rebuild-docs`: pass
  - `python3 scripts/workflow.py validate`: pass (`Workflow validation passed.`; the expected `consolidation_owed` / `stale_docs` / `oversized_doc_sections` warnings only)
- deviations: none from `plan.md`. Two edits go past the owed notes; both are in *Contradictions and observations*.
- doc_impact: none (a docs phase leaves no notes)

# P31.S1 result: Architecture, P26-P30 notes

## Which note landed where

| Note | Landed in |
|---|---|
| P26.S1 (five `design-*` commands, `DESIGN_*` block, registry outside the repo) | new `## Design Record and Design Subagent` (*Engine*, *The one engine write outside the repo*); the `scripts/workflow.py` bullet in `## Current Repo Shape` |
| P26.S2 (`design-drafter` agent, not a tier) | `## Design Record and Design Subagent` (*The design subagent*); the `.claude/` bullet in `## Current Repo Shape`; `FIXED_LIVE_FILES` list in `## Installer Source Tree` |
| P27.S3 (two loops, one governance; schema 1 vs `claude-design/`; `design-migrate`, register hint) | `## Design Record and Design Subagent` (opening, *Two record layouts*, *Engine*); the design-tools clause in the `CLAUDE.md` bullet; `## Status` |
| P28.S1 (two roots, marker gate, `host_anchors`, `phase-scope` host read, host-relative printing, parallel off, host provenance) | new `## Nested Install` (*The marker is the switch*, *Two roots in the engine*) |
| P28.S2 (nested layout, engine side vs untracked host side, no CI/`.gitattributes`/`docs/`/`settings.json`, marker rename plus `installed`, `SLICES_GUIDANCE`) | `## Nested Install` (*What a nested install writes*, *The marker is the switch*); `installer/main.py` bullet |
| P28.S3 (rewrite covers seed `executors.toml` and `docs/README.md`; `/update-workspace`, `/retrofit`, `/commit` nested branches; messages not renamed on a clash) | `## Nested Install` (*What a nested install writes*) |
| P28.F1 (self-hiding skill `.gitignore`, `git check-ignore` preflight, refusal text, "stays clean" assert) | `## Nested Install` (*The ignore guarantee*) |
| P29.S1 (nested default, `git init` of a new target, `--at-root`, `--update` layout detection, `--nested` no-op, refusals) | `## Nested Install` (*The default and its flags*); `## Installer Source Tree` (the `installer/main.py` bullet, the byte-identical paragraph, the fresh-install sentence); `## Status` |
| P30.S1 (`consolidates`, typed blockers, `_parallel_branch_merged`, `_debt_only`, `phase_consolidates`, `consolidation_cover`, `next_phase_id`, `_print_docs_phase_proposal`) | new `## Docs Phase Marker and the Rotate Proposal`; one cross-reference sentence at the end of the *consolidation debt* paragraph in `## Execution Streams`; `## Status` |

## Supersession chains applied

- Design loop: stated as P26's file contract and drafter, then P27's per-phase choice; the P26 governance wins where the loops differ.
- Install default: P29's nested default throughout; `--nested` appears only as "a redundant no-op", never as an opt-in.
- Nested marker: `workflow/.agentic-nested.json` only; the earlier `nested.json` name is not mentioned.
- The older "Claude Design + DesignSync" statements are not in architecture v0009, so there was nothing to replace there.

## Section sizes after the edit (record only; no section was split)

Total `docs/current/architecture.md`: 31,141 B (was 23,582 B).

| Section | Bytes |
|---|---|
| `## Status` | 1,477 |
| `## Current Repo Shape` | 3,470 |
| `## Installer Source Tree` | 3,296 |
| `## Nested Install` (new) | 3,198 |
| `## Execution Streams` | 10,202 (was 10,081; still under the 10,240 B warning line) |
| `## Operator Acceptance Gate` | 5,305 (unchanged) |
| `## Design Record and Design Subagent` (new) | 1,723 |
| `## Docs Phase Marker and the Rotate Proposal` (new) | 1,272 |

No architecture section is over the 10 KB warning. The eight sections `validate` warns about are in decisions and operations, which S2 and S4 handle.

## Contradictions and observations

No owed note contradicted existing text in a way the chains do not settle. These points are recorded rather than silently chosen:

1. **Skill count 17 became 18 (outside the notes).** v0009 said "17 skill packages" and `EXPECTED_SKILL_COUNT = 17`. `ls .claude/skills` shows 18, `installer/build.py` and `installer/main.py` set `EXPECTED_SKILL_COUNT = 18`, and CHANGELOG v49 says "the 18 skills". No P26-P30 note names this number, so this is drift from before P26 (`executor-mode` arrived in v45). I corrected both occurrences because I was editing the same bullet and sentence, and leaving a known-false count would break "the doc states the latest truth". If the operator prefers notes-only edits, revert those two numbers.
2. **"Byte-identical across all three install modes" narrowed.** The nested default rewrites paths at install time, so the sentence now covers the at-root build output (`--at-root` / `--into-existing` / `--update`) and points to *Nested Install*. The wording is mine; the notes imply it but do not state it.
3. **"A fresh install produces `CLAUDE.md` + `.claude/`" became "a fresh `--at-root` install".** P29 made the bare install nested, which produces neither tracked.
4. **P28.F1's "on `--update --nested` too" became "on a nested `--update` too".** P29 made `--update` detect the layout and `--nested` a no-op, so the flag no longer appears.
5. **Facts taken from the S2 notes or code, not the S1 notes** (to resolve what the S1 notes leave open; each is a reviewed fact):
   - "parallel worktrees need `--at-root`" is from P29.S2's operations note.
   - The `claude-design/` folder is `DESIGN_LEGACY_DIR` under `docs/reference/design/`, in the pre-v47 layout, per `scripts/workflow.py`.
   - `design-register` is the command that upserts the registry (`design-register` help text).
   - The register hint's deck URL comes from `$AGENTIC_DESIGN_DECK_URL` and is never guessed (the same help text).
   - The helper semantics for `consolidation_cover`, `_debt_only` and `next_phase_id` match the engine docstrings.
6. **A forward reference to decisions.** *Nested Install* says "The install-time rewrite and clash map are pinned in `decisions.md`", which follows the P28.S2 note. That text lands in decisions v0043 (S4, P28's decisions note), so the reference becomes true then. S4 should keep the rewrite and the `wf-<name>` clash map in its P28 entry.

## Dead ends

None. Notes: `docs-debt` and `doc-new-version` ran as planned, and the new version starts as a byte-copy of v0009 plus the new frontmatter.
