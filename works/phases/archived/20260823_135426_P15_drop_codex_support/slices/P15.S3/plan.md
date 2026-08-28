# Plan — P15.S3: Strip Codex from the contract and Claude skill prose

Scope: `CLAUDE.md`, the **11** `.claude/**` files that mention Codex / `.agents` / `.codex` /
`AGENTS.md`, and the **two installer literals that pin `CLAUDE.md`'s header line**.

Read `works/phases/active/P15/phase.md` first — *What must stay atomic* item 2, and the
cross-slice notes `P15.S1` and `P15.S2` appended.

## The atomic coupling (verified post-S2, current line numbers)

`CLAUDE.md` line 3 is `> Equivalent to \`AGENTS.md\`. If you change workflow rules, update both.`
That exact string is pinned in two places, both confirmed after S2 landed:

- `installer/build.py:59` — `CLAUDE_HDR = "# CLAUDE.md\n\n> Equivalent to \`AGENTS.md\`. …\n\n"`,
  checked in `collect_contract_body()` with `die("CLAUDE.md header changed — update CLAUDE_HDR in build.py")`
- `installer/main.py:460` — `write_text("CLAUDE.md", f"# CLAUDE.md\n\n> Equivalent to …{CONTRACT_BODY}")`

Delete line 3 and its blank line from `CLAUDE.md`; both literals become `"# CLAUDE.md\n\n"`.
All three change in this slice or the build fails. The extracted body must still start at
`## Agent Contract` — verify that, because `collect_contract_body()` slices on the header length.

**S2's standing rule applies here:** `build.py` only `compile()`s the artifact body, so a green
`--check` does not prove the installer runs. This slice changes what `main.py` writes, so it must
**execute the built artifact**, not just build it (see *Validation*).

## `CLAUDE.md` — passage by passage

Line refs are pre-edit; they shift as you go, so work by content.

| Line | Change |
|---|---|
| 3 | Delete the blockquote line + its blank line (with the two literals above). |
| 7 | Drop `` and `.agents/skills/` ``. |
| 13 | **Rewrite, don't delete** — "so they work natively in either tool" → the skills are simply how the workspace is driven. The bullet list drops to two entries (Claude Code, Any agent / CI); keep it a list. |
| 15 | Keep. It stops being "one of two harnesses" and becomes the primary path — adjust any wording that only makes sense as a contrast. |
| 16 | Delete the whole Codex bullet. |
| 21 | "**Both tools** ship…" → the workspace ships them. Delete the Codex automatic-only sentence. "Claude Code defaults to `auto` and **retains** opt-in `gate` and `plan only`" — "retains" reads as a contrast; "supports" is cleaner. Last sentence: drop "in either tool" and "cross-tool" but **keep the upgrade justification** — a pre-v31 workspace can still hold a `ready` slice, so it remains executable as-is. |
| 23 | Tier paths → `.claude/agents/slice-executor-{mid,high}.md` only. For the matrix, **drop the `Claude:`/`Codex:` qualifiers entirely**, not just the Codex half: `economy` is `sonnet@high` / `opus@high`; `flex` is `sonnet@xhigh` / `opus@xhigh`. (Verified against post-S1 `scripts/workflow.py`.) The `mode = "flex"` sentence stands. |
| 25 | Keep "Claude Code dispatches it as a background Agent task"; delete the Codex clause after the semicolon. |
| 27 | `(\`.claude/skills/\`, \`.agents/skills/\`)` → `` (`.claude/skills/design-cowork/`) ``. |
| 65 | "**Codex and either tool's** automatic path write it inline, while **Claude Code's** gated modes copy…" → "the automatic path writes it inline, while the gated modes copy…". |
| 68 | "Claude's gate still does not move; Codex remains automatic-only." → "The gate still does not move." |
| 70 | **The "Narrow Codex design exception" — generalize, do not delete.** See below. |
| 71 | Drop the possessive and the Codex clause: "`plan only` writes an operator-approved `plan.md` and sets the slice `ready`." Keep the rest. |
| 75 | The design hard rule — the largest edit. See below. |
| 76 | Drop `.agents/*` and `.codex/*` from the embedded-machinery list. |
| 114 | Drop "in either tool". Delete the "in another tool … `<noreply@openai.com>`" clause. "or carry over **another tool's** trailer" → "or carry over a trailer from another session" — keep the hygiene rule, lose the contrast. |

### Line 70 — the design exception (decided: generalize)

The rule currently reads as a "Narrow Codex design exception": when a `pending` `co-work` slice
records an approval need and the invocation carries a literal response to it, the orchestrator
may clear and resume that slice inline. It was written for Codex because Codex was
automatic-only — but Claude Code's **default is `auto`**, so it hits the identical situation, and
the mechanism is not Codex-specific. It has no `.claude/**` counterpart, so deleting it removes
the behaviour from the workspace entirely.

**Generalize it:** drop "Narrow Codex design exception" and "the Codex orchestrator", keep the
rule (the orchestrator may clear and resume that same slice inline under `design-cowork`), and
keep both guardrails verbatim — *a bare automatic invocation is never approval*, and *no other
pending gate is relaxed*. Note the decision in `phase.md` so `P15.REVIEW` can challenge it.

### Line 75 — the design hard rule

