---
name: architecture-design
description: Generate Architecture Design document from PRD and IA/User Flow. AI acts as Solutions Architect, recommending technical solutions based on product requirements. User only answers business questions. Use when user mentions "#architecture", "#架构设计", or "continue architecture".
---

## Overview

This skill generates a complete Architecture Design document based on:
- Completed PRD (product requirements)
- Completed IA & User Flow (features and flows)

The AI acts as **Solutions Architect**, recommending technical solutions based on product requirements. User only needs to answer business questions and confirm the solution meets product intent.

**User does NOT need to**:
- Understand technical details
- Make technology choices
- Review code or configurations

---

## Input Files

All inputs are read from `.vibe-doc/`:

| File | Required | Description |
|------|----------|-------------|
| `.vibe-doc/PRD.md` | ✅ | Completed PRD with platform info |
| `.vibe-doc/library-ia-flow.md` | ✅ | Completed IA & User Flow |

---

## Template File

| Template | Path |
|----------|------|
| Architecture Template | `.cursor/skills/05-architecture/architecture-template.md` |

---

## Output File

| Output | Path |
|--------|------|
| Architecture Design | `.vibe-doc/architecture.md` |

---

## Workflow

### First Run (Initialization)

```
1. READ `.vibe-doc/PRD.md`
   - Extract platform(s) from Section 1.4
   - Extract features and requirements
   - Note answers to business questions
                               │
                               ▼
2. READ `.vibe-doc/library-ia-flow.md`
   - Extract entities and relationships
   - Extract user flows
   - Note implied requirements
                               │
                               ▼
3. COPY template from `.cursor/skills/05-architecture/architecture-template.md`
   CREATE `.vibe-doc/architecture.md`
                               │
                               ▼
4. SCAN Business Questions Checklist
   - Mark questions answered by PRD as SKIP
   - Mark questions answered by IA as SKIP
   - Identify remaining questions to ask
                               │
                               ▼
5. ASK remaining business questions
   (Batch short questions, 3-5 per round)
                               │
                               ▼
6. SUMMARIZE all requirements (from PRD + IA + answers)
   Confirm with user before generating
                               │
                               ▼
7. GENERATE architecture based on:
   - PRD requirements
   - IA/User Flow entities and flows
   - User answers
   - AI best practice recommendations
                               │
                               ▼
8. SAVE and report progress
```

### Resume (User says "continue" or "继续")

```
1. READ `.vibe-doc/architecture.md`
2. IDENTIFY last completed section
3. CONTINUE from next incomplete section
4. ASK questions if needed
5. SAVE and report progress
```

### Update (User says "modify" or "修改")

```
1. ASK: "Which section do you want to modify?"
2. WAIT for user response
3. NAVIGATE to specified section
4. ASK for changes or re-generate
5. UPDATE section
6. SAVE and confirm
```

---

## Business Questions Checklist

### CRITICAL RULE: Skip Questions Already Answered

Before asking any question, AI MUST check:

```
FOR EACH question in checklist:
  1. Search PRD for answer
     - Check relevant sections
     - Check user stories
     - Check feature list
     - Check AI Implementation Notes
  
  2. Search IA/User Flow for answer
     - Check flow descriptions
     - Check edge cases
     - Check view states
  
  3. IF answer found:
     - Mark as SKIP
     - Note the answer and source
     - DO NOT ask user
  
  4. IF answer NOT found or AMBIGUOUS:
     - Add to questions list
     - ASK user
```

**Example of skipping:**

```
PRD Section 3.1 says: "User registration with email and password"
→ SKIP question U2 (How do users sign up?)
→ Answer is: Email + password (Source: PRD 3.1)

IA Flow F-03 says: "Sign in with Apple flow"  
→ SKIP question U2 about social login
→ Answer includes: Apple Sign In (Source: IA F-03)

PRD Section 2.1 says: "Single user, personal use"
→ SKIP questions D1, D2, D3 about sharing
→ Answer is: Private data, no sharing (Source: PRD 2.1)
```

---

### Question Format

