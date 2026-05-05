---
name: subgo
description: Run iOS, designer, and PM reviewers in parallel on recent changes
---

Run the ios-reviewer, designer-reviewer, and pm-reviewer subagents in parallel against the most recent changes in this session. If no specific changes were made in this session, ask the user what they want reviewed before proceeding.

Each subagent should review independently without seeing the others' output. After all three complete, present their findings together, clearly separated by reviewer role with a header for each.
