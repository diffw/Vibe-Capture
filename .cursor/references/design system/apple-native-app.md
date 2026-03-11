# Design System | Apple Native (iOS / macOS)

> Project: [Project Name]  
> Version: v1.0  
> Last Updated: YYYY-MM-DD

---

## Prerequisites

Before development, read:
1. `.cursor/references/design-principle.md` — Design philosophy
2. `.vibe-doc/design-token.json` — Design variables

---

## Tech Stack

| Item | Choice |
|------|--------|
| UI Framework | SwiftUI |
| Minimum Support | iOS 17.0 / macOS 14.0 |
| Icons | SF Symbols (preferred) |
| Architecture | MVVM / TCA |
| Package Manager | Swift Package Manager |

---

## Design Guidelines Reference

| Platform | Official Guide |
|----------|----------------|
| iOS | [Human Interface Guidelines - iOS](https://developer.apple.com/design/human-interface-guidelines/ios) |
| macOS | [Human Interface Guidelines - macOS](https://developer.apple.com/design/human-interface-guidelines/macos) |

> Follow Apple HIG first, then layer brand customizations on top.

---

## Applying Design Tokens

### Color Definitions

**Option A: Asset Catalog (Recommended)**

Create Color Sets in `Assets.xcassets` with Any Appearance and Dark Appearance.

**Option B: Code Definition**

```swift
// Color+Brand.swift
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
    static let bgPrimary = Color("BgPrimary")       // From Asset Catalog
    static let bgSecondary = Color("BgSecondary")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
}

// Hex Initializer Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### Border Radius

```swift
// Radius.swift
import SwiftUI

enum Radius {
    static let none: CGFloat = 0
    static let sm: CGFloat = 4
    static let base: CGFloat = 8
    static let lg: CGFloat = 12
    static let full: CGFloat = 9999
}

// Usage
RoundedRectangle(cornerRadius: Radius.base)
```

### Typography

```swift
// Typography.swift
import SwiftUI

extension Font {
    static let brandSans = Font.custom("Inter", size: 16)
    static let brandMono = Font.custom("JetBrains Mono", size: 14)
    
    // Or use system fonts (recommended, no bundling needed)
    static let bodyPrimary = Font.system(.body)
    static let titlePrimary = Font.system(.title2, design: .default, weight: .semibold)
}
```

---

## Icon Usage

### SF Symbols (Preferred)

```swift
Image(systemName: "magnifyingglass")
    .font(.system(size: 20, weight: .medium))
    .foregroundColor(.brandPrimary)

// Multicolor
Image(systemName: "heart.circle.fill")
    .symbolRenderingMode(.palette)
    .foregroundStyle(.white, .red)
```

### Finding SF Symbols

1. Download [SF Symbols App](https://developer.apple.com/sf-symbols/)
2. Search for icon names
3. Check available variants (filled, outlined, etc.)

### Lucide to SF Symbols Mapping

| Function | Lucide (Web) | SF Symbols (Apple) |
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

---

## Component Specifications

### Button Styles

```swift
// ButtonStyles.swift
import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.brandPrimary)
            .foregroundColor(.white)
            .cornerRadius(Radius.base)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.brandPrimary.opacity(0.1))
            .foregroundColor(.brandPrimary)
            .cornerRadius(Radius.base)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

// Usage
Button("Submit") { }
    .buttonStyle(PrimaryButtonStyle())
```

### Card Style

```swift
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(Color.bgSecondary)
            .cornerRadius(Radius.lg)
    }
}
```

---

## Platform Differences

### iOS vs macOS

| Scenario | iOS | macOS |
|----------|-----|-------|
| Navigation | TabView / NavigationStack | Sidebar + NavigationSplitView |
| Min tap target | 44×44pt | Can be smaller |
| Hover state | None | Required |
| Context menu | Long press | Right click |

```swift
// Conditional compilation
#if os(iOS)
TabView { ... }
#elseif os(macOS)
NavigationSplitView { ... }
#endif
```

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1.0 | YYYY-MM-DD | Initial version |
