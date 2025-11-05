//
//  MoodBoardCanvasView.swift
//  MoodBoardFeature
//
//  Custom NSView that implements the infinite canvas for mood board items
//

import AppKit
import QuartzCore

/// Custom view that renders the mood board canvas with drag & drop support
class MoodBoardCanvasView: NSView {

    // MARK: - Properties

    /// View model managing the canvas state
    var viewModel: CanvasViewModel

    /// Layers dictionary for quick lookup
    private var itemLayers: [UUID: CALayer] = [:]

    /// Current mouse tracking state
    private var trackingArea: NSTrackingArea?

    /// Selection layer for visual feedback
    private var selectionLayer: CALayer?

    /// Visible rect with buffer for culling calculations
    private var visibleRectWithBuffer: CGRect = .zero

    /// Transform handles for selected items
    private var transformHandles: TransformHandles?

    /// Current zoom scale (1.0 = 100%)
    private var zoomScale: CGFloat = 1.0

    /// Resize state
    private var resizeStartPoint: CGPoint?
    private var resizeHandleType: HandleType?
    private var resizeAnchorPoint: CGPoint?
    private var resizeOriginalFrame: CGRect?

    // MARK: - Initialization

    init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
        super.init(frame: CGRect(origin: .zero, size: viewModel.canvasState.canvasBounds))
        setupView()
        setupLayers()
        registerForDragAndDrop()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupView() {
        // Use flipped coordinates (top-left origin)
        // Note: This is done via override below

        // Enable layer backing for performance
        wantsLayer = true

        // Set initial background color
        updateBackgroundColor()

        // Update frame size to match canvas bounds
        frame.size = viewModel.canvasState.canvasBounds
    }

    // MARK: - Appearance Updates

