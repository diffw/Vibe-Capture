# Web Platform Reference

## Standard Layouts

### Sidebar + Content (Dashboard Style)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  [Logo]                    [Search]              [Notifications] [User]  │  ← Header
├────────────┬─────────────────────────────────────────────────────────────┤
│            │                                                             │
│  Sidebar   │                     Content Area                            │
│            │                                                             │
│  - Nav 1   │   ┌─────────────────────────────────────────────────────┐   │
│  - Nav 2   │   │                                                     │   │
│  - Nav 3   │   │                    Main Content                     │   │
│            │   │                                                     │   │
│  ────────  │   └─────────────────────────────────────────────────────┘   │
│  - Settings│                                                             │
│            │                                                             │
│  200-280px │                       Flexible                              │
└────────────┴─────────────────────────────────────────────────────────────┘
```

Use when: Complex apps with multiple sections (SaaS, admin panels).

### Top Nav + Content (Marketing/Simple Apps)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  [Logo]    [Nav 1]  [Nav 2]  [Nav 3]           [Search]  [CTA]  [User]   │  ← Header
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│                                                                          │
│                           Content Area                                   │
│                                                                          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

Use when: Simpler apps, content-focused sites.

### Three-Column (Email/Chat Style)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  [Logo]                    [Search]                              [User]  │
├────────────┬────────────────────────┬────────────────────────────────────┤
│            │                        │                                    │
│  Folders   │       List             │           Detail                   │
│            │                        │                                    │
│  - Inbox   │  ┌──────────────────┐  │   From: xxx                        │
│  - Sent    │  │ Item 1           │  │   Subject: xxx                     │
│  - Drafts  │  │ Item 2 ← selected│  │                                    │
│            │  │ Item 3           │  │   Content...                       │
│            │  └──────────────────┘  │                                    │
│            │                        │                                    │
│  200px     │       300px            │         Flexible                   │
└────────────┴────────────────────────┴────────────────────────────────────┘
```

Use when: List-detail pattern with categorization.

## Responsive Breakpoints

| Breakpoint | Width | Layout Adaptation |
|------------|-------|-------------------|
| Mobile | < 768px | Single column, hamburger menu |
| Tablet | 768-1024px | Collapsible sidebar |
| Desktop | > 1024px | Full layout |

### Mobile Adaptation

```
┌─────────────────────┐
│ ☰  [Logo]    [User] │  ← Hamburger menu
├─────────────────────┤
│                     │
│   Content Area      │
│   (Full width)      │
│                     │
├─────────────────────┤
│ 🏠   📋   ➕   👤   │  ← Optional bottom nav
└─────────────────────┘
```

## Common Components

### Modal Dialog

```
┌─────────────────────────────────────┐
│                                     │
│     (Dimmed background)             │
│                                     │
│   ┌─────────────────────────────┐   │
│   │  Title                   ✕  │   │
│   ├─────────────────────────────┤   │
│   │                             │   │
│   │      Modal Content          │   │
│   │                             │   │
│   ├─────────────────────────────┤   │
│   │      [Cancel]  [Confirm]    │   │
│   └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Slide-over Panel

```
┌──────────────────────────────────────────────────────────────┬───────────┐
│                                                              │           │
│                     Main Content                             │  Panel    │
│                     (Dimmed)                                 │  Content  │
│                                                              │           │
│                                                              │  Title    │
│                                                              │  ───────  │
│                                                              │  ...      │
│                                                              │           │
└──────────────────────────────────────────────────────────────┴───────────┘
```

### Toast/Notification

```
                    ┌─────────────────────────┐
                    │ ✓ Action completed      │
                    └─────────────────────────┘
```

### Dropdown Menu

```
┌─────────────┐
│ User Name ▼ │
├─────────────┤
│ Profile     │
│ Settings    │
│ ─────────── │
│ Logout      │
└─────────────┘
```

## Keyboard Shortcuts (Web Apps)

| Shortcut | Function |
|----------|----------|
| / | Focus search |
| ? | Show keyboard shortcuts |
| Esc | Close modal/cancel |
| Ctrl/Cmd + S | Save |
| Ctrl/Cmd + K | Command palette |
| G then H | Go to Home (Gmail style) |

## View States

| State | Implementation |
|-------|----------------|
| Empty | Illustration + message + CTA |
| Loading | Skeleton loader or spinner |
| Error | Error message + retry |
| Offline | Banner + cached content |
| Partial load | Progressive loading |
