//
//  ImageCache.swift
//  MoodBoardFeature
//
//  Memory-efficient image caching with size limits
//

import AppKit
import Foundation

/// LRU cache for images and thumbnails with automatic memory management
class ImageCache {

    // MARK: - Singleton

    static let shared = ImageCache()

    // MARK: - Properties

    /// Full-resolution image cache
    private let imageCache = NSCache<NSString, NSImage>()

    /// Thumbnail cache
    private let thumbnailCache = NSCache<NSString, NSImage>()

    /// Access times for LRU tracking
    private var accessTimes: [String: Date] = [:]
    private let accessTimesLock = NSLock()

    // MARK: - Configuration

    /// Maximum memory for full images (in bytes, default ~200MB)
    var maxImageCacheSize: Int = 200 * 1024 * 1024 {
        didSet {
            imageCache.totalCostLimit = maxImageCacheSize
        }
    }

    /// Maximum memory for thumbnails (in bytes, default ~100MB)
    var maxThumbnailCacheSize: Int = 100 * 1024 * 1024 {
        didSet {
            thumbnailCache.totalCostLimit = maxThumbnailCacheSize
        }
    }

    /// Maximum number of images to cache
    var maxImageCount: Int = 100 {
        didSet {
            imageCache.countLimit = maxImageCount
        }
    }

    /// Maximum number of thumbnails to cache
    var maxThumbnailCount: Int = 500 {
        didSet {
            thumbnailCache.countLimit = maxThumbnailCount
        }
    }

    // MARK: - Initialization

    private init() {
        setupCaches()
        observeMemoryWarnings()
    }

    private func setupCaches() {
        // Configure image cache
        imageCache.totalCostLimit = maxImageCacheSize
        imageCache.countLimit = maxImageCount
        imageCache.name = "com.moodboard.imagecache"

        // Configure thumbnail cache
        thumbnailCache.totalCostLimit = maxThumbnailCacheSize
        thumbnailCache.countLimit = maxThumbnailCount
        thumbnailCache.name = "com.moodboard.thumbnailcache"
    }

    private func observeMemoryWarnings() {
        // Listen for memory pressure notifications (macOS)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    // MARK: - Image Cache

    /// Get an image from cache
    func getImage(forKey key: String) -> NSImage? {
        updateAccessTime(forKey: key)
        return imageCache.object(forKey: key as NSString)
    }

    /// Store an image in cache
    func setImage(_ image: NSImage, forKey key: String) {
        let cost = estimateImageSize(image)
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
        updateAccessTime(forKey: key)
    }

    /// Remove an image from cache
    func removeImage(forKey key: String) {
        imageCache.removeObject(forKey: key as NSString)
        removeAccessTime(forKey: key)
    }

    // MARK: - Thumbnail Cache

    /// Get a thumbnail from cache
    func getThumbnail(forKey key: String) -> NSImage? {
        updateAccessTime(forKey: "thumb_\(key)")
        return thumbnailCache.object(forKey: key as NSString)
    }

    /// Store a thumbnail in cache
    func setThumbnail(_ thumbnail: NSImage, forKey key: String) {
        let cost = estimateImageSize(thumbnail)
        thumbnailCache.setObject(thumbnail, forKey: key as NSString, cost: cost)
        updateAccessTime(forKey: "thumb_\(key)")
    }

    /// Remove a thumbnail from cache
    func removeThumbnail(forKey key: String) {
        thumbnailCache.removeObject(forKey: key as NSString)
        removeAccessTime(forKey: "thumb_\(key)")
    }

    // MARK: - Cache Management

    /// Clear all caches
    func clearAll() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()

        accessTimesLock.lock()
        accessTimes.removeAll()
        accessTimesLock.unlock()

        print("ImageCache: Cleared all caches")
    }

    /// Clear only full-resolution images (keep thumbnails)
    func clearImages() {
        imageCache.removeAllObjects()
        print("ImageCache: Cleared image cache")
    }

    /// Clear only thumbnails
    func clearThumbnails() {
        thumbnailCache.removeAllObjects()
        print("ImageCache: Cleared thumbnail cache")
    }

    /// Remove least recently used items to free memory
    func trimCache(targetReduction: Double = 0.5) {
        accessTimesLock.lock()
        let sortedKeys = accessTimes.sorted { $0.value < $1.value }.map { $0.key }
        accessTimesLock.unlock()

        let itemsToRemove = Int(Double(sortedKeys.count) * targetReduction)

        for i in 0..<min(itemsToRemove, sortedKeys.count) {
            let key = sortedKeys[i]

            if key.hasPrefix("thumb_") {
                let thumbKey = String(key.dropFirst(6))
                removeThumbnail(forKey: thumbKey)
            } else {
                removeImage(forKey: key)
            }
        }

        print("ImageCache: Trimmed \(itemsToRemove) items from cache")
    }

    // MARK: - Memory Management

    private func handleMemoryWarning() {
        print("ImageCache: Received memory warning - clearing full image cache")
        clearImages()
        trimCache(targetReduction: 0.3)
    }

    // MARK: - Access Time Tracking

    private func updateAccessTime(forKey key: String) {
        accessTimesLock.lock()
        accessTimes[key] = Date()
        accessTimesLock.unlock()
    }

    private func removeAccessTime(forKey key: String) {
        accessTimesLock.lock()
        accessTimes.removeValue(forKey: key)
        accessTimesLock.unlock()
    }

    // MARK: - Size Estimation

    /// Estimate the memory size of an image
    private func estimateImageSize(_ image: NSImage) -> Int {
        let size = image.size
        let pixelCount = Int(size.width * size.height)

        // Assume 4 bytes per pixel (RGBA)
        let bytesPerPixel = 4

        // Account for representations
        let representationCount = max(1, image.representations.count)

        return pixelCount * bytesPerPixel * representationCount
    }

    // MARK: - Cache Statistics

    /// Get cache statistics
    var statistics: CacheStatistics {
        accessTimesLock.lock()
        let totalItems = accessTimes.count
        accessTimesLock.unlock()

        return CacheStatistics(
            imageCount: totalItems,
            thumbnailCount: totalItems,
            estimatedMemoryUsage: estimatedTotalMemoryUsage()
        )
    }

    private func estimatedTotalMemoryUsage() -> Int {
        // This is an estimation - NSCache doesn't provide exact current usage
        return 0 // Could be enhanced with actual tracking if needed
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let imageCount: Int
    let thumbnailCount: Int
    let estimatedMemoryUsage: Int

    var description: String {
        let memoryMB = Double(estimatedMemoryUsage) / (1024 * 1024)
        return """
        Cache Statistics:
        - Images cached: \(imageCount)
        - Thumbnails cached: \(thumbnailCount)
        - Memory usage: ~\(String(format: "%.1f", memoryMB)) MB
        """
    }
}

// MARK: - Notification Extension

extension NSApplication {
    static let didReceiveMemoryWarningNotification = NSNotification.Name("NSApplicationDidReceiveMemoryWarning")
}
