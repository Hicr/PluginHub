# PluginHub 设计文档

## 1. 项目概述

**App名称：** PluginHub
**定位：** macOS 菜单栏通用插件平台
**目标用户：** 开发者（会写 Python 脚本）
**核心理念：** 让开发者可以快速编写 Python 插件，在菜单栏展示任意类型的数据

## 2. 需求总结

| 项目 | 决策 |
|------|------|
| 平台 | macOS 13+ 菜单栏 App |
| 插件语言 | Python 脚本，输出 JSON |
| UI 形式 | 进度条、列表/表格、图表、文本、图片、交互式、自由布局 |
| 主题 | 支持深色/浅色主题 + macOS 毛玻璃效果 |
| 插件交互 | 可读取其他插件的输出数据 |
| 刷新机制 | 定时轮询 + 手动刷新 + 插件主动推送 |
| 安全性 | 无限制（完全信任插件） |
| 插件分发 | 本地安装，手动管理 |
| 代码基础 | 完全重写 |

## 3. 技术架构

### 3.1 技术栈

- **语言：** Swift 5.9+ (async/await)
- **UI框架：** SwiftUI + AppKit (NSStatusItem)
- **构建：** Swift Package Manager
- **最低版本：** macOS 13.0

### 3.2 模块划分

```
PluginHub/
├── Package.swift
├── Sources/
│   ├── PluginHubCore/           # 核心逻辑
│   │   ├── Models/              # 数据模型
│   │   ├── PluginEngine/        # 插件执行引擎
│   │   ├── PluginStore/         # 插件数据存储
│   │   └── SharedData/          # 插件间共享数据
│   │
│   └── PluginHubApp/            # UI 层
│       ├── MenuBar/             # 菜单栏状态项
│       ├── Dashboard/           # 弹出面板
│       ├── Components/          # 通用 UI 组件
│       └── Settings/            # 设置界面
│
├── Resources/
│   └── BuiltinPlugins/          # 内置示例插件
│
└── Tests/
```

## 4. 核心数据模型

### 4.1 插件输出协议 (PluginOutput)

```swift
/// 插件输出的根结构
struct PluginOutput: Codable {
    let updatedAt: Date
    let title: String?           // 可选标题
    let icon: String?            // 可选图标 (SF Symbol 名称或 URL)
    let badge: String?           // 菜单栏角标文字
    let components: [Component]  // UI 组件列表
    let notification: Notification?  // 可选提醒
}

/// 提醒配置
struct Notification: Codable {
    let title: String
    let body: String
    let sound: Bool?             // 是否播放声音
    let url: String?             // 点击后打开的链接
    let scheduledAt: Date?       // 定时触发（nil 表示立即）
}

/// UI 组件 - 使用 enum 实现多态
enum Component: Codable {
    case progress(ProgressComponent)    // 进度条
    case list(ListComponent)            // 列表/表格
    case chart(ChartComponent)          // 图表
    case text(TextComponent)            // 纯文本/提醒
    case image(ImageComponent)          // 图片
    case interactive(InteractiveComponent)  // 交互式组件
    case custom(CustomComponent)        // 自定义
}
```

### 4.2 基础组件类型

