# Result — P15.S4: Rewrite the retrofit smoke test Codex-free

**Status: done.** `tests/retrofit_smoke.sh` is fully green — **115 PASS, 0 FAIL, exit 0** — from
24 failing checks at the start of the slice. One file changed; nothing else. No rebuild (the test
is not embedded in the artifact) and no commit.

## Validation

| Command | Outcome |
| --- | --- |
| `bash tests/retrofit_smoke.sh` | **PASS** — 115 PASS / 0 FAIL, exit 0. Run twice (mid-slice and as the closing gate); identical both times. |
| `python3 scripts/workflow.py validate` | **PASS** — `Workflow validation passed.` |
| `grep -rni 'codex\|\.agents\|openai\|gpt-' tests/` | 27 hits, **every one a proof of absence**: the Test 0 negatives, the `.agents`/`.codex`/`AGENTS.workspace.md` non-creation checks, the `[codex.*]` rejection fixture, and the pre-v31 migration fixture. No hit asserts that Codex machinery exists. |
| All eight blocks still fire | **Yes** — Test 0…Test 8 headers all printed; no block reduced to a no-op (see the call-site accounting below). |

Test 7 (`installer/build.py --check`) passes inside the run, so the committed artifact the test
installs from is current — the results are trustworthy.

### `ok`/`bad` call-site accounting (the plan's closing check)

`ok` sites 89 → **91**; `bad` sites 90 → **92**. Net **+2**, fully accounted for: **9 removed**
(Codex payload/metadata/tier existence assertions that no longer describe anything) and
**11 added**:

| Added assertion | What it guards |
| --- | --- |
| `retrofit installs no Codex trees (.agents/, .codex/)` | retrofit never re-grows a Codex tree |
| `retrofit writes no AGENTS.workspace.md sidecar` | the stranded-sidecar path stays closed |
| `a repo's own AGENTS.md left byte-identical` (sha pin, Test 1) | the installer never clobbers a cross-tool `AGENTS.md` — stronger than the tracked-modification list, which only sees *tracked* edits |
| `fresh install is Codex-free (no AGENTS.md, no .agents/, no .codex/)` | the headline fresh-install regression |
| `leftover [codex.*] section rejected with the v31 migration message` | S1's rejection path (`removed in workspace v31`) |
| `--update flags each pre-v31 Codex path as stale exactly once` | S2's whole migration mechanism (see below) |
| `--update never deletes the flagged pre-v31 machinery` | the "never deletes" invariant the mechanism rests on |
| `dual-apply covers all 17 skill bodies` | a count guard, so a future typo in the `find` cannot yield an empty loop and a green result |
| `dual-apply manifest covers every installer FIXED_LIVE_FILES entry` | the hand-maintained Test 6 list against `installer/build.py`'s actual constant |
| `--force-empty-ok installs beside a repo's own AGENTS.md` | the new code path S2 created (finding 1) |
| `install leaves a pre-existing AGENTS.md byte-identical` | same path, the non-destructive half |

Two renamed-and-inverted survivors are not counted as new: the `--update` staleness pair, ported
from the Codex skill tree to the Claude one.

## What changed, block by block

**Test 0** — rewritten around the Claude tree and turned into the phase's negative-space test.
Deleted: the `.agents/skills` count, `claude == codex` parity, the `openai.yaml` loop, the Codex
forbidden-string list, the yaml metadata asserts, the `.codex/agents/*.toml` block. Retargeted:
`len(skills) == 17`, the orchestrator-skill safety subset, the design-cowork strings, the executor
invariants. Added four negatives: (1) `AGENTS.md` / `.agents` / `.codex` do not exist at the repo
root; (2) `"Codex"` appears in no `.claude/skills/*/SKILL.md` except the two that document the
removal; (3) `"Codex"`, `"AGENTS.md"`, `".agents/"`, `".codex/"` appear nowhere in `CLAUDE.md`;
(4) `disable-model-invocation: true` in all 17 skills **except** `design-cowork` — the Claude
analogue of the deleted `allow_implicit_invocation` loop, and previously untested.

**The contract read is fixed.** `(root / "AGENTS.md").read_text()` is gone (it raised) and the
`.split("\n\n", 2)[2]` is gone with it — it existed only to compare the two bodies, and since S3
shortened the header it was landing one paragraph late and passing by luck. Test 0 now asserts
against the full `CLAUDE.md` text.

**Test 1** — kept the sample repo's own `AGENTS.md` and made it the fixture for a sha pin taken
before the retrofit and re-checked after. Modified-file list is now
`.claude/settings.json,.gitattributes,CLAUDE.md,` (3 files). The Codex package/metadata assertions
became non-creation negatives; the sidecar greps moved to `CLAUDE.workspace.md`.

**Test 5** — the version pin's literal `== 30` is **gone**; the three-way equality
(`main_version == top_changelog == marker_version`) already catches every partial bump, so
`P15.S6` can bump `WORKSPACE_VERSION` and append the CHANGELOG heading **with no test edit at
all**. Codex tier/model greps deleted, Claude halves kept. The fresh-install inventory inverted
into the Codex-free negative. `[codex.*]` rejection check added next to the retired-tier one.

