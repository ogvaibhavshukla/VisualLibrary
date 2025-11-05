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
            .background(Color.clear)

            // Canvas
            MoodBoardCanvasRepresentable(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.all, edges: .top)
        .onAppear {
            // Additional window configuration to ensure traffic light buttons are hidden
            // This works as a direct fallback in case AppDelegate configuration doesn't trigger
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow && $0 != NSApplication.shared.windows.first }) {
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                }
            }
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
