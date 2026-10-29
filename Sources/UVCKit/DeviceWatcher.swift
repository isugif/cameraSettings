import Foundation
import IOKit
import IOKit.usb

/// Calls `onChange` on the main run loop whenever a USB device is attached or removed.
@MainActor
public final class DeviceWatcher {
    private let port: IONotificationPortRef
    private var iterators: [io_iterator_t] = []
    private let onChange: @MainActor () -> Void

    public init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        port = IONotificationPortCreate(kIOMainPortDefault)
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { context, iterator in
            DeviceWatcher.drain(iterator)
            let watcher = Unmanaged<DeviceWatcher>.fromOpaque(context!).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.onChange() }
        }
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            IOServiceAddMatchingNotification(port, type, IOServiceMatching(kIOUSBDeviceClassName), callback, context, &iterator)
            // Draining arms the notification; the initial batch is existing devices, so it is not reported.
            DeviceWatcher.drain(iterator)
            iterators.append(iterator)
        }
    }

    isolated deinit {
        iterators.forEach { IOObjectRelease($0) }
        IONotificationPortDestroy(port)
    }

    nonisolated private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }
}
