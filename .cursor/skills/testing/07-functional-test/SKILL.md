---
name: 07-functional-test
description: Defines functional test methodology. Verifies that a complete feature works according to requirements — from the user's perspective, without caring about technical implementation. Triggered alongside E2E tests by "#测流程", "#test-e2e", or independently when verifying a specific feature against requirements.
---

# Functional Test

---

## What Is a Functional Test

A functional test verifies that a complete feature works as described in the requirements. It answers: **"Does this feature do what the PRD/Spec says it should do?"**

- ✅ Test a complete feature against its requirements
- ✅ Test from the user's perspective (what they see and experience)
- ✅ Verify all specified behaviors including edge cases in the spec
- ❌ NOT testing code internals (that's unit test)
- ❌ NOT testing cross-feature journeys (that's E2E)
- ❌ NOT testing visual appearance (that's snapshot)

---

## How Functional Tests Differ from Other Tests

| Aspect | Functional Test | E2E Test | UI Test |
|--------|----------------|----------|---------|
| Scope | ONE complete feature | Full cross-feature journey | ONE UI component |
| Reference | Requirements/Spec | User journey map | UI behavior |
| Example | "Screenshot capture works as specified" | "Capture → annotate → copy → paste to ChatGPT" | "Drag on overlay shows selection rect" |

---

## When to Write Functional Tests

Triggered by: **#测流程**, **#test-e2e**, or when verifying a specific feature.

Write functional tests when:
1. A feature is fully implemented and ready to verify against Spec
2. Requirements specify specific behaviors that need verification
3. A feature has multiple modes or configurations to test

---

## Test Design: Spec-Driven

Functional tests are derived directly from the product spec. For each feature:

```
Step 1 → Read the feature requirements from Spec/PRD
Step 2 → Extract each testable behavior
Step 3 → Write one test per behavior
```

Example — Screenshot Capture feature from Spec:
```
Requirement: "User presses ⌘⇧C → screen freezes → selection overlay appears"
→ test_capture_triggerHotkey_screenFreezesAndOverlayAppears

Requirement: "User drags to select area → selected region is highlighted"
→ test_capture_dragSelection_regionIsHighlighted

Requirement: "User presses ESC → capture is cancelled, back to idle"
→ test_capture_pressEscape_cancelledBackToIdle

Requirement: "Selected area is captured and shown in modal for annotation"
→ test_capture_completeSelection_modalShowsWithCapturedImage
```

---

## Coverage Rules

For each feature, test:

### 1. All Specified Behaviors (required)
Every behavior mentioned in the Spec gets a test.

### 2. Feature Modes/Configurations (required)
If the feature behaves differently based on settings or state:
- Free vs Pro mode
- Different user preferences
- First-time vs returning user

### 3. Feature Boundaries (required)
- What happens at the limits of the feature
- Minimum and maximum inputs
- Feature interaction with permissions (granted vs denied)

### 4. Negative Cases from Spec (required)
Requirements often specify what should NOT happen:
- "Must not capture if permissions not granted"
- "Must not allow purchase if already Pro"

---

## Test Naming Convention

```
test_[featureName]_[specBehavior]_[expectedOutcome]
```

Examples:
```
test_screenshotCapture_triggerHotkey_freezesScreen
test_screenshotCapture_noPermission_showsPermissionPrompt
test_iapPurchase_alreadyPro_purchaseButtonDisabled
test_onboarding_completeAllSteps_settingsSavedCorrectly
test_autoPaste_armAndPaste_textAndImagePastedTogether
```

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Write tests without reading the Spec | Always derive tests from requirements |
| Test technical implementation | Test user-visible behavior |
| Duplicate E2E journey tests | Functional = single feature; E2E = cross-feature journey |
| Skip negative cases | Test what should NOT happen too |
| Ignore feature modes (Free/Pro) | Test each mode separately |

---

## Test Execution Workflow

When triggered:

```
Step 1 → Identify the feature being tested
Step 2 → Load the relevant Spec/PRD section
Step 3 → Extract all testable behaviors from the Spec
Step 4 → Write tests for each behavior
Step 5 → Run functional tests in the terminal
Step 6 → Report results:
          🔧 Functional Tests: [X passed] / [Y total] | [feature name]
          Spec coverage: [X of Y requirements verified]
          ❌ Failures: [brief description if any]
Step 7 → If any test fails → follow Test Failure Protocol from Global Rules
```

---

## File Organization

```
# Swift
ScreenshotCaptureFunctionalTests.swift
IAPPurchaseFunctionalTests.swift
OnboardingFunctionalTests.swift

# TypeScript
screenshot-capture.functional.test.ts
iap-purchase.functional.test.ts
onboarding.functional.test.ts
```