# AGENTS.md

## 项目概述

PluginHub 是 macOS 13+ 菜单栏插件平台。Python 插件输出 JSON，应用使用 SwiftUI 和 AppKit 在菜单栏弹出面板中呈现结果。Swift Package 包含三个目标：

- `PluginHubCore` 负责模型、插件执行、元数据解析和数据持久化。
- `PluginHubApp` 负责菜单栏、Dashboard、设置和刷新调度。刷新与插件执行入口在 `Sources/PluginHubApp/PluginHubStore.swift`。
- `PluginHubWidget` 提供 macOS 14+ 桌面小组件，通过 Core 的 `WidgetDataStore` 读取数据。

## 构建与验证

```bash
swift build                  # 构建（Debug）
swift build -c release       # Release 构建
swift test                   # ⚠️ 当前测试目标未使用 XCTest，swift test 不会发现任何测试用例
bash scripts/dev-app.sh      # 创建 .app bundle，通知等功能必须在 .app 包内运行
```

测试文件 `Tests/PluginHubCoreTests/ModelsTests.swift` 是手动 `runTests()` 函数，非 XCTest，`swift test` 实际无效。

## 架构要点

- **Swift 6 严格并发模式**（`swiftLanguageModes: [.v6]`）：所有跨 actor 边界的类型必须 `Sendable`；UI 层用 `@MainActor`；`PluginExecutor.run()` 是同步阻塞调用，在 `Task.detached` 中执行
- 所有数据模型集中在 `Sources/PluginHubCore/PluginHubCore.swift` 一个文件，未按模型拆分
- `Component` 是带标签的枚举联合体，使用自定义 `Codable`（`type` + `data` 字段做类型区分），新增组件类型需在此处添加 case
- JSON 编解码统一通过 `PluginHubJSON.decoder()/encoder()`，日期策略为 `.iso8601`
- `PluginHubApp`（可执行目标）依赖 `PluginHubCore`（库目标），App 层不导出公开 API

## 插件系统

- Python 脚本通过 `/usr/bin/env python3` 执行，参数通过 `--pluginhub-param KEY=value` 传递
- 插件元数据写在脚本前 80 行内 `# PluginHub:` 和 `# /PluginHub` 之间的注释块中（YAML 或 JSON 格式）
- 插件 JSON 输出最大 1MB，组件最多 50 个，执行超时 30 秒
- stdout 输出单个符合 `PluginOutput` 的 JSON 对象。插件可以通过 `PLUGINHUB_SHARED_DIR` 访问共享数据，也可以用输出中的 `notification` 请求系统通知。
- 内置插件在 `Resources/BundledPlugins/`，首次启动自动安装到 `~/Library/Application Support/PluginHub/plugins/`
- 修改插件协议或新增插件时，可参考 `Resources/PluginAuthoringGuide.html` 和 `Resources/BundledPlugins/hello-template.py`。

## 容易踩的坑

- 修改 `PluginHubCore.swift` 中模型时，需同步更新 `Component` 的 `Codable` switch（encode + decode 两处）
- `PluginExecutor.run()` 是同步方法（内部 `Thread.sleep` 轮询等待），不能在主线程调用
- 通知权限仅在 .app bundle 内运行时才会请求（`isInAppBundle` 检查）
- 配置文件路径：`~/Library/Application Support/PluginHub/config.json`；状态缓存：同目录下 `states/`；触发文件：`triggers/`
- 无 lint/CI 配置，构建前手动 `swift build` 验证即可

## Agent skills

### Issue tracker

本仓库使用本地 Markdown issue tracker：issue 与 spec 以文件形式存放在 `.scratch/<feature-slug>/`，建票、认领、改状态通过 deck 工具执行。See `docs/agents/issue-tracker.md`.

### Triage labels

沿用五个默认 triage 角色：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`（标签字符串与角色名相同）。See `docs/agents/triage-labels.md`.

### Domain docs

single-context：全仓库共用一份根目录 `GLOSSARY.md`，架构决策记录在 `docs/adr/`。See `docs/agents/domain.md`.
