import SwiftUI
import PluginHubCore

struct DashboardView: View {
    @ObservedObject var store: PluginHubStore
    var onSizeChange: ((NSSize) -> Void)?

    static let contentWidth: CGFloat = 400

    private var maxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) * 0.85
    }

    private var enabledPlugins: [PluginConfiguration] {
        store.configuration.plugins.filter(\.enabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 小三角指示器（不裁切，共享背景材质）
            TriangleIndicator()
                .fill(.clear)
                .frame(width: 16, height: 8)

            VStack(spacing: 0) {
                HeaderView(store: store)

                Divider()

                if enabledPlugins.isEmpty {
                    EmptyPluginsView {
                        AppDelegate.shared?.openSettings()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(enabledPlugins.enumerated()), id: \.element.id) { index, plugin in
                                PluginCardView(
                                    snapshot: store.snapshot(for: plugin),
                                    isExpanded: store.cardExpandedStates[plugin.id] ?? true,
                                    isFirst: index == 0,
                                    isLast: index == enabledPlugins.count - 1,
                                    onToggle: { store.toggleCardExpanded(pluginID: plugin.id) },
                                    onMoveUp: { store.movePluginUp(pluginID: plugin.id) },
                                    onMoveDown: { store.movePluginDown(pluginID: plugin.id) },
                                    onRefresh: {
                                        store.refresh(pluginID: plugin.id, force: true)
                                    },
                                    onInteract: {
                                        store.refresh(pluginID: plugin.id, force: true)
                                    }
                                )
                            }
                        }
                        .padding(10)
                    }
                    .frame(maxHeight: maxHeight)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .background(backgroundView)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { reportSize(proxy.size) }
                    .onChange(of: proxy.size.height) { newH in reportSize(proxy.size) }
                    .onReceive(store.$configuration) { _ in
                        DispatchQueue.main.async { reportSize(proxy.size) }
                    }
            }
        )
    }

    private func reportSize(_ size: CGSize) {
        onSizeChange?(NSSize(width: size.width, height: size.height))
    }

    @ViewBuilder
    private var backgroundView: some View {
        if store.configuration.visualEffect.enabled {
            if #available(macOS 26, *) {
                Color.clear
                    .glassEffect(in: .rect(cornerRadius: 16))
            } else {
                Color.clear
                    .background(.ultraThinMaterial)
            }
        } else {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @ObservedObject var store: PluginHubStore

    var body: some View {
        HStack(spacing: 8) {
            if let url = Bundle.main.url(forResource: "menubar-icon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            Text("PluginHub")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button {
                store.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("刷新全部")
            Button {
                AppDelegate.shared?.openSettings()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("设置")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("退出 PluginHub")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Empty State

private struct EmptyPluginsView: View {
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("暂无启用的插件")
                .font(.headline)
            Text("在设置中添加并启用插件后显示。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("打开设置", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Plugin Card

struct PluginCardView: View {
    var snapshot: PluginSnapshot
    var isExpanded: Bool = true
    var isFirst: Bool = false
    var isLast: Bool = false
    var onToggle: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onInteract: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                if let iconName = snapshot.icon {
                    Image(systemName: iconName)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .frame(width: 18, height: 18)
                }

                Text(snapshot.displayName)
                    .font(.headline)

                if let badge = snapshot.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Spacer()

                statusView

                // 上移
                Button {
                    onMoveUp?()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isFirst ? .tertiary : .secondary)
                .disabled(isFirst)

                // 下移
                Button {
                    onMoveDown?()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isLast ? .tertiary : .secondary)
                .disabled(isLast)

                // 折叠
                Button {
                    onToggle?()
                } label: {
                    Image(systemName: isExpanded ? "chevron.forward" : "chevron.backward")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(isExpanded ? "收起" : "展开")
            }

            if isExpanded {
                Divider()

                // Components
                if snapshot.components.isEmpty {
                    Text(emptyText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ComponentGroupView(components: snapshot.components, onAction: onInteract)
                }
            }
        }
        .padding(10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(cardStroke)
    }

    @ViewBuilder
    private var cardBackground: some View {
        Color(nsColor: .controlBackgroundColor)
    }

    @ViewBuilder
    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
    }

    @ViewBuilder
    private var statusView: some View {
        switch snapshot.state {
        case .idle:
            Text("等待刷新")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .ready:
            if let updatedAt = snapshot.updatedAt {
                Button {
                    onRefresh?()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                Text(updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Text(message)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.red)
        }
    }

    private var emptyText: String {
        switch snapshot.state {
        case .failed:
            return "插件执行失败"
        default:
            return "暂无数据"
        }
    }
}

// MARK: - Component Renderer Dispatcher

struct ComponentRenderer: View {
    var component: Component
    var onAction: (() -> Void)?

    var body: some View {
        switch component {
        case .progress(let data):
            ProgressRenderer(component: data)
        case .list(let data):
            ListRenderer(component: data)
        case .chart(let data):
            ChartRenderer(component: data)
        case .text(let data):
            TextRenderer(component: data)
        case .image(let data):
            ImageRenderer(component: data)
        case .interactive(let data):
            InteractiveRenderer(component: data, onAction: onAction)
        case .custom(let data):
            CustomRenderer(component: data)
        }
    }
}

// MARK: - Component Group View (两两并排)

struct ComponentGroupView: View {
    let components: [Component]
    var onAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                ComponentRowView(row: row, onAction: onAction)
            }
        }
    }

    private var rows: [ComponentRow] {
        var result: [ComponentRow] = []
        var idx = 0
        let count = components.count
        while idx < count {
            let remaining = count - idx
            // 服务器监控：text 标签独占首行，后面 4 个一行
            if idx == 0, case .text = components[idx], remaining == 5 {
                result.append(.row([components[idx]]))
                idx += 1
            } else if idx == 1, case .text = components[0], remaining == 4 {
                result.append(.row(Array(components[idx..<idx+4])))
                idx += 4
            } else if remaining >= 3 {
                result.append(.row(Array(components[idx..<idx+3])))
                idx += 3
            } else if remaining >= 2 {
                result.append(.row(Array(components[idx..<idx+remaining])))
                idx += remaining
            } else {
                result.append(.row([components[idx]]))
                idx += 1
            }
        }
        return result
    }
}

enum ComponentRow {
    case row([Component])
}

struct ComponentRowView: View {
    let row: ComponentRow
    var onAction: (() -> Void)?

    var body: some View {
        switch row {
        case .row(let items):
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, component in
                    ComponentRenderer(component: component, onAction: onAction)
                }
            }
        }
    }
}

// MARK: - Triangle Indicator

struct TriangleIndicator: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

