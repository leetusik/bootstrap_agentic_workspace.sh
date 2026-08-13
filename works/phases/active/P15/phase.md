# Phase P15: Drop Codex support

_Intent: see [intent.md](intent.md)._

## Objective

Remove all Codex-specific machinery, contract text, installer payload, tests, and documentation so the workspace ships Claude Code only, and give existing adopters a flagged upgrade path.

## Context

Upstream bootstrap repo. Everything Claude-facing stays; everything Codex-facing goes. The
removal is spread over six ordered slices because the build guard (`installer/build.py --check`,
enforced by `.githooks/pre-commit`) refuses any commit where the live tree and the committed
`bootstrap_agentic_workspace.sh` disagree — so the cut is shaped by "what must land in one
commit", not by "what is topically similar".

Verified against the tree at commit `c307eb9`. The survey in `intent.md` was re-checked file by
file during `P15.DECOMP`; corrections and additions are in *Findings & Notes* below.

## Decomposition

Six middle slices, strictly ordered. Every one is `--risk high` (`slice-executor-high`): each
writes real code or spans several files; nothing here is a one-line edit.

| Slice | Name | Why it is its own slice |
| --- | --- | --- |
| `P15.S1` | Strip Codex from the workflow engine and `executors.toml` | Pure engine change. The Codex files still exist on disk, so the build stays green; doing this first means later slices delete files nothing references. |
| `P15.S2` | Strip Codex from the installer and delete the Codex trees | **Atomic by necessity** — see *Constraints*. `installer/build.py` + `installer/main.py` + `installer/wrapper.sh` + `.githooks/pre-commit` + `rm -rf .agents/ .codex/` + `rm AGENTS.md` in one commit. |
| `P15.S3` | Strip Codex from the contract and Claude skill prose | `CLAUDE.md` plus the 10 `.claude/**` files that mention Codex or `AGENTS.md`. **Also owns two `installer/` constants** — see *Constraints* (the `CLAUDE_HDR` coupling). |
| `P15.S4` | Rewrite the retrofit smoke test Codex-free | `tests/retrofit_smoke.sh`. Must come after `S3`, because Test 0 asserts contract strings (`"Codex branch:"`, `"DesignSync"`, …) that `S3` deletes. Keeps the version pin at `30`. |
| `P15.S5` | Strip Codex from READMEs, guides, and shipped doc bodies | `README.md`, `README.en.md`, `docs/retrofit-guide.md`, `installer/README.md`, `installer/payloads/doc_bodies/{architecture,operations}.md`. Nothing else depends on it, so it sits late. |
| `P15.S6` | Ship the removal as workspace v31 with a CHANGELOG entry | Release metadata last, so the CHANGELOG describes the finished phase. Bumps `WORKSPACE_VERSION`, appends `## v31` with **Migration notes**, and moves the smoke test's version pin `30` → `31` in the same commit. |

Ordering rationale, in one line: **engine → installer+deletion → contract → tests → prose →
release**, so that every commit builds, validates, and (from `S4` onward) keeps the smoke test
green.

### What must stay atomic, and why

1. **`S2` — installer edits and the tree deletion are one commit.** `installer/build.py`
   currently (a) lists `.codex/config.toml` and both `.codex/agents/slice-executor-*.toml` in
   `FIXED_LIVE_FILES`, (b) globs `.agents/skills/*/SKILL.md` and `.agents/skills/*/agents/openai.yaml`
   as live payload, (c) hard-asserts `len(claude_skills) == len(codex_skills) == EXPECTED_SKILL_COUNT`
   and `claude_skills == codex_skills`, and (d) `collect_contract_body()` reads `AGENTS.md` and
   asserts its body is byte-equal to `CLAUDE.md`'s. Deleting any of those trees without fixing
   `build.py` in the same commit makes the build `die()` and the pre-commit hook reject the commit.
   `installer/main.py` re-derives `CODEX_SKILLS` from the generated `PAYLOADS` dict and raises at
   import time on the same parity guard, so it moves with `build.py`.
2. **`S3` — the `CLAUDE.md` header line and its two pinned copies are one commit.** *(New — the
   survey missed this.)* `CLAUDE.md` line 3 is `> Equivalent to \`AGENTS.md\`. If you change
   workflow rules, update both.` That exact string is pinned in two places:
   - `installer/build.py` `CLAUDE_HDR` (~L62), checked by `collect_contract_body()` with
     `die("CLAUDE.md header changed — update CLAUDE_HDR in build.py")`;
   - `installer/main.py` (~L477) `write_text("CLAUDE.md", f"# CLAUDE.md\n\n> Equivalent to ...")`.

   So `S3` must edit `CLAUDE.md`'s header line **and** `CLAUDE_HDR` **and** the `main.py` write
   literal together. After the change, `CLAUDE_HDR` becomes `"# CLAUDE.md\n\n"` and the extracted
   body still starts at `# Agent Contract`. (`AGENTS_HDR` and the byte-equality assertion are
   already gone by then — `S2` removed them.)
3. **`S6` — the version bump and the smoke test's pin are one commit.** `tests/retrofit_smoke.sh`
   (~L232) asserts `main_version == top_changelog == marker_version == 30`. Bumping
   `WORKSPACE_VERSION` without moving that literal turns the smoke test red; moving the literal
   first turns it red the other way. Ordering the release last and doing both together means the
   smoke test is green at the end of every slice from `S4` on.

