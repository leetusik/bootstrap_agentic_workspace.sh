# Playbook: fix (kind `fix`)

**How it usually goes.**
- A fix repairs a whole **problem class**, never one finding: every input or state that fails for the same reason. Start from the plan's case list (its acceptance matrix) and add any case of the class it missed.
- Reproduce first: each case runs red before your change, in the real runtime (the shell and flags CI uses, the real entry point). A case you cannot make fail is not yet understood.
- Repair at the root, by the correction ladder: in product code first, then a type or lint, then a test or check, and only last in a rule file.
- Then each case runs green. Keep one tiny test per class when it guards core behaviour.
- Change nothing beyond the class. A problem the base already had is one line in `result.md`, never work you take on.
- A user-visible case is driven in `playwright-cli` in the runtime `## Operator Runtime` names, as `feature.md` says.

**What done proves.** Every case of the class, each with its result in `result.md` (red before, green after); a case still failing is not `done`.

**Carve-out.** None beyond the card's.

**Where it may deviate.** The root cause is not where the plan located it, or the class reaches a core invariant: on the mid row that is an `escalate` with what you found (files, the failing command and its output); on the high row, follow the cause and say so under `deviations`. A class that comes back a third time is a scope question for the operator (`## Operator Questions`), not a fourth fix.
