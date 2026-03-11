---
name: 08-smoke-test
description: Defines smoke test methodology. A quick, surface-level check of the most critical features to confirm the app is basically functional — "does it turn on without catching fire?" Triggered by "#准备发布", "#pre-release", or related natural language like "准备提审", "最后检查一下". Also runs regression (re-runs all existing tests).
---

# Smoke Test

---

## What Is a Smoke Test

A smoke test is a QUICK, SHALLOW check of the most critical paths. It answers: **"Does the app basically work? Can a user do the most important things?"**

- ✅ App launches without crashing
- ✅ Core feature is accessible and functional
- ✅ Critical business flows are not broken
- ❌ NOT deep testing of edge cases (that's functional/unit test)
- ❌ NOT visual verification (that's snapshot test)
- ❌ NOT complete journey testing (that's E2E)

Think of it as: **"Power it on, see if it smokes."**

---

## When to Run Smoke Tests

Triggered by: **#准备发布**, **#pre-release**, or natural language like "准备提审", "准备上架", "submit to App Store", "ready to publish", "最后检查一下"

Also runs **regression** — re-runs ALL existing tests in the project.

---

## Smoke Test Checklist Design

For each project, define a checklist of 5-10 critical checks. Derive from the product's core value:

### Template:
```
□ App launches successfully
□ [Core feature 1] is accessible
□ [Core feature 2] works at basic level
□ [Revenue feature] is functional
□ [Critical permission] is properly handled
□ [Navigation] main paths are reachable
□ No crash on basic usage
```

### Example — macOS Screenshot App:
```
□ App launches, menu bar icon appears
□ Hotkey ⌘⇧C triggers capture overlay
□ Can select a region and see it in modal
□ Can copy screenshot to clipboard
□ Paywall opens and displays products
□ Purchase flow initiates (sandbox)
□ Settings panel opens and saves
□ No crash during basic capture flow
```

### Example — Chrome Extension:
```
□ Extension installs and activates
□ New tab page loads with custom content
□ Core feature renders correctly
□ Settings persist after browser restart
□ No console errors on main page
□ Backend sync works (if applicable)
```

---

## Smoke Test + Regression Combo

When #准备发布 triggers, run TWO things:

### 1. Smoke Test (quick surface check)
Run the smoke checklist — each item is a fast pass/fail.

### 2. Regression Test (re-run ALL existing tests)
Run every test in the project: unit, integration, API, UI, snapshot, functional.
Purpose: ensure nothing previously working is now broken.

---

## Test Naming Convention

```
test_smoke_[criticalCheck]
```

Examples:
```
test_smoke_appLaunches
test_smoke_menuBarIconAppears
test_smoke_captureHotkeyWorks
test_smoke_canCopyToClipboard
test_smoke_paywallDisplaysProducts
test_smoke_settingsPanelOpens
```

---

## Execution Rules

1. **Speed is priority** — each smoke check should complete in seconds, not minutes
2. **No deep assertions** — just verify "it works at a basic level"
3. **Fail fast** — if a smoke check fails, it's a BLOCKER for release
4. **Run ALL existing tests** as regression after smoke checks

---

## Test Execution Workflow

When triggered by #准备发布 or related keywords:

```
Step 1 → Run smoke checklist (quick surface checks)
Step 2 → Run ALL existing tests (regression)
Step 3 → Report combined results:

          💨 Smoke Tests: [X passed] / [Y total]
          Critical checks:
            ✅ App launches
            ✅ Core capture works
            ✅ Paywall loads
            ❌ Settings not saving  ← BLOCKER

          📊 Regression: [X passed] / [Y total]
            ✅ Unit Tests: [n/n]
            ✅ Integration Tests: [n/n]
            ✅ API Tests: [n/n]
            ❌ UI Tests: [n/n] — [brief description]

          🚫 RELEASE BLOCKED: [list blockers]
          or
          ✅ READY FOR RELEASE: all checks passed

Step 4 → If any blocker found → follow Test Failure Protocol
```

---

## File Organization

```
# Swift
SmokeTests.swift              ← one file for all smoke checks

# TypeScript
smoke.test.ts                 ← one file for all smoke checks
```