### Deliberately not sliced

Per `intent.md`, the historical record is preserved: `works/phases/active/P13` and `P14`,
`docs/versions/**`, `works/events.jsonl`, and existing `CHANGELOG.md` sections are untouched.
`works/backlog.md` and `works/index.json` mention Codex only because P13/P14 are named after it —
they are generated files and regenerate as-is. `docs/current/*.md` is generated; new durable truth
lands as **new** doc versions at `P15.REVIEW` (see *Doc impact*).

## Findings & Notes

### Survey verification (against the tree at `c307eb9`)

The survey in `intent.md` is accurate. Confirmed exactly:

- `.agents/` = **34 files** (17 skills x `SKILL.md` + `agents/openai.yaml`); `.codex/` = **3 files**
  (`config.toml`, `agents/slice-executor-{mid,high}.toml`). `.claude/skills/` = 17, same names.
- `installer/build.py`: `EXPECTED_SKILL_COUNT = 17` (L41). `FIXED_LIVE_FILES` Codex entries are
  exactly three: `".codex/config.toml"` (L46), `".codex/agents/slice-executor-mid.toml"` (L50),
  `".codex/agents/slice-executor-high.toml"` (L51). `AGENTS_HDR` at L63. `.agents/` payload globs
  at L86-89. Parity block L90-117. `collect_contract_body()` L121-130.
- `installer/main.py`: `WORKSPACE_VERSION = 30` (L38); `CODEX_SKILLS` + `EXPECTED_SKILL_COUNT = 17`
  + guards L55-71; `MANAGED_DIRS` L80-81; `MANAGED_FILES` L85, L94; the `CODEX_SKILLS` loop
  L100-105; `_merge_contract` L231-255 and `_retrofit_handle` L266; `_is_machinery()` L286-289;
  update dispatch L351; contract writes L477-478; Codex payload writes L555-563 and L572;
  `OBSOLETE_MACHINERY` L597-606; `flag_obsolete_machinery()` L609-612; `flag_stale_skills()`
  L615-640; final banner L709-724.
- `scripts/workflow.py`: `CODEX_AGENTS` L41; `codex_model`/`codex_effort` in all four
  `EXECUTOR_PRESETS` tier dicts L53-58 (flat dicts of four keys each — edit each dict, do not
  delete a branch); `read_executors_toml()` L116-166 (the `(claude|codex)` alternations are at
  L144 and L148, error strings at L137, L157, L165); `executor_config()` L169-181 (the `codex_`
  prefixing at L175, the empty-model check at L178); `_patched_agent_toml()` L197-210 (exists only
  for `.codex/agents/*.toml`); `executor_agent_files()` L213-220 (4 entries → 2, drop L219);
  `sync_agents()` print at L244; `validate` warnings L748-760 (they are generic over
  `executor_agent_files()`, so they need no Codex-specific edit once L219 is gone — only the
  `_patched_agent_toml` branch at L756 does); the `parallel-start` next-step hint at L1133.
- `.githooks/pre-commit` L8 alternation, verbatim:
  `^(installer/|scripts/workflow\.py$|CLAUDE\.md$|AGENTS\.md$|executors\.toml$|\.claude/|\.agents/|\.codex/|\.github/|\.gitattributes$|works/templates/|bootstrap_agentic_workspace\.sh$)`
  → drop `AGENTS\.md$|`, `\.agents/|`, `\.codex/|`.
- `executors.toml`: preset docs L10-21, commented `[codex.*]` block L43-49.
- `installer/wrapper.sh`: usage heredoc L21 ("Claude Code and OpenAI Codex"), L23-24 (AGENTS.md /
  CLAUDE.md equivalence), L26 (`.agents/skills/`). There are no per-tool installer flags, so there
  is nothing to gate — only text to remove.
- `.gitattributes`, `.github/workflows/workspace-ci.yml`, `.claude/settings.json`, and
  `works/templates/*` contain **no** Codex or `AGENTS.md` references. Nothing to do there.

### New findings the survey did not have

1. **`CLAUDE_HDR` / `main.py` contract-write coupling** — see *What must stay atomic* item 2.
   This is the one place where a "prose-only" edit breaks the build.
2. **The release needs a version bump, and the smoke test pins it.**
   `tests/retrofit_smoke.sh` L222-234 asserts
   `main_version == top_changelog == marker_version == 30`. `installer/main.py` documents
   `WORKSPACE_VERSION` as "bumped (with a matching `CHANGELOG.md` entry) whenever a machinery
   change ships to targets" — and the whole `OBSOLETE_MACHINERY` flagging story only reaches
   adopters through an update, so **v31 + a `## v31` CHANGELOG section with Migration notes is
   required**, not optional. This is an *append* to `CHANGELOG.md`, which is consistent with
   `intent.md`'s "append-only history stays as it is". Hence `P15.S6`.
   Optional simplification for `S4`/`S6` to consider: the three-way equality already catches a
   partial bump, so the trailing `== 30` literal could be dropped instead of maintained. Either
   choice is fine; just do not leave the two disagreeing.
