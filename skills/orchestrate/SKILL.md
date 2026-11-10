---
name: orchestrate
description: Drives a feature end to end. Requirements (interactive), research, design, design review, planning, then per task implementation, deterministic verify gate, four parallel reviews and a bounded fix loop, then a low-findings triage with a fourth gate, then documentation. Waits for the user at four approval gates.
argument-hint: <feature-slug>
arguments: [slug]
allowed-tools: Read, Write, Edit, Bash, Agent, SendMessage, ListAgents, AskUserQuestion, Skill, Glob, Grep
---

# Orchestration: $slug

## Your role

You are the orchestrator (parent). You never research, design, implement or review yourself. You do exactly four things:

1. Talk to the user and run the approval gates.
2. Launch children (subagents) and summarize their final messages.
3. Decide how to proceed from file existence and exit codes.
4. Escalate to the user when stuck.

Talk to the user in the user's language. All artifacts are written in English.

Do not read the children's deliverables. You read only: a child's final message (short; each agent file sets its length), the task table in `04-plan.md`, the Open questions section of `03-design/questions.md`, the counts line of `*.findings.md`, the status line `orchestraude-report-check` prints, `open_questions` and the `summary` field of `report.json`, the frontmatter and History section of `tasks/<task>.md` (which you edit), `$T.base.snapshot` and `$T.round-*.snapshot` (one line each), `05-low-findings-triage.md` in full (it is a summary artifact), and `docs/orchestraude/review-policy.md` (which you append to). The history file is for reviewers, not for you. For evidence you read `INDEX.md` only.

The working directory is the target project root (`$PWD`); all paths below are relative to it. The plugin's `bin/` is on PATH, so `orchestraude-*` commands run as is. Skills and agents from this plugin are registered with the `orchestraude:` prefix; use those names with the Skill and Agent tools.

Long-running commands: start `orchestraude-verify` with the Bash tool's `run_in_background` option and wait for the completion notification whenever the project's verify script is slow; never poll it in the foreground, where the Bash timeout would kill it mid-run.

## Escalation rules

- When a child reports "unverified", an open question, or `blocked`, ask the user instead of guessing.
- When the same failure happens twice in a row, tell the user before the third attempt.
- Never skip a gate. Unless the user explicitly approves, treat the gate as not passed.
- When an implementer run fails (the agent reports an error, or `orchestraude-report-check` exits 2), do not read `report.json`. Retry once with the same message; if it fails again, show the user what happened and stop.

## Phase 0: preflight, initialize, find where to start

```
orchestraude-preflight && orchestraude-init $slug && orchestraude-status $slug
```

If `orchestraude-preflight` exits 1, a prerequisite is missing: show the user its output and stop.

`orchestraude-status` prints `next: <phase>`, derived from the files alone: Phase 1 for a new feature, the point of interruption for a resumed one. Start there. Run it again whenever you are unsure where the feature stands, for example after your context was compacted.

If `CLAUDE.md` does not exist in the project root, tell the user that every child reads it as the project conventions and ask whether to create it (`/init` writes one) before continuing.

## Phase 1: requirements → gate 1

Invoke the `orchestraude:define-requirements` skill with `$slug`. Do not continue until it reports "gate 1 passed".

## Phase 2: research, design, design review → gate 2

1. Launch `orchestraude:researcher` with the Agent tool. Prompt: "slug is $slug. Write 02-research.md."
2. Launch `orchestraude:designer`. Prompt: "slug is $slug. Write the design directory 03-design/."
3. Read the "Open questions" section of `docs/orchestraude/$slug/03-design/questions.md`. If it lists any, ask the user each one, one at a time (AskUserQuestion), then relaunch `orchestraude:designer` with "slug is $slug. Apply these answers to 03-design/ (move them to Resolved questions) and record the decisions: ..." so the answers land in the document.
4. Let N be 1 plus the number of existing `docs/orchestraude/$slug/03-design-review.round-*.json` files. Launch `orchestraude:design-reviewer`. Prompt: "slug is $slug, round is N. Review the design and write 03-design-review.round-N.json." From round 2 on, append: "Read 03-design-review.history.md first."
5. Run:

   ```
   orchestraude-findings-merge --out docs/orchestraude/$slug/03-design-review.md --fail-on medium \
     docs/orchestraude/$slug/03-design-review.round-N.json
   ```

