import SwiftUI
import WidgetKit
import PluginHubCore

@available(macOS 14.0, *)
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 6) {
            if entry.componentType == "progress" {
                ZStack {
                    Circle()
                        .stroke(progressColor.opacity(0.16), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(entry.formattedValue)
                            .font(.system(.title2, design: .rounded).bold())
                            .monospacedDigit()
                        Text(entry.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "puzzlepiece.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(entry.label.isEmpty ? "添加指标" : entry.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(entry.pluginName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .containerBackground(for: .widget) {
            glassBackground
        }
    }

    private var mediumView: some View {
        VStack(spacing: 8) {
            Text(entry.pluginName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if entry.componentType == "progress" {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.formattedValue)
                            .font(.title.bold())
                            .monospacedDigit()
                    }
                    ProgressView(value: entry.progress)
                        .tint(progressColor)
                }
            } else {
                VStack(spacing: 4) {
                    Text(entry.label)
                        .font(.title3)
                    Text(entry.formattedValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .containerBackground(for: .widget) {
            glassBackground
        }
    }

    private var progressColor: Color {
        Color.from(hex: entry.colorHex, fallback: .accentColor)
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(macOS 26, *) {
            Color.clear.glassEffect(in: .rect(cornerRadius: 0))
        } else {
            Color.clear.background(.ultraThinMaterial)
        }
    }
}
