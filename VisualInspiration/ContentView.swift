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

struct Vault: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    var imageCount: Int
    
    init(name: String = "New Vault") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.imageCount = 0
    }
}

struct ImageAsset: Identifiable {
    let id: UUID
    let filename: String
    let filePath: URL
    let vaultId: UUID         // Which vault this image belongs to
    let thumbnail: NSImage?
    
    init(filePath: URL, vaultId: UUID) {
        self.id = UUID()
        self.filePath = filePath
        self.filename = filePath.lastPathComponent
        self.vaultId = vaultId
        
        // Avoid loading full-size image synchronously; thumbnails are loaded lazily via cache
        self.thumbnail = nil
    }
}

struct ContentView: View {
    @State private var isFullscreen = false
    @State private var colorScheme: ColorScheme = .light
    @State private var isHoveringBottomNav = false
    @State private var isHoveringFolderButton = false
    @State private var bottomNavOpacity: Double = 1.0
    @State private var isHoveringThemeToggle = false
    @State private var isHoveringFullscreen = false
    @State private var vaults: [Vault] = []
    @State private var currentVaultId: UUID? = nil
    @State private var images: [ImageAsset] = []
    @State private var isHoveringImageGrid = false
    @State private var hoveredImageId: UUID? = nil
    @State private var draggedImage: ImageAsset? = nil
    @State private var currentTime = Date()
    @State private var quickLookSelectedIndex: Int? = nil
    @State private var isPresentingEmbeddedPreview = false
    @State private var lastColumnCount: Int = 5
    @State private var showingSidebar = false
    @State private var hoveredVaultId: UUID? = nil
    @State private var isHoveringVaults = false
    @State private var isHoveringVaultsPath = false
    @State private var editingVaultId: UUID? = nil
    @State private var editingVaultName: String = ""
    @State private var showingVaultMenu = false
    @State private var menuVaultId: UUID? = nil
    @State private var deletedVaults: [(vault: Vault, deletedAt: Date)] = []
    @State private var deletedImages: [(image: ImageAsset, backupPath: URL, deletedAt: Date)] = []
    @State private var skipEmptyConfirmation = false
    @State private var skipDeleteConfirmation = false
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
    
