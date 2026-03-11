---
name: 09-acceptance-test
description: Defines acceptance test methodology. Systematically verifies the implementation against the product spec/PRD — every requirement is checked and reported as met or not met. This is the product owner's final sign-off checklist. Triggered by "#验收", "#acceptance", or related natural language like "对照 Spec 检查", "check PRD".
---

# Acceptance Test

---

## What Is an Acceptance Test

An acceptance test verifies that the product meets its acceptance criteria as defined in the Spec/PRD. It answers: **"Has everything the product owner asked for been built correctly?"**

- ✅ Every requirement in the Spec is verified
- ✅ Results are presented as a clear pass/fail checklist
- ✅ Product owner (you!) can make a ship/no-ship decision
- ❌ NOT testing code quality (that's unit/integration)
- ❌ NOT testing performance (that's performance test)
- ❌ NOT testing edge cases beyond what Spec defines

---

## When to Run Acceptance Tests

Triggered by: **#验收**, **#acceptance**, or natural language like "对照 Spec 检查", "验收测试", "check PRD"

Run acceptance tests when:
1. A feature or release milestone is claimed "complete"
2. Before final release decision
3. After significant changes to verify nothing regressed from Spec

---

## Step-by-Step Execution

### Step 1 — Load the Spec

Find and read the product spec document. Common locations:
```
.vibe-doc/PRODUCT_SPEC.md
.vibe-doc/IMPLEMENTATION_PRODUCT_SPEC.md
.vibe-doc/PRD.md
README.md (if it contains requirements)
```

If no spec found:
```
📋 No Spec/PRD document found. Please point me to the requirements document
   so I can run acceptance tests against it.
```

### Step 2 — Extract Acceptance Criteria

Parse the Spec into individual, testable criteria. Each criterion is one verifiable statement:

```
Feature: Screenshot Capture
  AC-001: Pressing ⌘⇧C triggers screen capture
  AC-002: Screen freezes with translucent overlay
  AC-003: User can drag to select a region
  AC-004: Selected region appears in annotation modal
  AC-005: ESC at any point cancels and returns to idle

Feature: IAP
  AC-010: Paywall displays correct products and prices
  AC-011: Annual plan is pre-selected
  AC-012: Purchase flow completes and unlocks Pro
  AC-013: Restore purchases works for existing subscribers
```

### Step 3 — Verify Each Criterion

For each criterion, verify through:
1. **Code inspection** — does the implementation exist?
2. **Existing test results** — do passing tests cover this?
3. **Manual verification description** — what would a human check?

### Step 4 — Generate Report

---

## Report Format

```
📋 Acceptance Test Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Spec: [document name]
Date: [date]
Total criteria: [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature: [Feature Name 1]
  ✅ AC-001: [criterion description]
  ✅ AC-002: [criterion description]
  ❌ AC-003: [criterion description]
     → Issue: [what's wrong or missing]
  ⚠️ AC-004: [criterion description]
     → Partial: [what works, what doesn't]

Feature: [Feature Name 2]
  ✅ AC-010: [criterion description]
  ✅ AC-011: [criterion description]
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary:
  ✅ Met:     [X] criteria
  ❌ Not met: [Y] criteria
  ⚠️ Partial: [Z] criteria

Verdict: [READY TO SHIP / NOT READY — N criteria unmet]
```

---

## Acceptance Criteria Quality

Good acceptance criteria are:
- **Specific** — "Annual plan is pre-selected" not "Paywall works"
- **Verifiable** — can be checked as true or false
- **Independent** — each criterion stands alone
- **Traceable** — can be linked back to a Spec section

If the Spec has vague requirements, flag them:
```
⚠️ Spec says "[vague requirement]" — this is not specific enough to verify.
   Suggest rewriting as: "[specific testable criterion]"
   Want me to use the suggested version?
```

---

## Feature Coverage Matrix

For complex products, generate a coverage matrix:

```
| Feature | Total AC | Met | Not Met | Partial | Coverage |
|---------|----------|-----|---------|---------|----------|
| Capture | 8 | 7 | 0 | 1 | 87.5% |
| IAP | 5 | 5 | 0 | 0 | 100% |
| Onboarding | 6 | 4 | 2 | 0 | 66.7% |
| Settings | 4 | 4 | 0 | 0 | 100% |
| TOTAL | 23 | 20 | 2 | 1 | 87.0% |
```

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Verify against memory, not the actual Spec | Always read the Spec document |
| Mark criteria as "met" without evidence | Cite code, tests, or observable behavior |
| Skip vague requirements | Flag them and suggest specific criteria |
| Only check happy paths | Spec often includes error handling requirements |
| Mix acceptance with performance testing | Acceptance = functionality per Spec only |

---

## File Organization

Acceptance test results are saved as reports, not test files:

```
.vibe-doc/ACCEPTANCE_REPORT_[date].md
.vibe-doc/ACCEPTANCE_REPORT_[feature]_[date].md
```