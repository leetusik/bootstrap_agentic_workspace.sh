# Plan — P15.S5: Strip Codex from READMEs, guides, and shipped doc bodies

Six files:

- `README.md` (Korean, 256 lines)
- `README.en.md` (English, 505 lines)
- `docs/retrofit-guide.md` (282 lines)
- `installer/README.md` (106 lines)
- `installer/payloads/doc_bodies/architecture.md`
- `installer/payloads/doc_bodies/operations.md`

Read `works/phases/active/P15/phase.md` first, including the `P15.S1`–`P15.S4` cross-slice notes.

## This is not a find-and-delete pass

Two things make it more than that.

**First, several passages are now *actively wrong*, not merely stale** — they document behaviour
that S1–S3 changed, and an adopter following them would be misled or harmed. Fix these on
their merits, not by deleting the Codex word:

1. **`docs/retrofit-guide.md` L117-130 (highest severity).** It promises retrofit appends a
   marker block to your `AGENTS.md` and writes an `AGENTS.workspace.md` sidecar. After S2 the
   installer leaves a repo's own `AGENTS.md` **byte-identical** and writes no such sidecar.
   This is the guide's core safety promise describing a mutation that no longer happens. The
   `CLAUDE.md` half (marker block + `CLAUDE.workspace.md`) is still exactly right — verify
   against `installer/main.py` `_merge_contract` before rewriting.
2. **`docs/retrofit-guide.md` L253-255 (actively harmful).** The manual-fallback instructions
   tell the operator to hand-copy `.agents/`, `.codex/`, and `AGENTS.workspace.md` into their
   repo. Those paths no longer exist in a staged workspace, and following this literally
   creates exactly the four paths `--update` now flags as stale.
3. **`docs/retrofit-guide.md` L88** lists `.codex/config.toml` as a managed skip-if-present file.
   No longer written.
4. **`installer/README.md` L44 and L96** document a build safety check
   `assert CLAUDE.md == AGENTS.md` that no longer exists. **Re-read `installer/build.py` and
   describe the checks that are actually there** (the `compile()`, the `sh -n`, the
   heredoc-collision check, `EXPECTED_SKILL_COUNT`, and the `CLAUDE_HDR` prefix test).
5. **`installer/README.md` L66-70** describes the payload inventory as "17 matching
   Claude/Codex packages, every Codex package has metadata". `collect_live_payloads()` now
   globs `.claude/skills/*/SKILL.md` only. **`EXPECTED_SKILL_COUNT = 17` survives — keep the
   doc asserting 17 is enforced; do not go vague.**
6. **`installer/README.md` L83, L85** document `FIXED_LIVE_FILES` as containing the two
   `.codex/agents/*.toml` and `.codex/config.toml`. Check the real constant and match it.
7. **`installer/README.md` L74-76** claims release validation pins the Claude design-cowork body
   at Git blob `0e3a1766…`. **No such check exists anywhere in the live tree** — it survives
   only in P14 phase history. Delete the claim; do not try to "fix" it.
8. **`README.en.md` L496-497**, a Contributing house rule telling contributors to keep
   `CLAUDE.md` and `AGENTS.md` in sync. Instructs editing a deleted file.
9. **Broken links:** `[AGENTS.md](AGENTS.md)` at `README.md` L249 and `README.en.md` L31-32,
   L172, L496 — already 404 on `main`.
10. **The model matrices** (`README.md` L165-168, L183-184; `README.en.md` L328-332) name Codex
    tiers that `executors.toml` now rejects outright with S1's v31 hard error.

**Second, removing the Codex half leaves dangling contrasts** that must be rewritten, not cut.
English: "both tools", "cross-tool by design", "per-tool", "for each tool", "Claude Code only",
"neither Claude Code nor Codex", "its own … same shared rules", "the next *tool*", "switching
tools never means switching conventions", "harness-specific", "reconcile the two routing
contracts". Korean (the file uses its own constructions, not `양쪽`/`두 도구`):
`Claude Code와 Codex 어디서든` (L12), `Claude Code나 Codex로` (L75), `Claude Code 전용:` (L95 —
becomes meaningless once L98-99 go), `두 경로 모두` (L109), `도구를 바꿔도` (L124),
`Claude Code와 Codex에 모두 있고` (L129), `또는 다른 도구가` (L236).

Known false positives — **leave alone**: `installer/README.md` "Both policy files" (CI +
`.gitattributes`), `README.en.md` L316 / `operations.md` L51 "you do not need both" (two
`/explain` namespaces), `README.en.md` L168 "Both `--flag value` and `--flag=value`", L360
"Both name the opt-in command", and L466's "**Cross-tool skills**" heading in *Related /
inspired by*, which describes someone else's project, not this one.

## Structural blocks to redraw

- **`README.en.md` L170-183 "What gets created"** — bullets 1 and 3 (contract pair; the
  `.claude/` + `.agents/` mirroring with per-tool executor tiers and `.codex/config.toml`).
  Bullets 2, 4, 5 are clean.
