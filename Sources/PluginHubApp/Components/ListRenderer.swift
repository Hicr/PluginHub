import SwiftUI
import PluginHubCore

struct ListRenderer: View {
    let component: ListComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = component.title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            switch component.style {
            case .simple:
                simpleListView
            case .detailed:
                detailedListView
            case .table:
                tableView
            }
        }
    }

    private var simpleListView: some View {
        VStack(spacing: 2) {
            ForEach(component.items) { item in
                HStack(spacing: 6) {
                    if let icon = item.icon {
                        Image(systemName: icon)
                            .frame(width: 16)
                            .foregroundColor(.secondary)
                    }
                    Text(item.title)
                        .lineLimit(1)
                        .font(.callout)
                    Spacer()
                    if let value = item.value {
                        Text(value)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var detailedListView: some View {
        VStack(spacing: 4) {
            ForEach(component.items) { item in
                HStack(spacing: 8) {
                    if let icon = item.icon {
                        Image(systemName: icon)
                            .frame(width: 20)
                            .foregroundColor(color(for: item.color))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.callout)
                            .lineLimit(1)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if let value = item.value {
                        Text(value)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var tableView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("名称")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let first = component.items.first, first.subtitle != nil {
                    Text("说明")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("值")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            Divider()
            ForEach(component.items) { item in
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.callout)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(item.value ?? "")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func color(for hex: String?) -> Color {
        Color.from(hex: hex, fallback: .secondary)
    }
}
