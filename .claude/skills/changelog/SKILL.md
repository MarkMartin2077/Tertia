---
name: changelog
description: Generate user-facing release notes from git commits — usage: /changelog [tag or range]
---

Generate a user-facing changelog for Keyoku from recent git commits.

$ARGUMENTS can optionally specify a version tag or commit range (e.g. "v1.2.0" or "v1.1.0..v1.2.0"). If not provided, use all commits since the last git tag.

---

## Step 1 — Get the commits

```bash
# Get the last tag
git describe --tags --abbrev=0

# Get commits since that tag (or all commits if no tag exists)
git log [last-tag]..HEAD --oneline --no-merges
```

## Step 2 — Categorize commits

Group commits by their prefix:
- `[Feature]` → New features for users
- `[Bug]` → Bug fixes
- `[Clean]` → Internal improvements (usually omit from user-facing notes unless impactful)

Ignore: merge commits, dependency bumps, config changes, and anything that only affects developer tooling.

## Step 3 — Generate three versions

### Version 1 — App Store "What's New" (max 4000 chars, plain text, no markdown)
Warm, user-facing tone. Lead with the biggest feature. Keep it scannable with short paragraphs. No technical jargon.

### Version 2 — TestFlight Release Notes (concise, bullet list)
Testers want specifics. Use bullets. Include bug fixes. Mention where to focus testing. Max ~300 words.

### Version 3 — Internal Dev Summary (technical, for your own records)
Full list of everything that changed, including [Clean] commits. File names and technical details are fine here.

## Step 4 — Output all three

Present all three versions clearly labeled so you can copy/paste the right one for each context.
