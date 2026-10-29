/// Where a UVC camera's controls live, as declared by its USB configuration descriptor.
public struct VideoControlLayout: Equatable, Sendable {
    public var interfaceNumber: UInt8
    public var cameraTerminal: Unit?
    public var processingUnit: Unit?

    public struct Unit: Equatable, Sendable {
        public var id: UInt8
        /// Little-endian bitmap of supported controls (bit N = byte N/8, bit N%8).
        public var controls: [UInt8]

        public func supports(bit: Int) -> Bool {
            let byte = bit / 8
            return byte < controls.count && controls[byte] & (1 << UInt8(bit % 8)) != 0
        }
    }

    public func unit(_ kind: UnitKind) -> Unit? {
        switch kind {
        case .cameraTerminal: cameraTerminal
        case .processingUnit: processingUnit
        }
    }
}

private enum DescriptorType {
    static let interface: UInt8 = 0x04
    static let classSpecificInterface: UInt8 = 0x24
}

private enum VC {
    static let videoClass: UInt8 = 0x0E
    static let controlSubclass: UInt8 = 0x01
    static let inputTerminal: UInt8 = 0x02
    static let processingUnit: UInt8 = 0x05
    static let cameraTerminalType: UInt16 = 0x0201
}

/// Parses a full configuration descriptor. Returns nil when the device has no UVC VideoControl interface.
public func parseVideoControlLayout(_ bytes: [UInt8]) -> VideoControlLayout? {
    var layout: VideoControlLayout?
    var inVideoControl = false
    var i = 0
    while i + 2 <= bytes.count {
        let length = Int(bytes[i])
        guard length >= 2, i + length <= bytes.count else { break }
        let d = Array(bytes[i ..< i + length])
        i += length

        switch d[1] {
        case DescriptorType.interface where length >= 9:
            inVideoControl = d[5] == VC.videoClass && d[6] == VC.controlSubclass
            if inVideoControl, layout == nil {
                layout = VideoControlLayout(interfaceNumber: d[2])
            }
        case DescriptorType.classSpecificInterface where inVideoControl && length >= 3:
            switch d[2] {
            case VC.inputTerminal where length >= 15:
                let terminalType = UInt16(d[4]) | UInt16(d[5]) << 8
                guard terminalType == VC.cameraTerminalType else { break }
                let size = Int(d[14])
                guard 15 + size <= length else { break }
                layout?.cameraTerminal = .init(id: d[3], controls: Array(d[15 ..< 15 + size]))
            case VC.processingUnit where length >= 8:
                let size = Int(d[7])
                guard 8 + size <= length else { break }
                layout?.processingUnit = .init(id: d[3], controls: Array(d[8 ..< 8 + size]))
            default:
                break
            }
        default:
            break
        }
    }
    return layout
}

extension VideoControlLayout {
    init(interfaceNumber: UInt8) {
        self.init(interfaceNumber: interfaceNumber, cameraTerminal: nil, processingUnit: nil)
    }
}