**Batch short questions (3-5 per round):**

```
Based on your PRD and IA documents, I still need clarification on:

1. **[Topic]**: [Question]?
   → A) [Option]  B) [Option]  C) [Option]

2. **[Topic]**: [Question]?
   → A) [Option]  B) [Option]

3. **[Topic]**: [Question]?
   → A) [Option]  B) [Option]  C) [Option]

Reply format: 1-A, 2-B, 3-C (or describe if none fit)
```

**For complex questions (one at a time):**

```
**[Topic]**

[Context from PRD/IA if relevant]

[Detailed question]

A) [Option with explanation]
B) [Option with explanation]
C) [Option with explanation]

Which fits your product vision?
```

---

### Category 1: User & Account System

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| U1 | Does your product require user accounts to use core features? | A) Yes, must sign up first B) Optional, can use as guest then convert C) No accounts needed | User registration flow, login flow |
| U2 | What sign-up methods should be available? | A) Email + password only B) Email magic link (passwordless) C) Social logins (Google, Apple, etc.) D) Multiple methods | Auth flows in IA, PRD feature list |
| U3 | For social login, which providers? | A) Apple only (required for iOS) B) Apple + Google C) Apple + Google + GitHub D) Other: [specify] | OAuth flows in IA |
| U4 | Is email verification required before using the app? | A) Yes, must verify B) No, can use immediately C) Required for some features only | Registration flow edge cases |
| U5 | Can one email be used for multiple accounts? | A) No, one account per email B) Yes, separate accounts allowed | PRD user model |
| U6 | Do you need different user roles with different permissions? | A) No, all users equal B) Yes, admin + regular user C) Yes, multiple roles: [describe] D) Yes, custom permissions per user | PRD features, user types |
| U7 | Can users change their email address after registration? | A) Yes B) No | User settings flow |
| U8 | Can users change their password? | A) Yes, with current password B) Yes, with email verification C) No | User settings flow |
| U9 | Forgot password recovery method? | A) Email link B) Email code C) Security questions D) Not needed | Password reset flow in IA |
| U10 | Can users delete their account? | A) Yes, permanently delete all data B) Yes, but anonymize data (keep for analytics) C) Yes, soft delete (recoverable) D) No deletion allowed | PRD compliance, user rights |
| U11 | When account deleted, what happens to shared content? | A) Also deleted B) Transferred to another user C) Becomes anonymous D) N/A - no sharing | Only if sharing exists |
| U12 | Session management: can user be logged in on multiple devices? | A) Yes, unlimited devices B) Yes, limited to [X] devices C) No, single device only | Cross-device usage in PRD |
| U13 | Auto-logout after inactivity? | A) No B) Yes, after [X] minutes C) Only on sensitive pages | Security requirements |
| U14 | Remember me / stay logged in option? | A) Yes, default on B) Yes, default off C) No, always require login | Login flow |
| U15 | Biometric login (Face ID, Touch ID) for mobile? | A) Yes, optional B) Yes, required C) No | iOS/macOS features |

---

### Category 2: Data Ownership & Privacy

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| D1 | Who owns the data users create? | A) User owns, completely private B) User owns, platform can use anonymized C) Platform owns | PRD terms, privacy section |
| D2 | Can users see other users' data? | A) Never, completely isolated B) Only if explicitly shared C) Public profiles visible D) All content public by default | User stories, sharing features |
| D3 | Can users share their content with others? | A) No sharing B) Share via link (read-only) C) Share via link (can comment) D) Share with edit permissions E) Multiple sharing levels | Sharing flows in IA |
| D4 | If shareable, who can users share with? | A) Anyone with link B) Only registered users C) Only invited users D) Specific groups/teams | Sharing flow details |
| D5 | Can shared access be revoked? | A) Yes, owner can revoke anytime B) Yes, with conditions C) No, once shared always shared | Sharing edge cases |
| D6 | Is there team/organization concept? | A) No, individual users only B) Yes, users can create teams C) Yes, organization with departments D) Yes, complex hierarchy | PRD user model, feature list |
| D7 | If teams exist, how is billing handled? | A) Per-user billing B) Per-team billing C) Organization-wide billing D) N/A - no teams | Pricing model, team features |
| D8 | Data residency requirements? | A) No requirements B) Must store in specific region C) User chooses region | PRD compliance, target market |
| D9 | GDPR/privacy compliance needed? | A) Yes, full compliance B) Basic privacy only C) Not required | PRD target market |
| D10 | User data export (GDPR right)? | A) Yes, full export B) Yes, limited export C) Not required | PRD compliance |
| D11 | Should deleted data be recoverable? | A) No, permanent delete B) Yes, trash with [X] days recovery C) Yes, unlimited recovery | Delete flows in IA |
| D12 | Audit log of user actions? | A) No B) Yes, for user's own actions C) Yes, admin can see all D) Yes, detailed compliance log | PRD requirements, security |

