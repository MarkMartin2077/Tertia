---
description: Review code against project rules using the code-reviewer agent.
model: sonnet
---

Ask the user what they want reviewed. Options:

1. **Specific files** — Review named files or a directory
2. **Recent changes** — Review uncommitted changes (`git diff`)
3. **Full project** — Review all source files against project rules

After the user picks an option, use the Task tool to invoke the `code-reviewer` agent with the review scope. Include specific file paths or "review all recent changes" as appropriate.
