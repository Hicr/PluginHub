import Darwin
import IOKit
import IOKit.ps
import PluginHubCore
import SwiftUI

@MainActor
final class PowerMonitor: ObservableObject {
    nonisolated static let pluginStateID = "builtin-power-monitor"

    @Published private(set) var reading: PowerReading?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var active = false
    @Published private(set) var refreshing = false
    @Published private(set) var cpuUsage: Double?
    @Published private(set) var memoryUsage: Double?
    @Published private(set) var thermalState: ProcessInfo.ThermalState?

    @Published private(set) var chipPower: String?
    @Published private(set) var chipSampleTime: Date?
    @Published private(set) var chipSampling = false

    private var enabled = false
    private var interval = 5
    private var schedule: Task<Void, Never>?
    private var request: Task<Void, Never>?
    private var generation = 0
    private var previousCPUTicks: (busy: UInt64, total: UInt64)?

    var visible = false {
        didSet {
            if visible != oldValue { reschedule() }
        }
    }

    func configure(_ plugin: PluginConfiguration) {
        let newInterval = max(1, plugin.refreshIntervalSeconds)
        guard enabled != plugin.enabled || interval != newInterval else { return }
        enabled = plugin.enabled
        interval = newInterval
        reschedule()
    }

    private func reschedule() {
        schedule?.cancel()
        active = enabled && visible
        guard active else {
            generation += 1
            previousCPUTicks = nil
            cpuUsage = nil
            return
        }
        let interval = interval
        schedule = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                do { try await Task.sleep(for: .seconds(interval)) }
                catch { return }
            }
        }
    }

    func refresh() {
        guard active, request == nil else { return }
        refreshing = true
        let generation = generation
        request = Task { [weak self] in
            let (sample, cpuTicks, memoryUsage) = await Task.detached(priority: .utility) {
                (Self.collect(), Self.cpuTicks(), Self.memoryUsage())
            }.value
            guard let self else { return }
            self.request = nil
            self.refreshing = false
            guard self.active else { return }
            guard self.generation == generation else {
                self.refresh()
                return
            }
            if let cpuTicks, let previous = self.previousCPUTicks,
               cpuTicks.total > previous.total, cpuTicks.busy >= previous.busy {
                self.cpuUsage = min(1, Double(cpuTicks.busy - previous.busy) / Double(cpuTicks.total - previous.total))
            } else {
                self.cpuUsage = nil
            }
            self.previousCPUTicks = cpuTicks
            self.memoryUsage = memoryUsage
            self.thermalState = ProcessInfo.processInfo.thermalState
            self.reading = sample
            self.updatedAt = Date()
        }
    }

    func sampleChipPower() {
        guard active, !chipSampling else { return }
        chipSampling = true
        let generation = generation
        Task {
            let result = await Task.detached(priority: .utility) { Self.collectChipPower() }.value
            chipSampling = false
            guard active, generation == self.generation else { return }
            chipPower = result
            chipSampleTime = Date()
        }
    }

    nonisolated private static func collectChipPower() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", """
            do shell script "/usr/bin/powermetrics -n 1 -i 500 -s cpu_power" with administrator privileges
            """]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let report = String(decoding: data, as: UTF8.self)
                let labels = ["CPU Power", "GPU Power", "ANE Power"]
                let values = report.split(whereSeparator: \.isNewline).compactMap { line -> String? in
                    let fields = line.split(separator: ":", maxSplits: 1)
                    guard fields.count == 2, labels.contains(String(fields[0])) else { return nil }
                    let parts = fields[1].split(whereSeparator: \.isWhitespace)
                    guard parts.count == 2, let value = Double(parts[0]), value.isFinite, value >= 0,
                          let chip = fields[0].split(separator: " ").first else { return nil }
                    if parts[1] == "mW" { return "\(chip) \(watts(value / 1000))" }
                    if parts[1] == "W" { return "\(chip) \(watts(value))" }
                    return nil
                }
                if !values.isEmpty { return values.joined(separator: " · ") }
            }
        } catch {
            return "无法启动芯片功耗采样"
        }
        return "未取得芯片功耗数据"
    }

    nonisolated private static func cpuTicks() -> (busy: UInt64, total: UInt64)? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.stride)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        let ticks = info.cpu_ticks
        let busy = UInt64(ticks.0) + UInt64(ticks.1) + UInt64(ticks.3)
        return (busy, busy + UInt64(ticks.2))
    }

    nonisolated private static func memoryUsage() -> Double? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.stride)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        var pageSize: vm_size_t = 0
        guard status == KERN_SUCCESS, totalBytes > 0,
              host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        let usedPages = Double(info.internal_page_count) + Double(info.wire_count)
            + Double(info.compressor_page_count) - Double(info.purgeable_count)
        return min(1, max(0, usedPages * Double(pageSize) / Double(totalBytes)))
    }

    nonisolated private static func collect() -> PowerReading? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let registry = properties?.takeRetainedValue() as? [String: Any] else { return nil }
        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] ?? [:]
        return PowerReading(registry: registry, adapter: adapter)
    }
}

struct PowerMonitorCard: View {
    @ObservedObject var monitor: PowerMonitor
    let title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let sample = monitor.reading
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text(title.isEmpty ? "整机功率" : title).font(.headline)
                } icon: {
                    Image(systemName: "bolt.fill").foregroundStyle(.blue)
                }
                Spacer()
                if let date = monitor.updatedAt {
                    Text(date, style: .time).font(.caption).foregroundStyle(.secondary)
                }
                Button { monitor.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(monitor.refreshing)
                    .help("立即刷新")
            }
            PowerFlowDiagram(reading: sample, animated: monitor.active && !reduceMotion)
            if sample?.externalConnected == true, let battery = sample?.batteryWatts, battery < -0.5 {
                Label("已接外部电源，电池正在补电", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    metric("CPU 占用", monitor.cpuUsage.map { $0.formatted(.percent.precision(.fractionLength(1))) })
                    metric("内存占用", monitor.memoryUsage.map { $0.formatted(.percent.precision(.fractionLength(1))) })
                }
                GridRow {
                    metric("电池温度", sample?.batteryTemperature.map { String(format: "%.1f °C", $0) })
                    metric("电源规格", sample?.adapterWatts.map { watts($0) })
                }
                metric("系统热状态", thermalLabel).gridCellColumns(2)
                if let name = sample?.adapterName, !name.isEmpty {
                    Text(name).font(.caption).foregroundStyle(.secondary).gridCellColumns(2)
                }
            }
            HStack {
                Text("芯片功耗").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(monitor.chipSampling ? "采样中…" : "授权并采样") { monitor.sampleChipPower() }
                    .disabled(monitor.chipSampling)
                    .help("通过管理员授权读取一次 CPU、GPU 和 ANE 功耗")
            }
            if let chipPower = monitor.chipPower, let date = monitor.chipSampleTime {
                HStack {
                    Text(chipPower).monospacedDigit()
                    Spacer()
                    Text(date, style: .time).foregroundStyle(.secondary)
                }.font(.caption)
            }
            if monitor.updatedAt != nil && sample == nil {
                Text("当前设备暂无电源读数").font(.caption).foregroundStyle(.secondary)
            }
        }
        .modifier(NetworkCardBackground())
    }

    private var thermalLabel: String? {
        guard let state = monitor.thermalState else { return nil }
        switch state {
        case .nominal: return "正常"
        case .fair: return "偏热"
        case .serious: return "高热"
        case .critical: return "严重"
        @unknown default: return nil
        }
    }

    private func metric(_ title: String, _ value: String?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
            Spacer(minLength: 2)
            Text(value ?? "暂无数据")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(value == nil ? Color.secondary : Color.primary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        }
    }
}

private func watts(_ value: Double) -> String {
    String(format: "%.1f W", value)
}

private struct PowerFlowDiagram: View {
    let reading: PowerReading?
    let animated: Bool

    var body: some View {
        let input = reading?.inputWatts ?? 0
        let battery = reading?.batteryWatts ?? 0
        let adapterActive = input > 0
        let batteryActive = abs(battery) > 0.1
        let batteryTint: Color = batteryActive ? .teal : .gray
        GeometryReader { geometry in
            let width = geometry.size.width
            let center = width - 52
            let sideWidth: CGFloat = 58
            let centerWidth: CGFloat = 76
            let upper = CGPoint(x: sideWidth - 1, y: 36)
            let lower = CGPoint(x: sideWidth - 1, y: 120)
            let upperJoin = CGPoint(x: center - centerWidth / 2 + 1, y: 54)
            let lowerJoin = CGPoint(x: upperJoin.x, y: 102)

            TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !animated || (!adapterActive && !batteryActive))) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.8) / 3.8
                Canvas { context, _ in
                    ribbon(context, from: upper, to: upperJoin, tint: .blue, flowsRight: adapterActive ? true : nil,
                           phase: animated && adapterActive ? phase : nil)
                    ribbon(context, from: lower, to: lowerJoin, tint: batteryTint, flowsRight: batteryActive ? battery < 0 : nil,
                           phase: animated && batteryActive ? (battery > 0 ? 1 - phase : phase) : nil)
                }
                .accessibilityHidden(true)
            }
            flowValue("实时输入", reading?.inputWatts.map(watts), direction: adapterActive ? "外部电源到 Mac" : nil, flowsRight: true, from: upper, to: upperJoin)
            flowValue("电池功率", reading?.batteryWatts.map { watts(abs($0)) },
                      direction: batteryActive ? (battery > 0 ? "Mac 到电池" : "电池到 Mac") : nil,
                      flowsRight: battery < 0, estimated: reading?.batteryWattsEstimated == true, from: lower, to: lowerJoin)

            node("外部电源", icon: "powerplug.fill", color: adapterActive ? .blue : .secondary)
                .frame(width: sideWidth, height: 60)
                .modifier(FlowNodeSurface())
                .position(x: sideWidth / 2, y: upper.y)
            node(battery < -0.1 ? "电池放电" : battery > 0.1 ? "电池充电" : "电池",
                 icon: "battery.50percent", color: batteryTint,
                 value: reading?.batteryPercent.map { "\($0)%" })
                .frame(width: sideWidth, height: 60)
                .modifier(FlowNodeSurface())
                .position(x: sideWidth / 2, y: lower.y)
            VStack(spacing: 5) {
                Image(systemName: "laptopcomputer").font(.title2).foregroundStyle(.blue)
                Text("系统负载").font(.caption2).foregroundStyle(.secondary)
                Text(reading?.loadWatts.map(watts) ?? "暂无数据")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                if reading?.loadWatts != nil {
                    Text("系统遥测").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .frame(width: centerWidth, height: 118)
            .modifier(FlowNodeSurface())
            .position(x: center, y: 78)
        }
        .frame(height: 156)
    }

    private func flowValue(
        _ label: String, _ value: String?, direction: String? = nil, flowsRight: Bool = true,
        estimated: Bool = false,
        from: CGPoint, to: CGPoint
    ) -> some View {
        VStack(spacing: 1) {
            Text(value ?? "暂无数据")
                .font(.system(size: value == nil ? 10 : 14, weight: .semibold, design: .rounded))
                .foregroundStyle(value == nil ? Color.secondary : Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if direction != nil || estimated {
                HStack(spacing: 4) {
                    if estimated { Text("估算") }
                    if direction != nil {
                        Image(systemName: flowsRight ? "arrow.right" : "arrow.left")
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            }
        }
        .frame(width: max(0, to.x - from.x - 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue([value ?? "暂无数据", estimated ? "估算" : nil, direction].compactMap { $0 }.joined(separator: "，"))
        .position(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
    }

    private func node(_ title: String, icon: String, color: Color, value: String? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(color)
            if let value {
                Text(value).font(.callout.weight(.semibold)).monospacedDigit()
            }
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func ribbon(_ context: GraphicsContext, from: CGPoint, to: CGPoint, tint: Color, flowsRight: Bool?, phase: Double?) {
        let middle = (from.x + to.x) / 2
        let startHalfWidth: CGFloat = 21
        let endHalfWidth: CGFloat = 17
        var band = Path()
        band.move(to: CGPoint(x: from.x, y: from.y - startHalfWidth))
        band.addCurve(to: CGPoint(x: to.x, y: to.y - endHalfWidth),
                      control1: CGPoint(x: middle, y: from.y - startHalfWidth), control2: CGPoint(x: middle, y: to.y - endHalfWidth))
        band.addLine(to: CGPoint(x: to.x, y: to.y + endHalfWidth))
        band.addCurve(to: CGPoint(x: from.x, y: from.y + startHalfWidth),
                      control1: CGPoint(x: middle, y: to.y + endHalfWidth), control2: CGPoint(x: middle, y: from.y + startHalfWidth))
        band.closeSubpath()
        if let flowsRight {
            context.fill(band, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.10), tint.opacity(0.38)]),
                startPoint: flowsRight ? from : to, endPoint: flowsRight ? to : from
            ))
        } else {
            context.fill(band, with: .color(.gray.opacity(0.15)))
        }
        context.stroke(band, with: .color((flowsRight == nil ? Color.gray : tint).opacity(0.27)), lineWidth: 0.75)
        if let phase {
            let x = from.x + (to.x - from.x) * phase
            context.fill(band, with: .linearGradient(
                Gradient(colors: [.clear, tint.opacity(0.55), .clear]),
                startPoint: CGPoint(x: x - 24, y: 0), endPoint: CGPoint(x: x + 24, y: 0)
            ))
        }
    }
}


private struct FlowNodeSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            }
    }
}
