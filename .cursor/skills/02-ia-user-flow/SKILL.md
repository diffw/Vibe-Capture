---
name: ia-user-flow
description: Generate Information Architecture and User Flow documents based on completed PRD. Use when user mentions "#信息架构", "#用户流程", "#ia", or "#user-flow". Interviews user about tasks and scenarios, then AI generates IA structure and user flows for confirmation.
---

# IA & User Flow

## When to use this skill

- User inputs `#信息架构`, `#用户流程`, `#ia`, or `#user-flow`
- PRD document has been completed
- Need to define app structure and navigation
- Need to document user flows before design/development

## Prerequisites

None. PRD is optional but recommended.

**PRD reference rules:**
1. If PRD exists at `.vibe-doc/PRD.md`: Read and use its content (platform, features, user stories) to supplement IA & User Flow generation
2. If user's IA description conflicts with PRD content: Highlight the conflict and ask user to confirm which to follow

## Session rules

When user replies "continue" (or "继续"), resume from last position:

1. Read `.vibe-doc/library-ia-flow.md` to check current state
2. Identify completed sections vs. pending sections
3. Resume with format:
   ```
   Resuming IA & User Flow for [ProjectName].
   
   ✅ Completed: [list completed sections]
   ⏳ Current: [current question or phase]
   
   [Continue with next question]
   ```

## Execution flow

### Phase 0: Initialization

1. Check for existing PRD at `.vibe-doc/PRD.md`
2. If PRD found:
   - Read PRD to extract project name, platform, feature list
   - Display: "Found PRD for [ProjectName]. I'll reference it during generation."
3. If PRD not found:
   - Ask for project name:
     ```
     No PRD found.
     
     Q0: What's the project name/codename? (e.g., TaskFlow, MyApp)
     ```
   - Ask for platform:
     ```
     Q0b: Target platform?
          a. macOS
          b. iOS
          c. Web (responsive)
          d. Android
          e. Multiple: [specify]
     ```
4. Create `.vibe-doc/library-ia-flow.md` with template
5. Display:
   ```
   Starting IA & User Flow document for [ProjectName].
   
   Platform: [platform]
   PRD: [Found / Not found]
   
   I'll ask about your user tasks and scenarios, then generate the information architecture and user flows for your review.
   ```

### Phase 1: Task collection (User input)

**Prompt:**
```
Q1: What tasks will users accomplish with this app?
    List all tasks, format:
    - Task name: Brief description
    
    Example:
    - Create note: Write a new text note
    - Create folder: Organize notes into folders
    - Search notes: Find notes by keyword
    - Share note: Send note to others

Q2: Which 3-5 tasks are most frequently used?
    (These determine navigation priority)

Q3: Which tasks need quick access?
    a. One-click from menu bar icon (e.g., quick capture)
    b. Global hotkey activation (e.g., instant search)
    c. Both a and b — please specify which task for each
    d. None, all tasks within main window

Q4: Does user need to view multiple items simultaneously?
    a. Yes — describe scenario (e.g., list on left + detail on right)
    b. No — one content at a time
    c. Depends on task — please specify
```

After response: Save user input, proceed to Phase 2.

### Phase 2: Preference settings (User input)

**Prompt:**
```
Q5: What settings should users be able to configure?
    List by category, e.g.:
    - General: startup behavior, appearance
    - Account: login, sync
    - [Feature-specific]: ...
    
    (Can skip, I'll suggest based on platform standards)

Q6: What system integrations are needed? (Multiple choice)
    a. Spotlight indexing (content searchable by system)
    b. Share extension
    c. Handoff (cross-device continuity)
    d. Notification center
    e. Widgets
    f. None
    g. Other: ___

Q7: Any custom keyboard shortcuts needed?
    Format: Shortcut - Function
    (Can skip, I'll suggest based on tasks)
```

After response: Save user input, proceed to Phase 3.

### Phase 3: AI generation

Notify user:
```
Generating Information Architecture and User Flows based on your input...

Please wait...
```

**PRD conflict detection:**
If PRD exists, compare user's task descriptions with PRD content:
- If conflict found (e.g., user describes a feature not in PRD, or contradicts PRD scope), highlight:
  ```
  ⚠️ Conflict detected:
  
  - Your input: [user's description]
  - PRD states: [PRD content]
  
  Which should I follow?
  a. Follow my input (update PRD later)
  b. Follow PRD
  ```

**AI generates based on:**
- PRD content (platform, features)
- User tasks from Q1-Q4
- Preferences from Q5-Q7
- Platform-specific standards (macOS/iOS/Web)

**Generate the following:**

#### Section 1: Information Architecture
- 1.1 App Structure Overview (tree diagram)
- 1.2 View Inventory (table)
- 1.3 Navigation Structure (layout diagrams)
- 1.4 Window/Screen Management

#### Section 2: User Flows
For each task from Q1, generate:
- Flow overview table
- Detailed flow (steps, user actions, system responses)
- Flow diagram (ASCII)
- Edge cases and error handling

#### Section 3: View States
- State inventory for each view (empty, loading, loaded, error)

#### Section 4: Platform-specific Features
- Keyboard shortcuts (system standard + custom)
- System integrations
- Permission requests

#### Section 5: Flow Relationships
- Relationship diagram between flows

### Phase 4: User confirmation

Present generated content section by section:

```
Generation complete. Please review each section (reply: OK / Edit / Delete)

---
## 1. Information Architecture

### 1.1 App Structure Overview
[generated tree structure]

### 1.2 View Inventory
[generated table]

### 1.3 Navigation Structure
[generated layout diagrams with explanation]

👉 Your feedback:

---
## 2. User Flows

### F-01: [Task Name]
[generated flow details]

### F-02: [Task Name]
[generated flow details]

...

👉 Your feedback:

---
[Continue for sections 3-5]
```

After user confirms: Update IA-UF document with confirmed content.

### Phase 5: Wrap-up

1. Generate glossary if needed
2. Update version info
3. Link to PRD document (if exists)
4. Output:
   ```
   ✅ IA & User Flow generated: `.vibe-doc/library-ia-flow.md`
   
   Related documents:
   - PRD: `.vibe-doc/PRD.md` [if exists]
   
   Let me know if you'd like to modify any section.
   ```

## Platform-specific templates

AI should use appropriate templates based on platform from PRD:

| Platform | Template |
|----------|----------|
| macOS | Three-column/two-column layout, menu bar, toolbar, preferences window |
| iOS | Tab bar, navigation controller, sheets, settings bundle |
| Web | Responsive layout, sidebar, modal dialogs |
| Android | Bottom navigation, drawer, settings activity |

See [references/](../../references/) for platform-specific templates.

## IA-UF template

See [ia-user-flow-template.md](./ia-user-flow-template.md) for the complete template.

## Notes

- Always read PRD first to maintain consistency
- Generate flows for ALL tasks listed in Q1
- Use platform-appropriate UI patterns
- Include ASCII diagrams for visual clarity
- Mark AI-generated content for user review
