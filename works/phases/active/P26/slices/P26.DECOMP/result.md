# Result — P26.DECOMP (decomposition)

## Verdict

- `status`: done
- `tier`: high
- `summary`: Cut P26 into four bare implementation slices chained S1 → S2 → S3 → S4 (S1 contract + engine, high; S2 design subagent, low; S3 `design-cowork` rewrite, high; S4 contract/skills sweep + v47, low). Recorded the cut, the verified machinery footprint, the design-cowork mechanics/governance split and a waive recommendation for the gate in `phase.md`, with tagged notes for each slice.
- `files_changed`:
  - `works/phases/active/P26/slices/P26.S1/slice.json` (new, via `new-slice`)
  - `works/phases/active/P26/slices/P26.S2/slice.json` (new, via `new-slice`)
  - `works/phases/active/P26/slices/P26.S3/slice.json` (new, via `new-slice`)
  - `works/phases/active/P26/slices/P26.S4/slice.json` (new, via `new-slice`)
  - `works/phases/active/P26/phase.md`
  - `works/phases/active/P26/slices/P26.DECOMP/result.md`
  - engine-regenerated: `works/backlog.md`, `works/index.json`, `works/events.jsonl`, `works/state.json`, `docs/index.json` (timestamp only)
- `validation`:
  - `python3 scripts/workflow.py rebuild` passed.
  - `python3 scripts/workflow.py validate` passed (exit 0). Its one warning, `oversized_doc_sections=7`, was already there and is unrelated.
  - `python3 scripts/workflow.py next` gives `next_slice=P26.S1`.
  - The four new folders hold only `slice.json`.
  - The `## Slices` table lists DECOMP, S1–S4 and REVIEW with the planned ratings.
- `deviations`: none from the steps. I added three items the plan did not list, all as notes only:
  - Verified line refs. A few drifted from the plan: `executor_agent_files()` is L260–265, `DUAL_FIXED` is L941, the banner is L688–689.
  - A disposition for D5 and D12, which `intent.md` asks DECOMP to check.
  - An S4 note that `README.md` and `README.en.md` still carry Claude Design / `DesignSync` text outside the plan's sweep list.
- `doc_impact`: none. DECOMP changes no durable truth; S1–S4 own their notes.
- `gate read`: **waive**, agreeing with the plan. P26 changes workspace machinery only. There is no running product surface and no `## Operator Runtime` section to verify in, so nothing is browser-verifiable, the same as P21–P24. The contract is the operator-facing artifact because the dashboard repo builds against it. I recommend relaying S1's contract summary to the operator **right after S1** rather than only at phase end, so any objection lands before S3/S4 bake the contract into the doctrine. That is advisory and needs no gate.

## Slices created

| Slice | Kind / risk | Order | depends_on | Trigger |
|---|---|---|---|---|
| `P26.S1` define the on-disk design contract and its engine commands | implementation / high | 1 | — | open design + wide blast radius |
| `P26.S2` add the design subagent and ship it | implementation / low | 2 | `P26.S1` | — |
| `P26.S3` rewrite design-cowork around the files | implementation / high | 3 | `P26.S2` | core invariant |
| `P26.S4` sweep the contract and orchestrator skills, ship v47 | implementation / low | 4 | `P26.S3` | — |

The commands are exactly as run, one `new-slice` each: `--kind implementation`, `--risk` and `--order` as in the table, and `--depends-on` on S2–S4. No `plan.md` was created in any of them.

## What went into phase.md

All of it is in `works/phases/active/P26/phase.md`:

- **`## Decisions`**:
  - the cut and each rating trigger;
  - that the contract lives inside `design-cowork/SKILL.md`, because skills ship as `SKILL.md` only;
  - the machinery footprint, with verified line refs;
  - the `design-cowork` mechanics/governance section map, with line numbers;
  - no interim viewer or `board.html`;
  - the deferred-job dispositions (D5, D7, D12, D13 and D27);
  - the gate recommendation.
- **`## Notes for later slices`**: one note for every slice (the upstream `build.py` rule and the smoke-run rule), and one each for S1, S2, S3 and S4.
- **`## Now`**: the handoff to S1.

## Findings behind the notes (not restated in phase.md)

- **Line refs checked against the tree:**
  - `SLICE_KINDS` is at `scripts/workflow.py` L54; its comment block starts at L38.
  - `executor_agent_files()` is at L260–265 and iterates `EXECUTOR_TIERS`. `executor_agent_drift()` (L268) feeds `sync_agents()` (L282) and the status line (L361–364), and `validate()` repeats the check as advisory warnings (L1334–1341).
  - `FIXED_LIVE_FILES` is at `installer/build.py` L44.
  - `MANAGED_FILES` is at `installer/main.py` L74, with the agent emit loop at L540–543, the banner at L688 (agents) and L689 (Visual design), and `WORKSPACE_VERSION = 46` at L38.
  - `DUAL_FIXED` is at `tests/retrofit_smoke.sh` L941.
  - `CLAUDE.md` L13, L15 and L52 are the design lines. L49 is the Aside rule and L60 the kinds list; both are only for re-checking.
- **`design-cowork/SKILL.md` headings:**
  - The file is 48,032 B. Headings and lines: §The loop L18, §Shape L69, §The handoff L160, §The card set L185, §The design record L237, §Read back L262, §The mockup L294, §Closing the round L360, §Mechanics L391, §Implementing L422, §Verifying L433, §When the record never drew it L575, §Never L594.
  - The frontmatter `allowed-tools` ends in `DesignSync`, and the `description:` names Claude Design.
- **`_ds_manifest.json`** is Claude Design's app-side index, compiled from the `@dsCard` markers. It is referenced at `design-cowork` L188/L266 and `operations.md` L256/L348. It is what S4's migration notes must address.
- **Counts of Claude Design / `DesignSync` mentions by file:**

  | File | Mentions |
  |---|---|
  | `design-cowork` | 25 |
  | `do-whole-phase` | 6 |
  | `do-next-slice` | 2 |
  | `create-phase` | 1 |
  | each executor | 2 |
  | `README.md` / `README.en.md` | 4 each |
  | `operations.md` | 19 |
  | `decisions.md` | 16 |

  The READMEs are not embedded by the installer, but they are the repo's public description, hence the S4 note.
- **The P25 prototype** `board.py` still exists in the session scratchpad (`…/scratchpad/board/board.py`). It is not durable; P25.S2 §3.1 carries enough to re-derive it.
- **Two risk-rating checks:**
  - S2 stays low only if its plan pins the drafter's model source. Tracking the high tier through `sync-agents` adds a third entry to `executor_agent_files()`, whose callers are all inside `workflow.py` (not a wide blast radius). A fixed alias should be the portable `opus`, because ocx routes aliases.
  - S4 stays low because every line it rewrites is named in the plan, and its wording follows S3.

## Dead ends

None.