---

### Category 3: Data Sync & Real-time

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| S1 | Is cross-device usage expected? | A) Single device only B) Multiple devices, same platform (e.g., two iPhones) C) Cross-platform (e.g., iPhone + Mac + Web) | PRD platforms, user scenarios |
| S2 | How quickly should changes sync to other devices? | A) Real-time (instant) B) Near real-time (few seconds) C) On app open/refresh D) Manual sync only | PRD requirements, user expectations |
| S3 | Should users see when data was last synced? | A) No, invisible B) Yes, show last sync time C) Yes, show sync status indicator | UI requirements |
| S4 | Can multiple people edit the same item simultaneously? | A) No, single editor B) Yes, but lock while editing C) Yes, real-time collaboration D) Yes, with conflict resolution UI | Collaboration features in PRD |
| S5 | If conflict occurs (two edits to same data), how to resolve? | A) Last write wins (server) B) Last write wins (by timestamp) C) Keep both versions D) Ask user to resolve E) Merge automatically | Only if multi-device/multi-user |
| S6 | Should user be notified when data changes elsewhere? | A) No notification B) Subtle UI update C) Explicit notification D) Push notification | Notification features |
| S7 | Background sync when app not active? | A) No B) Yes, periodic C) Yes, on system events D) Platform dependent | Platform features |

---

### Category 4: Offline Capability

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| O1 | Should the app work without internet? | A) No, requires connection B) Yes, view cached data C) Yes, view + create new D) Yes, full functionality | PRD requirements, user scenarios |
| O2 | If offline, which features should work? | A) View only B) View + create C) View + create + edit D) Everything except sync | Feature-specific if O1 not A |
| O3 | How much data to cache offline? | A) Recent items only B) User-selected items C) Everything D) Smart (frequently used) | Storage constraints |
| O4 | Offline data storage limit? | A) No limit B) System managed C) Fixed limit: [X] MB D) User configurable | Storage constraints |
| O5 | When going back online, how to sync? | A) Automatic immediately B) Automatic when on WiFi C) Manual trigger D) Ask user | Sync preferences |
| O6 | Show offline indicator? | A) No B) Subtle indicator C) Prominent banner D) Block actions with message | UI requirements |
| O7 | What if user makes changes offline that conflict with server? | A) Server wins, discard local B) Local wins, overwrite server C) Keep both D) Show conflict resolution UI E) Merge automatically | Conflict handling |
| O8 | Queue actions while offline? | A) No, show error B) Yes, queue and execute when online C) Yes, with retry limits | If O1 not A |
| O9 | What happens if offline too long? | A) Nothing, keep all changes B) Warn after [X] days C) Auto-discard after [X] days D) Require re-auth when online | Long offline scenarios |

---

