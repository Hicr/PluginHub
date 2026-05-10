import WidgetKit
import PluginHubCore

struct WidgetProvider: TimelineProvider {
    let dataStore = WidgetDataStore()

    func placeholder(in context: Context) -> WidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let config = dataStore.loadWidgetConfig()
        let entry = loadEntry(config: config)
        let nextRefresh = Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func loadEntry(config: WidgetConfig?) -> WidgetEntry {
        guard let config,
              let pluginID = config.pluginID,
              let cached = dataStore.loadSnapshot(stateID: pluginID) else {
            return WidgetEntry(
                date: Date(), pluginName: "PluginHub", componentID: "",
                label: "暂无数据", value: 0, maxValue: 1, unit: "",
                componentType: "text", colorHex: nil
            )
        }

        let components = cached.components
        guard config.componentIndex < components.count else {
            return WidgetEntry(
                date: Date(), pluginName: cached.title ?? "PluginHub", componentID: "",
                label: "选择指标", value: 0, maxValue: 1, unit: "",
                componentType: "text", colorHex: nil
            )
        }

        let component = components[config.componentIndex]

        switch component {
        case .progress(let c):
            return WidgetEntry(
                date: Date(), pluginName: cached.title ?? "", componentID: c.id,
                label: c.label, value: c.value, maxValue: c.max,
                unit: c.unit ?? "%", componentType: "progress", colorHex: c.color
            )
        case .text(let c):
            return WidgetEntry(
                date: Date(), pluginName: cached.title ?? "", componentID: c.id,
                label: c.content, value: 0, maxValue: 1, unit: "",
                componentType: "text", colorHex: nil
            )
        case .list(let c):
            let firstItem = c.items.first
            return WidgetEntry(
                date: Date(), pluginName: cached.title ?? "", componentID: c.id,
                label: c.title ?? firstItem?.title ?? "",
                value: Double(c.items.count), maxValue: 1, unit: "项",
                componentType: "text", colorHex: firstItem?.color
            )
        default:
            return WidgetEntry(
                date: Date(), pluginName: cached.title ?? "", componentID: "",
                label: "不支持", value: 0, maxValue: 1, unit: "",
                componentType: "text", colorHex: nil
            )
        }
    }
}
