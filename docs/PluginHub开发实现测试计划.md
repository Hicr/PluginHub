# PluginHub 开发实现测试计划

本文档提供详细的开发实现和测试步骤，按阶段划分，每个阶段包含具体的实现任务和验证方法。

---

## Phase 1: 基础框架（Week 1）

### 1.1 创建 Swift Package 项目结构

**实现步骤：**
```bash
# 1. 创建项目目录
mkdir -p PluginHub && cd PluginHub

# 2. 初始化 Swift Package
swift package init --type executable

# 3. 创建目录结构
mkdir -p Sources/PluginHubCore/Models
mkdir -p Sources/PluginHubCore/PluginEngine
mkdir -p Sources/PluginHubCore/PluginStore
mkdir -p Sources/PluginHubCore/SharedData
mkdir -p Sources/PluginHubApp/MenuBar
mkdir -p Sources/PluginHubApp/Dashboard
mkdir -p Sources/PluginHubApp/Components
mkdir -p Sources/PluginHubApp/Settings
mkdir -p Resources/BuiltinPlugins
mkdir -p Tests/PluginHubCoreTests
mkdir -p Tests/PluginHubAppTests
```

**配置 Package.swift：**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PluginHub",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PluginHub", targets: ["PluginHubApp"]),
        .library(name: "PluginHubCore", targets: ["PluginHubCore"])
    ],
    targets: [
        .target(
            name: "PluginHubCore",
            path: "Sources/PluginHubCore"
        ),
        .executableTarget(
            name: "PluginHubApp",
            dependencies: ["PluginHubCore"],
            path: "Sources/PluginHubApp"
        ),
        .testTarget(
            name: "PluginHubCoreTests",
            dependencies: ["PluginHubCore"],
            path: "Tests/PluginHubCoreTests"
        )
    ]
)
```

**测试验证：**
```bash
# 验证项目结构
swift build

# 预期输出：Build complete!
```

---

### 1.2 实现核心数据模型

**实现文件：**
- `Sources/PluginHubCore/Models/PluginOutput.swift`
- `Sources/PluginHubCore/Models/Component.swift`
- `Sources/PluginHubCore/Models/PluginConfiguration.swift`

**PluginOutput.swift：**
```swift
import Foundation

/// 插件输出的根结构
public struct PluginOutput: Codable {
    public let updatedAt: Date
    public let title: String?
    public let icon: String?
    public let badge: String?
    public let components: [Component]
    public let notification: Notification?

    public init(
        updatedAt: Date = Date(),
        title: String? = nil,
        icon: String? = nil,
        badge: String? = nil,
        components: [Component] = [],
        notification: Notification? = nil
    ) {
        self.updatedAt = updatedAt
        self.title = title
        self.icon = icon
        self.badge = badge
        self.components = components
        self.notification = notification
    }
}

/// 提醒配置
public struct Notification: Codable {
    public let title: String
    public let body: String
    public let sound: Bool?
    public let url: String?
    public let scheduledAt: Date?
}
```

**Component.swift：**
```swift
import Foundation

/// UI 组件
public enum Component: Codable {
    case progress(ProgressComponent)
    case list(ListComponent)
    case chart(ChartComponent)
    case text(TextComponent)
    case image(ImageComponent)
    case interactive(InteractiveComponent)
    case custom(CustomComponent)

