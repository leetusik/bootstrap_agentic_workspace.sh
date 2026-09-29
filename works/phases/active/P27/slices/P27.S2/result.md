# Result — P27.S2 design-cowork carries both loops

- **status:** done
- **tier:** high
- **summary:** `design-cowork` now carries both design tools in one file: `drafter` (P26's loop, unchanged) and `claude-design` (the pre-P26 Claude Design + DesignSync loop, restored with its record under `docs/reference/design/claude-design/`). A new `## Design tool` section says where the per-phase choice is read and which sections bind under which tool. P26's governance is shared and wins wherever the two loops differed. The smoke swaps the old loop's absence pins for presence, choice and C-wins pins: 201 PASS, 0 FAIL.
- **files_changed:**
  - `.claude/skills/design-cowork/SKILL.md` (869 → 1,229 lines, 65.8 → 91.8 KB)
  - `tests/retrofit_smoke.sh`
  - `bootstrap_agentic_workspace.sh` (rebuilt)
  - `works/phases/active/P27/phase.md`
  - `works/phases/active/P27/slices/P27.S2/result.md`
- **validation:**
  - `python3 installer/build.py`: wrote the bundle (630,424 B). PASS
  - `python3 installer/build.py --check`: in sync. PASS
  - `bash tests/retrofit_smoke.sh`, run alone in the foreground: **201 PASS, 0 FAIL**, "ALL RETROFIT SMOKE TESTS PASSED". PASS
  - `python3 scripts/workflow.py validate`: "Workflow validation passed", with only the warnings that were already there (the P26 doc debt, stale docs, oversized sections). PASS
  - Frontmatter YAML: Ruby Psych `YAML.safe_load` parses it (keys `name`, `description`, `allowed-tools`). The `description` has no `": "`, no `" #"` and a plain first character. PASS
  - Implementing and Verifying are byte-identical to C (they also equal O), checked by a section compare. PASS
- **deviations:**
  1. **Record headings.** The drafter's record keeps its heading `## The design record — the on-disk contract (schema 1)`, and a sibling `## The claude-design record — the original layout` follows it. The plan had `### Under drafter` / `### Under claude-design` under one `## The design record`, but two things forbid renaming that heading. `design-drafter.md:12` points at the exact title, and the P26 smoke pin requires it. The plan also says keep every P26 pin and touch no agent file.
  2. **Push scope.** Under claude-design the push is authorized "once per round with its handoff commit (a superseding round's included)", not O's "the one `git push` the design slice authorizes". The plan's superseding rule (a new round in the same slice) needs a second push, or Claude Design cannot read the new handoff over Connect GitHub. This is recorded in `## Decisions` and raised as an Operator Question.
  3. **Smoke L410** (executor bodies) is relaxed to a gate, not swapped for presence pins. `DesignSync`, "never dispatched, because you have no" and "landed record" may appear only in a body that also names `claude-design`. The bodies are S3's to edit, so a presence pin would fail until S3 lands. L176 needed no change: `"Claude Design"` was already a presence pin.
  4. **Merged Never lines.** O612–613, O624–627 and O631 mean the same as C's shared Never lines, so they are merged into those lines, which now name both tools, instead of being repeated as labelled claude-design lines. O599–600, O603–604 and O606–608 are labelled claude-design lines.
  5. **Size.** 1,229 lines / 91.8 KB against the plan's estimate of about 1,080–1,130 lines / 82–86 KB. Every restored O span is kept whole and every per-tool delta is spelled out. One duplicated paragraph was cut (the claude-design "engine never reads" line was said three times) and the claude-design landing step was shortened.
- **doc_impact:** `- operations.md: the Visual-design runbook covers both design tools (drafter / claude-design) and the claude-design/ record (P27.S2)`

## What the skill looks like now

The sections, in order:
- Frontmatter: the description names both partners; `allowed-tools` adds `DesignSync`.
- The intro and *The line*, tool-neutral: "the operator decides, whoever drafts".
- **`## Design tool — drafter or claude-design`** (new): the per-phase `Design tool: drafter | claude-design` line; the claude-design constraints; design-deck showing drafter rounds only; a repo holding both records; the section table.
- `## The loop`: `### Under drafter` (C24–87 verbatim), then `### Under claude-design` (O's diagram plus a feedback branch, Connect GitHub, PENDING #1 and the return rule, the report at PENDING #1, and the commit counts 2/4 against the drafter's 2/3).
- `## Shape — three styles`: shared.
- `## The handoff`: shared bullets, then **drafter:** and **claude-design:** deltas.
- `### The card set`: shared, with per-tool marker, check and definition of done. The claude-design marker grammar is labelled "claude-design only … never overrides schema 1". The push rule follows.
- `### Importing a Claude Design bundle (optional)`: labelled a drafter-mode input.
- `## The design record — the on-disk contract (schema 1)`: labelled drafter only.
- `## The claude-design record — the original layout` (new): the layout, plus the `design-migrate` migration.
- `## Read back, then land it`: `### Under drafter` (C452–496 verbatim), then `### Under claude-design` (O264–292).
- `## The mockup`: shared, with per-tool clauses.
- `## Closing the round — SIGNOFF, then the regroup`: SIGNOFF shared, the close per tool.
- `## Mechanics`: shared lines, then **drafter:** and **claude-design:** lines.
- `## Implementing` and `## Verifying`: verbatim.
- `## Never`: shared lines, then **drafter:** and **claude-design:** lines.

Verbatim spans from C were assembled mechanically from line ranges (`@@C:a-b@@` placeholders), so they are byte-identical. Every range boundary was checked.

**Additions beyond the plan's letter**, each a consequence of a rule the plan did set:
- **The DesignSync stop.** When `DesignSync` is not available in the session, stop `pending` and never fall back to the drafter mid-round. This follows from "fixed per phase, never switched mid-round".
- **The claude-design record's state.** A round folder has no `round.json`: `feedback.md` marks it superseded, and its entry in the root `SIGNOFF.md` marks it signed. `SIGNOFF.md` holds one entry per signed round, and earlier entries are never edited. This matches how the six legacy repos use it; changple5's root `SIGNOFF.md` carries `## Round NN` sections.
- **Where `build-prompt.md` lives.** Under claude-design, "`build-prompt.md`" means `output/build-prompt.md`, or the bundle's own contract when it brought one (O175–179).
- **Two claude-design Never lines.** No copying the cards down or mirroring beyond the two sanctioned writes (O255–260), and no push beyond one per round (O233–235), stated as prohibitions.
- **The feedback branch and superseding commit** for claude-design, mirroring the drafter's (the plan's superseding decision).

