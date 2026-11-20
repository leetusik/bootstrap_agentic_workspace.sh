# Playbook: wave (read when `plan.md` carries `## Wave`)

Slices run together in one checkout. `## Wave` names your declared set, the slices beside you with their sets, each finished slice whose commit still waits, and the join-rebuilt artifact, if any. On top of your kind's playbook:

- **Write no `phase.md`.** Return the entries you would have written in a `notebook` field of your verdict, by section (Decisions, Notes for later slices, Operator Questions, Now), so also in `result.md`'s verdict block, where a resumed orchestrator finds them; the orchestrator writes them and numbers the questions. Keep each entry gist-sized; long material goes in a new `topics/<slug>.md` of your own, behind a gist line.
- **Run no engine command that writes**, every carve-out included; `check` and `section` reads are fine.
- **Edit only your declared set.** Any other file you need, in a sibling's set, a waiting commit's set or no set, means the declaration was wrong, and a stronger row would hit the same wall: return `needs_operator` naming the file and the slice whose set or commit holds it. Your commit stages your set as the tree has it, so an edit outside it lands in another slice's commit or in none.
- **Regenerate only the generated files in your own set**, never the join-rebuilt artifact: the orchestrator rebuilds it once the wave drains.
- **Run only the checks scoped to your set.** List each whole-tree check you left out (a full suite, a whole-project typecheck or build, a check the repo's rules say must run alone) in `validation` as `deferred: whole-tree`; the review runs them. A failure that traces to a file outside your set is a sibling's work in flight: report it, never fix it.

**Fields.** `notebook`: your entries by section.