    // Codable 实现
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
                debugDescription: "Unknown component type: \(type)"
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
```

**测试验证：**
```swift
// Tests/PluginHubCoreTests/ModelsTests.swift
import XCTest
@testable import PluginHubCore

final class ModelsTests: XCTestCase {
    func testPluginOutputDecoding() throws {
        let json = """
        {
            "updatedAt": "2024-01-01T00:00:00Z",
            "title": "Test Plugin",
            "icon": "star.fill",
            "badge": "OK",
            "components": [
                {
                    "type": "progress",
                    "data": {
                        "id": "cpu",
                        "label": "CPU",
                        "value": 50.0,
                        "max": 100.0,
                        "style": "bar"
                    }
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let output = try decoder.decode(PluginOutput.self, from: data)

        XCTAssertEqual(output.title, "Test Plugin")
        XCTAssertEqual(output.components.count, 1)
    }
}
```

```bash
swift test --filter ModelsTests
```

---

### 1.3 实现插件执行引擎

**实现文件：**
- `Sources/PluginHubCore/PluginEngine/PluginExecutor.swift`

**PluginExecutor.swift：**
```swift
import Foundation

public class PluginExecutor {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 30) {
        self.timeout = timeout
    }

    /// 执行插件脚本
    public func execute(
        scriptPath: String,
        parameters: [String: String] = [:],
        sharedDir: String? = nil
    ) async throws -> PluginOutput {
        // 1. 验证脚本存在
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw PluginError.scriptNotFound(scriptPath)
        }

        // 2. 构建参数
        var args = [scriptPath]
        for (key, value) in parameters {
            args.append("--pluginhub-param")
            args.append("\(key)=\(value)")
        }

        // 3. 配置环境变量
        var environment = ProcessInfo.processInfo.environment
        if let sharedDir = sharedDir {
            environment["PLUGINHUB_SHARED_DIR"] = sharedDir
        }

        // 4. 创建进程
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3"] + args
        process.environment = environment

        // 5. 捕获输出
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        // 6. 执行并设置超时
        return try await withThrowingTaskGroup(of: PluginOutput.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    process.terminationHandler = { process in
                        if process.terminationStatus == 0 {
                            let data = stdout.fileHandleForReading.readDataToEndOfFile()
                            do {
                                let decoder = JSONDecoder()
                                decoder.dateDecodingStrategy = .iso8601
                                let output = try decoder.decode(PluginOutput.self, from: data)
                                continuation.resume(returning: output)
                            } catch {
                                continuation.resume(throwing: PluginError.invalidOutput(error))
                            }
                        } else {
                            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            continuation.resume(throwing: PluginError.executionFailed(errorMessage))
                        }
                    }

                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: PluginError.executionFailed(error.localizedDescription))
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
                process.terminate()
                throw PluginError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

public enum PluginError: LocalizedError {
    case scriptNotFound(String)
    case invalidOutput(Error)
    case executionFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "Script not found: \(path)"
        case .invalidOutput(let error):
            return "Invalid output: \(error.localizedDescription)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .timeout:
            return "Plugin execution timed out"
        }
    }
}
```

**测试验证：**
```swift
// Tests/PluginHubCoreTests/PluginExecutorTests.swift
import XCTest
@testable import PluginHubCore

final class PluginExecutorTests: XCTestCase {
    func testExecuteSimplePlugin() async throws {
        // 创建测试脚本
        let script = """
        #!/usr/bin/env python3
        import json
        from datetime import datetime

        data = {
            "updatedAt": datetime.utcnow().isoformat() + "Z",
            "title": "Test",
            "components": []
        }
        print(json.dumps(data))
        """

        let scriptPath = "/tmp/test_plugin.py"
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        let executor = PluginExecutor()
        let output = try await executor.execute(scriptPath: scriptPath)

        XCTAssertEqual(output.title, "Test")
    }

    func testExecuteWithParameters() async throws {
        let script = """
        #!/usr/bin/env python3
        import json
        import os
        from datetime import datetime

        value = os.environ.get("PLUGINHUB_PARAM_TEST_KEY", "default")

        data = {
            "updatedAt": datetime.utcnow().isoformat() + "Z",
            "components": [
                {"type": "text", "data": {"id": "test", "content": value}}
            ]
        }
        print(json.dumps(data))
        """

        let scriptPath = "/tmp/test_plugin_params.py"
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        let executor = PluginExecutor()
        let output = try await executor.execute(
            scriptPath: scriptPath,
            parameters: ["TEST_KEY": "hello"]
        )

        // 验证参数传递
        if case .text(let text) = output.components.first {
            XCTAssertEqual(text.content, "hello")
        }
    }
}
```

```bash
swift test --filter PluginExecutorTests
```

---

### 1.4 实现配置存储

**实现文件：**
- `Sources/PluginHubCore/PluginStore/ConfigStore.swift`

**ConfigStore.swift：**
```swift
import Foundation

public class ConfigStore {
    private let configURL: URL
    private var config: AppConfiguration

    public struct AppConfiguration: Codable {
        public var schemaVersion: Int
        public var theme: Theme
        public var visualEffect: VisualEffect
        public var plugins: [PluginConfiguration]
        public var globalRefreshIntervalSeconds: TimeInterval
        public var showBadge: Bool
        public var enableNotifications: Bool

        public init() {
            self.schemaVersion = 1
            self.theme = .system
            self.visualEffect = VisualEffect()
            self.plugins = []
            self.globalRefreshIntervalSeconds = 60
            self.showBadge = true
            self.enableNotifications = true
        }
    }

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pluginHubDir = appSupport.appendingPathComponent("PluginHub")

        // 创建目录
        try? FileManager.default.createDirectory(at: pluginHubDir, withIntermediateDirectories: true)

        self.configURL = pluginHubDir.appendingPathComponent("config.json")

        // 加载或创建配置
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            self.config = config
        } else {
            self.config = AppConfiguration()
            save()
        }
    }

    public func getConfig() -> AppConfiguration {
        return config
    }

    public func updateConfig(_ update: (inout AppConfiguration) -> Void) {
        update(&config)
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config) {
            try? data.write(to: configURL)
        }
    }
}
```

**测试验证：**
```swift
// Tests/PluginHubCoreTests/ConfigStoreTests.swift
import XCTest
@testable import PluginHubCore

final class ConfigStoreTests: XCTestCase {
    func testConfigPersistence() {
        let store = ConfigStore()

        // 更新配置
        store.updateConfig { config in
            config.showBadge = false
            config.globalRefreshIntervalSeconds = 120
        }

        // 重新加载验证
        let newStore = ConfigStore()
        let config = newStore.getConfig()

        XCTAssertFalse(config.showBadge)
        XCTAssertEqual(config.globalRefreshIntervalSeconds, 120)
    }
}
```

```bash
swift test --filter ConfigStoreTests
```

---

### 1.5 实现主题系统

**实现文件：**
- `Sources/PluginHubCore/Models/Theme.swift`
- `Sources/PluginHubApp/Components/VisualEffectView.swift`

**Theme.swift：**
```swift
import Foundation

public enum Theme: String, Codable {
    case system
    case light
    case dark
}

public struct VisualEffect: Codable {
    public let enabled: Bool
    public let material: MaterialType
    public let blending: BlendingMode

    public init(
        enabled: Bool = true,
        material: MaterialType = .sidebar,
        blending: BlendingMode = .behindWindow
    ) {
        self.enabled = enabled
        self.material = material
        self.blending = blending
    }
}

public enum MaterialType: String, Codable {
    case headerView
    case sheet
    case menu
    case popover
    case sidebar
    case windowBackground
    case contentBackground
    case underWindowBackground
}

public enum BlendingMode: String, Codable {
    case behindWindow
    case withinWindow
}
```

**VisualEffectView.swift：**
```swift
import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}
```

**测试验证：**
- 运行 App，检查 Dashboard 背景是否有毛玻璃效果
- 切换深色/浅色模式，验证效果是否跟随系统

---

### 1.6 实现基本菜单栏 UI

**实现文件：**
- `Sources/PluginHubApp/MenuBar/StatusBarController.swift`
- `Sources/PluginHubApp/Dashboard/DashboardView.swift`

**StatusBarController.swift：**
```swift
import SwiftUI
import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    init() {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "puzzlepiece.fill", accessibilityDescription: "PluginHub")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // 创建弹出窗口
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: DashboardView())
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
```

**测试验证：**
```bash
# 构建并运行
swift build
.build/debug/PluginHubApp

# 验证：
# 1. 菜单栏出现图标
# 2. 点击图标弹出 Dashboard
# 3. 点击其他区域关闭 Dashboard
```

---

## Phase 2: 组件渲染（Week 2）

### 2.1 实现 ProgressRenderer

**实现文件：**
- `Sources/PluginHubApp/Components/ProgressRenderer.swift`

**ProgressRenderer.swift：**
```swift
import SwiftUI

struct ProgressRenderer: View {
    let component: ProgressComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(component.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formattedValue)
                    .font(.caption)
                    .monospacedDigit()
            }

            switch component.style {
            case .bar:
                progressBar
            case .ring:
                progressRing
            case .gauge:
                progressGauge
            }
        }
    }

    private var formattedValue: String {
        if let unit = component.unit {
            return String(format: "%.1f%@", component.value, unit)
        }
        return String(format: "%.1f%%", component.value / component.max * 100)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * percentage, height: 8)
            }
        }
        .frame(height: 8)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: percentage)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text(formattedValue)
                .font(.caption2)
                .monospacedDigit()
        }
        .frame(width: 40, height: 40)
    }

    private var progressGauge: some View {
        Gauge(value: component.value, in: 0...component.max) {
            Text(component.label)
        }
        .gaugeStyle(.accessoryLinear)
        .tint(color)
    }

    private var percentage: CGFloat {
        min(max(component.value / component.max, 0), 1)
    }

    private var color: Color {
        if let hex = component.color {
            return Color(hex: hex)
        }
        return .accentColor
    }
}
```

**测试验证：**
创建测试插件，验证三种进度条样式都能正确渲染。

---

### 2.2 实现 ListRenderer

**实现文件：**
- `Sources/PluginHubApp/Components/ListRenderer.swift`

**测试验证：**
创建测试插件，验证列表样式（simple、detailed、table）都能正确显示。

---

### 2.3 实现 ChartRenderer

**实现文件：**
- `Sources/PluginHubApp/Components/ChartRenderer.swift`

使用 Swift Charts 框架。

**测试验证：**
创建测试插件，验证折线图、柱状图、饼图都能正确渲染。

---

### 2.4 实现 TextRenderer

**实现文件：**
- `Sources/PluginHubApp/Components/TextRenderer.swift`

**测试验证：**
创建测试插件，验证纯文本、Markdown、alert 样式都能正确显示。

---

### 2.5 实现 ImageRenderer

**实现文件：**
- `Sources/PluginHubApp/Components/ImageRenderer.swift`

**测试验证：**
创建测试插件，验证 URL 图片和 base64 图片都能正确加载。

---

### 2.6 实现 InteractiveRenderer

**实现文件：**
- `Sources/PluginHubApp/Components/InteractiveRenderer.swift`
- `Sources/PluginHubApp/Components/ScratchcardView.swift`
- `Sources/PluginHubApp/Components/ButtonView.swift`

**测试验证：**
创建刮刮乐测试插件，验证交互功能正常工作。

---

### 2.7 完成 Dashboard 布局

**实现文件：**
- `Sources/PluginHubApp/Dashboard/DashboardView.swift`
- `Sources/PluginHubApp/Dashboard/PluginCardView.swift`

**测试验证：**
```bash
swift build
.build/debug/PluginHubApp

# 验证：
# 1. Dashboard 显示毛玻璃背景
# 2. 插件卡片正确布局
# 3. 组件正确渲染
```

---

## Phase 3: 插件管理（Week 3）

### 3.1 实现插件元数据解析器

**实现文件：**
- `Sources/PluginHubCore/PluginEngine/PluginMetadataParser.swift`

**测试验证：**
```swift
func testParseMetadata() throws {
    let script = """
    #!/usr/bin/env python3
    # PluginHub:
    #   name: Test Plugin
    #   description: A test plugin
    #   parameters:
    #     - name: key
    #       type: string
    #       label: API Key
    # /PluginHub

    print("{}")
    """

    let parser = PluginMetadataParser()
    let metadata = try parser.parse(script: script)

    XCTAssertEqual(metadata.name, "Test Plugin")
    XCTAssertEqual(metadata.parameters.count, 1)
}
```

---

### 3.2 实现设置界面

**实现文件：**
- `Sources/PluginHubApp/Settings/SettingsView.swift`
- `Sources/PluginHubApp/Settings/PluginSettingsCard.swift`

**测试验证：**
- 打开设置界面
- 验证插件列表显示
- 验证参数配置表单生成

---

### 3.3 实现插件安装/卸载

**实现文件：**
- `Sources/PluginHubCore/PluginStore/PluginManager.swift`

**测试验证：**
- 安装新插件（复制脚本到 plugins 目录）
- 卸载插件（删除符号链接）
- 验证配置更新

---

### 3.4 实现插件间数据共享

**实现文件：**
- `Sources/PluginHubCore/SharedData/SharedDataStore.swift`

**测试验证：**
创建两个测试插件，一个写入数据，一个读取数据，验证共享功能。

---

## Phase 4: 高级功能（Week 4）

### 4.1 实现定时刷新调度器

**实现文件：**
- `Sources/PluginHubCore/PluginEngine/RefreshScheduler.swift`

**测试验证：**
- 设置 10 秒刷新间隔
- 验证插件定期执行
- 验证手动刷新立即生效

---

### 4.2 实现组件排序和展开/折叠

**实现文件：**
- `Sources/PluginHubCore/PluginStore/CardStateStore.swift`

**测试验证：**
- 拖拽调整组件顺序
- 展开/折叠插件卡片
- 重启 App 验证状态持久化

---

### 4.3 实现定时提醒/通知系统

**实现文件：**
- `Sources/PluginHubCore/PluginEngine/NotificationManager.swift`

**测试验证：**
创建喝水提醒测试插件，验证通知正常弹出。

---

### 4.4 添加内置示例插件

**实现文件：**
- `Resources/BuiltinPlugins/system-monitor.py`
- `Resources/BuiltinPlugins/scratchcard.py`
- `Resources/BuiltinPlugins/drink-reminder.py`

**测试验证：**
- 安装所有内置插件
- 验证每个插件都能正常运行
- 验证 UI 渲染正确

---

## Phase 5: 打磨发布（Week 5）

### 5.1 错误处理和日志

**实现文件：**
- `Sources/PluginHubCore/Utilities/Logger.swift`

**测试验证：**
- 模拟插件执行失败
- 验证错误信息显示
- 验证日志文件记录

---

### 5.2 性能优化

**优化点：**
- 插件异步并发执行
- 图片缓存
- 组件懒加载

**测试验证：**
- 安装 10+ 插件
- 验证 Dashboard 流畅滚动
- 验证内存使用合理

---

### 5.3 编写插件开发文档

**输出文件：**
- `Resources/PluginAuthoringGuide.md`

---

### 5.4 打包和签名

**步骤：**
```bash
# 1. Release 构建
swift build -c release

# 2. 创建 .app bundle
mkdir -p PluginHub.app/Contents/MacOS
mkdir -p PluginHub.app/Contents/Resources
cp .build/release/PluginHubApp PluginHub.app/Contents/MacOS/PluginHub

# 3. 创建 Info.plist
cat > PluginHub.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PluginHub</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.PluginHub</string>
    <key>CFBundleName</key>
    <string>PluginHub</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 4. 签名
codesign --force --deep --sign - PluginHub.app

# 5. 打包
zip -r PluginHub.zip PluginHub.app
```

**测试验证：**
- 在干净的 macOS 系统上安装
- 验证 App 正常启动
- 验证所有功能正常

---

## 验收标准

### 功能验收

- [ ] 菜单栏图标显示正常
- [ ] 点击弹出 Dashboard，毛玻璃效果正常
- [ ] 插件执行和 JSON 解析正确
- [ ] 7 种组件类型都能正确渲染
- [ ] 插件安装/卸载正常
- [ ] 定时刷新正常工作
- [ ] 手动刷新立即生效
- [ ] 插件间数据共享正常
- [ ] 定时提醒/通知正常弹出
- [ ] 主题切换（深色/浅色）正常
- [ ] 组件排序和展开/折叠正常
- [ ] 远程服务器监控插件正常
- [ ] 快速 SSH 连接功能正常
- [ ] 刮刮乐小游戏交互正常

### 性能验收

- [ ] Dashboard 打开时间 < 500ms
- [ ] 插件执行超时 30s
- [ ] 10+ 插件同时运行流畅
- [ ] 内存使用 < 100MB

### 兼容性验收

- [ ] macOS 13.0+ 正常运行
- [ ] 深色/浅色模式都正常
- [ ] Intel 和 Apple Silicon 都正常

---

## 测试插件清单

1. **系统监控插件** - 测试 progress 组件
2. **GitHub Trending 插件** - 测试 list 组件
3. **刮刮乐插件** - 测试 interactive 组件
4. **服务器监控插件** - 测试 SSH 连接和 button 组件
5. **喝水提醒插件** - 测试 notification 功能
6. **网站统计插件** - 测试 chart 和 image 组件
7. **纯文本插件** - 测试 text 组件

每个插件都需要：
- 正确的元数据声明
- 符合协议的 JSON 输出
- 错误处理
- 参数支持（如适用）
