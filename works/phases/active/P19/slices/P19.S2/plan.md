# Plan — P19.S2: Aside as the prescribed real-browser verification instrument

Name the instrument the verification doctrine has been asking for since v32 but never had, ship
workspace **v36**, and write the changelog covering both middle slices.

`phase.md`'s `## Notes for later slices` carries the Aside surface facts (commands, install, the
three surfaces), the file-by-file blast radius with line numbers, and the note listing exactly what
S1 already changed in the files you both touch. Read them first; this plan says what to decide.

## What is actually missing today, and what you are adding

Read `design-cowork`'s *Verifying* section and `review-phase`'s *Gate stages* before you write
anything. They already specify, thoroughly, **what** to check (the functional sweep — every control
does something observable, interaction states including browser defaults, liveness over time, type
into it and wait) and **where** (the `## Operator Runtime` manifest, plus the production build when
they differ). What they never say is **how** — with what. That gap is the whole slice.

Fill it: **Aside is the default instrument**, replacing scripted Playwright-style automation.
**MCP is the surface to prescribe** (`aside mcp`; its tools arrive as native tools in a dispatched
executor's session, which the CLI and REPL do not), with `aside` CLI and `aside repl` as the Bash
surfaces when deterministic inspection or a one-shot check is what is wanted.

**The argument is already written and you should point at it, not restate it.** `docs/current/qa.md`
*Verification doctrine* exists because thirty slices with a **scripted** fidelity slice at the end of
each passed while the operator then found eleven user-visible failures. Its demands are agentic
browsing by nature — "watch a timer tick for a real interval", "type into it and wait", the browser
defaults the record never drew — and a script asserting known selectors is the wrong shape for every
one of them. That doc is a generated snapshot: **read it, do not edit it.**

## The three decisions this slice actually turns on

**1. Prescription strength, given that Aside is not installed here.** It is macOS-only, needs an
account, has an undocumented headless story, and installing it is an operator-only outward-facing
action. So write **prescription + surface + fallback**, and be honest in the prose about which is
which. The fallback follows from the doctrine itself: *the doctrine's demands bind, the instrument
does not* — a workspace that cannot run Aside still owes the same functional sweep in the manifest
runtime by whatever real browser it has. Do not write the fallback as a loophole that makes the
prescription decorative, and do not write the prescription as a hard gate that a Linux workspace
fails. **Claim no verified Aside run anywhere** — nobody has made one.

**2. Instrument and runtime are different axes — do not let them blur.** `## Operator Runtime` is
*the operator's* runtime and access path; Aside is *the agent's* tool for driving it. Aside never
substitutes a runtime of its own, and the absent/`UNFILLED` → `needs_operator` → `pending` rule is
untouched. The existing "never assume headless" line in *Where it runs* now has a reason attached
rather than being a bare prohibition — a desktop browser agent is not headless — and that is worth
one clause, not a paragraph.

**3. How far into the seeds this goes.** The seed bodies under `installer/payloads/doc_bodies/` are
ordinary source, edited directly (unlike `docs/current/*`), and a fresh workspace gets them. Seeds
stay minimal by design: `qa.md` carries no verification-doctrine section at all today. My steer —
**one line at most, and only where its absence would make a fresh workspace guess**; the instrument
is agent behaviour and belongs in the skills and agent bodies, which every workspace gets anyway.
If you conclude a seed line earns its place, say why in `result.md`; if you conclude none does, that
is equally a result. Do not import the doctrine into the seeds.

## Also in this slice

- **`WORKSPACE_VERSION` 35 → 36** (`installer/main.py`) and a `CHANGELOG.md` `## v36` section
  covering **both** middle slices — the `research` kind and `DECOMP2`'s generalization from S1, and
  Aside from this one. Read S1's `result.md` and the notebook so the entry describes what shipped
  rather than what was planned. Include a **Migration notes** line if a sync needs manual steps.
- `.claude/skills/review-phase/SKILL.md` — S1 deliberately left this to you.
- Both agent bodies stay **byte-identical below the frontmatter**; `tests/retrofit_smoke.sh` asserts
  it. Edit them the same way, and add smoke assertions for the new prose rather than only writing it.

## Scope discipline

- **No `doc-new-version`, no editing `docs/current/*`.** Durable truth becomes `## Doc impact` lines
  in `phase.md`; `P19.REVIEW` consolidates. S1 left two notes there — add yours, do not disturb its.
- Do not add a slice to P19 or touch its `## Slices` block. The 4-slice cap is the operator's.
- If your work raises something only the operator can settle, append it to `## Operator Questions`
  (two entries are already there from `DECOMP`; do not answer them yourself — the review routes them).

## Validate

`python3 scripts/workflow.py validate` · `bash tests/retrofit_smoke.sh` · `python3 installer/build.py`
then `--check`, leaving the rebuilt `bootstrap_agentic_workspace.sh` in the tree. You cannot run
Aside; do not pretend otherwise. If you want to demonstrate the surface is real, cite the docs — do
not install anything.

## Notebook

`phase.md` is at 159 lines / 12.5 KB against a 200-line / 16 KB budget — **tight**. Your space comes
from consuming and dropping the five `for P19.S2` notes you use, and from compressing `## Decisions`
where S1 and S2 have both landed and the detail now lives in the `result.md` files. Rewrite `## Now`
(≤ 15 lines) last as the review's handoff: what shipped across both slices, what is unproven, and
what the review must route.

## Return

A structured verdict. `result.md` verdict-block-first. Do not commit, do not transition status.
