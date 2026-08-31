# Result — P20.S3 (ship workspace v37: version, changelog, consistency sweep)

- **status:** `done`
- **summary:** Shipped workspace **v37** — `WORKSPACE_VERSION = 37` bumped before the rebuild, one
  `## v37 — 2026-09-01` CHANGELOG section covering S1 and S2 (Migration notes included the sharp
  "remove any v36 `aside mcp` registration"), artifact rebuilt — and ran the seven-check consistency
  sweep over the settled tree, which found **no defect**, so no landed prose was rewritten; added one
  assertion (every changelog section carries a **Migration notes** line), taking the smoke suite to
  **140 PASS / 0 FAIL**.
- **files_changed:**
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/installer/main.py`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/CHANGELOG.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/tests/retrofit_smoke.sh`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh` (rebuilt, never hand-edited)
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/works/phases/active/P20/phase.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/works/phases/active/P20/slices/P20.S3/result.md`
- **validation:**
  - `python3 installer/build.py` — PASS (wrote `bootstrap_agentic_workspace.sh`, 448341 bytes, **after** the version bump)
  - `python3 installer/build.py --check` — PASS (artifact in sync with `installer/` source; re-run after the test edit)
  - `python3 scripts/workflow.py sync-agents --check` — PASS (mid sonnet@xhigh / high opus@xhigh, mode flex, no drift)
  - `bash tests/retrofit_smoke.sh` — PASS, **140 PASS / 0 FAIL**, `ALL RETROFIT SMOKE TESTS PASSED`
    (139 at v36; +1 is the one new `ok`/`bad` block described in *Assertion upkeep* below). The
    three-way version check reports `PASS: release version agrees across installer, top changelog
    heading, and fresh marker` — i.e. installer 37 == top changelog 37 == fresh-install marker 37.
  - `bash -n tests/retrofit_smoke.sh` — PASS (nested-heredoc syntax check before the full run)
  - `python3 scripts/workflow.py validate` — PASS (`Workflow validation passed.`, no notebook warning)
  - the seven-check consistency sweep — reported check by check below
- **deviations:** none from `plan.md`. The one judgment the plan left open (§4 assertion upkeep) I
  exercised: I added exactly one assertion block; reasoning below.
- **doc_impact:** four lines appended to `## Doc impact` in
  `works/phases/active/P20/phase.md` — `operations.md` (pre-v37 migration bullet),
  `operations.md` (the "halt condition did not move" passage), `qa.md` (smoke baseline 139 → 140),
  `decisions.md` (D9 + D10's surface half, D12 re-file). Quoted in *Doc impact* below.
- **No browser was run and no browser claim is made.** No Aside invocation of any kind was made in
  this slice — not even `--help`; `aside account use` was never run.

---

## 1. The version bump, in the required order

`installer/main.py:38` — `WORKSPACE_VERSION = 36` → `37`, **before** `installer/build.py`, exactly as
the plan warned: `marker_version` in the smoke suite's three-way equality comes from a *fresh install
of the built artifact*, so rebuilding first would have left the marker at 36 and the failure would
have read as a changelog problem. The equality assertion at `tests/retrofit_smoke.sh:487-496` was not
touched — the three values were made to agree instead.

Heading shape verified against the assertion's `^## v(\d+) ` regex: `## v37 — 2026-09-01` (space
after the number, em dash), and `changelog_versions == sorted(..., reverse=True)` still holds
(37, 36, 35, …).

## 2. The `## v37` changelog section

One section for S1 **and** S2, newest-first directly under the intro prose, matching the `## v36`
register (leading **"Why this release"** bullet → bold-lead bullets → **Migration notes**). Eight
bullets: why (v36 got the *surface* wrong and never said *which profile*); two surfaces not three;
`aside repl` over Bash as the default with the measured cost and the re-attach preamble; the
"pre-written assertion suite" reframing and why the old wording had to go; the dedicated profile with
the authority reason (Google session, 49 passwords, 6 passkeys) that makes it a requirement rather
than advice; fallback and axes unchanged; surface facts executed rather than cited, including the
`title` + `code` correction and the D9 / D11 / D10-surface-half closure; Migration notes.

Migration notes carry all five items the plan required, including the one the plan called sharp:
**an adopter who followed v36 and ran `claude mcp add -s local aside -- aside mcp` should remove that
registration**, since v37 stops prescribing it and leaving it costs ~1,344 tokens per session — the
only way v37 could otherwise leave a live workspace worse off than it found it. Max line width 101
chars, matching the file's existing maximum.

## 3. The consistency sweep — check by check

Scope as specified: live carriers only (`CLAUDE.md`, `.claude/`, `installer/payloads/`, `tests/`,
`scripts/`, `works/templates/`). `docs/current/*`, `docs/versions/*`, `works/phases/archived/*` and
the built artifact were read but never edited.

