# Plan — P20.S1 (correct the surface taxonomy and prescribe `aside repl` over Bash)

- Phase: **P20** — make the Aside prescription true
- Kind / risk: `implementation / high` → **`slice-executor-high`**
- Order 1 of 3; `P20.S2` (profile safety) and `P20.S3` (release) follow. Mode: `auto`.

## What this slice is

**Intent parts 1, 2 and 5** — the *surface truth*: what the instrument is, how it is driven, and why.
You own **every surface-wording rewrite** across the live carriers, plus the smoke-test assertions that
pin those exact strings. You do **not** touch the profile question (part 3 — `P20.S2` owns it), you do
**not** touch the fallback paragraphs (part 4 is unchanged), and you do **not** bump the version or
write the changelog (`P20.S3`).

Read first, whole: `works/phases/active/P20/phase.md` (the notebook — `## Decisions`, and the
`## Notes for later slices` tagged for `P20.S1`) and `works/phases/active/P20/intent.md` (the confirmed
five-part intent, with the live-verified measurements). The notebook's blast radius and passage
ownership are already correct — **do not re-inventory the tree**.

## The doctrine to write — the operator's confirmed content, not yours to redecide

**1. Two surfaces, not three.** v36 names three (MCP / CLI / REPL) as if they were peers. Execution
shows **two**:

- the **`repl` surface** — one tool, **identical** over `aside mcp` and the `aside repl` CLI: the same
  Playwright-like environment (`page`, `snapshot()`, locators, page JS, screenshots), **different
  transport only**. The executor holds the surface and **chooses each next action itself**.
- **`aside exec`** — **Aside's own model** drives the browser from a natural-language instruction.

The old three-way split confused a *transport* difference (MCP vs CLI) with a *surface* difference,
and hid the one distinction that matters: **who picks the next action.**

**2. The default is `aside repl` over Bash, executor-driven — explicitly NOT the MCP transport.**
Both halves of that are load-bearing, and the reason is **recorded, not asserted**:

- `aside mcp` exposes **one** `repl` tool whose definition measures **4,974 JSON chars (~1,344 tokens)**
  and is paid **in every session, browser-related or not**, with **no lazy-load option**. A standing
  MCP registration taxes every slice in the workspace for a capability almost none of them use.
- The one thing the CLI loses — JS scope between invocations — is **bought back with a two-line
  re-attach preamble**, verified live:
  ```js
  const tabs = await listBrowserTabs();
  const page = await attachBrowserTab(tabs[0].targetId);
  ```
  Write that preamble **once, in full**, where an executor will actually read it before driving a
  browser (the notebook says `design-cowork` / the long-form home — not repeated in five files).
- **`repl` requires both `title` and `code`** — a call omitting either fails.
- **Bash is already in both executor tiers' allowlists**, so **nothing ships, nothing registers,
  nothing is configured**. That is the point: the default costs zero tokens until used.
- `claude mcp add -s local aside -- aside mcp` is named **once**, as an **optional per-operator,
  per-session escape hatch the workspace neither ships nor prescribes** — an operator who wants native
  tools in their own session may register it; the workspace never does it for them.

The v36 sentence *"Prefer the **MCP** surface … because an MCP server's tools arrive as native tools in
a dispatched executor's session, which a shell-out does not"* is now **wrong as a prescription** and
must go everywhere it appears. Its factual half stays true — that is exactly why the escape hatch
exists — so retire the *preference*, keep the *fact* where it explains the hatch. Delete the
`{"mcpServers":{"aside":{"command":"aside","args":["mcp"]}}}` JSON block in `design-cowork`: the
workspace no longer tells anyone to configure that.

**5. Recorded surface facts, and the rewritten argument.**

- Snapshot **refs are session- and snapshot-scoped** and go **stale on navigation** (`RefStaleError`);
  **`getByRole` survives it.** An executor that navigates and then reuses a ref gets an error, not a
  wrong click — worth one line where the preamble lives.
- **"not scripted Playwright-style automation" becomes "not a pre-written assertion suite."** This is
  the sharpest correction in the phase and it must be made in *every* place the old phrasing appears.
  The v36 wording is now false on its face: **the surface *is* Playwright.** What the doctrine rejects
  was never the library — it is **deciding every check in advance**. The demands the doctrine already
  makes (type into it and wait; watch a timer tick for a real interval; catch the browser defaults the
  record never drew) fail against a suite of pre-written assertions no matter what drives it, and pass
  only when something **looks at the page and chooses the next action**. Keep the argument's existing
  shape and its evidence (the thirty-slice phase whose scripted fidelity slice passed while eleven
  user-visible failures survived) — replace the *target* of the argument, not the argument.

## Files you own — the passages, with anchors

Machinery only. All of it ships to adopters, so the wording is the product.

