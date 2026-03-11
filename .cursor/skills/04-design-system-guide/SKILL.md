---
name: design-system-guide
description: Design System specification guide. Triggered when user mentions keywords like "UI design", "UX design", "design optimization", "interface design", "interaction design", "visual design", "styling", "component style", "design specs", "build a page", "create an interface". Automatically reads Design Principles, Design Tokens, and platform-specific Design System docs to ensure output follows unified design standards.

---

# Design System Guide

When this Skill is triggered, execute the following steps:

## Step 1: Read Design Principles

Read `.cursor/references/design-principle.md` to understand the core design philosophy.

## Step 2: Read Design Tokens

Read `.vibe-doc/design-token.json` to get specific values for brand colors, semantic colors, border radius, fonts, etc.

## Step 3: Determine Target Platform

Check the current conversation context or PRD for the specified platform:



| Platform Keywords | Document |
|-------------------|----------|
| Browser extension, Chrome extension, Extension | `.cursor/references/design system/browser-extension.md` |
| Web, Website, Next.js, React, Web app | `.cursor/references/design system/web.md` |
| iOS, iPhone, iPad | `.cursor/references/design system/apple-native-app.md` |
| macOS, Mac, Mac App | `.cursor/references/design system/macos-app.md` |

If platform is not specified, ask the user: "Please confirm target platform: Browser Extension / Web App / iOS·macOS App?"

## Step 4: Read Platform Document

Based on the platform determined in Step 3, read the corresponding Design System document to understand:
- Tech stack (framework, component library, icon library)
- Platform constraints (dimensions, performance, special considerations)
- How to apply Design Tokens

## Step 5: Execute Design Task

Perform UI/UX design or optimization based on the above specifications, ensuring:
- Adherence to Design Principles
- Use of values defined in Design Tokens
- Compliance with target platform's tech stack and constraints

## Output Requirements

- Code output must use the specified tech stack (shadcn/ui + Tailwind or SwiftUI)
- Colors must use variables defined in Design Tokens, no hardcoded values
- Border radius, fonts, etc. must be consistent with Design Tokens
- If component customization is needed, document it in the "Component Customization Log" section of the platform doc