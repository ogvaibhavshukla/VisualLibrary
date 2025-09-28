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
    
    // File manager and directory setup (following Freewrite's pattern)
    private let fileManager = FileManager.default
    
    // Cached images directory (following Freewrite's pattern)
    private let imagesDirectory: URL = {
        let directory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].appendingPathComponent("VisualInspiration")
        
        // Create VisualInspiration directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Successfully created VisualInspiration directory")
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        
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
        let navHeight: CGFloat = 68
        
        HStack(spacing: 0) {
            // Main content area - will be replaced with image grid
            ZStack {
                Color(colorScheme == .light ? .white : .black)
                    .ignoresSafeArea()
                
                // Image grid area (replacing text editor)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(images) { image in
                            ImageThumbnailView(image: image, colorScheme: colorScheme)
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
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, navHeight)
                .background(Color(colorScheme == .light ? .white : .black))
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
                                
                                Text("Drag images here")
                                    .font(.system(size: 18))
                                    .foregroundColor(colorScheme == .light ? .gray.opacity(0.5) : .gray.opacity(0.6))
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
                                colorScheme = colorScheme == .light ? .dark : .light
                                // Save preference
                                UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
                            }) {
                                Image(systemName: colorScheme == .light ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(isHoveringThemeToggle ? textHoverColor : textColor)
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
                        }
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                    }
                    .padding()
                    .background(Color(colorScheme == .light ? .white : .black))
                    .opacity(bottomNavOpacity)
                    .onHover { hovering in
                        isHoveringBottomNav = hovering
                        if hovering {
                            withAnimation(.easeOut(duration: 0.2)) {
                                bottomNavOpacity = 1.0
                            }
                        } else {
                            withAnimation(.easeIn(duration: 1.0)) {
                                bottomNavOpacity = 0.0
                            }
                        }
                    }
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
        }
    }
    
    // MARK: - Image Management Functions (following Freewrite's file handling patterns)
    
    private func loadExistingImages() {
        print("Looking for images in: \(imagesDirectory.path)")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            let imageFiles = fileURLs.filter { url in
                let supportedTypes = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
                return supportedTypes.contains(url.pathExtension.lowercased())
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
        var hasHandledDrop = false
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self.saveImage(from: url)
                        } else if let data = item as? Data {
                            self.saveImageData(data)
                        }
                    }
                }
                hasHandledDrop = true
            }
        }
        
        return hasHandledDrop
    }
    
    private func saveImage(from url: URL) {
        let filename = url.lastPathComponent
        let destinationURL = imagesDirectory.appendingPathComponent(filename)
        
        do {
            // Copy file to our directory
            try fileManager.copyItem(at: url, to: destinationURL)
            
            // Add to images array
            let newImage = ImageAsset(filePath: destinationURL)
            images.insert(newImage, at: 0)
            
            print("Successfully saved image: \(filename)")
        } catch {
            print("Error saving image: \(error)")
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
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipped()
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

#Preview {
    ContentView()
}
