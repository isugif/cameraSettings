import Foundation
import Observation
import UVCKit

/// One control as shown in the UI.
struct ControlState: Identifiable {
    var spec: ControlSpec
    var value: Int
    var range: ControlRange?
    var id: String { spec.id }
}

@MainActor @Observable
final class CameraModel {
    private(set) var cameras: [ConnectedCamera] = []
    var selectedKey: String?
    private(set) var controls: [ControlState] = []
    private(set) var lastError: String?

    private let store = SettingsStore()
    private var watcher: DeviceWatcher?

    var selected: ConnectedCamera? {
        cameras.first { $0.info.modelKey == selectedKey } ?? cameras.first
    }

    init() {
        rescan()
        watcher = DeviceWatcher { [weak self] in self?.rescan() }
    }

    /// Re-discovers cameras and re-applies saved settings, since UVC cameras forget them on unplug.
    func rescan() {
        let previous = Set(cameras.map(\.info))
        cameras = UVCCamera.discover()
        cameras.filter { !previous.contains($0.info) }.forEach(restore)
        if !cameras.contains(where: { $0.info.modelKey == selectedKey }) {
            selectedKey = cameras.first?.info.modelKey
        }
        reload()
    }

    func reapplySaved() {
        cameras.forEach(restore)
        reload()
    }

    private func restore(_ cam: ConnectedCamera) {
        let failures = cam.camera.apply(store.load(cam.info.modelKey))
        if let (id, error) = failures.first { lastError = "Restoring \(id): \(error)" }
    }

    func reload() {
        guard let cam = selected?.camera else { controls = []; return }
        controls = cam.supportedControls.compactMap { spec in
            guard let value = try? cam.get(spec) else { return nil }
            let range = spec.kind == .range ? try? cam.range(spec) : nil
            return ControlState(spec: spec, value: value, range: range)
        }
    }

    func isAutomatic(_ spec: ControlSpec) -> Bool {
        guard let auto = spec.automaticBy,
              let state = controls.first(where: { $0.id == auto }),
              case .toggle(let on, _) = state.spec.kind else { return false }
        return state.value == on
    }

    func set(_ id: String, _ value: Int) {
        guard let cam = selected, let i = controls.firstIndex(where: { $0.id == id }) else { return }
        do {
            try cam.camera.set(controls[i].spec, value)
            lastError = nil
        } catch {
            lastError = "\(controls[i].spec.name): \(error)"
        }
        // Read back: the camera may clamp the value, and toggling auto changes the values it drives.
        if controls[i].spec.kind == .range {
            controls[i].value = (try? cam.camera.get(controls[i].spec)) ?? value
        } else {
            reload()
        }
        save()
    }

    func resetToDefaults() {
        guard let cam = selected?.camera else { return }
        // Defaults for toggles are not exposed by every camera, so auto modes go back on.
        var values: [String: Int] = [:]
        for state in controls {
            switch state.spec.kind {
            case .toggle(let on, _): values[state.id] = on
            case .choice: values[state.id] = (try? cam.get(state.spec, .getDef)) ?? state.value
            case .range: values[state.id] = state.range?.defaultValue ?? state.value
            }
        }
        cam.apply(values)
        reload()
        save()
    }

    private func save() {
        guard let cam = selected else { return }
        store.save(Dictionary(uniqueKeysWithValues: controls.map { ($0.id, $0.value) }), for: cam.info.modelKey)
    }
}
