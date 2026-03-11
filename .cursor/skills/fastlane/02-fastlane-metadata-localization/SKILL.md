---
name: fastlane-metadata-localization
description: Generate localized App Store metadata from the base en-US metadata with ASO-aware localization, automatic QA, and interactive review for Chinese locales.
---

# Fastlane Metadata Localization (v2)

## Purpose

This skill generates localized App Store metadata for multiple markets based on the **base locale (en-US)**.

It supports:

- ASO-aware localization (not literal translation)
- automatic QA validation
- back translation verification
- interactive review mode for Chinese locales
- fastlane-compatible metadata output

This skill runs **after `fastlane-base-metadata-builder`**.

---

# Inputs

The skill reads the base metadata:

fastlane/metadata/en-US/

Files:

name.txt  
subtitle.txt  
keywords.txt  
description.txt  
promotional_text.txt  
release_notes.txt  

It also reads market configuration:

.cursor/appstore-markets.json

---

# Localization Modes

The skill supports two modes.

## Auto Mode

Used for locales where the user cannot manually review the language.

Examples:

ja  
ko  
de-DE  
fr-FR  
es-ES  

Workflow:

Generate localization  
↓  
Back-translation check  
↓  
Keyword semantic verification  
↓  
Generate QA report  

No user confirmation required.

---

## Review Mode

Used for locales the user can review.

Default:

zh-Hans  
zh-Hant  

Workflow:

Generate candidate localization  
↓  
Present field-by-field review  
↓  
Wait for confirmation  
↓  
Proceed to next field  

---

# Review Mode Workflow

Fields must be reviewed sequentially.

Order:

1 name  
2 subtitle  
3 keywords  
4 promotional_text  
5 description  
6 release_notes  

The assistant must:

- show English source
- show localized candidate
- show character count
- wait for user confirmation

---

# Example Review Interaction

## Step 1 — Name

Locale: zh-Hans

English:

Bible Clock

Candidate:

圣经时刻

Characters: 4 / 30

Options:

1 Accept  
2 Edit  
3 Regenerate  

Wait for user response before continuing.

---

## Step 2 — Subtitle

English:

A verse for every moment

Candidate:

每一刻都有圣经的话语

Characters: 11 / 30

Confirm before continuing.

---

## Step 3 — Keywords

Candidate:

圣经,经文,每日经文,信仰,祷告

Characters: 22 / 100

Confirm before continuing.

---

# ASO-aware Localization

Localization must adapt to the target market instead of literal translation.

Adjust:

- search keywords
- phrasing patterns
- store language norms

Example:

English:

Bible verse for every moment

Japanese example:

毎日の聖句をあなたに

---

# Back Translation QA

For auto-mode locales the assistant must perform:

localized text  
↓  
back translate to English  
↓  
compare semantic meaning  

If meaning diverges significantly, rewrite localization.

---

# Metadata Constraints

All localized metadata must respect App Store limits.

Title ≤ 30 characters  
Subtitle ≤ 30 characters  
Keywords ≤ 100 characters  
Promotional text ≤ 170 characters  
Description ≤ 4000 characters  
Release notes ≤ 4000 characters  

If limits are exceeded, rewrite automatically.

---

# Localization QA Report

For each locale produce a report.

Example:

Locale: ja

Meaning accuracy: High  
Keyword coverage: Good  
ASO alignment: Strong  
Potential issues: None  

---

# Output

Write localized metadata to:

fastlane/metadata/<locale>/

Example:

fastlane/metadata/ja/  
fastlane/metadata/ko/  
fastlane/metadata/de-DE/  
fastlane/metadata/zh-Hans/  
fastlane/metadata/zh-Hant/  

Files generated:

name.txt  
subtitle.txt  
keywords.txt  
description.txt  
promotional_text.txt  
release_notes.txt  

---

# Rules

## Sequential review for Chinese

Locales:

zh-Hans  
zh-Hant  

must use review mode.

## Auto mode for other languages

Locales not listed for review use automatic generation and QA.

## Preserve product positioning

Localization must preserve the meaning of the base metadata.

---

# When to Use

Use when:

- base metadata already exists
- preparing multi-language App Store release
- generating localized metadata before Fastlane upload

---

# Expected Result

After running this skill the project should contain:

fastlane/metadata/<locale>/

for each target market.

Chinese locales are manually reviewed.
Other locales are automatically localized and QA checked.
