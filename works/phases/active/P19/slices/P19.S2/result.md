# Result — P19.S2: Aside as the prescribed real-browser verification instrument; v36

- **status:** done
- **summary:** Named the instrument the verification doctrine has demanded since v32 and never had: **Aside**, MCP surface first (`aside mcp`), with the `aside` CLI and `aside repl` as the Bash surfaces, **in place of scripted Playwright-style automation** — written as prescription + surface + fallback across `design-cowork`'s *Verifying*, `review-phase`'s gate stages, a new `CLAUDE.md` Hard Rule and both agent bodies, with instrument and runtime kept on separate axes and no verified Aside run claimed anywhere. Bumped `WORKSPACE_VERSION` to **36** and wrote the `CHANGELOG.md` `## v36` section covering both middle slices.
- **files_changed:** `.claude/skills/design-cowork/SKILL.md`, `.claude/skills/review-phase/SKILL.md`, `CLAUDE.md`, `.claude/agents/slice-executor-mid.md`, `.claude/agents/slice-executor-high.md`, `installer/payloads/doc_bodies/operations.md`, `installer/main.py`, `CHANGELOG.md`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P19/phase.md`, this file
- **validation:** `python3 scripts/workflow.py validate` — pass · `bash tests/retrofit_smoke.sh` — pass (139 PASS / 0 FAIL) · `python3 installer/build.py` then `python3 installer/build.py --check` — pass (`OK`, artifact left in the tree) · agent-body byte-identity below the frontmatter — asserted directly and by the smoke test
- **deviations:** none from the plan's instructions. Three judgement calls it explicitly left to me are recorded below (one seed line in the operations body, none in the qa body; a new `CLAUDE.md` Hard Rule rather than an extension of the manifest rule; one new `## Operator Questions` entry).
- **doc_impact:** three lines appended to `phase.md` — `qa.md` (the doctrine names its instrument, with the fallback), `operations.md` (the seed manifest's new *Browser instrument for the agent* field + the v36 update note), `decisions.md` (why Aside is prescribed as doctrine rather than integrated as tooling, and why instrument and runtime are separate axes)
- **doc_versions:** n/a (not a review slice — no `doc-new-version` run, no `docs/current/*` edited)
- **no Aside run was made.** Aside is not installed here (macOS desktop app, account required, installing it is an operator-only outward-facing action). Everything below is doctrine and prose; the surface facts are cited from the vendor docs, not from execution.

## What changed, and where

**`.claude/skills/design-cowork/SKILL.md` — the canonical statement.** *Verifying* already specified
**what** to check (the four-item functional sweep) and **where** (*Where it runs*); it never said
**with what**. Three new paragraphs sit between those two and *Re-run the whole list*:

- **With what — the instrument.** Aside is the default, MCP first (`aside mcp`, with the client
  config snippet) *because an MCP server's tools arrive as native tools in a dispatched executor's
  session, which a shell-out does not*; the CLI is the one-shot Bash surface and `aside repl` the
  deterministic-inspection one.
- **Why an agent and not a script.** One paragraph, pointing at the doctrine rather than restating
  it: an assertion suite tests the selectors someone already thought of, and no demand in the sweep
  is of that shape.
- **The fallback — the doctrine's demands bind, the instrument does not.** Same sweep, same
  viewports, same manifest runtime, another real browser. Name the instrument used in `result.md`;
  never report a run you did not make.

Plus two one-clause edits: *Where it runs*' bare "never assume headless" now carries its reason (a
browsing agent drives a visible browser, and Aside's headless story is undocumented), and the mockup
bullet says the mockup is driven with the same instrument — its exemption is from the **sweep**,
never from the runtime or the tooling. The *Never* list gained one clause: a scripted assertion
suite is no substitute for a browsing agent, and a workspace without Aside owes the same checks
through another real browser, never weaker ones.

**`.claude/skills/review-phase/SKILL.md`** — gate stage 2 (which S1 deliberately left to me) now
names the instrument, the MCP-first surface, the fallback, and the ban on reporting a walk that was
not made, and says the same instrument serves stages 3 and 4; stage 4 says "in the manifest runtime
and with the same instrument as stage 2".

**`CLAUDE.md`** — one new Hard Rule, immediately after the operator-runtime-manifest rule:
*Real-browser verification runs through Aside, not a script.* It carries the instrument, the four
places a real browser is needed, the MCP-first surface with its reason, the axis separation, and the
fallback.

**Both agent bodies** (edited identically; byte-identity below the frontmatter re-asserted after):
the *Do* step-1 implementation bullet gains the instrument sentence and the fallback; the mockup-span
bullet gains "driven with the same instrument (Aside first)"; the review bullet's gate stage 2 gains
"driving it with the same instrument (Aside first, the fallback browser otherwise)".

**`installer/payloads/doc_bodies/operations.md`** — exactly one new field line in the seeded
`## Operator Runtime` block (reasoning below).

**`installer/main.py`** `WORKSPACE_VERSION = 36`, and a **`## v36`** `CHANGELOG.md` section covering
**both** middle slices: the research kind with its four semantics, `DECOMP2`'s two origins, the Aside
prescription with its surface and fallback, the axis separation, an explicit "v36 ships the doctrine,
not an integration — no verified Aside run has been made from an executor here", and **Migration
notes** (`sync-agents`; the engine change is purely additive; the new seed field reaches fresh
installs only because `--update` never touches `docs/`, and its absence never stops a slice).

## The three judgement calls the plan left open

**1. Prescription strength.** Written as **prescription + surface + fallback**, with the honesty in
the prose rather than in a caveat: the prescription is unconditional in voice ("drive that browser
with Aside"), and the fallback is framed as *the doctrine's demands bind, the instrument does not* —
so it excuses no check, no viewport and no runtime, and cannot be read as making the prescription
decorative. Nothing anywhere is written as a hard gate a Linux workspace fails, nothing installs or
calls Aside, and no verified run is claimed.

**2. Axis separation.** Stated explicitly in `CLAUDE.md` and honoured everywhere else: *Aside drives
the runtime `## Operator Runtime` records and never substitutes one of its own, and the
absent/`UNFILLED` → `needs_operator` rule is about the **runtime**, not the instrument — a manifest
naming no instrument is not an unfilled one.* That last clause is load-bearing for adopters: every
existing workspace's manifest names no instrument, and without it the new seed field would silently
become a new halt condition on every workspace that never receives it.

**3. How far into the seeds — one line, in the operations body only.** The qa seed carries no
verification-doctrine section and gets none: the doctrine is agent behaviour and travels in the
skills and agent bodies, which every workspace receives. The operations seed gets exactly one field:

```
- Browser instrument for the agent: <Aside (`aside mcp`) if installed here, else the real browser it may drive — optional; its absence alone never stops a slice>
```

It earns its place because the fallback branch turns on a **per-machine fact** that no skill can
carry and that an agent should not decide on the operator's behalf: whether Aside is installed, and
which real browser an agent may drive on this machine. That is availability, not doctrine, so it
stays on the runtime axis, and the manifest is already where per-machine runtime facts live. It is
explicitly optional — the halt condition is unchanged — so a fresh workspace that ignores it loses
nothing, and an absent field never turns into a `pending`.

## Validation detail

- `python3 scripts/workflow.py validate` → `Workflow validation passed.`
- `python3 installer/build.py` → rebuilt `bootstrap_agentic_workspace.sh` (440,485 bytes);
  `--check` → `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`. Run after the
  machinery edits, so the committed artifact matches `installer/` source and the smoke test's
  dual-apply comparison passes.
- `bash tests/retrofit_smoke.sh` → `ALL RETROFIT SMOKE TESTS PASSED`, **139 PASS / 0 FAIL**. The
  count is unchanged from S1 on purpose: every new assertion lives **inside** Test 0's existing
  Python block, which reports one `ok`/`bad` line however many invariants it checks.

New assertions (prose is otherwise undefended against later drift — the same reasoning S1 used):

- `design-cowork`: `**With what — the instrument.**`, `` `aside mcp` ``,
  `in place of scripted Playwright-style automation`,
  `The fallback — the doctrine's demands bind, the instrument does not.`
- `review-phase`: `**Drive it with Aside**`, the fallback clause, `with the same instrument as stage 2`
- `CLAUDE.md`: the Hard Rule's opening, `**Instrument and runtime are different axes:**`, the fallback clause
- **both** agent bodies (inside the existing per-tier loop, so drift between the tiers fails too):
  `Drive that browser with **Aside**`, the fallback clause,
  `Name in \`result.md\` which instrument you used`, `driven with the same instrument (Aside first)`,
  `driving it with the same instrument (Aside first, the fallback browser otherwise)`
- operations seed: `- Browser instrument for the agent:` and `its absence alone never stops a slice`
- The header comment and Test 0's `ok`/`bad` strings were **extended**, not replaced: they now read
  "the v36 research-kind and Aside-instrument invariants".

## Surface facts, cited not executed

The commands and the MCP config snippet were re-confirmed against `docs.aside.com/help/developers`
during this slice (`aside "<task>"`, `aside --session <id>`, `aside --account <id>`,
`aside exec --account <id> -m <model>`, `aside account list|status|use`, `aside mcp`, `aside repl`,
and `{"mcpServers":{"aside":{"command":"aside","args":["mcp"]}}}`). That page **does not document a
headless mode**, which is why the "never assume headless" clause now cites it as a reason rather
than only as a prohibition. macOS-only and the account requirement come from `P19.DECOMP`'s
investigation (see `phase.md` `## Operator Questions`), not from this session. **No `aside` binary
was installed, invoked, or probed here.**

## Notebook

`phase.md` was edited under budget: the six consumed `for P19.S2` notes were dropped, `## Decisions`
was compressed where both middle slices have now landed (the detail lives in this file and in
`slices/P19.S1/result.md`), three `## Doc impact` lines and one `## Operator Questions` entry were
appended, one note was left for `P19.REVIEW`, and `## Now` was rewritten as the review's handoff. See
`works/phases/active/P19/phase.md`; nothing from it is restated here.
