import WidgetKit
import PluginHubCore

struct WidgetEntry: TimelineEntry {
    let date: Date
    let pluginName: String
    let componentID: String
    let label: String
    let value: Double
    let maxValue: Double
    let unit: String
    let componentType: String
    let colorHex: String?

    var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    var formattedValue: String {
        if value == value.rounded() {
            return "\(Int(value))" + (unit.isEmpty ? "" : " \(unit)")
        }
        return String(format: "%.1f", value) + (unit.isEmpty ? "" : " \(unit)")
    }

    static var placeholder: WidgetEntry {
        WidgetEntry(
            date: Date(),
            pluginName: "PluginHub",
            componentID: "cpu",
            label: "CPU",
            value: 45,
            maxValue: 100,
            unit: "%",
            componentType: "progress",
            colorHex: "#007AFF"
        )
    }
}
