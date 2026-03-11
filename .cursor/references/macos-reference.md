# macOS Platform Reference

## Standard Layouts

### Three-Column Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ◀ ▶  [Navigation]      [Search Bar]                [Toolbar Buttons]    │  ← Toolbar
├───────────────┬─────────────────────────┬───────────────────────────────┤
│               │                         │                               │
│   Sidebar     │      Content List       │       Detail / Inspector      │
│   200-250px   │       300-400px         │        350-450px              │
│               │                         │                               │
└───────────────┴─────────────────────────┴───────────────────────────────┘
```

Use when: Users need to browse items and view details simultaneously. (Mail, Finder, Notes)

### Two-Column Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ◀ ▶  [Navigation]      [Search Bar]                [Toolbar Buttons]    │
├───────────────┬─────────────────────────────────────────────────────────┤
│               │                                                         │
│   Sidebar     │                    Content Area                         │
│   200-250px   │                                                         │
│               │                                                         │
└───────────────┴─────────────────────────────────────────────────────────┘
```

Use when: Content doesn't require persistent detail view. (System Settings, Music)

### Single Canvas Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ◀ ▶  [Navigation]      [Title]                     [Toolbar Buttons]    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         Full Canvas / Editor                            │
│                                                                         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

Use when: Content is the primary focus with no list/sidebar needed. (Preview, TextEdit)

---

## Toolbar (NSToolbar)

### Standard Toolbar

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ◀ ▶  [Toggle Sidebar]  [Search]        [Share] [Customize...] [+]      │
│       ← Navigation      ← Flexible Space →               Fixed Items → │
└─────────────────────────────────────────────────────────────────────────┘
```

### Toolbar Behavior

| Behavior | Standard |
|----------|----------|
| Style | Unified (title integrated into toolbar) preferred for modern apps |
| Customization | Allow user to customize toolbar items via right-click > "Customize Toolbar..." |
| Display modes | Icon only (default), Icon and Text, Text only |
| Overflow | Items that don't fit collapse into >> menu automatically |
| Title visibility | `.inlineLarge` for prominent title, `.automatic` for standard |

### SwiftUI Toolbar

```swift
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) { ... }
    ToolbarItem(placement: .navigation) { ... }
}
.toolbarRole(.editor)          // editor-style toolbar
.navigationTitle("Title")
.navigationSubtitle("Subtitle")
```

---

## Inspector / Detail Panel

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ◀ ▶  [Navigation]      [Search]                     [ℹ️ Inspector]     │
├───────────────┬──────────────────────────────┬──────────────────────────┤
│               │                              │                          │
│   Sidebar     │       Content Area           │   Inspector Panel        │
│               │                              │   250-300px              │
│               │                              │   ─────────────          │
│               │                              │   Properties             │
│               │                              │   Metadata               │
│               │                              │   Actions                │
└───────────────┴──────────────────────────────┴──────────────────────────┘
```

Use when: Contextual properties or metadata for selected item. Toggle visibility with toolbar button.

```swift
.inspector(isPresented: $showInspector) {
    InspectorView(item: selectedItem)
        .inspectorColumnWidth(min: 200, ideal: 260, max: 350)
}
```

---

## Menu Bar Component

```
                    System Menu Bar
┌────────────────────────────────────────────────────────────┐
│  Apple  [App Menus...]        📶  🔋  [App Icon]  🔍  Time │
└────────────────────────────────────────────────────────────┘
                                    ↑
                              Click to expand
```

### Menu Bar Popover (MenuBarExtra)

```
                    ┌─────────────────────┐
                    │   Status/Summary    │
                    ├─────────────────────┤
                    │   Quick Action 1    │
                    │   Quick Action 2    │
                    │   Quick Action 3    │
                    ├─────────────────────┤
                    │   Open Main Window  │
                    │   Settings...       │
                    │   Quit              │
                    └─────────────────────┘
```

