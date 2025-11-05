//
//  CanvasViewModel.swift
//  MoodBoardFeature
//
//  View model for managing canvas state and business logic
//

import AppKit
import Combine

/// View model that manages the mood board canvas state and operations
class CanvasViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var canvasState: CanvasState

    /// Current selection
    @Published var selectedItemIDs: Set<UUID> = []

    /// Whether a drag operation is in progress
    @Published var isDragging: Bool = false

    /// Whether a resize operation is in progress
    @Published var isResizing: Bool = false

    // MARK: - Properties

    /// Undo manager for undo/redo support
    let undoManager: UndoManager

    /// Persistence manager for auto-save
    private let persistenceManager: PersistenceManager

    /// Auto-save cancellable
    private var autoSaveCancellable: AnyCancellable?

    /// Drag state
    private var dragStartPoint: CGPoint?
    private var draggedItemsOriginalPositions: [UUID: CGPoint] = [:]

    // MARK: - Initialization

    init(canvasState: CanvasState = CanvasState(), undoManager: UndoManager = UndoManager(), persistenceManager: PersistenceManager = PersistenceManager()) {
        self.canvasState = canvasState
        self.undoManager = undoManager
        self.persistenceManager = persistenceManager

        // Setup auto-save with debounce
        setupAutoSave()
    }

    // MARK: - Auto-Save

    /// Setup auto-save functionality with debounce
    private func setupAutoSave() {
        autoSaveCancellable = objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveCanvas()
            }
    }

    /// Save canvas state to disk
    private func saveCanvas() {
        persistenceManager.save(canvasState)
    }

    // MARK: - Item Management

    /// Add a new item to the canvas
    func addItem(_ item: MoodBoardItem) {
        // Register undo
        undoManager.registerUndo(withTarget: self) { viewModel in
            viewModel.removeItem(item)
        }
        undoManager.setActionName("Add Image")

        canvasState.addItem(item)
        objectWillChange.send()
    }

    /// Remove an item from the canvas
    func removeItem(_ item: MoodBoardItem) {
        let capturedItem = item
        let capturedPosition = canvasState.items.firstIndex { $0.id == item.id }

        // Register undo
        undoManager.registerUndo(withTarget: self) { viewModel in
            viewModel.canvasState.items.insert(capturedItem, at: capturedPosition ?? 0)
            viewModel.objectWillChange.send()
        }
        undoManager.setActionName("Delete Image")

        canvasState.removeItem(item)
        selectedItemIDs.remove(item.id)
        objectWillChange.send()
    }

    /// Remove all selected items
    func removeSelectedItems() {
        let itemsToRemove = canvasState.selectedItems
        guard !itemsToRemove.isEmpty else { return }

        // Capture state for undo
        let capturedItems = itemsToRemove

        // Register undo
        undoManager.registerUndo(withTarget: self) { viewModel in
            capturedItems.forEach { item in
                viewModel.canvasState.addItem(item)
            }
            viewModel.objectWillChange.send()
        }
        undoManager.setActionName("Delete Images")

        canvasState.removeItems(withIDs: Set(itemsToRemove.map { $0.id }))
        selectedItemIDs.removeAll()
        objectWillChange.send()
    }

    /// Clear all items from canvas
    func clearAll() {
        let itemsToRemove = canvasState.items
        guard !itemsToRemove.isEmpty else { return }

        // Capture state for undo
        let capturedItems = Array(itemsToRemove)

        // Register undo
        undoManager.registerUndo(withTarget: self) { viewModel in
            capturedItems.forEach { item in
                viewModel.canvasState.addItem(item)
            }
            viewModel.objectWillChange.send()
        }
        undoManager.setActionName("Clear All")

        // Clear all items and selection
        canvasState.items.removeAll()
        selectedItemIDs.removeAll()

        // Force UI update
        objectWillChange.send()
    }

    // MARK: - Selection Management

    /// Select a single item
    func selectItem(_ item: MoodBoardItem, addToSelection: Bool = false) {
        if !addToSelection {
            canvasState.clearSelection()
            selectedItemIDs.removeAll()
        }

        item.isSelected = true
        selectedItemIDs.insert(item.id)
        objectWillChange.send()
    }

    /// Deselect an item
    func deselectItem(_ item: MoodBoardItem) {
        item.isSelected = false
        selectedItemIDs.remove(item.id)
        objectWillChange.send()
    }

    /// Clear all selections
    func clearSelection() {
        canvasState.clearSelection()
        selectedItemIDs.removeAll()
        objectWillChange.send()
    }

    /// Select all items
    func selectAll() {
        canvasState.items.forEach { $0.isSelected = true }
        selectedItemIDs = Set(canvasState.items.map { $0.id })
        objectWillChange.send()
    }

    // MARK: - Drag Operations

    /// Begin dragging selected items
    func beginDrag(at point: CGPoint) {
        guard !selectedItemIDs.isEmpty else { return }

        isDragging = true
        dragStartPoint = point

        // Capture original positions
        draggedItemsOriginalPositions.removeAll()
        canvasState.selectedItems.forEach { item in
            draggedItemsOriginalPositions[item.id] = item.position
        }
    }

    /// Update drag operation
    func updateDrag(to point: CGPoint) {
        guard isDragging,
              let startPoint = dragStartPoint else { return }

        let delta = CGPoint(x: point.x - startPoint.x,
                           y: point.y - startPoint.y)

        canvasState.selectedItems.forEach { item in
            if let originalPos = draggedItemsOriginalPositions[item.id] {
                item.position = CGPoint(x: originalPos.x + delta.x,
                                       y: originalPos.y + delta.y)
                item.markAsModified()

                // Expand canvas if needed
                canvasState.expandCanvasIfNeeded(toInclude: item.position)
            }
        }

        objectWillChange.send()
    }

    /// End drag operation
    func endDrag() {
        guard isDragging else { return }

        // Register undo
        let capturedOriginalPositions = draggedItemsOriginalPositions
        let capturedItemIDs = selectedItemIDs

        undoManager.registerUndo(withTarget: self) { viewModel in
            capturedItemIDs.forEach { itemID in
                if let item = viewModel.canvasState.item(withID: itemID),
                   let originalPos = capturedOriginalPositions[itemID] {
                    item.position = originalPos
                    item.markAsModified()
                }
            }
            viewModel.objectWillChange.send()
        }
        undoManager.setActionName("Move")

        isDragging = false
        dragStartPoint = nil
        draggedItemsOriginalPositions.removeAll()
        objectWillChange.send()
    }

    // MARK: - Transform Operations

    /// Resize an item
    func resizeItem(_ item: MoodBoardItem, to newSize: CGSize) {
        let oldSize = item.size

        // Register undo
        undoManager.registerUndo(withTarget: self) { viewModel in
            item.size = oldSize
            item.markAsModified()
            viewModel.objectWillChange.send()
        }
        undoManager.setActionName("Resize")

        item.size = newSize
        item.markAsModified()
        objectWillChange.send()
    }

    /// Rotate an item
    func rotateItem(_ item: MoodBoardItem, by angle: CGFloat) {
        let oldRotation = item.rotation
        let newRotation = oldRotation + angle

        // Register undo
        undoManager.registerUndo(withTarget: self) { viewModel in
            item.rotation = oldRotation
            item.markAsModified()
            viewModel.objectWillChange.send()
        }
        undoManager.setActionName("Rotate")

        item.rotation = newRotation
        item.markAsModified()
        objectWillChange.send()
    }

    // MARK: - Layer Management

    /// Bring selected items to front
    func bringToFront() {
        canvasState.selectedItems.forEach { canvasState.bringToFront($0) }
        undoManager.setActionName("Bring to Front")
        objectWillChange.send()
    }

    /// Send selected items to back
    func sendToBack() {
        canvasState.selectedItems.forEach { canvasState.sendToBack($0) }
        undoManager.setActionName("Send to Back")
        objectWillChange.send()
    }

    // MARK: - Helpers

    /// Get item at a specific point (for hit testing)
    func hitTest(at point: CGPoint) -> MoodBoardItem? {
        return canvasState.hitTest(at: point)
    }
}
