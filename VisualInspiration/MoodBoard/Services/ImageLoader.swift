//
//  ImageLoader.swift
//  MoodBoardFeature
//
//  Handles asynchronous image loading and thumbnail generation
//

import AppKit
import Foundation

/// Manages async image loading with thumbnail generation
class ImageLoader {

    // MARK: - Singleton

    static let shared = ImageLoader()

    // MARK: - Properties

    /// Cache for loaded images
    private let cache = ImageCache.shared

    /// Operation queue for image loading
    private let loadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.moodboard.imageloader"
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// Thumbnail generation queue
    private let thumbnailQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.moodboard.thumbnails"
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .utility
        return queue
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Load an image asynchronously from a URL
    /// - Parameters:
    ///   - url: The file URL to load from
    ///   - completion: Called with the loaded image or error
    func loadImage(from url: URL, completion: @escaping (Result<NSImage, Error>) -> Void) {
        // Check cache first
        if let cachedImage = cache.getImage(forKey: url.path) {
            completion(.success(cachedImage))
            return
        }

        // Load in background
        loadQueue.addOperation {
            autoreleasepool {
                do {
                    guard let image = NSImage(contentsOf: url) else {
                        throw ImageLoaderError.invalidImage
                    }

                    // Cache the loaded image
                    self.cache.setImage(image, forKey: url.path)

                    DispatchQueue.main.async {
                        completion(.success(image))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    /// Generate a thumbnail asynchronously
    /// - Parameters:
    ///   - image: The source image
    ///   - maxSize: Maximum dimension for the thumbnail
    ///   - completion: Called with the generated thumbnail
    func generateThumbnail(
        from image: NSImage,
        maxSize: CGFloat = 2048,
        completion: @escaping (NSImage) -> Void
    ) {
        let cacheKey = "thumb_\(ObjectIdentifier(image).hashValue)_\(Int(maxSize))"

        // Check cache
        if let cachedThumbnail = cache.getThumbnail(forKey: cacheKey) {
            completion(cachedThumbnail)
            return
        }

        thumbnailQueue.addOperation {
            autoreleasepool {
                let thumbnail = self.createThumbnail(from: image, maxSize: maxSize)

                // Cache thumbnail
                self.cache.setThumbnail(thumbnail, forKey: cacheKey)

                DispatchQueue.main.async {
                    completion(thumbnail)
                }
            }
        }
    }

    /// Load image and generate thumbnail asynchronously
    /// - Parameters:
    ///   - url: The file URL to load from
    ///   - maxThumbnailSize: Maximum dimension for thumbnail
    ///   - completion: Called with original image and thumbnail
    func loadImageWithThumbnail(
        from url: URL,
        maxThumbnailSize: CGFloat = 2048,
        completion: @escaping (Result<(image: NSImage, thumbnail: NSImage), Error>) -> Void
    ) {
        loadImage(from: url) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let image):
                self.generateThumbnail(from: image, maxSize: maxThumbnailSize) { thumbnail in
                    completion(.success((image: image, thumbnail: thumbnail)))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Batch load multiple images
    /// - Parameters:
    ///   - urls: Array of file URLs
    ///   - progressHandler: Called for each loaded image with index and total
    ///   - completion: Called when all images are loaded
    func loadImages(
        from urls: [URL],
        progressHandler: @escaping (Int, Int, NSImage) -> Void,
        completion: @escaping ([NSImage]) -> Void
    ) {
        var loadedImages: [Int: NSImage] = [:]
        let group = DispatchGroup()
        let lock = NSLock()

        for (index, url) in urls.enumerated() {
            group.enter()

            loadImage(from: url) { result in
                defer { group.leave() }

                if case .success(let image) = result {
                    lock.lock()
                    loadedImages[index] = image
                    lock.unlock()

                    DispatchQueue.main.async {
                        progressHandler(index + 1, urls.count, image)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            // Sort by index to maintain order
            let sortedImages = loadedImages.sorted { $0.key < $1.key }.map { $0.value }
            completion(sortedImages)
        }
    }

    // MARK: - Helper Methods

    /// Create a thumbnail from an image (synchronous)
    private func createThumbnail(from image: NSImage, maxSize: CGFloat) -> NSImage {
        let originalSize = image.size

        // If image is small enough, return copy
        if originalSize.width <= maxSize && originalSize.height <= maxSize {
            return image.copy() as! NSImage
        }

        // Calculate thumbnail size maintaining aspect ratio
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height)
        let thumbnailSize = CGSize(
            width: floor(originalSize.width * scale),
            height: floor(originalSize.height * scale)
        )

        // Create high-quality thumbnail
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()

        // Use high quality interpolation
        NSGraphicsContext.current?.imageInterpolation = .high

        // Draw scaled image
        image.draw(
            in: CGRect(origin: .zero, size: thumbnailSize),
            from: CGRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )

        thumbnail.unlockFocus()
        return thumbnail
    }

    /// Cancel all pending operations
    func cancelAll() {
        loadQueue.cancelAllOperations()
        thumbnailQueue.cancelAllOperations()
    }

    /// Get supported image file extensions
    static var supportedImageExtensions: Set<String> {
        return ["png", "jpg", "jpeg", "tiff", "tif", "gif", "bmp", "heic", "heif", "webp"]
    }

    /// Check if a URL points to a supported image file
    static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supportedImageExtensions.contains(ext)
    }
}

// MARK: - Errors

enum ImageLoaderError: Error, LocalizedError {
    case invalidImage
    case fileNotFound
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The file is not a valid image"
        case .fileNotFound:
            return "Image file not found"
        case .loadFailed(let reason):
            return "Failed to load image: \(reason)"
        }
    }
}
