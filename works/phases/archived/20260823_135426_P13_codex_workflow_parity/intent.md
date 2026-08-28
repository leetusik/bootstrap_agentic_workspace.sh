# Intent — P13

- Captured at: 2026-08-13T15:28:01+09:00
- Origin: operator

## Original Input (verbatim)

> This bootstrap_agentic_workspace.sh is for both codex and claude code. but it's tillted to claude code.
>   you make codex works well as well as the claude code. $create-phase . do-whole-phase re available,
>   since it's auto mode by default, its not matter if you can enter plan mode or auto mode by yourself.
>   just disable the gate mode on the codex. and design cowork, you should suggest replacement of claude
>   design. and the executor tier, all of stuff.

## Confirmed Intent (refined + clarified)

Make Codex a first-class orchestrator across all non-visual workspace workflow machinery. Ship and align applicable command skills, including `create-phase` and `do-whole-phase`; support automatic execution only in Codex, with both `gate` and `plan only` unavailable; and achieve parity across executor tiers, routing, escalation, configuration, commit attribution, contracts, installer payloads, documentation, validation, and tests. Audit the complete workspace for Claude-only assumptions rather than limiting the work to the examples named in the request.

## Clarifications Resolved

- Q: Should Codex retain `plan only`, or should it be disabled with `gate`? — A: Only automatic mode remains.
- Q: Should this be one phase or may it be split? — A: Two or more phases are allowed.
- Q: Is the proposed two-phase split—core workflow parity followed by the visual-design cowork replacement—correct? — A: Confirmed.

## Notes

- This phase covers non-visual workflow parity. The Codex visual-design cowork replacement is isolated in P14.