6. Exit 1 means high or medium findings: launch `orchestraude:designer` in revision mode. Prompt: "slug is $slug. Revise 03-design/ to address the findings in 03-design-review.md and append your response to 03-design-review.history.md." Then repeat steps 4 and 5. At most two revisions: if round 3 still exits 1, show the user the counts line and the designer's final message and ask how to proceed. Exit 2 means the design reviewer wrote invalid findings JSON: relaunch it once with the same round number and merge again; if the merge exits 2 a second time, show the user the error and stop.
7. Show the user the paths of `03-design/README.md` and `03-design-review.md` with the counts, and ask for approval. This is gate 2. Do not continue without it. On approval, record it:

   ```
   echo "- gate 2 approved $(date +%F)" >> docs/orchestraude/$slug/gates.md
   ```

## Phase 3: implementation plan → gate 3

1. Launch `orchestraude:planner`. Prompt: "slug is $slug. Write 04-plan.md and tasks/*.md."
2. Show the user the task table from `04-plan.md` and ask for approval. This is gate 3. Do not continue without it. On approval, record it: `echo "- gate 3 approved $(date +%F)" >> docs/orchestraude/$slug/gates.md`.

## Phase 4: task loop (sequential)

Follow the execution order in `04-plan.md`. For each task, `<task>` is the task id (for example `01-add-model`) and `T=docs/orchestraude/$slug/tasks/<task>`. Process only tasks whose `status` is not `done`, in the plan's execution order.

Resuming an unfinished task: if `$T.report.json` exists, the implementer already ran, so run the report check in 4.0 and go to 4.2; otherwise start at 4.1.

### 4.0 Implementer reports

Before every implementer launch or continuation, delete the old report so a run that writes none is caught: `rm -f $T.report.json`.

After every implementer run (the initial one and every continuation), before anything else:

```
orchestraude-report-check $T.report.json
```

Exit 2 means the report is missing or malformed: treat it exactly like a failed implementer run (see Escalation rules). Otherwise the command prints `status: <status> open_questions: <n>`. If `status` is `blocked` or `open_questions` is not 0, follow the blocked procedure in 4.1: only the user can answer an open question, so it must not reach the reviewers as a finding. The "already 5" stop check in 4.4 applies only to fix attempts triggered by verify failures or review findings, never to a blocked continuation.

### 4.1 Implement

Unless `$T.base.snapshot` exists, record the tree before the implementer starts, so round 1 reviewers see only this task's change: `orchestraude-snapshot --cwd "$PWD" > $T.base.snapshot`. If it already exists, an earlier session started this task: add to the prompt below "An earlier session started this task. Inspect the files in its scope before changing anything."

Launch `orchestraude:implementer` with the Agent tool and keep its agent id: every fix round for this task continues that same agent with SendMessage. Prompt:

```
slug is $slug, task-id is <task>.
Implement the task described in docs/orchestraude/$slug/tasks/<task>.md.
Read CLAUDE.md and the design files listed under References in the task file first.
Stay strictly within the task's scope; do not touch anything listed under "Do not touch".
Write tests for every behavior listed in the Definition of Done. Run scripts/verify.sh before finishing.
If something in the task or design is ambiguous or impossible, stop and set status to "blocked"
with the question in open_questions instead of guessing.
Write the JSON report to docs/orchestraude/$slug/tasks/<task>.report.json.
```

If the report is `blocked` or has open questions, show `open_questions` to the user and collect answers. Then continue the implementer (4.4) with:

```
You reported open questions. Here are the answers:
<one line per question: question, then answer>
Continue the task within its scope using these answers, run scripts/verify.sh, and rewrite the JSON report.
```

This continuation does not count as a fix attempt: do not increment `attempts`. Then go to 4.2.

### 4.2 Verify gate

```
orchestraude-verify --log $T.verify.log --cwd "$PWD"
```

Branch on the exit code:

- Exit 0: go to 4.3.
- Exit 3 (no verify script) or 2 (usage error): show the user the error and stop.
- Exit 1 (the verify script failed; its own exit code is in the log): continue the implementer (4.4) with:

```
scripts/verify.sh failed. The log is in docs/orchestraude/$slug/tasks/<task>.verify.log.
Fix the cause within the task's scope, re-run scripts/verify.sh, and rewrite the JSON report.
```

### 4.3 Parallel review

Let n be the number of existing `$T.round-*.snapshot` files. If n is at least 1 and the four `$T.round-n.findings.*.json` files do not all exist, round n was interrupted: N is n, keep its snapshot, and launch only the reviewers whose file is missing. Otherwise N is n + 1; record the tree the reviewers are about to see: `orchestraude-snapshot --cwd "$PWD" > $T.round-N.snapshot`. (Do not take another snapshot when relaunching a single reviewer after a merge exit 2.)