### Category 5: Notifications & Communication

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| N1 | Email notifications needed? | A) No B) Transactional only (verify, reset password) C) Transactional + activity D) Full marketing emails too | PRD features, notification flows |
| N2 | Push notifications needed? | A) No B) Yes, iOS/macOS only C) Yes, all platforms D) Web push too | Platform features, notification flows |
| N3 | In-app notifications/inbox? | A) No B) Simple badge/count C) Notification center/inbox D) Full activity feed | UI flows, notification features |
| N4 | What events trigger notifications? | A) User-initiated only (reminders) B) System events (deadlines, updates) C) Social events (shares, comments) D) All of above | Notification flows in IA |
| N5 | Notification frequency control? | A) All or nothing B) Per-category control C) Per-item control D) Custom schedule | Settings flows |
| N6 | Quiet hours / do not disturb? | A) No B) Yes, user-set schedule C) Yes, system DND integration | Settings features |
| N7 | Email digest option? | A) No, immediate only B) Yes, daily digest C) Yes, weekly digest D) User chooses frequency | Notification preferences |
| N8 | Notification sound/vibration customization? | A) System default only B) App default, can disable C) Multiple sound options | Mobile app features |
| N9 | Rich notifications (images, actions)? | A) Simple text only B) Yes, with images C) Yes, with action buttons D) Yes, full rich | Push notification requirements |
| N10 | Notification history? | A) No, ephemeral B) Yes, in-app history C) Yes, with search | Notification features |

---

### Category 6: File & Media Handling

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| F1 | Can users upload files? | A) No uploads B) Images only C) Images + documents D) Any file type | PRD features, upload flows |
| F2 | Upload source? | A) Device storage only B) Camera capture too C) Cloud services (Drive, Dropbox) D) URL import E) All sources | Upload flow details |
| F3 | Maximum file size per upload? | A) 1 MB B) 5 MB C) 25 MB D) 100 MB E) Unlimited F) Varies by file type | Requirements, pricing tier |
| F4 | Total storage limit per user? | A) Unlimited B) [X] MB/GB C) Varies by pricing tier D) Shared team quota | Pricing model, storage |
| F5 | Image processing needed? | A) Store original only B) Resize/compress C) Generate thumbnails D) Multiple sizes E) Advanced (crop, rotate, filters) | Image display requirements |
| F6 | Image format requirements? | A) Accept all, store as-is B) Convert to standard format C) Preserve original + web format | Performance requirements |
| F7 | Document preview? | A) No preview, download only B) Image preview C) PDF preview D) Office doc preview E) All formats | Document features |
| F8 | Video support? | A) No video B) Upload only, no streaming C) Streaming playback D) Video processing (transcode) | Media features |
| F9 | Audio support? | A) No audio B) Upload only C) Playback D) Recording E) Processing | Media features |
| F10 | File versioning? | A) No, replace only B) Yes, keep [X] versions C) Yes, unlimited versions | Version control needs |
| F11 | File sharing permissions? | A) Same as content B) Separate file permissions C) Public file links | Sharing features |
| F12 | Virus/malware scanning? | A) No B) Yes, on upload C) Yes, on download too | Security requirements |

---

### Category 7: Payments & Monetization

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| P1 | Business model? | A) Free forever B) Freemium C) Paid only D) Ads supported E) Undecided | PRD business model |
| P2 | If freemium, what's limited in free tier? | A) Feature limits B) Usage limits C) Storage limits D) Time limits E) Combination | PRD pricing tiers |
| P3 | Payment model? | A) One-time purchase B) Monthly subscription C) Annual subscription D) Both monthly + annual E) Usage-based F) Credits/tokens | PRD pricing |
| P4 | Free trial offered? | A) No trial B) Yes, [X] days full access C) Yes, limited features D) Yes, limited usage | PRD pricing |
| P5 | Payment processors? | A) Stripe only B) Apple/Google IAP only C) Stripe + IAP D) PayPal too E) Regional processors | Platform requirements |
| P6 | Handle Apple's 30% fee how? | A) Same price (eat the fee) B) Higher price on iOS C) No iOS purchases (web only) D) IAP for required, Stripe for optional | iOS pricing strategy |
| P7 | Multiple pricing tiers? | A) Single tier B) 2 tiers (free/pro) C) 3+ tiers D) Custom enterprise | PRD pricing |
| P8 | Team/organization billing? | A) N/A B) Per-seat billing C) Flat team rate D) Volume discounts | Team features |
| P9 | Invoicing for business customers? | A) No, self-serve only B) Yes, automatic invoices C) Yes, custom invoices | Business features |
| P10 | Refund policy? | A) No refunds B) [X] day money-back C) Prorated refunds D) Case-by-case | PRD policies |
| P11 | Upgrade/downgrade handling? | A) Immediate B) End of billing period C) Prorated | Subscription logic |
| P12 | Failed payment handling? | A) Immediate downgrade B) Grace period [X] days C) Retry then downgrade | Subscription logic |
| P13 | Promotional codes/discounts? | A) No B) Yes, percentage off C) Yes, fixed amount D) Yes, free months E) All types | Marketing features |

