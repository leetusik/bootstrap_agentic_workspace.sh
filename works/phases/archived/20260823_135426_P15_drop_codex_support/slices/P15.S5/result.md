# Result — P15.S5: Strip Codex from READMEs, guides, and shipped doc bodies

All six files edited. The two embedded doc bodies were rebuilt into the artifact and verified by a
**real fresh install**, not just by `build.py`. Smoke test unchanged at 115 PASS / 0 FAIL.

## Files changed

| File | What changed |
| --- | --- |
| `README.en.md` | English source of truth for the shared paragraphs; ~20 passages |
| `README.md` | Korean; the shared paragraphs authored from the English |
| `docs/retrofit-guide.md` | 3 actively-wrong passages fixed + the decided v31 migration note |
| `installer/README.md` | 4 actively-wrong passages fixed against `build.py` |
| `installer/payloads/doc_bodies/architecture.md` | repo-shape lines |
| `installer/payloads/doc_bodies/operations.md` | `explain` location + the Codex sandbox caveat |
| `bootstrap_agentic_workspace.sh` | rebuilt (the two doc bodies are embedded) |

## The ten "actively wrong" items, and how each replacement was verified

1. **`docs/retrofit-guide.md` Tier 3 contract merge (highest severity).** The `AGENTS.md` half of
   the promise is gone. Verified against `installer/main.py:214 _merge_contract` — it is reached
   only for `path == "CLAUDE.md"` (`_retrofit_handle`, L249), writes exactly one sidecar
   (`CLAUDE.workspace.md`), and its marker block text is now quoted **verbatim from the code**
   (the old guide quoted a block the installer no longer writes). Added a blockquote stating the
   new positive promise — *your `AGENTS.md` is never touched, retrofit and `--update` leave it
   byte-identical* — which is S2 finding 2 and is enforced by S4's sha pin in the smoke test.
   Deliberately did **not** claim this for a fresh install: a fresh install into a directory
   holding `AGENTS.md` is still rejected by the emptiness guard unless `--force-empty-ok`
   (S2 finding 1), so the byte-identical claim is scoped to retrofit + update.
2. **Manual fallback (actively harmful).** The copy list no longer names `.agents/`, `.codex/`, or
   `AGENTS.workspace.md` — following it literally would have created three of the four paths
   `--update` now flags as stale. It now reads `scripts/workflow.py`, `.claude/`, `executors.toml`,
   `docs/`, `works/`, and — conditionally — `CLAUDE.workspace.md`.
3. **`.codex/config.toml` removed from the Tier-1 skip-if-present list.** Cross-checked against
   `MANAGED_FILES` / `MANAGED_DIRS` in `installer/main.py:74-88`: the tier-1 set is the skills, the
   two `.claude/agents/slice-executor-*.md`, `executors.toml`, `works/templates/*`, `docs/README.md`.
4. **`installer/README.md` build safety checks.** The `assert CLAUDE.md == AGENTS.md` claim is
   replaced by the checks actually in `installer/build.py`: `compile()` of the assembled body
   (L138), the heredoc-delimiter collision scan (L141-143), `sh -n` (L157-167), the
   `EXPECTED_SKILL_COUNT` assertion (L88-89), and the `CLAUDE_HDR` prefix test in
   `collect_contract_body()` (L95-96).
5. **Payload inventory.** Now describes `collect_live_payloads()` as it is: `.claude/skills/*/SKILL.md`
   globbed from disk, **17 asserted** (`EXPECTED_SKILL_COUNT` in *both* `build.py` and `main.py`, so
   the doc says both must move together — per S2 finding 5). No vagueness introduced.
6. **`FIXED_LIVE_FILES`.** The `.codex/agents/*.toml` and `.codex/config.toml` entries dropped;
   the list now matches `build.py:44-57` exactly.
7. **The `0e3a1766…` blob pin deleted, not "fixed".** Confirmed no such check exists anywhere in the
   live tree (`grep -rn '0e3a1766'` over the repo excluding `works/` returns nothing).
