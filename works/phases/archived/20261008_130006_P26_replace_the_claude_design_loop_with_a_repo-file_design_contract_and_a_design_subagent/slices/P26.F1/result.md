# Result — P26.F1 (fix)

## Verdict

- `status`: done
- `tier`: high
- `summary`: Fixed all four P26.REVIEW findings. The drafter now keys `frontend-design` only on the handoff's `new visual direction` line. `design-check` accepts exactly the contract's reference set, with `//` and `http://` failing by name. The v47 CHANGELOG retires only the DesignSync-side regroup. Both do-* feedback steps now write the revision handoff and read back before PENDING #1. New pins sit inside the existing Test 0 and Test 13 blocks, and the smoke stays at 195 PASS / 0 FAIL.
- `files_changed`:
  - `.claude/agents/design-drafter.md` (§Inputs 1, §Do 7)
  - `scripts/workflow.py` (`DESIGN_ALLOWED_REFS` and `DESIGN_REF_WHY` replace `DESIGN_ABSOLUTE_REFS`; `design_reference_problems`)
  - `CHANGELOG.md` (v47, the `design-cowork` bullet)
  - `.claude/skills/do-whole-phase/SKILL.md` (co-work step 4, the feedback bullet)
  - `.claude/skills/do-next-slice/SKILL.md` (step 3, the feedback clause)
  - `tests/retrofit_smoke.sh` (the Test 0 do-* and drafter pins; the Test 13 first assertion; the header comments)
  - `bootstrap_agentic_workspace.sh` (rebuilt)
  - `works/phases/active/P26/slices/P26.F1/result.md` (new)
  - `works/phases/active/P26/phase.md`
- `validation`:
  - `python3 installer/build.py`: wrote 595,777 B. PASS
  - `bash tests/retrofit_smoke.sh` (alone in its call, foreground, 600 s): `ALL RETROFIT SMOKE TESTS PASSED`, **195 `PASS:` / 0 `FAIL`**, the same as the baseline. PASS
  - `python3 installer/build.py --check`: in sync. PASS
  - `python3 scripts/workflow.py sync-agents --check`: agent files in sync. PASS
  - `python3 scripts/workflow.py validate`: passed, exit 0. Its only warning is the existing `oversized_doc_sections=7`. It was re-run after the notebook edit and still passed. PASS
  - The Test 0 block run on its own against the repo before the full smoke (`T0-OK`). PASS
  - Scratch probe `scratchpad/f1_probe.sh f1probe2`, outside the repo, with `HOME` and `$AGENTIC_DESIGN_REGISTRY` in scratch (see *Probe*). `//x.css`, `http://x`, `HTTP://…`, `url(//…)`, `mailto:`, `javascript:`, a relative `styles.css` and a `//` inside `tokens.css` all fail with exit 1. `https:`, `data:`, `../tokens.css` and `#` fragments (`url(#g)`, `<use href="#g">`, `href="#"`) all pass with exit 0. The real `~/.config/agentic-workspace` was absent before and after, and the scratch HOME has no `.config`. PASS
- `deviations`:
  - **Finding 2 goes past the two named schemes, as the plan directs.** The plan says "if the contract text and the engine disagree beyond those two schemes, the contract text wins". The contract says "Images are inline SVG or `data:`, and anything else is an absolute `https:` URL". So `mailto:`, `tel:`, `javascript:` and `about:`, which the engine used to let through, now fail too. They fail with the generic named problem; `//` and `http://` also get a specific reason.
  - **The contract does not literally name `#` fragments.** I kept them allowed, as the contract's own inline-SVG rule requires (detail under *Finding 2*).
  - **The contract text is unchanged.**
- `doc_impact`: three lines appended to `phase.md` `## Doc impact`:
  - `operations.md`: the reference rule as `design-check` now enforces it, and the drafter's `frontend-design` licence keyed to the handoff line, with a missing line becoming an open question (P26.F1).
  - `qa.md`: Test 13's first assertion now also covers `//`/`http://` failing and `#`/`data:`/`https` passing, and Test 0 pins the drafter licence and the do-* revision handoff. The baseline stays 195 (P26.F1).
  - `decisions.md`: why the engine follows the contract text strictly, apart from `#` fragments (P26.F1).

## Finding by finding

### Finding 1: the drafter's `frontend-design` licence is the handoff's line

- **Fix, `.claude/agents/design-drafter.md`:**
  - §Inputs 1 now lists "the `new visual direction: yes` or `no` line" among the handoff's contents. It adds that the line "is the operator's call, and your only licence for `frontend-design` (§Do 7)".
  - §Do 7 now reads: "The handoff's `new visual direction: yes` or `no` line is the operator's call, and your **only** licence to load it: load it through `Skill` on a round whose handoff says `new visual direction: yes`, and only there. On `no`, never. If the line is missing, do not load it, and name the missing line in `open_questions`. You never infer the licence yourself: a line that looks wrong for the round (a `no` on a product's first round, say) is an `open_questions` entry, not a reason to load it."
  - The old self-judged rule ("only on a round that sets a new visual direction: a product's first round, a redesign…") is gone.
