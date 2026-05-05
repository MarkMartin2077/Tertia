---
name: appstore
description: Generate App Store What's New copy from recent git commits
---

Generate App Store release notes for Keyoku based on recent changes.

## Step 1 — Gather Changes
Run this to get the last 20 commits:
```
git log --oneline -20
```
Also look at what changed in this session if applicable.

## Step 2 — Understand the Changes
Read the commit messages and identify:
- New features users will notice
- Bug fixes that affected the user experience
- Performance improvements
- Anything removed or changed that users might notice

Ignore: internal refactors, analytics changes, code cleanup, dependency updates, config changes — users don't care about these.

## Step 3 — Write 3 Versions of "What's New"

Write three different versions of the App Store "What's New" section, each with a different tone:

**Version A — Clean & Minimal** (Apple's own style)
- Bullet points, 3-5 items max
- Short, factual, no fluff
- Under 150 words total

**Version B — Warm & Conversational**
- Friendly, human tone
- Reads like a message from the developer
- Highlights the user benefit, not the feature name
- Under 200 words

**Version C — Punchy & Energetic**
- Short sentences, active voice
- Leads with the most exciting change
- Under 150 words

## Step 4 — Recommendation
State which version you'd recommend and why, based on what was shipped.

## Format Rules (all versions)
- Never use technical jargon ("VIPER", "Firestore", "presenter", "refactor")
- Never mention version numbers or build numbers
- Write in plain English a non-technical user understands
- Focus on what the user can now DO, not what you built
- If it was a bug fix, say what now works correctly, not that there was a bug
