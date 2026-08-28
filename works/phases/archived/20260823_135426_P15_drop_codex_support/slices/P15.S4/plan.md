# Plan — P15.S4: Rewrite the retrofit smoke test Codex-free

One file: `tests/retrofit_smoke.sh` (390 lines). Nothing else. It is **not** embedded in the
artifact, so this slice needs no rebuild.

Read `works/phases/active/P15/phase.md` (finding 9 lists the Codex-bearing line ranges) and the
`P15.S1`/`P15.S2`/`P15.S3` cross-slice notes first.

## Current state

The test is red: **24 failing checks**, all pre-existing fallout from S1–S3, which are now
committed. There is no `set -e` — `bad()` increments a counter and execution continues to the
end, so you get the full failure list in one run. It runs the **committed artifact** (`$BOOT`),
not a fresh build, so `python3 installer/build.py` must be current before you interpret results
(it is — S3 committed the rebuild).

**Author every asserted contract string against the post-S3 `CLAUDE.md` in the working tree.**
S3 rewrote that file; strings like `"Claude Code branch:"`, `"built-in ImageGen"`,
`"verified GPT Image 2"`, `"Prompt-only size/quality wording is advisory"`, and
`"without upscaling"` are gone or changed. Do not copy the old list — read the file.

## The goal, stated plainly

After this phase the valuable regressions are the ones proving **Codex is gone and stays gone**.
So wherever an assertion currently proves a Codex thing exists, prefer **inverting it into a
negative** over deleting it. A deleted assertion protects nothing; a negative one keeps the
removal from silently regressing.

## Test 0 (~L38-106) — rewrite, ~60% survives

Not the ~90%-Codex the decomposition estimated: most of the required-string lists are
contract/design-process text that lived in both trees.

**Delete:** the `.agents/skills` count and `claude == codex` parity (L45, L47-48); the
`openai.yaml` loop (L49-54); the Codex *forbidden*-string list (L67-68); the yaml metadata
asserts (L82-83); the `.codex/agents/*.toml` block (L85-89).

**Retarget to the Claude tree:** the `len(claude) == 17` assert; the
`do-next-slice`/`do-whole-phase` required-string list (L60-65) — port only the
**safety-critical subset** (the mode-rejection rule, "a bare invocation is never approval",
the `SIGNOFF.md` gate), not the whole list, which would just be brittle; the design-cowork
required strings (L72-81) against `.claude/skills/design-cowork/SKILL.md`; the two executor
invariants (L87-88) against `.claude/agents/slice-executor-{mid,high}.md`.

**Fix the contract read (L91-93).** `(root / "AGENTS.md").read_text()` now raises outright, and
`(root / "CLAUDE.md").read_text().split("\n\n", 2)[2]` is off by one paragraph since S3 shortened
the header — it passes only by luck. The split existed *solely* to compare the two bodies; with
`AGENTS.md` gone there is nothing to compare, so **drop the split entirely** and assert against
the full `CLAUDE.md` text.

**Add the negatives that make Test 0 earn its keep:**
1. `AGENTS.md`, `.agents/`, and `.codex/` do not exist at the repo root.
2. `"Codex"` appears in **none** of the 17 `.claude/skills/*/SKILL.md` (widen from the old
   `"In Codex"`).
3. `"Codex"`, `".agents/"`, and `".codex/"` appear nowhere in `CLAUDE.md`.
4. Invocation metadata: `disable-model-invocation: true` in all 17 skills **except**
   `design-cowork` — the direct Claude analogue of the deleted `allow_implicit_invocation` loop,
   and currently untested.

Rename the `ok`/`bad` strings at L38 and L106 — they say "17+17 skills … Codex execution
semantics".

## Test 1 — retrofit (L109-177)

- Keep the sample repo's own `AGENTS.md` at L116. It is now the **fixture** for the best new
  regression in the file.
- L135's modified-file list → `.claude/settings.json,.gitattributes,CLAUDE.md,`.
- **Add a sha pin on `$R/AGENTS.md`** taken before the retrofit and re-checked after: the
  installer must leave a repo's own `AGENTS.md` byte-identical. The comma-list only covers
  *tracked* modifications; this is the stronger and more direct assertion.
- L165-167 and L175-177 (Codex packages, `AGENTS.workspace.md` contents) → **invert**:
  `.agents/` and `.codex/` are not created, and `AGENTS.workspace.md` is not created. Keep the
  `CLAUDE.workspace.md` greps, minus `'Codex branch:'`.
