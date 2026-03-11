---
name: fastlane-keyword-refinement
description: Refine localized App Store keywords and subtitle after metadata localization by analyzing each target market's search behavior, competitor patterns, and ASO opportunities.
---

# Fastlane Keyword Refinement

## Purpose

This skill refines **localized App Store metadata** after base metadata generation and localization are already complete.

It focuses on **market-specific ASO optimization**, especially for:

- `keywords.txt`
- `subtitle.txt`

This skill runs **after `fastlane-metadata-localization`** and before preflight check or deployment.

Recommended workflow:

```text
fastlane-base-metadata-builder
→ fastlane-metadata-localization
→ fastlane-keyword-refinement
→ fastlane-preflight-check
→ fastlane-deploy
```

This skill is not responsible for building the initial metadata foundation.  
It improves metadata that already exists.

---

## Inputs

This skill reads:

```text
fastlane/metadata/<locale>/
```

Especially:

- `name.txt`
- `subtitle.txt`
- `keywords.txt`
- `description.txt`

It may also read:

```text
.cursor/appstore-markets.json
```

to determine which locales are active.

Base locale reference may be:

```text
fastlane/metadata/en-US/
```

---

## Core Responsibilities

This skill performs:

1. locale-specific keyword refinement
2. subtitle refinement for ASO
3. competitor pattern comparison
4. keyword quality review
5. market-by-market optimization suggestions

It should improve metadata quality without changing the app's core positioning.

---

## When to Use

Use this skill when:

- localization is already complete
- metadata exists for multiple locales
- you want better keyword quality for each market
- you want to improve subtitle ASO
- you want to adapt keywords to local search behavior

Typical requests:

- "Refine keywords for Japanese and Korean markets."
- "Improve `keywords.txt` and subtitle for all active locales."
- "Optimize localized metadata for App Store search."
- "Review whether each market is using the best keyword set."

---

## Do NOT Use This Skill When

Do not use this skill when the task is mainly about:

- creating the initial English metadata
- translating metadata into other languages
- generating full descriptions from scratch
- uploading to App Store Connect
- validating Fastlane structure only
- generating release notes only

Use a different skill for:

- base metadata generation
- metadata localization
- preflight validation
- Fastlane deployment

---

## Core Principle

Do **not** assume that the best English keywords are the best local keywords.

This skill must treat each locale as its own App Store search environment.

Example:

- `en-US` may perform best with: `bible,verse,scripture`
- `ja` may need: `聖書,聖句,聖書アプリ`
- `ko` may need: `성경,성경말씀,오늘의말씀`

The goal is **local search relevance**, not literal translation.

---

## Supported Optimization Scope

This skill should prioritize refining:

- `keywords.txt`
- `subtitle.txt`

Optional, only if explicitly requested:

- `promotional_text.txt`
- small wording changes in `description.txt`

Do not rewrite:

- `name.txt`
- full `description.txt`

unless the user explicitly asks.

---

## Core Workflow

### Step 1 — Discover target locales

Determine which locales to refine.

Possible sources:

- user request
- `.cursor/appstore-markets.json`
- existing locale folders in `fastlane/metadata/`

If the user specifies locales, only refine those locales.

If not specified, refine active locales only.

---

### Step 2 — Read current localized metadata

For each locale, read:

- `name.txt`
- `subtitle.txt`
- `keywords.txt`
- `description.txt`

Understand the current positioning and wording.

Do not assume the current keywords are good.

---

### Step 3 — Compare against base positioning

Read `en-US` as the strategic baseline.

Check whether the localized metadata still reflects:

- product promise
- feature emphasis
- brand language
- intended use case

The refinement must improve ASO without changing product meaning.

---

### Step 4 — Analyze market-specific search language

For each locale, identify likely local search expressions.

Consider:

- common app-store phrasing
- natural local keyword forms
- short high-intent search terms
- local equivalents of major English terms

Do not simply translate the English keyword list.

---

### Step 5 — Refine keywords.txt

Generate an improved localized `keywords.txt`.

Rules:

- maximum 100 characters total
- comma separated only
- no spaces
- no duplicates
- avoid words already used in the title when possible
- prioritize high-intent and market-natural terms
- do not use filler terms

Show character count for every generated keyword list.

Example:

```text
聖書,聖句,毎日の聖句,祈り
Length: 16 / 100
```

---

