---
name: create-phase
description: Capture operator intent (refine → clarify → confirm), then create one or more phases (intent.md + DECOMP/REVIEW only) or route to defer-job. Stops before decomposition.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep
---

# create-phase

Turn an operator request into one or more phases, or a deferred job, with their intent captured first. **This skill creates phases; it never decomposes or implements them** (that is the `DECOMP` slice's job, later), with one exception: *The explain route* creates **and** runs its phase after one confirmation.

**Who may invoke it.** The operator, or the agent when instructed (an approved plan or a direct operator instruction says to create a phase). **Never on the agent's own initiative.** Whoever started it, `phase new` runs only after the operator explicitly confirms each phase's name and objective. **Invocation is not the gate; confirmation is.**

## Procedure

1. **Refine.** Restate the request plainly; read only the `docs/current/` sections it touches and `next` if useful. Keep the operator's exact words. **From an agenda item** (`/create-phase A7-m3`): take its title and note from `agenda --json` as the request; every `phase new` or `defer-job` it runs takes `--agenda <AID>`.
2. **Clarify.** Ask about anything unclear (scope, one phase or several, name and objective, now or later) and wait. Run no `workflow.py` command yet.
   - **Visual design:** ask the design style, with your suggestion and its reason (the `design-cowork` skill's `reference/shape.md`): `build-after` (one phase; the whole design lands, then `DECOMP2` cuts the build), `design-only` (a design phase, then a separate apply phase; it must be chosen here, since `DECOMP` cannot run `phase new`), or `paired` (design 1 → apply 1 → …, no `DECOMP2`). In the same question: *every design job comes as a working canvas you open in the Claude app; do you also want an in-product mockup before you sign, or will you sign on the canvas?* A mockup is a throwaway route built **in addition to** the canvas; the default is `on request`, each job closing on the operator's literal approval when they return to the published canvas. And suggest the drafter: `fable` when the design sets a look (a new face, a redesign, a landing), `opus` when it applies a signed system; Fable costs about twice per round. `drafter` is the only design tool.
   - **An explain** (`/knowledge:explain <topic>`, "explain P30", "write a book on X"): *The explain route*.
   - **If the request carries a `Research: <subject>` block**: *The research route*.
   - **A full regression sweep** ("QA sweep", "re-run the checklist"): *The QA-sweep route*.
3. **Confirm.** Present each phase's **name** and **objective** (a deferred job: title, reason, trigger). For a phase that changes product files, also propose its branch name per repo it will change, from `nested-convention [--repo <name>]` (at root, the repo's habits), with no phase or slice IDs. **One question rides on that confirmation, never a stop of its own:** when `next` lists `pr_open=` or `pr_stack=`, or the operator names an open PR, ask whether the phase builds on one, and propose its branch as the base (`.claude/skills/pr/reference/stack.md`). Never split a phase for size: a large one splits into PRs at its review. Wait for the explicit yes.
4. **Route on the operator's choice.**
   - **Defer:** `python3 scripts/workflow.py defer-job --title "..." --reason "..." --trigger "..." --source ... [--agenda <AID>]` (the engine mints the id); commit, report, STOP.
   - **Make a phase**, for each in the confirmed order: `python3 scripts/workflow.py phase new --name "..." --objective "..." [--agenda <AID>]`; use the id it prints. It creates only `DECOMP` and `REVIEW` and scaffolds `intent.md`. Fill `intent.md`: the request word for word under *Original Input (verbatim)*; the confirmed wording under *Confirmed Intent* (what the operator wants, never workflow mechanics); the Q/A under *Clarifications Resolved*; for a phase that changes product files, a `Branches:` line (`Branches: <name>`, `Branches: <repo>: <name>; …` on a multi-repo host, `Branches: feat/y (base: feat/x, merges after #12)` when stacked; `DECOMP`'s end records them with `pr-branch`); for a visual phase only, `## Design Style` with the style and its reason, then `Mockup: requested` or `Mockup: on request` (the default), then `Drafter: fable` or `Drafter: opus`; for an explain phase only, `## Explain`.
   - **Say nothing about worktrees.** The phase runs on this stream. When `phase new` prints a hint that it could run on its own branch: Relay that hint; never act on it. Only the operator's word starts a worktree, later, in `/do-next-slice` or `/do-whole-phase`. **An explain phase is the one exception:** its route starts the worktree (`worktree: yes`, its default).
5. **Commit, then STOP and report.** Commit only what the intake wrote (the new phase or job folders and the regenerated `works/` files), in one commit by the `commit` skill: `chore(P<N>): create <name> and record the operator's intent` (a job: `chore(D<N>): defer <title>`); nested, with `git -C workflow …`. In a linked checkout (`next` prints `store=cloud`), skip this commit: hi2vi's revisions are the workflow's history. Product commits are unchanged. Never push. List what you created and stop: no decomposition, no `plan.md`, no code.

## The QA-sweep route

A review re-runs only the `## Regression Checklist` lines inside its phase's boundary, so the whole list is re-run only when the operator asks. An ordinary phase through the procedure; objective: *"re-run every `## Regression Checklist` line in the manifest runtime and report what no longer holds"*. Write into `intent.md` what its `DECOMP` will cut: `--kind qa --risk low` slices, one per checklist block; no product code, so its gate is normally waived.

## The explain route

Every explain is its own explain phase: every unit is a phase, a **document** by default, a **book** or a **chapter** of one only when the operator asks, or a v2 (`prior:`), settled once at the start. It tells what this repository's code does from the records of the phases that built it: one writer, a critic on a second model, no research run. The knowledge plugin's explain skill (**0.10.0 or later**) owns every evidence and writing rule; cite its sections by number and heading.

**Refuse, writing nothing:** from inside a phase worktree (`next` prints `stream=`): "start an explain from the main checkout"; a subject with no code behind it; a book or chapter in a public project (`visibility: private` is absolute); the plugin missing, older than 0.10.0 or not set up.

1. **Gather the `## Explain` fields**, drafted the way the plugin's front door drafts them (its §1 and *The front door, step by step*, steps 4–6). The sixteen, in order:
   - **unit**: `document`, `book` or `chapter`. The literal `unit` line is what the front door tests for;
   - **subject**: a phase id, a slice id or a topic of this repository's code;
   - **phases**: the covering phases (at most 6), or `none`;
   - **book**: `none`, or slug and title (kind `codebase`), or the book a chapter joins;
   - **chapter**: `none`, or `<key> — "<title>" · position <n>`;
   - **prior**: `none`, or the version a v2 supersedes;
   - **lang**: `en` (translations: none) unless the operator names another;
   - **reader**: a concrete guess at who it is for and what they will do with it;
   - **depth**: `one document`, `one chapter`, or about how many chapters;
   - **must-cover**, **leave-out**, **trusted sources**: each a list or `none`;
   - **project**: a private knowledge-base project;
   - **visibility**: always `private`;
   - **outline sign-off**: `off` (default), `on` for a book;
   - **worktree**: `yes` (default) or `no`.

   There is **no `run:` line and no `mode:` line**. **The required set, per unit:** all sixteen lines; a document has `book: none`, `chapter: none`, `depth: one document`; a book `chapter: none`, `outline sign-off: on`; a chapter an existing `book`, its `chapter`, `depth: one chapter`. When no phase covers the subject, offer "research first" (*The research route*) or "yes" (`phases: none`). The cost: one writer and one critic on a second model, plus the phase around it. Manual permission mode needs the rules §3.2 *Permissions, and the payload builder* prints.
2. **Show the one confirmation,** in the shape of the front door's step 7: it opens `Explain — confirm once; then it runs to publish.` and carries the plain summary, the reader, the sections, the covering phases, the cost, the phase name (`Explain: <subject>`) and objective, the `## Explain` block and a `Why:` line. One literal yes signs the phase, every field, the worktree and the run in `auto`.
3. **On the yes:** `phase new --name "Explain: <subject>" --objective "..."`; fill `intent.md` (the request, the confirmation as shown and the reply verbatim; then `## Explain`, one field a line, e.g. `- unit: document`, `- phases: P30, P33-n3`, `- outline sign-off: off`, `- worktree: yes`); the intake commit; unless `worktree: no`, `parallel-start <P>` (nested: with no `--host-branch`) and `EnterWorktree`; then `next` and run the phase by `do-whole-phase` in **`auto`**. Its only stops are typed: a critic stop `--stop-kind decision`, a publish failure `operator-action`, a denied call `needs_operator`; a book adds its outline and acceptance gates.

**A confirmed proposal.** From `/knowledge:explain`, the operator's literal yes to the front door's proposal is the one confirmation: check its sixteen-line set, the private project, the subject and the phase ids, then run step 3. A proposal **with no `unit` line**, or with `run:` and `mode:` and no `phases:`, it came from a plugin older than 0.10.0: create nothing; ask for the update. Its `DECOMP` follows `do-whole-phase`'s `reference/explain-decomposition.md` (a book's evidence per §9.2 *The evidence for a book (an explain phase)*). **The acceptance gate, per unit:** a book's is required; a document's and a chapter's are waived.

## The research route

When no phase covers an explain's subject, a "research first" reply arrives with a block: `Research: <subject>`, then `subject:`, `paths:`, `question:`, `findings-only: yes`, `then:`. It is an ordinary phase: propose `Research: <subject>` and an objective that reads `<paths>` and records what the code does and why as findings, no product code. Write the block's lines under *Confirmed Intent* (the `paths:` line and the subject's plain name are what a later explain greps for), and what its `DECOMP` will cut: one `--kind research --risk high` slice per part of the subject, reading this repository only, each finding a `## Decisions` gist naming its paths with detail in a topic, cited `<path>:L<a>-L<b>@<short sha>`, and `Not found:` lines for what the code does not show. Its gate is waived (`accept-gate <P> --waive --note "research phase: findings only, nothing the operator sees"`). Its closing report says: ask `/knowledge:explain <subject>` again.
