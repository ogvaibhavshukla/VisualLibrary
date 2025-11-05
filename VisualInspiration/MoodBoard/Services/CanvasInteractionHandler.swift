//
//  CanvasInteractionHandler.swift
//  MoodBoardFeature
//
//  Coordinates mouse and keyboard interactions for the canvas
//

import AppKit
import QuartzCore

/// Manages all user interactions with the canvas
class CanvasInteractionHandler {

    // MARK: - Interaction State

    enum InteractionMode {
        case none
        case dragging
        case resizing(handle: HandleType, anchor: CGPoint)
        case rotating(center: CGPoint)
        case marqueeSelection
    }

    // MARK: - Properties

    /// Reference to the canvas view
    weak var canvasView: MoodBoardCanvasView?

    /// View model
    weak var viewModel: CanvasViewModel?

    /// Selection manager
    let selectionManager: SelectionManager

    /// Transform handles for selected items
    private var transformHandles: TransformHandles?

    /// Current interaction mode
    private(set) var currentMode: InteractionMode = .none

    /// Mouse down point
    private var mouseDownPoint: CGPoint?

    /// Original item states for undo
    private var dragStartPositions: [UUID: CGPoint] = [:]
    private var resizeStartFrame: CGRect?
    private var rotationStartAngle: CGFloat = 0

    // MARK: - Initialization

    init(canvasView: MoodBoardCanvasView, viewModel: CanvasViewModel) {
        self.canvasView = canvasView
        self.viewModel = viewModel
        self.selectionManager = SelectionManager(canvasState: viewModel.canvasState)

        setupCallbacks()
    }

    private func setupCallbacks() {
        selectionManager.onSelectionChanged = { [weak self] in
            self?.updateTransformHandles()
        }
    }

    // MARK: - Mouse Event Handling

    func handleMouseDown(at point: CGPoint, modifiers: NSEvent.ModifierFlags) {
        mouseDownPoint = point

        // Check if clicking on transform handle
        if let handle = transformHandles?.hitTest(at: point) {
            handleHandleMouseDown(handle: handle, at: point)
            return
        }

        // Hit test for items
        if let hitItem = viewModel?.hitTest(at: point) {
            handleItemMouseDown(item: hitItem, at: point, modifiers: modifiers)
        } else {
            handleEmptySpaceMouseDown(at: point, modifiers: modifiers)
        }
    }

    func handleMouseDragged(to point: CGPoint, modifiers: NSEvent.ModifierFlags) {
        guard let startPoint = mouseDownPoint else { return }

        switch currentMode {
        case .none:
            // Start dragging if we have selection and moved enough
            if selectionManager.hasSelection {
                let distance = hypot(point.x - startPoint.x, point.y - startPoint.y)
                if distance > 3 { // 3pt threshold
                    beginDragging(from: startPoint)
                    updateDragging(to: point)
                }
            } else {
                // Start marquee selection
                beginMarqueeSelection(from: startPoint)
                updateMarqueeSelection(to: point)
            }

        case .dragging:
            updateDragging(to: point)

        case .resizing(let handle, let anchor):
            updateResizing(to: point, handle: handle, anchor: anchor, modifiers: modifiers)

        case .rotating(let center):
            updateRotating(to: point, center: center)

        case .marqueeSelection:
            updateMarqueeSelection(to: point)
        }

        canvasView?.updateAllLayers()
    }

    func handleMouseUp(at point: CGPoint) {
        switch currentMode {
        case .dragging:
            endDragging()

        case .resizing:
            endResizing()

        case .rotating:
            endRotating()

        case .marqueeSelection:
            endMarqueeSelection()

        case .none:
            break
        }

        currentMode = .none
        mouseDownPoint = nil
        canvasView?.updateAllLayers()
    }

    // MARK: - Item Interaction

