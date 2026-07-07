# Stashbar — Accessibility Compliance

Stashbar is designed to be accessible to all users. The following accessibility features are implemented:

## VoiceOver Support

- All interactive elements in the popover are exposed to VoiceOver with descriptive labels.
- File items in the grid, list, and hierarchy views announce their name, modification date, size, and selection state.
- Buttons (add folder, remove folder, refresh, sort, view mode) have accessibility labels and hints.

## Keyboard Navigation

- **Arrow keys:** Navigate between files in the grid and list views.
- **Space:** Open Quick Look preview for the selected file.
- **Command+A:** Select all files in the current folder.
- **Command+C / Command+X / Command+V:** Copy, cut, paste files.
- **Command+Delete:** Move selected files to trash.
- **Tab / Shift+Tab:** Navigate between focusable controls in Settings.

## Dynamic Type & Contrast

- The app respects the user's system accent color.
- Text uses standard macOS label colors that adapt to Light/Dark Mode automatically.
- Selection highlights use the system accent color with sufficient contrast (alpha 0.30).

## Accessibility Testing Checklist

- [x] VoiceOver reads all controls correctly in the popover.
- [x] VoiceOver reads all controls correctly in Settings.
- [x] Keyboard navigation works in all three view modes (icon, list, hierarchy).
- [x] Quick Look is accessible via keyboard (Space).
- [x] File operations (copy, cut, paste, trash) are accessible via keyboard.
- [x] Color contrast meets WCAG AA guidelines for UI elements.

---

*Last updated: 2026-05-11*