---

### Category 8: Search & Discovery

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| SR1 | Search functionality needed? | A) No search B) Basic text search C) Advanced filters D) Full-text search E) AI-powered | Search features in IA |
| SR2 | Search scope? | A) User's own data only B) Shared data too C) Public content D) Global search | Data access model |
| SR3 | Search filters? | A) No filters B) Basic (date, type) C) Advanced (multiple criteria) D) Saved filters | Search UI |
| SR4 | Sort options? | A) Relevance only B) Date, name, etc. C) Custom sort D) User-defined | List/search UI |
| SR5 | Pagination style? | A) Traditional pages B) Load more button C) Infinite scroll D) All at once | UI patterns |
| SR6 | Recent/history feature? | A) No history B) Recent items C) Recent searches D) Full activity history | Navigation features |
| SR7 | Favorites/bookmarks? | A) No B) Yes, simple star C) Yes, with folders/tags D) Yes, with notes | Organization features |
| SR8 | Tags/labels on content? | A) No tags B) Predefined tags C) User-created tags D) Both E) Hierarchical tags | Organization features |

---

### Category 9: Analytics & Tracking

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| A1 | User analytics needed? | A) No B) Basic (page views, sessions) C) Detailed (funnels, cohorts) D) Full product analytics | PRD metrics |
| A2 | What metrics matter most? | A) Acquisition B) Activation C) Retention D) Revenue E) All | PRD success metrics |
| A3 | User identification in analytics? | A) Anonymous only B) Identified users C) Both with toggle | Privacy model |
| A4 | Event tracking granularity? | A) Page views only B) Key actions C) Detailed interactions D) Everything | Analytics needs |
| A5 | Error tracking/monitoring? | A) No B) Basic error logs C) Full error tracking (Sentry) D) With user context | Development needs |
| A6 | Performance monitoring? | A) No B) Basic metrics C) Detailed APM D) Real-user monitoring | Performance needs |
| A7 | User feedback collection? | A) No B) In-app feedback button C) Surveys D) Full feedback system | Feedback features |
| A8 | A/B testing needed? | A) No B) Simple feature flags C) Full A/B testing D) Multivariate testing | Growth features |

---

### Category 10: Security & Compliance

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| SE1 | Data sensitivity level? | A) Public data B) Personal but not sensitive C) Sensitive personal data D) Financial/health data | Data type, compliance |
| SE2 | Encryption requirements? | A) Standard (HTTPS + at rest) B) Enhanced encryption C) End-to-end encryption D) User-managed keys | Security requirements |
| SE3 | Two-factor authentication? | A) Not needed B) Optional for users C) Required for all D) Required for admins only | Security features |
| SE4 | Session security? | A) Standard tokens B) Refresh token rotation C) Device binding D) Additional verification | Security level |
| SE5 | IP/location restrictions? | A) No restrictions B) Suspicious login alerts C) Configurable restrictions D) Geo-blocking | Security features |
| SE6 | Rate limiting? | A) Standard (prevent abuse) B) Strict (API limits) C) Tiered by plan D) Custom | API usage |
| SE7 | Data backup requirements? | A) Provider default B) Daily backups C) Point-in-time recovery D) Multi-region | Data requirements |
| SE8 | Compliance certifications needed? | A) None B) SOC 2 C) HIPAA D) PCI DSS E) Multiple | Industry requirements |
| SE9 | Audit requirements? | A) None B) Basic logging C) Detailed audit trail D) Compliance audit trail | Compliance needs |
| SE10 | Penetration testing? | A) No B) Annual C) Continuous D) Bug bounty | Security maturity |

