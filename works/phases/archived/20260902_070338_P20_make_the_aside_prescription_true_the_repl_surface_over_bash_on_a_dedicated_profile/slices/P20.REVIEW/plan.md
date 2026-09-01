# Plan — P20.REVIEW (phase review)

- Phase: **P20** — make the Aside prescription true: the `repl` surface over Bash, on a dedicated profile
- Kind / risk: `review / high` → **`slice-executor-high`** (review routes high by kind)
- Acceptance gate: **WAIVED** — declared at the `DECOMP` boundary. **Run no gate stages.** Mode: `auto`.

## What this slice is

Review the whole phase, then — **only on a passing verdict** — consolidate its durable docs. The three
middle slices are done and committed (`49c9bb6`, `4cd6ea3`, `fd34b04`); `P20.DECOMP` is `8b8d13a`.

**Complete the validation and the judgment before you branch on the verdict.** Never abort at the
first failing check: the orchestrator needs the whole picture in one cycle, not one finding per cycle.
On `changes_requested` or `blocked`, **stop before the consolidation** and return numbered findings
plus proposed fix slices (`P20.F1`, …).

**Never edit source code on a review slice.** If the work needs a code or prose change, that is a
`changes_requested` with a fix slice — not a quiet edit.

## The gate is waived — what that removes

`phase.json` carries `acceptance.required: false`. So: **no** `## Operator Runtime` lookup, **no**
opening a running product, **no** first-time-user walk, **no** `## Regression Checklist` re-run, and
**no `walkthrough`** in your return. This is the upstream machinery repo; it ships no browsable
product. Review it as a pre-v32 phase is reviewed, plus the `## Operator Questions` routing below,
which is **not** gate-specific and still binds.

Related, and worth checking rather than assuming: **no browser was run anywhere in P20**, by design.
Every slice used read-only `aside --help` / `repl --help` / `account --help` only. Confirm no
`result.md` claims a browser run — a false claim would be a serious finding in a phase whose whole
subject is browser verification.

## 1. Validate all the slices together

Re-run each slice's validation commands — they head every `result.md` — plus the workspace's own:

- `python3 installer/build.py --check` — the artifact must be in sync with `installer/` source.
- `python3 scripts/workflow.py sync-agents --check` — no drift.
- `bash tests/retrofit_smoke.sh` — **full run**. `P20.S3` reports **140 PASS / 0 FAIL** (139 at v36,
  +1 for the new changelog Migration-notes block). Confirm the count and the zero.
- `python3 scripts/workflow.py validate`.
- The release equality: `WORKSPACE_VERSION = 37` in `installer/main.py`, `## v37 — 2026-09-01` as the
  top `CHANGELOG.md` heading, and the smoke suite's fresh-install marker agreeing. The suite asserts
  this; confirm it actually ran and passed rather than taking the number from a report.

## 2. Judge the phase against what was asked

`intent.md` states the confirmed intent in **five numbered parts**. Check each is actually landed in
the shipped machinery — read the files, do not take the `result.md` files' word for it:

1. **Surface taxonomy** — two surfaces (`repl`, identical over `aside mcp` and `aside repl`; and
   `aside exec`), not v36's three.
2. **Default `aside repl` over Bash**, executor-driven, explicitly not MCP, with the ~1,344-token cost
   recorded as the reason, the `listBrowserTabs()` / `attachBrowserTab()` preamble present once in
   full, and `claude mcp add -s local aside -- aside mcp` named only as an optional per-operator
   escape hatch. Nothing ships, nothing registers.
3. **Dedicated profile required** — per-invocation `aside repl --account <id>`, never
   `aside account use`; the manifest records the agent's account; personal-profile-only →
   `needs_operator`, as a **third** halt distinct from the runtime one.
4. **Fallback stands** — the paragraphs are unchanged apart from `P20.S2`'s one generalizing clause.
5. **Surface facts + the rewritten argument** — `title`/`code` correctly attributed to the **MCP
   tool's schema** (not a CLI flag), stale snapshot refs / `RefStaleError` / `getByRole`, and "not
   scripted Playwright-style automation" → **"not a pre-written assertion suite"** everywhere.

Then judge quality, not just presence: **the register split** (contract = rule, agent bodies =
instruction, `design-cowork` = reasoning and invocation, seed = recorded field), the **two agent
bodies byte-identical** past frontmatter, and whether a first-time reader can tell the **three halts**
apart. `P20.S3`'s sweep says all of this is clean — **verify it, do not inherit it.** A sweep run by
the same phase that wrote the prose is exactly the check a review exists to double.

