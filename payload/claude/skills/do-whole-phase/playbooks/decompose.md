# Playbook: decompose (kind `decomposition`)

**How it usually goes.**
- **Finish line first:** write the walkthrough the phase is judged by, `topics/walkthrough.md`, one line each: you can do X, and Y proves it. The slices build against it; the review runs it.
- **Settle by a run** what a throwaway run can settle before you cut. What only later work can teach becomes a `research` slice (`--risk high`) and a `<P>.DECOMP2` ordered after it.
- **Cut few big slices**, each verifying its own work; no QA slice by default. `--risk low` is the norm; `high` needs a named trigger (open design, a core invariant, an unlocated root cause, a wide blast radius), named beside the slice.
- Create bare folders with `new-slice --phase <P> --slice <P>.S<n> --name "…" --kind … --risk … --order … --depends-on …`; never pre-fill a `plan.md`. A fractional `--order` (`4.5`) inserts between neighbours. Pass `--depends-on <id>` per real dependency or `none`; never on `DECOMP2`, `REVIEW` or a `co-work` slice (`set-slice-deps` fixes one already cut). Two slices may run together only when no dependency joins them and their sets (files, regenerated files, numbered sequences, runtime resources) are disjoint.
- Write `topics/breakdown.md` whole: `## Passes`, `## Estimate` (time from `dispatch-summary`'s `means`, never session-$), a join-rebuilt artifact with its rebuild command if any, and one `## <slice id>` block each (goal, set, risk and trigger, `spends money: no` or `yes, ~$X via <service>`, depends on). Add one `Breakdown (<pass>): …` gist line to `## Decisions`.
- A design phase runs in the plan's style (`build-after`, `design-only`, `paired`): record the build inventory and each co-work slice's one job with its critique level (`off | critic | critic+judge`); a `co-work` slice is `--kind co-work --risk high` and never carries product code.

**What done proves.** `validate` passes and `python3 scripts/workflow.py parallel-plan <P>` prints the rounds.

**Carve-out.** `new-slice` and `set-slice-deps`, for this phase only.

**Fields.** `parallel`: the rounds `parallel-plan` printed; for a chain, why, and what would unlock it.
