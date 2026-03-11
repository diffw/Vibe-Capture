---
name: fastlane-preflight-check
description: Validate App Store metadata and Fastlane configuration before deployment. Ensures character limits, keyword quality, locale completeness, and market configuration consistency.
---

# Fastlane Preflight Check

## Purpose

This skill validates that all App Store metadata is ready for release before running Fastlane.

It acts as a **release safety layer** between metadata generation and deployment.

Workflow position:

Metadata Builder
→ Metadata Localization
→ Preflight Check
→ Fastlane Deploy

---

# Inputs

This skill reads:

fastlane/metadata/

and

.cursor/appstore-markets.json

---

# Stage 1 — Metadata Structure Validation

Check that each locale directory exists.

Example:

fastlane/metadata/en-US/
fastlane/metadata/ja/
fastlane/metadata/ko/
fastlane/metadata/zh-Hans/

Each locale must contain:

name.txt
subtitle.txt
keywords.txt
description.txt
promotional_text.txt
release_notes.txt

If files are missing, report them.

---

# Stage 2 — Character Limit Validation

App Store limits:

Title ≤ 30 characters
Subtitle ≤ 30 characters
Keywords ≤ 100 characters
Promotional text ≤ 170 characters
Description ≤ 4000 characters
Release notes ≤ 4000 characters

If limits are exceeded:

• Flag the file
• Suggest rewriting

---

# Stage 3 — Keyword Validation

Check keywords.txt for:

Duplicate words
Spaces after commas
Words already used in title/subtitle
Exceeding 100 characters

Example of correct format:

bible,verse,scripture,faith,christian,prayer

---

# Stage 4 — Market Configuration Validation

Read:

.cursor/appstore-markets.json

Check that each market has a matching metadata locale.

Example issue:

Market listed:
ja

But directory missing:
fastlane/metadata/ja/

Report mismatch.

---

# Stage 5 — Chinese Review Validation

Ensure Chinese locales were reviewed.

Locales requiring review:

zh-Hans
zh-Hant

If files were auto-generated without confirmation, warn user.

---

# Stage 6 — Fastlane Compatibility Check

Validate directory structure compatible with Fastlane.

Expected structure:

fastlane/
  metadata/
    en-US/
    ja/
    ko/
    zh-Hans/

If structure is invalid, report issue.

---

# Output

Generate a **Preflight Report**.

Example:

Preflight Report

Locales:
✓ en-US
✓ zh-Hans
✓ zh-Hant
✓ ja
✓ ko

Character limits:
✓ Passed

Keyword validation:
✓ Passed

Missing files:
None

Market configuration:
✓ Consistent

Status:
Ready for fastlane deploy

---

# Rules

Do not modify metadata automatically.

Only report issues and suggest fixes.

---

# When to Use

Use before:

fastlane deliver
fastlane deliver --metadata_only

---

# Expected Result

After running this skill the metadata should be:

• structurally complete
• within App Store limits
• keyword optimized
• ready for deployment
