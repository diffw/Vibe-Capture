---
name: product-spec
description: Generate platform-specific Product Spec from PRD, IA/User Flow, and Architecture Design documents. Outputs implementation-ready specs for Web, iOS, macOS, or Browser Extension. Use when user mentions "#product spec", "#生成 Product Spec", or "continue product spec".
---

## Overview

This skill generates a complete, AI-implementation-ready Product Spec based on:
- Completed PRD
- Completed IA & User Flow document
- Completed Architecture Design document
- Design Principle (reference)
- Design Token (reference)

The generated Spec enables AI to implement the product without the user reviewing any code.

---

## Input Files

All inputs are read from `.vibe-doc/`:

| File | Required | Description |
|------|----------|-------------|
| `.vibe-doc/PRD.md` | ✅ | Completed PRD |
| `.vibe-doc/library-ia-flow.md` | ✅ | Completed IA & User Flow |
| `.vibe-doc/architecture.md` | ✅ | Completed Architecture Design |
| `.vibe-doc/design-token.json` | Optional | Design tokens |
| `.cursor/references/design-principle.md` | Optional | Design philosophy |
| Figma Link (in PRD) | Optional | Design mockups URL |

---

## Template Files

Templates are stored in `.cursor/skills/06-product-spec/`:

| Platform | Template Path |
|----------|---------------|
| Web | `.cursor/skills/06-product-spec/product-spec-web-template.md` |
| iOS | `.cursor/skills/06-product-spec/product-spec-ios-app-template.md` |
| macOS | `.cursor/skills/06-product-spec/product-spec-macos-app-template.md` |
| Browser Extension | `.cursor/skills/06-product-spec/product-spec-browser-extension.md` |

---

## Output Files

Based on platform(s) specified in PRD Section 1.4:

| Platform in PRD | Output File |
|-----------------|-------------|
| Web | `.vibe-doc/product-spec-web.md` |
| iOS | `.vibe-doc/product-spec-ios.md` |
| macOS | `.vibe-doc/product-spec-macos.md` |
| Browser Extension | `.vibe-doc/product-spec-extension.md` |

---

## Workflow

### First Run (Initialization)

```
1. READ platform(s) from `.vibe-doc/PRD.md` Section 1.4
                               │
                               ▼
2. COPY template from `.cursor/skills/06-product-spec/product-spec-[platform]-template.md`
   CREATE `.vibe-doc/product-spec-[platform].md`
                               │
                               ▼
3. READ all input documents:
   - `.vibe-doc/PRD.md`
   - `.vibe-doc/library-ia-flow.md`
   - `.vibe-doc/architecture.md`
   - `.vibe-doc/design-token.json` (if exists)
   - `.cursor/references/design-principle.md` (if exists)
                               │
                               ▼
4. POPULATE spec sections from inputs
                               │
                               ▼
5. IDENTIFY gaps requiring user input
                               │
                               ▼
6. ASK clarification questions (batch short questions)
                               │
                               ▼
7. CONTINUE populating until complete or context limit
                               │
                               ▼
8. SAVE and report progress
```

### Resume (User says "continue" or "继续")

```
1. READ `.vibe-doc/product-spec-[platform].md`
2. IDENTIFY last completed section
3. CONTINUE from next incomplete section
4. REPEAT steps 5-8 from First Run
```

### Update (User says "modify" or "修改")

```
1. ASK: "Which section do you want to modify?"
2. WAIT for user response
3. NAVIGATE to specified section
4. ASK for changes or re-generate from updated inputs
5. UPDATE section
6. SAVE and confirm
```

---

## Complexity Assessment

Automatically assess project complexity:

| Factor | Simple | Medium | Complex |
|--------|--------|--------|---------|
| User system | No auth | Email auth | OAuth + roles |
| Data model | 1-2 entities | 3-5 entities | 6+ entities |
| API endpoints | < 10 | 10-25 | 25+ |
| Real-time features | None | Basic sync | Collaboration |
| Offline support | None | Cache only | Full offline |
| Multi-platform | Single | 2 platforms | 3+ platforms |

Complexity affects:
- Level of detail in Spec
- Number of edge cases documented
- Depth of error handling

---

## Product Spec Structure (per platform)

### Web App Spec