Currently: shared invariants → "**Claude Code branch:**" → "**Codex branch:**" → "Neither branch…".
Collapse it to a single rule.

- Opening → "Product visual design follows the **`design-cowork` skill**." Drop "harness-native".
- "Shared invariants come first:" has nothing left to be shared *against* — reword (e.g. "The
  invariants:").
- Drop the "**Claude Code branch:**" label and inline that content as the rule body.
- Delete the Codex branch — but **rescue the general prose stranded inside it**:
  *"Approval must be literal; revisions create new immutable superseding rounds; later slices
  verify the running product in a real browser."* That is harness-independent and must survive,
  relocated into the invariants. By contrast, the ImageGen/GPT Image 2 specifics, the
  native-pixel chapter composition, the "prompt-only size/quality wording is advisory" sentence,
  and "it generates without a separate pre-generation confirmation" are Codex-only and go.
- "**Neither branch** may invent visual decisions…" → "**Never** invent visual decisions…".
- **Keep the word `DesignSync` in this rule** — `P15.S4` asserts its presence in the contract.

## The 11 `.claude/**` files

Pure `AGENTS.md` co-mentions — one-line edits, drop the `AGENTS.md` half:

- `.claude/agents/slice-executor-mid.md` (L24, L45) and `slice-executor-high.md` (L24, L46)
- `.claude/skills/do-next-slice/SKILL.md` (L10), `do-whole-phase/SKILL.md` (L10),
  `create-phase/SKILL.md` (L10), `review-phase/SKILL.md` (L16), `parallel-phase/SKILL.md` (L18)

Real content:

- **`.claude/skills/design-cowork/SKILL.md`** (L200-202) — delete the "**Claude Code only.** In
  Codex, DesignSync does not exist…" bullet entirely. The preceding bullet is
  harness-independent and self-sufficient. Nothing else in this file assumes two harnesses; do
  not restructure it.
- **`.claude/skills/explain/SKILL.md`** (L156, L460-461) — delete the "On Codex, `workspace-write`
  blocks outbound network…" paragraph (check the surrounding numbered-step flow still reads),
  and the `(in Codex, use the actual executing model name with <noreply@openai.com>)`
  parenthetical. **This file is vendored** (L11: "Vendored from leetusik/knowledge @ d0c2c38").
  Edit it anyway — it ships in the artifact and the Codex paragraph is now false — and record
  the upstream divergence in `phase.md`.
- **`.claude/skills/retrofit/SKILL.md`** (L27, L31) — describes installer behaviour **S2 just
  changed**. Rewrite against the landed code, not the old text: the installer no longer touches
  `AGENTS.md` at all, so no pointer block and no `AGENTS.workspace.md` sidecar. Read S2's
  `result.md` and `phase.md` notes before writing this.
- **`.claude/skills/update-workspace/SKILL.md`** (L12, L61) — L12's overwrite list must lose
  `.codex/agents/`, `.agents/skills/`, `.codex/config.toml` and match S2's actual installer.
  **L61 is now actively wrong**: it describes a pre-v23 migration mentioning `[codex.low]`, but
  after S1 any `[codex.*]` section is a hard error naming workspace v31. Rewrite it against S1's
  actual error string (read `scripts/workflow.py`). Also mention that `--update` now flags
  `.agents`, `.codex`, `AGENTS.md`, and `AGENTS.workspace.md` as stale.

`.claude/settings.json` and `settings.local.json` are **clean** — no edit.

## Out of scope

`tests/**` (S4), `README*`, `docs/**`, `installer/README.md`,
`installer/payloads/doc_bodies/*` (S5), `WORKSPACE_VERSION` / `CHANGELOG.md` (S6). Touch
`installer/build.py` and `installer/main.py` **only** for the two header literals.

## Validation

- `python3 installer/build.py` then `--check` — both pass.
- **Execute the artifact** (S2's standing rule — this slice changes what `main.py` writes):
  fresh-install into a temp dir under the scratchpad, confirm exit 0, confirm the installed
  `CLAUDE.md` starts with `# CLAUDE.md` followed directly by `## Agent Contract` with no
  `AGENTS.md` blockquote, and confirm `python3 scripts/workflow.py validate` passes there.
- `python3 scripts/workflow.py validate` in this repo passes.
- `grep -rni 'codex\|openai\|gpt-' CLAUDE.md .claude/` — the only permitted hits are the
  generalized design-exception wording if it still names anything, which it should not. Expect
  zero.
- `grep -rn '\.agents/\|\.codex/\|AGENTS\.md' CLAUDE.md .claude/` — zero hits. **Run this
  second grep explicitly**: S2 found that a `codex\|AGENTS` grep alone misses bare `.agents/` /
  `.codex/` path references (that is how `update-workspace` L12/L61 hide).
- `grep -rn 'both tools\|either tool\|cross-tool\|each tool\|another tool' CLAUDE.md .claude/`
  — zero hits. These are the dangling contrasts; they must be rewritten, not left.
- Confirm `DesignSync` still appears in `CLAUDE.md`.

## Notes for `phase.md`

Record: the design-exception generalization and its rationale (flagged for `P15.REVIEW`); the
`explain` skill's divergence from its vendored upstream; the final wording of the design hard
rule; and confirmation that the rescued "approval must be literal…" sentence survived.
