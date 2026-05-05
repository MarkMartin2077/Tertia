---
name: audit
description: Scan the codebase for technical debt: force unwraps, missing analytics, TODOs, violations
---

Run a codebase audit on Keyoku to surface accumulated technical debt and quality gaps. Scan the entire Keyoku/ source directory.

## Checks to Run

### 1. Force Unwraps
Search for `!` force unwraps in production Swift files (exclude test files and mock services).
- Flag any that aren't clearly safe (e.g., IBOutlets, known non-nil contexts)
- Group by file, sorted by highest count first

### 2. Missing Analytics in Presenters
Scan every file matching `*Presenter.swift`.
- Find every `func on...()` method (user-facing actions)
- Flag any that do NOT call `interactor.trackEvent` or `interactor.trackScreenEvent`
- List: file name, method name

### 3. TODO / FIXME / HACK Comments
Search for `// TODO`, `// FIXME`, `// HACK`, `// temp`, `// remove`, `// fix`
- List every occurrence with file and line number
- Note how old it looks based on surrounding context if possible

### 4. Spacer() Layout Violations
Search for `Spacer()` usage in View files.
- Flag uses where `.frame(maxWidth: .infinity, alignment:)` would be the correct pattern instead
- Ignore legitimate uses (e.g., pushing content to screen edges in a VStack with a single item)

### 5. AsyncImage Usage
Search for `AsyncImage` — this project should always use `ImageLoaderView` instead.
- List every occurrence with file name

### 6. Direct Manager Access from Views or Presenters
Search for patterns where a Presenter accesses a Manager directly (bypassing the Interactor layer).
- Look for `container.resolve` called outside of CoreInteractor
- Look for manager type names referenced directly in Presenter files

### 7. Large Files
List any Swift files in Keyoku/ exceeding 400 lines.
- File name and line count, sorted descending
- Note if they're approaching the 750-line SwiftLint limit

### 8. Missing #Preview Blocks
Scan component files in Components/Views/ and Components/Modals/.
- Flag any that have fewer than 2 `#Preview` blocks
- Components should always have multiple preview states

## Output Format
Group findings by category. For each category:
- Show a count (e.g. "12 force unwraps across 6 files")
- List the specific occurrences
- Give a priority: 🔴 Fix now / 🟡 Fix soon / 🟢 When you're in the area

End with a **Debt Score**: a rough estimate of how many hours it would take to address everything, and the top 3 highest-priority items to tackle first.