```swift
/// 进度条组件
struct ProgressComponent: Codable {
    let id: String
    let label: String
    let value: Double
    let max: Double
    let unit: String?            // 单位显示
    let color: String?           // 颜色 (hex)
    let style: ProgressStyle     // .bar, .ring, .gauge
}

/// 列表组件
struct ListComponent: Codable {
    let id: String
    let title: String?
    let items: [ListItem]
    let style: ListStyle         // .simple, .detailed, .table
}

struct ListItem: Codable {
    let title: String
    let subtitle: String?
    let value: String?
    let icon: String?
    let color: String?
    let url: String?             // 可点击跳转
}

/// 图表组件
struct ChartComponent: Codable {
    let id: String
    let title: String?
    let type: ChartType          // .line, .bar, .pie
    let data: [ChartDataPoint]
    let xLabel: String?
    let yLabel: String?
}

struct ChartDataPoint: Codable {
    let label: String
    let value: Double
    let series: String?          // 用于多系列
}

/// 文本组件 - 纯文本/提醒
struct TextComponent: Codable {
    let id: String
    let content: String          // 文本内容（支持 Markdown）
    let style: TextStyle?        // .plain, .markdown, .alert, .success, .warning
    let icon: String?            // 可选图标
    let url: String?             // 可点击链接
}

/// 图片组件
struct ImageComponent: Codable {
    let id: String
    let url: String              // 图片 URL 或 base64
    let alt: String?             // 替代文本
    let width: Double?           // 可选宽度
    let height: Double?          // 可选高度
    let caption: String?         // 图片说明
}

/// 交互式组件 - 支持用户交互（如小游戏）
struct InteractiveComponent: Codable {
    let id: String
    let type: InteractiveType    // .scratchcard, .button, .input, .toggle
    let config: InteractiveConfig
    let state: [String: AnyCodable]?  // 组件状态
}

/// 交互类型
enum InteractiveType: String, Codable {
    case scratchcard   // 刮刮乐
    case button        // 按钮
    case input         // 输入框
    case toggle        // 开关
}

/// 交互配置
struct InteractiveConfig: Codable {
    let title: String?
    let description: String?
    let actions: [InteractiveAction]?  // 可用操作
}

/// 交互操作
struct InteractiveAction: Codable {
    let id: String
    let label: String
    let type: ActionType         // .callback, .url, .copy
    let payload: String?
}

enum ActionType: String, Codable {
    case callback   // 回调插件
    case url        // 打开链接
    case copy       // 复制到剪贴板
}

/// 自定义组件 - 允许插件定义任意 key-value 结构
struct CustomComponent: Codable {
    let id: String
    let type: String             // 自定义类型标识
    let data: [String: AnyCodable]  // 任意数据
}
```

### 4.3 插件配置

```swift
struct PluginConfiguration: Codable, Identifiable {
    let id: UUID
    var name: String
    var enabled: Bool
    var executablePath: String
    var refreshIntervalSeconds: TimeInterval
    var parameters: [String: String]  // 传递给插件的参数
    var metadata: PluginMetadata?
}

/// 从脚本注释解析的元数据
struct PluginMetadata: Codable {
    let name: String
    let description: String?
    let author: String?
    let version: String?
    let icon: String?
    let parameters: [ParameterDefinition]
    let outputSchema: String?    // 声明使用的组件类型
}

struct ParameterDefinition: Codable {
    let name: String
    let type: ParameterType      // .string, .secret, .integer, .boolean, .choice
    let label: String
    let description: String?
    let defaultValue: String?
    let choices: [String]?       // 用于 choice 类型
}
```

## 5. 插件协议规范

### 5.1 脚本元数据格式

```python
#!/usr/bin/env python3
# PluginHub:
#   name: 系统监控
#   description: 显示 CPU、内存、磁盘使用情况
#   author: Developer
#   version: 1.0.0
#   icon: desktopcomputer
#   parameters:
#     - name: interval
#       type: integer
#       label: 刷新间隔(秒)
#       default: 5
# /PluginHub

import json
from datetime import datetime

# 插件逻辑
data = {
    "updatedAt": datetime.utcnow().isoformat() + "Z",
    "title": "系统监控",
    "icon": "desktopcomputer",
    "badge": "正常",
    "components": [
        {
            "type": "progress",
            "id": "cpu",
            "label": "CPU",
            "value": 45.2,
            "max": 100,
            "unit": "%",
            "color": "#007AFF",
            "style": "bar"
        },
        {
            "type": "list",
            "id": "disks",
            "title": "磁盘",
            "style": "simple",
            "items": [
                {"title": "Macintosh HD", "value": "256GB / 512GB"},
                {"title": "External", "value": "100GB / 1TB"}
            ]
        }
    ]
}

print(json.dumps(data))
```

