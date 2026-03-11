---
name: 06-e2e-test
description: Defines end-to-end test methodology. Verifies complete user journeys from start to finish — simulating a real user going through the entire flow. The most expensive and slowest tests but closest to real user experience. Triggered by "#测流程", "#test-e2e", or related natural language. Must be used together with platform-specific toolchain in .cursor/skills/testing/toolchain/e2e-[platform].md.
---

# End-to-End Test (E2E)

⚠️ When executing this skill, you MUST also load the corresponding `.cursor/skills/testing/toolchain/e2e-*.md` file for the current project's platform. If that file does not exist, prompt the user: "No E2E test toolchain config found. Should I run the toolchain generator first?"

---

## What Is an E2E Test

An E2E test simulates a real user completing an entire journey through the application. It answers: **"Can a real user accomplish this task from start to finish?"**

- ✅ Test complete user journeys (e.g., open app → capture screenshot → annotate → copy → paste)
- ✅ Test critical business flows (e.g., onboarding → paywall → purchase → Pro features unlocked)
- ✅ Verify that all layers (UI, logic, services, storage) work together
- ❌ NOT testing individual modules (that's unit/integration)
- ❌ NOT testing UI appearance (that's snapshot)
- ❌ NOT a replacement for other test types — E2E is the last safety net

---

## When to Write E2E Tests

Triggered by keywords: **#测流程**, **#test-e2e**, or natural language like "跑一下端到端测试", "从头到尾走一遍"

Write E2E tests for:
1. **Critical user journeys** — flows that, if broken, make the product unusable
2. **Revenue-impacting flows** — purchase, subscription, trial activation
3. **First-time user experience** — onboarding, permissions, initial setup
4. **Core value proposition** — the primary thing users come to do

---

## Identifying Critical Journeys

Before writing E2E tests, ask:

```
📋 What are this product's critical user journeys?
   Please confirm the top 3-5 journeys I should test end-to-end.
```

If the user has a PRODUCT_SPEC.md or PRD, extract the critical journeys from there.

Typical examples for a macOS app:
1. First launch → Onboarding → Permissions → Ready to use
2. Trigger capture → Select area → Annotate → Copy → Paste elsewhere
3. Open paywall → Select plan → Purchase → Pro features unlocked

Typical examples for a Chrome extension:
1. Install → Open new tab → See customized content
2. Configure settings → Settings persist across sessions
3. Interact with feature → Data syncs to backend

---

## Test Structure

E2E tests follow a JOURNEY structure, not AAA:

```
Setup    → Launch app in a clean state (fresh install or known state)
Journey  → Step-by-step user actions in sequence:
           Step 1: [action] → verify [expected result]
           Step 2: [action] → verify [expected result]
           Step 3: [action] → verify [expected result]
           ...
Teardown → Clean up (reset state, remove test data)
```

Each step should:
- Perform ONE user action
- Verify the expected result before moving to the next step
- Use realistic waits (for animations, network, etc.)

---

## Test Naming Convention

```
test_journey_[journeyName]_[happyOrEdge]
```

Examples:
```
test_journey_firstLaunchOnboarding_happyPath
test_journey_captureAnnotateCopy_happyPath
test_journey_purchaseProSubscription_happyPath
test_journey_purchaseProSubscription_cancelMidway
test_journey_captureAnnotateCopy_escapeAtEachStep
```

For TypeScript:
```
should complete first launch onboarding journey
should capture annotate and copy successfully
should handle purchase cancellation gracefully
```

---

## Coverage Rules

For each critical journey:

| Coverage type | Required? | Description |
|--------------|-----------|-------------|
| Happy path | ✅ Yes | Complete journey, everything works |
| Cancel/abort at each step | ✅ Yes | User cancels at step 1, step 2, step 3... |
| Error recovery | ✅ Yes | Something fails mid-journey, does the app recover? |
| Repeat journey | 🟡 If applicable | Run the same journey twice — no stale state? |

---

## Timeout and Stability Rules

E2E tests are inherently slower and more fragile. Follow these rules:

1. **Generous timeouts** — allow 2-3x the expected duration for each step
2. **Retry on flaky failure** — allow 1 automatic retry before marking as failed
3. **Wait for conditions, not time** — use `waitForExistence` / `waitFor` instead of `sleep`
4. **Isolate state** — each test starts from a clean/known state
5. **No dependency between tests** — each journey test is independent

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Too many E2E tests (50+) | Keep to 5-10 critical journeys max |
| Test implementation details through E2E | E2E tests user-visible behavior only |
| Hard-coded sleeps | Use condition-based waits |
| Tests depend on each other's state | Each test starts fresh |
| No cleanup/teardown | Always reset state after test |
| Test non-critical flows with E2E | Use unit/integration for non-critical paths |

---

## Test Execution Workflow

When triggered by #测流程 or related keywords:

```
Step 1 → Identify critical user journeys for this feature/product
Step 2 → Ask user to confirm the journeys to test (if not obvious)
Step 3 → Write journey tests with step-by-step verification
Step 4 → Run E2E tests in the terminal (expect longer execution time)
Step 5 → Report results:
          🔄 E2E Tests: [X passed] / [Y total]
          Journeys tested:
            ✅ [journey 1 name]
            ✅ [journey 2 name]
            ❌ [journey 3 name] — failed at step [N]: [description]
          Duration: [total time]
Step 6 → If any test fails → follow Test Failure Protocol from Global Rules
```

---

## File Organization

```
# Swift
OnboardingJourneyE2ETests.swift
CaptureFlowE2ETests.swift
PurchaseJourneyE2ETests.swift

# TypeScript
onboarding-journey.e2e.test.ts
capture-flow.e2e.test.ts
purchase-journey.e2e.test.ts
```