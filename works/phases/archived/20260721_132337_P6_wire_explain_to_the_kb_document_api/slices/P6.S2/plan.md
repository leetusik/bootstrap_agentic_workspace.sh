# P6.S2 — Plan (Sync updated /explain skill to ~/.claude/skills/explain)

## Context

Last middle slice of P6 (S1 done and committed as `de71eba`, v4 shipped). P6.S2
(implementation, risk **low** → `slice-executor-high`) performs the single
operator-authorized outside-repo write from `intent.md`: copy the updated Claude-copy
`.claude/skills/explain/SKILL.md` (v4: API-first save path) over
`~/.claude/skills/explain/SKILL.md`, so the user-level `/explain` the operator invokes
daily matches the repo. Never commit outside this repo (`~/.claude` is not a repo; the
only in-repo changes are works/ bookkeeping).

## Pre-verified facts (orchestrator, read-only)

- `~/.claude/skills/explain/` contains exactly one file, `SKILL.md` (6069 bytes, from
  10:51 today) — nothing else to reconcile.
- **Pre-existing description drift, surfaced for approval:** beyond the expected v4
  content delta, the user-level copy's frontmatter `description` (line 3) has different
  trigger-phrase wording than the repo copy ("/explain", "write this up", …, "make an
  educational md" vs the repo's "(explain and document, write this up, document what we
  just discussed)"). The straight copy **normalizes the description to the repo wording**
  — consistent with intent's "so the user-level /explain … matches", so the plan proceeds
  with a byte-identical sync. (If the user-level wording was a deliberate tweak worth
  keeping, that belongs in the repo copy via a later slice — not in a divergent user copy.)

## Executor steps

1. `cp .claude/skills/explain/SKILL.md ~/.claude/skills/explain/SKILL.md`
2. Verify byte-identical: `cmp .claude/skills/explain/SKILL.md ~/.claude/skills/explain/SKILL.md`
   → exit 0, no output.
3. Sanity: the synced copy's `allowed-tools` includes the two new Bash rules
   (`curl -sS --max-time 5`, `python3 -c`) and step 5 reads "Save via the KB document API".
4. Write `result.md`; append a one-line cross-slice note to `phase.md` (sync done +
   description drift normalized). No Doc-impact lines — the user-level copy is outside
   durable repo truth (S1 already recorded the doc impacts).

## No pending handoff (recommendation)

Intent offered an operator-run end-to-end `/explain` validation via `pending`. S1's live
smoke already exercised the skill's own spelled commands against the real API (201, 409,
cleanup verified), so S2 completes without a `pending` stop; the operator's next natural
`/explain` run is the real-world confirmation, and the fallback path keeps any surprise
non-fatal.

## Orchestrator after `done` verdict

`finish-slice P6.S2` → `validate` → commit (works/ bookkeeping only:
`chore(explain): sync v4 skill to user-level ~/.claude/skills (P6.S2)`) → plan P6.REVIEW.
