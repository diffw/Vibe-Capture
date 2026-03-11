---
name: fastlane-base-metadata-builder
description: Analyze product documentation, research competitors, interactively design App Store metadata, validate constraints, and generate base Fastlane metadata and market configuration.
---

# Fastlane Base Metadata Builder (v4)

## Purpose

This skill builds the **base App Store metadata (en-US)** and **market release configuration** for the app.

It performs:

- product document analysis
- competitor research
- ASO keyword strategy
- interactive confirmation with the user
- metadata validation (App Store constraints)
- fastlane metadata generation

This skill runs **before metadata localization and Fastlane delivery**.

---

# Stage 1 — Product Understanding

Read product documentation.

Possible sources:

.vibe-doc/PRD.md  
.vibe-doc/product-spec-ios.md  
.vibe-doc/architecture.md  
docs/  
README.md  
website copy  

Extract:

- product purpose
- core user persona
- main use cases
- key features
- differentiation
- brand tone

Produce a **Product Understanding Summary**.

Ask the user to confirm the summary before continuing.

---

# Stage 2 — Competitor Research

Identify **5–10 competing apps** in the same category.

For each competitor analyze:

App Name  
Subtitle  
Primary positioning  
Description structure  
Primary category  

Produce a **Competitor Analysis Report** including:

### Competitor Table

App | Positioning | Category | Keyword Focus

### Metadata Patterns

Identify:

- common title structures
- common keywords
- common subtitle strategies

### Opportunities

Identify:

- keyword gaps
- positioning opportunities
- differentiation angles

Ask the user to confirm the report before continuing.

---

# Stage 3 — Keyword Strategy

Generate keyword clusters.

Primary keywords  
Secondary keywords  
Long-tail keywords  

Then propose the final `keywords.txt`.

### Constraints

keywords ≤ 100 characters  
comma separated  
no spaces  
no duplicate words  

Example:

bible,verse,scripture,faith,christian,prayer

Ask the user to confirm before continuing.

---

# Stage 4 — Interactive Metadata Design

Metadata must be confirmed **one field at a time**.

Never present all metadata simultaneously.

Fields must be confirmed in this order:

1. App Name  
2. Subtitle  
3. keywords.txt  
4. Description outline  
5. Full description  
6. Promotional text  
7. Release notes  
8. URLs (marketing_url, privacy_url, support_url)  

Each step must:

1. Present candidate options
2. Ask the user for confirmation
3. Wait for a response
4. Apply edits if requested
5. Proceed only after confirmation

---

# Metadata Constraints

All generated metadata must respect App Store limits.

Title ≤ 30 characters  
Subtitle ≤ 30 characters  
Keywords ≤ 100 characters  
Promotional text ≤ 170 characters  
Description ≤ 4000 characters  
Release notes ≤ 4000 characters  
URLs must be valid HTTPS URLs

If limits are exceeded, rewrite automatically.

# URL Fields

The following URLs are required by App Store Connect and must be collected from the user:

marketing_url — the app's product website or landing page  
privacy_url — the app's privacy policy page (required by Apple)  
support_url — the app's support page or contact page

Ask the user to provide these URLs.  
If the user does not have a dedicated support page, the marketing URL may be reused.

These URLs are **not locale-specific** — the same values apply across all markets.  
They are stored in `fastlane/metadata/en-US/` and shared by all locales.

---

# Stage 5 — Market Strategy

Propose recommended release markets.

Example:

en-US  
en-GB  
ja  
ko  
de-DE  
fr-FR  
es-ES  
zh-Hant  

Ask the user to confirm or modify.

Generate:

.cursor/appstore-markets.json

Example:

{
"default_locale": "en-US",
"markets": [
"en-US",
"en-GB",
"ja",
"ko",
"de-DE",
"fr-FR",
"es-ES",
"zh-Hant"
],
"excluded_markets": [
"zh-Hans"
]
}

---

# Stage 6 — Category Strategy

Propose:

Primary Category  
Secondary Category  

Explain reasoning and ask the user to confirm.

Write:

fastlane/metadata/primary_category.txt  
fastlane/metadata/secondary_category.txt  

---

# Stage 7 — Metadata Generation

Only after **all fields are confirmed** generate files.

Directory:

fastlane/metadata/en-US/

Files generated:

name.txt  
subtitle.txt  
keywords.txt  
description.txt  
promotional_text.txt  
release_notes.txt  
marketing_url.txt  
privacy_url.txt  
support_url.txt  

---

# Rules

## Sequential confirmation

Metadata must be confirmed sequentially.  
Never ask for confirmation of multiple fields at once.

## Avoid keyword waste

Avoid repeating words already used in:

title  
subtitle  

## Avoid exaggerated claims

Do not include:

- fake awards
- unsupported statements
- misleading language

---

# When to Use This Skill

Use when:

- creating App Store metadata for a new app
- rebuilding metadata from product documentation
- preparing a Fastlane metadata pipeline

---

# Expected Result

After running this skill the project should contain:

fastlane/metadata/en-US/  
  name.txt  
  subtitle.txt  
  keywords.txt  
  description.txt  
  promotional_text.txt  
  release_notes.txt  
  marketing_url.txt  
  privacy_url.txt  
  support_url.txt  
.cursor/appstore-markets.json  
fastlane/metadata/primary_category.txt  
fastlane/metadata/secondary_category.txt  

This becomes the foundation for:

metadata localization  
ASO optimization  
fastlane delivery