    // Vaults directory
    private var vaultsDirectory: URL {
        let directory = imagesDirectory.appendingPathComponent("Vaults")
        
        // Create Vaults directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Successfully created Vaults directory at: \(directory.path)")
            } catch {
                print("Error creating Vaults directory: \(error)")
            }
        }
        
        return directory
    }
    
    // Vaults metadata file
    private var vaultsMetadataURL: URL {
        return imagesDirectory.appendingPathComponent("vaults.json")
    }
    
    // Backup directory for undo functionality
    private var backupDirectory: URL {
        return imagesDirectory.appendingPathComponent("Backups")
    }
    
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
            // Main content area - Image grid
            ZStack {
                Color(colorScheme == .light ? .white : .black)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: colorScheme)
                
                // Image grid area - Masonry Layout
                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        MasonryGridView(
                            images: images,
                            colorScheme: colorScheme,
                            hoveredImageId: $hoveredImageId,
                            availableWidth: geo.size.width - 60, // account for 30px padding on each side
                            onColumnCountChange: { count in
                                lastColumnCount = max(1, count)
                            },
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
                .onDrop(of: [.image], isTargeted: nil) { providers in
                    handleImageDrop(providers: providers)
                }
                .overlay(
                    Group {
                        if isPresentingEmbeddedPreview, let idx = quickLookSelectedIndex, images.indices.contains(idx) {
                            EmbeddedPreviewOverlay(
                                urls: images.map { $0.filePath },
                                selectedIndex: Binding(
                                    get: { quickLookSelectedIndex ?? idx },
                                    set: { quickLookSelectedIndex = $0 }
                                ),
                                onClose: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        isPresentingEmbeddedPreview = false
                                    }
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
                        }
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                        
                        Spacer()
                        
                        // Right side controls
                        HStack(spacing: 8) {
                            // Live timer
                            Text(currentTime, style: .time)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(textColor)
                                .animation(.easeInOut(duration: 0.6), value: colorScheme)
                        
                            Text("•")
                                .foregroundColor(.gray)

                            // Fullscreen button
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
                            
                            // History button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingSidebar.toggle()
                                }
                            }) {
                                Image(systemName: "folder.fill")
                                .foregroundColor(isHoveringFolderButton ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringFolderButton = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.clear)
                        .compositingGroup()
                        .shadow(color: (colorScheme == .light ? Color.white.opacity(0.35) : Color.black.opacity(0.35)), radius: 2, x: 0, y: 1)
                        .cornerRadius(6)
                    }
                    .padding(.horizontal, 30)
                    // .padding(.top, 2)
                    .padding(.bottom, 10) 
                    .background(Color.clear)
                    .animation(.easeInOut(duration: 0.6), value: colorScheme)
                    .opacity(1.2)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Vaults Sidebar - Only show when toggled
            if showingSidebar {
                Divider()
                
                    VaultsSidebar(
                        vaults: vaults,
                        currentVaultId: $currentVaultId,
                        colorScheme: colorScheme,
                        hoveredVaultId: $hoveredVaultId,
                        isHoveringVaults: $isHoveringVaults,
                        isHoveringVaultsPath: $isHoveringVaultsPath,
                        editingVaultId: $editingVaultId,
                        editingVaultName: $editingVaultName,
                        onVaultSelected: { vault in
                            switchToVault(vault)
                        },
                        onVaultCreated: {
                            createNewVault()
                        },
                        onVaultNameSaved: { vault in
                            saveVaultName(vault)
                        },
                        onVaultRename: { vault in
                            editingVaultId = vault.id
                            editingVaultName = vault.name
                        },
                        onVaultEmpty: { vault in
                            if skipEmptyConfirmation {
                                emptyVault(vault)
                            } else {
                                showConfirmationDialog(
                                    title: "Empty Vault",
                                    message: "This will delete all images in '\(vault.name)'. This action can be undone with Cmd+Z within 10 minutes.",
                                    destructiveButtonTitle: "Empty",
                                    isDestructive: false,
                                    skipKey: "skipEmptyConfirmation"
                                ) {
                                    emptyVault(vault)
                                }
                            }
                        },
                        onVaultDelete: { vault in
                            if skipDeleteConfirmation {
                                deleteVault(vault)
                            } else {
                                showConfirmationDialog(
                                    title: "Delete Vault",
                                    message: "This will permanently delete '\(vault.name)' and all its images. This action can be undone with Cmd+Z within 10 minutes.",
                                    destructiveButtonTitle: "Delete",
                                    isDestructive: true,
                                    skipKey: "skipDeleteConfirmation"
                                ) {
                                    deleteVault(vault)
                                }
                            }
                        },
                        onVaultDownloadAll: { vault in
                            downloadAllImages(from: vault)
                        },
                        onResetConfirmations: {
                            UserDefaults.standard.set(false, forKey: "skipEmptyConfirmation")
                            UserDefaults.standard.set(false, forKey: "skipDeleteConfirmation")
                            skipEmptyConfirmation = false
                            skipDeleteConfirmation = false
                            print("Reset confirmation dialogs")
                        },
                        formatDate: formatVaultDate
                    )
                .frame(width: 200)
                .background(Color(colorScheme == .light ? .white : .black))
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: showingSidebar)
        .preferredColorScheme(colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
        .onAppear {
            loadVaults()
            
            // Load confirmation preferences
            skipEmptyConfirmation = UserDefaults.standard.bool(forKey: "skipEmptyConfirmation")
            skipDeleteConfirmation = UserDefaults.standard.bool(forKey: "skipDeleteConfirmation")
            
            // Start live timer
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    currentTime = Date()
                }
            }
            
            // Start cleanup timer for expired backups
            Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
                cleanupExpiredBackups()
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
                } else if event.modifierFlags.contains(.command) && event.keyCode == 6 { // Cmd+Z
                    // Undo functionality
                    if showingSidebar && !deletedVaults.isEmpty {
                        undoDeletedVault()
                        return nil
                    } else if !deletedImages.isEmpty {
                        undoDeletedImage()
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
                    // Arrow key navigation while preview is open
                    if let idx = quickLookSelectedIndex {
                        switch event.keyCode {
                        case 123: // left
                            if idx > 0 { quickLookSelectedIndex = idx - 1 }
                            return nil
                        case 124: // right
                            if idx < images.count - 1 { quickLookSelectedIndex = idx + 1 }
                            return nil
                        case 126: // up
                            let target = idx - lastColumnCount
                            if target >= 0 { quickLookSelectedIndex = target }
                            return nil
                        case 125: // down
                            let target = idx + lastColumnCount
                            if target < images.count { quickLookSelectedIndex = target }
                            return nil
                        default:
                            break
                        }
                    }
                }
                return event
            }
            // No NotificationCenter needed; binding keeps indices in sync
        }
    }
    
    // MARK: - Vault Management Functions
    
    private func loadVaults() {
        // Load vaults from metadata file
        if fileManager.fileExists(atPath: vaultsMetadataURL.path) {
            do {
                let data = try Data(contentsOf: vaultsMetadataURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                vaults = try decoder.decode([Vault].self, from: data)
                print("Loaded \(vaults.count) vaults from metadata")
            } catch {
                print("Error loading vaults: \(error)")
                createDefaultVaults()
            }
        } else {
            createDefaultVaults()
        }
        
        // Load last opened vault
        if let lastVaultIdString = UserDefaults.standard.string(forKey: "lastOpenedVaultId"),
           let lastVaultId = UUID(uuidString: lastVaultIdString),
           vaults.contains(where: { $0.id == lastVaultId }) {
            currentVaultId = lastVaultId
        } else if let firstVault = vaults.first {
            currentVaultId = firstVault.id
        }
        
        // Load images for current vault
        loadImagesForCurrentVault()
    }
    
    private func createDefaultVaults() {
        let defaultVault = Vault(name: "All Images")
        vaults = [defaultVault]
        currentVaultId = defaultVault.id
        saveVaults()
        print("Created default 'All Images' vault")
    }
    
    private func saveVaults() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(vaults)
            try data.write(to: vaultsMetadataURL)
            print("Saved \(vaults.count) vaults to metadata")
        } catch {
            print("Error saving vaults: \(error)")
        }
    }
    
    private func loadImagesForCurrentVault() {
        guard let currentVaultId = currentVaultId else {
            images = []
            return
        }
        
        let vaultDirectory = vaultsDirectory.appendingPathComponent(currentVaultId.uuidString)
        
        // Create vault directory if it doesn't exist
        if !fileManager.fileExists(atPath: vaultDirectory.path) {
            do {
                try fileManager.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
                print("Created vault directory: \(vaultDirectory.path)")
            } catch {
                print("Error creating vault directory: \(error)")
                return
            }
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: nil)
            let imageFiles = fileURLs.filter { url in
                let supportedTypes = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
                return supportedTypes.contains(url.pathExtension.lowercased())
            }
            
            images = imageFiles.map { ImageAsset(filePath: $0, vaultId: currentVaultId) }
            print("Loaded \(images.count) images for current vault")
            
        } catch {
            print("Error loading images for vault: \(error)")
            images = []
        }
    }
    
    private func createNewVault() {
        let newVault = Vault(name: "")
        vaults.append(newVault)
        saveVaults()
        
        // Create vault directory
        let vaultDirectory = vaultsDirectory.appendingPathComponent(newVault.id.uuidString)
        do {
            try fileManager.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
            print("Created new vault: \(newVault.name)")
        } catch {
            print("Error creating vault directory: \(error)")
        }
        
        // Start editing the new vault name
        editingVaultId = newVault.id
        editingVaultName = newVault.name
        
        // Ensure the TextField gets focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // This ensures the TextField is properly focused
        }
    }
    
    private func saveVaultName(_ vault: Vault) {
        if let index = vaults.firstIndex(where: { $0.id == vault.id }) {
            vaults[index].name = editingVaultName
            saveVaults()
            editingVaultId = nil
            editingVaultName = ""
            print("Saved vault name: \(editingVaultName)")
        }
    }
    
    private func switchToVault(_ vault: Vault) {
        currentVaultId = vault.id
        UserDefaults.standard.set(vault.id.uuidString, forKey: "lastOpenedVaultId")
        loadImagesForCurrentVault()
        print("Switched to vault: \(vault.name)")
    }
    
    private func formatVaultDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            // Check if it's in the current year
            if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
                formatter.dateFormat = "MMM d"
            } else {
                formatter.dateFormat = "MMM d yyyy"
            }
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Vault Management Actions
    
    private func emptyVault(_ vault: Vault) {
        let vaultDirectory = vaultsDirectory.appendingPathComponent(vault.id.uuidString)
        
        do {
            // Ensure backup directory exists
            if !fileManager.fileExists(atPath: backupDirectory.path) {
                try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            }
            
            let fileURLs = try fileManager.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: nil)
            let imageFiles = fileURLs.filter { url in
                let supportedTypes = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
                return supportedTypes.contains(url.pathExtension.lowercased())
            }
            
            // Backup images before deletion
            for imageURL in imageFiles {
                let backupPath = backupDirectory.appendingPathComponent("\(vault.id.uuidString)_\(imageURL.lastPathComponent)")
                
                // Copy to backup location
                try fileManager.copyItem(at: imageURL, to: backupPath)
                
                // Add to undo list with backup path
                let image = ImageAsset(filePath: imageURL, vaultId: vault.id)
                deletedImages.append((image: image, backupPath: backupPath, deletedAt: Date()))
                
                // Now delete the original
                try fileManager.removeItem(at: imageURL)
            }
            
            // Update vault image count
            if let index = vaults.firstIndex(where: { $0.id == vault.id }) {
                vaults[index].imageCount = 0
                saveVaults()
            }
            
            // Reload images if this is the current vault
            if currentVaultId == vault.id {
                loadImagesForCurrentVault()
            }
            
            print("Emptied vault: \(vault.name)")
            performHaptic(.levelChange)
            
        } catch {
            print("Error emptying vault: \(error)")
        }
    }
    
    private func deleteVault(_ vault: Vault) {
        let vaultDirectory = vaultsDirectory.appendingPathComponent(vault.id.uuidString)
        
        do {
            // Ensure backup directory exists
            if !fileManager.fileExists(atPath: backupDirectory.path) {
                try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            }
            
            // Get all images in the vault first
            let fileURLs = try fileManager.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: nil)
            let imageFiles = fileURLs.filter { url in
                let supportedTypes = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
                return supportedTypes.contains(url.pathExtension.lowercased())
            }
            
            // Backup images before deletion
            for imageURL in imageFiles {
                let backupPath = backupDirectory.appendingPathComponent("\(vault.id.uuidString)_\(imageURL.lastPathComponent)")
                
                // Copy to backup location
                try fileManager.copyItem(at: imageURL, to: backupPath)
                
                // Add to undo list with backup path
                let image = ImageAsset(filePath: imageURL, vaultId: vault.id)
                deletedImages.append((image: image, backupPath: backupPath, deletedAt: Date()))
            }
            
            // Add vault to undo list
            deletedVaults.append((vault: vault, deletedAt: Date()))
            
            // Delete the entire vault directory
            try fileManager.removeItem(at: vaultDirectory)
            
            // Remove vault from list
            vaults.removeAll { $0.id == vault.id }
            saveVaults()
            
            // Switch to next available vault or create empty state
            if currentVaultId == vault.id {
                if let nextVault = vaults.first {
                    switchToVault(nextVault)
                } else {
                    // Create default vault if none left
                    createDefaultVaults()
                }
            }
            
            print("Deleted vault: \(vault.name)")
            performHaptic(.levelChange)
            
        } catch {
            print("Error deleting vault: \(error)")
        }
    }
    
    private func downloadAllImages(from vault: Vault) {
        let vaultDirectory = vaultsDirectory.appendingPathComponent(vault.id.uuidString)
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: nil)
            let imageFiles = fileURLs.filter { url in
                let supportedTypes = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
                return supportedTypes.contains(url.pathExtension.lowercased())
            }
            
            guard !imageFiles.isEmpty else {
                print("No images to download in vault: \(vault.name)")
                return
            }
            
            // Create downloads directory for this vault
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let vaultDownloadsURL = downloadsURL.appendingPathComponent("\(vault.name) - VisualInspiration")
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: vaultDownloadsURL.path) {
                try fileManager.createDirectory(at: vaultDownloadsURL, withIntermediateDirectories: true)
            }
            
            // Copy all images to downloads
            for imageURL in imageFiles {
                let destinationURL = vaultDownloadsURL.appendingPathComponent(imageURL.lastPathComponent)
                try fileManager.copyItem(at: imageURL, to: destinationURL)
            }
            
            print("Downloaded \(imageFiles.count) images to: \(vaultDownloadsURL.path)")
            performHaptic(.alignment)
            
        } catch {
            print("Error downloading images: \(error)")
        }
    }
    
    private func undoDeletedVault() {
        guard let lastDeleted = deletedVaults.last else { return }
        
        let now = Date()
        if now.timeIntervalSince(lastDeleted.deletedAt) > 600 { // 10 minutes
            deletedVaults.removeLast()
            return
        }
        
        // Restore vault
        vaults.append(lastDeleted.vault)
        saveVaults()
        
        // Create vault directory
        let vaultDirectory = vaultsDirectory.appendingPathComponent(lastDeleted.vault.id.uuidString)
        do {
            try fileManager.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error recreating vault directory: \(error)")
        }
        
        deletedVaults.removeLast()
        print("Restored vault: \(lastDeleted.vault.name)")
        performHaptic(.alignment)
    }
    
    private func undoDeletedImage() {
        guard let lastDeleted = deletedImages.last else { 
            print("No deleted images to restore")
            return 
        }
        
        let now = Date()
        if now.timeIntervalSince(lastDeleted.deletedAt) > 600 { // 10 minutes
            print("Undo window expired for image")
            deletedImages.removeLast()
            return
        }
        
        // Restore image file from backup
        do {
            // Ensure the vault directory exists
            let vaultDirectory = vaultsDirectory.appendingPathComponent(lastDeleted.image.vaultId.uuidString)
            if !fileManager.fileExists(atPath: vaultDirectory.path) {
                try fileManager.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
            }
            
            // Restore from backup to original location
            try fileManager.moveItem(at: lastDeleted.backupPath, to: lastDeleted.image.filePath)
            
            // Update vault image count
            if let index = vaults.firstIndex(where: { $0.id == lastDeleted.image.vaultId }) {
                vaults[index].imageCount += 1
                saveVaults()
            }
            
            // Reload images if this is the current vault
            if currentVaultId == lastDeleted.image.vaultId {
                loadImagesForCurrentVault()
            }
            
            deletedImages.removeLast()
            print("Restored image: \(lastDeleted.image.filename)")
            performHaptic(.alignment)
            
        } catch {
            print("Error restoring image: \(error)")
            deletedImages.removeLast()
        }
    }
    
    private func cleanupExpiredBackups() {
        let now = Date()
        
        // Clean up expired deleted images
        deletedImages.removeAll { now.timeIntervalSince($0.deletedAt) > 600 } // 10 minutes
        
            // Clean up expired deleted vaults
            deletedVaults.removeAll { now.timeIntervalSince($0.deletedAt) > 600 } // 10 minutes
        
        // Clean up backup files that are no longer needed
        do {
            if fileManager.fileExists(atPath: backupDirectory.path) {
                let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
                for backupFile in backupFiles {
                    // Check if this backup is still referenced in our undo lists
                    let isReferenced = deletedImages.contains { $0.backupPath == backupFile }
                    if !isReferenced {
                        try fileManager.removeItem(at: backupFile)
                        print("Cleaned up expired backup: \(backupFile.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("Error cleaning up backups: \(error)")
        }
    }
    
    private func showConfirmationDialog(
        title: String,
        message: String,
        destructiveButtonTitle: String,
        isDestructive: Bool,
        skipKey: String,
        onConfirm: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: destructiveButtonTitle)
        alert.addButton(withTitle: "Cancel")
        
        if isDestructive {
            alert.alertStyle = .critical
        } else {
            alert.alertStyle = .warning
        }
        
        // Create a checkbox for "Don't ask again"
        let checkbox = NSButton(checkboxWithTitle: "Don't ask again", target: nil, action: nil)
        checkbox.state = .off
        alert.accessoryView = checkbox
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Check if "Don't ask again" was selected
            if checkbox.state == .on {
                UserDefaults.standard.set(true, forKey: skipKey)
                if skipKey == "skipEmptyConfirmation" {
                    skipEmptyConfirmation = true
                } else if skipKey == "skipDeleteConfirmation" {
                    skipDeleteConfirmation = true
                }
            }
            onConfirm()
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
        guard let currentVaultId = currentVaultId else { return }
        
        let filename = url.lastPathComponent
        let vaultDirectory = vaultsDirectory.appendingPathComponent(currentVaultId.uuidString)
        let destinationURL = vaultDirectory.appendingPathComponent(filename)
        
        print("💾 Saving image from: \(url)")
        print("💾 Destination: \(destinationURL)")
        
        do {
            // Copy file to current vault directory
            try fileManager.copyItem(at: url, to: destinationURL)
            
            // Add to images array
            let newImage = ImageAsset(filePath: destinationURL, vaultId: currentVaultId)
            images.insert(newImage, at: 0)
            
            // Update vault image count
            if let index = vaults.firstIndex(where: { $0.id == currentVaultId }) {
                vaults[index].imageCount += 1
                saveVaults()
            }
            
            print("✅ Successfully saved image: \(filename)")
            print("📊 Images array now has \(images.count) items")
            performHaptic(.alignment)
        } catch {
            print("❌ Error saving image: \(error)")
        }
    }
    
    private func saveImageData(_ data: Data) {
        guard let currentVaultId = currentVaultId else { return }
        
        let filename = "image_\(UUID().uuidString).png"
        let vaultDirectory = vaultsDirectory.appendingPathComponent(currentVaultId.uuidString)
        let destinationURL = vaultDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: destinationURL)
            
            let newImage = ImageAsset(filePath: destinationURL, vaultId: currentVaultId)
            images.insert(newImage, at: 0)
            
            // Update vault image count
            if let index = vaults.firstIndex(where: { $0.id == currentVaultId }) {
                vaults[index].imageCount += 1
                saveVaults()
            }
            
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
            
            // Update vault image count
            if let index = vaults.firstIndex(where: { $0.id == image.vaultId }) {
                vaults[index].imageCount = max(0, vaults[index].imageCount - 1)
                saveVaults()
            }
            
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
    let onColumnCountChange: (Int) -> Void
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
        .onAppear { onColumnCountChange(columnCount) }
        .onChange(of: availableWidth) { onColumnCountChange(getColumnCount(for: availableWidth)) }
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
    @Binding var selectedIndex: Int
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
                            // Left arrow straddling edge (only when there is a previous image)
                            .overlay(alignment: .leading) {
                                if urls.count > 1 && index > 0 {
                                    Button(action: { index -= 1 }) {
                                        Image(systemName: "chevron.left.circle.fill")
                                            .font(.system(size: arrowSize, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.96))
                                            .shadow(color: .black.opacity(0.4), radius: 4)
                                    }
                                    .buttonStyle(.plain)
                                    .keyboardShortcut(.leftArrow, modifiers: [])
                                    .offset(x: -arrowSize / 2)
                                }
                            }
                            // Right arrow straddling edge (only when there is a next image)
                            .overlay(alignment: .trailing) {
                                if urls.count > 1 && index < urls.count - 1 {
                                    Button(action: { index += 1 }) {
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
        }
        .onAppear { index = min(max(0, selectedIndex), urls.count - 1) }
        .onChange(of: index) { _, newValue in
            selectedIndex = newValue
        }
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
                await loadThumbnail(
                    url: url,
                    maxPixel: Int(width * 3.0) // Increased from 2.0 to 3.0 for better quality
                )
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

// MARK: - Vaults Sidebar
struct VaultsSidebar: View {
    let vaults: [Vault]
    @Binding var currentVaultId: UUID?
    let colorScheme: ColorScheme
    @Binding var hoveredVaultId: UUID?
    @Binding var isHoveringVaults: Bool
    @Binding var isHoveringVaultsPath: Bool
    @Binding var editingVaultId: UUID?
    @Binding var editingVaultName: String
    let onVaultSelected: (Vault) -> Void
    let onVaultCreated: () -> Void
    let onVaultNameSaved: (Vault) -> Void
    let onVaultRename: (Vault) -> Void
    let onVaultEmpty: (Vault) -> Void
    let onVaultDelete: (Vault) -> Void
    let onVaultDownloadAll: (Vault) -> Void
    let onResetConfirmations: () -> Void
    let formatDate: (Date) -> String
    
    var textColor: Color {
        colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
    }
    
    var textHoverColor: Color {
        colorScheme == .light ? Color.black : Color.white
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with + button
            HStack {
                Button(action: {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: getImagesDirectory().path)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Vaults")
                                .font(.system(size: 13))
                                .foregroundColor(isHoveringVaults ? textHoverColor : textColor)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(isHoveringVaults ? textHoverColor : textColor)
                        }
                        Text(getImagesDirectory().path)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringVaults = hovering
                }
                
                Spacer()
                
                // + Button for creating new vaults
                Button(action: onVaultCreated) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(textColor)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Vaults List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vaults) { vault in
                        VaultRow(
                            vault: vault,
                            isSelected: vault.id == currentVaultId,
                            isHovered: vault.id == hoveredVaultId,
                            isEditing: vault.id == editingVaultId,
                            editingName: $editingVaultName,
                            formatDate: formatDate,
                            onSelected: {
                                if vault.id != currentVaultId {
                                    onVaultSelected(vault)
                                }
                            },
                            onNameSaved: {
                                onVaultNameSaved(vault)
                            },
                            onRename: { vault in
                                onVaultRename(vault)
                            },
                            onEmpty: { vault in
                                onVaultEmpty(vault)
                            },
                            onDelete: { vault in
                                onVaultDelete(vault)
                            },
                            onDownloadAll: { vault in
                                onVaultDownloadAll(vault)
                            },
                            onResetConfirmations: {
                                onResetConfirmations()
                            }
                        )
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoveredVaultId = hovering ? vault.id : nil
                            }
                        }
                        
                        if vault.id != vaults.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .background(Color(colorScheme == .light ? .white : .black))
    }
    
    private func getImagesDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("VisualInspiration")
    }
}

// MARK: - Vault Row
        struct VaultRow: View {
            let vault: Vault
            let isSelected: Bool
            let isHovered: Bool
            let isEditing: Bool
            @Binding var editingName: String
            let formatDate: (Date) -> String
            let onSelected: () -> Void
            let onNameSaved: () -> Void
            let onRename: (Vault) -> Void
            let onEmpty: (Vault) -> Void
            let onDelete: (Vault) -> Void
            let onDownloadAll: (Vault) -> Void
            let onResetConfirmations: () -> Void
            @State private var tempName: String = ""
            @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        Button(action: onSelected) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if isEditing {
                            TextField("", text: $tempName)
                                .placeholder(when: tempName.isEmpty) {
                                    Text("Vault name")
                                        .foregroundColor(.secondary)
                                }
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    editingName = tempName
                                    onNameSaved()
                                }
                                .onAppear {
                                    tempName = vault.name.isEmpty ? "" : vault.name
                                    // Auto-focus when editing starts
                                    DispatchQueue.main.async {
                                        isTextFieldFocused = true
                                    }
                                }
                                .onTapGesture {
                                    // Ensure focus when tapping
                                    isTextFieldFocused = true
                                }
                        } else {
                            Text(vault.name.isEmpty ? "Vault name" : vault.name)
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .foregroundColor(vault.name.isEmpty ? .secondary : .primary)
                        }
                        
                        Spacer()
                    }
                    
                    Text(formatDate(vault.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .contextMenu {
            Button("Rename") {
                onRename(vault)
            }
            Button("Empty") {
                onEmpty(vault)
            }
            Button("Delete Vault") {
                onDelete(vault)
            }
            Button("Download All") {
                onDownloadAll(vault)
            }
            Divider()
            Button("Reset Confirmations") {
                onResetConfirmations()
            }
        }
        .onAppear {
            NSCursor.pop()  // Reset cursor when button appears
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.gray.opacity(0.1)  // More subtle selection highlight
        } else if isHovered {
            return Color.gray.opacity(0.05)  // Even more subtle hover state
        } else {
            return Color.clear
        }
    }
}

// MARK: - View Extensions
extension View {
    func placeholder<Content: View>(
        when condition: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(condition ? 1 : 0)
            self
        }
    }
}

#Preview {
    ContentView()
}
