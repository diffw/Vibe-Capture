---
name: requirement-clarification
description: Requirement clarification skill. Use structured questions to help users clarify vague or complex requirements. Applicable when: user has new feedback/requirements but worries AI may not fully understand, requirement description is unclear, or multiple interaction details need confirmation. Use when user mentions "#需求对齐", "#需求澄清".
---


## Workflow

1. Carefully read the user's requirement/feedback
2. Identify ambiguities, unclear points, and unspecified details
3. Ask questions to confirm with the user

## Questioning Principles

### Core Principles

- Adjust number of questions based on requirement complexity, no fixed template
- Prioritize questions that most impact implementation
- Each question focuses on a single point, avoid multi-part questions
- First understand "what", then confirm "how"

### Common Clarification Dimensions (use as needed)

- **Scope**: What's included vs excluded
- **Trigger conditions**: When does a behavior trigger
- **Interaction flow**: What happens after user action, is the flow complete
- **State changes**: How states change before/after an action
- **Edge cases**: How to handle exceptions or boundary conditions
- **Visual presentation**: UI details, styles, layout
- **Data flow**: Where data comes from, goes to, and how it connects

### Questioning Strategy

- If requirement involves multiple independent issues, clarify one by one
- If multiple implementations are possible, list options for user to choose
- If user provides screenshots/examples, ask questions based on specific content
- Avoid asking about things user has already clearly stated
- **For complex information structures or page layouts that are hard to describe in words, always use ASCII diagrams to illustrate**

## Format Requirements

```
1. [Question description]
   A. Option one
   B. Option two
   C. Option three (if applicable)

2. [Question description]
   (No options needed for open-ended questions)

3. [Question description]
   A. ...
   B. ...
```

## Example

User input:
> Clarify requirements: Clicking the arrow in onboarding should not open the IAP sheet, but should open the IAP plan selection sheet

Clarification questions:
```
1. After user selects a plan in the Onboarding plan selection panel, what should happen when clicking "Start Free Trial"?
   A. Directly trigger IAP purchase flow
   B. Close panel, return to Onboarding main page, user clicks main CTA to trigger purchase
   C. Other (please specify)

2. If user switches plans in the panel (e.g., from Yearly to Monthly), should the main CTA button's purchase plan also change?
   A. Yes, CTA purchases the user's last selected plan
   B. No, CTA always purchases the default plan (e.g., Yearly)

3. To confirm my understanding of the flow, is this correct?

   Current flow:
   ┌─────────────┐    click ▼    ┌─────────────┐
   │  Onboarding │ ───────────►  │  IAP Sheet  │
   └─────────────┘               └─────────────┘

   Expected flow:
   ┌─────────────┐    click ▼    ┌─────────────┐   select plan   ┌─────────────┐
   │  Onboarding │ ───────────►  │ Plan Picker │ ─────────────►  │  IAP Sheet  │
   └─────────────┘               └─────────────┘                 └─────────────┘

   A. Yes, this is correct
   B. No (please describe the expected flow)
```
