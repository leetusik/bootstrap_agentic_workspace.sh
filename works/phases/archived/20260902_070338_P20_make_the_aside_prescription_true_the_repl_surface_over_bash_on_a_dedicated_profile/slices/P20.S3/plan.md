# Plan — P20.S3 (ship workspace v37: version, changelog, consistency sweep)

- Phase: **P20** — make the Aside prescription true
- Kind / risk: `implementation / high` → **`slice-executor-high`**
- Order 3 of 3, the last slice before `P20.REVIEW`. Depends on `P20.S1` and `P20.S2`, both **done**.
- Mode: `auto`. Today is **2026-09-01**.

## What this slice is

The **release**, and the one thing no earlier slice could do: a **consistency sweep over a settled
tree**. `P20.DECOMP` cut this slice for exactly that reason — S1 and S2 rewrote the *same five
passages* one after the other, and neither could check its own work against a tree that had stopped
moving. Now it has.

The doctrine prose is **finished**. You own `installer/main.py` and `CHANGELOG.md`, plus assertion
upkeep and whatever the sweep turns up. Do not re-open S1's surface wording or S2's profile rule —
if the sweep finds a real defect in either, **fix it and say so plainly in `result.md`**; if it finds
something arguable, record it rather than rewriting settled prose on your own judgment.

Read first: `works/phases/active/P20/phase.md` (`## Decisions`, the notes tagged `P20.S3`, `## Now`)
and `works/phases/active/P20/intent.md`. The blast radius is established — **do not re-inventory**.

## 1. The version bump — and the ordering trap

`installer/main.py` line 38: `WORKSPACE_VERSION = 36` → **37**.

`tests/retrofit_smoke.sh` asserts a **three-way equality** — no literal pin, so **you never edit that
assertion**; you make the three agree:

```
main_version   = ^WORKSPACE_VERSION = (\d+)$   from installer/main.py
top_changelog  = first ^## v(\d+)\  heading     from CHANGELOG.md   (order also asserted: newest-first)
marker_version = works/.workspace-version.json  from a FRESH INSTALL of the built artifact
assert main_version == top_changelog == marker_version
```

**The trap:** `marker_version` comes from installing the **built artifact**, so the order is
**bump `installer/main.py` → run `installer/build.py` → then run the smoke suite.** Rebuild before the
bump and the marker still reads 36 and the failure looks like a changelog problem. The heading must
match `^## v(\d+) ` exactly — `## v37 — 2026-09-01`, space after the number, em dash, as every prior
entry.

## 2. The `## v37` changelog section

Newest-first, directly under the file's intro prose, in the established register: a leading
**"Why this release"** bullet naming the failure being closed, then bold-lead bullets, closing with
**Migration notes**. Read the `## v36` section first and match its voice; it is the entry this one
corrects. **One section covers S1 and S2 both** — the reader wants the release, not the slice log.

What it must carry:

- **Why:** v36 named the instrument and got the *surface* wrong. It prescribed the MCP transport for
  a reason that is true but not decisive (native tools in a dispatched session) and never weighed the
  cost — ~1,344 tokens of tool definition in **every** session, browser-related or not. And it said
  *use Aside* without ever saying **with which profile**, on a real desktop browser signed into the
  operator's accounts.
- **Two surfaces, not three** — the `repl` surface (identical over `aside mcp` and `aside repl`;
  transport is the only difference) and `aside exec`. v36's three-way split confused a transport
  difference with a surface one and hid the distinction that matters: **who picks the next action.**
- **The default is `aside repl` over Bash**, executor-driven, explicitly not MCP, with the measured
  cost as the recorded reason and the two-line `listBrowserTabs()` / `attachBrowserTab()` preamble
  buying back the only thing the CLI loses. Nothing ships, nothing registers.
  `claude mcp add -s local aside -- aside mcp` survives as a named per-operator escape hatch.
- **"Not scripted Playwright-style automation" → "not a pre-written assertion suite."** The surface
  *is* Playwright; what the doctrine rejects is deciding every check in advance. Say why the old
  wording had to go — it forbade the very thing v37 prescribes.
- **A dedicated profile, required** — per-invocation `aside repl --account <id>`, never
  `aside account use`; the manifest records the agent's account id; **a third `needs_operator` halt**,
  distinct from the runtime one. Give the authority reason (the probe found the operator's Google
  session, 49 imported passwords, 6 passkeys) — it is what makes this a requirement rather than
  hygiene advice.
- **Closes D9 and D11**, and D10's surface half: the fallback stands as written, and the surface facts
  are now executed rather than cited. Note the correction that came out of executing them: `title` +
  `code` is the **MCP tool's** schema, not a CLI flag — v36's phrasing would have shipped an
  invocation that fails.
- **Migration notes** — at minimum:
  - `python3 scripts/workflow.py sync-agents` after updating, as always: **both agent bodies changed**.
  - **No engine change at all this release** (`scripts/workflow.py` untouched), so history, existing
    slices and `validate` are unaffected and nothing needs renaming.
  - `--update` never touches `docs/`, so the seeded manifest's **two** fields — the corrected
    *Browser instrument* line and the new **conditionally required** agent-account field — reach
    **fresh installs only**; an existing adopter copies them from
    `installer/payloads/doc_bodies/operations.md` in the upstream clone via `doc-new-version`.
  - **The sharp one, and do not omit it:** an adopter who followed v36 and actually ran
    `claude mcp add -s local aside -- aside mcp` should **remove that registration** — v37 stops
    prescribing it, and leaving it in place keeps paying the per-session cost this release exists to
    avoid. This is the only way v37 can leave a live workspace worse off than it found it.
  - Installing Aside, and creating a second Aside account, remain operator actions the workspace never
    takes for anyone.

