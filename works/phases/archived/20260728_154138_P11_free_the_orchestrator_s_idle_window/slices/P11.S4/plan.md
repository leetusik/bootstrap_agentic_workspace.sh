# P11.S4 — Correct the README explainer claims after auto-explain removal

## Context

`P11.S3` removed auto-explain from the review across every live machinery surface and shipped it as
v21. That made `README.en.md` false in three places: it still tells readers that a passing phase
review files a phase explainer into their KB. `README.md` (Korean) makes no explainer claim and is
not touched.

This is being fixed **before** `P11.REVIEW` rather than after, deliberately: under the rule S3 just
shipped, a known-false README is exactly the kind of finding that stops a review and costs a full
cycle. `P11.S2` already established the READMEs as in scope for this phase.

READMEs are **not** embedded machinery (absent from `FIXED_LIVE_FILES`), so: **no rebuild, no
`WORKSPACE_VERSION` bump, no CHANGELOG entry.** v21 stands as shipped.

Dispatch: **`slice-executor-low`** (`risk: low`). Every edit is an exact string replacement; a
mismatch is an `escalate`, not an improvisation.

## Work — four exact replacements, all in `README.en.md`

### 1. The "Review gates" bullet (~line 46)

OLD:
```
  isolated context that never edits source) checks it against the phase's objective, consolidates its
  doc versions, and — with the knowledge plugin installed — files a phase explainer into your KB.
```
NEW:
```
  isolated context that never edits source) checks it against the phase's objective and consolidates
  its doc versions. A verdict short of `pass` stops there and hands its findings back.
```

### 2. The Knowledge blockquote opening (~line 274)

OLD:
```
> **Knowledge (phase explainers).** A passing phase review can auto-save an interactive HTML phase
> explainer to the knowledge service — plugin-free by default. Sign up at the
```
NEW:
```
> **Knowledge (phase explainers).** Phase explainers are interactive HTML documents saved to the
> knowledge service — produced on demand, not by the review: run `/explain` for a phase when you want
> one, and a passing review simply reports that none was written. Sign up at the
```

### 3. The same blockquote's REST sentence (~line 280)

OLD:
```
> project defaults to the repo's directory name, and with the env vars set a passing review auto-saves the
> explainer via plain REST — Claude Code and Codex equally, no plugin install required (gracefully skipped
> when the KB is absent).
```
NEW:
```
> project defaults to the repo's directory name, and with the env vars set `/explain` saves via plain
> REST — Claude Code and Codex equally, no plugin install required.
```

Leave the **Codex caveat** and **Alternative (Claude Code plugin)** paragraphs untouched — both are
still accurate for an operator-run `/explain`.

### 4. The tier paragraph's review description (~line 296)

OLD:
```
a fresh context that never edits source, validating the phase and consolidating its doc versions, and,
on a pass, producing the phase explainer via the knowledge plugin's explain skill — gracefully skipped
when the plugin/KB is absent).
```
NEW:
```
a fresh context that never edits source, validating the phase and — only on a pass — consolidating its
doc versions; a `changes_requested` or `blocked` verdict stops there and hands the findings back).
```

## Validation

| Check | Expectation |
|---|---|
| `grep -n 'explainer\|explain' README.en.md` | no claim anywhere that a review produces/auto-saves an explainer; the surviving mentions are the on-demand `/explain` framing and the unchanged plugin paragraph |
| `grep -c 'auto-save' README.en.md` | 0 |
| `grep -n 'hands' README.en.md` | two hits — the "Review gates" bullet and the tier paragraph |
| `git diff --stat` | exactly one file: `README.en.md`. **Nothing else** — no `README.md`, no `bootstrap_agentic_workspace.sh`, no `installer/`, no `CHANGELOG.md`, no `docs/` |
| `python3 installer/build.py --check` | still in sync **and unchanged** — you must not run `python3 installer/build.py`; READMEs are not shipped machinery |
| `python3 scripts/workflow.py validate` | passes |
| Consistency read | Re-read `README.en.md:44-50`, `:272-292`, and `:293-302` and confirm they now agree with each other and with the v21 behaviour: the review validates and (on a pass) consolidates docs, stops on a non-pass, and never writes an explainer |

## Record

- `result.md` — the four replacements as applied, the validation table with real outcomes, and an
  explicit note that no rebuild/bump/CHANGELOG entry was made and why.
- `phase.md` — a short cross-slice note. **No Doc impact line**: the READMEs are not durable docs,
  and `P11.S3` already recorded the `operations.md` and `decisions.md` impacts for `REVIEW`.
- No `doc-new-version`, no edits under `docs/`, no commits, no status transitions.

## Non-goals

- No `README.md` (Korean) edits — it makes no explainer claim.
- No other `README.en.md` changes: not the Codex caveat, not the plugin paragraph, not the tier
  models (`P11.S2` already corrected those).
- No rebuild, no version bump, no CHANGELOG entry, no machinery or `docs/` edits of any kind.
