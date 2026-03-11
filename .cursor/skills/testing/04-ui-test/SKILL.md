---
name: 04-ui-test
description: Defines UI and interaction test methodology. Verifies that user interface elements respond correctly to user actions — clicks, drags, inputs, keyboard shortcuts. Simulates real user interactions and checks UI behavior. Triggered by "#测UI", "#test-ui", or related natural language. Must be used together with platform-specific toolchain in .cursor/skills/testing/toolchain/ui-[platform].md.
---

# UI / Interaction Test

⚠️ When executing this skill, you MUST also load the corresponding `.cursor/skills/testing/toolchain/ui-*.md` file for the current project's platform. If that file does not exist, prompt the user: "No UI test toolchain config found. Should I run the toolchain generator first?"

---

## What Is a UI Test

A UI test simulates real user interactions with the interface and verifies the UI responds correctly. It answers: **"When a user clicks/drags/types, does the UI do what it should?"**

- ✅ Test button clicks trigger correct actions
- ✅ Test drag gestures produce correct visual results
- ✅ Test keyboard shortcuts activate correct features
- ✅ Test UI state transitions (enabled/disabled, visible/hidden)
- ✅ Test navigation between views/screens
- ❌ NOT testing business logic (that's unit test)
- ❌ NOT testing visual appearance/layout (that's snapshot test)
- ❌ NOT testing full user journeys across the app (that's E2E test)

---

## When to Write UI Tests

Triggered by keywords: **#测UI**, **#test-ui**, or natural language like "检查一下 UI", "UI 有没有问题"

Write UI tests for:
1. Interactive components (buttons, toggles, sliders, input fields)
2. Gesture-driven features (drag to select, draw annotations)
3. Keyboard shortcuts and hotkeys
4. Modal/dialog presentation and dismissal
5. State-driven UI changes (loading → loaded → error states)

---

## What to Test

### 1. User Actions → UI Response (required)

For each interactive element, verify:
- Tap/click → expected action fires
- Long press / right click → expected context menu appears
- Drag → expected visual feedback during and after drag
- Keyboard input → expected text appears or action fires
- Keyboard shortcut → expected feature activates

### 2. UI State Transitions (required)

For components with multiple states:
- Initial state on appearance
- Transition between states (idle → hover → active → disabled)
- State after user action completes
- Error state presentation

### 3. Navigation (when applicable)

- View A action → navigates to View B
- Back/cancel → returns to previous view
- Deep navigation → correct view hierarchy

### 4. Conditional UI (when applicable)

- Elements show/hide based on state (e.g., Pro vs Free features)
- Elements enable/disable based on context
- Dynamic content loads and displays correctly

### 5. Edge Cases (required)

- Rapid repeated taps (debounce works?)
- Interaction during loading state
- Interaction during animation
- Empty state UI (no data, first launch)
- Escape / cancel during operation

---

## Test Naming Convention

```
test_[component]_[userAction]_[expectedUIResponse]
```

Examples:
```
test_captureOverlay_dragSelection_showsSelectionRect
test_captureOverlay_pressEscape_closesOverlay
test_annotationToolbar_selectArrow_activatesArrowTool
test_copyButton_tap_showsSuccessHUD
test_paywallView_selectAnnualPlan_highlightsAnnualOption
test_onboarding_tapNext_advancesToStep2
```

For TypeScript:
```
should show selection rect when user drags on overlay
should close overlay when escape is pressed
should activate arrow tool when selected in toolbar
```

---

## Test Structure

```
Arrange  → Launch the app/component
         → Navigate to the screen being tested
         → Set up required preconditions (login state, data, permissions)

Act      → Perform the user action (tap, drag, type, press key)

Assert   → Verify UI response:
           - Element exists / is visible
           - Element has correct text / value
           - Element is in correct state (enabled, selected, highlighted)
           - Navigation occurred to correct destination
           - Animation/transition completed
```

---

## Query Strategy

When finding UI elements to interact with, prefer these query strategies in order:

1. **Accessibility identifier** (most reliable, works across platforms)
2. **Accessibility label** (good for user-facing text)
3. **Role/type** (button, textfield, slider)
4. **Text content** (least stable — breaks if text changes)

Never query by position/coordinates unless testing gesture-specific features.

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Test visual appearance (colors, fonts, layout) | Use snapshot tests for visual verification |
| Hard-code wait times (`sleep(2)`) | Use proper wait mechanisms (waitForExistence, waitFor) |
| Test business logic through UI | Test logic in unit tests; UI tests verify the interaction |
| Query elements by index or position | Query by accessibility identifier or label |
| Ignore setup/teardown state | Reset app state between tests |
| Test too many interactions in one test | One user action → one assertion per test |

---

## Test Execution Workflow

When triggered by #测UI or related keywords:

```
Step 1 → Identify UI components in scope
Step 2 → Check if UI test file exists
          - If YES → update existing tests
          - If NO  → create new test file
Step 3 → Write tests covering actions, states, navigation, edge cases
Step 4 → Run UI tests in the terminal
Step 5 → Report results:
          🖼️ UI Tests: [X passed] / [Y total] | [component name]
          ❌ Failures: [brief description if any]
Step 6 → If any test fails → follow Test Failure Protocol from Global Rules
```

---

## File Organization

```
# Swift
CaptureOverlayUITests.swift
AnnotationToolbarUITests.swift
PaywallViewUITests.swift
OnboardingFlowUITests.swift

# TypeScript
capture-overlay.ui.test.ts
annotation-toolbar.ui.test.ts
paywall-view.ui.test.ts
onboarding-flow.ui.test.ts
```