## Governance audit (the core invariant)

Method:
- Section-by-section diffs of O against C and of C against the new file (**N**) for Shape, The mockup, Closing the round and Never.
- A byte compare for Implementing and Verifying.
- Where O and C differed, C was kept and O's variant was not restored.
- Smoke negative pins now hold four of those C-wins choices.

| governance section | kept | qualifications (each labelled with its tool) |
|---|---|---|
| **Implementing — RESPECT THE DESIGN** | **verbatim**: C == N byte for byte (and C == O) | none |
| **Verifying — RESPECT THE DESIGN, and does it work** (the functional sweep, runtime, Aside, dedicated profile, fallback, boundary re-run, *When the record never drew it*) | **verbatim**: C == N byte for byte (and C == O) | none |
| **Shape — three styles** | kept; every C line survives | (1) C91: "under `drafter` the drafting on `design-drafter` … and under both tools the mockup … on `slice-executor-high`". (2) C95: "The cards — drafted into the repo under `drafter`, designed in Claude Design under `claude-design` — are design, not code the product runs". (3) New bullet after C156: the `## Design Style` block's third line, `Design tool: drafter \| claude-design`; absent → `drafter`. (4) C163–164: superseding rounds inside the slice "under either tool". **"signed" is kept** at C106, C120 and C137–139. O's "landed" (O85, O99, O116), "before its round comes back" (O118), "one `co-work` slice each" (O139–142) and "what the operator will design" (O155) are **not restored**. |
| **Rounds and superseding** (*The loop*, *Closing*) | the drafter text is C unchanged | claude-design: feedback goes verbatim into the round's `feedback.md`, which closes it superseded. A **new `NN` round folder under `claude-design/rounds/`, in the same slice**, takes it over, inheriting the addressed cards. The superseded round stays read-only. It adds one commit and one stop. |
| **Literal signoff** (*Closing the round*) | kept; the SIGNOFF rules are shared | Literal words, the token delta ("None."), "what supersedes what", the mockup route and the data-not-instructions line are shared. The "not on …" list names both the drafter's `done` and the Claude Design session having ended (O362–363 merged). Step 1's location is per tool: the round's `SIGNOFF.md` under drafter; the root `claude-design/SIGNOFF.md` entry under claude-design. Step 2's invariants are shared: every byte after line 1 identical, the path kept, only after signing, idempotent. The mechanism is per tool: `design-close --words` under drafter; the O372–386 remote regroup under claude-design. |
| **The mockup gate** (*The mockup*) | kept; every C bullet survives | (1) C502–504: no request means no mockup span; the drafter's drafting is its only dispatched work, claude-design dispatches nothing; the go-ahead moment is per tool. (2) C509–511 kept for both tools: the route is recorded in `phase.md` and in `SIGNOFF.md`, which under claude-design is the root entry. **O306 ("the round's record") is not restored.** (3) C530–536: drafter keeps its sources (record on disk, cards included); claude-design gets O326–331 (no DesignSync, cards not on disk, `build-prompt.md` plus the landed record). (4) C540–541: the first two `needs_operator` conditions, per tool. (5) C549–551: the superseding steps, per tool. Verbatim: RESPECT THE DESIGN, stubbed data, exempt from the sweep, the operator's runtime, PENDING #2 existing only on request, the rejection split, the throwaway lifecycle, the gate following the mockup, the concreteness bar. |
| **Never** (shared lines) | kept; every C prohibition survives, shared or in a tool list | (1) The first line's "The design subagent drafts, the operator decides" becomes "**The operator decides, whoever drafts**"; the drafter's "drafting is `design-drafter`'s alone" and the drafter mockup timing (C821–822) move to the **drafter:** list; claude-design's timing (O596) goes to its list. (2) Answering a design question: "the drafter may draft options" is labelled drafter. (3) The `frontend-design` exception (C829–832) is **drafter-only**; claude-design has none (its own line says so). (4) The DesignSync / account / push ban (C833–835) is **drafter-only**. (5) Dispatching: the shared line stays; drafter has its two spans; claude-design gets O606–608. (6) Sign-off names both "the drafter's `done`" and "the Claude Design session having ended" (O612–613 merged). (7) Editing names "the returned record" (O624 merged). (8) The early-regroup line names both mechanisms (O625–627 merged). Unchanged: product code, verify, fix a gap silently, build an unasked mockup, renumber (= O631), rate low, pre-plan. Restored as claude-design lines: O599–600, O603–604, O606–608. |