### 5.2 插件执行

- 执行命令：`/usr/bin/env python3 <script_path> --pluginhub-param KEY=value`
- 超时：30秒
- 输出：stdout 解析为 JSON
- 错误：stderr 记录到日志

### 5.3 插件间数据共享

插件可读取其他插件的最近一次输出：

```python
import json
import os

# 读取其他插件的数据
shared_dir = os.environ.get("PLUGINHUB_SHARED_DIR")
other_output = json.load(open(f"{shared_dir}/other-plugin-id.json"))

# 使用其他插件的数据
cpu_usage = next(
    (c["value"] for c in other_output["components"]
     if c.get("id") == "cpu"),
    0
)
```

## 6. UI 组件系统

### 6.1 主题支持与毛玻璃效果

```swift
/// 主题配置
enum Theme: String, Codable {
    case system    // 跟随系统
    case light     // 浅色
    case dark      // 深色
}

/// 视觉效果配置
struct VisualEffect: Codable {
    let enabled: Bool            // 是否启用毛玻璃
    let material: MaterialType   // 毛玻璃材质
    let blending: BlendingMode   // 混合模式
}

/// macOS 毛玻璃材质类型
enum MaterialType: String, Codable {
    case headerView          // 标题栏效果
    case sheet               // 弹窗效果
    case menu                // 菜单效果
    case popover             // 弹出框效果
    case sidebar             // 侧边栏效果
    case windowBackground    // 窗口背景
    case contentBackground   // 内容背景
    case underWindowBackground // 窗口下方背景
}

/// 混合模式
enum BlendingMode: String, Codable {
    case behindWindow   // 窗口后方
    case withinWindow   // 窗口内
}

/// 主题颜色（可选自定义）
struct ThemeColors: Codable {
    let background: String?      // 背景色（毛玻璃时为叠加色）
    let foreground: String       // 前景色
    let accent: String           // 强调色
    let cardBackground: String?  // 卡片背景
    let border: String?          // 边框色
}

// 在 config.json 中
{
    "theme": "system",
    "visualEffect": {
        "enabled": true,
        "material": "sidebar",
        "blending": "behindWindow"
    },
    "customColors": null
}
```

**毛玻璃效果实现：**

```swift
import SwiftUI

// 使用 NSVisualEffectView 实现毛玻璃
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

// 在 Dashboard 中使用
struct DashboardView: View {
    var body: some View {
        VisualEffectView(material: .sidebar, blending: .behindWindow)
            .overlay {
                // 插件卡片内容
                VStack {
                    ForEach(plugins) { plugin in
                        PluginCardView(plugin: plugin)
                    }
                }
            }
    }
}

// 插件卡片也使用毛玻璃
struct PluginCardView: View {
    var body: some View {
        VisualEffectView(material: .contentBackground, blending: .withinWindow)
            .cornerRadius(10)
            .overlay {
                // 卡片内容
            }
    }
}
```

**支持的毛玻璃效果：**
- Dashboard 整体背景：`.sidebar` 材质
- 插件卡片：`.contentBackground` 材质
- 设置窗口：`.windowBackground` 材质
- 弹出菜单：`.menu` 材质

### 6.2 组件排序和展开/折叠

```swift
/// 插件卡片状态
struct PluginCardState: Codable {
    let pluginId: UUID
    var isExpanded: Bool         // 是否展开
    var componentOrder: [String] // 组件显示顺序（组件 ID 列表）
}

// 保存到 ~/Library/Application Support/PluginHub/card-states.json
```

### 6.3 组件渲染器

每种组件类型对应一个 SwiftUI View：

