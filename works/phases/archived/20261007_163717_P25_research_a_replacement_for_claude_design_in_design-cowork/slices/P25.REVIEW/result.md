# Result — P25.REVIEW (review)

## Verdict

- **status:** done
- **tier:** high
- **summary:** Reviewed P25, a findings-only research phase. The deliverable answers every point of `intent.md`:
  - a ranked top 3 with C1–C5 trade-offs: 1. repo frames board, 2. Storybook + addon-mcp, 3. self-hosted Penpot;
  - the Claude Design recommendation: retire the `DesignSync` loop and keep an optional import of the native bundle;
  - both readings verified or honestly qualified;
  - C5 addressed per option;
  - `frontend-design` scoped;
  - governance untouched.

  Spot-checked evidence re-verified. The hard limits held, teardown holds, and Doc impact "none" is correct. **Verdict: `pass`**, after three small notebook repairs.
- **files_changed:**
  - `works/phases/active/P25/slices/P25.REVIEW/result.md` (new)
  - `works/phases/active/P25/phase.md`: `## Decisions` (+3 lines, 1 wording fix), `## Notes for later slices` (3 consumed), `## Now` (rewritten)
- **validation:**
  - `python3 scripts/workflow.py validate`: passed, exit 0. It printed the pre-existing `oversized_doc_sections=7` warning, which is outside the boundary and already tracked as D25. Run at the start and again after the `phase.md` edit.
  - `python3 scripts/workflow.py phase-scope P25`: `product_files=0`, range `a02ed0a..3c7df41`, 3 commits.
  - `python3 scripts/workflow.py next`: `current_slice=P25.REVIEW`, `next_slice=none`.
  - `git log a02ed0a..HEAD --stat`: only `works/…` and `docs/index.json` (in the DECOMP commit: the `last_rebuilt_at` timestamp). `git status --short`: only `works/`.
  - Teardown: `docker ps -a`, `docker volume ls`, `docker images` and `docker network ls` show nothing `p25s2`/penpot. Ports 8765, 6006, 9001, 1080, 4300 and 4400 are free, and `pgrep` finds no probe process.
  - Slice validations re-run: S1 and S2 (validate, `git status --short`, `docker ps -a`) and DECOMP (validate, `next`) all pass. DECOMP's `rebuild` was **not** re-run, because it only regenerates `works/` files and the orchestrator's `finish-slice` runs it anyway.
- **deviations:** none. The notebook repairs are the kind the plan allows ("findings that you repair inside the notebook (not source) are fine"). They are listed in §5.
- **doc_versions:** none — deferred to a docs phase. Nothing is owed: the Doc impact list is correctly "none", and the waived gate needs no gate sections.
- **review_verdict:** `pass`
- **walkthrough:** none (gate waived: `acceptance.required: false`)
- **explain:** not written — run /explain for this phase
- **Deferred jobs for the orchestrator to file:** two specs, in §8: (1) "Adopt the chosen Claude Design replacement in design-cowork", which carries both Operator Questions; (2) "Re-evaluate Doop as a design-cowork option".

**Notebook:** the review's routing decision and the three repairs are in `phase.md` `## Decisions`, and the close-out is in `## Now`. This file is the review log.

---

## 1. Boundary

`phase-scope P25` gives `product_files=0`. The phase changed nothing outside `works/`, so the review covers exactly the three slices' claims and the notebook. The `## Regression Checklist` has no line inside a zero-file boundary, so none was re-run (the gate is waived anyway, so the gate stages do not apply).

## 2. Slice validation re-run

| Slice | Its validation (verdict block) | Re-run here |
|---|---|---|
| P25.DECOMP | `rebuild`, `validate`, `next`, S1/S2 bare folders, `## Slices` lists 4 | `validate` exit 0; `next` fine; the table lists DECOMP/S1/S2/REVIEW. The S1/S2 folders now hold `plan.md` + `result.md`, as expected after they ran. |
| P25.S1 | `validate`, `git status --short` (works/ only) | pass / pass |
| P25.S2 | `validate`, `git status --short`, `docker ps -a` (no p25s2) | pass / pass / pass (details in §6) |

## 3. Objective and intent coverage