## 3. The consistency sweep — this slice's real work

Run it over the settled tree and **report each check with its outcome** in `result.md`, not a blanket
"all green". Live carriers only: `CLAUDE.md`, `.claude/`, `installer/payloads/`, `tests/`, `scripts/`.
`docs/current/*`, `docs/versions/*`, `works/phases/archived/*` and `bootstrap_agentic_workspace.sh`
are generated or history — hits there are expected and are **not** yours to fix.

1. **Stale v36 prescription.** `grep -rn "MCP surface\|mcpServers\|scripted Playwright\|MCP surface first"`
   — every surviving hit must be one you can justify out loud (the escape hatch; the smoke test's own
   negative assertions, which must contain a retired string in order to forbid it).
2. **Profile rule reaches every Aside-prescribing carrier.** The notebook records the check:
   `grep -rn -- "--account" CLAUDE.md .claude/ installer/payloads/` should show design-cowork ×3, both
   agent bodies, `review-phase`, `CLAUDE.md`, with the seed naming the field without the flag.
3. **The two agent bodies are body-identical** in the changed passages — `diff` them, do not eyeball;
   the smoke test asserts each string in both tiers and drift is a defect. Then
   `python3 scripts/workflow.py sync-agents --check` for frontmatter.
4. **The three halts are still distinguishable** — runtime absent/`UNFILLED`, instrument absent
   (never halts), profile missing. Read the contract rule and the agent bodies as a first-time reader
   and confirm a reader can tell which halt they are in. This is the failure S2 was warned about; the
   settled tree is where it would show.
5. **The doctrine's split still holds** — contract = rule, agent bodies = instruction,
   `design-cowork` = reasoning and invocation, seed = recorded field. Two slices editing the same five
   passages is exactly how an essay leaks into a routing contract.
6. **`## Doc impact` completeness.** Cross-check the notebook's list against what S1 and S2 actually
   changed and add anything missing **as a line, for the review to consolidate** — you do not write
   docs. One you should expect to add yourself: `operations.md` needs a **"Coming from a pre-v37
   workspace"** migration paragraph mirroring the pre-v36 one at its line ~371, since you are the slice
   that writes the migration mapping.
7. **`README.md` / `README.en.md`** carry no Aside mention (verified 2026-09-01) — confirm still true,
   and add nothing.

## 4. Assertion upkeep

You are not expected to add assertions, but if the sweep shows an invariant this release established
that nothing pins — particularly anything in the changelog/migration path — add it in the established
`# v37:` idiom. Remember Test 5's `design` text is **whitespace-normalised**, so a design-cowork
assertion is written on **one line**, and that the PASS count moves only when a new `ok`/`bad` **block**
is added, not per assertion. Never weaken an assertion to make it pass.

## Validate

1. Bump `installer/main.py` **first**.
2. `python3 installer/build.py` — mandatory, and after the bump.
3. `python3 installer/build.py --check` — must pass.
4. `python3 scripts/workflow.py sync-agents --check` — no drift.
5. `bash tests/retrofit_smoke.sh` — **full run**, green, and the version equality now at **37**. S2
   left it at **139 PASS / 0 FAIL**; report the count and account for any change.
6. `python3 scripts/workflow.py validate`.
7. The sweep in §3, each check reported individually.

**No browser, no browser claim.** Read-only `aside --help` if you need it; drive nothing, and never
run `aside account use`.

## Notebook and result

**The notebook is at 16,042 bytes against a 16,384 budget — tight, and it must go to the review
comfortably under.** This is a **compressing** edit:

- **Drop every note tagged `P20.S3`** — after this slice they are all spent; the detail lives in the
  three `result.md` files by path.
- **Keep** the two entries the review needs: the `P21` version-coordination note, and everything under
  `## Operator Questions` (S2's fallback-generalization question **must** survive — an unrouted entry
  is a review finding, and the orchestrator files it with `defer-job` at the review).
- **`## Decisions`**: compress to what the review must know. Replace superseded lines; never stack.
- **`## Doc impact`**: append your lines; this list is the review's consolidation worklist, so it is
  the one section that must stay complete rather than short.
- **Rewrite `## Now` (≤ 15 lines)** as the **review's** handoff: the phase is doctrinally complete,
  v37 shipped, the smoke count, and the review's own worklist — validate all slices, consolidate
  `qa.md` / `operations.md` / `decisions.md` from `## Doc impact`, drop **D9**, **D11**, **D10** and
  re-file D10's real-product half as the next free id, route S2's operator question with `defer-job`,
  and note the gate is **waived** so there is no walkthrough to write.

`result.md`, **verdict block first**: the bump, the changelog, then the sweep check by check with what
each found — including the checks that found nothing, since "the settled tree is clean" is this
slice's actual product.

## Do not

- Rewrite S1's or S2's landed prose except to fix a defect the sweep proves, and say so if you do.
- Edit `docs/current/*`, `docs/versions/*`, `docs/index.json`, `works/phases/archived/**`, the
  generated dashboards, or another slice's `plan.md`. **Run no `doc-new-version`** — the review
  consolidates.
- Hand-edit `bootstrap_agentic_workspace.sh`, edit the version-equality assertion, or renumber
  anything (P21 takes the number after 37).
- Run any git command, status transition, `accept-gate`, `defer-job` or `drop-deferred` — the
  deferred-job work is the **orchestrator's at the review**, and the notebook already records it.

## Verdict

Return the structured verdict block, `summary` in one line. If the sweep turns up something that
should change the doctrine but is beyond a defect fix, return `done` and record it as a finding for
the review rather than expanding this slice.
