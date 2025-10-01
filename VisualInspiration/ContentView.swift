//
//  ContentView.swift
//  VisualInspiration
//
//  Created by Visual Library on 2/14/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
#if canImport(QuickLookUI)
import QuickLookUI
#endif

struct ImageAsset: Identifiable {
    let id: UUID
    let filename: String
    let filePath: URL
    let dateAdded: Date
    let thumbnail: NSImage?
    
    init(filePath: URL) {
        self.id = UUID()
        self.filePath = filePath
        self.filename = filePath.lastPathComponent
        self.dateAdded = Date()
        // Avoid loading full-size image synchronously; thumbnails are loaded lazily via cache
        self.thumbnail = nil
    }
}

struct ContentView: View {
    @State private var isFullscreen = false
    @State private var colorScheme: ColorScheme = .light
    @State private var isHoveringBottomNav = false
    @State private var bottomNavOpacity: Double = 1.0
    @State private var isHoveringThemeToggle = false
    @State private var isHoveringFullscreen = false
    @State private var images: [ImageAsset] = []
    @State private var isHoveringImageGrid = false
    @State private var hoveredImageId: UUID? = nil
    @State private var draggedImage: ImageAsset? = nil
    @State private var currentTime = Date()
    @State private var isReloading = false
    @State private var quickLookSelectedIndex: Int? = nil
    @State private var isPresentingEmbeddedPreview = false
    static let imageCopiedNotification = Notification.Name("VI.ImageCopied")
    
    // File manager and directory setup
    private let fileManager = FileManager.default
    
    // Cached images directory
    private let imagesDirectory: URL = {
        // Use Documents directory
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("VisualInspiration")
        
        print("🔍 DEBUG: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] = \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])")
        print("🔍 DEBUG: Final imagesDirectory = \(directory)")
        
        // Create VisualInspiration directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Successfully created VisualInspiration directory at: \(directory.path)")
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        
        print("Using images directory: \(directory.path)")
        return directory
    }()
    
    // Initialize with saved theme preference if available
    init() {
        // Load saved color scheme preference
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        _colorScheme = State(initialValue: savedScheme == "light" ? .light : .dark)
    }
    
