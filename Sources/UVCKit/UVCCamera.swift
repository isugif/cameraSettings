/// Sends control requests on a USB device's default pipe. Real devices use `USBTransport`; tests use a stub.
public protocol ControlTransport {
    /// Returns the number of bytes transferred. `data` is read for OUT requests and filled for IN requests.
    func control(requestType: UInt8, request: UInt8, value: UInt16, index: UInt16, data: inout [UInt8]) throws -> Int
}

public struct ControlRange: Equatable, Sendable {
    public var min: Int
    public var max: Int
    public var step: Int
    public var defaultValue: Int
}

public enum UVCRequest: UInt8 {
    case setCur = 0x01
    case getCur = 0x81
    case getMin = 0x82
    case getMax = 0x83
    case getRes = 0x84
    case getDef = 0x87
}

/// UVC control access for one camera. Holds no UI or persistence state.
public final class UVCCamera {
    public let transport: ControlTransport
    public let layout: VideoControlLayout

    public init(transport: ControlTransport, layout: VideoControlLayout) {
        self.transport = transport
        self.layout = layout
    }

    /// Reads the device's configuration descriptor (GET_DESCRIPTOR, configuration 0).
    public static func readConfigurationDescriptor(_ transport: ControlTransport) throws -> [UInt8] {
        var header = [UInt8](repeating: 0, count: 9)
        _ = try transport.control(requestType: 0x80, request: 0x06, value: 0x0200, index: 0, data: &header)
        let total = Int(header[2]) | Int(header[3]) << 8
        var full = [UInt8](repeating: 0, count: total)
        let n = try transport.control(requestType: 0x80, request: 0x06, value: 0x0200, index: 0, data: &full)
        return Array(full.prefix(n))
    }

    /// Controls this camera advertises, in catalog order.
    public var supportedControls: [ControlSpec] {
        Controls.all.filter { layout.unit($0.unit)?.supports(bit: $0.bit) ?? false }
    }

    public func get(_ spec: ControlSpec, _ request: UVCRequest = .getCur) throws -> Int {
        let payload = try read(spec, request)
        return Codec.decode(payload, offset: spec.offset, width: spec.width, signed: spec.signed)
    }

    public func set(_ spec: ControlSpec, _ value: Int) throws {
        // Shared payloads (pan/tilt) are read first so the other field keeps its current value.
        var payload = spec.width < spec.payloadSize
            ? try read(spec, .getCur)
            : [UInt8](repeating: 0, count: spec.payloadSize)
        Codec.encode(value, into: &payload, offset: spec.offset, width: spec.width)
        _ = try transport.control(requestType: 0x21, request: UVCRequest.setCur.rawValue,
                                  value: UInt16(spec.selector) << 8, index: try index(for: spec), data: &payload)
    }

    public func range(_ spec: ControlSpec) throws -> ControlRange {
        ControlRange(min: try get(spec, .getMin), max: try get(spec, .getMax),
                     step: max(1, try get(spec, .getRes)), defaultValue: try get(spec, .getDef))
    }

    private func read(_ spec: ControlSpec, _ request: UVCRequest) throws -> [UInt8] {
        var payload = [UInt8](repeating: 0, count: spec.payloadSize)
        _ = try transport.control(requestType: 0xA1, request: request.rawValue,
                                  value: UInt16(spec.selector) << 8, index: try index(for: spec), data: &payload)
        return payload
    }

    private func index(for spec: ControlSpec) throws -> UInt16 {
        guard let unit = layout.unit(spec.unit) else { throw UVCError.unsupported(spec.id) }
        return UInt16(unit.id) << 8 | UInt16(layout.interfaceNumber)
    }
}

public enum UVCError: Error, CustomStringConvertible {
    case io(Int32)
    case openFailed(Int32)
    case unsupported(String)
    case notAVideoDevice

    public var description: String {
        switch self {
        case .io(let code): "USB request failed (\(ioReturnName(code)))"
        case .openFailed(let code): "Could not open device (\(ioReturnName(code)))"
        case .unsupported(let id): "Control \(id) is not supported by this camera"
        case .notAVideoDevice: "Device has no UVC video control interface"
        }
    }
}

func ioReturnName(_ code: Int32) -> String {
    switch UInt32(bitPattern: code) {
    case 0xE000_404F: "pipe stalled: the camera rejected the request"
    case 0xE000_02C5: "exclusive access: another process owns the device"
    case 0xE000_02E2: "not permitted"
    case 0xE000_02C0: "not found"
    case 0xE000_02D6: "timeout"
    default: String(format: "0x%08X", UInt32(bitPattern: code))
    }
}
