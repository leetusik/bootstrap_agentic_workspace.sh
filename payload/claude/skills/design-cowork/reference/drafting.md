# design-cowork — drafting and the inner loop

## Drafting and the inner loop

**Dispatch the drafter.** Resolve once with `executor-route --drafter`, and pass its `model` /
`effort` on every Agent call (`subagent_type` = its `subagent_type=` line; `subagent_type:
design-drafter` in a plain install). The prompt is **only a `slice: <id>` line, the round address
`<job>/<round>` and a `pass:` line** (`pass: frame`, `pass: page <slug>` or `pass: join`); on an
answer pass add `critique-01.md` (the page's or the round's) and, under `critic+judge`, the ids held
for the judge; on the judge's short follow-up pass add `judge-01.md` (*below*). The drafter reads
everything else itself; paste nothing. Run each span as a background task (never pass
`run_in_background: false`).

**The passes — a frame, the pages at once, a join.** The slice designs one job with one round open;
the round is drafted in passes, from the page list `design-open --pages` recorded:

1. **The frame pass** (one span, `pass: frame`). Deciding a shared choice is design, so a drafter
   makes it, once, before any page: `rounds/<round>/frame.md` (the shared-choice ledger, `F<n>` with
   one answer each: the term glossary, number / date / currency formats, the confirm pattern, the
   shared messages, empty / loading / error patterns, house style, the shared fixture (every entity a
   page shows, lists or links to, with its figures), the layout rules, and the page contract: per
   page the item it takes and the events it emits, plus the file prefix it owns),
   `canvas/project/frame.css` (the layout primitives and tokens, on the system's
   tokens), `canvas/project/Shell.dc.html` and every shared component two pages use, each with its
   board. It loads the face the product declares (an `@font-face` from its https source) and applies
   no optical nudge: a product that declares a face it never loads is logged as a system gap, which
   the build fixes by loading it.
2. **The page passes, all at once** (N spans, `pass: page <slug>`): **one background Agent call per
   page, in one message.** Each draws its page, its states (with its state bar) and its page-local
   components, writes only files starting with its page's stem plus `rounds/<round>/pages/<slug>/`
   (`boards.json`, `result.md`), leaves a link that carries nothing as `href="#to:<slug>"` for the
   join, logs a choice the frame did not foresee (an entity the fixture lacks included) as
   `frame_gaps:`, and self-checks with `design-preview <job> --page <slug>` and
   `design-check <job> --page <slug>`. A page draft is **never published**.
