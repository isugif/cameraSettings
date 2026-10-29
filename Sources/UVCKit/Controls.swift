/// The UVC unit a control is addressed to.
public enum UnitKind: Sendable {
    case cameraTerminal
    case processingUnit
}

/// How a control is presented and what values it takes.
public enum ControlKind: Equatable, Sendable {
    /// A numeric range read from the device (GET_MIN/MAX/RES/DEF).
    case range
    /// An on/off switch; `on` and `off` are the raw values written.
    case toggle(on: Int, off: Int)
    /// A fixed set of labelled values.
    case choice([Choice])

    public struct Choice: Equatable, Sendable {
        public var value: Int
        public var label: String
    }
}

/// One user-facing control. Several specs may share a selector (pan and tilt share one 8-byte payload).
public struct ControlSpec: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var unit: UnitKind
    public var selector: UInt8
    /// Bit in the unit's bmControls that advertises support.
    public var bit: Int
    public var payloadSize: Int
    public var offset: Int = 0
    public var width: Int
    public var signed: Bool = false
    public var kind: ControlKind = .range
    /// The toggle that, when on, makes the device drive this control itself.
    public var automaticBy: String?
}

public enum Controls {
    public static let all: [ControlSpec] = [
        ControlSpec(id: "zoom", name: "Zoom", unit: .cameraTerminal, selector: 0x0B, bit: 9, payloadSize: 2, width: 2),
        ControlSpec(id: "pan", name: "Pan", unit: .cameraTerminal, selector: 0x0D, bit: 11, payloadSize: 8, offset: 0, width: 4, signed: true),
        ControlSpec(id: "tilt", name: "Tilt", unit: .cameraTerminal, selector: 0x0D, bit: 11, payloadSize: 8, offset: 4, width: 4, signed: true),
        ControlSpec(id: "autoFocus", name: "Auto focus", unit: .cameraTerminal, selector: 0x08, bit: 17, payloadSize: 1, width: 1, kind: .toggle(on: 1, off: 0)),
        ControlSpec(id: "focus", name: "Focus", unit: .cameraTerminal, selector: 0x06, bit: 5, payloadSize: 2, width: 2, automaticBy: "autoFocus"),
        // AE mode is a bitmap: 1 = manual, 8 = aperture priority (what UVC webcams call "auto").
        ControlSpec(id: "autoExposure", name: "Auto exposure", unit: .cameraTerminal, selector: 0x02, bit: 1, payloadSize: 1, width: 1, kind: .toggle(on: 8, off: 1)),
        ControlSpec(id: "exposure", name: "Exposure", unit: .cameraTerminal, selector: 0x04, bit: 3, payloadSize: 4, width: 4, automaticBy: "autoExposure"),
        ControlSpec(id: "autoWhiteBalance", name: "Auto white balance", unit: .processingUnit, selector: 0x0B, bit: 12, payloadSize: 1, width: 1, kind: .toggle(on: 1, off: 0)),
        ControlSpec(id: "whiteBalance", name: "White balance", unit: .processingUnit, selector: 0x0A, bit: 6, payloadSize: 2, width: 2, automaticBy: "autoWhiteBalance"),
        ControlSpec(id: "brightness", name: "Brightness", unit: .processingUnit, selector: 0x02, bit: 0, payloadSize: 2, width: 2, signed: true),
        ControlSpec(id: "contrast", name: "Contrast", unit: .processingUnit, selector: 0x03, bit: 1, payloadSize: 2, width: 2),
        ControlSpec(id: "saturation", name: "Saturation", unit: .processingUnit, selector: 0x07, bit: 3, payloadSize: 2, width: 2),
        ControlSpec(id: "sharpness", name: "Sharpness", unit: .processingUnit, selector: 0x08, bit: 4, payloadSize: 2, width: 2),
        ControlSpec(id: "gain", name: "Gain", unit: .processingUnit, selector: 0x04, bit: 9, payloadSize: 2, width: 2, automaticBy: "autoExposure"),
        ControlSpec(id: "backlight", name: "Backlight compensation", unit: .processingUnit, selector: 0x01, bit: 8, payloadSize: 2, width: 2),
        ControlSpec(id: "powerLine", name: "Anti-flicker", unit: .processingUnit, selector: 0x05, bit: 10, payloadSize: 1, width: 1,
                    kind: .choice([.init(value: 0, label: "Off"), .init(value: 1, label: "50 Hz"), .init(value: 2, label: "60 Hz")])),
    ]

    public static func spec(_ id: String) -> ControlSpec? {
        all.first { $0.id == id }
    }
}

// Little-endian integer packing for control payloads.
enum Codec {
    static func decode(_ bytes: [UInt8], offset: Int, width: Int, signed: Bool) -> Int {
        var raw: UInt64 = 0
        for k in 0 ..< width {
            raw |= UInt64(bytes[offset + k]) << (8 * UInt64(k))
        }
        if signed, width < 8, raw & (1 << (UInt64(width) * 8 - 1)) != 0 {
            raw |= ~UInt64(0) << (UInt64(width) * 8)
        }
        return Int(Int64(bitPattern: raw))
    }

    static func encode(_ value: Int, into bytes: inout [UInt8], offset: Int, width: Int) {
        let raw = UInt64(bitPattern: Int64(value))
        for k in 0 ..< width {
            bytes[offset + k] = UInt8(truncatingIfNeeded: raw >> (8 * UInt64(k)))
        }
    }
}
