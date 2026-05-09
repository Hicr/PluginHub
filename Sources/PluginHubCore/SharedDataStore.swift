import Foundation

public struct SharedDataStore: Sendable {
    public var directoryURL: URL

    public init(directoryURL: URL = SharedDataStore.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
    }

    public static func defaultDirectoryURL() -> URL {
        ConfigStore.defaultConfigurationDirectoryURL().appendingPathComponent("shared", isDirectory: true)
    }

    public func save(stateID: String, state: PluginCachedState) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("\(stateID).json")
        guard let data = try? PluginHubJSON.encoder().encode(state) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    public func load(stateID: String) -> PluginCachedState? {
        let fileURL = directoryURL.appendingPathComponent("\(stateID).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? PluginHubJSON.decoder().decode(PluginCachedState.self, from: data)
    }
}
