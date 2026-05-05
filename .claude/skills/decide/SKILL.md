---
name: decide
description: Evaluate a technical or product decision using iOS and PM reviewers in parallel
---

Help make a technical or product decision for Keyoku. The decision to evaluate is:

$ARGUMENTS

## Step 1 — Clarify (if needed)
If the decision isn't clearly stated with at least two options, ask for clarification before proceeding. You need: what the decision is, and what the two (or more) approaches being considered are.

## Step 2 — Understand the Context
Read relevant parts of the codebase to understand how this decision fits into the existing architecture. Don't give generic advice — base your analysis on how Keyoku is actually built.

## Step 3 — Evaluate from Two Perspectives in Parallel
Run the ios-reviewer and pm-reviewer subagents in parallel. Give each the same decision description and ask them to evaluate the options from their perspective.

- **iOS Reviewer**: evaluates technical correctness, architectural fit (VIPER/RIBs), maintainability, performance, and implementation complexity
- **PM Reviewer**: evaluates user impact, delivery speed, risk, reversibility, and alignment with the app's core metrics (retention, conversion, session completion)

## Step 4 — Synthesize
After both subagents respond, synthesize their input into a final recommendation:

**Decision: [restate the question]**

| | Option A | Option B |
|---|---|---|
| Architecture fit | | |
| User impact | | |
| Implementation effort | | |
| Risk | | |
| Reversibility | | |

**Recommendation:** [Option A / Option B / Hybrid]

**Reasoning:** 2-3 sentences on why this is the right call for Keyoku right now.

**Watch out for:** One specific risk or gotcha to keep in mind when implementing the recommended option.
