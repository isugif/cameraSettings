import SwiftUI
import UVCKit

struct ContentView: View {
    @Environment(CameraModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            PreviewView(info: model.selected?.info)
                .frame(minWidth: 480, minHeight: 270)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if model.cameras.isEmpty {
                    ContentUnavailableView("No camera", systemImage: "video.slash",
                                           description: Text("Plug in a USB webcam."))
                } else {
                    Picker("Camera", selection: $model.selectedKey) {
                        ForEach(model.cameras, id: \.info.modelKey) { cam in
                            Text(cam.info.name).tag(Optional(cam.info.modelKey))
                        }
                    }
                    .onChange(of: model.selectedKey) { model.reload() }
                    Form {
                        ForEach(model.controls) { state in
                            ControlRow(state: state, disabled: model.isAutomatic(state.spec)) { model.set(state.id, $0) }
                        }
                    }
                    .formStyle(.grouped)
                    HStack {
                        Button("Reset to defaults") { model.resetToDefaults() }
                        Spacer()
                        Button("Refresh") { model.rescan() }
                    }
                }
                if let error = model.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .padding()
            .frame(width: 360)
        }
    }
}

struct ControlRow: View {
    var state: ControlState
    var disabled: Bool
    var onChange: (Int) -> Void

    var body: some View {
        switch state.spec.kind {
        case .toggle(let on, let off):
            Toggle(state.spec.name, isOn: Binding(get: { state.value == on }, set: { onChange($0 ? on : off) }))
        case .choice(let choices):
            Picker(state.spec.name, selection: Binding(get: { state.value }, set: { onChange($0) })) {
                ForEach(choices, id: \.value) { Text($0.label).tag($0.value) }
            }
        case .range:
            if let range = state.range, range.max > range.min {
                LabeledContent(state.spec.name) {
                    Slider(value: Binding(get: { Double(state.value) }, set: { onChange(Int($0)) }),
                           in: Double(range.min) ... Double(range.max), step: Double(range.step))
                    Text("\(state.value)").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
                .disabled(disabled)
            }
        }
    }
}
