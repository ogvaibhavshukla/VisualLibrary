//
//  SelectionManager.swift
//  MoodBoardFeature
//
//  Manages item selection state and multi-selection behavior
//

import AppKit
import Foundation

/// Manages selection state and operations for mood board items
class SelectionManager {

    // MARK: - Properties

    /// Reference to the canvas state
    weak var canvasState: CanvasState?

    /// Currently selected item IDs
    private(set) var selectedIDs: Set<UUID> = []

    /// Selection changed callback
    var onSelectionChanged: (() -> Void)?

    /// Whether marquee selection is active
    private(set) var isMarqueeSelectionActive = false

    /// Marquee selection rect
    private(set) var marqueeRect: CGRect?

    // MARK: - Initialization

    init(canvasState: CanvasState) {
        self.canvasState = canvasState
    }

    // MARK: - Selection Operations

    /// Select a single item
    /// - Parameters:
    ///   - item: The item to select
    ///   - addToSelection: Whether to add to existing selection or replace it
    func select(_ item: MoodBoardItem, addToSelection: Bool = false) {
        if !addToSelection {
            clearSelection()
        }

        item.isSelected = true
        selectedIDs.insert(item.id)
        notifySelectionChanged()
    }

    /// Select multiple items
    /// - Parameters:
    ///   - items: Items to select
    ///   - addToSelection: Whether to add to existing selection or replace it
    func selectMultiple(_ items: [MoodBoardItem], addToSelection: Bool = false) {
        if !addToSelection {
            clearSelection()
        }

        items.forEach { item in
            item.isSelected = true
            selectedIDs.insert(item.id)
        }

        notifySelectionChanged()
    }

    /// Deselect an item
    /// - Parameter item: The item to deselect
    func deselect(_ item: MoodBoardItem) {
        item.isSelected = false
        selectedIDs.remove(item.id)
        notifySelectionChanged()
    }

    /// Toggle selection of an item
    /// - Parameter item: The item to toggle
    func toggleSelection(_ item: MoodBoardItem) {
        if item.isSelected {
            deselect(item)
        } else {
            select(item, addToSelection: true)
        }
    }

    /// Clear all selections
    func clearSelection() {
        guard let canvasState = canvasState else { return }

        canvasState.items.forEach { $0.isSelected = false }
        selectedIDs.removeAll()
        notifySelectionChanged()
    }

    /// Select all items
    func selectAll() {
        guard let canvasState = canvasState else { return }

        canvasState.items.forEach { item in
            item.isSelected = true
            selectedIDs.insert(item.id)
        }

        notifySelectionChanged()
    }

    /// Get all selected items
    var selectedItems: [MoodBoardItem] {
        guard let canvasState = canvasState else { return [] }
        return canvasState.items.filter { selectedIDs.contains($0.id) }
    }

    /// Get the primary selected item (for single selection operations)
    var primarySelectedItem: MoodBoardItem? {
        return selectedItems.first
    }

    /// Check if any items are selected
    var hasSelection: Bool {
        return !selectedIDs.isEmpty
    }

    /// Get selection count
    var selectionCount: Int {
        return selectedIDs.count
    }

    // MARK: - Marquee Selection

    /// Start marquee selection
    /// - Parameter startPoint: Starting point of the marquee
    func beginMarqueeSelection(at startPoint: CGPoint) {
        isMarqueeSelectionActive = true
        marqueeRect = CGRect(origin: startPoint, size: .zero)
    }

    /// Update marquee selection
    /// - Parameter currentPoint: Current mouse position
    func updateMarqueeSelection(to currentPoint: CGPoint) {
        guard isMarqueeSelectionActive,
              let startPoint = marqueeRect?.origin else { return }

        // Calculate rect from start point to current point
        let minX = min(startPoint.x, currentPoint.x)
        let minY = min(startPoint.y, currentPoint.y)
        let maxX = max(startPoint.x, currentPoint.x)
        let maxY = max(startPoint.y, currentPoint.y)

        marqueeRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        // Update selection based on marquee rect
        updateSelectionFromMarquee()
    }

    /// End marquee selection
    func endMarqueeSelection() {
        isMarqueeSelectionActive = false
        marqueeRect = nil
    }

    /// Update which items are selected based on current marquee rect
    private func updateSelectionFromMarquee() {
        guard let rect = marqueeRect,
              let canvasState = canvasState else { return }

        // Find items intersecting with marquee
        let intersectingItems = canvasState.items.filter { item in
            item.frame.intersects(rect)
        }

        // Update selection
        selectedIDs.removeAll()
        intersectingItems.forEach { item in
            item.isSelected = true
            selectedIDs.insert(item.id)
        }

        // Clear selection for non-intersecting items
        canvasState.items.forEach { item in
            if !intersectingItems.contains(where: { $0.id == item.id }) {
                item.isSelected = false
            }
        }

        notifySelectionChanged()
    }

    // MARK: - Selection Bounds

    /// Get the bounding rect that contains all selected items
    var selectionBounds: CGRect? {
        let items = selectedItems
        guard !items.isEmpty else { return nil }

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        items.forEach { item in
            let frame = item.frame
            minX = min(minX, frame.minX)
            minY = min(minY, frame.minY)
            maxX = max(maxX, frame.maxX)
            maxY = max(maxY, frame.maxY)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Get the center point of the selection
    var selectionCenter: CGPoint? {
        guard let bounds = selectionBounds else { return nil }
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Helpers

    private func notifySelectionChanged() {
        onSelectionChanged?()
    }
}
