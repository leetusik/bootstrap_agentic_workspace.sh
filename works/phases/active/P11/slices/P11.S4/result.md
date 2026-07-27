# P11.S4 result — Correct the README explainer claims after auto-explain removal

## What was done

Applied the four exact string replacements specified in `plan.md`, all in `README.en.md`. Every OLD
block matched the file verbatim before editing (line breaks and `>` blockquote prefixes included), so
no improvisation was needed and nothing else was touched.

1. **Review gates bullet** (`:46-48`) — dropped the "files a phase explainer into your KB" claim,
   replaced with "checks it against the phase's objective and consolidates its doc versions. A verdict
   short of `pass` stops there and hands its findings back."
2. **Knowledge blockquote opening** (`:274-276`) — reframed explainers as produced on demand via
   `/explain`, not by the review; a passing review now "simply reports that none was written."
3. **Knowledge blockquote REST sentence** (`:280-281`) — "a passing review auto-saves the explainer"
   became "`/explain` saves via plain REST"; dropped the now-inapplicable "(gracefully skipped when the
   KB is absent)" clause since the sentence no longer describes a review-time action.
4. **Tier paragraph's review description** (`:296-298`) — replaced "consolidating its doc versions, and,
   on a pass, producing the phase explainer via the knowledge plugin's explain skill" with "validating
   the phase and — only on a pass — consolidating its doc versions; a `changes_requested` or `blocked`
   verdict stops there and hands the findings back."

The Codex caveat and Alternative (Claude Code plugin) paragraphs (`:284-291`) were left untouched, as
directed — both remain accurate for an operator-run `/explain`.

## No rebuild, no version bump, no CHANGELOG entry

`README.en.md` is not embedded machinery (absent from `FIXED_LIVE_FILES` in `installer/build.py`), so
per the plan this slice made no changes to `installer/`, `bootstrap_agentic_workspace.sh`,
`WORKSPACE_VERSION`, or `CHANGELOG.md`. `python3 installer/build.py --check` confirms the artifact is
still in sync (see validation table) — proof no rebuild ran. v21 stands as shipped by `P11.S3`.

## Validation

| Check | Command | Result |
|---|---|---|
| No explainer-produced-by-review claim | `grep -n 'explainer\|explain' README.en.md` | 6 hits, all expected: the contract tagline (`:228`, unrelated — "Slice folder explains"), the on-demand `/explain` framing (`:274-275`, `:281`), and the unchanged Alternative paragraph (`:288`, `:291`). No hit claims a review produces/auto-saves an explainer. |
| No "auto-save" claim | `grep -c 'auto-save' README.en.md` | `0` (grep exit code 1 — expected for zero matches) |
| "hands" appears in both corrected spots | `grep -n 'hands' README.en.md` | 2 hits: `:48` (Review gates bullet) and `:298` (tier paragraph) — matches expectation exactly |
| Exactly one file changed | `git diff --stat` | `README.en.md` (19 lines changed) plus pre-existing dirty state files (`works/backlog.md`, `works/deferred.md`, `works/events.jsonl`, `works/index.json`, `works/state.json`) from the orchestrator's `start-slice P11.S4` transition that ran before this slice was dispatched — not touched by this slice. No `README.md`, no `bootstrap_agentic_workspace.sh`, no `installer/`, no `CHANGELOG.md`, no `docs/`. |
| Installer artifact unchanged | `python3 installer/build.py --check` | `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| Workflow state integrity | `python3 scripts/workflow.py validate` | `Workflow validation passed.` |
| Consistency read | Re-read `README.en.md:40-52`, `:270-292`, `:293-302` | Consistent with each other and with v21 behaviour: the review validates and, only on a pass, consolidates docs; a non-pass stops and hands findings back; explaining is an operator-run `/explain`, never review-produced. |

## Deviations from plan

None. All four OLD blocks matched the file verbatim; no substitute edits, no nearby-text fixes, no
scope widening.

## Doc impact

None recorded — as the plan states, `README.en.md`/`README.md` are not durable docs consolidated via
`doc-new-version`, and `P11.S3` already recorded the `operations.md` and `decisions.md` impacts for
`REVIEW`.