1. **`CLAUDE.md` ~line 76** — the hard rule **"Real-browser verification runs through Aside, not a
   script."** Rewrite the surface sentence (*"Prefer the **MCP** surface (`aside mcp`; …), with the
   `aside` **CLI** for a one-shot check and `aside repl` for deterministic inspection."*) into the
   two-surface taxonomy + the `aside repl`-over-Bash default + the escape hatch, and change the
   "in place of scripted Playwright-style automation" clause to the assertion-suite framing. **Keep**
   `**Instrument and runtime are different axes:**` and the whole `**The fallback:**` sentence — both
   are asserted by the smoke test and part 4 is unchanged. Contract prose is **compact by design**:
   this is a routing contract, so the rule gets the *rule*, not the reasoning. Do not let it grow into
   the essay that belongs in `design-cowork`.
2. **`.claude/agents/slice-executor-high.md` and `.claude/agents/slice-executor-mid.md`** — **lines
   32, 33, 36**, and they are **body-identical between the tiers**; the smoke test asserts each string
   in **both**. Line 32 (implementation/`fix` bullet) carries the full surface sentence and is the main
   edit; lines 33 and 36 carry the short pointers `driven with the same instrument (Aside first)` and
   `driving it with the same instrument (Aside first, the fallback browser otherwise)` — **judge
   whether "Aside first" still reads right.** It was shorthand for *MCP first*, but it also reads as
   *Aside before the fallback browser*, which stays true. Prefer keeping them (they are asserted, and
   part 4 is unchanged); if you do change them, change both tiers, both lines, and the assertions
   together. These bodies are generated-adjacent — `executors.toml` owns the frontmatter — so edit body
   text only and run `python3 scripts/workflow.py sync-agents --check` after.
   **An executor is the one reader who will actually run this**, so line 32 is where the concrete
   invocation belongs: `aside repl` over Bash, with the re-attach preamble reachable.
