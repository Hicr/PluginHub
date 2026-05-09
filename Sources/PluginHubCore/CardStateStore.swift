import Foundation

public struct CardState: Codable, Equatable, Sendable {
    public var isExpanded: Bool

    public init(isExpanded: Bool = true) {
        self.isExpanded = isExpanded
    }
}

public struct CardStateStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL = CardStateStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        ConfigStore.defaultConfigurationDirectoryURL().appendingPathComponent("card-states.json")
    }

    private func loadAll() -> [String: CardState] {
        guard let data = try? Data(contentsOf: fileURL),
              let states = try? PluginHubJSON.decoder().decode([String: CardState].self, from: data) else {
            return [:]
        }
        return states
    }

    public func load(for stateID: String) -> CardState {
        loadAll()[stateID] ?? CardState()
    }

    public func save(for stateID: String, state: CardState) {
        var states = loadAll()
        states[stateID] = state
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? PluginHubJSON.encoder().encode(states) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
