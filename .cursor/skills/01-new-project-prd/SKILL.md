---
name: new-project-prd
description: Guide users through a structured interview to create PRD documents for new projects or features. Captures all product decisions needed for downstream documents (Architecture, IA, Product Spec). Use when user mentions "#新功能", "#新项目", "#创建PRD", "#PRD".
---

# New Project PRD

## When to Use

- Starting a new project or designing a new feature
- Need to create PRD document before development
- Want AI assistance in product definition and competitive research
- Creating PRD for Vibe Coding workflow

## Session Rules

When user replies "continue" (or "继续"), resume from last position:

1. Read `.vibe-doc/PRD.md` to check current state
2. Identify completed sections vs. pending sections marked "[To be filled]"
3. Resume with format:
   ```
   Resuming PRD interview for [ProjectName].
   
   ✅ Completed: [list completed sections]
   ⏳ Current: [current question or phase]
   
   [Continue with next question]
   ```

---

## Execution Flow

### Phase 0: Initialization

1. Create directory `.vibe-doc` if not exists
2. Copy template from `.cursor/skills/01-new-project-prd/prd-template.md` to `.vibe-doc/PRD.md`

**Prompt:**
```
Starting new project PRD interview.

This interview will capture all product decisions needed for development.
I'll ask questions in phases - answer as briefly or detailed as you like.

Q0: What's the project name/codename? (e.g., TaskFlow, MyApp)
```

---

### Phase 1: Product Overview

**Prompt:**
```
## Phase 1: Product Overview

Q1: Describe this product in one sentence—
    "[Product Name] is a [product type] that helps [target users] solve [core problem]"

Q2: Why build this product?
    a. What problems do users currently face?
    b. What's wrong with existing solutions?

Q3: Why is now the right time?

Q4: Product vision—If wildly successful, how will users' lives change?
```

After response, continue:

```
Q5: Launch platform(s)?
    a. Web (responsive)
    b. iOS App
    c. macOS App
    d. Browser Extension
    e. Android App
    f. Windows App
    g. Multiple: [specify, e.g., a+b+c]

Q6: Multi-language support?
    a. No, single language only (which?)
    b. Yes — which languages?
```

**After response:** Update Section 1 in PRD.md immediately.

---

### Phase 1.5: AI Role Assignment

After Phase 1 complete:

```
Based on your project, I'll engage these expert roles for research:

| Module | Role |
|--------|------|
| Competitive Reference | Senior Market Research Expert |
| Success Metrics | Growth Analytics Specialist |
| Technical Constraints | Solutions Architect |
| Risks & Assumptions | Product Strategy Consultant |
| Milestones | Technical Project Manager |

Proceeding with interview...
```

---

### Phase 2: Target Users

**Prompt:**
```
## Phase 2: Target Users

Q7: Who is the core user?
    a. Role/occupation?
    b. Technical level? (Beginner / Intermediate / Advanced)
    c. Biggest pain point?
    d. When/where do they use this product?

Q8: Write one user story—
    "As a [role], I want to [action], so that [benefit]"
    
    (Give me 1, I'll suggest 3-5 more)
```

**After response:**
- Update Section 2.1 in PRD.md
- AI generates 3-5 additional user stories marked "AI Suggested"
- Update Section 2.2

---

### Phase 3: Product Scope

**Prompt:**
```
## Phase 3: Product Scope

Q9: What are the core features (MVP must-haves)?
    Format: 
    - Feature name: Brief description
    
Q10: What's explicitly OUT of scope (won't build)?
     (Can skip — I'll suggest based on similar products)
```

**After response:**
- Update Section 3.1, 3.2
- If Q10 skipped: AI suggests 2-3 items marked "AI Suggested"

---

### Phase 4: Product Characteristics

**Prompt:**
```
## Phase 4: Product Characteristics

These questions help define the technical architecture later.

**Data & Content**

Q11: What will users create/manage in this product?
     (e.g., text notes, tasks, images, files, records, projects)

Q12: Who can see the data?
     a. Private to each user (personal tool)
     b. Shared within teams/groups
     c. Public by default
     d. Private with optional sharing

Q13: How sensitive is this data?
     a. Not sensitive (public info)
     b. Personal but not sensitive (preferences, notes)
     c. Sensitive personal (health, finance, location)
     d. Highly confidential (legal, medical records)
```

After response, continue:

```
**Collaboration**

Q14: Is this a personal tool or collaborative?
     a. Personal only (single user)
     b. Personal with occasional sharing (send a link)
     c. Team collaboration (multiple people edit together)
     d. Community/social (many-to-many interactions)

Q15: If sharing exists, what can shared users do?
     a. View only
     b. View + comment
     c. Full edit access
     d. Configurable per share
     e. N/A (no sharing)
```

After response, continue:

```
**Connectivity**

Q16: Should this work without internet?
     a. No, requires connection
     b. Nice to have (view cached data)
     c. Must work offline with later sync

Q17: If on multiple platforms/devices, how should data sync?
     a. Not needed (single platform)
     b. Manual sync (user triggers)
     c. Sync when app opens
     d. Real-time (instant across devices)

Q18: Is the content time-sensitive?
     a. No, users access at leisure
     b. Sometimes (has deadlines, reminders)
     c. Yes, real-time matters
```

**After response:** Update Section 4.1, 4.2, 4.3 in PRD.md

---

### Phase 5: Usage & Growth

**Prompt:**
```
## Phase 5: Usage & Growth

Q19: How often will users use this?
     a. Multiple times daily (always open)
     b. Daily (morning routine, end of day)
     c. Weekly (planning sessions)
     d. Occasionally (monthly or less)

Q20: Typical session length?
     a. Quick: <1 minute (check and go)
     b. Short: 1-5 minutes
     c. Medium: 5-30 minutes
     d. Long: 30+ minutes (deep work)

Q21: How will users discover this product?
     a. Search engines (SEO)
     b. App store search (ASO)
     c. Word of mouth / referral
     d. Social media
     e. Paid advertising
     f. Multiple: [specify]

Q22: Are users coming from an existing tool?
     a. No, this is new behavior for them
     b. Yes, from: [competitor name(s)]
     c. Yes, from spreadsheets/manual process
```

**After response:** Update Section 4.4 in PRD.md

---

### Phase 6: Notifications & Business Model

**Prompt:**
```
## Phase 6: Notifications & Monetization

**Notifications**

Q23: What notifications are needed?
     a. None
     b. Email only (verification, password reset)
     c. Push notifications (reminders, updates)
     d. Both email and push
     e. Undecided

Q24: If notifications, what triggers them?
     (e.g., reminders, deadlines, activity from others, system updates)
```

After response, continue:

```
**Business Model**

Q25: How will this make money (or not)?
     a. Free forever
     b. Freemium (free tier + paid upgrade)
     c. Paid only (no free tier)
     d. Subscription (monthly/annual)
     e. One-time purchase
     f. Undecided

Q26: If freemium, what's limited in free tier?
     a. Feature limits (certain features paid-only)
     b. Usage limits (e.g., 5 projects free)
     c. Storage limits
     d. Time limit (trial then pay)
     e. N/A (not freemium)
```

**After response:** Update Section 4.5, 4.6 in PRD.md

---

### Phase 7: UX Tone

**Prompt:**
```
## Phase 7: UX Tone & Voice

Q27: What's the overall tone?
     a. Friendly & casual ("Hey! Let's get started")
     b. Professional & clear ("Welcome. Create your first project.")
     c. Minimal & quiet ("New project")
     d. Playful & fun (with emoji, personality)

Q28: When errors happen, how should messages feel?
     a. Friendly: "Oops! Something went wrong. Let's try again."
     b. Professional: "Error: Unable to save. Please retry."
     c. Minimal: "Save failed. Retry"

Q29: How should the product address the user?
     a. "You" / "Your" (direct)
     b. "We" / "Let's" (collaborative)
     c. User's name ("Hi Sarah")
     d. Neutral (no direct address)
```

**After response:** Update Section 6 in PRD.md

---

### Phase 8: Design Principles

Check if `.cursor/references/design-principle.md` exists:

**If exists:**
```
## Phase 8: Design Principles

I found your design principles document. 

[Show summary of principles]

Should I reference these for this project?
a. Yes, apply all
b. Yes, with modifications: [specify]
c. No, this project has different principles
```

**If not exists:**
```
## Phase 8: Design Principles

No design principles document found at `.cursor/references/design-principle.md`.

Would you like to:
a. Skip for now (add later)
b. Define key principles now (I'll help)
```

**After response:** Update Section 5 in PRD.md

---

### Phase 9: Open-ended

**Prompt:**
```
## Phase 9: Final Thoughts

Q30: Anything else important that I haven't asked?

This could include:
- Product philosophy or values
- Hard constraints (budget, timeline, team size)
- Inspirations ("I love how X does Y")
- Concerns or risks you're thinking about
- Technical preferences (if any)

(Feel free to skip if nothing comes to mind)
```

**After response:** Update Section 13.1 in PRD.md

---

### Phase 10: AI Research

**Notify user:**
```
✅ Interview complete! 

Now I'll conduct expert research on:
- Competitive landscape (Market Research Expert)
- Success metrics with benchmarks (Growth Analyst)
- Technical recommendations (Solutions Architect)
- Risks & assumptions (Strategy Consultant)
- Milestone planning (Project Manager)

This may take a moment...
```

**Research Requirements:**

#### 10.1 Competitive Reference (Market Research Expert)

Research 3+ competitors. For each:

| Data Point | Requirement |
|------------|-------------|
| Product & Link | Official name, URL |
| Ranking | App Store / Web ranking if available |
| User Base | Downloads, MAU/DAU or "Data not public" |
| Release & Updates | Launch date, last update, frequency |
| Company | Name, size |
| Revenue | Estimated or "Data not public" |
| Pricing Model | Free / Freemium / Subscription / One-time |
| **Paywall Trigger** | When/how paywall appears |
| **All Pricing Tiers** | Exact prices for all options |
| What to Learn | Key strengths |
| What to Avoid | Weaknesses, complaints |

#### 10.2 Success Metrics (Growth Analyst)

- North Star Metric with industry benchmark + source
- AARRR metrics table with benchmarks

#### 10.3 Technical Constraints (Solutions Architect)

- Tech preferences based on requirements
- Third-party service recommendations

#### 10.4 Risks & Assumptions (Strategy Consultant)

- Core assumptions to validate
- Risk identification with mitigation

#### 10.5 Milestones (Project Manager)

- Phased delivery plan

---

**Present research for review:**

```
## Research Complete

Review each section. Reply with: ✓ (approve) / ✗ (remove) / Edit: [changes]

---

### 7. Competitive Reference
> 📌 Senior Market Research Expert

[Competitor analysis tables]

👉 Your feedback:

---

### 8. Success Metrics  
> 📌 Growth Analytics Specialist

[Metrics tables with benchmarks]

👉 Your feedback:

---

### 9. Technical Constraints
> 📌 Solutions Architect

[Recommendations]

👉 Your feedback:

---

### 10. Risks & Assumptions
> 📌 Product Strategy Consultant

[Risk tables]

👉 Your feedback:

---

### 11. Milestones
> 📌 Technical Project Manager

[Milestone table]

👉 Your feedback:
```

**After user confirms:** Update Sections 7-11 in PRD.md

---

### Phase 11: Wrap-up

1. Ask if glossary terms needed
2. Generate "AI Implementation Notes" section based on all answers
3. Generate "Appendix: AI Roles" section
4. Update version info and date

**Final output:**
```
✅ PRD Complete: `.vibe-doc/PRD.md`

## Summary

| Section | Status |
|---------|--------|
| Product Overview | ✓ |
| Target Users | ✓ |
| Product Scope | ✓ |
| Product Characteristics | ✓ |
| Design Principles | ✓ |
| UX Guidelines | ✓ |
| Competitive Reference | ✓ |
| Success Metrics | ✓ |
| Technical Constraints | ✓ |
| Risks & Assumptions | ✓ |
| Milestones | ✓ |
| AI Implementation Notes | ✓ |

**Next Steps:**
1. Review the complete PRD
2. Create IA & User Flow (`#ia-user-flow`)
3. Create Architecture Design (`#architecture`)

Let me know if you'd like to modify any section.
```

---

## Question Reference

Complete list of all questions for quick reference:

| Phase | ID | Topic | Question Summary |
|-------|-----|-------|------------------|
| 0 | Q0 | Setup | Project name |
| 1 | Q1 | Overview | One-liner description |
| 1 | Q2 | Overview | Why build this |
| 1 | Q3 | Overview | Why now |
| 1 | Q4 | Overview | Vision |
| 1 | Q5 | Overview | Platforms |
| 1 | Q6 | Overview | Languages |
| 2 | Q7 | Users | Core persona |
| 2 | Q8 | Users | User story |
| 3 | Q9 | Scope | Core features |
| 3 | Q10 | Scope | Out of scope |
| 4 | Q11 | Data | Content types |
| 4 | Q12 | Data | Data ownership |
| 4 | Q13 | Data | Data sensitivity |
| 4 | Q14 | Collab | Personal vs team |
| 4 | Q15 | Collab | Sharing permissions |
| 4 | Q16 | Connect | Offline requirement |
| 4 | Q17 | Connect | Sync behavior |
| 4 | Q18 | Connect | Time sensitivity |
| 5 | Q19 | Usage | Frequency |
| 5 | Q20 | Usage | Session duration |
| 5 | Q21 | Growth | Acquisition channel |
| 5 | Q22 | Growth | Migration source |
| 6 | Q23 | Notify | Notification channels |
| 6 | Q24 | Notify | Notification triggers |
| 6 | Q25 | Business | Business model |
| 6 | Q26 | Business | Freemium limits |
| 7 | Q27 | UX | Tone |
| 7 | Q28 | UX | Error messages |
| 7 | Q29 | UX | Address user |
| 8 | - | Design | Design principles |
| 9 | Q30 | Open | Anything else |

---

## Notes

- Update PRD.md immediately after each phase
- Mark AI-generated content with "AI Suggested" or role name
- When user says "skip": Provide suggested value
- Keep questions concise with option letters
- Batch related questions (3-5 per prompt)
- Use web search for competitive research
- All research must include sources

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-30 | Initial version |
| 2.0 | 2025-01-30 | Added Product Characteristics (Q11-Q22), UX Tone (Q27-Q29), Open-ended (Q30) |