```
1. Tech Stack (from Architecture)
2. Data Model (from Architecture)
3. API Specification (from Architecture)
4. Feature Modules (from IA/User Flow)
   - For each feature:
     - Design mockup reference
     - UI components
     - Interaction rules
     - Validation rules
     - Error handling
     - Desktop vs Mobile differences
5. Page States
6. Responsive Design
7. Copywriting Guidelines
8. Edge Cases & Error Handling
9. Security Requirements
10. Performance Requirements
11. Test Checklist
```

### iOS App Spec

```
1. Tech Stack (SwiftUI-specific)
2. Data Model (SwiftData)
3. API Integration
4. Feature Modules (from IA/User Flow)
   - For each feature:
     - Design mockup reference
     - SwiftUI components
     - Gestures & interactions
     - Validation rules
     - Error handling
     - iPhone vs iPad differences
5. View States
6. iOS-specific Features (Sign in with Apple, Widget, Push)
7. System Permissions
8. iPad Adaptation
9. App Store Requirements
```

### macOS App Spec

```
1. Tech Stack (SwiftUI + AppKit)
2. Data Model (SwiftData)
3. API Integration
4. Window Architecture (Main window + Menu bar)
5. Feature Modules (from IA/User Flow)
   - For each feature:
     - Design mockup reference
     - UI components
     - Keyboard shortcuts
     - Menu bar interactions
6. View States
7. System Menu Structure
8. Global Hotkeys
9. Preferences Window
10. Window Behavior
11. System Permissions
12. Distribution
```

### Browser Extension Spec

```
1. Tech Stack (Manifest V3)
2. Extension Architecture (Popup, Side Panel, Content Script, Service Worker)
3. Storage Schema
4. Message Passing
5. Feature Modules (from IA/User Flow)
   - Popup features
   - Side Panel features
   - Content Script features
   - Background tasks
6. Cross-browser Compatibility
7. Permissions
8. Store Requirements
```

---

## Clarification Questions

### Format for Short Questions (multiple choice / yes-no)

Batch multiple questions:

```
I need a few clarifications:

1. **Empty State**: Show illustration + button, or button only?
   → A) Illustration + button  B) Button only

2. **Form Errors**: Inline under each field, or summary at top?
   → A) Inline  B) Summary at top  C) Both

3. **Delete Confirmation**: Simple confirm, or require typing name?
   → A) Simple confirm button  B) Type name to confirm

Reply format: 1-A, 2-C, 3-A (or describe your preference)
```

### Format for Complex Questions

Ask one at a time:

```
**Offline Behavior**

When the user loses network connection while editing:

A) Save locally and sync when back online (may cause conflicts)
B) Show warning and disable editing until online
C) Auto-save periodically, show "last saved" timestamp

Which approach fits your product better?
```

### Common Question Topics

| Category | Example Questions |
|----------|-------------------|
| Empty states | Illustration style, action button text |
| Loading | Skeleton vs spinner, full-page vs inline |
| Errors | Display location, retry behavior |
| Confirmations | Destructive action confirmation level |
| Defaults | Pre-selected values, remember user choices |
| Edge cases | Concurrent editing, data limits |

---

## Progress Tracking

After each session, report progress:

```
---

## Progress Report

**Document**: `.vibe-doc/product-spec-[platform].md`

**Completed**:
- [x] 1. Tech Stack
- [x] 2. Data Model
- [x] 3. API Specification
- [x] 4.1 Feature: User Registration
- [x] 4.2 Feature: User Login

**Current Position**: Section 4.3 - Project Management

**Remaining**:
- [ ] 4.3 Feature: Project Management
- [ ] 4.4 Feature: Task Management
- [ ] 5. Page States
- [ ] ...

**Next Action**: Say "continue" to resume from Section 4.3

**Pending Questions**: None
```

---

## Quality Checklist

Generated Spec must satisfy:

- [ ] All features from IA/User Flow are covered
- [ ] All API endpoints from Architecture are referenced
- [ ] All user flows have complete interaction rules
- [ ] All forms have validation rules and error messages
- [ ] All edge cases have handling defined
- [ ] All empty states have content
- [ ] All loading states are specified
- [ ] Platform-specific patterns are applied
- [ ] Design principles are reflected
- [ ] Design tokens are referenced
- [ ] No code review required by user
- [ ] AI can implement without additional questions

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-30 | Initial version |
