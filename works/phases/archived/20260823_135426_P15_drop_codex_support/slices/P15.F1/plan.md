# Plan — P15.F1: Settle the `pending` design exception

Fix slice, opened by `P15.REVIEW` finding 1. Read that finding in
`works/phases/active/P15/slices/P15.REVIEW/result.md` before starting.

## What went wrong

`P15.S3` generalized the contract's "Narrow **Codex** design exception" into a harness-general
rule instead of deleting it. The orchestrator's rationale was that deleting it would remove a
capability the operator never asked to lose. **That premise was inverted.** The pre-phase
sentence (at `c307eb9`, `CLAUDE.md:70`) granted the permission to *"the **Codex** orchestrator …
under **its** `design-cowork` skill"*. Claude Code never held it. So deleting it removes a
**Codex** capability — precisely what this phase was asked to do — while generalizing it granted
the surviving harness a **new** permission.

Worse, the widened rule is unbacked and self-contradictory:

- `.claude/skills/do-whole-phase/SKILL.md:16` and `.claude/skills/do-next-slice/SKILL.md:14`
  both still say *"Resume only after the operator clears `pending`."*
- The operational clause that backed the exception lived solely in the deleted
  `.agents/skills/do-whole-phase/SKILL.md`. Nothing replaced it on the Claude side.
- The original scoping was load-bearing: Codex rejected `gate` and `plan only`, so the
  invocation really was the operator's only channel. That is not Claude Code's situation.

## The fix: option A — delete the exception

The review offered two options; **take A**. The phase's job is to drop Codex, and this rule was
a Codex carve-out. Deleting it restores exactly the pre-phase Claude-side behaviour and makes
the contract agree with both skill bodies again. Option B (keep the rule and add the backing
clause to both skills) would ship a capability the operator never asked for, inside a removal
phase. Do not implement B.

## Edits

### 1. `CLAUDE.md` — the operator co-work bullet

Delete the two sentences beginning **"Narrow design exception:"** through **"…and no other
pending gate is relaxed."** Keep everything else in that bullet intact — in particular the
preceding sentence (*"Work resumes only after explicit operator input clears the same item back
to `in_progress`; normally the operator does that, or the orchestrator does it on their explicit
say-so"*) and the closing `pending`-vs-`blocked` distinction. That preceding sentence already
covers what Claude Code actually does, which is why nothing is lost.

Read the bullet after editing and confirm it reads as one continuous rule, with no seam where
the exception was.

### 2. `CHANGELOG.md` — the v31 section

Two things, both in the `## v31 — 2026-08-14` section:

- **Remove the bullet describing the generalized exception** (~L28-32 region — locate it by
  content, not line number, since your `CLAUDE.md` edit does not move it but earlier edits may).
  The change it announces will no longer have happened.
- **Fix the framing of the bullet that files this under "The contract keeps every rule that was
  not Codex-specific."** That claim misdescribed a rule that *was* explicitly a Codex carve-out.
  With the exception now deleted, check whether the claim becomes simply true, or whether the
  wording still needs adjusting to be accurate. Do not rewrite the rest of the section.

Do not touch any other CHANGELOG section, and do not change the version number or date — v31 has
not shipped anywhere, so it is corrected in place rather than superseded.

### 3. Check for other references

Grep for the exception's distinctive strings — `"never approval"`, `"design exception"`,
`"no other pending gate"` — across `CLAUDE.md`, `.claude/**`, `tests/`, `docs/retrofit-guide.md`,
and both READMEs. **In particular check `tests/retrofit_smoke.sh`**: `P15.S4` ported a
safety-critical subset of contract strings into Test 0's required list, and if any of them
pins the exception's wording, the assertion must go in this same commit or the test breaks.

## Rebuild

`CLAUDE.md` is embedded in the artifact, so finish with `python3 installer/build.py` and leave
the regenerated `bootstrap_agentic_workspace.sh` for the orchestrator to stage in the same
commit. `CHANGELOG.md` is not embedded.

Per the standing rule (`build.py` only `compile()`s), **run the artifact**: fresh-install into a
temp dir under the scratchpad and confirm the installed `CLAUDE.md` is byte-identical to the
repo's and carries no trace of the exception.

## Out of scope

Do not touch the two upheld judgment calls (`AGENTS.workspace.md` in `OBSOLETE_MACHINERY`; the
vendored `explain/SKILL.md` edit). Do not start the doc consolidation — the re-review does that
on a pass. Do not fix the pre-existing items parked as `D2` and `D3`.

## Validation

- `python3 scripts/workflow.py validate` — passes.
- `python3 installer/build.py` then `--check` — both pass.
- `bash tests/retrofit_smoke.sh` — **115 PASS / 0 FAIL** (or a deliberate, explained count change
  if you had to drop an assertion that pinned the exception's wording).
- Fresh install of the rebuilt artifact — exit 0, installed `CLAUDE.md` byte-identical to the
  repo's, `validate` clean inside.
- `grep -rn 'design exception\|never approval\|no other pending gate' CLAUDE.md .claude/ tests/
  CHANGELOG.md README*.md docs/retrofit-guide.md` — no hit that still asserts the deleted rule.
- Confirm the contract and the two skill bodies now agree: `CLAUDE.md`'s `pending` rule and
  `do-next-slice`/`do-whole-phase`'s *"Resume only after the operator clears `pending`"* say the
  same thing.

## Notes for `phase.md`

Record that finding 1 is resolved by deletion (option A), why A over B, and that the v31
CHANGELOG section was corrected in place rather than superseded.
