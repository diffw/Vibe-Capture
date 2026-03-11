# Design System | Browser Extension

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
| Framework | React 18 + TypeScript |
| Styling | Tailwind CSS |
| Components | [shadcn/ui](https://ui.shadcn.com) |
| Icons | [Lucide Icons](https://lucide.dev) |
| Bundler | Vite + CRXJS / WXT |
| Target Browsers | Chrome (MV3), Edge, Firefox |

---

## Platform Constraints

### Size Limits

| View | Width | Height | Notes |
|------|-------|--------|-------|
| Popup | 300-400px | 400-600px | Fixed size, avoid long scroll |
| Side Panel | 300-400px | 100vh | Scrollable |
| Options Page | Responsive | - | Standard web layout |
| Content Script | - | - | Embedded in host page |

### Performance Requirements

- Bundle size < 500KB (Popup)
- First render < 200ms
- Avoid large dependencies (moment.js, full lodash, etc.)

### Special Considerations

- Dark mode: Follow browser/system settings
- Fonts: Use system font stack to reduce loading
- Storage: Use `chrome.storage` instead of localStorage

---

## Applying Design Tokens

### Tailwind Config

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          primary: '#3B82F6',
          'primary-hover': '#2563EB',
        },
        // Map from design-tokens.json
      },
      borderRadius: {
        DEFAULT: '8px', // radius.base
      },
    },
  },
}
```

### CSS Variables

```css
/* globals.css */
:root {
  /* From design-tokens.json color.light */
  --bg-primary: #FFFFFF;
  --bg-secondary: #F9FAFB;
  --text-primary: #111827;
  --text-secondary: #6B7280;
  --border: #E5E7EB;
  
  /* Brand colors */
  --brand-primary: #3B82F6;
}

.dark {
  /* From design-tokens.json color.dark */
  --bg-primary: #0F172A;
  --bg-secondary: #1E293B;
  --text-primary: #F9FAFB;
  --text-secondary: #94A3B8;
  --border: #334155;
}
```

---

## Component Usage

### Install from shadcn/ui

```bash
npx shadcn-ui@latest add button
npx shadcn-ui@latest add input
npx shadcn-ui@latest add dropdown-menu
# Add as needed
```

### Common Components

| Use Case | Recommended Component |
|----------|----------------------|
| Primary action | `<Button>` |
| Settings | `<Switch>`, `<Select>` |
| List actions | `<DropdownMenu>` |
| Notifications | `<Toast>` (sonner) |
| Loading state | `<Skeleton>` |

### Component Customization Log

Document any modifications to shadcn defaults:

| Component | Changes |
|-----------|---------|
| Button | [Document changes here if any] |
| - | - |

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1.0 | YYYY-MM-DD | Initial version |