- **Wording match:** it uses the same phrases as `design-cowork` L198–201 and L828–830, the do-* handoff step ("the operator's call, and the drafter's only licence for `frontend-design`") and CHANGELOG v47 L38–39.
- **Pin, Test 0** (after the design-cowork engine-constants check). The drafter body, whitespace-flattened, must contain:
  - "the `new visual direction: yes` or `no` line";
  - "your **only** licence to load it";
  - "If the line is missing, do not load it, and name the missing line in `open_questions`.";
  - "You never infer the licence yourself".

  It must not contain the old "**only** on a round that sets a new visual direction".
- **Evidence:** Test 0 PASS. The frontmatter is unchanged, and Test 5 still passes both "ships the design-drafter subagent" and "keeps design-drafter on the high tier".

### Finding 2: `design-check`'s reference rule matches the contract

- **Contract text** (`design-cowork` §*The design record — the on-disk contract (schema 1)*, the Self-contained bullet): "A card references nothing relative except `../tokens.css`. Images are inline SVG or `data:`, and anything else is an absolute `https:` URL. … `tokens.css` follows the same rule with no exception."
- **Engine, before:**
  - `DESIGN_ABSOLUTE_REFS = ("#", "data:", "http://", "https://", "//", "mailto:", "tel:", "javascript:", "about:")`.
- **Engine, after:**
  - `DESIGN_ALLOWED_REFS = ("#", "data:", "https://")`, plus `../tokens.css` for cards only, as before.
  - `DESIGN_REF_WHY` adds a named reason to the two schemes the review found:
    - `//…` gives "(protocol-relative: it resolves against file:// when a card file is opened directly)";
    - `http://…` gives "(plain http, not https)".
  - The "allowed" text in the problem now names "an in-page `#` fragment" as well.
  - The match is case-insensitive, as before (`HTTP://` fails too).
- **Where the contract text won (beyond the two schemes):** `mailto:`, `tel:`, `javascript:` and `about:` were accepted and now fail. The contract's "anything else is an absolute `https:` URL" does not name them.
  - No adopter has schema-1 cards yet: v47 is unreleased, and this slice amends it.
  - Snapshots in closed rounds are not reference-checked (only the live `cards/` and the root `tokens.css` are), so no immutable round can start failing.
- **The one reading I made: `#` stays allowed.** The contract does not name fragments literally, but it requires them in substance:
  - "Images are inline SVG", and inline SVG's gradients, filters, clip paths and `<use>` reference by `url(#id)` / `href="#id"`;
  - a same-document fragment resolves inside the card's own bytes wherever the file is opened, which is exactly the property the rule protects ("the same bytes render from `cards/` and from a round snapshot");
  - `href="#"` is the ordinary stub for a non-functional link on a design card.

  Rejecting fragments would fail cards the contract endorses. The contract text itself is unchanged: rewording it is outside this slice and would change the dashboard interface. The re-review may want to confirm this reading.
- **Pin, Test 13** (extending the first assertion, so there is no new `ok` line):
  - The three probe cards now also carry `<a href="#top"><img src="data:…"></a><a href="https://example.com/">`.
  - Before the whole-tree `design-check`, `03-button.html` gets `<img src="//cdn.example.com/x.png"><link … href="http://x.example/y.css">` appended; it is restored from a copy afterwards.
  - The failing run must name both references with their reasons, as well as the gap and the unnumbered card. The restored run (`../tokens.css`, `#`, `data:`, `https`) must pass with exit 0.
  - The Test 13 echo and the file-header comment say so.
- **Evidence:**
  - Test 13's first line: "PASS: design-check names a gap, an unnumbered card, a // and an http:// reference (exit 1) and passes the numbered set with ../tokens.css, #, data: and https references".
  - The later Test 13 lines (regroup line 1 only, idempotent close, register) still pass with the richer card bodies.
  - The probe output is below.

### Finding 3: the v47 CHANGELOG is consistent

- **Fix, `CHANGELOG.md` L47–50** (formerly L47–48). It now reads: "The `DesignSync` read-back and its SIGNOFF regroup (the write into the Claude Design project) are retired, along with the push and the `_ds_manifest.json` card contract; the regroup itself lives on locally in `design-close --words`, which rewrites line 1 of each signed card and nothing after it."
- **Why this is consistent:** it now agrees with L29–30 ("regroups line 1 only") and with `design-cowork` §Closing step 2.
- **Evidence:**
  - Test 5 "every changelog release section carries a Migration notes line" and "release version agrees…" both PASS.
  - No version bump: `WORKSPACE_VERSION` is still 47.

### Finding 4: the do-* feedback step writes the revision handoff and reads back

