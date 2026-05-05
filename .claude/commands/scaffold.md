---
description: Scaffold new files (screens, managers, components, models, tests, etc.) using the scaffolder agent.
model: sonnet
---

Ask the user what they want to scaffold. Present these options:

1. **Screen** — VIPER screen (View, Presenter, Interactor, Router) with RIBs wiring
2. **Manager** — Manager with service protocol + Mock/Prod implementations
3. **Component** — Dumb UI component with injected data
4. **Model** — Codable/Sendable model with CodingKeys, eventParameters, mocks
5. **Test** — Swift Testing unit test file
6. **Module** — Top-level navigation module
7. **Paywall** — Paywall variant with AB test wiring
8. **AB Test** — AB test service + mock + DevSettings wiring
9. **View Modifier** — ViewModifier + View extension
10. **Extension** — Type extension file
11. **Package** — SPM package integration
12. **Deep Link** — Deep link / push notification handler

After the user picks an option and describes what they need, use the Task tool to invoke the `scaffolder` agent with their request. Pass the full description of what to create.