| `intent.md` asks for | Where it is answered | Holds? |
|---|---|---|
| A ranked top 3 (roughly) | S2 §1; `## Decisions` "Ranked top 3" | yes |
| Trade-offs per criterion C1–C5 | S2 §2: C1–C5 plus R2–R8, setup, maintenance and MCP cost, for all 4 candidates and the baseline | yes |
| A recommendation on Claude Design as an optional path | S2 §6: retire the pull loop and keep a native-bundle import; the rejected opt-in is argued (4 reasons) and the unverified items are named | yes |
| Both orchestrator readings verified and stated, not assumed | S1 §2 (a) and §3 (b) | yes. (a) is honestly "strongly indicated, corrected", backed by a binary read, the ocx source and an `auth status` probe in an ocx-shaped env; the live `/design-login` is named unverified. (b) is verified from docs and the binary. |
| C5 persistent memory, per option | S2 §2 row C5, plus the "Design memory" row in each §4 mapping | yes: repo, repo, instance DB + per-round export, Doop DB with no tokens |
| `frontend-design` only where needed | S2 §5: drafter only, on HTML-authored options, on new-direction rounds; never when extending an established system; barely relevant to Penpot | yes |
| Fixed governance untouched in each loop mapping | S2 §4 preamble plus the three mappings: styles, rounds, literal signoff, the mockup gate and RESPECT THE DESIGN are unchanged. The one change is the drafter, which the confirmed framing asked for ("agent drafts, you decide"). | yes (see the note below) |
| Each option runs in both `claude` and `ocx claude` | S2 §2 row C1 | yes, but the evidence is partly reasoned (§4 below, repair 2) |
| No machinery changes | `phase-scope`, `git log --stat` | yes |

**Note for adoption, not a finding.** S2 §7.2 proposes rewording the CLAUDE.md hard rule "never invent visual decisions in an executor" to "a drafter drafts; nothing is decided until the operator's literal signoff". The confirmed intent authorizes that ("the agent may draft variants/mockups; nothing is decided until the operator's literal signoff"). Because it rewrites a hard rule, the adoption phase should confirm the wording with the operator. It is folded into deferred-job spec 1.

## 4. Evidence discipline: spot-checks

Every headline claim in S2 §1–§6 names its evidence: a probe command and output in §3, a doc URL, or "unverified"/"?" with reasoning. §3.5 and §8 list what was reasoned or not done. I re-verified these claims read-only:

| Claim | Source re-checked | Result |
|---|---|---|
| A background subagent keeps every MCP tool but only a fixed built-in list (the basis of C3 and the `DesignSync` main-thread cause) | WebFetch `code.claude.com/docs/en/sub-agents` | **verbatim match** |
| "define it inline here rather than in `.mcp.json`. The subagent gets the tools; the parent conversation doesn't." (the MCP cost lever) | same page | **verbatim match**; "String references share the parent session's connection" also matches (Doop C3) |
| Storybook MCP: the docs toolset needs a components manifest (React frameworks, `angular-vite`, `vue3-vite`); `stories-preview` renders inline only with MCP Apps, otherwise returns links | WebFetch `storybook.js.org/docs/ai/mcp/overview` | **match**. The docs list `review-create` as a 5th dev tool, and S2 correctly says it needs the review feature (4 tools measured). |
| Storybook telemetry: `disableTelemetry` does not stop the `boot` event; only `STORYBOOK_DISABLE_TELEMETRY` does | WebFetch `storybook.js.org/docs/configure/telemetry` | **match** |
| Penpot remote MCP has no `import_image`; the plugin runs in a browser tab | WebFetch `help.penpot.app/mcp/` | **match**. The docs do not label the MCP "beta"; S2 cites the "Beta" label from the UI it saw, which does not conflict. |
| Doop: created 2026-08-22, 777★, 95 forks, AGPL-3.0, `kgoedecke` 139 commits | `gh api repos/kgoedecke/doop` (+ contributors), read-only public metadata | **match** |
| `DesignSync`'s own description ("Use this only with the /design-sync skill, which the user starts"), the `/design-login` provider-token text, flag `tengu_omelette_fouet` | Python byte search of `~/.local/share/claude/versions/2.1.284` | **all three strings present**, near S1's cited offsets |
| Executors' `tools:` lack `Skill`; design-cowork bans `frontend-design` | `.claude/agents/slice-executor-*.md` line 4; `.claude/skills/design-cowork/SKILL.md:602` | **match** |
| `frontend-design`'s description | the local plugin `SKILL.md` | **verbatim match** |
| The changple5 containers were recreated by the operator's project, not by S2 | `docker inspect`: created 11:20:38–39Z = 20:20:38 KST | **match** with S2 §8 (images rebuilt at 20:20:36) |

