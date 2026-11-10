# Orchestration phases 4.9 and 5

Part of the orchestrate skill; its role and escalation rules apply. `$slug` is the feature slug given to that skill.

## Phase 4.9: low-findings triage → gate 4

Runs once, after every task is done and before documentation.

1. Merge the leftover lows deterministically:

```
orchestraude-findings-triage --tasks-dir docs/orchestraude/$slug/tasks --out docs/orchestraude/$slug/05-low-findings.md
```

The command prints `raw: <M> merged: <N>`. If N is 0, record `echo "- gate 4 skipped $(date +%F): no low findings" >> docs/orchestraude/$slug/gates.md` and skip to Phase 5.

2. Launch `orchestraude:triage` with the Agent tool. Prompt: "slug is $slug. Read 05-low-findings.md and write 05-low-findings-triage.md."
3. Show the user the summary table and the "Follow-up task candidates (from A)", "B. Decisions needed" and "D. Convention candidates" sections of `docs/orchestraude/$slug/05-low-findings-triage.md`, then ask, one question at a time (AskUserQuestion): each B question, which A candidates to implement now, which D conventions to adopt. This is gate 4; do not continue without the user's answers.
4. Act on the answers, in this order:
   - B answers: relaunch `orchestraude:designer` with "slug is $slug. Apply these answers to 03-design/questions.md (Resolved questions) and record the decisions: ...".
   - C items, A candidates the user did not choose, and D items the user declined: append them to `docs/orchestraude/review-policy.md` under "## Accepted low findings", one line each with today's date and $slug.
   - D conventions adopted: append each rule to `CLAUDE.md` and to "## Conventions adopted" in `docs/orchestraude/review-policy.md`.
   - Follow-up tasks are the A candidates the user chose plus every B answer that changes what the code does today (each B entry states the current behavior). If there are any, launch `orchestraude:planner`. Prompt: "slug is $slug. Append tasks to 04-plan.md and tasks/ for these follow-ups from 05-low-findings-triage.md: <chosen A candidates; B items with the user's answers>."
   - Record the gate, after the planner has returned so chosen follow-ups cannot be lost: `echo "- gate 4 approved $(date +%F)" >> docs/orchestraude/$slug/gates.md`.
   - Run Phase 4 (the task loop in the orchestrate skill) for the new tasks. Gate 4 is on record, so Phase 5 follows them, not a second triage; the lows they leave are reported in the completion report.

## Phase 5: documentation and completion report

1. Launch `orchestraude:doc-writer`. Prompt: "slug is $slug. Update the documentation."
2. Record completion: `echo "- done $(date +%F)" >> docs/orchestraude/$slug/gates.md`.
3. Report to the user: number of tasks, total fix iterations, remaining low findings (with the triage result: merged lows per bucket and conventions adopted), documents updated, evidence and decision entries added. Include the artifact paths.
