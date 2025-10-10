VisualInspiration - How to Open on macOS (Un-notarized Build)

Thank you for trying VisualInspiration!

Because this build is shared outside the App Store and is not notarized, macOS Gatekeeper may warn you that the app is from an unidentified developer. This is normal for personal sharing.

Option A) Fastest Way (Right-click Open)
1. Move `VisualInspiration.app` to your Applications folder.
2. Right-click (control-click) `VisualInspiration.app` → click `Open`.
3. In the dialog, click `Open`. You will only need to do this once.

Option B) Allow from Privacy & Security
1. Try to open `VisualInspiration.app` once (it will be blocked).
2. Open System Settings → Privacy & Security.
3. Scroll to the Security section, click `Open Anyway` next to `VisualInspiration.app`.

Option C) Terminal (for power users)
1. Move the app to Applications.
2. Open Terminal and run:
   xattr -dr com.apple.quarantine /Applications/VisualInspiration.app

Notes
- This build is not notarized, so Gatekeeper shows a warning the first time.
- If you prefer a warning-free experience, use a notarized build.
- On first run, the app may ask for file access when you choose download locations.

Uninstall
Drag `VisualInspiration.app` to the Trash. There is no system-wide installer.