**1. Stale v36 prescription — clean.**
`grep -rn "MCP surface\|mcpServers\|scripted Playwright\|MCP surface first"` over the live set
returns six hits, every one justifiable out loud:

- `.claude/skills/explain/SKILL.md:351` — "the KB's search and MCP surfaces": the *knowledge base's*
  MCP, nothing to do with Aside. Not a hit on the doctrine.
- `tests/retrofit_smoke.sh:173-174, 193, 277, 351` — the four **negative** assertion lists. These
  must contain the retired strings in order to forbid them; if the grep stopped matching here the
  negatives would have been deleted, which is the failure, not the match.

A second pass (**1b**) audited *every* `MCP` / `aside mcp` mention in the five prescribing carriers
individually: each is either the corrected taxonomy ("identical over `aside mcp` and the `aside repl`
CLI"), the explicit "not the MCP transport" default, or the named escape hatch. None prescribes MCP.
A third pass (**1c**) checked that "nothing ships, nothing registers" is true of this repository
itself: no `.mcp.json`, no `aside` string in `.claude/settings.json`, and no `aside` string anywhere
in `installer/main.py`.

**2. Profile rule reaches every Aside-prescribing carrier — exactly as the notebook predicted.**
`grep -rn -- "--account" CLAUDE.md .claude/ installer/payloads/` → `design-cowork` ×3 (L447, L454,
L459), `slice-executor-high:32`, `slice-executor-mid:32`, `review-phase:43`, `CLAUDE.md:76`. The
complementary direction also holds: `grep -rln "Aside"` over the live set returns those five files
plus `installer/payloads/doc_bodies/operations.md` (the seed, which names the field
`- Agent's Aside account id (required whenever the instrument above is Aside):` without the flag —
correct for a manifest placeholder) and `tests/retrofit_smoke.sh`. **No live carrier prescribes Aside
without carrying the profile rule.**

**3. The two agent bodies are body-identical — verified by `diff`, not by eye.**
`diff <(tail -n +9 .../slice-executor-mid.md) <(tail -n +9 .../slice-executor-high.md)` → **empty,
exit 0**. Past the 8-line frontmatter the two files are byte-identical, which is stronger than "the
changed passages agree". `sync-agents --check` then confirms the frontmatter side (sonnet@xhigh /
opus@xhigh, mode flex, no drift).

**4. The three halts are still distinguishable — yes, with one arguable wrinkle (recorded, not fixed).**
Read as a first-time reader in each register:

- `design-cowork` L462-471 states all three explicitly and contrasts them in one sentence: the
  profile case "is a **third** halt condition and it is not the runtime one: the runtime halt fires
  on an absent or `UNFILLED` manifest, while a manifest naming no instrument still stops nothing."
  Both antecedents are named on the spot. Unambiguous.
- `CLAUDE.md:76` names the runtime rule and the instrument-is-not-a-halt clause in the sentence
  immediately before the profile halt ("a **third** halt … distinct from the runtime halt above"), so
  the reader has both antecedents in view.
- Agent bodies L32 state the runtime halt, then the profile halt as "a third halt, distinct from the
  runtime one". The instrument axis is not discussed in the agent register at all — correct, since it
  never halts and there is nothing for an executor to do about it.

