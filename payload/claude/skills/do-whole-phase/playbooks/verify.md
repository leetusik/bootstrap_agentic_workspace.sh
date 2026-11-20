# Playbook: verify (kind `qa`)

**How it usually goes.**
- A qa slice checks behaviour; it does not build it. Use the repo's own verification skill when it ships one; otherwise drive each surface the plan lists yourself.
- Run in the runtime the operations doc's `## Operator Runtime` names, plus the production build when they differ. Absent or `UNFILLED` is `needs_operator`.
- The browser is `playwright-cli`, the agent's own (`.claude/skills/design-cowork/reference/build.md`, *How to call it*). It is never a blocker: install it yourself when it is missing (`npm install -g @playwright/cli@0.1.25`, exactly so: the settings allow that line; then `playwright-cli install-browser chrome-for-testing` if no browser is found). Only what you cannot have (a credential, a sign-in, a paid account) is `needs_operator`.
- Each check proves an observable end state (the saved row, the changed count, the page after the action), never that a page loaded. Prove a match with an expect: `find` exits 0 with no match. Send a secret's `fill` to `/dev/null` and snapshot only after the page moved on.
- Keep the evidence (screenshots, logs) outside every repo's tree, and name its paths in `result.md`.
- A failing check is a finding with its reproduction, written for a fix slice; you do not fix product code here unless the plan says so.
- Stop what you start: `playwright-cli close` (then `playwright-cli list` shows no browser), and every server and container you launched.

**What done proves.** Each check's result with its evidence path, and nothing left running.

**Carve-out.** None beyond the card's.

**Where it may deviate.** A check the plan names that the product cannot reach (the surface moved, a step changed) is recorded as such with what you saw, never skipped silently.
