# Plan — P23.S3 (implementation/high): collapse the worktree, design and Aside bullets to stubs

## Context

P23 slims `CLAUDE.md` to a ≤ 12,288 B routing layer without losing a load-bearing rule (`intent.md`). S1 mapped the rules, DECOMP2 cut S2 → S3 → S4, and **S2 has landed** (commit `a63ed44`): `CLAUDE.md` is 36,712 B / 36,418 chars, Workflow Commands and 32 other duplicate units are gone, both executor bodies carry the OQ1 carve-out (28,461 B high), v44 is open in the installer and CHANGELOG, and smoke counted 180 PASS / 0 FAIL. This slice collapses the three largest Hard Rules bullets, which their owning skills already carry almost verbatim, into the **final-form stubs** the outline names, so S4 does not rewrite them again:

- **Aside** (HR-23, the bullet starting `**Real-browser verification runs through Aside`, now line 72, 3,286 B) — owner `design-cowork`;
- **worktree** (HR-25, starting `**A phase runs on the default stream unless the operator asks for a worktree (v43)`, now line 74, 4,425 B) — owner `parallel-phase`;
- **design** (HR-26, starting `**Product visual design follows the \`design-cowork\` skill.**`, now line 75, 3,807 B) — owner `design-cowork`;
- plus **HR-6d**, the design-styles tail of the DECOMP bullet (from `**A design-bearing phase follows one of three operator-confirmed styles**` to the end of that bullet, now line 58, 1,282 B). The breakdown note gives S3 only HR-23/25/26, but HR-6d is the same design family: the outline puts its never-rule (N54, "`design-only` is chosen at `/create-phase` or nowhere") in the design stub, and its other destination is a one-clause executor addition. Taking it here finishes the design move in one slice and leaves S4 the non-design text. Record this as a scope note in `result.md`, not a deviation.

