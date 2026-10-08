# Plan — P27.DECOMP (decomposition)

## Context

P27 makes the design tool a **per-phase choice**:
- **`drafter`** (default): P26's repo design files + `design-drafter`, viewed in design-deck.
- **`claude-design`**: the original Claude Design co-work loop that P26 removed, restored as it was. Nothing is copied into the repo, and design-deck never shows these rounds.
- The records of a `claude-design` round live in the original layout under `docs/reference/design/claude-design/`. The `design-*` commands and the deck skip that folder.
- Pre-P26 repos are migrated by moving their old records there.
- `design-register` prints a deck hint.
- The release is **v48**, with a re-sync note.

Read `works/phases/active/P27/intent.md` in full. It holds the verbatim request, the seven confirmed deliverables, the out-of-scope list (every design-deck-side change, `design-check --root`, schema 2/D29, mirroring) and the clarifications.

## Machinery footprint (read-only exploration)

- **Engine (`scripts/workflow.py`)**
  - The design contract is at L3011–3583: `DESIGN_ROOT_REL` L3021, `design_scan` L3212, `design_check` L3354, `design_open` L3437, `design_close` L3474, `design_registry_path` L3549, `design_register` L3554, argparse L3734+.
  - `design_scan`'s `root.rglob("*.htm*")` (L3268–3274) flags every HTML file outside `cards/` and `rounds/*/{cards,import}/`. That covers a `claude-design/grounding/previews/*.html`, so the scan must skip `claude-design/`.
  - `rounds/` is read only at the root (L3276), so `claude-design/rounds/` is already out of its path.
  - A repo holding only `claude-design/` (no `design.json`) is never `design-check`ed, because that loop does not use the engine.
- **The old loop's text:** `git show 7ecd381^:.claude/skills/design-cowork/SKILL.md` (639 lines). The removal diffs are 4eaabc8 (the skill) and f21129d (the contract/executor/driver sweep, v47).
- **`design-cowork/SKILL.md` today** (869 lines): §The loop L22, §Shape L89, §The handoff L182, §The card set L220, §Importing a Claude Design bundle L270, §The design record L286, §Read back L450, §The mockup L498, §Closing the round L567, §Mechanics L607, §Implementing L643, §Verifying L654, §Never L815.
  - Governance (styles, rounds and superseding, literal signoff, the mockup gate, RESPECT THE DESIGN, Verifying) is **shared by both tools**.
  - The loop mechanics differ per tool.
- **Pins retired in P26:**
  - `tests/retrofit_smoke.sh` (1383 lines) pins the old loop's **absence** at L97–99, 153–154, 176, 257–273, 314–320, 410, 579–586 and 754–757.
  - These become "the choice is present" pins. Keep `design-drafter` free of `DesignSync`.
