import AppKit
import SwiftUI
import PluginHubCore

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case plugins = "插件"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .plugins: return "puzzlepiece.extension"
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject var store: PluginHubStore
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            sidebar

            Divider()

            // 内容
            switch selectedTab {
            case .general:
                GeneralSettingsView(store: store)
            case .plugins:
                PluginSettingsView(store: store)
            }
        }
        .frame(minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Image(systemName: "puzzlepiece.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 14)

            Divider()
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                                .frame(width: 16)
                            Text(tab.rawValue)
                                .font(.system(size: 13))
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Spacer()
        }
        .frame(width: 170)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var store: PluginHubStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 主题
                VStack(alignment: .leading, spacing: 10) {
                    Text("外观")
                        .font(.system(size: 14, weight: .semibold))
                    VStack(alignment: .leading, spacing: 0) {
                        settingsRow("主题") {
                            Picker("", selection: Binding(
                                get: { store.configuration.theme },
                                set: {
                                    store.configuration.theme = $0
                                    AppDelegate.shared?.applyTheme($0)
                                    store.saveConfiguration()
                                }
                            )) {
                                ForEach(Theme.allCases) { theme in
                                    Text(themeDisplayName(theme)).tag(theme)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140, alignment: .leading)
                        }

                        Divider().padding(.leading, 14)

                        settingsRow(glassEffectLabel) {
                            Toggle("", isOn: Binding(
                                get: { store.configuration.visualEffect.enabled },
                                set: {
                                    store.configuration.visualEffect.enabled = $0
                                    store.saveConfiguration()
                                }
                            ))
                            .labelsHidden()
                            .frame(width: 120, alignment: .leading)
                        }

                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 启动
                VStack(alignment: .leading, spacing: 10) {
                    Text("通用")
                        .font(.system(size: 14, weight: .semibold))
                    VStack(alignment: .leading, spacing: 0) {
                        settingsRow("开机启动") {
                            Toggle("", isOn: Binding(
                                get: { store.configuration.launchAtLogin },
                                set: { newValue in
                                    store.configuration.launchAtLogin = newValue
                                    store.saveConfiguration()
                                }
                            ))
                            .labelsHidden()
                            .frame(width: 120, alignment: .leading)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func settingsRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.primary)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func themeDisplayName(_ theme: Theme) -> String {
        switch theme {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    private var glassEffectLabel: String {
        if #available(macOS 26, *) {
            return "液态玻璃"
        }
        return "毛玻璃"
    }

}

// MARK: - Plugin Settings

struct PluginSettingsView: View {
    @ObservedObject var store: PluginHubStore
    @State private var selectedPluginID: UUID?
    @State private var draft: PluginConfiguration?

    var body: some View {
        HStack(spacing: 0) {
            // 插件列表侧边栏
            pluginSidebar

            Divider()

            // 插件详情
            if let draft, draft.id == selectedPluginID {
                pluginDetail(draft)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("选择一个插件查看配置")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selectedPluginID == nil {
                selectedPluginID = store.configuration.plugins.first?.id
            }
            if let id = selectedPluginID {
                loadDraft(for: id)
            }
        }
    }

    // MARK: - Sidebar

    private var pluginSidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.configuration.plugins) { plugin in
                        HStack(spacing: 8) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 12))
                                .foregroundStyle(selectedPluginID == plugin.id ? Color.accentColor : .secondary)
                                .frame(width: 16)
                            Text(plugin.name.isEmpty ? "未命名" : plugin.name)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            Spacer()
                            VStack(spacing: -3) {
                                Button {
                                    store.movePluginUp(pluginID: plugin.id)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 7, weight: .bold))
                                        .frame(width: 14, height: 10)
                                }
                                .buttonStyle(.borderless)
                                .disabled(store.configuration.plugins.first?.id == plugin.id)
                                Button {
                                    store.movePluginDown(pluginID: plugin.id)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 7, weight: .bold))
                                        .frame(width: 14, height: 10)
                                }
                                .buttonStyle(.borderless)
                                .disabled(store.configuration.plugins.last?.id == plugin.id)
                            }
                            Toggle("", isOn: pluginEnabledBinding(plugin))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            loadDraft(for: plugin.id)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack(spacing: 4) {
                Button {
                    choosePlugin()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)

                Button {
                    if let id = selectedPluginID {
                        store.removePlugin(id: id)
                        selectedPluginID = nil
                        draft = nil
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(selectedPluginID == nil)

                Spacer()

                Button {
                    NSWorkspace.shared.open(store.pluginsDirectoryURL)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("打开插件文件夹")

                Button {
                    openPluginHelp()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("插件编写指南")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(width: 250)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Plugin Detail

    private func pluginDetail(_ draft: PluginConfiguration) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let lastError = store.lastError {
                        Text(lastError)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.name.isEmpty ? "未命名" : draft.name)
                                    .font(.system(size: 16, weight: .semibold))
                                if let desc = draft.metadata?.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 0) {
                            pluginRow("名称") {
                                TextField("插件名称", text: draftBinding.name)
                                    .textFieldStyle(.roundedBorder)
                            }

                            pluginRow("脚本") {
                                HStack(spacing: 4) {
                                    TextField("Python 脚本路径", text: draftBinding.executablePath)
                                        .textFieldStyle(.roundedBorder)
                                    Button {
                                        chooseExecutable()
                                    } label: {
                                        Image(systemName: "folder")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.borderless)
                                    Button {
                                        reloadDraftMetadata()
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }

                            pluginRow("刷新间隔") {
                                HStack(spacing: 4) {
                                    TextField("秒", value: draftBinding.refreshIntervalSeconds, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    Text("秒")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if let metadata = draft.metadata, !metadata.parameters.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("插件参数")
                                    .font(.system(size: 13, weight: .semibold))
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(metadata.parameters) { parameter in
                                        parameterField(parameter)
                                    }
                                }
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("重置") {
                    loadDraft(for: draft.id)
                }
                .disabled(!hasChanges)
                Button("保存") {
                    saveDraft()
                }
                .disabled(!hasChanges)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Helpers

    private var hasChanges: Bool {
        guard let id = selectedPluginID,
              let original = store.configuration.plugins.first(where: { $0.id == id }),
              let draft else { return false }
        return draft.name != original.name
            || draft.executablePath != original.executablePath
            || draft.refreshIntervalSeconds != original.refreshIntervalSeconds
            || draft.parameterValues != original.parameterValues
    }

    private var draftBinding: Binding<PluginConfiguration> {
        Binding(
            get: { draft ?? PluginConfiguration(name: "", executablePath: "") },
            set: { draft = $0 }
        )
    }

    private func loadDraft(for id: UUID) {
        selectedPluginID = id
        if let plugin = store.configuration.plugins.first(where: { $0.id == id }) {
            draft = plugin
        }
    }

    private func saveDraft() {
        guard let draft else { return }
        guard let index = store.configuration.plugins.firstIndex(where: { $0.id == draft.id }) else { return }
        store.configuration.plugins[index] = draft
        store.saveConfiguration()
    }

    private func reloadDraftMetadata() {
        guard let draft else { return }
        let fileURL = URL(fileURLWithPath: draft.executablePath)
        let metadata = PluginMetadataParser.parse(fileURL: fileURL)
        var updated = draft
        updated.metadata = metadata
        for parameter in metadata?.parameters ?? [] where updated.parameterValues[parameter.name] == nil {
            updated.parameterValues[parameter.name] = parameter.defaultValue ?? ""
        }
        self.draft = updated
    }

    private func pluginEnabledBinding(_ plugin: PluginConfiguration) -> Binding<Bool> {
        Binding(
            get: {
                store.configuration.plugins.first(where: { $0.id == plugin.id })?.enabled ?? false
            },
            set: { newValue in
                store.setPluginEnabled(id: plugin.id, enabled: newValue)
            }
        )
    }

    private func choosePlugin() {
        store.ensurePluginsDirectory()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.pluginsDirectoryURL
        if panel.runModal() == .OK, let url = panel.url {
            store.addPlugin(fileURL: url)
            let newID = store.configuration.plugins.last?.id
            selectedPluginID = newID
            if let newID { loadDraft(for: newID) }
        }
    }

    private func openPluginHelp() {
        if let url = Bundle.main.url(forResource: "PluginAuthoringGuide", withExtension: "html") {
            NSWorkspace.shared.open(url)
            return
        }
        let devURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/PluginAuthoringGuide.html")
        if FileManager.default.fileExists(atPath: devURL.path) {
            NSWorkspace.shared.open(devURL)
        }
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.pluginsDirectoryURL
        if panel.runModal() == .OK, let url = panel.url {
            var updated = draft ?? PluginConfiguration(name: "", executablePath: "")
            updated.executablePath = url.path
            draft = updated
        }
    }

    @ViewBuilder
    private func pluginRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.primary)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func parameterField(_ parameter: PluginParameterMetadata) -> some View {
        HStack(spacing: 2) {
            HStack {
                Text(parameter.label)
                    .font(.system(size: 13))
                if parameter.required {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 80, alignment: .trailing)

            switch parameter.type {
            case .secret:
                SecureField(parameter.placeholder ?? "", text: parameterValueBinding(parameter))
                    .textFieldStyle(.roundedBorder)
            case .integer:
                TextField(parameter.placeholder ?? "", text: parameterValueBinding(parameter))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            case .boolean:
                Toggle("", isOn: parameterBoolBinding(parameter))
                    .labelsHidden()
            case .choice:
                Picker("", selection: parameterValueBinding(parameter)) {
                    ForEach(parameter.options) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 160, alignment: .leading)
            case .time:
                Picker("", selection: parameterValueBinding(parameter)) {
                    ForEach(0..<24) { h in
                        Text(String(format: "%02d:00", h)).tag(String(h))
                    }
                }
                .labelsHidden()
                .frame(width: 100, alignment: .leading)
            case .textarea:
                TextEditor(text: unescapedBinding(parameter))
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
            case .server_list:
                ServerListEditor(value: parameterValueBinding(parameter))
            case .string:
                TextField(parameter.placeholder ?? "", text: parameterValueBinding(parameter))
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func parameterValueBinding(_ parameter: PluginParameterMetadata) -> Binding<String> {
        Binding(
            get: { draft?.parameterValues[parameter.name] ?? parameter.defaultValue ?? "" },
            set: {
                var updated = draft ?? PluginConfiguration(name: "", executablePath: "")
                updated.parameterValues[parameter.name] = $0
                draft = updated
            }
        )
    }

    private func unescapedBinding(_ parameter: PluginParameterMetadata) -> Binding<String> {
        Binding(
            get: {
                let raw = draft?.parameterValues[parameter.name] ?? parameter.defaultValue ?? ""
                return raw.replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            },
            set: {
                var updated = draft ?? PluginConfiguration(name: "", executablePath: "")
                updated.parameterValues[parameter.name] = $0.replacingOccurrences(of: "\n", with: "\\n")
                draft = updated
            }
        )
    }

    private func parameterBoolBinding(_ parameter: PluginParameterMetadata) -> Binding<Bool> {
        Binding(
            get: {
                let value = draft?.parameterValues[parameter.name] ?? parameter.defaultValue ?? "false"
                return ["1", "true", "yes", "on"].contains(value.lowercased())
            },
            set: {
                var updated = draft ?? PluginConfiguration(name: "", executablePath: "")
                updated.parameterValues[parameter.name] = $0 ? "true" : "false"
                draft = updated
            }
        )
    }
}

// MARK: - Server List Editor

struct ServerEntry: Codable, Identifiable {
    var id = UUID().uuidString
    var host: String = ""
    var port: String = "22"
    var user: String = "root"
    var key: String = "~/.ssh/id_rsa"
    var name: String = ""
}

struct ServerListEditor: View {
    @Binding var value: String
    @State private var servers: [ServerEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($servers) { $server in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("名称")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        TextField("服务器名称", text: $server.name)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                        Text("端口")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField("22", text: $server.port)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(width: 50)
                    }
                    HStack {
                        Text("主机")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        TextField("192.168.1.1", text: $server.host)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                        Text("用户")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField("root", text: $server.user)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("密钥")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        TextField("~/.ssh/id_rsa", text: $server.key)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                        Button {
                            servers.removeAll { $0.id == server.id }
                            saveToJSON()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button {
                servers.append(ServerEntry())
                saveToJSON()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                    Text("添加服务器")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.borderless)
        }
        .onAppear {
            loadFromJSON()
        }
        .onChange(of: value) { _ in
            loadFromJSON()
        }
        .onChange(of: servers.count) { _ in saveToJSON() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            saveToJSON()
        }
    }

    private func loadFromJSON() {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ServerEntry].self, from: data) else {
            if servers.isEmpty { servers = [] }
            return
        }
        servers = decoded
    }

    private func saveToJSON() {
        guard let data = try? JSONEncoder().encode(servers),
              let json = String(data: data, encoding: .utf8),
              json != value else { return }
        value = json
    }
}
