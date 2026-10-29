extension UVCCamera {
    /// True when the toggle that drives `spec` is currently on, so the camera ignores manual values.
    public func isAutomatic(_ spec: ControlSpec) throws -> Bool {
        guard let auto = spec.automaticBy.flatMap(Controls.spec),
              case .toggle(let on, _) = auto.kind,
              supportedControls.contains(auto) else { return false }
        return try get(auto) == on
    }

    /// Writes saved values by control id. Modes go first so the camera accepts the manual values
    /// that follow; values currently under automatic control are skipped. Returns failures by id.
    @discardableResult
    public func apply(_ values: [String: Int]) -> [String: Error] {
        var failures: [String: Error] = [:]
        let specs = supportedControls.filter { values[$0.id] != nil }
        let modes = specs.filter { $0.kind != .range }
        let levels = specs.filter { $0.kind == .range }

        for spec in modes {
            do { try set(spec, values[spec.id]!) } catch { failures[spec.id] = error }
        }
        for spec in levels {
            do {
                if try isAutomatic(spec) { continue }
                try set(spec, values[spec.id]!)
            } catch {
                failures[spec.id] = error
            }
        }
        return failures
    }
}
