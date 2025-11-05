//
//  PersistenceManager.swift
//  VisualInspiration
//

import Foundation

class PersistenceManager {
    private let fileManager = FileManager.default
    private let saveURL: URL

    init() {
        // Get Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VisualInspiration", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            do {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
                print("📁 Created VisualInspiration directory at: \(appDirectory.path)")
            } catch {
                print("❌ Failed to create directory: \(error)")
            }
        }

        // Set save location
        saveURL = appDirectory.appendingPathComponent("moodboard.json")
        print("💾 MoodBoard save location: \(saveURL.path)")
    }

    /// Save canvas state to disk
    func save(_ canvasState: CanvasState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(canvasState)
            try data.write(to: saveURL, options: .atomic)
            print("✅ Saved MoodBoard state (\(canvasState.items.count) items)")
        } catch {
            print("❌ Failed to save canvas: \(error)")
        }
    }

    /// Load canvas state from disk
    func load() -> CanvasState? {
        guard fileManager.fileExists(atPath: saveURL.path) else {
            print("ℹ️ No saved MoodBoard found (first time use)")
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: saveURL)
            let canvasState = try decoder.decode(CanvasState.self, from: data)
            print("✅ Loaded MoodBoard state (\(canvasState.items.count) items)")
            return canvasState
        } catch {
            print("❌ Failed to load canvas: \(error)")
            return nil
        }
    }

    /// Delete saved state (used when clearing canvas)
    func clear() {
        guard fileManager.fileExists(atPath: saveURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: saveURL)
            print("🗑️ Cleared saved MoodBoard state")
        } catch {
            print("❌ Failed to clear saved state: \(error)")
        }
    }
}
