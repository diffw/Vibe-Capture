---
name: design-token-generator
description: Design Token generator and editor. Use when user wants to create or modify design tokens, brand colors, or design system configuration. Use when user mentions "#创建design token", "修改design token".
---

# Design Token Generator

## File Locations

- Template: `.cursor/skills/03-design-token/design-token-template.json`
- Output: `.vibe-doc/design-token.json`

---

## Mode A: Generate New Design Tokens

### Step 1: Initialize

1. Read project name from PRD in `.vibe-doc/PRD.md`
2. Copy template to `.vibe-doc/design-token.json`

### Step 2: Ask ALL Questions at Once

Output the following, then WAIT for user to answer all:

```
Created: .vibe-doc/design-token.json

Please answer the following questions (enter number/value, or 'skip'/'default'):

─────────────────────────────────────
Q1. Primary brand color?
    Enter HEX (e.g., #3B82F6):

Q2. Secondary brand color?
    Enter HEX, or 'skip':

─────────────────────────────────────
Q3. Primary font?
    a. system (recommended)
    b. Inter
    c. Poppins
    d. Other: ______

Q4. Need monospace font?
    a. yes (JetBrains Mono)
    b. no

─────────────────────────────────────
Q5. Semantic colors?
    a. default (green/amber/red/blue)
    b. customize

Q6. Visual style (border radius)?
    a. Sharp (0px)
    b. Slightly rounded (4px)
    c. Rounded (8px)
    d. Very rounded (12px)

─────────────────────────────────────
Q7. Light mode background/text/border?
    a. default
    b. customize

Q8. Need Dark Mode?
    a. yes (auto-generate)
    b. no
─────────────────────────────────────

Example answer format:
Q1: #3B82F6
Q2: skip
Q3: a
Q4: a
Q5: a
Q6: c
Q7: a
Q8: a
```

### Step 3: Process Answers

After user responds:
1. Parse all answers
2. Auto-generate derived values (hover/active, radius sm/lg, dark mode if selected)
3. Save to `.vibe-doc/design-token.json`
4. Show summary:

```
✓ Saved: .vibe-doc/design-token.json

Summary:
- Brand: #3B82F6 (hover: #2563EB, active: #1D4ED8)
- Font: system
- Radius: 8px (rounded)
- Dark Mode: yes (auto-generated)
```

---

## Mode B: Modify Existing Design Tokens

### Trigger
User says "modify design token" / "修改 Design Token" / "调整颜色"

### Step 1: Load & Show Options

```
Current Design Token: .vibe-doc/design-token.json

Which to modify? (enter number)

1. Brand primary color      — current: #3B82F6
2. Brand secondary color    — current: #6366F1
3. Primary font             — current: system
4. Monospace font           — current: JetBrains Mono
5. Semantic colors          — success/warning/error/info
6. Border radius            — current: 8px
7. Light mode colors        — bg/text/border
8. Dark mode colors         — bg/text/border
9. Regenerate Dark Mode     — auto-generate from Light Mode

Enter number (1-9), or 'done':
```

### Step 2: Handle Selection

Based on user's choice, ask the specific question:

**If 1:** `New primary color? (HEX):`
**If 2:** `New secondary color? (HEX):`
**If 3:** `New font? (name or 'system'):`
**If 4:** `Monospace font? (name or 'none'):`
**If 5:** `Which semantic color? (success/warning/error/info/all):`
**If 6:** `New radius? (a. 0px / b. 4px / c. 8px / d. 12px):`
**If 7:** `Which? (bg/text/border/all):`
**If 8:** `Which? (bg/text/border/all):`
**If 9:** Auto-regenerate dark mode based on current light mode values

### Step 3: Save & Loop

After each change:
```
Updated! [show what changed]

Modify another? (1-9 / done):
```

---

## Auto-Generation Rules

### Hover/Active Variants
- `primary-hover`: darken primary 10%
- `primary-active`: darken primary 15%

### Radius Variants
- `sm`: base - 4px
- `lg`: base + 4px
- `full`: 9999px

### Dark Mode (WCAG AA)
```json
"dark": {
  "bg-primary": "#0F172A",
  "bg-secondary": "#1E293B",
  "bg-tertiary": "#334155",
  "text-primary": "#F9FAFB",
  "text-secondary": "#94A3B8",
  "text-disabled": "#64748B",
  "border": "#334155",
  "border-strong": "#475569"
}
```
- Contrast ratio ≥ 4.5:1
- No pure black/white
- Brand colors: increase lightness 5-10%