```swift
// 进度条渲染器
struct ProgressRenderer: View {
    let component: ProgressComponent
    var body: some View {
        switch component.style {
        case .bar: LinearProgressView(value: component.value, total: component.max)
        case .ring: RingProgressView(value: component.value, total: component.max)
        case .gauge: GaugeProgressView(value: component.value, total: component.max)
        }
    }
}

// 列表渲染器
struct ListRenderer: View {
    let component: ListComponent
    var body: some View {
        switch component.style {
        case .simple: SimpleListView(items: component.items)
        case .detailed: DetailedListView(items: component.items)
        case .table: TableListView(items: component.items)
        }
    }
}

// 图表渲染器
struct ChartRenderer: View {
    let component: ChartComponent
    var body: some View {
        switch component.type {
        case .line: LineChartView(data: component.data)
        case .bar: BarChartView(data: component.data)
        case .pie: PieChartView(data: component.data)
        }
    }
}

// 文本渲染器
struct TextRenderer: View {
    let component: TextComponent
    var body: some View {
        HStack {
            if let icon = component.icon {
                Image(systemName: icon)
            }
            Text(component.content)
                .style(component.style)
        }
    }
}

// 图片渲染器
struct ImageRenderer: View {
    let component: ImageComponent
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: component.url))
            if let caption = component.caption {
                Text(caption).font(.caption)
            }
        }
    }
}

// 交互式组件渲染器
struct InteractiveRenderer: View {
    let component: InteractiveComponent
    var body: some View {
        switch component.type {
        case .scratchcard: ScratchcardView(config: component.config, state: component.state)
        case .button: ButtonView(config: component.config)
        case .input: InputView(config: component.config)
        case .toggle: ToggleView(config: component.config)
        }
    }
}
```

### 6.2 菜单栏展示

```
┌─────────────────────────────────────────┐
│  PluginHub Icon  [badge]                │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐   │
│  │ Plugin 1: 系统监控              │   │
│  │ ┌─────────────────────────┐    │   │
│  │ │ CPU  ████████░░  80%    │    │   │
│  │ │ RAM  ██████░░░░  60%    │    │   │
│  │ └─────────────────────────┘    │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │ Plugin 2: API 配额              │   │
│  │ ┌─────────────────────────┐    │   │
│  │ │ OpenAI  ████████░░ 80%  │    │   │
│  │ │ Claude  ████░░░░░░ 40%  │    │   │
│  │ └─────────────────────────┘    │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │ Plugin 3: RSS 阅读器            │   │
│  │ ┌─────────────────────────┐    │   │
│  │ │ • HN: New Post Title... │    │   │
│  │ │ • Reddit: Interesting.. │    │   │
│  │ └─────────────────────────┘    │   │
│  └─────────────────────────────────┘   │
├─────────────────────────────────────────┤
│  ⚙ Settings    🔄 Refresh All          │
└─────────────────────────────────────────┘
```

## 7. 刷新机制

### 7.1 三种刷新模式

1. **定时轮询**：后台 Timer，间隔可配置（默认 60 秒）
2. **手动刷新**：用户点击刷新按钮
3. **主动推送**：插件可通过文件监控触发更新

### 7.2 主动推送实现

插件可写入一个 trigger 文件：

```python
# 插件写入触发文件
trigger_file = os.environ.get("PLUGINHUB_TRIGGER_FILE")
with open(trigger_file, 'w') as f:
    f.write(datetime.utcnow().isoformat())
```

App 监控该文件变化，收到信号后立即执行插件。

## 8. 配置存储

### 8.1 目录结构

```
~/Library/Application Support/PluginHub/
├── config.json                  # App 配置
├── card-states.json             # 卡片展开/排序状态
├── plugins/                     # 插件脚本（符号链接）
│   ├── system-monitor.py
│   └── api-quota.py
├── states/                      # 插件状态缓存
│   ├── {plugin-id-1}.json
│   └── {plugin-id-2}.json
└── shared/                      # 插件间共享数据
    └── {plugin-id}.json         # 每个插件的最新输出
```

### 8.2 config.json 结构

