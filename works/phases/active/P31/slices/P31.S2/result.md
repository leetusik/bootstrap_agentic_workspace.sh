- status: done
- tier: mid
- summary: Cut operations v0037 folding the 20 P26-P30 operations notes plus D50. The visual-design runbook is rewritten to the two-tool design loop (retitled), the nested-by-default install modes are stated throughout in a new `## Nested personal install` section, P30's rotate proposal is in the docs-phase section, and a filled `## Operator Runtime` (CLI, no browser) now sits beside `## Local Development`.
- version: `docs/versions/operations/v0037_p26-p30_design_loop_runbook_nested_install_default_rotate_docs-phase_proposal_operator_runtime.md` (previous v0036; `docs/current/operations.md` rebuilt)
- validation:
  - `python3 scripts/workflow.py docs-debt` (read in full; 20 operations lines, matching *Cut*): pass
  - `python3 scripts/workflow.py doc-new-version --doc operations --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "P26-P30 design loop runbook, nested install default, rotate docs-phase proposal, Operator Runtime"`: pass; its only warning was the oversized-section hint, ignored per the phase's *No restructuring* decision
  - `python3 scripts/workflow.py rebuild-docs`: pass
  - `python3 scripts/workflow.py validate`: pass (`Workflow validation passed.`; the expected `consolidation_owed` / `stale_docs` / `oversized_doc_sections` warnings only; the oversized count is 8, as before this slice)
- deviations: none from `plan.md`. Six edits go past the owed notes, each named under *Edits beyond the notes* below.
- doc_impact: none (a docs phase leaves no notes)
- D50: paid by this slice. `works/deferred.md` already shows D50 `promoted` to `P31.S2`; the `## Operator Runtime` section in operations v0037 is the deliverable.

# P31.S2 result: Operations, P26-P30 notes and the Operator Runtime section

## Which note landed where

