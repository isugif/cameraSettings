import CUSB
import Foundation

public struct USBDeviceInfo: Hashable, Sendable {
    public var vendorID: UInt16
    public var productID: UInt16
    public var locationID: UInt32
    public var name: String

    /// Stable across ports and replugs, unlike `locationID`.
    public var modelKey: String { String(format: "%04x:%04x", vendorID, productID) }
}

/// A `ControlTransport` backed by IOKit.
public final class USBTransport: ControlTransport {
    private let handle: OpaquePointer

    public init(locationID: UInt32) throws {
        var err: Int32 = 0
        guard let handle = cusb_open(locationID, &err) else { throw UVCError.openFailed(err) }
        self.handle = handle
    }

    deinit { cusb_close(handle) }

    public func control(requestType: UInt8, request: UInt8, value: UInt16, index: UInt16, data: inout [UInt8]) throws -> Int {
        var transferred: UInt32 = 0
        let kr = data.withUnsafeMutableBytes { buf in
            cusb_control(handle, requestType, request, value, index, buf.baseAddress, UInt16(buf.count), &transferred)
        }
        guard kr == 0 else { throw UVCError.io(kr) }
        return Int(transferred)
    }

    public static func allDevices() -> [USBDeviceInfo] {
        var buffer = [cusb_device_info](repeating: cusb_device_info(), count: 64)
        let n = min(Int(cusb_list_devices(&buffer, Int32(buffer.count))), buffer.count)
        return buffer.prefix(n).map { info in
            let name = withUnsafeBytes(of: info.name) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
            return USBDeviceInfo(vendorID: info.vendor_id, productID: info.product_id, locationID: info.location_id, name: name)
        }
    }
}

public struct ConnectedCamera {
    public var info: USBDeviceInfo
    public var camera: UVCCamera
}

extension UVCCamera {
    /// Opens every attached USB device that exposes a UVC VideoControl interface.
    public static func discover() -> [ConnectedCamera] {
        USBTransport.allDevices().compactMap { info in
            guard let transport = try? USBTransport(locationID: info.locationID),
                  let descriptor = try? readConfigurationDescriptor(transport),
                  let layout = parseVideoControlLayout(descriptor) else { return nil }
            return ConnectedCamera(info: info, camera: UVCCamera(transport: transport, layout: layout))
        }
    }
}
