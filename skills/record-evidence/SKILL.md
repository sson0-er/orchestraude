---
name: record-evidence
description: How to record external facts (docs, command output, codebase findings) as evidence and design choices as decisions. Used by the researcher, designer and reviewer agents.
user-invocable: false
---

# Recording evidence and decisions

## When to record

Write one evidence entry immediately after any of these:

- You consulted an external source: official docs, source code, an issue, an RFC.
- You ran a command to confirm behavior or a version (CLI flags, API responses, installed versions).
- You read existing code and found a fact that a design decision will rest on.

Write one decision entry whenever you choose between alternatives (adopting an approach, rejecting another).

## Writing an evidence entry

1. Create `docs/orchestraude/evidence/<yyyy-mm-dd>-<slug>.md` using the format in `${CLAUDE_PLUGIN_ROOT}/templates/evidence.md`. The slug uses `[a-z0-9-]` only.
2. Body is a summary: a few lines up to a dozen. Never paste whole pages or raw command output.
3. `fetched` is today's date. `expires` is 90 days later by default, 30 days for fast-moving sources (preview features, beta APIs).
4. Separate what you learned from what you could not confirm.
5. Exclude secrets: tokens, output of authenticated commands, internal URLs, personal data.
6. Append one line to `docs/orchestraude/evidence/INDEX.md`: `- <id> | <question> | expires <yyyy-mm-dd>`

## Writing a decision entry

1. Number it `<nnn>` (three digits, zero-padded) by counting existing files in `docs/orchestraude/decisions/`.
2. Create `docs/orchestraude/decisions/<nnn>-<slug>.md` using `${CLAUDE_PLUGIN_ROOT}/templates/decision.md`.
3. In "Rationale", reference evidence ids. If a reason has no evidence, write "unverified" next to it.

## Citing in deliverables

When a design, research note or review finding states an external fact, end the sentence with `(evidence: <id>)`.
If you cannot cite, write "unverified". Reviewers treat uncited external claims as findings.

## Expired evidence

Before relying on an entry past its `expires` date, re-check the source and update `fetched` and `expires`.
If you cannot re-check, state "expired, not re-verified" where you use it.
