# Result — P20.S1 (correct the surface taxonomy and prescribe `aside repl` over Bash)

- **status:** `done`
- **summary:** Rewrote the Aside surface doctrine across all six live carriers — two surfaces instead of
  three, `aside repl` over Bash as the executor-driven default with the measured ~1,344-token MCP cost as
  its recorded reason, the MCP registration demoted to a named per-operator escape hatch, and "scripted
  Playwright-style automation" retargeted to "a pre-written assertion suite" — and updated
  `retrofit_smoke.sh` to pin the v37 strings (positives **and** negatives) instead of the retired v36 ones.
- **files_changed:**
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/CLAUDE.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/agents/slice-executor-mid.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/agents/slice-executor-high.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/skills/design-cowork/SKILL.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/skills/review-phase/SKILL.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/installer/payloads/doc_bodies/operations.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/tests/retrofit_smoke.sh`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh` (rebuilt, never hand-edited)
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/works/phases/active/P20/phase.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/works/phases/active/P20/slices/P20.S1/result.md`
- **validation:**
  - `python3 installer/build.py` — PASS (wrote 444327 bytes)
  - `python3 installer/build.py --check` — PASS (artifact in sync with `installer/` source)
  - `python3 scripts/workflow.py sync-agents --check` — PASS (mid sonnet@xhigh / high opus@xhigh, flex, no drift)
  - `bash tests/retrofit_smoke.sh` — PASS, **139 PASS / 0 FAIL** (same count as the v36 baseline: the v37
    assertions live inside existing checks, so no new check line was added)
  - `python3 scripts/workflow.py validate` — PASS
  - stale-wording grep (`MCP surface|mcpServers|scripted Playwright-style` over `CLAUDE.md .claude/
    installer/payloads/ tests/`) — only intended hits remain (see below)
- **deviations:** three, all deliberate — the retired contract title, the `title`/`code` correction, and
  keeping "Aside first" in agent lines 33/36. Detail below.
- **doc_impact:** three lines appended to `works/phases/active/P20/phase.md` (`qa.md`, `decisions.md`,
  `operations.md`) — quoted in the *Doc impact* section below.
- **No browser was run and no browser claim is made.** This slice writes the prescription; it does not
  exercise it. The only Aside invocations were `aside --help` and `aside repl --help` (read-only, no
  browser), used to get the CLI's real invocation shape rather than invent one.

---

## What was rewritten, where

Notebook state (decisions, notes, `## Now`) is in
`works/phases/active/P20/phase.md` — not restated here.

