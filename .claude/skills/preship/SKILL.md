---
name: preship
description: Run the full pre-ship gate before a TestFlight or App Store submission
---

You are running a pre-ship checklist for a TestFlight or App Store build of Keyoku. This is the final gate before the build goes out. Be thorough and honest — a missed issue here means a bad user experience in production.

## Step 1 — Parallel Expert Review
Run the ios-reviewer, designer-reviewer, and pm-reviewer subagents in parallel against the most recent changes in this session. Each reviews independently.

## Step 2 — Automated Checks
After the subagents complete, personally perform these checks by reading the relevant files:

**Analytics coverage**
- Scan every Presenter file modified in this session
- Flag any `func on...()` method that does NOT call `interactor.trackEvent(event:)` or `interactor.trackScreenEvent(event:)`
- List missing events by file and method name

**Force unwraps**
- Search modified Swift files for `!` force unwraps that are not in comments
- Flag any that are not in test files or clearly safe contexts

**TODO / FIXME**
- Search modified files for `// TODO`, `// FIXME`, `// HACK`, `// temp`, `// remove`
- List every occurrence with file and line number

**Accessibility**
- Check any new interactive elements (buttons, tappable views) for `.accessibilityLabel`
- Flag any `Image(systemName:)` used as a standalone interactive element without a label

**Empty & error states**
- For any new screen or modified section, confirm there is handling for: empty data, loading, and error

## Step 3 — Final Verdict
Summarize findings from all sources into three tiers:
- 🔴 **Must fix before shipping** — anything that would cause crashes, data loss, broken flows, or App Store rejection
- 🟡 **Should fix soon** — quality issues, missing analytics, minor UX problems
- 🟢 **Log for later** — polish, suggestions, future improvements

End with a clear one-line verdict:
**🚀 Ready to ship** / **⚠️ Ship after fixing [N] issues** / **🛑 Not ready — fix blockers first**
