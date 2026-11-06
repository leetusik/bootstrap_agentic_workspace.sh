---
name: create-phase
description: Capture operator intent (refine → clarify → confirm), then create one or more phases (intent.md + DECOMP/REVIEW only) or route to defer-job. Stops before decomposition.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep
---

# create-phase

Turn an operator request for new work into one or more phases — or a deferred job — with the operator's intent captured first. **This skill creates phases; it never decomposes or implements them** (see *Making a phase ≠ executing it* in the contract — `CLAUDE.md`), with one exception: *The explain route* creates **and** runs its explain phase after one confirmation.

**Who may invoke it.** The operator, or **the agent when instructed** — by an approved plan that says to create a phase, or by a direct operator instruction. **Never on the agent's own initiative**: this is a narrower exception to the contract's "workflow command-skills are explicit-invocation only" than `design-cowork`, which does fire by itself. And invocation is not where the safety lives: **the confirmation gate at step 3 does not move**. Whoever started the intake, `new-phase` runs only after the operator has explicitly confirmed each phase's name and objective. **Invocation is not the gate; confirmation is.** One route is the exception: `/rotate-backlog`'s docs-phase route, where the operator's `/rotate-backlog` invocation *is* the confirmation of the engine-drafted name, objective and `docs-debt` scope (the proposal is still printed). The explain route is the other: its one confirmation is step 3's yes **and** the explicit `auto` that runs the phase to publish, so it creates, then runs (*The explain route*). Every other phase waits for the explicit yes and stops after creation.

## Procedure

1. **Refine.** Restate the operator's request in clear language. Read the `docs/current/` **sections** the request actually touches (just in time — never the whole doc set; `python3 scripts/workflow.py docs` lists what exists) and run `python3 scripts/workflow.py next` for the current pointer, if useful. Preserve the operator's exact words — you will record them verbatim later.

2. **Clarify.** Ask the operator about anything ambiguous before acting: scope and boundaries, whether this is one phase or several, a sensible name and objective for each, and whether the work should start now (a phase) or be parked for later (a deferred job). Wait for answers. Do not run any `workflow.py` command yet.

   **If the work touches product visual design, one of those questions is the design style** — read the `design-cowork` skill (its `reference/shape.md`, `## Shape — three styles`) and ask which of the three the work wants. **You suggest one and give the reason; the operator confirms or overrides.** It is never your decision alone and never left implicit:

   - **`build-after`** — one phase, two decomposition passes: `DECOMP` → groundwork → design round(s) → `DECOMP2` → build slices. Choose it when the whole design should land before any of it is built and the build fits in the same phase.
   - **`design-only`** — a *design* phase, then a separate *apply* phase; both keep the single pass. Choose it when the design is big.
   - **`paired`** — one phase, alternating design 1 → apply 1 → design 2 → apply 2; `DECOMP` cuts the pairs as **bare folders** and there is **no `DECOMP2`**. Choose it when the rounds are independent surfaces and each is small enough to apply before the next design starts.

   **`design-only` must be chosen here** — the `DECOMP` slice's executor is forbidden from running `new-phase`, so a phase split decided later cannot be created from inside decomposition. That is the deadline this choice has; the other two styles can still be settled at `DECOMP`. When a phase was created before its visual nature was clear, `DECOMP` asks the style instead and stops **`pending`** for the answer — and if the answer turns out to be `design-only`, the apply phase is created on the main thread through this skill, never from inside a `DECOMP`.

   **Ask the mockup question in the same breath:** *every design job comes as a working canvas you open in the Claude app — clickable Pages with realistic data, and each component in all its states; do you also want an in-product mockup before you sign, or will you sign on the canvas?* The canvas is the default review surface. A mockup is a throwaway route in the project's own frontend, built from the signed-off design with stubbed data, **in addition to** the canvas — it costs a dispatched build and a second `pending` stop. The default is **`on request`**: each job closes on the operator's literal approval when they return to the published canvas, and they can still ask for a mockup in their own words at any time before that. Record the answer as the `Mockup:` line under `## Design Style` (step 4.2). When the style is asked at `DECOMP` instead, this question travels with it.

   **If the request is "consolidate the docs" / "run a docs phase" — or the operator is clearing a `consolidation_owed=` line from `next` — the scope is already written down.** Run `python3 scripts/workflow.py docs-debt` and propose what it prints; see *The docs-phase route* below. It is an ordinary phase through this same procedure, confirmed at step 3 like any other.

   **If the request is recurring or near-endless work under bounds** (strategy mining, a research sweep, a bug hunt: "keep trying X until …", "run this every hour within $Y"), it is a **loop phase**: follow *The loop route* below.

   **If the request is to explain something** (`/knowledge:explain <topic>`, "explain P30", "write a book on X", "add a chapter on Y to book Z", an explain phase), every unit is a phase: a standalone **document** by default, a **book** or a **chapter** of one only when the operator asks. Follow *The explain route* below: it gathers the `## Explain` fields into **one confirmation** and, on the yes, creates and runs the phase. A request that arrives from `/knowledge:explain` with a proposal the operator accepted with a literal yes is already confirmed: *A confirmed proposal* in the route.

   **If the request carries a `Research: <subject>` block** (the explain's "research first": no phase covers the subject yet), it is not an explain but an ordinary phase that records findings for one: follow *The research route* below.

3. **Confirm.** Present your refined understanding back to the operator — for each phase, the proposed **name** and **objective**; for deferred work, the title, reason, and trigger. For a phase that will change product files, also propose its **branch name per repo** it will change, from the host's recorded custom (`nested-convention [--repo <name>]`; at root, the repo's own branch habits), with no phase or slice IDs, and confirm them with the name and objective. **One question rides on that confirmation, never a stop of its own:** when `next` lists a `pr_open=` or `pr_stack=` line, or the operator names an open PR, ask whether the new phase builds on one; if it does, propose that PR's branch as its base (`.claude/skills/pr/reference/stack.md`). Never split a phase for size: a large one is split into PRs at its review, never into phases. Get explicit confirmation. Per the contract, do **not** run `new-phase` until the operator confirms. (An explain phase is confirmed once, by *The explain route*'s one confirmation, which also covers its fields, its worktree and its run; one the plugin's `/knowledge:explain` proposed, and the operator accepted with a literal yes, arrives confirmed: *A confirmed proposal*.)

