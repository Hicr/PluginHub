import SwiftUI
import PluginHubCore

@MainActor
final class Countdown: ObservableObject {
    nonisolated static let pluginStateID = "builtin-countdown"
    @Published private(set) var state = CountdownState()
    @Published private(set) var error: String?
    private let fileURL: URL

    init(fileURL: URL = ConfigStore.defaultConfigurationDirectoryURL().appendingPathComponent("countdown.json")) {
        self.fileURL = fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            state = try PluginHubJSON.decoder().decode(CountdownState.self, from: Data(contentsOf: fileURL))
            guard state.duration.isFinite, (0...8_639_999).contains(state.duration) else {
                state = CountdownState()
                error = "已保存的时长无效，请重新设置"
                return
            }
        } catch {
            self.error = "倒计时读取失败：\(error.localizedDescription)"
        }
    }

    func start(duration: TimeInterval) {
        guard duration.isFinite, (1...8_639_999).contains(duration) else { return }
        save(CountdownState(duration: duration, endDate: Date().addingTimeInterval(duration)))
    }

    func cancel() {
        save(CountdownState(duration: state.duration))
    }

    private func save(_ next: CountdownState) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PluginHubJSON.encoder().encode(next).write(to: fileURL, options: .atomic)
            state = next
            error = nil
        } catch {
            self.error = "倒计时保存失败：\(error.localizedDescription)"
        }
    }
}

