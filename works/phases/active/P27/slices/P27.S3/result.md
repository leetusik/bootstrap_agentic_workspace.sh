# Result — P27.S3 (implementation / low)

- **status:** done
- **tier:** mid
- **summary:** Every text outside `design-cowork` that names the design partner now covers both tools: `create-phase` asks and records `Design tool:`, `CLAUDE.md` (12,280 B), both executor bodies, both drivers (a compact `claude-design` branch), both READMEs, the retrofit guide and the installer banner. The smoke's absence pins became choice pins, and **v48 shipped** (`WORKSPACE_VERSION` 48, a CHANGELOG entry with the migration and re-sync notes, the installer rebuilt).
- **files_changed:** `CLAUDE.md`, `.claude/skills/create-phase/SKILL.md`, `.claude/skills/do-next-slice/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md`, `.claude/agents/slice-executor-high.md`, `.claude/agents/slice-executor-mid.md`, `README.md`, `README.en.md`, `docs/retrofit-guide.md`, `installer/main.py`, `CHANGELOG.md`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P27/phase.md`, `works/phases/active/P27/slices/P27.S3/result.md`
- **validation:**
  - `python3 installer/build.py` then `python3 installer/build.py --check` — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` (pass)
  - `bash tests/retrofit_smoke.sh`, alone and in the foreground: **201 PASS, 0 FAIL**, `ALL RETROFIT SMOKE TESTS PASSED` (pass; baseline 201, no new PASS lines). A first run after the sweep failed 165 checks; that was the installer tokenizer trap below, fixed before the passing run.
  - `python3 scripts/workflow.py validate` — `Workflow validation passed.` (pass; the three warnings are the pre-existing P26 consolidation, stale-docs and oversized-section ones)
  - `wc -c CLAUDE.md` — **12,280** (cap 12,288; the plan's ideal was ≤ 12,286)
  - `diff <(sed -n '33p;60p' slice-executor-high.md) <(sed -n '33p;60p' slice-executor-mid.md)` — identical (the only other differences between the two bodies are the pre-existing `name`, `description` and `model` lines)
  - `grep -rn "DesignSync\|claude-design"` over `CLAUDE.md`, `.claude/agents`, the two drivers and `create-phase` shows the new wording (pass)
- **deviations:**
  1. **A 3-byte rewording in both executor bodies that the plan did not ask for.** The first smoke run failed 165 checks because the rebuilt installer no longer started (details below). I changed "and either way the rest of that slice" to "and in both cases the rest of that slice" in both bodies (identical), which moved the offending character off the tokenizer's chunk boundary. This is a workaround, not a fix. The structural fix (ASCII-escaping the embedded strings in `installer/build.py`, or feeding Python from a file) is outside this slice, and `build.py` is D3's trigger. It is an Operator Question in `phase.md`.
  2. **`CLAUDE.md` tightening was wider than the plan's example, but rule-preserving.** See the list below. The L15 and L52 wording differs from the plan's suggestions to stay inside the byte cap and keep the smoke-pinned phrases contiguous.
  3. **`review-phase` was checked and left unedited.** Its only design line (L41, the orphaned mockup route) is tool-neutral.
  4. **No size assertion was added to the smoke.** I first wrote a `len(claude.encode()) <= 12288` assert, then removed it, since the plan says to keep every other pin and measure with `wc -c`.
  5. The driver smoke pins kept `never dispatched` (and `_ds_manifest`, `four commits, two`, `one dispatched span`, `Push the branch`) as absence pins. Only `DesignSync` and `Claude Design` left the driver absence list, so the driver text says "never handed to an executor" instead.
- **doc_impact:** four lines appended to `phase.md` `## Doc impact` (decisions, architecture, qa, operations/v48 upgrade steps); see the notebook. No doc versions were created.

## What changed

### `create-phase`
- A paragraph after the mockup question: *"And ask which design tool: `drafter` (the design subagent drafts into the repo, viewable in design-deck; the default) or `claude-design` (you design in Claude Design; it needs a claude.ai login and does not run under `ocx claude`)? … fixed for the phase … travels with the style when that is asked at `DECOMP`."*
- The `## Design Style` block (step 4.2) gains a third line, `Design tool: drafter` or `Design tool: claude-design`. `DECOMP` reads all three, and an absent `Design tool:` line reads as `drafter`.

### `CLAUDE.md` (12,286 → 12,280 B)
- **L15:** the co-work exception keeps its pinned phrases and gains "(`claude-design`: no drafting, DesignSync inline)".
- **L52:** the pinned "The design subagent drafts, the operator decides:" stays, and the end reads "`design-cowork` carries the styles, handoff, rounds, gates and both tools (`drafter`; `claude-design`, the operator designing in Claude Design)."
- **Paid for by** (no rule or never-rule dropped, no smoke-pinned phrase touched):
  - the gloss "(version history)" after `docs/index.json`;
  - "Staying on the default stream needs nothing." in the worktree rule;
  - "the re-attach preamble" in the Aside pointer;
  - the githooks sentence, "and the tracked … hook enforces that" → "; the tracked … hook enforces it";
  - "since its input has not landed" → "until its input lands";
  - "(a requested throwaway mockup is the one exception)" → "(a requested throwaway mockup excepted)";
  - "fires by itself whenever work touches product **visual** design" → "fires by itself on product **visual** design work";
  - "clears the same item back to `in_progress`" → "clears the same item to `in_progress`".
- I first probed the smoke for a few guardrail phrases ("own initiative", "when instructed"); the classifier refused that grep, so I did not run it or pursue it, and left every guardrail phrase in the file as it was. The full `CLAUDE.md` pin list from `tests/retrofit_smoke.sh` L551–600 had been read before, and the passing smoke confirms no pin moved.

### Both executor bodies (L33 mockup span, L60 refusal), identical
- **L33:** under `drafter` the drafting goes to `design-drafter`, under `claude-design` there is none, and in both cases the orchestrator keeps the rest inline. The source of truth is per tool: under `drafter` the cards, `tokens.css` and the round's `result.md`; under `claude-design` only the landed record at `docs/reference/design/claude-design/rounds/<NN-slug>/output/` (`result.md`, `build-prompt.md`), because that tool's cards are not on disk. The span has "no design tooling (no `DesignSync`)".
- **L60:** the pinned "the design subagent (`design-drafter`) drafts a round's cards, and the operator decides" stays, followed by "(under `claude-design` the operator designs in Claude Design and decides there)". "Never handed to you" now names the `DesignSync` read-back and regroup under `claude-design`: they need a claude.ai login and never run in a subagent.
- The smoke gate at L440 (`DesignSync`, `never dispatched, because you have no`, `landed record` allowed only beside `claude-design`) holds.

### `do-whole-phase` and `do-next-slice`
- The intro says drafting is dispatched under `drafter` only (`claude-design` has none), and the co-work step reads the tool first: `Design tool:` under `## Design Style` in `intent.md`, an absent line reads as `drafter`. Steps 1–4 (do-whole-phase) and the existing step 3 text (do-next-slice) are the drafter loop, unchanged.
- The `claude-design` branch: no `design-open`, no drafter, nothing mirrored; `handoff.md` in a new `docs/reference/design/claude-design/rounds/<NN-slug>/`, commit, `git push` once for the round, PENDING #1 (S2's exact wording, in do-whole-phase's "Report each `pending` window" paragraph and inline in do-next-slice); on return an inline `DesignSync` read-back, the record landed as `output/`, the card and concreteness checks; literal approval (no mockup) → the round's `claude-design/SIGNOFF.md` entry, the remote regroup, continue; feedback → `feedback.md` and a superseding round in the same slice (one more commit, push and stop); mockup requested → dispatch to `slice-executor-high` from `build-prompt.md` and the landed record only, PENDING #2. Commits: **two without a mockup, four with one**.
- `do-whole-phase` also qualifies the idle-window note (the drafter span is a dispatched window under `drafter`) and the delegated-slices list (`design-drafter`, `drafter` only).

### Docs, banner, release
- **`README.md`** (Korean) and **`README.en.md`** (English): the design paragraph gains the choice, the `claude-design` tool (claude.ai login, not under `ocx claude`, nothing copied, the `claude-design/` record hidden from the dashboard, chosen per phase at `/create-phase`), and `design-migrate` for a pre-v47 layout.
- **`docs/retrofit-guide.md`:** one sentence on the two tools and one on `design-migrate`.
- **`installer/main.py`:** the banner names both tools; `WORKSPACE_VERSION = 48`.
- **`CHANGELOG.md`:** `## v48 — 2026-09-30` at the top: the choice, both loops, the `claude-design/` record, `design-migrate`, the register hint, the contract wording, the claude-design constraints, the re-sync note and five migration notes. The command lines are S1's: `python3 scripts/workflow.py design-migrate`, `… design-migrate --apply` (commit the renames yourself), `… design-init` only for the drafter, and `AGENTIC_DESIGN_DECK_URL=<deck url> python3 scripts/workflow.py design-register`. The rule sentence: with no `design.json` every top-level entry moves; with one, only the rounds without `round.json`, `SIGNOFF.md` and `grounding/` move.

### Smoke (`tests/retrofit_smoke.sh`)
- **create-phase (L98–104):** the absence pin became `Design tool:`, `` `claude-design` ``, `` `drafter` `` and `reads as `drafter``; `DesignSync` stays out of the skill.
- **Drivers (L134–139, L163–170):** required `` `Design tool:` under `## Design Style` ``, `an absent line reads as `drafter``, `` **`claude-design`** ``, `**read back inline with `DesignSync`**`, the `claude-design/rounds/<NN-slug>/` path and `**two commits without a mockup, four with one**`. `DesignSync` and `Claude Design` left the absence list.
- **`CLAUDE.md` and banner (L616–632):** `DesignSync`/`Claude Design` left the contract's absence list (`never dispatched` and `one dispatched span` stay); the contract must name `` `claude-design` `` and "the operator designing in Claude Design", and the banner must name `claude-design` and `drafter`.
- Every other pin is kept. The count is unchanged (201).

## The installer tokenizer trap (found by the first smoke run)

- **Symptom.** After the sweep, `sh bootstrap_agentic_workspace.sh <target> --into-existing …` printed `SyntaxError: Non-UTF-8 code starting with '\xe2' in file <stdin> on line 56, but no encoding declared`, and 165 smoke checks failed (Test 0 passed; every retrofit test after it failed).
- **Cause.** `installer/build.py` embeds each payload file as one long Python string line in a `python3 - <<'INSTALLER_PY'` heredoc. The system CPython (3.9.6, `/usr/bin/python3`) tokenizes stdin in `fgets` chunks of about 1023 bytes. If a multibyte character straddles a boundary, the chunk fails UTF-8 validation and the whole program is rejected. I reproduced it in isolation: a 3-byte `—` whose lead byte sits at line offset 1021 or 1022 fails, and so does 2044–2045, 3067–3068, and so on (offsets ≡ −2, −1 mod 1023).
- **Where.** The culprit was the `—` in "note tagged `(gate section — written at merge)`" in the **high** executor line (byte offset 24,551 of 31,645; 24,551 ≡ 1,022 mod 1,023). The error is reported one line late, on the mid line. My L33/L60 additions had moved it there. It is unedited text; only its offset changed.
- **Fix used.** A +3-byte shift earlier in both bodies (see deviation 1). The scratch probes that found this are in the session scratchpad, not the repo.
- **Why it matters.** Any later edit to an embedded file (a skill, an agent body, `CLAUDE.md`, a template) can move some `—`, `→` or `…` onto a boundary, and only the retrofit smoke notices. `build.py` compiles the artifact body but never runs it (D3). Routed to the operator as a question in `phase.md`.

## Dead ends

- The plan's example L15 wording, "dispatching its drafting to `design-drafter` (none under `claude-design`, …)", splits the smoke-pinned phrase `dispatching its drafting to `design-drafter` and its mockup build (only on request) to `slice-executor-high``, so the parenthetical goes after the sentence instead.
- I first replaced "and is never pre-planned, since its input has not landed" with "never pre-planned, its input not landed", which reads as an apposition; the final "and is never pre-planned until its input lands" is grammatical and only 8 B longer.
- A one-off grep of the smoke for CLAUDE.md phrases was refused by the classifier as self-modification of guardrail text; see the `CLAUDE.md` section above for how I proceeded.

## Not done, by plan

- D18, D20, D21, D23 and D24 stay deferred: no executor slimming, no never-rule floor pin, no README drift fix beyond the design paragraphs. `installer/build.py` was not edited (D3).
- No `doc-new-version`; the `## Doc impact` notes carry the durable-truth changes. No commit, no state transition.
