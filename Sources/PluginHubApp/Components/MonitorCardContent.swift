import PluginHubCore
import SwiftUI

struct SystemMonitorCardContent: View {
    let components: [Component]

    private var resources: [ProgressComponent] {
        components.compactMap {
            guard case .progress(let data) = $0 else { return nil }
            return data
        }
    }

    private var statuses: [TextComponent] {
        components.compactMap {
            guard case .text(let data) = $0 else { return nil }
            return data
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !resources.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(resources, id: \.id) { resource in
                        ProgressRenderer(component: percentage(resource))
                            .frame(maxWidth: .infinity)
                    }
                }

                if let capacity = resources.first(where: { $0.id == "disk" })?.unit,
                   capacity.contains("/") {
                    Text(capacity.hasSuffix("可用") ? "磁盘 · " + capacity : "磁盘 · " + capacity + " 可用")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if let network = statuses.first(where: { $0.id == "network" }) {
                let speeds = network.content.split(whereSeparator: \.isNewline)
                Divider()
                HStack(spacing: 12) {
                    reading("下载", value: speed(speeds, prefix: "↓"), icon: "arrow.down")
                    reading("上传", value: speed(speeds, prefix: "↑"), icon: "arrow.up")
                }
            }

            HStack(spacing: 12) {
                if let power = statuses.first(where: { $0.id == "power" }) {
                    let battery = power.content.hasPrefix("🔋")
                    let value = power.content
                        .replacingOccurrences(of: "🔋 ", with: "")
                        .replacingOccurrences(of: "⚡ ", with: "")
                    reading("电源", value: value, icon: battery ? "battery.50percent" : "bolt")
                }
                if let thermal = statuses.first(where: { $0.id == "thermal" }) {
                    reading("热状态", value: thermal.content, icon: "thermometer.medium")
                }
            }
        }
    }

    private func percentage(_ resource: ProgressComponent) -> ProgressComponent {
        var metric = resource
        metric.unit = "%"
        return metric
    }

    private func speed(_ lines: [Substring], prefix: Character) -> String {
        guard let line = lines.first(where: { $0.first == prefix }) else { return "—" }
        let value = line.dropFirst().trimmingCharacters(in: .whitespaces)
        return value.isEmpty || value == "--" ? "—" : value
    }

    private func reading(_ label: String, value: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DeepSeekCardContent: View {
    let summary: TextComponent
    let details: [ListComponent]

    var body: some View {
        let lines = summary.content.split(whereSeparator: \.isNewline)
        let status = lines.first.map(String.init) ?? "暂无余额明细"
        let amounts = Array(lines.dropFirst())

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(summary.style == .alert ? Color.red : Color.secondary)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(Array(amounts.enumerated()), id: \.offset) { _, amount in
                        Text(amount)
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }

            ForEach(details, id: \.id) { detail in
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    if details.count > 1, let currency = detail.title {
                        Text(currency)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(detail.items) { item in
                        HStack(spacing: 7) {
                            Image(systemName: item.icon ?? "creditcard")
                                .frame(width: 16)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(item.title)
                            Spacer(minLength: 8)
                            if let value = item.value {
                                Text(value)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }
}