```swift
MenuBarExtra("App Name", systemImage: "icon.name") {
    MenuBarView()
}
.menuBarExtraStyle(.window)   // popover with custom UI
// or
.menuBarExtraStyle(.menu)     // standard menu items
```

---

## Settings Window

### macOS 14+ (Settings scene)

```swift
Settings {
    TabView {
        GeneralSettingsView()
            .tabItem { Label("General", systemImage: "gear") }
        AccountSettingsView()
            .tabItem { Label("Account", systemImage: "person") }
    }
}
```

### Settings Layout

```
┌──────────────────────────────────────────────────┐
│   [General]  [Account]  [Feature]  [Shortcuts]   │  ← Toolbar Tabs
├──────────────────────────────────────────────────┤
│                                                  │
│   Form {                                         │
│       Section("Appearance") {                    │
│           Picker / Toggle / Slider               │
│       }                                          │
│       Section("Behavior") {                      │
│           Picker / Toggle                        │
│       }                                          │
│   }                                              │
│                                                  │
└──────────────────────────────────────────────────┘
```

| Standard | Notes |
|----------|-------|
| Cmd+, | Always opens Settings |
| Tab style | Toolbar tabs for 3+ categories, single pane for fewer |
| Form layout | Use `Form` with `Section` grouping |
| Window size | Fixed per tab, no manual resize |

---

## Window Management

| Behavior | Standard |
|----------|----------|
| Close window (Cmd+W) | Hide window, don't quit app (for menu bar apps) |
| Close window (Cmd+W) | Quit app if not a menu bar / background app |
| Window size | Remember user's size and position across launches |
| Full screen | Support native full screen mode (Ctrl+Cmd+F) |
| Split View | Support split view with other apps |
| Stage Manager | Works automatically; no special handling needed |
| Multiple windows | Support if document-based; use `Window` or `WindowGroup` |
| Dark mode | Follow system appearance or manual toggle |
| Minimum size | Set `.frame(minWidth:minHeight:)` to prevent content clipping |

### SwiftUI Window Configuration

```swift
WindowGroup {
    ContentView()
}
.defaultSize(width: 900, height: 600)
.windowResizability(.contentSize)    // or .contentMinSize, .automatic

Window("Auxiliary", id: "aux") {
    AuxiliaryView()
}
.windowStyle(.hiddenTitleBar)
.defaultPosition(.center)
```

---

## Drag and Drop

| Pattern | Usage |
|---------|-------|
| Draggable source | `.draggable(item)` on any view |
| Drop target | `.dropDestination(for: Type.self) { items, location in }` |
| Spring-loading | Folders/containers open after hover-hold during drag |
| Visual feedback | Highlight drop target; show + badge for copy, arrow for move |
| Pasteboard types | Use `Transferable` protocol for custom types |

---

## Context Menus (Right-Click)

```
         ┌───────────────────┐
         │ 📋 Copy            │
         │ 📤 Share       ▶  │  ← Submenu indicator
         │ ✏️ Rename          │
         │ ─────────────────  │  ← Divider
         │ 🗑 Move to Trash   │  ← Destructive (red text)
         └───────────────────┘
```

```swift
.contextMenu {
    Button("Copy") { ... }
    ShareLink(item: selectedItem)
    Divider()
    Button("Move to Trash", role: .destructive) { ... }
}
```

---

## System Standard Menus

| Menu | Items | Notes |
|------|-------|-------|
| [App Name] | About, Settings (Cmd+,), Services, Hide, Quit (Cmd+Q) | System standard |
| File | New (Cmd+N), Open, Close (Cmd+W), Save (Cmd+S), Export | As needed |
| Edit | Undo, Redo, Cut, Copy, Paste, Select All, Find (Cmd+F) | System standard |
| View | Show/Hide Sidebar (Cmd+Ctrl+S), Show/Hide Toolbar, Show/Hide Inspector | As needed |
| Window | Minimize, Zoom, Full Screen, Window List | System standard |
| Help | Search, [App] Help, Keyboard Shortcuts | System standard |

