import Foundation

// MARK: - 插件输出

public struct PluginNotification: Codable, Equatable, Sendable {
    public var title: String
    public var body: String
    public var sound: Bool?
    public var url: String?
    public var scheduledAt: Date?

    public init(title: String, body: String, sound: Bool? = nil, url: String? = nil, scheduledAt: Date? = nil) {
        self.title = title
        self.body = body
        self.sound = sound
        self.url = url
        self.scheduledAt = scheduledAt
    }
}

public struct PluginOutput: Codable, Equatable, Sendable {
    public var updatedAt: Date
    public var title: String?
    public var icon: String?
    public var badge: String?
    public var components: [Component]
    public var notification: PluginNotification?

    public init(
        updatedAt: Date,
        title: String? = nil,
        icon: String? = nil,
        badge: String? = nil,
        components: [Component] = [],
        notification: PluginNotification? = nil
    ) {
        self.updatedAt = updatedAt
        self.title = title
        self.icon = icon
        self.badge = badge
        self.components = components
        self.notification = notification
    }
}

// MARK: - 组件

public enum Component: Codable, Equatable, Sendable {
    case progress(ProgressComponent)
    case list(ListComponent)
    case chart(ChartComponent)
    case text(TextComponent)
    case image(ImageComponent)
    case interactive(InteractiveComponent)
    case custom(CustomComponent)

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "progress":
            let data = try container.decode(ProgressComponent.self, forKey: .data)
            self = .progress(data)
        case "list":
            let data = try container.decode(ListComponent.self, forKey: .data)
            self = .list(data)
        case "chart":
            let data = try container.decode(ChartComponent.self, forKey: .data)
            self = .chart(data)
        case "text":
            let data = try container.decode(TextComponent.self, forKey: .data)
            self = .text(data)
        case "image":
            let data = try container.decode(ImageComponent.self, forKey: .data)
            self = .image(data)
        case "interactive":
            let data = try container.decode(InteractiveComponent.self, forKey: .data)
            self = .interactive(data)
        case "custom":
            let data = try container.decode(CustomComponent.self, forKey: .data)
            self = .custom(data)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "未知组件类型: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .progress(let data):
            try container.encode("progress", forKey: .type)
            try container.encode(data, forKey: .data)
        case .list(let data):
            try container.encode("list", forKey: .type)
            try container.encode(data, forKey: .data)
        case .chart(let data):
            try container.encode("chart", forKey: .type)
            try container.encode(data, forKey: .data)
        case .text(let data):
            try container.encode("text", forKey: .type)
            try container.encode(data, forKey: .data)
        case .image(let data):
            try container.encode("image", forKey: .type)
            try container.encode(data, forKey: .data)
        case .interactive(let data):
            try container.encode("interactive", forKey: .type)
            try container.encode(data, forKey: .data)
        case .custom(let data):
            try container.encode("custom", forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - 组件类型定义

public enum ProgressStyle: String, Codable, Equatable, Sendable {
    case bar
    case ring
    case gauge
}

public struct ProgressComponent: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var value: Double
    public var max: Double
    public var unit: String?
    public var color: String?
    public var style: ProgressStyle

    public init(
        id: String,
        label: String,
        value: Double,
        max: Double,
        unit: String? = nil,
        color: String? = nil,
        style: ProgressStyle = .bar
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.max = max
        self.unit = unit
        self.color = color
        self.style = style
    }
}

public enum ListStyle: String, Codable, Equatable, Sendable {
    case simple
    case detailed
    case table
}

public struct ListComponent: Codable, Equatable, Sendable {
    public var id: String
    public var title: String?
    public var items: [ListItem]
    public var style: ListStyle

    public init(
        id: String,
        title: String? = nil,
        items: [ListItem] = [],
        style: ListStyle = .simple
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.style = style
    }
}

public struct ListItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String { title }
    public var title: String
    public var subtitle: String?
    public var value: String?
    public var icon: String?
    public var color: String?
    public var url: String?

    public init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        icon: String? = nil,
        color: String? = nil,
        url: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.icon = icon
        self.color = color
        self.url = url
    }
}

public enum ChartType: String, Codable, Equatable, Sendable {
    case line
    case bar
    case pie
}

public struct ChartComponent: Codable, Equatable, Sendable {
    public var id: String
    public var title: String?
    public var type: ChartType
    public var data: [ChartDataPoint]
    public var xLabel: String?
    public var yLabel: String?