8. **`README.en.md` Contributing house rule.** "Keep `CLAUDE.md` and `AGENTS.md` in sync" instructed
   editing a deleted file. Replaced with the rule a contributor to *this* repo actually needs: rebuild
   `bootstrap_agentic_workspace.sh` with `python3 installer/build.py` in the same commit as any
   machinery edit, `--check` must pass, register `.githooks` once. (Taken from `CLAUDE.md`'s
   upstream-only hard rule.)
9. **Broken links.** All four `[AGENTS.md](AGENTS.md)` links removed (`README.md` L249;
   `README.en.md` L31-32, L172, L496). A script re-resolved **every** relative markdown link in both
   READMEs afterwards — 43 links, all exist.
10. **Model matrices.** Both languages now carry `economy` = sonnet@high / opus@high and
    `flex` = sonnet@xhigh / opus@xhigh, read off `scripts/workflow.py:50-59` (post-S1) and
    cross-checked against `executors.toml`'s own comment block.

## Dangling contrasts rewritten (not cut)

English: "cross-tool by design" → **"One command surface"** (skills are native Claude Code; the same
operations are always reachable as `python3 scripts/workflow.py …` from any shell, incl. CI);
"hand-offs between tools" → "between sessions"; "the next *tool*" → "the next *session*";
"switching tools never means switching conventions" → "the conventions belong to the repo, not to a
chat"; "Both tools delegate" → "The orchestrator delegates"; "equivalent per-tool routing contracts"
→ a single contract line; "Claude Code only" on `/do-whole-phase gate` → replaced by a sentence
saying automatic is the default and `gate` / `plan only` are opt-in words.

Korean: all seven listed constructions rewritten (`Claude Code와 Codex 어디서든`, `Claude Code나
Codex로`, `Claude Code 전용:`, `두 경로 모두`, `도구를 바꿔도`, `Claude Code와 Codex에 모두 있고`,
`또는 다른 도구가`), plus one the plan did not list: L158 `Claude Code에서 gate를 고른 경우에만`
lost its now-redundant tool qualifier.

Known false positives left alone, as instructed: `installer/README.md` "Both policy files";
`README.en.md` "you do not need both", "Both `--flag value` and `--flag=value`", "Both name the
opt-in command"; `operations.md` "you do not need both"; and the **Cross-tool skills** heading in
*Related / inspired by* (it describes wshobson/agents, not this project).

## Structural blocks redrawn

- `README.en.md` "What gets created": bullets 1 and 3 rewritten (single contract; `.claude/` alone,
  with the two tier subagents and `settings.json`). Bullets 2, 4, 5 untouched.
- `README.en.md` project tree: `CLAUDE.md / AGENTS.md` → `CLAUDE.md` (comment column re-aligned to
  the existing 35-char gutter); the `.agents/skills/` line and the whole `.codex/` subtree deleted;
  `└──` confirmed still on `.github/`. The `.codex/agents/` comment's one useful fact
  ("economy/flex models from executors.toml") was **salvaged onto** the `.claude/agents/` line rather
  than lost. The pre-existing one-space misalignment on `│   │   └── archived/` was left as found.
- `README.md` tier table: headers collapsed to `economy` / `flex`, each `X / Y` cell to `X`.
- `docs/retrofit-guide.md` inventory + visual paragraphs rewritten; the four salvage items the plan
  named (17 Claude skills, `executors.toml` selection, `--update` refresh/preservation, retrofit
  skips operator-owned files) all survive.
- Small fenced blocks: `README.en.md` `/create-phase` and `docs/retrofit-guide.md` `/retrofit` are
  now one line each with the now-pointless `# Claude Code` comment dropped.

## The v31 migration note (decided in the plan — it landed)

