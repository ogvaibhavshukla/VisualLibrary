//
//  VisualInspirationApp.swift
//  VisualInspiration
//
//  Created by Visual Library on 2/14/25.
//

import SwiftUI

@main
struct VisualInspirationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("colorScheme") private var colorSchemeString: String = "light"
    
    init() {
        // Register Lato font
        if let fontURL = Bundle.main.url(forResource: "Lato-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }
     
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toolbar(.hidden, for: .windowToolbar)
                .preferredColorScheme(colorSchemeString == "dark" ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 600)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)

        // MoodBoard window - opens as a separate independent window (single instance)
        Window("MoodBoard", id: "moodboard") {
            MoodBoardWindowView()
                .preferredColorScheme(colorSchemeString == "dark" ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unifiedCompact)
    }
}

// AppDelegate handles window configuration
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainWindow()

        // Observe for new windows (like MoodBoard)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    private func configureMainWindow() {
        if let window = NSApplication.shared.windows.first {
            // Ensure window starts in windowed mode
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }

            // Center the window on the screen
            window.center()

            // Remove any reserved title bar/toolbar space and extend content to full size
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar = nil
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }
            // Keep standard window capabilities off-screen; buttons are intentionally hidden
            // because we use a minimal chrome-less appearance.
        }
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // Configure MoodBoard window when it appears
        // Check if this is not the main window (first window)
        // MoodBoard windows are secondary windows created after the main window
        if window != NSApplication.shared.windows.first,
           window.styleMask.contains(.titled) {
            // Additional check: ensure it hasn't been configured already
            // by checking if closeButton is already hidden
            if window.standardWindowButton(.closeButton)?.isHidden != true {
                configureMoodBoardWindow(window)
            }
        }
    }

    private func configureMoodBoardWindow(_ window: NSWindow) {
        // Remove title bar and traffic lights completely
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = nil
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }

        // Hide traffic light buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