```json
{
  "schemaVersion": 1,
  "theme": "system",
  "plugins": [
    {
      "id": "uuid-here",
      "name": "系统监控",
      "enabled": true,
      "executablePath": "~/Library/Application Support/PluginHub/plugins/system-monitor.py",
      "refreshIntervalSeconds": 60,
      "parameters": {}
    }
  ],
  "globalRefreshIntervalSeconds": 60,
  "showBadge": true,
  "enableNotifications": true
}
```

## 9. 实现计划

### Phase 1: 基础框架（Week 1）

- [ ] 创建 Swift Package 项目结构
- [ ] 实现核心数据模型 (`PluginOutput`, `Component` 等)
- [ ] 实现插件执行引擎 (`PluginExecutor`)
- [ ] 实现配置存储 (`ConfigStore`)
- [ ] 实现主题系统 (`ThemeManager`)
- [ ] 实现基本菜单栏 UI (NSStatusItem + NSPopover)

### Phase 2: 组件渲染（Week 2）

- [ ] 实现 ProgressRenderer（进度条）
- [ ] 实现 ListRenderer（列表）
- [ ] 实现 ChartRenderer（图表）- 使用 Swift Charts
- [ ] 实现 TextRenderer（文本）
- [ ] 实现 ImageRenderer（图片）
- [ ] 实现 InteractiveRenderer（交互式组件）
- [ ] 实现 CustomComponentRenderer（自定义）
- [ ] 完成 Dashboard 布局

### Phase 3: 插件管理（Week 3）

- [ ] 实现插件元数据解析器
- [ ] 实现设置界面（插件列表、参数配置）
- [ ] 实现插件安装/卸载
- [ ] 实现插件间数据共享

### Phase 4: 高级功能（Week 4）

- [ ] 实现定时刷新调度器
- [ ] 实现手动刷新
- [ ] 实现文件监控触发更新
- [ ] 实现插件拖拽排序
- [ ] 实现组件排序（用户可调整显示顺序）
- [ ] 实现展开/折叠功能
- [ ] 实现定时提醒/通知系统
- [ ] 添加内置示例插件

### Phase 5: 打磨发布（Week 5）

- [ ] 错误处理和日志
- [ ] 性能优化
- [ ] 编写插件开发文档
- [ ] 打包和签名

## 10. 示例插件

### 10.1 系统监控插件

```python
#!/usr/bin/env python3
# PluginHub:
#   name: 系统监控
#   description: 显示 CPU、内存、磁盘使用情况
#   icon: desktopcomputer
# /PluginHub

import json
import psutil
from datetime import datetime

cpu = psutil.cpu_percent()
memory = psutil.virtual_memory()
disk = psutil.disk_usage('/')

data = {
    "updatedAt": datetime.utcnow().isoformat() + "Z",
    "title": "系统监控",
    "icon": "desktopcomputer",
    "components": [
        {
            "type": "progress",
            "id": "cpu",
            "label": "CPU",
            "value": cpu,
            "max": 100,
            "unit": "%",
            "style": "bar"
        },
        {
            "type": "progress",
            "id": "memory",
            "label": "内存",
            "value": memory.percent,
            "max": 100,
            "unit": "%",
            "style": "bar"
        },
        {
            "type": "progress",
            "id": "disk",
            "label": "磁盘",
            "value": disk.percent,
            "max": 100,
            "unit": "%",
            "style": "ring"
        }
    ]
}

print(json.dumps(data))
```

### 10.2 GitHub Trending 插件

```python
#!/usr/bin/env python3
# PluginHub:
#   name: GitHub Trending
#   description: 显示 GitHub 热门项目
#   icon: star.fill
# /PluginHub

import json
import requests
from datetime import datetime

# 获取 trending 数据
repos = requests.get("https://gh-trending-api.herokuapp.com/repositories").json()[:5]

data = {
    "updatedAt": datetime.utcnow().isoformat() + "Z",
    "title": "GitHub Trending",
    "icon": "star.fill",
    "components": [
        {
            "type": "list",
            "id": "trending",
            "style": "detailed",
            "items": [
                {
                    "title": repo["name"],
                    "subtitle": repo["description"],
                    "value": f"⭐ {repo['stars']}",
                    "url": repo["url"]
                }
                for repo in repos
            ]
        }
    ]
}

print(json.dumps(data))
```