- **Contract, drivers and shipping text naming the partner:**
  - `CLAUDE.md` L15 and L52;
  - `slice-executor-high.md` and `slice-executor-mid.md` L15, 33, 60;
  - `do-whole-phase` and `do-next-slice` (the co-work steps, PENDING #1);
  - `create-phase` L27 and L52–57 (the `## Design Style` block);
  - `review-phase` (mockup lines, if affected);
  - both READMEs, the retrofit guide, and the installer banner (`installer/main.py` ~L691).
- **Release:**
  - `installer/main.py:38` `WORKSPACE_VERSION = 47` becomes 48.
  - Add a `CHANGELOG.md` `## v48` entry with migration notes.
  - Run `python3 installer/build.py`; `--check` must pass (the pre-commit hook enforces it).

## The cut: three middle slices, then REVIEW

| Slice | Kind / risk | Why this rating |
|---|---|---|
| `P27.S1` Engine: skip `claude-design/`, `design-migrate`, the register hint | implementation / **high** | **core invariant**: `design-migrate` moves the operator's persisted design records, and a wrong move loses history |
| `P27.S2` `design-cowork` carries both loops | implementation / **high** | **core invariant + open design**: restores ~18 KB of loop mechanics next to P26's without dropping a governance line, and the two-loop structure of one skill is not pinned |
| `P27.S3` Choice, contract and driver sweep, then ship v48 | implementation / low | a pinned text sweep that follows S2's final wording, plus the release steps (same shape as P26.S4, which was low) |

**S1 — engine.**
- `design_scan` ignores `claude-design/` entirely, and so does every command built on it.
- **`design-migrate`** moves a pre-P26 record into `claude-design/`:
  - it moves the legacy `rounds/` (rounds without `round.json`), `SIGNOFF.md` and `grounding/` into `docs/reference/design/claude-design/`, unchanged;
  - it is a dry run by default, printing each move; `--apply` performs the moves;
  - it refuses when a destination exists or when `rounds/` mixes legacy and schema-1 rounds;
  - it never deletes, never runs git, and never writes `design.json` (`design-init` stays a separate, optional step for repos that will use the drafter).
- **`design-register`** prints, on success:
  - that design-deck reads this registry;
  - the deck URL when `$AGENTIC_DESIGN_DECK_URL` is set (the engine never guesses the Tailscale IP);
  - that the deck only sees repos under its mounted projects folder (default `~/projects`), with a warning when this repo is outside `~/projects`.
- **Tests:** small smoke probes for the core only:
  - the scan ignores `claude-design/` HTML;
  - `design-migrate` dry-run vs `--apply` on a legacy fixture;
  - it refuses a conflict.
- **Live check:** dry-run `design-migrate` against a **copy** of `changple5`'s design folder in a scratch directory. Never touch the real repo.

**S2 — `design-cowork` with both loops.**
- **Where the choice is read:** a short "Design tool" section near the top says:
  - the tool is chosen per phase at `/create-phase`, as a `Design tool:` line under `## Design Style`, and reads as `drafter` when absent;
  - which sections are shared and which belong to one tool.
- **The `drafter` loop is unchanged.**
- **The `claude-design` loop** restores the pre-P26 mechanics from `7ecd381^`, adapted only in its paths to `docs/reference/design/claude-design/`:
  - Connect GitHub and the one sanctioned design-slice push;
  - PENDING while the operator designs in Claude Design;
  - the DesignSync read-back (`list_files`/`get_file`), the card-contract and concreteness checks, and `_ds_manifest.json`;
  - `result.md`/`build-prompt.md` landed as-is, `SIGNOFF.md`, and the remote regroup (`finalize_plan` → `write_files`);
  - "DesignSync is main-thread only": the read-back and the regroup are never dispatched, and the mockup is the only dispatched span;
  - the two sanctioned writes, and `/design-sync` as operator-only;
  - the mode's constraints: a claude.ai login, fails under `ocx claude`, not runnable in a subagent.
- **Tool-specific lines in shared sections:**
  - §Mechanics and §Never carry both tools' lines, each labelled with its tool.
  - `DesignSync` goes back into `allowed-tools`, and the description names both partners (quote any `: `).
- **Keep:** the bundle-import subsection (a drafter-mode input) and every governance section's meaning.
- **Smoke:** swap the design-cowork absence pins for presence and choice pins, and keep the P26 contract pins.

**S3 — sweep + v48.**
- **`create-phase`:** ask `Design tool: drafter | claude-design` together with the style and mockup questions, and record the line under `## Design Style`, defaulting to drafter.
- **`CLAUDE.md` L15 and L52:** the co-work exception and the hard rule name the partner per tool. For example: "the design subagent drafts (or, under `claude-design`, the operator designs in Claude Design); the operator decides". Keep the file ≤ 12 KB, per the P23/D8 cap.
- **Executors (L15, 33, 60):** the refusal and mockup-span clauses cover both tools.
- **`do-whole-phase` and `do-next-slice`:** the co-work steps branch on the tool, and PENDING #1 wording exists for each.
- **Also:** `review-phase` if affected, both READMEs, the retrofit guide, and the installer banner.
- **Smoke:** the pins at L97–99, 153–154, 579–586 and 754–757 become choice pins.
- **Release:**
  - `WORKSPACE_VERSION` 48 and a `## v48` CHANGELOG entry whose migration notes cover: the choice, `design-migrate` for pre-P26 repos, `$AGENTIC_DESIGN_DECK_URL`, and the **re-sync note** (copies synced at v47 before P26.F1/F2, including design-deck, lack the drafter's `new visual direction` licence, the `#` fragments and the stricter reference scan: update to v48);
  - `python3 installer/build.py` and `--check`.
- **Doc impact:** a `## Doc impact` note for operations (the Visual-design runbook), decisions, architecture and qa. **No `doc-new-version`.**

**Upstream rule for every slice:** any slice that edits an embedded file (`scripts/workflow.py`, `.claude/*`, `works/templates/*`, `CLAUDE.md`) runs `python3 installer/build.py` in that slice, and `--check` must pass. Only S3 bumps the version.

## What the DECOMP executor does

1. Read `intent.md`, `phase.md`, and `CLAUDE.md`'s DECOMP/risk rules.
2. Create the three bare slices with `new-slice`:
   - `--kind implementation` and the risks in the table;
   - `--order 1`–`3`;
   - `--depends-on` chaining S1 → S2 → S3;
   - no `plan.md`.
3. Edit `phase.md`:
   - **`## Decisions`:**
     - the cut and its rating triggers;
     - the footprint above (compact, with line refs);
     - `claude-design/` as the old loop's record home;
     - no mirroring;
     - the `$AGENTIC_DESIGN_DECK_URL` choice;
     - design-deck-side work out of scope (listed in `intent.md`).
   - **`## Notes for later slices`** (tagged by slice):
     - S1: the scan lines and the migrate rules;
     - S2: the section map, the `7ecd381^` source and "keep governance meaning";
     - S3: the contract/executor/driver lines, the 12 KB cap on `CLAUDE.md` and the release/re-sync duty;
     - all slices: the build.py rule;
     - for the later design-deck phase (not this phase): verify the deck ignores `claude-design/`.
   - **`## Now`:** the handoff to S1.
4. `rebuild`, then `validate`.
5. Write `result.md` with the verdict block first, including your read on the gate.

**Boundaries:** bare folders only; no `accept-gate`, no commits, no machinery edits in this slice.

## Acceptance gate (orchestrator, after `finish-slice`)

**`--waive`**, note: "workspace machinery only: no running product surface; the design-tool choice is exercised by the next design-bearing phase". Same reason as P21–P26.

## Verification

- `validate` exits 0.
- `next` points at `P27.S1`.
- The three new folders hold only `slice.json`.
- The `## Slices` table lists DECOMP, S1–S3 and REVIEW with the ratings above.