3. **`flag_obsolete_machinery()` really does only check `is_file()`** (`installer/main.py` L611,
   confirmed). Adding `.agents` and `.codex` as **directory** entries to `OBSOLETE_MACHINERY`
   silently no-ops unless that becomes `.exists()` (or `is_file() or is_dir()`). `AGENTS.md` is a
   file and works either way.
4. **Two existing `OBSOLETE_MACHINERY` entries become redundant**: `.codex/agents/slice-executor.toml`
   (L599) and `.codex/agents/slice-executor-low.toml` (L605) are subsumed by a `.codex` directory
   entry and would double-report. `S2` should collapse them.
5. **`AGENTS.workspace.md` is a stranded artifact for retrofitted adopters.** `_merge_contract()`
   writes `CLAUDE.workspace.md` *and* `AGENTS.workspace.md`, and the update path refreshes whichever
   sidecar exists. Once the installer stops handling `AGENTS.md`, an already-retrofitted repo keeps
   a stale `AGENTS.workspace.md` that is never refreshed and never flagged. `S2` should decide:
   add `AGENTS.workspace.md` to `OBSOLETE_MACHINERY` too, or accept the strand and say so. Also
   note the pointer block at L241 names `` `.claude/`/`.agents/` `` and must lose `.agents/`.
6. **`flag_stale_skills()` is per-tool by design** (`disable-model-invocation: true` for Claude,
   `agents/openai.yaml` for Codex). Dropping the `.agents/skills` half is straightforward; keep the
   Claude marker logic exactly as is. With `.agents` flagged wholesale via `OBSOLETE_MACHINERY`,
   nothing is lost.
7. **CI runs the smoke test on every push** (`.github/workflows/workspace-ci.yml` step
   "retrofit smoke (upstream only)"). The pre-commit hook does **not**. So a red smoke test blocks
   nothing locally but does turn CI red on push — which is exactly why `S4` and `S6` are ordered to
   leave it green.
8. **`tests/retrofit_smoke.sh` Test 1 creates its own `AGENTS.md`** in the sample repo (L116) and
   pins the modified-file list to `.claude/settings.json,.gitattributes,AGENTS.md,CLAUDE.md,`
   (L135). After removal, the installer no longer touches it, so the list becomes
   `.claude/settings.json,.gitattributes,CLAUDE.md,`. Keeping the sample `AGENTS.md` and asserting
   it is left **byte-identical** is a better regression than deleting it: `AGENTS.md` is a
   cross-tool convention other tools still use, and this workspace must not clobber a repo's own.
   `S4`'s call, but recommended.
9. **Smoke-test blocks that carry Codex expectations** (verified line ranges): Test 0 L38-106
   (rewrite wholesale — the `AGENTS.md`/`CLAUDE.md` body-equality assertion at L91-93 and the
   `"Codex branch:"` requirement at L95 both go); L135; L165-177; L236-255 (incl. the fresh-install
   inventory, the Codex tier-model greps, and the `.codex/agents/slice-executor-low.toml` retirement
   checks); L261-283 (economy/flex mode matrices — drop the `gpt-5.6-*` greps, keep the
   `[claude.low]`-rejected and unknown/duplicate/misplaced-mode checks); L288-303 (the `--update`
   staleness block, which is entirely Codex-skill-based and needs replacing with a Claude-skill
   equivalent); L330-336; L346 (`find .claude/skills .agents/skills`); L351-357 (the byte-for-byte
   drift manifest — drop the three `.codex` paths and `AGENTS.md`); L380.
10. **`docs/retrofit-guide.md`, `installer/README.md`, `README*.md`, and `tests/` are NOT embedded**
    in the artifact (only `installer/payloads/doc_bodies/*.md` and the `FIXED_LIVE_FILES` /
    skill-glob set are). Confirmed against `build.py`. So `S4` needs no rebuild; `S5` does, because
    of the two doc bodies.

### From `P15.S1` (engine + `executors.toml`)

1. **`sync-agents` output format changed** — the per-tier line is now
   `f"{tier:<5} {cfg['model']} @ {cfg['effort'] or '(no effort line)'}"` (was
   `claude=... codex=...`). Sample output: `mid   sonnet @ xhigh` / `high  opus @ xhigh`. The
   `config source:` line, the `missing agent file:` lines, and both `--check` outcomes are byte-identical
   to before. **Good news for `P15.S4`:** the smoke test's mode-matrix blocks send `sync-agents` stdout
   to `/dev/null` and assert against the *generated agent files*, so the format change breaks nothing —
   the only stdout assertion is L279 (`grep -q 'retired in workspace v23'`), and that message still fires.
   What `S4` must actually remove is the `.codex/agents/slice-executor-*.toml` greps at L249-253,
   L265-266, L275-276.
2. **`[claude.<tier>]` table name kept** (deliberate, per plan). Renaming it would break every adopter's
   existing `executors.toml` for no gain. So a post-v31 `executors.toml` is the old syntax minus the
   Codex tables — an adopter who never wrote a `[codex.*]` block needs no migration at all.