Where O and C differed and **C won** (none of O's variant restored):
- "landed" becomes "signed" (DECOMP2 and paired);
- O139–142's "one co-work slice per round";
- O306, the mockup route "in the round's record";
- O251, "may keep this under its own `design/` tree";
- O's "the workspace never requires a claude.ai account" now scopes to the drafter loop only.

New negative pins in the smoke:
- "cuts the build slices once the design has landed";
- "one `co-work` slice each";
- "in the round's record *and* in `phase.md`";
- "under its own `design/` tree instead";
- "**The workspace never requires a claude.ai account".

## Smoke changes (`tests/retrofit_smoke.sh`)

- **Header comment:** now names the v48 design-tool invariants.
- **Test 0 ok message:** now says "both design tools".
- **design-cowork required list:**
  - The L258 pin becomes "**The drafter loop never requires a claude.ai account and does not use `DesignSync`**".
  - New choice pins: `## Design tool — drafter or claude-design`, `Design tool: drafter | claude-design`, "**An absent line reads as `drafter`**", "**design-deck shows `drafter` rounds only.**", "**Governance is shared.**", `docs/reference/design/claude-design/`, the claude-design record heading, "**`claude-design/` is outside schema 1.**", the `design-migrate --apply` command and table row, `### Under drafter` / `### Under claude-design`, and "**two without a mockup, four with one**".
  - Restored presence pins (the old L314–320 absence pins, swapped): "**Claude Design reads the real repo itself**", "**Connect GitHub**", "The Design System pane", "`_ds_manifest.json`", "**DesignSync is main-thread only.**", "**the DesignSync work is never dispatched**", "**Read back with the `DesignSync` tool**", "`list_files` → `get_file` each card", "**`finalize_plan`**", "`write_files`", the `get_project` line, "`register_assets`", "**`/design-sync`**", "**the cards appear in the pane**", "**Push the branch** so Claude Design reads current code", and the claude-design-only marker label.
- **C-wins negatives:** the five above.
- **Frontmatter:**
  - `allowed-tools` now **contains** `DesignSync`;
  - the description must name "the operator designs in Claude Design", `claude-design` and `DesignSync`, alongside the kept "the design subagent drafts, the operator decides" and trigger pins;
  - "Claude Design + the operator" is still banned.
- **Constants-vs-skill loop:** adds `DESIGN_LEGACY_DIR` and `DESIGN_DECK_URL_ENV`. Their values, `claude-design` and `AGENTIC_DESIGN_DECK_URL`, are in the skill text.
- **Old gone list:** the v47 loop phrases are removed, with a comment saying where they went. The v37/v42/v44 negatives stay.
- **L410** (now L440): gated on `claude-design` in the body (deviation 3).
- **Kept:** every P26 contract pin; `design-drafter` free of `DesignSync` (now L787); S3's pins, at their new line numbers after this slice's edits (the old L97–99, 153–154 and 579–586 references are stale):
  - `create-phase` pins at L100–101;
  - the drivers' negatives at L155–158;
  - the `CLAUDE.md` negatives at L609–611;
  - the banner at L613–617.

## Notebook edits (`phase.md`)

- **Consumed:** the three S2 notes. The upstream-rule note now targets S3 only.
- **`## Decisions`:** added claude-design superseding, "C wins where O and C differ", the per-round push and the record-heading layout.
- **`## Notes for later slices`:** added S3's mirror phrases, the new smoke line numbers and the push caveat for `CLAUDE.md`.
- **`## Operator Questions`:** appended the push-scope question.
- **`## Doc impact`:** appended the operations line.
- **`## Now`:** rewritten.
