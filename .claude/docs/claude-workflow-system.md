# Claude Code Workflow System

A personal productivity and collaboration system built on top of Claude Code. Designed for solo iOS developers who want expert-level code reviews, structured decision-making, and a simulated team workflow using AI subagents.

---

## Table of Contents

1. [What This System Does](#what-this-system-does)
2. [How It's Structured](#how-its-structured)
3. [Subagents — Expert Reviewers](#subagents--expert-reviewers)
4. [Custom Commands](#custom-commands)
5. [Built-In Commands Worth Knowing](#built-in-commands-worth-knowing)
6. [The Solo Team Workflow](#the-solo-team-workflow)
7. [Installing Into a New Project](#installing-into-a-new-project)
8. [Adapting to a New Project](#adapting-to-a-new-project)

---

## What This System Does

This system turns Claude Code into a simulated engineering team. Instead of getting one perspective on your code, you get simultaneous reviews from a staff iOS engineer, a senior designer, and a senior product manager — each with full knowledge of your codebase's specific patterns and conventions.

On top of that, a set of custom commands handles the repetitive parts of shipping: pre-ship checklists, App Store release notes, codebase audits, structured decision-making, and a full GitHub PR workflow that mirrors working on a real team.

**Core capabilities:**
- Parallel expert code reviews (3 perspectives at once)
- Pre-ship gate that catches issues before they reach users
- Simulated team workflow: plan → branch → implement → PR → review → merge
- Codebase health audits on demand
- Structured approach to architecture decisions
- App Store release note generation

---

## How It's Structured

```
.claude/
├── agents/                  # Subagent definitions (expert reviewers)
│   ├── ios-reviewer.md
│   ├── designer-reviewer.md
│   └── pm-reviewer.md
├── commands/                # Custom slash commands
│   ├── subgo.md             # Trigger all 3 reviewers in parallel
│   ├── preship.md           # Full pre-ship checklist
│   ├── appstore.md          # Generate App Store release notes
│   ├── audit.md             # Codebase health scan
│   ├── decide.md            # Structured decision-making
│   ├── sprint.md            # Full team PR workflow
│   └── respond.md           # Address GitHub review comments
└── docs/
    └── claude-workflow-system.md   # This file
```

---

## Subagents — Expert Reviewers

Subagents are specialized AI assistants with their own system prompt, tool access, and independent context. They run in parallel, each thinking from a completely different perspective without contaminating the others.

### How to Trigger Them

**All three at once (most common):**
```
Have ios-reviewer, designer-reviewer, and pm-reviewer review my recent changes in parallel
```

**One at a time:**
```
Have the designer-reviewer look at the new onboarding screen
```

**Via the /subgo command (fastest):**
```
/subgo
```

---

### ios-reviewer

**File:** `.claude/agents/ios-reviewer.md`
**Model:** Sonnet
**Tools:** Read, Grep, Glob (read-only — no editing)

A staff iOS engineer who reviews Swift/SwiftUI code for architectural correctness, performance, and best practices. Knows your project's specific conventions.

**What it checks:**
- VIPER layer violations (View accessing Manager directly, etc.)
- Layer completeness (Router protocol declares all needed methods, Interactor exposes all needed data)
- Threading — async work in `Task {}`, UI updates on main actor
- Memory — retain cycles, missing `[weak self]`
- Analytics — every user-facing Presenter method must call `trackEvent`
- Build config guards — Firebase code inside `#if !MOCK`
- SwiftUI correctness — unnecessary re-renders, expensive computed properties in `body`
- Edge cases — empty arrays, nil optionals, network failures, rapid taps

**Output format:**
- Overall assessment paragraph
- Findings grouped: 🔴 Critical / 🟡 Should Fix / 🟢 Minor
- Each finding: file + line, problem, fix
- Verdict: Approved / Approve with minor fixes / Needs changes

**To adapt for a new project:**
Update the "Project Context" section with your architecture (VIPER, MVVM, TCA, etc.), navigation library, state management approach, and any project-specific rules.

---

### designer-reviewer

**File:** `.claude/agents/designer-reviewer.md`
**Model:** Sonnet
**Tools:** Read, Grep, Glob (read-only)

A senior product designer who reviews UI implementation from the user's perspective. Thinks about what confused users experience, not what the engineer intended.

**What it checks:**
- Empty, loading, and error states — handled and purposeful?
- Visual hierarchy — does the eye know where to go?
- Spacing, layout, and balance
- Typography — right sizes and weights, legible at minimum scale?
- Color — accent used purposefully, sufficient contrast?
- Tap targets — all interactive elements at least 44×44pt?
- Accessibility — `accessibilityLabel` on interactive elements, icons labeled?
- Interaction feedback — do buttons feel responsive?
- iOS conventions — does this feel native?
- Edge cases — long text, large Dynamic Type, one item vs many?
- Preview coverage — multiple `#Preview` states per component?

**Output format:**
- First impression as a user
- Findings grouped: 🔴 Blocks shipping / 🟡 Fix before release / 🟢 Polish
- Each finding: user-perspective problem description, then fix
- Verdict: Approved / Approve with minor polish / Needs redesign

**To adapt for a new project:**
Update the app description, user persona, design language, and any component-specific rules (e.g. which button/image components are required).

---

### pm-reviewer

**File:** `.claude/agents/pm-reviewer.md`
**Model:** Sonnet
**Tools:** Read, Grep, Glob (read-only)

A senior product manager who reviews features for completeness, production risk, and business alignment. Finds what you forgot when you were heads-down building.

**What it checks:**
- Feature completeness — is this actually done?
- User journeys — works for new user, returning user, power user?
- Edge cases — 0 items, 1 item, 100 items, offline, rapid taps?
- Analytics instrumentation — right events tracked, correct naming convention?
- Error handling — are errors actionable for the user?
- Paywall / monetization — premium gating correct?
- Regression risk — what adjacent features could break?
- Notification/streak impact — does this affect scheduling or gamification?
- Onboarding impact — how does this affect a new user's first experience?
- Production risk — anything that could spike crashes or support tickets?

**Output format:**
- Product assessment: ready to ship?
- Findings grouped: 🔴 Blocks release / 🟡 High priority / 🟢 Future iteration
- Each finding: user scenario, risk, recommended fix
- Missing analytics called out explicitly by event name
- Verdict: Ship it / Ship with minor fixes / Not ready

**To adapt for a new project:**
Update the app description, monetization model, core metrics, analytics naming convention, user types, and build config names.

---

## Custom Commands

Custom commands live in `.claude/commands/` and are triggered by typing `/commandname` in Claude Code. They accept arguments via `$ARGUMENTS`.

---

### /subgo

**File:** `.claude/commands/subgo.md`
**Usage:** `/subgo`

Runs all three reviewers (ios-reviewer, designer-reviewer, pm-reviewer) in parallel against the most recent changes in the session. Each reviews independently. Results are presented together, separated by reviewer.

**When to use:** After implementing any feature or fix. The fastest way to get a full review.

---

### /preship

**File:** `.claude/commands/preship.md`
**Usage:** `/preship`

A comprehensive pre-ship gate designed to run before every TestFlight or App Store build. Combines the three parallel expert reviews with a set of automated code checks.

**What it does:**
1. Runs ios-reviewer, designer-reviewer, pm-reviewer in parallel
2. Scans for missing analytics events in modified Presenters
3. Searches for force unwraps (`!`) in production code
4. Finds TODO / FIXME / HACK comments
5. Checks new interactive elements for accessibility labels
6. Verifies empty and error states exist for new screens/sections

**Output:** Three-tier summary (🔴 Must fix / 🟡 Should fix / 🟢 Log for later) with a final one-line verdict: Ready to ship / Ship after fixing N issues / Not ready.

**When to use:** Before every build that goes to external testers or the App Store.

---

### /appstore

**File:** `.claude/commands/appstore.md`
**Usage:** `/appstore`

Generates App Store "What's New" release notes from your git commit history. Reads the last 20 commits, filters out developer-only changes (refactors, analytics, config), and writes three versions of the release notes with different tones.

**Output:**
- Version A: Clean & Minimal (Apple's own style, bullet points)
- Version B: Warm & Conversational (friendly developer voice)
- Version C: Punchy & Energetic (short sentences, active voice)
- Recommendation: which version to use and why

**Rules enforced:**
- No technical jargon (no "VIPER", "Firestore", "refactor")
- No version numbers or build numbers
- Focuses on what users can now *do*, not what was built
- Bug fixes framed as "X now works correctly" not "we fixed a bug"

**When to use:** When preparing a new release. Run it, pick a version, copy/paste into App Store Connect.

**To adapt for a new project:**
The command is generic and works for any app. No changes needed.

---

### /audit

**File:** `.claude/commands/audit.md`
**Usage:** `/audit`

Scans the entire codebase for accumulated technical debt and quality gaps. Meant to be run periodically (every few weeks) to catch what accumulates when you're moving fast.

**Checks:**
1. Force unwraps (`!`) in production code — grouped by file, sorted by count
2. Missing analytics in Presenters — any `func on...()` without `trackEvent`
3. TODO / FIXME / HACK comments — every occurrence with file and line
4. Spacer() violations — where `frame(maxWidth: .infinity, alignment:)` should be used instead
5. AsyncImage usage — should always be ImageLoaderView in this project
6. Direct Manager access from Views or Presenters — VIPER layer violations
7. Large files — anything over 400 lines (SwiftLint limit is 750)
8. Missing #Preview blocks — components should have 2+ preview states

**Output:** Each category with a count, specific occurrences, and priority. Ends with a Debt Score (estimated hours to fix) and the top 3 items to tackle first.

**To adapt for a new project:**
Replace the project-specific checks (AsyncImage, Spacer(), VIPER violations) with your own architectural rules. Keep the generic ones (force unwraps, TODOs, large files).

---

### /decide

**File:** `.claude/commands/decide.md`
**Usage:** `/decide [describe the decision and options]`

Takes a technical or product decision with two or more options and gives you a structured recommendation from both an engineering and product perspective.

**Example:**
```
/decide should I use a local notification manager or integrate with Firebase for study reminders?
```

**What it does:**
1. Reads relevant codebase context to give grounded (not generic) advice
2. Runs ios-reviewer and pm-reviewer in parallel, each evaluating the options
3. Synthesizes into a comparison table and a clear recommendation with reasoning

**Output:**
- Comparison table (architecture fit, user impact, implementation effort, risk, reversibility)
- Recommendation with 2-3 sentence reasoning
- One specific risk/gotcha for the recommended option

**When to use:** When you're stuck choosing between two approaches. Especially useful late at night when you're debating yourself.

**To adapt for a new project:**
No changes needed — the command is fully generic.

---

### /sprint

**File:** `.claude/commands/sprint.md`
**Usage:** `/sprint [describe the feature or set of features to build]`

The flagship command. Orchestrates a full simulated team workflow: planning, parallel implementation in isolated git worktrees, and opening real GitHub PRs for you to review.

**Example:**
```
/sprint add a study reminders screen to Profile and fix the streak display on Home
```

**What it does:**

**Phase 1 — Plan:**
Breaks the work into atomic, independently-implementable tasks. Each task gets a branch name and one-sentence description. Identifies which tasks can run in parallel and which are sequential. Presents the plan for your approval before touching any code.

**Phase 2 — Implement:**
For each approved task, launches a subagent with `isolation: worktree` — an isolated copy of the repo. Each subagent:
- Creates a branch off main
- Implements the task following project conventions
- Verifies the build succeeds
- Commits with the project's message format
- Pushes the branch
- Opens a PR on GitHub with a standardized description (What / Why / Changes / Testing checklist)

Independent tasks run in parallel. Dependent tasks note the dependency in their PR description.

**Phase 3 — Handoff:**
Presents all opened PR URLs with a recommended review order. Notes any dependencies between PRs.

**After /sprint — your role as reviewer:**
- Open each PR on GitHub
- Leave inline comments on anything that looks wrong
- Request changes or approve
- Use `/respond [PR number]` to have Claude address your review comments
- Merge approved PRs

**When to use:** When building a multi-part feature or several independent improvements at once. Creates a real, auditable git history of atomic changes.

**Important:**
- Be specific: "add study reminders screen" works. "improve the app" is too vague.
- The plan step requires your approval — don't skip reviewing it.
- Tasks with shared file dependencies will note conflicts in their PR descriptions.

---

### /respond

**File:** `.claude/commands/respond.md`
**Usage:** `/respond [PR number]`

**Example:**
```
/respond 47
```

Closes the loop on the GitHub review workflow. After you leave review comments on a PR, this command fetches those comments, addresses every requested change in the code, commits, pushes, and replies to the comments on GitHub.

**What it does:**
1. Fetches PR diff and all review comments using `gh` CLI
2. Categorizes comments (🔴 must address / 🟡 should address / 🟢 consider)
3. Checks out the PR branch
4. Implements fixes for every 🔴 and 🟡 comment
5. Commits and pushes
6. Posts replies to GitHub comments explaining what changed

**The loop:**
```
/sprint → PRs open → you review on GitHub → /respond → you re-review → merge
```

**When to use:** After leaving review comments on a sprint-generated PR. Also works on any PR, not just sprint-generated ones.

---

## Built-In Commands Worth Knowing

These come with Claude Code and require no setup.

| Command | When to use it |
|---|---|
| `/plan` | Before any complex change — think before you code |
| `/review` | Review the current branch's PR against main |
| `/security-review` | Scan pending changes for security vulnerabilities |
| `/rewind` | Roll back conversation AND code to a previous point |
| `/diff` | Interactive viewer of all uncommitted changes |
| `/compact` | Compress context when you're running low mid-session |
| `/cost` | See how many tokens you've used in this session |
| `/pr-comments [PR]` | Pull GitHub review comments into your session |
| `/fork` | Fork the conversation at this point (try two approaches) |
| `/subgo` | (Custom) Run all 3 reviewers in parallel |

---

## The Solo Team Workflow

The full day-to-day flow using everything in this system:

### Building a New Feature

```
1. /plan
   Describe what you want to build. Claude enters plan mode,
   explores the codebase, and presents a step-by-step approach.
   You approve before any code is written.

2. /sprint [feature description]
   Claude breaks the work into atomic tasks and presents them.
   You approve the task breakdown.
   Subagents implement each task in parallel on isolated branches.
   PRs open on GitHub automatically.

3. Review on GitHub
   Open each PR. Read the diff. Leave inline comments.
   Be a tough reviewer — that's the point.
   Request changes on anything that violates conventions.
   Approve what's solid.

4. /respond [PR number]
   Claude reads your comments, fixes the code, pushes, and replies.
   Re-review the updated diff on GitHub.
   Merge when satisfied.

5. /subgo  (optional second pass)
   Run all 3 reviewers on the final state before merging
   if you want an extra layer of confidence.
```

### Before Shipping a Build

```
1. /preship
   Full gate check — 3 reviewers + automated scans.
   Fix everything marked 🔴.
   Log 🟡 items as follow-up.

2. /appstore
   Generate release notes from git history.
   Pick a version, paste into App Store Connect.
```

### Periodic Maintenance

```
/audit   (every 2-4 weeks)
Catch accumulated debt before it compounds.
Address top 3 items in the next quiet period.
```

### Stuck on an Approach

```
/decide [describe the two options]
Get a grounded recommendation from engineering + product perspectives.
Read the reasoning, make the call, move on.
```

---

## Installing Into a New Project

To bring this system into a new project, copy the following files and customize them for the new codebase.

### Files to Copy

```
.claude/
├── agents/
│   ├── ios-reviewer.md       ← customize Project Context section
│   ├── designer-reviewer.md  ← customize app description and patterns
│   └── pm-reviewer.md        ← customize app description, metrics, monetization
└── commands/
    ├── subgo.md              ← no changes needed
    ├── preship.md            ← update build command if different scheme/simulator
    ├── appstore.md           ← no changes needed
    ├── audit.md              ← update project-specific checks
    ├── decide.md             ← no changes needed
    ├── sprint.md             ← update build command if different scheme/simulator
    └── respond.md            ← no changes needed
```

### Quick Checklist

- [ ] Copy all files above into new project's `.claude/` directory
- [ ] Update `ios-reviewer.md` — replace architecture, navigation, state management, and project-specific rules
- [ ] Update `designer-reviewer.md` — replace app description, user, and design system conventions
- [ ] Update `pm-reviewer.md` — replace app description, monetization model, analytics naming, user types
- [ ] Update `preship.md` and `sprint.md` — replace `xcodebuild` command with correct scheme and simulator ID
- [ ] Confirm `gh` CLI is authenticated (`gh auth status`) for sprint and respond commands
- [ ] Test with `/subgo` on a small change to verify agents are working

### Finding Your Simulator ID

```bash
xcrun simctl list devices available | grep "iPhone"
```

Copy the UUID and replace `id=7982E0CF-71DE-4FB0-B739-C7C28377DF98` in `preship.md` and `sprint.md`.

### Finding Your Scheme Name

```bash
xcodebuild -list
```

Copy the scheme name (e.g. `MyApp - Mock`) and replace in both commands.

---

## Adapting to a New Project

### For Non-VIPER Projects

The ios-reviewer checks VIPER layer violations specifically. For MVVM:
- Replace VIPER rules with: "ViewModel should not import UIKit", "Views should not contain business logic"
- Replace Interactor references with Repository or Service layer
- Replace Router references with Coordinator or NavigationPath

For TCA (The Composable Architecture):
- Replace VIPER rules with: "Side effects only in Reducers", "State mutations only through Actions", "Dependencies injected via `@Dependency`"

### For Non-iOS Projects

The ios-reviewer and designer-reviewer are iOS-specific. For React Native, Flutter, or web:
- Rename to match the stack (e.g. `react-native-reviewer.md`)
- Update Project Context to reflect the framework
- Replace SwiftUI-specific checks with platform equivalents
- The pm-reviewer, /decide, /audit (generic checks), /appstore, and /sprint are all platform-agnostic

### For Teams (Not Solo)

If you eventually have a real team:
- Move agent files to a shared repo or organization-level `.claude/agents/`
- The `/sprint` workflow already produces real PRs — real teammates can review them the same way you do
- `/respond` works for any GitHub PR, not just AI-generated ones
- `/preship` becomes a required CI gate rather than a manual step

---

*This document covers the full Claude Code workflow system as built for Keyoku (iOS, VIPER, SwiftUI). Last updated March 2026.*
