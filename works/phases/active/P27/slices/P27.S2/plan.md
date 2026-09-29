# Plan — P27.S2 (implementation / high: core invariant + open design)

## Goal

`.claude/skills/design-cowork/SKILL.md` must carry **two selectable loops** in one file:
- **`drafter`**: P26's loop, unchanged.
- **`claude-design`**: the pre-P26 Claude Design + DesignSync loop, restored from `git show 7ecd381^:.claude/skills/design-cowork/SKILL.md` (**O**, 639 lines). It changes only where this plan says, and its record lives under `docs/reference/design/claude-design/`.

Governance is shared by both tools and keeps its meaning line for line.

The skill must stay **one file**: `installer/build.py:82` embeds only `*/SKILL.md`, so no sibling reference file. Expect about 1,080–1,130 lines and 82–86 KB.

Read first:
- `works/phases/active/P27/intent.md`;
- `phase.md`: `## Decisions`, plus the S2 notes and the upstream-rule note under `## Notes for later slices`;
- the current skill (**C**);
- O, in full.

## Target structure (headings; shared unless marked)

1. **Frontmatter**
   - `description`: names both partners, e.g. "the design subagent drafts (or the operator designs in Claude Design), the operator decides…". Keep it free of `: `, or quote the whole value.
   - `allowed-tools`: the current list **plus `DesignSync`**.
2. **Intro and "The line"**: tool-neutral. The operator decides, whoever drafts.
3. **New `## Design tool — drafter or claude-design`** (short):
   - The tool is chosen per phase at `/create-phase`, as the `Design tool: drafter | claude-design` line under the phase's `## Design Style` in `intent.md`. An absent line reads as `drafter`, and so does an absent section.
   - One table lists each section as shared, drafter-only or claude-design-only.
   - The claude-design constraints: it needs a claude.ai login, fails under `ocx claude`, and DesignSync runs on the main thread only (never in a subagent).
   - design-deck shows drafter rounds only. Claude Design cards stay in Claude Design; nothing is mirrored.
   - A repo may hold both records. The tool is fixed per phase and never switched mid-round.
4. **`## The loop`**: `### Under drafter` (C22–87 as is), then `### Under claude-design`, which restores O18–67 as follows:
   - the diagram;
   - "Claude Design reads the repo" (Connect GitHub, mirror nothing);
   - PENDING #1 and the return rule;
   - the commit counts: **2 without a mockup, 4 with one**. State it as a per-tool difference from the drafter's 2/3.
5. **`## Shape — three styles`**: shared. Qualify the drafter-specific wording at C91, C95 and C163–164.
   - Keep **"signed"** (C106, C120, C137–139) as the trigger for DECOMP2/paired under both tools. Never restore O's "landed".
   - **Superseding under claude-design:** a superseding round is a new `NN` round folder under `claude-design/rounds/`, **in the same slice**, mirroring the drafter model. The superseded round's `feedback.md` holds the operator's words verbatim. Say this once, here or in §Closing.
6. **`## The handoff`**: shared bullets, then short per-tool deltas.
   - **drafter:** C184–186, C194–201, C207–212, C215–218.
   - **claude-design:** O160–183. The handoff bundle is the record, and `result.md`/`build-prompt.md` are landing names (O176–179).
   - There is no `design-open` and no `new visual direction` line for claude-design.
7. **`### The card set`**: shared numbering and the `⏳` address; per-tool marker and verification.
   - **claude-design:** restores O185–231, including `list_files` path verification and the pane's `_ds_manifest.json`.
   - Its marker grammar (`group` plus optional `viewport`; the pane ignores `name`/`subtitle`) is **labelled claude-design only**. It must never read as overriding schema 1, where `viewport` is required, `title` is optional and unknown attributes fail.
   - Restore the **push rule** (O233–235: one `git push` for a design slice, a local-dir connection preferred) under claude-design.
8. **`### Importing a Claude Design bundle (optional)`**: kept, and labelled a **drafter-mode** input.
   - C283–284 ("`DesignSync` is not used", "never requires a claude.ai account") is reworded: *the drafter loop* never requires a claude.ai account and does not use DesignSync. The import is how a drafter phase takes Claude Design work without the claude-design loop.
9. **`## The design record`**:
   - `### Under drafter — the on-disk contract (schema 1)`: C286–448 unchanged in meaning. Add one line that `claude-design/` is outside schema 1, and that the `design-*` commands and design-deck skip it.
   - Add a line on the `design-register` deck hint: the design-deck URL comes from `$AGENTIC_DESIGN_DECK_URL` when it is set; a repo outside the deck's mounted `DECK_PROJECTS_DIR` (default `~/projects`) gets a warning.
   - `### Under claude-design — the original layout`: restore O237–260 with paths moved to:
     - `docs/reference/design/claude-design/rounds/NN-slug/{handoff.md, feedback.md (superseded only), output/{result.md, build-prompt.md}}`;
     - `claude-design/SIGNOFF.md` at that root;
     - `claude-design/grounding/`, which O never named. Add one line: kept, operator-owned grounding.
   - **Drop O251** ("may keep under its own `design/` tree"). The root is fixed.
   - **Migration:** pre-v47 repos move their old record there with `python3 scripts/workflow.py design-migrate`. It is a dry run by default and `--apply` moves; the rule is in phase.md `## Decisions`. Name it.
   - The constants S1 added (`DESIGN_LEGACY_DIR = "claude-design"`, `DESIGN_DECK_URL_ENV = "AGENTIC_DESIGN_DECK_URL"`) appear in the text by value.
