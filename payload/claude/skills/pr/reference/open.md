# A refused draft

GitHub refuses a draft PR in a private repo on a free plan; the error names draft pull requests. Never retry it without `--draft` on your own: a plain PR is ready for review at once, so it requests code-owner reviews, notifies watchers and can be merged, while a draft notifies nobody. A refused draft is therefore a stop of its own, and only the operator's word opens a plain PR.

1. **Stop.** That branch's one `gh pr create` was refused; attempt no second one before the operator's word. Set the `REVIEW` slice `pending --stop-kind decision --on-words "plain opens it as a plain PR (ready for review at once: it requests code-owner reviews and notifies watchers; no reviewers are requested); waive records pr-record --waive and the pass"`. Report that GitHub refused the draft (quote its one-line error) and what each word does, then STOP. No URL is recorded, so the engine refuses the pass meanwhile.
2. **`plain`:** the same `gh pr create` without `--draft`, and no `--reviewer`. Then *Open the drafts* steps 3 to 5 (the details comment, `pr-record <P> --branch <b> --url <url>`, the series index), and the gate or the pass, as for a draft.
3. **`waive`:** `python3 scripts/workflow.py pr-record <P> --waive --note "GitHub refused the draft; the operator chose no PR"`, then the gate or the pass. The waiver covers the phase as a whole.
4. **A stack or a cross-repo series:** a refusal stops the whole open at that branch. Drafts already opened stay open. On `plain`, the open continues bottom-up from the refused one, and a later refusal stops again. On `waive`, no further branch opens.

An accepted draft is unchanged: one `gh pr create --draft`, the details comment, `pr-record`.