## 11. 更多插件场景

### 11.1 远程服务器监控（支持快速 SSH 连接）

```python
#!/usr/bin/env python3
# PluginHub:
#   name: 服务器监控
#   description: 通过 SSH 监控远程服务器状态，支持快速打开终端
#   icon: server.rack
#   parameters:
#     - name: host
#       type: string
#       label: 服务器地址
#     - name: user
#       type: string
#       label: SSH 用户名
#     - name: key_path
#       type: string
#       label: SSH 密钥路径
#     - name: terminal
#       type: choice
#       label: 终端应用
#       choices: ["Terminal", "iTerm", "Ghostty", "Kitty", "Alacritty"]
#       default: "Terminal"
# /PluginHub

import json
import subprocess
import os
from datetime import datetime

host = os.environ.get("PLUGINHUB_PARAM_HOST")
user = os.environ.get("PLUGINHUB_PARAM_USER")
key_path = os.environ.get("PLUGINHUB_PARAM_KEY_PATH")
terminal = os.environ.get("PLUGINHUB_PARAM_TERMINAL", "Terminal")

# 通过 SSH 获取服务器信息
def ssh_cmd(cmd):
    try:
        result = subprocess.run(
            ["ssh", "-i", key_path, "-o", "ConnectTimeout=5", f"{user}@{host}", cmd],
            capture_output=True, text=True, timeout=10
        )
        return result.stdout.strip()
    except:
        return None

# 生成终端启动命令
def get_terminal_command():
    ssh_cmd_str = f"ssh -i {key_path} {user}@{host}"
    commands = {
        "Terminal": f'osascript -e \'tell app "Terminal" to do script "{ssh_cmd_str}"\'',
        "iTerm": f'osascript -e \'tell app "iTerm" to create window with default profile command "{ssh_cmd_str}"\'',
        "Ghostty": f'ghostty -e {ssh_cmd_str}',
        "Kitty": f'kitty {ssh_cmd_str}',
        "Alacritty": f'alacritty -e {ssh_cmd_str}'
    }
    return commands.get(terminal, commands["Terminal"])

cpu = ssh_cmd("top -bn1 | grep 'Cpu(s)' | awk '{print $2}'")
memory = ssh_cmd("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'")
disk = ssh_cmd("df -h / | awk 'NR==2{print $5}' | tr -d '%'")

is_online = cpu is not None

data = {
    "updatedAt": datetime.utcnow().isoformat() + "Z",
    "title": f"服务器: {host}",
    "icon": "server.rack",
    "badge": "在线" if is_online else "离线",
    "components": [
        {
            "type": "text",
            "id": "status",
            "content": f"🟢 已连接" if is_online else "🔴 无法连接",
            "style": "success" if is_online else "alert"
        },
        {
            "type": "progress",
            "id": "cpu",
            "label": "CPU",
            "value": float(cpu) if cpu else 0,
            "max": 100,
            "unit": "%",
            "style": "bar"
        },
        {
            "type": "progress",
            "id": "memory",
            "label": "内存",
            "value": float(memory) if memory else 0,
            "max": 100,
            "unit": "%",
            "style": "bar"
        },
        {
            "type": "progress",
            "id": "disk",
            "label": "磁盘",
            "value": float(disk) if disk else 0,
            "max": 100,
            "unit": "%",
            "style": "ring"
        },
        {
            "type": "interactive",
            "id": "connect",
            "type": "button",
            "config": {
                "title": "快速连接",
                "description": f"使用 {terminal} 打开 SSH 连接",
                "actions": [
                    {
                        "id": "open_terminal",
                        "label": f"打开 {terminal}",
                        "type": "callback",
                        "payload": get_terminal_command()
                    }
                ]
            }
        }
    ]
}
print(json.dumps(data))
```

