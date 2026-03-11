**Minimal. Usable. Calm. Trustworthy.**
**Version**: v1.0  
**Last Updated**: 2026-01-28  

This document defines the shared design philosophy across all Dudan products.  
It is not a UI guideline, but a **decision-making framework**.  
When trade-offs arise, these principles are the highest authority.

---

## 1. Usability Over Elegance  
**Usability always comes before visual sophistication**

If usability and visual elegance conflict, usability wins.

### Principles
- Users should complete tasks, not admire design
- Any visual detail that increases thinking cost is debt
- Design exists to reduce user effort, not to express taste

### Practical Rules
- Core flows require no explanation
- Avoid designer-only metaphors
- Optimize for “still good after 5 years,” not first-impression wow

---

## 2. One Screen, One Intent  
**Every screen serves a single clear purpose**

Complexity comes from mixed intent, not from feature count.

### Principles
- Each screen answers exactly one user question
- The screen title should reflect the user’s current intent
- If a screen needs explanation, it has failed

### Practical Rules
- One primary action per screen
- Secondary actions must be visually de-emphasized
- Avoid dashboard-style “do everything” pages

---

## 3. Reduce Cognitive Load Aggressively  
**Actively remove thinking, don’t teach users to think more**

### Principles
- Default states must be safe and effective
- Decision fatigue is a design failure
- Advanced options are delayed, not hidden

### Practical Rules
- 80% of flows require no more than 3 decisions
- Defaults are always recommended values
- Never require users to “figure things out first”

---

## 4. Progressive Disclosure, Not Feature Dump  
**Reveal depth gradually, never all at once**

Good products feel simple first, powerful later.

### Principles
- Completion comes before exploration
- Mastery emerges through use, not upfront complexity
- Advanced features should be discovered, not confronted

### Practical Rules
- Initial screens show only core functionality
- Advanced features have clear entry points
- Simple → advanced paths are always reversible

---

## 5. Instant & Calm Feedback  
**Every action gets a response, without noise**

Feedback exists to remove uncertainty, not to entertain.

### Principles
- The system is always responding
- Users should never guess whether something worked
- Motion supports understanding, not emotion

### Practical Rules
- Visible response within 100ms
- Loading states are always explicit
- No silent failures

---

## 6. Forgiving by Default  
**Assume mistakes will happen and design for recovery**

Errors are system responsibilities, not user faults.

### Principles
- Actions should be reversible whenever possible
- Destructive actions require clarity and confirmation
- User input is always valuable

### Practical Rules
- Undo or confirmation for destructive actions
- Never clear user input on errors
- Error messages explain how to fix the problem

---

## 7. Consistency Creates Trust  
**Consistency builds confidence and predictability**

### Principles
- Same actions behave the same everywhere
- Consistency beats local optimization
- Language, placement, and behavior form the product grammar

### Practical Rules
- Same action → same label
- Same state → same visual language
- “This screen is special” is not a valid exception

---

## 8. Accessibility Is Not Optional  
**Accessibility is the baseline of usability**

### Principles
- If it’s not accessible, it’s not usable
- Never rely on color alone to convey meaning
- Keyboard and screen readers are first-class citizens

### Practical Rules
- WCAG AA contrast (≥ 4.5:1)
- Full keyboard navigation
- Clear and visible focus states

---

## 9. Calm Is a Feature  
**Restraint, clarity, and quiet confidence**

Great experiences reduce anxiety instead of creating urgency.

### Principles
- Do not pressure users
- Do not use noise to demand attention
- Do not hide weak logic behind animation

### Practical Rules
- Minimal, predictable motion
- Neutral, human copy
- White space for clarity, not decoration

---

## 10. Design for Long-Term Use  
**Built for daily use over many years**

### Principles
- Not a demo, but a companion
- Durability beats trendiness
- Design is infrastructure, not marketing

### Practical Rules
- Avoid trend-dependent visuals
- Stable typography, color, and layout
- Evolvable systems, not rewrites

---

## When Principles Conflict  
**Decision priority order**

1. Usability  
2. Clarity  
3. Consistency  
4. Accessibility  
5. Visual Elegance  
6. Delight & Decoration  

---

## Changelog

| Version | Date       | Changes          |
|--------|------------|------------------|
| v1.0   | 2026-01-28 | Initial version  |
