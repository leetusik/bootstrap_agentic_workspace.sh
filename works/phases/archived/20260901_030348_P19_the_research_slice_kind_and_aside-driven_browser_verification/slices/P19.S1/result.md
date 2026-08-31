# Result — P19.S1: the `research` slice kind, and `DECOMP2` generalized

- **status:** done
- **summary:** Added `research` to the closed `SLICE_KINDS` set with all four semantics — findings-only, always `slice-executor-high` **by kind** regardless of `risk`, findings land in `phase.md`, a `DECOMP2` usually follows — stated at every place routing is stated, and rewrote `DECOMP2` as a device with **two origins** (a research slice, and the `build-after` design style, unchanged) across the contract, both agent bodies and the `do-*` skills. Added engine probes and prose assertions to `tests/retrofit_smoke.sh` and rebuilt the installer artifact. No version bump and no changelog: both are S2's.
- **files_changed:** `scripts/workflow.py`, `CLAUDE.md`, `.claude/agents/slice-executor-mid.md`, `.claude/agents/slice-executor-high.md`, `.claude/skills/do-next-slice/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md`, `.claude/skills/design-cowork/SKILL.md`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P19/phase.md`, this file
- **validation:** `python3 scripts/workflow.py validate` — pass · `bash tests/retrofit_smoke.sh` — pass (139 PASS / 0 FAIL) · `python3 installer/build.py` then `--check` — pass · `python3 scripts/workflow.py new-slice --help` — inspected, both help strings render
- **deviations:** none of substance; two in-scope judgement calls recorded below (READMEs left alone; `design-cowork` gets a cross-reference, not a rewrite)
- **doc_impact:** two lines appended to `phase.md` — `operations.md` (the closed kind set gains `research`; tier routing stated kind-first, incl. the *Executor tiers* table row) and `decisions.md` (why the kind exists, and `DECOMP2` generalized)
- **doc_versions:** n/a (not a review slice — no `doc-new-version` run)

## What changed, and where

**Engine — `scripts/workflow.py`.** `SLICE_KINDS` now carries `research` (8 kinds). The comment block
above it gained a paragraph naming the three kinds that route to `slice-executor-high` **by kind**
whatever `risk` says (`decomposition`, `review`, `research`), why research is one of them, the
instruction to set `--risk high` anyway so the record cannot contradict the routing, and the
tie-break: the kind wins. Both `--kind` help strings (`new-slice`, `promote-deferred`) name
`research` and state its semantics in one clause; both `--risk` help strings now end with "kind
decomposition, review and research route to high whatever this says". No behavioral code changed
beyond the set membership — `require_slice_kind` and the validate-warning path already read the set,
which is why the hard-error/warning asymmetry needed no work.

**Contract — `CLAUDE.md`.** Two new Hard Rules, inserted immediately after the `DECOMP` rule:

1. `research` as a findings-only kind, with the four semantics spelled out (no product code; always
   high **by kind**, `--risk high`, kind wins on a disagreement; findings land in `phase.md` and that
   is the *point* of dispatching it, with `result.md` keeping the log; a `DECOMP2` **usually** — not
   *must* — follows).
2. `DECOMP2` has **two origins**, neither a special case of the other, both never pre-planned; a
   genuine third pass is `DECOMP3`, "a licence for one more id, not a numbering scheme".

Plus `research` added to the routing sentence under *Orchestrator and executor*, the "every slice is
dispatched" Hard Rule, the *IDs and Status* `DECOMP2` gloss (no longer "in a `build-after` design
phase only"), and the `--kind` closed set under *Workflow Commands*.

**Both agent bodies** (edited identically; asserted byte-identical below the frontmatter afterwards):
a new **Research slice (`kind: research`)** bullet in *Do* step 1 immediately before the
Decomposition bullet — it says where each kind of finding goes in the notebook (`## Decisions`,
tagged `## Notes for later slices`, `## Operator Questions`, `## Now`), why the relocation is the
whole reason the kind is dispatched, that `result.md` keeps the log and references rather than
restates, that a throwaway probe is fine but a product change is the next slice's job, and that "my
findings change nothing about the breakdown" is itself a real result. The Decomposition bullet gained
the research/`DECOMP2` cut instruction; the `slice-executor-high` tier bullet now says decomposition,
research and review land there by kind; the *Never* list bans **product** code on a research slice.

