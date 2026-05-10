import Foundation

public struct WidgetConfig: Codable, Equatable, Sendable {
    public var pluginID: String?
    public var componentIndex: Int

    public init(pluginID: String? = nil, componentIndex: Int = 0) {
        self.pluginID = pluginID
        self.componentIndex = componentIndex
    }
}

public struct WidgetPluginInfo: Codable, Equatable, Sendable {
    public var pluginID: String
    public var pluginName: String
    public var icon: String?
    public var components: [WidgetComponentInfo]

    public init(pluginID: String, pluginName: String, icon: String? = nil, components: [WidgetComponentInfo] = []) {
        self.pluginID = pluginID
        self.pluginName = pluginName
        self.icon = icon
        self.components = components
    }
}

public struct WidgetComponentInfo: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var type: String

    public init(id: String, label: String, type: String) {
        self.id = id
        self.label = label
        self.type = type
    }
}

public struct WidgetDataStore: Sendable {
    public let appGroupID: String

    public init(appGroupID: String = "R7GQ9HSA5W.com.pluginhub.widget") {
        self.appGroupID = appGroupID
    }

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    // MARK: - Snapshots

    public func saveSnapshot(stateID: String, cached: PluginCachedState) {
        guard let dir = containerURL?.appendingPathComponent("snapshots", isDirectory: true) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("\(stateID).json")
        guard let data = try? PluginHubJSON.encoder().encode(cached) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    public func loadSnapshot(stateID: String) -> PluginCachedState? {
        guard let fileURL = containerURL?.appendingPathComponent("snapshots/\(stateID).json") else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? PluginHubJSON.decoder().decode(PluginCachedState.self, from: data)
    }

    // MARK: - Plugin List

    public func savePluginList(_ plugins: [WidgetPluginInfo]) {
        guard let dir = containerURL else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("plugin-list.json")
        guard let data = try? PluginHubJSON.encoder().encode(plugins) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    public func loadPluginList() -> [WidgetPluginInfo] {
        guard let fileURL = containerURL?.appendingPathComponent("plugin-list.json"),
              let data = try? Data(contentsOf: fileURL),
              let list = try? PluginHubJSON.decoder().decode([WidgetPluginInfo].self, from: data) else {
            return []
        }
        return list
    }

    // MARK: - Widget Config

    public func saveWidgetConfig(_ config: WidgetConfig) {
        guard let dir = containerURL else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("widget-config.json")
        guard let data = try? PluginHubJSON.encoder().encode(config) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    public func loadWidgetConfig() -> WidgetConfig? {
        guard let fileURL = containerURL?.appendingPathComponent("widget-config.json"),
              let data = try? Data(contentsOf: fileURL),
              let config = try? PluginHubJSON.decoder().decode(WidgetConfig.self, from: data) else {
            return nil
        }
        return config
    }
}
