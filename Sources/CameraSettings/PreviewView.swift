@preconcurrency import AVFoundation
import SwiftUI
import UVCKit

/// Live preview of the AVFoundation device matching a USB camera.
struct PreviewView: NSViewRepresentable {
    var info: USBDeviceInfo?

    func makeNSView(context: Context) -> PreviewNSView { PreviewNSView() }

    func updateNSView(_ view: PreviewNSView, context: Context) {
        view.show(info)
    }
}

final class PreviewNSView: NSView {
    private let session = AVCaptureSession()
    private var shownID: String?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspect
        layer = preview
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Release the camera when the window closes; the app keeps running in the menu bar.
        if window == nil {
            let session = self.session
            DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
            shownID = nil
        }
    }

    func show(_ info: USBDeviceInfo?) {
        // AVFoundation's uniqueID for a USB camera is 0x<locationID><vendorID><productID>.
        let id = info.map { String(format: "0x%x%04x%04x", $0.locationID, $0.vendorID, $0.productID) }
        guard id != shownID else { return }
        shownID = id

        let session = self.session
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }
            let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: .video, position: .unspecified)
                .devices.first { $0.uniqueID.lowercased() == id }
            DispatchQueue.global(qos: .userInitiated).async {
                session.beginConfiguration()
                session.inputs.forEach(session.removeInput)
                if let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
                if !session.isRunning { session.startRunning() }
            }
        }
    }
}
