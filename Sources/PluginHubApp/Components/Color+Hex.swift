import SwiftUI

extension Color {
    static func from(hex: String?, fallback: Color) -> Color {
        guard let hex else { return fallback }

        // 先检查是否为命名的颜色名
        switch hex.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        default: break
        }

        // 解析 hex 颜色
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized = String(sanitized.dropFirst())
        }

        guard sanitized.count == 6,
              let value = UInt64(sanitized, radix: 16) else {
            return fallback
        }

        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}