    var body: some View {
        let textColor = colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
        let textHoverColor = colorScheme == .light ? Color.black : Color.white
        let navHeight: CGFloat = 52
        
        HStack(spacing: 0) {
            // Main content area - will be replaced with image grid
            ZStack {
                Color(colorScheme == .light ? .white : .black)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: colorScheme)
                
                // Image grid area (replacing text editor) - Masonry Layout
                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        MasonryGridView(
                            images: images,
                            colorScheme: colorScheme,
                            hoveredImageId: $hoveredImageId,
                            availableWidth: geo.size.width - 60, // account for 30px padding on each side
                            onPreviewRequested: { index in
                                presentQuickLook(at: index)
                            },
                            onDeleteRequested: { image in
                                deleteImage(image)
                            }
                        )
                        .padding(30)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, navHeight)
                .background(Color(colorScheme == .light ? .white : .black))
                .animation(.easeInOut(duration: 0.6), value: colorScheme)
                .opacity(isReloading ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isReloading)
                .onDrop(of: [.image], isTargeted: nil) { providers in
                    handleImageDrop(providers: providers)
                }
                .overlay(
                    Group {
                        if isPresentingEmbeddedPreview, let idx = quickLookSelectedIndex, images.indices.contains(idx) {
                            EmbeddedPreviewOverlay(
                                urls: images.map { $0.filePath },
                                selectedIndex: idx,
                                onClose: {
                                    isPresentingEmbeddedPreview = false
                                }
                            )
                            .transition(.opacity)
                        }
                        // Toast for "Copied!"
                        CopiedToast()
                    }
                )
                .overlay(
                    // Empty state overlay
                    Group {
                        if images.isEmpty {
                            VStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 64))
                                    .foregroundColor(colorScheme == .light ? .gray.opacity(0.3) : .gray.opacity(0.5))
                                    .animation(.easeInOut(duration: 0.6), value: colorScheme)
                                
                                Text("Drag images here")
                                    .font(.system(size: 18))
                                    .foregroundColor(colorScheme == .light ? .gray.opacity(0.5) : .gray.opacity(0.6))
                                    .animation(.easeInOut(duration: 0.3), value: colorScheme)
                                    .padding(.top, 16)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                )
                
                // Bottom control bar
                VStack {
                    Spacer()
                    HStack {
                        // Left side controls (image count)
                        HStack(spacing: 8) {
                            Text("\(images.count) images")
                                .font(.system(size: 13))
                                .foregroundColor(textColor)
                                .animation(.easeInOut(duration: 0.6), value: colorScheme)
                            
            Button(action: {
                // Simple screen flash effect
                withAnimation(.easeInOut(duration: 0.1)) {
                    isReloading = true
                }
                loadExistingImages()
                
                // Stop flash after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isReloading = false
                    }
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textColor)
            }
            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                        
                        Spacer()
                        
                        // Right side controls
                        HStack(spacing: 8) {
                            Button(isFullscreen ? "Minimize" : "Fullscreen") {
                                if let window = NSApplication.shared.windows.first {
                                    window.toggleFullScreen(nil)
                                }
                                performHaptic()
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringFullscreen ? textHoverColor : textColor)
                            .animation(.easeInOut(duration: 0.6), value: colorScheme)
                            .onHover { hovering in
                                isHoveringFullscreen = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            // Theme toggle button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    colorScheme = colorScheme == .light ? .dark : .light
                                }
                                // Save preference
                                UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
                                performHaptic()
                            }) {
                                Image(systemName: colorScheme == .light ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(isHoveringThemeToggle ? textHoverColor : textColor)
                                    .animation(.easeInOut(duration: 0.2), value: colorScheme)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringThemeToggle = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            // Live timer
                            Text(currentTime, style: .time)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(textColor)
                                .animation(.easeInOut(duration: 0.6), value: colorScheme)
                        }
                        .padding(8)
                        .background(Color.clear)
                        .compositingGroup()
                        .shadow(color: (colorScheme == .light ? Color.white.opacity(0.35) : Color.black.opacity(0.35)), radius: 2, x: 0, y: 1)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                    }
                    .padding(.horizontal, 30)
                    // .padding(.top, 2)
                    .padding(.bottom, 10) 
                    .background(Color.clear)
                    .animation(.easeInOut(duration: 0.6), value: colorScheme)
                    .opacity(1.2)
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .preferredColorScheme(colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
        .onAppear {
            loadExistingImages()
            
            // Start live timer
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    currentTime = Date()
                }
            }

            // Spacebar Quick Look
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49 { // spacebar
                    if let index = quickLookIndexForCurrentHoverOrFirst() {
                        presentQuickLook(at: index)
                        return nil
                    }
                } else if event.keyCode == 53 { // escape
                    if isPresentingEmbeddedPreview {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isPresentingEmbeddedPreview = false
                        }
                        return nil
                    }
                // Copy image: Command+C or Control+C when preview is open
                } else if isPresentingEmbeddedPreview {
                    let isCommandC = event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "c"
                    let isControlC = event.modifierFlags.contains(.control) && event.charactersIgnoringModifiers?.lowercased() == "c"
                    if isCommandC || isControlC {
                        copyCurrentPreviewToPasteboard()
                        return nil
                    }
                }
                return event
            }
        }
    }
    
    // MARK: - Image Management Functions
    
    private func loadExistingImages() {
        print("Looking for images in: \(imagesDirectory.path)")
        print("Directory exists: \(fileManager.fileExists(atPath: imagesDirectory.path))")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            print("All files in directory: \(fileURLs.map { $0.lastPathComponent })")
            
            let imageFiles = fileURLs.filter { url in
                let supportedTypes = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
                let isImage = supportedTypes.contains(url.pathExtension.lowercased())
                print("File: \(url.lastPathComponent), Extension: \(url.pathExtension.lowercased()), IsImage: \(isImage)")
                return isImage
            }
            
            print("Found \(imageFiles.count) image files")
            
            images = imageFiles.map { ImageAsset(filePath: $0) }
                .sorted { $0.dateAdded > $1.dateAdded }
            
            print("Successfully loaded \(images.count) images")
            
        } catch {
            print("Error loading directory contents: \(error)")
        }
    }
    
    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        print("🖱️ Drag & Drop triggered with \(providers.count) providers")
        var hasHandledDrop = false
        
        for (index, provider) in providers.enumerated() {
            print("📦 Provider \(index): \(provider)")
            print("📦 Has image type: \(provider.hasItemConformingToTypeIdentifier(UTType.image.identifier))")
            
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                print("✅ Found image provider, loading item...")
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                    print("📥 Load item callback - Item: \(String(describing: item)), Error: \(String(describing: error))")
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            print("🔗 Item is URL: \(url)")
                            self.saveImage(from: url)
                        } else if let data = item as? Data {
                            print("📊 Item is Data: \(data.count) bytes")
                            self.saveImageData(data)
                        } else {
                            print("❌ Unknown item type: \(type(of: item))")
                        }
                    }
                }
                hasHandledDrop = true
            } else {
                print("❌ Provider doesn't conform to image type")
            }
        }
        
        print("🎯 Drag & Drop result: \(hasHandledDrop)")
        return hasHandledDrop
    }
    
    private func saveImage(from url: URL) {
        let filename = url.lastPathComponent
        let destinationURL = imagesDirectory.appendingPathComponent(filename)
        
        print("💾 Saving image from: \(url)")
        print("💾 Destination: \(destinationURL)")
        print("💾 Directory exists: \(fileManager.fileExists(atPath: imagesDirectory.path))")
        
        do {
            // Copy file to our directory
            try fileManager.copyItem(at: url, to: destinationURL)
            
            // Add to images array
            let newImage = ImageAsset(filePath: destinationURL)
            images.insert(newImage, at: 0)
            
            print("✅ Successfully saved image: \(filename)")
            print("📊 Images array now has \(images.count) items")
            performHaptic(.alignment)
        } catch {
            print("❌ Error saving image: \(error)")
        }
    }
    
    private func saveImageData(_ data: Data) {
        let filename = "image_\(UUID().uuidString).png"
        let destinationURL = imagesDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: destinationURL)
            
            let newImage = ImageAsset(filePath: destinationURL)
            images.insert(newImage, at: 0)
            
            print("Successfully saved image data: \(filename)")
            performHaptic(.alignment)
        } catch {
            print("Error saving image data: \(error)")
        }
    }

    private func deleteImage(_ image: ImageAsset) {
        do {
            try fileManager.removeItem(at: image.filePath)
            images.removeAll { $0.id == image.id }
            performHaptic(.levelChange)
            print("🗑️ Deleted image: \(image.filename)")
        } catch {
            print("❌ Failed to delete image: \(error)")
        }
    }
}