3. **New `[codex.*]` rejection**, placed right after the retired-tier check in `read_executors_toml()`:
   `executors.toml line {n}: Codex support was removed in workspace v31 — this workspace ships Claude
   Code only, so drop this section`. Regex `^\[\s*codex\s*\.\s*[^\]]*\]\s*(?:#.*)?$` — loose on the tier,
   so `[codex.low]` lands here rather than on the retired-tier message (the retired-tier regex is now
   `claude`-only, so the two can never collide). **This message pins the version number `v31`** — it is a
   second place, alongside `WORKSPACE_VERSION` and the CHANGELOG, where `P15.S6` must land on 31. If the
   release ends up being a different number, this string must move with it. A smoke-test assertion
   mirroring L279 (`grep -q 'removed in workspace v31'`) would be a cheap regression for `S4` to add.
4. **`values` key tuple simplified** to `(tier, key)` (was `(harness, tier, key)`); `read_executors_toml`'s
   `section` is now a bare tier string and `executor_config()`'s overlay is a plain two-line loop. No
   `harness == "claude"` residue remains. `executor_agent_files()` also lost its `kind` element →
   `(tier, path, model, effort)`; both call sites (`sync_agents`, `validate`) call `_patched_agent_md`
   directly. Anything later touching these helpers should expect the 4-tuple.
5. **Nothing outside `scripts/workflow.py` referenced the removed symbols** — verified by grepping the
   whole repo (excluding the generated artifact, `works/`, `docs/`) for `_patched_agent_toml`,
   `CODEX_AGENTS`, `codex_model`, `codex_effort`, `executor_agent_files`: only `workflow.py` itself. The
   engine cut was genuinely self-contained.
6. **`validate` still emits zero warnings** after the cut, because the `.codex/agents/*.toml` files it
   used to check are simply no longer in `executor_agent_files()`. The advisory-only `try/except` wrapper
   is unchanged, so a partial or foreign workspace still validates.
7. **`tests/retrofit_smoke.sh` is now red**, as planned (Codex tier-model greps). Expected until `S4`;
   the pre-commit hook does not run it, so local commits are unaffected.

### From `P15.S2` (installer + tree deletion)

1. **Fresh-install conflict guard narrowed — but less than expected, and the exact shape matters.**
   `MANAGED_FILES` lost `"AGENTS.md"`, so a target containing one no longer trips the
   *managed-file conflict* guard. It is **still rejected by the emptiness guard**, because
   `AGENTS.md` is not in `EMPTY_OK_ALLOWLIST` — verified: the error is now "target is not empty
   (beyond common repo metadata) … - AGENTS.md" instead of "target already contains managed
   workflow files". The behaviour change is therefore confined to
   `--force-empty-ok`: pre-S2 that combination aborted on the managed-file conflict; now it
   installs and leaves the repo's own `AGENTS.md` byte-identical. That is correct — we no longer
   write there — and it is arguably better, but it is a real change. (Adding `AGENTS.md` to
   `EMPTY_OK_ALLOWLIST` would make the plain case work too; **not** done here, out of scope.)
2. **A repo's own `AGENTS.md` is now left completely untouched, on every path.** Retrofit no longer
   reads it, no longer appends a pointer block, and no longer writes an `AGENTS.workspace.md`
   sidecar; `--update` no longer rewrites it. Verified byte-identical after a real retrofit (diff)
   and after a real `--update` (md5 unchanged). This makes the installer strictly less invasive and
   is the desired outcome — `AGENTS.md` is a cross-tool convention (Cursor, Amp, Copilot) that this
   workspace must not clobber. **For `S4`:** finding 8 above is now confirmed behaviour, so the
   smoke test should keep the sample `AGENTS.md` and assert it comes out byte-identical (this is
   the "should the installer *assert* it never touches a repo's own `AGENTS.md`" question from the
   S2 plan — answer: yes, and it belongs in the smoke test, not in `main.py`). The pinned
   modified-file list becomes `.claude/settings.json,.gitattributes,CLAUDE.md,`.
3. **`AGENTS.workspace.md` — decided: flagged.** Resolves the first *Open Question*. It is in
   `OBSOLETE_MACHINERY` alongside `.agents`, `.codex`, and `AGENTS.md`. Rationale: `_merge_contract`
   created it for retrofitted adopters, and once the installer stops handling `AGENTS.md` it would
   never be refreshed and never flagged — a silent strand, which is exactly what this list exists to
   prevent.
4. **Final `OBSOLETE_MACHINERY` list** (10 entries): `.claude/agents/slice-executor.md`,
   `.env.example`, `executors.toml.example`, `works/templates/result.md`,
   `.claude/agents/slice-planner.md`, `.claude/agents/slice-executor-low.md`, `.agents`, `.codex`,
   `AGENTS.md`, `AGENTS.workspace.md`. The two `.codex/agents/slice-executor{,-low}.toml` entries
   were **removed** — the `.codex` directory entry subsumes them and they would double-report.
   `flag_obsolete_machinery()` now tests `.exists()` instead of `is_file()` (finding 3); without
   that the two directory entries are dead code. Verified end-to-end: a real `--update` against a
   pre-S2 install prints
   `stale workspace skills/machinery dropped upstream (remove manually?): .agents, .codex, AGENTS.md, AGENTS.workspace.md`
   — each exactly once — and deletes nothing (37 Codex files before and after).
5. **`EXPECTED_SKILL_COUNT = 17` kept in both `build.py` and `main.py`** as a Claude-only assert.
   `S5`/`S6` must not drop it, and anything that changes the shipped skill count must move both.