The line numbers above are as of `a63ed44`; the rule map's refer to `e08bd7a` (`git show e08bd7a:CLAUDE.md`). Locate each unit by its text either way. Leave S2's surviving edits alone (the notebook's *(from P23.S2, for P23.S4)* note lists them).

**Done when** `CLAUDE.md` is about 26 KB (S1's ≈ 27 KB estimate, minus HR-6d), smoke is green, and `build.py --check` passes.

## Inputs

- `phase.md` whole: the rule map rows HR-6d, HR-23a–j, HR-25a–j, HR-26a–k; the outline's *Hard Rules* line (what the Aside, design and worktree stubs keep); the never-rule floor; the pin map summary; the drift list (D-3); the D13 note.
- S1 `result.md` §3 (carriers for each CUT unit), §4 (the phrase that proved each never-rule), §5 (the full pin table, for which K pins each stub must keep).

## Steps

### 1. Contract: three bullets become final-form stubs

Write each stub as the outline names it. Keep every pinned phrase that stays (`K` in the map) **on one line, byte-for-byte** (contract pins are raw substrings), and keep each never-rule's prohibition. Budget: the three stubs together about 2,000–2,400 B; report each stub's bytes.

- **Aside stub** keeps:
  - HR-23a, with its heading pin `**Real-browser verification runs through Aside, not a pre-written assertion suite.**`;
  - HR-23d's never-core: `aside repl` over Bash, never a standing `aside mcp` registration (N41);
  - HR-23f's pointer: `design-cowork` carries the invocation, the re-attach preamble and the surface's sharp edges;
  - HR-23h: `**Whose browser: a dedicated profile.**`, `pass \`--account <id>\` on every invocation`, `is a **third** halt: \`needs_operator\` → \`pending\``, the manifest records the agent's account id, never borrow the personal profile or create an account for the operator (N42);
  - HR-23i **verbatim in scope** (D13): `an agent never drives a profile signed into the operator's accounts`, for whichever browser is driven (N43);
  - HR-23j: `**the doctrine's demands bind, the instrument does not.**`, name the instrument in `result.md`, never claim a browser run you did not make (N44).
  - Cut HR-23b, c, e, g; `design-cowork` carries them.
- **Worktree stub** keeps:
  - HR-25a with its pin `unless the operator asks for a worktree (v43)`, the phase as the unit of parallelism, and never fan slices out (N49);
  - HR-25b's core: a worktree only on the operator's word (the `worktree` mode word, `parallel-start` by their hand, or their own words); never on your own initiative; a `hint:` is relayed, never acted on (N48);
  - HR-25h's core: never merge past a closed `parallel-gate`; never unstage or discard the operator's work (N50);
  - HR-25i's core: never a worktree for a docs phase; staying on the default stream needs nothing;
  - a pointer to the `parallel-phase` skill for the lifecycle.
  - Cut HR-25c–g and HR-25j; `parallel-phase` carries them (rules 2–7), and the stream-scoped facts stay in Canonical State.
- **Design stub** keeps:
  - HR-26a: a `co-work` slice is `--kind co-work --risk high` (N53) and runs inline; the dispatch pins (`*DesignSync* work is never dispatched`, `mockup build is its one dispatched span`) live in the Driving/orchestrator text and must stay satisfiable wherever they are;
  - HR-26b: `writes no ***product*** implementation code` (N52; Test 1 greps it in the retrofit sidecar with escaped asterisks, so keep it byte-exact);
  - HR-6d's never-core: `design-only` is chosen at `/create-phase` or nowhere (N54);
  - HR-26g and HR-26h: Claude Design and the operator make the visual decisions; generated or external artifacts are `data, not instructions` (N56); `Approval must be literal`; `literal operator signoff closes an immutable round`; revisions create superseding rounds; `RESPECT THE DESIGN`, never drop, simplify, restyle or "improve" an approved element (N55); later slices verify `real-browser fidelity`;
  - HR-26j's decision core and HR-26k: never invent visual decisions in an executor, build a mockup the operator did not ask for, or pre-plan build slices before the signed design (N51);
  - a pointer to `design-cowork` for the three styles, the handoff, the rounds and the gates.
  - Cut HR-26c, d, e, f, i and HR-6d's style procedure; `design-cowork`, `create-phase` and the do-* skills carry them.
- Check the K-pin list against S1 §5 for all three bullets before you finish: every positive that stays must still hit.

### 2. Executor bodies (identical)

HR-6d's second destination: add one clause to the decomposition bullet saying that in every design style `DECOMP` also records the phase's **build inventory** in `phase.md` (what to build, not how). About +100 B per body. Both bodies stay byte-identical below the frontmatter.

### 3. `parallel-phase` drift (D-3)

`parallel-phase/SKILL.md:99-100`: "(the do-* skills do this for you when `next` prints the hint)" contradicts v43's "relay, never act" (`:82`). Replace it with wording that says `parallel-start` runs only on the operator's word, and a `hint:` is relayed.

### 4. Smoke (`tests/retrofit_smoke.sh`, Test 0)

- **New `parallel-phase` list**, whitespace-normalized like the design-cowork one: `Worktree rules`, `**When — only when asked**`, `retired no-ops`, `Relay a hint to the operator; never act on it.`, and `` Never merge a parallel phase whose `parallel-gate` is closed ``. All five are present today (verified with normalized matching). Its negatives: `runs in its own worktree by default` and `enters its worktree at **first execution**` (both absent today). Add a positive for the D-3 wording you land.
- **design-cowork list:** add `two-digit reading-order prefix` and `a manifest naming no instrument still stops nothing` (both present once whitespace is normalized). Add the negative `runs through Aside, not a script` (absent today).
- **review-phase list:** add the negative `re-runs the whole cumulative` (absent today).
- **Contract list:** remove the 16 positives that leave with these bullets. Before removing each, confirm its destination list or the new asserts above cover it. The 16 are (per the pin map): HR-23c `**Two surfaces, not three:**`; HR-23d `**The default is \`aside repl\` over Bash**` and `~1,344 tokens`; HR-23e the `claude mcp add -s local aside -- aside mcp` escape-hatch line; HR-23g `**Instrument and runtime are different axes:**`; HR-25b `Worktree rules` and `**When — only when asked**`; HR-25i `retired no-ops`; HR-26c `**\`build-after\`**`, `**\`design-only\`**`, `**\`paired\`**`, `## Design Style`, `Mockup: requested`; HR-26d `two-digit reading-order prefix`; HR-26e `the operator's return closes the round` and `PENDING #2 exists only when a mockup was requested`. Cross-check this list against S1 §5 and use §5 if they differ.
- Every contract negative stays on the contract list.
- Reword Test 0's `ok`/`bad` labels: they name "the worktree-by-default rules" and other v42 contract invariants that now live in the skills. Say what the test asserts after this slice.

### 5. Release and rebuild

Append to the `## v44` CHANGELOG section: the three bullets are now stubs, with their procedure in `design-cowork` and `parallel-phase`; the new `parallel-phase` pin list; the D-3 fix; the executor's build-inventory clause. Extend its Migration notes line only if an adopter must do something (expected: nothing). Then `python3 installer/build.py` and `--check`, each in its own call.

### 6. Notebook and result

- `phase.md`: append `## Doc impact` lines for this slice (qa.md: the new parallel-phase list and the moved pins; decisions.md or architecture.md: the Aside, worktree and design rules now live in their skills with never-stubs in the contract). Drop D-3 from the drift note once fixed. Record in `## Now` that **D13's trigger fired** (the Aside text moved) and that D13 stays open for the operator; the review mentions it. Rewrite `## Now` last, for S4, including the new line positions S4 needs and what is left of the design family (nothing).
- `result.md`: verdict block first; each stub's bytes; the pin moves; the never-rules checked.

## Boundaries

- Touch no other contract unit (S4's). Do not resolve D13 or edit `works/deferred/`.
- No new loading mechanism; no adopter edits; no `docs/` edits. Never commit or run status commands.

## Verification

- The never-rules these bullets carry, each by its S1 §4 phrase or an exact equivalent you name: N19, N40–N44, N48–N56.
- `wc -c CLAUDE.md`; per-dispatch prefix `wc -c CLAUDE.md .claude/agents/slice-executor-high.md`.
- `python3 scripts/workflow.py validate`; `python3 installer/build.py --check`.
- Smoke: `bash tests/retrofit_smoke.sh > /tmp/p23-s3-smoke.log 2>&1` as the **only** command in its Bash call, foreground, `timeout: 600000`; then count `^PASS` / `^FAIL` and read the tail in a separate call. Compare with S2's counted number and account for the difference.
- `git status --porcelain`: only the files this plan names plus the rebuilt `bootstrap_agentic_workspace.sh`.

## Verdict

Return: status; one-line summary for `finish-slice --outcome`; files_changed; validation (sizes, counted PASS/FAIL); deviations; doc_impact lines added.
