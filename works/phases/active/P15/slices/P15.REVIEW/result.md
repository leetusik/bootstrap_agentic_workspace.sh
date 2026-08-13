# Result — P15.REVIEW: phase review

> **Two rounds.** Round 1 (below) returned `changes_requested` on one finding. Round 2 (at the
> end of this file) verified `P15.F1`'s fix, re-ran every gate, and returned **`pass`** with the
> three consolidated doc versions. Round 1's record is kept verbatim — the finding and the
> reasoning behind it are part of the phase's history.

---

# Round 1 — verdict `changes_requested`

**Verdict: `changes_requested`.** One blocking finding, in the contract itself. Everything else in
this phase is clean: the mechanical removal is complete and correct, the adopter migration path
works end to end against a real pre-v31 install, the out-of-scope boundary held exactly, and two of
the three flagged judgment calls are upheld. The third — generalizing the `pending` design
exception — is overruled, and the argument is in §3.

Per the contract, a non-passing review **stops before doc consolidation**. No `doc-new-version` was
run and no doc file was touched; the whole "Doc impact" list is still outstanding and belongs to the
re-review. No commit, no state transition, no explainer.

---

## 1. Validation — every command actually run, with real output

| # | Command | Outcome |
| --- | --- | --- |
| 1 | `python3 scripts/workflow.py validate` | **PASS** — `Workflow validation passed.` (exit 0) |
| 2 | `python3 installer/build.py --check` | **PASS** — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` (exit 0) |
| 3 | `python3 scripts/workflow.py sync-agents --check` | **PASS** — `mid   sonnet @ xhigh` / `high  opus @ xhigh` / `config source: executors.toml (mode flex, 0 override(s))` / `agent files in sync` (exit 0) |
| 4 | `bash tests/retrofit_smoke.sh` | **PASS** — **115 PASS / 0 FAIL**, exit 0, `ALL RETROFIT SMOKE TESTS PASSED`. Matches the expectation in `plan.md` exactly. |
| 5 | **Fresh install of the artifact** into scratch | **PASS** — see below |
| 6 | **Retrofit** into a git repo with its own `CLAUDE.md` + `AGENTS.md` | **PASS** — see below |
| 7 | **`--update`** over a real pre-v31 install | **PASS** — see below |

### 5 — fresh install (the gate `build.py` cannot provide)

`installer/build.py` only `compile()`s the assembled body (L138) and `sh -n`s the wrapper (L162);
it never executes the artifact. So the artifact was run for real:

- exit 0, no import-time `RuntimeError` / `KeyError`
- `works/.workspace-version.json` → `"workspace_version": 31`
- root inventory is exactly `.claude .gitattributes .github CLAUDE.md docs executors.toml scripts works`
- `AGENTS.md`, `.agents`, `.codex`, `AGENTS.workspace.md` — **all four absent**
- 17 skills in `.claude/skills/`; `.claude/agents/` is exactly `slice-executor-{mid,high}.md`
- installed `CLAUDE.md` opens `# CLAUDE.md` → blank → `## Agent Contract`, and is **byte-identical**
  to this repo's `CLAUDE.md` (`diff` clean) — the strongest available proof that
  `collect_contract_body()`'s `CLAUDE_HDR` slice still lands on the right line after S3 shortened
  the header
- in the fresh workspace: `validate` passes, `sync-agents --check` exits 0 with the S1 format
- `grep -ri 'codex\|AGENTS.md'` over the installed `docs/` returns nothing

### 6 — retrofit leaves a repo's own `AGENTS.md` alone

