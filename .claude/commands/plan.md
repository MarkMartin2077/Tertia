---
description: Plan a feature before implementing it using the feature-planner agent.
model: opus
---

Ask the user to describe the feature they want to build. Then use the Task tool to invoke the `feature-planner` agent with their description.

The planner will explore the codebase and return an implementation spec with:
- Files to create and modify
- Data flow through VIPER layers
- Manager dependencies
- Navigation plan
- Edge cases to handle