**终端快速连接实现原理：**
- 插件输出中包含一个 `interactive` 类型的 button 组件
- App 端收到 `callback` 类型的 action 时，执行 payload 中的命令
- 支持 Terminal、iTerm、Ghostty、Kitty、Alacritty 等主流终端

### 11.2 刮刮乐小游戏

```python
#!/usr/bin/env python3
# PluginHub:
#   name: 刮刮乐
#   description: 每日刮刮乐小游戏
#   icon: gift.fill
# /PluginHub

import json
import random
from datetime import datetime, date

# 生成今日奖池
today = date.today().isoformat()
random.seed(today)  # 同一天结果相同

prizes = ["🎉 恭喜中奖 100元!", "🎁 获得优惠券", "😊 再接再厉", "🌟 今日幸运星", "💪 明天再来"]
prize = random.choice(prizes)

data = {
    "updatedAt": datetime.utcnow().isoformat() + "Z",
    "title": "每日刮刮乐",
    "icon": "gift.fill",
    "components": [
        {
            "type": "text",
            "id": "info",
            "content": "点击下方按钮试试今日手气！",
            "style": "plain"
        },
        {
            "type": "interactive",
            "id": "scratchcard",
            "type": "scratchcard",
            "config": {
                "title": "刮刮卡",
                "description": "刮开查看结果",
                "actions": [
                    {"id": "scratch", "label": "刮开", "type": "callback", "payload": "reveal"}
                ]
            },
            "state": {
                "revealed": False,
                "prize": prize,
                "scratch_area": "████████████████"
            }
        }
    ]
}
print(json.dumps(data))
```

### 11.3 API 数据统计

```python
#!/usr/bin/env python3
# PluginHub:
#   name: 网站统计
#   description: 通过 API 查询网站访问数据
#   icon: chart.bar.fill
#   parameters:
#     - name: api_key
#       type: secret
#       label: API Key
# /PluginHub

import json
import requests
from datetime import datetime

api_key = os.environ.get("PLUGINHUB_PARAM_API_KEY")

# 获取数据
stats = requests.get("https://api.example.com/stats", headers={"Authorization": api_key}).json()

data = {
    "updatedAt": datetime.utcnow().isoformat() + "Z",
    "title": "网站统计",
    "icon": "chart.bar.fill",
    "components": [
        {
            "type": "list",
            "id": "overview",
            "title": "今日概览",
            "style": "detailed",
            "items": [
                {"title": "访问量", "value": str(stats["visits"]), "icon": "eye.fill"},
                {"title": "用户数", "value": str(stats["users"]), "icon": "person.fill"},
                {"title": "页面浏览", "value": str(stats["pageviews"]), "icon": "doc.fill"}
            ]
        },
        {
            "type": "chart",
            "id": "trend",
            "title": "7天趋势",
            "type": "line",
            "data": [
                {"label": day["date"], "value": day["visits"], "series": "访问量"}
                for day in stats["weekly"]
            ]
        },
        {
            "type": "image",
            "id": "screenshot",
            "url": stats.get("screenshot_url", ""),
            "caption": "网站截图"
        }
    ]
}
print(json.dumps(data))
```

### 11.4 定时提醒插件