**1. `CLAUDE.md` line 76 — the hard rule.** Title → *"Real-browser verification runs through Aside, not a
pre-written assertion suite."* The surface sentence now carries the rule and only the rule: two surfaces
(`repl`, identical over `aside mcp` and the `aside repl` CLI — same Playwright-like environment, different
transport only, executor picks each next action; and `aside exec`, Aside's own model driving), **the default
is `aside repl` over Bash** with the token cost stated in one parenthetical (`~1,344 tokens, no lazy-load`,
paid every session), Bash already allowlisted so nothing ships/registers/configures, and
`claude mcp add -s local aside -- aside mcp` named once as the optional per-operator escape hatch — the v36
"native tools in a dispatched session" fact kept exactly there, where it explains the hatch. The reasoning is
pushed to `design-cowork` by one pointer sentence. `**Instrument and runtime are different axes:**` and the
whole `**The fallback:**` sentence are byte-identical to v36.

**2. Both agent bodies, line 32.** Identical text in `mid` and `high` (the smoke test's body-diff check
still passes). The concrete invocation an executor actually runs now lives here: `aside repl "<js>"`, one
tool, `page` / `snapshot()` / locators / page JS / screenshots, "**you** pick each next action", re-attach via
the two-line `listBrowserTabs()` → `attachBrowserTab()` preamble *written out in full in `design-cowork`*
(named, not duplicated — the notebook's "once in full" rule), and **never a standing `aside mcp`
registration** with the ~1,344-tokens-per-session reason inline. Lines 33 and 36 are unchanged (see the
judgment calls).

**3. `design-cowork/SKILL.md` — the long-form home.** Four passages:
- ~278, the mockup's *Verified in the operator's runtime* bullet: `(**Aside**, MCP first)` →
  `(**Aside**, the `repl` surface over Bash)`, re-wrapped over the two lines.
- *With what — the instrument* (now ~420-455): rewritten whole. Two-surface bullet list; the
  repl-over-Bash default with the measurement spelled out (4,974 JSON chars ≈ ~1,344 tokens, every session,
  no lazy-load, "taxes every slice for a capability almost none of them use"); the re-attach preamble as a
  real `js` code fence; the two sharp edges (`title`+`code`, and session/snapshot-scoped refs going stale on
  navigation with `RefStaleError` while `getByRole` survives); and the escape hatch as the last sentence. The
  `{"mcpServers":{...}}` JSON block is **deleted** — the workspace no longer tells anyone to configure it.
- *Why an agent and not a script* → **_Why the executor drives, and not a pre-written suite_**. The
  argument's shape and its evidence (the thirty-slice phase whose scripted fidelity slice passed while
  eleven user-visible failures survived) are untouched; only the target moved: the surface *is* Playwright,
  so what is rejected is **deciding every check in advance**, and the demands pass "only when something
  looks at the page and chooses the next action".
- ~500, the anti-pattern bullet: "a scripted assertion suite is no substitute for a browsing agent" → "a
  pre-written assertion suite is no substitute for an executor that looks at the page and picks the next
  action", with `(`aside repl` over Bash)` beside the instrument.
- The fallback paragraph (now ~462-466) is untouched, as instructed.

**4. `review-phase/SKILL.md` line 43, gate stage 2.** Same treatment, one sentence: the `repl` surface over
Bash, `aside repl "<js>"`, preamble pointer, "never a standing `aside mcp` registration", "in place of a
pre-written assertion suite". `the doctrine's demands bind, the instrument does not` and `with the same
instrument as stage 2` (stage 4) are untouched.

**5. `installer/payloads/doc_bodies/operations.md` line 28.** `<Aside (`aside mcp`) if installed here …>` →
`<Aside (driven as `aside repl` over Bash) if installed here …>`. The field label
`- Browser instrument for the agent:` and the clause `its absence alone never stops a slice` are unchanged,
the block is not restructured, and the line beside it is left free for `P20.S2`'s profile field.

## The smoke test (`tests/retrofit_smoke.sh`)

Retired (string no longer exists) and **replaced by an assertion pinning its successor** — nothing was
weakened or simply deleted:

| retired v36 assertion | replacement |
|---|---|
| design: `` "`aside mcp`" `` | `"claude mcp add -s local aside -- aside mcp"` (pins where `aside mcp` now lives: the escape hatch) |
| design: `"in place of scripted Playwright-style automation"` | `"in place of a pre-written assertion suite"` |
| `CLAUDE.md`: `"**Real-browser verification runs through Aside, not a script.**"` | `"**Real-browser verification runs through Aside, not a pre-written assertion suite.**"` |

New v37 positives, in the surrounding `# v37: …` comment idiom:
- **design** — `"**two surfaces, not three**"`, ``"**The default is `aside repl` over Bash**"``,
  `"~1,344 tokens"`, `"nothing ships, nothing registers, nothing is configured"`,
  `"const page = await attachBrowserTab(tabs[0].targetId);"` (the preamble is really there),
  ``"requires both `title` and `code`"``, `"RefStaleError"`, `"escape hatch"`,
  `"**Why the executor drives, and not a pre-written suite.**"`, `"deciding every check in advance"`.
- **review-phase** — ``"the `repl` surface over Bash"``, ``"never a standing `aside mcp` registration"``,
  `"in place of a pre-written assertion suite"`.
- **ops seed** — ``assert "`aside repl` over Bash" in ops`` and ``assert "aside mcp" not in ops``.
- **agent bodies** (inside the per-tier loop, so each is asserted twice) — ``"Run its `repl` surface over
  Bash"``, ``"`aside repl \"<js>\"`"``, ``"`listBrowserTabs()` → `attachBrowserTab()`"``,
  ``"never a standing `aside mcp` registration"``, `"in place of a pre-written assertion suite"`.
- **`CLAUDE.md`** — `"**Two surfaces, not three:**"`, ``"**The default is `aside repl` over Bash**"``,
  `"~1,344 tokens"`, and the whole escape-hatch clause.

New v37 **negatives**, written the way v35's and v31's are:
- design: `'{"mcpServers"'`, `"Prefer the **MCP** surface"`, `"MCP first"`,
  `"scripted Playwright-style automation"`, `"scripted assertion suite"`
- review-phase and both agent bodies: `"MCP surface first"`, `"scripted Playwright-style automation"`
- `CLAUDE.md`: `"Prefer the **MCP** surface"`, `"scripted Playwright-style automation"`,
  `"runs through Aside, not a script"`

Also updated: the file's header comment (lines 12-15) and the Test 5 `ok`/`bad` summary line, which now
names "the v37 Aside-surface invariants (two surfaces, `aside repl` over Bash, no standing MCP registration,
the assertion-suite framing)". The `WORKSPACE_VERSION` three-way-equality assertion was **not** touched —
that is `P20.S3`'s.