4. **Route on the operator's choice:**

   **Defer for later** → fold the confirmed intent into the arguments and run:
   ```
   python3 scripts/workflow.py defer-job --title "..." --reason "..." --trigger "..." [--source ...]
   ```
   Leave out `--id`: the engine mints the job's id (`D92-x4`: the next number and a random tail) and prints it on the `created deferred job` line; never pick a number. This parks the job under `works/deferred/open/<DID>/` and never affects next-slice selection until promoted (the same command the `defer-job` skill wraps). Commit it as step 5 says, report and STOP.

   **Make a phase (or several)** → for each phase, in operator-confirmed order:
   1. Create it, leaving out `--phase`:
      ```
      python3 scripts/workflow.py new-phase --name "..." --objective "..."
      ```
      The engine mints the id (`P46-k2`: the next number and a random tail) and prints it on the `created phase` line; never pick it, and use that printed id as `P<N>` in every step below. `new-phase` creates only `P<N>.DECOMP` and `P<N>.REVIEW`, scaffolds `intent.md`, and links it near the top of `phase.md`.
   2. Fill `works/phases/active/P<N>/intent.md`:
      - leave **Origin** as `operator`;
      - paste the operator's request **word-for-word** under *Original Input (verbatim)* — do not fix grammar or wording;
      - write the confirmed, refined wording under *Confirmed Intent (refined + clarified)*: what the operator wants (objective, scope, constraints, in their terms), **never workflow mechanics** (which tools, hooks or design loop run). The skills own those and can retire them;
      - record any clarifying Q/A under *Clarifications Resolved*;
      - for a phase that will change product files, add a `Branches:` line to the confirmed intent with each confirmed name
        (`Branches: <name>`, or `Branches: <repo>: <name>; …` on a multi-repo host), with a confirmed base for a
        phase stacked on an open PR (`Branches: feat/y (base: feat/x, merges after #12)`; per repo on a multi-repo
        host). Nothing is cut here: `DECOMP`'s end records them with `pr-branch` (`--base` for a recorded base);
      - **for a visual-design phase only**, append a `## Design Style` section naming the confirmed
        style (`build-after` / `design-only` / `paired`) and the one-line reason, then a second line
        `Mockup: requested` or `Mockup: on request` (the default when the operator did not ask for
        one). `DECOMP` reads both. The section is added **only when the phase is visual** — the
        scaffold does not carry the heading, and every reader treats its absence as "not a design
        phase", never as an unanswered question; an absent `Mockup:` line reads as `on request`.
        There is no `Design tool:` line: `drafter` is the only design tool.
      - **for an explain phase only**, append a `## Explain` section with the confirmed fields
        (*The explain route* below shows its shape). `DECOMP` and the review read it; its absence
        reads as "not an explain phase", never as an unanswered question.

      (`new-phase` already filled the phase id and captured-at timestamp.)
   3. Confirm `phase.md` links `intent.md` near the top (the engine added `_Intent: see [intent.md](intent.md)._`).
   4. **Say nothing about worktrees.** The phase runs on this stream, like every phase the
      operator does not ask into a worktree (v43), and creation stamps nothing. The one exception
      is a hint `new-phase` prints when another phase is already `in_progress` here — that this
      phase *could* run in parallel on its own branch. **Relay that hint; never act on it.** Only
      the operator's word starts a worktree, and it is `/do-next-slice` / `/do-whole-phase` that
      act on it later, never `create-phase`. See the `parallel-phase` skill.
      **An explain phase is the one exception:** its route starts the phase's own worktree,
      because its one confirmation (`worktree: yes`, the default) is the operator's word for it;
      `worktree: no` keeps it on this stream.
      **A loop phase records its answer and starts nothing here:** its `worktree:` line in
      `intent.md` is the operator's word, and `do-whole-phase` acts on it before the loop's `DECOMP`
      (*The loop route*).

