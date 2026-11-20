# Playbook: review (kind `review`)

The procedure is `.claude/skills/review-phase/SKILL.md`, read by path. What the review never leaves:

- **The boundary:** the product files `phase-scope <P>` prints and the surfaces they feed. Anything outside is an observation (a deferred-job candidate: title, reason, trigger), never a finding.
- **Validate everything first:** each slice's validation commands (the verdict block atop its `result.md`) plus `validate`, then the judgment against `intent.md`, before you branch on a verdict.
- **The code reader is yours to dispatch,** once per phase unless the operator said skip: `subagent_type: code-reader`, model and effort from `executor-route --code`, a blind prompt of repo, base, head, pathspec and the output `topics/code-read.md`, never the plan, a result or the notebook. Rule on each finding in the same span, one line per id under `result.md`'s `## Code reader`: upheld (a finding), rejected (why) or routed.
- **A gated phase** (`acceptance.required: true`): open the running product yourself in the runtime `## Operator Runtime` names and walk the changed surfaces as a first-time user; what you find goes in the walkthrough, never into silent fixes. Route every `## Operator Questions` entry.
- **Each finding gets one outcome:** fix now, note or drop. `changes_requested` only for fix now, with one proposed fix slice per problem class and its risk (high when it repairs work the mid row did).
- **Cross-check** the notebook against every `result.md`: a decision a result records but `## Decisions` lost is a finding. Check that nothing the phase started still runs.
- **A reopened phase's re-review** (its review note reads `team-reported: …` or `operator-reported: …`): the request is the claims to verify.

**Carve-out.** Never edit source. You write `result.md`, the notebook, the PR step's `topics/pr-body*.md` and `topics/pr-details*.md`, and on a pass the two gate sections the skill names. Never run `review-phase`, `accept-gate` or `defer-job`, and never push.

**Fields.** `review_verdict`: `pass` | `changes_requested` | `blocked`; `walkthrough` (a gated phase, else `none`); `pr_bodies` (or `none`); `code_read`: the file and upheld / rejected / routed counts, `n/a (0 product files)` or `skipped (operator: "<words>")`; `explain`: `not written — run /knowledge:explain P<N> for a document, or ask it for a book`.
