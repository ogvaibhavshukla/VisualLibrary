//
//  GeometryExtensions.swift
//  MoodBoardFeature
//
//  Useful geometry extensions and helpers
//

import Foundation
import CoreGraphics

// MARK: - CGRect Extensions

extension CGRect {

    /// Center point of the rect
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }

    /// Top-left corner
    var topLeft: CGPoint {
        return CGPoint(x: minX, y: minY)
    }

    /// Top-right corner
    var topRight: CGPoint {
        return CGPoint(x: maxX, y: minY)
    }

    /// Bottom-left corner
    var bottomLeft: CGPoint {
        return CGPoint(x: minX, y: maxY)
    }

    /// Bottom-right corner
    var bottomRight: CGPoint {
        return CGPoint(x: maxX, y: maxY)
    }

    /// Create a rect from two points
    init(from point1: CGPoint, to point2: CGPoint) {
        let minX = min(point1.x, point2.x)
        let minY = min(point1.y, point2.y)
        let maxX = max(point1.x, point2.x)
        let maxY = max(point1.y, point2.y)

        self.init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Expand rect by a margin on all sides
    func expanded(by margin: CGFloat) -> CGRect {
        return insetBy(dx: -margin, dy: -margin)
    }

    /// Check if rect is valid (non-negative size)
    var isValid: Bool {
        return width >= 0 && height >= 0
    }
}

// MARK: - CGPoint Extensions

extension CGPoint {

    /// Calculate distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Calculate angle to another point (in radians)
    func angle(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return atan2(dy, dx)
    }

    /// Add two points
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    /// Subtract two points
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    /// Multiply point by scalar
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    /// Interpolate between two points
    func interpolate(to other: CGPoint, fraction: CGFloat) -> CGPoint {
        return CGPoint(
            x: x + (other.x - x) * fraction,
            y: y + (other.y - y) * fraction
        )
    }

    /// Clamp point to a rect
    func clamped(to rect: CGRect) -> CGPoint {
        return CGPoint(
            x: max(rect.minX, min(x, rect.maxX)),
            y: max(rect.minY, min(y, rect.maxY))
        )
    }
}

// MARK: - CGSize Extensions

extension CGSize {

    /// Calculate aspect ratio (width / height)
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1.0 }
        return width / height
    }

    /// Scale size to fit within a maximum size while maintaining aspect ratio
    func scaledToFit(within maxSize: CGSize) -> CGSize {
        let scale = min(maxSize.width / width, maxSize.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }

    /// Scale size to fill a minimum size while maintaining aspect ratio
    func scaledToFill(minimum minSize: CGSize) -> CGSize {
        let scale = max(minSize.width / width, minSize.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }

    /// Multiply size by scalar
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    /// Check if size is valid (non-negative)
    var isValid: Bool {
        return width >= 0 && height >= 0
    }

    /// Check if size is effectively zero
    var isZero: Bool {
        return width < 0.001 && height < 0.001
    }
}

// MARK: - Angle Utilities

struct AngleHelper {

    /// Convert degrees to radians
    static func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
        return degrees * .pi / 180.0
    }

    /// Convert radians to degrees
    static func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        return radians * 180.0 / .pi
    }

    /// Normalize angle to 0...2π range
    static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if normalized < 0 {
            normalized += 2 * .pi
        }
        return normalized
    }

    /// Calculate the shortest angular distance between two angles
    static func angleDifference(_ angle1: CGFloat, _ angle2: CGFloat) -> CGFloat {
        let diff = (angle2 - angle1).truncatingRemainder(dividingBy: 2 * .pi)
        if diff > .pi {
            return diff - 2 * .pi
        } else if diff < -.pi {
            return diff + 2 * .pi
        }
        return diff
    }
}

// MARK: - Transform Utilities

struct TransformHelper {

    /// Create a transform that rotates around a specific point
    static func rotationTransform(angle: CGFloat, around point: CGPoint) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: point.x, y: point.y)
        transform = transform.rotated(by: angle)
        transform = transform.translatedBy(x: -point.x, y: -point.y)
        return transform
    }

    /// Apply a transform to a point
    static func transformPoint(_ point: CGPoint, with transform: CGAffineTransform) -> CGPoint {
        return point.applying(transform)
    }

    /// Apply a transform to a rect
    static func transformRect(_ rect: CGRect, with transform: CGAffineTransform) -> CGRect {
        return rect.applying(transform)
    }
}

// MARK: - Intersection & Collision

struct CollisionHelper {

    /// Check if two rects intersect (accounting for a tolerance)
    static func rectsIntersect(_ rect1: CGRect, _ rect2: CGRect, tolerance: CGFloat = 0) -> Bool {
        let expanded = rect1.expanded(by: tolerance)
        return expanded.intersects(rect2)
    }

    /// Check if a point is inside a rotated rect
    static func pointInRotatedRect(_ point: CGPoint, rect: CGRect, rotation: CGFloat) -> Bool {
        // Transform point to rect's local coordinate system
        let center = rect.center
        let transform = TransformHelper.rotationTransform(angle: -rotation, around: center)
        let localPoint = TransformHelper.transformPoint(point, with: transform)

        // Simple rect check in local space
        return rect.contains(localPoint)
    }
}