---

## System Standard Shortcuts

| Shortcut | Function |
|----------|----------|
| Cmd+Q | Quit |
| Cmd+W | Close Window |
| Cmd+, | Settings |
| Cmd+H | Hide App |
| Cmd+M | Minimize |
| Cmd+N | New |
| Cmd+S | Save |
| Cmd+Z | Undo |
| Cmd+Shift+Z | Redo |
| Cmd+C/V/X | Copy/Paste/Cut |
| Cmd+A | Select All |
| Cmd+F | Find |
| Ctrl+Cmd+F | Toggle Full Screen |
| Cmd+Ctrl+S | Toggle Sidebar |
| Cmd+Option+I | Toggle Inspector (convention) |

---

## Sandbox and Hardened Runtime

| Topic | Standard |
|-------|----------|
| Hardened Runtime | Required for notarization and App Store |
| App Sandbox | Required for Mac App Store distribution |
| File access | Use `NSOpenPanel` / `NSSavePanel` for user-selected files |
| Bookmarks | Use security-scoped bookmarks to persist file access across launches |
| Network | Enable `com.apple.security.network.client` for outbound requests |
| Camera | `com.apple.security.device.camera` + Info.plist usage description |
| Microphone | `com.apple.security.device.audio-input` + Info.plist usage description |
| Location | `com.apple.security.personal-information.location` + Info.plist |
| Apple Events | `com.apple.security.automation.apple-events` for scripting other apps |
| Temporary exception | Avoid; use only during migration from non-sandboxed |

---

## Document-Based App

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ◀ ▶  [Document Title ▼]    [Search]                 [Toolbar Buttons]   │
│        ↑ Click for rename, move, tags                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         Document Content                                │
│                                                                         │
│                         [Edited indicator: dot in close button]          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

| Behavior | Standard |
|----------|----------|
| Auto-save | Documents auto-save; no manual save prompt |
| Versions | Support Versions (File > Revert To > Browse All Versions) |
| Title bar | Show document name; proxy icon for drag |
| Unsaved changes | Dot in close button red circle |
| Multiple windows | Each document in its own window |
| Recent documents | File > Open Recent, populated automatically |

---

## Notification Center Integration

| Pattern | Usage |
|---------|-------|
| Alert style | Banners (disappear) or Alerts (stay until dismissed); user controls in System Settings |
| Request permission | `UNUserNotificationCenter.current().requestAuthorization(options:)` |
| Content | Title + subtitle + body; optional image attachment |
| Actions | Add actionable buttons via `UNNotificationCategory` |
| Grouping | Group related notifications by thread identifier |
| Badge | Dock icon badge with `NSApp.dockTile.badgeLabel` |

---

## Accessibility

| Requirement | Implementation |
|-------------|---------------|
| VoiceOver | All interactive elements must have `.accessibilityLabel` |
| Keyboard navigation | Full Tab key navigation; support arrow keys in lists/tables |
| Focus ring | System default focus ring; never hide or override |
| Rotor | Use `.accessibilityRotor` for custom navigation groups |
| Headings | Mark section headers with `.accessibilityAddTraits(.isHeader)` |
| Images | Decorative: `.accessibilityHidden(true)`; Meaningful: add `.accessibilityLabel` |
| Dynamic Type | Respect user's text size preferences; test with large sizes |
| Reduce Motion | Check `AccessibilitySettings.isReduceMotionEnabled`; provide alternatives |
| High contrast | Test with Increase Contrast enabled in System Settings |

---

## View States

| State | Implementation |
|-------|----------------|
| Empty | Centered illustration + message + action button |
| Loading | `ProgressView()` or skeleton placeholder |
| Error | Error message + retry button |
| No network | Offline indicator + cached content if available |
| No permission | Explain what's needed + button to System Settings |
| No selection | Placeholder in detail panel: "Select an item" |
