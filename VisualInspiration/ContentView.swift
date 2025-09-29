//
//  ContentView.swift
//  VisualInspiration
//
//  Created by Visual Library on 2/14/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
        self.thumbnail = NSImage(contentsOf: filePath)
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
    
    // File manager and directory setup (following Freewrite's pattern)
    private let fileManager = FileManager.default
    
    // Cached images directory (following Freewrite's Documents pattern)
    private let imagesDirectory: URL = {
        // Use Documents directory like Freewrite does
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
                            availableWidth: geo.size.width - 60 // account for 30px padding on each side
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
                    // Empty state overlay (like Freewrite's placeholder)
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
                
                // Bottom control bar (exactly like Freewrite's)
                VStack {
                    Spacer()
                    HStack {
                        // Left side controls (image count like Freewrite's word count)
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
                        
                        // Right side controls (matching Freewrite's layout)
                        HStack(spacing: 8) {
                            Button(isFullscreen ? "Minimize" : "Fullscreen") {
                                if let window = NSApplication.shared.windows.first {
                                    window.toggleFullScreen(nil)
                                }
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
                            
                            // Theme toggle button (exactly like Freewrite)
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    colorScheme = colorScheme == .light ? .dark : .light
                                }
                                // Save preference
                                UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
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
                            
                            // Live timer (exactly like Freewrite)
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
            
            // Start live timer (exactly like Freewrite)
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    currentTime = Date()
                }
            }
        }
    }
    
    // MARK: - Image Management Functions (following Freewrite's file handling patterns)
    
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
        } catch {
            print("Error saving image data: \(error)")
        }
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
                            width: columnWidth
                        )
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoveredImageId = hovering ? image.id : nil
                            }
                        }
                        .onTapGesture {
                            // Open image in QuickLook
                            NSWorkspace.shared.open(image.filePath)
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

// MARK: - Masonry Image Thumbnail View Component
struct MasonryImageThumbnailView: View {
    let image: ImageAsset
    let colorScheme: ColorScheme
    let width: CGFloat
    @State private var isHovered = false
    
    var body: some View {
        Group {
            if let thumbnail = image.thumbnail {
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
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ContentView()
}
