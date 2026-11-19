# 实现参考

以下入口基于技能创建时的源码，修改前核对当前代码。

## Python 插件

- Sources/PluginHubCore/PluginHubCore.swift 包含模型和 Component 编解码。
- PluginMetadataParser.swift 从前 80 行读取 PluginHub 元数据块。
- PluginExecutor.swift 通过 /usr/bin/env python3 启动脚本，使用重复的 --pluginhub-param KEY=value 参数。stdout 是单个 JSON，错误写 stderr。输出上限 1 MB、组件最多 50 个、执行超时 30 秒。
- 参数解析参考 Resources/BundledPlugins/deepseek-balance.py 的 parse_params。hello-template.py 当前从 PLUGINHUB_PARAM_TITLE 取值，复制模板时需适配命令行传参。
- Resources/PluginAuthoringGuide.html 提供协议说明，字段与枚举以 Core 实时定义为准。
- PluginHubStore.installBundledPlugins 和 BundledPluginInstaller 处理安装。当前内置脚本链接到 App 资源，打包后验证实际脚本版本，保留配置中的凭据和启用状态。
- PLUGINHUB_SHARED_DIR 是共享目录，PLUGINHUB_TRIGGER_FILE 对应插件实例。系统监控借助实例触发路径隔离网速采样状态。

## Swift 原生插件

源码目录为 Sources/PluginHubApp/。

1. 参考 Countdown.swift、NetworkUsage.swift。由 PluginHubStore 持有服务，服务使用 @MainActor，跨 actor 类型为 Sendable。
2. 初始化时幂等注册 PluginConfiguration，使用稳定 stateID 标识。保留已存在实例的启用与配置。
3. 更新 PluginConfiguration.isNativePlugin。检查 reloadMetadata、setPluginEnabled、removePlugin、refresh、startSchedulers、refreshPluginsAfterConfigurationChange、startFileMonitors 和 updateWidgetPluginList 的分支。
4. 原生插件走各自生命周期，绕过 Python 执行和脚本文件监控。网络采样在 startSchedulers 同步启停，倒计时通过保存的结束日期恢复。
5. DashboardView 在现有排序循环中选专用卡片，SettingsView 复用左侧列表与右侧详情。按插件需要隐藏脚本路径或刷新间隔。
6. NetworkCardBackground 是当前卡片共享底色与圆角。Components/MonitorCardContent.swift 提供系统指标与余额的单页布局。

## 倒计时实例

设计在 docs/PluginHub倒计时插件设计.md。

- 单倒计时，四个独立输入框，天 0–99、小时 0–23、分秒 0–59，总时长大于零。
- Core 的 CountdownState 保存 duration 和 endDate，计算剩余时长与比例。Countdown 原子保存 countdown.json。取消保留时长，重新开始用原时长计算新结束时间。
- CountdownCard 用 TimelineView 每秒更新，Canvas 绘制数码管数字，Shape 绘制圆角边框斜线。结束时间居中靠下，操作按钮位于面板下方。
- 斜线按剩余时间逐段熄灭。已用 70% 转橙色、90% 转红色，结束时整圈绿色闪动一次，遵守系统减少动态效果设置。
- 此实例关闭通知，第一版声音关闭、默认启用，停用时保留结束时间。其他插件按各自需求确定这些选项。

## 验证入口

- swift build
- bash scripts/dev-app.sh
- swift build --show-bin-path 定位开发版输出目录。
- 用户要求 DMG 时运行 bash scripts/package-dmg.sh VERSION，根据用户指定或现有版本选择版本号并说明。
- plutil 核对 App 与 Widget 版本，codesign --verify --deep --strict 检查签名，hdiutil verify 与只读挂载检查 DMG。
- docs/ 当前被 Git 忽略，交付文档时说明其本地保存范围。技能位于 .agents/skills/pluginhub-plugin。