3. **`.claude/skills/design-cowork/SKILL.md`** — the long-form home (with the qa doc, which is a
   generated snapshot you do not touch). Four passages:
   - **~line 278**, the mockup's *Verified in the operator's runtime* bullet — `(**Aside**, MCP first)`
     must stop saying MCP first.
   - **~lines 420–427, "With what — the instrument."** — the main rewrite: the two-surface taxonomy,
     the `aside repl`-over-Bash default with the token measurement as its stated reason, the re-attach
     preamble **in full**, the `repl`-needs-`title`-and-`code` and stale-ref facts, and the escape
     hatch. **Delete the `mcpServers` JSON.**
   - **~lines 429–433, "Why an agent and not a script."** — retarget to the pre-written assertion
     suite; consider whether the heading itself still says the right thing now that the surface *is*
     Playwright and the agent *is* the executor.
   - **~lines 500–502**, the anti-pattern bullet ("a scripted assertion suite is no substitute for a
     browsing agent") — align the wording.
   - **Leave ~lines 435–439 (the fallback) exactly as written.**
4. **`.claude/skills/review-phase/SKILL.md` line 43**, gate stage 2 — the same surface sentence, same
   treatment. Keep `the doctrine's demands bind, the instrument does not` and
   `with the same instrument as stage 2` (both asserted).
5. **`installer/payloads/doc_bodies/operations.md` line 28** — the seeded manifest field
   `- Browser instrument for the agent: <Aside (\`aside mcp\`) if installed here, …>`. Retire
   `aside mcp` from the placeholder. **Keep** `- Browser instrument for the agent:` as the field label
   and the clause `its absence alone never stops a slice` — both are asserted, and `P20.S2` adds the
   **profile** field beside this one, so leave that room and do not restructure the block.
6. **`tests/retrofit_smoke.sh`** — see below. Not optional, not deferrable to `P20.S3`.

## The smoke test — update it in this slice or the commit breaks

`tests/retrofit_smoke.sh` **Test 5** is one python heredoc that pins the exact v36 strings you are
rewriting. Walk these and make each one true again — by updating the string, or by replacing the
assertion with one that pins the *new* invariant:

- **design-cowork block (~138–142):** `"**With what — the instrument.**"` (heading — keep if you keep
  the heading), `` "`aside mcp`" ``, `"in place of scripted Playwright-style automation"` ← **both
  must change**, `"The fallback — the doctrine's demands bind, the instrument does not."` ← **keep**.
- **review-phase block (~149–153):** `"**Drive it with Aside**"`,
  `"the doctrine's demands bind, the instrument does not"`, `"with the same instrument as stage 2"`.
- **ops seed (~159–163):** `"- Browser instrument for the agent:"`,
  `"its absence alone never stops a slice"` ← **both keep**.
- **agent bodies (~197–205, inside the per-tier loop so each string is asserted twice):**
  `"Drive that browser with **Aside**"`, `"the doctrine's demands bind, the instrument does not"`,
  `"Name in \`result.md\` which instrument you used"`, `"driven with the same instrument (Aside first)"`,
  `"driving it with the same instrument (Aside first, the fallback browser otherwise)"`.
- **`CLAUDE.md` block (~255–259):** `"**Real-browser verification runs through Aside, not a script.**"`,
  `"**Instrument and runtime are different axes:**"`,
  `"**the doctrine's demands bind, the instrument does not.**"`.
- **Test 5 summary line ~274** — it names "the v36 … Aside-instrument invariants"; extend it to name
  v37's if you add assertions.

**Add positive assertions for what v37 actually prescribes**, in the same style and comment idiom as
the surrounding blocks (`# v37: …`) — at minimum that the default is `aside repl` over Bash and not the
MCP transport, that the token cost is recorded as the reason, and that the assertion-suite framing
replaced the Playwright one. **Do not weaken an assertion to make it pass** — if a string no longer
appears, the assertion should pin its replacement, not disappear. And consider a **negative**: the
retired MCP-first prescription (e.g. the `mcpServers` JSON) should be gone, the way v35's and v31's
negatives are written.

Leave the `WORKSPACE_VERSION` three-way-equality assertion (~line 395) alone — that is `P20.S3`'s.

## Validate

Run all of these, in order, and record the outcomes in `result.md`:

1. `python3 installer/build.py` — **mandatory**: you edited machinery, and the orchestrator commits at
   this slice's boundary. Leave the rebuilt `bootstrap_agentic_workspace.sh` in the tree.
2. `python3 installer/build.py --check` — must pass.
3. `python3 scripts/workflow.py sync-agents --check` — must report no drift.
4. `bash tests/retrofit_smoke.sh` — **the full run**, all tests, must be green. Report the PASS/FAIL
   counts; the v36 baseline was **139 PASS / 0 FAIL**, so say what v37 makes it.
5. `python3 scripts/workflow.py validate` — must pass.
6. A stale-wording grep over the live tree for the retired prescription — `grep -rn "MCP surface\|mcpServers\|scripted Playwright-style"` over `CLAUDE.md .claude/ installer/payloads/ tests/` — should return only hits you intend (e.g. the escape hatch, or the historical framing inside a comment). `docs/current/*`, `docs/versions/*`, `works/phases/archived/*` and `bootstrap_agentic_workspace.sh` are **not** live carriers: expected hits there are history or generated output.

No real browser is needed and **no browser claim may be made**: this slice writes the prescription, it
does not exercise it.

## Notebook and result

- **Edit `phase.md`** (do not merely append), under the 200-line / 16 KB budget:
  **drop** the notes tagged for `P20.S1` that you consumed (the argument-placement note and the
  nothing-installs note are S1-and-S2 — drop only if S2 no longer needs them, otherwise re-tag);
  add any decision that later slices need in `## Decisions` (replace, never stack); append your
  `## Doc impact` lines; rewrite `## Now` (≤ 15 lines) as `P20.S2`'s handoff — say plainly which
  passages are already rewritten so S2 adds the profile rule *into* the new text, not the old.
- **`## Doc impact` — expect at least three**, one line each, in the shipped shape
  `- <doc>.md: <what changed> (P20.S1)`: `qa.md` (*Verification doctrine* / *With what — the
  instrument*: two surfaces, the repl-over-Bash default and its token reason, the assertion-suite
  framing), `decisions.md` (a v37 entry superseding v36's MCP-first prescription), `operations.md`
  (the reseeded manifest field). **Do not** edit `docs/current/*` or run `doc-new-version` — the review
  consolidates.
- **`result.md`, verdict block first**, then the log: what you rewrote where, the assertions you
  retired/replaced/added with their reasoning, the smoke-test counts, and any judgment call you made
  (especially on "Aside first" in agent lines 33/36, and on the *"Why an agent and not a script"*
  heading). Do not restate what you put in `phase.md` — reference it by path in a line.

## Do not

- Touch the **profile** question in any file (`aside --account`, dedicated vs personal profile, the
  new `needs_operator` halt) — that is `P20.S2`, and writing it here would collide.
- Change the **fallback** paragraphs, or the instrument/runtime axes rule.
- Bump `WORKSPACE_VERSION`, write a `## v37` CHANGELOG section, or edit `installer/main.py`.
- Edit `docs/current/*`, `docs/versions/*`, `docs/index.json`, `works/phases/archived/**`, the
  generated dashboards, or another slice's `plan.md`.
- Hand-edit `bootstrap_agentic_workspace.sh` — it is built.
- Run any git command, any status transition, `accept-gate`, `doc-new-version`, `defer-job` or
  `drop-deferred`. The orchestrator owns all of it.

## Verdict

Return the structured verdict block. `summary` in one line. Use `escalate` only if the slice turns out
to be materially different from this plan; `needs_operator` if the rewrite would require a decision
`intent.md` does not already settle — it settles all five parts, so that should not happen.
