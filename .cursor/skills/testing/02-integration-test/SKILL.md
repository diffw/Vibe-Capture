---
name: 02-integration-test
description: Defines integration test methodology, standards, and patterns. Applies when multiple modules, services, or components interact with each other. Triggered when a feature is complete, modules are wired up, or 3+ modules are involved in a task. Use when Tier 2 (Integration Test) is triggered per Global Rules.
---

# Integration Test

⚠️ Integration tests verify that modules work TOGETHER correctly. They sit between unit tests (single module) and E2E tests (full user journey). If platform-specific toolchain details are needed, refer to `.cursor/skills/testing/toolchain/unit-[platform].md` for mock patterns and test framework setup — integration tests use the same framework as unit tests but with broader scope.

---

## What Is an Integration Test

An integration test verifies the INTERACTION between two or more modules. It answers: **"When module A talks to module B, does the conversation go correctly?"**

- ✅ Test that Module A calls Module B with correct parameters
- ✅ Test that Module B's response is correctly handled by Module A
- ✅ Test the data flow through a chain of modules (A → B → C)
- ✅ Test that shared state is correctly updated across modules
- ❌ NOT testing a single function in isolation (that's unit test)
- ❌ NOT testing UI rendering (that's UI test)
- ❌ NOT testing full user journey from start to finish (that's E2E test)

---

## When to Write Integration Tests

Per Global Rules Tier 2, integration tests are triggered when:

1. **Feature completion**: You say "done", "complete", "finished" for a feature
2. **Module wiring**: You ask to "wire up", "connect", or "integrate" modules
3. **Complex interaction detected**: The current task involves 3+ modules interacting

If the trigger condition is ambiguous, ASK before running:
```
🔗 This task involves [Module A], [Module B], and [Module C] interacting.
   Want me to write and run integration tests for this interaction chain?
```

---

## How Integration Tests Differ from Unit Tests

| Aspect | Unit Test | Integration Test |
|--------|-----------|-----------------|
| Scope | ONE function/class | 2+ modules interacting |
| Dependencies | ALL mocked | Real modules, only EXTERNAL deps mocked |
| Speed | Milliseconds | Seconds |
| What breaks | Logic inside a module | Contracts between modules |
| Example | `formatDate()` returns correct string | `CaptureManager` passes correct data to `ClipboardService` |

**Key principle**: In integration tests, use REAL implementations of the modules being tested. Only mock things that are truly external (network, file system, database, OS APIs).

---

## Integration Test Patterns

### Pattern 1 — Chain Test

Test a sequence of modules that pass data through a pipeline.

```
Module A produces output → Module B transforms it → Module C consumes it
```

Verify:
- Module A's output format matches Module B's expected input
- Module B's output format matches Module C's expected input
- The final result at Module C is correct given the initial input at Module A

**Example**: `ScreenCaptureService` captures image → `AnnotationCanvasView` adds markup → `ClipboardService` copies final image

### Pattern 2 — Event/Notification Test

Test that when Module A fires an event, Module B correctly responds.

Verify:
- The event is sent with correct data
- Module B receives the event
- Module B's state changes correctly in response

**Example**: `PurchaseService` completes purchase → `EntitlementsService` updates Pro status → `CapabilityService` unlocks features

### Pattern 3 — Shared State Test

Test that multiple modules reading/writing shared state stay in sync.

Verify:
- Module A writes state correctly
- Module B reads the updated state
- No race conditions or stale state

**Example**: `SettingsStore` saves hotkey config → `ShortcutManager` reads and registers the new hotkey

### Pattern 4 — Error Propagation Test

Test that when Module B fails, Module A handles the error correctly.

Verify:
- Module B's error is propagated to Module A
- Module A doesn't crash or enter an inconsistent state
- User-facing error handling (if any) is correct

**Example**: `StoreKit` returns purchase failure → `PurchaseService` handles error → `PaywallView` shows correct error message

---

## What to Mock vs What to Keep Real

### Keep REAL (the whole point is testing their interaction):
- The modules being tested
- Their internal logic and state
- Communication between them (delegates, callbacks, notifications, closures)

### Mock these (external to the interaction chain):
- Network calls (API requests, server responses)
- File system operations (reading/writing files)
- Database access
- OS-level APIs (ScreenCaptureKit, CGEventTap, etc.)
- Third-party services (StoreKit, Supabase, Firebase)
- System clock / dates (inject fixed dates)

### Rule of thumb:
> If it's a module YOU wrote and it's part of the interaction being tested → use the REAL implementation.
> If it's external or would make the test slow/flaky → mock it.

---

## Test Naming Convention

Integration test names should describe the INTERACTION, not a single unit:

```
test_[moduleA]_[action]_[moduleB]_[expectedResult]
```

Examples:
```
test_captureManager_onCapture_clipboardService_receivesImage
test_purchaseService_onSuccess_entitlementsService_unlocksPro
test_settingsStore_onHotkeyChange_shortcutManager_registersNewKey
test_purchaseService_onFailure_paywallView_showsErrorState
```

For TypeScript:
```
should pass captured image to clipboard service when capture completes
should unlock pro in entitlements when purchase succeeds
should register new hotkey when settings change
```

---

## Test Structure

Integration tests follow an extended AAA pattern:

```
Arrange  → Set up ALL modules in the interaction chain
         → Mock only external dependencies
         → Configure initial state

Act      → Trigger the interaction from the entry point
         → Let the real modules communicate with each other

Assert   → Verify the END STATE of the interaction chain
         → Check intermediate states if the sequence matters
         → Verify no unexpected side effects
```

---

## Coverage Rules for Integration Tests

For each module interaction chain, test:

### 1. Happy Path (required)
The normal flow — all modules cooperate successfully.

### 2. Error Propagation (required)
What happens when a module in the chain fails:
- Does the error propagate correctly?
- Do upstream modules handle it gracefully?
- Is shared state left in a consistent state?

### 3. Boundary Handoff (required)
Data format at module boundaries:
- Does Module A's output match Module B's expected input?
- What happens with edge-case data (empty, nil, maximum size)?

### 4. Timing / Order (when applicable)
If the interaction involves async operations or sequenced events:
- Do modules execute in the correct order?
- Are race conditions handled?
- Do callbacks/completions fire at the right time?

---

## Minimum Test Count Per Integration

| Interaction complexity | Minimum tests | Breakdown |
|-----------------------|---------------|-----------|
| Simple (A → B) | 3 | 1 happy + 1 error + 1 boundary |
| Medium (A → B → C) | 5 | 2 happy + 1 error + 1 boundary + 1 timing |
| Complex (4+ modules, async, state) | 8+ | Cover every path + error + timing |

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Mock everything including modules under test | Only mock EXTERNAL dependencies |
| Test individual functions (that's a unit test) | Test the interaction between modules |
| Duplicate unit test scenarios | Focus on what ONLY integration can catch: contracts between modules |
| One giant test covering the entire app | Test one interaction chain per test |
| Ignore error propagation | Always test what happens when a module in the chain fails |
| No cleanup between tests | Reset shared state in setUp/tearDown to ensure independence |

---

## Test Execution Workflow

When Tier 2 (Integration Test) is triggered per Global Rules:

```
Step 1 → Identify the modules involved in the completed feature
Step 2 → Map the interaction chains (A → B → C)
Step 3 → Check if integration test file exists
          - If YES → update existing tests
          - If NO  → create a new test file
Step 4 → Write tests covering happy path, error propagation, and boundary handoff
Step 5 → Run the integration tests in the terminal
Step 6 → Report results using Tier 2 format from Global Rules:
          🔗 Integration Tests: [X passed] / [Y total] | [modules tested]
          ❌ Failures: [brief description if any]
Step 7 → If any test fails → follow Test Failure Protocol from Global Rules
```

---

## File Organization

Integration test files should be clearly separated from unit tests:

- Name files to indicate which modules are being integrated
- Group by feature or interaction chain, not by individual module

Examples:
```
# Swift
CaptureToClipboardIntegrationTests.swift
PurchaseFlowIntegrationTests.swift
SettingsToShortcutIntegrationTests.swift

# TypeScript
capture-clipboard.integration.test.ts
purchase-flow.integration.test.ts
settings-shortcut.integration.test.ts
```