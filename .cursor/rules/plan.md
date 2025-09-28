# Swift Visual Inspiration Manager Development Prompt

You are an expert Swift developer tasked with creating a minimal, native macOS visual inspiration organizer. This app should heavily reference the architectural patterns from the open-source Freewrite app (https://github.com/farzaa/freewrite) while implementing image management functionality instead of text editing.

## Project Overview

**Goal:** Create "Freewrite for Images" - a distraction-free visual inspiration manager that stores images locally with the same minimalist philosophy as Freewrite.

**Core Principle:** Maximum simplicity, native performance, local-first storage, clean interface with essential controls only.

## Key Freewrite Components to Reference

### 1. AppDelegate Setup
- Study Freewrite's app initialization and lifecycle management
- Copy their window restoration and state persistence patterns
- Implement similar app menu structure and keyboard shortcuts
- Use their approach to handling app termination and background states

### 2. Window Configuration
- Replicate Freewrite's window styling (borderless, custom title bar handling)
- Copy their window sizing, positioning, and restoration logic
- Implement similar fullscreen and minimize behavior
- Use their approach to window delegate methods

### 3. Bottom Bar Component Structure
- Exactly mirror Freewrite's bottom control bar layout and spacing
- Copy their typography choices (monospaced fonts, sizing)
- Implement similar button styling and hover states
- Use their color schemes and material backgrounds
- Include the live clock display with same formatting

### 4. Theme Management System
- Study how Freewrite handles light/dark mode switching
- Copy their theme persistence and system preference integration
- Implement similar color scheme definitions
- Use their approach to updating UI elements when theme changes

### 5. File Handling Patterns
- Reference their local file storage architecture
- Copy their folder creation and file management patterns
- Study their data persistence approaches
- Implement similar file system monitoring if applicable

## Technical Requirements

### Swift/SwiftUI Implementation
```swift
// Main app structure should follow Freewrite's patterns
@main
struct VisualInspirationApp: App {
    // Copy Freewrite's app setup patterns
}

// Window and view structure
struct ContentView: View {
    // Replace text editing with image grid
    // Keep same layout philosophy: main content area + bottom bar
}

// Bottom bar exactly like Freewrite's
struct BottomControlBar: View {
    // Mirror Freewrite's control layout:
    // [Count] [Spacer] [Controls] [Spacer] [Time]
}
```

### Core Functionality to Implement

#### Image Management (Replace Text Editing)
- **Drag & Drop**: Images from Finder/browser into main content area
- **Grid Display**: Clean masonry/grid layout for image thumbnails
- **Preview**: Click to view full-size (use QuickLook integration)
- **Local Storage**: Save to `~/Pictures/VisualInspiration/` folder

#### UI Components to Keep from Freewrite
- Bottom bar with exact spacing and typography
- Window management and controls
- Theme switching button and logic
- Time display with live updates
- Haptic feedback on interactions (if Freewrite has this)

#### Data Models
```swift
// Simple Core Data model for image metadata
@Model
class ImageAsset {
    var id: UUID
    var filename: String
    var filePath: URL
    var dateAdded: Date
    // Keep it minimal like Freewrite keeps text simple
}
```

## Design Guidelines

### Visual Design
- **Background**: Clean white/dark background like Freewrite
- **Spacing**: Use Freewrite's padding and margin values
- **Typography**: Copy their font choices and sizes exactly
- **Colors**: Use their color palette and semantic colors
- **Interactions**: Mirror their button styles and hover effects

### User Experience
- **Startup**: App opens to clean interface, ready for drag & drop
- **No Menus**: Keep interface minimal like Freewrite (bottom bar only)
- **Keyboard Focus**: Images should be the main focus (like text in Freewrite)
- **Persistence**: Remember window state and loaded images between sessions

## Implementation Priority

### Phase 1 (Week 1-2)
1. Fork/reference Freewrite codebase for patterns
2. Create clean Swift project with Freewrite's app structure
3. Implement window setup exactly like Freewrite
4. Create bottom bar component matching their design

### Phase 2 (Week 3-4)
5. Replace text editing area with image grid view
6. Implement drag & drop functionality
7. Add local file storage using Freewrite's file handling patterns
8. Implement theme switching using their system

### Phase 3 (Week 5-6)
9. Add image preview functionality
10. Polish interactions and add haptic feedback
11. Test and refine performance
12. Package app following Freewrite's build configuration

## Success Criteria

The finished app should:
- Feel exactly like Freewrite but for images instead of text
- Have the same minimalist, distraction-free interface
- Use identical bottom bar layout and controls
- Follow same window behavior and theming
- Maintain native macOS integration and performance
- Store everything locally with no cloud dependency

## Code References

When implementing, directly study these Freewrite files (if accessible):
- `AppDelegate.swift` - for app lifecycle patterns
- `WindowController.swift` - for window management
- `BottomBar.swift` or similar - for control bar implementation  
- `ThemeManager.swift` - for theme handling
- `DocumentManager.swift` - for file handling patterns

Your goal is to create an app that looks and feels like it was made by the same developer as Freewrite, just for visual inspiration instead of writing.