**One labelling imprecision, repaired in the notebook.** S2's §2 table marks C1 as "✓v" (verified in this slice's probe) for the board, Storybook and Penpot. What was probed is provider independence: files + Bash, and HTTP MCP from a stand-in client. No `ocx claude` session was launched, and no background subagent was run against any server. S2 discloses both in §3.5 and §8, and each C1 cell states what was actually verified, so the evidence is named, not hidden. It is therefore not a finding. The inference is sound, because the ocx proxy carries only model traffic (S1 §4). Still, the notebook's "passes all five" read stronger than the evidence, so I added an evidence-basis line to `## Decisions`: adoption verifies the chosen option in an `ocx claude` session from a background subagent first.

## 5. Consistency: notebook vs logs

I compared `## Decisions` line by line with S1 §2–§5 and S2 §1–§7. Rank order, drop reasons (Doop: age, 86% one author, DB memory without tokens, OAuth-only MCP, no image, binds all interfaces), the screened-out list, the Claude Design recommendation, the unverified items, the MCP cost lever and the `frontend-design` placement all agree. The `## Slices` outcomes agree too.

**Repairs made in `phase.md` (notebook only, no source):**
1. **A dropped decision, restored.** The orchestrator's **local-account ruling** (in `P25.S2/plan.md`: throwaway local users on a scratch self-hosted instance allowed, under conditions) relaxed DECOMP's "no account creation" hard limit. S2's `result.md` relies on it (§3.3 "per the orchestrator's ruling"). The S1 note and `## Now` line that asked for it were consumed when S2 ran, and the ruling itself never reached `## Decisions`. It is added there now.
2. **The C1/C3 evidence-basis line** (§4 above).
3. **Penpot wording.** `## Decisions` said "the plugin API modifies only the active page". S2 §3.3 shows that content edits on a non-active page fail (`Cannot modify a page that is not currently active`), but a page *rename* of a non-active page worked (R7 probe). The line now says "edits only the active page's content (a page rename worked on a non-active page)".

No `## Operator Questions` entry was dropped; both S2 questions are present. The notebook's `## Doc impact` and `## Operator Questions` were not edited, since they are append-only and nothing needed adding.

## 6. Hard limits