Seeded a git repo with its own `CLAUDE.md`, its own `AGENTS.md` ("My own cross-tool contract for
Cursor and Amp. Do not clobber me."), and `src/app.py`. After `--into-existing`:

- exit 0, `merged (additive): CLAUDE.md`, 52 files created
- `AGENTS.md` sha `bb47d403…` **before and after — byte-identical**
- no `AGENTS.workspace.md`, no `.agents`, no `.codex`
- `CLAUDE.workspace.md` written and byte-identical to this repo's `CLAUDE.md`
- `validate` passes in the retrofitted repo

### 7 — the adopter migration path, against a real pre-v31 install

Not simulated: installed **`git show c307eb9:bootstrap_agentic_workspace.sh`** (the actual last
dual-harness artifact) into scratch, confirmed marker 30 and `.agents` + `.codex` + `AGENTS.md`
present, then hand-seeded an `AGENTS.workspace.md` (the retrofitted-adopter strand) and a leftover
`[codex.mid]` table, then ran `--update` with the v31 artifact:

```
  machinery updated: 13 file(s)     ← CLAUDE.md, scripts/workflow.py, 9 skills, 2 tier agents
  stale workspace skills/machinery dropped upstream (remove manually?): .agents, .codex, AGENTS.md, AGENTS.workspace.md
```

- marker 30 → **31**
- all four paths flagged, **each exactly once** (the collapsed `.codex/agents/*.toml` entries do not
  double-report)
- **deletes nothing**: Codex file count **37 before, 37 after**; `AGENTS.workspace.md` still present
- `AGENTS.md` sha `aad2a4f7…` unchanged — `--update` no longer rewrites it either

**The `is_file()` → `.exists()` fix is confirmed load-bearing, mechanically**, against that live
tree:

```
.agents              exists=True  is_file=False
.codex               exists=True  is_file=False
AGENTS.md            exists=True  is_file=True
AGENTS.workspace.md  exists=True  is_file=True

under is_file() the flagged set would be: ['AGENTS.md', 'AGENTS.workspace.md']
under .exists()  the flagged set is:      ['.agents', '.codex', 'AGENTS.md', 'AGENTS.workspace.md']
```

Without S2's one-word change the two directory entries are dead code and the migration promise is
silently empty. `S4`'s exactly-once assertion pins it.

**Error severity matches the docs.** With the leftover `[codex.mid]` table: `sync-agents --check`
exits **1** with `executors.toml line 51: Codex support was removed in workspace v31 — …`, while
`validate` prints it as `warning: executor tier config check failed: …` and still exits **0**. That
is precisely the correction `S5` made to its own draft ("aborts every workflow command" was false),
and the guide and `update-workspace/SKILL.md` both say it correctly. Deleting the table restores
`sync-agents` to exit 0.

---

## 2. The objective, judged

> *Remove all Codex-specific machinery, contract text, installer payload, tests, and documentation so
> the workspace ships Claude Code only, and give existing adopters a flagged upgrade path.*

**Removal half — complete.** Non-generated, non-history sweep for `codex` leaves six files, and
every survivor is deliberate:

| File | Hits | Deliberate? |
| --- | --- | --- |
| `tests/retrofit_smoke.sh` | 26 | yes — every one a proof of absence |
| `installer/main.py` | 5 | yes — the 4 `OBSOLETE_MACHINERY` entries + the `flag_obsolete_machinery` note; this *is* the migration deliverable |
| `scripts/workflow.py` | 2 | yes — the `[codex.*]` rejection regex + message |
| `.claude/skills/update-workspace/SKILL.md` | 1 | yes — the mandated pre-v31 migration paragraph |
| `.claude/skills/explain/SKILL.md` | 1 | yes — the re-vendor comment |
| `installer/README.md` | 1 | yes — the `explain` vendoring note (not on the plan's expected-survivor list, but clearly documentation of the removal) |

Zero elsewhere. No `.agents/` / `.codex/` / `AGENTS.md` reference survives outside those.

**Adopter half — verified independently, not trusted.** §1.7 above.

**Nothing regressed for Claude Code users.** Fresh install, retrofit, and `--update` all produce a
working workspace whose `validate` and `sync-agents --check` are clean; the smoke test's 115 checks
cover the drift manifest, the mode matrices, the dual-apply manifest cross-check, and the version
three-way agreement.

---

## 3. The three judgment calls

### 3.1 — The `pending` design exception, generalized rather than deleted — **OVERRULED**

This is the blocking finding.

**What changed.** `CLAUDE.md` @ `c307eb9` L70:

> **Narrow Codex design exception:** … **the Codex orchestrator** may clear and resume that same
> slice inline under **its** `design-cowork` skill.

`CLAUDE.md` @ `HEAD` L67:

> **Narrow design exception:** … **the orchestrator** may clear and resume that same slice inline
> under the `design-cowork` skill.

**Why I disagree — four reasons, in descending weight.**

1. **The stated rationale is factually inverted.** `S3`'s justification (recorded in `phase.md`
   *From `P15.S3`* item 2, and repeated in `plan.md`) is that deleting the sentence "would have
   silently removed a capability the operator never asked to remove." But the capability was
   **Codex's** — the sentence named "the Codex orchestrator … under **its** `design-cowork` skill".
   Claude Code never held it. Removing Codex's capabilities is exactly what `intent.md` asked for.
   Deleting the sentence was the in-scope action; generalizing it **granted the surviving harness a
   new permission**, which is the one thing a removal phase should not do on its own authority.

2. **The permission is now unbacked, and contradicted, by the skills that actually run.** Both
   operative Claude skill bodies still say the opposite:
   - `.claude/skills/do-whole-phase/SKILL.md:16` — "Resume only after the operator clears `pending`
     back to `in_progress`."
   - `.claude/skills/do-next-slice/SKILL.md:14` — "Resume only after the operator approves and
     clears the `pending` status back to `in_progress`."

   Pre-P15 there was no conflict, because the exception was Codex-scoped and the **Codex**
   `do-whole-phase/SKILL.md:18` carried the matching operational clause ("read that literal input …
   set that same slice back to `in_progress`, and resume it inline under `design-cowork`"), plus its
   approval / revision / capability resume paths at L43-45. That tree is now deleted and nothing
   replaced it. So the contract grants a permission on a **safety halt** that the skills deny, with
   no procedure anywhere for exercising it safely — on a design-approval gate, which is precisely
   where `design-cowork`'s "approval must be literal" invariant is load-bearing.

3. **The original scoping was load-bearing, and its justification does not transfer.** Codex was
   automatic-only — it *rejected* `gate` and `plan only` — so an invocation was the operator's only
   channel for a literal approval. Claude Code has `gate`, `plan only`, an interactive session, and
   a plain `set-slice-status <id> in_progress`. The carve-out existed to solve a problem Claude Code
   does not have.

4. **The CHANGELOG misdescribes its own change.** `CHANGELOG.md` L26-32 files this under
   "**The contract keeps every rule that was not Codex-specific.**" The rule *was* explicitly
   Codex-specific. An adopter reading the entry is told a rule was preserved when it was widened.

**Mitigation I weighed and rejected as sufficient.** `CLAUDE.md`'s surrounding general clause
already says "normally the operator does that, **or the orchestrator does it on their explicit
say-so**", so one can argue the exception only adds "resume that same slice *inline*". That softens
the size of the widening but not the two concrete defects: the contract-vs-skill contradiction on a
safety halt, and a CHANGELOG bullet advertising a capability the shipped skills refuse. Both are in
the **released** v31 contract and artifact.

**Credit where due:** `S3` did not do this silently. It flagged the call in `phase.md`, `S6` put it
in the CHANGELOG so adopters would see it, and both explicitly asked the review to challenge it.
That is the process working — the disagreement is with the conclusion, not the conduct.

#### Proposed fix slice `P15.F1` — "Settle the `pending` design exception"

`--kind fix --risk high` (multi-file + embedded machinery ⇒ rebuild required).

The operator picks one of two coherent endings; **do not leave the current middle state**:

- **Option A (recommended — restores the phase to pure removal).** Delete the exception sentence
  from `CLAUDE.md`'s `pending` hard rule. The surrounding "or the orchestrator does it on their
  explicit say-so" already authorizes an operator-directed clear, and `design-cowork`'s "Read back,
  then land it" flow (`SKILL.md` §*Read back, then land it*, steps 1-5) already covers what happens
  on the resume run — so nothing Claude Code actually does today is lost.
- **Option B (keep the capability, deliberately).** Keep the generalized sentence **and** add the
  matching operational clause to `.claude/skills/do-next-slice/SKILL.md:14` and
  `.claude/skills/do-whole-phase/SKILL.md:16` so the contract and the skills agree, porting the
  guardrails from the deleted Codex body (bare/`auto`/unattended invocation is never approval; a
  pending *phase*, any other slice kind, or input that does not answer the recorded need still
  halts).

Either way, in the **same commit**:
- rewrite `CHANGELOG.md`'s v31 bullet at L28-32 to match (the coupling `S6` finding 5 called out) —
  and fix its "keeps every rule that was not Codex-specific" framing;
- run `python3 installer/build.py` and stage the regenerated artifact (`CLAUDE.md` and `.claude/**`
  are both embedded);
- under Option A, tighten `tests/retrofit_smoke.sh`'s `codex_prose` subset assertion only if the
  prose hits change (they do not under either option);
- re-run `validate`, `build.py --check`, and `tests/retrofit_smoke.sh`.

### 3.2 — `AGENTS.workspace.md` added to `OBSOLETE_MACHINERY` — **UPHELD**

It is installer-created machinery, not an operator file: `_merge_contract()` wrote it, and once
`AGENTS.md` handling is gone nothing would ever refresh or flag it — a silent strand, which is what
this list exists to prevent. The mechanism flags with "remove manually?" and provably deletes
nothing (§1.7: 37 files before and after). Not overreach.

The sharper edge is flagging **`AGENTS.md` itself**, which an adopter may legitimately own for
Cursor / Amp / Copilot. I checked whether the phase covered that, and it did, in all three
adopter-facing places — `docs/retrofit-guide.md:129-131` ("Your `AGENTS.md` is never touched … not
read, not appended to, and gets no sidecar") and `:244`, `.claude/skills/update-workspace/SKILL.md:61`
("an `AGENTS.md` your project maintains for other tools is yours to keep"), and `CHANGELOG.md` v31
L29-31. Adequately handled; no change requested.

### 3.3 — Editing the vendored `.claude/skills/explain/SKILL.md` — **UPHELD**

The two dropped passages (the Codex `workspace-write` network caveat, the `<noreply@openai.com>`
attribution) are Codex-only. Leaving them would ship *live instructions* naming a harness that no
longer exists — strictly worse than drift. Forking upstream is out of scope. The divergence is
recorded where a re-vendor will actually look: the file's own comment (`SKILL.md:11-18`) now
enumerates all four divergences and closes "Nothing syncs the two copies — re-vendor by hand", and
`installer/README.md:76` repeats it. `phase.md` alone would have been the wrong home — it gets
archived. Right call.

---

## 4. The out-of-scope boundary — held exactly

Verified over `c307eb9..HEAD`:

| Protected | Result |
| --- | --- |
| `works/phases/active/P13`, `P14`, `works/phases/archived/**` | **no file in the diff** |
| `docs/versions/**`, `docs/current/**` | **no file in the diff** |
| `works/events.jsonl` | **0 removed lines** — pure append |
| pre-v31 `CHANGELOG.md` sections | **0 removed lines** — pure append; the v31 section was inserted above `## v30`, none rewritten |

No violation. Nothing to report here.

---

## 5. The "actively wrong" doc fixes — spot-checked against the code

I checked the three load-bearing ones the plan named, against the source rather than against S5's
description:

1. **Retrofit guide Tier-3 contract-merge promise** (`docs/retrofit-guide.md:118-131`) — the quoted
   marker block matches `_merge_contract`'s literal in `installer/main.py:222-227` **verbatim**
   (`> This repo uses the agentic workspace (\`scripts/workflow.py\` + skills under \`.claude/\`).`
   and the `CLAUDE.workspace.md` sidecar line). My live retrofit (§1.6) produced exactly that.
   The added byte-identical promise is correctly **scoped to retrofit + `--update`** and
   deliberately not to a fresh install — right, because a fresh install into a directory holding
   `AGENTS.md` is still refused by the emptiness guard unless `--force-empty-ok`.
2. **Manual fallback** (`docs/retrofit-guide.md:254-273`) — copy list is `scripts/workflow.py`,
   `.claude/`, `executors.toml`, `docs/`, `works/`, and conditionally `CLAUDE.workspace.md`. Matches
   my fresh install's actual root exactly; naming `.agents/` / `.codex/` / `AGENTS.workspace.md`
   here would have told an operator to hand-create three of the four paths `--update` now flags.
   Correctly fixed.
3. **`installer/README.md` build-safety list** — every claim verifies line by line against
   `installer/build.py`: `compile()` L138 · heredoc-delimiter collision L142-143 · `sh -n` L162-165
   · `EXPECTED_SKILL_COUNT` 17 L88-89 · `CLAUDE_HDR` prefix test L95-96. Its added sentence "**It
   only `compile()`s the artifact — it never runs it**" is true: `build.py` has no execution path.

S5 caught them all. No residual inaccuracy found in the passages checked.

---

## 6. Doc consolidation — **not performed**

Correct for a non-passing verdict. No `doc-new-version`, no `rebuild-docs`, no file under
`docs/versions/**` or `docs/current/**` touched.

For the re-review, I verified the "Doc impact" list is otherwise complete and appended **one
correction** to it in `phase.md`: `docs/current/architecture.md` has a **third** stale line the list
did not name — **L58** (`it has no .agents/skills/<name>/ mirror`), alongside the recorded L23 and
L35. Review-time counts: `architecture` 3, `operations` 51, `decisions` 105 (all historical entries
— the plan is right that `decisions` takes a **new appended** entry and no rewrite of the 33). The
other eight `docs/current/*.md` are clean, as recorded. Three docs to version when this passes:
`architecture`, `operations`, `decisions`.

---

## 7. Open questions — closed or carried

| Question | Disposition |
| --- | --- |
| `AGENTS.workspace.md` strand | **closed** by S2 (flagged); upheld here (§3.2) |
| literal release pin in the smoke test | **closed** by S4 (dropped); confirmed — S6 needed no test edit and the run is green |
| `installer/build.py` only `compile()`s the artifact | **carried — recommend filing as `D3`.** Confirmed still true; pre-existing and correctly out of scope. Harmless for *this* phase, since the review re-ran all three artifact paths for real. Suggested title: *"Make `installer/build.py` smoke-execute the assembled artifact so the build gate catches a broken artifact, not only a non-compiling one."* Trigger: next edit to `build.py` or the payload plumbing. Workaround is now documented for contributors at `installer/README.md:47-48`. |
| retrofit guide Troubleshooting omits the `.gitattributes` line-merge | **carried.** Pre-existing, non-Codex, one clause. Not folded into `P15.F1` (different file, unrelated cause) — attach it there only if the operator wants one pass. |
| `slice-executor-mid` co-work refusal gap | **already `D2`**, open. No action this phase. |

---

## 8. Deviations from `plan.md`

**None.** Every step was executed as written: the five validation commands plus the three real
artifact executions (§1), the completeness sweep and adopter-path verification (§2), all three
judgment calls challenged (§3), the boundary check over the phase's commit range (§4), the
load-bearing doc spot-checks (§5), and the open questions (§7). Step 6 (doc consolidation) was
**correctly skipped** because the verdict is not `pass` — the plan mandates exactly that.

One judgment worth naming: I completed the entire review, including the doc-impact completeness
check and the open-question dispositions, **before** returning the non-pass, so the orchestrator
gets the whole picture in one cycle rather than one finding per cycle.

## 9. Boundaries respected

No commit. No `review-phase`, `start-slice`, `finish-slice`, `set-slice-status`, or
`set-phase-status`. No `doc-new-version` / `rebuild-docs`. No source code edited (a review slice
writes only docs + `result.md` / `phase.md`). No phase explainer — `explain: not written — run
/explain for this phase`.

Files written by this slice: this `result.md`, and the `From P15.REVIEW` section + two `Doc impact`
corrections + four `Open Questions` updates in `works/phases/active/P15/phase.md`.

---

# Round 2 — verdict `pass`

**Verdict: `pass`.** Finding 1 is resolved — not merely deleted, but resolved in the sense that
mattered: the contract, both operative skill bodies, the released CHANGELOG entry, and the smoke
test now say the same thing about the `pending` gate. Every gate is green, the artifact was
executed again, the out-of-scope boundary still holds over the whole phase range, and the three
durable docs are consolidated.

## 1. Finding 1 — checked, not assumed

`P15.F1` took option A (delete). Five checks, each run against the tree rather than against the
fix slice's own account:

| # | Check | Result |
| --- | --- | --- |
| 1 | The exception is gone from `CLAUDE.md` and the bullet reads continuously | **PASS** |
| 2 | Contract ↔ both skill bodies agree | **PASS** |
| 3 | The v31 CHANGELOG section is accurate, and corrected **in place** | **PASS** |
| 4 | The new smoke assertions are load-bearing (my own mutation run) | **PASS** |
| 5 | Nothing anywhere still asserts the deleted rule | **PASS** |

**1 — the deletion.** `CLAUDE.md:67` is now one continuous rule ending
*"…normally the operator does that, or the orchestrator does it on their explicit say-so. `pending`
means "waiting on the operator" and is distinct from `blocked` …"*. Diffed sentence-by-sentence
against `c307eb9`'s L70: exactly two sentences left (`**Narrow Codex design exception:** …` and
`A bare automatic invocation is never approval, and no other pending gate is relaxed.`) and
**nothing else in the bullet moved** — the surviving text is byte-identical to the pre-phase
version. No seam, no residue.

**2 — the agreement, which was the substance of the finding.** Read all three live files:

- `CLAUDE.md:67` — "Work resumes only after explicit operator input clears the same item back to
  `in_progress`; normally the operator does that, or the orchestrator does it on their explicit
  say-so."
- `.claude/skills/do-next-slice/SKILL.md:14` — "Resume only after the operator approves and clears
  the `pending` status back to `in_progress`."
- `.claude/skills/do-whole-phase/SKILL.md:16` — "Resume only after the operator clears `pending`
  back to `in_progress`."

No contradiction remains. I also re-verified the historical claim the fix rests on, from git rather
than from the phase's notes: at `c307eb9` the two Claude skill bodies carried **exactly the same
"resume only after the operator clears" sentences they carry now** (unchanged by this phase), while
the deleted `.agents/skills/do-whole-phase/SKILL.md:18` carried the matching operational clause and
called it, in its own words, *"exactly one **Codex-only** resume exception"*. So the permission was
Codex's, its backing clause died with the Codex tree, and deleting the contract sentence orphans
nothing. Round 1's diagnosis holds up under its own evidence standard.

The surviving "or the orchestrator does it on their explicit say-so" is **not** a residual
carve-out: it is gated on explicit operator input and only names who types the command. It is
pre-P15 text and was never in conflict with either skill.

**3 — the CHANGELOG.** The v31 bullet now reads *"The contract keeps every rule that was not
Codex-specific, **and drops the one that was**"* and states plainly which rule went, why it was
Codex-only, and that the `pending` gate is uniform again "exactly as the `do-next-slice` and
`do-whole-phase` skills have always said" — which I verified is true of both files. Corrected **in
place**: `git show 2be44fc -- CHANGELOG.md` is a single 7→8-line bullet rewrite inside `## v31 —
2026-08-14`; no version number, no date, no other section. And over the phase's whole range
(`c307eb9..HEAD`) `CHANGELOG.md` is **51 insertions / 0 deletions** — the intermediate S6 wording
never existed outside this working history, so the released file is a pure append.

**4 — the mutation check, run by me.** I extracted Test 0's Python block from
`tests/retrofit_smoke.sh` (lines 40-113) verbatim and ran it against a scratch copy of `.claude/` +
`CLAUDE.md`:

- unmutated → exit 0;
- with the exception sentence re-injected after the "explicit say-so" anchor → **exit 1**,
  `AssertionError: design exception`.

So the negatives are load-bearing, not vacuous, and a reintroduction cannot land silently. The
positive assert (`"Work resumes only after explicit operator input clears the same item"`) pins the
surviving rule from the other side.

**5 — the sweep.** `grep -rn 'Narrow design exception|Narrow Codex design exception|never approval|
no other pending gate'` over every `*.md` / `*.sh` / `*.py` / `*.toml` / `*.json` / `*.yml` in the
repo: the only **live** hits are the smoke test's own negatives (`tests/retrofit_smoke.sh:110`).
Everything else is history — `docs/versions/operations/v0025_*` (never patched), this phase's and
P14's planning records — plus `docs/current/operations.md:145`, which was generated from the stale
v0025 body and is exactly what this round's `operations` consolidation replaces. The rebuilt
artifact has **0** hits. `.claude/`, `README*.md`, and `docs/retrofit-guide.md` have none at all.

## 2. Gates — re-run, with real output

| # | Command | Outcome |
| --- | --- | --- |
| 1 | `python3 scripts/workflow.py validate` | **PASS** — `Workflow validation passed.` (exit 0) |
| 2 | `python3 installer/build.py --check` | **PASS** — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` (exit 0) |
| 3 | `bash tests/retrofit_smoke.sh` | **PASS** — **115 PASS / 0 FAIL**, exit 0, `ALL RETROFIT SMOKE TESTS PASSED` — the number `plan.md` predicted |
| 4 | `python3 scripts/workflow.py sync-agents --check` | **PASS** — `mid   sonnet @ xhigh` / `high  opus @ xhigh` / `config source: executors.toml (mode flex, 0 override(s))` / `agent files in sync` (exit 0) |
| 5 | **Fresh install of the rebuilt artifact** | **PASS** — see below |
| 6 | Test 0 mutation check (extracted, run standalone) | **PASS** — clean copy exit 0, mutated copy exit 1 |
| 7 | `python3 scripts/workflow.py validate` **after** doc consolidation | **PASS** |
| 8 | `python3 installer/build.py --check` **after** doc consolidation | **PASS** — docs are not embedded; artifact untouched |

**5 — the artifact was executed, not just built.** `bash bootstrap_agentic_workspace.sh <scratch>`:
exit 0, clean banner, no import-time error; `works/.workspace-version.json` →
`"workspace_version": 31`; root inventory exactly
`.claude .gitattributes .github CLAUDE.md docs executors.toml scripts works` (Codex-free); 17 skills;
installed `CLAUDE.md` **byte-identical** to this repo's (`diff` clean) with **0** hits for
`design exception|never approval|no other pending gate|Codex|AGENTS.md`; inside the fresh workspace
`validate` passes and `sync-agents --check` exits 0.

**Retrofit and `--update` were not re-run, deliberately and on evidence.** `plan.md` allows skipping
them if `installer/` did not change since round 1; `git diff --stat 237d57b..HEAD -- installer/` is
**empty**, and so is the same diff over `.claude/`. The only machinery `P15.F1` touched is the
contract body (plus the rebuild it forces), so round 1's live pre-v31 `--update` and retrofit
verification stands unchanged — and the fresh install above re-proves the one thing a contract edit
can break (`collect_contract_body()`'s `CLAUDE_HDR` slice).

## 3. Boundary and judgment calls — re-confirmed

**Out-of-scope boundary, over `c307eb9..HEAD`:** no file under `works/phases/active/P13`,
`P14`, `works/phases/archived/`, `docs/versions/**`, or `docs/current/**` appears in the phase's
diff (the doc versions this round creates are the review's own sanctioned consolidation, not phase
work). `works/events.jsonl`: **29 insertions / 0 deletions**. `CHANGELOG.md`: **51 / 0** — append-only
across the range, F1's in-place v31 correction included, exactly as intended.

**Judgment calls 2 and 3 — untouched and still upheld.** `git diff 237d57b..HEAD -- installer/
.claude/` is empty, so `AGENTS.workspace.md`'s `OBSOLETE_MACHINERY` entry and the vendored
`explain/SKILL.md` edit are byte-identical to what round 1 examined. Not re-litigated.

**Every surviving `Codex` string is still deliberate.** Live, non-generated, non-history sweep:
`tests/retrofit_smoke.sh` (proof-of-absence negatives), `installer/main.py` (5 — the
`OBSOLETE_MACHINERY` entries and the `flag_obsolete_machinery` `.exists()` note),
`scripts/workflow.py` (2 — the `[codex.*]` rejection), `.claude/skills/{update-workspace,explain}/SKILL.md`
(1 each), `installer/README.md` (1), `docs/retrofit-guide.md` (7 — the adopter migration paragraph),
`CHANGELOG.md` (release history). Zero elsewhere. Artifact: 474619 → **323796 bytes** on disk
(`build.py`'s printed 322345 is a *character* count — S6 finding 4), so the CHANGELOG's
"~475 KB to ~324 KB" is accurate.

## 4. Doc consolidation — three versions, with the retraction honoured

Consolidated per the "Doc impact" list in `phase.md`, **including `P15.F1`'s retraction**: the
`P15.S3` line's item (a) — *"the `pending` design exception is now harness-general"* — was **not**
carried into any version; the `operations` version records the opposite, which is the shipped truth.
Item (b) of that line (the `update-workspace` pre-v31 migration step) was carried. `P15.S5`'s line
concerns the shipped **seed payload** (`installer/payloads/doc_bodies/*.md`) and was correctly not
double-counted against this repo's own docs.

| Doc | Version | What it now records |
| --- | --- | --- |
| `architecture` | **v0003 → v0004** | One contract (`CLAUDE.md`, no `AGENTS.md` twin) · one entry-point tree (`.claude/`, 17 skills + 2 tier agents) · the single-harness distributable (payload is `.claude/**` only; no parity and no byte-equality assertion; the two surviving invariants are `EXPECTED_SKILL_COUNT = 17` and the `CLAUDE_HDR` prefix test) · and that the build only `compile()`s the artifact, never runs it (`D3`). **All three stale lines fixed**, L58 included. |
| `operations` | **v0025 → v0026** | The largest rewrite: the v31 single-harness status; the executor-tier story (one model/effort pair per tier, `[claude.<tier>]` kept, `[codex.*]` rejected by name with the exact v31 message and its exact severity — `sync-agents` exits 1, `validate` warns and exits 0; the new one-line-per-tier `sync-agents` output); the install/retrofit/update contract (a repo's own `AGENTS.md` byte-identical on both paths with the `--force-empty-ok` caveat named, the four flagged paths each exactly once, `.exists()`-not-`is_file()` called out as load-bearing, never deletes); the visual-design runbook rewritten from the shipped Claude skill (handoff → `pending` → DesignSync read-back → land as-is → SIGNOFF → pure regroup → separate implement slice); and **the corrected `pending`-gate truth**. |
| `decisions` | **v0033 → v0034** | **One appended entry** — *"Drop Codex support; ship Claude Code only (phase P15)"* — with the dual-harness parity tax as rationale, the `OBSOLETE_MACHINERY` / workspace-v31 flagging as the migration mechanism, five rejected alternatives (including the generalized-exception option this review overruled), and `D2`/`D3` named as filed follow-ups. Two supersession bullets added to *Superseded Decisions*, naming what P13/P14 lose and what carries forward unchanged. **The 33 historical entries were not rewritten** — verified: 32 pre-existing `###` entries in, 33 out. |

Mechanics: `doc-new-version` → edit **only** the returned `edit_path` → `rebuild-docs` → `validate`.
No file under `docs/versions/` was patched (`git status` shows the three new versions as untracked
additions and **no modification** anywhere else under `docs/versions/`), and `docs/current/*.md` was
never hand-edited — the three snapshots changed only by regeneration. Verified after the rebuild:
`docs/current/{architecture,operations,decisions}.md` carry frontmatter `v0004` / `v0026` / `v0034`
with `source: P15.REVIEW`, `docs/index.json` lists 4 / 26 / 34 versions, the retracted
"harness-general" claim appears nowhere, and the Codex-era inline-resume paragraph that sat at
`docs/current/operations.md:141-146` is replaced by the uniform-gate text.

**One disclosed deviation:** while rewriting the `architecture` body I corrected one adjacent stale
clause that is *not* Codex-related — `installer/payloads/` was still described as containing
"`p1_seed/` phase+intent scaffolds", deleted in v6 (the `operations` doc has said so since). It is a
single clause in a body I was authoring anyway; signing a new version that I knew to be false read
worse than the scope nit. Named here so the correction is auditable.

## 5. Open questions — final disposition

| Question | Disposition |
| --- | --- |
| `AGENTS.workspace.md` strand | **closed** (S2: flagged; upheld both rounds) |
| Literal release pin in the smoke test | **closed** (S4: dropped; S6 needed no test edit, proved by a green run) |
| The `pending` design exception | **closed** by `P15.F1` — deleted, contract/skills/CHANGELOG/test aligned, mutation-checked |
| `installer/build.py` only `compile()`s the artifact | **filed as `D3`** (`works/deferred/open/D3`), trigger recorded; also now stated in `docs/current/architecture.md` and `operations.md` so it survives the phase's archiving |
| `slice-executor-mid` has no `co-work` refusal clause | **filed as `D2`** (`works/deferred/open/D2`) |
| Retrofit guide's Troubleshooting row omits the `.gitattributes` line-merge | **still carried, and the only item with no durable home.** Pre-existing, non-Codex, one clause. `phase.md`'s Open Questions are archived with the phase, so unlike `D2`/`D3` this note will be lost. **Recommendation for the orchestrator (not a finding, and not a gate on this verdict):** one `defer-job` call parks it — `--title "retrofit guide Troubleshooting omits the .gitattributes line-merge" --reason "…the only intended modification is the additive .claude/settings.json merge and the marked CLAUDE.md section' omits the .gitattributes line-merge that the smoke test pins" --trigger "next edit to docs/retrofit-guide.md" --source P15.REVIEW`. I did not run it: `defer-job` is outside a review executor's two carve-outs. |

Nothing else needs filing.

## 6. Deviations from `plan.md` (round 2)

One, explicitly authorized by the plan: **retrofit and `--update` were not re-executed**, because
`git diff --stat 237d57b..HEAD -- installer/` is empty (§2). Everything else was run as written. The
`architecture` clause correction in §4 is a disclosed addition, not a departure from an instruction.

## 7. Boundaries respected (round 2)

No commit, no `git add`. No `review-phase`, `start-slice`, `finish-slice`, `set-slice-status`,
`set-phase-status`, `defer-job`, or `new-slice`. No source code edited — the only writes are the
three new `docs/versions/**` files, the regenerated `docs/current/*.md` + `docs/index.json` (via
`rebuild-docs`), this `result.md`, and the round-2 notes in `phase.md`. No phase explainer:
`explain: not written — run /explain for this phase`.
