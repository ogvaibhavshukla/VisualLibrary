//
//  Colors.swift
//  VisualInspiration
//

import SwiftUI
import AppKit

extension Color {
    // Adaptive colors that sync with app's color scheme preference
    static let moodBoardToolbar = Color(nsColor: .moodBoardToolbar)
    static let moodBoardCanvas = Color(nsColor: .moodBoardCanvas)
}

extension NSColor {
    // Adaptive colors that automatically switch based on app's appearance
    static let moodBoardToolbar = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            // Dark mode: darker toolbar
            return NSColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)  // #2B2B2E
        } else {
            // Light mode: light toolbar
            return NSColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)  // #F2F2F5
        }
    }

    static let moodBoardCanvas = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            // Dark mode: almost black canvas
            return NSColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0)  // #171717
        } else {
            // Light mode: white/very light gray canvas
            return NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)  // #FFFFFF
        }
    }
}