- L168-171 → Claude 17 only. L172-174 → delete (Test 6's loop already covers it).

## Test 5 — fresh install + modes (L215-337)

**This block is one long stateful chain over `$F`, and L328-329 deliberately restores files for
Test 6.** Anything you insert must sit before that restore or clean up after itself.

- **Version pin (L232): drop the literal `== 30`.** The three-way equality
  (`main_version == top_changelog == marker_version`) already catches every partial bump, and
  dropping the literal removes the S4/S6 cross-slice coupling entirely. Update the `ok`/`bad`
  strings at L234, which hardcode "v30". After this, `P15.S6` bumps `WORKSPACE_VERSION` and
  appends the CHANGELOG heading with no test edit at all.
- L236-239 → Claude 17 only. L245, L249-253, L265-266, L275-276 → delete the Codex tier/model
  greps; keep the Claude halves at L263-264 and L273-274. L254-255, L330 → keep the `.claude/…`
  halves only.
- L240-243 → **invert** into the headline fresh-install regression: no `AGENTS.md`, no
  `.agents/`, no `.codex/` in a fresh workspace.
- L331-332, L335-336 → delete (subsumed by the `.agents` negative).
- **Add the `[codex.*]` rejection check**, mirroring the existing retired-tier check at L279:
  write `[codex.high]` into `$F/executors.toml`, run `sync-agents --check`, and grep for
  `removed in workspace v31`. It is green immediately (S1 shipped it). The string records *when*
  removal happened, so it will not drift as the workspace version advances.

### The `--update` staleness block (L288-303) — the operator's headline deliverable

Today this block is entirely Codex-skill-based, and its fixture setup at L289-290 is currently
failing as a **shell redirect error**, meaning it is testing nothing at all.

Port it 1:1 to the Claude side: `rm -rf "$F/.claude/skills/do-whole-phase"`; overwrite
`"$F/.claude/skills/design-cowork/SKILL.md"` with junk (no yaml sidecar on the Claude side);
`--update`; then assert restore, byte-equality against the repo copy, and the two "not flagged
stale" negatives. L292-293 (executors.toml seed-once) is already Codex-free — keep verbatim.

Then **add a real regression for the migration mechanism S2 built**, because nothing currently
asserts that an `OBSOLETE_MACHINERY` entry ever fires:

- Before the `--update`, seed the pre-v31 shape: `.agents/skills/<x>/`, `.codex/agents/`,
  `AGENTS.md`, `AGENTS.workspace.md` (files inside the directories).
- Assert the stale line names all four.
- Assert `--update` **deleted nothing** — all four still present afterwards. "Never deletes" is
  the invariant the whole mechanism rests on.
- Assert `AGENTS.workspace.md` appears **exactly once** — the direct pin on S2's collapse of the
  redundant `.codex/agents/slice-executor{,-low}.toml` entries, which would otherwise
  double-report.
- The two **directory** entries pin S2's `is_file()` → `.exists()` fix for free: restore
  `is_file()` and `.agents`/`.codex` silently vanish from the line and this fails. That is the
  cheapest possible guard on the fix that makes the whole migration promise real.
- Clean up the seeded paths before L328-329.

## Test 6 — drift manifest (L340-361)

L346's `find` loop → `find .claude/skills -type f -name SKILL.md`. **Add a count guard**
(`-eq 17`): with `.agents/skills` dropped from the argument list, a future typo would silently
produce an empty loop, zero assertions, and a green result.

The hand-maintained list (L351-357) drops the two `.codex/agents/*.toml`, `.codex/config.toml`,
and `AGENTS.md`, leaving nine entries. **Closing step: cross-check that list against
`installer/build.py`'s `FIXED_LIVE_FILES`** — S2 edited that constant, and the manifest's whole
job is to cover it.

## Test 8 (L375-380)

`[ ! -d "$G/.agents/skills" ]` → keep `[ ! -d "$G/.claude/skills" ]`, and keep the `.agents`
half as a permanent negative.

## One more worth adding

S2's finding 1: `--force-empty-ok` into a directory holding only an `AGENTS.md` **now installs**
where it previously aborted. That is a new, untested code path created by this phase. Add a
cheap assertion covering it.

## Out of scope

`WORKSPACE_VERSION` and `CHANGELOG.md` (S6 — and after dropping the `== 30` literal, S6 needs no
test change). READMEs and doc bodies (S5). No `.github/workflows/` edit is needed — the workflow
already runs this script and has zero Codex references.

## Validation

- `bash tests/retrofit_smoke.sh` — **fully green, zero failures.** S1–S3 are committed, so
  nothing external is holding it red. Run it on a clean tree as the final step.
- `python3 scripts/workflow.py validate` passes.
- `grep -rni 'codex\|\.agents\|openai\|gpt-' tests/` — the only permitted hits are the deliberate
  negative assertions and the `[codex.*]` rejection check. Every hit must be one that proves
  Codex is *absent*.
- Confirm the test still exercises all eight blocks and that no block was reduced to a no-op —
  count the `ok`/`bad` call sites before and after and account for the difference.

## Notes for `phase.md`

Record: that the version pin's literal is gone (so S6 needs no test edit); the new negative
assertions and what each one guards; the `OBSOLETE_MACHINERY` regression and that it pins the
`.exists()` fix; and the corrected `CLAUDE.md` read in Test 0.
