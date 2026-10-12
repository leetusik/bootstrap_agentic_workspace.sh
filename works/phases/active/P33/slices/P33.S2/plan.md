# Plan — P33.S2: Skills, contract and release v54 — the one-shot chain

`implementation / low` (the texts are pinned below and in `phase.md`; no design decision is left open). Executor: `slice-executor-mid`. Depends on `P33.S1` (landed, committed as `ea90793`).

## Context

`P33.S1` landed the engine: `rotate-backlog` (default) checks the doc debt first and prints `rotate=<refused|archive|stop_midflight|resume|create>` as its first stdout line, archives only when nothing owes, puts the docs phase ahead of planned work with `--order` on `create` and re-asserts that order on `resume`, stops for mid-flight default-stream work, and refuses on a parallel stream. The **exact printed lines, follow-up lines and exit codes** are in `works/phases/active/P33/phase.md` `## Decisions` under *Engine (landed in P33.S1)* — read that entry whole and write every skill line against it, never from memory. Read also the two notes tagged `for P33.S2` under `## Notes for later slices`, the *skill runs the chain* and *Release* Decisions, and `intent.md` (the operator's confirmed intent and the `## Notes` list of texts that move).

This checkout is P33's parallel worktree: **never run `rotate-backlog` or any writing engine command here** (even a no-op rewrites the generated `works/` files). The smoke test must be the **only** command in its Bash call. After every machinery edit run `python3 installer/build.py`; `--check` must pass.

## What to write

### 1. `.claude/skills/rotate-backlog/SKILL.md` — rewrite to the chain

Frontmatter: `name: rotate-backlog`; a `description` (quoted, no bare `: ` inside) saying one invocation pays the doc debt then archives: check the debt first, create and run the docs phase, archive every done phase; `archive-only` keeps the archive-and-report path; `gate` restores the approval loop. `argument-hint: "[archive-only] [gate]"`. `allowed-tools`: what `do-whole-phase` grants (`Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash, Agent`) — it embeds that loop; keep `disable-model-invocation: true`.

Body, in order:
- One paragraph: what one invocation does and that it is safe to re-run at any point of the chain (resumes from the live docs phase).
- **Procedure.** (1) `archive-only` in the args → `python3 scripts/workflow.py rotate-backlog --archive-only`, relay, STOP. Otherwise run `python3 scripts/workflow.py rotate-backlog` and branch on the **first stdout line as a prefix** (read stdout before the exit code — `refused` exits 1):
  - `rotate=refused` → relay the line and stderr, STOP (run it from the main checkout).
  - `rotate=archive` → relay the sweep report; commit the archive (`chore(works): archive <ids> with rotate-backlog`, or nothing to commit when nothing was rotated); report; STOP.
  - `rotate=stop_midflight` → relay `midflight=`, `stopped_before=` and the closing line; nothing was archived, created or reordered; STOP.
  - `rotate=create` → **show the proposal** (`docs_phase_proposal=`, `phase=`, `name=`, `objective=`, `scope:` and `docs-debt`'s scope in a few lines) so the operator sees what is being created, then run the printed `create:` line **exactly as printed** (its `--order` is the queue jump; the invocation is the operator's yes — no pause, no narrowing, no editing); read `<P>` from the `phase=` line. Fill `works/phases/active/<P>/intent.md` per `create-phase`'s docs-phase route: origin `operator`; *Original Input (verbatim)* = the `/rotate-backlog` invocation; *Confirmed Intent* = the engine-drafted name and objective and the `docs-debt` scope; the cut `DECOMP` will make (one `--kind docs` slice per doc, `doc-new-version` → `rebuild-docs` per note, the payment per covered phase as `docs-debt`'s `pay:` line says, gate `--waive`d at the `DECOMP` boundary). Relay any parallel `hint:` `new-phase` prints, never act on it. Commit (`chore(works): create <P> with rotate-backlog`). Continue as `resume`.
  - `rotate=resume` → if a `docs_phase_order=` line was printed, `phase.json` and the regenerated `works/` files changed: commit them (`chore(works): move <P> ahead with rotate-backlog`). Relay `docs_phase_covered=` / `docs_debt_waiting=`. Then **run the docs phase `<P>` end to end per the `do-whole-phase` skill in `auto`**: `next` now points at it (lowest order); the `/rotate-backlog` invocation is the explicit `auto` the contract's decomposition carve-out requires, so its `DECOMP` plans inline; `gate` in the args restores the approval loop instead. The normal stops end the run (`pending`, `needs_operator`, `blocked`, a failed or empty high return, a non-passing review): report where it stopped and that the next `/rotate-backlog` resumes from there. The docs phase's acceptance gate is normally `--waive`d at its `DECOMP` boundary. When the phase is `done`, run `python3 scripts/workflow.py rotate-backlog` once more: on `rotate=archive`, sweep, commit and report; **on anything else, relay it and STOP** (one docs phase per invocation keeps the chain finite).