5. **Commit, then STOP and report** (an explain phase confirmed with a `unit:` field commits here, then runs on: *The explain route*). Commit what the intake wrote, and only that: the new phase folders (or the deferred job's folder) and the regenerated `works/` files (`state.json`, `index.json`, `backlog.md`, `deferred.md`, `events.jsonl`), never other changes the tree holds. **(nested)** Commit in the nested repo, `git -C workflow …`, with paths relative to it. One commit for the whole intake, in the contract's Commit Convention: `chore(P<N>): create <name> and record the operator's intent` (a deferred job: `chore(D<N>): defer <title>`). Never push. Then list the phases created — IDs, names, and `intent.md` paths — or the deferred job created. Do **not** decompose into middle slices, write any slice's `plan.md`, or implement code. Decomposition is the `DECOMP` slice's own job, later, when the operator executes the phase (`/do-next-slice`, `/do-whole-phase`, `/do-whole-phases`) or explicitly tells you to.

## The docs-phase route

Durable docs are versioned **in a docs phase the operator creates** — never per slice, and no longer at the review, which only *verifies* each phase's `## Doc impact` list and lets the engine stamp that phase's `consolidation` debt. So "consolidate the docs", "clear the doc debt", and a `consolidation_owed=` line in `next` all land here. **`/rotate-backlog` is the default entry point for this route, and there the invocation is the confirmation**: it checks the debt first, drafts the docs phase's name and objective from `docs-debt`, prints the proposal, runs the printed `new-phase` line as is (no pause, no narrowing), fills `intent.md` as below, then runs the docs phase through `do-whole-phase` and archives the done phases at the end. A later `/rotate-backlog` replaces a docs phase that has not started (no docs slice past `ready`) with one new docs phase covering all the debt, the debt that arose since included; one that has started finishes first, and the new debt waits for it. Steps 2–4 below still hold, with the operator's confirmation at step 3 for a docs phase made by hand through `/create-phase`; the same refine → clarify → **confirm at step 3** → `new-phase` → stop applies there. What the route adds is that the scope is already recorded — do not re-derive it by hand:

1. **Read the debt** (read-only): `python3 scripts/workflow.py docs-debt`. It prints every owing phase with its `## Doc impact` notes, the docs those notes touch, and the command that pays each phase.
2. **Propose that as the scope** in step 2 — the phases and the docs it names. The operator may narrow it; a phase left out simply keeps owing and stays in `active/`.
3. **Confirm the name and objective at step 3, unchanged.** An objective that works: *"consolidate the `## Doc impact` notes from P12–P16 into new versions of architecture, operations and qa"* — name the phases, because they are what gets cleared at the end.
4. **`new-phase`, fill `intent.md`, STOP.** Create it with `--consolidates <the confirmed phases>` (for example `--consolidates 46,P12,P-7kq2`: any brief form works) — that flag is what marks it a docs phase, so `rotate-backlog` and `docs-debt` see those phases' debt as being paid and never propose a second docs phase for them; it refuses, writing nothing, for an id that is not an active phase owing consolidation, and a phase left out of the list keeps owing. A docs phase runs on the default stream, like every phase (v43) — nothing to pass, nothing to pin. It has to: `doc-new-version`, `docs-consolidated` and `parallel-consolidated` only run there, so **never ask for a worktree on a docs phase**, whatever hint `new-phase` or `next` prints. Record the `docs-debt` scope in `intent.md`; decomposition is the docs phase's own `DECOMP` slice, later.

**What that `DECOMP` will cut** (write it into `intent.md`; do not cut it here): **one slice per doc**, `--kind docs` — `doc-new-version` is per doc and one doc usually collects notes from several phases, so per-doc keeps each doc to a single new version. Risk by the normal rule. Each slice runs, per note it covers:

```sh
python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source <P>.REVIEW
# edit only the returned edit_path, then:
python3 scripts/workflow.py rebuild-docs
```

and the phase records the payment **for each phase it covered**: `python3 scripts/workflow.py docs-consolidated <P>` (a merged parallel phase: `parallel-consolidated <P>`), which is also what unblocks archiving those phases. All of it on the **default stream**: a doc version copies the doc's whole body and writes the one shared `docs/index.json`, so two branches versioning at once would fork it.

Two things that keep the route from feeding itself: a docs phase leaves **no `## Doc impact` notes of its own** (it pays other phases' notes; it creates no new durable truth), so its own review stamps no new debt — and it changes no operator-visible surface, so its acceptance gate is normally `--waive`d at the `DECOMP` boundary.

## The QA-sweep route

The phase review re-runs only the `## Regression Checklist` lines inside its phase's boundary (`python3 scripts/workflow.py phase-scope <P>`: the phase's own surfaces plus every earlier line a changed file feeds), so the **whole** cumulative list is re-run only when the operator asks for it — "run the full regression sweep", "QA sweep", "re-run the checklist" all land here. Nothing is special-cased: same refine → clarify → **confirm at step 3** → `new-phase` → stop. An objective that works: *"re-run every `## Regression Checklist` line in the manifest runtime and report what no longer holds"*.

**What that `DECOMP` will cut** (write it into `intent.md`; do not cut it here): `--kind qa --risk low` slices (the mid row — a sweep re-runs written lines, it designs nothing), one per checklist block (one for the whole list when it is short), each re-running its lines with the instrument and viewports `## Operator Runtime` names and recording the result line by line in `result.md`. Failures become findings the phase's review turns into fix slices or deferred jobs; a line whose precondition no longer exists is reported for the review to strike or rewrite in its `## Regression Checklist` write. A QA phase changes no product code, leaves no `## Doc impact` notes of its own, appends no new checklist lines, and changes no operator-visible surface — so its acceptance gate is normally `--waive`d at the `DECOMP` boundary.

## The loop route

A **loop phase** runs bounded cycles under a signed charter, one item each, until the operator stops it or a charter stop halts it (the `run-loop` skill drives it). Requests for recurring or near-endless work under bounds land here: strategy mining, research sweeps, bug hunts. Nothing is special-cased in the intake: the same refine → clarify → **confirm at step 3** → `new-phase` → stop.

- **Clarify** the objective, what one cycle does to one item, what is forbidden, the money and the bounds (per cycle, per day, in total), in the operator's own words.
- **Ask in the confirmation whether the loop runs in its own worktree, defaulting to yes**: a loop is long-lived and should not block the default stream. Record the answer as a `worktree: yes|no` line in `intent.md`; on yes, `do-whole-phase` runs `parallel-start` before the `DECOMP` (`.claude/skills/do-whole-phase/reference/worktree.md`), with the branch name the operator confirms.
- **Create it** with `python3 scripts/workflow.py new-phase --name "…" --objective "…" --loop` (or `loop-init <P>` on an already-planned phase), and record the objective and the operator's bounds wording, verbatim, in `intent.md`.

**What its `DECOMP` will do** (write it into `intent.md`; never cut it here): draft `loop/charter/v1.md` from `intent.md` (every `UNFILLED` filled, each bound proposed with a one-line reason, `## Forbidden` from the operator's own words, `outputs` as narrow as the product allows), cut any setup slices the cycles need, declare the acceptance gate, and present the charter for the operator's literal signature (`loop-sign`). The cycles are never planned at intake: `/run-loop <P>` runs them once the charter is signed.

## The explain route

**Every explain is its own explain phase**, in this repo's workspace (nested or at root), one phase per publishable unit: a **document** (the default: one standalone document), a **book** (several chapters drawn from the phases that built the subject, outlined and signed, each chapter written, checked by a critic on a second model, and the book read whole), a **chapter** added to an existing book, or a v2 of a document or chapter (`prior:`). A book or a chapter is made only when the operator asks, in their own words or at the confirmation; the unit is settled **once, at the start**, never mid-run. `/knowledge:explain <topic>` lands here (the plugin calls this skill when instructed), and so do "explain P30", "write a book on X", "add a chapter on Y to book Z" and "make an explain phase for Y". Like every phase, it is created only on the operator's word, never on the agent's own initiative and never because a phase just finished.

**An explain tells what this repository's code does, from what its phases recorded.** One writer reads the code at one commit and the records of the phases that built the subject, traces every sentence to them, and a critic on a second model checks the draft against them before the private publish. There is no research run: no web search, no research agent, nothing from outside the code and the records. A subject with no code behind it is declined; a subject the code has but no phase covers is offered *The research route* (below) first. The plugin's explain skill owns every evidence and writing rule (the evidence and its record, grammar, ids, quiz, sources, publish). The phase orchestrates that skill, and nothing here restates it. The phase needs the plugin at **0.10.0 or later**, whose §3 *Gather the evidence* is the evidence model these steps follow. Plugin sections are cited by number **and** heading, so a renumbering cannot silently point a phase at the wrong rule.

**Refuse before anything is written:**
- **From inside a phase worktree** (`python3 scripts/workflow.py next` prints a `stream=` line): say "start an explain from the main checkout" and stop, writing nothing; a phase created here would land on another phase's branch.
- **A subject with no code behind it** (not this repository's code, or no git repository: the plugin's §1 *Resolve the topic, the mode and the placement*): decline plainly, in one or two sentences, and write nothing. Explain is codebase-only; the knowledge base keeps the subject books and documents already published.
- **A book, or a chapter of one, in a public project:** `visibility: private` is absolute. Refuse at the confirmation and offer the two ways on: make the project private for the run, or write a standalone private document instead.
- **The plugin missing, older than 0.10.0, or not set up:** say so and stop, writing nothing. The operator updates it (`/plugin marketplace update knowledge`, then `knowledge@knowledge` from the `/plugin` panel; a first install is `/plugin install knowledge@knowledge`) and runs `/knowledge:setup` once, which writes the org-level key the review publishes with. Read the version from the plugin registry, as `do-whole-phase`'s `reference/explain-decomposition.md` does.

1. **Gather the `## Explain` fields** (step 2). A request from the plugin's front door arrives with them (*A confirmed proposal*, below). Any other request (a direct "make an explain phase for X") is drafted here the way the front door drafts it, from the installed skill and never from memory: its §1 *Resolve the topic, the mode and the placement* (the unit and its placement, *The title rule*, *The reader*, *The shape*, *The phases that cover the subject*) and its *The front door, step by step*, steps 4–6 (a live explain phase on the same subject, the knowledge base and the prior, the cheap look and the coverage, the proposal). The sixteen fields, in this order:
   - **unit**: `document` (default), `book` or `chapter`. The literal `unit` line is what the plugin's front door tests for, so it is always written;
   - **subject**: a phase id (`P30`), a slice id (`P30.S4`) or a topic of this repository's code;
   - **phases**: the phases that cover the subject, by §1's *The phases that cover the subject* (ids, comma-separated, at most 6 named), or `none` when no phase covers it and the operator chose to explain from the code alone. The writer reads their records, the code, and nothing else;
   - **book**: `none` for a document. For a book, its slug and title, kind `codebase`, by §1's rules: a phase or slice subject gets that phase's own book, slug `p<N>` (a tailed or v73 id keeps its form: `P46-k2` suggests `p46-k2`), its title set by §1's title rule; anything else is a named book. For a chapter, the existing book it joins;
   - **chapter**: `none`, or for a chapter `<key> — "<title>" · position <n>`;
   - **prior**: `none`, or the version a v2 supersedes: `<rel_path> v<N>` for a document, `<book>/<key> v<N>` for a chapter. Fill it when a lookup finds one;
   - **lang**: `en` (translations: none), unless the operator names another language. The dossier is written in English either way. A translation names the published original's version (§5 *Publish via the KB document API*), so translations follow the accepted unit: the review lists them as a deferred job for the orchestrator to file;
   - **reader**: a concrete guess at who it is for, by §1's *The reader*: who they are, what they already know, what they are new to, and what they will do with it; never a stock reader. Every chapter and the critic write for this reader (a chapter: the book's reader, as its outline states);
   - **depth**: `one document`, `one chapter`, or for a book about how many chapters. A topic too big for one document is scoped down to what one carries, and the closing report suggests a book for the rest;
   - **must-cover**: the points it must teach, or `none`. The writer looks for the evidence of each one; one the code and the records cannot carry is stated as a gap;
   - **leave-out**: what it deliberately leaves out, or `none`. The writer does not read for it, and the critic does not ask for it;
   - **trusted sources**: the files or phases the operator wants read first, or `none`. Only the code and the records count: a page, or anything else outside them, is set aside, and the report says so;
   - **project**: the knowledge-base project it is published into. It **must be private**: an existing private project of the operator's org, or a new name, created private on its first publish;
   - **visibility**: always `private`. The operator makes it public in the reader after accepting it, never through this phase;
   - **outline sign-off**: `off` (default) or `on`. A book is `on`, fixed;
   - **worktree**: `yes` (default: the phase runs in its own worktree, so it never blocks product work) or `no`.

   There is **no `run:` line and no `mode:` line**: one run, and every subject is this repository's code. **The required set, per unit:** every unit writes all sixteen lines. A document has `book: none`, `chapter: none`, `depth: one document`; a book has `chapter: none`, `outline sign-off: on`; a chapter names an existing `book`, its `chapter` and `depth: one chapter`. An older section is read, never rewritten here: one with no `unit` line is a book from before the line existed (its eleven fields: subject, mode, book, lang, reader, depth, must-cover, leave-out, trusted sources, project, visibility), and one with `run:` and `mode:` lines and no `phases:` line is from before this route; `do-whole-phase`'s `reference/explain-decomposition.md` says how their `DECOMP` reads them.

   **When no phase covers the subject,** the confirmation says so and offers two replies, as the front door's step 7 words them: "research first" (*The research route*, below: a research phase that records findings; the explain follows only when the operator asks again) or "yes" (explain from the code alone, `phases: none`).

   Say the cost here: **one writer and one critic on a second model**, plus the explain phase around it (a book: one of each per chapter, after one reading of the whole subject). The writer reads the skill by path, so manual permission mode needs the rules §3.2 *Permissions, and the payload builder* prints, with its lines for such a writer; auto mode needs none.

2. **Show the one confirmation** (step 3), in the shape of the plugin's front-door step 7, drawn from the installed skill: the plain summary, the reader, the sections with their Quiz and Next steps lines and the other shapes, the phases that built it, the cost line, the phase name and objective, the `## Explain` block, and the `Why:` line. One literal yes signs the phase's name (`Explain: <subject>`), its objective, every field, the sections, the worktree and the run in `auto`; a changed line or a picked shape is folded in and the whole confirmation shown again. Its head and tail, for orientation (step 7 holds the rest and a worked example):

   ```
   Explain — confirm once; then it runs to publish.
   In plain words: <2–4 plain sentences: what it explains, for whom, what they can do afterwards>
   Reader: <the reader> (change it if I guessed wrong)
   Sections (your yes signs them; change any line): 1. <Heading> — <the reader's question it answers> …
   Built by: <the covering phases> | no phase covers this code — see below
   Cost: one writer and one critic on a second model, plus the explain phase around it
   Phase: Explain: <subject> — <the objective>
   ## Explain … the sixteen lines …
   Why: <field — reason>; …
   Reply yes, or change any line.
   ```

   A book's confirmation lists its chapters in place of the sections, and its stops line adds the outline and acceptance gates.
3. **On the yes, create and run**, in this order:
   1. `python3 scripts/workflow.py new-phase --name "Explain: <subject>" --objective "..."`;
   2. fill `intent.md` (step 4.2): under *Original Input (verbatim)* the operator's request, the confirmation as last shown and their reply, word for word (the writer takes the signed sections from there: §3.1 *D0: the brief, and the prior version*, *The signed sections*); under *Confirmed Intent* the objective; then the `## Explain` section, one field a line:

      ```markdown
      ## Explain

      - unit: document
      - subject: how a re-explain publishes the next version of the same document
      - phases: P30, P33-n3
      - book: none
      - chapter: none
      - prior: none
      - lang: en (translations: none)
      - reader: you, who built the publish path in P30; new to how a v2 keeps its ids; you will change the 409 handling
      - depth: one document
      - must-cover: the 409 → new-version path; why heading and quiz ids survive a version
      - leave-out: the web reader's styling
      - trusted sources: none
      - project: knowledge (private)
      - visibility: private
      - outline sign-off: off
      - worktree: yes
      ```

      The section is added only to an explain phase, as `## Design Style` is added only to a design phase. The scaffold does not carry the heading, and every reader treats its absence as "not an explain phase". The section is the whole marker: there is no flag;
   3. the intake commit (step 5);
   4. unless `worktree: no`, `python3 scripts/workflow.py parallel-start <P>` (nested: with no `--host-branch`, which cuts a detached host worktree, since an explain makes no host commit), then `EnterWorktree` into the path it prints (nested: the host worktree). The `parallel-phase` skill carries the rest of the lifecycle, the merge back included;
   5. `python3 scripts/workflow.py next`, then run the phase per the `do-whole-phase` skill in **`auto`**: the confirmation is the explicit `auto` the contract's decomposition carve-out requires, so `DECOMP` plans inline, as `/rotate-backlog`'s invocation is for its docs phase.

   It runs to publish. Its only stops are the quality stops, each a typed `pending`: a **critic stop** (the critic failed twice, or a must-fix left neither fixed nor disputed) takes `--stop-kind decision`; a **publish failure** (a refusal twice, a rejected key, a public project) takes `operator-action`; a denied call (`FAILED: permissions`, §3.2 *Permissions, and the payload builder*) returns `needs_operator`, as the references say; and a book adds its outline gate and its acceptance gate.

**A confirmed proposal.** The plugin's `/knowledge:explain` shows the operator its own proposal (its front-door step 7): the plain summary, the reader, the sections, the phases that built the subject, the unit, the phase name, the objective and every `## Explain` field, each with its reason. Only on the operator's **literal yes** does it invoke this skill, with the operator's request, that proposal as last shown and their reply, verbatim. That yes is the one confirmation, so do not ask again:
- check the proposal as step 1 would: the sixteen-line set for its unit present, `visibility: private`, the project private, the subject real and in this repository's code, every `phases:` id a phase of this workspace (active or archived), and the stream check. Anything missing or contradictory (a public project, a field the proposal left out) means the proposal is not confirmed: ask about that field and show the one confirmation as usual. Never ask for a field the set does not have (`run:`, `mode:`);
- run step 3 as written, the request, the proposal and the reply under *Original Input (verbatim)* (the proposal joins some fields with ` · `: write one a line);
- **with no `unit` line**, or with `run:` and `mode:` lines and no `phases:` line, the proposal came from a plugin older than 0.10.0: create nothing, and refuse as step 1's last refusal says (update the plugin, then ask again).

**A "research first" reply** (the front door's, or this route's own confirmation's) is not an explain: it arrives with a `Research: <subject>` block and goes to *The research route*, below. No `## Explain` section and no explain phase is created for it.

**What that `DECOMP` will cut.** Do not cut it here; `DECOMP` reads the procedure from `do-whole-phase`'s references:
- **a book:** `DECOMP` (`reference/explain-decomposition.md`) reads the whole subject (§9.2 *The evidence for a book (an explain phase)*): the code at one commit and every covering phase's records, into `book/research/evidence.md`. It then writes `book/outline.md` from it: the reader; `## Drawn from` (each chapter and the phases it draws from) and `## Gaps`; the order and prerequisites; and for each chapter its key, title, goal, sections, reader tasks, entries, gaps and open items, diagrams and figures, and quiz targets. It cuts one bare chapter slice per chapter, `--kind implementation --risk high`. **The outline gate:** the first chapter slice stops `pending` until the operator signs the outline (`accept`), which signs every chapter's sections at once and freezes the book's `brief.md` and `evidence.md`; on feedback `DECOMP` runs again. **Each chapter slice** (`reference/explain-chapter.md`) reads its phases closer into its own `evidence-ch<k>.md` and drafts (§9.3 *A chapter: its evidence, then the draft*), is judged once by the plugin's `knowledge:explain-critic` on a second model, and is revised once;
- **a document or a chapter:** the same shape with one chapter. `DECOMP` writes the brief, reads the evidence and writes the reader's path (§3 *Gather the evidence*, through §3.10 *D6: the final outline, the reader's path*) into the phase's `doc/` dossier, and always cuts exactly one write slice `S1`; with `outline sign-off: on`, `S1` waits for the operator's `accept` first;
- **the review** (`reference/explain-review.md`) publishes private, proves it private, reads it in the real reader, and returns the URL as the walkthrough.

**The acceptance gate, per unit:** a book's is `--require` (the operator accepts by reading the book); a document's and a chapter's are waived (published private; a v2 is cheap). An explain phase changes no product code and no durable truth, so it leaves no `## Doc impact` notes, owes no docs phase, and appends no `## Regression Checklist` line.

## The research route

An explain tells only what the phases recorded. **When no phase covers its subject** (the code is there, but no phase built or recorded it), the plugin's front door, or *The explain route*'s own confirmation, offers "research first", and on that reply hands this skill the operator's request and a block like this one, verbatim (the plugin's §1 *Resolve the topic, the mode and the placement*, *The phases that cover the subject*):

