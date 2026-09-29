# Changelog

Workspace versions for the agentic-workspace cornerstone. One `## v<N>` section per
integer `WORKSPACE_VERSION`, newest first. `/update-workspace` reads this file from
the upstream clone to show adopting repos what a sync brings — so each entry states
what changed and, when a sync needs manual steps, a **Migration notes** line.

Everything before v1 is **pre-versioning**: those workspaces carry no
`workspace_version` in `works/.workspace-version.json`; consult `git log` for that
history.

## v47 — 2026-09-29

- **The design lives in the repo, under a written contract.** Visual design no longer lives in a
  Claude Design project that the agent reads back through `DesignSync` (both need a claude.ai
  login, so they fail under `ocx claude`, and `DesignSync` cannot run in a subagent).
  Schema 1 puts one design project per repo at the fixed root `docs/reference/design/`: a
  `design.json` manifest (`{schema, id, name}`), numbered self-contained cards
  `cards/NN-slug.html` (line 1 is the `@dsCard` marker: `group`, `viewport`, optional `title`), one
  `tokens.css`, and a flat folder per round under `rounds/NN-slug/` (`round.json`, `handoff.md`,
  `result.md`, `build-prompt.md`, and `feedback.md`, `SIGNOFF.md` or an `import/` folder when they
  apply). At most one round is open at a time, and a closed round is an immutable snapshot of the
  cards and tokens it touched. The contract is written out in `design-cowork`, so a separate
  dashboard can read it without configuration.

