import SwiftUI
import PluginHubCore

struct ImageRenderer: View {
    let component: ImageComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if component.url.hasPrefix("data:") {
                // base64 图片
                if let image = decodeBase64(component.url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: component.width.map { CGFloat($0) } ?? .infinity)
                        .frame(maxHeight: component.height.map { CGFloat($0) } ?? .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("图片解码失败")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let url = URL(string: component.url) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: component.width.map { CGFloat($0) } ?? .infinity)
                            .frame(maxHeight: component.height.map { CGFloat($0) } ?? .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        Text("图片加载失败")
                            .font(.caption)
                            .foregroundColor(.red)
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Text("无效的图片地址")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let caption = component.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func decodeBase64(_ dataURL: String) -> NSImage? {
        let base64 = dataURL.components(separatedBy: ",").last ?? dataURL
        guard let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
    }
}
