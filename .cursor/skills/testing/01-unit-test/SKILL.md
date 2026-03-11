---
name: 01-unit-test
description: Defines unit test methodology, standards, and coverage rules. Applies when writing or modifying any function, method, or class. Must be used together with the platform-specific toolchain config in .cursor/skills/testing/toolchain/unit-[platform].md. Use when Tier 1 (Unit Test) is triggered per Global Rules.
---

# Unit Test

 ⚠️ When executing this skill, you MUST also load the corresponding `.cursor/skills/testing/toolchain/unit-*.md` file for the current project's platform. If that file does not exist, prompt the user: "No unit test toolchain config found. Should I run the toolchain generator first?"

---

## What Is a Unit Test

A unit test verifies the SMALLEST testable piece of code in isolation — a single function, method, or class. It answers one question: **"Does this one piece, by itself, do what it's supposed to do?"**

- ✅ Test ONE function's logic
- ✅ Test ONE method's return value
- ✅ Test ONE class's behavior
- ❌ NOT how multiple modules work together (that's integration test)
- ❌ NOT how UI looks or behaves (that's UI test)
- ❌ NOT a full user workflow (that's E2E test)

---

## Test Naming Convention

Every test name MUST clearly describe three things:

```
test_[WHAT action]_[WHEN condition]_[THEN expected result]
```

Good examples:
```
test_cropImage_withValidRect_returnsCorrectSize
test_cropImage_withZeroRect_returnsNil
test_cropImage_withRectExceedingBounds_clampsToImageBounds
test_generateFileName_withCurrentDate_returnsFormattedString
should return correct size when rect is valid
should return null when rect is zero
should clamp to image bounds when rect exceeds bounds
```

Bad examples:
```
test1
testA
testStuff
testCrop   ← missing condition and expected result
```

---

## Test Coverage Rules

For EVERY function/method, create tests covering these categories:

### 1. Happy Path (required — always write this)
The normal, expected usage. Valid inputs → expected output.

### 2. Edge Cases (required — always write this)
Boundary conditions and special values:
- Empty inputs: `""`, `[]`, `nil`, `null`, `undefined`, `0`
- Boundary values: max int, min int, maximum allowed length
- Single element: array with one item, string with one character
- Exact boundary: if limit is 100, test 99, 100, 101

### 3. Error Cases (required — always write this)
Invalid inputs and failure scenarios:
- Invalid arguments: wrong type, out of range, malformed data
- Missing dependencies: nil/null references, unavailable services
- Expected throws: verify the correct error type is thrown

### 4. State Transitions (when applicable)
If the function changes state:
- Verify state BEFORE the action
- Execute the action
- Verify state AFTER the action
- Verify the transition sequence if order matters

---

## Minimum Test Count Per Unit

| Unit complexity | Minimum tests | Breakdown |
|----------------|---------------|-----------|
| Simple (pure function, no branching) | 3 | 1 happy + 1 edge + 1 error |
| Medium (2-3 branches / conditions) | 5 | 2 happy + 2 edge + 1 error |
| Complex (4+ branches, state machine) | 8+ | Cover every branch + state transition |

This is a MINIMUM. Use judgment to add more if the function has critical business logic.

---

## The AAA Pattern

Every test MUST follow this structure:

```
Arrange  → Set up test data, create mocks, configure preconditions
Act      → Execute the ONE function/action being tested
Assert   → Verify the expected outcome
```

Rules:
- ONE act per test. If you need two "Act" steps, split into two tests.
- Arrange can be shared via setUp/beforeEach for common setup.
- Assert should verify ONE logical behavior (multiple related assertions for the same behavior are OK).

---

## Isolation Principles

Unit tests MUST be isolated. The unit under test should NOT depend on:
- Network calls
- File system operations
- Database access
- Other modules' real implementations
- System time / dates
- User defaults / storage

How to isolate: use mocks, stubs, or fakes. The specific mock patterns and syntax are defined in `.cursor/skills/testing/toolchain/unit-[platform].md`.

### Rule: If you can't isolate it, flag it
If a function is tightly coupled and hard to test in isolation, report:
```
⚠️ [functionName] is tightly coupled to [dependency].
   Recommend: Extract a protocol/interface for [dependency] to enable testability.
   Want me to refactor?
```

---

## What NOT to Unit Test

- **Trivial getters/setters** with no logic
- **Direct UI layout code** (use UI/Snapshot tests instead)
- **Third-party library functions** (trust their own tests; mock them)
- **Declarative UI view bodies** (SwiftUI views, React JSX without logic — test the underlying logic/state instead)
- **Simple type aliases or constants**

When in doubt, ask: **"Can this break in a way that a unit test would catch?"** If no, skip it.

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Test depends on another test's result | Each test is completely independent |
| Test uses real network/file system | Mock all external dependencies |
| Test name is `test1`, `testA`, `testStuff` | Name describes what/when/then |
| One test checks 5 different things | One test = one behavior = one assertion focus |
| Test only checks happy path | Always include edge + error cases |
| Duplicated setup code in every test | Use setUp / beforeEach for shared setup |
| Test mirrors implementation line by line | Test the BEHAVIOR, not the implementation |

---

## Test Execution Workflow

When Tier 1 (Unit Test) is triggered per Global Rules:

```
Step 1 → Identify the unit(s) you just created or modified
Step 2 → Check if test file exists for this unit
          - If YES → update existing tests to cover your changes
          - If NO  → create a new test file following platform conventions
                      (see .cursor/skills/testing/toolchain/unit-[platform].md)
Step 3 → Write tests covering all 4 categories (happy, edge, error, state)
Step 4 → Run ONLY the relevant test file (not the entire test suite)
Step 5 → Report results using Tier 1 format from Global Rules:
          ✅ Unit Tests: [X passed] / [Y total] | [module/file name]
          ❌ Failures: [brief description if any]
Step 6 → If any test fails → follow Test Failure Protocol from Global Rules
```