---

### Categories 11-13: Platform-Specific Questions

Based on the platform(s) specified in PRD Section 1.4, read the corresponding question file(s) from this directory:

| Platform in PRD | Question File |
|-----------------|---------------|
| Web, Website, Next.js, React | `questions-web.md` |
| iOS, macOS, Apple, SwiftUI, iPhone, Mac | `questions-apple.md` |
| Browser Extension, Chrome Extension | `questions-extension.md` |

Read ONLY the file(s) matching the project's platform(s).
If multiple platforms, read all applicable files.
Skip this section entirely if PRD platform is not in the table.

---

### Category 14: Scale & Performance

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| SC1 | Expected users at launch? | A) <100 (beta) B) <1,000 C) <10,000 D) 10,000+ | Launch plan |
| SC2 | Expected users in 1 year? | A) <1,000 B) <10,000 C) <100,000 D) 100,000+ E) 1M+ | Growth plan |
| SC3 | Expected users in 3 years? | A) <10,000 B) <100,000 C) <1M D) 1M+ E) 10M+ | Growth plan |
| SC4 | Data volume per user? | A) Tiny (<1MB) B) Small (<10MB) C) Medium (<100MB) D) Large (<1GB) E) Very large (1GB+) | Storage planning |
| SC5 | Read/write ratio? | A) Read-heavy (90%+ reads) B) Balanced C) Write-heavy D) Varies by feature | Database design |
| SC6 | Peak usage patterns? | A) Steady throughout day B) Business hours peak C) Specific times D) Unpredictable spikes | Infrastructure |
| SC7 | Geographic distribution? | A) Single region B) Single continent C) Global D) Specific regions: [list] | CDN, multi-region |
| SC8 | Latency sensitivity? | A) Not critical B) Moderate (<500ms) C) Important (<200ms) D) Critical (<100ms) | Performance requirements |
| SC9 | Uptime requirements? | A) Best effort B) 99% (3.65 days down/year) C) 99.9% (8.76 hours) D) 99.99% (52 minutes) | SLA needs |
| SC10 | Disaster recovery? | A) Not critical B) Same-day recovery C) Hours recovery D) Minutes recovery | Business continuity |

---

### Category 15: Integration & API

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| I1 | Import from other apps? | A) No import B) Yes: [list formats/apps] | Migration features |
| I2 | Export to other apps? | A) No export B) Standard formats (CSV, JSON) C) Specific apps D) Full data portability | Export features |
| I3 | Integrate with external services? | A) No B) Yes: [list services] | Integration features |
| I4 | Webhook notifications? | A) No B) Yes, outgoing webhooks C) Yes, incoming webhooks D) Both | Integration features |
| I5 | Public API? | A) No B) Future consideration C) Yes, from start D) Yes, as core product | API product |
| I6 | API authentication? | A) API keys B) OAuth C) Both D) N/A | If API exists |
| I7 | Rate limits for API? | A) Generous B) Standard C) Strict D) By pricing tier | If API exists |
| I8 | Zapier/Make integration? | A) No B) Future consideration C) Yes, from start | Automation features |
| I9 | Calendar integration? | A) No B) View only C) Two-way sync | Calendar features |
| I10 | Email integration? | A) No B) Send emails from app C) Email to app D) Both | Email features |

---

## Question Flow

```
1. READ PRD and IA-User-Flow thoroughly
   Extract all explicit and implied answers
                    │
                    ▼
2. CREATE answer map from documents
   Category by category, mark what's known
                    │
                    ▼
3. IDENTIFY gaps
   List questions with no clear answer
                    │
                    ▼
4. PRIORITIZE questions
   - Must-know for architecture (ask first)
   - Nice-to-know (ask if time)
   - Can-assume (use defaults, mention in summary)
                    │
                    ▼
5. ASK in batches
   - 3-5 short questions per round
   - 1 complex question per round
   - Group by category when possible
                    │
                    ▼
6. SUMMARIZE before generating
   Show all answers (from docs + user)
   Confirm understanding
                    │
                    ▼
7. GENERATE architecture
```