- **Fix:** `do-whole-phase` (co-work step 4, the feedback bullet) and `do-next-slice` (step 3, the feedback clause) now say, word for word where `design-cowork` L215 and L569–574 allow:
  1. write their words verbatim into `feedback.md`;
  2. run `design-close <round> --superseded` (snapshot and close, no regroup: the cards stay addressed);
  3. `design-open` again in the same slice ("the new round inherits the addressed cards");
  4. **write its handoff**: what the feedback asks for, pointing at the superseded round's `feedback.md`, and the full numbered list, **every card still carrying the slice's address** plus any new ones, with its `new visual direction` line;
  5. re-dispatch the drafter (step 2 in do-whole-phase);
  6. read back exactly as in step 3 ("inline exactly as above" in do-next-slice);
  7. commit the drafted round, with the superseded round's `feedback.md` and close in the same commit;
  8. stop at PENDING #1 again.
- **Counts:** both keep them exactly as before: "one more commit and one more stop per superseding round" (do-whole-phase) and "one more commit, stop and invocation per superseding round" (do-next-slice). The line that the superseded round's close rides in the same commit matches `design-cowork` L82–84.
- **The one addition beyond L215 is "with its `new visual direction` line".** Every handoff carries that line (`design-cowork` L198), and after finding 1 a missing line becomes a drafter open question. Naming it keeps the revision handoff from dropping it.
- **Pins, Test 0** (the do-* loop, both skills):
  - required: "**write its handoff**", "**every card still carrying the slice's address**" and "the new round inherits the addressed cards";
  - negative: "in the same slice, re-dispatch the drafter", the old elided wording.
- **Evidence:** Test 0 PASS.

## Probe (scratch, outside the repo)

`bash scratchpad/f1_probe.sh f1probe2`:
- a fresh install from the rebuilt installer into `scratchpad/f1probe2/acme-web`;
- `HOME=…/f1probe2/home` and `AGENTIC_DESIGN_REGISTRY=…/f1probe2/reg/design-registry.json`;
- `design-init`, then `design-open --slug probe --slice P1.S1`;
- one card, `cards/01-a.html`, rewritten per case.

```
[//x.css] rc=1 :: - cards/01-a.html: references '//x.css' (protocol-relative: it resolves against file:// when a card file is opened directly): only ../tokens.css, an in-page `#` fragment, `data:` or an absolute https URL may be referenced (…)
[http://x] rc=1 :: - cards/01-a.html: references 'http://x' (plain http, not https): only …
[HTTP:// uppercase] rc=1 :: - cards/01-a.html: references 'HTTP://X.EXAMPLE/' (plain http, not https): only …
[url(//...)] rc=1 :: - cards/01-a.html: references '//cdn.example.com/bg.png' (protocol-relative: …): only …
[https:] rc=0 :: design-check: OK -- 1 card(s), 1 round(s), open round: 01-probe
[data:] rc=0 :: design-check: OK -- 1 card(s), 1 round(s), open round: 01-probe
[../tokens.css] rc=0 :: design-check: OK -- 1 card(s), 1 round(s), open round: 01-probe
[# fragments] rc=0 :: design-check: OK -- 1 card(s), 1 round(s), open round: 01-probe
[mailto:] rc=1 :: - cards/01-a.html: references 'mailto:hi@example.com': only …
[javascript:] rc=1 :: - cards/01-a.html: references 'javascript:void(0)': only …
[relative styles.css] rc=1 :: - cards/01-a.html: references 'styles.css': only …
[tokens.css carrying //] rc=1 :: - tokens.css: references '//cdn.example.com/t.png' (protocol-relative: …): only an in-page `#` fragment, `data:` or an absolute https URL may be referenced (…)
scratch HOME .config: absent
real ~/.config/agentic-workspace: absent before and after
```

**A dead end:** the first run (`f1probe`) wrote no card, because `design-init` does not create `cards/`. The probe script now runs `mkdir -p cards/` and was re-run into a fresh `f1probe2`; both runs live in the session scratchpad only.

## Smoke count

195 `PASS:` lines, counted per test in the run's output: T0 1, T1 22, T2 3, T3 3, T4 6, T5 84, T6 32, T7 1, T8 3, T9 7, T10 6, T11 3, T12 19, T13 5. There were 0 FAIL, and the run ended "ALL RETROFIT SMOKE TESTS PASSED". No `ok` line was added: the new checks extend the Test 0 block and Test 13's first assertion.

## Notebook (`phase.md`)

`## Decisions`:
- The P26.S2 drafter line now says `frontend-design` is keyed to the handoff line.
- The Review line is rewritten to record the fix.
- A new line records F1's reference-rule reading.

`## Doc impact`: three lines appended.

`## Notes for later slices`:
- The REVIEW → F1 note is consumed.
- A note for the re-review is added.

`## Now`: rewritten. Its stale "file DJ1–DJ3" item now reads "filed as D29–D31", as `works/deferred/open/` confirms.
