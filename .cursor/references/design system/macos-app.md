# Design System | macOS App

> Project: [Project Name]  
> Version: v1.0  
> Last Updated: 2026-03-11

---

## Prerequisites

Before development, read:
1. `.cursor/references/design-principle.md` — Design philosophy
2. `.vibe-doc/design-token.json` — Design variables

---

## Tech Stack

| Item | Choice |
|------|--------|
| UI Framework | SwiftUI (primary) + AppKit (when SwiftUI insufficient) |
| Minimum Support | macOS 14.0 (Sonoma) |
| Icons | SF Symbols (preferred) |
| Architecture | MVVM |
| Package Manager | Swift Package Manager |
| Window Model | Multi-window via `WindowGroup` / `Window` / `MenuBarExtra` |

---

## Design Guidelines Reference

| Platform | Official Guide |
|----------|----------------|
| macOS | [Human Interface Guidelines - macOS](https://developer.apple.com/design/human-interface-guidelines/macos) |

> Follow Apple HIG first, then layer brand customizations on top.

---

## Applying Design Tokens

### Color Definitions

**Option A: Asset Catalog (Recommended)**

Create Color Sets in `Assets.xcassets` with Any Appearance and Dark Appearance.

**Option B: Code Definition**

```swift
import SwiftUI

extension Color {
    // MARK: - Brand
    static let brandPrimary = Color(hex: "3B82F6")
    static let brandPrimaryHover = Color(hex: "2563EB")
    static let brandSecondary = Color(hex: "6366F1")
    
    // MARK: - Semantic
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    
    // MARK: - Adaptive (Light/Dark)
    static let bgPrimary = Color("BgPrimary")
    static let bgSecondary = Color("BgSecondary")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
}
```

### Border Radius

```swift
enum Radius {
    static let none: CGFloat = 0
    static let sm: CGFloat = 4
    static let base: CGFloat = 8
    static let lg: CGFloat = 12
    static let full: CGFloat = 9999
}
```

### Typography

```swift
extension Font {
    // Use system fonts (recommended for macOS)
    static let bodyPrimary = Font.system(.body)
    static let titlePrimary = Font.system(.title2, design: .default, weight: .semibold)
    static let caption = Font.system(.caption)
    static let monoBody = Font.system(.body, design: .monospaced)
}
```

---

## Icon Usage (SF Symbols)

```swift
Image(systemName: "magnifyingglass")
    .font(.system(size: 16, weight: .medium))
    .foregroundColor(.brandPrimary)

// Multicolor
Image(systemName: "heart.circle.fill")
    .symbolRenderingMode(.palette)
    .foregroundStyle(.white, .red)
```

### Lucide to SF Symbols Mapping

| Function | Lucide (Web) | SF Symbols (macOS) |
|----------|--------------|-------------------|
| Search | `search` | `magnifyingglass` |
| Settings | `settings` | `gearshape` |
| User | `user` | `person` |
| Home | `home` | `house` |
| Add | `plus` | `plus` |
| Delete | `trash` | `trash` |
| Edit | `pencil` | `pencil` |
| Close | `x` | `xmark` |
| Menu | `menu` | `line.3.horizontal` |
| More | `more-horizontal` | `ellipsis` |
| Sidebar | `sidebar` | `sidebar.left` |
| Inspector | `panel-right` | `sidebar.right` |

---

## macOS-Specific Component Specifications

### Button Styles

```swift
// Primary action button
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.brandPrimary)
            .foregroundColor(.white)
            .cornerRadius(Radius.base)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Toolbar button (borderless, icon-only)
Button(action: { }) {
    Image(systemName: "plus")
}
.buttonStyle(.borderless)

// Accessory bar button (small, rounded)
Button("Filter") { }
    .buttonStyle(.accessoryBar)
    .controlSize(.small)
```

### Sidebar

```swift
NavigationSplitView {
    List(selection: $selection) {
        Section("Library") {
            Label("All Items", systemImage: "tray.full")
            Label("Favorites", systemImage: "star")
        }
        Section("Collections") {
            ForEach(collections) { collection in
                Label(collection.name, systemImage: "folder")
            }
        }
    }
    .listStyle(.sidebar)
    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
} detail: {
    DetailView(selection: selection)
}
.navigationSplitViewStyle(.balanced)
```

### NavigationSplitView (Three-Column)

```swift
NavigationSplitView {
    SidebarView()
} content: {
    ContentListView()
        .navigationSplitViewColumnWidth(min: 250, ideal: 350)
} detail: {
    DetailView()
}
```

### Hover States

macOS requires hover feedback on interactive elements. iOS does not have hover.

```swift
struct HoverableRow: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack { ... }
            .padding(8)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            .cornerRadius(Radius.sm)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
```

### Context Menu (Right-Click)

```swift
ContentView()
    .contextMenu {
        Button("Copy") { ... }
        Button("Duplicate") { ... }
        Divider()
        Button("Move to Trash", role: .destructive) { ... }
    }
```

### Table (macOS-Only)

```swift
Table(items, selection: $selection, sortOrder: $sortOrder) {
    TableColumn("Name", value: \.name)
    TableColumn("Date", value: \.date) { item in
        Text(item.date, style: .date)
    }
    TableColumn("Size", value: \.size) { item in
        Text(item.formattedSize)
    }
}
.contextMenu(forSelectionType: Item.ID.self) { ids in
    Button("Delete", role: .destructive) { ... }
}
```

### Settings Scene

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        
        Settings {
            TabView {
                GeneralSettings()
                    .tabItem { Label("General", systemImage: "gear") }
                AppearanceSettings()
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                AccountSettings()
                    .tabItem { Label("Account", systemImage: "person") }
            }
            .frame(width: 450)
        }
    }
}
```

### MenuBarExtra

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        
        MenuBarExtra("Status", systemImage: "app.badge") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

### Window Management

```swift
WindowGroup {
    ContentView()
}
.defaultSize(width: 900, height: 600)
.windowResizability(.contentMinSize)

// Auxiliary window
Window("Quick Capture", id: "capture") {
    QuickCaptureView()
}
.windowStyle(.hiddenTitleBar)
.defaultPosition(.center)
.keyboardShortcut("n", modifiers: [.command, .shift])
```

---

## macOS vs iOS Behavioral Differences

| Scenario | iOS | macOS |
|----------|-----|-------|
| Navigation | `TabView` / `NavigationStack` | Sidebar + `NavigationSplitView` |
| Min tap/click target | 44x44pt | Can be smaller (28pt min recommended) |
| Hover state | None | Required on all interactive elements |
| Context menu | Long press | Right click |
| Settings | In-app settings screen or Settings.app | `Settings` scene (Cmd+,) |
| Toolbar | Navigation bar | `NSToolbar` (customizable) |
| Multi-window | Limited (iPadOS) | Full multi-window support |
| Text selection | Tap-and-hold | Click-and-drag (native) |
| Scrollbar | Hidden, pull-to-reveal | Visible on hover or always (user pref) |
| Keyboard shortcuts | Limited, mostly system | Extensive, custom shortcuts expected |
| Drag and drop | Available | First-class interaction model |
| Menu bar | N/A | Required: app menus + optional MenuBarExtra |

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1.0 | 2026-03-11 | Initial version for macOS-specific Design System |
