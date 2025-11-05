//
//  TransformHandles.swift
//  MoodBoardFeature
//
//  Visual handles for resizing and rotating items
//

import AppKit
import QuartzCore

/// Type of transform handle
enum HandleType {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
    case rotation

    var cursor: NSCursor {
        switch self {
        case .topLeft, .bottomRight:
            return NSCursor.closedHand
        case .topRight, .bottomLeft:
            return NSCursor.closedHand
        case .top, .bottom:
            return NSCursor.resizeUpDown
        case .left, .right:
            return NSCursor.resizeLeftRight
        case .rotation:
            return NSCursor.pointingHand
        }
    }
}

/// Visual transform handles for resizing and rotating items
class TransformHandles {

    // MARK: - Properties

    /// The item these handles are for
    weak var item: MoodBoardItem?

    /// Container layer for all handles
    let containerLayer: CALayer

    /// Individual handle layers
    private var handleLayers: [HandleType: CALayer] = [:]

    /// Handle size
    private let handleSize: CGFloat = 10.0

    /// Rotation handle offset from top edge
    private let rotationHandleOffset: CGFloat = 30.0

    /// Whether handles are currently visible
    private(set) var isVisible: Bool = false

    // MARK: - Initialization

    init(item: MoodBoardItem) {
        self.item = item
        self.containerLayer = CALayer()
        setupHandles()
    }

    // MARK: - Setup

    private func setupHandles() {
        containerLayer.name = "TransformHandles"

        // Create resize handles
        let resizeHandles: [HandleType] = [
            .topLeft, .top, .topRight,
            .left, .right,
            .bottomLeft, .bottom, .bottomRight
        ]

        resizeHandles.forEach { type in
            let handle = createHandle(for: type)
            handleLayers[type] = handle
            containerLayer.addSublayer(handle)
        }

        // Create rotation handle
        let rotationHandle = createRotationHandle()
        handleLayers[.rotation] = rotationHandle
        containerLayer.addSublayer(rotationHandle)

        // Initially hide handles
        containerLayer.isHidden = true
    }

    private func createHandle(for type: HandleType) -> CALayer {
        let handle = CALayer()
        handle.name = "Handle_\(type)"
        handle.bounds = CGRect(x: 0, y: 0, width: handleSize, height: handleSize)
        handle.backgroundColor = NSColor.white.cgColor
        handle.borderColor = NSColor.selectedControlColor.cgColor
        handle.borderWidth = 2.0
        handle.cornerRadius = handleSize / 2

        // Shadow for better visibility
        handle.shadowColor = NSColor.black.cgColor
        handle.shadowOpacity = 0.3
        handle.shadowOffset = CGSize(width: 0, height: 1)
        handle.shadowRadius = 2

        return handle
    }

    private func createRotationHandle() -> CALayer {
        let handle = CALayer()
        handle.name = "Handle_rotation"
        handle.bounds = CGRect(x: 0, y: 0, width: handleSize + 2, height: handleSize + 2)
        handle.backgroundColor = NSColor.systemBlue.cgColor
        handle.borderColor = NSColor.white.cgColor
        handle.borderWidth = 2.0
        handle.cornerRadius = (handleSize + 2) / 2

        // Shadow
        handle.shadowColor = NSColor.black.cgColor
        handle.shadowOpacity = 0.4
        handle.shadowOffset = CGSize(width: 0, height: 1)
        handle.shadowRadius = 2

        return handle
    }

    // MARK: - Display

    /// Show the handles
    func show() {
        updatePositions()
        containerLayer.isHidden = false
        isVisible = true
    }

    /// Hide the handles
    func hide() {
        containerLayer.isHidden = true
        isVisible = false
    }

    /// Update handle positions based on item's current frame
    func updatePositions() {
        guard let item = item else { return }

        let frame = item.frame
        let halfHandle = handleSize / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Position resize handles
        handleLayers[.topLeft]?.position = CGPoint(x: frame.minX, y: frame.minY)
        handleLayers[.top]?.position = CGPoint(x: frame.midX, y: frame.minY)
        handleLayers[.topRight]?.position = CGPoint(x: frame.maxX, y: frame.minY)

        handleLayers[.left]?.position = CGPoint(x: frame.minX, y: frame.midY)
        handleLayers[.right]?.position = CGPoint(x: frame.maxX, y: frame.midY)

        handleLayers[.bottomLeft]?.position = CGPoint(x: frame.minX, y: frame.maxY)
        handleLayers[.bottom]?.position = CGPoint(x: frame.midX, y: frame.maxY)
        handleLayers[.bottomRight]?.position = CGPoint(x: frame.maxX, y: frame.maxY)

        // Position rotation handle
        handleLayers[.rotation]?.position = CGPoint(
            x: frame.midX,
            y: frame.minY - rotationHandleOffset
        )

        // Update container bounds to encompass all handles
        let containerBounds = CGRect(
            x: frame.minX - halfHandle,
            y: frame.minY - rotationHandleOffset - halfHandle,
            width: frame.width + handleSize,
            height: frame.height + rotationHandleOffset + halfHandle
        )
        containerLayer.frame = containerBounds

        CATransaction.commit()
    }

    // MARK: - Hit Testing

    /// Find which handle (if any) is at the given point
    /// - Parameter point: Point in canvas coordinates
    /// - Returns: The handle type at that point, or nil
    func hitTest(at point: CGPoint) -> HandleType? {
        guard isVisible else { return nil }

        for (type, handle) in handleLayers {
            let handleFrame = handle.frame
            let expandedFrame = handleFrame.insetBy(dx: -5, dy: -5) // Expand hit area

            if expandedFrame.contains(point) {
                return type
            }
        }

        return nil
    }

