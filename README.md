# PluginHub

macOS 菜单栏插件平台 —— 用 Python 写插件，SwiftUI 渲染 UI

## 功能特性

- **菜单栏集成**：驻留在 macOS 菜单栏，点击弹出 Dashboard 面板
- **Python 插件系统**：编写输出 JSON 的 Python 脚本即可生成 UI 组件
- **7 种 UI 组件**：进度条、列表、图表、文本、图片、交互式组件、自定义组件
- **参数配置**：插件通过 YAML 元数据声明参数，在设置面板中提供可视化配置
- **定时刷新**：可配置的刷新间隔，支持文件变更触发推送刷新
- **系统通知**：插件可通过输出 `notification` 字段触发 macOS 通知
- **Widget 支持**：macOS 14+ 支持桌面小组件，展示插件关键指标
- **液态玻璃效果**：macOS 26+ 原生 `glassEffect`，更早版本使用 `ultraThinMaterial` 毛玻璃
- **7 个内置插件**：系统监控、服务器监控、网络延迟、DeepSeek 余额、喝水提醒、每日签运、示例模板

## 工作原理

```
Python 插件脚本
    │
    │  输出 JSON (stdout)
    ▼
PluginExecutor (子进程, 30s 超时)
    │
    │  解码为 PluginOutput
    ▼
DashboardView
    │
    │  按组件类型分发
    ▼
SwiftUI 渲染器 (Progress / List / Chart / Text / Image / Interactive / Custom)
```

### 插件协议

每个插件是一个 Python 脚本，包含两部分：

**1. 元数据头部（YAML 注释）**

```python
# PluginHub:
#   name: 我的插件
#   description: 一个示例插件
#   icon: star.fill
#   parameters:
#     - name: title
#       type: string
#       label: 标题
#       default: Hello
# /PluginHub
```

支持的参数类型：`string`、`secret`、`integer`、`boolean`、`choice`、`time`、`textarea`、`server_list`

**2. JSON 输出（stdout）**

```json
{
  "updatedAt": "2026-01-01T00:00:00Z",
  "title": "我的插件",
  "icon": "star.fill",
  "badge": "3",
  "components": [
    {
      "type": "progress",
      "data": { "id": "cpu", "label": "CPU", "value": 45, "max": 100, "unit": "%", "style": "bar" }
    },
    {
      "type": "text",
      "data": { "id": "msg", "content": "运行正常", "style": "success" }
    }
  ]
}
```

参数通过 `--pluginhub-param key=value` 传入，共享数据通过 `$PLUGINHUB_SHARED_DIR` 环境变量访问。

### 组件类型

| 类型 | 用途 | 样式 |
|------|------|------|
| `progress` | 进度/指标展示 | bar / ring / gauge |
| `list` | 列表/表格 | simple / detailed / table |
| `chart` | 图表 | line / bar / pie |
| `text` | 文本消息 | plain / markdown / alert / success / warning |
| `image` | 图片展示 | URL 或 base64 |
| `interactive` | 交互式组件 | button / input / toggle / scratchcard |
| `custom` | 自定义键值对 | 任意 key-value 数据 |

### 设计约束

| 约束项 | 限制值 |
|--------|--------|
| 插件 JSON 输出 | 最大 1MB |
| 单插件组件数 | 最多 50 个 |
| 列表项数量 | 最多 100 项 |
| 图表数据点 | 最多 1000 点 |
| 图片大小 | 最大 5MB |
| 插件执行超时 | 30 秒 |
| 最小刷新间隔 | 10 秒 |
| 并发执行数 | 最多 5 个 |

## 项目结构

```
PluginHub/
├── Sources/
│   ├── PluginHubCore/         # 核心逻辑库
│   │   ├── PluginHubCore.swift      # 所有数据模型
│   │   ├── PluginExecutor.swift     # Python 插件执行引擎
│   │   ├── PluginMetadataParser.swift # 插件元数据解析
│   │   ├── ConfigStore.swift        # 配置持久化
│   │   ├── PluginStateStore.swift   # 插件状态缓存
│   │   ├── SharedDataStore.swift    # 插件间数据共享
│   │   └── WidgetDataStore.swift    # Widget 数据桥接
│   ├── PluginHubApp/          # 菜单栏 App
│   │   ├── PluginHubApp.swift       # AppDelegate + NSStatusItem + NSPopover
│   │   ├── PluginHubStore.swift     # 插件生命周期管理
│   │   ├── DashboardView.swift      # Dashboard 弹窗面板
│   │   ├── SettingsView.swift       # 设置界面
│   │   └── Components/             # 各组件 SwiftUI 渲染器
│   └── PluginHubWidget/       # macOS 14+ Widget 扩展
├── Resources/
│   ├── BundledPlugins/         # 内置插件
│   ├── menubar-icon.png        # 菜单栏图标
│   └── PluginHub.icns          # App 图标
├── scripts/
│   ├── dev-app.sh              # 构建打包脚本
│   └── generate-menubar-icon.swift  # 图标生成工具
├── docs/                       # 设计文档
└── Package.swift               # SPM 配置
```

## 技术栈

| 层级 | 技术 |
|------|------|
| UI 框架 | SwiftUI + AppKit (NSStatusItem + NSPopover) |
| 语言 | Swift 6 (strict concurrency) |
| 构建系统 | Swift Package Manager |
| 图表 | Swift Charts |
| Widget | WidgetKit (macOS 14+) |
| 通知 | UserNotifications |
| 插件语言 | Python 3（通过 `/usr/bin/env python3` 执行） |
| 最低系统 | macOS 13.0 |

无外部依赖，纯 Apple SDK。

## 快速开始

### 环境要求

- macOS 13.0+
- Xcode 16+（或 Swift 6.0+ 工具链）
- Python 3

### 构建运行

```bash
# 克隆
git clone https://github.com/Hicr/PluginHub.git
cd PluginHub

# 构建
swift build

# 开发版打包（创建 .app bundle）
bash scripts/dev-app.sh

# 运行
open .build/arm64-apple-macosx/debug/PluginHub.app
```

## 插件开发

### 快速示例

```python
#!/usr/bin/env python3
# PluginHub:
#   name: 我的第一个插件
#   description: 输出一个进度条
#   icon: gauge.with.dots.needle.33percent
# /PluginHub

import json
from datetime import datetime, timezone

print(json.dumps({
    "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "title": "我的插件",
    "components": [
        {
            "type": "progress",
            "data": {
                "id": "example",
                "label": "完成度",
                "value": 75,
                "max": 100,
                "unit": "%",
                "color": "#34C759",
                "style": "bar"
            }
        }
    ]
}))
```

将脚本放到 `~/Library/Application Support/PluginHub/plugins/`，在设置面板中添加即可。

更多信息参考 `Resources/PluginAuthoringGuide.html` 和 `docs/` 中的设计文档。

## 打包发布

### 开发版

```bash
bash scripts/dev-app.sh
```

脚本会构建主程序和 Widget，组装 `.app` bundle 并签名。

### 发布版

```bash
swift build -c release
```

发布前需要在 `scripts/dev-app.sh` 中配置你自己的 Apple Developer 签名身份，并在 `scripts/PluginHub.entitlements` 中配置你自己的 App Group ID。

### 菜单栏图标

```bash
swift scripts/generate-menubar-icon.swift
```

可在脚本中调整齿轮齿数、圆角弧度等参数后重新生成。

## 配置存储

配置文件：`~/Library/Application Support/PluginHub/config.json`。包含插件列表、主题、视觉效果、刷新间隔等设置。

## 许可证

MIT License - 详见 [LICENSE](LICENSE)