    func updateBackgroundColor() {
        // Update the background color based on current appearance
        // Explicitly resolve the color with the effective appearance
        let appearance = self.appearance ?? self.effectiveAppearance
        let color: NSColor

        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            // Dark mode
            color = NSColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0)
        } else {
            // Light mode
            color = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }

        layer?.backgroundColor = color.cgColor
    }

    private func setupLayers() {
        guard let rootLayer = layer else { return }

        // Create layers for all items in z-index order
        viewModel.canvasState.itemsSortedByZIndex.forEach { item in
            createLayer(for: item, in: rootLayer)
        }
    }

    private func registerForDragAndDrop() {
        // Register for drag types
        registerForDraggedTypes([
            .fileURL,
            .tiff,
            .png,
            .jpeg
        ])
    }

    // MARK: - Layout

    override var isFlipped: Bool {
        // Top-left origin for more intuitive positioning
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove old tracking area
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        // Create new tracking area covering entire view
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseMoved,
            .mouseEnteredAndExited
        ]

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )

        if let area = trackingArea {
            addTrackingArea(area)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = canvasPoint(from: event.locationInWindow)

        // Update cursor based on position relative to selected item
        if let selectedItem = viewModel.canvasState.selectedItems.first,
           selectedItem.frame.insetBy(dx: -8, dy: -8).contains(point) {

            if let handleType = hitTestResizeZone(at: point, item: selectedItem) {
                // Set cursor based on resize handle type
                handleType.cursor.set()
                return
            }
        }

        // Default cursor
        NSCursor.arrow.set()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Set proper backing scale for Retina displays
        if let window = window {
            layer?.contentsScale = window.backingScaleFactor
        }
    }

    // MARK: - Layer Management

    /// Create a CALayer for an item
    private func createLayer(for item: MoodBoardItem, in parentLayer: CALayer) {
        let itemLayer = CALayer()

        // Set layer properties
        itemLayer.frame = item.frame
        itemLayer.contentsGravity = .resizeAspect

        // Use thumbnail for display
        if let thumbnail = item.thumbnail {
            itemLayer.contents = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil)
        } else if let image = item.image {
            itemLayer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }

        // Set transform for rotation
        if item.rotation != 0 {
            itemLayer.transform = CATransform3DMakeRotation(item.rotation, 0, 0, 1)
        }

        // Performance optimizations
        itemLayer.drawsAsynchronously = true
        itemLayer.contentsScale = window?.backingScaleFactor ?? 2.0

        // Add selection border if selected (subtle)
        if item.isSelected {
            itemLayer.borderWidth = 1.5
            itemLayer.borderColor = NSColor.systemBlue.withAlphaComponent(0.6).cgColor
        }

        // Add to parent and track
        parentLayer.addSublayer(itemLayer)
        itemLayers[item.id] = itemLayer
        item.layer = itemLayer
    }

    /// Update layer for an item
    func updateLayer(for item: MoodBoardItem) {
        guard let itemLayer = itemLayers[item.id] else {
            // Layer doesn't exist, create it
            if let rootLayer = layer {
                createLayer(for: item, in: rootLayer)
            }
            return
        }

        // Disable implicit animations for immediate updates
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        itemLayer.frame = item.frame
        itemLayer.transform = CATransform3DMakeRotation(item.rotation, 0, 0, 1)

        // Update selection state (subtle border)
        if item.isSelected {
            itemLayer.borderWidth = 1.5
            itemLayer.borderColor = NSColor.systemBlue.withAlphaComponent(0.6).cgColor
        } else {
            itemLayer.borderWidth = 0.0
        }

        CATransaction.commit()
    }

    /// Remove layer for an item
    func removeLayer(for item: MoodBoardItem) {
        guard let itemLayer = itemLayers[item.id] else { return }
        itemLayer.removeFromSuperlayer()
        itemLayers.removeValue(forKey: item.id)
    }

    /// Update all layers (call after batch changes)
    func updateAllLayers() {
        // Update existing layers
        viewModel.canvasState.items.forEach { item in
            updateLayer(for: item)
        }

        // Reorder layers by z-index
        reorderLayers()

        // Perform culling based on visible rect
        cullLayers()

        // Update transform handles for selected items
        updateTransformHandles()
    }

    /// Update transform handles based on selection
    private func updateTransformHandles() {
        // Remove transform handles - we'll use invisible hit zones instead
        transformHandles?.removeFromSuperlayer()
        transformHandles = nil
    }

    /// Reorder layers to match z-index
    private func reorderLayers() {
        guard let rootLayer = layer else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Remove all sublayers
        itemLayers.values.forEach { $0.removeFromSuperlayer() }

        // Re-add in z-index order
        viewModel.canvasState.itemsSortedByZIndex.forEach { item in
            if let itemLayer = itemLayers[item.id] {
                rootLayer.addSublayer(itemLayer)
            }
        }

        CATransaction.commit()
    }

    /// Hide/show layers based on visibility (performance optimization)
    private func cullLayers() {
        // Calculate visible rect with buffer
        if let scrollView = enclosingScrollView {
            let visibleRect = scrollView.documentVisibleRect
            let buffer: CGFloat = 500.0
            visibleRectWithBuffer = visibleRect.insetBy(dx: -buffer, dy: -buffer)

            // Update layer visibility
            viewModel.canvasState.items.forEach { item in
                if let itemLayer = itemLayers[item.id] {
                    itemLayer.isHidden = !item.frame.intersects(visibleRectWithBuffer)
                }
            }
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Layer-backed view handles all rendering
        // This method is kept minimal for performance
        super.draw(dirtyRect)
    }

    // MARK: - Scroll Handling

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateCanvasBoundsIfNeeded()
    }

    func updateCanvasBoundsIfNeeded() {
        guard let scrollView = enclosingScrollView else { return }

        let visibleRect = scrollView.documentVisibleRect

        // Expand canvas if user is near edge
        viewModel.canvasState.expandCanvasIfNeeded(forVisibleRect: visibleRect, threshold: 500)

        // Update frame size
        if frame.size != viewModel.canvasState.canvasBounds {
            frame.size = viewModel.canvasState.canvasBounds
        }

        // Update culling
        cullLayers()
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Accept file drops
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        // Handle file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let dropPoint = canvasPoint(from: sender.draggingLocation)

            var offset: CGFloat = 0
            let spacing: CGFloat = 20

            for url in urls {
                // Check if it's an image file
                guard let image = NSImage(contentsOf: url) else { continue }

                // Calculate reasonable initial size (max 300px width)
                let maxInitialSize: CGFloat = 300.0
                var initialSize = image.size
                if initialSize.width > maxInitialSize {
                    let scale = maxInitialSize / initialSize.width
                    initialSize = CGSize(width: maxInitialSize, height: initialSize.height * scale)
                }

                // Create item at drop location with offset for multiple images
                let position = CGPoint(x: dropPoint.x + offset, y: dropPoint.y + offset)
                let item = MoodBoardItem(image: image, position: position, size: initialSize)
                item.imagePath = url.path

                // Add to canvas
                viewModel.addItem(item)
                createLayer(for: item, in: layer!)

                offset += spacing
            }

            updateAllLayers()
            return true
        }

        // Handle image data directly
        if let imageData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: imageData) {
            let dropPoint = canvasPoint(from: sender.draggingLocation)
            let item = MoodBoardItem(image: image, position: dropPoint)

            viewModel.addItem(item)
            createLayer(for: item, in: layer!)
            updateAllLayers()

            return true
        }

        return false
    }

    // MARK: - Mouse Handling

    private var mouseDownPoint: CGPoint?
    private var mouseDownItem: MoodBoardItem?

    /// Convert point from window coordinates to canvas coordinates (accounting for zoom)
    private func canvasPoint(from windowPoint: CGPoint) -> CGPoint {
        let viewPoint = convert(windowPoint, from: nil)
        return CGPoint(x: viewPoint.x / zoomScale, y: viewPoint.y / zoomScale)
    }

    /// Check if point is near edge/corner of an item (for resizing)
    private func hitTestResizeZone(at point: CGPoint, item: MoodBoardItem) -> HandleType? {
        let frame = item.frame
        let threshold: CGFloat = 8.0 // Distance from edge to trigger resize

        let nearLeft = abs(point.x - frame.minX) < threshold
        let nearRight = abs(point.x - frame.maxX) < threshold
        let nearTop = abs(point.y - frame.minY) < threshold
        let nearBottom = abs(point.y - frame.maxY) < threshold

        // Check corners first (higher priority)
        if nearTop && nearLeft { return .topLeft }
        if nearTop && nearRight { return .topRight }
        if nearBottom && nearLeft { return .bottomLeft }
        if nearBottom && nearRight { return .bottomRight }

        // Check edges
        if nearTop && point.x >= frame.minX && point.x <= frame.maxX { return .top }
        if nearBottom && point.x >= frame.minX && point.x <= frame.maxX { return .bottom }
        if nearLeft && point.y >= frame.minY && point.y <= frame.maxY { return .left }
        if nearRight && point.y >= frame.minY && point.y <= frame.maxY { return .right }

        return nil
    }

    /// Get opposite corner/edge for resize anchor
    private func getResizeAnchor(for handleType: HandleType, item: MoodBoardItem) -> CGPoint {
        let frame = item.frame

        switch handleType {
        case .topLeft: return CGPoint(x: frame.maxX, y: frame.maxY)
        case .topRight: return CGPoint(x: frame.minX, y: frame.maxY)
        case .bottomLeft: return CGPoint(x: frame.maxX, y: frame.minY)
        case .bottomRight: return CGPoint(x: frame.minX, y: frame.minY)
        case .top: return CGPoint(x: frame.midX, y: frame.maxY)
        case .bottom: return CGPoint(x: frame.midX, y: frame.minY)
        case .left: return CGPoint(x: frame.maxX, y: frame.midY)
        case .right: return CGPoint(x: frame.minX, y: frame.midY)
        case .rotation: return item.center
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = canvasPoint(from: event.locationInWindow)
        mouseDownPoint = point

        // Check if clicking on selected item's resize zone
        if let selectedItem = viewModel.canvasState.selectedItems.first,
           selectedItem.frame.contains(point) || selectedItem.frame.insetBy(dx: -8, dy: -8).contains(point) {

            // Check for resize zone
            if let handleType = hitTestResizeZone(at: point, item: selectedItem) {
                resizeHandleType = handleType
                resizeStartPoint = point
                resizeOriginalFrame = selectedItem.frame
                resizeAnchorPoint = getResizeAnchor(for: handleType, item: selectedItem)
                viewModel.isResizing = true
                return
            }
        }

        // Hit test to find item at click location
        if let hitItem = viewModel.hitTest(at: point) {
            mouseDownItem = hitItem

            // Handle selection
            let isCommandDown = event.modifierFlags.contains(.command)

            if isCommandDown {
                // Toggle selection
                if hitItem.isSelected {
                    viewModel.deselectItem(hitItem)
                } else {
                    viewModel.selectItem(hitItem, addToSelection: true)
                }
            } else {
                // Replace selection unless item already selected
                if !hitItem.isSelected {
                    viewModel.selectItem(hitItem, addToSelection: false)
                }
            }

            updateAllLayers()
        } else {
            // Clicked on empty space - clear selection
            viewModel.clearSelection()
            updateAllLayers()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint = mouseDownPoint else { return }

        let currentPoint = canvasPoint(from: event.locationInWindow)

        // Handle resize/rotate operations
        if viewModel.isResizing,
           let handleType = resizeHandleType,
           let selectedItem = viewModel.canvasState.selectedItems.first,
           let anchorPoint = resizeAnchorPoint {

            if handleType == .rotation {
                // Handle rotation
                let angle = ResizeCalculator.calculateRotation(from: currentPoint, center: selectedItem.center)
                selectedItem.rotation = angle
                selectedItem.markAsModified()
            } else {
                // Handle resize
                let newFrame = ResizeCalculator.calculateNewFrame(
                    currentPoint: currentPoint,
                    handleType: handleType,
                    anchorPoint: anchorPoint,
                    maintainAspectRatio: event.modifierFlags.contains(.shift),
                    originalAspectRatio: selectedItem.originalSize.width / selectedItem.originalSize.height
                )
                selectedItem.position = newFrame.origin
                selectedItem.size = newFrame.size
                selectedItem.markAsModified()
            }

            updateAllLayers()
            return
        }

        // If we have selected items and we're dragging, move them
        if !viewModel.selectedItemIDs.isEmpty {
            if !viewModel.isDragging {
                viewModel.beginDrag(at: startPoint)
            }

            viewModel.updateDrag(to: currentPoint)
            updateAllLayers()
            updateCanvasBoundsIfNeeded()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if viewModel.isDragging {
            viewModel.endDrag()
            updateAllLayers()
        }

        if viewModel.isResizing {
            viewModel.isResizing = false
            resizeHandleType = nil
            resizeStartPoint = nil
            resizeAnchorPoint = nil
            resizeOriginalFrame = nil
        }

        mouseDownPoint = nil
        mouseDownItem = nil
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else {
            super.keyDown(with: event)
            return
        }

        switch characters {
        case String(Character(UnicodeScalar(NSDeleteCharacter)!)),
             String(Character(UnicodeScalar(NSBackspaceCharacter)!)):
            // Delete selected items
            deleteSelectedItems()

        case "+", "=":
            // Zoom in (Command/Ctrl + or =)
            if event.modifierFlags.contains(.command) {
                let newScale = zoomScale * 1.1
                setZoom(newScale, centeredAt: CGPoint(x: bounds.midX / zoomScale, y: bounds.midY / zoomScale))
            } else {
                super.keyDown(with: event)
            }

        case "-", "_":
            // Zoom out (Command/Ctrl - or _)
            if event.modifierFlags.contains(.command) {
                let newScale = zoomScale / 1.1
                setZoom(newScale, centeredAt: CGPoint(x: bounds.midX / zoomScale, y: bounds.midY / zoomScale))
            } else {
                super.keyDown(with: event)
            }

        case "0":
            // Reset zoom to 100% (Command/Ctrl 0)
            if event.modifierFlags.contains(.command) {
                setZoom(1.0, centeredAt: CGPoint(x: bounds.midX / zoomScale, y: bounds.midY / zoomScale))
            } else {
                super.keyDown(with: event)
            }

        default:
            super.keyDown(with: event)
        }
    }

    private func deleteSelectedItems() {
        let itemsToRemove = viewModel.canvasState.selectedItems

        // Remove layers
        itemsToRemove.forEach { removeLayer(for: $0) }

        // Remove from view model
        viewModel.removeSelectedItems()

        updateAllLayers()
    }

    // MARK: - Zoom Handling

    override func magnify(with event: NSEvent) {
        // Handle trackpad pinch-to-zoom
        let newScale = zoomScale * (1.0 + event.magnification)
        setZoom(newScale, centeredAt: canvasPoint(from: event.locationInWindow))
    }

    override func scrollWheel(with event: NSEvent) {
        // Handle zoom with Command + scroll wheel OR Option key for easier access
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
            let zoomDelta = event.scrollingDeltaY * 0.01
            let newScale = zoomScale * (1.0 + zoomDelta)
            setZoom(newScale, centeredAt: canvasPoint(from: event.locationInWindow))
        } else {
            // Normal scrolling
            super.scrollWheel(with: event)
        }
    }

    private func setZoom(_ newScale: CGFloat, centeredAt point: CGPoint) {
        // Clamp zoom between 10% and 500%
        let clampedScale = min(max(newScale, 0.1), 5.0)

        // Get the point in the unscaled coordinate system
        let pointInView = CGPoint(x: point.x / zoomScale, y: point.y / zoomScale)

        // Update zoom scale
        zoomScale = clampedScale

        // Update window title with zoom percentage
        if let window = self.window {
            let zoomPercent = Int(clampedScale * 100)
            let baseTitle = window.title.components(separatedBy: " - ").first ?? window.title
            window.title = "\(baseTitle) - \(zoomPercent)%"
        }

        // Apply scale transform
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let rootLayer = layer {
            rootLayer.setAffineTransform(CGAffineTransform(scaleX: zoomScale, y: zoomScale))
        }

        CATransaction.commit()

        // Update frame size to account for zoom
        let scaledSize = CGSize(
            width: viewModel.canvasState.canvasBounds.width * zoomScale,
            height: viewModel.canvasState.canvasBounds.height * zoomScale
        )
        frame.size = scaledSize

        // Adjust scroll position to keep the zoom centered on the cursor
        if let scrollView = enclosingScrollView {
            let newPoint = CGPoint(
                x: pointInView.x * zoomScale - scrollView.contentView.bounds.width / 2,
                y: pointInView.y * zoomScale - scrollView.contentView.bounds.height / 2
            )
            scrollView.contentView.scroll(to: newPoint)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    // MARK: - Public API

    /// Refresh the entire canvas (call after external state changes)
    func refresh() {
        updateAllLayers()
        updateCanvasBoundsIfNeeded()
        needsDisplay = true
    }
}

// MARK: - Pasteboard Type Extensions

extension NSPasteboard.PasteboardType {
    static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
}
