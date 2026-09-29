# Plan — P26.S2: add the design subagent and ship it

## Context

P26 moves design drafting from Claude Design to a **dedicated design subagent** that writes rounds into the on-disk contract S1 landed. The contract is §*The design record — the on-disk contract (schema 1)* in `.claude/skills/design-cowork/SKILL.md`; its summary is at the end of `slices/P26.S1/result.md`.

This slice adds the agent file and ships it. It does **not** rewrite the loop in `design-cowork` (that is S3), and it does not touch `CLAUDE.md`, the do-* skills or the executor bodies (that is S4).

Binding notes in `phase.md`:
- `for P26.S2`: what the drafter writes, runs and never runs;
- the five shipping places;
- the frontmatter rules;
- `for every slice`: the build and smoke rules.

## Decisions pinned by the orchestrator

- **Name and file:** `.claude/agents/design-drafter.md`, `name: design-drafter`.
- **Model source: it tracks the high tier through `sync-agents`.** Add a third entry to `executor_agent_files()` in `scripts/workflow.py` that maps `design-drafter.md` to `config["high"]`'s model and effort. It must not add a new tier to `EXECUTOR_TIERS`, `executors.toml` or the presets.
  - **Why:** one knob (economy/flex) governs all agents, and design never runs on the mid tier.
  - Update the function's docstring. Make sure the drift check, `sync-agents` and the status line handle the third file, and say so in `result.md`. Also update the `executors.toml` seed comment in the installer, if it lists the agent files, so it mentions that the drafter follows `high`.
- **Frontmatter:**
  - `tools: Read, Edit, Write, Glob, Grep, Bash, Skill`. `Bash` is for `design-check` and an optional headless screenshot. `Skill` is for `frontend-design`. No `DesignSync`, no web tools.
  - `model` / `effort` as `sync-agents` writes them for high (`opus` / the current preset's effort).
  - Copy the executors' `permissionMode:` line.
  - `description:`: one sentence, with any `: ` quoted or reworded out.
- **Body.** Keep it short and in the executor files' voice; it is doctrine, not an essay. It covers:
  1. **Role.** It drafts exactly one design round's cards into the contract from the round's `handoff.md`. It is dispatched by the orchestrator as a background task, and it never commits or transitions state.
  2. **Inputs.** The dispatch prompt gives the round folder (`docs/reference/design/rounds/<NN-slug>/`) and the co-work slice id. Read `handoff.md`, `design.json`, `tokens.css`, the existing library cards, and prior rounds' `SIGNOFF.md` / `feedback.md` / `result.md` as the design memory.
  3. **Writes.**
     - The cards at exactly the numbered paths the handoff names, with the line-1 `@dsCard` marker carrying `⏳ <slice> · <Group>`.
     - Each card self-contained: only `../tokens.css` may be referenced relatively.
     - `tokens.css` when the round changes the system.
     - The round's `result.md`: what was designed, and every departure from the handoff logged.
     - The round's `build-prompt.md`: complete enough to build from.
  4. **Grounding.** Extend the existing system (tokens, library, signed decisions). **RESPECT THE DESIGN** applies to signed rounds: never restyle or drop a signed element unless the handoff asks for it.
  5. **`frontend-design`.** Load it via `Skill` **only** on rounds that set a new visual direction: a product's first round, a redesign, or a new brand or surface family (P25.S2 §5). Never on rounds that extend an existing system.
  6. **The operator decides.** The drafter drafts variants and proposals; nothing is decided until the operator's literal signoff. It never writes `SIGNOFF.md`, and it never runs `design-open`, `design-close` or `design-register`. It never edits `round.json`, `design.json` or anything in a closed round's folder.
  7. **Check before returning.** Run `python3 scripts/workflow.py design-check <the handoff's card paths>` and return only on exit 0, or return `blocked` with the named problems.
     - Optional visual self-check: a screenshot via a throwaway headless browser. This is never the operator's profile, and Aside only with the agent account id recorded in `## Operator Runtime`.
  8. **Return a structured verdict:**
     - `status: done | needs_operator | blocked`;
     - `round`, `cards_written`, `tokens_changed`;
     - `frontend_design: used | not used` (with why);
     - `departures`;
     - `design_check` (the output line);
     - `open_questions` for the operator.

     `needs_operator` covers a handoff too thin or contradictory to draft from. It never fills the gap with a decision.
- **Shipping (the five places):**
  - `installer/build.py` `FIXED_LIVE_FILES`;
  - `installer/main.py` `MANAGED_FILES`, the agent emit loop (emit the drafter too) and the banner's agents line (L688; leave the "Visual design" line L689 to S4);
  - smoke `DUAL_FIXED`;
  - grep the smoke suite for pins on the agent set or banner and update them.
- **Smoke:** add at most two small probes:
  - a fresh install ships `.claude/agents/design-drafter.md` with `Skill` in its `tools:` and no `DesignSync`;
  - `sync-agents` keeps the drafter on the high tier's model (e.g. after `executor-mode economy` its `model:` matches `slice-executor-high`'s).

  Core invariants only.

## Validation

- `python3 installer/build.py`;
- then, in its own foreground Bash call with a 600 s timeout: `bash tests/retrofit_smoke.sh` (all PASS; report the new count);
- `python3 installer/build.py --check` OK;
- `python3 scripts/workflow.py sync-agents --check`, or the equivalent, reports in sync;
- `python3 scripts/workflow.py validate` exits 0.

## Notebook

- `## Doc impact`: architecture (the third agent file and that it follows the high tier), operations (executor tiers: the drafter), qa (the smoke count).
- `## Notes for later slices`: consume the S2 notes, and leave S3/S4 anything they need about how to dispatch the drafter (what the prompt must carry).
- `## Now`: rewrite it.

Write `result.md` with the verdict block first.
