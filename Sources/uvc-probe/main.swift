// Lists each UVC camera's controls with range and current value.
// `uvc-probe descriptor` prints each camera's configuration descriptor as hex (for test fixtures).
// `uvc-probe roundtrip` also writes each range control to a new value, reads it back, and restores it.
import Darwin
import UVCKit

let mode = CommandLine.arguments.dropFirst().first
let roundtrip = mode == "roundtrip"
var failures = 0

let cameras = UVCCamera.discover()
if cameras.isEmpty { print("No UVC cameras found.") }

for found in cameras {
    let cam = found.camera
    print("\(found.info.name) [\(found.info.modelKey)] location 0x\(String(found.info.locationID, radix: 16))")
    if mode == "descriptor" {
        let bytes = (try? UVCCamera.readConfigurationDescriptor(cam.transport)) ?? []
        print(bytes.map { String(format: "%02x", $0) }.joined())
        continue
    }
    print("  VC interface \(cam.layout.interfaceNumber), camera terminal \(cam.layout.cameraTerminal?.id ?? 0), processing unit \(cam.layout.processingUnit?.id ?? 0)")
    for spec in cam.supportedControls {
        do {
            let cur = try cam.get(spec)
            var line = "  \(spec.id.padding(toLength: 18, withPad: " ", startingAt: 0)) cur=\(cur)"
            if spec.kind == .range {
                let r = try cam.range(spec)
                line += "  min=\(r.min) max=\(r.max) step=\(r.step) def=\(r.defaultValue)"
                if roundtrip {
                    // Auto-driven controls only accept writes while their auto toggle is off.
                    let auto = spec.automaticBy.flatMap(Controls.spec)
                    let autoWas = try auto.map { try cam.get($0) }
                    if let auto, case .toggle(_, let off) = auto.kind { try cam.set(auto, off) }
                    let start = try cam.get(spec)
                    let target = start + r.step <= r.max ? start + r.step : start - r.step
                    try cam.set(spec, target)
                    let back = try cam.get(spec)
                    try cam.set(spec, cur)
                    if let auto, let autoWas { try cam.set(auto, autoWas) }
                    line += back == target ? "  roundtrip OK" : "  roundtrip FAIL (wrote \(target), read \(back))"
                    if back != target { failures += 1 }
                }
            }
            print(line)
        } catch {
            failures += 1
            print("  \(spec.id): \(error)")
        }
    }
}
exit(failures == 0 ? 0 : 1)
