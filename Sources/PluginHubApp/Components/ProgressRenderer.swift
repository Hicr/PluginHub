import SwiftUI
import PluginHubCore

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
            // unit 是完整尺寸信息（如 "3.2G / 7.8G"）时直接展示，不额外加数值
            if unit.contains("/"), unit.first?.isNumber == true {
                return unit
            }
            return valueStr + " " + unit
        }
        if component.max == 100 {
            return valueStr + "%"
        }
        return valueStr + " / " + maxStr
    }

    private var valueStr: String {
        component.value == component.value.rounded()
            ? String(format: "%.0f", component.value)
            : String(format: "%.1f", component.value)
    }

    private var maxStr: String {
        component.max == component.max.rounded()
            ? String(format: "%.0f", component.max)
            : String(format: "%.1f", component.max)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.16))
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * percentage), height: 10)
            }
        }
        .frame(height: 10)
    }

    private var progressRing: some View {
        HStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 40, height: 40)

            Text(formattedValue)
                .font(.caption)
                .monospacedDigit()
        }
    }

    private var progressGauge: some View {
        Gauge(value: component.value, in: 0...component.max) {
            EmptyView()
        }
        .gaugeStyle(.accessoryLinear)
        .tint(color)
    }

    private var percentage: CGFloat {
        guard component.max > 0 else { return 0 }
        return min(max(component.value / component.max, 0), 1)
    }

    private var color: Color {
        Color.from(hex: component.color, fallback: .accentColor)
    }
}
