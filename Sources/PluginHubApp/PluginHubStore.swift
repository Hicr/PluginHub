import AppKit
import Darwin
import Foundation
import PluginHubCore

@MainActor
final class PluginHubStore: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published private(set) var snapshots: [UUID: PluginSnapshot] = [:]
    @Published var lastError: String?
    @Published var selectedPluginID: UUID?

    private let configStore: ConfigStore
    private let stateStore: PluginStateStore
    private let sharedDataStore: SharedDataStore
    private let cardStateStore: CardStateStore
    private let notificationManager: NotificationManager
    private let executor: PluginExecutor
    private var refreshTasks: [UUID: Task<Void, Never>] = [:]
    private var fileMonitors: [UUID: DispatchSourceFileSystemObject] = [:]
    @Published var cardExpandedStates: [UUID: Bool] = [:]

    private var triggersDirURL: URL {
        configStore.fileURL.deletingLastPathComponent().appendingPathComponent("triggers", isDirectory: true)
    }

    init(
        configStore: ConfigStore = ConfigStore(),
        stateStore: PluginStateStore = PluginStateStore(),
        sharedDataStore: SharedDataStore = SharedDataStore(),
        cardStateStore: CardStateStore = CardStateStore(),
        notificationManager: NotificationManager = NotificationManager(),
        executor: PluginExecutor = PluginExecutor()
    ) {
        self.configStore = configStore
        self.stateStore = stateStore
        self.sharedDataStore = sharedDataStore
        self.cardStateStore = cardStateStore
        self.notificationManager = notificationManager
        self.executor = executor
        var didLoadConfiguration = false
        do {
            configuration = try configStore.loadOrCreate()
            didLoadConfiguration = true
        } catch {
            configuration = AppConfiguration()
            lastError = "配置加载失败：\(error.localizedDescription)"
        }
        if didLoadConfiguration {
            try? configStore.save(configuration)
        }
        do {
            try installBundledPlugins()
        } catch {
            lastError = "内置插件安装失败：\(error.localizedDescription)"
        }
        syncMissingPluginsFromDirectory()
        reloadAllMetadata()
        try? configStore.save(configuration)
        loadCardStates()
        rebuildSnapshots()
        loadCachedStates()
        startSchedulers()
        startFileMonitors()
    }

    deinit {
        refreshTasks.values.forEach { $0.cancel() }
        fileMonitors.values.forEach { $0.cancel() }
    }

    var displayNames: [UUID: String] {
        var counts: [String: Int] = [:]
        var names: [UUID: String] = [:]
        for plugin in configuration.plugins {
            let baseName = plugin.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名" : plugin.name
            let nextCount = (counts[baseName] ?? 0) + 1
            counts[baseName] = nextCount
            names[plugin.id] = nextCount == 1 ? baseName : "\(baseName) \(nextCount)"
        }
        return names
    }

    var pluginsDirectoryURL: URL {
        configStore.pluginsDirectoryURL()
    }

    func snapshot(for plugin: PluginConfiguration) -> PluginSnapshot {
        if let snapshot = snapshots[plugin.id] {
            return snapshot
        }
        return makeSnapshot(for: plugin)
    }

    func saveConfiguration() {
        do {
            try configStore.save(configuration)
            lastError = nil
            rebuildSnapshots()
            startSchedulers()
            startFileMonitors()
            refreshPluginsAfterConfigurationChange()
        } catch {
            lastError = "配置保存失败：\(error.localizedDescription)"
        }
    }

    func addPlugin(fileURL: URL) {
        let metadata = PluginMetadataParser.parse(fileURL: fileURL)
        let name = metadata?.name ?? fileURL.deletingPathExtension().lastPathComponent
        var values: [String: String] = [:]
        for parameter in metadata?.parameters ?? [] {
            if let defaultValue = parameter.defaultValue {
                values[parameter.name] = defaultValue
            }
        }

        let plugin = PluginConfiguration(
            name: name,
            enabled: false,
            executablePath: fileURL.path,
            refreshIntervalSeconds: 300,
            metadata: metadata,
            parameterValues: values
        )
        configuration.plugins.append(plugin)
        snapshots[plugin.id] = makeSnapshot(for: plugin)
        saveConfiguration()
    }

    func ensurePluginsDirectory() {
        do {
            try FileManager.default.createDirectory(at: pluginsDirectoryURL, withIntermediateDirectories: true)
        } catch {
            lastError = "插件目录创建失败：\(error.localizedDescription)"
        }
    }

    func setPluginEnabled(id: UUID, enabled: Bool) {
        guard let index = configuration.plugins.firstIndex(where: { $0.id == id }) else { return }

        guard enabled else {
            configuration.plugins[index].enabled = false
            saveConfiguration()
            return
        }

        let missing = missingRequiredParameters(for: configuration.plugins[index])
        guard missing.isEmpty else {
            configuration.plugins[index].enabled = false
            lastError = "请先填写必填参数：\(missing.joined(separator: "、"))"
            return
        }

        configuration.plugins[index].enabled = true
        lastError = nil
        saveConfiguration()

        snapshots[id] = makeSnapshot(
            for: configuration.plugins[index],
            state: .loading,
            components: snapshots[id]?.components ?? [],
            updatedAt: snapshots[id]?.updatedAt
        )
        refresh(pluginID: id, force: true)
    }

    func reloadMetadata(pluginID: UUID) {
        guard let index = configuration.plugins.firstIndex(where: { $0.id == pluginID }) else { return }
        let fileURL = URL(fileURLWithPath: configuration.plugins[index].executablePath)
        let metadata = PluginMetadataParser.parse(fileURL: fileURL)
        configuration.plugins[index].metadata = metadata

        for parameter in metadata?.parameters ?? [] where configuration.plugins[index].parameterValues[parameter.name] == nil {
            configuration.plugins[index].parameterValues[parameter.name] = parameter.defaultValue ?? ""
        }
    }

    private func reloadAllMetadata() {
        for plugin in configuration.plugins {
            reloadMetadata(pluginID: plugin.id)
        }
    }

    func removePlugin(id: UUID) {
        guard let index = configuration.plugins.firstIndex(where: { $0.id == id }) else { return }
        configuration.plugins.remove(at: index)
        snapshots.removeValue(forKey: id)
        refreshTasks[id]?.cancel()
        refreshTasks.removeValue(forKey: id)
        saveConfiguration()
    }

    func refreshAll() {
        for plugin in configuration.plugins where plugin.enabled {
            refresh(pluginID: plugin.id, force: true)
        }
    }

    func refresh(pluginID: UUID, force: Bool = false) {
        guard let plugin = configuration.plugins.first(where: { $0.id == pluginID }) else { return }
        guard plugin.enabled else { return }
        guard force || stateStore.needsRefresh(stateID: plugin.stateID, intervalSeconds: plugin.refreshIntervalSeconds) else { return }

        snapshots[plugin.id] = makeSnapshot(
            for: plugin,
            state: .loading,
            components: snapshots[plugin.id]?.components ?? [],
            updatedAt: snapshots[plugin.id]?.updatedAt,
            badge: snapshots[plugin.id]?.badge
        )

        let executor = executor
        let stateStore = stateStore
        let sharedDataStore = sharedDataStore
        let displayName = displayNames[plugin.id] ?? plugin.name
        let sharedDir = sharedDataStore.directoryURL.path
        let triggerFile = triggerFilePath(for: plugin.stateID)
        let thermalState = thermalStateString()
        Task {
            let snapshot = await Task.detached(priority: .utility) {
                executor.run(configuration: plugin, displayName: displayName, sharedDir: sharedDir, triggerFile: triggerFile, thermalState: thermalState)
            }.value
            snapshots[plugin.id] = snapshot
            if case .ready = snapshot.state, let updatedAt = snapshot.updatedAt {
                if let notification = snapshot.notification {
                    sendNotificationIfNeeded(notification)
                }
                let cached = PluginCachedState(
                    updatedAt: updatedAt,
                    components: snapshot.components,
                    badge: snapshot.badge,
                    title: snapshot.title,
                    icon: snapshot.icon
                )
                stateStore.save(stateID: plugin.stateID, state: cached)
                sharedDataStore.save(stateID: plugin.stateID, state: cached)
            }
        }
    }

    func missingRequiredParameters(for plugin: PluginConfiguration) -> [String] {
        var missing: [String] = []
        for parameter in plugin.metadata?.parameters ?? [] where parameter.required {
            let value = plugin.parameterValues[parameter.name] ?? parameter.defaultValue ?? ""
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missing.append(parameter.label)
            }
        }
        return missing
    }

    private func installBundledPlugins() throws {
        guard let sourceURL = bundledPluginsDirectoryURL() else { return }
        let installed = try BundledPluginInstaller(
            sourceDirectoryURL: sourceURL,
            destinationDirectoryURL: configStore.pluginsDirectoryURL()
        )
        .installIfNeeded()
        for url in installed {
            let path = url.path
            guard !configuration.plugins.contains(where: { $0.executablePath == path }) else { continue }
            let metadata = PluginMetadataParser.parse(fileURL: url)
            let name = metadata?.name ?? url.deletingPathExtension().lastPathComponent
            var values: [String: String] = [:]
            for param in metadata?.parameters ?? [] {
                if let dv = param.defaultValue { values[param.name] = dv }
            }
            configuration.plugins.append(PluginConfiguration(
                name: name,
                enabled: false,
                executablePath: path,
                refreshIntervalSeconds: 300,
                metadata: metadata,
                parameterValues: values
            ))
        }
    }

    private func syncMissingPluginsFromDirectory() {
        let dirURL = configStore.pluginsDirectoryURL()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension == "py" {
            guard !configuration.plugins.contains(where: { $0.executablePath == url.path }) else { continue }
            let metadata = PluginMetadataParser.parse(fileURL: url)
            let name = metadata?.name ?? url.deletingPathExtension().lastPathComponent
            var values: [String: String] = [:]
            for param in metadata?.parameters ?? [] {
                if let dv = param.defaultValue { values[param.name] = dv }
            }
            configuration.plugins.append(PluginConfiguration(
                name: name,
                enabled: false,
                executablePath: url.path,
                refreshIntervalSeconds: 300,
                metadata: metadata,
                parameterValues: values
            ))
        }
    }

    private func bundledPluginsDirectoryURL() -> URL? {
        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/BundledPlugins", isDirectory: true)
        if FileManager.default.fileExists(atPath: developmentURL.path) {
            return developmentURL
        }

        if let appResourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("Plugins", isDirectory: true),
            FileManager.default.fileExists(atPath: appResourceURL.path) {
            return appResourceURL
        }

        return nil
    }

    private func rebuildSnapshots() {
        var next: [UUID: PluginSnapshot] = [:]
        for plugin in configuration.plugins {
            next[plugin.id] = snapshots[plugin.id] ?? makeSnapshot(for: plugin)
        }
        snapshots = next
    }

    private func loadCachedStates() {
        for plugin in configuration.plugins {
            guard let cached = stateStore.load(stateID: plugin.stateID) else { continue }
            snapshots[plugin.id] = makeSnapshot(
                for: plugin,
                state: .ready,
                components: cached.components,
                updatedAt: cached.updatedAt,
                badge: cached.badge,
                icon: cached.icon,
                title: cached.title
            )
        }
    }

    private func startSchedulers() {
        refreshTasks.values.forEach { $0.cancel() }
        refreshTasks = [:]

        for plugin in configuration.plugins where plugin.enabled {
            let id = plugin.id
            let interval = max(plugin.refreshIntervalSeconds, 5)
            let hasCached = stateStore.load(stateID: plugin.stateID) != nil

            if !hasCached {
                snapshots[id] = makeSnapshot(for: plugin, state: .loading)
            }

            refreshTasks[id] = Task { [weak self] in
                if let cached = self?.stateStore.load(stateID: plugin.stateID) {
                    let elapsed = Date().timeIntervalSince(cached.updatedAt)
                    let remaining = Double(interval) - elapsed
                    if remaining > 0 {
                        try? await Task.sleep(for: .seconds(remaining))
                    }
                }
                while !Task.isCancelled {
                    self?.refresh(pluginID: id)
                    try? await Task.sleep(for: .seconds(interval))
                }
            }
        }
    }

    private func refreshPluginsAfterConfigurationChange() {
        for plugin in configuration.plugins where plugin.enabled {
            let snapshot = snapshots[plugin.id]
            let hasCached = stateStore.load(stateID: plugin.stateID) != nil
            let shouldRefresh = !hasCached || snapshot?.state == .loading || isFailed(snapshot?.state)
            if shouldRefresh {
                refresh(pluginID: plugin.id, force: true)
            }
        }
    }

    private func isFailed(_ state: PluginSnapshotState?) -> Bool {
        guard let state else { return false }
        if case .failed = state {
            return true
        }
        return false
    }

    private func makeSnapshot(
        for plugin: PluginConfiguration,
        state: PluginSnapshotState = .idle,
        components: [Component] = [],
        updatedAt: Date? = nil,
        badge: String? = nil,
        icon: String? = nil,
        title: String? = nil
    ) -> PluginSnapshot {
        PluginSnapshot(
            id: plugin.id,
            pluginName: plugin.name,
            displayName: displayNames[plugin.id] ?? plugin.name,
            state: state,
            components: components,
            updatedAt: updatedAt,
            badge: badge,
            icon: icon,
            title: title
        )
    }

    private func thermalStateString() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "nominal"
        }
    }

    // MARK: - 卡片展开/折叠

    private func loadCardStates() {
        for plugin in configuration.plugins {
            let state = cardStateStore.load(for: plugin.stateID)
            cardExpandedStates[plugin.id] = state.isExpanded
        }
    }

    func toggleCardExpanded(pluginID: UUID) {
        let newValue = !(cardExpandedStates[pluginID] ?? true)
        cardExpandedStates[pluginID] = newValue
        if let plugin = configuration.plugins.first(where: { $0.id == pluginID }) {
            cardStateStore.save(for: plugin.stateID, state: CardState(isExpanded: newValue))
        }
    }

    func movePluginUp(pluginID: UUID) {
        guard let index = configuration.plugins.firstIndex(where: { $0.id == pluginID }),
              index > 0 else { return }
        configuration.plugins.swapAt(index, index - 1)
        saveConfiguration()
    }

    func movePluginDown(pluginID: UUID) {
        guard let index = configuration.plugins.firstIndex(where: { $0.id == pluginID }),
              index < configuration.plugins.count - 1 else { return }
        configuration.plugins.swapAt(index, index + 1)
        saveConfiguration()
    }

    // MARK: - 通知

    private func sendNotificationIfNeeded(_ notification: PluginNotification) {
        notificationManager.send(notification: notification)
    }

    // MARK: - 文件监控推送刷新

    private func triggerFilePath(for stateID: String) -> String {
        try? FileManager.default.createDirectory(at: triggersDirURL, withIntermediateDirectories: true)
        return triggersDirURL.appendingPathComponent(stateID).path
    }

    private func startFileMonitors() {
        fileMonitors.values.forEach { $0.cancel() }
        fileMonitors = [:]

        for plugin in configuration.plugins {
            let path = triggerFilePath(for: plugin.stateID)
            // 确保 trigger 文件存在
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil)
            }

            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
            let pluginID = plugin.id
            source.setEventHandler { [weak self] in
                self?.refresh(pluginID: pluginID, force: true)
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            fileMonitors[pluginID] = source
        }
    }
}
