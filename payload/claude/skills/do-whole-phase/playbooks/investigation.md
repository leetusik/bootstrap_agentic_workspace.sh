# Playbook: investigation (kind `research`)

**How it usually goes.**
- Findings only: **write no product code.** What you learned is the deliverable.
- Settle by a run: a question a throwaway run can answer is answered by the run (read the code, probe the engine, run an experiment), never argued. Delete each probe before you finish. Search the web when the plan says to, citing each external contract with its URL and the date you read it.
- Put the findings **where the next slice reads them**, in `phase.md`: what they settle in `## Decisions`, what a later slice must not trip over in `## Notes for later slices` (tagged `**(from <slice>, for <slice>)**`), what only the operator can answer in `## Operator Questions`, and what they mean for the work ahead in `## Now`. Each is a gist line; long detail goes to `topics/<slug>.md` behind it. A finding left only in `result.md` or in your context is lost.
- `result.md` is the log: what you tried, the dead ends, the commands and their output. It points at the notebook by path instead of restating it.

**What done proves.** Every question the plan asks is answered by a run or a cited source, or named as still open and why.

**Carve-out.** Throwaway probes outside the product tree; no change ships.

**Where it may deviate.** If the findings need a code change, that is the next slice's: say so in `## Now`. A `DECOMP2` usually follows to re-cut the remaining work: write for it, and when the findings change nothing about the breakdown, say that plainly (no re-cut needed).
