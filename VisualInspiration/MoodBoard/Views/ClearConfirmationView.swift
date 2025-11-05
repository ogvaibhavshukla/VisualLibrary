//
//  ClearConfirmationView.swift
//  VisualInspiration
//

import SwiftUI

struct ClearConfirmationView: View {
    @Binding var skipConfirmation: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 24))

                Text("Clear MoodBoard")
                    .font(.headline)
            }

            Divider()

            // Message
            Text("This will remove all items from the MoodBoard.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // Remember my choice checkbox
            Toggle("Don't ask me again", isOn: $skipConfirmation)
                .toggleStyle(.checkbox)

            Divider()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button("Clear All Items") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 350)
    }
}
