# MoodBoard Integration Plan for Visual Library

## 📋 Overview
This document outlines the complete plan to integrate MoodBoard canvas functionality into the Visual Library app, allowing users to create visual mood boards with their saved images.

---

## 🎯 Goals
1. **Add a MoodBoard button** in Visual Library toolbar
2. **Open MoodBoard canvas** when button is clicked
3. **Send images from library to canvas** via context menu
4. **Maintain both apps as separate but integrated**

---

## 🚧 Problems Encountered Previously

### Issue 1: Xcode Project File Conflicts
- When copying entire MoodBoard folder, Xcode couldn't properly track files
- Duplicate references to `MoodBoardApp.swift` and `MoodBoardDocument.swift` caused AppDelegate conflicts
- Nested folder structures (`MoodBoard/MoodBoard/`) created confusion

### Issue 2: File Permission Issues
- Trying to launch MoodBoard as separate app hit macOS security restrictions
- `NSWorkspace.shared.open()` required explicit user permissions

### Issue 3: Complexity
- Too many files to manage (2,300+ lines of code)
- Document-based architecture not needed for embedded integration

---

## ✅ New Simplified Approach

### Strategy: **Embed Essential Canvas Functionality Only**

Instead of copying the entire MoodBoard project, we'll:
1. **Copy only core canvas files** (Models, ViewModels, Views)
2. **Skip document architecture** (MoodBoardApp.swift, MoodBoardDocument.swift)
3. **Create simple SwiftUI wrappers** to embed the NSView canvas
4. **Add files directly to ContentView.swift folder** (no subfolder confusion)

---

## 📁 Files to Copy (Minimal Set)

### Essential Files (~1,000 lines total)

#### 1. **Models** (2 files)
```
✓ MoodBoardItem.swift       (201 lines)
  - Represents canvas items with position, size, rotation

✓ CanvasState.swift          (227 lines)
  - Manages canvas state and items collection
```

#### 2. **Views** (2 files)
```
✓ MoodBoardCanvasView.swift  (688 lines)
  - Core canvas NSView with drag/drop, zoom, pan

✓ TransformHandles.swift     (375 lines)
  - Resize/rotate handles for canvas items
```

#### 3. **ViewModels** (1 file)
```
✓ CanvasViewModel.swift      (255 lines)
  - Business logic for canvas operations
```

#### 4. **Utilities** (1 file)
```
✓ GeometryExtensions.swift   (229 lines)
  - Helper functions for geometry calculations
```

#### 5. **Services** (2 files - optional)
```
✓ ImageCache.swift           (262 lines)
  - LRU cache for image management

✓ ExportManager.swift        (331 lines)
  - Export canvas to PNG/JPEG
```

### Files to CREATE (New Integration Code)

#### 6. **SwiftUI Wrappers** (2 new files)
```
✓ MoodBoardCanvasRepresentable.swift  (~20 lines)
  - Wraps NSView canvas for SwiftUI

✓ MoodBoardWindowView.swift           (~60 lines)
  - SwiftUI window containing the canvas
```

**Total: ~2,300 lines to copy + ~80 lines new code = ~2,400 lines**

---

## 🔧 Step-by-Step Implementation Plan

### **Phase 1: Prepare Files** (10 minutes)

#### Step 1.1: Create Organized Folder Structure
```bash
VisualInspiration/
├── MoodBoard/                    # New folder
│   ├── Models/
│   ├── ViewModels/
│   ├── Views/
│   ├── Services/
│   └── Utilities/
```

#### Step 1.2: Copy Files (Command Line)
```bash
# Copy Models
cp "/path/to/MoodBoard/Models/MoodBoardItem.swift" "VisualInspiration/MoodBoard/Models/"
cp "/path/to/MoodBoard/Models/CanvasState.swift" "VisualInspiration/MoodBoard/Models/"

# Copy Views
cp "/path/to/MoodBoard/Views/MoodBoardCanvasView.swift" "VisualInspiration/MoodBoard/Views/"
cp "/path/to/MoodBoard/Views/TransformHandles.swift" "VisualInspiration/MoodBoard/Views/"

# Copy ViewModels
cp "/path/to/MoodBoard/ViewModels/CanvasViewModel.swift" "VisualInspiration/MoodBoard/ViewModels/"

# Copy Utilities
cp "/path/to/MoodBoard/Utilities/GeometryExtensions.swift" "VisualInspiration/MoodBoard/Utilities/"

# Copy Services (optional)
cp "/path/to/MoodBoard/Services/ImageCache.swift" "VisualInspiration/MoodBoard/Services/"
cp "/path/to/MoodBoard/Services/ExportManager.swift" "VisualInspiration/MoodBoard/Services/"
```