6. **Scope correction for `S3`: 11 `.claude/**` files, not 10.** Exact current hits —
   `.claude/agents/slice-executor-{mid,high}.md` (2 `AGENTS.md` each, no "Codex");
   `.claude/skills/{create-phase,do-next-slice,do-whole-phase,parallel-phase,review-phase}/SKILL.md`
   (1 `AGENTS.md` each); `.claude/skills/retrofit/SKILL.md` (2 `AGENTS.md`);
   `.claude/skills/{design-cowork,explain}/SKILL.md` (2 "Codex" each, no `AGENTS.md`);
   `.claude/skills/update-workspace/SKILL.md` (2 "Codex" + 1 `AGENTS.md`, **plus** two
   `.agents/`/`.codex/` path references at L12 and L61 that a "Codex"/"AGENTS.md" grep alone
   misses). `CLAUDE.md` itself: 11 "Codex" + 2 `AGENTS.md` + `.agents/`/`.codex/` path references
   at L7, L16, L23, L27, L75, L76. **Grep for `\.agents/\|\.codex/` as well as `codex\|AGENTS`.**
7. **The artifact is now Codex-free at the payload level**: zero `'.agents/…'` / `'.codex/…'`
   payload keys. The 28 remaining "Codex" strings in `bootstrap_agentic_workspace.sh` all come from
   embedded prose `S3` owns (`.claude/skills/*`, the `CLAUDE.md` contract body) plus the two
   deliberate `[codex.*]`-rejection strings in `scripts/workflow.py` from `S1`. **`S3`'s rebuild
   should drive that 28 down to just the 2 workflow.py rejection strings** — a good closing check
   for `S3`.
8. **The `.githooks/pre-commit` narrowing is inert for the `S2` commit** and verified so: the new
   alternation still matches `installer/*` and `bootstrap_agentic_workspace.sh`, which are staged
   here, so the hook fires and `--check` runs. Only a hypothetical deletions-only commit would stop
   firing, which is harmless (no installer/artifact change ⇒ no drift possible).
9. **`S1` + `S2` compose correctly in a *freshly installed* workspace** — the combination neither
   slice could verify alone. In the temp fresh install, `validate` passes and
   `sync-agents --check` prints the new S1 format (`mid   sonnet @ xhigh` / `high  opus @ xhigh`)
   and exits 0.
10. **`tests/retrofit_smoke.sh` remains red**, as planned, and was deliberately not run as a gate.

### From `P15.S3` (contract + Claude skill prose)

1. **The `CLAUDE_HDR` coupling landed cleanly.** `CLAUDE.md` now opens `# CLAUDE.md\n\n## Agent
   Contract`; `installer/build.py:59` `CLAUDE_HDR` and the `installer/main.py:460`
   `write_text("CLAUDE.md", …)` literal are both `"# CLAUDE.md\n\n"`. Verified end to end, not just
   by the build: a fresh install, a retrofit sidecar (`CLAUDE.workspace.md`), and an `--update`
   contract refresh each produce a `CLAUDE.md` **byte-identical to the repo's**, which is the
   strongest available proof that `collect_contract_body()`'s length-slice still lands exactly on
   `## Agent Contract`. `grep -rn 'Equivalent to'` over the whole repo (incl. `tests/`, `README*`,
   `docs/retrofit-guide.md`, the artifact) returns **zero** — nothing else pinned that line.
2. **The design exception was generalized, not deleted — flagged for `P15.REVIEW` to challenge.**
   The `pending` hard rule now reads "**Narrow design exception:**" and "the orchestrator may clear
   and resume that same slice inline under the `design-cowork` skill"; both guardrails are verbatim
   ("A bare automatic invocation is never approval, and no other pending gate is relaxed").
   Rationale: it was written for Codex only because Codex was automatic-only, but Claude Code's
   default **is** `auto`, so it meets the identical situation; the mechanism is not harness-specific;
   and it has no `.claude/**` counterpart, so deletion would have removed the behaviour from the
   workspace outright. **This is the one place where `S3` widened a rule's applicability rather than
   narrowing it** — the reviewer should judge whether `auto` + a literal in-invocation approval is a
   gate it wants relaxed for Claude Code.
3. **Final wording of the design hard rule.** Single rule, no branches: opener "**Product visual
   design follows the `design-cowork` skill.**" → "The invariants: …" (the same list, unchanged) →
   the rescued sentence → the Claude Design / DesignSync body inlined without its "**Claude Code
   branch:**" label → closing "**Never** invent visual decisions in an executor or pre-plan build
   slices before the signed design." All Codex-only mechanics (ImageGen / GPT Image 2, native-pixel
   chapter composition, the advisory size/quality wording, `SIGNOFF.md`, the no-pre-generation-
   confirmation sentence) are gone.
4. **The rescued sentence survived verbatim**: "Approval must be literal; revisions create new
   immutable superseding rounds; later slices verify the running product in a real browser." It sits
   at the end of the invariants, before the Claude Design body. It slightly overlaps "literal
   operator signoff closes an immutable round", which was kept deliberately — the rescued sentence
   carries two facts (revision rounds, browser verification) that exist nowhere else in the contract.
   `DesignSync` still appears in `CLAUDE.md` (exactly once, in that rule) for `P15.S4`'s assertion.