```
Research: <subject>
- subject: <subject, refined from the operator's words>
- paths: <the subject's files and folders>
- question: what does this code do, and why is it built this way: <the reader's questions, one a line>
- findings-only: yes — it reads the code and records findings in its phase's notebook and topics; it writes no product code
- then: an explain of <subject>, from these findings, only when the operator asks again (`/knowledge:explain <subject>`)
```

A research phase is an **ordinary phase**: no flag, no new `intent.md` section, no engine change. Its `research` slices already record findings, never product code, into the phase's notebook and `topics/`, and that record is what a later explain reads (the plugin's §3.4 *D1: the evidence*). What the route adds is that the scope is already written down, and the lines that make the record findable. The same refine → clarify → **confirm at step 3** → `new-phase` → stop:

1. **Propose from the block** at step 3: the name `Research: <subject>`, and an objective such as *"read `<paths>` and record what this code does and why, as findings, so that an explain of <subject> can be written from them; findings only, no product code"*. The operator may narrow the paths or add questions. The explain does **not** follow by itself.
2. **`new-phase`, fill `intent.md`, STOP.** The request and the block go verbatim under *Original Input (verbatim)*. Under *Confirmed Intent* write the block's five lines as confirmed, one a line: **the `paths:` line and the subject's plain name are what the plugin's coverage greps `intent.md` for**, so that a later explain finds this phase. (Its commits touch only its own phase folder, so the coverage's other half, `git log` over the subject's paths, never names it: these lines, and its `## Decisions` gists naming the same paths, are how it is found.) Then write what its `DECOMP` will cut (below). It runs on the default stream like any phase, unless the operator asks for a worktree.

