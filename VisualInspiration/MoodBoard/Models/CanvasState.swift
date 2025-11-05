//
//  CanvasState.swift
//  MoodBoardFeature
//
//  Manages the state of the mood board canvas
//

import Foundation
import CoreGraphics

/// Represents the complete state of the mood board canvas
class CanvasState: Codable {

    // MARK: - Properties

    /// All items on the canvas
    var items: [MoodBoardItem] = []

    /// Current canvas bounds (grows dynamically)
    var canvasBounds: CGSize

    /// Current zoom level (1.0 = 100%)
    var zoomLevel: CGFloat = 1.0

    /// Scroll offset (viewport position)
    var scrollOffset: CGPoint = .zero

    /// Next available z-index
    private var nextZIndex: Int = 0

    /// Creation date
    let createdAt: Date

    /// Last modified date
    var modifiedAt: Date

    // MARK: - Initialization

    init(initialBounds: CGSize = CGSize(width: 10000, height: 10000)) {
        self.canvasBounds = initialBounds
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Item Management

    /// Add a new item to the canvas
    func addItem(_ item: MoodBoardItem) {
        item.zIndex = nextZIndex
        nextZIndex += 1
        items.append(item)
        markAsModified()
    }

    /// Remove an item from the canvas
    func removeItem(_ item: MoodBoardItem) {
        items.removeAll { $0.id == item.id }
        markAsModified()
    }

    /// Remove items by IDs
    func removeItems(withIDs ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
        markAsModified()
    }

    /// Get item by ID
    func item(withID id: UUID) -> MoodBoardItem? {
        return items.first { $0.id == id }
    }

    /// Get all selected items
    var selectedItems: [MoodBoardItem] {
        return items.filter { $0.isSelected }
    }

    /// Clear all selections
    func clearSelection() {
        items.forEach { $0.isSelected = false }
    }

    // MARK: - Layer Management

    /// Bring item to front
    func bringToFront(_ item: MoodBoardItem) {
        item.zIndex = nextZIndex
        nextZIndex += 1
        item.markAsModified()
        markAsModified()
    }

    /// Send item to back
    func sendToBack(_ item: MoodBoardItem) {
        // Find the minimum z-index
        let minZ = items.map { $0.zIndex }.min() ?? 0
        item.zIndex = minZ - 1
        item.markAsModified()
        markAsModified()
    }

    /// Bring item forward one level
    func bringForward(_ item: MoodBoardItem) {
        let sortedItems = items.sorted { $0.zIndex < $1.zIndex }
        guard let currentIndex = sortedItems.firstIndex(where: { $0.id == item.id }),
              currentIndex < sortedItems.count - 1 else {
            return
        }

        let nextItem = sortedItems[currentIndex + 1]
        let tempZ = item.zIndex
        item.zIndex = nextItem.zIndex
        nextItem.zIndex = tempZ

        item.markAsModified()
        nextItem.markAsModified()
        markAsModified()
    }

    /// Send item backward one level
    func sendBackward(_ item: MoodBoardItem) {
        let sortedItems = items.sorted { $0.zIndex < $1.zIndex }
        guard let currentIndex = sortedItems.firstIndex(where: { $0.id == item.id }),
              currentIndex > 0 else {
            return
        }

        let prevItem = sortedItems[currentIndex - 1]
        let tempZ = item.zIndex
        item.zIndex = prevItem.zIndex
        prevItem.zIndex = tempZ

        item.markAsModified()
        prevItem.markAsModified()
        markAsModified()
    }

    /// Get items sorted by z-index (back to front)
    var itemsSortedByZIndex: [MoodBoardItem] {
        return items.sorted { $0.zIndex < $1.zIndex }
    }

    // MARK: - Canvas Bounds Management

    /// Expand canvas bounds if needed based on a point
    func expandCanvasIfNeeded(toInclude point: CGPoint, threshold: CGFloat = 500) {
        var newBounds = canvasBounds
        var didExpand = false

        // Expand right
        if point.x > canvasBounds.width - threshold {
            newBounds.width = max(newBounds.width, point.x + 5000)
            didExpand = true
        }

        // Expand bottom
        if point.y > canvasBounds.height - threshold {
            newBounds.height = max(newBounds.height, point.y + 5000)
            didExpand = true
        }

        // Expand left (negative coordinates)
        if point.x < threshold && point.x >= 0 {
            // For simplicity, we'll keep origin at (0,0) for now
            // In a more advanced implementation, you could shift all items
        }

        if didExpand {
            canvasBounds = newBounds
            markAsModified()
        }
    }

    /// Expand canvas based on visible rect
    func expandCanvasIfNeeded(forVisibleRect rect: CGRect, threshold: CGFloat = 500) {
        var newBounds = canvasBounds
        var didExpand = false

        // Check right edge
        if rect.maxX > canvasBounds.width - threshold {
            newBounds.width += 5000
            didExpand = true
        }

        // Check bottom edge
        if rect.maxY > canvasBounds.height - threshold {
            newBounds.height += 5000
            didExpand = true
        }

        if didExpand {
            canvasBounds = newBounds
            markAsModified()
        }
    }

    // MARK: - Hit Testing

    /// Find the topmost item at a given point
    func hitTest(at point: CGPoint) -> MoodBoardItem? {
        // Test from front to back (reverse z-index order)
        let sortedItems = itemsSortedByZIndex.reversed()
        return sortedItems.first { $0.containsPoint(point) }
    }

    /// Find all items in a given rect
    func items(in rect: CGRect) -> [MoodBoardItem] {
        return items.filter { $0.frame.intersects(rect) }
    }

    // MARK: - Helpers

    private func markAsModified() {
        modifiedAt = Date()
    }

    /// Get statistics about the canvas
    var statistics: String {
        return """
        Canvas Statistics:
        - Items: \(items.count)
        - Bounds: \(Int(canvasBounds.width)) x \(Int(canvasBounds.height))
        - Zoom: \(Int(zoomLevel * 100))%
        - Selected: \(selectedItems.count)
        """
    }
}
