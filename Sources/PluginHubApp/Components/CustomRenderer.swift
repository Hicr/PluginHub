import SwiftUI
import PluginHubCore

struct CustomRenderer: View {
    let component: CustomComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(component.type)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 2) {
                ForEach(Array(component.data.keys.sorted()), id: \.self) { key in
                    HStack(spacing: 6) {
                        Text(key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        Text(component.data[key] ?? "")
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
