# Plan — P27.S3 (implementation / low: pinned sweep + release)

## Goal

Make every text outside `design-cowork` that names the design partner cover **both tools**, using the exact wording S2 set, and add the choice to `/create-phase`. Then ship **v48**.

Read first:
- `works/phases/active/P27/intent.md`;
- the whole `## Notes for later slices` block in `phase.md`, especially the S2 note "Mirror S2's exact wording", the `CLAUDE.md` cap note, the Release note, S1's CHANGELOG command lines, and the upstream rule;
- `.claude/skills/design-cowork/SKILL.md`, `## Design tool — drafter or claude-design` section, as the wording source.

## Edits

1. **`.claude/skills/create-phase/SKILL.md`**
   - **L27:** after the mockup question, add the tool question in the same breath: *"which design tool: `drafter` (the design subagent drafts into the repo, viewable in design-deck, the default) or `claude-design` (you design in Claude Design; needs a claude.ai login, not under `ocx claude`)?"*. Keep it to 2–3 sentences.
   - **L52–57 (`## Design Style` block):** add a third line, `Design tool: drafter` or `Design tool: claude-design`. Say that an absent line reads as `drafter`, and that when the style is asked at `DECOMP`, the tool travels with it.
2. **`CLAUDE.md`, at 12,286 B against the 12,288 B cap.**
   - **L15, the co-work exception:** make it tool-neutral in as few bytes as possible. For example: "a `co-work` design slice runs inline, dispatching its drafting to `design-drafter` (none under `claude-design`, whose DesignSync work stays inline) and its mockup build…".
   - **L52:** keep the pinned "The design subagent drafts, the operator decides:" and add a claude-design partner, for example "(under `claude-design`, the operator designs in Claude Design)".
   - **Pay for every added byte** elsewhere in the file by tightening wording. Never drop a rule or a never-rule, and never change a smoke-pinned phrase (grep `tests/retrofit_smoke.sh` for any phrase before you touch it).
   - The final `wc -c CLAUDE.md` must be ≤ 12,288, and ideally ≤ 12,286.
3. **Both executor bodies** (`.claude/agents/slice-executor-high.md` and `-mid.md`, L15, 33, 60). They must stay **word-for-word identical** in these paragraphs; diff them afterwards.
   - The refusal clause and the mockup-span clause cover both tools.
   - Under `claude-design`, the DesignSync read-back and regroup are main-thread only and never handed to an executor.
   - Under `claude-design`, the mockup span builds only from `build-prompt.md` and the landed record at `docs/reference/design/claude-design/rounds/<NN-slug>/output/`. There is no DesignSync and no cards on disk.
   - The drafter clauses are unchanged. Smoke L440 already lets `DesignSync` into a body that names `claude-design`.
4. **`do-whole-phase` and `do-next-slice`**
   - The co-work step reads the tool from `intent.md` `## Design Style`, where an absent line means drafter.
   - **drafter:** today's text, unchanged.
   - **claude-design:** a compact branch:
     - write the handoff under `claude-design/rounds/NN-slug/`;
     - commit and push once for the round;
     - PENDING #1, with S2's exact claude-design PENDING #1 wording;
     - on return, read back inline with DesignSync (never dispatched), land the output, then signoff, the remote regroup and `finish-slice`;
     - feedback → a superseding round in the same slice;
     - mockup → the dispatched span, then PENDING #2;
     - commits: two without a mockup, four with one.
   - Point to `design-cowork` for detail rather than restating it. Keep each addition as short as the drafter text allows.
5. **`.claude/skills/review-phase/SKILL.md`:** check its mockup and design lines. Qualify only what is drafter-specific.
6. **READMEs.** `README.md` is Korean; `README.en.md` is English. Each design paragraph gains one or two sentences on the choice, the `claude-design` tool, and `design-migrate` for pre-v47 repos. Match each file's language and tone.
7. **`docs/retrofit-guide.md`** (~L156–160): one sentence on the two tools, and `design-migrate` for an adopter with a pre-v47 `docs/reference/design/`.
8. **Installer banner** (`installer/main.py` L690–691): name both tools briefly.
9. **Smoke** (`tests/retrofit_smoke.sh`): the create-phase, driver and `CLAUDE.md`/banner absence pins are now at L100–101, L155–158 and L609–617. Turn them into choice pins:
   - `create-phase` contains `Design tool:` and `claude-design`;
   - the drivers name `claude-design`;
   - `CLAUDE.md` keeps "The design subagent drafts, the operator decides" and names `claude-design`.

   Keep every other pin. The baseline is 201 PASS; expect 201, 0 FAIL.
10. **Release**
    - `installer/main.py:38`: `WORKSPACE_VERSION = 48`.
    - `CHANGELOG.md`: a `## v48` entry at the top, in the style of v47. It covers:
      - what changed (the per-phase design tool, the restored claude-design loop, the `claude-design/` record, `design-migrate`, the register hint);
      - **migration notes** using S1's exact command lines and the one-sentence migrate rule, and `AGENTIC_DESIGN_DECK_URL`;
      - the **re-sync note**: workspaces synced at v47 before P26.F1/F2, design-deck among them, lack the drafter's `new visual direction` licence, the `#` fragments and the stricter `design-check` reference scan, so update to v48;
      - the claude-design constraints (a claude.ai login, not under `ocx claude`, main-thread DesignSync).
    - Run `python3 installer/build.py`, then `--check`.

## Validation

- `bash tests/retrofit_smoke.sh` **alone in its Bash call**, in the foreground.
- `python3 installer/build.py --check`.
- `python3 scripts/workflow.py validate`.
- `wc -c CLAUDE.md` ≤ 12,288.
- Diff the two executor bodies' edited paragraphs: identical.
- `grep -rn "DesignSync\|claude-design" CLAUDE.md .claude/agents .claude/skills/do-*/SKILL.md .claude/skills/create-phase/SKILL.md` shows the new wording.

## Notebook

In `phase.md`:
- consume the S3 notes, and the upstream-rule note;
- `## Doc impact`: one line each for:
  - `decisions.md`: the design tool as a per-phase choice; `claude-design/` is outside schema 1;
  - `architecture.md`: two design loops share governance;
  - `qa.md`: the smoke choice pins and the migrate probes;
  - `operations.md`: the v48 upgrade steps, if not already covered by S1/S2's lines;
- rewrite `## Now` for the REVIEW;
- leave both Operator Questions for the review to route.

**Deferred jobs D18, D20, D21, D23 and D24 stay deferred:** do not slim the executors, pin the never-rule floor or fix README drift beyond the design paragraphs.
