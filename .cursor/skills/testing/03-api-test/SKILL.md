---
name: 03-api-test
description: Defines API and interface test methodology. Verifies that modules expose correct public interfaces — given specific inputs, they produce expected outputs. Focuses on the contract (input/output), not internal implementation. Applies when modules define public APIs, service interfaces, or cross-module contracts. Often run alongside integration tests when features are completed. Use when user mentions "api test".
---

# API / Interface Test

API tests verify a module's PUBLIC CONTRACT — what goes in, what comes out. They don't care HOW the module works internally, only that the contract is honored. Uses the same test framework as unit tests — refer to `.cursor/skills/testing/toolchain/unit-[platform].md` for setup.

---

## What Is an API Test

An API test verifies that a module's public interface behaves according to its contract. It answers: **"If I call this interface with X, do I get Y back — regardless of how the module is implemented internally?"**

- ✅ Test public method signatures — correct return types and values
- ✅ Test that input validation works (reject bad inputs, accept good ones)
- ✅ Test that state transitions exposed via API are correct
- ✅ Test that error responses follow documented patterns
- ❌ NOT testing internal private methods (that's unit test territory)
- ❌ NOT testing how modules interact (that's integration test)
- ❌ NOT testing external REST/GraphQL endpoints you don't own

---

## When to Write API Tests

API tests are typically written alongside integration tests (Tier 2). Write them when:

1. A module exposes a **public interface** that other modules depend on
2. A **service class** defines a protocol/interface contract
3. You're building a module that will be consumed by other modules later
4. The public API has **state machines** (e.g., idle → armed → active → idle)

---

## How API Tests Differ from Other Tests

| Aspect | Unit Test | API Test | Integration Test |
|--------|-----------|----------|-----------------|
| What's tested | Internal logic | Public contract | Module interaction |
| Internal knowledge | Yes (white box) | No (black box) | Partial |
| Mocking | Mock dependencies | Mock dependencies | Real modules, mock externals |
| Breaks when | Logic changes | Contract changes | Wiring changes |
| Refactoring impact | Often needs updating | Survives refactoring | Sometimes needs updating |

**Key principle**: API tests are BLACK BOX. You test the interface as a consumer would use it. If the implementation changes but the contract stays the same, API tests should still pass.

---

## What to Test in an API Test

### 1. Method Contracts (required)

For each public method, verify:
- Correct return value for valid inputs
- Correct error/exception for invalid inputs
- Return type matches the declared signature

### 2. State Machine Contracts (when applicable)

For modules with state:
- Verify initial state after construction
- Verify each valid state transition
- Verify that invalid transitions are rejected or handled
- Verify state after sequences of operations

Example — `ClipboardAutoPasteService`:
```
Initial state: idle
arm() → state becomes armed
trigger paste → state becomes pasting → then back to idle
arm() when already armed → stays armed (idempotent)
disarm() when idle → stays idle (no error)
```

### 3. Input Validation (required)

For each public method, verify it handles:
- Valid inputs → correct result
- Null/nil/undefined inputs → appropriate error or default
- Out-of-range inputs → appropriate error or clamping
- Malformed inputs → appropriate error, no crash

### 4. Callback / Delegate Contracts (when applicable)

For modules that communicate via callbacks, delegates, or closures:
- Callback is called at the correct time
- Callback receives correct parameters
- Callback is NOT called when it shouldn't be
- Multiple callbacks fire in correct order

### 5. Idempotency and Side Effects (when applicable)

- Calling the same method twice with same input → same result
- Methods that should NOT have side effects → verify no state change
- Methods that SHOULD have side effects → verify the exact side effect

---

## Test Naming Convention

API test names should describe the contract being verified:

```
test_[interface]_[input/action]_[expectedOutput/behavior]
```

Examples:
```
test_autoPasteService_arm_stateBecomesArmed
test_autoPasteService_armWhenAlreadyArmed_staysArmed
test_autoPasteService_disarmWhenIdle_noError
test_purchaseService_loadProducts_returnsCorrectProductIDs
test_purchaseService_loadProducts_withInvalidID_returnsEmpty
test_capabilityService_checkFeature_whenPro_returnsEnabled
test_capabilityService_checkFeature_whenFree_returnsDisabled
```

For TypeScript:
```
should transition to armed state when arm is called
should stay armed when arm is called twice
should return correct product IDs when loading products
should return enabled for pro features when user is pro
```

---

## Test Structure

API tests follow the AAA pattern with emphasis on the INTERFACE:

```
Arrange  → Create the module instance
         → Mock only EXTERNAL dependencies (not internal implementation)
         → Set up any required preconditions via PUBLIC methods only

Act      → Call the PUBLIC method being tested
         → Use only the public interface — never access private state directly

Assert   → Verify the return value or observable state change
         → Use only public getters/properties to check state
         → Never peek into internal variables
```

**Critical rule**: If you need to access private/internal state to write the assertion, the API is incomplete — suggest adding a public property or method to expose that state.

```
⚠️ [ModuleName] has internal state [stateName] that cannot be verified
   via public API. Recommend: Add a public read-only property to expose it.
   Want me to add it?
```

---

## Coverage Rules

For each public interface:

| Interface complexity | Minimum tests | Breakdown |
|---------------------|---------------|-----------|
| Simple (1-2 methods, no state) | 3 | 1 valid + 1 invalid + 1 edge |
| Stateful (state machine) | 6+ | Each state transition + invalid transitions |
| Complex (many methods, callbacks) | 10+ | Each method × valid/invalid + callback timing |

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Access private/internal state in tests | Only use public API to arrange, act, and assert |
| Test implementation details | Test the contract — what, not how |
| Copy-paste unit tests and call them API tests | API tests are black-box; unit tests are white-box |
| Skip input validation testing | Always test invalid/edge inputs |
| Ignore state machine transitions | Map out all states and test every valid transition |
| Assume idempotency | Explicitly verify calling methods multiple times |

---

## Test Execution Workflow

When API tests are triggered (typically alongside Tier 2):

```
Step 1 → Identify modules with public interfaces in the completed feature
Step 2 → Map out the public API surface (methods, properties, delegates)
Step 3 → For stateful modules, draw the state machine transitions
Step 4 → Write tests covering contracts, validation, state, callbacks
Step 5 → Run the tests in the terminal
Step 6 → Report results:
          📡 API Tests: [X passed] / [Y total] | [module name]
          ❌ Failures: [brief description if any]
Step 7 → If any test fails → follow Test Failure Protocol from Global Rules
```

---

## File Organization

API test files should clearly indicate they test the public interface:

```
# Swift
ClipboardAutoPasteServiceAPITests.swift
PurchaseServiceAPITests.swift
CapabilityServiceAPITests.swift

# TypeScript
clipboard-auto-paste.api.test.ts
purchase-service.api.test.ts
capability-service.api.test.ts
```