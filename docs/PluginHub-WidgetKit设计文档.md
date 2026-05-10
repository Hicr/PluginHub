# PluginHub WidgetKit 桌面小组件设计文档

## 1. 概述

### 1.1 定位

把插件指标「钉」到 macOS 桌面上，不点菜单栏也能看到关键数据。Widget 是插件输出的**指标快照**，不渲染完整 UI。

### 1.2 约束

| 约束 | 说明 |
|------|------|
| 不可交互 | Widget 不能有按钮/拖拽/输入框 |
| 只能点击跳转 | 点击打开主 App；macOS 14+ 可多个 `Link` 区域 |
| 独立进程 | Widget 不依赖 App 运行，由系统管理生命周期 |
| 10MB 内存 | Widget 内存上限，超过被系统杀死 |
| 刷新有限 | 系统决定刷新频率，频繁刷新会被限流 |

### 1.3 尺寸

| 尺寸 | 网格 | 内容 | 示例 |
|------|------|------|------|
| `systemSmall` (171×171) | 2×2 | 1 个指标：图标 + 值 + 迷你进度条 | CPU 45% |
| `systemMedium` (362×171) | 4×2 | 3-4 个指标并排 | CPU / 内存 / 磁盘 |

## 2. 架构

```
┌─────────────────────────┐         ┌──────────────────────────┐
│      PluginHub App      │         │     PluginHub Widget      │
│                         │  App    │                          │
│  PluginHubStore         │  Group  │  TimelineProvider        │
│    ↓ refresh()          │ ──────→ │    ↓ getTimeline()      │
│    ↓ 写入 snapshots/    │  JSON   │    ↓ 读 snapshots/       │
│    ↓ WidgetCenter.reload│         │  WidgetEntryView          │
└─────────────────────────┘         └──────────────────────────┘
```

### 2.1 App Group 目录结构

```
~/Library/Group Containers/<group-id>/
├── widget-config.json               # Widget 选择了显示哪个指标
├── plugin-list.json                 # 可选插件/指标列表（供 AppIntent 读取）
├── snapshots/
│   └── <plugin-stateID>.json        # 格式同 PluginCachedState
```

### 2.2 widget-config.json

```json
{
  "kind": "single",
  "pluginID": "uuid-of-plugin",
  "componentID": "cpu"
}
```

### 2.3 plugin-list.json（供 Widget Configuration 选择）

```json
[
  {
    "pluginID": "uuid-1",
    "pluginName": "系统监控",
    "icon": "desktopcomputer",
    "components": [
      {"id": "cpu", "label": "CPU", "type": "progress"},
      {"id": "memory", "label": "内存", "type": "progress"}
    ]
  }
]
```

## 3. 数据流

### 3.1 写入（主 App → App Group）

```
PluginHubStore.refresh()
  → 插件执行完成
  → stateStore.save(stateID, cached)        // 原有逻辑
  → sharedDataStore.save(stateID, cached)   // 原有逻辑
  → WidgetDataStore.save(stateID, cached)   // 新增：写入 App Group
  → WidgetDataStore.updatePluginList(config) // 新增：更新可选列表
  → WidgetCenter.shared.reloadAllTimelines() // 通知 Widget 刷新
```

### 3.2 读取（Widget ← App Group）

```
TimelineProvider.getTimeline()
  → WidgetDataStore.loadConfig()             // 读 widget-config.json
  → WidgetDataStore.loadSnapshot(id)         // 读 snapshots/<id>.json
  → 生成 WidgetEntry(component, icon, name)  // 构建条目
  → Timeline(entries: [entry], policy: .after(5.min))
```

### 3.3 Widget 配置（用户操作）

```
长按 Widget → 编辑
  → AppIntent 触发
  → WidgetDataStore.loadPluginList()         // 读 plugin-list.json
  → 用户选择插件 + 组件
  → WidgetDataStore.saveConfig(selection)   // 写 widget-config.json
  → Widget 重新渲染
```

## 4. 代码结构

```
Sources/
├── PluginHubCore/
│   └── WidgetDataStore.swift       # 新增：App Group 读写
├── PluginHubApp/
│   └── PluginHubStore.swift        # 修改：refresh 后写 Widget 数据
└── PluginHubWidget/                # 新增 target
    ├── PluginHubWidgetBundle.swift  # @main
    ├── WidgetEntry.swift            # TimelineEntry 模型
    ├── WidgetProvider.swift         # TimelineProvider + AppIntent
    └── WidgetView.swift            # SwiftUI 渲染

Package.swift                        # 新增 .target("PluginHubWidget")
```

## 5. 核心实现

### 5.1 WidgetDataStore (PluginHubCore)

```swift
public struct WidgetDataStore {
    public let appGroupID: String
    
    public init(appGroupID: String = "group.com.pluginhub.widget") {
        self.appGroupID = appGroupID
    }
    
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    // 写入插件快照
    public func saveSnapshot(stateID: String, cached: PluginCachedState)
    
    // 读取插件快照
    public func loadSnapshot(stateID: String) -> PluginCachedState?
    
    // 更新可选插件列表
    public func updatePluginList(_ plugins: [PluginConfiguration])
    
    // 读/写 widget 配置
    public func loadWidgetConfig() -> WidgetConfig?
    public func saveWidgetConfig(_ config: WidgetConfig)
}
```