3. **The join pass** (one span, `pass: join`), after every page's loop is done: `canvas.json` (the
   frame's and every page's `boards.json`, laid out and numbered `01..N`), `Main.dc.html` (the entry
   Page, the flow through the related pages), every `#to:` rewired to a real link, **one answer per
   shared choice** (each `frame_gaps:` entry settled once, appended to `frame.md` and applied on every
   page it touches), `rounds/<round>/join.json` (`related`, `unrelated`, the settled choices), and the
   round `result.md` (its `## Build` assembled from the frame and each page's fragment). Then the
   whole-canvas self-check and `design-check <job>`. **An unrelated page stays on the canvas,
   unlinked**: `join.json` lists it, and the entry Page does not reach it.

**A one-page round skips the frame and the join:** its one `pass: page <slug>` span also writes
`canvas.json` and `Main.dc.html` and the round `result.md`, and is checked like a joined canvas.

**The drafter's verdict.** `done` → the loop below. `needs_operator` → the handoff is thin or
contradictory: hold the round (never fill the gap yourself, never tell it to guess), and raise
exactly what it named at the round's stop. The operator's answer amends that open round's handoff,
and the round is drafted again from the pass that needs it. `blocked` → `design-check` problems it
could not fix: same, reported as named. Fields to read: `boards_written`, `render_loop`,
`component_gaps`, `frame_gaps`, `departures`, `open_questions`, `open_items`, `critique_answers`,
`design_check`.

**What you read of a span: its verdict block, and the round `result.md`'s `## Summary`** (1 KB or
less; a page pass's own `## Summary` before the join). Never the drafter's other output, the canvas's
JS or CSS, `frame.md`, a critique's findings or any whole design file: their detail is the next
span's input, and the operator's when they open the canvas.

## The critics — two scopes, one pass and one answer each

**The levels.** `off` runs no critic at either scope: the passes go straight to the read-back.
`critic` runs a **page critic** for each page and the **cross-page critic** after the join.
`critic+judge` adds the judge on escalated items. **`critic` is the usual level for a connected
group of new surfaces**: a page critic reads inside its page, which the cross-page critic never
does, so the two scopes catch different defects. `off` suits small follow-ups and superseding
revision rounds, and an unset level is `off` (`shape.md`'s critique-level bullet).

**Inside each scope, before the operator sees anything:** one critic pass, then at most one drafter answer pass. There is no second critic pass.

1. **The page critics** (`executor-route --critic`; its `model` / `effort` per call), one per page,
   each dispatched as soon as its page drafter returns `done`, so they run at once. The prompt:
   `slice:`, `mode: critic`, `scope: page <slug>`, the round address, `pass: 01` and a scratch
   directory outside the design root. It judges that page against the handoff's page section, the bar
   and `frame.md` (a departure from `frame.md` without a `frame_gaps:` entry is must-fix), never the
   links between pages, and writes `rounds/<round>/pages/<slug>/critique-01.md`. **That page's drafter
   answers it once** (`pass: page <slug>` with the critique). Every page's loop ends before the join.
2. **The cross-page critic** (one span after the join): `mode: critic`, `scope: cross`, the round,
   `pass: 01`, the scratch directory. It reads the frame, `join.json`, the round `result.md`, the
   entry Page, the click graph and each Page's contact sheet, never page internals: the entry reaches
   every related page, the links carry the item, unrelated pages are complete and unlinked, one answer
   per shared choice, every in-round link landing on its own drawn item. It writes the round's
   `critique-01.md`. **The joiner answers it once** (`pass: join` with the critique).
3. Read **only each critique's verdict block**: `verdict`, `confidence`, `must_fix`, `escalate`. With
   no must-fix open, skip that answer pass. What an answer leaves open (a rebuttal, a fix that did not
   hold) reaches the operator with both sides.
4. **What a critic was unsure of** (its `escalate` ids: a low-confidence must-fix, a `pass` below
   `high`, a standoff over a logged departure):
   - **under `critic`**, no judge exists, so **nothing is held**: the drafter answers a listed
     must-fix like any other finding, and the operator still sees every listed item marked
     **unsure**, with its reasons, beside the drafter's answer;
   - **under `critic+judge`** (`executor-route --judge`; its `model` / `effort` per call), dispatch
     the judge **beside the drafter's answer pass** that holds those ids, a page's or the joiner's.
     The judge's prompt: `mode: judge`, the same `scope:` line, the round, `pass: 01`, the critique
     path, the escalated ids, and the critic's `--out` path so it reuses the render. It writes
     `judge-01.md` beside that critique, ruling once. Its **upheld** items get **one more short drafter pass**
     from that same owner (with `judge-01.md`); dropped ones are gone. A `pass-rejected` sends
     the must-fixes it names into that same short pass. With no confident must-fix for the answer
     pass, the judge runs first and the drafter takes its upheld items in its one pass.
   - **`skip=yes`** (the judge row overridden to Fable behind a loopback proxy, which serves no Fable): dispatch no judge; the escalated items go to the
     operator marked **low confidence**.

**The measured checks stay self-contained.** `design-preview` measures contrast, targets, keyboard,
reflow and alignment (`check=align`) itself; no external checker (axe-core or another) is hooked in,
since a hook only some machines run gives each machine a different result.

## Cost

**One measured round, not a norm** (4 pages at `critic`, fixing a built product's screens, every
span on opus @ high; main thread not included): 16 spans, $71.50, 3 h 43 min wall clock.

| pass | spans | $ | minutes per span |
|---|---|---|---|
| frame | 1 | 6.63 | 20 |
| pages at once | 4 | 22.50 | 22–26 (wall about 26) |
| page critics | 4 | 10.44 | 5–12 |
| page answers | 4 | 9.46 | 5–16 |
| join | 1 | 7.43 | 36 |
| cross-page critic | 1 | 3.60 | 11 |
| join answer | 1 | 11.44 | 47 |

The page-critic tier (the page critics and their answers) cost $19.90, 28 % of the round, and
raised 13 must-fix items inside pages that the cross-page critic, never reading page internals,
could not see; the cross-page critic raised 6 more. The join answer was the costliest span: each
page had grown the shared fixture with entities of its own, and it rewrote them onto one (the
frame's fixture covering every entity a page shows, lists or links to is the guard). A superseding
revision, one drafter editing the canvas in place with a whole-round critic and its answer, cost
$28.60 (3 spans, about 1 h 50 min). Page count, states per page and how much the pages share
move every figure.

**Estimates for other sizes**, scaled per span from earlier metering; the measured round came in
under them on dollars (about $81 predicted at 4 pages) and over on wall clock (about 2.7 h):

| pages | spans at `critic` | $ at `critic` | wall clock | $ with no page critics |
|---|---|---|---|---|
| 3 | 13 | about $67 ($55–80) | 2.5 h or more | about $49 |
| 7 | 25 | about $122 ($100–150) | 3.5 h or more | about $80 |

At seven pages that is about 3× a one-drafter round (about $39) and slower in wall clock: the frame
and the join add serial stages the parallel pages do not win back. The passes buy quality per page
and cross-page consistency, not speed or cost. Span-minutes of parallel spans sum past wall clock,
so read `dispatch-summary`'s means with the slice's window. The critic's model and effort are the
`[claude.critic]` row's and the judge's the `[claude.judge]` row's (`executor-route --critic` and
`--judge` print what this install resolves; `max` is the step up): the operator tunes them in
`executors.toml`, never in a prompt. (For the record, on an earlier whole-round critic: a critic
pass took 25–36 minutes on a flow-board job, and the judge about 2 minutes per item.)

**Every span's prompt starts with its `slice: <id>` line** — drafter, critic and judge alike: the
meter attributes the span by it, and labels it by its `pass:` or `scope:` line (`design-frame`,
`design-page`, `design-join`, `critic-page`, `critic-cross`). Spans are metered from the transcripts
by `dispatch-summary`; never record one by hand.

## Never — dispatching

- Dispatch anything but these spans: the drafting passes to `design-drafter`, every round; the
  critique and the judging to `design-critic`, when the job's level says so; and the mockup build to
  `slice-executor` on the high row, only when the operator asked for one.
- Publish a page draft, or anything before the join.
- Dispatch the join before every page's loop (its pass, its critic, its answer) is done.
