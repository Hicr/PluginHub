import SwiftUI
import PluginHubCore

struct TextRenderer: View {
    let component: TextComponent

    var body: some View {
        HStack(spacing: 6) {
            if let icon = component.icon {
                Image(systemName: icon)
                    .foregroundColor(styleColor)
            }
            Text(component.content)
                .font(.callout)
                .foregroundColor(styleColor)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(styleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var styleColor: Color {
        switch component.style {
        case .alert: return .red
        case .success: return .green
        case .warning: return .orange
        default: return .primary
        }
    }

    private var styleBackground: Color {
        switch component.style {
        case .alert: return .red.opacity(0.08)
        case .success: return .green.opacity(0.08)
        case .warning: return .orange.opacity(0.08)
        default: return .clear
        }
    }
}