- **`README.en.md` L387-417 project-structure ASCII tree** — L391's `CLAUDE.md / AGENTS.md`
  line, and delete the `.agents/skills/` line plus the whole `.codex/` subtree (L410-413).
  Box-drawing edit: confirm `└──` still lands on `.github/`. There is a pre-existing
  one-space misalignment on `│   │   └── archived/` — not this slice's job either way.
- **`README.md` L162-168 executor tier table** — the `Claude / Codex (economy)` and
  `Claude / Codex (flex)` headers collapse to `economy` / `flex`, and each `X / Y` cell to `X`.
  Ground truth (post-S1 `scripts/workflow.py`): `economy` = sonnet@high / opus@high,
  `flex` = sonnet@xhigh / opus@xhigh. The prose at L183-184 must match, and so must the
  English counterpart at `README.en.md` L328-332.
- **`README.md` L101-109 / `README.en.md` L214-222 visual-design sections** — both are mostly
  the Codex ImageGen path with a trailing "Claude Code keeps its own path" sentence. Rewrite
  each as a single Claude Design + DesignSync paragraph. **These two must say the same thing in
  two languages** — author the English first, then the Korean from it.
- **`docs/retrofit-guide.md` L145-162** — the 17+17 inventory and the harness-specific visual
  paragraph. Salvage: 17 Claude skills under `.claude/skills/`; `executors.toml` selection
  (`economy` default, upstream seed selects `flex`) — both still accurate; the `--update`
  refresh/preservation semantics; retrofit skips operator-owned files.
- **Small fenced blocks** that pair a `/cmd # Claude Code` line with a `$cmd # Codex` line
  (`README.en.md` L146-149, `docs/retrofit-guide.md` L47-48): drop the Codex line, and then the
  now-pointless `# Claude Code` comment too.

## Decided: add the v31 migration note

The brief raised whether adopter-facing docs should cover the migration. **Yes — add a short
note to `docs/retrofit-guide.md`'s "Updating after adoption" section** (~L231-240): `--update`
flags `.agents`, `.codex`, `AGENTS.md`, and `AGENTS.workspace.md` as stale machinery to remove
manually, never deletes them, and a leftover `[codex.*]` table in `executors.toml` is now a hard
error. This is the operator's headline deliverable and adopters read the guide, not the
CHANGELOG. Keep it to a few sentences — `P15.S6` writes the fuller Migration notes.

## Bilingual discipline

The two READMEs are **not** structurally parallel (256 vs 505 lines; the English has a TOC,
"What is this?", an options table, "What gets created", the skills table, the project tree,
Related, and Contributing that the Korean lacks; the Korean has the tier table and a short
command subset the English states as prose). Edit English-only sections freely. The facts that
**must** agree in both: the tagline, the retrofit/update skill invocations, which tool to open
the directory in, the execution-mode paragraph, the visual-design paragraph, the executor model
matrix, the skill count (17), the parallel-phase pointer, and the contract file name.

## Rebuild and run

The two doc bodies are **embedded** — they seed a fresh workspace's `docs/current/`. So this
slice must run `python3 installer/build.py` and leave the regenerated artifact for the
orchestrator. And per S2's standing rule, `build.py` only `compile()`s: **actually run the built
artifact** into a temp dir under the scratchpad and confirm the produced
`docs/current/{architecture,operations}.md` match the edited sources.

## Out of scope

`CHANGELOG.md` and `WORKSPACE_VERSION` (S6). `docs/versions/**` (immutable) and
`docs/current/**` (generated — `P15.REVIEW` owns them; a mismatch against the edited doc bodies
until the review regenerates is expected, not a bug). `tests/**` (S4, landed). `docs/README.md`
is clean — no edit.

## Validation

- `python3 installer/build.py`, then `--check` — both pass.
- Fresh-install the artifact into a temp dir; diff the produced
  `docs/current/architecture.md` and `operations.md` against the edited payload sources.
- `python3 scripts/workflow.py validate` passes; `bash tests/retrofit_smoke.sh` stays green
  (S4 left it at 115 PASS / 0 FAIL — it must not regress).
- `grep -rn '\.agents\|\.codex\|AGENTS' README.md README.en.md docs/retrofit-guide.md
  installer/README.md installer/payloads/doc_bodies/` — zero hits, except the deliberate v31
  migration note naming the paths to remove.
- Dangling-contrast grep over the same six files for the English phrases listed above — zero.
- Every remaining `[...](...)` link in both READMEs resolves to a path that exists.
- **A repo-wide `grep -ri codex` will still return hits** — `CHANGELOG.md`, two `.claude/skills`
  files, `installer/main.py`'s `OBSOLETE_MACHINERY` comments, `scripts/workflow.py`'s rejection
  strings, `docs/current/**`, `docs/versions/**`, `works/**`. That is correct. Do not treat a
  non-zero repo-wide grep as failure.

## Notes for `phase.md`

Record: which "actively wrong" items you fixed and how you verified the replacement against the
real code; the final wording of the executor matrix in both languages; that the v31 migration
note landed in the retrofit guide (so S6 does not duplicate it verbatim); and any link you had
to repoint.