5. **`.claude/skills/explain/SKILL.md` now diverges from its vendored upstream** (`leetusik/knowledge
   @ d0c2c38`). Two upstream passages were dropped: the step-2a "**On Codex**, `workspace-write`
   blocks outbound network…" paragraph and the `<noreply@openai.com>` attribution parenthetical. The
   divergence is recorded **in the file's own re-vendor comment** (which already enumerated the two
   pre-existing de-plugin-ification divergences) so a future re-vendor does not silently reintroduce
   them. Nothing syncs the two copies; upstream is unchanged and unaware.
6. **Two deliberate "Codex" hits remain under `CLAUDE.md` + `.claude/` — an interpreted gate, same
   shape as `S2`'s.** The plan asked for zero, but its own body mandates one of them:
   - `.claude/skills/update-workspace/SKILL.md` step 8 — the **pre-v31 migration paragraph** the
     plan explicitly required ("mention that `--update` now flags `.agents`, `.codex`, `AGENTS.md`,
     and `AGENTS.workspace.md` as stale"), which also quotes `S1`'s real error string verbatim
     (`executors.toml line <n>: Codex support was removed in workspace v31 — …`) so an adopter can
     recognize the `[codex.*]` table they must delete.
   - `.claude/skills/explain/SKILL.md` — the re-vendor comment in item 5.
   Both **document the removal**; neither instructs an agent to do anything Codex-shaped. This is the
   same reading `S2` applied to its `OBSOLETE_MACHINERY` comments. `P15.REVIEW` may overrule it.
7. **Artifact "Codex" count: 28 → 19**, not the 2 `S2` predicted, and the gap is fully accounted for:
   5 in `installer/payloads/doc_bodies/{architecture,operations}.md` (**`S5`'s**), 8 in
   `installer/main.py`'s own `OBSOLETE_MACHINERY` entries + `flag_obsolete_machinery()` comment
   (`S2`'s deliberate migration block, embedded because `main.py` *is* the artifact), 2 in
   `scripts/workflow.py`'s rejection strings (`S1`'s), and 4 in the two `.claude/**` prose hits in
   item 6. `S2`'s "down to just the 2" estimate simply forgot the doc bodies and its own `main.py`
   comments. **After `S5` the floor is 14**, not 2.
8. **Concrete `S4` findings this slice created** (beyond the ones already listed):
   - `tests/retrofit_smoke.sh` L91-92 does `(root / "AGENTS.md").read_text()` and
     `(root / "CLAUDE.md").read_text().split("\n\n", 2)[2]`. The `AGENTS.md` read now raises. The
     `split("\n\n", 2)[2]` was written to skip a **two-paragraph** header (`# CLAUDE.md` + the
     blockquote); the header is one paragraph shorter now, so `[2]` starts at "This file is a
     compact routing contract…" instead of "## Agent Contract". Every string it asserts lives further
     down, so it would still pass by luck — `S4` should drop the split and read the whole file.
   - The contract strings the smoke test requires at L95 / L175-176 / L242 are now: `"Claude Code
     branch:"` **gone**, `"Codex branch:"` **gone**, `"Claude Design"` kept, `"DesignSync"` kept,
     `"built-in ImageGen"` **gone**, `"never writes implementation code"` kept, `"RESPECT THE
     DESIGN"` kept.
   - The `--update` change-list is an exact scope oracle: updating a pre-`S3` install with the new
     artifact reports **precisely 12 machinery files** — `CLAUDE.md` plus the 11 `.claude/**` files —
     confirming nothing else embedded moved.
9. **`.claude/settings.json` / `settings.local.json` needed no edit**, as the plan said, and neither
   did any `.claude/**` file outside the 11.

### From `P15.S4` (smoke test)

1. **`tests/retrofit_smoke.sh` is green again — 115 PASS, 0 FAIL, exit 0** (was 24 failures). All
   eight blocks still fire. `ok` sites 89 → 91, `bad` 90 → 92: **9 Codex-existence assertions
   removed, 11 added**, itemized in `slices/P15.S4/result.md`. `S5` and `S6` should keep it green
   and treat a red run as their own regression, not inherited fallout.
2. **The version pin's literal `== 30` is gone — `P15.S6` needs no test edit.** The block now
   asserts only `main_version == top_changelog == marker_version`, which already catches every
   partial bump. This closes the *Open Question* "whether to keep the literal release pin": there
   is no literal left to disagree with `WORKSPACE_VERSION`. `S6` bumps `installer/main.py` and
   appends the `## v31` CHANGELOG heading; the smoke test follows automatically. **The `v31`
   string still pinned by the test is S1's rejection message** (`removed in workspace v31`), which
   records *when* removal happened and does not drift with the workspace version — but if the
   release lands on a number other than 31, S1's string, the `update-workspace` migration
   paragraph, and this assertion all move together.
3. **The Codex-removal negatives now in the test**, so a regression cannot land silently:
   `AGENTS.md`/`.agents`/`.codex` absent at the repo root, absent after a retrofit, absent after a
   fresh install; no `AGENTS.workspace.md` sidecar written; no `Codex`/`AGENTS.md`/`.agents/`/
   `.codex/` string in `CLAUDE.md` or in either `slice-executor-*.md`; a leftover `[codex.*]`
   table rejected with S1's v31 message; and — the strongest one — **a sha pin proving a repo's
   own `AGENTS.md` comes out of a retrofit byte-identical** (finding 8 / S2 finding 2, now
   enforced). S2's `--force-empty-ok`-beside-`AGENTS.md` path (S2 finding 1) is covered too.
4. **The `OBSOLETE_MACHINERY` regression pins three S2 decisions with one assertion.** The test
   seeds the pre-v31 shape (`.agents/skills/<x>/`, `.codex/agents/slice-executor{,-low}.toml`,
   `AGENTS.md`, `AGENTS.workspace.md`), runs `--update`, and asserts each of the four paths appears
   in the stale line **exactly once** and that all four **still exist afterwards**. Reverting
   `flag_obsolete_machinery()` to `is_file()` drops the two directory entries → count 0 → fail;
   un-collapsing the two redundant `.codex/agents/*.toml` entries → `.codex` counted 3 times →
   fail; deleting instead of flagging → fail. Real output, verified:
   `stale workspace skills/machinery dropped upstream (remove manually?): .agents, .codex, AGENTS.md, AGENTS.workspace.md`
5. **That block had been testing nothing at all.** Its old fixture (`printf … > "$F/.agents/skills/
   design-cowork/…"`) was a shell redirect into a tree S2 deleted, so it failed as a redirect error
   and every assertion after it was vacuous. It is now the Claude-side equivalent (delete
   `.claude/skills/do-whole-phase`, junk `.claude/skills/design-cowork/SKILL.md`) and genuinely
   exercises restore + refresh + the two "not flagged stale" negatives.
6. **Test 0's contract read is fixed** (S3 finding 8). The `AGENTS.md` read and the
   `.split("\n\n", 2)[2]` are both gone — the split existed only to compare the two bodies and,
   after S3 shortened the header, was landing one paragraph late and passing by luck. Test 0 now
   asserts against the full `CLAUDE.md` text.
7. **Deviation, for `P15.REVIEW`: "zero `Codex` in the 17 skills" was not achievable and was not
   forced.** S3 finding 6 kept two deliberate mentions (`update-workspace`'s mandated pre-v31
   migration step, `explain`'s re-vendor comment). The test asserts
   `codex_prose <= {"update-workspace", "explain"}` — a *subset*, so any third mention fails and
   dropping one later is allowed — plus a pin that the adopter-facing
   `"Codex support was removed in workspace v31"` sentence is still there. If `REVIEW` overrules
   S3's interpretation, tighten the subset to `== set()` in the same edit that removes the prose.
8. **`.claude/agents/slice-executor-mid.md` has no `co-work` / `DesignSync` clause** — the Codex
   tomls stated the design gate in *both* tiers; the Claude files state it only in `high`. So the
   ported assertion covers `high` only (both tiers still assert the commit ban, the
   state-transition ban, and Codex absence). **Pre-existing asymmetry, not introduced by this
   phase** — flagged for `REVIEW` to decide whether `mid` should carry the clause too (a `mid`
   executor handed a `co-work` slice has no written instruction to refuse it).
9. **Test 6 gained a count guard and a cross-check.** The skill loop asserts exactly 17 `SKILL.md`
   files (with `.agents/skills` dropped from the `find`, a typo would otherwise produce an empty
   loop and a green result), and a new `ast`-based check proves the hand-maintained dual-apply list
   plus `scripts/workflow.py` covers every `FIXED_LIVE_FILES` entry in `installer/build.py`
   (mutation-checked: a truncated list fails). Anything that adds a fixed live file now fails the
   smoke test until the manifest is updated.
10. **No doc impact from this slice.** `docs/current/qa.md`'s smoke-test sentence stays accurate
    word for word, and no doc describes the test's contents; the phase's existing engine /
    installer / contract lines already carry the durable truth this test enforces.

### Doc impact

_(One line per durable-truth change; `P15.REVIEW` consolidates these into new doc versions —
never patch `docs/current/*.md` or an existing version.)_

- `architecture` — the tool-entry-point and contract lines change: `.agents/` and `.codex/` are
  gone, and `CLAUDE.md` is the single routing contract (no `AGENTS.md` twin).
  (`docs/current/architecture.md` L23, L35; latest version `v0003`.)
- `operations` — the whole dual-harness operating story goes: the 17+17 skill inventory, Codex's
  automatic-only `do-next-slice`/`do-whole-phase`, the `.codex/agents/slice-executor-*.toml`
  dispatch, the Codex `workspace-write` network caveat for `/explain`, and the Codex halves of the
  executor preset matrices. (`docs/current/operations.md`, 44 Codex mentions; latest `v0025`.)
- `decisions` — record the new accepted decision "drop Codex support; ship Claude Code only" with
  its rationale (dual-harness parity tax) and its migration mechanism (`OBSOLETE_MACHINERY`
  flagging, workspace v31). **Append a new decision; do not rewrite the 33 historical entries** —
  P13/P14 remain accepted history that this decision supersedes. (latest `v0033`.)
- `operations` (from `P15.S1`) — the executor-tier config story is now single-harness: `executors.toml`
  accepts `[claude.<tier>]` only (a `[codex.*]` section is a hard error naming workspace v31), the
  presets are two fields per tier, and `sync-agents` prints `<tier> <model> @ <effort>` instead of
  `claude=... codex=...`.
- `architecture` (from `P15.S2`) — the installer/distributable story is single-harness: the artifact
  embeds `.claude/**` only (no `.agents/`/`.codex/` payloads, no `CLAUDE.md == AGENTS.md`
  byte-equality assertion), and a fresh install produces `CLAUDE.md` + `.claude/` with no
  `AGENTS.md`.
- `operations` (from `P15.S2`) — the install/retrofit/update contract changed: retrofit and
  `--update` now leave a repo's own `AGENTS.md` completely untouched (no pointer block, no
  `AGENTS.workspace.md` sidecar), and `--update` flags `.agents`, `.codex`, `AGENTS.md`, and
  `AGENTS.workspace.md` as stale machinery to remove manually (workspace v31 migration path;
  `--update` still never deletes).
- `architecture` (from `P15.S3`) — the shipped contract has no `AGENTS.md` equivalence header: a
  fresh install, a retrofit sidecar, and an `--update` refresh all write a `CLAUDE.md` that opens
  `# CLAUDE.md` → `## Agent Contract`. (Folds into the S2 `architecture` line; same doc, same
  version.)
- `operations` (from `P15.S3`) — two operating rules changed shape, not just wording: (a) the
  `pending` **design exception is now harness-general** — any orchestrator may clear and resume a
  `pending` `co-work` slice inline when the invocation carries a literal response to it (guardrails
  unchanged: a bare automatic invocation is never approval, no other pending gate is relaxed);
  (b) `update-workspace` now carries a **pre-v31 migration step** (`.agents`, `.codex`, `AGENTS.md`,
  `AGENTS.workspace.md` flagged, remove by hand; a leftover `[codex.*]` table is a hard error).
- No other `docs/current/*.md` mentions Codex (`product`, `experience`, `frontend`, `backend`,
  `data`, `api`, `security`, `qa` are all clean).

## Constraints

- **Every slice must end with all three of these passing**, because the orchestrator commits at
  each slice boundary and `.githooks/pre-commit` runs the build check:
  - `python3 installer/build.py`
  - `python3 installer/build.py --check`
  - `python3 scripts/workflow.py validate`
- **Any slice touching an embedded machinery file must run `python3 installer/build.py` and leave
  the regenerated `bootstrap_agentic_workspace.sh` for the orchestrator to stage in the same
  commit.** Embedded = `scripts/workflow.py`, `.claude/**` (skills, agents, `settings.json`),
  `CLAUDE.md`, `executors.toml`, `works/templates/**`, `.github/workflows/workspace-ci.yml`,
  `.gitattributes`, `installer/{main,wrapper}.py|sh`, and `installer/payloads/doc_bodies/*.md`.
  **Not embedded**: `README*.md`, `docs/retrofit-guide.md`, `installer/README.md`, `tests/**`,
  `CHANGELOG.md`, `.githooks/**`. So `S1`, `S2`, `S3`, `S5`, `S6` rebuild; `S4` does not.
- From `S4` onward, `bash tests/retrofit_smoke.sh` should also pass; treat it as `S4`'s and `S6`'s
  closing gate. (It is slow — it builds and installs into several temp dirs.)
- Never patch `docs/versions/**` or hand-edit `docs/current/*.md`; durable truth is versioned once,
  at `P15.REVIEW`.
- Leave `works/phases/active/P13`, `P14`, `works/events.jsonl`, and the existing `CHANGELOG.md`
  sections alone.

## Open Questions

- ~~**`AGENTS.workspace.md` for already-retrofitted adopters**~~ — **RESOLVED by `P15.S2`: flagged.**
  It is in `OBSOLETE_MACHINERY` with the other three. See *From `P15.S2`* item 3.
- ~~**Whether to keep the literal `== 30`/`== 31` release pin in the smoke test**~~ (finding 2) —
  **RESOLVED by `P15.S4`: dropped.** The three-way equality stands alone, so there is no literal
  left to disagree with `WORKSPACE_VERSION` and `S6` needs no test edit. See *From `P15.S4`* item 2.
- **NEW (`P15.S2`) — `installer/build.py` only `compile()`s the assembled artifact body (~L171);
  it never executes it.** So `installer/main.py`'s import-time guards and every payload-key lookup
  are invisible to the build. A change that stops embedding a payload while leaving its
  `PAYLOADS[...]` read or its parity `raise` in place passes `python3 installer/build.py`,
  `--check`, **and the pre-commit hook**, and ships an artifact that dies on the first line of
  every install, retrofit, and update. `S2` dodged this only because its plan mandated running the
  built artifact for real. **This is a pre-existing hazard this phase surfaced, not one it
  introduced — do not fix it here.** Candidate deferred job for `P15.REVIEW` to file: *"Make
  `installer/build.py` smoke-execute the assembled artifact (e.g. a fresh install into a temp dir)
  so the build gate catches a broken artifact instead of only a non-compiling one."* Until then,
  **any slice that changes what `main.py` reads out of `PAYLOADS` must run the artifact, not just
  build it** — that includes `S3` and `S5`.
- Nothing else was left unresolved read-only.