    public init(
        id: String,
        title: String? = nil,
        type: ChartType = .line,
        data: [ChartDataPoint] = [],
        xLabel: String? = nil,
        yLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.data = data
        self.xLabel = xLabel
        self.yLabel = yLabel
    }
}

public struct ChartDataPoint: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(label)-\(series ?? "")" }
    public var label: String
    public var value: Double
    public var series: String?

    public init(label: String, value: Double, series: String? = nil) {
        self.label = label
        self.value = value
        self.series = series
    }
}

public enum TextStyle: String, Codable, Equatable, Sendable {
    case plain
    case markdown
    case alert
    case success
    case warning
}

public struct TextComponent: Codable, Equatable, Sendable {
    public var id: String
    public var content: String
    public var style: TextStyle?
    public var icon: String?
    public var url: String?

    public init(
        id: String,
        content: String,
        style: TextStyle? = nil,
        icon: String? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.content = content
        self.style = style
        self.icon = icon
        self.url = url
    }
}

public struct ImageComponent: Codable, Equatable, Sendable {
    public var id: String
    public var url: String
    public var alt: String?
    public var width: Double?
    public var height: Double?
    public var caption: String?

    public init(
        id: String,
        url: String,
        alt: String? = nil,
        width: Double? = nil,
        height: Double? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.url = url
        self.alt = alt
        self.width = width
        self.height = height
        self.caption = caption
    }
}

public enum InteractiveType: String, Codable, Equatable, Sendable {
    case scratchcard
    case button
    case input
    case toggle
}

public enum ActionType: String, Codable, Equatable, Sendable {
    case callback
    case url
    case copy
}

public struct InteractiveAction: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var type: ActionType
    public var payload: String?

    public init(id: String, label: String, type: ActionType, payload: String? = nil) {
        self.id = id
        self.label = label
        self.type = type
        self.payload = payload
    }
}

public struct InteractiveConfig: Codable, Equatable, Sendable {
    public var title: String?
    public var description: String?
    public var actions: [InteractiveAction]?

    public init(title: String? = nil, description: String? = nil, actions: [InteractiveAction]? = nil) {
        self.title = title
        self.description = description
        self.actions = actions
    }
}

public struct InteractiveComponent: Codable, Equatable, Sendable {
    public var id: String
    public var type: InteractiveType
    public var config: InteractiveConfig
    public var state: [String: String]?

    public init(id: String, type: InteractiveType, config: InteractiveConfig, state: [String: String]? = nil) {
        self.id = id
        self.type = type
        self.config = config
        self.state = state
    }
}

public struct CustomComponent: Codable, Equatable, Sendable {
    public var id: String
    public var type: String
    public var data: [String: String]

    public init(id: String, type: String, data: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.data = data
    }
}

// MARK: - 插件配置

public enum PluginParameterType: String, Codable, CaseIterable, Identifiable, Sendable {
    case string
    case secret
    case integer
    case boolean
    case choice
    case time
    case textarea
    case server_list

    public var id: String { rawValue }
}

public struct PluginParameterOption: Codable, Equatable, Identifiable, Sendable {
    public var label: String
    public var value: String

    public var id: String { value }

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct PluginParameterMetadata: Codable, Equatable, Identifiable, Sendable {
    public var name: String
    public var label: String
    public var type: PluginParameterType
    public var required: Bool
    public var placeholder: String?
    public var defaultValue: String?
    public var options: [PluginParameterOption]

    public var id: String { name }

    public init(
        name: String,
        label: String? = nil,
        type: PluginParameterType = .string,
        required: Bool = false,
        placeholder: String? = nil,
        defaultValue: String? = nil,
        options: [PluginParameterOption] = []
    ) {
        self.name = name
        self.label = label ?? name
        self.type = type
        self.required = required
        self.placeholder = placeholder
        self.defaultValue = defaultValue
        self.options = options
    }

    enum CodingKeys: String, CodingKey {
        case name
        case label
        case type
        case required
        case placeholder
        case defaultValue
        case options
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? name
        type = try container.decodeIfPresent(PluginParameterType.self, forKey: .type) ?? .string
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue)
        options = try container.decodeIfPresent([PluginParameterOption].self, forKey: .options) ?? []
    }
}

public struct PluginMetadata: Codable, Equatable, Sendable {
    public var name: String?
    public var description: String?
    public var icon: String?
    public var parameters: [PluginParameterMetadata]

    public init(
        name: String? = nil,
        description: String? = nil,
        icon: String? = nil,
        parameters: [PluginParameterMetadata] = []
    ) {
        self.name = name
        self.description = description
        self.icon = icon
        self.parameters = parameters
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case icon
        case parameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        parameters = try container.decodeIfPresent([PluginParameterMetadata].self, forKey: .parameters) ?? []
    }
}