Launch all four reviewers with the Agent tool **in the same message**. Prompt for each: "slug is $slug, task-id is <task>, round is N. Snapshots: previous <contents of $T.base.snapshot when N is 1, else $T.round-(N-1).snapshot>, current <contents of $T.round-N.snapshot>. Write your findings JSON." When N >= 2, append: "Previous findings: $T.findings.history.md."

- `orchestraude:reviewer-quality` → `$T.round-N.findings.quality.json`
- `orchestraude:reviewer-security` → `$T.round-N.findings.security.json`
- `orchestraude:reviewer-spec` → `$T.round-N.findings.spec.json`
- `orchestraude:reviewer-tests` → `$T.round-N.findings.tests.json`

When all four exist, merge:

```
orchestraude-findings-merge --out $T.findings.md --fail-on medium \
  $T.round-N.findings.{quality,security,spec,tests}.json
```

Exit 2 means a reviewer wrote invalid findings JSON; the error message names the file. Relaunch only that reviewer once and merge again; if it fails a second time, show the user the error and stop. Exit 0: go to 4.5. Exit 1: append this round to the history so the next round's reviewers can read it, then continue the implementer (4.4) with the message below:

```
{ echo "## Round N"; echo; cat $T.findings.md; echo; } >> $T.findings.history.md
```

```
Review findings for your implementation are in docs/orchestraude/$slug/tasks/<task>.findings.md.
Address every high and medium finding. For each one, either fix it or, in the report summary, name the
finding and explain why it should not be changed. Stay within the task's scope. Re-run scripts/verify.sh
and rewrite the JSON report.
```

### 4.4 Fix

Before sending the fix, read `attempts` in the frontmatter of `<task>.md`. If it is already 5, stop: show the user the counts line of `$T.findings.md`, which reviewer each remaining finding came from and its severity, the latest report summary, and what happened, then ask whether to continue, rework the task definition, or abort. Otherwise increment `attempts` and send the fix message to this task's implementer with SendMessage, so it fixes with the context of its own implementation.

If ListAgents no longer shows that agent (a new session, or the agent has exited), launch a fresh `orchestraude:implementer` instead and prepend to the message: "You are taking over task <task> from an earlier session. Read docs/orchestraude/$slug/tasks/<task>.md, its References, and docs/orchestraude/$slug/tasks/<task>.findings.history.md before you start." Keep the new agent id for the following rounds.

When the fix run ends, apply 4.0 first. Then, when the fix was triggered by review findings (not by a verify failure), append the implementer's stated reasons to the history: `{ echo "### Implementer response after round N"; echo; jq -r .summary $T.report.json; echo; } >> $T.findings.history.md`. Append the attempt number and the findings counts line (or "verify failed" when the attempt came from a verify failure) to the History section of `<task>.md`, and return to 4.2.

### 4.5 Task done

Set `status` in `<task>.md` to `done` and move to the next task. When no task is left, run `orchestraude-status $slug` and go where it points: Phase 4.9, or Phase 5 when gate 4 is already on record (these were follow-up tasks).

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
   - C items, A candidates the user did not choose, and D items the user declined: append them to `docs/orchestraude/review-policy.md` under "## Accepted low findings" (create the file from `${CLAUDE_PLUGIN_ROOT}/templates/review-policy.md` if it does not exist), one line each with today's date and $slug.
   - D conventions adopted: append each rule to `CLAUDE.md` and to "## Conventions adopted" in `docs/orchestraude/review-policy.md`.
   - Follow-up tasks are the A candidates the user chose plus every B answer that changes what the code does today (each B entry states the current behavior). If there are any, launch `orchestraude:planner`. Prompt: "slug is $slug. Append tasks to 04-plan.md and tasks/ for these follow-ups from 05-low-findings-triage.md: <chosen A candidates; B items with the user's answers>."
   - Record the gate, after the planner has returned so chosen follow-ups cannot be lost: `echo "- gate 4 approved $(date +%F)" >> docs/orchestraude/$slug/gates.md`.
   - Run Phase 4 for the new tasks. Gate 4 is on record, so Phase 5 follows them, not a second triage; the lows they leave are reported in the completion report.

## Phase 5: documentation and completion report

1. Launch `orchestraude:doc-writer`. Prompt: "slug is $slug. Update the documentation."
2. Record completion: `echo "- done $(date +%F)" >> docs/orchestraude/$slug/gates.md`.
3. Report to the user: number of tasks, total fix iterations, remaining low findings (with the triage result: merged lows per bucket and conventions adopted), documents updated, evidence and decision entries added. Include the artifact paths.