**The `--update` staleness block** — ported 1:1 to the Claude side (delete
`.claude/skills/do-whole-phase`, junk `.claude/skills/design-cowork/SKILL.md`, `--update`, assert
restore + byte-equality + the two "not flagged stale" negatives). Its old fixture was a **dead
shell redirect** into the deleted `.agents/` tree, so that whole block had been asserting nothing.
On top of it, a real regression for S2's migration mechanism: seed the pre-v31 shape
(`.agents/skills/<x>/`, `.codex/agents/slice-executor{,-low}.toml`, `AGENTS.md`,
`AGENTS.workspace.md`), then assert the stale line names all four paths **exactly once each** and
that `--update` **deleted nothing**. Verified against the real output:

```
  stale workspace skills/machinery dropped upstream (remove manually?): .agents, .codex, AGENTS.md, AGENTS.workspace.md
```

The seeded paths are removed before the Test 6 restore step. That single count-based assertion
pins three separate S2 decisions at once: `.exists()` instead of `is_file()` (restore `is_file()`
and the two directory entries silently vanish → count 0 → fail), the collapse of the redundant
`.codex/agents/slice-executor{,-low}.toml` entries (both fixture files are seeded, so an
uncollapsed list would report `.codex` three times → fail), and `AGENTS.workspace.md` being
flagged at all.

**Test 6** — the `find` loop is `.claude/skills` only, with a `-eq 17` count guard. The
hand-maintained list is nine entries (the three `.codex` paths and `AGENTS.md` dropped), and a new
`ast`-based cross-check proves that list plus `scripts/workflow.py` covers every
`FIXED_LIVE_FILES` entry in `installer/build.py`. Mutation-checked: feeding it a truncated list
does fail.

**Test 8** — unchanged; the `[ ! -d "$G/.agents/skills" ]` half stays as a permanent negative.

## Deviations from `plan.md`

Three, all forced by the tree the plan describes vs. the tree S3 actually left. None changes the
plan's intent (nothing that was protected became unprotected).

1. **"`Codex` appears in none of the 17 `SKILL.md`" is false today**, and deliberately so: S3
   finding 6 kept two documented mentions — `update-workspace`'s pre-v31 migration step (which
   `S3`'s plan *mandated*) and `explain`'s re-vendor comment. Implemented as
   `codex_prose <= {"update-workspace", "explain"}` (a *subset*, so a Codex mention anywhere else
   still fails, and dropping one of the two is allowed later) plus a pin that
   `"Codex support was removed in workspace v31"` is still in `update-workspace` — the adopter's
   migration instruction, mirroring S1's real error string.
2. **The "safety-critical subset" for `do-next-slice` / `do-whole-phase` is the Claude analogue,
   not the Codex list.** The strings the plan names (the mode-rejection rule, "a bare invocation
   is never approval", the `SIGNOFF.md` gate) are Codex-only and do not exist in the Claude
   bodies. Ported instead, and verified present in **both** files: `WAITING ON OPERATOR`,
   `` `kind: co-work` ``, `never dispatched`, `DesignSync`,
   `` never pass `run_in_background: false` ``, `` never glob `~/.claude/plans/` ``, and
   `` `plan only` `` — the pending halt, the design gate, the background-dispatch rule, and the
   plan-file copy discipline.
3. **The two executor invariants could not both be asserted against both tiers.**
   `.claude/agents/slice-executor-mid.md` has no `co-work`/`DesignSync` clause at all — the Codex
   tomls carried it in both tiers, the Claude files do not. So: both tiers assert the commit ban
   and the state-transition ban plus a Codex/`AGENTS.md` absence negative, and the design gate
   (`never dispatched, because you have no `DesignSync``, `return `needs_operator``) is asserted
   against the **high** tier, where it lives. The asymmetry is pre-existing (not introduced by
   this phase) and is recorded in `phase.md` for `P15.REVIEW` to judge.

Also, per the plan's own suggestion in *Test 5*, the `== 30` literal was dropped rather than moved
— so the `S4`/`S6` cross-slice coupling in the phase's *Open Questions* is now closed.

## Doc impact

**None.** This slice changed only a test file. `docs/current/qa.md`'s description ("a single
committed smoke test (`tests/retrofit_smoke.sh`) plus `python3 scripts/workflow.py validate`")
remains accurate word for word, and no other doc describes the test's contents — so there is
nothing for `P15.REVIEW` to consolidate from `S4`. The phase's existing "Doc impact" lines
(engine, installer, contract) already carry the durable truth this test now enforces.

## Out of scope, untouched

`WORKSPACE_VERSION`, `CHANGELOG.md`, READMEs, `docs/**`, `installer/**`, `.github/workflows/**`.
No rebuild was needed or run. No commit, no state transition, no `doc-new-version`.
