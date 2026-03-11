---
name: 11-accessibility-test
description: Defines accessibility test methodology. Verifies that the product is usable by people with disabilities — screen readers, keyboard-only navigation, high contrast, and more. Important for inclusive design and App Store review compliance. Triggered by "#测无障碍", "#test-a11y", or related natural language like "VoiceOver 能用吗", "accessibility 检查". Must be used together with platform-specific toolchain in .cursor/skills/testing/toolchain/accessibility-[platform].md.
---

# Accessibility Test

⚠️ When executing this skill, you MUST also load the corresponding `.cursor/skills/testing/toolchain/accessibility-*.md` file for the current project's platform. If that file does not exist, prompt the user: "No accessibility test toolchain config found. Should I run the toolchain generator first?"

---

## What Is an Accessibility Test

An accessibility test verifies that the product can be used by people with disabilities. It answers: **"Can someone who can't see/hear/use a mouse still use this product?"**

- ✅ Screen reader (VoiceOver) can navigate and read all content
- ✅ All functionality is reachable via keyboard alone
- ✅ Sufficient color contrast for low vision users
- ✅ Interactive elements have proper labels and roles
- ❌ NOT testing visual design aesthetics (that's snapshot/UI)
- ❌ NOT testing business logic (that's unit/functional)

---

## When to Run Accessibility Tests

Triggered by: **#测无障碍**, **#test-a11y**, or natural language like "无障碍测试", "VoiceOver 能用吗", "accessibility 检查"

Run accessibility tests when:
1. New UI components are created
2. Before App Store submission (Apple reviews accessibility)
3. After UI redesign or major layout changes
4. When adding support for new interaction patterns

---

## What to Test

### 1. Screen Reader Support (required)

For every interactive element:
- Has an accessibility label (human-readable name)
- Has correct accessibility role (button, link, textfield, etc.)
- Has accessibility value when applicable (toggle on/off, slider value)
- Reading order is logical (top-to-bottom, left-to-right)
- Group related elements (e.g., a card's title + description)

### 2. Keyboard Navigation (required)

- ALL interactive elements are reachable via Tab key
- Tab order follows logical visual order
- Focus indicator is visible on the focused element
- Enter/Space activates buttons and controls
- Escape dismisses modals and popovers
- Arrow keys navigate within lists, menus, tabs
- No keyboard traps (user can always Tab away)

### 3. Color Contrast (required)

- Text contrast ratio ≥ 4.5:1 (normal text) per WCAG 2.1 AA
- Text contrast ratio ≥ 3:1 (large text, 18pt+) per WCAG 2.1 AA
- UI component contrast ≥ 3:1 (borders, icons, focus indicators)
- Information is NOT conveyed by color alone (use icons, text, patterns too)

### 4. Dynamic Type / Text Scaling (when applicable)

- UI adapts to larger text sizes without clipping or overlap
- No fixed-height containers that truncate scaled text
- Minimum touch/click target size: 44x44 points (Apple HIG)

### 5. Motion and Animation (when applicable)

- Respect "Reduce Motion" system preference
- No auto-playing animations that can't be paused
- No flashing content (seizure risk)

---

## Test Naming Convention

```
test_a11y_[component]_[accessibilityAspect]
```

Examples:
```
test_a11y_captureModal_voiceOverLabels
test_a11y_captureModal_keyboardNavigation
test_a11y_annotationToolbar_buttonRoles
test_a11y_paywallView_contrastRatios
test_a11y_onboarding_tabOrder
test_a11y_settingsPanel_escDismisses
test_a11y_HUD_voiceOverAnnouncement
```

For TypeScript:
```
should have proper aria labels on all buttons
should be navigable by keyboard tab
should meet WCAG AA contrast requirements
should announce HUD messages to screen readers
```

---

## Accessibility Audit Checklist

For each UI component or screen, run through:

```
□ Every interactive element has an accessibility label
□ Every interactive element has the correct role
□ Tab order follows logical visual order
□ Focus is visible on every focusable element
□ No keyboard traps
□ Escape closes modals/popovers
□ Color contrast meets WCAG 2.1 AA
□ No information conveyed by color alone
□ Screen reader can read all meaningful content
□ Reading order is logical
□ Dynamic content changes are announced
□ Minimum touch target size is 44x44pt
```

---

## Report Format

```
♿ Accessibility Audit: [component/screen name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Screen Reader:
  ✅ All elements labeled
  ❌ [element] missing accessibility label
  ⚠️ [element] has generic label "button" — needs descriptive label

Keyboard:
  ✅ All elements reachable via Tab
  ❌ [element] is a keyboard trap
  ✅ Escape dismisses modal

Contrast:
  ✅ Body text: 7.2:1 (passes AA)
  ❌ Secondary text: 2.8:1 (fails AA, needs ≥ 4.5:1)
  ⚠️ Icon buttons: 3.1:1 (passes for large elements only)

Summary:
  ✅ Passed: [X] checks
  ❌ Failed: [Y] checks — MUST fix before release
  ⚠️ Warning: [Z] checks — should fix
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Add labels as afterthought | Design with accessibility from the start |
| Use generic labels ("button", "image") | Use descriptive labels ("Copy screenshot", "Annotation preview") |
| Only test with mouse/trackpad | Test complete keyboard-only workflow |
| Assume default contrast is fine | Measure actual contrast ratios |
| Ignore system preferences (Reduce Motion, etc.) | Respect all system accessibility preferences |
| Test only main screen | Test every screen and modal |

---

## Test Execution Workflow

When triggered by #测无障碍 or related keywords:

```
Step 1 → Identify UI components/screens in scope
Step 2 → Run automated accessibility audit (axe-core / Accessibility Inspector)
Step 3 → Run manual checks (keyboard navigation, screen reader flow)
Step 4 → Measure contrast ratios for text and UI elements
Step 5 → Report results using the audit format above
Step 6 → If any MUST-FIX issues found → follow Test Failure Protocol
```

---

## File Organization

```
# Swift
AccessibilityTests.swift
CaptureModalAccessibilityTests.swift
PaywallAccessibilityTests.swift

# TypeScript
accessibility.test.ts
capture-modal.a11y.test.ts
paywall.a11y.test.ts
```