**Skills.** `do-next-slice`: tier selection, the dispatch-applies-to list, the `plan only` stop list
(`DECOMP2`'s dependency is now "findings or a design that do not exist yet"), and the decomposition
step. `do-whole-phase`: the delegated-kinds list, the tier line, the `plan only` rule (now **four
faces**, and `plan only` readies a research slice but stops before its `DECOMP2`), the idle-window
bullet (skip preparation during a `research` slice; `DECOMP2`/apply plans come from "what has not
landed yet"), and the decomposition step. `design-cowork`: one new bullet closing the `build-after`
section — the id is not design-only — and nothing else touched, deliberately.

## Judgement calls

- **`design-cowork` keeps its design framing.** Generalizing `DECOMP2` inside the design skill would
  make a design reader carry machinery they never use; a single cross-reference bullet prevents the
  "DECOMP2 is design equipment" misreading at a fraction of the cost. `CLAUDE.md` is where the two
  origins are stated as peers.
- **`create-phase` untouched.** Its `DECOMP2` mentions (lines 21, 23) sit inside the design-style
  menu, where they remain exactly correct; a research slice is cut at `DECOMP`, not at phase
  creation, so nothing there was made false.
- **`README.md` / `README.en.md` untouched.** They never enumerate slice kinds — `co-work` is absent
  from both — and their tier prose stays true because a research slice is rated `high`. v34 added
  `co-work` on the same terms.
- **`review-phase` untouched.** It states no routing, and S2 rewrites its gate stages; leaving it
  avoids a needless collision.

## Validation detail

- `python3 scripts/workflow.py validate` → `Workflow validation passed.`
- `python3 installer/build.py` → rebuilt `bootstrap_agentic_workspace.sh` (434 KB); `--check` → `OK`.
  Run **after** every machinery edit, so the committed artifact matches `installer/` source and the
  smoke test's dual-apply comparison passes.
- `bash tests/retrofit_smoke.sh` → `ALL RETROFIT SMOKE TESTS PASSED`, 139 PASS / 0 FAIL.

New assertions in `tests/retrofit_smoke.sh`, per the notebook's "the smoke test is the drift
detector" note — prose alone would not have caught a later drift:

- **Engine, against the throwaway workspace** (`$F`, self-cleaning — P19's own 4-slice cap was never
  touched): the unknown-kind rejection message must name `'research'` (i.e. the kind is in the closed
  set), and `new-slice --kind research --risk high` must succeed **and** land `"kind": "research"` in
  the created `slice.json`. The pre-existing negative (an invented kind is a hard error at creation,
  a warning at `validate`) still passes unchanged.
- **Prose:** the do-* skills must carry "that is what the `research` kind is for",
  "`--kind research --risk high`", "second origin" and "`research` and review always"; both agent
  bodies must carry the Research-slice bullet opener, "in `phase.md`, where the next slice will
  actually read them", the product-code ban, the tier clause and the second-origin clause (the
  `bodies["mid"] == bodies["high"]` diff still guards the pair); `CLAUDE.md` must carry the two new
  rule openers, "if the two ever disagree the **kind wins**", "**findings land in `phase.md`**",
  "`P<N>.DECOMP3`" and the widened closed set.

## Not done here (S2's, by plan)

`WORKSPACE_VERSION` is still 35 and `CHANGELOG.md` has no `## v36` section — S2 writes both, and the
v36 entry must cover this slice's half too. Nothing Aside-related was touched anywhere.

Phase state (decisions, doc impact, the S1→S2 handoff note, `## Now`) is in
`works/phases/active/P19/phase.md`; it is not restated here.