#### Step 1.3: Remove Conflicting Files
```bash
# Delete app-specific files we DON'T need
rm "VisualInspiration/MoodBoard/MoodBoardApp.swift"
rm "VisualInspiration/MoodBoard/MoodBoardDocument.swift"
rm "VisualInspiration/MoodBoard/Info.plist"
rm -rf "VisualInspiration/MoodBoard/Assets.xcassets"
rm -rf "VisualInspiration/MoodBoard/Resources"
```

---

### **Phase 2: Register Files with Xcode Project** (Automated - 2 minutes)

**100% automated via Claude Code - no Xcode GUI needed!**

Claude will programmatically edit the `project.pbxproj` file to:
1. Generate unique file reference IDs for each MoodBoard file
2. Add files to the project's file tree structure
3. Register files with the VisualInspiration build target
4. Organize files into proper groups (Models, Views, ViewModels, etc.)

**What happens:**
```
Claude edits: VisualInspiration.xcodeproj/project.pbxproj
→ Adds ~50 lines of file references
→ Links all MoodBoard files to build system
→ Xcode sees files automatically on next build
```

**You don't do anything - Claude handles this completely!**

---

### **Phase 3: Create SwiftUI Wrappers** (Automated - 1 minute)

**100% automated via Claude Code!**

Claude will create these wrapper files using the Write tool:

#### File 1: `MoodBoardCanvasRepresentable.swift`
```swift
import SwiftUI
import AppKit

struct MoodBoardCanvasRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: CanvasViewModel

    func makeNSView(context: Context) -> MoodBoardCanvasView {
        let canvasView = MoodBoardCanvasView(viewModel: viewModel)
        return canvasView
    }

    func updateNSView(_ nsView: MoodBoardCanvasView, context: Context) {
        nsView.viewModel = viewModel
    }
}
```

#### File 2: `MoodBoardWindowView.swift`
```swift
import SwiftUI
import AppKit

struct MoodBoardWindowView: View {
    @StateObject private var viewModel: CanvasViewModel
    @Environment(\.dismiss) private var dismiss

    init() {
        let canvasState = CanvasState()
        _viewModel = StateObject(wrappedValue: CanvasViewModel(
            canvasState: canvasState,
            undoManager: nil
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Text("\(viewModel.canvasState.items.count) items")
                    .foregroundColor(.secondary)

                Spacer()

                Button("Export") { exportCanvas() }
                    .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Canvas
            MoodBoardCanvasRepresentable(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func exportCanvas() {
        let exportManager = ExportManager(canvasState: viewModel.canvasState)
        exportManager.exportWithSavePanel { success in
            print("Export \(success ? "succeeded" : "failed")")
        }
    }
}
```

---

### **Phase 4: Integrate into Visual Library UI** (Automated - 1 minute)

**100% automated via Claude Code!**

Claude will use the Edit tool to update ContentView.swift:

#### Step 4.1: Add State Variables to ContentView
```swift
// In ContentView.swift, around line 56:
@State private var isHoveringMoodBoard = false
@State private var showingMoodBoard = false
```

#### Step 4.2: Add MoodBoard Button to Toolbar
```swift
// In ContentView.swift, around line 260 (after time display):

Text("•")
    .foregroundColor(.gray)

// MoodBoard button
Button(action: {
    showingMoodBoard = true
}) {
    Image(systemName: "square.grid.2x2")
        .font(.system(size: 13, weight: .medium))
}
.buttonStyle(.plain)
.foregroundColor(isHoveringMoodBoard ? textHoverColor : textColor)
.animation(.easeInOut(duration: 0.6), value: colorScheme)
.onHover { hovering in
    isHoveringMoodBoard = hovering
    isHoveringBottomNav = hovering
    if hovering {
        NSCursor.pointingHand.push()
    } else {
        NSCursor.pop()
    }
}
.help("Open MoodBoard")

Text("•")
    .foregroundColor(.gray)
```

#### Step 4.3: Add Sheet Modifier
```swift
// In ContentView.swift, around line 454 (after .preferredColorScheme):

.sheet(isPresented: $showingMoodBoard) {
    MoodBoardWindowView()
        .frame(minWidth: 1200, minHeight: 800)
}
```

---

### **Phase 5: Build and Test** (Automated - 2 minutes)

**Claude handles the build via command line!**

Claude will run:
```bash
# Clean build
xcodebuild clean -scheme VisualInspiration

# Build the app
xcodebuild -scheme VisualInspiration -configuration Debug build

# Launch the app
open "/Users/vaibhav/Library/Developer/Xcode/DerivedData/VisualInspiration-*/Build/Products/Debug/VisualInspiration.app"
```

**Your job:** Test the running app!

