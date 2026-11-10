# Orchestration phases 1 to 3

Part of the orchestrate skill; its role and escalation rules apply. `$slug` is the feature slug given to that skill. Start at the step `orchestraude-status` named.

Design model: when `orchestraude-status $slug` also prints `design-model: fable`, set the Agent tool's `model` to `fable` every time you launch `orchestraude:designer`, `orchestraude:design-reviewer` or `orchestraude:planner`. Without that line pass no `model`: each agent's definition decides.

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
7. Show the user the paths of `03-design/README.md` and `03-design-review.md` with the counts, and ask for approval. This is gate 2. Do not continue without it.

   When the counts line shows one or more lows, list their titles (`grep '^- \[' docs/orchestraude/$slug/03-design-review.md`) and offer a second choice next to approval: have the designer fix the lows first. A low left in the design is copied into the plan and the code, and comes back there as review findings and follow-up tasks. On that choice launch `orchestraude:designer`. Prompt: "slug is $slug. Revise 03-design/ to address the low findings in 03-design-review.md and append your response to 03-design-review.history.md." When it returns, repeat step 3 (it may have raised a question), then ask for approval again, saying that the lows were revised and not reviewed again. Offer this choice once.

   On approval, record it:

   ```
   echo "- gate 2 approved $(date +%F)" >> docs/orchestraude/$slug/gates.md
   ```

## Phase 3: implementation plan → gate 3

1. Launch `orchestraude:planner`. Prompt: "slug is $slug. Write 04-plan.md and tasks/*.md."
2. Show the user the task table from `04-plan.md` and ask for approval. This is gate 3. Do not continue without it. On approval, record it: `echo "- gate 3 approved $(date +%F)" >> docs/orchestraude/$slug/gates.md`.

After gate 3 is recorded, continue with Phase 4, the task loop in the orchestrate skill.