- **Rules.** The docs phase runs on the default stream only (never ask for a worktree; relay hints). `rotate-backlog` creates the docs phase only through the printed `create:` line, never narrows or edits it, and never runs `--force`. Every stop is reported with the exact line that caused it. `archive-only` never creates or runs anything.

### 2. Other skills (minimal edits, each file's own voice)
- `.claude/skills/create-phase/SKILL.md` l.11: the "when instructed" exception gains the `/rotate-backlog` docs-phase route, **where the invocation is the confirmation** ("Invocation is not the gate; confirmation is" stays true for every other phase). *The docs-phase route* (~l.74–93): `/rotate-backlog` no longer "archives the clean phases" first — it checks the debt first, creates the docs phase from the engine's proposal on the invocation alone, runs it, then archives; the route's step 3/4 still hold for a docs phase created by hand through `/create-phase`.
- `.claude/skills/archive-phase/SKILL.md` l.20–34: rotate's paragraph — debt first, docs phase created and run, archive every done phase at the end; `--archive-only` keeps the plain sweep.
- `.claude/skills/do-whole-phase/SKILL.md` l.53 and `.claude/skills/do-next-slice/SKILL.md` l.45: archiving is never the loop's job; it is `/rotate-backlog`'s, which archives after the docs phase it runs (or `archive-all` / `archive-phase <P>`). Touch only that sentence in each file (P32 edits other parts of these files on the default stream).
- `.claude/skills/review-phase/SKILL.md` l.85: the archiving clause names `/rotate-backlog` the same way.

### 3. Contract `CLAUDE.md` — four lines only
- l.13: the create-phase exception gains "and `/rotate-backlog`'s docs-phase route, where the invocation is the operator's yes".
- l.15: the decomposition carve-out: "(inline only on an explicit `auto`, which a `/rotate-backlog` run is for its docs phase)".
- l.19 *Making a phase ≠ executing it*: add that `/rotate-backlog` is the one invocation that creates **and** runs its docs phase.
- l.53: "Archiving is explicit — `/rotate-backlog`, `archive-all`, `archive-phase <P>` — and takes whole phases only, never individual slices."

### 4. `README.en.md` l.454 — the `rotate-backlog` row: one invocation pays the doc debt (creates and runs the docs phase) then archives every done phase; `archive-only` keeps the plain sweep. If `README.md` (Korean) has the same table row, update it to match; if not, leave it.

### 5. Release v54
- `installer/main.py` l.44: `WORKSPACE_VERSION = 54`.
- `CHANGELOG.md`: a `## v54 — 2026-10-12` section directly under the header paragraph (above `## v52`; P32's v53 slots between at merge). Model it on v51's shape: the one-shot chain and the five `rotate=` branches with their meaning; the queue jump and the resume re-order; the mid-flight stop; the invocation-is-the-yes amendment (docs-phase route only); `gate` and `archive-only` words; the skills, contract and README edits; the smoke baseline 239 → 247. End with a **Migration notes** line: nothing to run; a docs phase created under v51–v53 sits behind planned work until the first `/rotate-backlog` re-asserts its order; `archive-only` is unchanged; `/update-workspace` overwrites the rotate-backlog skill as machinery.
- `python3 installer/build.py`, then `python3 installer/build.py --check` → pass; the rebuilt `bootstrap_agentic_workspace.sh` is in `files_changed`.
- Keep `(v54)` tags few; list every place the number appears (yours plus S1's three comments) in `result.md`.

## Not in this slice

No engine logic changes (S1 landed them); no `doc-new-version`; no commit; no state transition; no edits to `do-whole-phase` / `do-next-slice` / `CLAUDE.md` beyond the lines named.

## phase.md

- Consume the two `for P33.S2` notes.
- Append `## Doc impact` notes only for what this slice changes: `operations.md` (the v51 release note becomes v54's; the *`/rotate-backlog` is the default entry point* paragraph describes the chain; the pre-v51 migration line) and `decisions.md` (the skill half of the decision superseding v0043) — one line each tagged `(P33.S2)`; the engine-half notes from S1 are already in.
- Rewrite `## Now` for the review: what landed, the smoke count, the `v54` locations, the two operator questions still open.

## Validation

- `python3 installer/build.py --check` → pass.
- `bash tests/retrofit_smoke.sh` as the only command in its Bash call → report PASS/FAIL (expect 247 / 0 or higher; a failing line is a defect to fix in this slice).
- `python3 scripts/workflow.py validate` → pass (expected warnings: `consolidation_owed=P33`, `oversized_doc_sections`, `stale_docs=…` from the `## Doc impact` notes).
- Skill frontmatter: every edited SKILL.md still parses as YAML (`python3 -c "import yaml"` if available, else check by eye that `description` is quoted and has no bare `: `).
- A read-through of the new rotate-backlog skill against the *Engine (landed in P33.S1)* lines: every branch named, every printed line the skill reads matches the engine's exactly.

## Verdict

`result.md` with the verdict block first: status, tier, summary, files_changed, validation (smoke counts), deviations, doc_impact.