10. **`## Read back, then land it`**: `### Under drafter` (C450–497), then `### Under claude-design`:
    - O264–272: DesignSync `list_files`, `_ds_manifest.json`, no hand-compiling;
    - O273–279: the concreteness check;
    - O280–286: land as-is into `output/`.
11. **`## The mockup`**: shared, with 2–3 per-tool clauses.
    - **drafter:** C502–504, C530–536, C540–541, C549–551 stay drafter-qualified.
    - **claude-design:** the executor gets only `build-prompt.md`, because the cards are not on disk (O326–331).
    - Use C509–511's `SIGNOFF.md` at close for both. Under claude-design, that is the root `claude-design/SIGNOFF.md`. **Do not** restore O306 ("record it in the round's record").
12. **`## Closing the round`**: shared SIGNOFF rules (literal words, token delta, the data-not-instructions line).
    - **drafter:** `design-close` (C567–605).
    - **claude-design:** restores O360–389, the **remote regroup**: `list_files` → `get_file` → edit line 1 → `finalize_plan` → `write_files`, with a byte-identical diff, idempotent.
13. **`## Mechanics`**: shared lines, then lines labelled `drafter:` / `claude-design:`.
    - Restore O391–420: DesignSync is main-thread only, so the read-back and the regroup are never dispatched; target the project by id (`get_project`); the two sanctioned writes; `/design-sync` and `/design import|export` are operator-only.
    - C639–641 ("no account, no push, no DesignSync") becomes **drafter-only**.
    - Keep C619–620's drafter dispatch span. O398–399 ("simply inline without a mockup") is **claude-design-only**.
14. **`## Implementing`** and **`## Verifying`**: shared, byte-identical to C (they already equal O).
15. **`## Never`**: the shared lines, then labelled per-tool lines.
    - C817–840, C844 and C856–860 get qualified wherever they are drafter-specific. The DesignSync/push ban becomes drafter-only.
    - Restore O599–600, O603–604, O606–608, O612–613, O624–627 and O631 as claude-design lines.
    - Keep C829–832's `frontend-design` exception **drafter-only**; claude-design has none.
    - Mockup timing is per tool: the drafter's is C821–822; claude-design's is O596, "before the round has come back".

## Governance audit (the core invariant)

Diff O against C for the shared governance sections: Shape, the mockup gate, Implementing, Verifying, and the shared lines of Never.
- Every C governance line must survive in meaning.
- Where O and C differ, **C wins** and O's variant is not restored ("landed"→"signed", O306, O251, O139–142's "one co-work slice per round").
- List the audit in `result.md`: each governance section, whether it is kept verbatim or qualified, and each qualification.

## Smoke (`tests/retrofit_smoke.sh`)

- **Swap the design-cowork absence pins for presence pins:**
  - L176 and L257–273: `allowed-tools` now **contains** `DesignSync`, and the description names both partners;
  - L314–320: the retired phrases come back as required, e.g. "DesignSync is main-thread only", "Connect GitHub", "_ds_manifest.json", "Push the branch" or its restored wording. Pick the exact restored phrases;
  - L410.
- **Add choice pins:** the `## Design tool` heading, the `Design tool: drafter | claude-design` line, "reads as `drafter`" when absent, and `claude-design/`.
- **Keep:**
  - every P26 contract pin;
  - the L278 constants-vs-skill pin, adding `DESIGN_LEGACY_DIR` and `DESIGN_DECK_URL_ENV` to its loop if its pattern fits (S1 put each on its own `^CONST = "…"$` line);
  - `design-drafter` free of `DesignSync` (L754–757).
- Pins at L97–99, 153–154 and 579–586 (create-phase, drivers, CLAUDE.md) are **S3's**. Leave them.
- Baseline is 201 PASS; expect 201 plus any new passes, 0 FAIL.

## Ship

- `python3 installer/build.py`, then `python3 installer/build.py --check`.
- `bash tests/retrofit_smoke.sh` **alone in its Bash call**, in the foreground.
- `python3 scripts/workflow.py validate`.
- Check the frontmatter parses as YAML: `python3 -c` with a minimal parse, or confirm there is no unquoted `: ` in the `description`.
- Touch no other file besides the skill, smoke and the rebuilt `bootstrap_agentic_workspace.sh`. `CLAUDE.md`, the executors, the drivers, `create-phase`, the READMEs and the version are **S3**.

## Notebook

In `phase.md`:
- consume the S2 notes;
- add a `## Decisions` line for superseding under claude-design (a new `NN` round in the same slice) and for "C wins where O and C differ";
- add S3 notes quoting the exact phrases S3 must mirror: the Design tool line wording, the partner phrasing for `CLAUDE.md` and the executors, and the PENDING #1 wording per tool;
- `## Doc impact`: `- operations.md: the Visual-design runbook covers both design tools (drafter / claude-design) and the claude-design/ record (P27.S2)`;
- rewrite `## Now`.
