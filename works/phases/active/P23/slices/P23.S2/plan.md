# Plan — P23.S2 (implementation/high): cut the derived and duplicated contract text and open v44

## Context

P23 slims `CLAUDE.md` (50,048 B / 49,646 chars; over Claude Code's 40k-char per-file warning and loaded into every session and dispatch) to a ≤ 12,288 B routing layer without losing a load-bearing rule. `intent.md` is the confirmed intent. P23.S1 mapped all 166 rule units; P23.DECOMP2 cut the edit work into S2 → S3 → S4. Their notes in `phase.md` (*Notes for later slices*: the rule map, the never-rule floor, the pin map summary, the drift list, and the *Slice breakdown*, whose S2 entry is this slice's scope record) are this slice's inputs, and S1's `result.md` §3 is the per-unit carrier evidence. Read `phase.md` whole first. `CLAUDE.md` and `tests/retrofit_smoke.sh` are unchanged since `e08bd7a`, so the map's line numbers are exact for this slice.

This is the **first shipping slice**. It removes only text that the code or an owning skill/executor already carries (the CUT and MOVE units outside HR-23, HR-25 and HR-26), lands the two MOVEs and the operator-approved docs-slice carve-out (OQ1) in the executor bodies, fixes drift D-4 and D-6, re-points the READMEs, re-homes the pins that leave, and opens workspace **v44**. It writes no new contract prose beyond one `--help` pointer and the IDs line that receives the `--kind` set; S4 rewrites the survivors later, so **do not polish surviving bullets** beyond keeping them grammatical.

**Done when** `CLAUDE.md` is about 36.6 KB and under 40,000 characters, smoke is green, and `build.py --check` passes.

## Steps

### 1. Contract cuts (`CLAUDE.md`)

Remove exactly these 55 units (ids, lines and bytes are in the notebook's rule map; lines refer to today's 50,048 B file). Before cutting each one, confirm its carrier from S1 `result.md` §3 still holds the text (a quick grep per unit). If a carrier is missing, keep the unit and record it as a deviation.

- **Driving:** DR-5b, DR-6b, DR-7b, DR-7d. Line 22 holds DR-7a..e: keep a, c and e, cut b and d.
- **Hard Rules:**
  - whole bullets: HR-1, HR-9, HR-16 (MOVE, step 2), HR-18;
  - sub-units: HR-5b (its docs-slice permission MOVEs as the OQ1 carve-out, step 2), HR-5d, HR-6a, HR-6b, HR-7b, HR-7d, HR-7e, HR-12b, HR-12e, HR-13b, HR-14b, HR-14c, HR-14e, HR-15b, HR-15c, HR-17e, HR-20a, HR-20b, HR-20e, HR-21b, HR-21c, HR-21d, HR-21f.
  - Leave HR-23, HR-25 and HR-26 (lines 76, 78, 79) untouched: they are S3's.
- **Workflow Commands:** delete the whole section (WC-0..23). WC-3 is the one SPLIT: its closed-set fact moves into *IDs and Status* as one line that keeps both pinned phrases on that line: `` `--kind` is a **closed set** `` and `` `research`, `fix`, `docs`, `qa`, `co-work` `` (for example, a slice-kind line listing all eight kinds and saying an unknown kind is rejected by `new-slice` and `promote-deferred`).
- **Commit Convention:** CC-2b only. Keep CC-1, CC-2a and CC-2c.
- **The one addition:** DR-1 (line 11) gains a short clause naming `python3 scripts/workflow.py --help` as the command reference, since the list is gone.

After the cuts, no never-rule may have lost its only contract statement. Per the map none of these units is a never-rule's sole carrier (for example N10 stays in RO-4, N26 in HR-12d and HR-8, N37 in HR-20d and DR-7e). Check the floor's N-rules whose source units you touched (N10, N21, N25, N26, N29, N37) by grepping their surviving phrases.

### 2. Executor bodies (`.claude/agents/slice-executor-high.md` and `-mid.md`, bodies byte-identical)

- **HR-16 MOVE** into the decomposition bullet (`:35`): slice selection is by `order`; `--order` takes fractional values (e.g. `--order 4.5`) to insert between neighbors without renumbering; `depends_on` is advisory and `validate` checks only that it exists.
- **OQ1 carve-out**, the wording the operator approved at the DECOMP2 gate (quoted in `slices/P23.DECOMP2/plan.md`): a `docs` slice in an operator-created docs phase, on the default stream, may run `doc-new-version` and `rebuild-docs` for the `## Doc impact` notes its plan names, editing only the returned `edit_path`; recording `docs-consolidated <P>` stays the orchestrator's. Land it at all four places, consistently:
  - `:10` "Two carve-outs, each tied to one kind" → three;
  - step 5 (`:47`–`:48`), "never per slice": add the docs-slice exception;
  - `:55` "The only workflow commands you may run are …": add `doc-new-version` / `rebuild-docs` for a `docs` slice in a docs phase;
  - `:56` "version docs on a non-review slice": except the docs slice.
