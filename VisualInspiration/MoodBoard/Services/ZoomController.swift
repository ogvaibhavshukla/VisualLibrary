//
//  ZoomController.swift
//  MoodBoardFeature
//
//  Manages zoom levels and scaling for the canvas
//

import AppKit
import Foundation

/// Controls zoom level and magnification for the canvas
class ZoomController {

    // MARK: - Properties

    /// Reference to the scroll view
    weak var scrollView: NSScrollView?

    /// Current zoom level (1.0 = 100%)
    private(set) var currentZoom: CGFloat = 1.0

    /// Minimum zoom level
    let minZoom: CGFloat = 0.1 // 10%

    /// Maximum zoom level
    let maxZoom: CGFloat = 10.0 // 1000%

    /// Standard zoom levels for zoom in/out buttons
    let standardZoomLevels: [CGFloat] = [
        0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 10.0
    ]

    /// Zoom changed callback
    var onZoomChanged: ((CGFloat) -> Void)?

    // MARK: - Initialization

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        setupScrollView()
    }

    private func setupScrollView() {
        scrollView?.allowsMagnification = true
        scrollView?.minMagnification = minZoom
        scrollView?.maxMagnification = maxZoom
        scrollView?.magnification = 1.0
    }

    // MARK: - Zoom Operations

    /// Set zoom to a specific level
    /// - Parameters:
    ///   - zoom: The zoom level (1.0 = 100%)
    ///   - animated: Whether to animate the zoom change
    ///   - centerPoint: Point to center on (in document view coordinates), nil for current center
    func setZoom(_ zoom: CGFloat, animated: Bool = true, centerPoint: CGPoint? = nil) {
        let clampedZoom = max(minZoom, min(zoom, maxZoom))

        guard let scrollView = scrollView else { return }

        // Get center point before zoom
        let centerToUse = centerPoint ?? scrollView.documentVisibleRect.center

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                scrollView.animator().magnification = clampedZoom

                // Keep centered on the same point
                self.centerOn(point: centerToUse, zoom: clampedZoom)
            }
        } else {
            scrollView.magnification = clampedZoom
            centerOn(point: centerToUse, zoom: clampedZoom)
        }

        currentZoom = clampedZoom
        onZoomChanged?(currentZoom)
    }

    /// Zoom in by one step
    func zoomIn(animated: Bool = true, centerPoint: CGPoint? = nil) {
        let nextZoom = findNextZoomLevel(after: currentZoom, direction: .up)
        setZoom(nextZoom, animated: animated, centerPoint: centerPoint)
    }

    /// Zoom out by one step
    func zoomOut(animated: Bool = true, centerPoint: CGPoint? = nil) {
        let nextZoom = findNextZoomLevel(after: currentZoom, direction: .down)
        setZoom(nextZoom, animated: animated, centerPoint: centerPoint)
    }

    /// Zoom to fit all content
    func zoomToFit(animated: Bool = true) {
        guard let scrollView = scrollView,
              let documentView = scrollView.documentView else { return }

        let visibleSize = scrollView.contentSize
        let documentSize = documentView.bounds.size

        // Calculate zoom to fit
        let scaleX = visibleSize.width / documentSize.width
        let scaleY = visibleSize.height / documentSize.height
        let scale = min(scaleX, scaleY) * 0.9 // 90% to leave some margin

        let clampedScale = max(minZoom, min(scale, maxZoom))

        setZoom(clampedScale, animated: animated, centerPoint: documentView.bounds.center)
    }

    /// Zoom to actual size (100%)
    func zoomToActualSize(animated: Bool = true, centerPoint: CGPoint? = nil) {
        setZoom(1.0, animated: animated, centerPoint: centerPoint)
    }

    /// Zoom to selection (fit selected items in view)
    func zoomToRect(_ rect: CGRect, animated: Bool = true) {
        guard let scrollView = scrollView else { return }

        let visibleSize = scrollView.contentSize

        // Calculate zoom to fit rect
        let scaleX = visibleSize.width / rect.width
        let scaleY = visibleSize.height / rect.height
        let scale = min(scaleX, scaleY) * 0.8 // 80% to leave margin

        let clampedScale = max(minZoom, min(scale, maxZoom))

        setZoom(clampedScale, animated: animated, centerPoint: rect.center)
    }

    // MARK: - Helper Methods

    private func findNextZoomLevel(after currentLevel: CGFloat, direction: ZoomDirection) -> CGFloat {
        switch direction {
        case .up:
            // Find next higher zoom level
            if let nextLevel = standardZoomLevels.first(where: { $0 > currentLevel + 0.01 }) {
                return nextLevel
            }
            return maxZoom

        case .down:
            // Find next lower zoom level
            if let nextLevel = standardZoomLevels.reversed().first(where: { $0 < currentLevel - 0.01 }) {
                return nextLevel
            }
            return minZoom
        }
    }

    private func centerOn(point: CGPoint, zoom: CGFloat) {
        guard let scrollView = scrollView,
              let documentView = scrollView.documentView else { return }

        // Calculate the scroll position to center on the point
        let visibleSize = scrollView.contentSize
        let scaledPoint = CGPoint(x: point.x * zoom, y: point.y * zoom)

        var scrollPoint = CGPoint(
            x: scaledPoint.x - visibleSize.width / 2,
            y: scaledPoint.y - visibleSize.height / 2
        )

        // Clamp to valid scroll range
        let maxScrollX = max(0, documentView.bounds.width * zoom - visibleSize.width)
        let maxScrollY = max(0, documentView.bounds.height * zoom - visibleSize.height)

        scrollPoint.x = max(0, min(scrollPoint.x, maxScrollX))
        scrollPoint.y = max(0, min(scrollPoint.y, maxScrollY))

        scrollView.contentView.scroll(to: scrollPoint)
    }

    // MARK: - Zoom Info

    /// Get current zoom as percentage
    var zoomPercentage: Int {
        return Int(currentZoom * 100)
    }

    /// Check if can zoom in
    var canZoomIn: Bool {
        return currentZoom < maxZoom - 0.01
    }

    /// Check if can zoom out
    var canZoomOut: Bool {
        return currentZoom > minZoom + 0.01
    }

    enum ZoomDirection {
        case up, down
    }
}
