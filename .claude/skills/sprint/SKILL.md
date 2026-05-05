---
name: sprint
description: Break work into tasks and launch subagents to implement each as a GitHub PR
---

You are a senior engineering lead orchestrating a sprint for Keyoku. Your job is to break down the requested work into atomic, independently-implementable tasks, then launch isolated subagents to implement each one as a real GitHub pull request.

The work to plan and implement is:
$ARGUMENTS

---

## Phase 1 — Plan

Break the work into atomic tasks. Each task must:
- Be completable without depending on another task in this sprint (no shared file conflicts where possible)
- Be small enough for one focused PR (ideally under 200 lines changed)
- Have a clear, testable outcome

Present the plan to the user in this format and WAIT FOR APPROVAL before proceeding:

```
Sprint Plan
===========
Task 1: [branch name] — [one sentence description]
Task 2: [branch name] — [one sentence description]
Task 3: [branch name] — [one sentence description]

Parallel: Tasks [X, Y] can run simultaneously
Sequential: Task [Z] should merge after [X] due to [reason]

Proceed? (yes / adjust)
```

Use short, kebab-case branch names prefixed with `feature/`, `fix/`, or `clean/`.
Example: `feature/empty-state-redesign`, `fix/practice-again-card-count`

---

## Phase 2 — Implement (after approval)

For each task, launch a subagent with `isolation: worktree`. Each subagent must:

1. **Create a branch** off main:
   ```
   git checkout -b [branch-name]
   ```

2. **Implement the task** following all project rules:
   - VIPER architecture — never skip layers
   - `.anyButton()` not `Button()`, `ImageLoaderView` not `AsyncImage`
   - Analytics tracking on every Presenter method
   - No force unwraps without justification
   - Build must succeed (run `xcodebuild -scheme "Keyoku - Mock" -destination "platform=iOS Simulator,id=7982E0CF-71DE-4FB0-B739-C7C28377DF98" build` to verify)

3. **Commit** using project conventions:
   - `[Feature]`, `[Bug]`, or `[Clean]` prefix
   - Short, descriptive message
   - No "Co-Authored-By" lines

4. **Push the branch**:
   ```
   git push -u origin [branch-name]
   ```

5. **Open a PR** using `gh pr create` with this body format:
   ```
   ## What
   [1-2 sentences: what was built or fixed]

   ## Why
   [1-2 sentences: the user problem or technical reason]

   ## Changes
   - [bullet list of specific files/components changed]

   ## Testing
   - [ ] Builds successfully on Mock scheme
   - [ ] [specific thing to tap/test]
   - [ ] [edge case to verify]

   ## Screenshots
   [Note: add before/after screenshots if UI changed]
   ```

Run independent tasks in parallel. Wait for dependencies to be noted before launching blocked tasks (you can't merge them, but note in the PR description which PR it depends on).

---

## Phase 3 — Handoff

After all subagents complete, present a summary:

```
Sprint Complete — Your PRs are ready for review
================================================
PR #[N]: [title] → [GitHub URL]
PR #[N]: [title] → [GitHub URL]
PR #[N]: [title] → [GitHub URL]

Review order recommendation:
1. Start with PR #[N] ([reason])
2. Then PR #[N] (depends on #[N] being merged first)

Tips:
- Use /pr-comments [PR number] to pull GitHub review comments back into Claude
- After merging a PR, run /subgo on the next one for a second opinion before approving
```

---

## Rules for Subagents

Each subagent must:
- Only touch files relevant to its task — no scope creep
- Leave no TODO comments or debug prints
- Not modify the same files as another task in this sprint (if unavoidable, note the conflict in the PR)
- Write a PR description a non-author could understand and review