- **Commits:** `git log a02ed0a..HEAD --stat` shows three commits (d360a3d, fb726f1, 3c7df41). They touch only `works/phases/active/P25/…`, the generated `works/` files and `docs/index.json` (DECOMP's rebuild timestamp). There are no machinery edits: nothing in `scripts/`, `.claude/`, `works/templates/`, `CLAUDE.md` or `installer/`.
- **Working tree:** only `works/` changes are uncommitted: the orchestrator's `start-slice` output plus this review's files.
- **Teardown:**
  - no `p25s2`/penpot container, volume, network or image;
  - no Penpot, `postgres:15`, valkey or mailcatcher image;
  - probe ports 8765, 6006, 9001, 1080, 4300 and 4400 free;
  - no probe process.
- **Left outside the repo, disclosed by S2 §8 and acceptable:**
  - the npm/npx cache entries for `storybook@10.6.0` in `~/.npm`;
  - the scratch artifacts in the session scratchpad.
- **Accounts:** no vendor, SaaS or operator account was used. The only local user was the throwaway Penpot user, under the ruling above. My own `gh api` calls were read-only reads of public metadata.

## 7. Doc impact

The list reads `- (none — P25 is findings-only; adoption is a later operator-created phase) (P25.DECOMP)`, which is **correct**: the phase changed no durable truth. I checked `docs/current/operations.md`, and its visual-design runbook says nothing the research falsified: it already states "`DesignSync` is main-thread only", which S1 confirmed and explained. The runbook does not mention that a stock `ocx claude` session loses `DesignSync` (`needs_design_login`). That is a pre-existing fact the research uncovered, not a change the phase made. It is folded into deferred-job spec 1 as an input, not written as a Doc impact line.

`doc_versions: none — deferred to a docs phase`. The gate is waived, so no gate sections were written.

## 8. Operator Questions routing and deferred-job specs

The gate is waived, so there is no walkthrough. Both `## Operator Questions` entries are routed twice:
- **To the operator with the report.** The orchestrator puts both questions to them alongside `slices/P25.S2/result.md` §1:
  - **Stack (P25.S2):** are your design-bearing products mostly JS/React with a real component library, or mixed/non-JS? That decides whether #1 and #2 swap.
  - **Canvas (P25.S2):** do you want on-canvas editing and pinned comments enough to run self-hosted Penpot, with its images, RAM, agent-tab sidecar, separate users and DB memory? That decides Penpot's rank.
- **As inputs of deferred-job spec 1** below, so the questions survive until the operator picks an option.

**Spec 1: for the orchestrator to file with `defer-job`**
- **title:** Adopt the chosen Claude Design replacement in design-cowork
- **reason:** P25 ranked 1. repo-native frames board, 2. Storybook + addon-mcp, 3. self-hosted Penpot + MCP. It recommended retiring the `DesignSync` read-back + regroup loop and keeping Claude Design only as an optional import of its native handoff bundle. Adoption was out of P25's scope because P25 made no machinery changes.
- **inputs:**
  - The two P25 Operator Questions (stack → #1 vs #2; canvas → Penpot's rank), which pick the option.
  - `P25/slices/P25.S2/result.md` §7 adoption notes:
    - the design-cowork SKILL.md sections and frontmatter;
    - the CLAUDE.md co-work rules, including the "never invent visual decisions in an executor" hard-rule rewording, which the operator should confirm;
    - a drafter executor with `Skill` and inline `mcpServers:`;
    - an engine `design-board` command plus `installer/build.py`;
    - the `## Operator Runtime` fields;
    - the record layout.
  - S2 §3 gotchas:
    - Storybook: explicit meta `id`, ESM config, `STORYBOOK_DISABLE_TELEMETRY=true`;
    - Penpot: separate agent and operator users, the active-page-only content rule, async `openPage`, telemetry on by default upstream, exporter memory.
  - The first live checks owed:
    - the chosen option driven by a background subagent inside an `ocx claude` session;
    - if the bundle-import path is kept, `/design-login` under ocx and the bundle push (both need the operator's claude.ai account).
  - The ocx `DesignSync` limitation is undocumented in `operations.md`'s visual-design runbook.
  - Related open jobs a design-cowork edit touches: D5, D7, D12, D13.
- **trigger:** the operator picks an option from the P25 report (answering the stack and canvas questions), or before the next design-bearing phase runs design-cowork under `ocx claude`.

**Spec 2: for the orchestrator to file with `defer-job`** (from the S2 note)
- **title:** Re-evaluate Doop as a design-cowork option
- **reason:** it is the closest to Claude Design's agent UX (HTML frames, screenshots, comments, style guides, saved decisions over MCP). P25 dropped it on maturity (created 2026-08-22, 86% of commits by one author), OAuth-only MCP (background-subagent reuse unverified), memory in its DB with no tokens, no published image, and a server binding all interfaces (`P25.S2/result.md` §3.4).
- **trigger:** Doop reaches v1.0, or publishes an image, or ships a non-interactive agent token.

## 9. Observations outside the boundary (not findings)

- **P25 stayed `planned` in `phase.json` while all of its slices ran.** No `phase_status_changed` event exists for P25, because `start-slice` never moves the phase. This is **already filed as D22** ("A running phase stays planned: start-slice never moves it to in_progress"), so no new job is needed. P25 is one more instance. It matters because `parallel-start`'s "a phase already in flight finishes on this stream" guard checks only `status == planned`.
- **`validate`'s `oversized_doc_sections=7` warning** predates P25 and is tracked as **D25**.