**One trap worth recording for `P20.S2`** (also now a note in `phase.md`): in Test 5 the design-cowork text
is read whitespace-**normalised** — `design = " ".join(... .read_text().split())` — so an assertion that
spans a wrapped line must be written on one line with single spaces. Two of my first-draft assertions
contained `\n` and failed; the review/ops/agent/contract texts are *not* normalised, but their passages are
single long lines anyway.

## Judgment calls / deviations from `plan.md`

1. **The contract rule's title changed** (`"…runs through Aside, not a script."` → `"…not a pre-written
   assertion suite."`), and its smoke assertion now pins the new string. The plan listed the old title among
   the strings to walk, and permits updating a string as long as the assertion pins the replacement. Reason:
   the v37 default *is* an executor writing small JS snippets, so "not a script" now reads as forbidding
   exactly what the doctrine prescribes; "not a pre-written assertion suite" says what is actually rejected.
   Also aligns the contract title, the `design-cowork` heading and the anti-pattern bullet on one phrase.
2. **`title` + `code` is an MCP-tool requirement, not a CLI flag.** `intent.md` part 5 records "`repl`
   requires both `title` and `code`". `aside repl --help` (Aside CLI 1.26.810.1915) shows
   `Usage: aside repl [options] [code...]` with only `--account` and `-h` — **no `--title`**; the code is
   positional. So the doctrine states it as the MCP-transport fact it is: "Over MCP the `repl` tool
   **requires both `title` and `code`** — a call omitting either fails (over the CLI the code is positional:
   `aside repl "await openTab('<url>')"`)". Writing `aside repl --title … --code …` into the agent bodies
   would have shipped an invocation that fails on the machine where it was measured.
3. **"Aside first" kept in agent lines 33 and 36** (the mockup-span and review-gate pointers), as the plan
   preferred. With MCP-first gone from every long form, the phrase can only read as *Aside before the
   fallback browser*, which part 4 leaves true. Both assertions therefore stand unchanged in both tiers.
4. **`design-cowork`'s heading changed** — *"Why an agent and not a script."* → *"Why the executor drives,
   and not a pre-written suite."* The plan invited this consideration explicitly. The old heading is now
   doubly wrong: the "agent" is the executor, and the thing rejected is not scripting. No assertion pinned
   the old heading; the new one is now asserted.
5. **`aside exec` got one clarifying half-sentence** the plan did not ask for ("Useful for a broad look; it
   is not what a check you must be able to describe runs on"), because naming a second surface without
   saying when it is *not* the answer invites an executor to pick it for a fidelity sweep.

## Stale-wording grep

`grep -rn "MCP surface\|mcpServers\|scripted Playwright-style" CLAUDE.md .claude/ installer/payloads/ tests/`
leaves only intended hits:
- `.claude/skills/explain/SKILL.md:351` — "the KB's search and MCP surfaces", unrelated to Aside.
- `tests/retrofit_smoke.sh` lines 165-166, 181, 251, 317 — the v37 **negative** assertions, which must
  contain the retired strings in order to forbid them.

`docs/current/*`, `docs/versions/*`, `works/phases/archived/*` still carry the v36 wording by design: the
first is a generated snapshot the review consolidates (see *Doc impact*), the rest are history.

## Doc impact (appended to `phase.md`, not versioned here)

- `qa.md`: *Verification doctrine* / *With what — the instrument* — two surfaces not three; the `aside
  repl`-over-Bash default with the ~1,344-token MCP cost as its reason; the re-attach preamble and the
  `title`/`code` + `RefStaleError` facts; "scripted Playwright-style automation" → "a pre-written assertion
  suite"; MCP demoted to an operator escape hatch. (P20.S1)
- `decisions.md`: a v37 entry superseding v36's MCP-first prescription (P19's *Prescribe Aside as the
  instrument*) — same doctrine, corrected surface taxonomy and corrected default. (P20.S1)
- `operations.md`: the seeded `- Browser instrument for the agent:` field now reads `aside repl` over Bash,
  not `aside mcp`; the v36 prose saying "MCP surface first" needs the same correction. (P20.S1)

No `doc-new-version` was run, `docs/current/*` was not edited, and no workflow state-transition or git
command was run.