// MARK: - Copied Toast
struct CopiedToast: View {
    @State private var isVisible = false

    var body: some View {
        VStack {
            Spacer()
            if isVisible {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("Copied!")
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .shadow(radius: 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isVisible)
        .onReceive(NotificationCenter.default.publisher(for: ContentView.imageCopiedNotification)) { _ in
            isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation {
                    isVisible = false
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Image Thumbnail View Component
struct ImageThumbnailView: View {
    let image: ImageAsset
    let colorScheme: ColorScheme
    @State private var isHovered = false
    
    var body: some View {
        Group {
            if let thumbnail = image.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Masonry Grid View Component
struct MasonryGridView: View {
    let images: [ImageAsset]
    let colorScheme: ColorScheme
    @Binding var hoveredImageId: UUID?
    let availableWidth: CGFloat
    let onPreviewRequested: (Int) -> Void
    let onDeleteRequested: (ImageAsset) -> Void
    
    var body: some View {
        let columnCount = getColumnCount(for: availableWidth)
        let columnWidth = (availableWidth - CGFloat(columnCount - 1) * 14) / CGFloat(columnCount)
        
        HStack(alignment: .top, spacing: 14) {
            ForEach(0..<columnCount, id: \.self) { columnIndex in
                LazyVStack(spacing: 14) {
                    ForEach(getImagesForColumn(columnIndex, totalColumns: columnCount)) { image in
                        MasonryImageThumbnailView(
                            image: image, 
                            colorScheme: colorScheme,
                            width: columnWidth,
                            onDelete: { onDeleteRequested(image) }
                        )
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoveredImageId = hovering ? image.id : nil
                            }
                        }
                        .onTapGesture {
                            // Quick Look on single-click
                            if let index = images.firstIndex(where: { $0.id == image.id }) {
                                onPreviewRequested(index)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getColumnCount(for width: CGFloat) -> Int {
        if width >= 1400 {
            return 7
        } else if width >= 1100 {
            return 6
        } else if width >= 700 {
            return 5
        } else {
            return 4
        }
    }
    
    private func getImagesForColumn(_ columnIndex: Int, totalColumns: Int) -> [ImageAsset] {
        return images.enumerated().compactMap { index, image in
            index % totalColumns == columnIndex ? image : nil
        }
    }
}

// MARK: - Quick Look Integration
extension ContentView {
    private func quickLookIndexForCurrentHoverOrFirst() -> Int? {
        if let hoveredId = hoveredImageId, let idx = images.firstIndex(where: { $0.id == hoveredId }) {
            return idx
        }
        return images.isEmpty ? nil : 0
    }

    private func presentQuickLook(at index: Int) {
        guard !images.isEmpty else { return }
        quickLookSelectedIndex = index
        withAnimation(.easeInOut(duration: 0.22)) {
            isPresentingEmbeddedPreview = true
        }
    }

    private func copyCurrentPreviewToPasteboard() {
        guard let idx = quickLookSelectedIndex, images.indices.contains(idx) else { return }
        let url = images[idx].filePath
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = NSImage(contentsOf: url) {
            pasteboard.writeObjects([image])
        }
        pasteboard.writeObjects([url as NSURL])
        performHaptic(.generic)
        print("📋 Copied image to pasteboard: \(url.lastPathComponent)")
        NotificationCenter.default.post(name: Self.imageCopiedNotification, object: nil)
    }
}

// MARK: - Haptics
extension ContentView {
    private func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

// MARK: - QuickLookPreviewer Helper
final class QuickLookPreviewer: NSObject {}

// MARK: - Embedded Preview Overlay (SwiftUI)
struct EmbeddedPreviewOverlay: View {
    let urls: [URL]
    let selectedIndex: Int
    let onClose: () -> Void
    @State private var index: Int = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Fullscreen clickable backdrop to close on outside click
                Button(action: { onClose() }) {
                    Color.black.opacity(0.92)
                        .ignoresSafeArea()
                }
                .buttonStyle(.plain)
                VStack(spacing: 0) {
                    let fitted = fittedImageSize(for: urls[index], in: CGSize(width: geo.size.width * 0.88, height: geo.size.height * 0.88))

                    ZStack {
                        let arrowSize: CGFloat = 36
                        QuickLookRepresentable(url: urls[index])
                            .frame(width: fitted.width, height: fitted.height)
                            .clipped()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(10)
                            // Transparent overlay for double-click and context menu
                            .onTapGesture(count: 2) {
                                copyToPasteboard(urls[index])
                            }
                            .contextMenu {
                                Button("Copy Image") {
                                    copyToPasteboard(urls[index])
                                }
                            }
                            // Left arrow straddling edge
                            .overlay(alignment: .leading) {
                                Button(action: { if index > 0 { index -= 1 } }) {
                                    Image(systemName: "chevron.left.circle.fill")
                                        .font(.system(size: arrowSize, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.96))
                                        .shadow(color: .black.opacity(0.4), radius: 4)
                                }
                                .buttonStyle(.plain)
                                .keyboardShortcut(.leftArrow, modifiers: [])
                                .offset(x: -arrowSize / 2)
                            }
                            // Right arrow straddling edge
                            .overlay(alignment: .trailing) {
                                Button(action: { if index < urls.count - 1 { index += 1 } }) {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.system(size: arrowSize, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.96))
                                        .shadow(color: .black.opacity(0.4), radius: 4)
                                }
                                .buttonStyle(.plain)
                                .keyboardShortcut(.rightArrow, modifiers: [])
                                .offset(x: arrowSize / 2)
                            }
                    }
                }
            }
        }
        .onAppear { index = min(max(0, selectedIndex), urls.count - 1) }
    }

    private func fittedImageSize(for url: URL, in boundingSize: CGSize) -> CGSize {
        #if canImport(AppKit)
        let imageSize = NSImage(contentsOf: url)?.size ?? .init(width: 800, height: 600)
        #else
        let imageSize = CGSize(width: 800, height: 600)
        #endif
        let widthScale = boundingSize.width / max(imageSize.width, 1)
        let heightScale = boundingSize.height / max(imageSize.height, 1)
        // Do not upscale small images: cap scale at 1.0
        let scale = min(widthScale, heightScale, 1.0)
        return CGSize(width: floor(imageSize.width * scale), height: floor(imageSize.height * scale))
    }

    private func copyToPasteboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = NSImage(contentsOf: url) {
            pasteboard.writeObjects([image])
        }
        pasteboard.writeObjects([url as NSURL])
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        print("📋 Copied image to pasteboard: \(url.lastPathComponent)")
        NotificationCenter.default.post(name: ContentView.imageCopiedNotification, object: nil)
    }
}

#if canImport(QuickLookUI)
// NSViewRepresentable wrapper for QLPreviewView to embed Quick Look in SwiftUI
struct QuickLookRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        if let view = QLPreviewView(frame: .zero, style: .normal) {
            view.autostarts = true
            view.previewItem = url as NSURL
            return view
        } else {
            // Fallback to NSImageView if QLPreviewView creation fails
            let fallbackView = NSImageView()
            fallbackView.imageScaling = .scaleProportionallyUpOrDown
            fallbackView.image = NSImage(contentsOf: url)
            return fallbackView
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let qlView = nsView as? QLPreviewView {
            qlView.previewItem = url as NSURL
        } else if let imageView = nsView as? NSImageView {
            imageView.image = NSImage(contentsOf: url)
        }
    }
}
#else
// Fallback if QuickLookUI not available: simple image preview using NSImageView
struct QuickLookRepresentable: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.image = NSImage(contentsOf: url)
        return view
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSImage(contentsOf: url)
    }
}
#endif

// MARK: - Masonry Image Thumbnail View Component
struct MasonryImageThumbnailView: View {
    let image: ImageAsset
    let colorScheme: ColorScheme
    let width: CGFloat
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage? = nil
    private static let thumbnailCache = NSCache<NSString, NSImage>()
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let thumbnail = thumbnailImage ?? Self.thumbnailCache.object(forKey: image.filePath.path as NSString) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: width)
                        .background(Color.gray.opacity(0.10))
                        .cornerRadius(8)
                        .animation(.easeInOut(duration: 0.12), value: isHovered)
                        .overlay(
                            Group {
                                if isHovered {
                                    // Darker overlay in light mode, lighter overlay in dark mode
                                    let edgeColor = (colorScheme == .light)
                                        ? Color.black.opacity(0.22)
                                        : Color.white.opacity(0.18)
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: edgeColor, location: 0.0),
                                            .init(color: .clear, location: 0.5),
                                            .init(color: edgeColor, location: 1.0)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .cornerRadius(8)
                                    .transition(.opacity)
                                }
                            }
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: width, height: width * 0.75)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.title2)
                        )
                }
            }

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.white)
                        .shadow(color: Color.black.opacity(0.25), radius: 3)
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .task(id: image.filePath) {
            // Load thumbnail asynchronously and cache
            if Self.thumbnailCache.object(forKey: image.filePath.path as NSString) == nil {
                let url = image.filePath
                await loadThumbnail(url: url, maxPixel: Int(width * NSScreen.main?.backingScaleFactor ?? 2.0))
            }
        }
    }

    @MainActor
    private func loadThumbnail(url: URL, maxPixel: Int) async {
        #if canImport(AppKit)
        // Use CGImageSource to create a downsampled thumbnail efficiently
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        let options: [NSString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        if let cgThumb = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) {
            let nsImage = NSImage(cgImage: cgThumb, size: .zero)
            Self.thumbnailCache.setObject(nsImage, forKey: url.path as NSString)
            thumbnailImage = nsImage
        }
        #endif
    }
}

#Preview {
    ContentView()
}