```python
#!/usr/bin/env python3
# PluginHub:
#   name: 喝水提醒
#   description: 定时提醒喝水
#   icon: drop.fill
#   parameters:
#     - name: interval_minutes
#       type: integer
#       label: 提醒间隔(分钟)
#       default: 30
# /PluginHub

import json
from datetime import datetime, timedelta

interval = int(os.environ.get("PLUGINHUB_PARAM_INTERVAL_MINUTES", "30"))
nextReminder = datetime.utcnow() + timedelta(minutes=interval)

data = {
    "updatedAt": datetime.utcnow().isoformat() + "Z",
    "title": "喝水提醒",
    "icon": "drop.fill",
    "components": [
        {
            "type": "text",
            "id": "status",
            "content": f"每 {interval} 分钟提醒喝水",
            "style": "plain"
        },
        {
            "type": "progress",
            "id": "countdown",
            "label": "下次提醒",
            "value": 0,
            "max": interval,
            "unit": "分钟",
            "style": "ring"
        }
    ],
    "notification": {
        "title": "喝水时间到！",
        "body": "记得喝一杯水，保持健康 💧",
        "sound": True,
        "scheduledAt": nextReminder.isoformat() + "Z"
    }
}
print(json.dumps(data))
```

## 12. 设计约束

### 12.1 插件输出约束

| 约束项 | 限制值 | 说明 |
|--------|--------|------|
| JSON 最大大小 | 1MB | 超出则解析失败 |
| 组件数量上限 | 50 个 | 单个插件最多输出 50 个组件 |
| 列表项数量上限 | 100 项 | 单个列表组件最多 100 项 |
| 图表数据点上限 | 1000 点 | 单个图表最多 1000 个数据点 |
| 图片大小上限 | 5MB | base64 图片最大 5MB |
| 执行超时 | 30 秒 | 插件执行超时时间 |
| 刷新间隔最小值 | 10 秒 | 避免过于频繁的刷新 |

### 12.2 组件 ID 约束

- 组件 ID 必须在单个插件内唯一
- ID 格式：`[a-zA-Z0-9_-]`，长度 1-64 字符
- 用于组件排序和状态持久化

### 12.3 错误处理规范

插件执行失败时，App 应：
1. 显示最后一次成功的数据（如有缓存）
2. 显示错误状态卡片，包含：
   - 错误类型（超时、解析失败、执行失败）
   - 错误信息（stderr 输出）
   - 重试按钮
3. 记录错误日志到 `~/Library/Application Support/PluginHub/logs/`

### 12.4 性能约束

| 指标 | 目标值 |
|------|--------|
| Dashboard 打开时间 | < 500ms |
| 插件并发执行数 | 最多 5 个 |
| 内存占用 | < 100MB |
| CPU 空闲占用 | < 1% |
| 状态缓存大小 | 每个插件 < 100KB |

### 12.5 安全约束（虽无限制，但有底线）

- 不执行非用户主动安装的插件
- 插件参数中的 secret 类型在 UI 中显示为 `••••••`
- 不自动执行插件的 callback 操作，需用户确认

## 13. 与 UsageBoard 的区别

| 特性 | UsageBoard | PluginHub |
|------|-----------|-----------|
| 定位 | AI API 配额监控 | 通用插件平台 |
| UI 组件 | 只有进度条 | 进度条、列表、图表、文本、图片、交互式、自定义 |
| 数据模型 | UsageItem (used/limit) | Component (多态) |
| 插件交互 | 无 | 可读取其他插件数据 |
| 刷新 | 定时轮询 | 定时 + 手动 + 推送 |
| 扩展性 | 受限于配额展示 | 高度可扩展 |

## 12. 验证计划

### 功能验证

1. 基本功能
   - [ ] 菜单栏图标显示
   - [ ] 点击弹出 Dashboard
   - [ ] 插件执行和 JSON 解析
   - [ ] 组件正确渲染

2. 插件管理
   - [ ] 安装新插件
   - [ ] 启用/禁用插件
   - [ ] 配置插件参数
   - [ ] 拖拽排序

3. 刷新机制
   - [ ] 定时刷新正常工作
   - [ ] 手动刷新立即生效
   - [ ] 文件触发更新生效

4. 数据共享
   - [ ] 插件可读取其他插件数据
   - [ ] 数据更新后共享数据同步更新

### 测试用例

编写以下测试插件：
1. 测试所有组件类型的展示
2. 测试参数传递
3. 测试数据共享
4. 测试错误处理（超时、JSON 解析失败等）