    /// Get the opposite handle for a given handle type (for resize operations)
    func oppositeHandle(for type: HandleType) -> CGPoint? {
        guard let item = item else { return nil }

        let frame = item.frame

        switch type {
        case .topLeft:
            return CGPoint(x: frame.maxX, y: frame.maxY)
        case .topRight:
            return CGPoint(x: frame.minX, y: frame.maxY)
        case .bottomLeft:
            return CGPoint(x: frame.maxX, y: frame.minY)
        case .bottomRight:
            return CGPoint(x: frame.minX, y: frame.minY)
        case .top:
            return CGPoint(x: frame.midX, y: frame.maxY)
        case .bottom:
            return CGPoint(x: frame.midX, y: frame.minY)
        case .left:
            return CGPoint(x: frame.maxX, y: frame.midY)
        case .right:
            return CGPoint(x: frame.minX, y: frame.midY)
        case .rotation:
            return item.center
        }
    }

    // MARK: - Cleanup

    func removeFromSuperlayer() {
        containerLayer.removeFromSuperlayer()
    }
}

// MARK: - Resize Calculator

/// Helper for calculating new size during resize operations
struct ResizeCalculator {

    /// Calculate new frame for an item being resized
    /// - Parameters:
    ///   - currentPoint: Current mouse position
    ///   - handleType: Which handle is being dragged
    ///   - anchorPoint: The opposite corner/edge (stays fixed)
    ///   - maintainAspectRatio: Whether to maintain aspect ratio
    ///   - originalAspectRatio: The original aspect ratio if maintaining
    /// - Returns: New frame for the item
    static func calculateNewFrame(
        currentPoint: CGPoint,
        handleType: HandleType,
        anchorPoint: CGPoint,
        maintainAspectRatio: Bool = false,
        originalAspectRatio: CGFloat? = nil
    ) -> CGRect {

        var newFrame = CGRect.zero

        switch handleType {
        case .topLeft:
            newFrame = rectFromCorners(currentPoint, anchorPoint)
        case .topRight:
            newFrame = rectFromCorners(currentPoint, anchorPoint)
        case .bottomLeft:
            newFrame = rectFromCorners(currentPoint, anchorPoint)
        case .bottomRight:
            newFrame = rectFromCorners(currentPoint, anchorPoint)

        case .top:
            newFrame = rectFromEdge(
                currentY: currentPoint.y,
                anchorPoint: anchorPoint,
                isHorizontal: false,
                width: abs(anchorPoint.x - anchorPoint.x)
            )

        case .bottom:
            newFrame = rectFromEdge(
                currentY: currentPoint.y,
                anchorPoint: anchorPoint,
                isHorizontal: false,
                width: abs(anchorPoint.x - anchorPoint.x)
            )

        case .left:
            newFrame = rectFromEdge(
                currentX: currentPoint.x,
                anchorPoint: anchorPoint,
                isHorizontal: true,
                height: abs(anchorPoint.y - anchorPoint.y)
            )

        case .right:
            newFrame = rectFromEdge(
                currentX: currentPoint.x,
                anchorPoint: anchorPoint,
                isHorizontal: true,
                height: abs(anchorPoint.y - anchorPoint.y)
            )

        case .rotation:
            // Rotation doesn't change frame
            return CGRect(origin: anchorPoint, size: .zero)
        }

        // Apply aspect ratio constraint if needed
        if maintainAspectRatio, let aspectRatio = originalAspectRatio {
            newFrame = constrainToAspectRatio(newFrame, aspectRatio: aspectRatio)
        }

        // Ensure minimum size
        let minSize: CGFloat = 20
        if newFrame.width < minSize {
            newFrame.size.width = minSize
        }
        if newFrame.height < minSize {
            newFrame.size.height = minSize
        }

        return newFrame
    }

    private static func rectFromCorners(_ point1: CGPoint, _ point2: CGPoint) -> CGRect {
        let minX = min(point1.x, point2.x)
        let minY = min(point1.y, point2.y)
        let maxX = max(point1.x, point2.x)
        let maxY = max(point1.y, point2.y)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func rectFromEdge(
        currentY: CGFloat? = nil,
        currentX: CGFloat? = nil,
        anchorPoint: CGPoint,
        isHorizontal: Bool,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) -> CGRect {
        if isHorizontal {
            let x = min(currentX ?? anchorPoint.x, anchorPoint.x)
            let width = abs((currentX ?? anchorPoint.x) - anchorPoint.x)
            return CGRect(x: x, y: anchorPoint.y - (height ?? 0) / 2, width: width, height: height ?? 0)
        } else {
            let y = min(currentY ?? anchorPoint.y, anchorPoint.y)
            let height = abs((currentY ?? anchorPoint.y) - anchorPoint.y)
            return CGRect(x: anchorPoint.x - (width ?? 0) / 2, y: y, width: width ?? 0, height: height)
        }
    }

    private static func constrainToAspectRatio(_ rect: CGRect, aspectRatio: CGFloat) -> CGRect {
        var newRect = rect
        let currentAspect = rect.width / rect.height

        if currentAspect > aspectRatio {
            // Width is too large
            newRect.size.width = rect.height * aspectRatio
        } else {
            // Height is too large
            newRect.size.height = rect.width / aspectRatio
        }

        return newRect
    }

    /// Calculate rotation angle from a point relative to a center
    static func calculateRotation(from point: CGPoint, center: CGPoint) -> CGFloat {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return atan2(dy, dx)
    }
}
