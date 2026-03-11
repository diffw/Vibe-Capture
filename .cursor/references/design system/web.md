# Design System | Web

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
| Framework | Next.js 14+ / React 18 + TypeScript |
| Styling | Tailwind CSS |
| Components | [shadcn/ui](https://ui.shadcn.com) |
| Icons | [Lucide Icons](https://lucide.dev) |
| Animation | Framer Motion (optional) |
| Deployment | Vercel / Cloudflare Pages |

---

## Responsive Breakpoints

| Name | Width | Typical Devices |
|------|-------|-----------------|
| `sm` | ≥ 640px | Large phone landscape |
| `md` | ≥ 768px | Tablet portrait |
| `lg` | ≥ 1024px | Tablet landscape, small laptop |
| `xl` | ≥ 1280px | Desktop monitor |
| `2xl` | ≥ 1536px | Large monitor |

### Layout Strategy

```
Mobile (< 768px):
- Single column layout
- Bottom nav or hamburger menu
- Full-width cards

Tablet (768px - 1023px):
- 2-column grid
- Side nav or top nav

Desktop (≥ 1024px):
- Multi-column layout
- Expanded side nav
- Max content width: 1200px
```

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
          'primary-active': '#1D4ED8',
          secondary: '#6366F1',
        },
        success: '#22C55E',
        warning: '#F59E0B',
        error: '#EF4444',
      },
      borderRadius: {
        DEFAULT: '8px',
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'ui-monospace', 'monospace'],
      },
    },
  },
}
```

### CSS Variables

```css
/* globals.css */
@layer base {
  :root {
    /* Background */
    --background: 0 0% 100%;
    --foreground: 222 47% 11%;
    
    /* Card */
    --card: 0 0% 100%;
    --card-foreground: 222 47% 11%;
    
    /* Primary - from design-tokens.json */
    --primary: 217 91% 60%;
    --primary-foreground: 0 0% 100%;
    
    /* Border/Input */
    --border: 220 13% 91%;
    --input: 220 13% 91%;
    --ring: 217 91% 60%;
    
    /* Radius */
    --radius: 0.5rem;
  }

  .dark {
    --background: 222 47% 11%;
    --foreground: 210 40% 98%;
    --card: 217 33% 17%;
    --card-foreground: 210 40% 98%;
    --border: 217 33% 17%;
    --input: 217 33% 17%;
  }
}
```

---

## Component Usage

### Recommended Installs

```bash
# Basic components
npx shadcn-ui@latest add button input label
npx shadcn-ui@latest add card dialog sheet

# Forms
npx shadcn-ui@latest add form select checkbox radio-group

# Feedback
npx shadcn-ui@latest add toast alert skeleton

# Navigation
npx shadcn-ui@latest add navigation-menu tabs
```

### Component Customization Log

| Component | Changes |
|-----------|---------|
| Button | [Document changes here if any] |
| Card | [Document changes here if any] |
| - | - |

---

## Project-Specific Guidelines

<!-- Add based on project needs, e.g.: -->

### [Example: Children's Product Considerations]

- Minimum tap target: 48×48px
- Body font size: 18px (larger than default)
- Feedback animations: More obvious and playful
- Error tolerance: Allow undo on mistakes

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1.0 | YYYY-MM-DD | Initial version |
