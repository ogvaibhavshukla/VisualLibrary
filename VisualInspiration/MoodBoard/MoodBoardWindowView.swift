//
//  MoodBoardWindowView.swift
//  VisualInspiration
//

import SwiftUI
import AppKit

struct MoodBoardWindowView: View {
    @StateObject private var viewModel: CanvasViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @AppStorage("skipClearConfirmation") private var skipClearConfirmation = false

    init() {
        // Load saved canvas state or create new one
        let persistenceManager = PersistenceManager()
        let canvasState = persistenceManager.load() ?? CanvasState()
        _viewModel = StateObject(wrappedValue: CanvasViewModel(
            canvasState: canvasState,
            persistenceManager: persistenceManager
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Close") {
                    // Close the window when it's a separate window
                    NSApplication.shared.keyWindow?.close()
                }
                    .buttonStyle(.bordered)

                Spacer()

                Text("MoodBoard")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button("Clear") {
                    if skipClearConfirmation {
                        clearCanvas()
                    } else {
                        showClearConfirmation = true
                    }
                }
                    .buttonStyle(.bordered)

                Button("Export") { exportCanvas() }
                    .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.moodBoardToolbar)

            Divider()
                .background(Color.white.opacity(0.1))

            // Canvas
            MoodBoardCanvasRepresentable(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showClearConfirmation) {
            ClearConfirmationView(
                skipConfirmation: $skipClearConfirmation,
                onConfirm: {
                    clearCanvas()
                    showClearConfirmation = false
                },
                onCancel: {
                    showClearConfirmation = false
                }
            )
        }
    }

    private func exportCanvas() {
        let exportManager = ExportManager(canvasState: viewModel.canvasState)
        exportManager.exportWithSavePanel { success in
            print("Export \(success ? "succeeded" : "failed")")
        }
    }

    private func clearCanvas() {
        let itemCount = viewModel.canvasState.items.count
        viewModel.clearAll()
        print("🗑️ Cleared all \(itemCount) items from MoodBoard")
    }
}
