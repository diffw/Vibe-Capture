# [Product Name] Architecture Design

> **Version**: 1.0  
> **Last Updated**: [Date]  
> **Author**: [User] + AI  
> **Status**: Draft / In Review / Approved  
> **Related PRD**: [Link to PRD]

---

## Document Purpose

This document defines the technical architecture for AI implementation. It covers all supported platforms and shared backend infrastructure.

**For non-technical readers**: You don't need to understand technical details. Your role is to confirm whether the proposed solution meets your product requirements.

---

## 1. Platform Overview

### 1.1 Supported Platforms

| Platform | Priority | Min Version | Notes |
|----------|----------|-------------|-------|
| Web | | | |
| iOS | | | |
| macOS | | | |
| Browser Extension | | | |

### 1.2 Platform Feature Matrix

| Feature | Web | iOS | macOS | Extension |
|---------|-----|-----|-------|-----------|
| User Authentication | | | | |
| Offline Support | | | | |
| Push Notifications | | | | |
| Background Sync | | | | |
| [Feature from PRD] | | | | |

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           CLIENTS                                    │
├─────────────┬─────────────┬─────────────┬───────────────────────────┤
│   Web App   │   iOS App   │  macOS App  │    Browser Extension      │
│  (Next.js)  │  (SwiftUI)  │  (SwiftUI)  │    (Plasmo/React)         │
└──────┬──────┴──────┬──────┴──────┬──────┴─────────────┬─────────────┘
       │             │             │                    │
       └─────────────┴──────┬──────┴────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         API LAYER                                    │
├─────────────────────────────────────────────────────────────────────┤
│                    Supabase / Backend Service                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │    Auth     │  │  Database   │  │   Storage   │  │  Realtime  │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     EXTERNAL SERVICES                                │
├─────────────────────────────────────────────────────────────────────┤
│   Email Service  │  Push (APNs/FCM)  │  Analytics  │  Payments      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

| Flow | Description |
|------|-------------|
| Client → API | Authenticated requests via Supabase client SDK |
| API → Client | JSON responses, real-time subscriptions |
| Cross-platform Sync | Via Supabase Realtime / polling |

### 2.3 Offline Strategy

| Platform | Strategy | Sync Behavior |
|----------|----------|---------------|
| Web | | |
| iOS | | |
| macOS | | |
| Extension | | |

---

## 3. Tech Stack

### 3.1 Backend (Shared across all platforms)

| Component | Technology | Rationale |
|-----------|------------|-----------|
| BaaS | Supabase | |
| Database | PostgreSQL | |
| Authentication | Supabase Auth | |
| File Storage | Supabase Storage | |
| Realtime | Supabase Realtime | |
| Edge Functions | Supabase Edge Functions | |

### 3.2 Frontend - Web

| Component | Technology | Version | Rationale |
|-----------|------------|---------|-----------|
| Framework | Next.js | 14.x | |
| Language | TypeScript | 5.x | |
| Styling | Tailwind CSS | 3.x | |
| UI Components | shadcn/ui | latest | |
| State Management | Zustand | 4.x | |
| Forms | React Hook Form + Zod | | |
| Data Fetching | SWR / TanStack Query | | |

### 3.3 Frontend - iOS

| Component | Technology | Version | Rationale |
|-----------|------------|---------|-----------|
| Framework | SwiftUI | | iOS 16+ |
| Language | Swift | 5.9+ | |
| Architecture | MVVM | | @Observable |
| Local Storage | SwiftData | | |
| Networking | async/await | | |
| Keychain | KeychainAccess | | Token storage |

### 3.4 Frontend - macOS

| Component | Technology | Version | Rationale |
|-----------|------------|---------|-----------|
| Framework | SwiftUI + AppKit | | macOS 13+ |
| Language | Swift | 5.9+ | |
| Architecture | MVVM | | @Observable |
| Local Storage | SwiftData | | |
| Menu Bar | NSStatusItem | | AppKit bridge |

### 3.5 Frontend - Browser Extension

| Component | Technology | Version | Rationale |
|-----------|------------|---------|-----------|
| Framework | Plasmo | latest | |
| Language | TypeScript | 5.x | |
| Styling | Tailwind CSS | 3.x | |
| UI Components | shadcn/ui | latest | |
| Storage | chrome.storage | | Manifest V3 |
| Target Browsers | Chrome, Edge, Firefox | | Safari via conversion |

### 3.6 Third-Party Services

| Service | Provider | Purpose | Platforms |
|---------|----------|---------|-----------|
| Email | Resend | Transactional emails | All |
| Analytics | PostHog | User behavior | All |
| Error Monitoring | Sentry | Exception tracking | All |
| Push Notifications | APNs | iOS/macOS push | iOS, macOS |
| Payments | Stripe | Subscriptions | Web, iOS, macOS |