---

## Answer Summary Template

Before generating architecture, confirm with user:

```
## Requirements Summary

I've gathered requirements from your PRD, IA documents, and our conversation.

### From Your Documents (PRD & IA)
- Platforms: Web, iOS, macOS
- User accounts: Required, email + password + Apple Sign In
- Data model: Users, Projects, Tasks (from IA entities)
- Key flows: Registration, Login, CRUD operations (from IA)
- [Other extracted requirements]

### From Our Conversation
- Offline: View cached data, queue creates
- Sync: Real-time for active users
- Notifications: Push for reminders, email for transactional
- [Other answered questions]

### Assumptions (using defaults)
- Session: Multi-device allowed, 7-day refresh token
- Storage: 100MB per user (standard tier)
- Analytics: PostHog for product analytics
- [Other reasonable defaults]

---

**Does this accurately capture your requirements?**

If yes, I'll generate the architecture document.
If anything is wrong or missing, please let me know.
```

---

## AI Recommendation Principles

### Default Tech Choices

| Component | Default | Change If |
|-----------|---------|-----------|
| Backend | Supabase | Need custom logic → add Edge Functions |
| Database | PostgreSQL (Supabase) | Need document store → consider alternatives |
| Auth | Supabase Auth | Enterprise SSO → add Auth0 |
| Storage | Supabase Storage | Large files/video → dedicated CDN |
| Web | Next.js 14 | Simple static → plain React |
| iOS/macOS | SwiftUI | Need complex AppKit → hybrid |
| Extension | Plasmo | Single browser → vanilla MV3 |
| Email | Resend | High volume → SendGrid |
| Analytics | PostHog | Enterprise → Amplitude |
| Payments | Stripe + IAP | Crypto → add processor |

### Data Model Generation

From IA/User Flow, extract:
- **Entities**: Nouns in flows (User, Project, Task)
- **Relationships**: Ownership, references (User has Projects)
- **Attributes**: Fields in UI (title, status, due_date)
- **Enums**: Status fields (draft, active, completed)
- **Constraints**: Required fields, unique fields

### API Generation

From User Flows, generate:
- **Auth endpoints**: From auth flows
- **CRUD endpoints**: For each entity
- **Validation**: From form fields in UI
- **Errors**: From edge cases in flows
- **Permissions**: From data ownership model

---

## Progress Tracking

After each session:

```
---

## Progress Report

**Document**: `.vibe-doc/architecture.md`

**Questions Answered**:
- From PRD/IA: 45 questions (auto-extracted)
- From conversation: 12 questions
- Using defaults: 8 assumptions

**Completed Sections**:
- [x] 1. Platform Overview
- [x] 2. System Architecture
- [x] 3.1 Tech Stack - Backend
- [x] 3.2 Tech Stack - Web

**Current Position**: Section 3.3 - Tech Stack (iOS)

**Remaining**:
- [ ] 3.3 Tech Stack - iOS
- [ ] 3.4 Tech Stack - macOS
- [ ] 4. Data Model
- [ ] 5. API Specification
- [ ] 6. Auth Strategy

**Next Action**: Say "continue" to resume from Section 3.3

**Pending Questions**: None
```

---

## Validation Checklist

Before marking complete:

- [ ] All platforms from PRD covered in Tech Stack
- [ ] All entities from IA in Data Model
- [ ] All user flows have API endpoints
- [ ] Auth methods match PRD (esp. Sign in with Apple for iOS)
- [ ] Offline strategy defined if required
- [ ] Sync strategy matches user expectations
- [ ] Third-party services identified
- [ ] Environment variables documented
- [ ] No questions left unanswered
- [ ] Summary confirmed by user

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-30 | Initial version |
