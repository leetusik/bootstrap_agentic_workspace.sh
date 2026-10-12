# Plan — P32.S6: CHANGELOG v53, the two READMEs and the retrofit guide

Kind `docs`, risk `low` — the **cheap route** (see `## Dispatch` at the end: this is the phase's first live Haiku dispatch). Read `phase.md` first: D1, D3, D4, D5, D7, D8, D9, D13, D14 and every `## Notes for later slices` entry tagged for S6 (H3; S4's names note; S5's CHANGELOG skeleton and baseline note; the retrofit-guide note). Work from this plan's pinned text; where the plan gives replacement text, use it as written, adjusting only to join cleanly with the surrounding sentences.

## Goal

Every operator-facing text outside the versioned docs says what v53 does: the route table replaces the presets, `executor-route` / `record-dispatch` / `dispatch-summary` exist, `/executor-route` replaces `/executor-mode`, the cheap route is on here and opt-in for adopters, `Explore` is the read-only lookup agent, and the migration steps are spelled out. No code changes.

## Files

- `CHANGELOG.md` — expand S5's minimal `## v53 — 2026-10-12` section into a full entry (house style: v52's entry — bold lead per bullet, a **Migration notes** bullet last). Keep the heading S5 wrote; keep every older section untouched.
- `README.md` (Korean) — the executor section (~332–364) and the skill table row for `executor-mode` (~389).
- `README.en.md` — lines ~170–172 (update advice), ~215–218 (the `.claude/` bullet), the command table rows (~430–431), the skill table row (~456), and the executor paragraph (~484–506).
- `docs/retrofit-guide.md` — ~173–180 (the installed surface) and the pre-v31 migration paragraph (~288–297) gains a v53 sentence.

Do **not** touch anything else: no code, no agent files, no skills, no `docs/current` or `docs/versions`, no installer.

## CHANGELOG v53 — the content (expand S5's skeleton; keep its heading line)

Bullets, each with a bold lead:
1. **One executor route table replaces the `economy` / `flex` presets.** Five rows — `high` (`opus @ high`: review, decomposition, the co-work mockup span, any risk but `low`, every second attempt; `design-drafter` follows it), `research` (`opus @ medium`), `mid` (`sonnet @ high`: implementation and fix rated `low`), `cheap` (docs and qa rated `low`; inherits `mid` unless overridden) and `explore` (`haiku @ high`, the read-only lookup agent). `executors.toml` overrides them row by row (`[claude.<row>]`, `model` / `effort`); `sync-agents` writes four agent files from the rows; `executor-mode` is gone.
2. **Model and effort are chosen at dispatch time.** `python3 scripts/workflow.py executor-route <slice_id> [--retry]` prints the deterministic decision (kind first, then risk, then attempt), one `key=value` per line; the orchestrator pins it as a `## Dispatch` section in the slice's `plan.md`, passes `model` and `effort` on the Agent call, and the agent files' frontmatter is only the fallback. `--drafter` and `--explore` resolve the design subagent and the lookup agent; a loopback `ANTHROPIC_BASE_URL` (ocx/Kiro) makes the cheap row fall back to the mid model and `explore` to `sonnet`; `CLAUDE_CODE_EFFORT_LEVEL` / `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` print a warning because they outrank the per-dispatch values.
3. **The cheap route.** Docs and qa slices rated `low` run on Haiku 5.5 at `high` — on in this repository's `executors.toml`, **seeded commented-out** for adopters because the `haiku` alias is Haiku 4.5 on Bedrock, Vertex and Foundry. Unset, the row inherits `mid`.
4. **The instrument.** `record-dispatch <slice_id> --route … --model … --effort … --verdict … [--attempt N] [--duration-ms N] [--tokens N] [--tool-uses N]` appends an `executor_dispatched` event to `works/events.jsonl`; `dispatch-summary [--phase P] [--slice S] [--json]` reads it back by route, model @ effort and kind. The table is tuned from this workspace's own runs.
5. **`Explore`, the read-only lookup agent, and the `Agent` tool in both executor tiers.** `.claude/agents/Explore.md` (Read / Grep / Glob, `haiku @ high`, `omitClaudeMd: true`) overrides Claude Code's built-in Explore in the repo; the orchestrator uses it for planning lookups and executors may hand it bulky read-only reads, upgrading the model per call for a lookup that needs judgment — never `result.md`, `phase.md`, code, validation or the verdict. Executors record `model` and `effort` beside `tier` in the verdict block, and the slice commit's `Co-Authored-By` follows the recorded model.
6. **`/executor-route` replaces `/executor-mode`** (bare: the table and the dispatch summary; with a slice id: its decision). The orchestrator's own effort stays at the session level.
7. **Migration notes.** (a) `sync-agents` refuses a leftover `mode = "…"` line in `executors.toml` — delete it; `flex` was `xhigh` on both tiers, so set `effort = "xhigh"` under `[claude.mid]` and `[claude.high]` to keep it. (b) After `--update`, re-run `python3 scripts/workflow.py sync-agents` (the agent files reset to upstream defaults, now `opus @ high` / `sonnet @ high`). (c) To opt into the cheap route on the Anthropic API, uncomment the `[claude.cheap]` block in `executors.toml`. (d) `--update` flags `.claude/skills/executor-mode/` as stale — remove it by hand. (e) `.claude/agents/Explore.md` overrides the built-in Explore for every session in the repo; in a nested install whose host already has an `Explore.md`, ours is installed renamed (`wf-Explore`) and no longer overrides the built-in, and the rename also rewrites the word "Explore" in the shipped agent bodies. (f) `CLAUDE_CODE_EFFORT_LEVEL`, if set, flattens every row's effort.