- Budget: ≈ +400 B per body (S1's estimate). Report both bodies' `wc -c` and confirm they are identical below the frontmatter (smoke asserts it).
- `scripts/workflow.py`: give `new-slice`'s `--order` (`:2951`) a help string saying fractional values insert between neighbors. Check whether the other two `--order` arguments (`:2962`, `:3062`) belong to commands where the same help fits; add it there only if so.

### 3. Drift

- **D-4:** `do-next-slice/SKILL.md:12` and `do-whole-phase/SKILL.md:12` list the delegated kinds without `research`. Add it.
- **D-6:** the note-tag form in `works/templates/phase.md:29` and its embedded twin in `scripts/workflow.py:1329` (`PHASE_MD_TEMPLATE_FALLBACK`) becomes the executor's `**(from <slice>, for <slice>)**`. Keep the two byte-identical (smoke checks it at `:948`–`:958`).
- **D-2** disappears with Workflow Commands; **D-5** needs no edit.

### 4. READMEs

Re-point the three stale lines to `python3 scripts/workflow.py --help` as the command reference: `README.en.md:266`, `README.en.md:389`, and `README.md:216` (Korean; keep the sentence Korean and read its context). No other README edits.

### 5. Smoke pins (`tests/retrofit_smoke.sh`, Test 0 contract list at `:369`–`:424`)

- Remove the four contract positives that leave, after grepping that each is asserted on its destination list (do-* `:102`, design-cowork `:145`, review-phase `:224`, executor `:279`) or functionally (Test 8 / Test 9):
  - `"finish-slice P1.S1 --outcome"`
  - ``"`phase-scope P1 [--base REF] [--head REF] [--json]`"``
  - `"design-only, no mockup: the operator signed the round on the card set"`
  - ``"**findings land in `phase.md`**"``
- The `--kind` pins stay on the contract list; the IDs line satisfies them.
- Add to the executor-body list one pin for the docs-slice carve-out and one for the fractional `--order`, each a short phrase from the text you land.
- Update the nearby comments to say v44 and why the four left. Leave every negative in place.

### 6. Release

- `installer/main.py:38`: `WORKSPACE_VERSION = 43` → `44`.
- `CHANGELOG.md`: a new `## v44 — 2026-09-28` section on top, in the v43 style: a *Why this release* bullet (the contract was 50 KB, over Claude Code's 40k-char per-file warning, and loaded on every session and dispatch), bullets for what this slice changed (Workflow Commands gone in favour of `--help`; procedure duplicated by skills and executors removed from the contract; the executor's docs-slice carve-out; fractional `--order` and advisory `depends_on` now stated in the executor; `research` listed among the delegated kinds; the notebook template's tag form), and a **Migration notes.** line (nothing to run; `/update-workspace` refreshes the contract or its `CLAUDE.workspace.md` sidecar; later P23 slices extend this same v44 section). Smoke requires the version to agree across installer, top heading and fresh marker, and a Migration notes line in every section.
- `python3 installer/build.py`, then `python3 installer/build.py --check`.

### 7. Notebook and result

- `phase.md`: append this slice's `## Doc impact` lines (at least: architecture.md or operations.md — the contract no longer lists commands and `--help` is the reference; qa.md — which contract pins moved to which lists; decisions.md — why the contract slimmed and where the cut text lives; the executor's docs-slice carve-out). Update `## Decisions` only if something here supersedes a line; drop the notes this slice consumed (D-2, D-4, D-6, the README item) and rewrite `## Now` last for S3.
- `result.md`: verdict block first; list each removed unit with the carrier you verified; deviations; sizes.

## Boundaries

- Do not touch HR-23, HR-25, HR-26 or any STAY/SPLIT unit beyond grammar. Do not reword pinned phrases.
- No new loading mechanism, no edits to adopting repos, no `docs/current` or `docs/versions` edits.
- Never commit or run status commands.

## Verification

- `wc -c CLAUDE.md` and `python3 -c 'print(len(open("CLAUDE.md").read()))'`: ≈ 36.6 KB and < 40,000 chars.
- Per-dispatch prefix: `wc -c CLAUDE.md .claude/agents/slice-executor-high.md` (77,782 B before).
- `python3 scripts/workflow.py validate` passes (pre-existing advisories expected).
- `python3 installer/build.py --check` passes.
- Smoke, after the rebuild and `--check` have run in earlier calls: `bash tests/retrofit_smoke.sh > /tmp/p23-s2-smoke.log 2>&1` as the **only** command in its Bash call, foreground, `timeout: 600000`. A redirect is fine; a chained or backgrounded command is not (such runs have stalled at 0 % CPU here). Then, in a separate call, count `^PASS` and `^FAIL` in the log and read its last lines for the final verdict. S1's 180-PASS baseline was derived, never counted, so this run confirms it: report the counted number, and account for any difference from 180 (for example, new ok lines you added).
- `git status --porcelain` shows only the files this plan names plus the rebuilt `bootstrap_agentic_workspace.sh`.

## Verdict

Return: status; one-line summary for `finish-slice --outcome`; files_changed; validation outcomes (with sizes and PASS count); deviations; doc_impact lines added.
