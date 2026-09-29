---
name: review-rules
description: Shared rules for the four implementation reviewers (quality, security, spec, tests) - findings JSON shape, severity calibration and how to review later rounds. Preloaded by the reviewer agents.
user-invocable: false
---

# Implementation review rules

These rules apply to every implementation reviewer. Your agent file gives your role id, your checklist and the path of your findings file `docs/orchestraude/<slug>/tasks/<task-id>.findings.<role>.json`.

## Review policy
Read `docs/orchestraude/review-policy.md` when it exists: it lists accepted low findings and adopted conventions. Do not report a low finding it covers.

## Output format
Write only the following JSON to your findings file (Write tool). It is the shape of `${CLAUDE_PLUGIN_ROOT}/schemas/findings.schema.json`; every field is required and every value is a string:

{"summary": "one or two sentences; from round 2 on, then one line per previous-round finding of your role: '<title>: addressed' or '<title>: not addressed'", "findings": [{"severity": "high|medium|low", "title": "short headline", "location": "path:line, or empty string", "detail": "what is wrong and how to fix it", "evidence": "evidence id when the claim rests on an external fact, else empty string"}]}

If there is nothing to report, `findings` is an empty array. Final message: the summary and the counts only. Do not paste content.

## Severity calibration
- high: must not merge. Incorrect behavior, data loss or corruption, a security vulnerability, or a violation of the design or the Definition of Done.
- medium: must fix before the task is done. Limited to defects: wrong or fragile behavior in a realistic case, a design or DoD requirement not met, missing validation that lets bad data through, a behavior listed in the DoD with no test, an error silently swallowed.
- low: everything else, including every matter of preference and style. Always low, never medium: duplicated helpers, "cleaner" dispatch or control-flow shapes, struct fields versus variadic arguments, unused fields or parameters with no behavioral effect, consolidating test helpers, naming and comment wording, file organization. A finding that starts with "consider", "could", or "would be cleaner" is low.

When unsure between medium and low, choose low. Zero medium findings must be reachable: a finding that any code would attract is not a defect.

## What to review
The prompt states the round number and two snapshot SHAs: the previous tree (round 1: the tree before the task started; later rounds: the tree reviewed in the previous round) and the tree as it is now. Run `git diff <previous snapshot> <current snapshot>` and review that diff; it is exactly what the implementer changed (plain `git diff` would not show new files, and would include earlier tasks' uncommitted changes).

## Later rounds
From round 2 on the prompt also names `<task>.findings.history.md` (all previous rounds' merged findings plus the implementer's stated reasons for anything left unchanged).
1. Read the history first. Do not contradict a change an earlier round asked for, and do not re-raise an item the implementer declined with a stated reason unless you can show the reason is wrong.
2. For each previous-round finding from your role, state whether it is addressed in the summary's per-finding lines (see Output format); re-report it only if it is not.
3. Review only the fix: the snapshot diff above. Behavior changed by the fix counts as part of the fix even where the lines did not change, for example a test that no longer exercises the path it covered. Code the fix did not affect was already reviewed; report something there only as a high (a real defect), never as medium or low.