## README.md (Korean) — replacement text

Replace the block from the paragraph beginning `실행자는 slice의 위험도(`risk`)에 따라` through the paragraph ending `지금 모드를 보여 줍니다.` (keep the three paragraphs in between about the four `high` triggers, the `risk` vocabulary and escalation, minus the sentence `Haiku는 실행자 티어로 쓰지 않습니다.`) with:

```
실행자는 slice의 종류(`kind`)와 위험도(`risk`)에 따라 엔진의 **라우트 표**에서 한 행이 선택되고, 그
행이 정한 모델과 노력 수준(effort)이 매 dispatch마다 전달됩니다(v53부터). 위험도 표시가 곧 비용 조절
장치입니다 — 대부분의 일은 기본 티어인 `mid`가 맡고, 정말 어려운 일과 `mid`가 한 번 실패한 일만
`high`가 맡습니다(v46부터).

| 행(route) | 기본값 | 실행 에이전트 | 맡는 일 |
|---|---|---|---|
| `high` | Opus@high | `slice-executor-high` | 일 나누기(`DECOMP`), 최종 리뷰(`REVIEW`), 이유를 적어 `risk: high`로 매긴 slice, 그리고 두 번째 시도(에스컬레이션, `mid`가 한 번 실패한 일). 디자인 하위 에이전트 `design-drafter`도 이 행을 따름 |
| `research` | Opus@medium | `slice-executor-high` | 조사(`research`) slice |
| `mid` | Sonnet@high | `slice-executor-mid` | 기본 — `risk: low`인 구현·수정(`fix`) slice. 실제 코드 작성과 여러 파일에 걸친 변경도 포함 |
| `cheap` | `mid` 행을 상속(이 저장소: Haiku@high) | `slice-executor-mid` | `risk: low`인 문서(`docs`)·QA slice — 싼 경로. 설정하지 않으면 `mid` 행과 같음 |
| `explore` | Haiku@high | `Explore` | 읽기 전용 조회(계획 조사, 실행자의 큰 읽기). slice 라우트는 아님 |
```

(then the kept paragraphs: the four triggers; `risk`; escalation) and, replacing the old closing paragraph from `이렇게 나누는 이유는 두 가지입니다.` onward:

```
이렇게 나누는 이유는 두 가지입니다. 오케스트레이터의 컨텍스트가 구현 세부사항으로 채워지지
않아 긴 phase도 끝까지 안정적으로 진행되고, slice마다 새 컨텍스트에서 시작하니 앞 작업의
잔상이 다음 작업을 오염시키지 않습니다. 행별 모델과 노력 수준은 저장소 루트의
[`executors.toml`](executors.toml)에서 `[claude.<row>]` 표로 행마다 덮어쓸 수 있습니다 — 에이전트에게
말하면 수정하고 `sync-agents`로 에이전트 파일에 적용해 줍니다. 프리셋(`economy`/`flex`)은 v53에서
없어졌고, 남아 있는 `mode = "..."` 줄은 삭제 안내와 함께 거부됩니다.
`python3 scripts/workflow.py executor-route`(또는 `/executor-route`)는 현재 라우트 표를,
`executor-route <slice_id>`는 그 slice의 dispatch 결정(행·모델·노력 수준·에이전트)을 보여 줍니다. 모든
dispatch는 `record-dispatch`로 `works/events.jsonl`에 기록되고 `dispatch-summary`가 라우트별로
요약합니다 — 라우트 표는 이 워크스페이스 자신의 실행 기록으로 조정합니다. 싼 경로(`cheap`)는 이
저장소에서는 켜져 있고(Haiku 5.5), 설치 시드에서는 주석 처리되어 있습니다 — `haiku` 별칭이
Bedrock·Vertex·Foundry에서는 Haiku 4.5이기 때문입니다. 실행자는 큰 읽기 전용 조회를 `Explore`(Haiku)
하위 에이전트에 맡길 수 있지만, `result.md`·`phase.md`·코드·검증·판정은 절대 맡기지 않습니다.
```

Skill table row (~389): replace the `executor-mode` row with
`| \`executor-route\` | 라우트 표와 dispatch 요약 확인; \`/executor-route <slice_id>\`로 한 slice의 dispatch 결정 확인 |`

## README.en.md — replacement text

- ~170–172: `… so run \`python3 scripts/workflow.py sync-agents\` after every update to re-apply your per-row overrides.` (drop "selected preset and").
- ~215–218, the `.claude/` bullet: `- \`.claude/\` — the 18 Agent Skills (\`/slash\` commands), the two risk-routed \`slice-executor\` tier subagents (\`.claude/agents/slice-executor-{mid,high}.md\`, dispatched on the model and effort the engine's route table resolves per slice — \`executor-route\` — with per-row overrides in \`executors.toml\` applied to the agent files by \`sync-agents\`), the \`design-drafter\` design subagent (it follows the high row), the read-only \`Explore\` lookup agent on Haiku, and a \`settings.json\` that pre-approves the workflow script.`
- Command table: replace the `sync-agents` row's text with `Apply the \`executors.toml\` per-row model/effort overrides to the four agent files`; replace the `executor-mode` row with three rows:
  `| \`executor-route\` / \`executor-route <slice_id> [--retry]\` | Show the resolved route table and the agent files' sync state, or the dispatch decision for one slice (\`--drafter\`, \`--explore\` for the two agents) |`
  `| \`record-dispatch <slice_id> --route … --model … --effort … --verdict …\` | Record one executor dispatch (duration, tokens, verdict) in \`works/events.jsonl\` |`
  `| \`dispatch-summary [--phase P] [--json]\` | Summarize the recorded dispatches by route, model @ effort and kind |`
- Skill table (~456): `| \`executor-route\` | Show the route table and the dispatch summary, or one slice's dispatch decision (\`/executor-route P1.S2\`) |`
- The executor paragraph (~484–506): keep the sentences about what each tier takes and about escalation; delete `Haiku is never an executor tier.`; replace the sentence `Tier models and efforts are configurable via the repo-root \`executors.toml\` — … and run bare it shows the current mode.` with:

```
Model and effort come from one engine-owned **route table**, resolved per slice at dispatch time:
`high` (opus @ high — review, decomposition, the mockup span, any risk but `low`, every second
attempt), `research` (opus @ medium), `mid` (sonnet @ high — implementation and fix rated `low`),
`cheap` (docs and qa rated `low`; inherits `mid` unless overridden — this repository runs it on Haiku
5.5 at `high`, and the seed ships it commented out because the `haiku` alias is Haiku 4.5 on Bedrock,
Vertex and Foundry) and `explore` (haiku @ high, the read-only `Explore` lookup agent). The repo-root
`executors.toml` overrides rows one by one (`[claude.<row>]`, seed-once — updates never overwrite it),
applied to the agent files with `python3 scripts/workflow.py sync-agents`; the presets are gone, and a
leftover `mode = "…"` line is refused with the migration step. `python3 scripts/workflow.py
executor-route <slice_id>` prints the decision the orchestrator dispatches from (kind first, then
risk, then attempt; `/executor-route` shows the table), every dispatch is recorded with
`record-dispatch` and summarized by `dispatch-summary`, so the table is tuned from this workspace's
own runs; executors may hand bulky read-only lookups to `Explore` but never their `result.md`,
`phase.md`, code, validation or verdict. Workflow skills are
```

