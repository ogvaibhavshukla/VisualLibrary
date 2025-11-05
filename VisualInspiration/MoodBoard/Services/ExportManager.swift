//
//  ExportManager.swift
//  MoodBoardFeature
//
//  Handles exporting the mood board canvas to image files
//

import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Manages exporting the canvas to various image formats
class ExportManager {

    // MARK: - Export Format

    enum ExportFormat {
        case png
        case jpeg(quality: CGFloat) // 0.0 - 1.0
        case tiff

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            }
        }

        var utType: String {
            switch self {
            case .png: return "public.png"
            case .jpeg: return "public.jpeg"
            case .tiff: return "public.tiff"
            }
        }
    }

    // MARK: - Export Options

    struct ExportOptions {
        /// Export format
        var format: ExportFormat = .png

        /// Scale factor (1.0 = original size, 2.0 = 2x resolution)
        var scaleFactor: CGFloat = 1.0

        /// Background color (nil = transparent for PNG, white for JPEG)
        var backgroundColor: NSColor?

        /// Export only selected items (if true), or entire canvas
        var selectedOnly: Bool = false

        /// Add margin around exported content
        var margin: CGFloat = 0

        static let `default` = ExportOptions()
    }

    // MARK: - Properties

    /// Canvas state to export
    weak var canvasState: CanvasState?

    // MARK: - Initialization

    init(canvasState: CanvasState) {
        self.canvasState = canvasState
    }

    // MARK: - Export Methods

    /// Export the canvas to an image
    /// - Parameters:
    ///   - options: Export options
    ///   - completion: Called with the generated image or error
    func exportToImage(options: ExportOptions = .default, completion: @escaping (Result<NSImage, Error>) -> Void) {
        guard let canvasState = canvasState else {
            completion(.failure(ExportError.noCanvasState))
            return
        }

        // Determine what to export
        let itemsToExport = options.selectedOnly ? canvasState.selectedItems : canvasState.items

        guard !itemsToExport.isEmpty else {
            completion(.failure(ExportError.noContent))
            return
        }

        // Calculate bounding rect
        let bounds = calculateBounds(for: itemsToExport, margin: options.margin)

        // Render in background
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                do {
                    let image = try self.renderImage(
                        items: itemsToExport,
                        bounds: bounds,
                        options: options
                    )

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

    /// Export the canvas to a file
    /// - Parameters:
    ///   - url: Destination file URL
    ///   - options: Export options
    ///   - completion: Called with success/failure
    func exportToFile(at url: URL, options: ExportOptions = .default, completion: @escaping (Result<Void, Error>) -> Void) {
        exportToImage(options: options) { result in
            switch result {
            case .success(let image):
                do {
                    try self.writeImage(image, to: url, format: options.format)
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Show save panel and export
    /// - Parameters:
    ///   - options: Export options
    ///   - completion: Called when export is complete or cancelled
    func exportWithSavePanel(options: ExportOptions = .default, completion: @escaping (Bool) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg, .tiff]
        savePanel.nameFieldStringValue = "MoodBoard.\(options.format.fileExtension)"
        savePanel.title = "Export Mood Board"
        savePanel.message = "Choose where to save the exported image"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else {
                completion(false)
                return
            }

            self.exportToFile(at: url, options: options) { result in
                switch result {
                case .success:
                    print("Successfully exported to: \(url.path)")
                    completion(true)

                case .failure(let error):
                    self.showError(error)
                    completion(false)
                }
            }
        }
    }

    // MARK: - Rendering

    private func renderImage(items: [MoodBoardItem], bounds: CGRect, options: ExportOptions) throws -> NSImage {
        let scaledSize = CGSize(
            width: bounds.width * options.scaleFactor,
            height: bounds.height * options.scaleFactor
        )

        // Create image
        let image = NSImage(size: scaledSize)

        image.lockFocus()

        // Set up graphics context
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            throw ExportError.renderingFailed("Could not get graphics context")
        }

        context.saveGState()

        // Set background color
        let bgColor = options.backgroundColor ?? (options.format.fileExtension == "jpg" ? .white : .clear)
        bgColor.setFill()
        context.fill(CGRect(origin: .zero, size: scaledSize))

        // Scale and translate
        context.scaleBy(x: options.scaleFactor, y: options.scaleFactor)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)

        // Set high quality rendering
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)

        // Sort items by z-index
        let sortedItems = items.sorted { $0.zIndex < $1.zIndex }

        // Draw each item
        for item in sortedItems {
            try renderItem(item, in: context)
        }

        context.restoreGState()
        image.unlockFocus()

        return image
    }

    private func renderItem(_ item: MoodBoardItem, in context: CGContext) throws {
        guard let image = item.image else { return }

        context.saveGState()

        // Translate to item position
        context.translateBy(x: item.position.x, y: item.position.y)

        // Apply rotation if any
        if item.rotation != 0 {
            let center = CGPoint(x: item.size.width / 2, y: item.size.height / 2)
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: item.rotation)
            context.translateBy(x: -center.x, y: -center.y)
        }

        // Draw the image
        let rect = CGRect(origin: .zero, size: item.size)

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: rect)
        } else {
            // Fallback to NSImage drawing
            image.draw(in: rect, from: CGRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        }

        context.restoreGState()
    }

    private func calculateBounds(for items: [MoodBoardItem], margin: CGFloat) -> CGRect {
        guard !items.isEmpty else { return .zero }

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for item in items {
            let frame = item.frame
            minX = min(minX, frame.minX)
            minY = min(minY, frame.minY)
            maxX = max(maxX, frame.maxX)
            maxY = max(maxY, frame.maxY)
        }

        return CGRect(
            x: minX - margin,
            y: minY - margin,
            width: maxX - minX + margin * 2,
            height: maxY - minY + margin * 2
        )
    }

    // MARK: - File Writing

    private func writeImage(_ image: NSImage, to url: URL, format: ExportFormat) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ExportError.renderingFailed("Could not create CGImage")
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = image.size

        let data: Data?

        switch format {
        case .png:
            data = bitmapRep.representation(using: .png, properties: [:])

        case .jpeg(let quality):
            data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])

        case .tiff:
            data = bitmapRep.representation(using: .tiff, properties: [:])
        }

        guard let imageData = data else {
            throw ExportError.renderingFailed("Could not encode image data")
        }

        try imageData.write(to: url, options: .atomic)
    }

    // MARK: - Error Handling

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Export Error

enum ExportError: Error, LocalizedError {
    case noCanvasState
    case noContent
    case renderingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCanvasState:
            return "No canvas state available for export"
        case .noContent:
            return "No content to export"
        case .renderingFailed(let reason):
            return "Rendering failed: \(reason)"
        }
    }
}
