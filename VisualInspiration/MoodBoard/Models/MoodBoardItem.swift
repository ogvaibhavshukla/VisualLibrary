//
//  MoodBoardItem.swift
//  MoodBoardFeature
//
//  Model representing a single image item on the mood board canvas
//

import AppKit
import QuartzCore

/// Represents a single image item on the mood board with all its properties
class MoodBoardItem: Identifiable, Codable {

    // MARK: - Properties

    /// Unique identifier for the item
    let id: UUID

    /// The original image
    var image: NSImage?

    /// Thumbnail version for display (memory efficient)
    var thumbnail: NSImage?

    /// Position on the infinite canvas (top-left corner)
    var position: CGPoint

    /// Size of the item (can differ from original image size)
    var size: CGSize

    /// Rotation angle in radians
    var rotation: CGFloat

    /// Z-index for layering (higher = on top)
    var zIndex: Int

    /// Path to the original image file (for persistence)
    var imagePath: String?

    /// The CALayer used to render this item
    var layer: CALayer?

    /// Original image size (preserved for reference)
    let originalSize: CGSize

    /// Timestamp when item was created
    let createdAt: Date

    /// Timestamp of last modification
    var modifiedAt: Date

    /// Whether this item is currently selected
    var isSelected: Bool = false

    // MARK: - Initialization

    init(image: NSImage, position: CGPoint, size: CGSize? = nil) {
        self.id = UUID()
        self.image = image
        self.originalSize = image.size
        self.position = position
        self.size = size ?? image.size
        self.rotation = 0
        self.zIndex = 0
        self.createdAt = Date()
        self.modifiedAt = Date()

        // Generate thumbnail on creation
        self.thumbnail = MoodBoardItem.generateThumbnail(from: image, maxSize: 2048)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, imagePath, position, size, rotation, zIndex
        case originalSize, createdAt, modifiedAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        rotation = try container.decode(CGFloat.self, forKey: .rotation)
        zIndex = try container.decode(Int.self, forKey: .zIndex)
        originalSize = try container.decode(CGSize.self, forKey: .originalSize)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)

        // Load image from path if available
        if let path = imagePath {
            image = NSImage(contentsOfFile: path)
            if let img = image {
                thumbnail = MoodBoardItem.generateThumbnail(from: img, maxSize: 2048)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(zIndex, forKey: .zIndex)
        try container.encode(originalSize, forKey: .originalSize)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }

    // MARK: - Helper Methods

    /// Returns the bounding rect of this item in canvas coordinates
    var frame: CGRect {
        return CGRect(origin: position, size: size)
    }

    /// Returns the center point of this item
    var center: CGPoint {
        return CGPoint(x: position.x + size.width / 2,
                      y: position.y + size.height / 2)
    }

    /// Update modification timestamp
    func markAsModified() {
        modifiedAt = Date()
    }

    /// Generate a thumbnail from an image
    static func generateThumbnail(from image: NSImage, maxSize: CGFloat) -> NSImage {
        let originalSize = image.size

        // If image is already small enough, return original
        if originalSize.width <= maxSize && originalSize.height <= maxSize {
            return image
        }

        // Calculate thumbnail size maintaining aspect ratio
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height)
        let thumbnailSize = CGSize(width: originalSize.width * scale,
                                  height: originalSize.height * scale)

        // Create thumbnail
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: CGRect(origin: .zero, size: thumbnailSize),
                   from: CGRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)

        thumbnail.unlockFocus()
        return thumbnail
    }

    /// Check if a point hits this item (accounts for rotation)
    func containsPoint(_ point: CGPoint) -> Bool {
        // Simple rect-based hit test (for now, without rotation)
        // TODO: Implement proper hit test with rotation transform
        let rect = frame
        return rect.contains(point)
    }
}

// MARK: - Codable Extensions for CoreGraphics Types

extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(CGFloat.self)
        let y = try container.decode(CGFloat.self)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}

extension CGSize: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let width = try container.decode(CGFloat.self)
        let height = try container.decode(CGFloat.self)
        self.init(width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(width)
        try container.encode(height)
    }
}