**The wrinkle (arguable, deliberately not rewritten):** in the agent bodies the word "third" appears
twice in adjacent bullets with **different referents** — L32's *third halt* is the profile one, while
L33's "the span's own **third `needs_operator` condition**" is the mockup span's record-too-thin one
(whose first two are at design read-back, as `design-cowork:285-289` spells out: "cards missing or
the round back as prose, and the concreteness bar unmet"). Both are correct and each carries its own
scoping qualifier ("distinct from the runtime one" / "the span's own"), and L33 is pre-P20 prose that
S1 and S2 deliberately left alone — so this is not a defect and I did not touch it. It is recorded
here as the kind of thing a later compression pass might disambiguate (e.g. by naming the conditions
rather than counting them).

**5. The doctrine's split still holds — no essay leaked into the contract.**
Fact-by-fact placement check (`grep -rl` per fact across the live carriers):

| fact | lives in |
|---|---|
| authority reason ("49 imported passwords", "6 passkeys") | `design-cowork` **only** |
| measured MCP tool definition ("4,974") | `design-cowork` **only** |
| sharp edges (`RefStaleError`, `title`+`code`) | `design-cowork` **only** |
| the two-line re-attach code block | `design-cowork` **only** (agent bodies name it and point) |
| `aside exec` | `CLAUDE.md` (taxonomy) + `design-cowork` (how) |
| `aside account use` | `CLAUDE.md` + `design-cowork` — the two registers that state a rule's negative |

Second arguable observation, again recorded rather than acted on: `CLAUDE.md:76` is now **3,267
chars**, the longest bullet in the contract (next: L79 at 2,624). Nothing in it is reasoning that
belongs elsewhere — it is rule + one measurement parenthetical + a pointer — but after two slices
editing the same passage it is the contract's heaviest line, and a future compression pass is a fair
call for the operator or a later phase to make. Out of scope here, and not something to decide on my
own judgment mid-release.

**6. `## Doc impact` completeness — four lines added.** Cross-checked the notebook's seven existing
lines against what S1 and S2 actually changed and against the live docs. The three durable carriers
(`qa.md`, `operations.md`, `decisions.md`) were already named, but four specific passages that go
stale at v37 were not covered — including the one the plan predicted (the pre-v37 migration
paragraph). See *Doc impact* below. `docs/current/` was read only; nothing there was edited and no
`doc-new-version` was run.

**7. `README.md` / `README.en.md` — still no Aside mention.** `grep -n "Aside\|aside "` over both →
empty. Nothing added.

## 4. Assertion upkeep — one new block, and why

The sweep turned up exactly one invariant this release *relies on* that nothing pinned: **every
`## v<N>` changelog section carries a "Migration notes" line.** The file's own intro prose promises
it ("when a sync needs manual steps, a **Migration notes** line"), `/update-workspace` prints exactly
those lines to adopting repos, and v37's sharpest instruction — remove the v36 `aside mcp`
registration — reaches an adopter through no other channel. All 37 sections satisfy it today, so the
assertion pins a real, universal, previously-unguarded property of the release path.

Written in the established `# v37:` idiom as its **own** `ok`/`bad` block immediately after the
version-equality block (`tests/retrofit_smoke.sh:497-511`) rather than folded into it: folding would
have made a missing migration line report "release version markers disagree", precisely the
misreading-failure hazard this slice was warned about. Because it is a new block, the count moves
**139 → 140** — the one and only reason for the change, and the qa doc's baseline sentence is updated
via a `## Doc impact` line.

Verified in both directions: green on the real tree, and it genuinely fires — run against a doctored
copy of `CHANGELOG.md` with the v37 migration bullet removed it raises `AssertionError: ['v37']`
(exit 1). No existing assertion was weakened or edited.

## Doc impact (appended to `phase.md`, for the review to consolidate)

- operations.md: the update-path list needs a **"Coming from a pre-v37 workspace"** bullet mirroring
  the pre-v36 one (~L371) — **no engine change at all** (`scripts/workflow.py` untouched),
  `sync-agents` because both agent bodies changed, the seed's **two** manifest fields are docs so
  `--update` never delivers them, and **remove any `claude mcp add -s local aside -- aside mcp`
  registration made under v36**. (P20.S3)
- operations.md: the *"One optional field since v36 — and the halt condition did not move"* passage
  (~L714) — v37 adds a **second, conditionally required** field and a **third** halt, so that
  sentence now holds only of the **runtime** halt; a manifest naming no instrument still stops
  nothing. (P20.S3)
- qa.md: *Test Commands* — the smoke baseline moves to **140 PASS / 0 FAIL** at v37 (139 at v36): one
  new `ok`/`bad` block asserts every `## v<N>` changelog section carries a **Migration notes** line,
  while the v37 prose invariants (positives and the retired-string negatives) ride inside existing
  blocks and add no count. (P20.S3)
- decisions.md: the same v37 entry also closes **D9** (the fallback stands as written) and **D10's
  surface half** (the surface facts are executed rather than cited — `title` + `code` is the MCP
  tool's schema, not a CLI flag; snapshot refs go stale on navigation), with D10's
  against-a-real-product half re-filed as **D12**. (P20.S3)

## Notebook

`works/phases/active/P20/phase.md` rewritten as a **compressing** edit: **16,049 → 14,455 bytes**
(86 lines), comfortably under the 16,384 / 200 budget. All six notes tagged `P20.S3` were dropped
(spent — the detail is in the three `result.md` files by path); the **P21 version-coordination** note
survives, retagged for `P20.REVIEW` and updated to say P20 shipped v37 so **P21 takes v38**; the
whole `## Operator Questions` section including S2's fallback-generalization question is untouched;
`## Decisions` was compressed in place (superseded lines replaced, the D9/D11/D10→D12 wording kept
verbatim because the orchestrator executes it); `## Doc impact` grew by four lines and lost none; and
`## Now` was rewritten as the review's handoff. The generated `## Slices` block was not touched.

## Findings for the review (nothing here needs a fix slice)

1. The two adjacent "third condition" referents in the agent bodies (sweep check 4) — correct as
   written, disambiguated in `design-cowork`; a candidate for a later compression pass only.
2. `CLAUDE.md:76` is now the contract's longest bullet at 3,267 chars (sweep check 5) — rule, not
   essay, but worth an operator's eye if the contract is ever compressed.
3. Nothing in P20 has been exercised against a real browser or a real product — by design (this is a
   machinery repo with no browsable product), and it is exactly what re-filed job **D12** exists to
   cover.
