import Foundation
import Testing
@testable import UVCKit

/// Behaves like a camera: remembers SET_CUR payloads per (selector, unit) and answers GET_CUR from them.
final class StubTransport: ControlTransport {
    var sent: [(request: UInt8, value: UInt16, index: UInt16, data: [UInt8])] = []
    var replies: [UInt8: [UInt8]] = [:]
    var state: [UInt32: [UInt8]] = [:]

    func control(requestType: UInt8, request: UInt8, value: UInt16, index: UInt16, data: inout [UInt8]) throws -> Int {
        sent.append((request, value, index, data))
        let key = UInt32(value) << 16 | UInt32(index)
        if request == UVCRequest.setCur.rawValue {
            state[key] = data
        } else if request == UVCRequest.getCur.rawValue, let saved = state[key] {
            data = saved
        } else if requestType & 0x80 != 0, let reply = replies[request] {
            data = Array(reply.prefix(data.count))
        }
        return data.count
    }

    var writes: [UInt16] { sent.filter { $0.request == UVCRequest.setCur.rawValue }.map(\.value) }
}

func fixture(_ name: String) throws -> [UInt8] {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "hex", subdirectory: "Fixtures"))
    let hex = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    var bytes: [UInt8] = []
    var i = hex.startIndex
    while i < hex.endIndex {
        let j = hex.index(i, offsetBy: 2)
        bytes.append(UInt8(hex[i ..< j], radix: 16)!)
        i = j
    }
    return bytes
}

@Test func parsesC930eDescriptor() throws {
    let layout = try #require(parseVideoControlLayout(try fixture("c930e-config")))
    #expect(layout.interfaceNumber == 0)
    #expect(layout.cameraTerminal?.id == 1)
    #expect(layout.processingUnit?.id == 3)

    let camera = UVCCamera(transport: StubTransport(), layout: layout)
    #expect(camera.supportedControls.map(\.id) == Controls.all.map(\.id))
}

@Test func nonVideoDescriptorHasNoLayout() {
    // Configuration header + one mass-storage interface.
    let bytes: [UInt8] = [9, 2, 18, 0, 1, 1, 0, 0x80, 50,
                          9, 4, 0, 0, 2, 0x08, 0x06, 0x50, 0]
    #expect(parseVideoControlLayout(bytes) == nil)
}

@Test func truncatedDescriptorDoesNotCrash() throws {
    let bytes = try fixture("c930e-config")
    for cut in stride(from: 0, to: bytes.count, by: 7) {
        _ = parseVideoControlLayout(Array(bytes.prefix(cut)))
    }
}

@Test func codecRoundTripsSignedValues() {
    var bytes = [UInt8](repeating: 0, count: 8)
    Codec.encode(-36000, into: &bytes, offset: 4, width: 4)
    #expect(Codec.decode(bytes, offset: 4, width: 4, signed: true) == -36000)
    #expect(Codec.decode(bytes, offset: 0, width: 4, signed: true) == 0)
    Codec.encode(-1, into: &bytes, offset: 0, width: 2)
    #expect(Codec.decode(bytes, offset: 0, width: 2, signed: true) == -1)
    #expect(Codec.decode(bytes, offset: 0, width: 2, signed: false) == 0xFFFF)
}

@Test func settingPanKeepsTilt() throws {
    let layout = try #require(parseVideoControlLayout(try fixture("c930e-config")))
    let stub = StubTransport()
    var current = [UInt8](repeating: 0, count: 8)
    Codec.encode(7200, into: &current, offset: 4, width: 4) // tilt = 7200
    stub.replies[UVCRequest.getCur.rawValue] = current

    try UVCCamera(transport: stub, layout: layout).set(Controls.spec("pan")!, -3600)

    let write = try #require(stub.sent.last)
    #expect(write.request == UVCRequest.setCur.rawValue)
    #expect(write.value == 0x0D00)
    #expect(write.index == 0x0100) // camera terminal 1, interface 0
    #expect(Codec.decode(write.data, offset: 0, width: 4, signed: true) == -3600)
    #expect(Codec.decode(write.data, offset: 4, width: 4, signed: true) == 7200)
}

@Test func processingUnitRequestsAddressUnit3() throws {
    let layout = try #require(parseVideoControlLayout(try fixture("c930e-config")))
    let stub = StubTransport()
    try UVCCamera(transport: stub, layout: layout).set(Controls.spec("brightness")!, 140)
    let write = try #require(stub.sent.last)
    #expect(write.index == 0x0300)
    #expect(write.data == [140, 0])
}

@Test func applyWritesModesFirstAndSkipsAutomaticValues() throws {
    let layout = try #require(parseVideoControlLayout(try fixture("c930e-config")))
    let stub = StubTransport()
    let camera = UVCCamera(transport: stub, layout: layout)

    let failures = camera.apply(["focus": 50, "autoFocus": 0, "whiteBalance": 5000, "autoWhiteBalance": 1])

    #expect(failures.isEmpty)
    // autoFocus (0x08) then autoWhiteBalance (0x0B) before focus (0x06); whiteBalance skipped because auto is on.
    #expect(stub.writes == [0x0800, 0x0B00, 0x0600])
    #expect(try camera.get(Controls.spec("focus")!) == 50)
}
