# iOS Platform Reference

## Standard Layouts

### Tab Bar Navigation

```
┌─────────────────────────────────────┐
│ ←  Title                      Edit  │  ← Navigation Bar
├─────────────────────────────────────┤
│                                     │
│                                     │
│           Content Area              │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  🏠     📋     ➕     🔔     👤    │  ← Tab Bar
│ Home   List   Add   Alerts  Profile │
└─────────────────────────────────────┘
```

Use when: App has 3-5 primary sections of equal importance.

### Navigation Controller (Push/Pop)

```
┌─────────────────────────────────────┐
│ ← Back    Title              Action │  ← Navigation Bar
├─────────────────────────────────────┤
│                                     │
│           Content Area              │
│                                     │
│   ┌─────────────────────────────┐   │
│   │      List Item 1        >   │   │  ← Tap to push
│   │      List Item 2        >   │   │
│   │      List Item 3        >   │   │
│   └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

Use when: Hierarchical content navigation.

### Modal Sheet

```
┌─────────────────────────────────────┐
│                                     │
│   (Background content dimmed)       │
│                                     │
├─────────────────────────────────────┤
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │  ← Drag indicator
│ Cancel      Title             Done  │
├─────────────────────────────────────┤
│                                     │
│           Sheet Content             │
│                                     │
└─────────────────────────────────────┘
```

Use when: Creating new content, editing, or focused tasks.

### Full Screen Modal

```
┌─────────────────────────────────────┐
│ Cancel      Title             Done  │  ← Navigation Bar
├─────────────────────────────────────┤
│                                     │
│                                     │
│           Full Screen               │
│              Content                │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

Use when: Complex forms, media capture, immersive experiences.

## Common Components

### Search Bar

```
┌─────────────────────────────────────┐
│  🔍  Search...                      │
└─────────────────────────────────────┘
```

### Action Sheet

```
┌─────────────────────────────────────┐
│                                     │
│         (Content behind)            │
│                                     │
├─────────────────────────────────────┤
│          Action Title               │
│   ┌─────────────────────────────┐   │
│   │        Option 1             │   │
│   │        Option 2             │   │
│   │        Option 3 (destructive)   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │          Cancel             │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### Context Menu (Long Press)

```
         ┌───────────────────┐
         │  Preview          │
         │                   │
         ├───────────────────┤
         │ 📋 Copy           │
         │ 📤 Share          │
         │ ✏️ Edit           │
         │ 🗑 Delete         │
         └───────────────────┘
```

## Standard Gestures

| Gesture | Function |
|---------|----------|
| Tap | Select, activate |
| Long press | Context menu |
| Swipe left | Delete, secondary actions |
| Swipe right | Primary action (e.g., mark as read) |
| Pull down | Refresh |
| Edge swipe left | Back navigation |
| Pinch | Zoom |

## Settings Bundle

```
Settings App
└── [Your App]
    ├── Account
    ├── Notifications
    ├── Appearance
    └── About
```

Or in-app Settings:

```
┌─────────────────────────────────────┐
│ ← Back      Settings                │
├─────────────────────────────────────┤
│                                     │
│ ACCOUNT                             │
│ ┌─────────────────────────────────┐ │
│ │ Profile                      >  │ │
│ │ Subscription                 >  │ │
│ └─────────────────────────────────┘ │
│                                     │
│ PREFERENCES                         │
│ ┌─────────────────────────────────┐ │
│ │ Notifications                >  │ │
│ │ Appearance                   >  │ │
│ │ Language                     >  │ │
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

## View States

| State | Implementation |
|-------|----------------|
| Empty | Centered illustration + message + action button |
| Loading | Activity indicator or skeleton |
| Error | Error message + retry button |
| No network | Offline indicator + cached content |