| Note | Landed in |
|---|---|
| P26.S1 (schema-1 record under `docs/reference/design/`, `design.json`, numbered cards, flat round folders, `design-*` commands; own `design/` tree and `output/` retired) | `### The design record` (schema 1 tree, `design.json`, rounds, cards, commands table); the heading and intro of the runbook; `## Status` (v47/v48 paragraph) |
| P26.S2 (`design-drafter` follows `high`, not a tier; the agent list gains it) | `## Executor tiers` (new bullet, and the *Upstream selection* bullet now says three agent files); `## Status`; the `### Install, retrofit, and update behavior` subsection; *Updating* (write policy, post-update tier config); *Adopting* inventory bullet |
| P26.S3 (the file loop: `design-open` + handoff with `new visual direction`, drafter in the background, `design-check` read-back, PENDING #1, literal signoff or superseding round, mockup gate, commit/stop counts, bundle import, no DesignSync/account/push, `design-register` the operator's) | `### Hand off, stop, read back, land — under drafter`; `### Close the round`; the v47/v48 paragraph in the runbook head |
| P26.S4 (routing rules: co-work inline, drafting to the drafter, mockup to `slice-executor-high`, hard rule reworded, `do-*` per-round steps and stop counts, mockup span reads the record on disk, v47 shipped with migration notes) | `## Status` (v47/v48 paragraph and the rewritten "Product visual work" paragraph); runbook intro and the co-work paragraph; `### The runnable mockup` (dispatch bullet); *Updating* (*Coming from a pre-v47 workspace*); *Building* (v47 release bullet) |
| P26.F1 (`design-check` enforces the reference rule exactly; `frontend-design` only on `new visual direction: yes`; revision handoff lists every addressed card) | `### The design record` (*Self-contained* bullet, with the `//`, `http://`, `mailto:`, `tel:`, `javascript:`, `about:` failures); the `handoff.md` bullet in the drafter section |
| P26.F2 (the contract text names `#` fragments; drafter §Do 2 says the same) | `### The design record` (*Self-contained, as the contract text states it*), which states F2's wording and so replaces F1's `#` half |
| P27.S1 (`design-migrate`; register deck hint with `$AGENTIC_DESIGN_DECK_URL`) | `### The design record` (*Migrating a pre-v47 record*, commands table); drafter section (`design-register` bullet) |
| P27.S2 (runbook covers both tools and the `claude-design/` record) | the retitled H2; `### Choose the design tool at intake` (new); `### Hand off, stop, read back, land — under claude-design` (new); `### The design record` (the `claude-design/` layout); `### Close the round` (per-tool close) |
| P27.S3 (v48 upgrade steps) | *Updating*, *Coming from a pre-v48 workspace* (`design-migrate` dry run then `--apply`, `design-init` only for the drafter, `AGENTIC_DESIGN_DECK_URL`, re-sync of copies synced at v47 before P26.F1/F2); *Building* (v48 release bullet) |
| P27.F3 (installer stdin program declares utf-8) | `## Building and releasing the installer` (new bullet, after *Drift guard*); `## Status` |
| P27.F1 (claude-design: feedback routed first, no read-back, no landing) | `### Hand off, stop, read back, land — under claude-design` (*The operator's words are routed first*); `### Close the round` (feedback bullet) |
| P27.F2 (pre-v47 root steered to `design-migrate`) | `### The design record` (*Migrating a pre-v47 record*) |
| P28.S1 (run the engine from the host root as `python3 workflow/scripts/workflow.py`; `nested-convention`; `next` prints `nested_host=` and `host_commit_convention=`; `parallel-*` refuses with its message) | new `## Nested personal install` (*Running it*, *Install modes*); `## Status`; `## Phase worktrees` (opening) |
| P28.S2 (nested install/update runbook, first run, personal skill shadowing) | `## Nested personal install` (*What a nested install writes*, *First run*, *Update*); the `--nested` refusal lines are superseded (see observation 3) |
| P28.S3 (per-ticket runbook; `/update-workspace` nested branch; caveats) | `## Nested personal install` (*One ticket, start to PR*, *First run*, *Update*) |
| P28.F1 (ignore guarantee: per-skill `.gitignore`, `git check-ignore` preflight, refusal text, "stays clean" assert) | `## Nested personal install` (*The ignore guarantee*); `## Status` |
| P29.S1 (nested default, `git init` of a new target, `--at-root`, `--into-existing`, `--force-empty-ok`, `--update` layout detection, `--nested` no-op, refusals) | `## Nested personal install` (*Install modes*); `## Status`; *Adopting into an existing repo* (intro, the `AGENTS.md` caveat, inventory); *Updating* (invoke bullet) |
| P29.S2 (docs present nested as default; `--force-empty-ok` needs `--at-root` incl. `--update`; parallel needs `--at-root`; v50 release) | `## Nested personal install`; `## Phase worktrees` (opening); *Updating* (*Coming from a pre-v49 or pre-v50 workspace*); *Building* (v49/v50 release bullet); `## Status` |
| P30.S1 (proposal block, `--archive-only`, `new-phase --consolidates`, `docs-debt` `paid by:`) | `## Durable-doc consolidation` (*The debt*, *Starting one*, new *`/rotate-backlog` is the default entry point*); `## Phase worktrees` (the "leaves it active" line) |
| P30.S2 (propose-then-confirm skill flow, `archive-only` word, docs-phase route passes `--consolidates`, archive-phase skill text, v51 shipped) | `## Durable-doc consolidation` (same paragraph); `## Status` (v51 paragraph); *Updating* (*Coming from a pre-v51 workspace*); *Building* (v51 release bullet) |

All 20 notes are placed, and no note is unplaced.

## D50: `## Operator Runtime`

Added after `## Local Development`, in the seeded template's order, filled for this repo: run commands (the engine and the built installer, rebuilt by `python3 installer/build.py`), mode (no dev/production split; `build.py --check` keeps the artifact in sync), origin (none, CLI, run in a terminal on the Mac), devices and browsers (none), browser instrument (none; real-browser claims do not apply, verification is live CLI runs), Aside account (n/a), production build (same as the run command), what else is needed (**scratch directories** for mutating commands: `cp -R` copies or `mktemp -d` installs), and the smoke suite (`bash tests/retrofit_smoke.sh`, once, alone, foreground). The section carries no `Status: UNFILLED` line and does not use that word. D50 is paid by this slice.

## Supersession chains applied

- **Design loop:** P26's file loop is the default text; P27's per-phase choice is stated beside it, with the `claude-design/` record, `design-migrate` and its own runbook branch. Where the two differ, P26's governance wins, as the phase decision says. The v31-era statement that "Claude Design plus the operator make every visual decision" and the "DesignSync" heading are replaced (the hard rule is quoted as "the design subagent drafts, the operator decides"). The v34 and v42 history paragraphs stay, with the v42 clause amended to the per-tool mockup commit counts.
- **Install default:** P29's nested default everywhere; P28's opt-in wording survives only as the history sentence in `## Status` ("v49's opt-in `--nested`") and in the v49/v50 release bullet.
- **Nested marker:** only `workflow/.agentic-nested.json`; the earlier `nested.json` name is not mentioned.
- **Self-contained card rule:** F1's engine facts (what `design-check` accepts and refuses) and F2's contract wording are both stated, with F2's text as the rule.
- **Smoke baseline:** not in operations (S3's).

## Section sizes after the edit (record only; no section was split)

Total `docs/current/operations.md`: 165,832 B (was 126,778 B). No section was split. The runbook retitle is the one allowed heading change.

| Section | Before | After |
|---|---|---|
| `## Status` | 15,657 | 19,470 |
| `## Visual-design runbook (two design tools: drafter or Claude Design, since v47/v48)` | 21,161 | 41,296 |
| `## Phase worktrees` | 17,356 | 17,535 |
| `## Updating an adopted workspace to upstream` | 7,178 | 10,234 (just under the 10,240 B warning; I tightened my own wording to stay under) |
| `## Nested personal install` (new) | n/a | 4,738 |
| `## Executor tiers` | 7,055 | 7,700 |
| `## Durable-doc consolidation` | 4,364 | 6,523 |
| `## Building and releasing the installer` | 5,922 | 7,757 |
| `## Operator Runtime` (new) | n/a | 1,911 |

Over the 10 KB warning in operations: Status, the runbook and Phase worktrees (the same three as before; the count of oversized sections in `validate` is 8, unchanged). The runbook roughly doubled because it now carries two loops and two record layouts, and it is the section to split first if the operator ever lifts the no-split rule (D25).

## Edits beyond the notes

These are all small, and each is needed to leave no known-false statement beside a note's edit:

1. **Skill count 17 became 18 in the retrofit inventory bullet**, with "17 at v31" kept and "(18 by v49)" added to the v31 Status paragraph. The count is not in any owed note; it matches architecture v0010 (S1 made the same correction) and CHANGELOG v49.
2. **`## The operator acceptance gate`: "This repository has no such manifest, on purpose" was replaced** by a paragraph saying this repo's manifest records a CLI with no browser. D50 makes the old sentence false.
3. **`## Phase worktrees` gained one sentence** that a nested install has no worktrees (P29.S2's "parallel worktrees need `--at-root`"), plus the "leaves it active" line gains "and proposes the docs phase that pays it".
4. **A new `## Nested personal install` H2.** The notes' candidate homes had no nested runbook section, and the doc never mentioned the nested layout, so a new section is the merge target (as architecture v0010 added `## Nested Install`). It is a new topic, not a split.
5. **`### Install, retrofit, and update behavior` was rewritten** to mention the drafter and `sync-agents` after every update, and to point at the install-mode section.
6. **Mockup bullet:** "the route's path is recorded in the round's record" became "in the slice's `result.md`", because a closed round is immutable under the contract. The plan for a mockup span itself already says `result.md`.

## Observations and contradictions the chains do not settle

No owed note contradicted text in a way the chains leave open. These are recorded rather than silently chosen:

1. **Executor tiers still describes the pre-v46 mid tier (no owed note covers it).** The tier table says `mid` takes "a one-line (or few-line) code edit, or docs" and "escalates the moment the slice turns out to be real code writing, spans more than one file"; the `## Status` v23 sentence says the same. CHANGELOG v46 made `mid` the default tier with real code in scope, and v45 added `executor-mode`. Neither release has an owed note, so operations has no v45 or v46 content, and the Status now jumps from v44 to v47. I left it. This is a candidate deferred job for the review to file (title: bring operations' executor-tier routing and Status up to v45/v46; trigger: the next docs phase).
2. **The brief's "Bring `## Status` up to v51" was read as v47 to v51 only**, for the same reason as observation 1.
3. **P28.S2's "`--nested` is refused with `--into-existing` and `--force-empty-ok`" is not carried.** P29 made `--nested` a redundant no-op and `--force-empty-ok` needs `--at-root`. I did not re-derive whether `--nested --into-existing` still refuses, since CHANGELOG v50 lists only `--at-root` with `--nested`. `installer/main.py` (lines 119-127) shows `--nested` still names the layout when an `--update` target is ambiguous or contradicting, which the doc states as "both found, no flag to choose".
4. **`## Local Development` is left as the empty seed stub.** D50 and the notes cover only `## Operator Runtime`; the engine, test and build commands are in the new section, so a later pass could fill the stub from it. Not a contradiction, only a gap beside the new section.
5. **The P27.REVIEW qa note** (the installer body under system Python 3.9 as a known fragile area) is qa's (S3). Operations carries only the cookie fact, in *Building*.
6. **P29's refusal "a new directory inside another repo's work tree"** is in the decisions note (S4) and CHANGELOG, not in an operations note, so it is not in the install-mode list. S4's P29 entry carries it with its operator-question pointer.

## Dead ends

None. The new version starts as a byte-copy of v0036 plus new frontmatter; every edit was made to that file only, through checked string replacements (each asserted a single match). `docs/index.json`, `docs/current/operations.md` and the new version file are the only doc files changed.