Added as a bolded paragraph at the end of `docs/retrofit-guide.md` § *Updating after adoption*:
`--update` flags `.agents`, `.codex`, `AGENTS.md`, `AGENTS.workspace.md`; it never deletes; an
`AGENTS.md` you maintain for other tools is yours to keep; and a leftover `[codex.*]` table is a
hard error, quoted verbatim from `scripts/workflow.py`.

**One correction against the code while writing it.** The first draft said the `[codex.*]` table
"aborts every workflow command". That is false: `validate` wraps the executor-tier check in
`try/except (SystemExit, Exception)` (`scripts/workflow.py:733-743`) and downgrades it to a
*warning*. Only `sync-agents` hard-fails. The shipped sentence says exactly that.

## Validation

| Command | Result |
| --- | --- |
| `python3 installer/build.py` | pass — wrote 322756 bytes |
| `python3 installer/build.py --check` | pass — artifact in sync |
| `python3 scripts/workflow.py validate` | pass — `Workflow validation passed.` |
| `bash tests/retrofit_smoke.sh` | pass — **115 PASS / 0 FAIL**, no regression from S4 |
| fresh install of the built artifact into a scratch dir | pass — see below |
| `grep -rn '\.agents\|\.codex\|AGENTS' <the six files>` | only the deliberate v31 note + the "your `AGENTS.md` is never touched" promise |
| dangling-contrast grep (English phrases + `$cmd` invocations) over the six files | only the documented `Cross-tool skills` false positive |
| every relative markdown link in both READMEs | 43/43 resolve |

**The fresh-install check** (per S2's standing rule that `build.py` only `compile()`s):
installed the rebuilt artifact into a scratch dir, then asserted the produced
`docs/current/{architecture,operations}.md` each contain the edited payload source **verbatim**
after `__PROJECT_NAME__` / `__PROJECT_SUMMARY__` substitution, under generated frontmatter only.
Both matched. The installed root is `.claude .gitattributes .github CLAUDE.md docs executors.toml
scripts works` — no `AGENTS.md`, no `.agents`, no `.codex`; `grep -ri 'codex\|AGENTS.md'` over the
installed `docs/` returns nothing; `validate` passes and `sync-agents --check` reports
`mid sonnet @ xhigh` / `high opus @ xhigh`, `agent files in sync`.

**Artifact Codex count: 19 → 14**, exactly the floor S3 predicted. The 5 that left were the doc
bodies. The remaining 14 are S1's two rejection strings, S2's four `OBSOLETE_MACHINERY` comments
(+ the `flag_obsolete_machinery` comment), and S3's two `.claude/**` prose hits.

## Deviations from `plan.md`

1. **One extra sentence in `installer/README.md`** beyond the five checks the plan enumerated: a
   bolded note that `build.py` only `compile()`s and never runs the artifact, so a change to what
   `main.py` reads out of `PAYLOADS` needs a real install to verify. Rationale: the plan asked me to
   "describe the checks that are actually there", and the boundary of those checks is the part a
   contributor is most likely to get burned by (it is `phase.md`'s open hazard). This **documents**
   the limitation; it does not fix it, so the deferred job `P15.REVIEW` may still file stands.
2. **One un-listed Korean contrast fixed** (`README.md` L158, above).
3. **Not done, deliberately:** `docs/retrofit-guide.md`'s Troubleshooting row "the only intended
   modification is the additive `.claude/settings.json` merge and the marked `CLAUDE.md` section"
   omits the `.gitattributes` line-merge (S4 pins the modified list as
   `.claude/settings.json,.gitattributes,CLAUDE.md,`). That inaccuracy is **pre-existing and
   unrelated to Codex**, so it was left alone and recorded in `phase.md` for `P15.REVIEW`.

## Doc impact

One line appended to `phase.md`'s *Doc impact* list (adopter-facing docs are not durable
`docs/current/*` truth, so this is a small note): the shipped `architecture` / `operations` seed
bodies are single-harness now. No `doc-new-version` run — that is `P15.REVIEW`'s job.
