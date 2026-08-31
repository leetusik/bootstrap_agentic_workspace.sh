# Plan — P20.DECOMP (decompose phase)

- Phase: **P20** — make the Aside prescription true: the repl surface over Bash, on a dedicated profile
- Kind / risk: `decomposition / high` → **`slice-executor-high`** (decomposition routes high by kind)
- Mode: `auto` (orchestrator planned inline; no operator approval pause)

## What this slice is

Cut P20 into its middle slices. **Bare folders only** — create them with
`python3 scripts/workflow.py new-slice`, and **never pre-fill another slice's `plan.md`**. Record the
breakdown, the findings, and the notes the later slices need in `phase.md` (the phase notebook), under
its 200-line / 16 KB budget. Write **no product code and no doctrine prose** in this slice: the
rewrite is the middle slices' work, not yours.

## The intent, already confirmed — do not re-litigate it

`works/phases/active/P20/intent.md` carries the operator's verbatim request, the confirmed refined
intent in **five numbered parts**, and the resolved clarifications. Read it whole first. It is the
source of truth; the operator has already answered the open questions (dedicated profile **required**;
fallback **stands**; **no MCP registration at all**). Your job is to decide the *shape of the work*,
not to reopen any of those.

The five parts, in one line each, so you can map them onto slices:

1. **Surface taxonomy correction** — v36's three surfaces (MCP / CLI / REPL) become the two that
   exist: the `repl` surface (one tool, identical over `aside mcp` and the `aside repl` CLI — same
   Playwright-like environment, different transport) and `aside exec` (Aside's own model drives).
2. **Default: `aside repl` over Bash, executor-driven** — explicitly **not** the MCP transport. The
   reason is recorded, not asserted: `aside mcp` exposes one `repl` tool whose definition costs
   ~1,344 tokens (4,974 JSON chars) in **every** session, browser-related or not, with no lazy-load;
   the JS scope lost between CLI invocations is bought back by a two-line re-attach preamble
   (`listBrowserTabs()` → `attachBrowserTab(targetId)`), verified live. Bash is already in both
   executor tiers' allowlists, so **nothing ships and nothing registers**.
   `claude mcp add -s local aside -- aside mcp` survives only as a named **optional per-operator,
   per-session escape hatch** the workspace neither ships nor prescribes.
3. **Profile safety, required (closes D11)** — agent runs use a dedicated Aside profile/account via
   `aside --account <id>`, never the operator's signed-in one (the live probe reached a browser
   holding the operator's Google session, 49 imported passwords, 6 passkeys). The `## Operator
   Runtime` manifest records which profile; an executor finding only the personal profile returns
   **`needs_operator`**.
4. **Fallback stands, unchanged (closes D9)** — the doctrine's demands bind, the instrument does not;
   Linux/CI runs the same sweep through whatever real browser it has.
5. **Recorded surface facts (closes D10's surface half)** — `repl` requires both `title` and `code`;
   snapshot refs are session- and snapshot-scoped and go stale on navigation (`RefStaleError`);
   `getByRole` survives it. And the argument "not Playwright-style automation" is rewritten as
   **"not a pre-written assertion suite"** — the surface *is* Playwright; what differs is who picks
   the next action.

Ships as **workspace v37**.

## The blast radius — the inventory I already took, for you to verify and extend

Every live file that carries the v36 Aside doctrine (archived phases and `docs/versions/*` are
history — **never edit them**):

- `CLAUDE.md` — the hard rule **"Real-browser verification runs through Aside, not a script."**
  (one paragraph; names MCP first, the CLI and `aside repl`, the instrument/runtime axes, the fallback)
- `.claude/agents/slice-executor-high.md` and `.claude/agents/slice-executor-mid.md` — **line 32**
  (implementation/`fix` bullet, "Drive that browser with **Aside** … MCP surface first"), **line 33**
  (the `co-work` mockup span, "driven with the same instrument (Aside first)"), **line 36**
  (the review's gate stage 2, "Aside first, the fallback browser otherwise"). The two bodies are
  **body-identical in these passages** — a drift between them is a defect. They are generated-adjacent:
  `python3 scripts/workflow.py sync-agents` applies `executors.toml`, so keep edits inside the body
  text and re-run `sync-agents --check` after.
- `.claude/skills/design-cowork/SKILL.md` — **~line 278** (the mockup's *Verified in the operator's
  runtime* bullet), **~lines 420–427** (**"With what — the instrument."** — the paragraph that names
  MCP first and prints the `mcpServers` JSON), **~lines 429–433** (**"Why an agent and not a script."**
  — the paragraph part 5 rewrites), **~lines 435–439** (the fallback), **~lines 500–502** (the
  anti-pattern bullet).
- `.claude/skills/review-phase/SKILL.md` — **line 43**, stage 2 ("**Drive it with Aside** … MCP
  surface first").
- `installer/payloads/doc_bodies/operations.md` — **line 28**, the seeded `## Operator Runtime`
  field `- Browser instrument for the agent:` (currently `Aside (\`aside mcp\`) …`). Part 3 wants the
  **profile** recorded in the manifest, so this seed is where that field is designed.
- `tests/retrofit_smoke.sh` — **the sharpest hazard.** Lines ~138–141, ~150–151, ~161–162, ~197–204,
  ~256–257 and the Test-5 summary line ~274 assert the **exact v36 strings this phase rewrites**
  (`"\`aside mcp\`"`, `"in place of scripted Playwright-style automation"`,
  `"driven with the same instrument (Aside first)"`, …). Any slice that rewrites a passage **must**
  update its assertions in the same slice, or the tests fail at that slice's boundary.
- `installer/main.py` — `WORKSPACE_VERSION = 36` → **37**.
- `CHANGELOG.md` — a new `## v37 — <date>` section, newest-first, with a **Migration notes** line
  (both agent bodies change → `sync-agents`; `--update` never touches `docs/`, so the seed manifest
  field reaches fresh installs only).
- `bootstrap_agentic_workspace.sh` — **rebuilt**, never hand-edited.
- `README.md` / `README.en.md` — verified: **no Aside mentions**. Confirm before assuming.

`docs/current/{decisions,operations,qa}.md` carry the v36 doctrine too, but they are **generated
snapshots**: middle slices never edit them and never run `doc-new-version` — they append one-line
`## Doc impact` notes to `phase.md` and the **review** consolidates. Say so in `phase.md` so no middle
slice reaches for them.

## Hard constraints your cut must respect

- **The installer rebuild rule is per-commit, and the orchestrator commits at every slice boundary.**
  This is the upstream bootstrap repo (`installer/` exists), so **every slice that edits machinery**
  (`scripts/workflow.py`, `.claude/*`, `works/templates/*`, `CLAUDE.md`) must itself run
  `python3 installer/build.py` and leave the rebuilt `bootstrap_agentic_workspace.sh` in the tree;
  `python3 installer/build.py --check` must pass. The tracked `.githooks/pre-commit` enforces it
  (`core.hooksPath` is already `.githooks` here). A slice that edits machinery and skips the rebuild
  blocks the commit. Put this in `## Notes for later slices` explicitly.
- **The version bump and the changelog are one slice's job — the last one** — and its `## v37` entry
  covers *every* middle slice, exactly as v36's single entry covered P19.S1 and P19.S2.
- **Sequence, don't parallelise.** All five parts land in the same handful of files (`CLAUDE.md`,
  both agent bodies, `design-cowork`, `review-phase`, `retrofit_smoke.sh`). Slices inside a phase are
  sequential anyway; make the ordering deliberate with `--order` and say in `phase.md` which slice
  owns which passage, so slice 2 does not rewrite what slice 1 just wrote.
- **`--risk` is the phase's cost lever, and it selects the tier.** `low` is only for a one-line or
  few-line edit, or docs. Every slice here rewrites doctrine prose across ≥5 files **and** the test
  assertions **and** rebuilds the installer → **`high`**, all of them. Do not rate anything `low` to
  save money; a mis-routed slice costs more.
- **No `research` slice, and no `DECOMP2`.** The research already happened: the operator ran Aside
  live on 2026-09-01 (CLI 1.26.810.1915, account u0, both transports round-tripped, MCP tool
  definition measured at 4,974 chars) and the findings are in `intent.md`. Nothing about the
  remaining breakdown is unknown. If you nevertheless conclude a `research` slice is needed, say why
  in `phase.md` — but the default answer is no.
- **No design slice.** Nothing here is product visual design; `intent.md` carries no `## Design Style`
  and needs none. Do not ask for one.
- **Slice count: keep it tight — 2 or 3 middle slices.** P19 shipped a comparable double change in
  two. Cut on the seams of the *change*, not of the files (every slice touches nearly every file).
  A defensible cut is the taxonomy+default rewrite as one slice and profile-safety+release as
  another, but the shape is yours to decide — argue for it in `## Decisions`.

## The three deferred jobs — decide the mechanics, do not execute them

`intent.md` says D9, D11 and **D10's surface half** close at this phase's review, with D10's
*against-a-real-product* half staying open. The engine has no half-close: `drop-deferred <D>
--reason "..."` is the only closing transition for an open job, and `deferred.json` has no partial
state. So **record in `phase.md` exactly what the review is to do** — which of D9/D10/D11 is dropped
with what reason, and, for D10, whether its remaining half is rewritten in place (a new `defer-job`
with the narrowed scope, the old one dropped) or the job is simply left open with the surface half
noted as answered. Pick one, write it down as a decision, and let the review execute it. Filing and
dropping deferred jobs is the orchestrator's action at the review, not a middle slice's.

## Also worth recording for the later slices

- **The doctrine's *argument* is not restated in every file** — v36 deliberately kept the long form
  in the qa doc and short pointers elsewhere. Preserve that: the contract gets a rule, the agent
  bodies get an instruction, `design-cowork` and the qa doc carry the reasoning.
- **Instrument and runtime stay different axes.** The absent-or-`UNFILLED` → `needs_operator` →
  `pending` rule is about the **runtime**; a manifest naming no instrument is not an unfilled
  manifest. Part 3 adds a **profile** condition that *does* halt (`needs_operator` when only the
  personal profile exists) — that is a new, third halt, and the slice writing it must not blur it
  into the runtime rule.
- **The re-attach preamble is canonical text** — `listBrowserTabs()` → `attachBrowserTab(targetId)` —
  and should appear once in full where an executor will actually read it before driving a browser.
- **Nothing installs, bundles, registers or auto-configures Aside**, and no slice may claim a browser
  run it did not make. v37 changes the prescription, not that rule.

## Acceptance gate — mine to declare, not yours

I declare the phase's gate immediately after `finish-slice P20.DECOMP`, in the same commit. On this
evidence it will be **waived** (`--waive`): this is the upstream machinery repo, it ships no browsable
product, and the phase's effects are contract/skill/agent prose, a seed doc body, the smoke tests and
a version bump — exactly P19's reasoning. **If your decomposition turns up anything operator-visible**
that would make `--require` the right call, say so plainly in `phase.md` and in your verdict summary.
Do not run `accept-gate` yourself — executors never do.

## Do

1. Read `works/phases/active/P20/intent.md` and `works/phases/active/P20/phase.md` whole.
2. Verify the inventory above against the tree (`grep -rn -i aside` over the live files; ignore
   `works/phases/archived/`, `docs/versions/`, `works/events.jsonl`, `bootstrap_agentic_workspace.sh`).
   Correct or extend it — a missed live carrier of the v36 wording is a review finding later.
3. Decide the cut and create the middle slices as **bare folders**:
   `python3 scripts/workflow.py new-slice --phase P20 --slice P20.S<n> --name "..." --kind implementation --risk high --order <n> [--depends-on P20.S<n-1>]`.
   `P20.REVIEW` already exists at the end — check its `--order` and place the middle slices before it
   (fractional `--order` is available if you need to slot between existing neighbours).
4. Edit `phase.md` — do not merely append. Fill `## Decisions` (the cut and why, the sequencing, the
   deferred-job mechanics, the no-research/no-DECOMP2 calls), `## Notes for later slices` (each tagged
   `**(from P20.DECOMP, for P20.S<n>)**` — the rebuild rule, the test-assertion hazard, the exact
   passages each slice owns, the agent-body twinning, the docs-are-generated rule), and rewrite
   `## Now` (≤ 15 lines) as the next dispatch's handoff. Leave the generated `## Slices` block alone.
   Stay under the 200-line / 16 KB budget — point at paths instead of quoting file contents.
5. Write `works/phases/active/P20/slices/P20.DECOMP/result.md`, **structured verdict block first**,
   then the free-form log: what you inventoried, the cut and the alternatives you rejected, and
   anything that belongs to *this* slice rather than to the next one. Do not duplicate what you put
   in `phase.md` — reference it by path in a line.

## Validate

- `python3 scripts/workflow.py rebuild && python3 scripts/workflow.py validate` — must pass clean,
  and the `## Slices` table must show the new slices.
- `python3 installer/build.py --check` — must still pass (this slice changes no machinery, so it
  should be untouched; if it fails, something outside your slice is wrong — report it, do not fix it
  by rebuilding).
- `bash tests/retrofit_smoke.sh` is **not** yours to run here (no machinery changed) — the middle
  slices and the review own it.

## Do not

- Write any doctrine prose, edit `CLAUDE.md`, the agent bodies, the skills, the seed doc bodies or
  the tests. That is the middle slices' work.
- Pre-fill any slice's `plan.md`, or create `result.md` for a slice that has not run.
- Edit `docs/current/*`, run `doc-new-version`, run `accept-gate`, commit, or move any phase/slice
  status. The orchestrator owns all of that.
- Touch `works/phases/archived/**` or `docs/versions/**`.

## Verdict

Return the structured verdict block. `summary` in one line: the cut you made and the reasoning in
brief. Use `needs_operator` only if something in `intent.md` genuinely cannot be decomposed without
an operator answer — the five parts are confirmed, so this should not happen.