public struct PluginConfiguration: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var stateID: String
    public var name: String
    public var enabled: Bool
    public var executablePath: String
    public var refreshIntervalSeconds: Int
    public var metadata: PluginMetadata?
    public var parameterValues: [String: String]

    public init(
        id: UUID = UUID(),
        stateID: String = UUID().uuidString,
        name: String,
        enabled: Bool = true,
        executablePath: String,
        refreshIntervalSeconds: Int = 300,
        metadata: PluginMetadata? = nil,
        parameterValues: [String: String] = [:]
    ) {
        self.id = id
        self.stateID = stateID
        self.name = name
        self.enabled = enabled
        self.executablePath = executablePath
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.metadata = metadata
        self.parameterValues = parameterValues
    }

    enum CodingKeys: String, CodingKey {
        case stateID
        case name
        case enabled
        case executablePath
        case refreshIntervalSeconds
        case metadata
        case parameterValues
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        stateID = try container.decodeIfPresent(String.self, forKey: .stateID) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未命名"
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        executablePath = try container.decodeIfPresent(String.self, forKey: .executablePath) ?? ""
        refreshIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalSeconds) ?? 300
        metadata = try container.decodeIfPresent(PluginMetadata.self, forKey: .metadata)
        parameterValues = try container.decodeIfPresent([String: String].self, forKey: .parameterValues) ?? [:]
    }
}

// MARK: - 主题

public enum Theme: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

public enum VisualMaterialType: String, Codable, CaseIterable, Identifiable, Sendable {
    case sidebar
    case menu
    case popover
    case windowBackground
    case contentBackground

    public var id: String { rawValue }
}

public enum VisualBlendingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case behindWindow
    case withinWindow

    public var id: String { rawValue }
}

public struct VisualEffect: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var material: VisualMaterialType
    public var blending: VisualBlendingMode

    public init(
        enabled: Bool = true,
        material: VisualMaterialType = .contentBackground,
        blending: VisualBlendingMode = .withinWindow
    ) {
        self.enabled = enabled
        self.material = material
        self.blending = blending
    }
}

// MARK: - App 配置

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var theme: Theme
    public var visualEffect: VisualEffect
    public var plugins: [PluginConfiguration]
    public var launchAtLogin: Bool

    public init(
        schemaVersion: Int = 1,
        theme: Theme = .system,
        visualEffect: VisualEffect = VisualEffect(),
        plugins: [PluginConfiguration] = [],
        launchAtLogin: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.theme = theme
        self.visualEffect = visualEffect
        self.plugins = plugins
        self.launchAtLogin = launchAtLogin
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case theme
        case visualEffect
        case plugins
        case launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        theme = try container.decodeIfPresent(Theme.self, forKey: .theme) ?? .system
        visualEffect = try container.decodeIfPresent(VisualEffect.self, forKey: .visualEffect) ?? VisualEffect()
        plugins = try container.decodeIfPresent([PluginConfiguration].self, forKey: .plugins) ?? []
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }
}

// MARK: - 插件快照（UI 使用）

public enum PluginSnapshotState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case failed(String)
}

public struct PluginSnapshot: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var pluginName: String
    public var displayName: String
    public var state: PluginSnapshotState
    public var components: [Component]
    public var updatedAt: Date?
    public var badge: String?
    public var icon: String?
    public var title: String?
    public var notification: PluginNotification?

    public init(
        id: UUID,
        pluginName: String,
        displayName: String,
        state: PluginSnapshotState = .idle,
        components: [Component] = [],
        updatedAt: Date? = nil,
        badge: String? = nil,
        icon: String? = nil,
        title: String? = nil,
        notification: PluginNotification? = nil
    ) {
        self.id = id
        self.pluginName = pluginName
        self.displayName = displayName
        self.state = state
        self.components = components
        self.updatedAt = updatedAt
        self.badge = badge
        self.icon = icon
        self.title = title
        self.notification = notification
    }
}

// MARK: - 缓存状态

public struct PluginCachedState: Codable, Equatable, Sendable {
    public var updatedAt: Date
    public var components: [Component]
    public var badge: String?
    public var title: String?
    public var icon: String?

    public init(
        updatedAt: Date,
        components: [Component],
        badge: String? = nil,
        title: String? = nil,
        icon: String? = nil
    ) {
        self.updatedAt = updatedAt
        self.components = components
        self.badge = badge
        self.title = title
        self.icon = icon
    }
}