- **Five `design-*` commands run the round's lifecycle.** `design-init` writes the manifest,
  `design-open` opens the next round, `design-check` names every contract problem with exit 1 (and,
  given the handoff's paths, runs the read-back check), `design-close <round> --words "…" |
  --superseded` snapshots, regroups line 1 only (every later byte is asserted identical) and closes
  the manifest, and `design-register` records the repo in a registry outside it so a dashboard can
  list it. All five are stdlib-only, and `design-close` and `design-register` are idempotent.

- **A design subagent drafts.** `.claude/agents/design-drafter.md` drafts one round's cards,
  `tokens.css`, `result.md` and `build-prompt.md` from `handoff.md`, runs `design-check` on its own
  paths, and returns a verdict block. It never signs, opens or closes a round, edits a record it does
  not own, builds a mockup or writes product code. It is not a third tier: it follows the **high**
  tier's model and effort through `sync-agents` and `executor-mode`, so one knob governs every agent
  file. It may load the `frontend-design` skill on a round whose handoff says `new visual direction:
  yes`, and nowhere else.

- **`design-cowork` is rewritten around the files.** Per round: the orchestrator opens the round
  and writes the handoff, `design-drafter` drafts it in the background, the orchestrator reads it
  back with `design-check` itself, and the slice stops for the operator. Literal approval writes
  `SIGNOFF.md` and runs `design-close --words` (two commits, one stop); anything else is recorded in
  `feedback.md`, closes the round `--superseded` and opens a new round of the same slice (one more
  commit and stop). A requested mockup is unchanged in spirit but goes three commits and two stops,
  not four, because there is no landing step. The `DesignSync` read-back and the SIGNOFF regroup are
  retired, along with the push and the `_ds_manifest.json` card contract. Governance is unchanged:
  the three styles, immutable rounds, literal signoff, the mockup gate and RESPECT THE DESIGN.

- **Claude Design is an optional bundle import.** An export the operator already has goes into a
  round's `import/` folder; the drafter translates it and logs its departures. No claude.ai account
  or `DesignSync` is needed for anything.

- **The hard rule now says who drafts.** The contract's visual-design rule reads "the design
  subagent drafts, the operator decides", and a `co-work` slice still runs inline. Its drafting is
  dispatched to `design-drafter` and its mockup build (only on request) to `slice-executor-high`,
  while the round's lifecycle and the operator's words stay on the main thread. Approval is still
  literal and a design slice still authorizes no `git push`.

- **Where it landed.** `CLAUDE.md` (the co-work exception and the visual-design rule, still under
  12 KB), `design-cowork`, `do-next-slice`, `do-whole-phase` (the per-round co-work steps and the
  idle-window note), `create-phase` (the mockup question), both executor bodies (the mockup span
  now reads the round's record on disk; still word-for-word identical), the installer banner, both
  READMEs and the retrofit guide. The smoke test moves the old pins to the new loop, retires
  `DesignSync` and the four-commit mockup as negative pins, and adds pins for the contract, the
  drafter and the commands. Installer rebuilt.

- **Migration notes.** (1) A round in flight in Claude Design under v46 can be finished there and
  brought in afterwards through the bundle import, or superseded by a first round under the new loop.
  (2) A record built around `_ds_manifest.json`, a repo's own `design/` tree or `rounds/<NN>/output/`
  moves to schema 1: run `python3 scripts/workflow.py design-init`, then move each card to
  `docs/reference/design/cards/NN-slug.html` with the `@dsCard` marker on line 1 (see the contract in
  `design-cowork`); `validate` does not run `design-check`, so run that yourself. (3) Run
  `python3 scripts/workflow.py sync-agents` after `--update`: updates reset agent files to the
  upstream defaults, and the drafter follows `[claude.high]`, so an override moves it too. (4) Run
  `python3 scripts/workflow.py design-register` once per product repo to list it for a dashboard; the
  registry is `$AGENTIC_DESIGN_REGISTRY`, default
  `~/.config/agentic-workspace/design-registry.json`. It is the first engine write outside a repo,
  which is why it is the operator's to run and no round waits on it.

## v46 — 2026-09-29

- **Mid is the default executor tier.** Since v23 routing was "high unless trivial": only a
  one-line or few-line edit or docs was rated `risk: low` and went to `slice-executor-mid`, and mid
  escalated the moment a slice turned into real code or touched a second file. With a stronger
  sonnet the rule flips to "mid unless a named trigger says high". `implementation`, `fix`, `docs`
  and `qa` slices are rated `low`, real code writing and multi-file changes included, as long as
  the plan pins the approach. Models and presets are unchanged: mid is sonnet and high is opus, at
  `high` effort in `economy` and `xhigh` in `flex`.

- **`high` needs a named trigger.** A slice earns `risk: high` only for **open design** (the plan
  cannot pin the approach), a **core invariant** (persisted state or a schema migration, state
  transitions, auth, money, deletion, concurrency), an **unlocated root cause** (a bug whose cause
  is known and located is `low`), or a **wide blast radius** (a shared interface whose callers are
  spread across the code). The decomposition writes the trigger beside each high rating. Kind
  routing is unchanged: `decomposition`, `research` and `review` go to high whatever their `risk`,
  and so does a co-work mockup span, the operator's approval surface. The safety net is unchanged
  too: `--risk` still defaults to `high` and an unrecognized value still routes high, so the
  decomposition rates every slice explicitly. QA-sweep slices are now cut `--kind qa --risk low`.

- **A second attempt never goes back to mid.** Mid escalates on four named reasons instead of
  "real code or more than one file": the plan's approach fails and repairing it needs a design
  decision the plan did not make; a high trigger the rating missed turns up; **two strikes**, where
  the same validation failure survives two honest fix attempts; or the job grows past the plan's
  scope. The ladder is unchanged (one escalation per slice, a failed or empty mid return counts as
  one, high never escalates). New: the executor verdict block gains a `tier: mid|high` line, the
  review rates each proposed fix slice, and a fix for a defect in a slice whose verdict reads
  `tier: mid` is `risk: high`. The do-* skills now create fix slices with `--kind fix --risk
  <low|high>` from that rating, where before they took the `high` default.

- **Mid gets `WebSearch` and `WebFetch`.** Only high had them, a leftover from v16's auto-explain,
  which has since been retired. A tier that writes real code against real libraries needs the
  docs.

- **Haiku is never an executor tier.** That was already true of both presets. The engine comment
  and the seeded `executors.toml` header stop offering haiku as an example.

- **Where it landed.** The contract's `risk` sentence (still under 12 KB), both executor bodies
  (still word-for-word identical) and their descriptions, `do-next-slice`, `do-whole-phase`,
  `review-phase`, `create-phase` (the QA-sweep rating), `design-cowork` (why the design slice stays
  `high`), the `--risk` help on `new-slice` and `promote-deferred`, the seeded `executors.toml`
  header, both READMEs and the installer's closing line. The smoke test pins the new wording in the
  contract, the do-* skills and both executor bodies, plus mid's tools line. Installer rebuilt.

- **Migration notes.** Run `python3 scripts/workflow.py sync-agents` after the update as usual.
  Slices that already exist keep their recorded `risk` (planning bumps up, never down), so the new
  standard applies to slices cut from now on. A seeded `executors.toml` is never overwritten, so an
  adopting repo keeps the old tier comment in its header until the operator edits it. Only the
  comment is stale; routing does not read it.

## v45 — 2026-09-29

- **Switch the executor mode with one command, and see which one is on.** Changing the preset both
  slice-executor tiers run on (`economy`: sonnet@high / opus@high; `flex`: sonnet@xhigh /
  opus@xhigh) meant hand-editing the `mode` line in `executors.toml` and then remembering
  `sync-agents`. `python3 scripts/workflow.py executor-mode <economy|flex>` now does both. It
  rewrites only the value of the top-level `mode = "…"` line (a trailing comment survives), inserts
  one before the first `[claude.<tier>]` table when there is none, and creates a one-line file when
  `executors.toml` is absent. Then it syncs `.claude/agents/slice-executor-{mid,high}.md`. A
  malformed file errors before anything is written, an unknown preset is refused by the argument
  parser, and re-selecting the active mode reports `(already set)` and still re-syncs. The switch
  is logged as an `executor_mode_set` event beside the usual `agents_synced`.

- **`executor-mode` run bare is the status command.** It prints the active mode and its source
  (`executors.toml`, or the `economy` default with or without a file), each tier's model @ effort,
  the per-tier overrides beside the preset value each one shadows, whether the agent files match
  (naming the drifting or missing file), and the presets on offer. It is read-only and exits 0 even
  on drift; `sync-agents --check` stays the gate that fails.

- **Per-tier overrides still win, and a switch says so.** When `executors.toml` carries
  `[claude.<tier>]` model/effort overrides, the switch still sets the mode but prints a `note:`
  listing the overrides that keep beating the new preset. It never deletes or edits them.

- **`/executor-mode` ships as the 18th skill**, explicit-invocation only like every other workflow
  command skill: `/executor-mode` shows the mode, `/executor-mode flex` switches it. Claude Code
  reloads edited agent files, so the next dispatch runs on the new mode without a restart. The
  seeded `executors.toml` header now names the one-step switch before the manual edit-and-sync
  route.

- **Mechanics.** `sync-agents`' drift computation moved into a shared `executor_agent_drift()`
  helper that both commands use, and `sync-agents`' output is unchanged. The skill inventory is 18
  in `build.py`, `main.py`, the smoke test and both READMEs. The smoke test asserts the status
  report, the switch in both directions, the byte-identical round trip of the seeded file, the
  override note, the missing-file create, and the refusal of an unknown preset. Installer rebuilt.

**Migration notes.** Nothing new to run: `/update-workspace` delivers the engine command and the
`executor-mode` skill, and the usual post-update `sync-agents` still applies. Your `executors.toml`
is seed-once, so its header comment keeps its old wording and won't mention `executor-mode`. The
command works on the file as it is.

## v44 — 2026-09-28

- **Why this release: the contract is a routing layer again.** `CLAUDE.md` had grown to 50,048
  bytes (49,646 characters), over Claude Code's 40,000-character per-file instruction warning, and
  it loads into every session and every slice-executor dispatch. v44 cuts it to 12,259 bytes, under
  the 12 KB (12,288-byte) target deferred job D8 set, without dropping a rule: each of its 58
  "never" rules keeps a statement in the contract, and everything that left still has a carrier.
  Commands are read from `python3 scripts/workflow.py --help`, procedure from the skill that runs
  it (`do-next-slice`, `do-whole-phase`, `create-phase`, `review-phase`, `design-cowork`,
  `parallel-phase`, `archive-phase`), and what a dispatched slice needs from the executor bodies.
  The per-dispatch prefix (contract plus executor body) falls from 77,782 to 40,844 bytes.

- **`## Workflow Commands` is gone; `python3 scripts/workflow.py --help` is the command
  reference.** The section restated the engine's own help, one bullet per command. The one fact
  worth keeping in the contract, the closed `--kind` set, moved to *IDs and Status*. Both READMEs
  now point at `--help` too.

- **Procedure the skills and executors already carry left the contract.** Mode mechanics and plan
  persistence, the preset matrices, the escalation path, idle-window details, the design slice's two
  `pending` windows, the review-verdict transitions, the acceptance-gate walkthrough sequence, the
  archiving guard and the phase-branch merge now live only in `do-next-slice`, `do-whole-phase`,
  `review-phase`, `design-cowork`, `archive-phase`, `parallel-phase`, the executor bodies and the
  engine, which already said the same thing. The contract keeps each rule's prohibition.

- **The Aside, worktree and design rules are stubs now; their procedure lives in the skills.** The
  three largest Hard Rules bullets (11.5 KB between them) and the design-styles tail of the
  decomposition bullet restated `design-cowork` and `parallel-phase` almost word for word. Each is
  now a short stub that keeps its prohibitions: `aside repl` over Bash and never a standing MCP
  registration, the dedicated profile (`--account <id>` on every call, the third halt, and the
  unchanged clause that an agent never drives a profile signed into the operator's accounts,
  whichever browser it is), the fallback, a worktree only on the operator's word and never for a
  docs phase, never merging past a closed gate, `--risk high` and no product code in a design
  slice, `design-only` chosen at `/create-phase` or nowhere, literal signoff, and RESPECT THE
  DESIGN. The two surfaces, the MCP cost and escape hatch, the eight worktree rules, the three
  styles, the numbered cards and the design slice's stops are read from `design-cowork` and
  `parallel-phase`. Both executor bodies now say that every design style's `DECOMP` records a
  **build inventory** in `phase.md`, which the contract used to carry.

- **What remains is seven sections of short stubs, one statement per rule.** *Driving This
  Workspace* absorbs the intent rules (refine, clarify, confirm; `new-phase` only after the operator
  confirms) and *Canonical State* the slice-file and notebook rules (the verbatim `intent.md` is
  immutable; two context files per slice, the verdict block first; the `phase.md` / `result.md`
  audience split; never pre-filling another slice's plan; the notebook edited under budget, never
  dropping a decision or a question), so *Hard Rules* keeps only what no other section owns. The
  section headings and the anchors the skills cite (*Making a phase ≠ executing it*, *Orchestrator
  and executor*, *Commit Convention*, `DECOMP2`'s two origins, the small-test-files rule) are
  unchanged.

- **A `docs` slice may now version docs.** The executor bodies forbade `doc-new-version` on every
  slice but the review, while a docs phase's slices exist to run it; only the contract implied the
  exception. Both executor bodies now carry it (operator-approved wording): a `docs` slice in an
  operator-created docs phase, on the default stream, may run `doc-new-version` and `rebuild-docs`
  for the `## Doc impact` notes its plan names, editing only the returned `edit_path`; recording
  `docs-consolidated <P>` stays the orchestrator's.

- **Fractional `--order` and advisory `depends_on` are stated where a decomposition reads them.**
  The executor's decomposition bullet now says them, and `new-slice`, `promote-deferred` and
  `new-phase` gained `--order` (and `--depends-on`) help text.

- **`parallel-phase` no longer says the do-* skills start a worktree on a hint.** Its
  `parallel-start` section said "the do-* skills do this for you when `next` prints the hint", a
  v42 leftover that contradicted v43's "relay a hint, never act on it". It now says `parallel-start`
  runs only on the operator's word and a hint is relayed.

- Smaller fixes: `do-next-slice` and `do-whole-phase` list `research` among the delegated kinds; the
  notebook template (and its embedded fallback) tags notes `**(from <slice>, for <slice>)**`, the
  form the executor and every live notebook use. Installer rebuilt.

- **Smoke follows the text.** Test 0's contract list keeps the 38 pins the stubs still carry and
  all 19 retired-phrasing negatives. Each of the 22 pins whose text left the contract is asserted
  where that text lives now: on the do-*, create-phase, design-cowork, parallel-phase,
  review-phase or executor lists, or functionally (Tests 9 and 11). Test 0 also gains a
  `parallel-phase` pin list (the worktree rules, the hint and merge-gate prohibitions, and the fix
  above), two more `design-cowork` pins (the numbered cards, the instrument/runtime axis), asserts
  for the two new executor-body rules, and copies of four retired phrasings on the skills that now
  carry their rules. The PASS count is unchanged.

**Migration notes.** Nothing to run. `/update-workspace` refreshes the contract (or its
`CLAUDE.workspace.md` sidecar in a repo that keeps its own `CLAUDE.md`), the executor bodies, the
skills and the engine. Use `python3 scripts/workflow.py --help` wherever you used to read the
Workflow Commands list, and read a procedure the contract used to spell out in the skill that runs
it.

## v43 — 2026-09-17

- **Why this release: v42 made every phase pay for parallelism almost no run used.** One phase at a
  time is the normal shape of this workspace, and v42 put each one on its own branch in its own
  worktree at first execution. Every ordinary run bought a stamp commit, a branch, a nested checkout
  and an integration sequence to get back — machinery that earns its keep only when two phases are
  genuinely moving at once. v43 puts the default back on the current checkout and makes the worktree
  **opt-in again**. Nothing about the mechanism changed; only how it is reached.

- **A phase runs on the default stream unless the operator asks for a worktree.** Rule 1 of the
  contract's Worktree rules is now *when — only when asked*, and asking has three forms: the
  **`worktree`** mode word on `/do-next-slice` / `/do-whole-phase` (or the same thing in the
  operator's own words — "in a worktree", "in parallel", "on its own branch"), `parallel-start <P>`
  run by the operator's own hand, or an explicit instruction to run two phases at once. The do-*
  skills never run `parallel-start` on their own initiative and `create-phase` still never does; a
  phase already carrying the stamp is entered without asking again. Rules 2–7 — the nested worktree
  home and the `info/exclude` line, the dirty-tree stamp commit, what stays behind, what still
  refuses, enter/exit, and the local `--no-ff` merge — are unchanged.

- **The hints are suggestions again, and fire only where a worktree pays.** `next` on the default
  stream prints `hint: <P> is waiting behind <current> — it can run in parallel on its own branch`
  when the current phase is `in_progress` and a later one is still `planned`; `new-phase` prints the
  same suggestion when it creates a phase while another is in flight. Both are silent in the ordinary
  one-phase-at-a-time run. v42's "this phase runs in its own worktree by default" hint is gone with
  the default that justified it. **Relay a hint; never act on it** — the contract, both do-* skills
  and `create-phase` say so explicitly.

- **`parallel-skip <P>` and `new-phase --on-main` are retired into no-ops.** They existed only
  because v42 needed a marker for "run on `main`"; the default stream now needs none. Both stay
  callable so adopting workspaces' habits and scripts survive the upgrade: they write nothing, stamp
  nothing, report where the phase actually runs, and exit 0. A docs phase needs no pin either — it
  runs on the default stream like everything else, and the rule that matters is stated directly
  instead: **never ask for a worktree on a docs phase**, since `doc-new-version` /
  `docs-consolidated` only work there.

- **v42's pin is still honoured where it exists.** A phase carrying `execution: {"mode": "default"}`
  keeps it, still validates, and still runs on the default stream — and `parallel-start` refuses that
  phase rather than override a deliberate pin. Un-pinning is a deliberate hand edit: delete the block
  from its `phase.json`.

- Smoke Test 12 is rewritten for the reversed default: creating and selecting a lone phase says
  nothing about worktrees, the waiting-behind hint fires from both `next` and `new-phase`, the
  dirty-tree stamp / nested worktree / exclude line / gate / local merge / teardown checks are
  unchanged, `parallel-skip` and `--on-main` are asserted to stamp nothing, and a hand-written legacy
  pin is asserted to validate and to be refused by `parallel-start`. Both READMEs and the
  `update-workspace` migration notes updated; installer rebuilt.

**Migration notes.** Nothing to run. Phases already stamped `execution: {"mode": "parallel"}` keep
running in their worktrees and integrate exactly as before. Phases carrying v42's
`execution: {"mode": "default"}` pin keep it and still validate. If a habit or script calls
`parallel-skip` or `new-phase --on-main`, it keeps working and now does nothing — drop it when
convenient. To put a phase in a worktree from here on, ask for one.

## v42 — 2026-09-13

- **Why this release: parallel mode was opt-in, so it was never the shape of the work — and a design
  round always paid for a mockup.** Every phase queued on `main` behind the one before it; the opt-in
  moment was creation, the one moment nobody thinks about execution; and `parallel-start`'s clean-tree
  guard refused exactly when the operator was mid-edit. On the design side every round paid a
  dispatched mockup build and a second `pending` stop even when the operator would have signed on the
  cards, and the cards carried no order, so the operator's review order was undefined. v42 reverses
  both defaults and writes the rules down.

- **Every phase runs in its own git worktree by default, entered at first execution in the same
  session.** Eight explicit **Worktree rules** now live in the contract and the `parallel-phase`
  skill: (1) *when* — a `planned` phase with no `execution` block enters its worktree when `next`
  points at it and `do-next-slice` / `do-whole-phase` run `parallel-start`; `create-phase` never does;
  (2) *where* — `<repo>/.claude/worktrees/P<N>-<slug>` on `phase/P<N>-<slug>`, the location Claude
  Code's `EnterWorktree` accepts from anywhere, with `.claude/worktrees/` written to
  `.git/info/exclude` (never `.gitignore`); (3) *the stamp commit* — exactly the phase folder plus the
  five regenerated `works/` files; (4) *what stays behind* — everything else dirty or staged, and the
  worktree starts from that commit; (5) *what still refuses* — not `planned`, already stamped or
  pinned, no git, a parallel stream, a merge or rebase in progress, a taken branch or path; (6) *enter
  and exit* — `EnterWorktree` by path, `ExitWorktree keep` to come back; (7) *the merge* — local
  `git merge --no-ff` after `parallel-gate`, push → PR only on request; (8) *stays on `main`* —
  `parallel-skip <P>` or `new-phase --on-main`. `next` on the default stream prints
  `hint: <P> runs in its own worktree by default …` for a planned, unstamped phase, and `new-phase`
  prints one note saying where the phase will run.

- **A dirty default checkout no longer blocks `parallel-start`.** The stamp commit is made with
  `git add -- <paths>` + `git commit --only -- <paths>`, so it holds the phase folder (whole, if the
  phase was never committed — `create-phase` makes no commit) plus `works/state.json`, `index.json`,
  `backlog.md`, `deferred.md` and `events.jsonl`, whatever else is dirty or staged; the worktree is cut
  from that commit and the operator's edits stay behind, uncommitted. The one new refusal is a merge
  or rebase in progress, because a partial commit cannot be made mid-operation.

- **Integration merges locally by default.** `parallel-gate <P>` — which now reads the default stream
  from the local default branch when run inside the worktree, instead of refusing — then
  `ExitWorktree keep` → `git pull --ff-only` only if `main` tracks a remote → stop and ask if the index
  is not clean or the merge would touch an uncommitted file → `git merge --no-ff phase/P<N>-<slug> -m
  "merge(P<N>): <name>"` → `parallel-merge-finish` → the review's two gate sections → commit →
  `parallel-teardown <P>`. Push → PR → CI → `gh pr merge` stays documented as the **remote variant**,
  run only when the operator asks or repo policy requires; the CI `parallel-gate` job still guards
  `phase/*` PRs there.

- **Pinned phases stay on `main`.** `parallel-skip <P>` (a `planned` phase) and `new-phase --on-main`
  stamp `execution: {"mode": "default"}`: `validate` accepts it, the hints skip it, `parallel-start`
  refuses it, the backlog marks the row `· pinned: default stream`, and `parallel-status` prints
  `pinned_to_default=`. The `create-phase` docs-phase route pins its phase, since doc versions come
  from one shared index.

- **The branch review's gate sections are recorded, not lost.** A review running in a phase worktree
  still writes no doc versions; it now appends its stage-4 checklist lines and any `## Operator
  Runtime` change to `phase.md`'s `## Doc impact` tagged `(gate section — written at merge)`, and the
  post-merge step writes exactly those. Every other note waits for the operator's docs phase, which
  records `parallel-consolidated <P>` — v38's deferral holds one stream over.

- **Numbered cards.** The design handoff names every card path with a two-digit reading-order prefix
  (`01-nav.html`, `02-hero.html`, …) following the scope checklist; cards the session adds take the
  next numbers, a superseding card keeps its path, read-back verifies the sequence, and the numbers
  stay in the library because paths never move at the regroup. Ordering the review is organization,
  not design.

- **Mockups are on request, and the operator's return closes the round.** `## Design Style` in
  `intent.md` gains a `Mockup: requested` / `Mockup: on request` line (default `on request`, asked at
  `/create-phase` beside the style — or in the operator's own words during the round). Without a
  mockup the round has one `pending` stop: the operator's literal "done" on returning from Claude
  Design is the signoff, taken after the read-back's card-contract and concreteness checks, which on
  any failure re-stop `pending` with the points named and sign nothing — two commits, two
  `/do-next-slice` invocations. **PENDING #2 exists only when a mockup was requested**, and is then the
  gate on the running mockup, as before (four commits, three invocations). The phase gate follows the
  mockup with no judgment left: `--require` when one ships, the fixed note
  `design-only, no mockup: the operator signed the round on the card set` for a `design-only` phase
  that ships none. "Only PENDING #2 is an approval" and "mechanical wait" are retired.

- **Migration notes.** Nothing to run. Phases already `in_progress` on `main` finish there
  (`parallel-start` refuses a non-`planned` phase); every `planned` phase enters its worktree the first
  time it is executed — run `python3 scripts/workflow.py parallel-skip <P>` on any that must stay on
  `main` (docs phases always) and create such phases with `new-phase … --on-main`.
  `.git/info/exclude` gains `.claude/worktrees/` on your first `parallel-start`; `.gitignore` is
  untouched. The CI seed is unchanged; the old `Bash(git push:*)` deny matters only for the remote
  variant. Design rounds in flight finish under the shape they started with; add the `Mockup:` line to
  a live design phase's `intent.md` if you want one. Adopters with their own smoke pins on "Only
  PENDING #2 is an approval" or "mechanical wait" retire them.

## v41 — 2026-09-06

- **Why this release: the phase review re-verified the whole system on every phase.** Its gate stage
  4 said *"re-run every line of `## Regression Checklist` … not just this phase's lines"*, its stage 3
  walked the product with no phase boundary at all, and the fidelity slice carried the same whole-list
  rule. On an adopting product with a 154-line cumulative list, a review of an auth-only phase re-ran
  135 lines — paid model calls on a surface the phase never touched included — until the operator
  interrupted it; the executor then derived the right scope itself from the phase's own diff. v41 makes
  that the rule: **the review reviews the boundary of the phase, not the whole system.**

- **The boundary is what the phase changed, and it is a mechanical read.** New read-only command
  `phase-scope <P> [--base REF] [--head REF] [--json]` prints the phase's creation commit, its
  base..head range and the product files it changed (`works/` and `docs/` excluded). The base is the
  creation commit's parent (the merge-base with the default branch in parallel mode); the head is
  `HEAD`, or the commit that recorded a passing review on a done phase, so a finished phase's boundary
  never leaks later commits in. Archived phases resolve through the archive rename. Advisory
  everywhere: without git it prints one explanatory line and exits 0, an uncommitted phase lists the
  working tree, and `next` / `validate` are untouched.

- **Stage 4 re-runs inside the boundary; stage 3 walks inside it.** The review classifies every
  existing checklist line by its surface against `phase-scope`'s files — inside when a changed file
  feeds it (a shared file such as global styles, chrome, a shared library or a dependency manifest
  widens the boundary to everything it feeds; an unplaceable line is inside), outside otherwise —
  re-runs the inside lines, records the classification in `result.md` with the outside count and the
  diff as the proof, and appends its own lines as before. The fresh-eyes walk reaches the changed
  surfaces the way a first-time user would and goes no further. Anything noticed outside the boundary
  is an **observation**, listed as a deferred-job candidate for the orchestrator to file — never a
  finding, never re-verified. The same wording lands in both executor bodies, both `do-*` skills, the
  contract, and the fidelity paragraph of `design-cowork`.

- **The whole-list sweep is an operator-created QA phase.** `create-phase` gains a *QA-sweep route*
  beside the docs-phase route: "run the full regression sweep" becomes an ordinary phase whose `DECOMP`
  cuts `--kind qa` slices per checklist block; it changes no code, appends no lines, and normally
  waives its gate. The seed qa doc's `## Regression Checklist` intro says the same.

- **v40 never bumped the marker.** The v40 change (decomposition slices plan at the gate by default in
  `auto`) shipped without a `WORKSPACE_VERSION` bump or a changelog section; both are backfilled below
  and the marker moves 39 → 41 in one step.

- **Migration notes.** Nothing to run: `scripts/workflow.py` syncs the command and the skill/agent
  prose carries the rule. Two things are yours: the `## Regression Checklist` intro in **your own** qa
  doc still promises a whole-list re-run — rewrite it to the boundary wording (the seed body is the
  model) in your next docs phase — and any review `plan.md` template of your own that says "read it
  whole, re-run all of it" is retired. `python3 scripts/workflow.py phase-scope <P>` works on every
  phase you already have, active or archived, so you can see a past phase's boundary today.

## v40 — 2026-09-02

- **Decomposition slices plan at the gate by default in `auto`.** With no mode word, a
  `kind: decomposition` slice (`DECOMP`, `DECOMP2`, …) pauses for the operator to approve its plan and
  then continues in `auto`; only an explicit `auto` invocation plans decompositions inline too. The
  contract, `do-next-slice` and `do-whole-phase` state it. Shipped in commit `5004346` without a
  version bump — this section is the backfill.

- **Migration notes.** Nothing to run. Adopters who synced between 2026-09-02 and v41 already carry
  this behaviour under a v39 marker; the marker catches up at v41.

## v39 — 2026-09-02

- **Why this release: a doc nobody has consolidated yet still reads like the truth.** v38 moved
  durable-doc consolidation off the review and onto a docs phase the operator creates — deliberately
  operator-paced, with no cadence forcing it. That left one gap: `docs/current` can trail the code by
  however long the operator waits, and nothing on the page said so. v39 makes a doc's age readable and
  states the doctrine that goes with it — **a doc whose last update predates the owed `## Doc impact`
  notes is stale evidence to check against those notes, never current truth.** No cadence knob was
  added: explicit staleness is what was taken instead of one.

- **Every durable doc carries a last-updated marker.** `doc-new-version` now records the commit it was
  written at beside the date and the consolidating slice, in **both** `docs/index.json` and the version's
  frontmatter — and `rebuild-docs` copies that frontmatter verbatim, so the marker reaches
  `docs/current/<doc>.md` itself. The sha is best-effort provenance, never a gate: a checkout without git
  records `unknown` / `null` and still writes the version, and pre-v39 entries render `unknown (pre-v39)`
  rather than being backfilled — a backfilled sha would mean "the commit that last touched the file", a
  different fact wearing the same name. The staleness keys are the date and the source slice.

- **`docs` and `validate` name the stale docs.** `workflow.py docs` — where an agent picks the sections
  it is about to read — prints each doc's marker and flags every doc named by an unconsolidated
  `## Doc impact` note as **STALE**, with the note count and the phases owing it; `validate` carries the
  same shared `stale_docs=` line as a warning beside `consolidation_owed=` (which names phases and the
  paying command, not docs). Advisory everywhere, exit codes unchanged, silent when nothing owes. The
  contract's read-order item and both executor agents now say what a STALE doc is: evidence to check
  against the notes, not truth.

- **The phase-notebook budget is one generous byte cap, not a squeeze.** `PHASE_MD_BUDGET` was
  `(200 lines, 16 KB)`; it is now a single **400 KB** byte cap — roughly 100k tokens — and the line
  ceiling is gone. P21 measured both halves across every budget-era notebook: the byte half bound at
  **92 %** of the ceiling while the line half sat at **69 %**, so four P21 slices compressed unrelated
  notes purely to make room for their own. The cap is now a sanity check, not a working constraint:
  the notebook is still **edited, never appended to**, still curated for the next slice, but it should
  carry what that slice needs instead of shrinking to fit. Unchanged: it is a **warning, never an
  error** (`validate` still exits 0 over budget, and still skips `done` phases), and `finish-slice`
  still prints `phase.md: <lines> lines / <bytes> bytes (budget 409600 bytes)` — both numbers are
  reported, only bytes judge.

- **Tests are for core behavior only.** The contract's *keep test files small* rule now says what
  earns a test file: **very core behavior — the logic the product cannot afford to break** — and
  **never** style, cosmetic, or trivial surface, which is verified **live** instead (run the product,
  `validate`, a small smoke check, the real-browser sweep). Tests that do exist still stay very small,
  and still grow only when the operator asks or the risk warrants it. This closes the gap where "small
  but welcome" was read as licence to test whatever was easy to assert.

- **Migration notes.** Nothing to run at update time. Adopting repos pick up the relaxed budget the
  moment `scripts/workflow.py` syncs; a notebook written under the old squeeze stays valid and simply
  stops being over budget. If your repo restates "200 lines / 16 KB" in prose of its own, update it to
  the soft ~100k-token cap. The doc marker is equally passive: existing `docs/index.json` entries are
  left alone and read as `unknown (pre-v39)`, the first `doc-new-version` after the sync starts
  recording it, and any doc your phases already owe notes for is flagged STALE from the first `docs`
  run — that flag is the debt you already had, now visible, not a new one.

## v38 — 2026-09-01

- **Why this release: the phase review was rewriting whole documents that only ever grow.** Measured
  across four live adopting repos (P21.S1, ~1,140 slices): per-review durable-doc consolidation is
  **90–97 %** of a review's read budget. One adopter's `backend.md` is at **v0054 / 420 KB** and every
  review rewrote it whole, while its last sixteen versions averaged **2.7 % new lines**; one review of
  sixteen versions exceeded a 1 M-token window. So consolidation moves off the review's critical path.

- **Durable docs are now versioned in a docs phase the operator creates.** Every slice still appends a
  one-line `## Doc impact` note to `phase.md`. A passing review **verifies** that the list covers every
  durable-truth change (an incomplete list is a finding) and reports
  `doc_versions: none — deferred to a docs phase` instead of creating versions. Nothing new was
  invented: **parallel mode has run exactly this deferred path since v24** — `consolidation:
  pending|done`, the awaiting-consolidation listing, the completion command, the archiving guard — and
  v38 simply lifts it out of the `execution` block so it serves every phase.

- **The review keeps a narrow, named carve-out: two sections.** `## Regression Checklist` in the qa doc
  (the acceptance gate's stage-4 append) and `## Operator Runtime` in the operations doc are written by
  the review itself through `doc-new-version` on that doc, editing **only that section**. Deferring them
  would have let the product's cumulative smoke list silently lag by however many phases the operator
  batches, and they are cheap: ~13 k tokens worst case against the 74–734 k the deferral saves. **In
  parallel mode even the carve-out waits** for the post-merge step — doc versions come from one shared
  index.

- **The debt is real state, and it holds a phase out of archiving.** `phase.json` gains a top-level
  `consolidation` field (`pending` / `done`, absent = nothing owed), stamped by `review-phase --verdict
  pass` whenever the phase left `## Doc impact` notes. `archive-phase` / `archive-all` /
  `rotate-backlog` refuse an owing phase — archiving is precisely what would move those notes out of
  `active/` — and the new **`docs-consolidated <P>`** records the payment. `parallel-consolidated <P>`
  is unchanged as the parallel twin, and now writes both fields.

- **Backward compatible in both directions.** A `phase.json` with no `consolidation` field owes nothing
  and archives exactly as before, so every phase reviewed under v37 and earlier is unaffected; a
  `phase.json` carrying the v24–v37 `execution.consolidation` is still read (and still honoured by the
  archiving guard) with no migration.

- **The debt is visible, never silent.** Deferral traded review cost for operator-paced staleness, so
  the staleness had to stop being invisible: `next` prints one advisory `consolidation_owed=<phases>`
  line naming the phases and the paying command, and `validate` raises the same text as a **warning** —
  never an error, so an owing phase can neither fail CI nor block the loop. Both read the debt through
  one helper, so the v24–v37 `execution.consolidation` shape surfaces identically and a phase merged
  from a parallel branch is named with `parallel-consolidated`. Nothing is printed when nothing owes,
  and "how loud" has exactly one knob — `CONSOLIDATION_DEBT_MIN_PHASES` (default 1 = always) — for a
  stated docs-phase cadence to tune later, with no config plumbing.

- **The docs phase now has an entry point, not just a rule.** Every doc said *"a docs phase the operator
  creates"*; nothing said how to start one. The new read-only **`docs-debt`** prints the worklist — each
  owing phase with its `## Doc impact` notes, the docs those notes touch, and the command that pays it
  (`docs-consolidated`, or `parallel-consolidated` for a phase merged from a branch) — including the
  v24–v37 `execution.consolidation` shape, and it writes nothing. The `create-phase` skill gained a
  **docs-phase route** that reads that output as the proposed scope and goes through the *same*
  procedure: the step-3 confirmation gate does not move, and no new gate is added. The default cut is
  **one slice per doc** (`doc-new-version` is per doc, and one doc usually collects notes from several
  phases), ending in `docs-consolidated <P>` for each phase covered. A docs phase leaves no `## Doc
  impact` notes of its own, so it cannot feed itself.

- **A second-order leak the same root cause caused: sections that outgrew the read-order rule.** Docs
  only grow and sections are never split, so "read only the `docs/current/` sections the work touches"
  quietly stopped being a small read — across the four repos measured, **10 % of H2 sections exceed
  10 KB** and the worst is a single **112,619 B (~28 k token)** section. `validate` and
  `doc-new-version` now print one advisory `oversized_doc_sections=` line naming the doc, the heading
  and the size, biggest first, with the same text from one helper. **Advisory only — a warning at
  both sites, never an error, and never a sweep order:** splitting is per-doc judgment taken while a
  docs phase is already editing that doc (`doc-new-version` prints it beside `edit_path`, the only
  place a split can land), and the same measurement showed sectioning *hurts* small-doc repos, so a
  small doc with few sections is right as it is. One knob: `DOC_SECTION_WARN_BYTES` (10 KB).

- **Migration notes.** Nothing to run at update time, and no existing phase changes state. What changes
  is the habit: from your next passing review onward, `docs/current/*.md` trails the code until you
  create a **docs phase** — run `python3 scripts/workflow.py docs-debt` for the worklist, then
  `/create-phase` (objective "consolidate the `## Doc impact` notes from P<a>–P<b>"), which runs `doc-new-version --doc <doc> --summary "..." --source <P>.REVIEW` per note,
  `rebuild-docs`, then `docs-consolidated <P>` for each phase it covered. Until you do, those phases
  stay in `active/` and `rotate-backlog` leaves them there — that is the guard keeping their notes
  findable, not a bug. Batching every ~5 phases is where the win is (3.3x fewer doc versions in the
  repo measured). As always after an update, run `python3 scripts/workflow.py sync-agents`.

## v37 — 2026-09-01

- **Why this release: v36 named the instrument and got the surface wrong.** It prescribed the
  **MCP** transport for a reason that is true but not decisive — an MCP server's tools arrive as
  native tools in a dispatched executor's session, which a shell-out does not — and it never
  weighed the cost: that one `repl` tool definition is paid in **every** session, browser-related
  or not (~1,344 tokens, no lazy-load). And it said *use Aside* without ever saying **with which
  profile**, on a real desktop browser signed into the operator's accounts. Both were settled by
  running the CLI rather than citing it (Aside 1.26.810.1915, on this machine, 2026-09-01).
- **Two surfaces, not three.** v36's MCP / CLI / REPL split confused a *transport* difference with
  a *surface* one, and hid the distinction that actually matters: **who picks the next action.**
  There are two — the **`repl` surface**, one tool, identical over `aside mcp` and the `aside repl`
  CLI (the same Playwright-like `page`, `snapshot()`, locators, page JS and screenshots; different
  transport only), where the **executor** chooses each step; and **`aside exec`**, where **Aside's
  own model** drives from a natural-language instruction.
- **The default is `aside repl` over Bash** — `aside repl --account <id> "<js>"`, executor-driven,
  explicitly **not** the MCP transport. The measured per-session cost is the recorded reason, and
  the only thing the CLI loses (JS scope between invocations) is bought back by the two-line
  `listBrowserTabs()` → `attachBrowserTab()` re-attach preamble, written out in full in the
  `design-cowork` skill and verified live. Bash is already in both executor tiers' allowlists, so
  **nothing ships, nothing registers, nothing is configured**, and the default costs nothing until
  it is used. `claude mcp add -s local aside -- aside mcp` survives as a named optional
  per-operator, per-session **escape hatch** the workspace neither ships nor prescribes.
- **"Not scripted Playwright-style automation" → "not a pre-written assertion suite."** The old
  wording forbade the very thing v37 prescribes: the surface *is* Playwright. What the doctrine
  rejects is never the library but **deciding every check in advance** — an assertion suite can
  only test the selectors someone already thought of. Every carrier now says so.
- **A dedicated Aside profile is required for agent runs.** The probe that settled the surface also
  reached a browser holding the operator's Google session, 49 imported passwords and 6 passkeys —
  authority enough to read mail, spend from saved cards and authenticate as the operator, which
  makes this a requirement rather than hygiene advice. So: `--account <id>` on **every**
  invocation, never `aside account use` (it only moves the *default*, and the default is the
  operator's profile); the `## Operator Runtime` manifest records which account id is the agent's;
  and a manifest naming Aside with no agent account id — or a machine holding only the operator's
  personal profile — is a **third** `needs_operator` halt, distinct from the runtime one, resolved
  by neither borrowing the personal profile nor creating an account for the operator. The same
  holds whichever browser is driven: an agent never drives a profile signed into the operator's
  accounts.
- **The fallback and the axes are unchanged.** Aside is macOS-only and needs an account, so a
  workspace that cannot run it owes the same sweep, at the same viewports, in the same manifest
  runtime, through whatever real browser it has — **the doctrine's demands bind, the instrument
  does not.** Instrument and runtime remain different axes: the absent-or-`UNFILLED` →
  `needs_operator` rule is about the **runtime**, and a manifest naming no instrument is still not
  an unfilled one.
- **Surface facts, executed rather than cited.** Snapshot refs are session- and snapshot-scoped and
  go stale on navigation (`RefStaleError`); `getByRole` survives it. One v36 phrasing was wrong and
  is corrected: `title` + `code` is the **MCP tool's** schema, not a CLI flag — `aside repl` takes
  the code as a positional, so v36's wording would have shipped an invocation that fails. This
  closes deferred jobs **D9** (fallback) and **D11** (profile) and **D10's surface half**; D10's
  against-a-real-product half stays open, since no executor has yet run this prescription against
  a browsable product.
- **Migration notes:** run `python3 scripts/workflow.py sync-agents` after updating, as always —
  **both agent bodies changed**. There is **no engine change at all** in this release
  (`scripts/workflow.py` is untouched), so history, existing slices and `validate` are unaffected
  and nothing needs renaming. Because `--update` never touches `docs/`, the seeded manifest's two
  fields — the corrected *Browser instrument for the agent* line and the new **conditionally
  required** *Agent's Aside account id* line — reach **fresh installs only**; copy them from
  `installer/payloads/doc_bodies/operations.md` in the upstream clone into your own operations doc
  with `doc-new-version`. **And the sharp one:** if you followed v36 and actually ran
  `claude mcp add -s local aside -- aside mcp`, **remove that registration** — v37 stops
  prescribing it, and leaving it in place keeps paying the per-session cost this release exists to
  avoid. Installing Aside, and creating a second Aside account for the agent, remain operator
  actions this workspace never takes for you.

## v36 — 2026-08-29

- **Why this release: two ways a slice could be the wrong shape.** An agent told `research` was
  not a valid `--kind` announced it would cut its research slices as `--kind qa` instead — a slice
  that reads as one thing and is another, the exact failure v34 closed the enum to prevent. And the
  verification doctrine shipped in v32 says thoroughly **what** to check (the functional sweep) and
  **where** (the `## Operator Runtime` manifest, plus the production build when they differ), and
  never once said **with what** — so the scripted assertion suite everyone reaches for kept being
  the default by silence, which is the very shape of check that let eleven user-visible failures
  through thirty slices.
- **`research` is a real slice kind** — the eighth member of the closed `SLICE_KINDS` set, with
  four semantics stated everywhere routing is stated (contract, both agent bodies, both `do-*`
  skills, both `--kind`/`--risk` help strings): **findings-only**, so it writes no product code and
  a throwaway probe is deleted before it finishes; **always `slice-executor-high` by *kind***,
  joining `decomposition` and `review` — set `--risk high` anyway so the record cannot contradict
  the routing, and **the kind wins if the two ever disagree**; **its findings land in `phase.md`**,
  because the executor's context dies with the slice and a finding that stays in `result.md` prose
  is lost, which is the whole reason the kind is worth a dispatch; and a `DECOMP2` **usually**
  follows it. "My findings change nothing about the breakdown" is itself a real result.
- **`DECOMP2` now has two origins, neither a special case of the other:** a research slice, and the
  `build-after` design style — which is unchanged in every particular. It was written as a design
  device with a research exception bolted on nowhere; the contract states the two as peers, and
  `design-cowork` gained one cross-reference bullet ("the id is not design-only") rather than
  carrying machinery a design reader never uses. A genuine third pass is `P<N>.DECOMP3` — one more
  id, not a numbering scheme.
- **Aside is the prescribed instrument for real-browser verification, in place of scripted
  Playwright-style automation.** [Aside](https://aside.com) is a local-first Chromium browser agent;
  the workspace now names it wherever a real browser is needed — the functional sweep, fidelity
  slices, a design round's mockup, and the review's own walk of the running product. The **MCP**
  surface comes first (`aside mcp`, configured
  `{"mcpServers":{"aside":{"command":"aside","args":["mcp"]}}}`) because an MCP server's tools
  arrive as native tools in a dispatched executor's session, which a shell-out does not; the `aside`
  **CLI** is the one-shot Bash surface and `aside repl` the deterministic-inspection one. The
  argument is not restated in every file: the doctrine's demands — type into it and wait, watch a
  timer tick for a real interval, catch the browser defaults the record never drew — are agentic
  browsing, and an assertion suite can only test the selectors someone already thought of.
- **Instrument and runtime stay different axes.** Aside *drives* the runtime `## Operator Runtime`
  records; it never substitutes one of its own. The absent-or-`UNFILLED` → `needs_operator` →
  `pending` rule is untouched and is about the **runtime**: a manifest that names no instrument is
  not an unfilled manifest. The long-standing "never assume headless" line now carries its reason —
  a browsing agent drives a visible browser, and Aside's headless story is undocumented.
- **Prescription, surface, fallback — and no pretence.** Aside is a macOS desktop app and needs an
  Aside account, so a workspace that cannot install it (Linux, CI, or an operator who declines) is
  excused nothing: it owes the same sweep, at the same viewports, in the same manifest runtime,
  through whatever real browser it has — **the doctrine's demands bind, the instrument does not.**
  Every slice names in `result.md` which instrument it actually used, and claiming a browser run
  that was not made stays banned. Nothing here installs, bundles, or calls Aside, and no verified
  Aside run has been made from an executor in this repository: v36 ships the doctrine, not an
  integration.
- **Migration notes:** run `python3 scripts/workflow.py sync-agents` after updating, as always —
  both agent bodies changed. The engine change is purely additive (one member added to
  `SLICE_KINDS`), so existing slices, history and `validate` are unaffected; nothing needs
  renaming. Because `--update` never touches `docs/`, the seed's new one-line `## Operator Runtime`
  field — *Browser instrument for the agent* — reaches **fresh installs only**; add it to your own
  operations doc with `doc-new-version` (copy the line from
  `installer/payloads/doc_bodies/operations.md` in the upstream clone) if you want it recorded, and
  note that its absence alone never stops a slice. Installing Aside is an operator action this
  workspace never takes for you.

## v35 — 2026-08-29

- **Why this release: `phase.md` was state and log in one append-only file, re-read whole on
  every dispatch.** Nothing was ever pruned, so it grew roughly 70–90 lines per slice — P15
  reached 819 lines, with `## Findings & Notes` alone at 82 % of that — and both the orchestrator
  and every executor paid to re-read the whole thing on every turn: cost scaled about `40·N²`
  lines per phase. The damage was context-window pressure, not dollars. Prompt caching was
  examined and deliberately left unchanged — Claude Code already caches the prefix automatically,
  and a 1-hour subagent TTL is a net loss on the write/read arithmetic — so size, not churn, is the
  lever v35 pulls.
- **`phase.md` is now bounded state, edited under a 200-line / 16 KB budget, not appended to.**
  A fresh phase is seeded from `works/templates/phase.md` (with an embedded fallback) into fixed
  sections: `## Objective`; an engine-generated `## Slices` table between `<!-- slices:begin -->` /
  `<!-- slices:end -->` markers, regenerated by `rebuild` (so also by `next`, `new-slice`, and
  `finish-slice`) — the markers must sit alone on their line, their absence is a silent no-op, and
  the writer only rewrites on real change, since `phase.md` itself is not a generated file; `##
  Decisions` (a superseded line is replaced, never stacked); `## Doc impact` and `## Operator
  Questions` (append-only); `## Notes for later slices` (tagged by source/audience, consumed by
  the slice that reads them); and `## Now`, rewritten last as the handoff the next dispatch reads
  first. `## Context`, `## Findings & Notes`, `## Constraints`, and `## Open Questions` are left in
  the seed for phases that still want them.
- **`result.md` becomes the per-slice log, verdict block first,** so the orchestrator and the
  review can `head` a file for status instead of reading it whole. `finish-slice <id> --outcome
  "one line"` stores that line in `slice.json` and renders it in the generated `## Slices` table
  (omitted is a warning, never a failure, and the command still exits 0).
- **Two new guardrails, both warnings.** `validate` warns — never errors, and never on a `done`
  phase, since a closed notebook waiting to be archived cannot act on the advice anyway — when a
  notebook exceeds the 200-line / 16 KB budget, and when a `## Doc Impact` heading has drifted in
  case from the canonical `## Doc impact`; `finish-slice` prints the notebook's current size on
  every call. `works/backlog.md` and `works/deferred.md` also drop their `- Rebuilt at:` line, so
  repeated `next` calls now leave them byte-identical instead of dirtying git on every read.
- **Reads move from "read everything" to just-in-time.** An executor's read order is now `plan.md`
  → `phase.md` → `intent.md` (only when still unsure) → `phase.json` → the `docs/current/`
  **sections** the plan actually names — never the whole doc set, and never `docs/index.json`.
  Both drivers drop their per-slice dashboard re-reads and read each `result.md` head-first for
  its verdict block; the phase review cross-checks `phase.md` against every slice's `result.md`
  rather than trusting the notebook alone. `CLAUDE.md`'s own `## Read Order` is now three steps
  instead of a flat list of documents.
- **Migration notes:** run `python3 scripts/workflow.py sync-agents` after updating, as always.
  Existing `phase.md` files are left untouched by `--update` — no markers means the engine never
  writes them — so a phase already in flight keeps its old append-only shape until it is archived,
  or can be migrated by hand by adding the marker pair and the new sections. The budget warning
  skips any `done` phase, so a pre-v35 notebook never nags once its review has passed.
  `finish-slice` without `--outcome` still works exactly as before (a warning, not an error).
  `CLAUDE.md` grew by roughly 1 KB carrying this protocol; trimming the remaining duplication
  between *Driving This Workspace* and *Hard Rules* is deferred job D8, not part of this release.

## v34 — 2026-08-29

- **Why this release: a design round ended at a picture, and the phase's shape was a guess.** The only
  thing an operator ever approved was the **card set** — a static review surface in the Claude Design
  pane — and whether `build-prompt.md` was concrete enough to build from was a human judgment call
  that nothing tested. The skill admitted the gap in its own closing line: *signing the cards is not
  accepting the product*. Beside it, the design-then-build split was an implicit binary an agent
  picked off a soft "big design → two phases" hint, and `--kind` — the one field that keeps a design
  slice from being dispatched to an executor with no DesignSync — had been an unvalidated free-form
  string since the beginning, so `--kind cowork` silently produced an ordinary implementation slice.
  v34 makes the round's approval **running code**, names the shapes so the operator picks one, and
  closes the typo hole in the engine.
- **Three named styles, suggested by the agent and confirmed by the operator.** `build-after` is the
  existing two-pass shape (`DECOMP` → groundwork → design round(s) → `DECOMP2` → build slices cut from
  the landed design). `design-only` is a design phase plus a separate apply phase, and **must be
  chosen at `/create-phase`**: a `DECOMP` executor may not run `new-phase`, so a split decided later
  cannot be created from inside decomposition. **`paired` is new** — design 1 → apply 1 → design 2 →
  apply 2 inside one phase, with **no `DECOMP2`**; `DECOMP` cuts one apply slice per round as a **bare
  folder**, and each one's `plan.md` is written at its turn from the round that just landed. Cutting a
  bare folder is not pre-planning, and the ban on planning past the design gate is generalized rather
  than weakened — it now names everything downstream of a round instead of `DECOMP2` specifically. The
  confirmed style is recorded in the phase's `intent.md` under **`## Design Style`**, appended by
  `create-phase` only when the phase is visual (`works/templates/intent.md` is unchanged, so no
  non-visual phase grows the heading); every reader treats its absence as "ask it at `DECOMP`", which
  stops **`pending`** for the answer.
- **A runnable mockup, and exactly one approval per round.** After the read-back lands the record, a
  **dispatched** span — `slice-executor-high`, no DesignSync, working from `build-prompt.md` plus the
  landed record — builds the round as a **throwaway route in the project's own frontend**, and the
  operator opens and clicks it. **Only the second `pending` window is an approval:** the operator
  confirmed the design *inside* the Claude Design session and that session ending **is** the
  confirmation, so the first window is a mechanical wait and **SIGNOFF moves off the read-back onto
  the mockup gate**. A design slice now runs **inline → dispatched → inline**, so the old absolute
  "the design slice is never dispatched" narrows to the DesignSync work alone, and its commits go
  from two to **four** — `handoff`, `read-back`, `mockup`, `signoff`, one per span. Both drivers carry
  the consequences a `co-work` grep would not find: `plan only` stops before any plan that depends on
  a round that has not landed (`paired` has no `DECOMP2` to stop at), a design slice is resumed
  **twice** because it stops `pending` twice, its dispatched mockup span is a genuine — if short —
  idle window for `do-whole-phase`'s optional preparation, and the two `pending` stops are reported
  distinguishably, since the engine cannot tell them apart and nothing else can carry the difference.
- **The mockup is stubbed on purpose, and that bound is load-bearing.** It proves **look and states,
  not wiring**: stubbed data, no backing work, non-functional controls acceptable **and named as such
  in the gate walkthrough**. Without the bound the mockup span grows into the apply slice it exists to
  precede, and the design gate lands after the build instead of before it. So the mockup is **exempt
  from the full functional sweep** — that sweep stays an apply/fidelity duty on real wiring — and
  `review-phase`'s fresh-eyes stage now says so, because **a phase shipping a mockup takes
  `accept-gate --require`** (so a `design-only` phase can no longer be waived) and a gated review
  meeting a stubbed mockup would otherwise have filed every deliberately unwired control as a defect.
  What *is* checked: it runs, every designed element and state renders, it matches the record, and it
  is verified in the runtime and access path `## Operator Runtime` names. The concreteness check stops
  being a judgment call — the mockup either builds from `build-prompt.md` without inventing anything
  or it does not, and a record too thin to build without inventing is a third `needs_operator`
  condition. The route is throwaway: whichever slice later implements the surface for real deletes it,
  and the phase review checks that no orphaned design routes remain.
- **`--kind` is a closed set — this release's one piece of machine enforcement.** `SLICE_KINDS` is
  `implementation`, `review`, `decomposition`, `fix`, `docs`, `qa`, `co-work`. An unknown kind is a
  **hard error at creation** — at `new-slice` *and* at `promote-deferred`, through a
  `require_slice_kind()` helper called both from `create_slice` (the shared chokepoint) and from the
  top of `promote_deferred`, because `--create-phase` creates the phase several lines before the slice
  and a single guard left a half-created phase behind on a rejected kind. In `validate()` it is a
  **warning only, exit-code neutral**, so an adopting repo carrying an invented kind survives an
  update instead of having `validate` fail on history it cannot change. `--risk` next door stays
  deliberately **unvalidated** — an unrecognized value routes to the `high` tier, which is the safe
  direction — and both halves of the asymmetry are now commented at `SLICE_KINDS` so neither is
  "fixed" for symmetry later.
- **`create-phase` is agent-runnable on instruction.** It loses `disable-model-invocation: true` and
  becomes the second model-invocable skill — and a **narrower** exception than `design-cowork`, which
  fires by itself whenever work turns visual: `create-phase` is callable when an approved plan or a
  direct operator instruction calls for a phase, and **never on the agent's own initiative**. Its
  step-3 confirmation gate does not move; `new-phase` still runs only after the operator has
  explicitly confirmed each phase's name and objective. **Invocation is not the gate; confirmation
  is.** The smoke suite now pins an exempt set of exactly those two skills, in both directions, so the
  marker still cannot be dropped from any other skill by accident.
- **Migration notes:** preview with `--update --dry-run`. **(a)** Fresh installs and any workspace
  whose `CLAUDE.md` the installer owns need nothing — `--update` overwrites the contract, both
  executor agents, and every skill. A **retrofitted** repo keeps its own `CLAUDE.md` and receives the
  new contract text in the `CLAUDE.workspace.md` sidecar instead; if you maintain a customised
  contract, fold in the amended bullets by hand — the design-style/dispatch rules, the "not every
  `pending` is an approval" wording, the gate bullet's no-waiver clause, and the `new-slice` line's
  closed `--kind` set. **(b) Existing slices whose
  `kind` is outside the set** — `docs` and `qa` are in it, only invented kinds are not — now produce a
  `validate` **warning** naming the set, and the **exit code is unchanged**, so nothing that gated on
  `validate` starts failing. Edit that `slice.json` if you want the warning gone, or leave it: it is
  history. **(c) A design phase already in flight under the old shape needs nothing done to it.** Its
  round ended at the cards, SIGNOFF sits at the read-back, and there is no mockup route — the engine
  never enforced round shape and still does not, so the new loop applies to rounds started from here
  on, the same way v32 scoped its acceptance gate. For a round whose handoff has not gone out yet, run
  it under the new loop and declare the phase's gate with `accept-gate <P> --require`. **(d)**
  `--update` preserves all of `docs/`, so the `## Visual-design runbook` in your `operations.md` keeps
  its old two-shape, one-`pending`-window text until you re-version it yourself with
  `doc-new-version --doc operations` — never by hand-editing `docs/current/`. **(e)** Run
  `python3 scripts/workflow.py sync-agents` after the update, as always.

## v33 — 2026-08-29

- **`phase.md` and `result.md` now divide by audience, so nothing is written twice.** The contract
  asked every executor to write `result.md` and, separately, to append cross-slice notes to
  `phase.md`, but never said the two must not carry the same content — so diligent executors wrote
  both in full. A v32 slice put the operator-runtime field bullets and the `UNFILLED` marker
  verbatim into each, and its `result.md` even noted "already recorded in `phase.md` Findings". The
  duplicated part was always the forward-looking notes, and `phase.md` is the file every later
  dispatch re-reads, so that copy was paid for on every slice rather than once.
- **The boundary, stated once and enforced in both tiers.** `phase.md` is what the **next slice**
  needs; `result.md` is what **this slice** did — its validation commands and outcomes, its
  deviations from `plan.md`, and the durable form of the structured verdict, which is otherwise
  ephemeral and dies with the session. A note belonging in `phase.md` goes there and is referenced
  from `result.md` in a line, never restated in both. The `## Operator Questions` instruction
  changed from "not *only* into `result.md`" — which invited writing both — to "there, rather than
  into `result.md`".
- **No behavioural surface moved.** Both slice files keep their owners, lifecycles, and readers;
  the review still re-runs each slice's validation from its `plan.md` / `result.md`, and the
  acceptance-gate resume still reads `review_verdict: pass` out of the `REVIEW` slice's
  `result.md`. `slice-executor-mid` and `-high` received identical wording, so the pre-existing
  drift between the tiers did not widen.
- **Migration notes:** none for a fresh install or for a workspace whose `CLAUDE.md` the installer
  owns — `--update` overwrites the contract and both agent files. A **retrofitted** repo keeps its
  own `CLAUDE.md` and receives the new contract text in the `CLAUDE.workspace.md` sidecar instead;
  fold the one amended bullet (the "two context files" rule) into your `CLAUDE.md` by hand if you
  maintain a customised one. The rule applies to slices written from here on; existing `result.md`
  files under `works/` are history and are not rewritten.

## v32 — 2026-08-23

- **Why this release: every gate the machinery had sat between agents.** An adopting workspace ran
  two build phases — 30 slices, a scripted real-browser fidelity pass at the end of each, both
  reviews passed — and the product owner, meeting the running product only afterwards, filed 11
  user-visible failures, starting with a login link that never rendered because of a dev-only
  double-effect the production-build verification could not see. Every check had passed, because
  verification's only yardsticks were the signed design record and the executor's most convenient
  runtime. v32 puts the operator, and the operator's runtime, back in the loop.
- **The operator acceptance gate, machine-enforced.** `phase.json` gains an optional five-field
  `acceptance` block (`required` / `walkthrough` / `requested_at` / `cleared_at` / `note`) driven by
  one new command, `accept-gate <P>`: `--require` or `--waive --note "why"` at the `DECOMP`
  boundary — every phase declares explicitly, never by omission, whether it changes operator-visible
  surfaces — then `--open --walkthrough "..."` at the review (records the script, sets the phase
  `pending`), `--clear [--note "..."]` once the operator has walked the product, and a bare
  invocation that shows the gate. The engine enforces it rather than trusting anyone to remember:
  `review-phase --verdict pass` refuses while the gate is undeclared or uncleared and names the
  exact command, while `changes_requested` and `blocked` are never refused — an operator's failure
  report has to stay recordable — and `changes_requested` resets the gate for the re-review. `next`
  prints an open gate's walkthrough and its `--clear` command, and `validate` errors on a `done`
  phase whose required gate was never cleared. A phase carrying **no `acceptance` block at all** is
  legacy and passes exactly as before.
- **The operator runtime manifest.** The seeded operations doc gains an `## Operator Runtime`
  section — run command(s), dev-vs-production mode, the origin the operator actually browses,
  devices/viewports/browsers, the production build command when it differs. Any slice claiming
  "verified in a real browser" now verifies **in that runtime and access path**, and additionally in
  the production build when the two differ, because dev-only bug classes and access-path differences
  live in exactly the gap between it and whichever runtime is convenient. The section ships an
  explicit `- Status: UNFILLED — …` marker; absent and unfilled mean the same thing — the slice
  returns `needs_operator` and the orchestrator sets it `pending` rather than assuming.
- **"Works as a product" is a named verification dimension beside "matches the record."** The
  `design-cowork` skill, which specified fidelity to the signed record and nothing else, gains a
  `## Verifying — RESPECT THE DESIGN, and does it work` section: the record is the floor of what to
  check, never the ceiling, and matching it is not acceptance. Its mandatory sweep — every visible
  control does something observable, interaction states (focus/hover/keyboard, including browser
  defaults the record never drew), liveness over time (the timer ticks; a refresh does not destroy
  in-progress typing), and type-into-it-and-wait — makes each failure a defect even when the render
  is pixel-perfect, in both runtime modes. Beside it the review walks the product once with fresh
  eyes as a first-time user, reporting everything dead, confusing or annoying **explicitly not
  judged against the design record**, and opens the running product itself instead of passing on
  other slices' reports.
- **Questions get asked, not archived.** Operator-decision questions accumulate on a running
  `## Operator Questions` list in `phase.md` (now in the `new-phase` scaffold), mirroring the proven
  "Doc impact" list, and the review must **route** every entry — into the acceptance walkthrough as
  a decision for the operator, or into a deferred job — because an unrouted entry is a finding it
  may not pass with. Catalogued now means delivered: a design gap is never fixed silently or
  "improved", and signing the cards is not accepting the product.
- **A cumulative product smoke list.** The seeded qa doc's `## Regression Checklist` is now the
  product's append-only smoke list — headline behaviours only, shaped
  `- [ ] <surface>: <one observable behaviour> (P<N>)` — re-run **whole** in the operator runtime by
  every later phase before it appends its own lines, so a phase touching shared surfaces can no
  longer silently invalidate an earlier phase's pass. Terse on purpose: the small-test-files rule
  applies to verification too.
- **Executor prompts carry the gate duties, with one new return field.** Both `slice-executor` tiers
  read `acceptance.required` as the single switch for every new duty (`true` bites, `false` is
  waived, `null` is a finding, no block is legacy), name `## Operator Runtime` as an input for any
  real-browser claim, run the review's six gate stages in order, and append to
  `## Operator Questions` beside "Doc impact". `walkthrough` is the one new structured-return field;
  `accept-gate` and `defer-job` join the prohibited commands (the review *returns* the walkthrough
  and *lists* the jobs; the orchestrator opens the gate and files them). Doc consolidation does not
  move — it stays in the review's pass path, before the gate opens, and parallel mode still defers
  it to the post-merge step. The two tier bodies are now byte-identical below their frontmatter (mid
  gained the co-work refusal clause it lacked, plus the two-pass decomposition and no-commit
  wording), pinned by the smoke test.
- **Migration notes:** preview with `--update --dry-run`. `--update` preserves `works/` and `docs/`,
  which shapes both manual steps. **(a) Every phase you already have carries no `acceptance`
  block**, so it is legacy and passes as before; to gate a phase already in flight, run
  `accept-gate <P> --require` on a **live** phase only — never on a `done` one, since `validate`
  would then correctly report it as done with an uncleared gate. **(b) The `## Operator Runtime`
  section and the rewritten `## Regression Checklist` reach fresh installs only.** Add them to your
  own docs with `doc-new-version` (`--doc operations` / `--doc qa`, copying the seed text from
  `installer/payloads/doc_bodies/` in an upstream clone) and fill the manifest in — never by
  hand-editing `docs/current/*.md`. Until it exists, the first slice claiming real-browser
  verification stops `pending` and asks you for it, as intended. **(c)** Run
  `python3 scripts/workflow.py sync-agents` after the update, as always.

## v31 — 2026-08-14

- **Codex support is removed; the workspace ships Claude Code only.** The `.agents/` skill mirror (34
  files), the `.codex/` config and executor agents (3 files), and `AGENTS.md` are gone from the
  repository and from the installer payload, and the build no longer asserts that `CLAUDE.md` and
  `AGENTS.md` carry byte-equal bodies. `CLAUDE.md` is the single routing contract — its "Equivalent to
  `AGENTS.md`" header line went with the twin, so a fresh install, a retrofit sidecar, and an
  `--update` refresh all write a contract that opens `# CLAUDE.md` → `## Agent Contract`. The Claude
  Code surface itself is unchanged: the same 17 skills, the same `slice-executor-mid` / `-high` tiers,
  the same workflow commands. The built artifact drops from ~475 KB to ~324 KB.
- **The engine is single-harness.** Executor presets carry one model/effort pair per tier — `economy`
  is Sonnet@high / Opus@high, `flex` (which the shipped seed selects) is Sonnet@xhigh / Opus@xhigh —
  and `executors.toml` accepts `[claude.<tier>]` tables only. A leftover `[codex.*]` table is a
  dedicated hard error naming this release rather than a generic parse failure, so an adopter is told
  what to delete instead of what failed to parse. `sync-agents` now prints one line per tier
  (`mid   sonnet @ xhigh`) in place of the old `claude=… codex=…` pair.
- **Retrofit is less invasive than before.** The installer no longer reads, merges into, appends to,
  or rewrites a repo's own `AGENTS.md` on any path, and writes no `AGENTS.workspace.md` sidecar. An
  `AGENTS.md` your project maintains for other tools comes out of a retrofit and out of an `--update`
  byte-identical — pinned by a sha check in the lifecycle smoke test. `CLAUDE.md` alone gets the
  marked section and the `CLAUDE.workspace.md` sidecar.
- **`--update` flags the retired machinery instead of deleting it.** `.agents`, `.codex`, `AGENTS.md`,
  and the now-orphaned `AGENTS.workspace.md` each appear exactly once in the stale change-list line,
  and all four survive the update. Removal stays the operator's call, as it is for every previously
  retired path.
- **The contract keeps every rule that was not Codex-specific, and drops the one that was.** The
  visual-design rule collapses to the single Claude Design / DesignSync loop this side always had,
  with the harness-branch framing dropped rather than a rule. The one genuine carve-out went with
  Codex: the narrow exception that let the **Codex** orchestrator clear and resume a `pending`
  `co-work` slice inline — written for Codex because it was automatic-only, and never held by Claude
  Code — is gone. The `pending` gate is uniform again: a `pending` item resumes only after explicit
  operator input clears it back to `in_progress`, exactly as the `do-next-slice` and `do-whole-phase`
  skills have always said.
- **Docs and tests were corrected against the source, not just stripped.** Passages this release
  invalidated were rewritten from the code they describe: the retrofit guide's contract-merge promise
  (it had been quoting a marker block the installer already stopped writing) and its manual-fallback
  copy list (following it literally would have recreated three of the four paths `--update` now
  flags), plus `installer/README.md`'s list of build safety checks. The lifecycle smoke test asserts
  Codex's *absence* as regressions — no `.agents/` or `.codex/` installed, no `AGENTS.md` in a fresh
  workspace, a repo's own `AGENTS.md` sha-pinned across a retrofit — and covers the stale-flagging
  mechanism itself.
- **Migration notes:** preview with `--update --dry-run`. The update flags `.agents`, `.codex`,
  `AGENTS.md`, and `AGENTS.workspace.md` as stale machinery and never deletes them, so remove them by
  hand; an `AGENTS.md` your project maintains for other tools is yours to keep. Drop any `[codex.*]`
  table from `executors.toml` — `sync-agents` rejects it outright and `validate` reports the same
  thing as a warning — then run `python3 scripts/workflow.py sync-agents` to re-apply your preserved
  mode and per-tier overrides. Phases, docs, and the seed-once `executors.toml` are preserved as
  always, and no state migration is needed. `docs/retrofit-guide.md` § *Updating after adoption* walks
  the procedure step by step. **If you drive this workspace from Codex, do not update** — v30 is the
  last release with a Codex path.

## v30 — 2026-08-13

- **Codex now has a native visual-design cowork path.** The model-invocable `design-cowork` skill uses
  built-in ImageGen or one exact approved reference, copies the canonical reference into the
  repository, reads that exact file back, and records a machine-checkable manifest, implementation
  contract, validation evidence, and immutable approval provenance. No Figma or other plugin is
  required; an explicitly chosen existing-design integration remains optional input only.
- **The normal operator boundary is one visual signoff, not approval of generation or every plan.** A
  complete review-ready record is committed without `SIGNOFF.md`, then the slice pauses for literal
  approval or revision. Missing/failed generation or read-back capability, missing exact-reference
  data, and requested revisions are explicit exceptional halts rather than silent service switches or
  extra routine gates.
- **Codex runners own design slices inline.** Automatic `do-next-slice` and `do-whole-phase` start and
  plan `co-work` on the orchestrator thread, never dispatch it, and clear its pending state only when
  the current invocation literally answers the recorded need. Bare automatic invocation is never
  approval. After hash recheck and signoff, one-slice execution stops while whole-phase execution may
  continue inside its entry phase to `DECOMP2`.
- **Implementation remains separate and fidelity is browser-backed.** `DECOMP2` cuts backing work,
  faithful UI implementation, and bounded fidelity work after signoff. Plans carry the approved round
  and `RESPECT THE DESIGN`; later slices exercise declared routes, states, responsiveness, keyboard /
  focus behavior, and reduced motion in a real browser before claiming fidelity.
- **Claude Code's path is preserved.** Its `design-cowork` skill remains byte-identical and continues
  to use Claude Design cards plus main-thread-only DesignSync read-back/regroup. Shared contracts now
  branch explicitly by harness while retaining no implementation in the design slice, two-pass mixed
  phases, immutable untrusted design data, literal signoff, and faithful downstream build rules.
- **Fresh install, non-destructive retrofit, and update ship the same v30 payload.** The lifecycle
  smoke covers the 17+17 inventory, implicit-invocation metadata, exact Codex skill/runner/executor /
  contract payloads, fresh and retrofit delivery, and replacement of deliberately stale pre-v30
  Codex visual files without misclassifying the still-current package as retired.
- **Migration notes:** preview with `--update --dry-run`. Update refreshes workspace-managed skills,
  runners, executor definitions, metadata, and contract files while preserving phases, docs, and the
  seed-once `executors.toml`; retrofit remains non-destructive for pre-existing operator files. No
  plugin, Figma integration, or state migration is required. This release alone needs no
  `sync-agents` rerun unless update output reports executor drift from a preserved adopter override
  (the installer continues to print its routine `sync-agents` instruction).

## v29 — 2026-08-13

- **Codex now ships the complete workflow surface as a first-class orchestrator.** All 17 Claude
  Code skills have matching Codex packages with `agents/openai.yaml`. In particular,
  `do-next-slice` and the restored `do-whole-phase` are independent Codex bodies: bare, `auto`,
  and unattended requests execute automatically, while `gate`, `plan only`, and unknown modes
  are rejected before workflow, state, or repository mutation. Existing `ready` slices still
  dispatch from their approved `plan.md` for upgrade and cross-tool compatibility.
- **Both harnesses use project custom-agent tiers with explicit preset matrices.** `economy`, the
  no-mode fallback, maps Claude to Sonnet/Opus at `high` and Codex to GPT-5.6 Luna/Terra at
  `high`; `flex` maps Claude to Sonnet/Opus at `xhigh` and Codex to GPT-5.6 Terra/Sol at `high`.
  The shipped seed and this upstream repo select `mode = "flex"`; adopter-owned per-tier overrides
  remain supported through `executors.toml` + `sync-agents`. Routing stays `risk: low` → mid and
  everything else → high, with one `mid → high` escalation.
- **Attribution follows the model that actually did the work.** Codex commits and saved explainers
  no longer name a hard-coded default model; the orchestrator records the executing model's current
  display name. The Codex project config also uses the current per-session concurrency setting.
- **Fresh install, non-destructive retrofit, and update now carry the same parity release.** The
  installer independently inventories both 17-skill trees, requires metadata for every Codex
  package, emits the restored Codex whole-phase files in every lifecycle, and treats them as current
  managed machinery rather than stale. Fresh installs seed the tracked `flex` selection; retrofits
  still skip every pre-existing operator file; updates add missing pre-parity Codex files, refresh
  managed skill/agent machinery, and preserve phase state, docs, and an existing seed-once
  `executors.toml`.
- **Migration notes:** preview with `--update --dry-run`, especially if a hand-maintained path may
  collide with the newly managed `.agents/skills/do-whole-phase/` package. Updates preserve the
  existing `executors.toml` but reset generated Claude/Codex agent files to upstream machinery, so
  run `python3 scripts/workflow.py sync-agents` immediately after updating. Codex `gate` and
  `plan only` requests are now rejected without mutation; already-`ready` slices remain executable.

## v28 — 2026-08-11

- **The round's slice ID comes back to the group names, and a post-approval regroup takes it off.** v27
  banned stamping a round address into a group name because a design system's taxonomy is cumulative —
  but the operator was using the prefix for a real reason (finding this round's cards in the pane), and
  v27's replacement covered the *agent's* checkability, not the operator's. The ban was the wrong
  strength. Both needs are now served, in sequence rather than as a trade.
- **During the round, the group carries the address** — `⏳ P48.S1 · Components` — so the operator lands
  on the cards under review instead of digging for them.
- **At SIGNOFF, after the operator has approved, the orchestrator does a *pure regroup***: `list_files`
  → `get_file` → rewrite **the `group` value on line 1 and nothing else** → `finalize_plan` with exactly
  those paths → `write_files`. The card's path never moves; only the display label does. Idempotent, and
  a pane that does not re-index is reported at the gate and left alone — a stale group label is cosmetic
  and never blocks the apply slices.
- **Why this is safe rather than a loophole.** "Pure regroup" is a first-class concept in the shipped
  design tooling, not something invented here: `group` is a **display-only** label, the render hash
  **deliberately ignores** it (`a pure regroup must not read as a contract change`), and a regroup
  **must not orphan grades**. The skill already classified grouping as "organization, not a design
  decision", so re-filing a card is documentation — the job this skill assigns the agent — and it
  happens *after* approval, so it cannot influence the design.
- **One enforceable invariant carries the whole carve-out:** everything after line 1 is byte-identical,
  confirmed by diff before upload. Below line 1 is the design, and it stays untouchable. `Never` gains
  two entries: touching anything below line 1 during a regroup, and regrouping **before** approval —
  which would remove the operator's way of finding the cards mid-review.
- **The write list is now two cases, not one:** grounding the project in already-implemented components
  (v27), and the SIGNOFF regroup. Both go list/read → `finalize_plan` (the operator sees the exact path
  list in the permission prompt) → `write_files`. "Never write anything that is a new visual decision"
  is unchanged.
- **Migration notes:** behavioral only — no state migration, no `sync-agents` re-run, no engine change.
  If you kept prefixed group names from before v27, they are now the documented review-time state again;
  nothing to undo. **Not verified end to end:** the regroup's semantics are confirmed from the shipped
  tooling, but that a `write_files` regroup makes the pane re-index has not been observed on a live
  round — hence the explicit "report it and leave the names" fallback.

## v27 — 2026-08-11

- **`design-cowork` is realigned with the shipped Claude Design contract.** The skill's policy was never
  the problem — *the agent never makes a visual decision; Claude Design and the operator do* still holds,
  and so does the whole handoff → `pending` → read-back → land → implement-in-a-separate-slice shape,
  including the two-pass `DECOMP` / `DECOMP2` rule. What had drifted was the skill prescribing mechanics
  of a product this workspace does not own, some of it demonstrably wrong.
- **The `@dsCard` marker spec is corrected.** The skill said "Line 1 of every card file, **exactly**"
  and gave four attributes, asserting that "the `subtitle` is where a card says what it is for." The
  card emitter shipped in Claude Code writes
  `` `<!-- @dsCard group="${escapeHtml(group)}"${viewportAttr} -->` `` — a `group` plus an *optional*
  `viewport`, and nothing else. `name` and `subtitle` are fields of `register_assets`, the path the
  `DesignSync` tool description itself labels **legacy** and which `@dsCard` replaced. We were telling
  Claude Design to write attributes the Design System pane does not read. The skill now documents the
  real two-attribute marker and says a card is addressed by its **file path**.
- **The slice-ID group prefix and the `⏳` sort-first marker are dropped.** `group` is free-form, so
  `P48.S1 · Components` was legal — but a design system is cumulative and shared, and stamping a round
  ID into its taxonomy turns a component library into a work log. The `⏳` trick additionally depended on
  group-ordering behavior in the server-side pane that is specified nowhere. Groups now follow the design
  system's own taxonomy (`Foundations`, `Components`, `Type`, `Colors`, the app's surfaces), and the
  round is made checkable a way we control: **the handoff names the exact card paths the round must
  produce, and read-back verifies them with `list_files`.**
- **The blanket ban on `DesignSync` writes is narrowed to what it always meant.** The skill's own opening
  line assigns "documenting *what exists*" to the agent, then forbade the one write that is pure
  documentation. The rule is now "never author a **new visual decision**", and one write is sanctioned,
  operator-requested only: pushing previews of components that **already exist and are implemented** in
  the repo, when there is no Connect-GitHub connection — following the tool's own
  list/read → `finalize_plan` → `write_files` ordering, with `get_project` first to confirm
  `type: PROJECT_TYPE_DESIGN_SYSTEM`. Mirroring nothing remains the default.
- **"Never run `/design-sync`" is replaced with what is true.** `/design-sync` and `/design …` ship
  `disableModelInvocation: true`, so the model could never call them; the old rule was inert and steered
  the operator away from the sanctioned way to ground a project in an existing component library. The
  skill now says the operator runs them.
- **The required-output manifest asks for content, not filenames.** Anthropic ships a native handoff
  bundle for exactly this purpose, so a round must return the card set, a record of what was designed,
  and an implementation contract complete enough to build from — and if the session produces the native
  bundle, that **is** the record and the contract. `result.md` / `build-prompt.md` remain only the names
  we land under when the bundle brings none of its own.
- **Why this was needed:** every earlier design-cowork change (v12, v13, v14, v22) moved `CLAUDE.md`,
  `AGENTS.md`, and this changelog together. The commit that introduced the slice-ID prefix and the `⏳`
  marker (`6cadb40`) touched only the two `SKILL.md` copies and the rebuilt installer — no changelog, no
  contract, no doc version, and no check against the product. That is how the unverified spec got in.
- **Migration notes:** behavioral only — no state migration, no `sync-agents` re-run, and no engine
  change (`scripts/workflow.py` is untouched; `co-work` and `DECOMP2` were always free-form strings).
  The contract's "Visual design is Claude Design's job" rule is reworded in place, so `--update`
  refreshes `CLAUDE.md` / `AGENTS.md` and both `design-cowork` skill copies as usual. If your design
  project already carries groups named with slice-ID prefixes or `⏳` markers, nothing breaks — they are
  valid group names; new rounds simply stop adding them, and you can rename the old ones in the pane at
  your leisure. Driver skills, executors, and the phase/slice architecture are unchanged.

## v26 — 2026-08-10

- **`/explain` ships with every workspace again — this reverses v15 for the skill.** v15 retired the
  embedded `explain` skill because the feature had graduated into a standalone Claude Code plugin.
  That left a dangling pointer: the phase review, the contract, the seeded `operations.md`, and the
  installer's closing line all tell you to "run `/explain`", while the workspace shipped nothing that
  provides it — an adopter followed the instructions and found no command. `explain` is now a normal
  workspace skill in both `.claude/skills/` and `.agents/skills/`, so the pointer resolves.
- **It sets up its own knowledge base on first use, and asks first.** A plugin-free workspace has no
  `/knowledge:setup` either, so the old "STOP, go run the plugin's setup" branch is replaced by
  step 2a: the skill asks for **one** thing — an email — then installs the `knowledge` CLI and runs
  `knowledge init` to sign you up (or log you in), mint an org-level key, and write
  `~/.config/knowledge-kb/config.json` at mode 0600. Creating an account is an outward-facing action,
  so nothing runs until the operator agrees, and passwords are piped via `--password-stdin`, never
  through argv. The hosted service at `knowledge.hi2vi.com` is the encouraged path; self-hosting stays
  supported via `KB_API_BASE_URL` / `KB_API_TOKEN` but is not walked through.
- **Operator-invoked only.** The vendored copy carries `disable-model-invocation: true` (and
  `allow_implicit_invocation: false` on the Codex side), matching every other workflow command-skill —
  `design-cowork` remains the single model-invocable exception. The phase review still writes no
  explainer; it only reports `explain: not written — run /explain for this phase`.
- **The offline local-file fallback is gone.** The upstream skill's "API unreachable" path wrote
  markdown into a local KB checkout and committed it with `git -C <KB_ROOT>` — but v21 deleted the
  contract carve-out that authorized exactly that commit, and a hosted account has no `kb_root`, so
  the path was both unauthorized and unreachable. An unreachable API is now reported as a failed save.
  This does not touch self-hosting: a self-hosted server is reached over the same REST API.
- **Docs and permissions.** `.claude/settings.json` gains three read-only allow entries
  (`Bash(command -v:*)`, `Bash(knowledge config:*)`, `Bash(knowledge guide:*)`); the account-creating
  and software-installing commands are deliberately **not** pre-approved, so they still prompt. The
  seeded `operations.md`, `README.en.md`, `installer/README.md`, and the installer's closing line all
  describe the new first-run setup.
- **Migration notes:** v15 left any existing `.claude/skills/explain/` alone as operator-owned. It is
  now workspace machinery, so **`--update` overwrites it unconditionally** — if you hand-maintained
  that file, run `--update --dry-run` first and save your copy. `--into-existing` still **skips** any
  `explain` dir already present, so a retrofitted repo keeps its own. The new `settings.json` entries
  merge in additively. A separately installed `knowledge` plugin is unaffected — its command is
  `/knowledge:explain`, a different namespace from this workspace's `/explain`, and you do not need
  both. `/explain` needs a knowledge base and will offer to create one on first run. On Codex it needs
  `[sandbox_workspace_write] network_access = true`, which now gates the setup as well as the save.
  The `--with-explain` flag stays **retired** — `explain` is unconditional, so the flag remains an
  unknown option the installer rejects. No `sync-agents` re-run is needed.

## v25 — 2026-08-05

- **`auto` is now the default execution mode for `do-next-slice` and `do-whole-phase`.** Invoked with
  no mode word, both skills plan each slice inline, `Write` its `plan.md`, and dispatch the executor
  straight through — no per-plan approval pause. The safety halts are unchanged: `pending`,
  `needs_operator`, `blocked`, and a failed/empty `slice-executor-high` return still stop the loop,
  and an `escalate` (or a failed/empty `mid` return) still re-dispatches to `slice-executor-high`
  without stopping. The word `auto` (and "run unattended") remains accepted as an explicit synonym of
  the default.
- **`gate` is the new explicit opt-in for manual-approval mode** (`/do-whole-phase gate`,
  `/do-next-slice gate`): the previous default loop — plan at the operator's gate (`EnterPlanMode` /
  `ExitPlanMode` in Claude Code; inline presentation in Codex), operator approves the readied plan,
  persist it by copying the harness plan file (confirm-then-copy), then dispatch — is unchanged, just
  no longer the default. Plan persistence inverts with the flip: `Write` is now the default path
  (plan mode is never entered, so no harness plan file exists), and the copy rule applies in the
  gated modes.
- **`plan only` is unchanged and always gated** — it exists to produce operator-approved plans, so it
  runs the approval gate regardless of the new default; an accompanying `auto` word is ignored
  (previously phrased as "`plan only` never combines with `auto`").
- The contract (`CLAUDE.md`/`AGENTS.md`), both skills (the Claude copies and the Codex
  `do-next-slice` mirror), both READMEs, and the durable docs (`operations`, `decisions`) carry the
  flipped wording. The engine has no mode logic, so `scripts/workflow.py` is untouched.
- **Migration notes:** behavioral change — a bare `/do-whole-phase` or `/do-next-slice` now runs
  unattended to the end of the phase (or slice) with no plan-approval pauses. Invoke with `gate` to
  keep the old approve-each-plan behavior.

## v24 — 2026-08-03

- **The workspace now ships CI.** `.github/workflows/workspace-ci.yml` is one generic workflow that
  works unchanged upstream and in every adopting repo: a `validate` job runs
  `python3 scripts/workflow.py validate` on every push and pull request, and the two upstream-only
  checks (`python3 installer/build.py --check`, `bash tests/retrofit_smoke.sh`) are **shell-guarded on
  the presence of the files they need**, so a repo without `installer/`/`tests/` simply skips them.
  Policy: **seed-once** — created when absent, never overwritten (the `executors.toml` precedent), on
  fresh install, `--into-existing` and `--update` alike. It is your CI file; edit it freely.
- **A second CI job gates parallel phase merges.** On a pull request whose head branch is
  `phase/P<N>-<slug>` (the branch `parallel-start` cuts), the `parallel-gate` job derives `<P>` from
  the branch name and runs `parallel-gate <P> --branch-ref HEAD --main-ref origin/<base>`, checking
  the branch out at the PR head sha with full history. `GATE CLOSED` exits non-zero, so the check goes
  red; whether that blocks the merge is your branch-protection choice, and the agent-side flow treats
  a red check as stop-and-report.
- **`.gitattributes` now ships too, line-merged instead of overwritten.** The
  `works/events.jsonl merge=union` rule (append-only log, built-in git driver, no per-clone config) is
  appended when missing and existing content is never rewritten — on install, retrofit and update
  alike. Skipping a repo that already has a `.gitattributes` would have silently dropped the rule
  exactly where a phase-branch merge conflicts. The generated files (`works/state.json`,
  `works/index.json`, `works/backlog.md`, `works/deferred.md`, `docs/current/*.md`) still get **no**
  merge driver on purpose: regenerate, don't merge.
- **The shipped `.claude/settings.json` deny narrows from `Bash(git push:*)` to
  `Bash(git push --force:*)`.** Agent-driven parallel integration has the orchestrator push a phase
  branch and drive `gh`; a blanket deny blocked that outright, with no prompt. Pushes now go through
  the normal interactive permission prompt — nothing is pre-allowed, the operator still approves each
  one — while force-pushes stay denied.
- **No `gh` wrapper in the engine.** PR creation/merge stays skill-guided (`gh` run directly by the
  orchestrator): `gh` auth/output/error handling is agent territory, and `parallel-gate` is already
  the shared engine-side check that both CI and the agent run before merging. `scripts/workflow.py`
  stays offline-testable and unchanged by this release.
- **A new `parallel-phase` skill documents the whole lifecycle** (Claude Code `/parallel-phase` and
  Codex alike): when to suggest parallel mode (the engine's advisory `parallel-start` hints in
  `new-phase` / `next`), how to opt in, how work and `pending` behave stream-scoped in the worktree,
  the one difference at the branch review (a passing review defers doc consolidation), and the
  agent-run integration sequence — `parallel-gate <P>` → push → `gh pr create` → `gh pr checks
  --watch` → `gh pr merge --merge` → `parallel-merge-finish` → serialized `doc-new-version` on the
  default stream → `parallel-consolidated <P>` → `parallel-teardown <P>` → commit.
- **The contract and the existing skills gained the matching carve-outs.** `CLAUDE.md`/`AGENTS.md`:
  the commit convention now says opting a phase in **is** the operator's ask (the engine stamp commit,
  the phase branch, and the pushes that open/merge its PR are authorized inside that documented flow —
  each push still prompts; outside it nothing changes), the durable-doc and review rules carry the
  parallel deferral, archiving is blocked while `execution.consolidation` is `"pending"`, the
  `works/state.json` pointer is documented as stream-scoped, and the six `parallel-*` commands are
  listed. `create-phase` relays the opt-in hint at creation time (the only moment a phase is still
  `planned`), `do-next-slice` / `do-whole-phase` read the pointer as stream-scoped and run the
  integration after a parallel `pass`, `review-phase` skips consolidation on a parallel branch (it
  verifies the "Doc impact" list instead), `archive-phase` names the consolidation gate, and all four
  `slice-executor-*` agent files report `doc_versions: none — deferred to post-merge consolidation
  (parallel mode)` in that case.
- **Incidental:** `.githooks/pre-commit` now also matches `^\.github/` and `^\.gitattributes$` in its
  staged-path regex, since both files are embedded in the distributable and must not ship stale.

**Migration notes.** Existing adopters: the settings merge is **additive** — a deny entry can never be
removed downstream — so your `.claude/settings.json` keeps the old `Bash(git push:*)` line. If you
adopt agent-driven parallel integration, **remove `Bash(git push:*)` from `.claude/settings.json` by
hand** (keep `Bash(git push --force:*)`); otherwise leave it and push manually. `--update` adds the CI
workflow when you have none (it never touches an existing `.github/workflows/workspace-ci.yml`) and
appends the union line to your `.gitattributes`, creating the file if absent — review both in
`git status` before committing. If your CI is not GitHub Actions, delete the seeded file; the
equivalent check anywhere is `python3 scripts/workflow.py validate`.

## v23 — 2026-08-01

- **The `low` executor tier is retired — slice execution is two-tier now.** `slice-executor-low` and
  `slice-executor-mid` were byte-identical apart from `name`, `description`, and `effort`, so the third
  tier bought a posture sentence and one effort step. The split is now drawn on **what the slice does**
  rather than on a three-point difficulty scale: **`slice-executor-high`** takes decomposition, the phase
  review, and essentially all code writing — every cross-file change without exception — while
  **`slice-executor-mid`** takes a one-line (or few-line) code edit, or docs, and nothing more.
- **The risk vocabulary narrows to `low | high`, and `--risk` now defaults to `high`** (it was `medium`)
  on both `new-slice` and `promote-deferred`. Routing fails safe: only an exact `low` reaches `mid`, so
  an unset, legacy (`medium`), or misspelled risk lands on `high`. `--risk` is still not validated by the
  engine — deliberately, and it is what makes this migration free. A phase's `DECOMP` and `REVIEW` slices
  are now created with `risk: high`, matching the `kind` rule that already routed them to the top tier.
- **The surviving `mid` tier keeps its own models and efforts** — economy `sonnet` @ `high`, flex
  `sonnet` @ `xhigh`, Codex `gpt-5.5` @ `high`. It was not re-cut down to the retired low tier's cheaper
  values. `high` is untouched (`opus` @ `high` / `xhigh`, Codex `gpt-5.5` @ `xhigh`). `mid` also keeps
  judgment within the plan's intent — it is not the old literal plan-follower — but escalates the moment
  a slice turns out to be real code writing, spans more than one file, or breaks the plan's assumptions.
- **The escalation ladder collapses to one step:** `mid → high`, at most **1** escalation per slice (was
  `low → mid → high`, max 2). The section heading is the fixed `## Escalation: mid → high`.
  `slice-executor-high` is still the ceiling and never escalates.
- **`sync-agents` now manages four agent files, not six**, and rejects a retired `[claude.low]` /
  `[codex.low]` section by name with a line-numbered migration message instead of a generic parse error.
- **Incidental fix:** `.githooks/pre-commit` did not match `executors.toml` in its staged-path regex even
  though the build embeds that file verbatim, so an `executors.toml`-only edit could ship without a
  rebuild. Added.

**Migration notes.** `--update` never deletes, so it flags
`.claude/agents/slice-executor-low.md` and `.codex/agents/slice-executor-low.toml` as stale — remove both
by hand. If you customized `executors.toml`, drop any `[claude.low]` / `[codex.low]` block (`sync-agents`
now errors on them), then re-run `python3 scripts/workflow.py sync-agents`, since updates reset the agent
files to upstream defaults. Existing slices need no edits: `risk: medium` routes to `slice-executor-high`
and `risk: low` routes to `slice-executor-mid`. Note the cost posture moves **up** by default — work you
would previously have rated `medium` now runs on opus; rate a slice `low` only when it truly is a
one-line edit or docs.

## v22 — 2026-07-28

- **A phase that both designs and builds now decomposes in two passes.** The old `design-cowork` shape
  assumed a phase could be cut up front ("one phase: design slice → implement slice"), but the design is
  what decides *what gets built* — features appear and disappear at the gate — so an opening `DECOMP`
  that cuts the build slices is guessing. It no longer does: the first `DECOMP` creates only what is
  knowable before the gate — any groundwork slices, the design slice(s), and a **second decomposition
  slice `P<N>.DECOMP2`** ordered after the last of them — and records a **build inventory** in `phase.md`
  (the candidate feature/surface list, *what* to build, not how) instead of build slices. That inventory
  is what the handoff's scope checklist is written from.
- **`P<N>.DECOMP2` cuts the build slices after the design lands**, from the landed spec in `phase.md` and
  the round's `build-prompt.md`: **backing/backend work first, then the design implementation**, then any
  fidelity fix. An ordinary decomposition slice otherwise — orchestrator plans it, `slice-executor-high`
  executes it, bare folders only. It is **never pre-planned**: `plan only` now stops before it for the
  same reason it stops before `REVIEW`.
- **How many design slices a phase gets is decided at the first `DECOMP`.** A design with many items to
  cover splits into several rounds, one `co-work` slice each with its own handoff and `pending` gate —
  that count *is* knowable up front from the inventory, unlike the build slices.
- **A design-only phase is unchanged** — single pass, `DECOMP` → design slice(s) → `REVIEW`. So is the
  *apply* phase of a two-phase split: its own `DECOMP` already runs after the design landed.
- **`co-work` is now a kind the machinery actually knows.** `design-cowork` has always mandated
  `--kind co-work` and said the design slice is never dispatched (only the main thread has `DesignSync`),
  but no driver skill or executor knew the word: `do-next-slice`, `do-whole-phase`, and
  `slice-executor-high` all enumerated "decomposition, implementation, `fix`, review" and would have
  dispatched a design slice to an executor that has no `DesignSync`. All of them now carve `co-work` out
  explicitly, `slice-executor-high` returns `needs_operator` if it is ever handed one, and
  `do-whole-phase`'s idle-window list notes that a `co-work` slice has no idle window at all.
- **`/create-phase` now asks the design-split question.** Whether a big design gets its own phase plus a
  separate *apply* phase can only be decided there — the `DECOMP` executor is forbidden from running
  `new-phase`, so a split decided later cannot be created from inside decomposition.

**Migration notes:** no state or command changes — `--kind` and slice ids are free-form strings, so
`P<N>.DECOMP2` and `--kind co-work` need no `workflow.py` change and `validate` is unaffected. But an
**in-flight phase that mixes design and build and was decomposed under the old single-pass rule needs
re-shaping**: delete the not-yet-started build slices, and insert a `P<N>.DECOMP2` slice
(`--kind decomposition --risk high`) after the design slice at a fractional `--order`, to cut them from
the landed design instead. Phases already past their design gate, and design-only phases, need nothing.

## v21 — 2026-07-28

- **The phase review no longer writes the phase explainer — this reverses v16's auto-explain.**
  v16 made a passing review locate the knowledge plugin's explain skill and produce a phase
  explainer as part of the review. That is removed: explaining is now a **separate operation the
  operator runs** (`/explain`) whenever they want one. The review executor locates no skill, runs
  no KB probe, has no offline fallback, and does no research for it — it was an authoring-plus-
  research job bolted onto the review at its most context-loaded moment, and explaining is a
  different job from reviewing.
- **The review still reports a pointer, so explainers do not silently stop happening.** Its
  structured return and `result.md` carry one fixed line on every verdict:
  `explain: not written — run /explain for this phase`. No work, just the nudge.
- **The KB-repo commit carve-out is gone.** v16 gave the executor's "never commit" invariant one
  narrow exception — the explain skill's offline fallback committing with `git -C <KB_ROOT>` in the
  separate knowledge-base repo. It existed solely for the explainer, so it is deleted from both
  `slice-executor-high` files: the executor now runs **no** `git` write command in any git root, on
  any slice kind. `WebSearch` / `WebFetch` stay on `slice-executor-high` — a reviewer sometimes
  needs to check an external fact.
- **A non-passing review now stops and hands back, instead of skipping a step and carrying on.**
  The old wording ("on `changes_requested` / `blocked`, version nothing") read as *skip the docs and
  continue*. It now reads as a full stop: the moment the verdict is not `pass`, the review executor
  does no doc consolidation and no other pass-only work, and returns the verdict with its numbered
  findings and proposed fix slices (`<P>.F<n>`) to the orchestrator, which decides — fix slices, or
  an operator decision.
- **"Stop" is scoped to the pass-only work, not to the review itself.** The executor still completes
  validation and judgment across every slice *before* branching on the verdict — it never aborts at
  the first failing check — so the orchestrator receives the complete picture in one cycle rather
  than one finding per cycle. Review and doc consolidation stay in the **same** executor; only the
  branch changed.
- **Fresh installs say the same thing.** The bootstrap's closing knowledge line and the seeded
  `operations.md` doc body no longer claim a passing review auto-saves the explainer — both now
  describe `/explain` as the operator-run step. Your KB setup instructions are otherwise identical.
- Unchanged: the review is still `slice-executor-high`'s job in a fresh context that never edits
  source, docs are still versioned once per phase at a passing review, and `review-phase` verdict
  handling, the executor tiers, `auto`'s safety halts, the escalation ladder, `plan only` / `ready`,
  v19's copy-based plan capture, and v20's optional idle window are all untouched.

Migration notes: **nothing to delete and nothing to configure.** The review simply stops writing
explainers — run `/explain` yourself when you want one; your knowledge-base setup (`KB_API_BASE_URL`
/ `KB_API_TOKEN`, or the plugin) still works exactly as before and is only ever used on demand now.
Everything else lands automatically with `--update`: the rewritten `review-phase` checklist (both
copies), the review paragraphs in `do-next-slice` / `do-whole-phase`, the amended contract bullets in
`CLAUDE.md` / `AGENTS.md`, and both `slice-executor-high` files.

## v20 — 2026-07-28

- **The `do-whole-phase` prefetch becomes a permission instead of a procedure.** v19 told the
  orchestrator to dispatch a research agent immediately after every executor and listed five
  hard conditions for skipping it. That is now one optional practice: while executor N runs,
  the orchestrator is idle on the main thread and **may** use that window to prepare slice N+1
  — by dispatching the built-in read-only **`Explore`** agent, by reading inline itself, by
  thinking the slice through, or by simply waiting. No mechanism is required, nothing is
  mandatory, and the choice is the orchestrator's per slice. The goal is efficient,
  high-quality work, not a sequence to follow.
- **The agent is gone: `.claude/agents/slice-planner.md` is deleted.** Plain Claude Code
  behaviour replaces it, so the workspace no longer maintains a fourth managed agent surface —
  and the v19 anomaly of an agent outside `EXECUTOR_TIERS` (no `executors.toml` knob, no
  `sync-agents` coverage, a model pinned in-file and drifting from the tier presets) dissolves
  rather than needing a fix. `scripts/workflow.py` is unchanged; there was never a Codex
  counterpart, since `do-whole-phase` is Claude Code only.
- **The enforcement guarantee is honestly weaker, and the docs say so.** v19's read-only
  property came from the agent's `Read, Glob, Grep` allowlist — structural, not prose. With the
  agent gone, `Explore` has `Bash` and inline research is bounded only by the orchestrator's own
  discipline: read-only is now a rule to follow, not a tool allowlist that enforces itself.
- **What still binds, whatever the orchestrator chooses:** read-only (no repo writes, no
  `workflow.py` state commands, no commits, none of slice N+1's actual work); no second
  executor; never block (the executor's completion notification always wins, and anything not
  ready by then is dropped); discard on any verdict other than `done`; notes live in the session
  scratchpad, never in a slice folder; and **the operator's approval gate does not move**.
- **v19's five skip conditions are demoted to guidance**, not deleted — `DECOMP`, a `REVIEW` or
  already-`ready` next slice, anything `pending`, and blast-radius overlap are now stated as
  where preparing ahead usually does not pay off, alongside where it does. The useful half of the
  deleted agent's prompt (hand everything by path, ask sharp questions, expect a compact advisory
  brief with an explicit "not read / possibly stale" list — never a plan, never a file dump)
  survives as short guidance inside the skill.
- Unchanged: v19's copy-based plan capture, `auto`'s safety halts, the escalation ladder,
  `plan only` / `ready` semantics, the executor tiers, and both `do-next-slice` copies (which
  never prefetched).

Migration notes: **delete `.claude/agents/slice-planner.md` by hand after `--update`.** The
updater never deletes files; it now lists the agent as **stale** in the update summary, but
removing it is a manual step. Leaving it in place is harmless — nothing dispatches it any more —
but it is dead machinery that will drift. Everything else lands automatically: the rewritten
`do-whole-phase` rule and the amended contract bullets in `CLAUDE.md` / `AGENTS.md`. No workflow
behaviour changes for Codex.

## v19 — 2026-07-28

- **`do-whole-phase` now overlaps the next slice's research with the running executor.**
  Right after dispatching executor N in the background, the orchestrator dispatches a new
  read-only prefetch agent to research slice N+1 during the idle window; when N returns it
  plans N+1 by **reconciling** that brief with what N actually changed, instead of starting
  a research pass from scratch. `do-next-slice` is unchanged — it stops after one slice, so
  a tail prefetch would speculate on work the operator may never run.
- **New agent: `.claude/agents/slice-planner.md`** (`Read, Glob, Grep` only; `sonnet`, pinned
  in-file). The tool allowlist, not prose, is what makes the prefetch read-only: with no
  `Bash` it cannot run `workflow.py`, `git`, or any build; with no `Agent` it cannot dispatch
  a second executor; with no `Write`/`Edit` it cannot touch a slice folder. It returns a
  compact advisory brief — relevant files, patterns to reuse, constraints, open questions,
  and an explicit "not read / possibly stale" list — never a plan and never a file dump.
- **The guardrails ship with it.** The prefetch is **skipped** when the current slice is
  `DECOMP`, when the next is `REVIEW`, when the next is already `ready` (`[r]`), when the
  phase or any slice is `pending`, or when the next slice's files sit inside slice N's blast
  radius (the paths N's `plan.md` says it will touch). The brief is **discarded** on any
  verdict other than `done`, is **never blocked on** (the executor's return always wins), and
  lives in the session scratchpad — **never** in a slice folder, where a stale draft could be
  misread as an approved plan. **The operator's approval gate does not move:** plan N+1 is
  still approved after slice N's `result.md`, verdict, and `phase.md` notes are in hand.
  Prefetch applies in the default loop and in `auto`; `plan only` has no idle window to fill.
- The `slice-planner` model is **not** wired into `executors.toml` / `sync-agents` — it is not
  an executor tier, so it stays pinned in the agent file and is not covered by the tier presets.
- **Every plan-persistence site now copies the approved plan instead of retyping it.** After the
  operator approves a plan in Claude Code, the orchestrator `cp`s the harness plan file — the
  exact path the harness named for that planning session, confirmed to hold the just-approved
  slice's plan — into the slice's `plan.md`, immediately, before the next `EnterPlanMode`
  overwrites it. This is byte-exact and removes the one step where a paraphrase or a silent
  truncation could creep in. Slice-local additions (an `## Escalation` section, for example) are
  appended after the copy, never a rewrite of the copied body. `Write` remains the fallback
  wherever no plan file exists: Codex (no plan mode) and `auto` (plan mode never entered).
  Covers `do-next-slice` (its default and `plan only` branches, both copies) and `do-whole-phase`
  (default loop and `plan only`; `auto` keeps `Write`, since it never enters plan mode).
- **New settings allowlist entry: `Bash(cp:*)`** in `.claude/settings.json`, beside the existing
  `Bash(python3 scripts/workflow.py:*)`. It grants nothing beyond the already-allowed `Write` tool
  (file overwrite, no deletion) but avoids a permission prompt immediately after every approval
  gate.

Migration notes: after `--update`, adopting workspaces gain `.claude/agents/slice-planner.md`,
the amended `do-whole-phase` rules and contract bullet, the copy-based plan-persistence rule in
both `do-next-slice` copies and in `do-whole-phase`, and the `Bash(cp:*)` allow entry merged into
`.claude/settings.json`. No manual action is required, and no existing behavior changes beyond how
the approved plan is persisted: the approval gate, `auto`'s safety halts, the escalation ladder,
`plan only` / `ready`, and the executor tiers are all untouched. Codex is unaffected (no plan mode
there, so it keeps the `Write` fallback; there is no Codex `do-whole-phase`, so no `slice-planner`
counterpart ships).

## v18 — 2026-07-28

- **Both tier presets are re-cut, and `economy` is the new default.** The shipped
  `flex` / `economy` mappings adopt the tuning proven in a downstream workspace:
  `economy` — now the default, applied even when `executors.toml` is absent or has no
  `mode` key — runs low = sonnet@medium, mid = sonnet@high, high = opus@high;
  `flex` raises the same ladder to low = sonnet@high, mid = sonnet@xhigh,
  high = opus@xhigh. The Codex tiers are unchanged and still identical in both presets
  (gpt-5.5 @ medium/high/xhigh). Per-tier `[claude.<tier>]` / `[codex.<tier>]` tables
  still override the active preset field by field.
- **No shipped preset uses haiku any more.** The low tier is sonnet in both presets, so
  the empty-`effort` escape hatch (`effort = ""` omits the effort line) is now purely an
  override-only feature — it stays in the engine and in `executors.toml`'s comments.
- **What each mode is for:** `economy` is the everyday default — the previous default
  (`flex` at sonnet@xhigh / opus@xhigh / opus@xhigh) put Opus on every medium-risk slice,
  which is more than routine work needs. `flex` is the opt-in step up for a phase where
  depth matters more than cost; the escalation ladder still covers the tail either way.

Migration notes: after `--update`, re-run `python3 scripts/workflow.py sync-agents`
— workspaces without explicit tier overrides move to the new economy mapping. To keep
the deeper tiers, set `mode = "flex"` in `executors.toml` (and note that `flex` itself
moved: its mid tier is now sonnet@xhigh, not opus@xhigh — pin `[claude.mid] model = "opus"`
to keep the old behavior). Uncommented per-tier tables keep overriding as before. A
previously seeded `executors.toml` keeps its old comment block — documentation only;
delete it and re-run `--update` to reseed.

## v17 — 2026-07-22

- **Fresh workspaces now ship with knowledge-setup guidance by default.** The seed
  `operations.md` doc body gains a `## Knowledge (phase explainers)` section describing the
  default, plugin-free path: sign up at the knowledge service → mint an org-level API key →
  export `KB_API_BASE_URL` + `KB_API_TOKEN` in `~/.zshenv` (never a repo `.env` — neither Claude
  Code nor Codex auto-loads it, and a repo file risks committing the secret). With the env vars
  set, a passing phase review auto-saves the phase explainer via plain REST — Claude Code and
  Codex equally, no plugin install required. One key serves every repo; each document's project
  defaults to the repo's directory name.
- **Codex sandbox opt-in documented.** The seed section notes that Codex's `workspace-write`
  sandbox blocks outbound network by default (so the save skips) and how to opt in with
  `[sandbox_workspace_write] network_access = true` in `~/.codex/config.toml`, with its tradeoff
  (loosens all Codex workspace-write runs; Claude Code needs nothing). The Claude Code knowledge
  plugin remains the alternative/richer path.
- **Fresh-install stdout gains a knowledge line** pointing operators at the `~/.zshenv` exports
  and `docs/current/operations.md` for details.
- **Migration notes:** no action required. Doc seeds are fresh-install-only, so existing
  workspaces won't gain the `## Knowledge` section on `--update` — add the exports to `~/.zshenv`
  directly (works regardless of workspace version), and, for Codex reviews to post online, enable
  `[sandbox_workspace_write] network_access = true` in `~/.codex/config.toml`.

## v16 — 2026-07-22

- **A passing phase review now auto-produces a phase explainer.** Phase review used to be
  *validate + consolidate docs*; it is now *validate + consolidate docs + **explain***. On a passing
  review only (never on `changes_requested` / `blocked`, exactly like doc versions), the review
  executor locates the knowledge plugin's installed `explain` skill — first hit wins: project
  `.claude/skills/explain/SKILL.md` → user `~/.claude/skills/explain/SKILL.md` → plugin installs under
  `~/.claude/plugins` (`cache/` and `marketplaces/`) — and follows it in change mode with the phase as
  the change-ref, writing a self-contained interactive HTML phase explainer into the operator's KB.
- **Verdict-neutral, gracefully skipped.** The explainer is best-effort: if the skill is not installed,
  the KB is unconfigured, web research tools are unavailable, or the KB API is unreachable, the step
  degrades to a reported skip (`skipped (skill not installed)` / `skipped (KB unconfigured)` /
  `skipped-offline` / `failed (<reason>)`) and its outcome **never** changes the `review_verdict`. The
  review executor now returns a one-line `explain:` outcome alongside its verdict.
- **`WebSearch` / `WebFetch` added to the Claude high executor.** `.claude/agents/slice-executor-high.md`
  gains those two read-only research tools so the explain skill's cited "Best practices & next steps"
  section can run at review; `sync-agents` patches only `model:` / `effort:`, so the new `tools:` line
  survives sync and `sync-agents --check` stays green. Only the high tier gets them (reviews always run
  there); mid/low and the Codex executors are unchanged. The Codex high executor has no per-agent tools
  list (Codex governs tools via `sandbox_mode`), so its review degrades the research section to
  `skipped-offline` by design.
- **Scoped KB-repo commit carve-out.** The explain skill's API-unreachable offline fallback commits the
  explainer with `git -C <KB_ROOT>` in the **separate** knowledge-base repo. The executor's "never
  commit" invariant gains one narrow exception for exactly this: the review slice's auto-explain
  fallback may commit **only** in that KB repo — never in this workspace's repo, never any `git push`.
  Under a Codex `workspace-write` sandbox (which cannot write outside the workspace) the fallback is an
  automatic skip.
- **Migration notes:** no action required — the step self-skips wherever the knowledge plugin or a KB
  is absent, and the review verdict is unaffected. Adopters who want auto-explain at their own KB
  install the knowledge plugin (`/plugin marketplace add leetusik/knowledge`,
  `/plugin install knowledge@knowledge`) and run `/knowledge:setup` once. On `--update` the
  `slice-executor-high` agent payload changed (new review step, `explain` verdict field, and — Claude
  only — the `WebSearch` / `WebFetch` `tools:` line); no `sync-agents` re-run is required, since
  `sync-agents` only rewrites `model:` / `effort:` and the update ships the new agent-file bodies
  directly.

## v15 — 2026-07-21

- **Embedded `/explain` is retired — the feature ships as a Claude Code plugin now.** The bootstrap
  used to carry an optional `explain` skill (installed with `--with-explain`) that wrote
  novice-friendly educational explainers into a hard-coded personal knowledge base. That feature has
  graduated into a real, portable Claude Code plugin in the
  [knowledge repo](https://github.com/leetusik/knowledge), so it no longer needs to ride inside every
  workspace. The embedded skill copies (`.claude/skills/explain`, `.agents/skills/explain`), the
  `--with-explain` installer flag, and the `WITH_EXPLAIN` / `OPTIONAL_SKILLS` wiring are all gone —
  `--with-explain` is now an unknown option that the installer rejects.
- **Install the plugin instead.** Inside Claude Code:

      /plugin marketplace add leetusik/knowledge
      /plugin install knowledge@knowledge

  then run `/knowledge:setup` once to scaffold a knowledge base, and `/knowledge:explain <topic>` to
  use it. Note the namespace change: the embedded skill was bare `/explain`; the plugin's command is
  `/knowledge:explain`.
- **Migration notes:** existing installs are never auto-deleted. On `--update`, the Codex copy
  `.agents/skills/explain` is flagged stale ("remove manually?") while the Claude copy
  `.claude/skills/explain` is left untouched — it carries no workspace marker, so it is treated as an
  operator-owned skill. Remove both copies by hand and install the knowledge plugin instead. No
  `sync-agents` re-run is needed; this is a payload/installer change only.

## v14 — 2026-07-17

- **The design round returns a card set — the operator has to see the design to design it.** v13 was
  right that the agent must not mirror a canvas, but it retired the line-1 `@dsCard` contract *as part
  of the mirror*, reasoning that **Connect GitHub** makes mirroring unnecessary. That holds for
  **input** — and the manifest was never only input. It is also **the render index for the Design
  System pane**, and Connect GitHub does not populate that pane. So v13 dropped the card medium along
  with the mirror, and a round degraded from "design on the cards" to "describe in prose, get loose
  HTML back" — a complete `build-prompt.md` the operator could not see, review, or fix.
- **The card set is now a required output of the session, authored by Claude Design.** Cards were never
  the agent's to *author* — they are Claude Design's to *deliver*. The handoff's required-output
  manifest is now three things: **the card set**, **`result.md`**, and **`build-prompt.md`**. **Markdown
  alone is not a round.** Requiring a card is not drawing one: the agent says what must be reviewable
  (**one card per reviewable unit** — never one monolithic "design system" page — and the `group`s that
  become the pane's headings); Claude Design decides what it looks like. **The mirror ban is unchanged
  and unweakened.**
- **The line-1 `@dsCard` marker returns as a handoff requirement, not as mirror work.**
  `<!-- @dsCard group="…" name="…" subtitle="…" viewport="…" -->` on line 1, exactly; the app compiles
  it into `_ds_manifest.json` on its self-check. **No marker → no card → an empty pane.**
- **`tokens.css` is Claude Design's deliverable now.** Under v12 it was the agent's mirror and it
  drifted four versions behind; v13 deleted it. **The palette *is* the design**, so the design session
  authors it and the pane compiles the foundations from it — no mirror, no drift, and the foundations
  render.
- **Read-back verifies the pane, not the files.** `list_files` first: no `_ds_manifest.json`, an empty
  `cards[]`, or one monolith → **`needs_operator`** with the card contract restated. Explicitly **not**
  fixable by editing the artifacts, writing the cards yourself, or hand-compiling the manifest —
  `register_assets` and the write path stay closed. The definition of done is *"the cards appear in the
  pane."*
- **Migration notes:** a round already handed off under v13 comes back with no cards — it is not lost,
  just invisible. Re-hand-off for the card set against the existing `result.md`/`build-prompt.md`
  (a visibility pass: it decides nothing new, and supersedes any monolith so there is no second source
  of truth). Nothing on disk migrates; no `sync-agents` re-run; skill text only.

## v13 — 2026-07-17

- **`design-cowork` drops the seeded canvas — the agent writes a handoff, nothing else.** v12 had the
  agent mirror the real palette and every shipped surface into design-system cards, push them, and
  keep them honest forever. Claude Design reads the **real repo** itself (**Connect GitHub** by
  default, a local-dir connection also works), so the mirror was redundant work that could only drift
  out of sync. The agent's one output is now **`handoff.md`** — product context, scope checklist,
  locked vs. in-play, where to look, a strict required-output manifest (always a **`result.md`** and a
  **`build-prompt.md`**), and the open questions posed back. **`DesignSync` survives as read-back
  only**, and is how the design reaches the codebase.
- **Retired with the mechanism:** the seeded-canvas / `/design-sync`-bundle selector and the
  app-first-trap essay (`/design-sync` is now simply never this workflow), card authoring, the
  `tokens.css` mirror, the `_ds_manifest.json` regen, the line-1 `@dsCard` contract,
  `register_assets`, `create_project` ordering, the frozen-baseline mandate, and the standing
  "re-push or the next pass runs against a lie" obligation — **no mirror, no drift.** The skill goes
  from 176 to 128 lines.
- **Design and implementation are now separate slices, always.** A design slice `--kind co-work
  --risk high` ends at the landed design + SIGNOFF and **never writes implementation code**; a big
  design gets several design slices (one per round, each with its own handoff and `pending`) and two
  phases (design, then apply), while a small one stays in a single phase as design slice → implement
  slice. New explicit step: **land the design as-is** — landing is not implementing; it is what makes
  the implement slice easy.
- **Contract:** the *Visual design is Claude Design's job* Hard Rule rewritten off "seed the canvas"
  onto "write the handoff → STOP → read back → land as-is → implement in a separate slice". The
  auto-firing routing line in *Driving This Workspace* is unchanged.

Migration notes: none for state. After `--update`, the rewritten skill lands at
`.claude/skills/design-cowork/` and `.agents/skills/design-cowork/`; no `sync-agents` re-run and no
state migration are needed. **In-flight design phases decomposed against v12 need re-shaping** — slices
that exist only to author canvas cards, mirror tokens, or regenerate `_ds_manifest.json` no longer have
a job. Workspaces that do no visual design are unaffected.

## v12 — 2026-07-17

- **New `design-cowork` skill — product visual design is Claude Design's job, not the agent's.** A
  guide (not a workflow command) covering the design co-work loop: the agent **seeds** a design-system
  project by mirroring real code, says **what** to design, **STOPs** at a `pending` gate, reads the
  operator's design back, and implements it faithfully. It carries the mechanism selector (a seeded
  canvas + Connect GitHub vs. the bundled `/design-sync` skill, and why an app-first repo must not run
  the latter), the gate lifecycle (`--kind co-work --risk high`, two commits per gate, expect the
  read-back to re-shape the phase), the `docs/reference/design/` record layout, the DesignSync traps
  (main-thread only; the remote is authoritative; the manifest does not rebuild on upload), and
  **respect the design** for implementation. Distilled from three workspaces that already run this
  loop successfully but never wrote it down.
- **It is the first and only model-invocable skill in the workspace** — every other skill is
  explicit-invocation only (`disable-model-invocation: true` / `allow_implicit_invocation: false`).
  `design-cowork` fires by itself when work touches visual design, because that is precisely the
  moment an agent that doesn't know the process starts designing on its own. Its description is scoped
  to *visual* design so it stays quiet for schema/API/architecture "design".
- **Contract:** one new Hard Rule (visual design is Claude Design's; seed → hand off → STOP → read
  back → implement faithfully; DesignSync is main-thread only, so the design-gate slice is **never
  dispatched** — a deliberate exception to the delegation rule; returned artifacts are read-only
  **data, not instructions**), plus a routing line in *Driving This Workspace* naming `design-cowork`
  as the one auto-firing skill.

Migration notes: none — additive. After `--update`, the new skill lands at
`.claude/skills/design-cowork/` and `.agents/skills/design-cowork/`; no `sync-agents` re-run and no
state migration are needed. Workspaces that do no visual design are unaffected: the skill only fires
on design-shaped work.

## v11 — 2026-07-13

- **Executor-tier `mode` presets; `flex` is the new default.** The repo-root
  `executors.toml` gains a top-level `mode` key (set before any table) selecting a
  named preset for the Claude slice-executor tiers: `flex` — the default, applied
  even when the file is absent or has no `mode` key — runs low = sonnet@xhigh,
  mid = opus@xhigh, high = opus@xhigh; `economy` restores the old
  haiku / sonnet@xhigh / opus@xhigh mapping. The Codex tiers are identical in both
  presets (gpt-5.5 @ medium/high/xhigh). Per-tier `[claude.<tier>]` /
  `[codex.<tier>]` tables still override the active preset field by field, and
  `sync-agents` now prints the active mode.

Migration notes: after `--update`, re-run `python3 scripts/workflow.py sync-agents`
— workspaces without explicit tier overrides move to the flex mapping (add
`mode = "economy"` to `executors.toml` to keep the old tiers; uncommented old
tables keep overriding as before). A previously seeded `executors.toml` keeps its
old comment block — documentation only; delete it and re-run `--update` to reseed.

## v10 — 2026-07-04

- **`result.md` is free-form; the template is gone.** `new-slice` no longer
  scaffolds `result.md` from `works/templates/result.md` — the executor writes it
  from scratch at slice end, shaped to the slice, just as the orchestrator already
  writes `plan.md` with no template. A fresh slice folder now holds only
  `slice.json`. The old template's fixed sections were mostly vestigial (per-slice
  review status, roadmap updates) and nothing in the engine ever read them; what a
  result must cover (validation commands + outcomes, doc impact, deviations from
  plan) stays specified in the executor agents. The full-result vs. cross-slice-note
  split is unchanged: details in `result.md`, durable one-liners in `phase.md`.

Migration notes: after `--update`, remove the flagged `works/templates/result.md`
(`git rm works/templates/result.md`). Existing slices' already-written `result.md`
files are untouched.

## v9 — 2026-07-04

- **`executors.toml` ships seeded; the `.example` file is gone.** The installer now
  writes `executors.toml` itself — all defaults shown, commented out — instead of an
  `executors.toml.example` to copy. The file is **seed-once**: created when absent
  (fresh install, retrofit, or an update onto an older workspace) and never
  overwritten by `--update`, so operator edits survive updates. The values ship
  commented out so the engine's built-in defaults stay authoritative — a workspace
  that hasn't opted into an override keeps tracking upstream default changes.
  Deleting the file is also fine (absent = defaults).

Migration notes: after `--update`, remove the flagged `executors.toml.example`
(`git rm executors.toml.example`). A previously created `executors.toml` is
preserved as-is — the update only seeds the file where it is missing.

## v8 — 2026-07-04

- **Executor-tier config moved from `.env` to `executors.toml`.** `sync-agents` now
  reads a repo-root `executors.toml` (see the shipped `executors.toml.example`):
  `[claude.low|mid|high]` / `[codex.low|mid|high]` tables holding `model` / `effort`
  keys. Semantics are unchanged — values pass through verbatim (aliases, full model
  IDs, `inherit`), `effort = ""` omits the effort line, models may not be empty.
  Unlike `.env`, the file is not gitignored: it holds no secrets, committing it
  shares the tier config with the team, and it no longer mingles workspace tooling
  keys into an app-level `.env`. A leftover `.env` with `SLICE_EXECUTOR_*` keys is
  no longer read; `sync-agents` warns when it sees one.
- **`plan only` mode and the `ready` (`[r]`) slice status.** `/do-next-slice plan
  only` and `/do-whole-phase plan only` walk slices through the plan-approval gate
  without dispatching executors: each approved plan is written to the slice's
  `plan.md` and the slice is set `ready`. A later execution run dispatches a
  `ready` slice straight from its approved plan without re-entering plan mode.
  `do-whole-phase plan only` ships `DECOMP` first when needed and stops before
  `REVIEW` (never pre-planned); `plan only` never combines with `auto`; `validate`
  errors on a `ready` slice that has no `plan.md`.

Migration notes: move any `SLICE_EXECUTOR_*` / `CODEX_SLICE_EXECUTOR_*` values from
`.env` into `executors.toml` tables and re-run `sync-agents`; after `--update`,
remove the flagged retired example (`git rm .env.example`) and drop the `.env` line
v7 added to `.gitignore` if nothing else in the repo uses a `.env`.

## v7 — 2026-07-03

- **Three slice-executor tiers.** The two executor variants are replaced by
  `slice-executor-low` / `-mid` / `-high` for both tools, risk-routed by the
  orchestrator: `risk == low` → low (haiku by default, no effort line — a literal
  plan-follower: no judgment, no improvisation; it stops and escalates on any
  surprise), `risk == medium` → mid (sonnet @ xhigh), and everything else —
  decomposition, the phase review, high/unknown risk — → high (opus @ xhigh,
  unchanged behavior). Codex tiers run gpt-5.5 at medium / high / xhigh. The
  untiered `slice-executor.md` / `slice-executor.toml` are retired; phase reviews
  now record `--reviewer slice-executor-high`.
- **`.env`-configurable executor models and efforts.** New `sync-agents` workflow
  command applies a repo-root `.env` (see the shipped `.env.example`) to the six
  agent files. Values pass through verbatim (aliases, full model IDs, `inherit`);
  an empty `*_EFFORT` omits the effort line (needed for models that reject the
  effort parameter, e.g. haiku); `validate` warns while the agent files drift
  from `.env`/defaults.
- **Failure escalation.** Executors gain an `escalate` verdict with an
  `escalation` findings field. When a low/mid executor can't safely complete a
  slice, the orchestrator appends the findings to the slice's `plan.md` as an
  `## Escalation` section and re-dispatches one tier up (a failed/empty low/mid
  return is treated the same; at most 2 escalations per slice; the top tier never
  escalates — there, unresolvable means `blocked` or `needs_operator`).
  `needs_operator` / `blocked` semantics are unchanged, and in `auto` runs an
  escalation re-dispatches without a pause while the other safety halts still stop
  the loop.

Migration notes: after `--update`, remove the two retired files the updater flags
(`git rm .claude/agents/slice-executor.md .codex/agents/slice-executor.toml`) —
updates never delete files. If you tune tiers via `.env`, re-run
`python3 scripts/workflow.py sync-agents` after every update (updates reset the
agent files to upstream defaults), and add `.env` to your `.gitignore`.

## v6 — 2026-07-03

- **The workspace bootstraps with no phases.** The installer no longer seeds a
  placeholder `P1` ("Bootstrap Intake") — fresh installs and retrofits both start
  with an empty `works/phases/active/`, and `next` reports the empty-start state
  ("no active slice; create a phase or promote deferred work"). The first phase is
  created by the operator through the create-phase intake flow (`/create-phase` /
  `$create-phase` / `new-phase`), so intent is always captured and confirmed rather
  than pre-filled at install time.
- **`--phase-name` / `--phase-objective` removed.** With nothing to seed, the flags
  are gone from the installer; passing them now fails as unknown options.
- **`/retrofit` no longer synthesizes a first phase.** The skill installs, reconciles,
  and verifies — then points the operator at `/create-phase` for their first task.
  The `installer/payloads/p1_seed/` scaffolds are deleted.

Migration notes: already-installed workspaces are unaffected (`--update` never
touches your phases). Any script that passed `--phase-name` / `--phase-objective`
to the installer must drop those flags.

## v5 — 2026-07-03

- **Slice-executor dispatch pinned to a background task.** The `do-next-slice` /
  `do-whole-phase` orchestrator always launches the executor via the Agent tool as a
  background task (never `run_in_background: false`) and waits for its completion
  notification. (Shipped in machinery at `d1767f9`; versioned here — that commit
  skipped the release rule.)
- **Both slice-executors pinned to `model: opus`.** `.claude/agents/slice-executor.md`
  and `slice-executor-high.md` now carry `model: opus` instead of inheriting the
  session model. (Shipped in machinery at `1950902`; versioned here — that commit
  skipped the release rule.)
- **Upstream rebuild guard in the contract.** New Hard Rule, self-scoped to the
  upstream bootstrap repo (inert in adopting repos, which have no `installer/`):
  editing embedded machinery requires rebuilding and committing the distributable in
  the same commit; upstream, the tracked `.githooks/pre-commit` hook enforces the
  drift check. Prompted by a downstream report that `--update` at `d1767f9` emitted
  stale machinery (that commit edited machinery without rebuilding the artifact).

Migration notes: none.

## v4 — 2026-07-02

- **`/explain` saves through the KB document API.** The old steps 5–7 (manual file
  write, Recent bullet in `docs/index.md`, KB git commit) are replaced by one
  `POST http://localhost:8766/api/documents` — the API writes the convention file with
  frontmatter, inserts the Recent bullet, upserts the DB row, and makes the scoped
  commit in a single locked call.
- **The manual flow is now fallback-only.** It runs only when the API is unreachable
  (curl transport failure: connection refused / timeout). HTTP errors (409 duplicate,
  422 validation, 401 auth) are handled per the API contract and **never** trigger a
  file fallback.

Migration notes: the primary path needs the KB API compose service running
(`docker compose up -d` in `~/projects/personal/knowledge`); the skill still works via
the fallback when it is down. Applies to `--with-explain` installs; delivered by
`/update-workspace` force-refresh.

## v3 — 2026-07-02

- **A passing phase review now closes the `REVIEW` slice.** `review-phase` drives the
  phase's `REVIEW` slice from the verdict (`pass` → `done`, `changes_requested` →
  `changes_requested`, `blocked` → `blocked`), so a passing review no longer strands the
  review slice `in_progress` — previously `do-whole-phase` left it open, showing a `done`
  phase whose "Current Slice" still pointed at an unfinished `REVIEW` slice. Both
  `do-next-slice` and `do-whole-phase` now behave identically; no separate `finish-slice`
  for the review slice is needed.
- **`validate` catches the inconsistency.** It now flags a `done` phase that still has any
  unfinished slice, mirroring the archive guard, so a stranded slice is surfaced immediately
  instead of only at archive time.

Migration notes: if a pre-v3 phase was left `done` with an open `REVIEW` slice, run
`python3 scripts/workflow.py finish-slice <P>.REVIEW` once — the new `validate` guard will
name any such slice.

## v2 — 2026-07-02

- **`/explain` is now opt-in.** The `explain` skill is no longer installed by default. Pass
  `--with-explain` to include it on a fresh install or an `--into-existing` retrofit. The skill
  still ships inside the built artifact — it is only gated at install time.
- **Update preserves your choice.** `/update-workspace` keeps refreshing an already-installed
  `explain` (it is never dropped or flagged stale on update). A repo without it stays without it
  unless you re-run update with `--with-explain`.

Migration notes: none. Repos that installed `explain` under v1 keep it and keep receiving refreshes.

## v1 — 2026-07-02

First versioned release. Workspace versioning starts here.

- **Installer is now a build product.** The 3,025-line self-contained
  `bootstrap_agentic_workspace.sh` is dissolved into an `installer/` source tree
  (`build.py` + `wrapper.sh` + `main.py` + `payloads/`); `python3 installer/build.py`
  reassembles the single committed distributable deterministically. Source of truth
  for emitted machinery is now the live repo files — no more heredoc mirroring.
- **Drift check.** `python3 installer/build.py --check` (also `tests/retrofit_smoke.sh`
  Test 7) fails when the committed artifact no longer matches `installer/` source.
- **Model-flexible attribution.** The `slice-executor` agent defs use `model: inherit`
  (run the session's model) and commit-attribution wording is rule-based — "attribute
  each commit to the model that actually did the work" — with model names appearing
  only as examples. The Codex agent tomls keep an explicit `model = "gpt-5.5"` (Codex
  needs an explicit model).
- **Workspace versioning.** A `WORKSPACE_VERSION` integer is stamped as
  `workspace_version` into each target's `works/.workspace-version.json`, and this
  `CHANGELOG.md` records what each version brings. `/update-workspace` reports
  "you're on vN → upstream vM" and shows the changelog entries in between.

Migration notes: none.