**Test checklist:**
- [ ] App launches without crashing
- [ ] MoodBoard button appears in toolbar (between time and fullscreen)
- [ ] Clicking button opens canvas window
- [ ] Can drag image files onto canvas
- [ ] Can resize/rotate items on canvas
- [ ] Export button works

---

## 🎨 Future Enhancements (Phase 6+)

### Enhancement 1: Context Menu Integration
Add "Send to MoodBoard" to image right-click menu:
```swift
.contextMenu {
    Button("Send to MoodBoard") {
        // Add selected image to canvas
    }
}
```

### Enhancement 2: Multi-Image Support
Allow selecting multiple images and sending to canvas at once

### Enhancement 3: Persistence
Save/load MoodBoard canvases:
```
~/Documents/VisualInspiration/MoodBoards/
    - canvas1.json
    - canvas2.json
```

### Enhancement 4: Recent MoodBoards
Show list of recent canvases to reopen

---

## ⚠️ Potential Issues & Solutions

### Issue 1: Build Errors - Missing Files
**Symptom:** "Cannot find type 'MoodBoardItem'"
**Solution:** Ensure all files are added to Xcode target

### Issue 2: CGPoint Codable Conflicts
**Symptom:** "Extension of 'CGPoint' declares conformance to 'Codable' which conflicts..."
**Solution:** Wrap CGPoint/CGSize extensions in conditional compilation:
```swift
#if !canImport(Darwin) || swift(<5.9)
extension CGPoint: Codable { ... }
#endif
```

### Issue 3: Canvas Not Rendering
**Symptom:** Blank canvas window
**Solution:** Check MoodBoardCanvasView's `wantsLayer = true` and ensure `setupLayers()` is called

### Issue 4: Memory Issues with Large Images
**Symptom:** App crashes with many images
**Solution:** Use ImageCache and limit thumbnail size to 2048x2048

---

## 📊 Success Criteria

### Minimum Viable Product (MVP)
- [x] Clean Visual Library builds successfully
- [ ] MoodBoard button added to toolbar
- [ ] Clicking button opens canvas window
- [ ] Can drag images onto canvas
- [ ] Can arrange/resize/rotate images
- [ ] Canvas persists during session

### Nice to Have
- [ ] Export canvas to PNG
- [ ] Save/load canvas state
- [ ] Send images from library via context menu
- [ ] Recent canvases list

---

## 🕐 Time Estimates

| Phase | Task | Who | Time |
|-------|------|-----|------|
| 1 | Prepare & Copy Files | Claude | 2 min |
| 2 | Register Files with Xcode | Claude | 2 min |
| 3 | Create SwiftUI Wrappers | Claude | 1 min |
| 4 | Integrate UI | Claude | 1 min |
| 5 | Build & Test | Claude + You | 2 min |
| **Total** | **MVP (Automated!)** | **~8 minutes** |
| 6+ | Future Enhancements | Both | 1-2 hours |

**You only:** Test the running app to verify everything works!

---

## 📝 Notes

### Why This Approach Works
1. **Minimal files** - Only copy what's needed
2. **No document architecture** - Simpler integration
3. **SwiftUI-first** - Works naturally with Visual Library
4. **Isolated code** - MoodBoard stays in its own folder

### Lessons Learned
1. **Don't copy entire projects** - Too much baggage
2. **Automate everything** - No Xcode GUI needed, edit `project.pbxproj` directly
3. **Test incrementally** - Build after each phase
4. **Keep it simple** - Start with MVP, add features later
5. **Let Claude handle it** - User only tests the result

---

## 🚀 Ready to Start?

When you're ready to integrate, **just tell Claude to begin!**

Claude will execute all 5 phases automatically:
1. ✅ Phase 1: Copy essential MoodBoard files (Claude does this)
2. ✅ Phase 2: Edit `project.pbxproj` to register files (Claude does this)
3. ✅ Phase 3: Create SwiftUI wrappers (Claude does this)
4. ✅ Phase 4: Update ContentView.swift (Claude does this)
5. ✅ Phase 5: Build via xcodebuild (Claude does this)

**You only:** Test the running app when Claude launches it!

**Current Status:** Visual Library is clean and ready for integration!

---

## 💡 Why This Approach Works

**Zero Xcode GUI involvement:**
- No screenshots needed
- No "Add Files" dialogs
- No confusion about which files to select
- Claude edits the project file programmatically
- Exactly like how we work with Visual Library now!

**Fast & reliable:**
- ~8 minutes total (vs. 40 minutes with manual Xcode steps)
- No room for user error
- Repeatable if anything goes wrong
- Claude can undo/redo easily

---

*Last Updated: 2025-11-03*
*Created by: Claude Code*
