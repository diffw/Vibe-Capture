---
name: 05-snapshot-test
description: Defines snapshot and screenshot test methodology. Captures a rendered UI component and compares it against a stored baseline image to detect unintended visual changes. Triggered alongside UI tests by "#测UI", "#test-ui", or related natural language. Must be used together with platform-specific toolchain in .cursor/skills/testing/toolchain/snapshot-[platform].md.
---

# Snapshot / Screenshot Test

⚠️ When executing this skill, you MUST also load the corresponding `.cursor/skills/testing/toolchain/snapshot-*.md` file for the current project's platform. If that file does not exist, prompt the user: "No snapshot test toolchain config found. Should I run the toolchain generator first?"

---

## What Is a Snapshot Test

A snapshot test captures the rendered output of a UI component and compares it to a previously stored baseline. It answers: **"Does this component still LOOK the same as before?"**

- ✅ Detect unintended visual changes after code modifications
- ✅ Catch layout regressions (spacing, alignment, sizing)
- ✅ Verify multiple visual states of a component
- ❌ NOT testing user interactions (that's UI test)
- ❌ NOT testing business logic (that's unit test)
- ❌ NOT a substitute for human visual review

---

## When to Write Snapshot Tests

Triggered alongside UI tests by: **#测UI**, **#test-ui**

Write snapshot tests for:
1. UI components with multiple visual states (normal, hover, active, disabled, error)
2. Components that render differently based on data (empty, one item, many items)
3. Components with complex layouts that could regress
4. Brand-critical UI (paywall, onboarding, marketing views)

---

## Core Workflow

### First Run — Record Baselines

```
Step 1 → Render the component in a specific state
Step 2 → Capture screenshot/snapshot
Step 3 → Store as baseline (reference image or serialized output)
Step 4 → Commit baseline to git
```

### Subsequent Runs — Compare

```
Step 1 → Render the component in the same state
Step 2 → Capture new screenshot/snapshot
Step 3 → Compare against stored baseline
Step 4 → If MATCH → test passes
         If DIFF  → test fails, show diff for review
```

---

## What to Snapshot

### 1. Component States (required)

Capture each meaningful visual state:
```
LoginButton — default state
LoginButton — hover state
LoginButton — loading state
LoginButton — disabled state
LoginButton — error state
```

### 2. Data Variations (required)

Capture how the component looks with different data:
```
ProductList — empty (no items)
ProductList — single item
ProductList — many items
ProductList — long text (overflow handling)
```

### 3. Responsive / Size Variations (when applicable)

Capture at different sizes or contexts:
```
PaywallView — compact width
PaywallView — regular width
SettingsPanel — collapsed
SettingsPanel — expanded
```

### 4. Localization Variations (when applicable)

Capture in different languages to catch text overflow:
```
OnboardingStep1 — English
OnboardingStep1 — German (long words)
OnboardingStep1 — Japanese (different typography)
```

---

## Test Naming Convention

```
test_[component]_[state/variation]_snapshot
```

Examples:
```
test_captureModal_defaultState_snapshot
test_captureModal_withAnnotations_snapshot
test_paywallView_annualSelected_snapshot
test_paywallView_monthlySelected_snapshot
test_onboardingStep1_english_snapshot
test_onboardingStep1_german_snapshot
test_HUD_successStyle_snapshot
test_HUD_errorStyle_snapshot
```

For TypeScript:
```
should match snapshot for default state
should match snapshot with annotations
should match snapshot for annual plan selected
```

---

## Baseline Management Rules

1. **Commit baselines to git** — baselines are part of the codebase
2. **Review baseline changes in PRs** — visual diffs should be reviewed by a human
3. **Update baselines intentionally** — only update when the visual change is desired
4. **Never auto-update baselines** — always ask the user:
   ```
   📸 Snapshot diff detected for [component].
      The rendered output differs from the stored baseline.
      Options:
      1. View the diff
      2. Update baseline (accept new appearance)
      3. Investigate (the change may be a bug)
   ```

---

## Pixel Tolerance

Set a small tolerance to avoid flaky tests from anti-aliasing or rendering differences:
- Recommended: 0.1% - 1% pixel difference tolerance
- Platform-specific settings are in the toolchain file

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Snapshot entire screens | Snapshot individual components in isolation |
| Auto-update baselines without review | Always review diffs before updating |
| No tolerance for pixel differences | Set small tolerance (0.1-1%) |
| Snapshot dynamic content (dates, random IDs) | Mock/fix dynamic data before snapshot |
| Too few states captured | Capture every meaningful visual state |
| Snapshots without descriptive names | Name clearly indicates component + state |

---

## Test Execution Workflow

When triggered by #测UI or related keywords (alongside UI tests):

```
Step 1 → Identify UI components in scope
Step 2 → Check if snapshot test file and baselines exist
          - If NO baselines → run in RECORD mode, generate baselines
          - If baselines exist → run in COMPARE mode
Step 3 → Write/update snapshot tests for each component state
Step 4 → Run snapshot tests in the terminal
Step 5 → Report results:
          📸 Snapshots: [X matched] / [Y compared] / [Z diffs detected]
          🆕 New baselines: [list if any]
          ❌ Diffs: [component names if any]
Step 6 → For any diffs → show options (view diff / update / investigate)
```

---

## File Organization

```
# Swift
CaptureModalSnapshotTests.swift
PaywallViewSnapshotTests.swift
HUDSnapshotTests.swift
__Snapshots__/           ← baseline images stored here

# TypeScript
capture-modal.snapshot.test.ts
paywall-view.snapshot.test.ts
hud.snapshot.test.ts
__snapshots__/           ← baseline snapshots stored here
```