### 5.2 WidgetEntry (PluginHubWidget)

```swift
struct WidgetEntry: TimelineEntry {
    let date: Date                            // Timeline 必须有的字段
    let pluginName: String                    // 插件名
    let componentID: String                   // 组件 ID
    let label: String                         // 指标名（如"CPU"）
    let value: Double                         // 数值
    let maxValue: Double                      // 上限
    let unit: String                          // 单位（如"%"）
    let color: Color                          // 颜色
    let componentType: String                 // 组件类型（progress/list/text）
}
```

### 5.3 WidgetProvider (PluginHubWidget)

```swift
struct Provider: AppIntentTimelineProvider {
    // 占位图
    func placeholder(in context: Context) -> WidgetEntry { ... }
    
    // 快照（通知中心预览）
    func snapshot(for configuration: SelectMetricIntent, in context: Context) async -> WidgetEntry { ... }
    
    // 完整时间线
    func timeline(for configuration: SelectMetricIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let store = WidgetDataStore()
        let config = store.loadWidgetConfig()
        let snapshot = store.loadSnapshot(stateID: config.pluginID)
        // 找到目标 component
        let entry = WidgetEntry(...)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
    }
}
```

### 5.4 WidgetView (PluginHubWidget)

```swift
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

// systemSmall：单个指标
struct SmallWidgetView: View {
    let entry: WidgetEntry
    var body: some View {
        VStack(spacing: 4) {
            Text(entry.label).font(.caption2).foregroundStyle(.secondary)
            Text(formattedValue).font(.title).bold()
            ProgressView(value: entry.value, total: entry.maxValue)
                .tint(entry.color)
        }
        .containerBackground(for: .widget) {
            glassBackground
        }
    }
}

// systemMedium：3-4 个指标并排
struct MediumWidgetView: View {
    let entry: WidgetEntry
    var body: some View {
        HStack { /* 多个指标 */ }
        .containerBackground(for: .widget) {
            glassBackground
        }
    }
}

// 液态玻璃
private var glassBackground: some View {
    if #available(macOS 26, *) {
        Color.clear.glassEffect(in: .rect(cornerRadius: 0))
    } else {
        Color.clear.background(.ultraThinMaterial)
    }
}
```

### 5.5 AppIntent 配置

```swift
struct SelectMetricIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择指标"
    
    @Parameter(title: "插件")
    var pluginID: String?
    
    @Parameter(title: "指标")
    var componentID: String?
    
    // 动态列表从 App Group 读
    func perform() async throws -> some IntentResult {
        // 保存选择到 widget-config.json
        return .result()
    }
}
```

### 5.6 Widget Bundle 注册

```swift
@main
struct PluginHubWidgetBundle: WidgetBundle {
    var body: some Widget {
        PluginHubWidgetSmall()
        PluginHubWidgetMedium()
    }
}

struct PluginHubWidgetSmall: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "com.pluginhub.widget.small",
            intent: SelectMetricIntent.self,
            provider: Provider()
        ) { entry in
            WidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall])
    }
}

struct PluginHubWidgetMedium: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "com.pluginhub.widget.medium",
            intent: SelectMetricIntent.self,
            provider: Provider()
        ) { entry in
            WidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemMedium])
    }
}
```

## 6. Package.swift 改造

```swift
.target(
    name: "PluginHubWidget",
    dependencies: ["PluginHubCore"],
    path: "Sources/PluginHubWidget"
)
```

## 7. 主 App 改造点

### 7.1 PluginHubStore.init()

```swift
self.widgetDataStore = WidgetDataStore()
```

### 7.2 refresh() 末尾追加

```swift
// 通知 Widget 刷新
widgetDataStore.saveSnapshot(stateID: plugin.stateID, cached: cached)
widgetDataStore.updatePluginList(configuration.plugins)
WidgetCenter.shared.reloadAllTimelines()
```

### 7.3 首次启动时

```swift
// 写入完整插件列表供 AppIntent 选择
widgetDataStore.updatePluginList(configuration.plugins)
```

## 8. App Group 配置

需要在 Xcode 项目设置或 `entitlements` 中配置：

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.pluginhub.widget</string>
</array>
```

SPM 项目需要通过 `Info.plist` 或在 Package.swift 中配置。

## 9. 限制与边界

| 场景 | 处理 |
|------|------|
| App 从未启动过 | Widget 用 `placeholder()` 显示占位图 |
| 插件禁用/删除 | Widget 显示灰色「无数据」 |
| App Group 读失败 | 显示上次缓存的数据或占位图 |
| 组件类型不支持 | 只支持 progress/text 类型组件 |
| 多个 Widget 实例 | 每个实例独立配置，可显示不同指标 |
| 内存超限 | 系统自动降级为静态快照 |

## 10. 实现步骤

| 步骤 | 内容 | 预估 |
|------|------|------|
| 1 | 创建 App Group ID + entitlements | 小 |
| 2 | 实现 WidgetDataStore | 中 |
| 3 | 创建 Widget target + Widget Bundle | 小 |
| 4 | 实现 TimelineProvider + AppIntent | 中 |
| 5 | 实现 Small/Medium WidgetView | 小 |
| 6 | 主 App 改造（refresh 后写数据）| 小 |
| 7 | 液态玻璃背景 | 小 |
| 8 | 测试验证 | 中 |
