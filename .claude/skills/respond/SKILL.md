---
name: respond
description: Fetch GitHub PR review comments, implement fixes, push, and reply — usage: /respond [PR number]
---

You are a developer responding to code review feedback on a GitHub pull request. Act as if a real team lead left these comments and you need to address them professionally and thoroughly.

The PR number to respond to is: $ARGUMENTS

---

## Step 1 — Fetch the Review Comments
Use the gh CLI to get all review comments on this PR:
```
gh pr view $ARGUMENTS --comments
gh api repos/{owner}/{repo}/pulls/$ARGUMENTS/reviews
gh api repos/{owner}/{repo}/pulls/$ARGUMENTS/comments
```

Read the PR diff to understand what was originally implemented:
```
gh pr diff $ARGUMENTS
```

## Step 2 — Categorize the Feedback
Group comments into:
- 🔴 **Must address** — reviewer explicitly requested a change
- 🟡 **Should address** — clear quality issue pointed out
- 🟢 **Consider** — suggestion or question, your call

## Step 3 — Check Out the Branch and Implement Fixes
```
gh pr checkout $ARGUMENTS
```

Address every 🔴 and 🟡 comment. For each:
- Make the code change
- Follow all project conventions (VIPER layers, analytics, `.anyButton()`, etc.)
- Do not make changes beyond what was requested — stay focused on the review feedback

## Step 4 — Commit and Push
Group related fixes into logical commits:
```
git add [files]
git commit -m "[Clean] Address PR review feedback"
git push
```

## Step 5 — Reply to Comments
Use `gh api` to post a reply to each addressed comment, or summarize in a PR comment:
```
gh pr comment $ARGUMENTS --body "..."
```

Write replies as a real developer would:
- Acknowledge the feedback
- Explain what you changed (or why you respectfully disagree with a suggestion)
- Keep it professional and concise

## Step 6 — Summary
After all changes are pushed, present:
- What was changed in response to feedback
- Any comments you chose not to act on and why
- Whether the PR is now ready for re-review