---

## 4. Data Model

### 4.1 Entity Relationship Diagram

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│    users     │       │  [entity_2]  │       │  [entity_3]  │
├──────────────┤       ├──────────────┤       ├──────────────┤
│ id (PK)      │──┐    │ id (PK)      │──┐    │ id (PK)      │
│ email        │  │    │ user_id (FK) │←─┘    │ [fk] (FK)    │←─┘
│ name         │  │    │ ...          │       │ ...          │
│ avatar_url   │  └───→│ created_at   │       │ created_at   │
│ created_at   │       │ updated_at   │       │ updated_at   │
│ updated_at   │       └──────────────┘       └──────────────┘
└──────────────┘
```

### 4.2 Table Definitions

#### users

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | uuid | PK, default gen_random_uuid() | Primary key |
| email | varchar(255) | UNIQUE, NOT NULL | User email |
| name | varchar(100) | NOT NULL | Display name |
| avatar_url | text | NULL | Avatar image URL |
| created_at | timestamptz | default now() | Creation timestamp |
| updated_at | timestamptz | default now() | Last update timestamp |

#### [entity_2]

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | uuid | PK | Primary key |
| user_id | uuid | FK → users.id, ON DELETE CASCADE | Owner |
| | | | |
| created_at | timestamptz | default now() | |
| updated_at | timestamptz | default now() | |

#### [entity_3]

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | uuid | PK | Primary key |
| [parent]_id | uuid | FK, ON DELETE CASCADE | Parent reference |
| | | | |
| created_at | timestamptz | default now() | |
| updated_at | timestamptz | default now() | |

### 4.3 Enums

```sql
-- [Define enums based on PRD]
CREATE TYPE [entity]_status AS ENUM ('value1', 'value2', 'value3');
```

### 4.4 Indexes

```sql
-- Performance indexes based on common queries
CREATE INDEX idx_[table]_user_id ON [table](user_id);
CREATE INDEX idx_[table]_[field] ON [table]([field]);
```

### 4.5 Row Level Security (RLS)

```sql
-- Users can only access their own data
ALTER TABLE [table] ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own data"
  ON [table] FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own data"
  ON [table] FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own data"
  ON [table] FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own data"
  ON [table] FOR DELETE
  USING (auth.uid() = user_id);
```

---

## 5. API Specification

### 5.1 Authentication Endpoints

#### POST /auth/register

**Request**:
```json
{
  "email": "string",
  "password": "string",
  "name": "string"
}
```

**Validation**:
| Field | Rules |
|-------|-------|
| email | Required, valid email, max 255 chars |
| password | Required, min 8 chars, uppercase + lowercase + number |
| name | Required, 1-100 chars |

**Response 201**:
```json
{
  "user": { "id": "uuid", "email": "string", "name": "string" },
  "message": "Verification email sent"
}
```

**Errors**:
| Status | Code | Message |
|--------|------|---------|
| 400 | INVALID_EMAIL | Invalid email format |
| 400 | WEAK_PASSWORD | Password too weak |
| 409 | EMAIL_EXISTS | Email already registered |

---

#### POST /auth/login

**Request**:
```json
{
  "email": "string",
  "password": "string"
}
```

**Response 200**:
```json
{
  "user": { "id": "uuid", "email": "string", "name": "string" },
  "access_token": "string",
  "refresh_token": "string",
  "expires_in": 3600
}
```

**Errors**:
| Status | Code | Message |
|--------|------|---------|
| 401 | INVALID_CREDENTIALS | Invalid email or password |
| 401 | EMAIL_NOT_VERIFIED | Please verify your email |
| 423 | ACCOUNT_LOCKED | Account locked, try again later |

---

#### POST /auth/logout

**Headers**: `Authorization: Bearer {token}`

**Response 200**:
```json
{ "message": "Logged out successfully" }
```

---

#### POST /auth/forgot-password

**Request**:
```json
{ "email": "string" }
```

**Response 200**:
```json
{ "message": "If registered, reset link sent" }
```

---

#### POST /auth/reset-password

**Request**:
```json
{
  "token": "string",
  "password": "string"
}
```

**Response 200**:
```json
{ "message": "Password reset successful" }
```

---

### 5.2 Resource Endpoints

#### GET /[resources]

**Headers**: `Authorization: Bearer {token}`

**Query Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| limit | number | No | Page size (default 50) |
| offset | number | No | Pagination offset |
| [filter] | string | No | Filter field |

**Response 200**:
```json
{
  "[resources]": [ { "id": "uuid", ... } ],
  "total": 100,
  "limit": 50,
  "offset": 0
}
```

---

#### POST /[resources]

**Request**:
```json
{
  "[field]": "value"
}
```

**Validation**:
| Field | Rules |
|-------|-------|
| [field] | [rules] |

**Response 201**:
```json
{
  "[resource]": { "id": "uuid", ... }
}
```

---

#### GET /[resources]/:id

**Response 200**:
```json
{
  "[resource]": { "id": "uuid", ... }
}
```

**Errors**:
| Status | Code | Message |
|--------|------|---------|
| 404 | NOT_FOUND | Resource not found |

---

#### PATCH /[resources]/:id

**Request** (all optional):
```json
{
  "[field]": "new_value"
}
```

**Response 200**:
```json
{
  "[resource]": { ... }
}
```

---

#### DELETE /[resources]/:id

**Response 200**:
```json
{ "message": "Deleted successfully" }
```

---

### 5.3 API Conventions

| Item | Convention |
|------|------------|
| Base URL | `https://[project].supabase.co/rest/v1` |
| Auth | Bearer token in Authorization header |
| Content-Type | application/json |
| Date Format | ISO 8601 |
| ID Format | UUID v4 |
| Error Format | `{ "code": "ERROR_CODE", "message": "..." }` |

