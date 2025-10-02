# Visual Inspiration (v1.0.0)

A minimalist, local-first macOS visual inspiration manager built with SwiftUI.

## Status

- Phase 1: Done
- Phase 2: Done
- Phase 3: Preview + UX polish done, performance in progress, packaging pending

## Project Structure

```
VisualInspiration/
├── VisualInspirationApp.swift      # App entry + window configuration
├── ContentView.swift               # Main UI: grid, bottom bar, preview, copy
├── Models/                         # (reserved)
├── Views/                          # (reserved)
├── Utilities/                      # (reserved)
├── Resources/                      # (reserved)
├── Assets.xcassets/                # App icons and colors
├── fonts/                          # Lato font family
├── VisualInspiration.entitlements  # App sandbox permissions
└── Preview Content/                # SwiftUI preview assets
```

## Features

- Window & Theme
  - Hidden title bar with full-size content (no reserved top space)
  - Light/Dark mode with persistence
- Image Grid
  - Drag & drop from Finder/Browser
  - Masonry layout with hover effects
  - Asynchronous, downsampled thumbnails (no full-size loads in grid)
  - In-memory thumbnail cache (NSCache)
- Preview
  - Single-click to open embedded preview
  - Click outside or press ESC to close
  - Left/Right chevrons at image edge and arrow-key navigation
  - Double-click, Cmd+C/Ctrl+C, or context menu to Copy Image
  - “Copied!” toast with haptic feedback
- File Storage
  - Images stored locally at `~/Documents/VisualInspiration/`
  - Supported image types: jpg, jpeg, png, gif, bmp, tiff, heic, webp
- Management
  - Hover delete button removes file from disk and grid
  - Image count in bottom bar; live clock; fullscreen toggle; theme toggle

## Phase Breakdown

### Phase 1 (Complete)
- Clean Swift project, App/Window setup, bottom bar, theme system, fonts

### Phase 2 (Complete)
- Image grid, drag & drop, local storage, basic management and UI polish

### Phase 3 (Partially Complete)
- Preview UX: complete (embedded, navigation, copy, toast)
- Haptics: complete
- Performance: in progress
  - Async downsampled thumbnails + memory cache (done)
  - Optional disk cache with LRU + batching (planned)
- Packaging: pending

## Shortcuts & Gestures

- Open preview: single-click on a thumbnail
- Close preview: click outside, or ESC
- Next/Prev: → / ← keys or chevron buttons
- Copy image: double-click in preview, Cmd+C/Ctrl+C, or right-click > Copy Image
- Toggle theme: bottom bar sun/moon
- Toggle fullscreen: bottom bar button

## Running the Project

1. Open `VisualInspiration.xcodeproj` in Xcode
2. Select the `VisualInspiration` target
3. Build and run (⌘R)

First run creates `~/Documents/VisualInspiration/`. Drag images into the window to add them to your library.

## Packaging (local use / share with friends)

We include a simple script to build a Release `.app` and a `.zip` suitable for personal use and sharing.

1) Run the packaging script

```bash
chmod +x scripts/package.sh
./scripts/package.sh
```

Outputs:
- `dist/VisualInspiration.app`
- `dist/VisualInspiration.zip`

Notes:
- This is a locally signed build (no Developer ID required). It runs on your Mac and can be shared; Gatekeeper may show a warning on other Macs unless you right‑click → Open.
- App icon warnings printed by Xcode are safe to ignore for local builds; add missing icon sizes later.

2) Optional: Use Developer ID and export

If you have a paid Apple Developer account and want a Developer ID‑signed build (still outside the Mac App Store):

```bash
DEV_TEAM=YOURTEAMID \
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/package.sh
```

The script will archive and export using `ExportOptions.plist` when both `DEV_TEAM` and `SIGNING_IDENTITY` are provided.

3) Notarization (later, optional for public distribution)

For distribution to a wider audience without warnings on macOS 10.15+:
- Notarize with `xcrun notarytool submit <.zip or .app> --keychain-profile <profile> --wait`
- Staple the ticket: `xcrun stapler staple <.app>`

We can add a one‑command notarization step later if needed.

## Roadmap

- Optional disk thumbnail cache (LRU, 256 MB cap, configurable)
- Batching/prefetch for thumbnails
- Video support (thumbs via AVFoundation, QuickLook preview)
- Packaging & distribution settings
