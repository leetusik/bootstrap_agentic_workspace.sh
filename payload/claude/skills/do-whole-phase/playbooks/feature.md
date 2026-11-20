# Playbook: feature (kind `implementation`, and `docs`)

**How it usually goes.**
- Read the code `plan.md` names and the repo's rules files, then change it the way the plan pins. A refactor is a feature whose behaviour must not move: the same checks pass before and after.
- Prove each claim in `## Claims and contracts` with a check you saw fail first (against the old code, or with the guard removed), then pass, in the real runtime: the shell and flags CI uses, the real entry point. Add a claim your change makes that the plan missed; read a contract marked `unread` before you build on it.
- Keep a check as a test only when it guards core behaviour. The plan's bar is the whole bar: add no gate or review round above it. A problem the base already had is one line in `result.md`.
- A user-visible change is driven in `playwright-cli` (`.claude/skills/design-cowork/reference/build.md`, *How to call it*) in the runtime `## Operator Runtime` names, plus the production build when they differ. A missing browser you install yourself; a missing credential, sign-in or paid account, or a runtime section absent or `UNFILLED`, is `needs_operator`. Send a secret's `fill` to `/dev/null`; prove a match with an expect, never `find` (it exits 0 with no match).
- A change to what the code cannot say (how the product is run, a reversed decision) goes to that doc when the plan names it; otherwise one line in `## Now` for the review.

**What done proves.** Each claim failed, then passed; the plan's validation passes; nothing you started still runs.

**Carve-out.** A `docs` slice edits only the docs its plan names; a versioned doc goes through `doc-new-version` (editing the returned `edit_path`) and `rebuild-docs`, on the default stream.

**Where it may deviate.** On the mid row the plan pins the approach: a design decision it did not make, a core invariant it did not rate (persisted state, auth, money, deletion, concurrency) or a shared interface with spread callers is an `escalate`. On the high row, decide, and record the decision in `## Decisions`.
