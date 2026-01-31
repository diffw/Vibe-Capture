# Vibe Capture (macOS Menu Bar App)

Vibe Capture is a lightweight macOS **menu bar** app that lets you:

1) Trigger a global shortcut  
2) Drag to select an area (overlay)  
3) Review the screenshot + type a prompt  
4) Copy **image then text** to the clipboard for pasting into Cursor  
5) Optionally save the screenshot as a **PNG** to a user-chosen folder

## Requirements

- macOS 13+
- Xcode 15+ recommended

## First-run permissions (expected)

- **Screen Recording**: Required to capture your screen contents.
  - The app will request access on first capture if needed, and can deep-link to System Settings.
- **Save Folder Access (Sandbox)**: If saving is enabled, the app will ask you to pick a folder the first time it saves.
  - The choice is stored as a security-scoped bookmark.

## Default behavior

- Global shortcut: **⌘⇧C**
- Saving: **Enabled** (asks for a folder on first save)
- Clipboard: **clears first**, then writes:
  - Item 1: PNG image
  - Item 2: text prompt (only if non-empty)



