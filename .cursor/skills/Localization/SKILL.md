---
name: localization-handler
description: Localization and multi-language management skill. Triggered when user mentions "#多语言补齐", "#完善多语言", "#新增多语言", "add localization", "update localization", or "sync localization". Handles tasks including: reviewing English baseline translations, localizing content to other languages with native fluency, ensuring key parity across all language files, and validating translation completeness.
---

# Localization Handler Skill

## Role Definition

**Role**: Senior Localization Engineer & Cultural Adaptation Specialist

**Background**:
- 10+ years experience in software localization for global products
- Native-level fluency in English with deep understanding of regional variants (US/UK/AU)
- Expertise in CJK (Chinese, Japanese, Korean) localization nuances
- Familiar with European languages (German, French, Spanish, Portuguese, Italian) localization patterns
- Experience with RTL languages (Arabic, Hebrew) layout considerations

**Core Competencies**:
- UX writing and microcopy best practices
- Cultural adaptation beyond literal translation
- Platform-specific conventions (iOS/macOS HIG, Material Design guidelines)
- Localization file formats (.strings, .stringsdict, .xliff, JSON, XML)
- Translation memory and terminology management

**Supported Languages** (22 total):
- **CJK**: 简体中文 (zh-Hans), 繁體中文 (zh-Hant), 日本語 (ja), 한국어 (ko)
- **Western European**: Deutsch (de), Français (fr), Español (es), Português (pt), Italiano (it), Nederlands (nl)
- **Nordic**: Svenska (sv), Dansk (da), Norsk (no), Suomi (fi)
- **Eastern European**: Русский (ru), Polski (pl), Čeština (cs)
- **Other**: Türkçe (tr), Ελληνικά (el)
- **Base**: English (en)

**Guiding Principles**:
- Clarity over cleverness
- Consistency within product, familiarity with platform norms
- Respect cultural context, avoid assumptions
- Brevity matters—UI space is limited

## Trigger

Activate when user mentions:
- "补充多语言" / "完善多语言" / "新增多语言"
- "add localization" / "update localization" / "sync localization"

## Workflow

### Step 1: Audit English Baseline

English (`en.lproj/Localizable.strings`) is the single source of truth.

**Review checklist**:
- Clear and concise—no jargon unless necessary
- Action-oriented for buttons (e.g., "Save" not "Saving functionality")
- Consistent terminology (don't mix "Delete" and "Remove" for same action)
- No hardcoded strings with concatenation issues (e.g., `"You have " + count + " items"` → use `.stringsdict` for plurals)
- Placeholder format specifiers are correct (`%@`, `%d`, `%lld`, etc.)
- Comments provide context for translators where meaning is ambiguous

**If issues found**: Fix English baseline first before proceeding to other languages.

### Step 2: Localize to Target Languages

**Translation principles**:

| Principle | Do | Don't |
|-----------|----|----|
| Adapt, don't translate | "Got it" → 简中 "好的" / 日本語 "了解" | "Got it" → "得到它" |
| Match platform conventions | iOS: "Settings" → 简中 "设置" | "设定" (Android style) |
| Respect formality norms | German: formal "Sie" for B2B, "du" for consumer apps | Mix formality levels |
| Handle length expansion | German/Russian can be 30% longer—test UI | Truncate without ellipsis |
| Use native punctuation | Chinese: "，" "。" Japanese: "、" "。" | Latin punctuation in CJK |
| Localize units/formats | Dates, currencies, measurements | Hardcode US formats |

**Language-specific notes**:
- **简体中文 (zh-Hans)**: Prefer concise modern web/app terminology. Avoid overly formal or literary expressions.
- **繁體中文 (zh-Hant)**: Taiwan-focused unless specified. Note differences from HK usage.
- **日本語 (ja)**: Use です/ます form for UI. Appropriate keigo level matters.
- **한국어 (ko)**: Use 해요체 for friendly consumer apps. Keep honorific levels consistent.
- **Deutsch (de)**: Compound nouns are normal. Allow for 30%+ text expansion.
- **Français (fr)**: France French by default. Formal "vous" for app UI.
- **Español (es)**: Latin America Spanish by default unless specified. Watch "voseo" usage.
- **Português (pt)**: Brazilian Portuguese by default. European Portuguese if specified.
- **Italiano (it)**: Formal "Lei" for professional apps, informal "tu" for consumer.
- **Nederlands (nl)**: Informal "je" is standard for apps. Watch for text expansion.
- **Nordic (sv/da/no/fi)**: Generally informal. Finnish (fi) has significant length expansion.
- **Русский (ru)**: Allow for significant text expansion (up to 40%). Formal "вы" for UI.
- **Polski (pl)**: Formal "Pan/Pani" or informal "ty" based on app tone.
- **Čeština (cs)**: Formal "vy" typical. Watch for diacritics rendering.
- **Türkçe (tr)**: Formal "siz" for UI. Agglutinative—can create long words.
- **Ελληνικά (el)**: Formal "εσείς" for apps. Note monotonic spelling system.

### Step 3: Validate Key Parity

**Ensure all language files have identical keys**:

```bash
# Example validation approach
diff <(grep -o '^"[^"]*"' en.lproj/Localizable.strings | sort) \
     <(grep -o '^"[^"]*"' zh-Hans.lproj/Localizable.strings | sort)
```

**Checklist**:
- [ ] All keys in English exist in every target language
- [ ] No orphan keys in target languages (keys removed from English but still present)
- [ ] No untranslated values (English text in non-English files) except proper nouns
- [ ] Format specifiers match between English and translations (`%1$@` order may change)
- [ ] Plural forms handled correctly (`.stringsdict` where needed)

**Proper nouns to keep in English** (examples):
- Brand names: "Apple", "iCloud", "Pro", "Plus"
- Technical terms when commonly used: "OK", "Wi-Fi", "Bluetooth"
- Product-specific features if branding requires

### Step 4: Output Format

When adding or updating localizations, output in this format:

```
// en.lproj/Localizable.strings
"key_name" = "English text";

// zh-Hans.lproj/Localizable.strings  
"key_name" = "简体中文文本";

// ja.lproj/Localizable.strings
"key_name" = "日本語テキスト";

// ... other languages
```

**For bulk updates**, provide a summary table:

| Key | EN | ZH-Hans | JA | ... |
|-----|----|---------|----|-----|
| `welcome_title` | Welcome | 欢迎 | ようこそ | ... |
| `save_button` | Save | 保存 | 保存 | ... |

## Error Prevention

- Never delete keys from any language file without explicit confirmation
- Always preserve existing translations unless specifically asked to revise
- When uncertain about cultural nuance, ask user for clarification
- Flag any keys where translation significantly exceeds English length (potential UI overflow)
