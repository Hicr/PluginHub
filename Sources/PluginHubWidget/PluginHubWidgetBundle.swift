import WidgetKit
import SwiftUI
import PluginHubCore

@available(macOS 14.0, *)
struct PluginHubWidget: Widget {
    let kind: String = "com.pluginhub.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PluginHub")
        .description("显示插件指标的桌面小组件")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PluginHubWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(macOS 14.0, *) {
            PluginHubWidget()
        }
    }
}
