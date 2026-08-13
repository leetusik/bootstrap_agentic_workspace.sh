# Changelog

Workspace versions for the agentic-workspace cornerstone. One `## v<N>` section per
integer `WORKSPACE_VERSION`, newest first. `/update-workspace` reads this file from
the upstream clone to show adopting repos what a sync brings — so each entry states
what changed and, when a sync needs manual steps, a **Migration notes** line.

Everything before v1 is **pre-versioning**: those workspaces carry no
`workspace_version` in `works/.workspace-version.json`; consult `git log` for that
history.

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