**Two arguable observations `P20.S3` logged rather than acted on** (in `slices/P20.S3/result.md`) —
judge each, and say so explicitly:
- the adjacent, differently-scoped "third condition" referents in the agent bodies (L32's profile halt
  vs L33's mockup-span condition), disambiguated in `design-cowork` but adjacent in the bodies;
- `CLAUDE.md:76` is now the contract's longest bullet at **3,267 chars**.

Either can be a finding, a deferred job, or explicitly accepted. Do not leave them unjudged.

## 3. Cross-check the notebook against the logs

`phase.md` is rewritten at every slice, so read it **and** all four `result.md` files, and confirm:

- no decision a `result.md` records was dropped from `## Decisions`;
- no `## Operator Questions` entry is left unrouted (see §5);
- the **ten `## Doc impact` lines** account for every durable-truth change the four slices actually
  made — a missing line means a doc version this review would not write.

A dropped decision or an unrouted question is a **finding**, and you may not pass with one.

## 4. Consolidate the docs — pass path only, one new version per doc

**Three docs, three versions**, each `--source P20.REVIEW`. For each:
`python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..."` → **edit only the returned
`edit_path`** under `docs/versions/<doc>/` → and after all three,
`python3 scripts/workflow.py rebuild-docs` then `python3 scripts/workflow.py validate`.
**Never** hand-edit `docs/current/*.md` or any existing file under `docs/versions/`.

Work from the ten `## Doc impact` lines; they name the passages. In outline:

- **`qa.md`** — the frontmatter `summary`; the "As of **v36** the doctrine finally names its
  instrument" intro; the *With what — the instrument (since v36)* section (two surfaces, the
  repl-over-Bash default and its measured reason, the preamble, the sharp edges, the escape hatch,
  the dedicated profile and the third halt, the fallback's generalizing clause); and the *Test
  Commands* baseline → **140 PASS / 0 FAIL at v37**.
- **`operations.md`** — the frontmatter `summary`; the v36 paragraph that says "MCP surface first"
  (~L71); the manifest section (~L703–725), where the single **optional** instrument field becomes
  two fields, the second **conditionally required**, and the *"the halt condition did not move"*
  sentence now holds only of the **runtime** halt; and a **"Coming from a pre-v37 workspace"** bullet
  in the update-path list, mirroring the pre-v36 one (~L371) — no engine change at all, `sync-agents`
  because both agent bodies changed, the seed's two manifest fields reach fresh installs only, and
  **remove any v36 `claude mcp add -s local aside -- aside mcp` registration**.
- **`decisions.md`** — the frontmatter `summary`; the count in the intro (**thirty-eight → thirty-nine**);
  and a **new v37 entry**. It must state plainly **what it supersedes**: P19's *Prescribe Aside as the
  instrument* decision was right about the instrument and **wrong about the surface** — MCP-first is
  retired, the transport reasoning survives only as the escape hatch's justification. Follow this
  doc's established supersession idiom (see the Codex paragraph at the file's end): the v36 entry
  stays as accepted history with an explicit superseding pointer; **do not rewrite its body.** Record
  the alternatives weighed and rejected, as every entry in this doc does. And record that v37 closes
  **D9**, **D11** and **D10's surface half**, with D10's real-product half re-filed as **D12**.

Doc prose is durable truth an adopter reads years later: match each doc's existing voice, and do not
turn a consolidation into a rewrite of sections this phase did not touch.

## 5. Route the questions and list the deferred work — list it, never run it

**You never run `defer-job`, `drop-deferred` or `accept-gate`.** Those are the orchestrator's. Your
job is to make the list complete and unambiguous, so it can be executed without re-deriving anything.

- **The one open `## Operator Questions` entry** — `P20.S2`'s: *does the profile rule bind the
  fallback browser too?* The gate is waived, so there is no walkthrough to fold it into; it **must**
  be routed as a deferred job. Return the exact `--title`, `--reason` and `--trigger` you want filed.
- **The deferred-job mechanics `P20.DECOMP` recorded** in `## Decisions`, for the orchestrator to run:
  drop **D9** (the fallback stands), drop **D11** (answered and written into the doctrine), drop
  **D10** and re-file its against-a-real-product half as a new job. Verify those reasons still hold
  after the phase actually shipped — particularly D10's, which turns on v37 no longer prescribing the
  MCP surface its title names — and return the exact commands.

## 6. Return

- `review_verdict`: `pass` | `changes_requested` (numbered findings + proposed `P20.Fn` fix slices) |
  `blocked`.
- `doc_versions`: the three version ids you created, or why not.
- The deferred/question list from §5.
- `walkthrough`: **none** — the gate is waived.
- `explain`: the fixed pointer `explain: not written — run /explain for this phase`. **Write no
  explainer** — explaining is a separate operator-run operation.

## Do not

- Run `accept-gate`, `defer-job`, `drop-deferred`, `finish-slice`, any status transition, or any git
  command. **`review-phase` is the orchestrator's** — it transitions both the phase and this slice, so
  there is no `finish-slice` for a review slice at all.
- Edit source, machinery, `CLAUDE.md`, the agent bodies, the skills, the tests, or the installer.
- Consolidate docs on a non-passing verdict, or hand-edit `docs/current/*` / existing
  `docs/versions/*` files.
- Bump the version, touch `CHANGELOG.md`, or renumber anything — **P21 takes v38**, per its
  `intent.md`; leave that to P21.
- Archive the phase. A pass leaves it `done` in `active/`.