### Step 6 — Refine subtitle.txt

Generate improved subtitle candidates.

Rules:

- maximum 30 characters
- preserve core product promise
- use natural market language
- improve search relevance where possible
- do not become spammy or awkward

Provide 2–3 candidate subtitles when useful.

---

### Step 7 — Review mode by locale type

#### Review mode for Chinese locales

Locales:

- `zh-Hans`
- `zh-Hant`

must be reviewed **field by field**.

Review order:

1. `subtitle.txt`
2. `keywords.txt`

The assistant must:

- show current text
- show proposed replacement
- show English reference if helpful
- show character count
- wait for confirmation before continuing

#### Auto mode for other locales

For locales such as:

- `ja`
- `ko`
- `de-DE`
- `fr-FR`
- `es-ES`

the assistant may refine automatically and produce a QA report.

---

### Step 8 — QA and semantic verification

For non-Chinese locales, perform light QA using:

- semantic consistency
- keyword quality
- market naturalness
- optional back translation check

The assistant should flag suspicious results such as:

- literal translation tone
- irrelevant or generic words
- weak keyword coverage
- subtitle too vague
- keyword list wasting character budget

---

### Step 9 — Summarize changes

After refinement, provide a concise summary.

Example:

```text
Refined locales: ja, ko, zh-Hant
Changed files: subtitle.txt, keywords.txt
Chinese review completed: zh-Hant
Potential follow-up: de-DE subtitle could be stronger
```

---

## Metadata Constraints

All refined metadata must respect App Store limits.

### Title

- maximum 30 characters

### Subtitle

- maximum 30 characters

### Keywords

- maximum 100 characters total
- comma separated
- no spaces

### Promotional Text

- maximum 170 characters

### Description

- maximum 4000 characters

### Release Notes

- maximum 4000 characters

This skill mainly modifies subtitle and keywords, so subtitle and keyword limits are mandatory.

---

## Review Interaction Format for Chinese

Use this format for Chinese locale review.

### Subtitle review example

```text
Locale: zh-Hant

Current subtitle:
每一刻都有聖經的話語

Proposed subtitle:
每個時刻看見神的話語

Characters: 11 / 30

Accept this change?
1. Accept
2. Edit
3. Regenerate
```

### Keywords review example

```text
Locale: zh-Hans

Current keywords:
圣经,经文,信仰

Proposed keywords:
圣经,经文,每日经文,祷告,信仰

Characters: 18 / 100

Accept this change?
1. Accept
2. Edit
3. Regenerate
```

Do not move to the next field before confirmation.

---

## Quality Heuristics

Use these heuristics when refining keywords.

### Good keywords are:

- short
- natural to the target market
- likely to match search intent
- non-redundant
- strongly related to the app

### Bad keywords are:

- literal translations that local users would not search
- words already fully covered by title and subtitle if character budget is tight
- vague generic terms with weak intent
- repeated variants that waste space

### Good subtitles are:

- concise
- natural
- benefit-led
- keyword-aware
- readable

### Bad subtitles are:

- stuffed with too many keywords
- awkward in the target language
- vague and generic
- too close to machine translation

---

## Safety and Change Control Rules

- Do not overwrite all locales unless explicitly asked.
- Do not rewrite full descriptions unless explicitly asked.
- Do not change app naming unless explicitly asked.
- Do not modify `zh-Hans` or `zh-Hant` automatically without interactive review.
- Do not assume local keyword quality from English keyword quality.
- Do not force identical keyword structures across all locales.

---

## Expected Output

Write refined metadata to existing locale folders:

```text
fastlane/metadata/<locale>/
```

Typically update:

- `subtitle.txt`
- `keywords.txt`

Optionally generate a refinement report in the assistant response including:

- locales refined
- character counts
- semantic confidence
- possible issues
- suggested next actions

---

## Recommended Collaboration with Other Skills

Suggested sequence:

```text
fastlane-base-metadata-builder
→ fastlane-metadata-localization
→ fastlane-keyword-refinement
→ fastlane-preflight-check
→ fastlane-deploy
```

This skill is the **market-specific ASO optimization layer** in the release pipeline.

---

## Final Instruction

When invoked, refine localized keywords and subtitles for the requested markets.

Preserve the app's meaning, improve local search relevance, and avoid literal keyword translation.

Treat each locale as a distinct ASO environment.