    private func handleItemMouseDown(item: MoodBoardItem, at point: CGPoint, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            // Toggle selection
            selectionManager.toggleSelection(item)
        } else {
            // Select item (replace selection if not already selected)
            if !item.isSelected {
                selectionManager.select(item, addToSelection: false)
            }
        }
    }

    private func handleEmptySpaceMouseDown(at point: CGPoint, modifiers: NSEvent.ModifierFlags) {
        if !modifiers.contains(.command) {
            selectionManager.clearSelection()
        }
    }

    private func handleHandleMouseDown(handle: HandleType, at point: CGPoint) {
        guard let selectedItem = selectionManager.primarySelectedItem else { return }

        switch handle {
        case .rotation:
            beginRotating(center: selectedItem.center, from: point)

        default:
            // Resize handle
            if let anchor = transformHandles?.oppositeHandle(for: handle) {
                beginResizing(handle: handle, anchor: anchor, item: selectedItem)
            }
        }
    }

    // MARK: - Dragging

    private func beginDragging(from point: CGPoint) {
        currentMode = .dragging

        // Save original positions
        dragStartPositions.removeAll()
        selectionManager.selectedItems.forEach { item in
            dragStartPositions[item.id] = item.position
        }

        viewModel?.beginDrag(at: point)
    }

    private func updateDragging(to point: CGPoint) {
        viewModel?.updateDrag(to: point)
        updateTransformHandles()
    }

    private func endDragging() {
        viewModel?.endDrag()
        dragStartPositions.removeAll()
    }

    // MARK: - Resizing

    private func beginResizing(handle: HandleType, anchor: CGPoint, item: MoodBoardItem) {
        currentMode = .resizing(handle: handle, anchor: anchor)
        resizeStartFrame = item.frame
    }

    private func updateResizing(to point: CGPoint, handle: HandleType, anchor: CGPoint, modifiers: NSEvent.ModifierFlags) {
        guard let selectedItem = selectionManager.primarySelectedItem,
              let startFrame = resizeStartFrame else { return }

        // Check if Shift is held (maintain aspect ratio)
        let maintainAspectRatio = modifiers.contains(.shift)
        let aspectRatio = startFrame.width / startFrame.height

        // Calculate new frame
        let newFrame = ResizeCalculator.calculateNewFrame(
            currentPoint: point,
            handleType: handle,
            anchorPoint: anchor,
            maintainAspectRatio: maintainAspectRatio,
            originalAspectRatio: aspectRatio
        )

        // Update item
        selectedItem.position = newFrame.origin
        selectedItem.size = newFrame.size
        selectedItem.markAsModified()

        updateTransformHandles()
    }

    private func endResizing() {
        guard let selectedItem = selectionManager.primarySelectedItem,
              let startFrame = resizeStartFrame else { return }

        // Register undo
        let finalSize = selectedItem.size
        let finalPosition = selectedItem.position

        viewModel?.undoManager.registerUndo(withTarget: selectedItem) { item in
            item.size = startFrame.size
            item.position = startFrame.origin
            item.markAsModified()
        }
        viewModel?.undoManager.setActionName("Resize")

        resizeStartFrame = nil
    }

    // MARK: - Rotation

    private func beginRotating(center: CGPoint, from point: CGPoint) {
        currentMode = .rotating(center: center)

        if let selectedItem = selectionManager.primarySelectedItem {
            rotationStartAngle = selectedItem.rotation
        }
    }

    private func updateRotating(to point: CGPoint, center: CGPoint) {
        guard let selectedItem = selectionManager.primarySelectedItem else { return }

        let angle = ResizeCalculator.calculateRotation(from: point, center: center)
        selectedItem.rotation = angle
        selectedItem.markAsModified()

        updateTransformHandles()
    }

    private func endRotating() {
        guard let selectedItem = selectionManager.primarySelectedItem else { return }

        let finalRotation = selectedItem.rotation

        viewModel?.undoManager.registerUndo(withTarget: selectedItem) { item in
            item.rotation = self.rotationStartAngle
            item.markAsModified()
        }
        viewModel?.undoManager.setActionName("Rotate")
    }

    // MARK: - Marquee Selection

    private func beginMarqueeSelection(from point: CGPoint) {
        currentMode = .marqueeSelection
        selectionManager.beginMarqueeSelection(at: point)
    }

    private func updateMarqueeSelection(to point: CGPoint) {
        selectionManager.updateMarqueeSelection(to: point)
    }

    private func endMarqueeSelection() {
        selectionManager.endMarqueeSelection()
    }

    // MARK: - Transform Handles

    private func updateTransformHandles() {
        // Remove existing handles
        transformHandles?.removeFromSuperlayer()
        transformHandles = nil

        // Create handles for selected item (single selection only for now)
        if selectionManager.selectionCount == 1,
           let selectedItem = selectionManager.primarySelectedItem {

            let handles = TransformHandles(item: selectedItem)

            if let canvasLayer = canvasView?.layer {
                canvasLayer.addSublayer(handles.containerLayer)
                handles.show()
                transformHandles = handles
            }
        }
    }

    /// Get the marquee rect for drawing
    var marqueeRect: CGRect? {
        return selectionManager.marqueeRect
    }

    // MARK: - Keyboard Handling

    func handleKeyDown(event: NSEvent) -> Bool {
        guard let characters = event.charactersIgnoringModifiers else { return false }

        switch characters {
        case String(Character(UnicodeScalar(NSDeleteCharacter)!)),
             String(Character(UnicodeScalar(NSBackspaceCharacter)!)):
            deleteSelection()
            return true

        case "a", "A":
            if event.modifierFlags.contains(.command) {
                selectionManager.selectAll()
                canvasView?.updateAllLayers()
                return true
            }

        default:
            break
        }

        return false
    }

    private func deleteSelection() {
        let itemsToDelete = selectionManager.selectedItems

        itemsToDelete.forEach { item in
            canvasView?.removeLayer(for: item)
        }

        viewModel?.removeSelectedItems()
        transformHandles?.removeFromSuperlayer()
        transformHandles = nil

        canvasView?.updateAllLayers()
    }

    // MARK: - Context Menu

    func menuForSelection() -> NSMenu? {
        guard selectionManager.hasSelection else { return nil }

        let menu = NSMenu()

        // Delete
        menu.addItem(withTitle: "Delete", action: #selector(handleDelete), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        // Bring to Front / Send to Back
        menu.addItem(withTitle: "Bring to Front", action: #selector(handleBringToFront), keyEquivalent: "")
        menu.addItem(withTitle: "Send to Back", action: #selector(handleSendToBack), keyEquivalent: "")

        return menu
    }

    @objc private func handleDelete() {
        deleteSelection()
    }

    @objc private func handleBringToFront() {
        viewModel?.bringToFront()
        canvasView?.updateAllLayers()
    }

    @objc private func handleSendToBack() {
        viewModel?.sendToBack()
        canvasView?.updateAllLayers()
    }
}