(the paragraph then continues `**explicit-invocation only** — …` unchanged).

## docs/retrofit-guide.md — replacement text

- ~173–180: `The installed command surface is complete: 18 Agent Skills under \`.claude/skills/\`, plus the two risk-routed \`slice-executor\` tier subagents, the \`design-drafter\` design subagent and the read-only \`Explore\` lookup agent under \`.claude/agents/\`. \`do-next-slice\` and \`do-whole-phase\` execute automatically by default; \`gate\` and \`plan only\` are opt-in words you add to the invocation, and an existing \`ready\` slice remains executable for upgrade compatibility. Executor dispatch follows the engine's route table (\`python3 scripts/workflow.py executor-route\` shows it), overridden row by row in \`executors.toml\`; the seed ships every row at its default with the cheap route (Haiku for low-risk docs and qa slices) commented out — uncomment it to opt in on the Anthropic API.`
- ~288–297: after the `[codex.*]` sentence add: `Likewise from a pre-v53 workspace: a leftover top-level \`mode = "…"\` line makes \`sync-agents\` abort with \`executors.toml line <n>: the economy/flex presets were retired in workspace v53 — …\`; delete the line (set \`effort = "xhigh"\` under \`[claude.mid]\` and \`[claude.high]\` if you want the old flex behaviour) and re-run \`sync-agents\`.`

## Validation (run all; record each in the verdict block)

1. `grep -n 'economy\|flex\|executor-mode' README.md README.en.md docs/retrofit-guide.md` → no matches except the two migration sentences that name the retired words on purpose (the Korean paragraph and the retrofit-guide v53 sentence); `grep -n 'economy\|flex\|executor-mode' CHANGELOG.md` → only in the v53 Migration notes and in sections `## v52` and older.
2. `grep -c '^## v' CHANGELOG.md` unchanged from before your edit (you added no heading; S5 did), and `grep -m1 '^## v' CHANGELOG.md` prints `## v53 — 2026-10-12`.
3. `python3 scripts/workflow.py validate` → exit 0 (known warnings).
4. `python3 installer/build.py --check` → OK (none of your files is embedded, so no rebuild is needed; if it reports drift you touched a wrong file).
5. `bash tests/retrofit_smoke.sh` — once, in the foreground, as the only command in its Bash call (it checks the CHANGELOG heading order and the Migration notes line); report the count (S5's baseline: 258 PASS / 0 FAIL).
6. Read each edited passage once more in place for broken Markdown tables (pipes, header rows) and for Korean/English sentences that no longer join.

## `result.md` and `phase.md`

- `result.md`: verdict block first — `status`, `tier: mid`, `model` and `effort` **copied from the `## Dispatch` section at the end of this plan**, `summary`, `files_changed`, `validation`, `deviations`, `doc_impact` — then the smoke count.
- `phase.md`: remove the S6 notes you consumed (H3, S4's names note, S5's skeleton note, the retrofit-guide note); add no new notes unless the review needs one; append `## Doc impact`: `operations.md: Installer / retrofit — the v53 migration (mode line refused, sync-agents after update, cheap route opt-in, Explore override and nested rename caveat) is recorded in CHANGELOG v53, both READMEs and docs/retrofit-guide.md (P32.S6)`. Rewrite `## Now` (≤ 15 lines) for the REVIEW: what the phase shipped, that every slice's `## Doc impact` line is in place, the open operator question, and that this slice ran on the cheap route.

## Dispatch

```
slice=P32.S6
phase=P32
kind=docs
risk=low
attempt=1
route=cheap
reason=kind docs rated low
tier=mid
subagent_type=slice-executor-mid
model=haiku
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Haiku 5.5
explore_model=haiku
explore_effort=high
```