struct CountdownCard: View {
    @ObservedObject var countdown: Countdown
    let title: String
    @State private var inputs = ["", "", "", ""]
    @State private var validation: String?
    @State private var flashing = false
    @State private var wasRunning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let units = ["天", "小时", "分钟", "秒"]
    private let factors = [86400, 3600, 60, 1]
    private let maxima = [99, 23, 59, 59]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = countdown.state.remaining(at: context.date)
            let completed = countdown.state.endDate != nil && remaining <= 0
            let fraction = countdown.state.remainingFraction(at: context.date)
            let color: Color = completed ? .green : fraction <= 0.1 ? .red : fraction <= 0.3 ? .orange : .green
            VStack(alignment: .leading, spacing: 10) {
                Text(title.isEmpty ? "倒计时" : title).font(.headline)
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(.primary.opacity(0.06))
                    CountdownBorder(fraction: 1)
                        .stroke(.primary.opacity(0.12), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .padding(5)
                    CountdownBorder(fraction: countdown.state.endDate == nil || completed ? 1 : fraction)
                        .stroke(color.opacity(flashing ? 0.2 : 0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .padding(5)
                    VStack(spacing: 12) {
                        if countdown.state.endDate == nil {
                            HStack(spacing: 8) {
                                ForEach(0..<4) { index in
                                    VStack(spacing: 4) {
                                        TextField("00", text: $inputs[index])
                                            .textFieldStyle(.plain)
                                            .multilineTextAlignment(.center)
                                            .font(.system(size: 25, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .padding(.vertical, 8)
                                            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                                            .accessibilityLabel(units[index])
                                        Text(units[index]).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Text("最长 99 天 23 小时 59 分 59 秒")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            let minutes = Int(remaining / 60)
                            let days = minutes / 1440
                            HStack(alignment: .bottom, spacing: 8) {
                                DigitalNumber(text: String(format: "%02d", days))
                                    .frame(width: 60, height: 44)
                                Text("天")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 2)
                                DigitalNumber(text: String(format: "%02d:%02d", minutes / 60 % 24, minutes % 60))
                                    .frame(width: 150, height: 44)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.primary)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(remaining > 0 && minutes == 0 ? "剩余不足一分钟" : "剩余 \(days) 天 \(minutes / 60 % 24) 小时 \(minutes % 60) 分")
                            Text(completed ? "倒计时结束" : remaining < 60 ? "剩余不足 1 分钟" : "剩余时间")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            if let end = countdown.state.endDate {
                                Text("结束于 \(end.formatted(.dateTime.year().month().day().hour().minute()))")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(22)
                }
                .frame(height: 160)
                .onAppear { wasRunning = countdown.state.endDate != nil && !completed }
                .onChange(of: completed) { ended in
                    if ended && wasRunning && !reduceMotion {
                        withAnimation(.easeInOut(duration: 0.25).repeatCount(2, autoreverses: true)) { flashing = true }
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.6))
                            flashing = false
                        }
                    }
                    wasRunning = countdown.state.endDate != nil && !ended
                }
                .onChange(of: countdown.state.endDate) { end in
                    wasRunning = end.map { $0 > Date() } ?? false
                }
                HStack {
                    if countdown.state.endDate == nil {
                        Spacer()
                        Button("确认") { confirm() }.buttonStyle(.borderedProminent)
                    } else {
                        Button(completed ? "设置时长" : "取消") { countdown.cancel() }
                        Spacer()
                        Button("重新开始") { countdown.start(duration: countdown.state.duration) }
                    }
                }
                if let error = validation ?? countdown.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .modifier(NetworkCardBackground())
        }
        .onAppear {
            let duration = Int(countdown.state.duration)
            inputs = [duration / 86400, duration / 3600 % 24, duration / 60 % 60, duration % 60].map(String.init)
        }
    }

    private func confirm() {
        var total = 0
        for index in 0..<4 {
            let text = inputs[index].trimmingCharacters(in: .whitespaces)
            guard let value = Int(text.isEmpty ? "0" : text), (0...maxima[index]).contains(value) else {
                validation = "\(units[index])请输入 0–\(maxima[index]) 的整数"
                return
            }
            total += value * factors[index]
        }
        guard total > 0 else { validation = "请输入大于零的时长"; return }
        validation = nil
        countdown.start(duration: Double(total))
    }
}

private struct DigitalNumber: View {
    let text: String
    private let segments = [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f]
    var body: some View {
        Canvas { context, size in
            let characters = Array(text)
            let cell = size.width / CGFloat(max(1, characters.count))
            let strokeWidth: CGFloat = 6
            let digitWidth = cell - strokeWidth - 3
            let height = size.height
            for (index, character) in characters.enumerated() {
                // Keep the full stroke inside the canvas, including the first left segment.
                let x = CGFloat(index) * cell + strokeWidth / 2 + 1.5
                if character == ":" {
                    for y in [height * 0.32, height * 0.68] {
                        context.fill(Path(ellipseIn: CGRect(x: x + digitWidth / 2 - strokeWidth / 2, y: y, width: strokeWidth, height: strokeWidth)), with: .foreground)
                    }
                } else if let value = character.wholeNumberValue {
                    let points: [(CGPoint, CGPoint)] = [
                        (.init(x: x + 5, y: 3.5), .init(x: x + digitWidth - 5, y: 3.5)),
                        (.init(x: x + digitWidth, y: 8), .init(x: x + digitWidth, y: height / 2 - 4.5)),
                        (.init(x: x + digitWidth, y: height / 2 + 4.5), .init(x: x + digitWidth, y: height - 8)),
                        (.init(x: x + 5, y: height - 3.5), .init(x: x + digitWidth - 5, y: height - 3.5)),
                        (.init(x: x, y: height / 2 + 4.5), .init(x: x, y: height - 8)),
                        (.init(x: x, y: 8), .init(x: x, y: height / 2 - 4.5)),
                        (.init(x: x + 5, y: height / 2), .init(x: x + digitWidth - 5, y: height / 2))
                    ]
                    for (segment, pair) in points.enumerated() {
                        var path = Path()
                        path.move(to: pair.0)
                        path.addLine(to: pair.1)
                        var layer = context
                        layer.opacity = segments[value] & (1 << segment) == 0 ? 0.09 : 1
                        layer.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    }
                }
            }
        }
    }
}

private struct CountdownBorder: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        // Walk the rounded perimeter clockwise, starting at the top centre.
        let radius = min(13.0, min(rect.width, rect.height) / 2)
        let straightX = rect.width - radius * 2
        let straightY = rect.height - radius * 2
        let arc = .pi * radius / 2
        let perimeter = 2 * straightX + 2 * straightY + 4 * arc
        let count = max(1, Int(perimeter / 9))
        var path = Path()
        for index in 0..<count {
            guard Double(index) / Double(count) < fraction else { continue }
            let distance = (CGFloat(index) / CGFloat(count) * perimeter + straightX / 2).truncatingRemainder(dividingBy: perimeter)
            let point = perimeterPoint(distance, rect: rect, radius: radius)
            let next = perimeterPoint((distance + 0.5).truncatingRemainder(dividingBy: perimeter), rect: rect, radius: radius)
            let angle = atan2(next.y - point.y, next.x - point.x) + .pi / 4
            let dx = cos(angle) * 3
            let dy = sin(angle) * 3
            path.move(to: CGPoint(x: point.x - dx, y: point.y - dy))
            path.addLine(to: CGPoint(x: point.x + dx, y: point.y + dy))
        }
        return path
    }

    private func perimeterPoint(_ distance: CGFloat, rect: CGRect, radius: CGFloat) -> CGPoint {
        let x = rect.width - 2 * radius
        let y = rect.height - 2 * radius
        let arc = .pi * radius / 2
        var remaining = distance
        let lengths = [x, arc, y, arc, x, arc, y, arc]
        for (index, length) in lengths.enumerated() {
            if remaining <= length {
                switch index {
                case 0: return CGPoint(x: radius + remaining, y: 0)
                case 2: return CGPoint(x: rect.width, y: radius + remaining)
                case 4: return CGPoint(x: rect.width - radius - remaining, y: rect.height)
                case 6: return CGPoint(x: 0, y: rect.height - radius - remaining)
                default:
                    let centers = [CGPoint(x: rect.width - radius, y: radius), CGPoint(x: rect.width - radius, y: rect.height - radius), CGPoint(x: radius, y: rect.height - radius), CGPoint(x: radius, y: radius)]
                    let corner = index / 2
                    let angle = CGFloat(corner - 1) * .pi / 2 + remaining / radius
                    return CGPoint(x: centers[corner].x + cos(angle) * radius, y: centers[corner].y + sin(angle) * radius)
                }
            }
            remaining -= length
        }
        return CGPoint(x: radius, y: 0)
    }
}
