import AppKit
import SwiftUI

@main
struct CameraSettingsApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = CameraModel()

    var body: some Scene {
        Window("Camera Settings", id: "main") {
            ContentView().environment(model)
        }
        .windowResizability(.contentSize)

        // Stays running after the window closes, so settings are re-applied when the camera is replugged.
        MenuBarExtra("Camera Settings", systemImage: "web.camera") {
            MenuContent().environment(model)
        }
    }
}

private struct MenuContent: View {
    @Environment(CameraModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Camera Settings") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Button("Re-apply saved settings") { model.reapplySaved() }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