---

## 6. Authentication Strategy

### 6.1 Supported Auth Methods

| Method | Web | iOS | macOS | Extension | Required |
|--------|-----|-----|-------|-----------|----------|
| Email + Password | ✅ | ✅ | ✅ | ✅ | Yes |
| Sign in with Apple | ✅ | ✅ | ✅ | ❌ | Yes (iOS) |
| Google OAuth | | | | | Optional |
| Magic Link | | | | | Optional |

### 6.2 Token Strategy

| Token | Storage by Platform | Lifetime |
|-------|---------------------|----------|
| Access Token | Web: Memory, iOS/macOS: Keychain, Ext: chrome.storage | 1 hour |
| Refresh Token | Web: HttpOnly Cookie, iOS/macOS: Keychain, Ext: chrome.storage | 7 days |

### 6.3 Security Measures

| Measure | Implementation |
|---------|----------------|
| Password Hashing | bcrypt |
| Rate Limiting | 5 attempts / 15 min |
| Account Lockout | After 5 failures |
| Token Revocation | On logout, password change |

---

## 7. Platform-Specific Considerations

### 7.1 Web

| Consideration | Approach |
|---------------|----------|
| SEO | SSR for public pages |
| PWA | Optional service worker |
| Browser Support | Chrome, Safari, Firefox, Edge (latest 2 versions) |

### 7.2 iOS

| Consideration | Approach |
|---------------|----------|
| Min iOS Version | iOS 16.0 |
| Sign in with Apple | Required for App Store |
| Push Notifications | APNs |
| App Store Guidelines | Follow latest guidelines |

### 7.3 macOS

| Consideration | Approach |
|---------------|----------|
| Min macOS Version | macOS 13.0 |
| Distribution | App Store + Direct (notarized) |
| Menu Bar | NSStatusItem for quick access |
| Sandbox | Required for App Store |

### 7.4 Browser Extension

| Consideration | Approach |
|---------------|----------|
| Manifest Version | V3 |
| Target Browsers | Chrome, Edge (primary), Firefox (secondary) |
| Permissions | Minimal required permissions |
| Store Compliance | Chrome Web Store policies |

---

## 8. Security Requirements

| Requirement | Implementation |
|-------------|----------------|
| HTTPS | Enforce on all platforms |
| Data Encryption | At rest (Supabase), in transit (TLS) |
| Input Validation | Client + server validation |
| XSS Prevention | Content escaping, CSP |
| CSRF Protection | SameSite cookies |
| Secure Storage | Keychain (iOS/macOS), HttpOnly (Web) |

---

## 9. Performance Requirements

| Metric | Target |
|--------|--------|
| API Response | < 500ms p95 |
| App Launch | < 2s cold start |
| Time to Interactive | < 3s (Web) |

---

## 10. Environment Configuration

### 10.1 Environments

| Environment | Purpose |
|-------------|---------|
| Development | Local development |
| Staging | Pre-production testing |
| Production | Live users |

### 10.2 Environment Variables

```env
# Supabase
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# OAuth (if applicable)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# Services
RESEND_API_KEY=
SENTRY_DSN=
POSTHOG_KEY=

# App
APP_ENV=development|staging|production
```

---

## Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| BaaS | Backend as a Service |
| RLS | Row Level Security |
| APNs | Apple Push Notification service |
| SSR | Server-Side Rendering |

### B. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | | | Initial version |