**What that `DECOMP` will cut** (write it into `intent.md`; do not cut it here): one `--kind research --risk high` slice per part of the subject a reader asks about separately (one for a small subject), declared by the usual rule, and nothing else: no build slices. Each research slice reads **this repository only**: the code at the commit it reads (`git log -1 --format=%h`), its comments and its history (`git log`, `git blame`), never the web, so that its findings stay inside what the code does. It records each finding as:
- a `## Decisions` gist line that names the subject's paths and what was found, its detail in `topics/<slug>.md`;
- in that topic, what the code does, each claim cited `<path>:L<a>-L<b>@<short sha>` (the citation form the explain re-finds, the plugin's B9 *The dossier: files, ids and entries*), the why where the code, a comment or the history shows it, and, on `Not found:` lines, what none of them shows: the explain states those as gaps, never fills them;
- an operator-decision question only on `## Operator Questions`, by the usual rule.

The phase changes no product code and no operator-visible surface, so its acceptance gate is waived at the `DECOMP` boundary (`accept-gate <P> --waive --note "research phase: findings only, nothing the operator sees"`). It leaves no `## Doc impact` note, unless a finding shows a `docs/current/` section wrong, which gets one line. Its closing report ends with the explain it was made for: "ask `/knowledge:explain <subject>` again; its front door now finds this phase as covering the subject."
