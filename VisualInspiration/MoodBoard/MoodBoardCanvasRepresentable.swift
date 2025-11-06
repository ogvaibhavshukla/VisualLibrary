//
//  MoodBoardCanvasRepresentable.swift
//  VisualInspiration
//

import SwiftUI
import AppKit

struct MoodBoardCanvasRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: CanvasViewModel
    @Environment(\.colorScheme) var colorScheme

    func makeNSView(context: Context) -> MoodBoardCanvasView {
        let canvasView = MoodBoardCanvasView(viewModel: viewModel)
        updateAppearance(for: canvasView)
        return canvasView
    }

    func updateNSView(_ nsView: MoodBoardCanvasView, context: Context) {
        nsView.viewModel = viewModel
        updateAppearance(for: nsView)
    }

    private func updateAppearance(for view: MoodBoardCanvasView) {
        // Force the NSView to use the SwiftUI color scheme
        // let appearance = colorScheme == .light ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        let appearance = colorScheme == .dark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        view.appearance = appearance

        // Update the background color
        view.updateBackgroundColor()
    }
}
